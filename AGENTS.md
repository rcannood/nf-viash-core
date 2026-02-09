# Copilot Instructions for nf-viash

## Project Overview

This is a **Nextflow plugin** (`nf-viash`) written in **Groovy**, built with Gradle. Its goal is to extract ~2800 lines of shared VDSL3 helper code that is currently duplicated in every viash-generated `main.nf` Nextflow module, moving it into a reusable plugin.

Key context documents: `additional-info.md` (project goals/challenges), `WORKPLAN.md` (phased migration plan with function inventory).

## Architecture

- **Plugin source**: `src/main/groovy/dataintuitive/plugin/` — Groovy classes using Nextflow's plugin API
  - `NfViashPlugin.groovy` — Plugin entry point (extends `BasePlugin`)
  - `NfViashExtension.groovy` — Functions exposed via `@Function` annotation (importable in NF scripts via `include { fn } from 'plugin/nf-viash'`)
  - `NfViashFactory.groovy` — Creates `TraceObserver` instances
  - `NfViashObserver.groovy` — Lifecycle hooks (`onFlowCreate`, `onFlowComplete`)
- **Plugin tests**: `src/test/groovy/dataintuitive/plugin/` — Spock framework tests
- **Active development target**: `viash-target-new/nextflow/` — The working copy where we develop against. This is the code we edit.
  - `viash-target-new/nextflow/VDSL3Helper.nf` — Extracted shared helper functions (~2480 lines). Imported by each module via `include { ... } from '../VDSL3Helper.nf'`.
  - `viash-target-new/nextflow/*/main.nf` — Slim component-specific modules (~700–1000 lines each). Contains config JSON, `innerWorkflowFactory`, `workflowFactory` (which has `workflow {}` blocks and can't be in VDSL3Helper.nf), `meta`, defaults, and the anonymous entrypoint workflow.
- **Reference code (read-only)**: `viash-target/nextflow/*/main.nf` — Original generated Nextflow modules with all ~2800 lines of VDSL3 code inlined per file. Do NOT edit. Regenerate with `viash ns build -s viash-src -t viash-target`. Use as reference to verify behavior equivalence.
- **Source components**: `viash-src/` — Viash component definitions (configs + scripts). Rebuild with `viash ns build -s viash-src -t viash-target`.
- **Validation pipeline**: `validation/main.nf` — Minimal NF pipeline for integration testing the plugin.

## Build & Test Commands

```bash
make assemble          # Compile + package plugin zip
make test              # Run Spock unit tests
make install           # Install to ~/.nextflow/plugins
make clean             # Clean build artifacts + NF work dirs

./scripts/verify.sh --quick   # Build + unit tests only
./scripts/verify.sh --full    # Build + tests + install + integration test
```

After any code change, run `./scripts/verify.sh --quick` to verify. After changes to extension points or the plugin interface, use `--full`.

### Integration testing with viash-target-new

The workflows in `viash-target-new/nextflow/` must behave identically to their `viash-target/nextflow/` counterparts. To verify:

```bash
# Run a single module standalone
nextflow run viash-target-new/nextflow/step1/main.nf --id foo --input "resources/lines*.txt" --publish_dir output

# Run a test workflow (should exit 0)
nextflow run viash-target-new/nextflow/test_wfs/runeach/main.nf --publish_dir output

# All test_wfs should pass:
for wf in viash-target-new/nextflow/test_wfs/*/main.nf; do
  echo "Running $wf"
  nextflow run "$wf" --publish_dir output || echo "FAILED: $wf"
done
```

Clean up after integration tests: `rm -rf .nextflow* work output`

## Key Conventions

- **Plugin extension points** use Nextflow annotations: `@Function` for importable functions, `@Operator` for channel operators, `@Factory` for channel factories. These are defined in classes extending `PluginExtensionPoint` and registered in `build.gradle` under `extensionPoints`.
- **Groovy, not Nextflow DSL**: Plugin code cannot define `workflow {}` or `process {}` blocks directly. Dynamic process/workflow creation must use Nextflow internals (`ScriptMeta`, `ScriptParser`).
- **Test framework**: Spock (specs extend `Specification`, tests use `given:`/`when:`/`then:` blocks). See `NfViashObserverTest.groovy` for the pattern.
- **Externally-consumed functions**: `runEach`, `findStates`, `setState` are used by workflows that `include` viash modules. These must remain accessible and backwards-compatible.

## Working with Code

### Development workflow
We are actively developing in `viash-target-new/nextflow/`. The migration proceeds by moving functions from `VDSL3Helper.nf` (and the remaining boilerplate in each `main.nf`) into the Groovy plugin at `src/main/groovy/dataintuitive/plugin/`. Steps:

1. Identify a function in `viash-target-new/nextflow/VDSL3Helper.nf` or a shared pattern in `viash-target-new/nextflow/*/main.nf`
2. Port it to Groovy in `src/main/groovy/dataintuitive/plugin/`
3. Expose it via `@Function` in `NfViashExtension.groovy` (or appropriate extension point)
4. Write a Spock test in `src/test/groovy/dataintuitive/plugin/`
5. Update `viash-target-new/nextflow/*/main.nf` to `include` it from the plugin instead of `VDSL3Helper.nf`
6. Verify with `make test` and `nextflow run viash-target-new/nextflow/test_wfs/.../main.nf`

### Reference code (read-only)
The `viash-target/nextflow/*/main.nf` files are the **original reference** — do NOT edit them. They are generated by `viash ns build -s viash-src -t viash-target`. Use them to compare behavior.

## Important Constraints

- Target Nextflow version: `24.10.0` (set in `build.gradle`), must also work with NF 25.x which has stricter APIs
- **`workflowFactory` stays in each `main.nf`** — it contains `workflow {}` DSL blocks which cannot be defined in a Nextflow module that is included (the workflow needs to be in the script where it's used). It currently lives in each component's `main.nf` (~300 lines per file, still duplicated).
- `_vdsl3ProcessFactory` (script-based components only) generates Nextflow processes at runtime by writing `.nf` files and loading them via `ScriptParser`/`ScriptLoaderFactory` — version-dependent reflection is used for compatibility
- **Include path convention**: Top-level modules use `from '../VDSL3Helper.nf'`, test_wfs modules use `from '../../VDSL3Helper.nf'`
