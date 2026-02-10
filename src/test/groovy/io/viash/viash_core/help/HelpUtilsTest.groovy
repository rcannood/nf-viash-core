package io.viash.viash_core.help

import spock.lang.Specification

class HelpUtilsTest extends Specification {

    def 'generateArgumentHelp for simple string argument' () {
        given:
        def param = [
            plainName: "input",
            type: "file",
            description: "Path to the input file.",
            required: true,
            default: null,
            example: "path/to/file.txt",
            multiple: false,
            multiple_sep: ";"
        ]
        
        when:
        def result = HelpUtils.generateArgumentHelp(param)
        
        then:
        result.contains("--input")
        result.contains("file")
        result.contains("Path to the input file.")
        result.contains("required")
    }

    def 'generateArgumentHelp for optional argument with default' () {
        given:
        def param = [
            plainName: "threads",
            type: "integer",
            description: "Number of threads.",
            required: false,
            default: [4],
            example: null,
            multiple: false,
            multiple_sep: ";"
        ]
        
        when:
        def result = HelpUtils.generateArgumentHelp(param)
        
        then:
        result.contains("--threads")
        result.contains("integer")
        result.contains("Number of threads.")
        result.contains("default: 4")
    }

    def 'generateHelp for simple config' () {
        given:
        def args = [
            [
                plainName: "input",
                type: "file",
                description: "Input file.",
                required: true,
                default: null,
                example: null,
                multiple: false,
                multiple_sep: ";"
            ],
            [
                plainName: "output",
                type: "file",
                description: "Output file.",
                required: false,
                default: ["out.txt"],
                example: null,
                multiple: false,
                multiple_sep: ";"
            ]
        ]
        def config = [
            name: "my_component",
            description: "A simple test component.",
            allArguments: args,
            allArgumentGroups: [
                [name: "Arguments", description: null, arguments: args]
            ]
        ]
        
        when:
        def result = HelpUtils.generateHelp(config)
        
        then:
        result.contains("my_component")
        result.contains("A simple test component.")
        result.contains("--input")
        result.contains("--output")
    }

    def 'generateHelp when description is null' () {
        given:
        def config = [
            name: "nodesc",
            description: null,
            allArguments: [],
            allArgumentGroups: []
        ]
        
        when:
        def result = HelpUtils.generateHelp(config)
        
        then:
        result.contains("nodesc")
    }
}
