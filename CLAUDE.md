# CLAUDE.md

Guidance for Claude Code when working in this repository.

## Repository Purpose

Personal collection of bash scripts for system setup, package install, and day-to-day utilities on the user's Linux
machines. Pure shell, no build system. Helper functions in `scripts/functions/*.bash` are covered by a BATS suite under
`test/`.

## Layout

Script directories live under `scripts/`; `SCRIPTS_DIR` points at `repo-root/scripts`.

- `scripts/non-interactive/` — automation-safe scripts, callable from cron, `topgrade`, etc.: **no prompts, no GUI, no
  `fzf`/pickers, no TTY assumptions.** Always on `PATH`.
- `scripts/interactive/` — everything that prompts, launches a GUI, or assumes a terminal, **plus every wrapper**
  (`mvn`, `gradle`, `kate`, flatpak wrappers, …). On `PATH` only in interactive shells, so wrappers shadow real binaries
  only when a human is at the keyboard. **Exception:** the `claude` wrapper lives in `non-interactive/`, because it
  derives `CLAUDE_CONFIG_DIR` from `PWD` (honoring an already-set value) and must also work from cron/`ssh`/scripts.
- `scripts/other/` — third-party scripts copied verbatim. **Never modify anything here unless explicitly told to touch a
  specific file** — no formatting, shellcheck fixes, or refactors. Always on `PATH`; excluded from formatting and
  shellcheck. Only `.ci/check-executable-bit` inspects it (file mode is not content).
- `scripts/install/` — numbered scripts run in order by `run-install-scripts`. All-caps names (`00_DISTRO_PACKAGES`,
  `70_WORK_ONLY`) are non-executable marker/data files; the runner skips non-executable files.
- `scripts/set_up/` — idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script must
  self-check current state and exit cleanly when there is nothing to do.
- `scripts/misc/` — one-off setup scripts, not on `PATH`, not auto-run. **Standalone**: must not source
  `.functions.bash`; inline what they need (including the `ERR` trap below). Hardcoded paths are acceptable.
- `scripts/shims/claude/` — `pkill`/`killall` guards plus their `lib.bash`. **Never on `PATH` by normal wiring** — only
  the `claude` wrapper prepends it. Standalone like `misc/`: bash builtins only, no external commands, no
  `.functions.bash`. Otherwise held to every gate, with paired tests under `test/shims/`. Refusal exits 125 without
  running the real binary; a missing real binary exits 127; `-h`/`--help`/`-V`/`--version` pass through.
- `scripts/functions/` — the function library, sourced via `scripts/.functions.bash`.

At the **repo root** (not under `scripts/`): `lib/` (vendored Groovy jars), `.ci/` (repo tooling, not on `PATH`),
`test/`, `.github/`, `.shdoc/`, `.docs/`, the root runners (`check-scripts`, `shellcheck-scripts`, `run-all-checks`,
`run-install-scripts`, `run-set-up-scripts`, `run-tests`), and all config files. Repo tooling derives the repo root via
`git rev-parse --show-toplevel` (a local `REPO_DIR`).

## Required Environment

Tooling comes from the **Nix flake devShell** (`direnv allow` or `nix develop`). CI uses the same flake.

`~/.profile` exports a fixed set of env vars (`SCRIPTS_DIR`, `XDG_*`, `PERSONAL_PROJECTS_DIR`, …) — read it to
enumerate them. They are **guaranteed** set whenever a script runs.

- **Reuse, don't hardcode:** `"${SCRIPTS_DIR}/.functions.bash"`, `"${XDG_CONFIG_HOME}/foo"`, etc.
- **No fallbacks:** no `${VAR:-default}` for these vars. Failing under `set -u` is desired.
- **No env-var prefix** when invoking repo scripts (`./check-scripts`, not `SCRIPTS_DIR=… ./check-scripts`).
- **Ignore conditional exports** (`EDITOR`, `PAGER`, `TAILNET_IP`, `TERM`, …) — not guaranteed.
- `misc/` scripts must not depend on this env.

### Sourcing `.functions.bash`

Every non-`misc/` script sources `"${SCRIPTS_DIR}/.functions.bash"`. A few Docker scripts
(`docker-grype-scan`, `docker-trivy-scan`) source `${DOCKER_COMPOSE_DIR}/functions.bash` instead, which transitively
sources this repo's library, so all helpers (including `log::enable_err_trap`) are available there.

`.ci/activate-githooks` and `.ci/in-devshell` are bootstrap scripts: they run before the devShell exists (where
`SCRIPTS_DIR` may be unset), so they source nothing, omit `args::handle_help_flag`, and inline the standalone `ERR` trap.

## Common Commands

Run repo scripts through `./.ci/in-devshell <script>` (or from an entered direnv shell).

- `nix fmt` — format via treefmt. It matches by extension, so it **does not** reach extensionless executables or
  `*.bats`; `./check-scripts` covers those with a verify-only shfmt step.
- `./check-scripts [<file-or-dir>...]` — shfmt verify, shellcheck, shdoc-header audit, executable-bit audit.
- `./shellcheck-scripts [<file-or-dir>...]` — shellcheck all shell files except `scripts/other/`.
- `./run-tests [<bats-args>...]` — BATS over `test/functions/`, `test/ci/`, `test/root/`, `test/shims/` in parallel.
  Single file: `./run-tests test/functions/strings.bats`; subset: `--filter 'is_blank'`.
- `./run-all-checks` — the full gate (see [Before Committing](#before-committing)).
- `scripts/non-interactive/new-script <path>` — scaffold a new script with header and exec bit.
- `.ci/build-site` — the single definition of the docs build (`.ci/build-docs` + `mkdocs build --strict`). Callers go
  through it; don't restate its commands.
- `./run-install-scripts` / `./run-set-up-scripts` — provision the machine. To gate a script off, `chmod -x` it.

### Shell style lives in `.editorconfig`

`.editorconfig` is the single source of truth for shell formatting. Neither shfmt call site (`.treefmt.nix`,
`check-scripts`) passes style flags, because any parser/printer flag (`-i`, `-ci`, `-bn`, `-sr`, `-s`) makes shfmt
ignore `.editorconfig`. Never add one. Because executables have no extension, `.editorconfig` carries path-based
sections per script directory; a new directory of executables needs its own section. `scripts/other/` is deliberately
absent.

## Script Conventions

The generic rules in `.claude/rules/shell-scripts.md` apply. **Rules in this section override that file where they
conflict.**

@.claude/rules/shell-scripts.md

### Helper function mandate

Always use a helper from `scripts/functions/*.bash` when one applies (file mutation, prompts, OS detection, downloads,
paths, logging, arg guards, executable checks, symlinks, …). Scan the library before writing inline shell. Propose new
helpers (file + signature) for reusable logic. Add a helper to the topically matching file; ask before creating a new
topic file.

Helper replacements for generic rules:

| Instead of                            | Use                                                                                                           |
| ------------------------------------- | ------------------------------------------------------------------------------------------------------------- |
| `log`/`log_info`/`log_warn`/`log_err` | `log::log`, `log::with_date`, `log::warn`, `log::die` (keep its caller context)                               |
| `[[ -z/-n "$x" ]]`                    | `strings::is_empty`, `strings::is_not_empty`, `strings::is_blank`                                             |
| `command -v`, `which`                 | `commands::executable_exists`, `commands::executable_path` (skip repo wrappers on PATH)                       |
| `[[ -t 0 ]]`                          | `args::check_for_stdin`, `args::stdin_exists`                                                                 |
| `[[ -f X ]]` + manual die             | `files::exists`/`files::assert_exists`, `dirs::exists`/`dirs::assert_exists`, `symlinks::exists`              |
| `read -rp`                            | `prompt::yn`, `prompt::ny`, `prompt::for_value` (inline colored `read -rp` only if none fits, with a comment) |
| `tmp="$(mktemp)"`                     | `files::create_temp tmp_var` — no EXIT trap, no manual `rm`                                                   |
| `until cmd; do sleep; done`           | `retry::with_linear_backoff <tries> <sleep> <cmd...>` (exponential only with a reason)                        |
| `mkdir --parents`                     | `dirs::create` / `dirs::root_create`                                                                          |
| `ln --symbolic`                       | `symlinks::link_file`, `symlinks::link_dir`                                                                   |
| `cmd &` for GUI launch                | `misc::exec_gui <cmd> "$@"` (last statement)                                                                  |
| `\|\| { echo msg >&2; exit 1; }`      | `var="$(cmd)" \|\| log::die 'msg'` (split `local` declarations still apply)                                   |
| `[[ "$#" -eq N ]]` branching          | `args::no_args "$@"`, `args::has_num_args N "$@"`                                                             |

File mutation (`functions/files.bash`, `functions/symlinks.bash`): `files::write`, `files::append_to`, `files::move`,
`files::copy`, and `root_*` variants for root-owned destinations. They short-circuit on byte equality, preview a diff,
confirm, and create parent dirs. `_no_prompt` skips confirmation; `_quiet` skips status logging — use
`files::move_no_prompt_quiet` for temp-to-destination moves. When no root helper fits, use `sudo test`/`cmp`/`cat` for
checks and `sudo tee` for writes, never `sudo bash -c 'echo … > …'`.

`path::append`/`path::prepend`/`path::remove` need no explanatory comment; direct `PATH=` assignments still do.

Process substitution `<(...)` is banned; route producers to a `files::create_temp` file. Helpers like `arrays::diff`
use temp files internally.

### Standard top-level skeleton

```bash
#!/usr/bin/env bash

# @description One-line summary of what the script does.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

#shellcheck disable=SC1091
source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
args::handle_help_flag "$@"
args::check_no_args "$@"   # or check_exactly_N_args / check_at_least_N_args / check_at_most_N_args
```

- `args::handle_help_flag` goes before the arity guard. Pass-through scripts (forwarding `"$@"` to a wrapped tool) and
  standalone scripts are exempt.
- Pass-through scripts and variadic library functions omit the arity guard and carry a same-line comment saying so
  (`# pass-through: any arg count valid`). Silent omission is not allowed.
- Library functions use the same `args::check_*_args` guards.

Standalone scripts (`misc/`) inline this trap after the `IFS=` line:

```bash
trap 'printf "\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n" "$(date +%T)" "${0##*/}" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR
```

### Shdoc annotations

Every top-level executable (under `scripts/{non-interactive,interactive,install,set_up,misc}/`, `.ci/`, repo root)
carries a file-level shdoc block between the shebang and `set -Eeuo pipefail`: `@description`, `@arg $N` for each
positional (or `@noargs`), `@stdout`/`@stderr` when meaningful, `@exitcode N` for every non-zero exit, optional
`@example`. Helper functions in scripts get full annotation blocks too (except `main`). Library files need a block per
function but no file-level `@description`. Annotation blocks must not contain a bare `TODO` (a backticked `` `TODO` `` is
fine). Enforced by `.ci/check-shdoc-headers`.

### Library files and naming

- Library files (`scripts/functions/*.bash`): shebang only — no strict mode, no `IFS`, no sourcing, no `ERR` trap, no
  `main`, not executable, `snake_case.bash`, hand-created. Functions are namespaced `topic::name`. All other rules apply.
- Top-level executables: no extension, `kebab-case`, executable, created via `new-script`.

### Namerefs

A helper returning through `local -n` binds the reserved name `__<function>_ref` (`::` → `_`; add a role word when
binding several, e.g. `__arrays_diff_first_ref`), guarded on the preceding line with the same literal:

```bash
local -r out_name="$1"
namerefs::assert_available "${out_name}" '__shell_scripts_filter_ref'
local -n __shell_scripts_filter_ref="${out_name}"
```

Without it, a caller passing the same name gets a silent empty result. Write guards as `if …; then log::die; fi`, never
`[[ … ]] && log::die` (returns 1 under `set -e`). Enforced by `.ci/check-nameref-convention`.

### Preserving the executable bit

`files::create_temp` → edit → `files::move_no_prompt_quiet` replaces the file with mode `0600`, stripping the exec bit.
Bulk rewrites of scripts must edit in place or re-`chmod +x`, and confirm with `git diff --summary` (look for
`mode change 100755 => 100644`). `.ci/check-executable-bit` enforces modes; non-executable `install/`/`set_up/` scripts
must be listed in its `GATED` array.

## Gate Scripts (`.ci/`, `.githooks/`, root runners)

- **Hermetic devShell.** Every gate, `just` recipe, hook, and workflow step runs through `.ci/in-devshell`, which uses
  `nix develop --ignore-environment` with a fixed `--keep` allowlist (`KEEP_VARS`). Nothing else may spell
  `nix develop`. Per-call extra variables go in `IN_DEVSHELL_KEEP`, never the fixed list. `nix fmt` and `new-script`
  stay outside. `.githooks/commit-msg` is deliberately outside too (one tool, not worth a nix evaluation per commit) —
  do not wrap it. Enforced by `.ci/check-workflow-hermetic`.

- **Scan roots come from `REPO_DIR`**, never `SCRIPTS_DIR` (which points at the main checkout, so a worktree would be
  graded against the wrong tree). The provisioning runners are the exception. Enforced by `.ci/check-tree-scan-root`.

- **Empty scans fail.** `shell_scripts::find` and `find_root_only` exit 1 on no matches; never tolerate that, and never
  bend production code to fit a fixture — fix the fixture. A missing scan directory is a `log::die`, not `exit 0`.

- **`inherit_errexit`.** Every gate script carries this block (enforced by `.ci/check-inherit-errexit`):

  ```bash
  set -Eeuo pipefail
  # Without this, errexit is off inside every $(...) subshell, so a helper called
  # as `n="$(scan ...)"` runs past a failed command and this gate exits 0.
  shopt -s inherit_errexit
  IFS=$'\n\t'
  ```

- **No parser-backed predicates.** `errexit` is off throughout a function called from `if`/`while`/`||`/`&&`, so a
  helper that runs `yq`/`jq` must be a producer called plainly, not a predicate in a condition. Never write
  `2> /dev/null || printf 'false'` fallbacks that turn a parse failure into an answer. Enforced by
  `.ci/check-errexit-predicate`.

- **`core.hooksPath` has one writer:** `.ci/activate-githooks`, run from the devShell `shellHook`. No other file may set
  it, and `flake.nix` may not use `git-hooks.nix`. Enforced by `.ci/check-hooks-path-single-writer`.

- **Configured paths must resolve.** Paths in `.typos.toml`, `.github/labeler.yml`, `.yamllint.yml`, `.treefmt.nix`,
  `.editorconfig-checker.json`, and reviewdog's `exclude:` must be tracked or gitignored (`.ci/check-config-paths`). A new
  config with a path list gets added to its `SOURCES`.

- **Lint `EXEMPT` arrays** use space-free keys (`arrays::from_env_override` splits on spaces) and fail on stale entries.
  Keep them empty where possible.

- **Lints that grep for a token** must obfuscate it in their own source (`y[q]`, `j[q]`) so they don't flag themselves.

- **New `.ci/` scripts** need a paired `test/ci/<name>.bats` (`.ci/check-script-has-test`, which also covers root
  runners → `test/root/`, hooks → `test/ci/`, shims → `test/shims/`).

## Comments

Comments and docs describe the present state, not history. No issue/PR numbers, no accounts of prior implementations,
no plan references. If a shape looks odd, state the constraint in the present tense so nobody "fixes" it.
`.ci/check-comment-archaeology` rejects `#NNN`/`#NNNN` in code; the `comment-archaeology-sweep` skill handles the rest.
Never touch lint self-reference devices or `scripts/other/`.

## Testing

Tests are **specification-driven**: encode what a function should do (name, doc comment, invariants), not what it
currently does. On failure, default to fixing the function; escalate genuine ambiguity.

- Every helper in `scripts/functions/*.bash` has tests in `test/functions/<topic>.bats` covering each behavior, the
  edge-case sweep (empty, whitespace, single/multi element, separators, arg-count boundaries), every arity guard, every
  `@exitcode`, and success/failure paths. New helpers ship with tests in the same PR, plus any new test helper needed to
  stub side effects.
- `.bats` files have **no shebang** and are not executable. `setup()` does `load '../test_helper/common'` and sources
  the file under test plus its dependencies.
- **Arity tests assert the guard message**, not just `assert_failure`
  (`assert_output --partial 'Expected exactly 1 argument'`). Enforced by `.ci/check-vacuous-arity-tests`.
- **Use bats-assert, never bracket tests on `${output}`/`${stderr}`/`${status}`**: `assert_output`/`refute_output`
  (`--partial`, `--regexp`), `assert_success`, `assert_failure N` (prefer an explicit code). Under
  `run --separate-stderr`, `${output}` is stdout only — use `assert_stderr`/`refute_stderr` (they exist; they live in
  `assert_output.bash`). Numeric comparisons and length tests on output stay as brackets. Enforced by
  `.ci/check-stderr-assertions`. Fixtures holding a deliberate violation must build it at runtime.
- **bats-assert and bats-support come from flake inputs**, not nixpkgs — the nixpkgs bats-assert release lacks
  `assert_stderr`. Never simplify `flake.nix` back to the nixpkgs packages. Renovate updates them via the `nix` manager
  and `lockFileMaintenance`, both explicitly enabled (`.ci/check-renovate-invariants`).
- `path::*` mutate `PATH`: call them directly, not under `run`.
- `read -rp` prompt text goes to `/dev/tty` and cannot be asserted; test file effects only.

Test helpers in `test/test_helper/`: `dual_mode` (stdin-or-file helpers), `env_file_fixture`, `path_shim` (stub
commands), `os_release_fixture`, `cli_shim` (record calls, canned/stateful output, passthrough `sudo`), `git_fixture`.
For prompt tests, set `SCRIPTS_AUTO_ANSWER=y` to accept defaults, or feed stdin through `bash -c` with `<<<`.

### Test safety

- **Never run `run-install-scripts`/`run-set-up-scripts` without `INSTALL_DIR_OVERRIDE`/`SET_UP_DIR_OVERRIDE`** — they
  execute real provisioning scripts; stubbing `sudo` does not make them safe.
- **Fixture repos go through `git_fixture::init`/`git_fixture::run`**, never raw `git -C` (reserved for probing git's
  own discovery). `common.bash` scrubs `GIT_*`, pins git config to `/dev/null`, and confines tests to
  `BATS_TEST_TMPDIR`; `pre-push` calls `git::clear_local_env`; `run-tests` fails if HEAD/config/index change. Keep all
  of these.
- Tests must not invoke real `nix`; stub it.
- Some tests clear `BASH_ENV` so a child bash does not re-source `~/.bashrc` and escape the shim `PATH`. That makes
  them invisible to kcov; keep them that way.

### Coverage

`.github/actions/coverage` runs kcov in two scopes, uploaded under separate Codecov flags: `functions`
(`scripts/functions`, the headline number) and `gates` (`.ci/`, `.githooks/`, root runners). Keep them separate.

- kcov is patched in `flake.nix` (`.nix/kcov-ansi-c-quoting.patch`, plus a PS4 `postPatch`). Don't drop either;
  `.gitignore` needs its `!.nix/*.patch` negation.
- Many uncovered lines are lexer artifacts that no test can hit: embedded awk/jq/sed bodies, `done <redirect>` lines,
  bare subshell parens, array literal members, the first line of a wrapped command. Don't chase them.
- A file suddenly reading 0% while its tests pass means a harness problem, not a test gap.
- Don't run the coverage suite with `bats --jobs`: interleaved trace output makes the number nondeterministic.
- Read `cobertura.xml` only after kcov exits; it is written progressively.
- Write kcov output outside the repo (`$RUNNER_TEMP`, `/tmp`), or `check-scripts` picks up its helper scripts.

## Before Committing

1. `nix fmt`
1. `./.ci/in-devshell ./run-all-checks`

`run-all-checks` is verify-only and aggregates failures across `./check-scripts`, `nix flake check`,
`.ci/run-governance-checks`, `.ci/run-lint-checks` (ending with the docs build), and `./run-tests`. `nix flake check`
evaluates the git tree, so **`git add` new files before trusting a green run**. The `.githooks/pre-push` hook runs the
same gate (several minutes; bypass with `git push --no-verify`). Hooks activate automatically on devShell entry.

## Merging PRs

- Merge commits only; the PR title becomes the commit subject and must be a Conventional Commit (`pr-title-lint`).
- Every branch commit is linted by `commitlint` and must be signed. Clean up WIP commits with an interactive rebase
  before merging.
- The `protect-main` ruleset has no bypass actors; a red required check blocks everyone.

## CI

- **Changed-path gating** (`.ci/decide-changed-tests`) is a denylist: a path runs the suite unless it matches an
  `IRRELEVANT` glob. Never invert it to an allowlist. `.editorconfig` is test-relevant.
- **Every job runs `step-security/harden-runner` first with `egress-policy: block`** and an explicit
  `allowed-endpoints`, written as a single-line `>-` folded scalar (`|-` silently collapses the list into one endpoint;
  yamlfmt rewraps multi-line lists). `.yamllint.yml`'s `line-length.max: 600` exists for this.
- Blocked egress is a silent drop; a green job may have had calls blocked. Find blocked hosts in the harden-runner Post
  Run log: `gh run view --job "${JOB_ID}" --log | grep -E 'domain not allowed: [^[:space:]]+'` (strip the trailing
  dot, append `:443`). Some hosts only appear on a cold Nix cache.
- Prefer exact hosts. Jobs that install Nix carry `hosted-compute-*.githubapp.com:443` because runner hosts rotate.
- `keybase.io:443` in `coverage.yml` is required: codecov-action verifies its CLI with a key fetched from there, and a
  blocked fetch quietly falls through to an unverified binary. Codecov's Sentry host stays blocked on purpose.
- Every host linked from tracked markdown must be in `links.yml`'s allowlist (`.ci/check-links-allowed-endpoints`).
- Non-Nix jobs set `disable-sudo-and-containers: true`; Nix jobs cannot (the installer needs root) and are listed in
  that lint's `EXEMPT`. The deprecated `disable-sudo` input is forbidden. A job that needs Docker cannot be
  sudo-hardened, so run its tool from the devShell instead.
  `disable-file-monitoring` and `disable-telemetry` stay `false`.
- When reading a `with:` value in yq, filter `to_entries` by key; `//` treats `false` as absent.
- A red Renovate action-bump PR with connection errors usually means the action's hosts changed; check the Post Run log.
