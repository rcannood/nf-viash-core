#!/bin/bash
# Test suite: Vdsl3ModuleTest
# Tests for running VDSL3 modules as part of a pipeline.
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/Vdsl3ModuleTest.scala
# Sourced by run.sh — do not run directly.

run_module_tests() {
  suite_header "Vdsl3ModuleTest (pipeline runs)"

  local publish_dir

  # ── Run pipeline (wf component) ─────────────────────────────────────
  local test_name="module: Run pipeline (wf)"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/module_pipeline"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/wf/main.nf" \
      -entry base \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run wf standalone (default entry) ───────────────────────────────
  test_name="module: Run wf standalone"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/module_wf_standalone"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/wf/main.nf" \
      --id foo \
      --input1 "$RESOURCES_DIR/lines*.txt" \
      --input2 "$RESOURCES_DIR/lines3.txt" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi
}
