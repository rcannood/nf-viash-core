#!/bin/bash
# Integration test runner for viash-target-new
#
# This script replicates the test logic from the viash repository's Scala test suites:
#   - NextflowScriptTest.scala
#   - Vdsl3StandaloneTest.scala
#   - Vdsl3ModuleTest.scala
#   - WorkflowHelperTest.scala
# See: https://github.com/viash-io/viash/tree/main/src/test/scala/io/viash/runners/nextflow
#
# Usage:
#   ./scripts/integration/run.sh [OPTIONS]
#
# Options:
#   --target <dir>      Target directory (default: viash-target-new/nextflow)
#   --reference <dir>   Reference directory (default: viash-target/nextflow)
#   --suite <name>      Run only a specific test suite:
#                         standalone, module, script, helper, cross, all (default: all)
#   --test <pattern>    Run only tests matching this grep pattern
#   --keep              Keep output/work dirs after tests (default: clean up)
#   --verbose           Show full nextflow output on failure
#   --help              Show this help message

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Defaults
TARGET_DIR="$PROJECT_DIR/viash-target-new/nextflow"
REFERENCE_DIR="$PROJECT_DIR/viash-target/nextflow"
RESOURCES_DIR="$PROJECT_DIR/resources"
SUITE="all"
TEST_FILTER=""
KEEP_OUTPUT=false
VERBOSE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)    TARGET_DIR="$2"; shift 2 ;;
    --reference) REFERENCE_DIR="$2"; shift 2 ;;
    --suite)     SUITE="$2"; shift 2 ;;
    --test)      TEST_FILTER="$2"; shift 2 ;;
    --keep)      KEEP_OUTPUT=true; shift ;;
    --verbose)   VERBOSE=true; shift ;;
    --help)
      head -24 "$0" | grep '^#' | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "Unknown option: $1"; exit 1 ;;
  esac
done

# ─── Source helpers and test suites ───────────────────────────────────────────

source "$SCRIPT_DIR/helpers.sh"
source "$SCRIPT_DIR/suite_standalone.sh"
source "$SCRIPT_DIR/suite_module.sh"
source "$SCRIPT_DIR/suite_script.sh"
source "$SCRIPT_DIR/suite_helper.sh"
source "$SCRIPT_DIR/suite_cross.sh"

# ═══════════════════════════════════════════════════════════════════════════════
# Main
# ═══════════════════════════════════════════════════════════════════════════════

echo -e "${BOLD}viash-target-new Integration Tests${NC}"
echo -e "Target:    $TARGET_DIR"
echo -e "Resources: $RESOURCES_DIR"
echo -e "Workdir:   $TEST_WORKDIR"
echo ""

cd "$PROJECT_DIR"

# Clean any leftover nextflow state
rm -rf "$PROJECT_DIR/.nextflow"* "$PROJECT_DIR/work"

case "$SUITE" in
  standalone) run_standalone_tests ;;
  module)     run_module_tests ;;
  script)     run_script_tests ;;
  helper)     run_helper_tests ;;
  cross)      run_cross_validation ;;
  all)
    run_standalone_tests
    run_module_tests
    run_script_tests
    run_helper_tests
    run_cross_validation
    ;;
  *)
    echo "Unknown suite: $SUITE"
    echo "Valid suites: standalone, module, script, helper, cross, all"
    exit 1
    ;;
esac

# ── Summary ───────────────────────────────────────────────────────────────────

echo ""
echo -e "${BOLD}━━━ Summary ━━━${NC}"
echo -e "  Total:   $TOTAL"
echo -e "  ${GREEN}Passed:  $PASSED${NC}"
if [[ $FAILED -gt 0 ]]; then
  echo -e "  ${RED}Failed:  $FAILED${NC}"
fi
if [[ $SKIPPED -gt 0 ]]; then
  echo -e "  ${YELLOW}Skipped: $SKIPPED${NC}"
fi

if [[ $FAILED -gt 0 ]]; then
  echo ""
  echo -e "${RED}Failed tests:${NC}"
  for t in "${FAILED_TESTS[@]}"; do
    echo -e "  ${RED}✗${NC} $t"
  done
  echo ""
  exit 1
else
  echo ""
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
