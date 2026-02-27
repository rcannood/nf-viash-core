#!/bin/bash
# Test suite: WorkflowHelperTest
# Tests for param_list processing with various input formats.
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/WorkflowHelperTest.scala
# Sourced by run.sh — do not run directly.
#
# The empty_workflow component's run_wf prints "DEBUG: [id, [key:value, ...]]"
# for each processed event. We parse these to verify argument values, matching
# the original Scala test's outputTupleProcessor + checkDebugArgs pattern.

# Expected checks for "foo" sample (from WorkflowHelperTest.scala)
# MatchCheck("input", ".*/lines3.txt")
# EqualsCheck("real_number", "10.5")
# EqualsCheck("whole_number", "3")
# EqualsCheck("str", "foo")
# NotAvailCheck("reality")
# NotAvailCheck("optional")
# EqualsCheck("optional_with_default", "foo")
# EqualsCheck("multiple", "[a, b, c]")
_check_foo_args() {
  check_debug_args "foo" "DEBUG" \
    "match:input:.*/lines3.txt" \
    "equals:real_number:10.5" \
    "equals:whole_number:3" \
    "equals:str:foo" \
    "notavail:reality" \
    "notavail:optional" \
    "equals:optional_with_default:foo" \
    "equals:multiple:[a, b, c]"
}

# Expected checks for "bar" sample (from WorkflowHelperTest.scala)
# MatchCheck("input", ".*/lines5.txt")
# EqualsCheck("real_number", "0.5")
# EqualsCheck("whole_number", "10")
# EqualsCheck("str", "foo")
# EqualsCheck("reality", "true")
# EqualsCheck("optional", "bar")
# EqualsCheck("optional_with_default", "The default value.")
# NotAvailCheck("multiple")
_check_bar_args() {
  check_debug_args "bar" "DEBUG" \
    "match:input:.*/lines5.txt" \
    "equals:real_number:0.5" \
    "equals:whole_number:10" \
    "equals:str:foo" \
    "equals:reality:true" \
    "equals:optional:bar" \
    "equals:optional_with_default:The default value." \
    "notavail:multiple"
}

run_helper_tests() {
  suite_header "WorkflowHelperTest (param_list & config handling)"

  local publish_dir

  # ── Run config pipeline (CLI args) ──────────────────────────────────
  # Original: test("Run config pipeline", NextflowTest)
  local test_name="helper: Run config pipeline"
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

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run config pipeline with yamlblob ───────────────────────────────
  # Original: test("Run config pipeline with yamlblob", NextflowTest)
  test_name="helper: Run config pipeline with yamlblob"
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

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args && _check_bar_args && \
       assert_debug_input_endswith "foo" "$RESOURCES_DIR/lines3.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run config pipeline with yaml file ──────────────────────────────
  # Original: test("Run config pipeline with yaml file", NextflowTest)
  test_name="helper: Run config pipeline with yaml file"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_yaml_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "$RESOURCES_DIR/pipeline3.yaml" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args && _check_bar_args && \
       assert_debug_input_endswith "foo" "$RESOURCES_DIR/lines3.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run config pipeline with yaml file as relative path ─────────────
  # Original: test("Run config pipeline with yaml file passed as a relative path", NextflowTest)
  test_name="helper: Run config pipeline with yaml relative path"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_yaml_relative"

    # Run from the resources directory with a relative param_list path
    # and a relative main-script path (relative to resources dir CWD)
    local rel_main_script
    rel_main_script=$(realpath --relative-to="$RESOURCES_DIR" "$TARGET_DIR/test_wfs/empty_workflow/main.nf")

    nf_run_cwd "$RESOURCES_DIR" \
      "$rel_main_script" \
      --param_list "pipeline3.yaml" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args && _check_bar_args && \
       assert_debug_input_endswith "foo" "$RESOURCES_DIR/lines3.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run config pipeline with json file ──────────────────────────────
  # Original: test("Run config pipeline with json file", NextflowTest)
  test_name="helper: Run config pipeline with json file"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_json_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "$RESOURCES_DIR/pipeline3.json" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args && _check_bar_args && \
       assert_debug_input_endswith "foo" "$RESOURCES_DIR/lines3.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run config pipeline with csv file ───────────────────────────────
  # Original: test("Run config pipeline with csv file", NextflowTest)
  test_name="helper: Run config pipeline with csv file"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_csv_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      --param_list "$RESOURCES_DIR/pipeline3.csv" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args && _check_bar_args && \
       assert_debug_input_endswith "foo" "$RESOURCES_DIR/lines3.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Run config pipeline asis (default nextflow implementation) ──────
  # Original: test("Run config pipeline asis, default nextflow implementation", NextflowTest)
  test_name="helper: Run config pipeline asis"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/helper_asis"

    nf_run_params \
      "$TARGET_DIR/test_wfs/empty_workflow/main.nf" \
      "$RESOURCES_DIR/pipeline3.asis.yaml" \
      --real_number 10.5 \
      --whole_number 10 \
      --str foo \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && _check_foo_args && _check_bar_args && \
       assert_debug_input_endswith "foo" "$RESOURCES_DIR/lines3.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi
}
