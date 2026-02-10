////////////////////////////
// VDSL3 helper functions //
////////////////////////////

// Import functions from viash-core plugin
include {
  // Collection utilities
  iterateMap;
  deepClone;
  mergeMap as _mergeMap;
  collectFiles;
  collectInputOutputPaths;

  // Text utilities
  paragraphWrap as _paragraphWrap;

  // Serialization utilities
  readJsonBlob;
  readYamlBlob;
  readTaggedYaml;
  toJsonBlob;
  toYamlBlob;
  toTaggedYamlBlob;
  toRelativeTaggedYamlBlob;
  writeJson;
  writeYaml;

  // Config utilities
  processArgument as _processArgument;
  processConfig;
  processAuto;
  assertMapKeys;

  // Help utilities
  generateArgumentHelp as _generateArgumentHelp;
  generateHelp as _generateHelp;

  // Path utilities
  stringIsAbsolutePath as _stringIsAbsolutePath;
  getChild as _getChild;
  getRootDir;

  // Directive utilities
  processDirectivesWithOverride as _processDirectivesWithOverride;

  // State utilities
  checkUniqueIds as _checkUniqueIds;
  splitParams as _splitParams;
  paramListGuessFormat as _paramListGuessFormat;
  processFromState as _processFromState;
  processToState as _processToState;
} from 'plugin/viash-core'

// helper file: 'src/main/resources/io/viash/runners/nextflow/arguments/_checkArgumentType.nf'
class UnexpectedArgumentTypeException extends Exception {
  String errorIdentifier
  String stage
  String plainName
  String expectedClass
  String foundClass
  
  // ${key ? " in module '$key'" : ""}${id ? " id '$id'" : ""}
  UnexpectedArgumentTypeException(String errorIdentifier, String stage, String plainName, String expectedClass, String foundClass) {
    super("Error${errorIdentifier ? " $errorIdentifier" : ""}:${stage ? " $stage" : "" } argument '${plainName}' has the wrong type. " +
      "Expected type: ${expectedClass}. Found type: ${foundClass}")
    this.errorIdentifier = errorIdentifier
    this.stage = stage
    this.plainName = plainName
    this.expectedClass = expectedClass
    this.foundClass = foundClass
  }
}

/**
  * Checks if the given value is of the expected type. If not, an exception is thrown.
  *
  * @param stage The stage of the argument (input or output)
  * @param par The parameter definition
  * @param value The value to check
  * @param errorIdentifier The identifier to use in the error message
  * @return The value, if it is of the expected type
  * @throws UnexpectedArgumentTypeException If the value is not of the expected type
*/
def _checkArgumentType(String stage, Map par, Object value, String errorIdentifier) {
  // expectedClass will only be != null if value is not of the expected type
  def expectedClass = null
  def foundClass = null
  
  // todo: split if need be
  
  if (!par.required && value == null) {
    expectedClass = null
  } else if (par.multiple) {
    if (value !instanceof Collection) {
      value = [value]
    }
    
    // split strings
    value = value.collectMany{ val ->
      if (val instanceof String) {
        // collect() to ensure that the result is a List and not simply an array
        val.split(par.multiple_sep).collect()
      } else {
        [val]
      }
    }

    // process globs
    if (par.type == "file" && par.direction == "input") {
      value = value.collect{ it instanceof String ? file(it, hidden: true) : it }.flatten()
    }

    // check types of elements in list
    try {
      value = value.collect { listVal ->
        _checkArgumentType(stage, par + [multiple: false], listVal, errorIdentifier)
      }
    } catch (UnexpectedArgumentTypeException e) {
      expectedClass = "List[${e.expectedClass}]"
      foundClass = "List[${e.foundClass}]"
    }
  } else if (par.type == "string") {
    // cast to string if need be. only cast if the value is a GString
    if (value instanceof GString) {
      value = value as String
    }
    expectedClass = value instanceof String ? null : "String"
  } else if (par.type == "integer") {
    // cast to integer if need be
    if (value !instanceof Integer) {
      try {
        value = value as Integer
      } catch (NumberFormatException e) {
        expectedClass = "Integer"
      }
    }
  } else if (par.type == "long") {
    // cast to long if need be
    if (value !instanceof Long) {
      try {
        value = value as Long
      } catch (NumberFormatException e) {
        expectedClass = "Long"
      }
    }
  } else if (par.type == "double") {
    // cast to double if need be
    if (value !instanceof Double) {
      try {
        value = value as Double
      } catch (NumberFormatException e) {
        expectedClass = "Double"
      }
    }
  } else if (par.type == "float") {
    // cast to float if need be
    if (value !instanceof Float) {
      try {
        value = value as Float
      } catch (NumberFormatException e) {
        expectedClass = "Float"
      }
    }
  } else if (par.type == "boolean" | par.type == "boolean_true" | par.type == "boolean_false") {
    // cast to boolean if need be
    if (value !instanceof Boolean) {
      try {
        value = value as Boolean
      } catch (Exception e) {
        expectedClass = "Boolean"
      }
    }
  } else if (par.type == "file" && (par.direction == "input" || stage == "output")) {
    // cast to path if need be
    if (value instanceof String) {
      value = file(value, hidden: true)
    }
    if (value instanceof File) {
      value = value.toPath()
    }
    expectedClass = value instanceof Path ? null : "Path"
  } else if (par.type == "file" && stage == "input" && par.direction == "output") {
    // cast to string if need be
    if (value !instanceof String) {
      try {
        value = value as String
      } catch (Exception e) {
        expectedClass = "String"
      }
    }
  } else {
    // didn't find a match for par.type
    expectedClass = par.type
  }

  if (expectedClass != null) {
    if (foundClass == null) {
      foundClass = value.getClass().getName()
    }
    throw new UnexpectedArgumentTypeException(errorIdentifier, stage, par.plainName, expectedClass, foundClass)
  }
  
  return value
}
// helper file: 'src/main/resources/io/viash/runners/nextflow/arguments/_processInputValues.nf'
Map _processInputValues(Map inputs, Map config, String id, String key) {
  if (!workflow.stubRun) {
    config.allArguments.each { arg ->
      if (arg.required && arg.direction == "input") {
        assert inputs.containsKey(arg.plainName) && inputs.get(arg.plainName) != null : 
          "Error in module '${key}' id '${id}': required input argument '${arg.plainName}' is missing"
      }
    }

    inputs = inputs.collectEntries { name, value ->
      def par = config.allArguments.find { it.plainName == name && (it.direction == "input" || it.type == "file") }
      assert par != null : "Error in module '${key}' id '${id}': '${name}' is not a valid input argument"

      value = _checkArgumentType("input", par, value, "in module '$key' id '$id'")

      [ name, value ]
    }
  }
  return inputs
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/arguments/_processOutputValues.nf'
Map _checkValidOutputArgument(Map outputs, Map config, String id, String key) {
  if (!workflow.stubRun) {
    outputs = outputs.collectEntries { name, value ->
      def par = config.allArguments.find { it.plainName == name && it.direction == "output" }
      assert par != null : "Error in module '${key}' id '${id}': '${name}' is not a valid output argument"
      
      value = _checkArgumentType("output", par, value, "in module '$key' id '$id'")
      
      [ name, value ]
    }
  }
  return outputs
}

void _checkAllRequiredOuputsPresent(Map outputs, Map config, String id, String key) {
  if (!workflow.stubRun) {
    config.allArguments.each { arg ->
      if (arg.direction == "output" && arg.required) {
        assert outputs.containsKey(arg.plainName) && outputs.get(arg.plainName) != null : 
          "Error in module '${key}' id '${id}': required output argument '${arg.plainName}' is missing"
      }
    }
  }
}
// helper file: 'src/main/resources/io/viash/runners/nextflow/channel/IDChecker.nf'
class IDChecker {
  final def items = [] as Set

  @groovy.transform.WithWriteLock
  boolean observe(String item) {
    if (items.contains(item)) {
      return false
    } else {
      items << item
      return true
    }
  }

  @groovy.transform.WithReadLock
  boolean contains(String item) {
    return items.contains(item)
  }

  @groovy.transform.WithReadLock
  Set getItems() {
    return items.clone()
  }
}
// helper file: 'src/main/resources/io/viash/runners/nextflow/channel/_channelFromParams.nf'
/**
 * Parse nextflow parameters based on settings defined in a viash config.
 * Return a list of parameter sets, each parameter set corresponding to 
 * an event in a nextflow channel. The output from this function can be used
 * with Channel.fromList to create a nextflow channel with Vdsl3 formatted 
 * events.
 *
 * This function performs:
 *   - A filtering of the params which can be found in the config file.
 *   - Process the params_list argument which allows a user to to initialise 
 *     a Vsdl3 channel with multiple parameter sets. Possible formats are 
 *     csv, json, yaml, or simply a yaml_blob. A csv should have column names 
 *     which correspond to the different arguments of this pipeline. A json or a yaml
 *     file should be a list of maps, each of which has keys corresponding to the
 *     arguments of the pipeline. A yaml blob can also be passed directly as a parameter.
 *     When passing a csv, json or yaml, relative path names are relativized to the
 *     location of the parameter file.
 *   - Combine the parameter sets into a vdsl3 Channel.
 *
 * @param params Input parameters. Can optionaly contain a 'param_list' key that
 *               provides a list of arguments that can be split up into multiple events
 *               in the output channel possible formats of param_lists are: a csv file, 
 *               json file, a yaml file or a yaml blob. Each parameters set (event) must
 *               have a unique ID.
 * @param config A Map of the Viash configuration. This Map can be generated from the config file
 *               using the readConfig() function.
 * 
 * @return A list of parameters with the first element of the event being
 *         the event ID and the second element containing a map of the parsed parameters.
 */
 
List<Tuple2<String, Map<String, Object>>> _paramsToParamSets(Map params, Map config){
  // todo: fetch key from run args
  def key_ = config.name
  
  /* parse regular parameters (not in param_list)  */
  /*************************************************/
  def globalParams = config.allArguments
    .findAll { params.containsKey(it.plainName) }
    .collectEntries { [ it.plainName, params[it.plainName] ] }
  def globalID = params.get("id", null)

  /* process params_list arguments */
  /*********************************/
  def paramList = params.containsKey("param_list") && params.param_list != null ?
    params.param_list : []
  // if (paramList instanceof String) {
  //   paramList = [paramList]
  // }
  // def paramSets = paramList.collectMany{ _parseParamList(it, config) }
  // TODO: be able to process param_list when it is a list of strings
  def paramSets = _parseParamList(paramList, config)
  if (paramSets.isEmpty()) {
    paramSets = [[null, [:]]]
  }

  /* combine arguments into channel */
  /**********************************/
  def processedParams = paramSets.indexed().collect{ index, tup ->
    // Process ID
    def id = tup[0] ?: globalID
  
    if (workflow.stubRun && !id) {
      // if stub run, explicitly add an id if missing
      id = "stub${index}"
    }
    assert id != null: "Each parameter set should have at least an 'id'"

    // Process params
    def parValues = globalParams + tup[1]
    // // Remove parameters which are null, if the default is also null
    // parValues = parValues.collectEntries{paramName, paramValue ->
    //   parameterSettings = config.functionality.allArguments.find({it.plainName == paramName})
    //   if ( paramValue != null || parameterSettings.get("default", null) != null ) {
    //     [paramName, paramValue]
    //   }
    // }
    parValues = parValues.collectEntries { name, value ->
      def par = config.allArguments.find { it.plainName == name && (it.direction == "input" || it.type == "file") }
      assert par != null : "Error in module '${key_}' id '${id}': '${name}' is not a valid input argument"

      if (par == null) {
        return [:]
      }
      value = _checkArgumentType("input", par, value, "in module '$key_' id '$id'")

      [ name, value ]
    }

    [id, parValues]
  }

  // Check if ids (first element of each list) is unique
  _checkUniqueIds(processedParams)
  return processedParams
}


def _channelFromParams(Map params, Map config) {
  def processedParams = _paramsToParamSets(params, config)
  return Channel.fromList(processedParams)
}

/**
  * Read the param list
  * 
  * @param param_list One of the following:
  *   - A String containing the path to the parameter list file (csv, json or yaml),
  *   - A yaml blob of a list of maps (yaml_blob),
  *   - Or a groovy list of maps (asis).
  * @param config A Map of the Viash configuration.
  * 
  * @return A List of Maps containing the parameters.
  */
def _parseParamList(param_list, Map config) {
  // first determine format by extension
  def paramListFormat = _paramListGuessFormat(param_list)

  def paramListPath = (paramListFormat != "asis" && paramListFormat != "yaml_blob") ?
    file(param_list, hidden: true) :
    null

  // get the correct parser function for the detected params_list format
  def paramSets = []
  if (paramListFormat == "asis") {
    paramSets = param_list
  } else if (paramListFormat == "yaml_blob") {
    paramSets = readYamlBlob(param_list)
  } else if (paramListFormat == "yaml") {
    paramSets = readYaml(paramListPath)
  } else if (paramListFormat == "json") {
    paramSets = readJson(paramListPath)
  } else if (paramListFormat == "csv") {
    paramSets = readCsv(paramListPath)
  } else {
    error "Format of provided --param_list not recognised.\n" +
    "Found: '$paramListFormat'.\n" +
    "Expected: a csv file, a json file, a yaml file,\n" +
    "a yaml blob or a groovy list of maps."
  }

  // data checks
  assert paramSets instanceof List: "--param_list should contain a list of maps"
  for (value in paramSets) {
    assert value instanceof Map: "--param_list should contain a list of maps"
  }

  // id is argument
  def idIsArgument = config.allArguments.any{it.plainName == "id"}

  // Reformat from List<Map> to List<Tuple2<String, Map>> by adding the ID as first element of a Tuple2
  paramSets = paramSets.collect({ data ->
    def id = data.id
    if (!idIsArgument) {
      data = data.findAll{k, v -> k != "id"}
    }
    [id, data]
  })

  // Split parameters with 'multiple: true'
  paramSets = paramSets.collect({ id, data ->
    data = _splitParams(data, config)
    [id, data]
  })
  
  // The paths of input files inside a param_list file may have been specified relatively to the
  // location of the param_list file. These paths must be made absolute.
  if (paramListPath) {
    paramSets = paramSets.collect({ id, data ->
      def new_data = data.collectEntries{ parName, parValue ->
        def par = config.allArguments.find{it.plainName == parName}
        if (par && par.type == "file" && par.direction == "input") {
          if (parValue instanceof Collection) {
            parValue = parValue.collectMany{path -> 
              def x = _resolveSiblingIfNotAbsolute(path, paramListPath)
              x instanceof Collection ? x : [x]
            }
          } else {
            parValue = _resolveSiblingIfNotAbsolute(parValue, paramListPath) 
          }
        }
        [parName, parValue]
      }
      [id, new_data]
    })
  }

  return paramSets
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/channel/checkUniqueIds.nf'
def checkUniqueIds(Map args) {
  def stopOnError = args.stopOnError == null ? args.stopOnError : true

  def idChecker = new IDChecker()

  return filter { tup ->
    if (!idChecker.observe(tup[0])) {
      if (stopOnError) {
        error "Duplicate id: ${tup[0]}"
      } else {
        log.warn "Duplicate id: ${tup[0]}, removing duplicate entry"
        return false
      }
    }
    return true
  }
}
// helper file: 'src/main/resources/io/viash/runners/nextflow/channel/runEach.nf'
/**
 * Run a list of components on a stream of data.
 * 
 * @param components: list of Viash VDSL3 modules to run
 * @param fromState: a closure, a map or a list of keys to extract from the input data.
 *   If a closure, it will be called with the id, the data and the component itself.
 * @param toState: a closure, a map or a list of keys to extract from the output data
 *   If a closure, it will be called with the id, the output data, the old state and the component itself.
 * @param filter: filter function to apply to the input.
 *   It will be called with the id, the data and the component itself.
 * @param id: id to use for the output data
 *   If a closure, it will be called with the id, the data and the component itself.
 * @param auto: auto options to pass to the components
 *
 * @return: a workflow that runs the components
 **/
def runEach(Map args) {
  assert args.components: "runEach should be passed a list of components to run"

  def components_ = args.components
  if (components_ !instanceof List) {
    components_ = [ components_ ]
  }
  assert components_.size() > 0: "pass at least one component to runEach"

  def fromState_ = args.fromState
  def toState_ = args.toState
  def filter_ = args.filter
  def runIf_ = args.runIf
  def id_ = args.id

  assert !runIf_ || runIf_ instanceof Closure: "runEach: must pass a Closure to runIf."

  workflow runEachWf {
    take: input_ch
    main:

    // generate one channel per method
    out_chs = components_.collect{ comp_ ->
      def filter_ch = filter_
        ? input_ch | filter{tup ->
          filter_(tup[0], tup[1], comp_)
        }
        : input_ch
      def id_ch = id_
        ? filter_ch | map{tup ->
          def new_id = id_
          if (new_id instanceof Closure) {
            new_id = new_id(tup[0], tup[1], comp_)
          }
          assert new_id instanceof String : "Error in runEach: id should be a String or a Closure that returns a String. Expected: id instanceof String. Found: ${new_id.getClass()}"
          [new_id] + tup.drop(1)
        }
        : filter_ch
      def chPassthrough = null
      def chRun = null
      if (runIf_) {
        def idRunIfBranch = id_ch.branch{ tup ->
          run: runIf_(tup[0], tup[1], comp_)
          passthrough: true
        }
        chPassthrough = idRunIfBranch.passthrough
        chRun = idRunIfBranch.run
      } else {
        chRun = id_ch
        chPassthrough = Channel.empty()
      }
      def data_ch = chRun | map{tup ->
          def new_data = tup[1]
          if (fromState_ instanceof Map) {
            new_data = fromState_.collectEntries{ key0, key1 ->
              [key0, new_data[key1]]
            }
          } else if (fromState_ instanceof List) {
            new_data = fromState_.collectEntries{ key ->
              [key, new_data[key]]
            }
          } else if (fromState_ instanceof Closure) {
            new_data = fromState_(tup[0], new_data, comp_)
          }
          tup.take(1) + [new_data] + tup.drop(1)
        }
      def out_ch = data_ch
        | comp_.run(
          auto: (args.auto ?: [:]) + [simplifyInput: false, simplifyOutput: false]
        )
      def post_ch = toState_
        ? out_ch | map{tup ->
          def output = tup[1]
          def old_state = tup[2]
          def new_state = null
          if (toState_ instanceof Map) {
            new_state = old_state + toState_.collectEntries{ key0, key1 ->
              [key0, output[key1]]
            }
          } else if (toState_ instanceof List) {
            new_state = old_state + toState_.collectEntries{ key ->
              [key, output[key]]
            }
          } else if (toState_ instanceof Closure) {
            new_state = toState_(tup[0], output, old_state, comp_)
          }
          [tup[0], new_state] + tup.drop(3)
        }
        : out_ch

      def return_ch = post_ch
        | concat(chPassthrough)
      
      return_ch
    }

    // mix all results
    output_ch =
      (out_chs.size == 1)
        ? out_chs[0]
        : out_chs[0].mix(*out_chs.drop(1))

    emit: output_ch
  }

  return runEachWf
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/channel/safeJoin.nf'
/**
 * Join sourceChannel to targetChannel
 * 
 * This function joins the sourceChannel to the targetChannel. 
 * However, each id in the targetChannel must be present in the
 * sourceChannel. If _meta.join_id exists in the targetChannel, that is 
 * used as an id instead. If the id doesn't match any id in the sourceChannel,
 * an error is thrown.
 */

def safeJoin(targetChannel, sourceChannel, key) {
  def sourceIDs = new IDChecker()

  def sourceCheck = sourceChannel
    | map { tup ->
      sourceIDs.observe(tup[0])
      tup
    }
  def targetCheck = targetChannel
    | map { tup ->
      def id = tup[0]
      
      if (!sourceIDs.contains(id)) {
        error (
          "Error in module '${key}' when merging output with original state.\n" +
          "  Reason: output with id '${id}' could not be joined with source channel.\n" +
          "    If the IDs in the output channel differ from the input channel,\n" + 
          "    please set `tup[1]._meta.join_id to the original ID.\n" +
          "  Original IDs in input channel: ['${sourceIDs.getItems().join("', '")}'].\n" + 
          "  Unexpected ID in the output channel: '${id}'.\n" +
          "  Example input event: [\"id\", [input: file(...)]],\n" +
          "  Example output event: [\"newid\", [output: file(...), _meta: [join_id: \"id\"]]]"
        )
      }
      // TODO: add link to our documentation on how to fix this

      tup
    }
  
  sourceCheck.cross(targetChannel)
    | map{ left, right ->
      right + left.drop(1)
    }
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/config/addGlobalParams.nf'
def addGlobalArguments(config) {
  def localConfig = [
    "argument_groups": [
      [
        "name": "Nextflow input-output arguments",
        "description": "Input/output parameters for Nextflow itself. Please note that both publishDir and publish_dir are supported but at least one has to be configured.",
        "arguments" : [
          [
            'name': '--publish_dir',
            'required': true,
            'type': 'string',
            'description': 'Path to an output directory.',
            'example': 'output/',
            'multiple': false
          ],
          [
            'name': '--param_list',
            'required': false,
            'type': 'string',
            'description': '''Allows inputting multiple parameter sets to initialise a Nextflow channel. A `param_list` can either be a list of maps, a csv file, a json file, a yaml file, or simply a yaml blob.
            |
            |* A list of maps (as-is) where the keys of each map corresponds to the arguments of the pipeline. Example: in a `nextflow.config` file: `param_list: [ ['id': 'foo', 'input': 'foo.txt'], ['id': 'bar', 'input': 'bar.txt'] ]`.
            |* A csv file should have column names which correspond to the different arguments of this pipeline. Example: `--param_list data.csv` with columns `id,input`.
            |* A json or a yaml file should be a list of maps, each of which has keys corresponding to the arguments of the pipeline. Example: `--param_list data.json` with contents `[ {'id': 'foo', 'input': 'foo.txt'}, {'id': 'bar', 'input': 'bar.txt'} ]`.
            |* A yaml blob can also be passed directly as a string. Example: `--param_list "[ {'id': 'foo', 'input': 'foo.txt'}, {'id': 'bar', 'input': 'bar.txt'} ]"`.
            |
            |When passing a csv, json or yaml file, relative path names are relativized to the location of the parameter file. No relativation is performed when `param_list` is a list of maps (as-is) or a yaml blob.'''.stripMargin(),
            'example': 'my_params.yaml',
            'multiple': false,
            'hidden': true
          ]
          // TODO: allow multiple: true in param_list?
          // TODO: allow to specify a --param_list_regex to filter the param_list?
          // TODO: allow to specify a --param_list_from_state to remap entries in the param_list?
        ]
      ]
    ]
  ]

  return processConfig(_mergeMap(config, localConfig))
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/config/generateHelp.nf'
def helpMessage(config) {
  if (params.containsKey("help") && params.help) {
    def mergedConfig = addGlobalArguments(config)
    def helpStr = _generateHelp(mergedConfig)
    println(helpStr)
    exit 0
  }
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/config/readConfig.nf'

def readConfig(file) {
  def config = readYaml(file ?: moduleDir.resolve("config.vsh.yaml"))
  processConfig(config)
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/functions/_resolveSiblingIfNotAbsolute.nf'
/**
  * Resolve a path relative to the current file.
  * 
  * @param str The path to resolve, as a String.
  * @param parentPath The path to resolve relative to, as a Path.
  *
  * @return The path that may have been resovled, as a Path.
  */
def _resolveSiblingIfNotAbsolute(str, parentPath) {
  if (str !instanceof String) {
    return str
  }
  if (!_stringIsAbsolutePath(str)) {
    return parentPath.resolveSibling(str)
  } else {
    return file(str, hidden: true)
  }
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/functions/collectTraces.nf'
class CustomTraceObserver implements nextflow.trace.TraceObserver {
  List traces

  CustomTraceObserver(List traces) {
    this.traces = traces
  }

  @Override
  void onProcessComplete(nextflow.processor.TaskHandler handler, nextflow.trace.TraceRecord trace) {
    def trace2 = trace.store.clone()
    trace2.script = null
    traces.add(trace2)
  }

  @Override
  void onProcessCached(nextflow.processor.TaskHandler handler, nextflow.trace.TraceRecord trace) {
    def trace2 = trace.store.clone()
    trace2.script = null
    traces.add(trace2)
  }
}

def collectTraces() {
  def traces = Collections.synchronizedList([])

  // add custom trace observer which stores traces in the traces object
  session.observers.add(new CustomTraceObserver(traces))

  traces
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/functions/getPublishDir.nf'
def getPublishDir() {
  return params.containsKey("publish_dir") ? params.publish_dir : 
    params.containsKey("publishDir") ? params.publishDir : 
    null
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/functions/niceView.nf'
/**
  * A view for printing the event of each channel as a YAML blob.
  * This is useful for debugging.
  */
def niceView() {
  workflow niceViewWf {
    take: input
    main:
      output = input
        | view{toYamlBlob(it)}
    emit: output
  }
  return niceViewWf
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/readwrite/readCsv.nf'

def readCsv(file_path) {
  def output = []
  def inputFile = file_path !instanceof Path ? file(file_path, hidden: true) : file_path

  // todo: allow escaped quotes in string
  // todo: allow single quotes?
  def splitRegex = java.util.regex.Pattern.compile(''',(?=(?:[^"]*"[^"]*")*[^"]*$)''')
  def removeQuote = java.util.regex.Pattern.compile('''"(.*)"''')

  def br = java.nio.file.Files.newBufferedReader(inputFile)

  def row = -1
  def header = null
  while (br.ready() && header == null) {
    def line = br.readLine()
    row++
    if (!line.startsWith("#")) {
      header = splitRegex.split(line, -1).collect{field ->
        m = removeQuote.matcher(field)
        m.find() ? m.replaceFirst('$1') : field
      }
    }
  }
  assert header != null: "CSV file should contain a header"

  while (br.ready()) {
    def line = br.readLine()
    row++
    if (line == null) {
      br.close()
      break
    }

    if (!line.startsWith("#")) {
      def predata = splitRegex.split(line, -1)
      def data = predata.collect{field ->
        if (field == "") {
          return null
        }
        def m = removeQuote.matcher(field)
        if (m.find()) {
          return m.replaceFirst('$1')
        } else {
          return field
        }
      }
      assert header.size() == data.size(): "Row $row should contain the same number as fields as the header"
      
      def dataMap = [header, data].transpose().collectEntries().findAll{it.value != null}
      output.add(dataMap)
    }
  }

  output
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/readwrite/readJson.nf'
def readJson(file_path) {
  def inputFile = file_path !instanceof Path ? file(file_path, hidden: true) : file_path
  def jsonSlurper = new groovy.json.JsonSlurper()
  jsonSlurper.parse(inputFile)
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/readwrite/readYaml.nf'
def readYaml(file_path) {
  def inputFile = file_path !instanceof Path ? file(file_path, hidden: true) : file_path
  def yamlSlurper = new org.yaml.snakeyaml.Yaml()
  yamlSlurper.load(inputFile)
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/states/findStates.nf'
def findStates(Map params, Map config) {
  def auto_config = deepClone(config)
  def auto_params = deepClone(params)

  auto_config = auto_config.clone()
  // override arguments
  auto_config.argument_groups = []
  auto_config.arguments = [
    [
      type: "string",
      name: "--id",
      description: "A dummy identifier",
      required: false
    ],
    [
      type: "file",
      name: "--input_states",
      example: "/path/to/input/directory/**/state.yaml",
      description: "Path to input directory containing the datasets to be integrated.",
      required: true,
      multiple: true,
      multiple_sep: ";"
    ],
    [
      type: "string",
      name: "--filter",
      example: "foo/.*/state.yaml",
      description: "Regex to filter state files by path.",
      required: false
    ],
    // to do: make this a yaml blob?
    [
      type: "string",
      name: "--rename_keys",
      example: ["newKey1:oldKey1", "newKey2:oldKey2"],
      description: "Rename keys in the detected input files. This is useful if the input files do not match the set of input arguments of the workflow.",
      required: false,
      multiple: true,
      multiple_sep: ";"
    ],
    [
      type: "string",
      name: "--settings",
      example: '{"output_dataset": "dataset.h5ad", "k": 10}',
      description: "Global arguments as a JSON glob to be passed to all components.",
      required: false
    ]
  ]
  if (!(auto_params.containsKey("id"))) {
    auto_params["id"] = "auto"
  }

  // run auto config through processConfig once more
  auto_config = processConfig(auto_config)

  workflow findStatesWf {
    helpMessage(auto_config)

    output_ch = 
      _channelFromParams(auto_params, auto_config)
        | flatMap { autoId, args ->

          def globalSettings = args.settings ? readYamlBlob(args.settings) : [:]

          // look for state files in input dir
          def stateFiles = args.input_states

          // filter state files by regex
          if (args.filter) {
            stateFiles = stateFiles.findAll{ stateFile ->
              def stateFileStr = stateFile.toString()
              def matcher = stateFileStr =~ args.filter
              matcher.matches()}
          }

          // read in states
          def states = stateFiles.collect { stateFile ->
            def state_ = readTaggedYaml(stateFile)
            [state_.id, state_]
          }

          // construct renameMap
          if (args.rename_keys) {
            def renameMap = args.rename_keys.collectEntries{renameString ->
              def split = renameString.split(":")
              assert split.size() == 2: "Argument 'rename_keys' should be of the form 'newKey:oldKey', or 'newKey:oldKey;newKey:oldKey' in case of multiple values"
              split
            }

            // rename keys in state, only let states through which have all keys
            // also add global settings
            states = states.collectMany{id, state ->
              def newState = [:]

              for (key in renameMap.keySet()) {
                def origKey = renameMap[key]
                if (!(state.containsKey(origKey))) {
                  return []
                }
                newState[key] = state[origKey]
              }

              [[id, globalSettings + newState]]
            }
          }

          states
        }
    emit:
    output_ch
  }

  return findStatesWf
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/states/joinStates.nf'
def joinStates(Closure apply_) {
  workflow joinStatesWf {
    take: input_ch
    main:
    output_ch = input_ch
      | toSortedList
      | filter{ it.size() > 0 }
      | map{ tups ->
        def ids = tups.collect{it[0]}
        def states = tups.collect{it[1]}
        apply_(ids, states)
      }

    emit: output_ch
  }
  return joinStatesWf
}
// helper file: 'src/main/resources/io/viash/runners/nextflow/states/publishFiles.nf'
def publishFiles(Map args) {
  def key_ = args.get("key")

  assert key_ != null : "publishFiles: key must be specified"
  
  workflow publishFilesWf {
    take: input_ch
    main:
      input_ch
        | map { tup ->
          def id_ = tup[0]
          def state_ = tup[1]

          // the input files and the target output filenames
          def inputoutputFilenames_ = collectInputOutputPaths(state_, id_ + "." + key_).transpose()
          def inputFiles_ = inputoutputFilenames_[0]
          def outputFilenames_ = inputoutputFilenames_[1]

          [id_, inputFiles_, outputFilenames_]
        }
        | publishFilesProc
    emit: input_ch
  }
  return publishFilesWf
}

process publishFilesProc {
  // todo: check publishpath?
  publishDir path: "${getPublishDir()}/", mode: "copy"
  tag "$id"
  input:
    tuple val(id), path(inputFiles, stageAs: "_inputfile?/*"), val(outputFiles)
  output:
    tuple val(id), path{outputFiles}
  script:
  def copyCommands = [
    inputFiles instanceof List ? inputFiles : [inputFiles],
    outputFiles instanceof List ? outputFiles : [outputFiles]
  ]
    .transpose()
    .collectMany{infile, outfile ->
      if (infile.toString() != outfile.toString()) {
        [
          "[ -d \"\$(dirname '${outfile.toString()}')\" ] || mkdir -p \"\$(dirname '${outfile.toString()}')\"",
          "cp -r '${infile.toString()}' '${outfile.toString()}'"
        ]
      } else {
        // no need to copy if infile is the same as outfile
        []
      }
    }
  """
  echo "Copying output files to destination folder"
  ${copyCommands.join("\n  ")}
  """
}


// this assumes that the state contains no other values other than those specified in the config
def publishFilesByConfig(Map args) {
  def config = args.get("config")
  assert config != null : "publishFilesByConfig: config must be specified"

  def key_ = args.get("key", config.name)
  assert key_ != null : "publishFilesByConfig: key must be specified"
  
  workflow publishFilesSimpleWf {
    take: input_ch
    main:
      input_ch
        | map { tup ->
          def id_ = tup[0]
          def state_ = tup[1] // e.g. [output: new File("myoutput.h5ad"), k: 10]
          def origState_ = tup[2] // e.g. [output: '$id.$key.foo.h5ad']


          // the processed state is a list of [key, value, inputPath, outputFilename] tuples, where
          //   - key is a String
          //   - value is any object that can be serialized to a Yaml (so a String/Integer/Long/Double/Boolean, a List, a Map, or a Path)
          //   - inputPath is a List[Path]
          //   - outputFilename is a List[String]
          //   - (inputPath, outputFilename) are the files that will be copied from src to dest (relative to the state.yaml)
          def processedState =
            config.allArguments
              .findAll { it.direction == "output" }
              .collectMany { par ->
                def plainName_ = par.plainName
                // if the state does not contain the key, it's an
                // optional argument for which the component did 
                // not generate any output OR multiple channels were emitted
                // and the output was just not added to using the channel
                // that is now being parsed
                if (!state_.containsKey(plainName_)) {
                  return []
                }
                def value = state_[plainName_]
                // if the parameter is not a file, it should be stored
                // in the state as-is, but is not something that needs 
                // to be copied from the source path to the dest path
                if (par.type != "file") {
                  return [[inputPath: [], outputFilename: []]]
                }
                // if the orig state does not contain this filename,
                // it's an optional argument for which the user specified
                // that it should not be returned as a state
                if (!origState_.containsKey(plainName_)) {
                  return []
                }
                def filenameTemplate = origState_[plainName_]
                // if the pararameter is multiple: true, fetch the template
                if (par.multiple && filenameTemplate instanceof List) {
                  filenameTemplate = filenameTemplate[0]
                }
                // instantiate the template
                def filename = filenameTemplate
                  .replaceAll('\\$id', id_)
                  .replaceAll('\\$\\{id\\}', id_)
                  .replaceAll('\\$key', key_)
                  .replaceAll('\\$\\{key\\}', key_)
                if (par.multiple) {
                  // if the parameter is multiple: true, the filename
                  // should contain a wildcard '*' that is replaced with
                  // the index of the file
                  assert filename.contains("*") : "Module '${key_}' id '${id_}': Multiple output files specified, but no wildcard '*' in the filename: ${filename}"
                  def outputPerFile = value.withIndex().collect{ val, ix ->
                    def filename_ix = filename.replace("*", ix.toString())
                    def inputPath = val instanceof File ? val.toPath() : val
                    [inputPath: inputPath, outputFilename: filename_ix]
                  }
                  def transposedOutputs = ["inputPath", "outputFilename"].collectEntries{ key -> 
                    [key, outputPerFile.collect{dic -> dic[key]}]
                  }
                  return [[key: plainName_] + transposedOutputs]
                } else {
                  def value_ = java.nio.file.Paths.get(filename)
                  def inputPath = value instanceof File ? value.toPath() : value
                  return [[inputPath: [inputPath], outputFilename: [filename]]]
                }
              }
          
          def inputPaths = processedState.collectMany{it.inputPath}
          def outputFilenames = processedState.collectMany{it.outputFilename}
          

          [id_, inputPaths, outputFilenames]
        }
        | publishFilesProc
    emit: input_ch
  }
  return publishFilesSimpleWf
}



def publishStates(Map args) {
  def key_ = args.get("key")
  def yamlTemplate_ = args.get("output_state", args.get("outputState", '$id.$key.state.yaml'))

  assert key_ != null : "publishStates: key must be specified"
  
  workflow publishStatesWf {
    take: input_ch
    main:
      input_ch
        | map { tup ->
          def id_ = tup[0]
          def state_ = tup[1]

          // the input files and the target output filenames
          def inputoutputFilenames_ = collectInputOutputPaths(state_, id_ + "." + key_).transpose()

          def yamlFilename = yamlTemplate_
            .replaceAll('\\$id', id_)
            .replaceAll('\\$\\{id\\}', id_)
            .replaceAll('\\$key', key_)
            .replaceAll('\\$\\{key\\}', key_)

            // TODO: do the pathnames in state_ match up with the outputFilenames_?

          // convert state to yaml blob
          def yamlBlob_ = toRelativeTaggedYamlBlob([id: id_] + state_, java.nio.file.Paths.get(yamlFilename))

          [id_, yamlBlob_, yamlFilename]
        }
        | publishStatesProc
    emit: input_ch
  }
  return publishStatesWf
}
process publishStatesProc {
  // todo: check publishpath?
  publishDir path: "${getPublishDir()}/", mode: "copy"
  tag "$id"
  input:
    tuple val(id), val(yamlBlob), val(yamlFile)
  output:
    tuple val(id), path{[yamlFile]}
  script:
  """
  mkdir -p "\$(dirname '${yamlFile}')"
  echo "Storing state as yaml"
  cat > '${yamlFile}' << HERE
${yamlBlob}
HERE
  """
}


// this assumes that the state contains no other values other than those specified in the config
def publishStatesByConfig(Map args) {
  def config = args.get("config")
  assert config != null : "publishStatesByConfig: config must be specified"

  def key_ = args.get("key", config.name)
  assert key_ != null : "publishStatesByConfig: key must be specified"
  
  workflow publishStatesSimpleWf {
    take: input_ch
    main:
      input_ch
        | map { tup ->
          def id_ = tup[0]
          def state_ = tup[1] // e.g. [output: new File("myoutput.h5ad"), k: 10]
          def origState_ = tup[2] // e.g. [output: '$id.$key.foo.h5ad']

          // TODO: allow overriding the state.yaml template
          // TODO TODO: if auto.publish == "state", add output_state as an argument
          def yamlTemplate = params.containsKey("output_state") ? params.output_state : '$id.$key.state.yaml'
          def yamlFilename = yamlTemplate
            .replaceAll('\\$id', id_)
            .replaceAll('\\$\\{id\\}', id_)
            .replaceAll('\\$key', key_)
            .replaceAll('\\$\\{key\\}', key_)
          def yamlDir = java.nio.file.Paths.get(yamlFilename).getParent()

          // the processed state is a list of [key, value] tuples, where
          //   - key is a String
          //   - value is any object that can be serialized to a Yaml (so a String/Integer/Long/Double/Boolean, a List, a Map, or a Path)
          //   - (key, value) are the tuples that will be saved to the state.yaml file
          def processedState =
            config.allArguments
              .findAll { it.direction == "output" }
              .collectMany { par ->
                def plainName_ = par.plainName
                // if the state does not contain the key, it's an
                // optional argument for which the component did 
                // not generate any output
                if (!state_.containsKey(plainName_)) {
                  return []
                }
                def value = state_[plainName_]
                // if the parameter is not a file, it should be stored
                // in the state as-is, but is not something that needs 
                // to be copied from the source path to the dest path
                if (par.type != "file") {
                  return [[key: plainName_, value: value]]
                }
                // if the orig state does not contain this filename,
                // it's an optional argument for which the user specified
                // that it should not be returned as a state
                if (!origState_.containsKey(plainName_)) {
                  return []
                }
                def filenameTemplate = origState_[plainName_]
                // if the pararameter is multiple: true, fetch the template
                if (par.multiple && filenameTemplate instanceof List) {
                  filenameTemplate = filenameTemplate[0]
                }
                // instantiate the template
                def filename = filenameTemplate
                  .replaceAll('\\$id', id_)
                  .replaceAll('\\$\\{id\\}', id_)
                  .replaceAll('\\$key', key_)
                  .replaceAll('\\$\\{key\\}', key_)
                if (par.multiple) {
                  // if the parameter is multiple: true, the filename
                  // should contain a wildcard '*' that is replaced with
                  // the index of the file
                  assert filename.contains("*") : "Module '${key_}' id '${id_}': Multiple output files specified, but no wildcard '*' in the filename: ${filename}"
                  def outputPerFile = value.withIndex().collect{ val, ix ->
                    def filename_ix = filename.replace("*", ix.toString())
                    def value_ = java.nio.file.Paths.get(filename_ix)
                    // if id contains a slash
                    if (yamlDir != null) {
                      value_ = yamlDir.relativize(value_)
                    }
                    return value_
                  }
                  return [["key": plainName_, "value": outputPerFile]]
                } else {
                  def value_ = java.nio.file.Paths.get(filename)
                  // if id contains a slash
                  if (yamlDir != null) {
                    value_ = yamlDir.relativize(value_)
                  }
                  def inputPath = value instanceof File ? value.toPath() : value
                  return [["key": plainName_, value: value_]]
                }
              }
              
          
          def updatedState_ = processedState.collectEntries{[it.key, it.value]}
          
          // convert state to yaml blob
          def yamlBlob_ = toTaggedYamlBlob([id: id_] + updatedState_)

          [id_, yamlBlob_, yamlFilename]
        }
        | publishStatesProc
    emit: input_ch
  }
  return publishStatesSimpleWf
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/states/setState.nf'
def setState(fun) {
  assert fun instanceof Closure || fun instanceof Map || fun instanceof List :
    "Error in setState: Expected process argument to be a Closure, a Map, or a List. Found: class ${fun.getClass()}"

  // if fun is a List, convert to map
  if (fun instanceof List) {
    // check whether fun is a list[string]
    assert fun.every{it instanceof CharSequence} : "Error in setState: argument is a List, but not all elements are Strings"
    fun = fun.collectEntries{[it, it]}
  }

  // if fun is a map, convert to closure
  if (fun instanceof Map) {
    // check whether fun is a map[string, string]
    assert fun.values().every{it instanceof CharSequence} : "Error in setState: argument is a Map, but not all values are Strings"
    assert fun.keySet().every{it instanceof CharSequence} : "Error in setState: argument is a Map, but not all keys are Strings"
    def funMap = fun.clone()
    // turn the map into a closure to be used later on
    fun = { id_, state_ ->
      assert state_ instanceof Map : "Error in setState: the state is not a Map"
      funMap.collectMany{newkey, origkey ->
        if (state_.containsKey(origkey)) {
          [[newkey, state_[origkey]]]
        } else {
          []
        }
      }.collectEntries()
    }
  }

  map { tup ->
    def id = tup[0]
    def state = tup[1]
    def unfilteredState = fun(id, state)
    def newState = unfilteredState.findAll{key, val -> val != null}
    [id, newState] + tup.drop(2)
  }
}

// processDirectives: thin wrapper delegating to plugin (uses params)
def processDirectives(Map drctv) {
  def containerRegistryOverride = params.containsKey("override_container_registry") ? params["override_container_registry"] : null
  return _processDirectivesWithOverride(drctv, containerRegistryOverride)
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/workflowFactory/processWorkflowArgs.nf'
def processWorkflowArgs(Map args, Map defaultWfArgs, Map meta) {
  // override defaults with args
  def workflowArgs = defaultWfArgs + args

  // check whether 'key' exists
  assert workflowArgs.containsKey("key") : "Error in module '${meta.config.name}': key is a required argument"

  // if 'key' is a closure, apply it to the original key
  if (workflowArgs["key"] instanceof Closure) {
    workflowArgs["key"] = workflowArgs["key"](meta.config.name)
  }
  def key = workflowArgs["key"]
  assert key instanceof CharSequence : "Expected process argument 'key' to be a String. Found: class ${key.getClass()}"
  assert key ==~ /^[a-zA-Z_]\w*$/ : "Error in module '$key': Expected process argument 'key' to consist of only letters, digits or underscores. Found: ${key}"

  // check for any unexpected keys
  def expectedKeys = ["key", "directives", "auto", "filter", "runIf", "fromState", "toState", "args", "debug"]
  def unexpectedKeys = workflowArgs.keySet() - expectedKeys
  assert unexpectedKeys.isEmpty() : "Error in module '$key': unexpected arguments to the '.run()' function: '${unexpectedKeys.join("', '")}'"

  // check whether directives exists and apply defaults
  assert workflowArgs.containsKey("directives") : "Error in module '$key': directives is a required argument"
  assert workflowArgs["directives"] instanceof Map : "Error in module '$key': Expected process argument 'directives' to be a Map. Found: class ${workflowArgs['directives'].getClass()}"
  workflowArgs["directives"] = processDirectives(defaultWfArgs.directives + workflowArgs["directives"])

  // check whether directives exists and apply defaults
  assert workflowArgs.containsKey("auto") : "Error in module '$key': auto is a required argument"
  assert workflowArgs["auto"] instanceof Map : "Error in module '$key': Expected process argument 'auto' to be a Map. Found: class ${workflowArgs['auto'].getClass()}"
  workflowArgs["auto"] = processAuto(defaultWfArgs.auto + workflowArgs["auto"])

  // auto define publish, if so desired
  if (workflowArgs.auto.publish == true && (workflowArgs.directives.publishDir != null ? workflowArgs.directives.publishDir : [:]).isEmpty()) {
    // can't assert at this level thanks to the no_publish profile
    // assert params.containsKey("publishDir") || params.containsKey("publish_dir") : 
    //   "Error in module '${workflowArgs['key']}': if auto.publish is true, params.publish_dir needs to be defined.\n" +
    //   "  Example: params.publish_dir = \"./output/\""
    def publishDir = getPublishDir()
    
    if (publishDir != null) {
      workflowArgs.directives.publishDir = [[ 
        path: publishDir, 
        saveAs: "{ it.startsWith('.') ? null : it }", // don't publish hidden files, by default
        mode: "copy"
      ]]
    }
  }

  // auto define transcript, if so desired
  if (workflowArgs.auto.transcript == true) {
    // can't assert at this level thanks to the no_publish profile
    // assert params.containsKey("transcriptsDir") || params.containsKey("transcripts_dir") || params.containsKey("publishDir") || params.containsKey("publish_dir") : 
    //   "Error in module '${workflowArgs['key']}': if auto.transcript is true, either params.transcripts_dir or params.publish_dir needs to be defined.\n" +
    //   "  Example: params.transcripts_dir = \"./transcripts/\""
    def transcriptsDir = 
      params.containsKey("transcripts_dir") ? params.transcripts_dir : 
      params.containsKey("transcriptsDir") ? params.transcriptsDir : 
      params.containsKey("publish_dir") ? params.publish_dir + "/_transcripts" :
      params.containsKey("publishDir") ? params.publishDir + "/_transcripts" : 
      null
    if (transcriptsDir != null) {
      def timestamp = nextflow.Nextflow.getSession().getWorkflowMetadata().start.format('yyyy-MM-dd_HH-mm-ss')
      def transcriptsPublishDir = [ 
        path: "$transcriptsDir/$timestamp/\${task.process.replaceAll(':', '-')}/\${id}/",
        saveAs: "{ it.startsWith('.') ? it.replaceAll('^.', '') : null }", 
        mode: "copy"
      ]
      def publishDirs = workflowArgs.directives.publishDir != null ? workflowArgs.directives.publishDir : null ? workflowArgs.directives.publishDir : []
      workflowArgs.directives.publishDir = publishDirs + transcriptsPublishDir
    }
  }

  // if this is a stubrun, remove certain directives?
  if (workflow.stubRun) {
    workflowArgs.directives.keySet().removeAll(["publishDir", "cpus", "memory", "label"])
  }

  for (nam in ["filter", "runIf"]) {
    if (workflowArgs.containsKey(nam) && workflowArgs[nam]) {
      assert workflowArgs[nam] instanceof Closure : "Error in module '$key': Expected process argument '$nam' to be null or a Closure. Found: class ${workflowArgs[nam].getClass()}"
    }
  }

  // check fromState
  workflowArgs["fromState"] = _processFromState(workflowArgs.get("fromState"), key, meta.config)

  // check toState
  workflowArgs["toState"] = _processToState(workflowArgs.get("toState"), key, meta.config)

  // return output
  return workflowArgs
}

// helper file: 'src/main/resources/io/viash/runners/nextflow/workflowFactory/workflowFactory.nf'
def _debug(workflowArgs, debugKey) {
  if (workflowArgs.debug) {
    view { "process '${workflowArgs.key}' $debugKey tuple: $it"  }
  } else {
    map { it }
  }
}
