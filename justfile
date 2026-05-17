default: check

# Combined shfmt --diff + shellcheck check
check:
    ./check-scripts

# Run BATS tests
test:
    ./run-tests

# Apply shfmt formatting in place
format:
    ./format-scripts

# Preview shfmt diffs without writing
format-check:
    ./format-scripts --check

# Run shellcheck on shell scripts
shellcheck:
    ./shellcheck-scripts

# Audit shdoc headers
shdoc-check:
    ./.ci/check-shdoc-headers

# Build the docs site locally (requires mkdocs)
docs:
    ./.ci/build-docs
    mkdocs build --strict

# Provision a new machine — run every executable under install/
install:
    ./run-install-scripts

# Run idempotent setup scripts under set_up/
setup:
    ./run-set-up-scripts

# Scaffold a new top-level script with the standard header + exec bit
new-script PATH:
    ./main/new-script {{PATH}}
