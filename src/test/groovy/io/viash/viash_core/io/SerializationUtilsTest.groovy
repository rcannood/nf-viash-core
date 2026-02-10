package io.viash.viash_core.io

import spock.lang.Specification
import java.nio.file.Files
import java.nio.file.Path

class SerializationUtilsTest extends Specification {

    // ---- JSON ----

    def 'readJsonBlob should parse JSON string' () {
        when:
        def result = SerializationUtils.readJsonBlob('{"name": "test", "value": 42}')
        
        then:
        result.name == "test"
        result.value == 42
    }

    def 'readJsonBlob should parse JSON array' () {
        when:
        def result = SerializationUtils.readJsonBlob('[1, 2, 3]')
        
        then:
        result == [1, 2, 3]
    }

    def 'toJsonBlob should serialize map' () {
        when:
        def result = SerializationUtils.toJsonBlob([name: "test", value: 42])
        
        then:
        result.contains('"name"')
        result.contains('"test"')
        result.contains('"value"')
        result.contains('42')
    }

    def 'readJsonFromPath should read JSON file' () {
        given:
        def tempFile = Files.createTempFile("test", ".json")
        tempFile.text = '{"key": "value"}'
        
        when:
        def result = SerializationUtils.readJsonFromPath(tempFile)
        
        then:
        result.key == "value"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    // ---- YAML ----

    def 'readYamlBlob should parse YAML string' () {
        when:
        def result = SerializationUtils.readYamlBlob("name: test\nvalue: 42")
        
        then:
        result.name == "test"
        result.value == 42
    }

    def 'readYamlFromPath should read YAML file' () {
        given:
        def tempFile = Files.createTempFile("test", ".yaml")
        tempFile.text = "key: value\nlist:\n  - a\n  - b"
        
        when:
        def result = SerializationUtils.readYamlFromPath(tempFile)
        
        then:
        result.key == "value"
        result.list == ["a", "b"]
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    def 'toYamlBlob should serialize map' () {
        when:
        def result = SerializationUtils.toYamlBlob([name: "test", items: [1, 2]])
        
        then:
        result.contains("name: test")
        result.contains("items:")
    }

    def 'readYamlBlob should parse YAML list' () {
        when:
        def result = SerializationUtils.readYamlBlob("- a\n- b\n- c")
        
        then:
        result == ["a", "b", "c"]
    }

    // ---- Tagged YAML ----

    def 'readTaggedYaml should handle file tags' () {
        given:
        def tempDir = Files.createTempDirectory("test")
        def yamlFile = tempDir.resolve("state.yaml")
        yamlFile.text = "output: !file output.h5ad\nname: test"
        
        when:
        def result = SerializationUtils.readTaggedYaml(yamlFile)
        
        then:
        result.name == "test"
        result.output instanceof Path
        result.output.toString().endsWith("output.h5ad")
        
        cleanup:
        Files.deleteIfExists(yamlFile)
        Files.deleteIfExists(tempDir)
    }

    def 'toTaggedYamlBlob should serialize with file tags' () {
        given:
        def path = java.nio.file.Paths.get("/tmp/output.h5ad")
        def data = [output: path, name: "test"]
        
        when:
        def result = SerializationUtils.toTaggedYamlBlob(data)
        
        then:
        result.contains("!file")
        result.contains("output.h5ad")
    }

    // ---- CSV ----

    def 'readCsvFromPath should parse CSV file' () {
        given:
        def tempFile = Files.createTempFile("test", ".csv")
        tempFile.text = "id,name,value\nfoo,bar,42\nbaz,qux,99"
        
        when:
        def result = SerializationUtils.readCsvFromPath(tempFile)
        
        then:
        result.size() == 2
        result[0].id == "foo"
        result[0].name == "bar"
        result[0].value == "42"
        result[1].id == "baz"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    def 'readCsvFromPath should handle quoted fields' () {
        given:
        def tempFile = Files.createTempFile("test", ".csv")
        tempFile.text = 'id,name\nfoo,"bar,baz"\nqux,quux'
        
        when:
        def result = SerializationUtils.readCsvFromPath(tempFile)
        
        then:
        result.size() == 2
        result[0].name == "bar,baz"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    def 'readCsvFromPath should skip comment lines' () {
        given:
        def tempFile = Files.createTempFile("test", ".csv")
        tempFile.text = "# comment line\nid,name\nfoo,bar"
        
        when:
        def result = SerializationUtils.readCsvFromPath(tempFile)
        
        then:
        result.size() == 1
        result[0].id == "foo"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    def 'readCsvFromPath should handle null fields' () {
        given:
        def tempFile = Files.createTempFile("test", ".csv")
        tempFile.text = "id,name,value\nfoo,,42"
        
        when:
        def result = SerializationUtils.readCsvFromPath(tempFile)
        
        then:
        result.size() == 1
        result[0].id == "foo"
        !result[0].containsKey("name")
        result[0].value == "42"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    // ---- writeJson / writeYaml ----

    def 'writeJson should write JSON file' () {
        given:
        def tempFile = File.createTempFile("test", ".json")
        
        when:
        SerializationUtils.writeJson([key: "value"], tempFile)
        def content = tempFile.text
        
        then:
        content.contains('"key"')
        content.contains('"value"')
        
        cleanup:
        tempFile.delete()
    }

    def 'writeYaml should write YAML file' () {
        given:
        def tempFile = File.createTempFile("test", ".yaml")
        
        when:
        SerializationUtils.writeYaml([key: "value"], tempFile)
        def content = tempFile.text
        
        then:
        content.contains("key: value")
        
        cleanup:
        tempFile.delete()
    }
}
