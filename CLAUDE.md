# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal collection of bash scripts for system setup, package install, and day-to-day utilities on the user's Linux machines. No build system, no tests — pure shell.

## Required Environment

- `SCRIPTS_DIR` env var points to repo root. Every script sources `"${SCRIPTS_DIR}/functions.bash"`.
- Claude can assume `SCRIPTS_DIR` is always set in the environment — do not add `${SCRIPTS_DIR:-default}` fallbacks or `set -u` defenses for it.
- When running `./check-scripts`, `./format-scripts`, `./shellcheck-scripts`, or any other script in the repo, do NOT prefix the command with `SCRIPTS_DIR=...`. The env var is set by `~/.profile` and is expected to already be present. If it is not set, the script will fail under `set -u` — that is the desired behavior so the user can fix their environment.
- `main/` and `other/` are always on `PATH`. `install/`, `set_up/`, `misc/` are not.

## Layout

- `main/` — primary utility scripts (on `PATH`).
- `other/` — third-party scripts copied verbatim from elsewhere. **Never modify anything under `other/` unless explicitly told to touch a specific file in there.** This applies to formatting, shellcheck fixes, refactors, renames, or any other automated cleanup. On `PATH`; excluded from `format-scripts` / `shellcheck-scripts`.
- `install/` — numbered scripts run in order by `run-install-scripts` to provision a new machine. Files starting with all-caps names (e.g. `00_DISTRO_PACKAGES`, `70_WORK_ONLY`) are markers/data with executable bit off — the runner skips non-executable files. `90_REMOVE` etc. follow same pattern.
- `set_up/` — idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script must self-check whether it should run.
- `misc/` — one-off setup scripts (not on `PATH`, not auto-run). Scripts here are expected to be **standalone** — runnable on a fresh machine by someone without access to this repo's function library. Do NOT source `functions.bash` from `misc/` scripts; inline anything they need (including the `ERR` trap — see Script Conventions).
- A small number of Docker-related scripts (e.g. `main/docker-grype-scan`, `main/docker-trivy-scan`) source `${DOCKER_COMPOSE_DIR}/functions.bash` from a separate Docker repo instead of this repo's `functions.bash` directly. That file in turn sources `${SCRIPTS_DIR}/functions.bash`, so all helpers from this repo (`log::enable_err_trap`, `log::log`, `log::die`, etc.) ARE available — no need to inline equivalents in those scripts.
- `functions/` — bash function library, all sourced via `functions.bash` (loops `functions/*.bash`).
- `lib/` — vendored Groovy jars (used by some scripts).

## Common Commands

- `./format-scripts [--check] [<file-or-dir>...]` — runs `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write` over the given files/dirs, or over all shell files except `other/` when no args. `--check` swaps `--write` for `--diff` (preview mode, no in-place changes).
- `./shellcheck-scripts [<file-or-dir>...]` — runs `shellcheck` over the given files/dirs, or over the same default set when no args. All scripts must pass.
- `./check-scripts [<file-or-dir>...]` — combined check: runs `shfmt --diff` and `shellcheck` over the same set, aggregates exit codes (exits non-zero if either fails). Use this for CI/pre-commit-style verification.
- `./run-install-scripts` — provision new machine. Sources `~/.profile`, validates sudo, runs every executable file under `install/` in `LC_COLLATE=C` order.
- `./run-set-up-scripts` — same pattern, recursive over `set_up/**/*`.
- `main/new-script <path>` — scaffolds a new script with the standard header + exec bit.
- `./run-tests [<bats-args>...]` — runs BATS tests under `test/functions/` recursively when called with no args, or forwards args to the vendored bats binary.

To gate a script from the `install`/`set_up runners`, remove its executable bit (`chmod -x`).

## Testing

A subset of `functions/*.bash` is exercised under [BATS](https://github.com/bats-core/bats-core). BATS itself, plus `bats-support` and `bats-assert`, are vendored as git submodules under `test/`.

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

### What is tested

- `functions/strings.bash` — `is_empty`, `is_not_empty`, `is_blank`, `trim`, `ensure_trailing_slash` (Phase A)
- `functions/args.bash` — all 13 `check_*` arity helpers, `stdin_exists`, `check_for_stdin` (Phase A)
- `functions/path.bash` — `remove`, `append`, `prepend` (Phase A)
- `functions/arrays.bash` — `to_lines` (Phase B)
- `functions/time.bash` — `calc_elapsed`, `shell_elapsed_time` (Phase B)
- `functions/text.bash` — `remove_ansi`, `remove_empty_lines`, `first_line`, `last_line`, `skip_first_lines` (Phase B)
- `functions/grep.bash` — all 20 `contains_*` and `file_contains_*` variants (Phase B)
- `functions/json.bash` — `sort` (Phase B)
- `functions/env_file.bash` — pure half: `assert_var_exists`, `get_var_value`, `is_var_value_empty`, `set_var_value`, `set_var_value_if_empty` (Phase C)

Phase D will cover the interactive `prompt_*` family in `env_file.bash`. Side-effecting helpers (sudo, network, package managers) remain out of scope until a mocking strategy is settled.

### Dual-mode helper

Several helpers (`text::*`, `json::sort`) accept input from EITHER stdin OR a file path. To avoid copy-pasting the test pattern, source `test/test_helper/dual_mode` in `setup()` and use `dual_mode::assert_stdin <fn> <input> <expected>` and `dual_mode::assert_file <fn> <input> <expected>`. The latter writes input to a per-test tmpfile under `${BATS_TEST_TMPDIR}` (BATS auto-cleans). `grep::*` functions are NOT dual-mode (each is stdin-only OR file-only) — write tests against them directly with `run` + heredoc / tmpfile fixtures.

For env-file tests (read+write tmpfile fixtures), source `test/test_helper/env_file_fixture` and use `env_file_fixture::create <content> [<basename>]` which writes content to `${BATS_TEST_TMPDIR}/<basename>` (default `env`) and echoes the path.

### `path::*` testing note

`path::remove`, `path::append`, and `path::prepend` mutate the caller's `PATH`. Do NOT wrap them in `run` — `run` executes in a subshell and the mutation is discarded. Set a local `PATH`, call the function directly, then assert on `PATH`. BATS isolates each `@test` in its own subshell, so mutations do not leak between tests.

## Script Conventions

@.claude/rules/shell-scripts.md

## Function Library

`functions/` is organized by topic — `args`, `arrays`, `commands`, `docker`, `downloads`, `env`, `files`, `grep`, `json`, `log::log`, `mvn`, `network`, `os`, `packages`, `path`, `prompt`, `sdkman`, `strings`, `symlinks`, `system`, `systemctl`, `text`, `time`, `wrappers`, etc. When adding a helper, drop it in the topically-matching file; it's auto-sourced. If no existing topic fits, Claude may create a new `functions/<topic>.bash` file — but must ask first before adding the new topic.

## Before Committing

Run `./format-scripts` then `./shellcheck-scripts`. Both must be clean. Both accept optional file/dir arguments — pass only the changed files for a faster check, or run with no args to cover the whole repo. To verify without writing, use `./check-scripts` (or `./format-scripts --check`) which runs `shfmt --diff` and `shellcheck` together and aggregates their exit codes.
