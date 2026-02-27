#!/bin/bash
# Test suite: NextflowScriptTest
# Tests for Nextflow script features (test workflows, symlinks, etc.)
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/NextflowScriptTest.scala
# Sourced by run.sh — do not run directly.

run_script_tests() {
  suite_header "NextflowScriptTest (test workflows)"

  local publish_dir

  # ── Run config pipeline ─────────────────────────────────────────────
  # Original: test("Run config pipeline", NextflowTest)
  local test_name="script: Run config pipeline"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_config_pipeline"
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

  # ── Run config pipeline with symlink ────────────────────────────────
  # Original: test("Run config pipeline with symlink", NextflowTest)
  test_name="script: Run config pipeline with symlink"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_symlink"
    local symlink_dir="$TEST_WORKDIR/workflowsAsSymlink"
    mkdir -p "$symlink_dir"
    ln -sfn "$TARGET_DIR/wf" "$symlink_dir/workflow"

    nf_run_cwd "$PROJECT_DIR" \
      "$symlink_dir/workflow/main.nf" \
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

  # ── Run config pipeline with subworkflow dependency and symlinks ────
  # Original: test("Run config pipeline with subworkflow dependency and symlinks", NextflowTest)
  test_name="script: Run with subworkflow dependency symlinks"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_nested_symlink"
    local symlink_dir="$TEST_WORKDIR/nestedWorkflowsAsSymlink"
    mkdir -p "$symlink_dir"
    ln -sfn "$TARGET_DIR/test_wfs" "$symlink_dir/workflow"

    nf_run_cwd "$PROJECT_DIR" \
      "$symlink_dir/workflow/nested/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test workflow ───────────────────────────────────────────────────
  # Original: test("Test workflow", DockerTest, NextflowTest)
  test_name="script: Test workflow"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_test_workflow"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/wf/main.nf" \
      -entry test_base \
      --rootDir "$PROJECT_DIR" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test fromState/toState ──────────────────────────────────────────
  # Original: test("Test fromState/toState", DockerTest, NextflowTest)
  test_name="script: Test fromState/toState"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_fromstate_tostate"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/fromstate_tostate/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test filter/runIf ──────────────────────────────────────────────
  # Original: test("Test filter/runIf", DockerTest, NextflowTest)
  test_name="script: Test filter/runIf"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_filter_runif"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/filter_runif/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test alias ──────────────────────────────────────────────────────
  # Original: test("Test whether aliasing works", DockerTest, NextflowTest)
  test_name="script: Test whether aliasing works"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_alias"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/alias/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      # Check stdout for alias-specific process names
      # Nextflow 23.04+ changed process name format in logs
      local alias_ok=true
      if ! (echo "$NF_STDOUT" | grep -qE ':step1_alias:proc|:step1_alias_process'); then
        echo "       Expected stdout to contain step1_alias process execution" >&2
        alias_ok=false
      fi
      if ! (echo "$NF_STDOUT" | grep -qE ':step1:proc|:step1_process'); then
        echo "       Expected stdout to contain step1 process execution" >&2
        alias_ok=false
      fi
      if echo "$NF_STDOUT" | grep -qF "Key for module 'step1' is duplicated"; then
        echo "       Unexpected: stdout contains key duplication warning" >&2
        alias_ok=false
      fi

      if $alias_ok; then
        pass "$test_name"
      else
        fail "$test_name" "alias stdout assertions failed"
        show_failure "$test_name"
      fi
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test concurrency ───────────────────────────────────────────────
  # Original: test("Test for concurrency issues", DockerTest, NextflowTest)
  test_name="script: Test for concurrency issues"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_concurrency"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/concurrency/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test runEach ───────────────────────────────────────────────────
  # Original: test("Test runEach", DockerTest, NextflowTest)
  test_name="script: Test runEach"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_runeach"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/runeach/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test nested workflows ──────────────────────────────────────────
  # Original: test("Test nested workflows", DockerTest, NextflowTest)
  test_name="script: Test nested workflows"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_nested"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/nested/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test invalid argument in fromState map ──────────────────────────
  # Original: test("Test invalid argument in fromState map", DockerTest, NextflowTest)
  test_name="script: Test invalid argument in fromState map"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_invalid_fromstate"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/invalid_fromstate_argument/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 1 ]]; then
      local expected_msg="Error processing fromState for 'sub_workflow': invalid argument 'thisargumentdoesnotexist'"
      if echo "$NF_STDOUT" | grep -qF "$expected_msg"; then
        pass "$test_name"
      else
        fail "$test_name" "Expected error message not found"
        show_failure "$test_name"
      fi
    else
      fail "$test_name" "Expected exit code 1, got $NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Test invalid argument in toState map ────────────────────────────
  # Original: test("Test invalid argument in toState map", DockerTest, NextflowTest)
  test_name="script: Test invalid argument in toState map"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_invalid_tostate"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/invalid_tostate_argument/main.nf" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 1 ]]; then
      local expected_msg="Error processing toState for 'sub_workflow': invalid argument 'thisargumentdoesnotexist'"
      if echo "$NF_STDOUT" | grep -qF "$expected_msg"; then
        pass "$test_name"
      else
        fail "$test_name" "Expected error message not found"
        show_failure "$test_name"
      fi
    else
      fail "$test_name" "Expected exit code 1, got $NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run multiple output channels standalone ─────────────────────────
  # Original: test("Run multiple output channels standalone", NextflowTest)
  test_name="script: Run multiple output channels standalone"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_multi_emit"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/multiple_emit_channels/main.nf" \
      --id foo \
      --input "$RESOURCES_DIR/lines5.txt" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run multiple output channels check output ──────────────────────
  # Original: test("Run multiple output channels check output", DockerTest, NextflowTest)
  test_name="script: Run multiple output channels check output"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_multi_emit_test"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/multiple_emit_channels/main.nf" \
      -entry test_base \
      --rootDir "$PROJECT_DIR" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Check whether --help works ──────────────────────────────────────
  # Original: test("Check whether --help is same as Viash's --help", NextflowTest)
  test_name="script: Check whether --help works"
  if should_run "$test_name"; then
    NF_QUIET=true
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/wf/main.nf" \
      --help
    NF_QUIET=

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi
}
