package io.viash.viash_core.util

import spock.lang.Specification
import java.nio.file.Paths

class CollectionUtilsTest extends Specification {

    // ---- iterateMap ----

    def 'iterateMap should apply function to leaf values' () {
        expect:
        CollectionUtils.iterateMap(5, { it * 2 }) == 10
    }

    def 'iterateMap should traverse lists' () {
        expect:
        CollectionUtils.iterateMap([1, 2, 3], { it * 2 }) == [2, 4, 6]
    }

    def 'iterateMap should traverse maps' () {
        expect:
        CollectionUtils.iterateMap([a: 1, b: 2], { it * 2 }) == [a: 2, b: 4]
    }

    def 'iterateMap should traverse nested structures' () {
        given:
        def input = [a: [1, 2], b: [c: 3]]
        
        expect:
        CollectionUtils.iterateMap(input, { it * 10 }) == [a: [10, 20], b: [c: 30]]
    }

    def 'iterateMap should not treat strings as lists' () {
        expect:
        CollectionUtils.iterateMap("hello", { it.toUpperCase() }) == "HELLO"
    }

    // ---- deepClone ----

    def 'deepClone should create independent copy of nested map' () {
        given:
        def original = [a: [1, 2, 3], b: [c: "hello"]]
        
        when:
        def clone = CollectionUtils.deepClone(original)
        original.a.add(4)
        
        then:
        clone.a == [1, 2, 3]
        clone.b.c == "hello"
    }

    def 'deepClone should handle simple values' () {
        expect:
        CollectionUtils.deepClone(42) == 42
        CollectionUtils.deepClone("hello") == "hello"
        CollectionUtils.deepClone(null) == null
    }

    // ---- mergeMap ----

    def 'mergeMap should override simple values' () {
        expect:
        CollectionUtils.mergeMap([a: 1, b: 2], [b: 3]) == [a: 1, b: 3]
    }

    def 'mergeMap should deep-merge nested maps' () {
        expect:
        CollectionUtils.mergeMap([a: [x: 1, y: 2]], [a: [y: 3, z: 4]]) == [a: [x: 1, y: 3, z: 4]]
    }

    def 'mergeMap should concatenate collections' () {
        expect:
        CollectionUtils.mergeMap([a: [1, 2]], [a: [3, 4]]) == [a: [1, 2, 3, 4]]
    }

    def 'mergeMap should not mutate original maps' () {
        given:
        def lhs = [a: 1, b: 2]
        def rhs = [b: 3, c: 4]
        
        when:
        def result = CollectionUtils.mergeMap(lhs, rhs)
        
        then:
        lhs == [a: 1, b: 2]
        rhs == [b: 3, c: 4]
        result == [a: 1, b: 3, c: 4]
    }

    // ---- collectFiles ----

    def 'collectFiles should find File objects' () {
        given:
        def f = new File("/tmp/test.txt")
        
        expect:
        CollectionUtils.collectFiles(f) == [f]
    }

    def 'collectFiles should find Path objects' () {
        given:
        def p = Paths.get("/tmp/test.txt")
        
        expect:
        CollectionUtils.collectFiles(p) == [p]
    }

    def 'collectFiles should find files in nested structures' () {
        given:
        def f1 = new File("/tmp/a.txt")
        def f2 = new File("/tmp/b.txt")
        def data = [name: "test", files: [f1, f2], count: 3]
        
        when:
        def result = CollectionUtils.collectFiles(data)
        
        then:
        result.size() == 2
        result.contains(f1)
        result.contains(f2)
    }

    def 'collectFiles should return empty for non-file values' () {
        expect:
        CollectionUtils.collectFiles("hello") == []
        CollectionUtils.collectFiles(42) == []
        CollectionUtils.collectFiles(null) == []
    }

    // ---- collectInputOutputPaths ----

    def 'collectInputOutputPaths should create pairs for files' () {
        given:
        def f = Paths.get("/tmp/test.txt")
        
        when:
        def result = CollectionUtils.collectInputOutputPaths(f, "prefix")
        
        then:
        result.size() == 1
        result[0][0] == f
        result[0][1] == "prefix.txt"
    }

    def 'collectInputOutputPaths should handle nested maps' () {
        given:
        def f1 = Paths.get("/tmp/a.csv")
        def f2 = Paths.get("/tmp/b.h5ad")
        def data = [output1: f1, output2: f2]

        when:
        def result = CollectionUtils.collectInputOutputPaths(data, "id.key")

        then:
        result.size() == 2
    }

    def 'collectInputOutputPaths should ignore non-file values' () {
        expect:
        CollectionUtils.collectInputOutputPaths("hello", "prefix") == []
        CollectionUtils.collectInputOutputPaths(42, "prefix") == []
    }
}
