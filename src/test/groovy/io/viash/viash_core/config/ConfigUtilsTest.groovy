package io.viash.viash_core.config

import spock.lang.Specification

class ConfigUtilsTest extends Specification {

    // ---- processArgument ----

    def 'processArgument should set defaults' () {
        given:
        def arg = [name: "--input", type: "string"]
        
        when:
        def result = ConfigUtils.processArgument(arg)
        
        then:
        result.multiple == false
        result.required == false
        result.direction == "input"
        result.multiple_sep == ";"
        result.plainName == "input"
    }

    def 'processArgument should handle file type' () {
        given:
        def arg = [name: "--output", type: "file", direction: "output", example: "output.txt"]
        
        when:
        def result = ConfigUtils.processArgument(arg)
        
        then:
        result.must_exist == true
        result.create_parent == true
        result.default != null
        result.default.contains(".txt")
    }

    def 'processArgument should strip leading dashes from plainName' () {
        expect:
        ConfigUtils.processArgument([name: "--my_arg", type: "string"]).plainName == "my_arg"
        ConfigUtils.processArgument([name: "-x", type: "string"]).plainName == "x"
        ConfigUtils.processArgument([name: "no_dashes", type: "string"]).plainName == "no_dashes"
    }

    def 'processArgument should set boolean_true default' () {
        given:
        def arg = [name: "--flag", type: "boolean_true"]
        
        when:
        def result = ConfigUtils.processArgument(arg)
        
        then:
        result.default == false
    }

    def 'processArgument should set boolean_false default' () {
        given:
        def arg = [name: "--flag", type: "boolean_false"]
        
        when:
        def result = ConfigUtils.processArgument(arg)
        
        then:
        result.default == true
    }

    // ---- processConfig ----

    def 'processConfig should create allArguments from arguments and argument_groups' () {
        given:
        def config = [
            name: "test",
            arguments: [
                [name: "--input", type: "file", direction: "input"],
            ],
            argument_groups: [
                [
                    name: "Output",
                    arguments: [
                        [name: "--output", type: "file", direction: "output", example: "out.txt"]
                    ]
                ]
            ]
        ]
        
        when:
        def result = ConfigUtils.processConfig(config)
        
        then:
        result.allArguments.size() == 2
        result.allArguments[0].plainName == "input"
        result.allArguments[1].plainName == "output"
    }

    def 'processConfig should create allArgumentGroups' () {
        given:
        def config = [
            name: "test",
            arguments: [
                [name: "--input", type: "string"]
            ],
            argument_groups: []
        ]
        
        when:
        def result = ConfigUtils.processConfig(config)
        
        then:
        result.allArgumentGroups.size() == 1
        result.allArgumentGroups[0].name == "Arguments"
    }

    // ---- processAuto ----

    def 'processAuto should validate and return expected keys' () {
        given:
        def auto = [simplifyInput: true, simplifyOutput: false, transcript: false, publish: true]
        
        when:
        def result = ConfigUtils.processAuto(auto)
        
        then:
        result == [simplifyInput: true, simplifyOutput: false, transcript: false, publish: true]
    }

    def 'processAuto should accept publish as state' () {
        given:
        def auto = [simplifyInput: true, simplifyOutput: false, transcript: false, publish: "state"]
        
        when:
        def result = ConfigUtils.processAuto(auto)
        
        then:
        result.publish == "state"
    }

    def 'processAuto should reject unexpected keys' () {
        when:
        ConfigUtils.processAuto([simplifyInput: true, simplifyOutput: false, transcript: false, publish: true, bogus: "oops"])
        
        then:
        thrown(AssertionError)
    }

    def 'processAuto should remove null values' () {
        given:
        def auto = [simplifyInput: true, simplifyOutput: false, transcript: false, publish: true, extra: null]
        
        when:
        def result = ConfigUtils.processAuto(auto)
        
        then:
        !result.containsKey("extra")
    }

    // ---- assertMapKeys ----

    def 'assertMapKeys should pass for valid map' () {
        when:
        ConfigUtils.assertMapKeys([a: 1, b: 2], ["a", "b", "c"], ["a"], "test")
        
        then:
        noExceptionThrown()
    }

    def 'assertMapKeys should fail for unexpected key' () {
        when:
        ConfigUtils.assertMapKeys([a: 1, d: 2], ["a", "b", "c"], [], "test")
        
        then:
        thrown(AssertionError)
    }

    def 'assertMapKeys should fail for missing required key' () {
        when:
        ConfigUtils.assertMapKeys([a: 1], ["a", "b"], ["b"], "test")
        
        then:
        thrown(AssertionError)
    }
}
