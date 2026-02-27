#!/bin/bash
# Test suite: Vdsl3ModuleTest
# Tests for running VDSL3 modules as part of a pipeline.
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/Vdsl3ModuleTest.scala
# Sourced by run.sh — do not run directly.
#
# NOTE: The original Scala test runs workflows/pipeline1/main.nf (a hand-written
# pipeline that chains step1→step2→step3) with -entry base. We don't have that
# file; the closest equivalent is wf/main.nf -entry test_base, which runs the
# same pipeline with built-in test data and internal assertions. The original
# test is tagged DockerTest, meaning it requires Docker to run the step processes.

run_module_tests() {
  suite_header "Vdsl3ModuleTest (pipeline runs)"

  local publish_dir

  # ── Run pipeline ────────────────────────────────────────────────────
  # Original: test("Run pipeline", DockerTest, NextflowTest)
  # Original runs: workflows/pipeline1/main.nf -entry base --publish_dir output
  # Adapted: wf/main.nf -entry test_base (provides its own test data + assertions)
  local test_name="module: Run pipeline"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/module_pipeline"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/wf/main.nf" \
      -entry test_base \
      --rootDir "$PROJECT_DIR" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      # The test_base entry has internal assertions that verify:
      # - Output channel has exactly 1 event
      # - Event has [id, state] format with id == "foo"
      # - state.output file exists and content matches '^11 .*$'
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi
}
