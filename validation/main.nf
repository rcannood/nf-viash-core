// A minimal Nextflow pipeline to verify the nf-viash plugin loads correctly
// and its extension points are accessible.
//
// Usage:
//   nextflow run validation/main.nf -plugins nf-viash@0.1.0

// Import the sayHello function from the plugin (placeholder, will be replaced)
include { sayHello } from 'plugin/nf-viash'

workflow {
    sayHello('nf-viash validation')
}
