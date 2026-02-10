package io.viash.viash_core.util

import spock.lang.Specification

class PathUtilsTest extends Specification {

    def 'stringIsAbsolutePath should detect absolute unix paths' () {
        expect:
        PathUtils.stringIsAbsolutePath("/home/user/file.txt") == true
        PathUtils.stringIsAbsolutePath("/tmp/test") == true
    }

    def 'stringIsAbsolutePath should detect URL protocols' () {
        expect:
        PathUtils.stringIsAbsolutePath("s3://bucket/key") == true
        PathUtils.stringIsAbsolutePath("gs://bucket/key") == true
        PathUtils.stringIsAbsolutePath("http://example.com/file") == true
    }

    def 'stringIsAbsolutePath should reject relative paths' () {
        expect:
        PathUtils.stringIsAbsolutePath("relative/path") == false
        PathUtils.stringIsAbsolutePath("file.txt") == false
        PathUtils.stringIsAbsolutePath("./local") == false
    }

    def 'getChild should resolve relative child' () {
        when:
        def result = PathUtils.getChild("/home/user/dir/params.yaml", "input.txt")
        
        then:
        result.endsWith("/home/user/dir/input.txt")
    }

    def 'getChild should return absolute child unchanged' () {
        when:
        def result = PathUtils.getChild("/home/user/dir/params.yaml", "/tmp/input.txt")
        
        then:
        result == "/tmp/input.txt"
    }

    def 'getChild should return URL child unchanged' () {
        when:
        def result = PathUtils.getChild("/home/user/params.yaml", "s3://bucket/input.txt")
        
        then:
        result == "s3://bucket/input.txt"
    }

    def 'findBuildYamlFile should return null when not found' () {
        given:
        def tempDir = java.nio.file.Files.createTempDirectory("test")
        
        when:
        def result = PathUtils.findBuildYamlFile(tempDir)
        
        then:
        result == null
        
        cleanup:
        java.nio.file.Files.deleteIfExists(tempDir)
    }

    def 'findBuildYamlFile should find build yaml' () {
        given:
        def tempDir = java.nio.file.Files.createTempDirectory("test")
        def buildYaml = tempDir.resolve(".build.yaml")
        buildYaml.text = "build: true"
        def subDir = java.nio.file.Files.createDirectory(tempDir.resolve("sub"))
        
        when:
        def result = PathUtils.findBuildYamlFile(subDir)
        
        then:
        result == buildYaml
        
        cleanup:
        java.nio.file.Files.deleteIfExists(buildYaml)
        java.nio.file.Files.deleteIfExists(subDir)
        java.nio.file.Files.deleteIfExists(tempDir)
    }

    def 'getRootDir should return parent of build yaml' () {
        given:
        def tempDir = java.nio.file.Files.createTempDirectory("test")
        def buildYaml = tempDir.resolve(".build.yaml")
        buildYaml.text = "build: true"
        def subDir = java.nio.file.Files.createDirectory(tempDir.resolve("sub"))
        
        when:
        def result = PathUtils.getRootDir(subDir)
        
        then:
        result == tempDir
        
        cleanup:
        java.nio.file.Files.deleteIfExists(buildYaml)
        java.nio.file.Files.deleteIfExists(subDir)
        java.nio.file.Files.deleteIfExists(tempDir)
    }
}
