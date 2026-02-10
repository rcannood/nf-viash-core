package io.viash.viash_core.io

import java.nio.file.Path
import org.yaml.snakeyaml.Yaml
import org.yaml.snakeyaml.LoaderOptions
import org.yaml.snakeyaml.DumperOptions
import groovy.json.JsonSlurper
import groovy.json.JsonOutput

import io.viash.viash_core.util.CollectionUtils

/**
 * Custom YAML constructor that handles !file tags,
 * resolving them relative to a root path.
 */
class CustomConstructor extends org.yaml.snakeyaml.constructor.Constructor {
  Path root

  class ConstructPath extends org.yaml.snakeyaml.constructor.AbstractConstruct {
    public Object construct(org.yaml.snakeyaml.nodes.Node node) {
      String filename = (String) constructScalar(node)
      if (root != null) {
        return root.resolve(filename)
      }
      return java.nio.file.Paths.get(filename)
    }
  }

  CustomConstructor(LoaderOptions options, Path root) {
    super(options)
    this.root = root
    this.yamlConstructors.put(new org.yaml.snakeyaml.nodes.Tag("!file"), new ConstructPath())
  }
}

/**
 * Custom YAML representer that serializes File/Path objects
 * with the !file tag, optionally using relative paths.
 */
class CustomRepresenter extends org.yaml.snakeyaml.representer.Representer {
  Path relativizer

  class RepresentPath implements org.yaml.snakeyaml.representer.Represent {
    public String getFileName(Object obj) {
      if (obj instanceof File) {
        obj = ((File) obj).toPath()
      }
      if (!(obj instanceof Path)) {
        throw new IllegalArgumentException("Object: " + obj + " is not a Path or File")
      }
      def path = (Path) obj

      if (relativizer != null) {
        return relativizer.relativize(path).toString()
      } else {
        return path.toString()
      }
    }

    public org.yaml.snakeyaml.nodes.Node representData(Object data) {
      String filename = getFileName(data)
      def tag = new org.yaml.snakeyaml.nodes.Tag("!file")
      return representScalar(tag, filename)
    }
  }

  CustomRepresenter(DumperOptions options, Path relativizer) {
    super(options)
    this.relativizer = relativizer
    this.representers.put(Path, new RepresentPath())
    this.representers.put(File, new RepresentPath())
    // Note: sun.nio.fs.UnixPath registration is handled dynamically below
    try {
      def unixPathClass = Class.forName("sun.nio.fs.UnixPath")
      this.representers.put(unixPathClass, new RepresentPath())
    } catch (ClassNotFoundException e) {
      // Not on a Unix system, skip
    }
  }
}

/**
 * Serialization utilities for reading and writing JSON, YAML, and CSV.
 * These are pure Groovy — no Nextflow dependencies.
 *
 * Note: readJson, readYaml, readCsv that accept a string file path and use
 * Nextflow's file() global are NOT included here. Those remain in VDSL3Helper.nf.
 * Only the blob/Path-based variants are included.
 */
class SerializationUtils {

  /**
   * Parse a JSON string into a Groovy object.
   */
  static Object readJsonBlob(String str) {
    def jsonSlurper = new JsonSlurper()
    jsonSlurper.parseText(str)
  }

  /**
   * Read and parse a JSON file from a Path.
   */
  static Object readJsonFromPath(Path path) {
    def jsonSlurper = new JsonSlurper()
    jsonSlurper.parse(path)
  }

  /**
   * Parse a YAML string into a Groovy object.
   */
  static Object readYamlBlob(String str) {
    def yamlSlurper = new Yaml()
    yamlSlurper.load(str)
  }

  /**
   * Read and parse a YAML file from a Path.
   */
  static Object readYamlFromPath(Path path) {
    def yamlSlurper = new Yaml()
    yamlSlurper.load(path.text)
  }

  /**
   * Read and parse a YAML file with !file tag support.
   *
   * @param path The path to the YAML file.
   * @return The parsed YAML object, with !file tags resolved to Paths.
   */
  static Object readTaggedYaml(Path path) {
    def options = new LoaderOptions()
    def constructor = new CustomConstructor(options, path.getParent())
    def yaml = new Yaml(constructor)
    return yaml.load(path.text)
  }

  /**
   * Read a CSV file and return a list of maps (one per row).
   *
   * @param inputFile The Path to the CSV file.
   * @return A List of Maps representing each row.
   */
  static List<Map<String, String>> readCsvFromPath(Path inputFile) {
    def output = []

    def splitRegex = java.util.regex.Pattern.compile(''',(?=(?:[^"]*"[^"]*")*[^"]*$)''')
    def removeQuote = java.util.regex.Pattern.compile('''"(.*)"''')

    def br = java.nio.file.Files.newBufferedReader(inputFile)

    def row = -1
    def header = null
    while (br.ready() && header == null) {
      def line = br.readLine()
      row++
      if (!line.startsWith("#")) {
        header = splitRegex.split(line, -1).collect { field ->
          def m = removeQuote.matcher(field)
          m.find() ? m.replaceFirst('$1') : field
        }
      }
    }
    assert header != null : "CSV file should contain a header"

    while (br.ready()) {
      def line = br.readLine()
      row++
      if (line == null) {
        br.close()
        break
      }

      if (!line.startsWith("#")) {
        def predata = splitRegex.split(line, -1)
        def data = predata.collect { field ->
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
        assert header.size() == data.size() : "Row $row should contain the same number as fields as the header"

        def dataMap = [header, data].transpose().collectEntries().findAll { it.value != null }
        output.add(dataMap)
      }
    }

    output
  }

  /**
   * Serialize data to a JSON string.
   */
  static String toJsonBlob(Object data) {
    return JsonOutput.toJson(data)
  }

  /**
   * Serialize data to a YAML string.
   * Path objects are converted to strings.
   */
  static String toYamlBlob(Object data) {
    def options = new DumperOptions()
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    options.setPrettyFlow(true)
    def yaml = new Yaml(options)
    def cleanData = CollectionUtils.iterateMap(data, { it instanceof Path ? it.toString() : it })
    return yaml.dump(cleanData)
  }

  /**
   * Serialize data to a YAML string with !file tags for Path/File values.
   */
  static String toTaggedYamlBlob(Object data) {
    return toRelativeTaggedYamlBlob(data, null)
  }

  /**
   * Serialize data to a YAML string with !file tags, using paths relative to a base.
   *
   * @param data The data to serialize.
   * @param relativizer The base path to relativize against (or null for absolute paths).
   * @return The YAML string.
   */
  static String toRelativeTaggedYamlBlob(Object data, Path relativizer) {
    def options = new DumperOptions()
    options.setDefaultFlowStyle(DumperOptions.FlowStyle.BLOCK)
    def representer = new CustomRepresenter(options, relativizer)
    def yaml = new Yaml(representer, options)
    return yaml.dump(data)
  }

  /**
   * Write data to a JSON file.
   */
  static void writeJson(Object data, File file) {
    assert data : "writeJson: data should not be null"
    assert file : "writeJson: file should not be null"
    file.write(toJsonBlob(data))
  }

  /**
   * Write data to a YAML file.
   */
  static void writeYaml(Object data, File file) {
    assert data : "writeYaml: data should not be null"
    assert file : "writeYaml: file should not be null"
    file.write(toYamlBlob(data))
  }
}
