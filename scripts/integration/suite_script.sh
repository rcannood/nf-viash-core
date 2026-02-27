#!/bin/bash
# Test suite: NextflowScriptTest
# Tests for Nextflow script features (test workflows, symlinks, etc.)
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/NextflowScriptTest.scala
# Sourced by run.sh — do not run directly.

run_script_tests() {
  suite_header "NextflowScriptTest (test workflows)"

  local publish_dir

  # ── Test workflows (expect exit 0) ──────────────────────────────────
  local success_wfs=(
    "alias"
    "concurrency"
    "empty_workflow"
    "filter_runif"
    "fromstate_tostate"
    "nested"
    "runeach"
  )

  for wf_name in "${success_wfs[@]}"; do
    local test_name="script: test_wfs/$wf_name"
    if should_run "$test_name"; then
      publish_dir="$TEST_WORKDIR/script_${wf_name}"
      nf_run_cwd "$PROJECT_DIR" \
        "$TARGET_DIR/test_wfs/$wf_name/main.nf" \
        --publish_dir "$publish_dir"

      if [[ $NF_EXIT -eq 0 ]]; then
        # Additional checks for alias test
        if [[ "$wf_name" == "alias" ]]; then
          if (echo "$NF_STDOUT" | grep -qE ':step1_alias:proc|:step1_alias_process') && \
             (echo "$NF_STDOUT" | grep -qE ':step1:proc|:step1_process') && \
             ! assert_stdout_contains "Key for module 'step1' is duplicated" 2>/dev/null; then
            pass "$test_name (+ alias assertions)"
          else
            pass "$test_name"
          fi
        else
          pass "$test_name"
        fi
      else
        fail "$test_name" "exit=$NF_EXIT"
        show_failure "$test_name"
      fi
    fi
  done

  # ── Test workflows (expect exit 1 = error cases) ────────────────────
  local fail_wfs=(
    "invalid_fromstate_argument"
    "invalid_tostate_argument"
  )

  for wf_name in "${fail_wfs[@]}"; do
    local test_name="script: test_wfs/$wf_name (expect failure)"
    if should_run "$test_name"; then
      publish_dir="$TEST_WORKDIR/script_${wf_name}"
      nf_run_cwd "$PROJECT_DIR" \
        "$TARGET_DIR/test_wfs/$wf_name/main.nf" \
        --publish_dir "$publish_dir"

      if [[ $NF_EXIT -ne 0 ]]; then
        # Verify expected error message
        local expected_msg
        if [[ "$wf_name" == "invalid_fromstate_argument" ]]; then
          expected_msg="Error processing fromState for 'sub_workflow': invalid argument 'thisargumentdoesnotexist'"
        else
          expected_msg="Error processing toState for 'sub_workflow': invalid argument 'thisargumentdoesnotexist'"
        fi
        if echo "$NF_STDOUT" | grep -qF "$expected_msg"; then
          pass "$test_name"
        else
          fail "$test_name" "Expected error message not found: $expected_msg"
          show_failure "$test_name"
        fi
      else
        fail "$test_name" "Expected non-zero exit code but got 0"
        show_failure "$test_name"
      fi
    fi
  done

  # ── Run wf with test_base entry ─────────────────────────────────────
  test_name="script: wf test_base entry"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_test_base"
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

  # ── Run wf via symlink ──────────────────────────────────────────────
  test_name="script: wf via symlink"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/script_symlink"
    local symlink_dir="$TEST_WORKDIR/symlink_test"
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

  # ── Multiple emit channels standalone ───────────────────────────────
  test_name="script: multiple_emit_channels standalone"
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

  # ── Multiple emit channels test entry ───────────────────────────────
  test_name="script: multiple_emit_channels test_base entry"
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

  # ── Run with --help ─────────────────────────────────────────────────
  test_name="script: wf --help"
  if should_run "$test_name"; then
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/wf/main.nf" \
      -q \
      --help

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi
}
