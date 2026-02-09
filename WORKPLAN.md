# nf-viash Plugin Work Plan

## Goal
Move ~2793 lines of duplicated VDSL3 helper code from each generated `main.nf` into the `nf-viash` Nextflow plugin. This reduces code duplication (~95% of each generated file is identical), improves maintainability, and enables unit testing.

## Key Constraints
- **Backwards compatibility**: The interface of viash nextflow modules must remain the same as much as possible.
- **Nextflow 25.10 compatibility**: Stricter API coming; design for it.
- **Groovy vs Nextflow DSL**: Plugin code must be Groovy, not Nextflow DSL. Workflows/processes can't be defined in plugin code directly — only functions, operators, and factories.
- **Externally-consumed functions**: `runEach`, `findStates`, `setState` are used by workflows that import viash modules. These must remain accessible after migration.

## Architecture Overview

### Original state (`viash-target/`)
Each generated `main.nf` contains:
- Lines 1–2793: Shared VDSL3 helpers (identical across all modules)
- Lines 2794+: Component-specific code (config JSON blob, innerWorkflowFactory, meta, defaults, entrypoint workflow)

### Intermediate state (`viash-target-new/`) ← WE ARE HERE
Shared helpers extracted into a single file, per-module code slimmed down, config externalized:
- `viash-target-new/nextflow/VDSL3Helper.nf` (~2480 lines): Most shared functions, imported via `include { ... } from '../VDSL3Helper.nf'`
- `viash-target-new/nextflow/*/main.nf` (~465–866 lines each): Component-specific code + `workflowFactory` (which contains `workflow {}` DSL blocks and can't be moved to an include file)
- `viash-target-new/nextflow/*/.config.vsh.yaml`: Component config read at runtime via `readYaml()` (previously inlined as a JSON blob in each `main.nf`)
- All modules must behave identically to their `viash-target/` counterparts

### Target state
- **Plugin (`nf-viash`)**: Contains all shared VDSL3 helper functions as Groovy classes/functions, exposed via `@Function`/`@Operator`/`@Factory`
- **Generated `main.nf`**: Contains only component-specific code, importing helpers from the plugin via `include { ... } from 'plugin/nf-viash'`

## Function Inventory

### Category A: Pure utility functions (no Nextflow dependencies)
These are plain Groovy functions with no dependency on Nextflow channels/workflows.

| Function | Lines | Description |
|----------|-------|-------------|
| `readJson` | 1200–1204 | Read JSON file |
| `readJsonBlob` | 1207–1210 | Parse JSON string |
| `readYaml` | 1257–1260 | Read YAML file |
| `readYamlBlob` | 1263–1266 | Parse YAML string |
| `readTaggedYaml` | 1249–1254 | Read YAML with `!file` tags |
| `readCsv` | 1150–1197 | Read CSV file |
| `toJsonBlob` | 1269–1271 | Serialize to JSON string |
| `toYamlBlob` | 1367–1373 | Serialize to YAML string |
| `toTaggedYamlBlob` | 1354–1356 | Serialize to YAML with `!file` tags |
| `toRelativeTaggedYamlBlob` | 1357–1363 | Serialize to YAML with relative `!file` tags |
| `writeJson` | 1376–1380 | Write JSON to file |
| `writeYaml` | 1383–1387 | Write YAML to file |
| `deepClone` | 1083–1085 | Deep-clone nested structures |
| `iterateMap` | 1120–1131 | Recursively transform nested structures |
| `collectFiles` | 1636–1650 | Collect File/Path objects from nested structure |
| `collectInputOutputPaths` | 1657–1673 | Build [inputPath, outputFilename] pairs |
| `_paragraphWrap` | 900–918 | Word-wrap text |
| `_mergeMap` | 796–806 | Deep-merge two maps |
| `assertMapKeys` | 1892–1899 | Validate map keys |

Helper classes:
| Class | Lines | Description |
|-------|-------|-------------|
| `UnexpectedArgumentTypeException` | 18–33 | Custom exception |
| `IDChecker` | 174–196 | Thread-safe ID uniqueness tracker |
| `CustomConstructor` | 1216–1247 | SnakeYAML `!file` tag support |
| `CustomRepresenter` | 1314–1352 | SnakeYAML `!file` serialization |
| `CustomTraceObserver` | 1050–1068 | Collect process traces |

### Category B: Argument/config processing functions
| Function | Lines | Description |
|----------|-------|-------------|
| `_checkArgumentType` | 48–148 | Validate & cast argument values |
| `_processArgument` | 679–729 | Set defaults on argument definition |
| `processConfig` | 930–965 | Process raw config map |
| `readConfig` | 968–971 | Read & process config file |
| `addGlobalArguments` | 732–794 | Add --publish_dir, --param_list args |
| `_generateArgumentHelp` | 809–856 | Help text for one argument |
| `_generateHelp` | 859–897 | Full help text for component |
| `helpMessage` | 920–927 | Print help & exit |
| `_processInputValues` | 150–167 | Validate required inputs |
| `_checkValidOutputArgument` | 170–182 | Validate output argument |
| `_checkAllRequiredOuputsPresent` | 184–192 | Assert all required outputs present |
| `getPublishDir` | 1087–1091 | Get publish directory from params |
| `getRootDir` | 1108–1112 | Find target root via .build.yaml |
| `_findBuildYamlFile` | 1095–1105 | Walk parents for .build.yaml |
| `collectTraces` | 1070–1077 | Register trace observer |

### Category C: Param/channel handling
| Function | Lines | Description |
|----------|-------|-------------|
| `_paramsToParamSets` | 240–303 | Parse params to channel events |
| `_channelFromParams` | 306–309 | Create channel from params |
| `_checkUniqueIds` | 317–320 | Assert unique IDs |
| `_getChild` | 325–332 | Resolve child path |
| `_paramListGuessFormat` | 340–353 | Guess param_list format |
| `_parseParamList` | 365–440 | Parse param_list file |
| `_splitParams` | 450–494 | Split multiple param values |
| `_resolveSiblingIfNotAbsolute` | 1010–1019 | Resolve relative paths |
| `_stringIsAbsolutePath` | 1031–1038 | Check if path is absolute |

### Category D: Workflow/directive processing
| Function | Lines | Description |
|----------|-------|-------------|
| `processDirectives` | 1902–2263 | Validate/normalize NF directives |
| `processWorkflowArgs` | 2266–2381 | Process .run() arguments |
| `_processFromState` | 2383–2422 | Standardize fromState |
| `_processToState` | 2424–2470 | Standardize toState |
| `processAuto` | 1867–1889 | Validate auto settings |
| `_debug` | 2473–2479 | Conditional debug view |

### Category E: Core workflow factory (HARDEST — contains NF workflow DSL)
| Function | Lines | Description |
|----------|-------|-------------|
| `workflowFactory` | 2482–2793 | Creates reusable VDSL3 workflow with .run()/.config |

### Category F: Externally-consumed functions (used by importing workflows)
| Function | Lines | Description |
|----------|-------|-------------|
| `runEach` | 524–625 | Run multiple components on a channel |
| `findStates` | 1389–1462 | Discover state files from directories |
| `setState` | 1827–1864 | Channel operator to update state |
| `checkUniqueIds` | 497–511 | Channel operator for ID uniqueness |
| `safeJoin` | 637–676 | Join channels with error handling |

### Category G: Component-specific (STAYS in main.nf)
| Item | Description |
|------|-------------|
| `meta` object | Reads config from `.config.vsh.yaml`, resources_dir |
| `innerWorkflowFactory` | Component's script or workflow reference |
| `vdsl3WorkflowFactory` | Dynamic process creation for script components |
| `_vdsl3ProcessFactory` | Runtime process generation |
| `_getScriptLoader` | NF version compat for script loading |
| `meta["defaults"]` | Default .run() arguments |
| `meta["workflow"]` | Default workflow instance |
| Anonymous `workflow` | Standalone entrypoint |

## Phased Work Plan

### Phase 0: Environment & verification setup ✓ DONE
- [x] Verify `make assemble` / `make test` work
- [x] Create a verification script (`scripts/verify.sh`) that builds plugin, installs it, and runs a simple NF pipeline
- [x] Document current test baseline
- [x] Create `viash-target-new/` with extracted `VDSL3Helper.nf` and slim `main.nf` files
- [x] Verify all test_wfs pass with `nextflow run viash-target-new/nextflow/test_wfs/.../main.nf`

### Phase 1: Move Category A (pure utilities) into plugin ✦ CURRENT
- [ ] Create Groovy source files with proper package structure
- [ ] Move serialization functions (readJson, readYaml, readCsv, toJsonBlob, etc.)
- [ ] Move helper classes (UnexpectedArgumentTypeException, IDChecker, CustomConstructor, CustomRepresenter)
- [ ] Move utility functions (deepClone, iterateMap, collectFiles, etc.)
- [ ] Write unit tests for each moved function
- [ ] Verify `make test` passes
- [ ] Update `VDSL3Helper.nf` to import from plugin instead of defining inline
- [ ] Verify all test_wfs still pass

### Phase 2: Move Category B (argument/config processing)
- [ ] Move _checkArgumentType, _processArgument, processConfig
- [ ] Move help generation functions
- [ ] Move validation functions (_processInputValues, _checkValidOutputArgument)
- [ ] Write unit tests
- [ ] Verify `make test` passes

### Phase 3: Move Category C (param/channel handling)
- [ ] Move _paramsToParamSets, _channelFromParams, _parseParamList
- [ ] Move path resolution helpers
- [ ] Write unit tests
- [ ] Verify `make test` passes

### Phase 4: Move Category D (directive/workflow arg processing)
- [ ] Move processDirectives, processWorkflowArgs
- [ ] Move fromState/toState processing
- [ ] Write unit tests
- [ ] Verify `make test` passes

### Phase 5: Move Category E (workflowFactory) — HARDEST
- [ ] This is the core 300-line function that creates NF workflows
- [ ] May need to be split or adapted for Groovy plugin constraints
- [ ] Workflows can't be defined directly in plugin code — need creative solution
- [ ] Write integration tests
- [ ] Verify with actual NF pipeline run

### Phase 6: Expose Category F as plugin extension points
- [ ] Expose `runEach` as @Function or @Operator
- [ ] Expose `findStates` as @Function or @Factory
- [ ] Expose `setState` as @Operator
- [ ] Write unit tests
- [ ] Verify backwards compatibility with test workflows

### Phase 7: Update viash code generation
- [ ] Modify what viash generates: slim main.nf with plugin imports
- [ ] Remove shared VDSL3 code from generated output
- [ ] Integration test with full pipeline
- [ ] Document breaking changes / deprecations

## Open Questions
- Can `workflowFactory` (which creates NF workflows dynamically) work from a plugin, or does it need to stay in generated code?
- How will `vdsl3WorkflowFactory` / `_vdsl3ProcessFactory` (dynamic process creation) interact with plugin scope?
- What's the right NF plugin extension point for `runEach` — it creates a workflow internally?
- Should we target NF 24.10 (current in build.gradle) or NF 25.x?

## Verification Checklist
After each phase:
1. `make assemble` succeeds
2. `make test` (Groovy unit tests) passes
3. `make install` succeeds
4. All test_wfs pass: `nextflow run viash-target-new/nextflow/test_wfs/<name>/main.nf --publish_dir output` exits 0
5. Clean up: `rm -rf .nextflow* work output`

Test workflows to verify (all under `viash-target-new/nextflow/test_wfs/`):
- `alias` — tests component aliasing via `.run(key:)`
- `concurrency` — 1000 items through step1→step1bis with fromState/toState closures
- `empty_workflow` — passthrough + empty emit channel
- `filter_runif` — tests `filter:` and `runIf:` parameters
- `fromstate_tostate` — tests fromState/toState as List, Map, and Closure
- `invalid_fromstate_argument` — expects error on bad fromState key
- `invalid_tostate_argument` — expects error on bad toState key
- `nested` — nested sub_workflow invocation
- `runeach` — `runEach()` with 26 component variants × 101 items
