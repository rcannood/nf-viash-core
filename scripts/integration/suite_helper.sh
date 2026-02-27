#!/bin/bash
# Test suite: WorkflowHelperTest
# Tests for param_list processing with various input formats.
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/WorkflowHelperTest.scala
# Sourced by run.sh — do not run directly.

run_helper_tests() {
  suite_header "WorkflowHelperTest (param_list & config handling)"

  local publish_dir

  # ── Run empty_workflow with CLI args ────────────────────────────────
  local test_name="helper: empty_workflow with CLI args"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_cli"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --id foo \
      --input "$RESOURCES_DIR/lines3.txt" \
      --real_number 10.5 \
      --whole_number 3 \
      --str foo \
      --optional_with_default foo \
      --multiple "a;b;c" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run empty_workflow with yamlblob param_list ─────────────────────
  test_name="helper: empty_workflow with yamlblob param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_yamlblob"
    local foo_args="{id: foo, input: $RESOURCES_DIR/lines3.txt, whole_number: 3, optional_with_default: foo, multiple: [a, b, c]}"
    local bar_args="{id: bar, input: $RESOURCES_DIR/lines5.txt, real_number: 0.5, optional: bar, reality: true}"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "[$foo_args, $bar_args]" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run empty_workflow with yaml file param_list ────────────────────
  test_name="helper: empty_workflow with yaml file param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_yaml_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "$RESOURCES_DIR/pipeline3.yaml" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run empty_workflow with json file param_list ────────────────────
  test_name="helper: empty_workflow with json file param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_json_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "$RESOURCES_DIR/pipeline3.json" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run empty_workflow with csv file param_list ─────────────────────
  test_name="helper: empty_workflow with csv file param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_csv_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "$RESOURCES_DIR/pipeline3.csv" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run empty_workflow with asis params-file ────────────────────────
  test_name="helper: empty_workflow with asis params-file"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_asis"

    nf_run_params \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      "$RESOURCES_DIR/pipeline3.asis.yaml" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi
}
