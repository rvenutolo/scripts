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
- `misc/` — one-off setup scripts (not on `PATH`, not auto-run).
- `functions/` — bash function library, all sourced via `functions.bash` (loops `functions/*.bash`).
- `lib/` — vendored Groovy jars (used by some scripts).

## Common Commands

- `./format-scripts [--check] [<file-or-dir>...]` — runs `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write` over the given files/dirs, or over all shell files except `other/` when no args. `--check` swaps `--write` for `--diff` (preview mode, no in-place changes).
- `./shellcheck-scripts [<file-or-dir>...]` — runs `shellcheck` over the given files/dirs, or over the same default set when no args. All scripts must pass.
- `./check-scripts [<file-or-dir>...]` — combined check: runs `shfmt --diff` and `shellcheck` over the same set, aggregates exit codes (exits non-zero if either fails). Use this for CI/pre-commit-style verification.
- `./run-install-scripts` — provision new machine. Sources `~/.profile`, validates sudo, runs every executable file under `install/` in `LC_COLLATE=C` order.
- `./run-set-up-scripts` — same pattern, recursive over `set_up/**/*`.
- `main/new-script <path>` — scaffolds a new script with the standard header + exec bit.

To gate a script from the `install`/`set_up runners`, remove its executable bit (`chmod -x`).

## Script Conventions

@.claude/rules/shell-scripts.md

## Function Library

`functions/` is organized by topic — `args`, `arrays`, `commands`, `docker`, `downloads`, `env`, `files`, `grep`, `json`, `log`, `mvn`, `network`, `os`, `packages`, `path`, `prompt`, `sdkman*`, `strings`, `symlinks`, `system`, `systemctl`, `text`, `time`, `wrappers`, etc. When adding a helper, drop it in the topically-matching file; it's auto-sourced. If no existing topic fits, Claude may create a new `functions/<topic>.bash` file — but must ask first before adding the new topic.

## Before Committing

Run `./format-scripts` then `./shellcheck-scripts`. Both must be clean. Both accept optional file/dir arguments — pass only the changed files for a faster check, or run with no args to cover the whole repo. To verify without writing, use `./check-scripts` (or `./format-scripts --check`) which runs `shfmt --diff` and `shellcheck` together and aggregates their exit codes.
