#!/bin/bash
# Test suite: Cross-validation
# Compares viash-target-new output vs viash-target (reference) output.
# Sourced by run.sh — do not run directly.

run_cross_validation() {
  suite_header "Cross-validation (viash-target-new vs viash-target)"

  if [[ ! -d "$REFERENCE_DIR" ]]; then
    skip "Reference directory not found: $REFERENCE_DIR"
    return
  fi

  # Compare each standalone module's output
  local modules=("step1" "step2" "step3")

  for mod in "${modules[@]}"; do
    local test_name="cross: $mod output matches reference"
    if should_run "$test_name"; then
      if [[ ! -f "$TARGET_DIR/$mod/main.nf" ]] || [[ ! -f "$REFERENCE_DIR/$mod/main.nf" ]]; then
        skip "$test_name (module not found)"
        continue
      fi

      local pub_new="$TEST_WORKDIR/cross_new_${mod}"
      local pub_ref="$TEST_WORKDIR/cross_ref_${mod}"

      # Choose appropriate args based on module
      local args
      if [[ "$mod" == "step2" ]]; then
        args=(--input1 "$RESOURCES_DIR/lines3.txt" --input2 "$RESOURCES_DIR/lines5.txt")
      else
        args=(--input "$RESOURCES_DIR/lines3.txt")
      fi

      # Run new target
      nf_run_cwd "$PROJECT_DIR" \
        "$TARGET_DIR/$mod/main.nf" \
        --id foo "${args[@]}" --publish_dir "$pub_new"
      local new_exit=$NF_EXIT

      # Clean nextflow cache between runs
      rm -rf "$PROJECT_DIR/.nextflow"* "$PROJECT_DIR/work"

      # Run reference target
      nf_run_cwd "$PROJECT_DIR" \
        "$REFERENCE_DIR/$mod/main.nf" \
        --id foo "${args[@]}" --publish_dir "$pub_ref"
      local ref_exit=$NF_EXIT

      if [[ $new_exit -ne $ref_exit ]]; then
        fail "$test_name" "Exit codes differ: new=$new_exit ref=$ref_exit"
      elif [[ $new_exit -ne 0 ]]; then
        fail "$test_name" "Both failed with exit=$new_exit"
      else
        # Compare output files
        local diff_output
        diff_output=$(diff -rq "$pub_new" "$pub_ref" 2>&1 || true)
        if [[ -z "$diff_output" ]]; then
          pass "$test_name"
        else
          fail "$test_name" "Output files differ: $diff_output"
        fi
      fi
    fi
  done
}
