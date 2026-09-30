# =============================================================================
# Makefile — orchestrates Swift tooling from the repo root.
# =============================================================================
# Why a Makefile? It's the convention for Swift projects (no node dependency
# for the day-to-day workflow). Run `make help` for the menu.
# =============================================================================

PROJECT          := ios/Venn.xcodeproj
SCHEME           := Venn
DESTINATION      := platform=iOS Simulator,name=iPhone 17 Pro,OS=latest
DERIVED_DATA     := build/DerivedData

XCODEBUILD       := xcodebuild
XCBEAUTIFY       := xcbeautify --quiet --is-ci

.PHONY: help setup doctor project packages lint format format-check periphery codegen test build verify clean prune-branches prune-branches-force

help: ## Print this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

doctor: ## Health-check the local dev environment (Xcode, brew tools, .env, hooks).
	@bash scripts/doctor.sh

setup: ## Install Homebrew tooling + node dev deps + resolve SPM. Run once after cloning.
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	brew bundle --file=- <<-EOF
		brew "xcodegen"
		brew "swiftlint"
		brew "swiftformat"
		brew "xcbeautify"
		brew "periphery"
	EOF
	npm install
	@$(MAKE) project
	@$(MAKE) packages

project: ## Generate Venn.xcodeproj from project.yml.
	cd ios && xcodegen generate

packages: project ## Resolve + download SPM dependencies (Supabase, Sentry, PostHog, …).
	$(XCODEBUILD) -resolvePackageDependencies \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-derivedDataPath $(DERIVED_DATA)

lint: ## Run SwiftLint in strict mode (warnings fail).
	@expected="$$(cat .swiftlint-version)"; actual="$$(swiftlint version 2>/dev/null)"; \
	if [ -n "$$actual" ] && [ "$$expected" != "$$actual" ]; then \
		echo "⚠ SwiftLint $$actual locally, $$expected in CI."; \
		echo "  A rule added between the two is invisible here and fails there."; \
		echo "  brew upgrade swiftlint, or match $$expected exactly."; \
	fi
	swiftlint lint --strict

format: ## Auto-format all Swift files in place.
	swiftformat ios

format-check: ## Fail if any Swift file is unformatted.
	swiftformat --lint ios

docs: project ## Build DocC docs into build/Venn.doccarchive (open in Xcode).
	set -o pipefail && $(XCODEBUILD) docbuild \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) | $(XCBEAUTIFY)
	@find $(DERIVED_DATA) -name 'Venn.doccarchive' -type d -print -quit | \
		xargs -I{} cp -R {} build/Venn.doccarchive
	@echo "Docs at build/Venn.doccarchive — open in Xcode."
periphery: project ## Scan for dead code (unused functions, types, properties).
	periphery scan

codegen: ## Regenerate Swift types from the Supabase schema (requires SUPABASE_DB_URL in .env).
	npm run db:types

# `-retry-tests-on-failure` runs a failing test once more before the suite
# is called red. The UI journeys hit real Supabase and what fails is almost
# never an assertion — see the note in .github/workflows/ci.yml and row 39.
test: project ## Run XCTest suites in the iOS simulator.
	set -o pipefail && $(XCODEBUILD) \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-enableCodeCoverage YES \
		-retry-tests-on-failure \
		-test-iterations 2 \
		test | $(XCBEAUTIFY)

build: project ## Build the app for the simulator (no tests).
	set -o pipefail && $(XCODEBUILD) \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		build | $(XCBEAUTIFY)

verify: doctor lint format-check test ## Run before opening any PR.

clean: ## Remove derived data and the generated Xcode project.
	rm -rf build $(DERIVED_DATA) ios/Venn.xcodeproj

prune-branches: ## List local branches whose remote was deleted (squash-merged PRs).
	@bash scripts/prune-branches.sh

prune-branches-force: ## Delete local branches whose remote was deleted.
	@bash scripts/prune-branches.sh delete
