# Required status checks

These are the status checks the `protect-main` ruleset requires before a pull
request can merge to `main`. The table below is the human-readable view; it is
kept in lock-step with `.github/rulesets/protect-main.json` and the workflow job
definitions by the `.ci/check-ci-job-in-summary` governance lint, which fails CI
if the documented set, the enforced set, and the real workflow jobs ever drift.

<!-- required-checks:begin -->
| Check | Category | Protects |
|-------|----------|----------|
| `bats` | testing | helper-library unit tests pass |
| `check-scripts` | lint | shellcheck + shdoc-header audit pass |
| `commitlint` | hygiene | each commit is Conventional Commits |
| `dependency-review` | security | no vulnerable or denied deps in a PR |
| `gitleaks` | security | no committed secrets |
| `governance` | ci-integrity | every `.ci` governance lint passes |
| `lint` | lint | treefmt / format gate passes |
| `lint-pr-title` | hygiene | PR title is Conventional Commits |
| `nix-flake-check` | ci-integrity | the flake builds and its checks pass |
| `zizmor` | security | GitHub Actions static security audit |
<!-- required-checks:end -->
