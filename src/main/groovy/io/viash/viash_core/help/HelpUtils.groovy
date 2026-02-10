package io.viash.viash_core.help

/**
 * Functions for generating help text for Viash components.
 * Pure Groovy — no Nextflow dependencies.
 */
class HelpUtils {

  /**
   * Generate help text for a single argument.
   *
   * @param param The argument definition map.
   * @return Formatted help text for the argument.
   */
  static String generateArgumentHelp(Map param) {
    def unnamedProps = [
      ["required parameter", param.required],
      ["multiple values allowed", param.multiple],
      ["output", param.direction?.toLowerCase() == "output"],
      ["file must exist", param.type == "file" && param.must_exist]
    ].findAll { it[1] }.collect { it[0] }

    def dflt = null
    if (param.default != null) {
      if (param.default instanceof List) {
        dflt = param.default.join(param.multiple_sep != null ? param.multiple_sep : ", ")
      } else {
        dflt = param.default.toString()
      }
    }
    def example = null
    if (param.example != null) {
      if (param.example instanceof List) {
        example = param.example.join(param.multiple_sep != null ? param.multiple_sep : ", ")
      } else {
        example = param.example.toString()
      }
    }
    def min = param.min?.toString()
    def max = param.max?.toString()

    def escapeChoice = { choice ->
      def s1 = choice.replaceAll("\\n", "\\\\n")
      def s2 = s1.replaceAll("\"", """\\\"""")
      s2.contains(",") || s2 != choice ? "\"" + s2 + "\"" : s2
    }
    def choices = param.choices == null ?
      null :
      "[ " + param.choices.collect { escapeChoice(it.toString()) }.join(", ") + " ]"

    def namedPropsStr = [
      ["type", ([param.type] + unnamedProps).join(", ")],
      ["default", dflt],
      ["example", example],
      ["choices", choices],
      ["min", min],
      ["max", max]
    ]
      .findAll { it[1] }
      .collect { "\n        " + it[0] + ": " + it[1].replaceAll("\n", "\\n") }
      .join("")

    def descStr = param.description == null ?
      "" :
      TextUtils.paragraphWrap("\n" + param.description.trim(), 80 - 8).join("\n        ")

    "\n    --" + param.plainName +
      namedPropsStr +
      descStr
  }

  /**
   * Generate full help text for a component.
   *
   * @param config The processed component configuration.
   * @return The formatted help text string.
   */
  static String generateHelp(Map config) {
    def fun = config

    // PART 1: NAME AND VERSION
    def nameStr = fun.name +
      (fun.version == null ? "" : " " + fun.version)

    // PART 2: DESCRIPTION
    def descrStr = fun.description == null ?
      "" :
      "\n\n" + TextUtils.paragraphWrap(fun.description.trim(), 80).join("\n")

    // PART 3: Usage
    def usageStr = fun.usage == null ?
      "" :
      "\n\nUsage:\n" + fun.usage.trim()

    // PART 4: Options
    def argGroupStrs = fun.allArgumentGroups.collect { argGroup ->
      def name = argGroup.name
      def descriptionStr = argGroup.description == null ?
        "" :
        "\n    " + TextUtils.paragraphWrap(argGroup.description.trim(), 80 - 4).join("\n    ") + "\n"
      def arguments = argGroup.arguments.collect { arg ->
        arg instanceof String ? fun.allArguments.find { it.plainName == arg } : arg
      }.findAll { it != null }
      def argumentStrs = arguments.collect { param -> generateArgumentHelp(param) }

      "\n\n$name:" +
        descriptionStr +
        argumentStrs.join("\n")
    }

    // FINAL: combine
    def out = nameStr +
      descrStr +
      usageStr +
      argGroupStrs.join("")

    return out
  }
}
