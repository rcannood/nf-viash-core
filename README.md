# viash-core Plugin

A Nextflow plugin that extracts reusable utilities from viash-generated workflow components, reducing code duplication and improving maintainability.

## What is this?

viash-core is a proof-of-concept Nextflow plugin that moves ~2800 lines of duplicated helper code from individual viash-generated Nextflow modules into a reusable plugin. The plugin provides utilities for configuration handling, serialization, state management, channel operations, and debugging.

## Getting Started

### Build and Install

```bash
make assemble      # Compile and package plugin
make install       # Install to ~/.nextflow/plugins
make test          # Run unit tests
```

### Run Test Workflows

```bash
# Single component
nextflow run viash-target-new/nextflow/step1/main.nf \
    --id foo --input "resources/lines*.txt" --publish_dir output

# Workflow with multiple steps
nextflow run viash-target-new/nextflow/test_wfs/runeach/main.nf --publish_dir output
```

### Quick Verification

```bash
./scripts/verify.sh --quick    # Build + unit tests
./scripts/verify.sh --full     # Build + tests + install + integration tests
```

## Project Structure

- **`src/main/groovy/io/viash/viash_core/`** — Plugin implementation (Groovy)
  - `ViashCoreExtension.groovy` — All exportable functions via @Function, @Factory, @Operator annotations
  - `ViashCorePlugin.groovy` — Plugin entry point
  - `config/`, `state/`, `io/`, `util/`, `help/` — Utility modules
- **`src/test/groovy/`** — Unit tests (Spock framework)
- **`viash-target-new/nextflow/`** — Generated test workflows using the plugin
- **`viash-target/nextflow/`** — Reference: original components for comparison

## Development

### Key Architecture

Plugin functions are exposed via Nextflow plugin API:
- **@Function** — Pure functions available via `include { fn } from 'plugin/viash-core'`
- **@Factory** — Channel factories like `fromViashParams()`
- **@Operator** — Channel operators like `debug()` and `niceView()`

### Adding a Function

1. Implement in appropriate utility class under `src/main/groovy/io/viash/viash_core/`
2. Expose via `@Function` annotation in `ViashCoreExtension.groovy`
3. Add unit test in `src/test/groovy/`
4. Update workflows to use it via `include`
5. Run `make test` to verify

### Important Notes

- **Target Nextflow version**: 24.10.0+ (tested with 25.04.x)
- **Cannot define workflows in plugin** — `workflow {}` blocks must stay in individual component `main.nf` files
- **Backwards compatibility** — Changes to public APIs must maintain compatibility with existing workflows

## Common Commands

```bash
make clean         # Remove build artifacts
make test          # Run all Spock tests
make assemble      # Build plugin zip only (no install)
```

## References

- [additional-info.md](additional-info.md) — Project goals and challenges
- [AGENTS.md](AGENTS.md) — AI assistant instructions
- [Nextflow plugin docs](https://www.nextflow.io/docs/latest/plugins/developing-plugins.html)
