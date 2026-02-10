# viash_core Plugin Work Plan

## Goal
Move ~2793 lines of duplicated VDSL3 helper code from each generated `main.nf` into the `viash_core` Nextflow plugin. This reduces code duplication (~95% of each generated file is identical), improves maintainability, and enables unit testing.

## Key Constraints
- **Backwards compatibility**: The interface of viash nextflow modules must remain the same as much as possible.
- **Nextflow 25.x compatibility**: Stricter API coming; design for it.
- **Groovy vs Nextflow DSL**: Plugin code must be Groovy, not Nextflow DSL. Workflows/processes can't be defined in plugin code directly — only functions, operators, and factories.
- **Externally-consumed functions**: `runEach`, `findStates`, `setState` are used by workflows that import viash modules. These must remain accessible after migration.
- **Classes can't be `include`d from plugin**: Nextflow's `include { ... } from 'plugin/viash_core'` only works for `@Function`-annotated methods, not classes. Classes like `UnexpectedArgumentTypeException`, `IDChecker`, `CustomTraceObserver` must stay in `VDSL3Helper.nf` or be refactored into function calls.

## Architecture Overview

### Original state (`viash-target/`)
Each generated `main.nf` contains:
- Lines 1–2793: Shared VDSL3 helpers (identical across all modules)
- Lines 2794+: Component-specific code (config JSON blob, innerWorkflowFactory, meta, defaults, entrypoint workflow)

### Intermediate state (`viash-target-new/`) ← WE ARE HERE
Shared helpers extracted into a single file, per-module code slimmed down, config externalized:
- `viash-target-new/nextflow/VDSL3Helper.nf` (~1458 lines): Remaining functions not yet in plugin + thin wrappers + classes that can't be `include`d from a plugin
- `viash-target-new/nextflow/*/main.nf` (~465–866 lines each): Component-specific code + `workflowFactory` (which contains `workflow {}` DSL blocks and can't be moved to an include file)
- `viash-target-new/nextflow/*/.config.vsh.yaml`: Component config read at runtime via `readYaml()` (previously inlined as a JSON blob in each `main.nf`)
- All modules must behave identically to their `viash-target/` counterparts

### Target state
- **Plugin (`viash_core`)**: Contains all shared VDSL3 helper functions as Groovy classes/functions, exposed via `@Function`/`@Operator`/`@Factory`
- **Generated `main.nf`**: Contains only component-specific code, importing helpers from the plugin via `include { ... } from 'plugin/viash_core'`

## Plugin Package Structure

Package: `io.viash.viash_core`

```
src/main/groovy/io/viash/viash_core/
├── ViashCorePlugin.groovy              # Plugin entry point (extends BasePlugin)
├── ViashCoreExtension.groovy           # @Function methods (importable in NF scripts)
├── config/
│   ├── ConfigUtils.groovy            # processArgument, processConfig, processAuto, assertMapKeys
│   ├── DirectiveUtils.groovy         # processDirectives (with container registry override)
│   └── UnexpectedArgumentTypeException.groovy  # Custom exception class
├── io/
│   └── SerializationUtils.groovy     # JSON/YAML/CSV read/write, CustomConstructor, CustomRepresenter
├── state/
│   ├── StateUtils.groovy             # processFromState, processToState, checkUniqueIds, splitParams, paramListGuessFormat
│   └── IDChecker.groovy              # Thread-safe ID uniqueness tracker
├── help/
│   ├── HelpUtils.groovy              # generateArgumentHelp, generateHelp
│   └── TextUtils.groovy              # paragraphWrap
└── util/
    ├── CollectionUtils.groovy        # iterateMap, deepClone, mergeMap, collectFiles, collectInputOutputPaths
    └── PathUtils.groovy              # stringIsAbsolutePath, getChild, findBuildYamlFile, getRootDir
```

## Function Inventory

### In Plugin — `io.viash.viash_core.util` (CollectionUtils, PathUtils)

| Function | Plugin Method | Status | Tests |
|----------|--------------|--------|-------|
| `iterateMap` | `CollectionUtils.iterateMap()` | ✅ Done | ✅ |
| `deepClone` | `CollectionUtils.deepClone()` | ✅ Done | ✅ |
| `_mergeMap` | `CollectionUtils.mergeMap()` | ✅ Done | ✅ |
| `collectFiles` | `CollectionUtils.collectFiles()` | ✅ Done | ✅ |
| `collectInputOutputPaths` | `CollectionUtils.collectInputOutputPaths()` | ✅ Done | ✅ |
| `_stringIsAbsolutePath` | `PathUtils.stringIsAbsolutePath()` | ✅ Done | ✅ |
| `_getChild` | `PathUtils.getChild()` | ✅ Done | ✅ |
| `_findBuildYamlFile` | `PathUtils.findBuildYamlFile()` | ✅ Done | ✅ |
| `getRootDir` | `PathUtils.getRootDir()` | ✅ Done | ✅ |

### In Plugin — `io.viash.viash_core.io` (SerializationUtils)

| Function | Plugin Method | Status | Tests |
|----------|--------------|--------|-------|
| `readJsonBlob` | `SerializationUtils.readJsonBlob()` | ✅ Done | ✅ |
| `readYamlBlob` | `SerializationUtils.readYamlBlob()` | ✅ Done | ✅ |
| `readTaggedYaml` | `SerializationUtils.readTaggedYaml()` | ✅ Done | ✅ |
| `toJsonBlob` | `SerializationUtils.toJsonBlob()` | ✅ Done | ✅ |
| `toYamlBlob` | `SerializationUtils.toYamlBlob()` | ✅ Done | ✅ |
| `toTaggedYamlBlob` | `SerializationUtils.toTaggedYamlBlob()` | ✅ Done | ✅ |
| `toRelativeTaggedYamlBlob` | `SerializationUtils.toRelativeTaggedYamlBlob()` | ✅ Done | ✅ |
| `readJsonFromPath` | `SerializationUtils.readJsonFromPath()` | ✅ Done | ✅ |
| `readYamlFromPath` | `SerializationUtils.readYamlFromPath()` | ✅ Done | ✅ |
| `readCsvFromPath` | `SerializationUtils.readCsvFromPath()` | ✅ Done | ✅ |
| `writeJson` | `SerializationUtils.writeJson()` | ✅ Done | ✅ |
| `writeYaml` | `SerializationUtils.writeYaml()` | ✅ Done | ✅ |

### In Plugin — `io.viash.viash_core.config` (ConfigUtils, DirectiveUtils)

| Function | Plugin Method | Status | Tests |
|----------|--------------|--------|-------|
| `_processArgument` | `ConfigUtils.processArgument()` | ✅ Done | ✅ |
| `processConfig` | `ConfigUtils.processConfig()` | ✅ Done | ✅ |
| `processAuto` | `ConfigUtils.processAuto()` | ✅ Done | ✅ |
| `assertMapKeys` | `ConfigUtils.assertMapKeys()` | ✅ Done | ✅ |
| `processDirectives` | `DirectiveUtils.processDirectives()` | ✅ Done | ✅ |

### In Plugin — `io.viash.viash_core.help` (HelpUtils, TextUtils)

| Function | Plugin Method | Status | Tests |
|----------|--------------|--------|-------|
| `_paragraphWrap` | `TextUtils.paragraphWrap()` | ✅ Done | ✅ |
| `_generateArgumentHelp` | `HelpUtils.generateArgumentHelp()` | ✅ Done | ✅ |
| `_generateHelp` | `HelpUtils.generateHelp()` | ✅ Done | ✅ |

### In Plugin — `io.viash.viash_core.state` (StateUtils, IDChecker)

| Function | Plugin Method | Status | Tests |
|----------|--------------|--------|-------|
| `_processFromState` | `StateUtils.processFromState()` | ✅ Done | ✅ |
| `_processToState` | `StateUtils.processToState()` | ✅ Done | ✅ |
| `_checkUniqueIds` | `StateUtils.checkUniqueIds()` | ✅ Done | ✅ |
| `_splitParams` | `StateUtils.splitParams()` | ✅ Done | ✅ |
| `_paramListGuessFormat` | `StateUtils.paramListGuessFormat()` | ✅ Done | ✅ |

### In Plugin — Helper Classes

| Class | Package | Status | Tests |
|-------|---------|--------|-------|
| `UnexpectedArgumentTypeException` | `io.viash.viash_core.config` | ✅ Done | ✅ |
| `IDChecker` | `io.viash.viash_core.state` | ✅ Done | ✅ |
| `CustomConstructor` | `io.viash.viash_core.io` (in SerializationUtils.groovy) | ✅ Done | ✅ |
| `CustomRepresenter` | `io.viash.viash_core.io` (in SerializationUtils.groovy) | ✅ Done | ✅ |

### Still in VDSL3Helper.nf — Argument validation (need Nextflow context or classes)

| Function | Lines | Description | Blocker |
|----------|-------|-------------|---------|
| `_checkArgumentType` | 84–148 | Validate & cast argument values | Uses `UnexpectedArgumentTypeException` class; could move to plugin |
| `_processInputValues` | 199–218 | Validate required inputs | Throws assertion with config context |
| `_checkValidOutputArgument` | 220–233 | Validate output argument | Simple validation |
| `_checkAllRequiredOutputsPresent` | 235–245 | Assert all required outputs | Simple validation |

### Still in VDSL3Helper.nf — Param/channel handling (needs `params`, `Channel`, `file()`)

| Function | Lines | Description | Blocker |
|----------|-------|-------------|---------|
| `_paramsToParamSets` | 306–375 | Parse params to channel events | Needs `params`, `file()` |
| `_channelFromParams` | 375–379 | Create channel from params | Needs `Channel` |
| `_parseParamList` | 391–464 | Parse param_list file | Needs `file()`, plugin serialization fns |
| `readCsv` | 793–848 | Read CSV file (NF-aware) | Needs `file()` — `readCsvFromPath` is in plugin |
| `readJson` | 850–855 | Read JSON file (NF-aware) | Needs `file()` — `readJsonFromPath` is in plugin |
| `readYaml` | 857–862 | Read YAML file (NF-aware) | Needs `file()` — `readYamlFromPath` is in plugin |
| `readConfig` | 711–723 | Read & process config | Needs `readYaml`, `moduleDir` |
| `_resolveSiblingIfNotAbsolute` | 725–735 | Resolve relative paths | Needs `file()` |

### Still in VDSL3Helper.nf — Config/workflow helpers (needs `params` or NF DSL)

| Function | Lines | Description | Blocker |
|----------|-------|-------------|---------|
| `addGlobalArguments` | 657–698 | Add --publish_dir, --param_list args | Pure logic, could move to plugin |
| `helpMessage` | 700–709 | Print help & exit | Needs `log`, could move |
| `getPublishDir` | 769–778 | Get publish directory | Needs `params` |
| `processDirectives` (wrapper) | 1353–1357 | Thin wrapper calling plugin fn | Needs `params` for `override_container_registry` |
| `processWorkflowArgs` | 1359–1450 | Process .run() arguments | Needs `processDirectives` wrapper, complex |
| `_debug` | 1452–1458 | Conditional debug view | Trivial |

### Still in VDSL3Helper.nf — Classes (can't be `include`d from plugin)

| Class | Lines | Description | Blocker |
|-------|-------|-------------|---------|
| `UnexpectedArgumentTypeException` | 55–81 | Custom exception | **Duplicate** — also in plugin; NF can't import classes from plugin |
| `IDChecker` | 253–305 | Thread-safe ID tracker | **Duplicate** — also in plugin; needed by `checkUniqueIds` channel operator |
| `CustomTraceObserver` | 737–757 | Collect process traces | NF-specific; could potentially move |

### Still in VDSL3Helper.nf — Workflow/channel operators (contain `workflow {}` DSL)

| Function | Lines | Description | Blocker |
|----------|-------|-------------|---------|
| `checkUniqueIds` | 468–500 | Channel operator for ID uniqueness | Contains `workflow {}` |
| `runEach` | 502–619 | Run multiple components on channel | Contains `workflow {}` |
| `safeJoin` | 621–655 | Join channels with error handling | Uses `IDChecker` class |
| `findStates` | 864–979 | Discover state files | Contains `workflow {}` |
| `joinStates` | 980–996 | Join states workflow | Contains `workflow {}` |
| `publishFiles` | 998–1055 | Publish output files | Contains `workflow {}` + `process {}` |
| `publishFilesByConfig` | 1057–1150 | Publish files using config | Contains `workflow {}` |
| `publishStates` | 1152–1205 | Publish state YAML files | Contains `workflow {}` + `process {}` |
| `publishStatesByConfig` | 1207–1312 | Publish states using config | Contains `workflow {}` |
| `setState` | 1313–1351 | Channel operator to update state | Uses `map {}` channel op |
| `niceView` | 780–791 | Pretty-print channel debug | Contains `workflow {}` |
| `collectTraces` | 759–767 | Register trace observer | Uses NF session |

### Component-specific (STAYS in each main.nf)

| Item | Description |
|------|-------------|
| `meta` object | Reads config from `.config.vsh.yaml`, resources_dir |
| `innerWorkflowFactory` | Component's script or workflow reference |
| `vdsl3WorkflowFactory` | Dynamic process creation for script components |
| `_vdsl3ProcessFactory` | Runtime process generation |
| `_getScriptLoader` | NF version compat for script loading |
| `meta["defaults"]` | Default .run() arguments |
| `meta["workflow"]` | Default workflow instance |
| `workflowFactory` | Creates reusable VDSL3 workflow with .run()/.config (~300 lines) |
| Anonymous `workflow` | Standalone entrypoint |

## Phased Work Plan

### Phase 0: Environment & verification setup ✅ DONE
- [x] Verify `make assemble` / `make test` work
- [x] Create a verification script (`scripts/verify.sh`) that builds plugin, installs it, and runs a simple NF pipeline
- [x] Document current test baseline
- [x] Create `viash-target-new/` with extracted `VDSL3Helper.nf` and slim `main.nf` files
- [x] Verify all test_wfs pass with `nextflow run viash-target-new/nextflow/test_wfs/.../main.nf`

### Phase 1: Move pure functions into plugin ✅ DONE
- [x] Create Groovy source files in `io.viash.viash_core.*` subpackages
- [x] Move serialization functions (readJsonBlob, readYamlBlob, readCsvFromPath, toJsonBlob, etc.)
- [x] Move helper classes (UnexpectedArgumentTypeException, IDChecker, CustomConstructor, CustomRepresenter)
- [x] Move utility functions (deepClone, iterateMap, collectFiles, etc.)
- [x] Move config processing (processArgument, processConfig, processAuto, assertMapKeys)
- [x] Move directive processing (processDirectives with container registry override)
- [x] Move help generation (generateArgumentHelp, generateHelp, paragraphWrap)
- [x] Move state processing (processFromState, processToState, checkUniqueIds, splitParams)
- [x] Move path utilities (stringIsAbsolutePath, getChild, findBuildYamlFile, getRootDir)
- [x] Write 100 unit tests across 10 test classes
- [x] Verify `make test` passes (100 tests, 0 failures)
- [x] Update `VDSL3Helper.nf` to import from plugin instead of defining inline
- [x] Reduce VDSL3Helper.nf from ~2480 → ~1458 lines
- [x] Verify all test_wfs still pass

### Phase 2: Move argument validation into plugin
- [ ] Move `_checkArgumentType` to `config/ConfigUtils.groovy`
- [ ] Move `_processInputValues`, `_checkValidOutputArgument`, `_checkAllRequiredOutputsPresent` to `config/ConfigUtils.groovy`
- [ ] Move `addGlobalArguments` to `config/ConfigUtils.groovy`
- [ ] Move `helpMessage` to `help/HelpUtils.groovy`
- [ ] Write unit tests for each
- [ ] Update VDSL3Helper.nf imports
- [ ] Verify `make test` + integration tests pass

### Phase 3: Move param/channel handling helpers
- [ ] Move `_paramsToParamSets` pure logic to `state/StateUtils.groovy` (NF-dependent parts stay as thin wrapper)
- [ ] Move `_parseParamList` pure logic to `state/StateUtils.groovy`
- [ ] Move `_resolveSiblingIfNotAbsolute` to `util/PathUtils.groovy`
- [ ] Create NF-aware wrappers in VDSL3Helper.nf for functions needing `file()` or `params`
- [ ] Write unit tests
- [ ] Verify `make test` + integration tests pass

### Phase 4: Move processWorkflowArgs and remaining logic
- [ ] Move `processWorkflowArgs` pure logic to plugin (NF-dependent parts stay as wrapper)
- [ ] Move `_debug` to plugin if feasible
- [ ] Eliminate duplicate class definitions in VDSL3Helper.nf (UnexpectedArgumentTypeException, IDChecker)
- [ ] Target: VDSL3Helper.nf should be mostly workflow/channel operators + thin NF wrappers
- [ ] Write unit tests
- [ ] Verify `make test` + integration tests pass

### Phase 5: Address workflow/channel operators
- [ ] Investigate moving `setState`, `checkUniqueIds`, `safeJoin` to plugin as `@Operator`
- [ ] Investigate if `runEach` logic can be partially moved to plugin
- [ ] Investigate `findStates`, `publishFiles`, `publishStates` — these contain `workflow {}` + `process {}` blocks
- [ ] These may need to stay in VDSL3Helper.nf or require creative solutions
- [ ] Write integration tests

### Phase 6: Address workflowFactory (HARDEST)
- [ ] `workflowFactory` (~300 lines in each main.nf) contains `workflow {}` DSL blocks
- [ ] Can't be defined in plugin code directly
- [ ] Investigate extracting pure-logic helpers into plugin, keeping DSL shell in main.nf
- [ ] Write integration tests
- [ ] Verify with actual NF pipeline run

### Phase 7: Update viash code generation
- [ ] Modify what viash generates: slim main.nf with plugin imports
- [ ] Remove shared VDSL3 code from generated output
- [ ] Integration test with full pipeline
- [ ] Document breaking changes / deprecations

## Known Issues
- `filter_runif` and `fromstate_tostate` test_wfs fail with **both** viash-target and viash-target-new — pre-existing bugs, not related to plugin migration
- `empty_workflow`, `invalid_fromstate_argument`, `invalid_tostate_argument` produce expected errors (they test error handling)

## Open Questions
- Can `workflowFactory` (which creates NF workflows dynamically) work from a plugin, or does it need to stay in generated code?
- How will `vdsl3WorkflowFactory` / `_vdsl3ProcessFactory` (dynamic process creation) interact with plugin scope?
- What's the right NF plugin extension point for `runEach` — it creates a workflow internally?
- Can we eliminate the duplicate UnexpectedArgumentTypeException/IDChecker classes in VDSL3Helper.nf? (NF can't `include` classes from plugins)

## Verification Checklist
After each phase:
1. `make assemble` succeeds
2. `make test` (Groovy unit tests) passes — currently 100 tests
3. `make install` succeeds
4. All test_wfs pass: `nextflow run viash-target-new/nextflow/test_wfs/<name>/main.nf --publish_dir output` exits 0
5. Clean up: `rm -rf .nextflow* work output`

Test workflows to verify (all under `viash-target-new/nextflow/test_wfs/`):
- `alias` — tests component aliasing via `.run(key:)` — ✅ passes
- `concurrency` — 1000 items through step1→step1bis with fromState/toState closures — ✅ passes
- `empty_workflow` — passthrough + empty emit channel — ✅ expected error
- `filter_runif` — tests `filter:` and `runIf:` parameters — ❌ pre-existing bug
- `fromstate_tostate` — tests fromState/toState as List, Map, and Closure — ❌ pre-existing bug
- `invalid_fromstate_argument` — expects error on bad fromState key — ✅ expected error
- `invalid_tostate_argument` — expects error on bad toState key — ✅ expected error
- `nested` — nested sub_workflow invocation — ✅ passes
- `runeach` — `runEach()` with 26 component variants × 101 items — ✅ passes
