package io.viash.viash_core.util

import spock.lang.Specification
import java.nio.file.Paths
import java.nio.file.Path
import java.nio.file.Files

class ResolveSiblingTest extends Specification {

    def defaultFileResolver = { str -> Paths.get(str) }

    def 'resolveSiblingIfNotAbsolute should return non-String as-is' () {
        expect:
        PathUtils.resolveSiblingIfNotAbsolute(42, Paths.get("/tmp/foo.txt")) == 42
        PathUtils.resolveSiblingIfNotAbsolute(null, Paths.get("/tmp/foo.txt")) == null
        PathUtils.resolveSiblingIfNotAbsolute(Paths.get("/a/b"), Paths.get("/tmp/foo.txt")) == Paths.get("/a/b")
    }

    def 'resolveSiblingIfNotAbsolute should resolve relative path' () {
        given:
        def parentPath = Paths.get("/data/params.yaml")
        
        when:
        def result = PathUtils.resolveSiblingIfNotAbsolute("input.txt", parentPath)
        
        then:
        result instanceof Path
        result.toString() == "/data/input.txt"
    }

    def 'resolveSiblingIfNotAbsolute should resolve nested relative path' () {
        given:
        def parentPath = Paths.get("/data/config/params.yaml")
        
        when:
        def result = PathUtils.resolveSiblingIfNotAbsolute("sub/input.txt", parentPath)
        
        then:
        result instanceof Path
        result.toString() == "/data/config/sub/input.txt"
    }

    def 'resolveSiblingIfNotAbsolute should use fileResolver for absolute paths' () {
        given:
        def parentPath = Paths.get("/data/params.yaml")
        
        when:
        def result = PathUtils.resolveSiblingIfNotAbsolute("/absolute/path.txt", parentPath, defaultFileResolver)
        
        then:
        result instanceof Path
        result.toString() == "/absolute/path.txt"
    }

    def 'resolveSiblingIfNotAbsolute should use Paths.get for absolute paths when no resolver' () {
        given:
        def parentPath = Paths.get("/data/params.yaml")
        
        when:
        def result = PathUtils.resolveSiblingIfNotAbsolute("/absolute/path.txt", parentPath)
        
        then:
        result instanceof Path
        result.toString() == "/absolute/path.txt"
    }

    def 'resolveSiblingIfNotAbsolute should handle URL-like absolute paths' () {
        given:
        def parentPath = Paths.get("/data/params.yaml")
        def called = false
        def resolver = { str -> called = true; return str }
        
        when:
        def result = PathUtils.resolveSiblingIfNotAbsolute("s3://bucket/file.txt", parentPath, resolver)
        
        then:
        called == true
    }
}
