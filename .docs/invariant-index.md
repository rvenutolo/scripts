# Invariant index

Central registry: every repo invariant maps to its enforcer script, the CI job
that runs it, and the required-status-check context that gates merges to `main`.
Kept in lock-step with the real `.ci/` scripts, workflow job definitions, the
`protect-main` ruleset, and `.ci/run-governance-checks` by the
`.ci/check-orphan-invariants` governance lint, which fails CI on any drift.

<!-- invariant-index:begin -->
| Invariant | Enforcer | CI job | Required check |
|-----------|----------|--------|----------------|
| every GitHub Actions `uses:` reference is SHA-pinned or local | `check-uses-sha-pinned` | `governance` | `governance` |
| every SHA-pinned `uses:` reference carries a version-tag comment | `check-patch-tag-pins` | `governance` | `governance` |
| every workflow sets empty top-level permissions and per-job permissions blocks | `check-min-permissions` | `governance` | `governance` |
| every workflow job begins with a SHA-pinned harden-runner step | `check-harden-runner-first` | `governance` | `governance` |
| no PR-triggered workflow references secrets other than GITHUB_TOKEN | `check-pr-workflows-no-secrets` | `governance` | `governance` |
| renovate.json carries all security-critical invariants | `check-renovate-invariants` | `governance` | `governance` |
| no required-check workflow declares path filters under pull_request | `check-required-checks-no-paths` | `governance` | `governance` |
| protect-main ruleset matches the required security posture | `check-protect-main` | `governance` | `governance` |
| repo config files validate against their JSON Schemas | `check-jsonschema` | `governance` | `governance` |
| every workflow job sets an explicit positive-integer timeout-minutes | `check-job-timeout-minutes` | `governance` | `governance` |
| every workflow declares a top-level concurrency block with a non-empty group | `check-workflow-concurrency` | `governance` | `governance` |
| no workflow declares the pull_request_target trigger | `check-pull-request-target-absent` | `governance` | `governance` |
| every actions/checkout step sets persist-credentials: false | `check-checkout-persist-credentials` | `governance` | `governance` |
| every actions/upload-artifact step sets if-no-files-found: error (or is allowlisted) | `check-upload-artifact-strict` | `governance` | `governance` |
| every multi-line bash run: block begins with set -Eeuo pipefail | `check-run-block-strict` | `governance` | `governance` |
| every .ci/ script has a paired bats test file | `check-script-has-test` | `governance` | `governance` |
| required-checks table, protect-main ruleset, and workflow jobs agree | `check-ci-job-in-summary` | `governance` | `governance` |
| every top-level script and library function has a shdoc annotation | `check-shdoc-headers` | `check-scripts` | `check-scripts` |
| invariant index, .ci/ enforcers, workflow jobs, ruleset contexts, and governance runner agree | `check-orphan-invariants` | `governance` | `governance` |
<!-- invariant-index:end -->
