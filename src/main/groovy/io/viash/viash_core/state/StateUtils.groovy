package io.viash.viash_core.state

/**
 * Functions for processing fromState and toState arguments
 * used in workflow factories.
 * Pure Groovy — no Nextflow dependencies.
 */
class StateUtils {

  /**
   * Standardize the fromState parameter.
   * Converts List[String] → Map[String,String] → Closure.
   *
   * @param fromState A Closure, Map, List, or null.
   * @param key_ The module key for error messages.
   * @param config_ The processed config map.
   * @return A Closure that extracts data from state, or null.
   */
  static Object processFromState(Object fromState, String key_, Map config_) {
    assert fromState == null || fromState instanceof Closure || fromState instanceof Map || fromState instanceof List :
      "Error in module '$key_': Expected process argument 'fromState' to be null, a Closure, a Map, or a List. Found: class ${fromState.getClass()}"
    if (fromState == null) {
      return null
    }

    // if fromState is a List, convert to map
    if (fromState instanceof List) {
      assert fromState.every { it instanceof CharSequence } : "Error in module '$key_': fromState is a List, but not all elements are Strings"
      fromState = fromState.collectEntries { [it, it] }
    }

    // if fromState is a map, convert to closure
    if (fromState instanceof Map) {
      assert fromState.values().every { it instanceof CharSequence } : "Error in module '$key_': fromState is a Map, but not all values are Strings"
      assert fromState.keySet().every { it instanceof CharSequence } : "Error in module '$key_': fromState is a Map, but not all keys are Strings"
      def fromStateMap = fromState.clone()
      def allArgumentNames = config_.allArguments.collect { it.plainName }
      def requiredInputNames = config_.allArguments.findAll { it.required && it.direction == "Input" }.collect { it.plainName }
      fromState = { it ->
        def state = it[1]
        assert state instanceof Map : "Error in module '$key_': the state is not a Map"
        def data = fromStateMap.collectMany { newkey, origkey ->
          if (!allArgumentNames.contains(newkey)) {
            throw new Exception("Error processing fromState for '$key_': invalid argument '$newkey'")
          }
          if (state.containsKey(origkey)) {
            [[newkey, state[origkey]]]
          } else if (!requiredInputNames.contains(origkey)) {
            []
          } else {
            throw new Exception("Error in module '$key_': fromState key '$origkey' not found in current state")
          }
        }.collectEntries()
        data
      }
    }

    return fromState
  }

  /**
   * Standardize the toState parameter.
   * Converts List[String] → Map[String,String] → Closure.
   *
   * @param toState A Closure, Map, List, or null.
   * @param key_ The module key for error messages.
   * @param config_ The processed config map.
   * @return A Closure that updates state from output.
   */
  static Object processToState(Object toState, String key_, Map config_) {
    if (toState == null) {
      toState = { tup -> tup[1] }
    }

    assert toState instanceof Closure || toState instanceof Map || toState instanceof List :
      "Error in module '$key_': Expected process argument 'toState' to be a Closure, a Map, or a List. Found: class ${toState.getClass()}"

    // if toState is a List, convert to map
    if (toState instanceof List) {
      assert toState.every { it instanceof CharSequence } : "Error in module '$key_': toState is a List, but not all elements are Strings"
      toState = toState.collectEntries { [it, it] }
    }

    // if toState is a map, convert to closure
    if (toState instanceof Map) {
      assert toState.values().every { it instanceof CharSequence } : "Error in module '$key_': toState is a Map, but not all values are Strings"
      assert toState.keySet().every { it instanceof CharSequence } : "Error in module '$key_': toState is a Map, but not all keys are Strings"
      def toStateMap = toState.clone()
      def allArgumentNames = config_.allArguments.collect { it.plainName }
      def requiredOutputNames = config_.allArguments.findAll { it.required && it.direction == "Output" }.collect { it.plainName }
      toState = { it ->
        def output = it[1]
        def state = it[2]
        assert output instanceof Map : "Error in module '$key_': the output is not a Map"
        assert state instanceof Map : "Error in module '$key_': the state is not a Map"
        def extraEntries = toStateMap.collectMany { newkey, origkey ->
          if (!allArgumentNames.contains(origkey)) {
            throw new Exception("Error processing toState for '$key_': invalid argument '$origkey'")
          }
          if (output.containsKey(origkey)) {
            [[newkey, output[origkey]]]
          } else if (!requiredOutputNames.contains(origkey)) {
            []
          } else {
            throw new Exception("Error in module '$key_': toState key '$origkey' not found in current output")
          }
        }.collectEntries()
        state + extraEntries
      }
    }

    return toState
  }

  /**
   * Check if the ids are unique across parameter sets.
   *
   * @param parameterSets a list of [id, params] tuples.
   * @throws AssertionError if duplicate ids are found.
   */
  static void checkUniqueIds(List parameterSets) {
    def ppIds = parameterSets.collect { it[0] }
    assert ppIds.size() == ppIds.unique().size() : "All argument sets should have unique ids. Detected ids: $ppIds"
  }

  /**
   * Split parameters for arguments that accept multiple values using their separator.
   *
   * @param parValues A Map of parameter values.
   * @param config The Viash configuration map.
   * @return A Map with split parameter values.
   */
  static Map splitParams(Map parValues, Map config) {
    def parsedParamValues = parValues.collectEntries { parName, parValue ->
      def parameterSettings = config.allArguments.find { it.plainName == parName }

      if (!parameterSettings) {
        return [parName, parValue]
      }
      if (parameterSettings.multiple) {
        if (parValue instanceof Collection) {
          parValue = parValue.collect { it instanceof String ? it.split(parameterSettings.multiple_sep) : it }
        } else if (parValue instanceof String) {
          parValue = parValue.split(parameterSettings.multiple_sep)
        } else if (parValue == null) {
          parValue = []
        } else {
          parValue = [parValue]
        }
        parValue = parValue.flatten()
      }
      if (!parameterSettings.multiple && parValue instanceof Collection) {
        assert parValue.size() == 1 :
          "Error: argument ${parName} has too many values.\n" +
          "  Expected amount: 1. Found: ${parValue.size()}"
        parValue = parValue[0]
      }
      [parName, parValue]
    }
    return parsedParamValues
  }

  /**
   * Guess the format of a param_list based on file extension.
   *
   * @param paramList The param_list value.
   * @return A format string: "asis", "csv", "json", "yaml", or "yaml_blob".
   */
  static String paramListGuessFormat(Object paramList) {
    if (!(paramList instanceof String)) {
      "asis"
    } else if (paramList.endsWith(".csv")) {
      "csv"
    } else if (paramList.endsWith(".json") || paramList.endsWith(".jsn")) {
      "json"
    } else if (paramList.endsWith(".yaml") || paramList.endsWith(".yml")) {
      "yaml"
    } else {
      "yaml_blob"
    }
  }
}
