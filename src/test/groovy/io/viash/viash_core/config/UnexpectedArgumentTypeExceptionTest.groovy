package io.viash.viash_core.config

import spock.lang.Specification

class UnexpectedArgumentTypeExceptionTest extends Specification {

    def 'should create exception with all fields' () {
        when:
        def e = new UnexpectedArgumentTypeException("in module 'foo' id 'bar'", "input", "myarg", "Integer", "String")
        
        then:
        e.message == "Error in module 'foo' id 'bar': input argument 'myarg' has the wrong type. Expected type: Integer. Found type: String"
        e.errorIdentifier == "in module 'foo' id 'bar'"
        e.stage == "input"
        e.plainName == "myarg"
        e.expectedClass == "Integer"
        e.foundClass == "String"
    }

    def 'should create exception with empty identifier' () {
        when:
        def e = new UnexpectedArgumentTypeException("", "output", "myarg", "Path", "Integer")
        
        then:
        e.message == "Error: output argument 'myarg' has the wrong type. Expected type: Path. Found type: Integer"
    }

    def 'should create exception with null identifier' () {
        when:
        def e = new UnexpectedArgumentTypeException(null, null, "myarg", "Boolean", "String")
        
        then:
        e.message == "Error: argument 'myarg' has the wrong type. Expected type: Boolean. Found type: String"
    }
}
