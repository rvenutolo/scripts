# shellcheck disable=SC2016 # backticks in the markdown fixtures are literal content the lint under test must match, never command substitution

setup() {
  load '../test_helper/common'
  CHECK="${REPO_DIR}/.ci/check-justfile-invariants"
  ROOT="${BATS_TEST_TMPDIR}/root"
  mkdir -p "${ROOT}/.github"
}

# Write a justfile whose recipes match the default README fixture below.
make_justfile() {
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# Run the full local verification gate
all:
    ./run-all-checks

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}
EOF
}

make_readme() {
  cat > "${ROOT}/README.md" << 'EOF'
## Common commands

| Shell script | `just` recipe | Purpose |
| --- | --- | --- |
| `./run-all-checks` | `just all` | Full local gate. |
| `./check-scripts` | `just check` (default) | Combined audit. |
| `scripts/non-interactive/new-script <path>` | `just new-script <path>` | Scaffold a script. |
EOF
}

make_pr_template() {
  cat > "${ROOT}/.github/PULL_REQUEST_TEMPLATE.md" << 'EOF'
## Test plan

- [ ] `nix fmt`
- [ ] `./run-all-checks`
EOF
}

# Every path input is pinned at fixtures. Without all four seams the lint would
# fall back to the live checkout and these tests would depend on real repo state.
# .ci/check-justfile-invariants derives its own repo root via `git rev-parse
# --show-toplevel`. common.bash's fixture-escape hardening leaves CWD at
# BATS_TEST_TMPDIR (outside any git repo) by design, so cd into REPO_DIR before
# every invocation.
run_check() {
  cd "${REPO_DIR}" || return 1
  ROOT_DIR_OVERRIDE="${ROOT}" \
    JUSTFILE_OVERRIDE="${ROOT}/.justfile" \
    README_OVERRIDE="${ROOT}/README.md" \
    PR_TEMPLATE_OVERRIDE="${ROOT}/.github/PULL_REQUEST_TEMPLATE.md" \
    run "${CHECK}" "$@"
}

@test "passes on a well-formed tree" {
  make_justfile
  make_readme
  make_pr_template
  run_check
  assert_success
}

@test "fails when a second justfile candidate exists" {
  make_justfile
  make_readme
  make_pr_template
  printf 'default: check\n' > "${ROOT}/justfile"
  run_check
  assert_failure
  assert_output --partial 'multiple justfile candidates'
}

@test "names both candidates when duplicated" {
  make_justfile
  make_readme
  make_pr_template
  printf 'default: check\n' > "${ROOT}/justfile"
  run_check
  assert_output --partial '.justfile'
  assert_output --partial 'justfile'
}

@test "fails when no justfile candidate exists" {
  make_readme
  make_pr_template
  run_check
  assert_failure
  assert_output --partial 'no justfile'
}

@test "fails when the sole candidate is the unhidden justfile" {
  make_justfile
  mv "${ROOT}/.justfile" "${ROOT}/justfile"
  make_readme
  make_pr_template
  cd "${REPO_DIR}"
  JUSTFILE_OVERRIDE="${ROOT}/justfile" ROOT_DIR_OVERRIDE="${ROOT}" \
    README_OVERRIDE="${ROOT}/README.md" \
    PR_TEMPLATE_OVERRIDE="${ROOT}/.github/PULL_REQUEST_TEMPLATE.md" \
    run "${CHECK}"
  assert_failure
  assert_output --partial '.justfile'
}

@test "fails when a recipe has no README row" {
  make_justfile
  make_readme
  make_pr_template
  printf '\n# Orphan\norphan:\n    true\n' >> "${ROOT}/.justfile"
  run_check
  assert_failure
  assert_output --partial 'orphan'
  assert_output --partial 'no README'
}

@test "fails when README names a recipe that does not exist" {
  make_justfile
  make_readme
  make_pr_template
  printf '| `./ghost` | `just ghost` | Ghost. |\n' >> "${ROOT}/README.md"
  run_check
  assert_failure
  assert_output --partial 'ghost'
}

@test "default is exempt from README parity" {
  make_justfile
  make_readme
  make_pr_template
  run_check
  assert_success
  refute_output --partial 'default'
}

@test "parameterized recipes match on bare name" {
  make_justfile
  make_readme
  make_pr_template
  run_check
  assert_success
  refute_output --partial 'new-script'
}

@test "fails when the all recipe does not invoke run-all-checks" {
  make_readme
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# Run the full local verification gate
all:
    ./check-scripts

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}
EOF
  run_check
  assert_failure
  assert_output --partial 'run-all-checks'
}

@test "fails when the all recipe is missing entirely" {
  make_readme
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}
EOF
  printf '| `./run-all-checks` | `just all` | Gate. |\n' >> "${ROOT}/README.md"
  run_check
  assert_failure
  assert_output --partial 'all'
}

@test "fails when the PR template does not name run-all-checks" {
  make_justfile
  make_readme
  printf '## Test plan\n\n- [ ] `nix fmt`\n' > "${ROOT}/.github/PULL_REQUEST_TEMPLATE.md"
  run_check
  assert_failure
  assert_output --partial 'PULL_REQUEST_TEMPLATE'
}

@test "dies when the justfile is missing" {
  make_readme
  make_pr_template
  printf 'default: check\n' > "${ROOT}/.justfile"
  rm "${ROOT}/.justfile"
  run_check
  assert_failure 1
  assert_output --partial 'no justfile found at'
}

@test "dies when README is missing" {
  make_justfile
  make_pr_template
  run_check
  assert_failure 1
  assert_output --partial 'README.md does not exist'
}

@test "rejects an unexpected argument" {
  make_justfile
  make_readme
  make_pr_template
  run_check unexpected
  assert_failure 1
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0 and prints the description" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'justfile'
}

@test "the real repo passes its own lint" {
  cd "${REPO_DIR}"
  run "${CHECK}"
  assert_success
}

# --- recipe names just accepts that a hand-rolled regex would reject ---

@test "an uppercase-initial recipe with no README row fails" {
  make_readme
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# Run the full local verification gate
all:
    ./run-all-checks

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}

# Build the thing
Build:
    ./build
EOF
  run_check
  assert_failure
  assert_output --partial 'Build'
  assert_output --partial 'no README'
}

@test "an uppercase-initial recipe documented in README passes" {
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# Run the full local verification gate
all:
    ./run-all-checks

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}

# Build the thing
Build:
    ./build
EOF
  make_readme
  printf '| `./build` | `just Build` | Build it. |\n' >> "${ROOT}/README.md"
  run_check
  assert_success
}

@test "an underscore-prefixed recipe needs no README row" {
  make_readme
  make_pr_template
  make_justfile
  printf '\n_scratch:\n    true\n' >> "${ROOT}/.justfile"
  run_check
  assert_success
}

@test "a private-attributed recipe needs no README row" {
  make_readme
  make_pr_template
  make_justfile
  printf '\n[private]\nhelper:\n    true\n' >> "${ROOT}/.justfile"
  run_check
  assert_success
}

@test "a hidden recipe documented in README fails" {
  make_pr_template
  make_justfile
  printf '\n_scratch:\n    true\n' >> "${ROOT}/.justfile"
  make_readme
  printf '| `./scratch` | `just _scratch` | Scratch. |\n' >> "${ROOT}/README.md"
  run_check
  assert_failure
  assert_output --partial '_scratch'
}

@test "a justfile just cannot parse fails the lint" {
  make_readme
  make_pr_template
  printf 'bogus line here\n\ncheck:\n    ./check-scripts\n' > "${ROOT}/.justfile"
  run_check
  assert_failure
  # Discriminating on purpose: a truncated justfile also trips README parity and
  # the missing-gate-recipe check, so a bare assert_failure passes vacuously and
  # would stay green even if nothing ever detected the parse failure.
  assert_output --partial 'could not parse this justfile'
}

@test "legal non-recipe constructs parse without a violation" {
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
set shell := ["bash", "-c"]
export MYVAR := "x"
myvar := "y"
alias c := check

# Run the default gate
default: check

# Run the full local verification gate
all: check
    ./run-all-checks

# shellcheck + shdoc header audit
check:
    ./check-scripts

# Scaffold a new script
new-script PATH="d":
    ./scripts/non-interactive/new-script {{PATH}}
EOF
  make_readme
  run_check
  assert_success
}

# --- README scanning must be scoped to the command table's section ---

@test "an unrelated markdown table mentioning just is ignored" {
  make_justfile
  make_pr_template
  make_readme
  cat >> "${ROOT}/README.md" << 'EOF'

## Migration notes

| Old | New |
| --- | --- |
| `make build` | `just legacy-thing` |
EOF
  run_check
  assert_success
}

@test "a README with no Common commands heading fails" {
  make_justfile
  make_pr_template
  cat > "${ROOT}/README.md" << 'EOF'
## Something else

| Shell script | `just` recipe | Purpose |
| --- | --- | --- |
| `./run-all-checks` | `just all` | Full local gate. |
| `./check-scripts` | `just check` (default) | Combined audit. |
| `scripts/non-interactive/new-script <path>` | `just new-script <path>` | Scaffold a script. |
EOF
  run_check
  assert_failure
  assert_output --partial 'Common commands'
}

# --- every public recipe describes itself ---

@test "fails when a public recipe has no doc comment" {
  make_readme
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# Run the full local verification gate
all:
    ./run-all-checks

check:
    ./check-scripts

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}
EOF
  run_check
  assert_failure
  assert_output --partial 'check'
  assert_output --partial 'doc comment'
}

@test "passes when a private recipe has no doc comment" {
  make_readme
  make_pr_template
  cat > "${ROOT}/.justfile" << 'EOF'
# Run the default gate
default: check

# Run the full local verification gate
all:
    ./run-all-checks

# shellcheck + shdoc header audit
check:
    ./check-scripts

_internal-helper:
    true

# Scaffold a new script
new-script PATH:
    ./scripts/non-interactive/new-script {{PATH}}
EOF
  run_check
  assert_success
}

@test "passes when every public recipe carries a doc comment" {
  make_justfile
  make_readme
  make_pr_template
  run_check
  assert_success
}
