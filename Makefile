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

.PHONY: help setup project lint format format-check test build verify clean

help: ## Print this help.
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Install Homebrew tooling + node dev deps. Run once after cloning.
	@command -v brew >/dev/null || { echo "Install Homebrew first: https://brew.sh"; exit 1; }
	brew bundle --no-lock --file=- <<-EOF
		brew "xcodegen"
		brew "swiftlint"
		brew "swiftformat"
		brew "xcbeautify"
	EOF
	npm install
	@$(MAKE) project

project: ## Generate Venn.xcodeproj from project.yml.
	cd ios && xcodegen generate

lint: ## Run SwiftLint in strict mode (warnings fail).
	swiftlint lint --strict

format: ## Auto-format all Swift files in place.
	swiftformat ios

format-check: ## Fail if any Swift file is unformatted.
	swiftformat --lint ios

test: project ## Run XCTest suites in the iOS simulator.
	set -o pipefail && $(XCODEBUILD) \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		-enableCodeCoverage YES \
		test | $(XCBEAUTIFY)

build: project ## Build the app for the simulator (no tests).
	set -o pipefail && $(XCODEBUILD) \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		-derivedDataPath $(DERIVED_DATA) \
		build | $(XCBEAUTIFY)

verify: lint format-check test ## Run before opening any PR.

clean: ## Remove derived data and the generated Xcode project.
	rm -rf build $(DERIVED_DATA) ios/Venn.xcodeproj
