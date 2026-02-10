// A minimal Nextflow pipeline to verify the viash_core plugin loads correctly
// and its extension points are accessible.
//
// Usage:
//   nextflow run validation/main.nf -plugins viash-core@0.1.0

include { deepClone; readJsonBlob; toJsonBlob } from 'plugin/viash-core'

workflow {
    // Test deepClone
    def original = [a: 1, b: [2, 3]]
    def cloned = deepClone(original)
    assert cloned == original
    assert !cloned.is(original)

    // Test JSON round-trip
    def data = [name: "viash-core", version: 1]
    def json = toJsonBlob(data)
    def parsed = readJsonBlob(json)
    assert parsed.name == "viash-core"
    assert parsed.version == 1

    println "viash-core plugin validation passed!"
}
