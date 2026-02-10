package io.viash.viash_core.help

/**
 * Text formatting utilities.
 */
class TextUtils {

  /**
   * Word-wrap a text string to a maximum line length,
   * preserving paragraph breaks (newlines).
   * 
   * @param str The text to wrap.
   * @param maxLength The maximum line length.
   * @return A list of wrapped lines.
   */
  static List<String> paragraphWrap(String str, int maxLength) {
    def outLines = []
    str.split("\n").each { par ->
      def words = par.split("\\s").toList()

      def word = null
      def line = words.pop()
      while (!words.isEmpty()) {
        word = words.pop()
        if (line.length() + word.length() + 1 <= maxLength) {
          line = line + " " + word
        } else {
          outLines.add(line)
          line = word
        }
      }
      if (words.isEmpty()) {
        outLines.add(line)
      }
    }
    return outLines
  }
}
