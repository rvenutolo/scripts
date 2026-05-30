default: check

# shellcheck + shdoc audit
check:
    ./check-scripts

# Run the repo-governance lint suite (workflow posture, renovate, ruleset)
governance:
    ./.ci/run-governance-checks

# Run BATS tests
test:
    ./run-tests

# Format every file via treefmt
format:
    nix fmt

# Verify formatting without writing
format-check:
    nix flake check

# Run shellcheck on shell scripts
shellcheck:
    ./shellcheck-scripts

# Audit shdoc headers
shdoc-check:
    ./.ci/check-shdoc-headers

# Build the docs site locally (requires mkdocs)
docs:
    ./.ci/build-docs
    mkdocs build --strict --config-file .mkdocs.yml

# Provision a new machine — run every executable under install/
install:
    ./run-install-scripts

# Run idempotent setup scripts under set_up/
setup:
    ./run-set-up-scripts

# Scaffold a new top-level script with the standard header + exec bit
new-script PATH:
    ./main/new-script {{PATH}}
