# Run the default gate (`just check`)
default: check

# Run the full local verification gate
all:
    ./.ci/in-devshell ./run-all-checks

# shellcheck + shdoc header audit
check:
    ./.ci/in-devshell ./check-scripts

# Run the repo-governance lint suite (workflow posture, renovate, ruleset)
governance:
    ./.ci/in-devshell ./.ci/run-governance-checks

# Run the config/markup lint suite (actionlint, yamllint, json, markdown, typos, editorconfig)
lint:
    ./.ci/in-devshell ./.ci/run-lint-checks

# Run the BATS test suite
test:
    ./.ci/in-devshell ./run-tests

# Format every file via treefmt
format:
    nix fmt

# Verify formatting without writing changes
format-check:
    nix flake check

# Run shellcheck over shell scripts
shellcheck:
    ./.ci/in-devshell ./shellcheck-scripts

# Audit shdoc headers
shdoc-check:
    ./.ci/in-devshell ./.ci/check-shdoc-headers

# Build the docs site locally
docs:
    ./.ci/in-devshell ./.ci/build-site

# Scaffold a new top-level script with the standard header + exec bit
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}
