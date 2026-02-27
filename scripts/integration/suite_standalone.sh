#!/bin/bash
# Test suite: Vdsl3StandaloneTest
# Tests for running VDSL3 components as standalone Nextflow workflows.
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/Vdsl3StandaloneTest.scala
# Sourced by run.sh — do not run directly.

run_standalone_tests() {
  suite_header "Vdsl3StandaloneTest (standalone component runs)"

  local publish_dir

  # ── Simple run ──────────────────────────────────────────────────────
  local test_name="standalone: Simple run of step2"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_simple"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --input1 "$RESOURCES_DIR/lines3.txt" \
      --input2 "$RESOURCES_DIR/lines5.txt" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$publish_dir/run.step2.output1.txt" && \
       assert_file_content "$publish_dir/run.step2.output1.txt" "one,two,three"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── ID with spaces and slashes ──────────────────────────────────────
  test_name="standalone: ID with spaces and slashes"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_spaces"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --id "one two three/four five six/seven eight nine" \
      --input1 "$RESOURCES_DIR/lines3.txt" \
      --input2 "$RESOURCES_DIR/lines5.txt" \
      --publish_dir "$publish_dir"

    local expected_file="$publish_dir/one two three/four five six/seven eight nine.step2.output1.txt"
    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$expected_file" && \
       assert_file_content "$expected_file" "one,two,three"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Output ID and key keywords ─────────────────────────────────────
  test_name="standalone: Output with \$id and \$key keywords"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_keywords"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --id foo \
      --input1 "$RESOURCES_DIR/lines3.txt" \
      --input2 "$RESOURCES_DIR/lines5.txt" \
      --output1 '$id.${id}.$key.${key}.txt' \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$publish_dir/foo.foo.step2.step2.txt" && \
       assert_file_content "$publish_dir/foo.foo.step2.step2.txt" "one,two,three"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── With yamlblob param_list ────────────────────────────────────────
  test_name="standalone: yamlblob param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_yamlblob"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --param_list "[{input1: $RESOURCES_DIR/lines3.txt, input2: $RESOURCES_DIR/lines5.txt}]" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$publish_dir/run.step2.output1.txt" && \
       assert_file_content "$publish_dir/run.step2.output1.txt" "one,two,three"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── With yaml file param_list ───────────────────────────────────────
  test_name="standalone: yaml file param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_yaml_file"
    local param_list="$RESOURCES_DIR/pipeline3.yaml"
    nf_run_cwd "$RESOURCES_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --param_list "$param_list" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]]; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── With optional inputs ────────────────────────────────────────────
  test_name="standalone: Optional inputs"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_optional"
    cp "$RESOURCES_DIR/lines5.txt" "$TEST_WORKDIR/lines5-bis.txt"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --input1 "$RESOURCES_DIR/lines3.txt" \
      --input2 "$RESOURCES_DIR/lines5.txt" \
      --optional "$TEST_WORKDIR/lines5-bis.txt" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$publish_dir/run.step2.output1.txt" && \
       assert_file_content "$publish_dir/run.step2.output1.txt" "one,two,three,1,2,3,4,5"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Multiple output ────────────────────────────────────────────────
  test_name="standalone: Multiple output"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_multi_output"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/multiple_output/main.nf" \
      --id foo \
      --input "$RESOURCES_DIR/lines*.txt" \
      --publish_dir "$publish_dir"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$publish_dir/foo.multiple_output.output_0.txt" && \
       assert_file_exists "$publish_dir/foo.multiple_output.output_1.txt"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Integer as double ──────────────────────────────────────────────
  test_name="standalone: Integer converted to double"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/standalone_int_double"
    local params_file="$TEST_WORKDIR/int_double_params.yaml"
    cat > "$params_file" <<EOF
id: foo
input: $RESOURCES_DIR/lines3.txt
double: 10
publish_dir: $publish_dir
EOF
    nf_run_params \
      "$TARGET_DIR/integer_as_double/main.nf" \
      "$params_file"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$publish_dir/foo.integer_as_double.output.txt" && \
       assert_file_content "$publish_dir/foo.integer_as_double.output.txt" "one,two,three,Double: 10.0"; then
      pass "$test_name"
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Help output ────────────────────────────────────────────────────
  test_name="standalone: --help does not error"
  if should_run "$test_name"; then
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
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
