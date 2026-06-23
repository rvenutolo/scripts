default: check

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Run the repo-governance lint suite (workflow posture, renovate, ruleset)
governance:
    ./.ci/run-governance-checks

# Run the config/markup lint suite (actionlint, yamllint, json, markdown, typos, editorconfig)
lint:
    ./.ci/run-lint-checks

# Run the BATS test suite
test:
    ./run-tests

# Format every file via treefmt
format:
    nix fmt

# Verify formatting without writing changes
format-check:
    nix flake check

# Run shellcheck over shell scripts
shellcheck:
    ./shellcheck-scripts

# Audit shdoc headers
shdoc-check:
    ./.ci/check-shdoc-headers
