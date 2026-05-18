---
name: shell-script-rules-check
description: Audits a single shell script against the merged shell-script rules (project + global) and applies fixes. TRIGGER RULES — (1) When the user explicitly invokes the slash command `/shell-script-rules-check <path>`, run the skill immediately without asking. (2) When the user makes a natural-language request that sounds like this skill's purpose ("check shell rules on X", "lint this script against the rules", "audit X for rule compliance", "see if this follows the shell-script rules", or any paraphrase), do NOT auto-run — first ask the user "Run the shell-script-rules-check skill on <path>?" and only proceed if they confirm. Never silently invoke the skill from a natural-language request. The skill produces a violations report (mechanical vs. judgment-call), applies mechanical fixes itself, and asks the user about judgment calls. It does NOT commit.
agent: true
model: sonnet
---

# shell-script-rules-check

Audit one shell script against this repo's shell-script rules and apply fixes.

## Trigger

Two paths:

1. **Slash command** — `/shell-script-rules-check <path>`. Run the skill immediately. No confirmation prompt.
2. **Natural-language paraphrase** — anything that sounds like this skill ("check shell rules on X", "lint this against the rules", "audit X for rule compliance", "does this follow the shell-script rules", etc.). Do NOT auto-run. Ask first: "Run the shell-script-rules-check skill on `<path>`?" Proceed only on confirmation. If the user says no, handle the request however they prefer (or not at all).

Never silently invoke the skill from a natural-language request — the confirmation prompt is mandatory in that path.

## Inputs

A single file path. The user supplies it as an argument to `/shell-script-rules-check`. Reject zero-arg or multi-arg invocations with a one-line error.

## Rule sources (merged, in precedence order)

1. **Project rules** (highest): `.claude/rules/shell-scripts.md` (relative to the project root)
2. **Global rules**: `$CLAUDE_CONFIG_DIR/rules/shell-scripts.md` (resolve `CLAUDE_CONFIG_DIR` via `printenv CLAUDE_CONFIG_DIR`)

Read both at the start of every run. If a rule appears in both with a conflict, the project version wins. Do not cache between invocations — rules drift.

## Workflow

### 1. Validate the argument

- Exactly one arg. Otherwise abort with `Usage: /shell-script-rules-check <path>`.
- Path must exist and be a regular file. Otherwise abort.
- Resolve to an absolute path under the repo root. Determine the repo root via `git rev-parse --show-toplevel` (or fall back to walking up until a `.git` directory is found). If the supplied path isn't under that root, warn and ask whether to proceed.

### 2. Handle `other/` specially

If the file is under `other/`: per CLAUDE.md, `other/` files are third-party and must NEVER be modified absent explicit per-file instruction. Warn the user with the file path and ask: "Skill is being called on a file under `other/`, which is normally never modified. Confirm you really want to check this file?" If the user says no, abort cleanly.

### 3. Classify the file

- Under `functions/` and ends in `.bash` → **library file**. The exemption list at the top of `.claude/rules/shell-scripts.md` ("`functions/*.bash` exemption list") tells you which rules don't apply.
- Anything else under `main/`, `install/`, `set_up/`, `misc/`, `other/`, or the repo root → **top-level executable**.

Misc subtleties:
- `misc/` scripts do NOT source `functions.bash` and use the inline `ERR` trap form, not `log::enable_err_trap`. Because they cannot source the function library, do NOT flag them for missing helper-function usage — the "use `files::exists` instead of `[[ -f ]]`", "use `log::log` instead of inline `log`", "use `commands::executable_exists` instead of `command -v`", "use `dirs::create` instead of `mkdir --parents`", "use `prompt::yn` instead of inline read", retry-loop-via-helper, etc. rules are all inapplicable here. Misc scripts are expected to inline equivalents. Do flag every OTHER rule (filename, extension, quoting, structure, `[[ ]]` over `[ ]`, long flags, `set -Eeuo pipefail`, IFS, ERR trap form, bash-version check, etc.).
- Scripts that source `${DOCKER_COMPOSE_DIR}/functions.bash` (e.g. some `main/docker-*` scripts) DO have access to this repo's helpers transitively, and use `log::enable_err_trap` (not the inline trap). Helper-function usage rules apply normally.
- `install/` files starting with all-caps names (e.g. `00_DISTRO_PACKAGES`) are markers/data, not executables — they have the executable bit off on purpose. Don't flag the missing strict-mode pragma if the file is non-executable.

### 4. Run the wrapped tooling first

Before reading the script yourself, run the repo's existing checkers and capture output. They catch most mechanical issues automatically and their violations are clear-cut.

```bash
./check-scripts "<file>"
```

Note: `./check-scripts` excludes `other/` by convention, so for `other/` files (only when the user has explicitly opted in above) run the underlying tools directly:

```bash
shfmt --indent 2 --case-indent --binary-next-line --space-redirects --diff "<file>"
shellcheck "<file>"
```

Capture the output. Anything `shfmt` would change is mechanical; anything `shellcheck` reports is mechanical (the shellcheck code itself plus the recommended fix).

### 5. Inspect the script against the rules

Read the script. Compare against the merged rule set. Flag every violation. Categorize each finding into one of two buckets:

**Mechanical / clear-cut** — the rule is unambiguous and the fix is obvious. Examples:
- Missing `#!/usr/bin/env bash` shebang
- Missing or misplaced `set -Eeuo pipefail` / `IFS=$'\n\t'`
- Missing `log::enable_err_trap` (or inline trap form for `misc/`)
- Missing `args::check_*_args "$@"` guard at top level
- `[ ]` instead of `[[ ]]`
- Short flags (`-r`) where long forms (`--recursive`) exist
- Backticks instead of `$(…)`
- Unbraced `${var}` (other than allowed specials)
- Unquoted command substitutions
- Tab indentation or non-2-space indentation
- `echo -e` instead of `printf`
- `.` instead of `source`
- Inline `mkdir -p` / `ln -s` / `[[ -f X ]]` where a helper exists (`dirs::create`, `symlinks::link_*`, `files::exists`, etc.)
- Inline `[[ -z "$x" ]]` / `[[ -n "$x" ]]` instead of `strings::is_empty` / `strings::is_not_empty`
- Inline `command -v` / `which` instead of `commands::executable_exists` / `commands::executable_path`
- Inline `[[ ! -s "$file" ]]` / `[[ -s "$file" ]]` instead of `files::is_empty` / `files::is_non_empty`
- Inline per-line `while read` of a sudo-owned file followed by `sudo tee`/`sudo mv` write-back where `files::root_transform` fits
- Inline `until cmd; do :; done` (interactive retry, no backoff) instead of `retry::until_success`
- Inline `[[ $# -gt N ]]` predicate branching instead of `args::has_at_least_num_args` / `args::no_args` / `args::has_num_args`
- Short flags (e.g. `find -L`, `tailscale ip -4`) without a same-line `# no long-form equivalent` comment when no long form exists
- `var="$(cmd)" || exit 1` redundant pattern
- `local var="$(cmd)"` masking the substitution's exit status
- Missing `main "$@"` for a multi-helper top-level script
- Wrong file extension or executable bit (FLAG always — including `.sh` extension on top-level executables under `main/`, `install/`, `set_up/`, `misc/`, which is a real violation per the rule that those files have NO extension. **Do not auto-rename**: filename changes have side effects — URLs in header comments, install/set-up runner ordering via `LC_COLLATE=C`, callers in other scripts, symlinks, dotfile references — that the skill cannot safely resolve. Treat the rename itself as a judgment call: flag the violation in the mechanical list, but in the "Plan" section state "rename pending your confirmation" and surface it under judgment calls for explicit user approval.)
- Wrong filename casing (same handling as extension — flag mechanical, rename is a judgment call)
- Lines >120 chars that aren't a single unbreakable string literal
- `let` / `expr` instead of `(( ))`
- `for x in $(cmd)` instead of `mapfile -t arr < <(cmd)`
- `xargs` without `--no-run-if-empty` and `--max-args=N`
- Bare `read` instead of `read -r`
- Aliases defined inside a script
- `;&` / `;;&` fall-through in a `case`
- `<` / `>` for numeric comparison inside `[[ ]]`
- Unquoted `${PIPESTATUS[@]}` capture not on the very next line
- Pipeline `|` placement on wrong line when wrapped
- Anything `shfmt` or `shellcheck` flagged
- `# shellcheck disable=SCxxxx` directives missing a same-line justification comment. Rule is unambiguous: justification must be on the SAME line as the disable directive. A justification comment on the line ABOVE does not satisfy the rule. Flag every disable directive lacking a same-line justification. **Format the justification as a separate comment using `# ` as the separator** — `# shellcheck disable=SC2016 # single quotes intentional`. Do NOT use `--` as a separator (shellcheck parses everything after `disable=` up to the next `#` as directive content and will error on `SC1072`/`SC1073`).

**Judgment calls** — the rule applies but the right answer depends on context, taste, or invasive design changes. Examples:
- A piece of inline shell that *could* be extracted into a new helper in `functions/<topic>.bash` (rule says "propose new helper rather than silently inlining" — but only when "logic looks reusable across scripts")
- Whether a function should be split because it's getting long
- Whether a comment block above a function is "non-trivial enough" to require the documented-positional-params block
- Whether a script's logic should be reorganized (e.g. interleaved executable code between function defs that could be moved into `main`, but is genuinely tricky to refactor)
- Whether a `# shellcheck disable=SCxxxx` line's justification comment is good enough
- Whether a dependency on bash 4+ features warrants adding the version-pin guard
- Choice between functionally equivalent helpers when both apply
- Refactors triggered by the "consistency tiebreaker" rule when surrounding code uses an outdated pattern

When unsure which bucket a finding belongs in, default to **judgment call** and let the user decide.

**Verify before flagging "no helper exists."** Before promoting an inline pattern to a judgment-call "consider new helper" finding, grep `functions/*.bash` for the operation. A prior audit incorrectly flagged `files::is_empty` as missing when it existed — silently rejecting an existing helper wastes review cycles. If a matching helper exists, treat the inline form as a mechanical violation (swap it) instead.

**Inter-library helper calls are runtime-safe.** Library files (`functions/*.bash`) contain only function definitions — no top-level code runs at source time. `functions.bash` sources every `functions/*.bash` before any user code executes, so by the time a function body runs, every other helper is defined. A helper in `args.bash` can safely call `strings::is_empty`, even though `strings.bash` is sourced later alphabetically. Do NOT defer cross-library helper swaps over fear of source-order or "circular sourcing" concerns — those concerns apply only to top-level code, which library files do not contain.

**Scope is NOT a judgment trigger.** The number of edits a rule fix requires (15 sites, 30 sites, whole-file rename) does not promote a mechanical violation to a judgment call. If the rule is clear and the fix is mechanical, apply it — no matter how many references must be updated. Rule adherence wins over edit-count concerns. The only reasons to defer are: (1) behavior change, (2) genuine ambiguity in how the rule applies, (3) requires authoring prose (rationale comments, opaque-filename `@description` text), (4) requires structural redesign (new helper extraction, restructuring control flow). Pure mechanical renames/replacements ship regardless of count.

### 6. Produce the report

Output the report inline in the conversation by default. (If the user told you to write to a file in `/tmp` for batch mode, do that instead.)

Use this exact structure:

```markdown
# shell-script-rules-check report — <path>

## File classification
- <top-level executable | library file>
- <any subtype notes: misc/ inline-trap, docker-* via DOCKER_COMPOSE_DIR, other/ third-party, etc.>

## Tooling output
- shfmt: <clean | N changes>
- shellcheck: <clean | N findings>
<paste any non-clean output verbatim>

## Mechanical violations (will be auto-fixed)
1. <line N>: <one-line description> → <one-line fix>
2. ...

## Judgment calls (need your decision)
1. <line N>: <description, context, options>
2. ...

## Plan
- Will apply mechanical fixes 1–N.
- Will pause for your decisions on judgment calls before touching them.
```

If a section is empty, write `(none)` under it.

### 7. Apply mechanical fixes

After printing the report, apply every mechanical fix to the file directly using `Edit` / `Write`. Do not ask first — the user has already opted in by invoking the skill. The judgment-call section is the only thing that pauses for input.

**Follow-on: test-setup updates.** When the fix swaps an inline pattern for a helper from a different `functions/<topic>.bash` file, check the corresponding `test/functions/<topic>.bats` setup for a `source` line for the newly-depended-on library. Example: replacing `[[ -z "${var}" ]]` with `strings::is_empty` in `functions/args.bash` requires `test/functions/args.bats` to also source `functions/strings.bash`. Add the missing source as part of the same mechanical fix — otherwise BATS tests will fail with `command not found` even though the helper resolves at runtime.

### 8. Resolve judgment calls

Ask the user about each judgment-call finding, one batch at a time. Be concrete: cite the line, state the rule, propose the change you'd make, and surface any tradeoff. Apply only what the user approves.

### 9. Verify

After all fixes, re-run the repo checker on the file to confirm clean:

```bash
./check-scripts "<file>"
```

If anything still fails, report the remaining output and either fix it (mechanical) or re-ask (judgment).

For `other/` files where the user opted in, re-run `shfmt --diff` and `shellcheck` directly instead.

### 10. Hands off

Do not `git add`, `git commit`, or otherwise touch git state. The skill ends after verification.

## Notes for the implementer

- The full merged rule list is large. When checking a script, you do NOT need to copy-paste every rule into your reasoning — read the rules files at the start of the run and rely on them as context. Focus the report on actual violations, not a recap of the rule book.
- Rules cross-reference helpers in `functions/*.bash`. When in doubt about whether a helper exists, grep `functions/`. Don't invent helper names.
- Predicate functions (`is_*`, `*_exists`) end with a bare `[[ ... ]]` whose exit status IS the return — flagging an explicit `return 0`/`return 1` here is a real violation, not a style nit.
- "Apply mechanical fix" means make the edit. Don't print a patch and call it done.
- When the script is a library file under `functions/`, suppress every finding that the exemption list explicitly removes. Do not flag a missing strict-mode pragma on `functions/foo.bash`.
