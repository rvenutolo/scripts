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
    ./main/check-shdoc-headers

# Build the docs site locally (requires mkdocs)
docs:
    ./main/build-docs
    mkdocs build --strict
