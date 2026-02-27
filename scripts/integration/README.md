# Integration Tests

Integration test suites for `viash-target-new`, replicating the test logic from
the [viash repository's Scala test suites](https://github.com/viash-io/viash/tree/main/src/test/scala/io/viash/runners/nextflow).

## Usage

```bash
# Run all suites
./scripts/integration/run.sh

# Run a single suite
./scripts/integration/run.sh --suite standalone

# Filter by test name pattern
./scripts/integration/run.sh --test "yamlblob"

# Keep temp outputs for debugging
./scripts/integration/run.sh --keep --verbose
```

Run `./scripts/integration/run.sh --help` for all options.

## Files

| File | Description |
|---|---|
| `run.sh` | Test runner — parses args, sources suites, prints summary |
| `helpers.sh` | Shared infrastructure: colors, counters, `nf_run*` wrappers, assertions |
| `suite_standalone.sh` | [Vdsl3StandaloneTest](https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/Vdsl3StandaloneTest.scala) — standalone component runs |
| `suite_module.sh` | [Vdsl3ModuleTest](https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/Vdsl3ModuleTest.scala) — pipeline / module runs |
| `suite_script.sh` | [NextflowScriptTest](https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/NextflowScriptTest.scala) — test workflows, symlinks, multi-emit |
| `suite_helper.sh` | [WorkflowHelperTest](https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/WorkflowHelperTest.scala) — param_list formats (yaml, json, csv, asis) |
| `suite_cross.sh` | Cross-validation — compares `viash-target-new` output against `viash-target` reference |

## Suites

Select a suite with `--suite <name>`:

- **`standalone`** — Run VDSL3 components directly (simple run, IDs with spaces, `$id`/`$key` keywords, param_list, optional inputs, multiple outputs, integer-as-double, `--help`)
- **`module`** — Run VDSL3 components as included modules in a pipeline workflow
- **`script`** — Test workflows (alias, concurrency, empty_workflow, filter_runif, fromstate_tostate, nested, runeach), error cases, symlinks, multi-emit channels
- **`helper`** — param_list processing with CLI args, yamlblob, yaml/json/csv files, and `-params-file`
- **`cross`** — Runs the same component in both `viash-target-new` and `viash-target`, diffs the outputs
- **`all`** — All of the above (default)

## CI

These tests run automatically in GitHub Actions (see `.github/workflows/ci.yml`).
The CI workflow installs Nextflow 24.10.9, builds and installs the plugin, then
runs `./scripts/integration/run.sh --verbose`.
