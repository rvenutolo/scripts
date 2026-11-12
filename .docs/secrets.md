# Secrets

Every repository secret a workflow reads, with enough detail to recreate it from
scratch. `.ci/check-secrets-documented` fails CI when a workflow or local action
reads a secret this page does not document, or when this page documents a secret
nothing reads. `GITHUB_TOKEN` is provided by Actions and is not listed.

All secrets here are repository secrets (no environment), set under the
repository's Settings → Secrets and variables → Actions
(`https://github.com/rvenutolo/scripts/settings/secrets/actions`).

## CODECOV_TOKEN

- **What it is:** the Codecov repository upload token.
- **Where to get it:** the repository's settings page on Codecov,
  [app.codecov.io/gh/rvenutolo/scripts/config/general](https://app.codecov.io/gh/rvenutolo/scripts/config/general),
  under "Repository upload token".
- **Stored as:** repository secret `CODECOV_TOKEN`.
- **Used by:** `coverage.yml`, to upload the four Cobertura reports. That
  workflow runs only on push to `main` and manual dispatch:
  `.ci/check-pr-workflows-no-secrets` forbids any secret other than
  `GITHUB_TOKEN` on a pull-request-triggered workflow, because a fork's pull
  request could exfiltrate it.

## RULESET_READ_TOKEN

- **What it is:** a fine-grained personal access token, created at
  [github.com/settings/personal-access-tokens](https://github.com/settings/personal-access-tokens).
- **Token name:** `scripts/RULESET_READ_TOKEN` (the `<repo>/<SECRET>` naming
  shown in the token list).
- **Resource owner:** `rvenutolo`.
- **Repository access:** only select repositories, `scripts` only.
- **Repository permissions:**
  - **Administration: Read-only.** Reading repository rulesets needs it, and
    `GITHUB_TOKEN` cannot be granted it.
  - **Metadata: Read-only.** GitHub adds it automatically to every
    fine-grained token.
- **Stored as:** repository secret `RULESET_READ_TOKEN`.
- **Used by:** `protect-main-drift-check.yml`, to read the live `protect-main`
  ruleset and compare it with `.github/rulesets/protect-main.json`. Like
  `coverage.yml`, it never runs on pull requests.
