# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal collection of bash scripts for system setup, package install, and day-to-day utilities on the user's Linux machines. Pure shell, no build system; helper functions in `functions/*.bash` are covered by a BATS test suite under `test/`.

## Layout

- `main/` — primary utility scripts (on `PATH`).

- `other/` — third-party scripts copied verbatim from elsewhere. **Never modify anything under `other/` unless explicitly told to touch a specific file in there.** This applies to formatting, shellcheck fixes, refactors, renames, or any other automated cleanup. On `PATH`; excluded from `format-scripts` / `shellcheck-scripts`.

- `install/` — numbered scripts run in order by `run-install-scripts` to provision a new machine. Files starting with all-caps names (e.g. `00_DISTRO_PACKAGES`, `70_WORK_ONLY`) are markers/data with executable bit off — the runner skips non-executable files. `90_REMOVE` etc. follow same pattern.

- `set_up/` — idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script must self-check whether it should run.

- `misc/` — one-off setup scripts (not on `PATH`, not auto-run). Scripts here are expected to be **standalone** — runnable on a fresh machine by someone without access to this repo's function library. Do NOT source `functions.bash` from `misc/` scripts; inline anything they need (including the `ERR` trap — see Script Conventions).

- `functions/` — bash function library, all sourced via `functions.bash` (loops `functions/*.bash`).

- `lib/` — vendored Groovy jars (used by some scripts).

- `.ci/` — repo-tooling scripts invoked by CI and `just` (e.g. `build-docs`, `check-shdoc-headers`). Not on `PATH`.

## Required Environment

The user's `~/.profile` exports a fixed set of env vars (`SCRIPTS_DIR`, `XDG_*`, `PERSONAL_PROJECTS_DIR`, etc.) that this repo relies on. They are always set in the environment by the time any script runs — interactive shells source `~/.profile`, and the `run-install-scripts` / `run-set-up-scripts` runners source it explicitly. Treat the full set as guaranteed. Read `~/.profile` to enumerate the available vars and their definitions.

- **Reuse, don't hardcode.** When a script references a path or hostname covered by one of these vars, use the env var literal directly: `"${SCRIPTS_DIR}/functions.bash"`, `"${XDG_CONFIG_HOME}/foo/bar"`, `"${PERSONAL_PROJECTS_DIR}/some-repo"`, etc. Shell expands env vars natively — no templating needed.

- **No fallbacks.** Do NOT add `${VAR:-default}` defensive defaults or `set -u` defenses for any of these vars (including `SCRIPTS_DIR`). Failure under `set -u` is the desired behavior if the environment is broken — the user wants to fix the environment, not paper over it.

- **No env-var prefix when invoking repo scripts.** When running `./check-scripts`, `./format-scripts`, `./shellcheck-scripts`, or any other script in the repo, do NOT prefix the command with `SCRIPTS_DIR=...` — the env var is already set.

- **Ignore conditional exports.** `EDITOR`, `VISUAL`, `PAGER`, `MANPAGER`, `FILE_MANAGER`, `TAILNET_IP`, `TAILNET_CIDR`, `TERM`, etc. are gated on `__executable_exists` / `case` / runtime probes in `~/.profile`; they're not meant for cross-file reuse and are not guaranteed to be set.

- **`PATH` membership.** `main/` and `other/` are always on `PATH`. `install/`, `set_up/`, `misc/`, `.ci/` are not.

- **`misc/` exemption.** Scripts under `misc/` are explicitly standalone — they must NOT depend on this repo's env or functions. Hardcoded paths are acceptable there.

### Sourcing `functions.bash`

Every non-`misc/` script sources `"${SCRIPTS_DIR}/functions.bash"`. Exception: a small number of Docker-related scripts (e.g. `main/docker-grype-scan`, `main/docker-trivy-scan`) source `${DOCKER_COMPOSE_DIR}/functions.bash` from a separate Docker repo instead. That file transitively sources `${SCRIPTS_DIR}/functions.bash`, so all helpers from this repo (`log::enable_err_trap`, `log::log`, `log::die`, etc.) ARE available — no need to inline equivalents in those scripts.

## Common Commands

- `./format-scripts [--check] [<file-or-dir>...]` — runs `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write` over the given files/dirs, or over all shell files except `other/` when no args. `--check` swaps `--write` for `--diff` (preview mode, no in-place changes).

- `./shellcheck-scripts [<file-or-dir>...]` — runs `shellcheck` over the given files/dirs, or over the same default set when no args. All scripts must pass.

- `./check-scripts [<file-or-dir>...]` — combined check: runs `shfmt --diff` and `shellcheck` over the same set, aggregates exit codes (exits non-zero if either fails). Use this for CI/pre-commit-style verification.

- `./run-install-scripts` — provision new machine. Sources `~/.profile`, validates sudo, runs every executable file under `install/` in `LC_COLLATE=C` order.

- `./run-set-up-scripts` — same pattern, recursive over `set_up/**/*`.

- `main/new-script <path>` — scaffolds a new script with the standard header + exec bit.

- `./run-tests [<bats-args>...]` — runs BATS tests under `test/functions/` recursively when called with no args, or forwards args to the vendored bats binary. Default invocation uses `bats --jobs $(nproc)` for parallel execution.

To gate a script from the `install`/`set_up runners`, remove its executable bit (`chmod -x`).

## Function Library

`functions/` is organized by topic — `args`, `arrays`, `commands`, `docker`, `downloads`, `env`, `files`, `grep`, `http`, `json`, `log`, `mvn`, `network`, `os`, `packages`, `path`, `prompt`, `retry`, `sdkman`, `strings`, `symlinks`, `system`, `systemctl`, `text`, `time`, etc. When adding a helper, drop it in the topically-matching file; it's auto-sourced. If no existing topic fits, Claude may create a new `functions/<topic>.bash` file — but must ask first before adding the new topic.

## Script Conventions

The generic shell-script rules in `.claude/rules/shell-scripts.md` apply to this repo. **Rules in this section override rules in that file when they conflict** — every override is called out with a "**Overrides**" line so the divergence is explicit.

@.claude/rules/shell-scripts.md

### Helper function mandate

- Claude MUST use the helper functions in `functions/*.bash` whenever an applicable helper exists. Do not write inline equivalents for operations that already have a helper (file mutation, prompts, OS detection, downloads, path manipulation, logging, arg-count guards, executable existence, symlinks, etc.). Before writing inline shell, scan `functions/*.bash` for a matching helper.

- Claude may propose new helper functions when a piece of logic looks reusable across scripts, even if it is currently only needed in one place. Suggest the new helper (with proposed file and signature) rather than silently inlining.

### Shdoc annotations for top-level scripts

Every top-level executable shell script (any file with a bash/sh shebang under `main/`, `install/`, `set_up/`, `misc/`, `.ci/`, or the project root) must carry a file-level shdoc header block immediately after the shebang line and before the `set -Eeuo pipefail` pragma.

Required tags (each used where applicable):

- `@description` — one-line prose summary; continuation lines allowed with aligned comment text.

- `@arg $N <name> <description>` for every positional parameter, OR `@noargs` if the script takes none.

- `@stdout <description>` if the script emits meaningful output to stdout (beyond logging).

- `@stderr <description>` if the script emits non-trivial diagnostic output to stderr (beyond standard `log::log`/`log::warn`/`log::die`).

- `@exitcode N <meaning>` for every non-zero exit code the script can produce.

- `@example` — optional but encouraged for any script with non-obvious CLI shape.

Header position — between the shebang and `set -Eeuo pipefail`:

```bash
#!/usr/bin/env bash

# @description One-line summary of what the script does.
# @arg $1 input path to input file
# @exitcode 0 success
# @exitcode 1 input file missing

set -Eeuo pipefail
IFS=$'\n\t'
```

Helper functions defined inside top-level scripts get the same full shdoc annotation block as library functions. **Exception:** the `main` function is exempt — the file-level header covers it.

`misc/` standalone scripts (those that do not source `functions.bash`) follow the same rule. Shdoc tags are plain comments and do not depend on the function library.

Files excluded from `shell_scripts::find` (`.shdoc/`, `other/`, vendored bats submodules under `test/`) are excluded from this rule.

Library files under `functions/*.bash` follow a related but distinct rule: every function must have a preceding shdoc annotation block, but the file-level `@description` is intentionally not required because library files are documented function-by-function. `.ci/check-shdoc-headers` enforces both rules in a single audit pass (top-level scripts get the file-level + per-helper check; library files get the per-function check only). Both contribute to the audit's exit code, and the audit is wired into `check-scripts` so any regression fails the aggregate gate.

### Standard top-level skeleton

Carry the file-level shdoc header (see [Shdoc annotations for top-level scripts](#shdoc-annotations-for-top-level-scripts)), source the function library, enable the `ERR` trap, handle `-h`/`--help`, then guard arg count:

```bash
#!/usr/bin/env bash

# @description One-line summary of what the script does.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

#shellcheck disable=SC1091
source "${SCRIPTS_DIR}/functions.bash"
log::enable_err_trap
args::handle_help_flag "$@"
args::check_no_args "$@"   # or check_exactly_N_args / check_at_least_N_args / check_at_most_N_args
```

- `log::enable_err_trap` (from `functions/log.bash`) installs an `ERR` trap that prints a red, prefixed `ERROR: line N (exit C): cmd` line to stderr when any unhandled command fails under `set -e`. Call it once, immediately after sourcing `functions.bash`. It complements `log::die` (explicit user-visible failures) — the trap catches everything else.

- `args::handle_help_flag "$@"` (from `functions/args.bash`) scans `"$@"` for `-h`/`--help` and, if present, prints help text derived from the script's file-level shdoc header (via `args::print_help`) and exits 0. Call it directly after `log::enable_err_trap` and before any arg-count guard — otherwise `--help` would be rejected as an unexpected argument. Pass-through scripts (those forwarding `"$@"` verbatim to an underlying tool) and standalone scripts under `misc/` are exempt: pass-throughs let the wrapped tool handle its own `--help`; standalones cannot source `functions.bash`.

- Create new scripts via `main/new-script <path>` (handles header + exec bit + `args::handle_help_flag` line).

### Arg-count guards

- Use `args::check_no_args "$@"` / `check_exactly_N_args` / `check_at_least_N_args` / `check_at_most_N_args` from `functions/args.bash` at the top of every top-level script and library function with a fixed arity.

- **Pass-through scripts and variadic library functions are exempt.** A pass-through script forwards `"$@"` to an underlying tool (e.g. `main/claude` wraps the real `claude` binary, `main/sync-flatpaks` accepts optional filter args) and has no fixed arity. A variadic library function takes 0+ items of the same kind. In both cases, omit the `args::check_*_args "$@"` guard and add a same-line comment explaining why: `# pass-through: any arg count valid` (or similar). The comment is mandatory — silent omission is not allowed.

- Library functions in `functions/*.bash` use the same `check_*_args "$@"` guards as top-level scripts.

- For predicate branching on caller arg count (e.g. choosing a default vs. consuming `$1`), use `args::no_args "$@"` or `args::has_num_args N "$@"` from `functions/args.bash` — never inline `[[ "$#" -eq N ]]`. Use `args::no_args` for the zero-arg case (not `args::has_num_args 0`).

### Library file conventions

Library files under `functions/` get only the shebang — do NOT add `set -euo pipefail` or source `functions.bash`. Strict mode is owned by the parent script that sources them.

**`functions/*.bash` exemption list** — library files are exempt from the following rules that apply to top-level scripts:

- `set -Eeuo pipefail` strict-mode pragma (parent owns strict mode)

- `IFS=$'\n\t'` (parent owns IFS)

- `source "${SCRIPTS_DIR}/functions.bash"` (would be circular)

- `log::enable_err_trap` call (parent installs the trap)

- The inline `ERR` trap form (only used by standalone `misc/` scripts)

- Top-level `args::check_*_args "$@"` guard (library files have no top-level args; functions inside them still use `check_*_args` guards)

- `main "$@"` final-line / `function main()` requirement (library files have no entry point)

- File-layout rule that constants must precede functions (library files contain only function definitions; no constants section)

- File extension: library files use `.bash` (top-level executables have no extension)

- Filename casing: library files use `snake_case` (top-level executables use `kebab-case`)

- Executable bit: library files must NOT be executable (top-level scripts must be executable)

- Creation via `main/new-script`: library files are hand-created (the helper is for top-level executables)

All other rules (helper-function usage, quoting, `[[ ]]` over `[ ]`, `(( ))` arithmetic, comment block above non-trivial functions, `local`/`local -r` inside every function, predicate-function return-via-exit-status, namespaced `::` function names, etc.) apply equally to library files.

### File extensions and filename conventions

- Top-level executables (everything under `main/`, `install/`, `set_up/`, `misc/`, `.ci/`) have no extension; library files under `functions/` use the `.bash` extension and are NOT executable.

- Executables use kebab-case (`new-script`, `format-scripts`, `run-install-scripts`); library files use snake_case with the `.bash` extension (`functions/files.bash`, `functions/log.bash`).

- Library functions are namespaced with `::`: a helper in `functions/files.bash` is `files::exists`, in `functions/log.bash` is `log::log`, etc. Internal/private helpers (not used across files) may keep plain `snake_case`.

### `set_up/` idempotency

Scripts under `set_up/` must be idempotent and self-gate — check current state before mutating, and exit cleanly when there is nothing to do.

### Standalone `misc/` ERR trap

Standalone scripts that do NOT source this repo's `functions.bash` (everything in `misc/`) cannot call `log::enable_err_trap`. Inline the trap directly after the `IFS=` line. (Note: scripts that source `${DOCKER_COMPOSE_DIR}/functions.bash` DO have access to this repo's helpers — that file transitively sources `${SCRIPTS_DIR}/functions.bash` — so use `log::enable_err_trap` there, not the inline form.)

```bash
trap 'printf "\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n" "$(date +%T)" "${0##*/}" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR
```

### Logging helpers

**Overrides** the generic `log` / `log_info` / `log_warn` / `log_err` template in `.claude/rules/shell-scripts.md`. Use the repo's helpers from `functions/log.bash` (all color-coded, written to stderr, prefixed with `${0##*/}`):

- `log::log` — green, info-level

- `log::with_date` — green, info-level with full date

- `log::warn` — yellow, warn-level (use for non-fatal problems)

- `log::die` — red, error-level + `exit 1` with caller context

There is no separate `log_info` (use `log::log`) or `log_err` (use `log::die` if fatal, or `log::warn` if not). `log::die` includes caller context via `${BASH_SOURCE[1]}:${FUNCNAME[1]}:${BASH_LINENO[0]}` — preserve this when modifying the helper.

### Stdin presence

Helpers `args::check_for_stdin` / `args::stdin_exists` from `functions/args.bash`. No inline `[[ -t 0 ]]`.

### Existence checks

Helpers `files::exists` / `files::assert_exists` (`functions/files.bash`), `dirs::exists` / `dirs::assert_exists` (`functions/dirs.bash`), `symlinks::exists` (`functions/symlinks.bash`). Use the `assert_*` variants for entry-point validation (they call `log::die` with a consistent message); use the bare predicates for branching. No inline `[[ -f X ]]` + manual `log::die` rolls.

### Interactive prompts

Helpers `prompt::yn` / `prompt::ny` / `prompt::for_value` from `functions/prompt.bash`. Fall back to inline `read -rp $'\e[0;33mPrompt: \e[0m'` (colored `$'...'` form) only when no helper fits, and document why with a comment.

### Empty-string tests

**Overrides** the generic `[[ -z "$x" ]]` / `[[ -n "$x" ]]` rule in `.claude/rules/shell-scripts.md`. Use helpers `strings::is_empty` / `strings::is_not_empty` / `strings::is_blank` from `functions/strings.bash` instead of inline `[[ -z "$x" ]]` / `[[ -n "$x" ]]`. `strings::is_blank` is true for empty OR all-whitespace strings.

### Tool availability

**Overrides** the generic `command -v tool >/dev/null 2>&1` rule in `.claude/rules/shell-scripts.md`. Use `commands::executable_exists` from `functions/commands.bash` (uses `type -aPf`, excludes builtins/aliases/functions, and strips `main/` and `other/` from `PATH` so wrappers in those dirs don't mask the real binary). `command -v` would return scripts in `main/` that mask command names (e.g. `mvn`, `gradle`).

For absolute-path resolution (when you need the path, not just a yes/no): helper `commands::executable_path` from `functions/commands.bash`. Same PATH-stripping as `commands::executable_exists`. No inline `command -v BIN` or `which BIN` — those would return wrappers in `main/`/`other/` instead of the real binary.

### Tempfiles

**Overrides** the generic `tmp="$(mktemp)"` rule in `.claude/rules/shell-scripts.md`. Use the `files::create_temp tmp_var_name` helper from `functions/files.bash`. Do NOT install an EXIT trap or otherwise manually `rm` the temp file at end of script. Temporary files created under `/tmp` are managed by the OS (tmpfs reboot wipe + systemd-tmpfiles age-based cleanup), so process-level cleanup adds complexity (EXIT-trap clobbering between multiple temp files, accounting for early exits) without buying anything. Standalone scripts under `misc/` that cannot source `functions.bash` should call `mktemp` directly and similarly omit any cleanup trap.

### Network retry

Use `retry::with_linear_backoff <max_tries> <base_sleep> <cmd...>` from `functions/retry.bash`. Prefer linear backoff unless there is a specific reason to grow the wait exponentially (in which case use `retry::with_exponential_backoff`). Do NOT hand-roll `until cmd; do ...; sleep N; done` loops.

### File mutation helpers (idempotent)

Helpers in `functions/files.bash` and `functions/symlinks.bash` — `files::write`, `files::append_to`, `files::move`, `files::move_no_prompt`, `files::copy`, `symlinks::link_file`, `symlinks::link_dir`. They implement the standard pattern: `cmp --silent` short-circuit on byte equality, `diff --color --unified ... || true` preview, `prompt::yn` confirmation, and parent-dir auto-creation via `dirs::create "$(dirname "$dest")"`. Variant suffixes:

- `_no_prompt`: skips the diff/confirm step — use for programmatic temp-file-to-destination moves where interactive confirmation would be inappropriate (`files::move_no_prompt`, `files::move_no_prompt_quiet`). Always combine with `_quiet` for temp-to-dest moves: use `files::move_no_prompt_quiet` so the internal move produces no log noise.

- `_quiet`: omits the `log::log` "Moving/Moved", "Copying/Copied", "Writing/Wrote", "Appending/Appended" status messages — use when that output is unwanted noise (`files::move_quiet`, `files::move_no_prompt_quiet`, `files::copy_quiet`, `files::write_quiet`, `files::append_to_quiet`).

Parent-dir auto-creation before writing/moving/copying: helpers `dirs::create "$(dirname "${dest}")"` (or `dirs::root_create` for sudo writes). No inline `mkdir --parents` / `mkdir -p`.

Root-owned destinations: `root_*` variants (`files::root_write`, `files::root_write_quiet`, `files::root_append_to`, `files::root_append_to_quiet`, `files::root_move`, `files::root_move_quiet`, `files::root_copy`, `files::root_copy_quiet`, `dirs::root_create`). When no helper fits, use `sudo test -f`, `sudo cmp`, `sudo cat` for state checks, and `echo "${content}" | sudo tee [--append] "${file}" > '/dev/null'` for the write — no `sudo bash -c 'echo ... > ...'`.

Symlinks: helpers `symlinks::link_file` / `symlinks::link_dir` from `functions/symlinks.bash`. No inline `ln --symbolic` / `ln -s` — the helpers handle the canonical-target short-circuit, diff/prompt confirmation, and parent-dir creation.

### Custom-message exit on command-substitution failure

**Overrides** the generic `|| { echo "msg" >&2; exit 1; }` form in `.claude/rules/shell-scripts.md`. Use `log::die` instead:

```bash
# right — when a custom message is needed
var="$(cmd)" || log::die "cmd failed"
```

The split-declaration rule for `local`/`readonly`/`declare`/`export` still applies — those mask the substitution's exit status, so `local var="$(cmd)" || log::die "..."` never triggers.

### `PATH` modification comment exemption

The generic rule requires a comment on any `PATH` modification. The repo's PATH-related helper functions (`path::append`, `path::prepend`, `path::remove`) are self-documenting — invocations do not need the comment. Direct `PATH=` assignments and `export PATH=...` still do.

### BATS test coverage for helpers

**Every helper function in `functions/*.bash` must have thorough BATS unit tests in `test/functions/<topic>.bats`.** Applies to both new and existing helpers — if you touch or notice an untested helper, the expectation is to add coverage in the same PR (or a follow-up PR explicitly tracked in the description). Tests are spec-driven (encode what the helper *should* do, not what the current implementation happens to do — see the "Testing philosophy" section below). Required coverage per helper:

1. One positive assertion per intended behavior.
2. The standard edge-case sweep — empty input, whitespace-only, single element, multi-element, leading/trailing separators, boundary arg counts.
3. Every arity guard branch (e.g. "dies with 0 args", "dies with 2 args" for a 1-arg helper).
4. Every documented `@exitcode`.
5. For stateful or side-effecting helpers, both the success path and any failure paths (`log::die`, missing dependency, etc.).

When adding a helper to an existing topic file that already has a `.bats` file, extend that file. When adding a new topic file, create the matching `.bats` file in the same PR. The PR is not complete until `./run-tests` is green and coverage matches the bullets above. If a helper genuinely cannot be tested without mocking a side effect that has no existing test-helper for it (sudo, network, package manager), add the helper and the new test-helper together — do not ship the helper untested.

### Process substitution and background commands

The generic ban on `<(...)` and `cmd &` from `.claude/rules/shell-scripts.md` applies here. Project-specific replacements:

- `<(...)` → use `files::create_temp tmp_var` and route the producer to that file (the parent's `pipefail` + `set -e` then catch failures). For the `comm -23 <(arrays::to_lines a) <(arrays::to_lines b)` shape used by `arrays::diff` and friends, keep the helper API but rewrite the implementation to use temp files internally.

- `cmd &` (for GUI launcher detachment) → `misc::exec_gui kate "$@"` (wraps `exec setsid --fork`). Must be the last statement in the calling script (`exec` does not return).

## Testing

Every helper in `functions/*.bash` is exercised under [BATS](https://github.com/bats-core/bats-core); each `functions/<topic>.bash` has a matching `test/functions/<topic>.bats` (or a topic-prefixed group of `.bats` files). BATS itself, plus `bats-support` and `bats-assert`, are vendored as git submodules under `test/`.

The mandate that every new public helper ships with thorough BATS tests in the same PR is documented under [BATS test coverage for helpers](#bats-test-coverage-for-helpers) above. Private `_`-prefixed internal helpers may be covered indirectly through the public callers that exercise them.

### Layout

```text
test/
  bats/                       # submodule — bats-core (excluded from format/shellcheck)
  test_helper/
    bats-support/             # submodule (excluded)
    bats-assert/              # submodule (excluded)
    common.bash               # shared loader; sourced by each .bats setup()
  functions/
    strings.bats              # tests for functions/strings.bash
    args.bats                 # tests for functions/args.bash
    path.bats                 # tests for functions/path.bash
```

### Running

- `./run-tests` — runs everything under `test/functions/`.

- `./run-tests test/functions/strings.bats` — single file.

- `./run-tests --filter-regex 'is_blank' test/functions/strings.bats` — subset by name.

### Bootstrap on a fresh clone

```bash
git submodule update --init --recursive
```

The `run-tests` wrapper aborts with this hint if `test/bats/bin/bats` is missing.

### Testing philosophy

Tests are **specification-driven**: each test encodes what the function *should* do based on its name, doc comment, and reasonable invariants — not what the current implementation happens to do. When a test fails, the default response is to fix the function, not the test. Genuinely ambiguous cases get raised before being silently encoded.

### Adding tests

1. Pick a `functions/<name>.bash` file.
2. Create `test/functions/<name>.bats`.
3. In `setup()`, `load '../test_helper/common'` and `source` the file under test plus any of its dependencies (e.g. `args.bash` for any helper that uses `args::check_*`).
4. Per function: one assertion per intended behavior, plus the standard edge-case sweep — empty input, whitespace-only, single char, multi-line, leading/trailing separators, arg-count boundaries.
5. Run `./run-tests test/functions/<name>.bats` and triage failures: genuine bug → fix the function; ambiguity → escalate; test bug → fix the test.

### Dual-mode helper

Several helpers (`text::*`, `json::sort`, `files::hash`) accept input from EITHER stdin OR a file path. To avoid copy-pasting the test pattern, source `test/test_helper/dual_mode` in `setup()` and use `dual_mode::assert_stdin <fn> <input> <expected>` and `dual_mode::assert_file <fn> <input> <expected>`. The latter writes input to a per-test tmpfile under `${BATS_TEST_TMPDIR}` (BATS auto-cleans). `grep::*` helpers are also dual-mode (1 arg = stdin + pattern; 2 args = file + pattern) but take an extra pattern arg, so the `dual_mode::assert_*` helpers don't fit — test them directly with `run` + heredoc / tmpfile fixtures (see `test/functions/grep.bats` for the `run_stdin_grep` / `run_file_grep` pattern).

For env-file tests (read+write tmpfile fixtures), source `test/test_helper/env_file_fixture` and use `env_file_fixture::create <content> [<basename>]` which writes content to `${BATS_TEST_TMPDIR}/<basename>` (default `env`) and echoes the path.

For tests that need to stub external commands (e.g. `hostname`, fake binaries for `commands::*` tests), source `test/test_helper/path_shim` and use `path_shim::add <name> <body>` to drop an executable shim into a per-test `${BATS_TEST_TMPDIR}/bin` (auto-prepended to `PATH`).

For `os.bats` tests that need to stub `/etc/os-release`, source `test/test_helper/os_release_fixture` and call `os_release_fixture::create KEY=VALUE ...` to write a fixture file under `${BATS_TEST_TMPDIR}`, then `os_release_fixture::install_source_override` to install a shell function override of the `source` builtin that redirects calls to `/etc/os-release` at the fixture. The override is a function (functions take precedence over builtins for unqualified names) and is exported, so it propagates into bash subshells inside `os::release_field`.

For tests that need to record CLI invocations or shim sudo, source `test/test_helper/cli_shim` and use `cli_shim::record <name>` (bare logger), `cli_shim::record_with_output <name> <stdout> [<exit>]` (canned output), `cli_shim::record_stateful <name> <out1> <out2> ...` (Nth output on Nth call; repeats last once exhausted), or `cli_shim::install_passthrough_sudo` (sudo→exec rest with flag stripping). Read back via `cli_shim::calls <name>` / `cli_shim::call_count <name>`.

### Prompt-mocking pattern

Interactive `env_file::prompt_*` tests use a hybrid strategy:

- **Default-accepted path** — set `SCRIPTS_AUTO_ANSWER=y` and supply a default. `misc::auto_answer` short-circuits the `read -rp` and the default is written to the file.

- **Typed-value path** — wrap the call in `bash -c "..."` with stdin fed via `<<<` (use the `prompt_via_stdin` helper in `env_file.bats`). The `read -rp` fires and reads the typed value from stdin.

`passwords::generate` and `passwords::generate_with_symbols` are mocked in `setup()` (and re-declared inside `prompt_via_stdin` since function definitions don't survive `bash -c` boundaries) so password-fn tests are deterministic. Mocks return `MOCK_PASSWORD_64` and `MOCK_PASSWORD_SYMBOLS` respectively.

Note: `read -rp` writes the prompt text to `/dev/tty`, which BATS `run` does not capture. Prompt-text content (var name, info, default substrings shown to the user) cannot be asserted via `assert_output`. Tests verify file mutation only; UI text is not under test.

### `path::*` testing note

`path::remove`, `path::append`, and `path::prepend` mutate the caller's `PATH`. Do NOT wrap them in `run` — `run` executes in a subshell and the mutation is discarded. Set a local `PATH`, call the function directly, then assert on `PATH`. BATS isolates each `@test` in its own subshell, so mutations do not leak between tests.

## Before Committing

Run `./format-scripts` then `./shellcheck-scripts`. Both must be clean. Both accept optional file/dir arguments — pass only the changed files for a faster check, or run with no args to cover the whole repo. To verify without writing, use `./check-scripts` (or `./format-scripts --check`) which runs `shfmt --diff` and `shellcheck` together and aggregates their exit codes.

The tracked `.githooks/pre-push` hook runs `./check-scripts` automatically on push (activated per-clone via `git config --local core.hooksPath .githooks`), so the same gate also fires at push time as a safety net.

## Merging PRs

- Rebase merge is the only allowed merge method on this repo. Squash and merge-commit are disabled in repo settings and in the `protect-main` ruleset (`allowed_merge_methods: ["rebase"]`). The `main` branch also has a `required_linear_history` rule.
- Consequence: every commit on a feature branch lands verbatim on `main` and is independently linted by the `commitlint` workflow. Each commit on a branch must satisfy Conventional Commits (`type: subject`) on its own — there is no squash subject to fall back on.
- Before merging, clean the branch with `git rebase --interactive` so WIP / "fix review" / typo commits do not leak onto `main`.
- Do not propose enabling squash merge to "fix" a noisy branch — fix the branch instead.
