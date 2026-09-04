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
| every workflow job blocks egress with an explicit allowed-endpoints list | `check-harden-runner-egress` | `governance` | `governance` |
| every workflow job takes the strongest harden-runner sudo hardening it can, no job disables file monitoring, and only container-runtime jobs may use the deprecated disable-sudo input | `check-harden-runner-disable-sudo-and-containers` | `governance` | `governance` |
| every host linked from markdown is in the Links workflow allowed-endpoints | `check-links-allowed-endpoints` | `governance` | `governance` |
| no PR-triggered workflow references secrets other than GITHUB_TOKEN | `check-pr-workflows-no-secrets` | `governance` | `governance` |
| every codecov-action step keeps fail_ci_if_error true and no validation bypass | `check-codecov-strict` | `governance` | `governance` |
| the README workflow table lists exactly the workflows that exist | `check-readme-workflow-table` | `governance` | `governance` |
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
| every workflow run step runs inside the devShell and no workflow spells `nix develop` | `check-workflow-hermetic` | `governance` | `governance` |
| every .ci/, .githooks/, and repo-root script has a paired bats test file | `check-script-has-test` | `governance` | `governance` |
| every arity-violating test asserts its guard message | `check-vacuous-arity-tests` | `governance` | `governance` |
| every BATS test asserts on stderr, stdout, and status through bats-assert | `check-stderr-assertions` | `governance` | `governance` |
| no .bats test file opens with a shebang | `check-bats-no-shebang` | `governance` | `governance` |
| code comments and runtime strings carry no bare issue number | `check-comment-archaeology` | `governance` | `governance` |
| no tree-inspecting repo tool resolves a scan root from SCRIPTS_DIR | `check-tree-scan-root` | `governance` | `governance` |
| every literal path a repo config file configures still names something git knows about | `check-config-paths` | `governance` | `governance` |
| every gate script enables `inherit_errexit` so a failed command substitution cannot exit 0 | `check-inherit-errexit` | `governance` | `governance` |
| every nameref binding uses its reserved name and guards against a caller passing it | `check-nameref-convention` | `governance` | `governance` |
| no gate script calls a yq/jq-backed helper from a condition | `check-errexit-predicate` | `governance` | `governance` |
| exactly one mechanism owns this clone's git hook path | `check-hooks-path-single-writer` | `governance` | `governance` |
| required-checks table, protect-main ruleset, and workflow jobs agree | `check-ci-job-in-summary` | `governance` | `governance` |
| every top-level script and library function has a shdoc annotation | `check-shdoc-headers` | `check-scripts` | `check-scripts` |
| no top-level script ships placeholder text in its shdoc header | `check-shdoc-headers` | `check-scripts` | `check-scripts` |
| no function annotation ships placeholder text | `check-shdoc-headers` | `check-scripts` | `check-scripts` |
| every non-exempt top-level script calls `args::handle_help_flag` | `check-shdoc-headers` | `check-scripts` | `check-scripts` |
| script file modes match the executable-bit convention | `check-executable-bit` | `check-scripts` | `check-scripts` |
| invariant index, .ci/ enforcers, workflow jobs, ruleset contexts, and governance runner agree | `check-orphan-invariants` | `governance` | `governance` |
| the repo has exactly one justfile and it agrees with the documented command table | `check-justfile-invariants` | `governance` | `governance` |
| every public `just` recipe has a doc comment | `check-justfile-invariants` | `governance` | `governance` |
| every tool the repo's tooling invokes is a member of the flake devShell's own PATH, not merely resolvable from the ambient one | `check-devshell-provides` | `governance` | `governance` |
| every package the flake devShell declares contributes a tool the repo declares, or is excluded by name | `check-devshell-provides` | `governance` | `governance` |
| every tool a repo-tooling call site names is declared in .ci/required-tools | `check-tool-declarations` | `governance` | `governance` |
| `nix flake check` passes and emits no evaluation warnings | `check-flake-eval-warnings` | `nix-flake-check` | `nix-flake-check` |
<!-- invariant-index:end -->
