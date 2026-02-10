package io.viash.viash_core.config

import spock.lang.Specification
import java.nio.file.Paths
import java.nio.file.Path

class CheckArgumentTypeTest extends Specification {

    def defaultFileResolver = { str -> Paths.get(str) }

    // ---- String type ----

    def 'checkArgumentType should accept String for string type' () {
        given:
        def par = [plainName: "input", type: "string", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "hello", "test")
        
        then:
        result == "hello"
        result instanceof String
    }

    def 'checkArgumentType should cast GString to String' () {
        given:
        def par = [plainName: "input", type: "string", required: true, multiple: false, multiple_sep: ";"]
        def val = "hello ${"world"}"
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, val, "test")
        
        then:
        result == "hello world"
        result instanceof String
    }

    def 'checkArgumentType should reject non-string for string type' () {
        given:
        def par = [plainName: "input", type: "string", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        ConfigUtils.checkArgumentType("input", par, 42, "test")
        
        then:
        thrown(UnexpectedArgumentTypeException)
    }

    // ---- Integer type ----

    def 'checkArgumentType should accept Integer for integer type' () {
        given:
        def par = [plainName: "count", type: "integer", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, 42, "test")
        
        then:
        result == 42
        result instanceof Integer
    }

    def 'checkArgumentType should cast String to Integer' () {
        given:
        def par = [plainName: "count", type: "integer", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "42", "test")
        
        then:
        result == 42
        result instanceof Integer
    }

    def 'checkArgumentType should reject non-numeric string for integer type' () {
        given:
        def par = [plainName: "count", type: "integer", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        ConfigUtils.checkArgumentType("input", par, "abc", "test")
        
        then:
        thrown(UnexpectedArgumentTypeException)
    }

    // ---- Long type ----

    def 'checkArgumentType should cast to Long' () {
        given:
        def par = [plainName: "bignum", type: "long", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "12345678901234", "test")
        
        then:
        result == 12345678901234L
        result instanceof Long
    }

    // ---- Double type ----

    def 'checkArgumentType should cast to Double' () {
        given:
        def par = [plainName: "ratio", type: "double", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "3.14", "test")
        
        then:
        result == 3.14d
        result instanceof Double
    }

    def 'checkArgumentType should accept Double directly' () {
        given:
        def par = [plainName: "ratio", type: "double", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, 3.14d, "test")
        
        then:
        result == 3.14d
    }

    // ---- Float type ----

    def 'checkArgumentType should cast to Float' () {
        given:
        def par = [plainName: "ratio", type: "float", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "2.5", "test")
        
        then:
        result == 2.5f
        result instanceof Float
    }

    // ---- Boolean type ----

    def 'checkArgumentType should accept Boolean for boolean type' () {
        given:
        def par = [plainName: "flag", type: "boolean", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, true, "test")
        
        then:
        result == true
    }

    def 'checkArgumentType should accept boolean_true type' () {
        given:
        def par = [plainName: "flag", type: "boolean_true", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, true, "test")
        
        then:
        result == true
    }

    def 'checkArgumentType should accept boolean_false type' () {
        given:
        def par = [plainName: "flag", type: "boolean_false", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, false, "test")
        
        then:
        result == false
    }

    // ---- File type ----

    def 'checkArgumentType should convert String to Path for file input' () {
        given:
        def par = [plainName: "input", type: "file", direction: "input", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "/tmp/test.txt", "test", defaultFileResolver)
        
        then:
        result instanceof Path
        result.toString() == "/tmp/test.txt"
    }

    def 'checkArgumentType should accept Path for file input' () {
        given:
        def par = [plainName: "input", type: "file", direction: "input", required: true, multiple: false, multiple_sep: ";"]
        def path = Paths.get("/tmp/test.txt")
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, path, "test", defaultFileResolver)
        
        then:
        result instanceof Path
        result == path
    }

    def 'checkArgumentType should convert File to Path' () {
        given:
        def par = [plainName: "input", type: "file", direction: "input", required: true, multiple: false, multiple_sep: ";"]
        def file = new File("/tmp/test.txt")
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, file, "test", defaultFileResolver)
        
        then:
        result instanceof Path
    }

    def 'checkArgumentType should keep file output as String in input stage' () {
        given:
        def par = [plainName: "output", type: "file", direction: "output", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "/tmp/out.txt", "test")
        
        then:
        result instanceof String
        result == "/tmp/out.txt"
    }

    def 'checkArgumentType should convert file output to Path in output stage' () {
        given:
        def par = [plainName: "output", type: "file", direction: "output", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("output", par, "/tmp/out.txt", "test", defaultFileResolver)
        
        then:
        result instanceof Path
    }

    // ---- Null / optional ----

    def 'checkArgumentType should accept null for non-required argument' () {
        given:
        def par = [plainName: "optional", type: "string", required: false, multiple: false, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, null, "test")
        
        then:
        result == null
    }

    // ---- Multiple values ----

    def 'checkArgumentType should handle multiple string values' () {
        given:
        def par = [plainName: "inputs", type: "string", required: true, multiple: true, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "a;b;c", "test")
        
        then:
        result == ["a", "b", "c"]
    }

    def 'checkArgumentType should handle multiple integer values' () {
        given:
        def par = [plainName: "counts", type: "integer", required: true, multiple: true, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, [1, 2, 3], "test")
        
        then:
        result == [1, 2, 3]
    }

    def 'checkArgumentType should wrap single value in list for multiple' () {
        given:
        def par = [plainName: "inputs", type: "string", required: true, multiple: true, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "single", "test")
        
        then:
        result == ["single"]
    }

    def 'checkArgumentType should handle multiple files' () {
        given:
        def par = [plainName: "inputs", type: "file", direction: "input", required: true, multiple: true, multiple_sep: ";"]
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, ["/tmp/a.txt", "/tmp/b.txt"], "test", defaultFileResolver)
        
        then:
        result.size() == 2
        result.every { it instanceof Path }
    }

    def 'checkArgumentType should use fileResolver for multiple file globs' () {
        given:
        def par = [plainName: "inputs", type: "file", direction: "input", required: true, multiple: true, multiple_sep: ";"]
        // fileResolver that expands "*.txt" to a list of paths
        def resolver = { str ->
            if (str.contains("*")) {
                [Paths.get("/tmp/a.txt"), Paths.get("/tmp/b.txt")]
            } else {
                Paths.get(str)
            }
        }
        
        when:
        def result = ConfigUtils.checkArgumentType("input", par, "*.txt", "test", resolver)
        
        then:
        result.size() == 2
        result.every { it instanceof Path }
    }

    // ---- Unknown type ----

    def 'checkArgumentType should throw for unknown type' () {
        given:
        def par = [plainName: "x", type: "unknown_type", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        ConfigUtils.checkArgumentType("input", par, "val", "test")
        
        then:
        thrown(UnexpectedArgumentTypeException)
    }

    // ---- Exception details ----

    def 'UnexpectedArgumentTypeException should have correct details' () {
        given:
        def par = [plainName: "count", type: "integer", required: true, multiple: false, multiple_sep: ";"]
        
        when:
        ConfigUtils.checkArgumentType("input", par, "abc", "in module 'test'")
        
        then:
        def e = thrown(UnexpectedArgumentTypeException)
        e.plainName == "count"
        e.expectedClass == "Integer"
        e.stage == "input"
        e.errorIdentifier == "in module 'test'"
    }
}
