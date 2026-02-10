package io.viash.viash_core.state

import spock.lang.Specification

class StateUtilsTest extends Specification {

    def 'checkUniqueIds with unique IDs should pass' () {
        given:
        def paramSets = [
            ["id1", [key: "val1"]],
            ["id2", [key: "val2"]],
            ["id3", [key: "val3"]]
        ]
        
        when:
        StateUtils.checkUniqueIds(paramSets)
        
        then:
        noExceptionThrown()
    }

    def 'checkUniqueIds with duplicate IDs should throw' () {
        given:
        def paramSets = [
            ["id1", [key: "val1"]],
            ["id2", [key: "val2"]],
            ["id1", [key: "val3"]]
        ]
        
        when:
        StateUtils.checkUniqueIds(paramSets)
        
        then:
        thrown(AssertionError)
    }

    def 'paramListGuessFormat with yaml string' () {
        when:
        def result = StateUtils.paramListGuessFormat("test.yaml")
        
        then:
        result == "yaml"
    }

    def 'paramListGuessFormat with json string' () {
        when:
        def result = StateUtils.paramListGuessFormat("test.json")
        
        then:
        result == "json"
    }

    def 'paramListGuessFormat with csv string' () {
        when:
        def result = StateUtils.paramListGuessFormat("test.csv")
        
        then:
        result == "csv"
    }

    def 'paramListGuessFormat with list returns asis' () {
        when:
        def result = StateUtils.paramListGuessFormat([[id: "foo", key: "val"]])
        
        then:
        result == "asis"
    }

    def 'paramListGuessFormat with map returns asis' () {
        when:
        def result = StateUtils.paramListGuessFormat([id: "foo", key: "val"])
        
        then:
        result == "asis"
    }

    def 'splitParams with simple map' () {
        given:
        def config = [
            allArguments: [
                [plainName: "input", type: "file", direction: "input", multiple: false],
                [plainName: "output", type: "file", direction: "output", multiple: false]
            ]
        ]
        def parValues = [input: "a.txt", output: "b.txt", extra: "val"]
        
        when:
        def result = StateUtils.splitParams(parValues, config)
        
        then:
        result.input == "a.txt"
        result.output == "b.txt"
        result.extra == "val"
    }

    def 'splitParams with multiple values' () {
        given:
        def config = [
            allArguments: [
                [plainName: "input", type: "file", direction: "input", multiple: true, multiple_sep: ";"]
            ]
        ]
        def parValues = [input: "a.txt;b.txt"]
        
        when:
        def result = StateUtils.splitParams(parValues, config)
        
        then:
        result.input == ["a.txt", "b.txt"]
    }

    def 'processFromState with closure' () {
        given:
        def config = [
            allArguments: [
                [plainName: "input", type: "file", direction: "input"]
            ]
        ]
        def fromState = { id, state -> [input: state.myInput] }
        def key = "id1"
        
        when:
        def result = StateUtils.processFromState(fromState, key, config)
        
        then:
        result instanceof Closure
    }

    def 'processFromState with list' () {
        given:
        def config = [
            allArguments: [
                [plainName: "input", type: "file", direction: "input"]
            ]
        ]
        def fromState = ["input"]
        def key = "id1"
        
        when:
        def result = StateUtils.processFromState(fromState, key, config)
        
        then:
        result instanceof Closure
    }

    def 'processToState with closure' () {
        given:
        def config = [
            allArguments: [
                [plainName: "output", type: "file", direction: "output"]
            ]
        ]
        def toState = { id, output, state -> state + [result: output.output] }
        def key = "id1"
        
        when:
        def result = StateUtils.processToState(toState, key, config)
        
        then:
        result instanceof Closure
    }

    def 'processToState with list' () {
        given:
        def config = [
            allArguments: [
                [plainName: "output", type: "file", direction: "output"]
            ]
        ]
        def toState = ["output"]
        def key = "id1"
        
        when:
        def result = StateUtils.processToState(toState, key, config)
        
        then:
        result instanceof Closure
    }
}
