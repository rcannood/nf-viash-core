package io.viash.viash_core.state

import spock.lang.Specification
import java.nio.file.Paths
import java.nio.file.Path
import java.nio.file.Files

import io.viash.viash_core.config.ConfigUtils

class ParseParamListTest extends Specification {

    def makeConfig() {
        ConfigUtils.processConfig([
            name: "test_module",
            arguments: [
                [name: "--input", type: "file", direction: "input", required: true],
                [name: "--output", type: "file", direction: "output", required: false, example: "out.txt"],
                [name: "--k", type: "integer", direction: "input", required: false],
            ],
            argument_groups: []
        ])
    }

    def testFileResolver = { str -> Paths.get(str) }

    // ---- asis format ----

    def 'parseParamList should handle asis format (list of maps)' () {
        given:
        def config = makeConfig()
        def paramList = [[id: "foo", input: "/tmp/a.txt"], [id: "bar", input: "/tmp/b.txt"]]
        
        when:
        def result = StateUtils.parseParamList(paramList, config)
        
        then:
        result.size() == 2
        result[0][0] == "foo"
        result[0][1].input == "/tmp/a.txt"
        result[1][0] == "bar"
    }

    def 'parseParamList should strip id from data when not an argument' () {
        given:
        def config = makeConfig()
        def paramList = [[id: "foo", input: "/tmp/a.txt"]]
        
        when:
        def result = StateUtils.parseParamList(paramList, config)
        
        then:
        result[0][0] == "foo"
        !result[0][1].containsKey("id")
    }

    def 'parseParamList should keep id in data when it is an argument' () {
        given:
        def config = ConfigUtils.processConfig([
            name: "test",
            arguments: [[name: "--id", type: "string"], [name: "--input", type: "file", direction: "input"]],
            argument_groups: []
        ])
        def paramList = [[id: "foo", input: "/tmp/a.txt"]]
        
        when:
        def result = StateUtils.parseParamList(paramList, config)
        
        then:
        result[0][0] == "foo"
        result[0][1].containsKey("id")
    }

    // ---- yaml_blob format ----

    def 'parseParamList should handle yaml_blob format' () {
        given:
        def config = makeConfig()
        def yamlBlob = "- id: foo\n  input: /tmp/a.txt\n- id: bar\n  input: /tmp/b.txt"
        
        when:
        def result = StateUtils.parseParamList(yamlBlob, config)
        
        then:
        result.size() == 2
        result[0][0] == "foo"
        result[1][0] == "bar"
    }

    // ---- yaml file format ----

    def 'parseParamList should handle yaml file format' () {
        given:
        def config = makeConfig()
        def tempFile = Files.createTempFile("test", ".yaml")
        tempFile.text = "- id: foo\n  input: /tmp/a.txt\n- id: bar\n  input: /tmp/b.txt"
        
        when:
        def result = StateUtils.parseParamList(tempFile.toString(), config, testFileResolver)
        
        then:
        result.size() == 2
        result[0][0] == "foo"
        result[1][0] == "bar"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    // ---- json file format ----

    def 'parseParamList should handle json file format' () {
        given:
        def config = makeConfig()
        def tempFile = Files.createTempFile("test", ".json")
        tempFile.text = '[{"id": "foo", "input": "/tmp/a.txt"}, {"id": "bar", "input": "/tmp/b.txt"}]'
        
        when:
        def result = StateUtils.parseParamList(tempFile.toString(), config, testFileResolver)
        
        then:
        result.size() == 2
        result[0][0] == "foo"
        result[1][0] == "bar"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    // ---- csv file format ----

    def 'parseParamList should handle csv file format' () {
        given:
        def config = makeConfig()
        def tempFile = Files.createTempFile("test", ".csv")
        tempFile.text = "id,input\nfoo,/tmp/a.txt\nbar,/tmp/b.txt"
        
        when:
        def result = StateUtils.parseParamList(tempFile.toString(), config, testFileResolver)
        
        then:
        result.size() == 2
        result[0][0] == "foo"
        result[1][0] == "bar"
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    // ---- multiple separator ----

    def 'parseParamList should split multiple values' () {
        given:
        def config = ConfigUtils.processConfig([
            name: "test",
            arguments: [
                [name: "--input", type: "file", direction: "input", required: true, multiple: true, multiple_sep: ";"],
            ],
            argument_groups: []
        ])
        def paramList = [[id: "foo", input: "/tmp/a.txt;/tmp/b.txt"]]
        
        when:
        def result = StateUtils.parseParamList(paramList, config)
        
        then:
        result[0][1].input == ["/tmp/a.txt", "/tmp/b.txt"]
    }

    // ---- relative path resolution ----

    def 'parseParamList should resolve relative paths' () {
        given:
        def config = makeConfig()
        def tempDir = Files.createTempDirectory("test")
        def tempFile = tempDir.resolve("params.yaml")
        tempFile.text = "- id: foo\n  input: data/a.txt"
        
        when:
        def result = StateUtils.parseParamList(tempFile.toString(), config, testFileResolver)
        
        then:
        result.size() == 1
        def resultPath = result[0][1].input
        resultPath instanceof Path
        resultPath.toString().endsWith("data/a.txt")
        resultPath.toString().startsWith(tempDir.toString())
        
        cleanup:
        Files.deleteIfExists(tempFile)
        Files.deleteIfExists(tempDir)
    }

    // ---- error handling ----

    def 'parseParamList should throw on non-list yaml blob' () {
        given:
        def config = makeConfig()
        
        when:
        // "data.xyz" is treated as a yaml_blob which parses to a string, not a list
        StateUtils.parseParamList("data.xyz", config)
        
        then:
        thrown(AssertionError)
    }

    def 'parseParamList should throw on non-list data' () {
        given:
        def config = makeConfig()
        def tempFile = Files.createTempFile("test", ".yaml")
        tempFile.text = "key: value"
        
        when:
        StateUtils.parseParamList(tempFile.toString(), config, testFileResolver)
        
        then:
        thrown(AssertionError)
        
        cleanup:
        Files.deleteIfExists(tempFile)
    }

    // ---- createIDChecker ----

    def 'createIDChecker should return a working IDChecker' () {
        when:
        def checker = StateUtils.createIDChecker()
        
        then:
        checker instanceof IDChecker
        checker.observe("a") == true
        checker.observe("b") == true
        checker.observe("a") == false
        checker.contains("a") == true
        checker.contains("c") == false
    }
}
