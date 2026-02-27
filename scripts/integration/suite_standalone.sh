#!/bin/bash
# Test suite: Vdsl3StandaloneTest
# Tests for running VDSL3 components as standalone Nextflow workflows.
# Mirrors: https://github.com/viash-io/viash/blob/main/src/test/scala/io/viash/runners/nextflow/Vdsl3StandaloneTest.scala
# Sourced by run.sh — do not run directly.

run_standalone_tests() {
  suite_header "Vdsl3StandaloneTest (standalone component runs)"

  local publish_dir

  # ── Simple run ──────────────────────────────────────────────────────
  # Original: test("Simple run", NextflowTest)
  local test_name="standalone: Simple run"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/moduleOutput1"
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
  # Original: test("With id containing spaces and slashes", NextflowTest)
  test_name="standalone: With id containing spaces and slashes"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/moduleOutput2"
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
  # Original: test("With output id and key keywords", NextflowTest)
  test_name="standalone: With output id and key keywords"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/moduleOutput3"
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
  # Original: test("With yamlblob param_list", NextflowTest)
  test_name="standalone: With yamlblob param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/moduleOutput4"
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

  # ── With yaml param_list ────────────────────────────────────────────
  # Original: test("With yaml param_list", NextflowTest)
  # Creates a param_list.yaml with relative paths, resolved relative to the yaml file location
  test_name="standalone: With yaml param_list"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/moduleOutput5"
    # Create a param_list.yaml alongside the resource files
    local yaml_dir="$TEST_WORKDIR/yaml_paramlist"
    mkdir -p "$yaml_dir"
    ln -sf "$RESOURCES_DIR/lines3.txt" "$yaml_dir/lines3.txt"
    ln -sf "$RESOURCES_DIR/lines5.txt" "$yaml_dir/lines5.txt"
    cat > "$yaml_dir/param_list.yaml" <<'YAML'
- input1: lines3.txt
  input2: lines5.txt
YAML

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --param_list "$yaml_dir/param_list.yaml" \
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

  # ── With optional inputs ────────────────────────────────────────────
  # Original: test("With optional inputs", NextflowTest)
  test_name="standalone: With optional inputs"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/moduleOutput6"
    local optional_file="$TEST_WORKDIR/lines5-bis.txt"
    cp "$RESOURCES_DIR/lines5.txt" "$optional_file"

    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/step2/main.nf" \
      --input1 "$RESOURCES_DIR/lines3.txt" \
      --input2 "$RESOURCES_DIR/lines5.txt" \
      --optional "$optional_file" \
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
  # Original: test("Run multiple output test", NextflowTest)
  test_name="standalone: Run multiple output test"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/multipleOutput"
    nf_run_cwd "$PROJECT_DIR" \
      "$TARGET_DIR/multiple_output/main.nf" \
      --id foo \
      --input "$RESOURCES_DIR/lines*.txt" \
      --publish_dir "$publish_dir"

    local state_file="$publish_dir/foo.multiple_output.state.yaml"
    local output0_file="$publish_dir/foo.multiple_output.output_0.txt"
    local output1_file="$publish_dir/foo.multiple_output.output_1.txt"

    if [[ $NF_EXIT -eq 0 ]] && \
       assert_file_exists "$state_file" && \
       assert_file_exists "$output0_file" && \
       assert_file_exists "$output1_file"; then
      # Check state.yaml content
      local state_content
      state_content=$(cat "$state_file")
      local expected_state
      expected_state=$(printf "id: foo\noutput:\n- !file 'foo.multiple_output.output_0.txt'\n- !file 'foo.multiple_output.output_1.txt'")
      if [[ "$state_content" == "$expected_state" ]]; then
        pass "$test_name"
      else
        fail "$test_name" "state.yaml content mismatch"
        if [[ "$VERBOSE" == "true" ]]; then
          echo "       Expected: $expected_state" >&2
          echo "       Actual:   $state_content" >&2
        fi
      fi
    else
      fail "$test_name" "exit=$NF_EXIT"
      show_failure "$test_name"
    fi
  fi

  # ── Integer as double ──────────────────────────────────────────────
  # Original: test("Whether integers can be converted to doubles", NextflowTest)
  test_name="standalone: Whether integers can be converted to doubles"
  if should_run "$test_name"; then
    publish_dir="$TEST_WORKDIR/integerAsDouble"
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
}
