# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal collection of bash scripts for system setup, package install, and day-to-day utilities on the user's Linux machines. Pure shell, no build system; helper functions in `functions/*.bash` are covered by a BATS test suite under `test/`.

## Required Environment

The user's `~/.profile` exports a fixed set of env vars (`SCRIPTS_DIR`, `XDG_*`, `PERSONAL_PROJECTS_DIR`, etc.) that this repo relies on. They are always set in the environment by the time any script runs — interactive shells source `~/.profile`, and the `run-install-scripts` / `run-set-up-scripts` runners source it explicitly. Treat the full set as guaranteed. Read `~/.profile` to enumerate the available vars and their definitions.

- **Reuse, don't hardcode.** When a script references a path or hostname covered by one of these vars, use the env var literal directly: `"${SCRIPTS_DIR}/functions.bash"`, `"${XDG_CONFIG_HOME}/foo/bar"`, `"${PERSONAL_PROJECTS_DIR}/some-repo"`, etc. Shell expands env vars natively — no templating needed.
- **No fallbacks.** Do NOT add `${VAR:-default}` defensive defaults or `set -u` defenses for any of these vars (including `SCRIPTS_DIR`). Failure under `set -u` is the desired behavior if the environment is broken — the user wants to fix the environment, not paper over it.
- **No env-var prefix when invoking repo scripts.** When running `./check-scripts`, `./format-scripts`, `./shellcheck-scripts`, or any other script in the repo, do NOT prefix the command with `SCRIPTS_DIR=...` — the env var is already set.
- **Ignore conditional exports.** `EDITOR`, `VISUAL`, `PAGER`, `MANPAGER`, `FILE_MANAGER`, `TAILNET_IP`, `TAILNET_CIDR`, `TERM`, etc. are gated on `__executable_exists` / `case` / runtime probes in `~/.profile`; they're not meant for cross-file reuse and are not guaranteed to be set.
- **`PATH` membership.** `main/` and `other/` are always on `PATH`. `install/`, `set_up/`, `misc/` are not.
- **`misc/` exemption.** Scripts under `misc/` are explicitly standalone — they must NOT depend on this repo's env or functions. Hardcoded paths are acceptable there.

### Sourcing `functions.bash`

Every non-`misc/` script sources `"${SCRIPTS_DIR}/functions.bash"`. Exception: a small number of Docker-related scripts (e.g. `main/docker-grype-scan`, `main/docker-trivy-scan`) source `${DOCKER_COMPOSE_DIR}/functions.bash` from a separate Docker repo instead. That file transitively sources `${SCRIPTS_DIR}/functions.bash`, so all helpers from this repo (`log::enable_err_trap`, `log::log`, `log::die`, etc.) ARE available — no need to inline equivalents in those scripts.

## Layout

- `main/` — primary utility scripts (on `PATH`).
- `other/` — third-party scripts copied verbatim from elsewhere. **Never modify anything under `other/` unless explicitly told to touch a specific file in there.** This applies to formatting, shellcheck fixes, refactors, renames, or any other automated cleanup. On `PATH`; excluded from `format-scripts` / `shellcheck-scripts`.
- `install/` — numbered scripts run in order by `run-install-scripts` to provision a new machine. Files starting with all-caps names (e.g. `00_DISTRO_PACKAGES`, `70_WORK_ONLY`) are markers/data with executable bit off — the runner skips non-executable files. `90_REMOVE` etc. follow same pattern.
- `set_up/` — idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script must self-check whether it should run.
- `misc/` — one-off setup scripts (not on `PATH`, not auto-run). Scripts here are expected to be **standalone** — runnable on a fresh machine by someone without access to this repo's function library. Do NOT source `functions.bash` from `misc/` scripts; inline anything they need (including the `ERR` trap — see Script Conventions).
- `functions/` — bash function library, all sourced via `functions.bash` (loops `functions/*.bash`).
- `lib/` — vendored Groovy jars (used by some scripts).

## Common Commands

- `./format-scripts [--check] [<file-or-dir>...]` — runs `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write` over the given files/dirs, or over all shell files except `other/` when no args. `--check` swaps `--write` for `--diff` (preview mode, no in-place changes).
- `./shellcheck-scripts [<file-or-dir>...]` — runs `shellcheck` over the given files/dirs, or over the same default set when no args. All scripts must pass.
- `./check-scripts [<file-or-dir>...]` — combined check: runs `shfmt --diff` and `shellcheck` over the same set, aggregates exit codes (exits non-zero if either fails). Use this for CI/pre-commit-style verification.
- `./run-install-scripts` — provision new machine. Sources `~/.profile`, validates sudo, runs every executable file under `install/` in `LC_COLLATE=C` order.
- `./run-set-up-scripts` — same pattern, recursive over `set_up/**/*`.
- `main/new-script <path>` — scaffolds a new script with the standard header + exec bit.
- `main/setup-githooks` — one-shot script that points `core.hooksPath` at the tracked `.githooks/` dir, activating the `pre-push` hook (runs `./check-scripts` and aborts the push on failure). Bypass with `git push --no-verify`.
- `./run-tests [<bats-args>...]` — runs BATS tests under `test/functions/` recursively when called with no args, or forwards args to the vendored bats binary. Default invocation uses `bats --jobs $(nproc)` for parallel execution.

To gate a script from the `install`/`set_up runners`, remove its executable bit (`chmod -x`).

## Testing

Every helper in `functions/*.bash` is exercised under [BATS](https://github.com/bats-core/bats-core); each `functions/<topic>.bash` has a matching `test/functions/<topic>.bats` (or a topic-prefixed group of `.bats` files). BATS itself, plus `bats-support` and `bats-assert`, are vendored as git submodules under `test/`.

**Every new public helper function in `functions/*.bash` MUST ship with thorough BATS unit tests in the same PR.** No exceptions. A PR that adds an untested helper is not complete. See the test-coverage rule in `.claude/rules/shell-scripts.md` for the required coverage shape (positive assertions per behavior, edge-case sweep, every arity guard branch, every `@exitcode`, success + failure paths for stateful helpers). Private `_`-prefixed internal helpers may be covered indirectly through the public callers that exercise them.

### Layout

```
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

```
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

Several helpers (`text::*`, `json::sort`) accept input from EITHER stdin OR a file path. To avoid copy-pasting the test pattern, source `test/test_helper/dual_mode` in `setup()` and use `dual_mode::assert_stdin <fn> <input> <expected>` and `dual_mode::assert_file <fn> <input> <expected>`. The latter writes input to a per-test tmpfile under `${BATS_TEST_TMPDIR}` (BATS auto-cleans). `grep::*` functions are NOT dual-mode (each is stdin-only OR file-only) — write tests against them directly with `run` + heredoc / tmpfile fixtures.

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

## Script Conventions

@.claude/rules/shell-scripts.md

## Function Library

`functions/` is organized by topic — `args`, `arrays`, `commands`, `docker`, `downloads`, `env`, `files`, `grep`, `http`, `json`, `log::log`, `mvn`, `network`, `os`, `packages`, `path`, `prompt`, `retry`, `sdkman`, `strings`, `symlinks`, `system`, `systemctl`, `text`, `time`, etc. When adding a helper, drop it in the topically-matching file; it's auto-sourced. If no existing topic fits, Claude may create a new `functions/<topic>.bash` file — but must ask first before adding the new topic.

## Before Committing

Run `./format-scripts` then `./shellcheck-scripts`. Both must be clean. Both accept optional file/dir arguments — pass only the changed files for a faster check, or run with no args to cover the whole repo. To verify without writing, use `./check-scripts` (or `./format-scripts --check`) which runs `shfmt --diff` and `shellcheck` together and aggregates their exit codes.

The tracked `.githooks/pre-push` hook runs `./check-scripts` automatically on push (activated per-clone via `main/setup-githooks`), so the same gate also fires at push time as a safety net.
