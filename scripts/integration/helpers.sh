#!/bin/bash
# Integration test helpers: colors, counters, assertions, nf_run wrappers.
# Sourced by run.sh — do not run directly.

# ─── Colors & output helpers ─────────────────────────────────────────────────

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

TOTAL=0
PASSED=0
FAILED=0
SKIPPED=0
FAILED_TESTS=()

pass() {
  PASSED=$((PASSED + 1))
  echo -e "  ${GREEN}PASS${NC} $1"
}

fail() {
  FAILED=$((FAILED + 1))
  FAILED_TESTS+=("$1")
  echo -e "  ${RED}FAIL${NC} $1"
  if [[ -n "${2:-}" ]]; then
    echo -e "       ${RED}$2${NC}"
  fi
}

skip() {
  SKIPPED=$((SKIPPED + 1))
  echo -e "  ${YELLOW}SKIP${NC} $1"
}

suite_header() {
  echo ""
  echo -e "${BLUE}${BOLD}━━━ $1 ━━━${NC}"
}

# ─── Test infrastructure ────────────────────────────────────────────────────

# Temporary working directory for test outputs
TEST_WORKDIR=$(mktemp -d "${TMPDIR:-/tmp}/viash_integration_XXXXXX")
trap 'cleanup' EXIT

cleanup() {
  if [[ "$KEEP_OUTPUT" == "false" ]]; then
    rm -rf "$TEST_WORKDIR"
    # Clean nextflow work dirs created in project dir
    rm -rf "$PROJECT_DIR/.nextflow"* "$PROJECT_DIR/work" "$PROJECT_DIR/output"
  else
    echo -e "\n${YELLOW}Test outputs preserved in: $TEST_WORKDIR${NC}"
  fi
}

# Run a nextflow workflow and capture exit code + stdout + stderr
# Usage: nf_run <main_script> [args...]
# Sets: NF_EXIT, NF_STDOUT, NF_STDERR
nf_run() {
  local main_script="$1"
  shift
  local args=("$@")

  local stdout_file="$TEST_WORKDIR/.nf_stdout"
  local stderr_file="$TEST_WORKDIR/.nf_stderr"

  NF_EXIT=0
  nextflow run "." \
    -main-script "$main_script" \
    "${args[@]}" \
    >"$stdout_file" 2>"$stderr_file" || NF_EXIT=$?

  NF_STDOUT=$(cat "$stdout_file")
  NF_STDERR=$(cat "$stderr_file")
}

# Run from a specific working directory
# Usage: nf_run_cwd <cwd> <main_script> [args...]
nf_run_cwd() {
  local cwd="$1"
  local main_script="$2"
  shift 2
  local args=("$@")

  local stdout_file="$TEST_WORKDIR/.nf_stdout"
  local stderr_file="$TEST_WORKDIR/.nf_stderr"

  NF_EXIT=0
  (cd "$cwd" && nextflow run "." \
    -main-script "$main_script" \
    "${args[@]}" \
    >"$stdout_file" 2>"$stderr_file") || NF_EXIT=$?

  NF_STDOUT=$(cat "$stdout_file")
  NF_STDERR=$(cat "$stderr_file")
}

# Run with -params-file
# Usage: nf_run_params <main_script> <params_file> [args...]
nf_run_params() {
  local main_script="$1"
  local params_file="$2"
  shift 2
  local args=("$@")

  local stdout_file="$TEST_WORKDIR/.nf_stdout"
  local stderr_file="$TEST_WORKDIR/.nf_stderr"

  NF_EXIT=0
  nextflow run "." \
    -main-script "$main_script" \
    -params-file "$params_file" \
    "${args[@]}" \
    >"$stdout_file" 2>"$stderr_file" || NF_EXIT=$?

  NF_STDOUT=$(cat "$stdout_file")
  NF_STDERR=$(cat "$stderr_file")
}

# Print failure diagnostics
show_failure() {
  local test_name="$1"
  if [[ "$VERBOSE" == "true" ]]; then
    echo -e "       ${YELLOW}--- stdout ---${NC}"
    echo "$NF_STDOUT" | head -50
    echo -e "       ${YELLOW}--- stderr ---${NC}"
    echo "$NF_STDERR" | head -50
  fi
}

# Check whether a test should be run based on filter
should_run() {
  local test_name="$1"
  TOTAL=$((TOTAL + 1))
  if [[ -n "$TEST_FILTER" ]] && ! echo "$test_name" | grep -qi "$TEST_FILTER"; then
    skip "$test_name (filtered)"
    return 1
  fi
  return 0
}

# ─── Assertions ──────────────────────────────────────────────────────────────

# Assert file exists
assert_file_exists() {
  local path="$1"
  local desc="${2:-$path}"
  if [[ ! -f "$path" ]]; then
    echo "       Expected file to exist: $path" >&2
    return 1
  fi
}

# Assert file content equals expected
assert_file_content() {
  local path="$1"
  local expected="$2"
  local actual
  actual=$(cat "$path" | tr '\n' ',' | sed 's/,$//')
  if [[ "$actual" != "$expected" ]]; then
    echo "       File content mismatch in $path" >&2
    echo "       Expected: $expected" >&2
    echo "       Actual:   $actual" >&2
    return 1
  fi
}

# Assert stdout contains string
assert_stdout_contains() {
  local expected="$1"
  if ! echo "$NF_STDOUT" | grep -qF "$expected"; then
    echo "       Expected stdout to contain: $expected" >&2
    return 1
  fi
}

# Assert stdout does NOT contain string
assert_stdout_not_contains() {
  local unexpected="$1"
  if echo "$NF_STDOUT" | grep -qF "$unexpected"; then
    echo "       Expected stdout NOT to contain: $unexpected" >&2
    return 1
  fi
}
