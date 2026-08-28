#!/usr/bin/env bash

# Shared test setup loader for all *.bats files under test/functions/, test/ci/,
# and test/root/.
# Each .bats file's setup() loads this, then sources the file under test.
#
# Globals exported:
#   REPO_DIR     — repo root, resolved from BATS_TEST_DIRNAME
#   SCRIPTS_DIR  — = repo-root/scripts, the function library
#
# bats-support / bats-assert are loaded here so individual test files do not
# each repeat the load.

# BATS_TEST_DIRNAME points at test/functions (the dir of the running .bats file).
# Repo root is two levels up; the function library lives under scripts/.
REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/../.." && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
export REPO_DIR SCRIPTS_DIR

# --- Fixture-escape hardening: every test is hermetic w.r.t. the real repo ---
# A caller (e.g. the pre-push hook after a worktree push) may carry repo-scoped GIT_* vars;
# with GIT_DIR set, `git -C <fixture>` ignores the fixture path and operates on the real
# repo. Unset them all. Inline rather than git::clear_local_env: the function library is
# the code under test and must not be a dependency of the harness.
_git_local_env_vars="$(git rev-parse --local-env-vars)"
while IFS= read -r _git_env_var; do
  unset "${_git_env_var}"
done <<< "${_git_local_env_vars}"
unset _git_local_env_vars _git_env_var

# Host git config must never leak into fixtures — a global commit.gpgsign=true reaches
# every fixture commit — and a fixture must never write the inverse back into the real
# shared config.
export GIT_CONFIG_GLOBAL='/dev/null'
export GIT_CONFIG_SYSTEM='/dev/null'

# Upward repo discovery from a fixture path must never cross into the real repo. (This does
# not protect discovery when CWD *is* the repo root — the cd below handles that class.)
export GIT_CEILING_DIRECTORIES="${REPO_DIR}"

# No test may shell out to `nix`. check-devshell-provides queries the devShell's own PATH
# via `nix print-dev-env`, and the governance runner invokes that lint — so a suite-wide
# default is the only thing that keeps the query out of every test that runs the real
# suite, not just the lint's own file. Three reasons it must stay out:
#   1. It needs the network. CI restores the Nix *store* cache but not the flake-input git
#      cache, so the query refetches inputs and fails under the pinned GIT_CONFIG_* above.
#   2. It pollutes the tree. Under this harness nix wrote nix/sentry/settings.dat into the
#      working directory, which editorconfig-checker then failed on — reddening
#      run-lint-checks.bats, a file with no connection to the lint that caused it.
#   3. It is slow: seconds per invocation, against a suite of ~2000 tests.
# The ambient PATH is a deliberately WRONG value — it is exactly the inherited-PATH
# confusion check-devshell-provides exists to catch. That is fine here: no test may assert
# the real devShell's contents. That assertion belongs to the `governance` CI job and the
# local ./run-all-checks gate, both of which run the lint in an unmodified environment.
# check-devshell-provides.bats overrides this per case to drive synthetic PATHs.
export DEVSHELL_PATH_OVERRIDE="${PATH}"

# Same mandate, second query. check-devshell-provides also enumerates the devShell's
# DECLARED packages via `nix eval`, which carries every hazard listed above — network,
# nix/sentry/settings.dat written into the working tree, seconds per call — and is reached
# by any test that runs the real governance suite, not just the lint's own file. An empty
# value means "no packages enumerated", which the lint treats as nothing to grade; it
# hard-fails on an empty enumeration only when this override is absent, so the seam cannot
# make the real gate fail open. check-devshell-provides.bats sets a synthetic enumeration
# per case to drive that arm.
export DEVSHELL_PACKAGES_OVERRIDE=''

# Several tests must stop a child bash from re-sourcing the user's interactive ~/.bashrc,
# which re-prepends the real nix PATH ahead of a per-test shim dir. Clearing BASH_ENV does
# that, but BASH_ENV is also the channel kcov injects its trace helper through: the subject
# then runs untraced and contributes nothing to the gates measurement, so a script reads 0%
# with its whole test suite behind it.
#
# The two values are distinguishable. kcov's helper is five lines that set PS4 to a
# `kcov@...` prefix and turn on `set -x`; it sources no startup file and does not touch
# PATH, so it is safe to keep. Preserve BASH_ENV when it is that helper and clear it for
# anything else, the ambient ~/.bashrc included. Tests spell "${SAFE_BASH_ENV}" rather than
# '' or `env --unset=BASH_ENV`.
#
# grep's non-zero exit is the meaningful signal here — unset, missing file, or a value that
# is not kcov's helper — and every one of those cases falls through to the safe empty
# default, which is exactly what clearing BASH_ENV outright would do.
if [[ -n "${BASH_ENV:-}" ]] && grep --quiet 'kcov@' "${BASH_ENV}" 2> '/dev/null'; then
  SAFE_BASH_ENV="${BASH_ENV}"
else
  SAFE_BASH_ENV=''
fi
export SAFE_BASH_ENV

# Fail the test loudly if the per-test tmpdir is unusable or inside the repo — a wrong
# fixture root is exactly how git commands end up aimed at the real checkout.
# Inline [[ ]] checks: strings.bash/dirs.bash are code under test, not harness deps.
if [[ -z "${BATS_TEST_TMPDIR:-}" ]] || [[ ! -d "${BATS_TEST_TMPDIR}" ]]; then
  printf 'common.bash: BATS_TEST_TMPDIR missing or not a directory\n' >&2
  return 1
fi
_bats_tmp_real="$(cd "${BATS_TEST_TMPDIR}" && pwd -P)"
if [[ "${_bats_tmp_real}" == "${REPO_DIR}" || "${_bats_tmp_real}" == "${REPO_DIR}"/* ]]; then
  printf 'common.bash: BATS_TEST_TMPDIR resolves inside the repo: %s\n' "${_bats_tmp_real}" >&2
  return 1
fi
unset _bats_tmp_real

# No test body executes with CWD inside the real repo: an empty/botched path in a
# `git -C "${var}"` call resolves to CWD, which must never be the real checkout.
cd "${BATS_TEST_TMPDIR}" || return 1

# Both libraries resolve through BATS_LIB_PATH, which the flake devShell's bats wrapper
# exports at its own share/bats (`bats.withLibraries` in flake.nix) — not from a vendored
# path under test/test_helper/. A bats that did not come from the devShell therefore fails
# loudly here — "unable to find library" — instead of silently omitting assert_*.
bats_load_library bats-support
bats_load_library bats-assert

# log.bash is sourced eagerly because args::check_* helpers call log::die on failure.
# shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
source "${SCRIPTS_DIR}/functions/log.bash"

# namerefs.bash likewise: every helper that returns through an out-parameter guards its
# nameref with namerefs::assert_available, and files::create_temp is one of them, so
# nearly every .bats file reaches it transitively. Sourcing it per-file instead would
# mean a "command not found" line on stdout in whichever file was missed next.
# shellcheck disable=SC1091 # path resolved at runtime via SCRIPTS_DIR
source "${SCRIPTS_DIR}/functions/namerefs.bash"
