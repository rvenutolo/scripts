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

| Path         | Purpose                                                                                                                        | On `PATH` |
| ------------ | ------------------------------------------------------------------------------------------------------------------------------ | --------- |
| `functions/` | Bash function library, auto-sourced via `functions.bash`.                                                                      | n/a       |
| `install/`   | Numbered scripts run in order by `run-install-scripts` to provision a new machine.                                             | no        |
| `main/`      | Primary utility scripts.                                                                                                       | yes       |
| `misc/`      | One-off setup scripts. Standalone — runnable on a fresh machine without this repo.                                             | no        |
| `other/`     | Third-party scripts copied verbatim; never modified locally.                                                                   | yes       |
| `set_up/`    | Idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script self-checks whether it should run. | no        |
| `test/`      | BATS test suite for the function library.                                                                                      | n/a       |

## Common commands

Most repo-level operations have both a shell script and a `just` recipe (see [`.justfile`](.justfile)). Either form works; `just` is shorter for the common ones.

| Shell script                                                          | `just` recipe            | Purpose                                                                         |
| --------------------------------------------------------------------- | ------------------------ | ------------------------------------------------------------------------------- |
| `./.ci/build-docs && mkdocs build --strict --config-file .mkdocs.yml` | `just docs`              | Build the docs site locally (requires `mkdocs`).                                |
| `./.ci/check-shdoc-headers`                                           | `just shdoc-check`       | Audit shdoc header coverage on scripts and library helpers.                     |
| `./check-scripts [<paths>...]`                                        | `just check` (default)   | Combined `shellcheck` and shdoc-header audit; non-zero exit on failure.         |
| `nix fmt`                                                             | `just format`            | Format every file via treefmt (shfmt for shell).                                |
| `nix flake check`                                                     | `just format-check`      | Verify formatting (treefmt) and run flake checks.                               |
| `./run-install-scripts`                                               | `just install`           | Provision a new machine — runs every executable file under `install/` in order. |
| `./run-set-up-scripts`                                                | `just setup`             | Run idempotent setup scripts under `set_up/`.                                   |
| `./run-tests [<bats-args>...]`                                        | `just test`              | Run BATS tests under `test/functions/`.                                         |
| `./shellcheck-scripts [<paths>...]`                                   | `just shellcheck`        | Run `shellcheck` over shell scripts.                                            |
| `main/new-script <path>`                                              | `just new-script <path>` | Scaffold a new top-level script with the standard header and exec bit.          |

## Required environment

Set `SCRIPTS_DIR` to the repo root. Every script sources `${SCRIPTS_DIR}/functions.bash`. The user's `~/.profile` is expected to export it.

## Development

Tooling is provided by a Nix flake devShell. Install [Nix](https://nixos.org/) and [direnv](https://direnv.net/), then run `direnv allow` (or `nix develop`) in the repo root. Every tool (shfmt, shellcheck, bats, formatters, etc.) is then available — nothing else to install, and CI uses the same flake. From inside the devShell, `nix fmt`, `nix flake check`, `./check-scripts`, and `./run-tests` all work.

## Git hooks

Tracked hooks live under `.githooks/`. Activate them once per clone:

```bash
git config --local core.hooksPath .githooks
```

| Hook         | When         | What it does                                                                                                                   |
| ------------ | ------------ | ------------------------------------------------------------------------------------------------------------------------------ |
| `commit-msg` | `git commit` | Runs `commitlint` against the staged commit message (Conventional Commits). Fails the commit if `commitlint` is not on `PATH`. |
| `pre-push`   | `git push`   | Runs `./check-scripts`; aborts the push on failure.                                                                            |

Bypass any hook with `--no-verify` on the corresponding git command.

## Testing

```bash
git submodule update --init --recursive   # one-time, on fresh clones
./run-tests                                # everything under test/functions/
./run-tests test/functions/strings.bats    # single file
./run-tests --filter-regex 'is_blank' test/functions/strings.bats   # subset by name
```

BATS plus `bats-support` and `bats-assert` are vendored as git submodules under `test/`. Every helper in `functions/*.bash` has a matching `test/functions/<topic>.bats` (or topic-prefixed group) — coverage is mandatory for new helpers. Shared fixtures live under `test/test_helper/` (CLI shims, env-file fixtures, `os-release` overrides, prompt mocks, etc.).

Tests are spec-driven: each test encodes what the function *should* do based on its name, doc comment, and reasonable invariants — not what the current implementation happens to do.

## Automations

### GitHub Actions

Workflows under `.github/workflows/`.

| Workflow                | Trigger                                                                      | Purpose                                                                                                                                                                                                        |
| ----------------------- | ---------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `ci.yml`                | push, PR, manual                                                             | Aggregate gate: `check-scripts`, BATS, coverage (kcov + bashcov → Codecov), `reviewdog` (shellcheck/shfmt on PRs), `actionlint`, `yamllint`, JSON lint, `markdownlint`, `typos`, `editorconfig`, `commitlint`. |
| `dependency-review.yml` | PR                                                                           | Block PRs that introduce vulnerable or disallowed dependencies.                                                                                                                                                |
| `gitleaks.yml`          | push, PR, weekly cron (Mon 13:00 UTC), manual                                | Scan history for leaked secrets.                                                                                                                                                                               |
| `labeler.yml`           | PR                                                                           | Auto-apply labels via `.github/labeler.yml` rules.                                                                                                                                                             |
| `labels.yml`            | push touching `.github/labels.yml`, manual                                   | Sync the repository's label set from `.github/labels.yml`.                                                                                                                                                     |
| `links.yml`             | weekly cron (Mon 12:00 UTC), manual                                          | `lychee` link check across Markdown files; opens issues on failure.                                                                                                                                            |
| `pages.yml`             | push to `main`                                                               | Build and deploy MkDocs site to GitHub Pages; regenerates the BATS test-count badge.                                                                                                                           |
| `zizmor.yml`            | push/PR touching `.github/workflows/**`, weekly cron (Mon 14:00 UTC), manual | Static analysis of workflow files for supply-chain risks.                                                                                                                                                      |

### Renovate

`.github/renovate.json` runs the Renovate App on a weekly schedule (Saturday before 6am, `America/New_York`). Pins GitHub Actions to SHAs, groups `github-actions` and `bats-submodules` updates, and auto-merges everything.

## License

[GPL-3.0](LICENSE).
