package io.viash.viash_core.config

import spock.lang.Specification
import java.nio.file.Paths

class ValidationUtilsTest extends Specification {

    def defaultFileResolver = { str -> Paths.get(str) }

    def makeConfig() {
        ConfigUtils.processConfig([
            name: "test_module",
            arguments: [
                [name: "--input", type: "file", direction: "input", required: true],
                [name: "--output", type: "file", direction: "output", required: true, example: "out.txt"],
                [name: "--optional_input", type: "string", direction: "input", required: false],
            ],
            argument_groups: []
        ])
    }

    // ---- processInputValues ----

    def 'processInputValues should validate valid inputs' () {
        given:
        def config = makeConfig()
        def inputs = [input: "/tmp/test.txt"]
        
        when:
        def result = ConfigUtils.processInputValues(inputs, config, "id1", "test_module", false, defaultFileResolver)
        
        then:
        result.input instanceof java.nio.file.Path
    }

    def 'processInputValues should skip validation in stub mode' () {
        given:
        def config = makeConfig()
        def inputs = [:] // missing required input
        
        when:
        def result = ConfigUtils.processInputValues(inputs, config, "id1", "test_module", true, defaultFileResolver)
        
        then:
        noExceptionThrown()
        result == [:]
    }

    def 'processInputValues should fail on missing required input' () {
        given:
        def config = makeConfig()
        def inputs = [:] // missing required input
        
        when:
        ConfigUtils.processInputValues(inputs, config, "id1", "test_module", false, defaultFileResolver)
        
        then:
        thrown(AssertionError)
    }

    def 'processInputValues should fail on invalid argument name' () {
        given:
        def config = makeConfig()
        def inputs = [input: "/tmp/test.txt", bogus: "value"]
        
        when:
        ConfigUtils.processInputValues(inputs, config, "id1", "test_module", false, defaultFileResolver)
        
        then:
        thrown(AssertionError)
    }

    def 'processInputValues should accept optional input as null' () {
        given:
        def config = makeConfig()
        def inputs = [input: "/tmp/test.txt", optional_input: null]
        
        when:
        def result = ConfigUtils.processInputValues(inputs, config, "id1", "test_module", false, defaultFileResolver)
        
        then:
        noExceptionThrown()
    }

    // ---- checkValidOutputArgument ----

    def 'checkValidOutputArgument should validate valid outputs' () {
        given:
        def config = makeConfig()
        def outputs = [output: "/tmp/out.txt"]
        
        when:
        def result = ConfigUtils.checkValidOutputArgument(outputs, config, "id1", "test_module", false, defaultFileResolver)
        
        then:
        result.output instanceof java.nio.file.Path
    }

    def 'checkValidOutputArgument should skip validation in stub mode' () {
        given:
        def config = makeConfig()
        def outputs = [bogus: "value"]
        
        when:
        def result = ConfigUtils.checkValidOutputArgument(outputs, config, "id1", "test_module", true, defaultFileResolver)
        
        then:
        noExceptionThrown()
    }

    def 'checkValidOutputArgument should fail on invalid output name' () {
        given:
        def config = makeConfig()
        def outputs = [bogus: "value"]
        
        when:
        ConfigUtils.checkValidOutputArgument(outputs, config, "id1", "test_module", false, defaultFileResolver)
        
        then:
        thrown(AssertionError)
    }

    // ---- checkAllRequiredOutputsPresent ----

    def 'checkAllRequiredOutputsPresent should pass with all required outputs' () {
        given:
        def config = makeConfig()
        def outputs = [output: "/tmp/out.txt"]
        
        when:
        ConfigUtils.checkAllRequiredOutputsPresent(outputs, config, "id1", "test_module", false)
        
        then:
        noExceptionThrown()
    }

    def 'checkAllRequiredOutputsPresent should fail on missing required output' () {
        given:
        def config = makeConfig()
        def outputs = [:] // missing required output
        
        when:
        ConfigUtils.checkAllRequiredOutputsPresent(outputs, config, "id1", "test_module", false)
        
        then:
        thrown(AssertionError)
    }

    def 'checkAllRequiredOutputsPresent should skip validation in stub mode' () {
        given:
        def config = makeConfig()
        def outputs = [:] // missing required output
        
        when:
        ConfigUtils.checkAllRequiredOutputsPresent(outputs, config, "id1", "test_module", true)
        
        then:
        noExceptionThrown()
    }

    // ---- addGlobalArguments ----

    def 'addGlobalArguments should add publish_dir and param_list arguments' () {
        given:
        def config = ConfigUtils.processConfig([
            name: "my_component",
            arguments: [[name: "--input", type: "file", direction: "input"]],
            argument_groups: []
        ])
        
        when:
        def result = ConfigUtils.addGlobalArguments(config)
        
        then:
        result.allArguments.any { it.plainName == "publish_dir" }
        result.allArguments.any { it.plainName == "param_list" }
        result.allArguments.any { it.plainName == "input" }
    }

    def 'addGlobalArguments should set publish_dir as required' () {
        given:
        def config = ConfigUtils.processConfig([
            name: "my_component",
            arguments: [],
            argument_groups: []
        ])
        
        when:
        def result = ConfigUtils.addGlobalArguments(config)
        
        then:
        def publishDirArg = result.allArguments.find { it.plainName == "publish_dir" }
        publishDirArg != null
        publishDirArg.required == true
        publishDirArg.type == "string"
    }

    def 'addGlobalArguments should set param_list as optional' () {
        given:
        def config = ConfigUtils.processConfig([
            name: "my_component",
            arguments: [],
            argument_groups: []
        ])
        
        when:
        def result = ConfigUtils.addGlobalArguments(config)
        
        then:
        def paramListArg = result.allArguments.find { it.plainName == "param_list" }
        paramListArg != null
        paramListArg.required == false
    }
}
