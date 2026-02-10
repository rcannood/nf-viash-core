package io.viash.viash_core.config

import spock.lang.Specification

class DirectiveUtilsTest extends Specification {

    def 'processDirectives should accept valid directives' () {
        given:
        def drctv = [
            cpus: 4,
            memory: "8 GB",
            container: "ubuntu:latest",
            tag: '$id'
        ]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.cpus == 4
        result.memory == "8 GB"
        result.container == "ubuntu:latest"
    }

    def 'processDirectives should reject unexpected keys' () {
        when:
        DirectiveUtils.processDirectives([bogusKey: "value"])
        
        then:
        thrown(AssertionError)
    }

    def 'processDirectives should remove null values' () {
        given:
        def drctv = [cpus: 4, memory: null]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        !result.containsKey("memory")
        result.cpus == 4
    }

    def 'processDirectives should process container map' () {
        given:
        def drctv = [container: [registry: "ghcr.io", image: "myimage", tag: "1.0"]]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.container == "ghcr.io/myimage:1.0"
    }

    def 'processDirectives should process container map without tag' () {
        given:
        def drctv = [container: [image: "myimage"]]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.container == "myimage:latest"
    }

    def 'processDirectives should join conda list' () {
        given:
        def drctv = [conda: ["bwa=0.7.15", "fastqc=0.11.5"]]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.conda == "bwa=0.7.15 fastqc=0.11.5"
    }

    def 'processDirectives should normalize publishDir string' () {
        given:
        def drctv = [publishDir: "/path/to/dir"]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.publishDir instanceof List
        result.publishDir[0].path == "/path/to/dir"
    }

    def 'processDirectives should validate publishDir mode' () {
        given:
        def drctv = [publishDir: [[path: "/out", mode: "copy"]]]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.publishDir[0].mode == "copy"
    }

    def 'processDirectives should normalize label to list' () {
        given:
        def drctv = [label: "big_mem"]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.label == ["big_mem"]
    }

    def 'processDirectives should validate errorStrategy values' () {
        when:
        DirectiveUtils.processDirectives([errorStrategy: "invalid"])
        
        then:
        thrown(AssertionError)
    }

    def 'processDirectives should accept valid errorStrategy' () {
        when:
        def result = DirectiveUtils.processDirectives([errorStrategy: "retry"])
        
        then:
        result.errorStrategy == "retry"
    }

    def 'processDirectives should accept empty map' () {
        when:
        def result = DirectiveUtils.processDirectives([:])
        
        then:
        result == [:]
    }

    def 'processDirectives should handle pod directive' () {
        given:
        def drctv = [pod: [label: "key", value: "val"]]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv)
        
        then:
        result.pod instanceof List
        result.pod[0].label == "key"
    }

    def 'processDirectives should use container registry override' () {
        given:
        def drctv = [container: [image: "myimage", tag: "1.0"]]
        
        when:
        def result = DirectiveUtils.processDirectives(drctv, "myregistry.io")
        
        then:
        result.container == "myregistry.io/myimage:1.0"
    }
}
