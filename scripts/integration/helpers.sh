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
# Set NF_QUIET=true before calling for quiet mode (-q before 'run')
nf_run() {
  local main_script="$1"
  shift
  local args=("$@")

  local stdout_file="$TEST_WORKDIR/.nf_stdout"
  local stderr_file="$TEST_WORKDIR/.nf_stderr"

  local quiet_args=()
  if [[ "${NF_QUIET:-}" == "true" ]]; then
    quiet_args=("-q")
  fi

  NF_EXIT=0
  nextflow "${quiet_args[@]}" run "." \
    -main-script "$main_script" \
    "${args[@]}" \
    >"$stdout_file" 2>"$stderr_file" || NF_EXIT=$?

  NF_STDOUT=$(cat "$stdout_file")
  NF_STDERR=$(cat "$stderr_file")
}

# Run from a specific working directory
# Usage: nf_run_cwd <cwd> <main_script> [args...]
# Set NF_QUIET=true before calling for quiet mode (-q before 'run')
nf_run_cwd() {
  local cwd="$1"
  local main_script="$2"
  shift 2
  local args=("$@")

  local stdout_file="$TEST_WORKDIR/.nf_stdout"
  local stderr_file="$TEST_WORKDIR/.nf_stderr"

  local quiet_args=()
  if [[ "${NF_QUIET:-}" == "true" ]]; then
    quiet_args=("-q")
  fi

  NF_EXIT=0
  (cd "$cwd" && nextflow "${quiet_args[@]}" run "." \
    -main-script "$main_script" \
    "${args[@]}" \
    >"$stdout_file" 2>"$stderr_file") || NF_EXIT=$?

  NF_STDOUT=$(cat "$stdout_file")
  NF_STDERR=$(cat "$stderr_file")
}

# Run with -params-file
# Usage: nf_run_params <main_script> <params_file> [args...]
# Set NF_QUIET=true before calling for quiet mode (-q before 'run')
nf_run_params() {
  local main_script="$1"
  local params_file="$2"
  shift 2
  local args=("$@")

  local stdout_file="$TEST_WORKDIR/.nf_stdout"
  local stderr_file="$TEST_WORKDIR/.nf_stderr"

  local quiet_args=()
  if [[ "${NF_QUIET:-}" == "true" ]]; then
    quiet_args=("-q")
  fi

  NF_EXIT=0
  nextflow "${quiet_args[@]}" run "." \
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

# ─── DEBUG output parsing (mirrors NextflowTestHelper.scala) ─────────────────

# Find a DEBUG line for a specific id in NF_STDOUT
# Matches lines like: KEYWORD: [id, [key:value, ...]]
# Usage: find_debug_line "foo" ["DEBUG"]
# Sets: FOUND_DEBUG_LINE or returns 1 if not found
find_debug_line() {
  local id="$1"
  local keyword="${2:-DEBUG}"
  FOUND_DEBUG_LINE=$(echo "$NF_STDOUT" | grep "^${keyword}: \[${id}, \[" | head -1)
  [[ -n "$FOUND_DEBUG_LINE" ]]
}

# Assert that a key has an exact value in a DEBUG line
# Mirrors: EqualsCheck(name, value)
# Usage: assert_debug_kv "$FOUND_DEBUG_LINE" "key" "value"
assert_debug_kv() {
  local line="$1"
  local key="$2"
  local value="$3"
  if echo "$line" | grep -qF "${key}:${value}"; then
    return 0
  fi
  echo "       assert_debug_kv: expected ${key}:${value}" >&2
  echo "       in: ${line}" >&2
  return 1
}

# Assert that a key's value matches a regex in a DEBUG line
# Mirrors: MatchCheck(name, regex)
# Usage: assert_debug_match "$FOUND_DEBUG_LINE" "key" "regex_pattern"
assert_debug_match() {
  local line="$1"
  local key="$2"
  local pattern="$3"
  if echo "$line" | grep -qE "${key}:${pattern}"; then
    return 0
  fi
  echo "       assert_debug_match: expected ${key}: to match ${pattern}" >&2
  echo "       in: ${line}" >&2
  return 1
}

# Assert that a key does NOT exist in a DEBUG line
# Mirrors: NotAvailCheck(name)
# Usage: assert_debug_notavail "$FOUND_DEBUG_LINE" "key"
assert_debug_notavail() {
  local line="$1"
  local key="$2"
  # Check for key: preceded by ', ' or '[' (Groovy Map.toString() format)
  if ! echo "$line" | grep -qE "(, |\[)${key}:"; then
    return 0
  fi
  echo "       assert_debug_notavail: ${key} should not exist" >&2
  echo "       in: ${line}" >&2
  return 1
}

# Check all expected debug args for a given id
# Mirrors: checkDebugArgs(id, debugPrints, expectedValues)
# Usage: check_debug_args "foo" "DEBUG" "equals:real_number:10.5" "match:input:.*/lines3.txt" "notavail:reality"
# Returns 0 if all checks pass, 1 if any fail
check_debug_args() {
  local id="$1"
  local keyword="$2"
  shift 2

  if ! find_debug_line "$id" "$keyword"; then
    echo "       check_debug_args: no DEBUG line found for id=$id keyword=$keyword" >&2
    return 1
  fi

  local all_ok=true
  for check in "$@"; do
    local type="${check%%:*}"
    local rest="${check#*:}"
    local key="${rest%%:*}"
    local value="${rest#*:}"

    case "$type" in
      equals)
        if ! assert_debug_kv "$FOUND_DEBUG_LINE" "$key" "$value"; then
          all_ok=false
        fi
        ;;
      match)
        if ! assert_debug_match "$FOUND_DEBUG_LINE" "$key" "$value"; then
          all_ok=false
        fi
        ;;
      notavail)
        # For notavail, there's no value; 'key' is extracted from 'rest' which is just the key
        if ! assert_debug_notavail "$FOUND_DEBUG_LINE" "$rest"; then
          all_ok=false
        fi
        ;;
      *)
        echo "       check_debug_args: unknown check type: $type" >&2
        all_ok=false
        ;;
    esac
  done

  $all_ok
}

# Assert that the input path for an id ends with a specific suffix
# Mirrors the endsWith assertion in WorkflowHelperTest
# Usage: assert_debug_input_endswith "foo" "/resources/lines3.txt" ["DEBUG"]
assert_debug_input_endswith() {
  local id="$1"
  local suffix="$2"
  local keyword="${3:-DEBUG}"

  find_debug_line "$id" "$keyword" || return 1

  # Extract input value: match input:/path up to next comma-key or end
  local input_path
  input_path=$(echo "$FOUND_DEBUG_LINE" | grep -oE 'input:[^],]*' | head -1 | sed 's/^input://')

  if [[ "$input_path" == *"$suffix" ]]; then
    return 0
  fi
  echo "       assert_debug_input_endswith: expected input to end with ${suffix}" >&2
  echo "       got: ${input_path}" >&2
  return 1
}
