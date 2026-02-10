package io.viash.viash_core.config

import io.viash.viash_core.util.CollectionUtils
import io.viash.viash_core.util.PathUtils
import io.viash.viash_core.util.NextflowHelper

/**
 * Functions for processing and validating Viash component configurations.
 */
class ConfigUtils {

  /**
   * Check if the given value is of the expected type. If not, an exception is thrown.
   *
   * @param stage The stage of the argument ("input" or "output")
   * @param par The parameter definition map
   * @param value The value to check
   * @param errorIdentifier The identifier to use in the error message
   * @param fileResolver Optional closure to resolve file paths from strings.
   *        If null, uses nextflow.Nextflow.file() when a session is available,
   *        or Paths.get() as a fallback (e.g. in unit tests).
   * @return The value, cast to the expected type if possible
   * @throws UnexpectedArgumentTypeException If the value is not of the expected type
   */
  static Object checkArgumentType(String stage, Map par, Object value, String errorIdentifier, Closure fileResolver = null) {
    def expectedClass = null
    def foundClass = null

    if (!par.required && value == null) {
      expectedClass = null
    } else if (par.multiple) {
      if (!(value instanceof Collection)) {
        value = [value]
      }

      // split strings
      value = value.collectMany { val ->
        if (val instanceof String) {
          val.split(par.multiple_sep).collect()
        } else {
          [val]
        }
      }

      // process globs for input files
      if (par.type == "file" && par.direction == "input") {
        value = value.collect { it instanceof String ? _resolveFile(it, fileResolver) : it }.flatten()
      }

      // check types of elements in list
      try {
        value = value.collect { listVal ->
          checkArgumentType(stage, par + [multiple: false], listVal, errorIdentifier, fileResolver)
        }
      } catch (UnexpectedArgumentTypeException e) {
        expectedClass = "List[${e.expectedClass}]"
        foundClass = "List[${e.foundClass}]"
      }
    } else if (par.type == "string") {
      if (value instanceof GString) {
        value = value as String
      }
      expectedClass = value instanceof String ? null : "String"
    } else if (par.type == "integer") {
      if (!(value instanceof Integer)) {
        try {
          value = value as Integer
        } catch (NumberFormatException e) {
          expectedClass = "Integer"
        }
      }
    } else if (par.type == "long") {
      if (!(value instanceof Long)) {
        try {
          value = value as Long
        } catch (NumberFormatException e) {
          expectedClass = "Long"
        }
      }
    } else if (par.type == "double") {
      if (!(value instanceof Double)) {
        try {
          value = value as Double
        } catch (NumberFormatException e) {
          expectedClass = "Double"
        }
      }
    } else if (par.type == "float") {
      if (!(value instanceof Float)) {
        try {
          value = value as Float
        } catch (NumberFormatException e) {
          expectedClass = "Float"
        }
      }
    } else if (par.type == "boolean" || par.type == "boolean_true" || par.type == "boolean_false") {
      if (!(value instanceof Boolean)) {
        try {
          value = value as Boolean
        } catch (Exception e) {
          expectedClass = "Boolean"
        }
      }
    } else if (par.type == "file" && (par.direction == "input" || stage == "output")) {
      if (value instanceof String) {
        value = _resolveFile(value, fileResolver)
      }
      if (value instanceof File) {
        value = value.toPath()
      }
      expectedClass = value instanceof java.nio.file.Path ? null : "Path"
    } else if (par.type == "file" && stage == "input" && par.direction == "output") {
      if (!(value instanceof String)) {
        try {
          value = value as String
        } catch (Exception e) {
          expectedClass = "String"
        }
      }
    } else {
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

  /**
   * Resolve a file path string via PathUtils.resolveFile.
   */
  private static Object _resolveFile(String path, Closure fileResolver) {
    return PathUtils.resolveFile(path, fileResolver)
  }

  /**
   * Validate input values against the config.
   * Automatically detects stub run from the Nextflow session.
   *
   * @param inputs Map of input argument values
   * @param config The processed component config
   * @param id The event ID
   * @param key The module key/name
   * @param stubRun Optional boolean to override stub run detection (for tests). If null, reads from Nextflow session.
   * @param fileResolver Optional file resolver closure (for tests)
   * @return The validated (and possibly cast) input values
   */
  static Map processInputValues(Map inputs, Map config, String id, String key, Boolean stubRun = null, Closure fileResolver = null) {
    boolean isStubRun = (stubRun != null) ? stubRun : NextflowHelper.isStubRun()
    if (!isStubRun) {
      config.allArguments.each { arg ->
        if (arg.required && arg.direction == "input") {
          assert inputs.containsKey(arg.plainName) && inputs.get(arg.plainName) != null :
            "Error in module '${key}' id '${id}': required input argument '${arg.plainName}' is missing"
        }
      }

      inputs = inputs.collectEntries { name, value ->
        def par = config.allArguments.find { it.plainName == name && (it.direction == "input" || it.type == "file") }
        assert par != null : "Error in module '${key}' id '${id}': '${name}' is not a valid input argument"

        value = checkArgumentType("input", par, value, "in module '$key' id '$id'", fileResolver)

        [name, value]
      }
    }
    return inputs
  }

  /**
   * Validate output argument values against the config.
   * Automatically detects stub run from the Nextflow session.
   *
   * @param stubRun Optional boolean to override stub run detection (for tests). If null, reads from Nextflow session.
   * @param fileResolver Optional file resolver closure (for tests)
   */
  static Map checkValidOutputArgument(Map outputs, Map config, String id, String key, Boolean stubRun = null, Closure fileResolver = null) {
    boolean isStubRun = (stubRun != null) ? stubRun : NextflowHelper.isStubRun()
    if (!isStubRun) {
      outputs = outputs.collectEntries { name, value ->
        def par = config.allArguments.find { it.plainName == name && it.direction == "output" }
        assert par != null : "Error in module '${key}' id '${id}': '${name}' is not a valid output argument"

        value = checkArgumentType("output", par, value, "in module '$key' id '$id'", fileResolver)

        [name, value]
      }
    }
    return outputs
  }

  /**
   * Assert all required output arguments are present.
   * Automatically detects stub run from the Nextflow session.
   *
   * @param stubRun Optional boolean to override stub run detection (for tests). If null, reads from Nextflow session.
   */
  static void checkAllRequiredOutputsPresent(Map outputs, Map config, String id, String key, Boolean stubRun = null) {
    boolean isStubRun = (stubRun != null) ? stubRun : NextflowHelper.isStubRun()
    if (!isStubRun) {
      config.allArguments.each { arg ->
        if (arg.direction == "output" && arg.required) {
          assert outputs.containsKey(arg.plainName) && outputs.get(arg.plainName) != null :
            "Error in module '${key}' id '${id}': required output argument '${arg.plainName}' is missing"
        }
      }
    }
  }

  /**
   * Add global arguments (--publish_dir, --param_list) to a config.
   * Pure logic — no NF dependencies.
   */
  static Map addGlobalArguments(Map config) {
    def localConfig = [
      "argument_groups": [
        [
          "name": "Nextflow input-output arguments",
          "description": "Input/output parameters for Nextflow itself. Please note that both publishDir and publish_dir are supported but at least one has to be configured.",
          "arguments": [
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
              'description': 'Allows inputting multiple parameter sets to initialise a Nextflow channel. ' +
                'A param_list can either be a list of maps, a csv file, a json file, a yaml file, or simply a yaml blob.\n\n' +
                '* A list of maps (as-is) where the keys of each map corresponds to the arguments of the pipeline.\n' +
                '* A csv file should have column names which correspond to the different arguments of this pipeline.\n' +
                '* A json or a yaml file should be a list of maps, each of which has keys corresponding to the arguments of the pipeline.\n' +
                '* A yaml blob can also be passed directly as a string.',
              'example': 'my_params.yaml',
              'multiple': false,
              'hidden': true
            ]
          ]
        ]
      ]
    ]

    return processConfig(CollectionUtils.mergeMap(config, localConfig))
  }

  /**
   * Set defaults on an argument definition.
   * Adds defaults for multiple, required, direction, multiple_sep, plainName,
   * must_exist, create_parent, and auto-generates output file defaults.
   *
   * @param arg The argument map.
   * @return The argument map with defaults applied.
   */
  static Map processArgument(Map arg) {
    arg.multiple = arg.multiple != null ? arg.multiple : false
    arg.required = arg.required != null ? arg.required : false
    arg.direction = arg.direction != null ? arg.direction : "input"
    arg.multiple_sep = arg.multiple_sep != null ? arg.multiple_sep : ";"
    arg.plainName = arg.name.replaceAll("^-*", "")

    if (arg.type == "file") {
      arg.must_exist = arg.must_exist != null ? arg.must_exist : true
      arg.create_parent = arg.create_parent != null ? arg.create_parent : true
    }

    // add default values to output files which haven't already got a default
    if (arg.type == "file" && arg.direction == "output" && arg.default == null) {
      def mult = arg.multiple ? "_*" : ""
      def extSearch = ""
      if (arg.default != null) {
        extSearch = arg.default
      } else if (arg.example != null) {
        extSearch = arg.example
      }
      if (extSearch instanceof List) {
        extSearch = extSearch[0]
      }
      def extSearchResult = extSearch.find(/\.[^.]+$/)
      def ext = extSearchResult != null ? extSearchResult : ""
      arg.default = "\$id.\$key.${arg.plainName}${mult}${ext}"
      if (arg.multiple) {
        arg.default = [arg.default]
      }
    }

    if (!arg.multiple) {
      if (arg.default != null && arg.default instanceof List) {
        arg.default = arg.default[0]
      }
      if (arg.example != null && arg.example instanceof List) {
        arg.example = arg.example[0]
      }
    }

    if (arg.type == "boolean_true") {
      arg.default = false
    }
    if (arg.type == "boolean_false") {
      arg.default = true
    }

    arg
  }

  /**
   * Process a raw config map by applying defaults to all arguments.
   * Creates combined argument lists and argument groups.
   *
   * @param config The raw configuration map.
   * @return The processed configuration map.
   */
  static Map processConfig(Map config) {
    // set defaults for arguments
    config.arguments =
      (config.arguments ?: []).collect { processArgument(it) }

    // set defaults for argument_group arguments
    config.argument_groups =
      (config.argument_groups ?: []).collect { grp ->
        grp.arguments = (grp.arguments ?: []).collect { processArgument(it) }
        grp
      }

    // create combined arguments list
    config.allArguments =
      config.arguments +
      config.argument_groups.collectMany { it.arguments }

    // add missing argument groups (based on Functionality::allArgumentGroups())
    def argGroups = config.argument_groups
    if (argGroups.any { it.name.toLowerCase() == "arguments" }) {
      argGroups = argGroups.collect { grp ->
        if (grp.name.toLowerCase() == "arguments") {
          grp = grp + [
            arguments: grp.arguments + config.arguments
          ]
        }
        grp
      }
    } else {
      argGroups = argGroups + [
        name: "Arguments",
        arguments: config.arguments
      ]
    }
    config.allArgumentGroups = argGroups

    config
  }

  /**
   * Validate and normalize auto settings map.
   *
   * @param auto The auto settings map.
   * @return The validated auto settings with only expected keys.
   */
  static Map processAuto(Map auto) {
    // remove null values
    auto = auto.findAll { k, v -> v != null }

    // check for unexpected keys
    def expectedKeys = ["simplifyInput", "simplifyOutput", "transcript", "publish"]
    def unexpectedKeys = auto.keySet() - expectedKeys
    assert unexpectedKeys.isEmpty() : "unexpected keys in auto: '${unexpectedKeys.join("', '")}'"

    // check auto.simplifyInput
    assert auto.simplifyInput instanceof Boolean : "auto.simplifyInput must be a boolean"

    // check auto.simplifyOutput
    assert auto.simplifyOutput instanceof Boolean : "auto.simplifyOutput must be a boolean"

    // check auto.transcript
    assert auto.transcript instanceof Boolean : "auto.transcript must be a boolean"

    // check auto.publish
    assert auto.publish instanceof Boolean || auto.publish == "state" : "auto.publish must be a boolean or 'state'"

    return auto.subMap(expectedKeys)
  }

  /**
   * Validate that a map contains only expected keys and all required keys.
   *
   * @param map The map to validate.
   * @param expectedKeys The list of allowed keys.
   * @param requiredKeys The list of required keys.
   * @param mapName A name for error messages.
   */
  static void assertMapKeys(Map map, List expectedKeys, List requiredKeys, String mapName) {
    assert map instanceof Map : "Expected argument '$mapName' to be a Map. Found: class ${map.getClass()}"
    map.forEach { key, val ->
      assert key in expectedKeys : "Unexpected key '$key' in ${mapName ? mapName + " " : ""}map"
    }
    requiredKeys.forEach { requiredKey ->
      assert map.containsKey(requiredKey) : "Missing required key '$requiredKey' in ${mapName ? mapName + " " : ""}map"
    }
  }
}
