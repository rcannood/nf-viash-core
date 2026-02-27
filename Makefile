# Build the plugin
assemble:
	./gradlew assemble

clean:
	rm -rf .nextflow*
	rm -rf work
	rm -rf output
	rm -rf build
	./gradlew clean

# Run plugin unit tests (Spock)
test:
	./gradlew test

# Install the plugin into local nextflow plugins dir
install:
	./gradlew install

# Publish the plugin
release:
	./gradlew releasePlugin

# ─── Integration tests ──────────────────────────────────────────────

# Run all integration tests (requires plugin to be installed first)
integration-test: install
	./scripts/integration/run.sh

# Run a specific test suite: standalone, module, script, helper, cross
integration-test-%: install
	./scripts/integration/run.sh --suite $*

# Quick verification: build + unit tests
verify-quick:
	./scripts/verify.sh --quick

# Full verification: build + unit tests + install + integration tests
verify-full:
	./scripts/verify.sh --full
