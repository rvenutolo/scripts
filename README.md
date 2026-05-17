# scripts

Personal Linux setup, install, and utility shell scripts.

[![CI](https://github.com/rvenutolo/scripts/actions/workflows/ci.yml/badge.svg)](https://github.com/rvenutolo/scripts/actions/workflows/ci.yml)
[![Last commit](https://img.shields.io/github/last-commit/rvenutolo/scripts)](https://github.com/rvenutolo/scripts/commits/main)
[![Open issues](https://img.shields.io/github/issues/rvenutolo/scripts)](https://github.com/rvenutolo/scripts/issues)
[![Open PRs](https://img.shields.io/github/issues-pr/rvenutolo/scripts)](https://github.com/rvenutolo/scripts/pulls)
[![Tests](https://img.shields.io/endpoint?url=https://rvenutolo.github.io/scripts/badge.json)](https://github.com/rvenutolo/scripts/tree/main/test/functions)
[![Coverage](https://codecov.io/gh/rvenutolo/scripts/branch/main/graph/badge.svg)](https://codecov.io/gh/rvenutolo/scripts)
[![Conventional Commits](https://img.shields.io/badge/Conventional%20Commits-1.0.0-yellow.svg)](https://www.conventionalcommits.org/en/v1.0.0/)
[![License: GPL-3.0](https://img.shields.io/badge/License-GPL_3.0-blue.svg)](LICENSE)

**Reference:** <https://rvenutolo.github.io/scripts/>

## Layout

| Path | Purpose | On `PATH` |
|---|---|---|
| `main/` | Primary utility scripts. | yes |
| `other/` | Third-party scripts copied verbatim; never modified locally. | yes |
| `install/` | Numbered scripts run in order by `run-install-scripts` to provision a new machine. | no |
| `set_up/` | Idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script self-checks whether it should run. | no |
| `misc/` | One-off setup scripts. Standalone — runnable on a fresh machine without this repo. | no |
| `functions/` | Bash function library, auto-sourced via `functions.bash`. | n/a |
| `test/` | BATS test suite for the function library. | n/a |

## Common commands

| Command | Purpose |
|---|---|
| `./check-scripts [<paths>...]` | Combined `shfmt --diff` and `shellcheck` check; non-zero exit on failure. |
| `./format-scripts [--check] [<paths>...]` | Apply `shfmt` formatting in place. `--check` previews via `--diff`. |
| `./shellcheck-scripts [<paths>...]` | Run `shellcheck` over shell scripts. |
| `./run-tests [<bats-args>...]` | Run BATS tests under `test/functions/`. |
| `./run-install-scripts` | Provision a new machine — runs every executable file under `install/` in order. |
| `./run-set-up-scripts` | Run idempotent setup scripts under `set_up/`. |
| `main/new-script <path>` | Scaffold a new top-level script with the standard header and exec bit. |

## Required environment

Set `SCRIPTS_DIR` to the repo root. Every script sources `${SCRIPTS_DIR}/functions.bash`. The user's `~/.profile` is expected to export it.

## Pre-push hook

The tracked `.githooks/pre-push` hook runs `./check-scripts` before each push and aborts on failure. Activate it once per clone:

```bash
git config --local core.hooksPath .githooks
```

Bypass with `git push --no-verify`.

## Testing

```bash
git submodule update --init --recursive   # one-time, on fresh clones
./run-tests                                # everything under test/functions/
./run-tests test/functions/strings.bats    # single file
```

BATS plus `bats-support` and `bats-assert` are vendored as git submodules under `test/`.

## License

[GPL-3.0](LICENSE).
