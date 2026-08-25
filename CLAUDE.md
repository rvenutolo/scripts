# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Personal collection of bash scripts for system setup, package install, and day-to-day utilities on the user's Linux machines. Pure shell, no build system; helper functions in `functions/*.bash` are covered by a BATS test suite under `test/` (at the repo root).

## Layout

All script directories live under a top-level `scripts/` dir, and `SCRIPTS_DIR` points at `repo-root/scripts`. Repo-tooling and config stay at the repo root (see the end of this section).

- `scripts/non-interactive/` — automation-safe utility scripts. These must be callable by cron, `topgrade`, or any other program: **no interactive prompts, no GUI launches, no `fzf`/picker UI, and no assumptions about a TTY or stdin-TTY.** **Always on `PATH`.**

- `scripts/interactive/` — everything else: utility scripts that prompt, launch a GUI, drive a picker, or otherwise assume a terminal, **plus every wrapper** (the former `wrapper/` scripts — `mvn`, `gradle`, `kate`, the flatpak wrappers, etc.). On `PATH` only in interactive shells (the user wires this into `~/.bashrc` behind a `case $- in *i*)` guard). **Exception:** the `claude` wrapper lives in `scripts/non-interactive/` — it derives `CLAUDE_CONFIG_DIR` from `PWD` at launch (honoring an already-set value), and that selection must also cover cron/`ssh`/scripted launches where `scripts/interactive/` is not on `PATH`.

- `scripts/other/` — third-party scripts copied verbatim from elsewhere. **Never modify anything under `scripts/other/` unless explicitly told to touch a specific file in there.** This applies to formatting, shellcheck fixes, refactors, renames, or any other automated cleanup. Always on `PATH`; excluded from treefmt formatting (via `.treefmt.nix` excludes) and from `shellcheck-scripts`. The one linter that does inspect `other/` is `.ci/check-executable-bit`: the directory is always on `PATH`, so a stripped exec bit breaks a script there, and restoring a file mode is not a content modification.

- `scripts/install/` — numbered scripts run in order by `run-install-scripts` to provision a new machine. Files starting with all-caps names (e.g. `00_DISTRO_PACKAGES`, `70_WORK_ONLY`) are markers/data with executable bit off — the runner skips non-executable files. `90_REMOVE` etc. follow same pattern.

- `scripts/set_up/` — idempotent post-install configuration, run recursively by `run-set-up-scripts`. Each script must self-check whether it should run.

- `scripts/misc/` — one-off setup scripts (not on `PATH`, not auto-run). Scripts here are expected to be **standalone** — runnable on a fresh machine by someone without access to this repo's function library. Do NOT source `.functions.bash` from `scripts/misc/` scripts; inline anything they need (including the `ERR` trap — see Script Conventions).

- `scripts/functions/` — bash function library, all sourced via `scripts/.functions.bash` (loops `scripts/functions/*.bash`).

Stays at the **repo root** (NOT under `scripts/`): `lib/` (vendored Groovy jars, used by some scripts), `.ci/` (repo-tooling scripts invoked by CI and `just`, e.g. `build-docs`, `check-shdoc-headers`; not on `PATH`), `test/` (BATS suite), `.github/`, `.shdoc/`, `.docs/`, the root runner executables (`check-scripts`, `shellcheck-scripts`, `run-install-scripts`, `run-set-up-scripts`, `run-tests`), and all config/dotfiles (`flake.nix`, `.treefmt.nix`, `CLAUDE.md`, `README.md`, etc.). Repo-tooling scripts that need the repo root (`.ci/*`, the root runners, `test/test_helper`) derive it via `git rev-parse --show-toplevel` (a local `REPO_DIR`), not a dedicated env var.

## Required Environment

The repo's tooling is provided by a **Nix flake devShell**: contributors install Nix + direnv, run `direnv allow` (or `nix develop`), and every tool (shfmt, shellcheck, bats, formatters, etc.) is available — nothing else to install. CI uses the same flake, so there is no version drift.

Every gate additionally runs *hermetically*, through `.ci/in-devshell` — see [Gates run inside the hermetic devShell](#gates-run-inside-the-hermetic-devshell). The local gate is `nix fmt` followed by `./.ci/in-devshell ./run-all-checks`.

The user's `~/.profile` exports a fixed set of env vars (`SCRIPTS_DIR`, `XDG_*`, `PERSONAL_PROJECTS_DIR`, etc.) that this repo relies on. They are always set in the environment by the time any script runs — interactive shells source `~/.profile`, and the `run-install-scripts` / `run-set-up-scripts` runners source it explicitly. Treat the full set as guaranteed. Read `~/.profile` to enumerate the available vars and their definitions.

- **Reuse, don't hardcode.** When a script references a path or hostname covered by one of these vars, use the env var literal directly: `"${SCRIPTS_DIR}/.functions.bash"`, `"${XDG_CONFIG_HOME}/foo/bar"`, `"${PERSONAL_PROJECTS_DIR}/some-repo"`, etc. Shell expands env vars natively — no templating needed.

- **No fallbacks.** Do NOT add `${VAR:-default}` defensive defaults or `set -u` defenses for any of these vars (including `SCRIPTS_DIR`). Failure under `set -u` is the desired behavior if the environment is broken — the user wants to fix the environment, not paper over it.

- **No env-var prefix when invoking repo scripts.** When running `./check-scripts`, `./shellcheck-scripts`, or any other script in the repo, do NOT prefix the command with `SCRIPTS_DIR=...` — the env var is already set.

- **Ignore conditional exports.** `EDITOR`, `VISUAL`, `PAGER`, `MANPAGER`, `FILE_MANAGER`, `TAILNET_IP`, `TAILNET_CIDR`, `TERM`, etc. are gated on `__executable_exists` / `case` / runtime probes in `~/.profile`; they're not meant for cross-file reuse and are not guaranteed to be set.

- **`PATH` membership.** `SCRIPTS_DIR` now points at `repo-root/scripts`. `scripts/non-interactive/` and `scripts/other/` are always on `PATH`. `scripts/interactive/` is on `PATH` only in interactive shells — the user wires it into `~/.bashrc` behind a `case $- in *i*)` guard so the wrapper scripts in there can shadow same-named binaries (`mvn`, `kate`, …) only when a human is at the keyboard, never in cron/`topgrade`/scripted contexts. `scripts/install/`, `scripts/set_up/`, `scripts/misc/`, and `.ci/` are not on `PATH`. Repo-tooling scripts (`.ci/*`, the root runners, `test/test_helper`) derive the repo root via `git rev-parse --show-toplevel`, not a dedicated env var. The `claude` wrapper is the deliberate exception — it lives in `scripts/non-interactive/` so profile selection works in every context.

- **`misc/` exemption.** Scripts under `misc/` are explicitly standalone — they must NOT depend on this repo's env or functions. Hardcoded paths are acceptable there.

### Sourcing `.functions.bash`

Every non-`misc/` script sources `"${SCRIPTS_DIR}/.functions.bash"`. Exception: a small number of Docker-related scripts (e.g. `scripts/non-interactive/docker-grype-scan`, `scripts/non-interactive/docker-trivy-scan`) source `${DOCKER_COMPOSE_DIR}/functions.bash` from a separate Docker repo instead. That file transitively sources `${SCRIPTS_DIR}/.functions.bash`, so all helpers from this repo (`log::enable_err_trap`, `log::log`, `log::die`, etc.) ARE available — no need to inline equivalents in those scripts.

`.ci/activate-githooks` is the one script under `.ci/` that sources nothing and omits `args::handle_help_flag`. It runs from the flake devShell's `shellHook`, including under `nix develop --ignore-environment`, where `SCRIPTS_DIR` does not exist — sourcing the library there killed it under `set -u`, so the tracked git hooks silently failed to activate in the one environment that most resembles a fresh clone (#231). A bootstrap script cannot depend on the environment it is bootstrapping, so it inlines the `ERR` trap and its few helpers the way `misc/` standalone scripts do.

## Common Commands

Tooling is provided by a **Nix flake devShell** (see [Required Environment](#required-environment)). Run `nix fmt` / `nix flake check` from the repo; every repo script below runs inside the hermetic boundary — `./.ci/in-devshell <script>` — or, interactively, from an already-entered direnv shell.

- `nix fmt` — formats files via treefmt (shfmt for shell, plus the other configured formatters). Replaces the now-retired in-place formatter script. **It does not cover every shell file:** treefmt matches formatters by file extension, so its shfmt only sees `*.sh` / `*.bash` / `*.envrc`. The extensionless top-level executables and `*.bats` files are outside its reach — `./check-scripts` carries the shfmt gate for those (see below).

- `nix flake check` — verifies formatting (treefmt) and runs the flake's checks. This is the formatting gate.

- `./shellcheck-scripts [<file-or-dir>...]` — runs `shellcheck` over the given files/dirs, or over all shell files except `other/` when no args. All scripts must pass.

- `./check-scripts [<file-or-dir>...]` — combined check: runs `shfmt` (verify only, never rewrites), `shellcheck`, the shdoc-header audit (`.ci/check-shdoc-headers`), and the executable-bit audit (`.ci/check-executable-bit`), aggregating exit codes so a failure in any of them fails the run. Use this for CI/pre-commit-style verification.

  The shfmt step is not redundant with `nix fmt`: treefmt matches by file extension, so it never sees the extensionless top-level executables or `*.bats` files. This step covers them, running over the pre-filter candidate list. That list is gated on `shell_scripts::is_shell_file` — extension-or-shebang, mirroring `shfmt --find` — because `shell_scripts::find` echoes an explicitly-passed file verbatim, so without the gate a `./check-scripts CLAUDE.md` would hand markdown to shfmt and fail on a bogus parse error (#206). `shell_scripts::filter` gates the shellcheck list on the same predicate, so `*.bats` files reach both steps by extension whether or not they carry a shebang; gating shellcheck on the shebang alone left 31 of 83 test files silently unlinted (#215). It passes no style flags — see [Shell style lives in `.editorconfig`](#shell-style-lives-in-editorconfig).

### Shell style lives in `.editorconfig`

`.editorconfig` is the single source of truth for shell formatting. Both shfmt call sites — treefmt's formatter entry in `.treefmt.nix` and the shfmt step in `check-scripts` — deliberately pass **no** parser or printer flags, because shfmt reads `.editorconfig` only when given none. `--write`, `--list`, and `--diff` are top-level flags and do not disable it; `-i`, `-ci`, `-bn`, `-sr`, and `-s` do.

Change shell style in `.editorconfig` and nowhere else. Adding a style flag at either call site silently overrides this file and forks the definition.

Because this repo's top-level executables have **no extension** by convention, `[*.{sh,bash,bats}]` alone would miss roughly 306 of them, so `.editorconfig` also carries path-based sections for `.ci/`, `.githooks/`, `scripts/{non-interactive,interactive,install,misc,set_up}/`, and the repo-root runners. `scripts/other/` is deliberately absent — third-party scripts are never reformatted. A new directory of executables needs a matching section, or its scripts silently fall back to the `[*]` defaults.

Note that `switch_case_indent`, `binary_next_line`, and `space_redirects` are shfmt-specific properties. Editors and `editorconfig-checker` ignore them; only shfmt acts on them.

- `./run-install-scripts` — provision new machine. Sources `~/.profile`, validates sudo, runs every executable file under `install/` in `LC_COLLATE=C` order.

- `./run-set-up-scripts` — same pattern, recursive over `set_up/**/*`.

- `scripts/non-interactive/new-script <path>` — scaffolds a new script with the standard header + exec bit.

- `./run-tests [<bats-args>...]` — runs BATS tests under `test/functions/`, `test/ci/`, and `test/root/` recursively when called with no args, or forwards args to the devShell's `bats` from `PATH`. Default invocation uses `bats --jobs $(nproc)` for parallel execution.

To gate a script from the `install`/`set_up runners`, remove its executable bit (`chmod -x`).

## Function Library

`functions/` is organized by topic — `args`, `arrays`, `commands`, `docker`, `downloads`, `env`, `files`, `flatpak`, `grep`, `http`, `json`, `log`, `mvn`, `network`, `os`, `packages`, `path`, `prompt`, `retry`, `sdkman`, `strings`, `symlinks`, `system`, `systemctl`, `text`, `time`, etc. When adding a helper, drop it in the topically-matching file; it's auto-sourced. If no existing topic fits, Claude may create a new `functions/<topic>.bash` file — but must ask first before adding the new topic.

## Script Conventions

The generic shell-script rules in `.claude/rules/shell-scripts.md` apply to this repo. **Rules in this section override rules in that file when they conflict** — every override is called out with a "**Overrides**" line so the divergence is explicit.

@.claude/rules/shell-scripts.md

### Helper function mandate

- Claude MUST use the helper functions in `functions/*.bash` whenever an applicable helper exists. Do not write inline equivalents for operations that already have a helper (file mutation, prompts, OS detection, downloads, path manipulation, logging, arg-count guards, executable existence, symlinks, etc.). Before writing inline shell, scan `functions/*.bash` for a matching helper.

- Claude may propose new helper functions when a piece of logic looks reusable across scripts, even if it is currently only needed in one place. Suggest the new helper (with proposed file and signature) rather than silently inlining.

### Shdoc annotations for top-level scripts

Every top-level executable shell script (any file with a bash/sh shebang under `scripts/non-interactive/`, `scripts/interactive/`, `scripts/install/`, `scripts/set_up/`, `scripts/misc/`, `.ci/`, or the project root) must carry a file-level shdoc header block immediately after the shebang line and before the `set -Eeuo pipefail` pragma.

Required tags (each used where applicable):

- `@description` — one-line prose summary; continuation lines allowed with aligned comment text.

- `@arg $N <name> <description>` for every positional parameter, OR `@noargs` if the script takes none.

- `@stdout <description>` if the script emits meaningful output to stdout (beyond logging).

- `@stderr <description>` if the script emits non-trivial diagnostic output to stderr (beyond standard `log::log`/`log::warn`/`log::die`).

- `@exitcode N <meaning>` for every non-zero exit code the script can produce.

- `@example` — optional but encouraged for any script with non-obvious CLI shape.

Header position — between the shebang and `set -Eeuo pipefail`:

```bash
#!/usr/bin/env bash

# @description One-line summary of what the script does.
# @arg $1 input path to input file
# @exitcode 0 success
# @exitcode 1 input file missing

set -Eeuo pipefail
IFS=$'\n\t'
```

Helper functions defined inside top-level scripts get the same full shdoc annotation block as library functions. **Exception:** the `main` function is exempt — the file-level header covers it.

`misc/` standalone scripts (those that do not source `.functions.bash`) follow the same rule. Shdoc tags are plain comments and do not depend on the function library.

Annotation blocks must not carry scaffold placeholder text. `check-shdoc-headers` fails a
bare, case-sensitive, word-bounded `TODO` in a top-level script's file-level header **and** in
any function's annotation block, in both top-level scripts and `functions/*.bash` library
files. A backtick-quoted `` `TODO` `` is allowed — that is prose about the token, which is how
`shdoc.bash` documents the rule it implements. `todo`, `TODOS`, and `TODO_MARKER` do not trip
it. This does not restrict `TODO:` for marking deferred work inside a function body, or in a
comment separated from the definition by a blank line.

Files excluded from `shell_scripts::find` (`.shdoc/`, `.direnv/`, `scripts/other/`) are excluded from this rule.

Library files under `functions/*.bash` follow a related but distinct rule: every function must have a preceding shdoc annotation block, but the file-level `@description` is intentionally not required because library files are documented function-by-function. `.ci/check-shdoc-headers` enforces both rules in a single audit pass (top-level scripts get the file-level + per-helper check; library files get the per-function check, minus the file-level `@description`). Both arms also reject placeholder text in a function's annotation block, per the rule above. Both contribute to the audit's exit code, and the audit is wired into `check-scripts` so any regression fails the aggregate gate.

### Arity tests must assert the guard message

A test that invokes a helper with a deliberately wrong argument count and then
asserts only `assert_failure` passes whenever the helper fails for *any* reason, so
it does not pin the arity guard it claims to test. Assert the message too:

```bash
@test "mtime_epoch: 2 args dies" {
  run files::mtime_epoch 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
```

Bare `assert_failure` remains correct where failure itself is the whole
specification — a predicate helper such as `strings::is_empty` or `os::is_debian`
returning non-zero has no message to assert.

**`run --separate-stderr` needs `assert_stderr` instead.** `log::die` writes to
stderr, so under that flag `${output}` is empty and `assert_output` can never match:

```bash
run --separate-stderr git::clear_local_env 'x'
assert_failure
assert_stderr --partial 'Expected no arguments'
```

`assert_stderr` and `refute_stderr` are easy to overlook — bats-assert defines them
inside `src/assert_output.bash` and `src/refute_output.bash` rather than in files of
their own, along with `assert_stderr_line` and `refute_stderr_line` in the `*_line.bash`
pair. All four delegate to a shared `__assert_stream` that picks the stream from the
caller's name. There is no `src/assert_stderr.bash`, which is why an `ls src/` once
concluded they were missing (#274).

**`flake.nix` takes bats-assert and bats-support from flake inputs, not from the nixpkgs
releases, and that is load-bearing — never "simplify" it back to a bare `l.bats-assert` /
`l.bats-support`.** Both come from the devShell's `bats.withLibraries`, but each is
wrapped in an `overrideAttrs` that swaps in the corresponding `flake = false` input.
nixpkgs ships **bats-assert 2.1.0, which has no `assert_stderr` / `refute_stderr` at
all** — they exist only on master. Taking the nixpkgs release would break roughly 30
tests and silently un-enforce `.ci/check-stderr-assertions` along with the entire
convention documented here.

They are inputs rather than hand-written `fetchFromGitHub` pins because `flake.lock`
stores the revision and its `narHash` **together**. A pin needs both, and Renovate cannot
compute a `fetchFromGitHub` hash, so the pinned form could only ever open a red PR
awaiting a hand-regenerated hash. As inputs they are covered by Renovate's ordinary `nix`
manager, which updates the lock wholesale — no hash step, and no separate custom manager
to maintain.

The `version` attribute is likewise derived from each input's own `lastModifiedDate`
through the `unstableVersion` helper, so the store path relabels itself on a bump. A
hardcoded version would go stale the first time the lock moved, leaving a path that
claims a revision it does not contain.

Note the consequence: because the `nix` manager rule carries `automerge: true`, a
bats-library bump **lands on `main` without review if CI is green**. The suite is the
control — it exercises these assertion functions on every run — but a semantics change
upstream gets in on a green build.

`.ci/check-vacuous-arity-tests` enforces this. It resolves each `run` target to the
`args::check_*` guard the helper declares and flags the test only when the argument
count on the `run` line violates that guard — it reads no test titles, so the prefix
collisions, loop-based tests, and competing title conventions that broke the #251
sweep cannot affect it. It abstains rather than guesses on any shape it cannot parse:
external commands, variable targets, dynamic argument lists, unbalanced or
continued lines, command substitution, and multi-line `bash -c` strings. Two
consequences follow. `test/ci/` and `test/root/` are **not** covered, because they
invoke their subject through `"${CHECK}"`. And non-arity deaths — a missing file, an
absent tool — are not covered either, since no static rule can predict them; assert
those messages anyway, just without a lint to enforce it.

Exemptions are keyed `<repo-relative-file>::<helper>#<argcount>`. The key carries no
spaces because `arrays::from_env_override` splits its override on spaces, and it
survives a test moving within its file, which a line number does not.

**Never hand-roll a bracket test against `${stderr}`, `${output}`, or `${status}`.**
The glob works, but on failure BATS prints only the bare failed-bracket line with no
indication of what the stream or the exit code actually held, while `assert_stderr`
prints a `-- stderr does not contain substring --` block naming both the substring and
the real stderr, and `assert_failure` names the expected and actual exit codes. The
rule is not limited to arity tests — it covers every such assertion in the suite.

- `assert_stderr --partial 'X'` / `refute_stderr --partial 'X'` — substring present or
  absent.
- `assert_stderr --regexp 'RE'` — ERE, the same engine bash's `=~` uses, so a pattern
  moved out of a `[[ ]]` transfers verbatim. Quote it, and drop any `\ ` escapes that
  were needed only because the old right-hand side was unquoted.
- Bare `assert_stderr` asserts stderr is non-empty; bare `refute_stderr` asserts it is
  empty. Prefer `refute_output` over `assert_output ''` for the stdout half, for the
  same diagnostic reason.
- Both die with `stderr: parameter not set` when the `run` omitted `--separate-stderr`,
  which is a clearer failure than the silent empty-string compare it replaces.

The stdout and status halves follow the same shape:

- `assert_output --partial 'X'` replaces `== *X*`, `refute_output --partial 'X'`
  replaces `!= *X*`, and `assert_output --regexp 'RE'` replaces `=~ RE`. Bare
  `assert_output` and bare `refute_output` replace `-n` and `-z`.
- `assert_success` replaces `-eq 0`. `assert_failure N` replaces `-eq N` — prefer it
  over bare `assert_failure`, which accepts any non-zero status and silently widens
  the assertion.
- Two things stay as brackets, because bats-assert has no replacement: a numeric
  comparison on stdout (`[ "${output}" -ge 3 ]`, a count) and a length test
  (`[[ "${#output}" -eq 32 ]]`).

`.ci/check-stderr-assertions` enforces this across four rules, over any `.bats` file
under `test/functions`, `test/ci`, or `test/root`. Its name predates rules 3 and 4 and
is kept for continuity; its scope is every variable `run` sets, not stderr alone.

- **Rule 1** rejects a raw `${stderr}` expansion inside a bracket test.
- **Rule 2** rejects an `assert_output` / `refute_output` / `assert_line` /
  `refute_line` carrying an expectation inside a `@test` whose `run` used
  `--separate-stderr` — the #274 trap, where the assertion reads correctly and can
  never match. A bare call or an explicit `''` is allowed, because asserting that
  stdout is empty while stderr carries the message is a legitimate shape.
- **Rule 3** rejects a raw `${output}` expansion inside a bracket test, except under a
  numeric operator (`-eq -ne -lt -le -gt -ge`). `${#output}` is never matched — the
  pattern targets the expansion, not the length of it.
- **Rule 4** rejects a raw `${status}` expansion inside a bracket test, with no numeric
  carve-out: a numeric status compare is exactly what `assert_failure N` replaces.

All four accept either bracket spelling. `[ "${status}" -eq 1 ]` is as opaque on
failure as the `[[ ]]` form, and `test/ci/check-orphan-invariants.bats` was written in
single brackets throughout.

Rule 2's block trigger is anchored to a real `run` invocation rather than matching
`--separate-stderr` anywhere on a line, so a fixture string that merely quotes the flag
does not open a block. That is load bearing: with a bare match the lint flagged its own
paired test. For the same reason each rule's pattern is spelled `\$[{]name[}]`, and both
`test/ci/check-stderr-assertions.bats` and the `@@STDERR@@` sentinel in
`test/ci/check-vacuous-arity-tests.bats` compose their offending fixture lines at runtime
rather than spelling them literally. A lint that scans the real tree cannot tell a fixture
string from an assertion, so any new fixture holding a deliberate violation needs the same
treatment.

### Standard top-level skeleton

Carry the file-level shdoc header (see [Shdoc annotations for top-level scripts](#shdoc-annotations-for-top-level-scripts)), source the function library, enable the `ERR` trap, handle `-h`/`--help`, then guard arg count:

```bash
#!/usr/bin/env bash

# @description One-line summary of what the script does.
# @noargs

set -Eeuo pipefail
IFS=$'\n\t'

#shellcheck disable=SC1091
source "${SCRIPTS_DIR}/.functions.bash"
log::enable_err_trap
args::handle_help_flag "$@"
args::check_no_args "$@"   # or check_exactly_N_args / check_at_least_N_args / check_at_most_N_args
```

- `log::enable_err_trap` (from `functions/log.bash`) installs an `ERR` trap that prints a red, prefixed `ERROR: line N (exit C): cmd` line to stderr when any unhandled command fails under `set -e`. Call it once, immediately after sourcing `.functions.bash`. It complements `log::die` (explicit user-visible failures) — the trap catches everything else.

- `args::handle_help_flag "$@"` (from `functions/args.bash`) scans `"$@"` for `-h`/`--help` and, if present, prints help text derived from the script's file-level shdoc header (via `args::print_help`) and exits 0. Call it directly after `log::enable_err_trap` and before any arg-count guard — otherwise `--help` would be rejected as an unexpected argument. Pass-through scripts (those forwarding `"$@"` verbatim to an underlying tool) and standalone scripts under `misc/` are exempt: pass-throughs let the wrapped tool handle its own `--help`; standalones cannot source `.functions.bash`.

- Create new scripts via `scripts/non-interactive/new-script <path>` (handles header + exec bit + `args::handle_help_flag` line).

### Arg-count guards

- Use `args::check_no_args "$@"` / `check_exactly_N_args` / `check_at_least_N_args` / `check_at_most_N_args` from `functions/args.bash` at the top of every top-level script and library function with a fixed arity.

- **Pass-through scripts and variadic library functions are exempt.** A pass-through script forwards `"$@"` to an underlying tool (e.g. `scripts/non-interactive/claude` wraps the real `claude` binary, `scripts/non-interactive/sync-flatpaks` accepts optional filter args) and has no fixed arity. A variadic library function takes 0+ items of the same kind. In both cases, omit the `args::check_*_args "$@"` guard and add a same-line comment explaining why: `# pass-through: any arg count valid` (or similar). The comment is mandatory — silent omission is not allowed.

- Library functions in `functions/*.bash` use the same `check_*_args "$@"` guards as top-level scripts.

- For predicate branching on caller arg count (e.g. choosing a default vs. consuming `$1`), use `args::no_args "$@"` or `args::has_num_args N "$@"` from `functions/args.bash` — never inline `[[ "$#" -eq N ]]`. Use `args::no_args` for the zero-arg case (not `args::has_num_args 0`).

### Library file conventions

Library files under `functions/` get only the shebang — do NOT add `set -euo pipefail` or source `.functions.bash`. Strict mode is owned by the parent script that sources them.

**`functions/*.bash` exemption list** — library files are exempt from the following rules that apply to top-level scripts:

- `set -Eeuo pipefail` strict-mode pragma (parent owns strict mode)

- `IFS=$'\n\t'` (parent owns IFS)

- `source "${SCRIPTS_DIR}/.functions.bash"` (would be circular)

- `log::enable_err_trap` call (parent installs the trap)

- The inline `ERR` trap form (only used by standalone `misc/` scripts)

- Top-level `args::check_*_args "$@"` guard (library files have no top-level args; functions inside them still use `check_*_args` guards)

- `main "$@"` final-line / `function main()` requirement (library files have no entry point)

- File-layout rule that constants must precede functions (library files contain only function definitions; no constants section)

- File extension: library files use `.bash` (top-level executables have no extension)

- Filename casing: library files use `snake_case` (top-level executables use `kebab-case`)

- Executable bit: library files must NOT be executable (top-level scripts must be executable)

- Creation via `scripts/non-interactive/new-script`: library files are hand-created (the helper is for top-level executables)

All other rules (helper-function usage, quoting, `[[ ]]` over `[ ]`, `(( ))` arithmetic, comment block above non-trivial functions, `local`/`local -r` inside every function, predicate-function return-via-exit-status, namespaced `::` function names, etc.) apply equally to library files.

### File extensions and filename conventions

- Top-level executables (everything under `scripts/non-interactive/`, `scripts/interactive/`, `scripts/install/`, `scripts/set_up/`, `scripts/misc/`, `.ci/`) have no extension; library files under `scripts/functions/` use the `.bash` extension and are NOT executable.

- Executables use kebab-case (`new-script`, `check-scripts`, `run-install-scripts`); library files use snake_case with the `.bash` extension (`functions/files.bash`, `functions/log.bash`).

- Library functions are namespaced with `::`: a helper in `functions/files.bash` is `files::exists`, in `functions/log.bash` is `log::log`, etc. Internal/private helpers (not used across files) may keep plain `snake_case`.

### `set_up/` idempotency

Scripts under `set_up/` must be idempotent and self-gate — check current state before mutating, and exit cleanly when there is nothing to do.

### Provisioning-runner test seams

`run-install-scripts` and `run-set-up-scripts` read their script directory through `INSTALL_DIR_OVERRIDE` / `SET_UP_DIR_OVERRIDE`, defaulting to `${SCRIPTS_DIR}/install` and `${SCRIPTS_DIR}/set_up`. Production leaves both unset; `test/root/` uses them to drive the runners against fixture trees, with `sudo` stubbed via `cli_shim::record` and `HOME` pointed at an empty tmpdir so the `~/.profile` branch is skipped.

**Never run these two runners without a seam in order to observe a "failure" — they execute the real provisioning scripts against the live machine.** Stubbing `sudo` does not prevent that; the scripts under `install/` and `set_up/` run for real. To exercise the fallback path, copy the repo to a tmpdir and empty those directories there.

### Gates run inside the hermetic devShell

Every gate — `./run-all-checks` and each of its five sub-gates, every `just` recipe that
runs one, `.githooks/pre-push`, and every workflow step that shells out — is invoked
through `.ci/in-devshell`. Nothing else in the repo may spell `nix develop`.

`.ci/in-devshell <command> [args…]` re-execs the command under
`nix develop "${REPO_DIR}" --ignore-environment --keep … --command`. The
`--ignore-environment` is the whole point. A plain `nix develop --command` *prepends* the
devShell PATH and leaves the ambient PATH reachable behind it, so every gate resolved its
tools by precedence rather than by guarantee: a tool missing from `flake.nix` still
resolved from the maintainer's machine and from the runner's `/usr/bin`, and the build was
green. That is the same class of false green as #219, #228, and #250, and the existing
`check-tool-declarations` + `check-devshell-provides` pair cannot catch it — those verify
that declared tools *are provided*, never that undeclared tools are *unavailable*.

**The boundary paid for itself on the first hermetic run.** It found exactly two
dependencies that were in no declaration and had been resolving silently all along:
`flock` (`bats --jobs` refuses to parallelize within a file without it and the nixpkgs
bats wrapper does not carry it, so the entire suite dies on its absence) and `bc` (piped
through by `files::size_gb`, whose test passed while the helper exited 127). Both are now
devShell packages. Neither was findable by inspection; only removing the ambient PATH
surfaced them.

The boundary applies to CI, `./run-all-checks`, `just`, and `pre-push` alike. CI-only
hermeticity would preserve exactly the local/CI gap the change exists to close.

- **`--keep` is a fixed allowlist**, spelled once, in `.ci/in-devshell`'s `KEEP_VARS`:
  `HOME`, `TERM`, `CI`, `SCRIPTS_DIR`, `IN_DEVSHELL`, `NIX_SSL_CERT_FILE`, the
  `GITHUB_*` workflow-context names, `GITHUB_TOKEN` / `GH_TOKEN` / `GH_REPO`, and
  `RUNNER_OS` / `RUNNER_TEMP`. Anything not on that list does not cross. Every name is
  passed unconditionally — `--keep` on an unset variable is silent and harmless — so no
  set-checking branch is needed for the `GITHUB_*` names that are absent locally.

- **`IN_DEVSHELL_KEEP` is the per-call-site escape:** a space-separated list of extra
  names appended at runtime. Use it for a variable meaningful to one step only, rather
  than growing the fixed list. `pr-title-lint.yml` uses it for `PR_TITLE`, which must stay
  off the fixed list precisely because it is attacker-influenced PR text.

- **The wrapper owns `SCRIPTS_DIR`.** It derives `REPO_DIR` from
  `git rev-parse --show-toplevel` and exports `SCRIPTS_DIR="${REPO_DIR}/scripts"`, which
  is why the `env: SCRIPTS_DIR:` block is gone from every converted job. It also passes
  `"${REPO_DIR}"` as the flake reference, so a worktree or second clone builds its own
  devShell instead of silently grading itself with the main checkout's (#250).

- **Nesting is free.** `IN_DEVSHELL=1` is exported and kept, and the wrapper `exec`s the
  command directly when it is already set, so a wrapped `./run-all-checks` pays one nix
  evaluation for all five sub-gates instead of six. Call it from anywhere without checking.

- **It is a bootstrap script**, in the `.ci/activate-githooks` mold (#231): it runs before
  the environment it creates, so it sources nothing, omits `args::handle_help_flag` (every
  argument belongs to the wrapped command, so a `--help` would have to be forwarded
  anyway), and inlines the standalone `ERR` trap. It needs only bash, git, and nix from
  the host. It does carry `shopt -s inherit_errexit` — it calls `$(git rev-parse …)`.

- **`nix fmt` stays outside**, and so does `just new-script`. `nix fmt` is a nix
  invocation, not repo tooling running under the devShell, so wrapping it is circular.
  `new-script` invokes a `scripts/` payload script, and `scripts/` is outside the boundary
  by design — payload scripts expect their tools from the machine.

- **`.githooks/commit-msg` is deliberately outside.** It shells out to exactly one tool,
  `commitlint`, from the ambient (direnv) PATH. Wrapping it would buy a nix evaluation on
  every single commit in exchange for one binary. This is a decision, not an oversight —
  do not "fix" it.

`.ci/check-workflow-hermetic` enforces the boundary over `.github/workflows/*.yml` and
`.github/actions/*/action.yml`, in two rules. Rule 1: every step carrying a `run:` key must
invoke `.ci/in-devshell`, or be listed in `EXEMPT`. Rule 2: no workflow may spell
`nix develop` at all — that spelling belongs to the wrapper alone, because the wrapper is
what supplies `--ignore-environment` and the keep list, and a direct invocation is a
boundary with its walls taken down while still looking correct. Rule 1 asks only whether
the wrapper appears somewhere in the run body: the reducer that would have to split a block
into commands is quote-unaware, so the inner script of an `.ci/in-devshell bash -c '…'`
would read as a row of unwrapped commands. Rule 2 is what closes the gap that leaves, and
the two together are what CI actually depends on.

`EXEMPT` keys are `<repo-relative-file>::<step-id>`, with the usual bidirectional staleness
detection — an entry naming no run step, or naming one that *does* go through the wrapper,
fails the lint rather than silently disarming it. Because a key needs a step id, an exempt
step must carry a YAML `id:`; a non-compliant step without one is reported as an error
naming that fix rather than being keyed on its `name:`, which is free text and drifts. The
single shipped exemption is `changed-tests`' `decide` step, which runs deliberately before
Nix is installed on the runner — installing Nix merely to decide whether the job needs to
do anything would defeat the skip it exists to provide. That exemption is permanent.

### Scan roots come from `REPO_DIR`, not `SCRIPTS_DIR`

Repo tooling that **inspects the tree** must resolve its scan roots from the repo it was
invoked in — `REPO_DIR="$(git rev-parse --show-toplevel)"` — never from the `SCRIPTS_DIR`
environment variable. `SCRIPTS_DIR` points at the user's main checkout, so a gate rooted
there audits that tree from inside a worktree or a second clone and reports success for the
tree actually being worked on. That is a false green, silent and indistinguishable from a
real pass; it hid a broken shdoc header through two consecutive full-gate runs (#250).

Runners that **act on the machine** are the deliberate exception: `run-install-scripts` and
`run-set-up-scripts` provision the host from the user's canonical scripts, so `SCRIPTS_DIR`
is the correct root there.

`source "${SCRIPTS_DIR}/.functions.bash"` is always fine — it locates the function library,
not a scan root.

`.ci/check-tree-scan-root` enforces this over `.ci/`, `.githooks/`, and the repo-root
runners. Its `EXEMPT` array holds the two provisioning runners and carries staleness
detection: an entry naming no in-scope file, or naming one with no flagged reference, fails
the lint rather than silently disarming it.

### Empty scan results are failures, not clean passes

`shell_scripts::find` (no-args form) and `shell_scripts::find_root_only` both **exit 1 when they
match nothing**. A caller that scans a tree and finds no shell files has almost certainly been
pointed at the wrong tree, and a silent empty result there is indistinguishable from a clean pass
over code that was never examined — the same false-green shape as #250 and #290. `find` gets this
from its trailing `grep --invert-match`; `find_root_only` counts what it emitted.

**No caller suppresses this, and none should.** A repo root with no shell scripts is not a shape
this project has — the root always holds `check-scripts`, `shellcheck-scripts`,
`run-install-scripts`, `run-set-up-scripts`, `run-tests` and `run-all-checks` — so the exit is a
live guard rather than decoration.

`test/ci/check-shdoc-headers.bats` originally built fixture repos with no root-level scripts, which
made the check die once the exit landed. The fix was to give the fixture a root script, **not** to
teach the check to tolerate an empty root: a fixture that does not mirror any real tree is worth
less than the guard it would have cost. Bending production code to accommodate a fixture is how a
gate ends up reading clean over a tree it never scanned (#250, #290).

### Configured paths must resolve

Exclusion lists and label globs name directories by hand, and when a directory moves the stale
entry simply matches nothing — no error, no warning, the config quietly stops working. The
`scripts/` reorganisation left four behind: typos was scanning `scripts/other/` (third-party code
the repo forbids editing, so a typo there would fail the gate with no legal fix), the PR
auto-labeler had stopped labelling script changes entirely, and reviewdog was shellchecking the
same third-party tree (#314, #315).

`.ci/check-config-paths` enforces that every literal path configured in `.typos.toml`,
`.github/labeler.yml`, `.yamllint.yml`, `.treefmt.nix`, and reviewdog's `exclude:` in
`.github/workflows/ci.yml` still names something git knows about.

**A path passes when it is tracked or deliberately gitignored** — both are intentional states, and
neither query consults the working tree. That distinction is load-bearing: a plain `[ -e ]` check
passes locally after a docs build and fails on a fresh CI checkout, because `site/` is generated.
For the same reason the ignore query retries with a trailing slash — a directory-only rule like
`site/` matches `git check-ignore site/` always, but matches bare `site` only while the directory
exists on disk.

An entry with no literal prefix (`**/*.md`) is skipped; there is nothing to resolve. The check
verifies **existence, not intent** — it catches an entry naming a path that is gone, not one naming
a real directory that is simply the wrong one.

`EXEMPT` holds paths git genuinely cannot see, and ships with one: `lib`, the vendored Groovy jars,
which were never committed and never ignored either. It carries the usual bidirectional staleness
detection, and the ordering inside `main` is what buys the second direction — only an entry that
actually fails to resolve is routed through the exemption, so an exemption whose path resolves on
its own is reported stale rather than sitting there unnoticed.

Adding a config file with a path list means adding it to `SOURCES` with an extractor function.
`.github/labels.yml` prose descriptions are deliberately out of scope: pinning an English sentence
shape would break the moment someone rewords one.

### Gate scripts enable `inherit_errexit`

Bash unsets `errexit` inside a command-substitution subshell unless `inherit_errexit` is
set. A helper invoked as `n="$(scan "${file}")"` therefore keeps running after a command
inside it fails, echoes a zero count, and the caller exits 0 on input it never managed to
check. The `ERR` trap still fires and prints a red line, which makes the failure look
reported when nothing acted on it — the same silent false-green as #250, and how a lint came
to grade a workflow it could not parse (#290).

Every shebang-bearing executable under `.ci/` and `.githooks/`, plus the repo-root runners,
carries the shopt directly below the strict-mode pragma:

```bash
set -Eeuo pipefail
# Without this, errexit is off inside every $(...) subshell, so a helper called
# as `n="$(scan ...)"` runs past a failed command and this gate exits 0 (#290).
shopt -s inherit_errexit
IFS=$'\n\t'
```

`.ci/check-inherit-errexit` enforces it. Its `EXEMPT` array holds only
`.ci/activate-githooks` — the bootstrap script that sources nothing (#231) and calls no
helper through a command substitution — and carries the usual bidirectional staleness
detection.

**The shopt does not cover the sibling suppression.** `errexit` is also disabled for a
function's entire call tree when that function is invoked as an `if`/`while`/`until` condition
or on the left of `||`/`&&`. A predicate that shells out to `yq` swallows the parse failure
and answers "no", which reads as a clean file. Write parser-backed helpers as producers called
plainly, never as predicates called from a condition — keep only the test whose non-zero
result is *meaningful* (a `grep`, a `jq empty`) inside the condition.

`.ci/check-errexit-predicate` enforces this over the same scope, and its `EXEMPT` array ships
empty. It is deliberately narrow: it flags a function **defined in the scanned file** whose
**own body** runs `yq` or `jq`, called from a condition **in that same file**. No transitive
analysis, because the condition shape alone is a poor signal — of the five call sites #294
first suspected, four turned out to be pure bash with nothing to suppress, and a pure
predicate called from an `if` is correct bash. The parser in the body is what makes the shape
dangerous.

Because the lint searches for the parser names, its own source spells them `y[q]` and `j[q]`
so it does not flag itself, the same self-reference device `check-tree-scan-root` uses.

Known-good conversions, all from #290/#294: `workflow_triggers` prints trigger names as a
plain command; `harden_runner_count` replaced a `has_harden_runner` predicate whose `yq`
failure manufactured a "job has no harden-runner step" finding out of a parse error;
`check-shdoc-headers`'s `audit_one`/`audit_library_one` print their report to stdout and the
caller judges by whether output appeared, so a failure in the `awk` that enumerates functions
can no longer read as "this file is clean"; and `run-lint-checks` inlined its `lint_json`
helper, whose suppressed `find` failure left `xargs --no-run-if-empty` with nothing to do and
every JSON file unlinted under a green step.

**A deliberate swallow is the same bug.** `check-required-checks-no-paths` carried
`2> /dev/null || printf 'false'`, which reported an unreadable workflow as "declares no path
filter". The fallback existed for a real shape — `.on.pull_request` errors while indexing a
flow-list `on: [pull_request]`, *before* any `select` on the result can filter it — but it
covered a genuine parse failure at the same time. Guard `.on` itself and the fallback becomes
unnecessary; no lint catches this form, so it is a review matter.

Scripts under `scripts/` are outside this rule: it targets the gates, where a wrong exit code
is indistinguishable from a clean run.

### Standalone `misc/` ERR trap

Standalone scripts that do NOT source this repo's `.functions.bash` (everything in `misc/`) cannot call `log::enable_err_trap`. Inline the trap directly after the `IFS=` line. (Note: scripts that source `${DOCKER_COMPOSE_DIR}/functions.bash` DO have access to this repo's helpers — that file transitively sources `${SCRIPTS_DIR}/.functions.bash` — so use `log::enable_err_trap` there, not the inline form.)

```bash
trap 'printf "\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n" "$(date +%T)" "${0##*/}" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR
```

### Logging helpers

**Overrides** the generic `log` / `log_info` / `log_warn` / `log_err` template in `.claude/rules/shell-scripts.md`. Use the repo's helpers from `functions/log.bash` (all color-coded, written to stderr, prefixed with `${0##*/}`):

- `log::log` — green, info-level

- `log::with_date` — green, info-level with full date

- `log::warn` — yellow, warn-level (use for non-fatal problems)

- `log::die` — red, error-level + `exit 1` with caller context

There is no separate `log_info` (use `log::log`) or `log_err` (use `log::die` if fatal, or `log::warn` if not). `log::die` includes caller context via `${BASH_SOURCE[1]}:${FUNCNAME[1]}:${BASH_LINENO[0]}` — preserve this when modifying the helper.

### Stdin presence

Helpers `args::check_for_stdin` / `args::stdin_exists` from `functions/args.bash`. No inline `[[ -t 0 ]]`.

### Existence checks

Helpers `files::exists` / `files::assert_exists` (`functions/files.bash`), `dirs::exists` / `dirs::assert_exists` (`functions/dirs.bash`), `symlinks::exists` (`functions/symlinks.bash`). Use the `assert_*` variants for entry-point validation (they call `log::die` with a consistent message); use the bare predicates for branching. No inline `[[ -f X ]]` + manual `log::die` rolls.

### Interactive prompts

Helpers `prompt::yn` / `prompt::ny` / `prompt::for_value` from `functions/prompt.bash`. Fall back to inline `read -rp $'\e[0;33mPrompt: \e[0m'` (colored `$'...'` form) only when no helper fits, and document why with a comment.

### Empty-string tests

**Overrides** the generic `[[ -z "$x" ]]` / `[[ -n "$x" ]]` rule in `.claude/rules/shell-scripts.md`. Use helpers `strings::is_empty` / `strings::is_not_empty` / `strings::is_blank` from `functions/strings.bash` instead of inline `[[ -z "$x" ]]` / `[[ -n "$x" ]]`. `strings::is_blank` is true for empty OR all-whitespace strings.

### Tool availability

**Overrides** the generic `command -v tool >/dev/null 2>&1` rule in `.claude/rules/shell-scripts.md`. Use `commands::executable_exists` from `functions/commands.bash` (uses `type -aPf`, excludes builtins/aliases/functions, and strips `scripts/non-interactive`, `scripts/interactive`, and `scripts/other` from `PATH` so wrappers in those dirs don't mask the real binary). `command -v` would return scripts in those dirs that mask command names (e.g. `mvn`, `gradle`).

For absolute-path resolution (when you need the path, not just a yes/no): helper `commands::executable_path` from `functions/commands.bash`. Same PATH-stripping as `commands::executable_exists`. No inline `command -v BIN` or `which BIN` — those would return wrappers in `scripts/non-interactive`/`scripts/interactive`/`scripts/other` instead of the real binary.

### Tempfiles

**Overrides** the generic `tmp="$(mktemp)"` rule in `.claude/rules/shell-scripts.md`. Use the `files::create_temp tmp_var_name` helper from `functions/files.bash`. Do NOT install an EXIT trap or otherwise manually `rm` the temp file at end of script. Temporary files created under `/tmp` are managed by the OS (tmpfs reboot wipe + systemd-tmpfiles age-based cleanup), so process-level cleanup adds complexity (EXIT-trap clobbering between multiple temp files, accounting for early exits) without buying anything. Standalone scripts under `misc/` that cannot source `.functions.bash` should call `mktemp` directly and similarly omit any cleanup trap.

### Preserving the executable bit

The `files::create_temp` → edit → `files::move_no_prompt_quiet` idiom **replaces** the destination
file rather than editing it in place, so the destination inherits `mktemp`'s restrictive `0600` mode
and silently loses its executable bit. This has already broken 23 `PATH` scripts once (surfaced
in #168, tracked as #171): every gate — `check-scripts`, `nix flake check`, `./run-tests`, all of
CI — passed on the broken tree.

Any bulk rewrite of top-level scripts must therefore either edit in place (`sed --in-place`) or
re-`chmod +x` afterwards, and must confirm with `git diff --summary` before committing — a stripped
bit shows up there as `mode change 100755 => 100644` and nowhere else in a normal diff.

`.ci/check-executable-bit` now enforces this: shebang-bearing scripts under
`scripts/non-interactive/`, `scripts/interactive/`, `scripts/misc/`, `scripts/other/`, `.ci/`,
`.githooks/`, and the repo root must be executable, and every in-scope `*.bash` / `*.bats` file must
not be. Scripts under `scripts/install/` and `scripts/set_up/` must also be executable unless they
appear in the lint's `GATED` allowlist. Removing the exec bit is still how a script is gated off from
those runners, but the exceptions are now enumerated instead of the directories being skipped — the
blanket skip left 78 of 81 in-scope files unenforced to protect 3 (#173). Each `GATED` entry must
itself exist and be non-executable, so a stale line cannot silently disarm the lint. `scripts/other/`
is included because it is always on `PATH`; the standing "never modify `other/`" rule governs
content, not file mode (#175). A `*.bash` file under `scripts/other/` is held to the
must-be-executable rule rather than the library-file rule — the `scripts/other/` arm is matched
first on purpose, because we impose no naming conventions on third-party content.

### Network retry

Use `retry::with_linear_backoff <max_tries> <base_sleep> <cmd...>` from `functions/retry.bash`. Prefer linear backoff unless there is a specific reason to grow the wait exponentially (in which case use `retry::with_exponential_backoff`). Do NOT hand-roll `until cmd; do ...; sleep N; done` loops.

### File mutation helpers (idempotent)

Helpers in `functions/files.bash` and `functions/symlinks.bash` — `files::write`, `files::append_to`, `files::move`, `files::move_no_prompt`, `files::copy`, `symlinks::link_file`, `symlinks::link_dir`. They implement the standard pattern: `cmp --silent` short-circuit on byte equality, `diff --color --unified ... || true` preview, `prompt::yn` confirmation, and parent-dir auto-creation via `dirs::create "$(dirname "$dest")"`. Variant suffixes:

- `_no_prompt`: skips the diff/confirm step — use for programmatic temp-file-to-destination moves where interactive confirmation would be inappropriate (`files::move_no_prompt`, `files::move_no_prompt_quiet`). Always combine with `_quiet` for temp-to-dest moves: use `files::move_no_prompt_quiet` so the internal move produces no log noise.

- `_quiet`: omits the `log::log` "Moving/Moved", "Copying/Copied", "Writing/Wrote", "Appending/Appended" status messages — use when that output is unwanted noise (`files::move_quiet`, `files::move_no_prompt_quiet`, `files::copy_quiet`, `files::write_quiet`, `files::append_to_quiet`).

Parent-dir auto-creation before writing/moving/copying: helpers `dirs::create "$(dirname "${dest}")"` (or `dirs::root_create` for sudo writes). No inline `mkdir --parents` / `mkdir -p`.

Root-owned destinations: `root_*` variants (`files::root_write`, `files::root_write_quiet`, `files::root_append_to`, `files::root_append_to_quiet`, `files::root_move`, `files::root_move_quiet`, `files::root_copy`, `files::root_copy_quiet`, `dirs::root_create`). When no helper fits, use `sudo test -f`, `sudo cmp`, `sudo cat` for state checks, and `echo "${content}" | sudo tee [--append] "${file}" > '/dev/null'` for the write — no `sudo bash -c 'echo ... > ...'`.

Symlinks: helpers `symlinks::link_file` / `symlinks::link_dir` from `functions/symlinks.bash`. No inline `ln --symbolic` / `ln -s` — the helpers handle the canonical-target short-circuit, diff/prompt confirmation, and parent-dir creation.

### Custom-message exit on command-substitution failure

**Overrides** the generic `|| { echo "msg" >&2; exit 1; }` form in `.claude/rules/shell-scripts.md`. Use `log::die` instead:

```bash
# right — when a custom message is needed
var="$(cmd)" || log::die "cmd failed"
```

The split-declaration rule for `local`/`readonly`/`declare`/`export` still applies — those mask the substitution's exit status, so `local var="$(cmd)" || log::die "..."` never triggers.

### `PATH` modification comment exemption

The generic rule requires a comment on any `PATH` modification. The repo's PATH-related helper functions (`path::append`, `path::prepend`, `path::remove`) are self-documenting — invocations do not need the comment. Direct `PATH=` assignments and `export PATH=...` still do.

### BATS test coverage for helpers

**Every helper function in `functions/*.bash` must have thorough BATS unit tests in `test/functions/<topic>.bats`.** Applies to both new and existing helpers — if you touch or notice an untested helper, the expectation is to add coverage in the same PR (or a follow-up PR explicitly tracked in the description). Tests are spec-driven (encode what the helper *should* do, not what the current implementation happens to do — see the "Testing philosophy" section below). Required coverage per helper:

1. One positive assertion per intended behavior.
1. The standard edge-case sweep — empty input, whitespace-only, single element, multi-element, leading/trailing separators, boundary arg counts.
1. Every arity guard branch (e.g. "dies with 0 args", "dies with 2 args" for a 1-arg helper).
1. Every documented `@exitcode`.
1. For stateful or side-effecting helpers, both the success path and any failure paths (`log::die`, missing dependency, etc.).

When adding a helper to an existing topic file that already has a `.bats` file, extend that file. When adding a new topic file, create the matching `.bats` file in the same PR. The PR is not complete until `./run-tests` is green and coverage matches the bullets above. If a helper genuinely cannot be tested without mocking a side effect that has no existing test-helper for it (sudo, network, package manager), add the helper and the new test-helper together — do not ship the helper untested.

`.ci/check-script-has-test` enforces the same paired-test mandate over **two scopes**: every shebang-bearing executable under `.ci/` needs `test/ci/<name>.bats`, and every executable shell file at the repo root needs `test/root/<name>.bats`. Both scopes carry an `EXEMPT` array with bidirectional stale-entry detection — an entry naming no script, or naming one that *does* have a paired test, fails the lint rather than silently disarming it. The repo-root array ships empty. Both arrays go through `arrays::from_env_override`, so `EXEMPT_OVERRIDE` / `ROOT_EXEMPT_OVERRIDE` let the tests drive them; `test/ci/check-script-has-test.bats` sets both to the empty string in `setup()`, because the shipped defaults name real repo scripts that do not exist in a fixture dir and would otherwise read as stale.

### Process substitution and background commands

The generic ban on `<(...)` and `cmd &` from `.claude/rules/shell-scripts.md` applies here. Project-specific replacements:

- `<(...)` → use `files::create_temp tmp_var` and route the producer to that file (the parent's `pipefail` + `set -e` then catch failures). For the `comm -23 <(arrays::to_lines a) <(arrays::to_lines b)` shape used by `arrays::diff` and friends, keep the helper API but rewrite the implementation to use temp files internally.

- `cmd &` (for GUI launcher detachment) → `misc::exec_gui kate "$@"` (wraps `exec setsid --fork`). Must be the last statement in the calling script (`exec` does not return).

## Testing

Every helper in `functions/*.bash` is exercised under [BATS](https://github.com/bats-core/bats-core); each `functions/<topic>.bash` has a matching `test/functions/<topic>.bats` (or a topic-prefixed group of `.bats` files). BATS itself, plus `bats-support` and `bats-assert`, come from the flake devShell (`bats.withLibraries` in `flake.nix`) — they are no longer vendored as git submodules. `test/test_helper/common.bash` loads the two libraries with `bats_load_library`, which resolves through the `BATS_LIB_PATH` that bats wrapper exports, so a bats that is not the flake's fails loudly at `setup()` instead of silently missing them.

The mandate that every new public helper ships with thorough BATS tests in the same PR is documented under [BATS test coverage for helpers](#bats-test-coverage-for-helpers) above. Private `_`-prefixed internal helpers may be covered indirectly through the public callers that exercise them.

### Layout

```text
test/
  test_helper/
    common.bash               # shared loader; sourced by each .bats setup()
  functions/
    strings.bats              # tests for functions/strings.bash
    args.bats                 # tests for functions/args.bash
    path.bats                 # tests for functions/path.bash
  ci/
    check-executable-bit.bats # tests for .ci/check-executable-bit
  root/
    check-scripts.bats          # tests for the repo-root runner check-scripts
    run-install-scripts.bats    # driven via INSTALL_DIR_OVERRIDE
    run-set-up-scripts.bats     # driven via SET_UP_DIR_OVERRIDE
    run-tests.bats              # driven in a throwaway git repo + recording bats stub
    shellcheck-scripts.bats
```

### Running

Prefix any of these with `./.ci/in-devshell` (or run them from an already-entered direnv
shell); outside the devShell there is no `bats` on `PATH` and `run-tests` says so.

- `./run-tests` — runs everything under `test/functions/`, `test/ci/`, and `test/root/`.

- `./run-tests test/functions/strings.bats` — single file.

- `./run-tests --filter 'is_blank' test/functions/strings.bats` — subset by name.

### Bootstrap on a fresh clone

```bash
git submodule update --init --recursive
```

Still required — but only for `.shdoc`, which is the one remaining submodule. bats,
`bats-support`, and `bats-assert` used to live under `test/` as submodules and now come
from the flake devShell, so what a fresh clone needs for them is `direnv allow` (or
`nix develop`), not a submodule init.

`run-tests` no longer carries a submodule hint. It guards `bats`, `flock`, and `parallel`
by name, and the missing-bats message points at `./.ci/in-devshell ./run-tests` and
`just test`. `flock` gets its own guard because `bats --jobs` dies inside GNU parallel
without it, with a message that says nothing about how this repo is meant to be run.

### Fixture-escape hardening (#248)

A worktree `git push` exports an absolute `GIT_DIR` into hooks; the pre-push gate runs the
BATS suite, so without defenses every fixture `git` command would be retargeted at the real
repo — this happened once (#248: branch rewritten, `commit.gpgsign=false` written into the
shared config). Defenses, all of which must stay:

- `.githooks/pre-push` calls `git::clear_local_env` before running the gate.
- `test/test_helper/common.bash` unsets repo-scoped `GIT_*`, pins
  `GIT_CONFIG_GLOBAL`/`GIT_CONFIG_SYSTEM` to `/dev/null`, sets `GIT_CEILING_DIRECTORIES`,
  asserts `BATS_TEST_TMPDIR` is sane and outside the repo, and `cd`s into it.
- Fixture repos are created and driven via `git_fixture::init` / `git_fixture::run` (from
  `test/test_helper/git_fixture.bash`), which confine every call to `BATS_TEST_TMPDIR` with
  explicit `--git-dir`/`--work-tree`. Raw `git -C` in tests is reserved for probes whose
  subject is git's own discovery behavior.
- `run-tests` snapshots HEAD + config + index around the suite and fails loudly on any change.

### Testing philosophy

Tests are **specification-driven**: each test encodes what the function *should* do based on its name, doc comment, and reasonable invariants — not what the current implementation happens to do. When a test fails, the default response is to fix the function, not the test. Genuinely ambiguous cases get raised before being silently encoded.

### Adding tests

1. Pick a `functions/<name>.bash` file.
1. Create `test/functions/<name>.bats`. **No shebang** — `.bats` files start directly
   with `setup()` (or `bats_require_minimum_version`). All tooling matches them by
   extension, and `check-executable-bit` forbids the exec bit, so a shebang is dead
   metadata; `.ci/check-bats-no-shebang` enforces this (#264).
1. In `setup()`, `load '../test_helper/common'` and `source` the file under test plus any of its dependencies (e.g. `args.bash` for any helper that uses `args::check_*`).
1. Per function: one assertion per intended behavior, plus the standard edge-case sweep — empty input, whitespace-only, single char, multi-line, leading/trailing separators, arg-count boundaries.
1. Run `./run-tests test/functions/<name>.bats` and triage failures: genuine bug → fix the function; ambiguity → escalate; test bug → fix the test.

### Dual-mode helper

Several helpers (`text::*`, `json::sort`, `files::hash`) accept input from EITHER stdin OR a file path. To avoid copy-pasting the test pattern, source `test/test_helper/dual_mode` in `setup()` and use `dual_mode::assert_stdin <fn> <input> <expected>` and `dual_mode::assert_file <fn> <input> <expected>`. The latter writes input to a per-test tmpfile under `${BATS_TEST_TMPDIR}` (BATS auto-cleans). `grep::*` helpers are also dual-mode (1 arg = stdin + pattern; 2 args = file + pattern) but take an extra pattern arg, so the `dual_mode::assert_*` helpers don't fit — test them directly with `run` + heredoc / tmpfile fixtures (see `test/functions/grep.bats` for the `run_stdin_grep` / `run_file_grep` pattern).

For env-file tests (read+write tmpfile fixtures), source `test/test_helper/env_file_fixture` and use `env_file_fixture::create <content> [<basename>]` which writes content to `${BATS_TEST_TMPDIR}/<basename>` (default `env`) and echoes the path.

For tests that need to stub external commands (e.g. `hostname`, fake binaries for `commands::*` tests), source `test/test_helper/path_shim` and use `path_shim::add <name> <body>` to drop an executable shim into a per-test `${BATS_TEST_TMPDIR}/bin` (auto-prepended to `PATH`).

For `os.bats` tests that need to stub `/etc/os-release`, source `test/test_helper/os_release_fixture` and call `os_release_fixture::create KEY=VALUE ...` to write a fixture file under `${BATS_TEST_TMPDIR}`, then `os_release_fixture::install_source_override` to install a shell function override of the `source` builtin that redirects calls to `/etc/os-release` at the fixture. The override is a function (functions take precedence over builtins for unqualified names) and is exported, so it propagates into bash subshells inside `os::release_field`.

For tests that need to record CLI invocations or shim sudo, source `test/test_helper/cli_shim` and use `cli_shim::record <name>` (bare logger), `cli_shim::record_with_output <name> <stdout> [<exit>]` (canned output), `cli_shim::record_stateful <name> <out1> <out2> ...` (Nth output on Nth call; repeats last once exhausted), or `cli_shim::install_passthrough_sudo` (sudo→exec rest with flag stripping). Read back via `cli_shim::calls <name>` / `cli_shim::call_count <name>`.

### Prompt-mocking pattern

Interactive `env_file::prompt_*` tests use a hybrid strategy:

- **Default-accepted path** — set `SCRIPTS_AUTO_ANSWER=y` and supply a default. `misc::auto_answer` short-circuits the `read -rp` and the default is written to the file.

- **Typed-value path** — wrap the call in `bash -c "..."` with stdin fed via `<<<` (use the `prompt_via_stdin` helper in `env_file.bats`). The `read -rp` fires and reads the typed value from stdin.

`passwords::generate` and `passwords::generate_with_symbols` are mocked in `setup()` (and re-declared inside `prompt_via_stdin` since function definitions don't survive `bash -c` boundaries) so password-fn tests are deterministic. Mocks return `MOCK_PASSWORD_64` and `MOCK_PASSWORD_SYMBOLS` respectively.

Note: `read -rp` writes the prompt text to `/dev/tty`, which BATS `run` does not capture. Prompt-text content (var name, info, default substrings shown to the user) cannot be asserted via `assert_output`. Tests verify file mutation only; UI text is not under test.

### `path::*` testing note

`path::remove`, `path::append`, and `path::prepend` mutate the caller's `PATH`. Do NOT wrap them in `run` — `run` executes in a subshell and the mutation is discarded. Set a local `PATH`, call the function directly, then assert on `PATH`. BATS isolates each `@test` in its own subshell, so mutations do not leak between tests.

### Coverage measurement

`.github/actions/coverage` runs `test/functions` under **kcov** and uploads the Cobertura report
to Codecov from `coverage.yml` (push to `main` only). `test/ci/` and `test/root/` are deliberately
unmeasured: they drive `.ci/` and the root runners, not `scripts/functions`, which is the tree the
headline number describes. Facts that are load-bearing, from #307 and #310:

- **kcov replaced bashcov because bashcov's number was noise.** Ruby's `IO.pipe` hands bash a
  non-blocking `BASH_XTRACEFD`; when the Ruby reader lagged, bash's `write()` got `EAGAIN` and
  silently discarded the trace record. About three quarters of the hits were lost, timing-dependent,
  with no error. Three runs on an unchanged tree spread 3.92 points; the same three runs under kcov
  produce byte-identical per-line hits, in ~9 minutes against bashcov's projected ~29 once its pipe
  is fixed. The post-switch baseline was 81.1% (1634 / 2015) against 54.1% through the lossy pipe;
  the current baseline is **96.5% (1944 / 2015)** after #310, #312 and #313 filled the real branch
  gaps and #311 fixed the quote-parsing loss below. **Never diagnose a Codecov delta from before those
  changes by reading the diff.**

- **kcov silently discarded every trace line after a `$'...'` one, and did it with exit 0** (#310).
  `BashEngine::getInputType()` carries single-quote state across trace lines but honours backslash
  escapes only outside a quote. Bash renders any value containing a newline with ANSI-C quoting,
  where `\'` is an escaped quote, so one such line — `printf '%s\n' $'#!/usr/bin/env bash\necho \'x\''` — left the parser latched in `INPUT_SINGLE_QUOTE`, and `checkEvent()` dropped everything
  after it. No diagnostic, no non-zero exit, a well-formed report reading 0%.

  Any test writing a multi-line script through a shell variable tripped it, which is every
  `path_shim::add` call site. It costs 184 lines across seven files — `systemctl.bash` reads 24.1%
  with every branch tested, `downloads.bash` 13%, `docker.bash` 63% — and read even lower before
  #310 and #312 added tests to those files (`packages.bash` was 4.8%). `cli_shim` was unaffected
  only because it writes shim bodies with `cat > file << EOF`, and bash never traces heredoc
  contents — that difference is why some shim-using files looked fine and others did not.

  `.nix/kcov-ansi-c-quoting.patch` fixes it, applied via `patches` on `kcovPatched`. A `*.patch`
  rule in the maintainer's global gitignore hides such files, so the repo `.gitignore` carries an
  explicit `!.nix/*.patch` negation — without it the patch is silently untracked and `nix` refuses
  to evaluate the flake. **A silent 0% is the signature of this class of bug**: if a file's number
  collapses while its tests pass, suspect the harness before the tests.

- **kcov also carries a one-line PS4 fix in `flake.nix`** (`kcovPatched`, separate from the patch
  above and applied via `postPatch` rather than `patches`): its PS4 is
  `kcov@${BASH_SOURCE}@${LINENO}@` with no default, so a `bash -c '… set -u …'` string — which has no
  `BASH_SOURCE` — dies inside PS4 expansion and the test around it fails. Four tests hit this
  (`log.bats`, `shdoc.bats`, `user.bats`). `--bash-method=DEBUG` avoids it but records nothing. The
  `substituteInPlace --replace-fail` fails the build loudly if a kcov bump moves the line; fix the
  patch, never drop it. Every devShell build compiles kcov from source (~1 min, then cached).

- **kcov's RSS grows with trace volume** — about 2.6 MB per test, 4.35 GB peak for the full
  `test/functions` run, all in the `kcov` process. Fine on a 16 GB runner; a leak-shaped ceiling
  around 6000 tests. Worth an eye when the suite doubles.

- **Two lines can never register for environment reasons**, not lexer ones. `args.bash` 145
  (`log::die 'Expected STDIN'`) needs a real TTY on stdin, which neither bats nor CI provides;
  `sdkman.bash` 24 (the must-be-called-from-a-subshell guard) needs `BASHPID == $$`, and bats forks
  every `@test`. Both are covered behaviourally by tests that run in a child process, which the
  harness cannot attribute. Do not try to cover them in-process — it is not possible.

- **Some lines can never be hit, and they set the ceiling.** Roughly 60 of the 71 still-uncovered
  lines are lexer artifacts, not gaps: embedded awk/sed program bodies (`sdkman_jdks.bash` 69–79,
  `shdoc.bash` 53–65/91–94/134–148, `sdkman.bash` 101–110, `git.bash` 174–177), bare subshell `(`
  and `)` lines, every `done <redirect>` line in the tree, and the opening line of a condition or
  command that wraps — kcov attributes a wrapped command to its last line. All 11 `done <redirect>`
  lines score 0 with no exceptions, which is what identifies them as artifacts rather than gaps.
  Do not chase them. That is also why `codecov/patch` is `informational` in `.codecov.yml`;
  `codecov/project` carries a real `auto` target with a 1% threshold.

- **The report is written to `$RUNNER_TEMP`, not into the tree.** kcov drops shebang-bearing
  `bash-helper*.sh` files into its output directory, and `check-scripts` walks the filesystem, so a
  `coverage/` inside the repo hands those to shfmt and shellcheck. Reproduce locally the same way:

  ```bash
  ./.ci/in-devshell bash -c 'kcov --bash-parser="$(type -P bash)" --bash-dont-parse-binary-dir \
    --include-path="$PWD/scripts/functions" --bash-parse-files-in-dir="$PWD/scripts/functions" \
    /tmp/kcov-out bats --recursive test/functions'
  ```

  `--bash-parse-files-in-dir` is what keeps never-executed files in the denominator at 0% instead of
  dropping them; `--bash-parser` pins the parser to the devShell's bash rather than `/bin/bash`.

- **Denominators are lexer opinions on both sides.** bashcov counted `fi`, `esac`, `function … {`
  and blank lines; kcov counts subshell parens and `local arr=()`. Neither is ground truth, so a
  per-file line count is not comparable across the switch.

## Before Committing

The gate is two steps: `nix fmt` (format every file via treefmt), then `./.ci/in-devshell ./run-all-checks` (the full gate, hermetically). Both must be clean. `nix fmt` deliberately stays outside the wrapper — it is a nix invocation, not repo tooling running under the devShell, so wrapping it is circular. See [Gates run inside the hermetic devShell](#gates-run-inside-the-hermetic-devshell).

`./run-all-checks` is the single definition of the local gate. It runs, in order:

1. `./check-scripts` — shfmt verify, shellcheck, the shdoc-header audit, the executable-bit audit
1. `nix flake check` — the formatting gate plus the flake's checks
1. `.ci/run-governance-checks` — workflow posture, Renovate config, branch ruleset
1. `.ci/run-lint-checks` — actionlint, yamllint, JSON schema, markdownlint, typos, editorconfig-checker
1. `./run-tests` — the BATS suite (slowest, so it runs last)

It **aggregates exit codes rather than failing fast**, so one run surfaces every failing category instead of only the first. The alternative makes you rediscover the next failure on each rerun, at roughly 90s a round trip.

It is **verify-only** — it never rewrites the tree. That is why `nix fmt` stays a separate step run before it: a gate that reformats the thing it is about to approve is not a gate, and the pre-push hook must never mutate the tree it is pushing.

`nix flake check` evaluates the **tracked git tree**, so it cannot see untracked files — a badly formatted new file passes vacuously until it is staged (#217). `./run-all-checks` therefore **warns** (never fails) when the working tree holds untracked, non-ignored files. Staging is what exposes a new file to the formatting gate, so `git add` before trusting a green run. Warning rather than failing is deliberate: hard-failing would block the gate on scratch files and work in progress.

`./check-scripts` and `./shellcheck-scripts` accept optional file/dir arguments — pass only the changed files for a faster inner loop, then run the whole gate argument-free before committing.

The tracked hooks under `.githooks/` activate **automatically**: the flake devShell's `shellHook` invokes `.ci/activate-githooks`, which points `core.hooksPath` at `.githooks`. `direnv allow` / `nix develop` is all that is required — there is no manual `git config --local core.hooksPath` step, and this section used to document one. Because repo-local config cannot be committed, that manual step silently never happened and both tracked hooks sat inert (#212). Activation is idempotent and silent once the value is correct; a foreign `core.hooksPath` is overwritten and logged.

`.githooks/pre-push` runs `./.ci/in-devshell ./run-all-checks` — the same gate, hermetically, including the BATS suite — so local and push-time verification cannot drift apart. It previously ran a hand-maintained four-step list that omitted the tests, which is exactly the drift the single runner exists to prevent. Bypass with `git push --no-verify`.

## Changed-Path Test Gating

`.github/actions/changed-tests` decides whether the `bats` and `coverage` jobs run
on a pull request. The decision logic lives in `.ci/decide-changed-tests` — a pure
function of a changed-path list — so it is unit-tested in
`test/ci/decide-changed-tests.bats` rather than buried in a YAML `run:` block.

**The matcher is a denylist, and inverting it back to an allowlist is a
regression.** A path runs the suite unless it matches one of the `IRRELEVANT`
globs. An allowlist skips every path nobody thought to enumerate, which is exactly
how a `.ci/`-only PR came to skip `test/ci/` while still reporting green (#207).
Wasted CI minutes are recoverable; an undetected regression on `main` is not.

`.editorconfig` is deliberately **not** in the irrelevant set: shfmt reads its
formatting style from that file, so a change to it is test-relevant. `*.md` is
safe only because `check-links-allowed-endpoints.bats` runs against fixture trees
via `MARKDOWN_ROOT_OVERRIDE`, never against real repo markdown — if that ever
changes, `*.md` must come out of the set.

## Merging PRs

- Merge commit is the only allowed merge method on this repo. Rebase and squash are disabled in repo settings and in the `protect-main` ruleset (`allowed_merge_methods: ["merge"]`). The `main` branch does NOT enforce linear history — merge commits are intentionally allowed.
- The PR title becomes the merge-commit subject (`merge_commit_title=PR_TITLE`), so the PR title must satisfy Conventional Commits — enforced by the `pr-title-lint` workflow. The PR body becomes the merge-commit message (`merge_commit_message=PR_BODY`).
- Every commit on a feature branch still lands verbatim under the merge commit and is independently linted by the `commitlint` workflow, so each commit must satisfy Conventional Commits (`type: subject`) on its own.
- Before merging, clean the branch with `git rebase --interactive` so WIP / "fix review" / typo commits do not leak onto `main` under the merge commit.
- All commits must be signed — the ruleset enforces `required_signatures`.
- The ruleset carries no bypass actors (`bypass_actors: []`): there is no admin override. A red required check blocks the merge for everyone, including the owner.

## GitHub Actions Egress Posture

Every job in every workflow runs `step-security/harden-runner` with `egress-policy: block` and an
explicit `allowed-endpoints` list. Audit mode only logs egress; block mode is what actually contains a
compromised dependency.

- **The mandate is enforced.** `.ci/check-harden-runner-egress` fails any job that omits
  `egress-policy: block` or ships a blank `allowed-endpoints`. Its `EXEMPT` array is deliberately empty,
  so a new workflow fails the governance gate until it declares a list. `.ci/check-harden-runner-first`
  separately requires harden-runner to be the job's first step.

- **`allowed-endpoints` must be a `>-` folded scalar on a single space-separated line.** Two independent
  reasons: treefmt's yamlfmt collapses a multi-line folded scalar back onto one line, so a hand-wrapped
  list does not survive formatting; and harden-runner splits the value on spaces only, so a `|-` literal
  block is parsed as **one giant endpoint** and every host but the first is silently dropped. A `|-`
  block is worse than a syntax error — it looks correct and disarms the policy.

- **`.yamllint.yml` sets `line-length.max: 600`** as a direct consequence of the rule above. Do not
  lower it to "fix" a long endpoint line.

- **Deriving a list.** Set `block`, run the job, then read the blocked hosts out of the harden-runner
  **Post Run** step:

  ```bash
  gh run view --job "${JOB_ID}" --log | grep -E 'domain not allowed: [^[:space:]]+'
  ```

  The host is printed with a trailing dot. Strip it and append `:443`.

- **A blocked call is a silent packet drop.** It does not fail the step, emits no annotation, and
  produces no warning — the calling command just reports a connection error, or worse, degrades
  quietly. **A green job may still have had calls blocked.** Two consequences: always harvest from
  green runs rather than waiting for a red one, and verify a job's real work actually happened
  (artifact uploaded, check published, cache saved) instead of trusting its conclusion.

- **Some hosts are only observable on a cold Nix cache.** `tarballs.nixos.org` is reached only when
  the devShell is rebuilt. Delete the `nix-Linux-*` caches and force one cold round before trusting a
  Nix job's list. (`rubygems.org` used to sit beside it for the bashcov bundlerEnv; that env is gone,
  and the host with it.)

- **Prefer exact hosts over wildcards.** A wildcard entry permits every subdomain. Use one only when the
  host name genuinely rotates between runs (for example an Azure storage-account number), and then
  narrow it as far as the observed family allows and comment why.
  `hosted-compute-*.githubapp.com:443` is the sanctioned instance of this: GitHub's own runner
  watchdog and request-orchestrator hosts carry a per-run region/index suffix (`eus-01`,
  `iad-02`, …), so no exact host exists to prefer (#201).
  **Every job that installs Nix carries this wildcard**, which is the rule to apply when adding a
  workflow — not a fixed list to copy. Today that is nine: `check-scripts`, `bats`, `lint`,
  `governance`, `nix-flake-check`, `coverage`, plus `pages`' build job, `pr-title-lint`, and
  `protect-main-drift-check`. The last three were missed when the wildcard first landed and were
  added in #301; `pr-title-lint` had been logging `domain not allowed` for both hosts on every
  green run, which is precisely how silent this failure mode is. `reviewdog` and `commitlint` are
  deliberately out — they carry different allowlists and neither installs Nix, so neither reaches
  the runner watchdog/orchestrator hosts this wildcard exists for. `pages`' `deploy` job is out for
  the same reason.
  The intra-label form is **proven**, not assumed: before the change the Post Run step logged
  `domain not allowed: hosted-compute-watchdog-prod-eus-02.githubapp.com.`, and after it the same
  host logs as `domain resolved`. harden-runner honors a `*` in the middle of a label, so the
  broader `*.githubapp.com` was not needed.

- **`keybase.io:443` in `coverage.yml` is load-bearing — never prune it.** `codecov-action` fetches the
  Codecov signing key from keybase.io to verify the CLI it just downloaded. The fetch uses a bare
  `curl -s` inside a command substitution, so a blocked request yields an empty key rather than an
  error; `gpg --verify` then fails, and with `fail_ci_if_error: false` the script's `exit_if_error`
  merely prints and returns, falling through to run the unverified binary (#199). The entry looks
  unused because nothing in the workflow names it — it is the least obviously necessary and
  highest-value host in that allowlist.

- **Codecov's Sentry telemetry host is blocked deliberately.** `o26192.ingest.us.sentry.io` is crash
  reporting, not part of the upload path. It is recorded here so a future allowlist harvest does not
  relitigate it.

- **`links.yml` carries a second, stricter gate.** `.ci/check-links-allowed-endpoints` requires every
  host linked from tracked markdown to appear in that workflow's allowlist. The comparison is one-way:
  extra entries are fine, missing ones fail. Adding an external link to any tracked markdown file —
  including this one — means adding its host there.

### Renovate action bumps can break an allowlist

A third-party action version bump can change that action's upstream hosts, turning an otherwise routine
Renovate PR red. This is the intended failure mode: loud, with a one-line fix.

When a version-bump PR fails and the error is a connection failure rather than a real test failure,
suspect the allowlist first and read the harden-runner Post Run step for `domain not allowed:` lines.

Worked example: GitHub moved release-asset downloads from `objects.githubusercontent.com` to
`release-assets.githubusercontent.com`. Four jobs download a release binary — reviewdog, gitleaks,
lychee, and shfmt — so all four broke at once and all four needed the new host added.
