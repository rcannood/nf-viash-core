package io.viash.viash_core.config

/**
 * Functions for processing and validating Viash component configurations.
 * These are pure Groovy — no Nextflow dependencies.
 */
class ConfigUtils {

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
