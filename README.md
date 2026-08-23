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

All script directories live under a top-level `scripts/` dir; `SCRIPTS_DIR` points at `repo-root/scripts`. Repo-tooling and config (the root runners, `.ci/`, `test/`, `lib/`, `flake.nix`, etc.) stay at the repo root.

| Path                       | Purpose                                                                                                                                 | On `PATH`          |
| -------------------------- | --------------------------------------------------------------------------------------------------------------------------------------- | ------------------ |
| `scripts/non-interactive/` | Automation-safe utility scripts: no prompts, no GUI, no picker, no TTY assumptions. Callable by cron/`topgrade`/other programs.         | yes                |
| `scripts/interactive/`     | Utility scripts that prompt, launch a GUI, or drive a picker, plus every wrapper (`mvn`, `gradle`, `kate`, `claude`, flatpak wrappers). | interactive shells |
| `scripts/other/`           | Third-party scripts copied verbatim; never modified locally.                                                                            | yes                |
| `scripts/install/`         | Numbered scripts run in order by `run-install-scripts` to provision a new machine.                                                      | no                 |
| `scripts/set_up/`          | Idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script self-checks whether it should run.          | no                 |
| `scripts/misc/`            | One-off setup scripts. Standalone — runnable on a fresh machine without this repo.                                                      | no                 |
| `scripts/functions/`       | Bash function library, auto-sourced via `scripts/.functions.bash`.                                                                      | n/a                |
| `test/`                    | BATS suite (at the repo root): `functions/`, `.ci/` scripts, and the repo-root runners.                                                 | n/a                |

## Common commands

Most repo-level operations have both a shell script and a `just` recipe (see [`.justfile`](.justfile)). Either form works; `just` is shorter for the common ones.

| Shell script                                                                                              | `just` recipe            | Purpose                                                                                       |
| --------------------------------------------------------------------------------------------------------- | ------------------------ | --------------------------------------------------------------------------------------------- |
| `./.ci/in-devshell ./.ci/build-docs && ./.ci/in-devshell mkdocs build --strict --config-file .mkdocs.yml` | `just docs`              | Build the docs site locally.                                                                  |
| `./.ci/in-devshell ./.ci/check-shdoc-headers`                                                             | `just shdoc-check`       | Audit shdoc header coverage on scripts and library helpers.                                   |
| `./.ci/in-devshell ./.ci/run-governance-checks`                                                           | `just governance`        | Run the repo-governance lint suite (workflow posture, Renovate, ruleset).                     |
| `./.ci/in-devshell ./.ci/run-lint-checks`                                                                 | `just lint`              | Run the config/markup lint suite (actionlint, yamllint, JSON, markdown, typos, editorconfig). |
| `./.ci/in-devshell ./check-scripts [<paths>...]`                                                          | `just check` (default)   | Combined `shellcheck`, shdoc-header, and executable-bit audit; non-zero exit on failure.      |
| `nix fmt`                                                                                                 | `just format`            | Format every file via treefmt (shfmt for shell).                                              |
| `nix flake check`                                                                                         | `just format-check`      | Verify formatting (treefmt) and run flake checks.                                             |
| `./.ci/in-devshell ./run-all-checks`                                                                      | `just all`               | Full local gate: `check-scripts`, `nix flake check`, governance, lint, and BATS suites.       |
| `./.ci/in-devshell ./run-tests [<bats-args>...]`                                                          | `just test`              | Run BATS tests under `test/functions/`, `test/ci/`, and `test/root/`.                         |
| `./.ci/in-devshell ./shellcheck-scripts [<paths>...]`                                                     | `just shellcheck`        | Run `shellcheck` over shell scripts.                                                          |
| `scripts/non-interactive/new-script <path>`                                                               | `just new-script <path>` | Scaffold a new top-level script with the standard header and exec bit.                        |

## Required environment

Set `SCRIPTS_DIR` to `repo-root/scripts`. Every script sources `${SCRIPTS_DIR}/.functions.bash`. The user's `~/.profile` is expected to export it. Repo-tooling scripts that need the repo root itself derive it via `git rev-parse --show-toplevel`.

## Development

Tooling is provided by a Nix flake devShell. Install [Nix](https://nixos.org/) and [direnv](https://direnv.net/), then run `direnv allow` (or `nix develop`) in the repo root. Every tool (shfmt, shellcheck, bats, formatters, etc.) is then available — nothing else to install, and CI uses the same flake. Entering the devShell also activates the tracked git hooks (see [Git hooks](#git-hooks)). The local gate is `nix fmt` followed by `./.ci/in-devshell ./run-all-checks`.

Every gate runs through [`.ci/in-devshell`](.ci/in-devshell), which re-execs the command under `nix develop --ignore-environment`. The ambient `PATH` is gone inside that boundary, so a tool missing from `flake.nix` fails loudly instead of resolving from the machine or the runner image. CI, `just`, and the `pre-push` hook all go through the same wrapper, so local and CI runs cannot diverge.

## Git hooks

Tracked hooks live under `.githooks/`. They activate automatically: the flake devShell's `shellHook` runs `.ci/activate-githooks`, which points `core.hooksPath` at `.githooks`. Running `direnv allow` (or `nix develop`) is all that is required — there is no manual `git config` step. Activation is idempotent and silent once the value is already correct.

| Hook         | When         | What it does                                                                                                                                                                                                                   |
| ------------ | ------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `commit-msg` | `git commit` | Runs `commitlint` against the staged commit message (Conventional Commits). Fails the commit if `commitlint` is not on `PATH`. Deliberately outside the hermetic boundary — one tool is not worth a nix evaluation per commit. |
| `pre-push`   | `git push`   | Runs `./.ci/in-devshell ./run-all-checks` — the full local gate, including the BATS suite; aborts the push on failure.                                                                                                         |

Bypass any hook with `--no-verify` on the corresponding git command.

## Testing

```bash
git submodule update --init --recursive   # one-time, on fresh clones (for .shdoc)
./.ci/in-devshell ./run-tests                              # test/functions/, test/ci/, and test/root/
./.ci/in-devshell ./run-tests test/functions/strings.bats  # single file
./.ci/in-devshell ./run-tests --filter 'is_blank' test/functions/strings.bats   # subset by name
```

BATS, `bats-support`, and `bats-assert` come from the flake devShell — `bats.withLibraries` in [`flake.nix`](flake.nix) — and are no longer vendored as git submodules. The wrapper it produces exports `BATS_LIB_PATH`, so `test/test_helper/common.bash` loads the two libraries with `bats_load_library` and a bats that is not the flake's fails loudly instead of silently missing them. `.shdoc` is still a submodule, which is why the bootstrap line above stays.

Every helper in `functions/*.bash` has a matching `test/functions/<topic>.bats` (or topic-prefixed group) — coverage is mandatory for new helpers. Shared fixtures live under `test/test_helper/` (CLI shims, env-file fixtures, `os-release` overrides, prompt mocks, etc.).

Tests are spec-driven: each test encodes what the function *should* do based on its name, doc comment, and reasonable invariants — not what the current implementation happens to do.

## Automations

### GitHub Actions

Workflows under `.github/workflows/`.

<!-- workflow-table:begin -->

| Workflow                       | Trigger                                                                      | Purpose                                                                                                                                                                                                |
| ------------------------------ | ---------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `ci.yml`                       | push, PR, manual                                                             | Aggregate gate: `check-scripts`, BATS, coverage (bashcov, PR-only), `reviewdog` (shellcheck/shfmt on PRs), `actionlint`, `yamllint`, JSON lint, `markdownlint`, `typos`, `editorconfig`, `commitlint`. |
| `coverage.yml`                 | push to `main`, manual                                                       | Run the BATS suite under bashcov and upload the Cobertura report to Codecov. Push-only so it can carry `CODECOV_TOKEN`.                                                                                |
| `dependency-review.yml`        | PR                                                                           | Block PRs that introduce vulnerable or disallowed dependencies.                                                                                                                                        |
| `gitleaks.yml`                 | push, PR, weekly cron (Mon 13:00 UTC), manual                                | Scan history for leaked secrets.                                                                                                                                                                       |
| `labeler.yml`                  | PR                                                                           | Auto-apply labels via `.github/labeler.yml` rules.                                                                                                                                                     |
| `labels.yml`                   | push touching `.github/labels.yml`, manual                                   | Sync the repository's label set from `.github/labels.yml`.                                                                                                                                             |
| `links.yml`                    | weekly cron (Mon 12:00 UTC), manual                                          | `lychee` link check across Markdown files; opens issues on failure.                                                                                                                                    |
| `pages.yml`                    | push to `main`                                                               | Build and deploy MkDocs site to GitHub Pages; regenerates the BATS test-count badge.                                                                                                                   |
| `pr-title-lint.yml`            | PR (opened, edited, reopened, synchronize)                                   | Enforce Conventional Commits on the PR title, which becomes the merge-commit subject.                                                                                                                  |
| `protect-main-drift-check.yml` | push to `main`, weekly cron (Mon 15:00 UTC), manual                          | Detect drift between the `protect-main` ruleset on GitHub and the checked-in `.github/rulesets/protect-main.json`.                                                                                     |
| `zizmor.yml`                   | push/PR touching `.github/workflows/**`, weekly cron (Mon 14:00 UTC), manual | Static analysis of workflow files for supply-chain risks.                                                                                                                                              |

<!-- workflow-table:end -->

### Renovate

`.github/renovate.json` runs the Renovate App on a weekly schedule (Saturday before 6am, `America/New_York`). Pins GitHub Actions to SHAs, groups `github-actions` and `submodules` updates, and auto-merges the actions, submodule, and `flake.lock` rules. A regex custom manager additionally tracks the SchemaStore SHA in `.ci/check-jsonschema`, which no packaged datasource covers. The `bats-support` and `bats-assert` revisions are ordinary flake inputs, so the `flake.lock` rule covers them — `flake.lock` carries each revision and its `narHash` together, which is why they are inputs rather than hand-written `fetchFromGitHub` pins.

## License

[GPL-3.0](LICENSE).
