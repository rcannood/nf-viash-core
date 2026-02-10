#!/bin/bash
# Quick verification script for viash_core plugin development
# Run this after any change to verify everything still works.
#
# Usage: ./scripts/verify.sh [--quick|--full]
#   --quick: Only build + unit tests (default)
#   --full:  Build + unit tests + install + integration test

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_DIR"

MODE="${1:---quick}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

pass() { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; exit 1; }
info() { echo -e "${YELLOW}→ $1${NC}"; }

# Step 1: Build
info "Building plugin..."
if make assemble 2>&1 | tail -3 | grep -q "BUILD SUCCESSFUL"; then
    pass "Build succeeded"
else
    fail "Build failed"
fi

# Step 2: Unit tests
info "Running unit tests..."
if make test 2>&1 | tail -3 | grep -q "BUILD SUCCESSFUL"; then
    pass "Unit tests passed"
else
    fail "Unit tests failed"
fi

if [[ "$MODE" == "--full" ]]; then
    # Step 3: Install
    info "Installing plugin..."
    if make install 2>&1 | tail -5 | grep -q "BUILD SUCCESSFUL"; then
        pass "Plugin installed"
    else
        fail "Plugin install failed"
    fi

    # Step 4: Integration test — run a simple pipeline with the plugin
    info "Running integration test..."
    if nextflow run "$PROJECT_DIR/validation/main.nf" \
        -plugins viash-core@0.1.0 \
        2>&1 | tail -5 | grep -q -E "complete|Pipeline"; then
        pass "Integration test passed"
    else
        fail "Integration test failed"
    fi
fi

echo ""
echo -e "${GREEN}All checks passed!${NC}"
