# Shell Script Rules

Generic, project-agnostic rules for writing bash scripts. Portable to any shell project.

> Project-specific rules may override anything in this file — see `CLAUDE.md` in the project root for overrides.

## File basics

- Use `#!/usr/bin/env bash`

- New scripts must be created executable (`chmod +x`)

- Indent with 2 spaces; never tabs

- Maximum line length is 120 characters. Wrap long lines via continuation, here-docs, or shorter expressions. Exempt: lines whose excess length comes from a single unbreakable string literal — URLs, file paths, embedded regex/awk/sed programs, multi-arg single-string command invocations. Multi-token or pipeline lines must still wrap.

## Strict mode and error handling

- Use `set -Eeuo pipefail` (the `-E` is required so the `ERR` trap inherits into shell functions and command substitutions)

- Set strict IFS alongside the strict-mode pragma: `IFS=$'\n\t'` immediately after `set -Eeuo pipefail`

- Use `set -E` and an `ERR` trap for stack-trace-style error reporting in non-trivial scripts:

  ```bash
  set -Eeuo pipefail
  trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR
  ```

- When sourcing or calling code from an external tool (e.g. SDKMAN, NVM, RVM), that code may use non-zero exit status for non-error conditions (e.g. `grep` returning 1 for "no match"), which fires false ERR trap hits, and may also reference unbound variables. Wrap the external block in a subshell with `set +u` and `trap - ERR` inside. The subshell is preferred over bracketing with restore lines because the parent's strict mode is never touched — both `set -u` and the ERR trap (inherited via `-E`) are reset automatically when the subshell exits:

  ```bash
  # Subshell isolates set +u and trap - ERR so parent strict mode is never touched.
  # Both are needed: set -u and ERR trap (via -E) are inherited by subshells.
  (
    set +u
    trap - ERR

    # shellcheck disable=SC1091
    source "/path/to/external-init.sh"
    external_tool_command
  )
  ```

- Pin minimum bash version when using bash 4+ features (associative arrays, `mapfile`, `${var^^}`, etc.):

  ```bash
  if (( BASH_VERSINFO[0] < 4 )); then
    echo 'bash 4+ required' >&2
    exit 1
  fi
  ```

- All error messages must be written to stderr.

## Syntax

- Use `[[ ]]` over `[ ]`

- Use `(( ))` for arithmetic; never `let` or `expr`

- Use `$(...)` not backticks

- Use `source` instead of `.` when sourcing a file. The `source` keyword is more readable and unambiguous (a leading `.` is easy to overlook).

- Use long options in commands (e.g., `cut --delimiter` not `cut -d`). When a tool has no long-form equivalent for the flag (e.g. `find -L`, `tailscale ip -4`), the short flag is allowed — but every such use must carry a same-line comment justifying it: `# no long-form equivalent`.

- Never define aliases in scripts. Use shell functions instead (aliases are inert in non-interactive shells anyway).

- Avoid `eval`; if needed, justify with comment.

- In `[[ ]]`, prefer `==` over `=` for equality.

- Never use `<` or `>` inside `[[ ]]` for numeric comparison (those are lexicographic). Use `(( a < b ))` or `[[ a -lt b ]]` instead.

- Inside `$(( … ))`, omit the `${}` braces — the shell auto-resolves bare variable names: `$(( count + 1 ))` not `$(( ${count} + 1 ))`.

- Avoid bare `(( expr ))` as a standalone statement when the expression can evaluate to zero — under `set -e`, an exit status of 1 from the arithmetic kills the script. Use `(( expr )) || true` (with a same-line comment), `: $(( expr ))` for side effects only, or capture the value with `result=$(( expr ))`.

## Quoting and variable expansion

- Quote all variable expansions: `"${var}"` not `$var`

- Use `${var}` brace syntax for all variables EXCEPT single-character shell specials and positional parameters (`$?`, `$#`, `$$`, `$!`, `$@`, `$*`, `$1`–`$9`) — leave those unbraced. Positionals `${10}` and above still require braces. The integer specials (`$?`, `$#`, `$$`, `$!`) are also exempt from the "quote everything" rule — quoting is optional since they cannot contain whitespace or globs.

- Quote command substitutions: `"$(cmd)"`

- Single-quote string literals when no expansion is needed: `'/dev/null'`, `'/etc/os-release'`, `'y'`. Reserve double quotes for expansion.

- Do not quote numeric option arguments: `--fields=1`, `--max-args=1` (not `--fields='1'`)

- Test for empty/non-empty strings with `[[ -z "$x" ]]` / `[[ -n "$x" ]]` rather than `[[ "$x" == "" ]]` / `[[ "$x" != "" ]]`.

## Variables and constants

- Constants and config: `readonly` and `UPPER_SNAKE_CASE` at top of script

- Top-level scripts with named positional args must bind each `$1`/`$2`/etc. to a `readonly` `UPPER_SNAKE_CASE` constant immediately after arg-count validation, then reference the named constant thereafter — never use `$1`/`$2`/etc. inline in the script body. Improves readability and self-documents intent. Exemptions: pass-through scripts forwarding `"$@"` verbatim; variadic scripts that only iterate `"$@"` (loop variable provides the name); single-use of `$1` on the first executable line where binding adds noise without readability gain (author's call).

  ```bash
  # wrong — bare positionals scattered through script body
  cp --archive -- "$1" "$2"
  log_info "$1 -> $2"

  # right — bind once, name everywhere
  readonly SRC="$1"
  readonly DEST="$2"
  cp --archive -- "${SRC}" "${DEST}"
  log_info "${SRC} -> ${DEST}"
  ```

- Locals: `local` (or `local -r` for read-only) inside every function. Use `snake_case` (lowercase) for local and other non-constant variables; reserve `UPPER_SNAKE_CASE` for constants, exported vars, and environment vars.

- Apply `${VAR:-}` defaults only to optional positional args (`"${2:-}"`) — required positionals are already validated by arg-count guards, so let `set -u` catch programming mistakes there.

- Default safely under `set -u`: use `"${VAR:-default}"` for vars that may legitimately be unset; do NOT add defaults for well-known env vars expected to always be present (`HOME`, `USER`, `SDKMAN_DIR`, `PATH`, etc.) — let `set -u` catch them if missing.

- When parsing decimal strings that may have leading zeros (e.g. `date +%H` → `09`), use `10#` in arithmetic context (`$((10#${var}))`) or strip via `%-H`/`%-M` with GNU date — bash arithmetic treats `08`/`09` as invalid octal.

- Force-decimal numbers from external commands before arithmetic comparison.

- When using command substitution to assign a `local`, declare and assign on separate lines so the command's exit status is observable (`local` always returns 0 and masks the substitution's exit status):

  ```bash
  # wrong — masks cmd's exit status
  local result="$(cmd)"

  # right
  local result
  result="$(cmd)"
  ```

- Never append `|| exit 1` (or `|| exit N`) to a plain command-substitution assignment: `var="$(cmd)" || exit 1` is redundant under the mandatory `set -Eeuo pipefail` and short-circuits the `ERR` trap, which would otherwise print the failing line and command. Write `var="$(cmd)"` and let strict mode + the trap handle failure. For an explicit user-visible failure with a custom message, use `|| { echo "msg" >&2; exit 1; }`:

  ```bash
  # wrong — redundant, suppresses ERR trap context
  var="$(cmd)" || exit 1

  # right — let strict mode + ERR trap handle it
  var="$(cmd)"
  ```

  For `local`/`readonly`/`declare`/`export`, the split-declaration rule above applies — `local var="$(cmd)" || exit 1` never triggers because the builtin masks the substitution's exit status.

## Functions

- Functions: `snake_case`, defined with `function name() { ... }` (always use `function` keyword)

- Library functions should be namespaced with `::` (e.g. `files::exists`, `log::info`); internal/private helpers may keep plain `snake_case`.

- Functions with named positional parameters must bind each `$1`/`$2`/etc. to a `local` (or `local -r`) variable on the first lines of the function body, then reference the named variable thereafter — never use `$1`/`$2`/etc. inline in the function body. The `local` name should match the `# @arg $1 description` doc comment above the function. Exemptions: variadic functions iterating `"$@"`; pass-through functions forwarding `"$@"` verbatim; single-use of `$1` on the first executable line where binding adds noise without readability gain (author's call).

  ```bash
  # wrong — bare positionals scattered through body
  function copy_file() {
    cp --archive -- "$1" "$2"
    log_info "$1 -> $2"
  }

  # right — bind once, name everywhere
  # @description Copy a file from src to dest, preserving attributes.
  # @arg $1 src path to source file
  # @arg $2 dest path to destination
  function copy_file() {
    local -r src="$1"
    local -r dest="$2"
    cp --archive -- "${src}" "${dest}"
    log_info "${src} -> ${dest}"
  }
  ```

- Document positional parameters above each function with shdoc-style `# @arg $1 description` comments (use `# @arg $@ description` for varargs). Add `# @description ...` above the function for the prose summary; add `# @noargs` for argument-less functions; use `# @stdout`, `# @stderr`, and `# @exitcode N meaning` where useful.

- Document non-trivial functions with a comment block above the definition: description, globals used or modified, arguments, outputs (stdout/stderr), and return value semantics. Library functions always require this; small internal helpers may be lighter.

- Predicate functions (`is_*`, `*_exists`, etc.) end with a `[[ ... ]]` test or command whose exit status is the result — do not write explicit `return 0` / `return 1`.

## Control flow

- Control flow opener: `; then` and `; do` on the same line as `if`/`while`/`for`. `else` on its own line. `fi`/`done` on their own line, aligned with the opener.

- Use `case ... in PATTERN) ;; *) ;; esac` instead of chained `[[ ]]` / `elif` when matching one variable against multiple string patterns

- `case` statement formatting: indent each alternative 2 spaces; multi-line alternatives put the pattern, the actions, and the closing `;;` on separate lines. Never use `;&` or `;;&` (fall-through) — write explicit cases instead.

- Iterate command output by routing it through a temp file first; never `for x in $(cmd)` and never `mapfile -t arr < <(cmd)` (process substitution is banned — see Concurrency):

  ```bash
  tmp="$(mktemp)"
  cmd > "${tmp}"
  mapfile -t arr < "${tmp}"
  for item in "${arr[@]}"; do
    ...
  done
  ```

- Iterate positional parameters explicitly: `for x in "$@"; do ...; done`, not the implicit `for x; do ...; done` (clearer at a glance what is being iterated)

- Name loop variables after the items being iterated: `for file in "${files[@]}"` not `for x in "${files[@]}"`.

- Never pipe into `while`: the loop runs in a subshell, so any variable assignments inside are lost. Route the producer through a temp file and read from the file:

  ```bash
  tmp="$(mktemp)"
  cmd > "${tmp}"
  while read -r line; do
    ...
  done < "${tmp}"
  ```

- Use `"$@"` to forward positional parameters; reach for `$*` only when you specifically need a single concatenated string.

## Arrays

- Use bash arrays for lists of elements or command-line flags to avoid quoting complications. Always expand with `"${array[@]}"` (quoted, `@` not `*`). Do not use arrays for complex data structures — bash arrays are not the right tool.

## I/O

- Use `printf '%s\n' "$x"` over `echo "$x"` when `$x` could start with `-` or contain backslashes

- Use `printf` (with explicit format string, including ANSI escapes like `'\033[0;32m%s\033[0m\n'` when colorizing) for any non-trivial output; never `echo -e`

- Heredocs: quote the terminator when no expansion wanted: `<<'EOF'`

- Always use `read -r` (or `read -rp PROMPT`); never bare `read` (matches ShellCheck SC2162 — `-r` prevents backslash mangling)

## Logging

- Standardize logging via helpers, all writing to stderr with timestamp + level prefix:

  ```bash
  log()      { printf '[%s] %-5s %s\n' "$(date '+%Y-%m-%dT%H:%M:%S%z')" "$1" "$2" >&2; }
  log_info() { log INFO  "$*"; }
  log_warn() { log WARN  "$*"; }
  log_err()  { log ERROR "$*"; }
  ```

## Files, paths, and globs

- Use `--` before user-supplied paths in destructive commands (`rm --force --`, `mv --`)

- Use `./*` rather than `*` when feeding glob results to commands so filenames beginning with `-` aren't treated as options.

- Never parse `ls` output; use globs or `find`

- Use `find -printf '<fmt>'` for structured output (e.g. `find . -printf '%u:%g\n'`) instead of parsing default `find` output

- Use `stat --format='<fmt>'` for file metadata. For non-integer arithmetic, pipe through `bc` (bash `(( ))` is integer-only): `echo "scale=2; $(stat --format='%s' "${f}") / 1073741824" | bc`

- Read values from `/etc/os-release` by sourcing it in a subshell, not by `grep`/`sed`/`awk`. The file is spec-defined as shell-sourceable, handles quoted values correctly, and exposes every field at once. Use a subshell so the sourced variables don't leak:

  ```bash
  # shellcheck disable=SC1091
  ( source '/etc/os-release' && printf '%s\n' "${ID}" )
  ```

- Always check `cd` results: `cd "${dir}" || exit 1`. Prefer scoped subshells over `pushd`/`popd`: `(cd "${dir}" && do_thing)`

- Tempfiles: `tmp="$(mktemp)"`

## PATH

- Scope `PATH` mutations inside a `( ... )` subshell so changes don't leak to the caller's environment.

- Any script that modifies `PATH` must include a comment explaining why. Applies to direct assignments and `export PATH=...`. Helper functions whose explicit purpose is PATH manipulation are exempt — calling them is self-documenting.

## External tools

- Tool availability: check with `command -v tool >/dev/null 2>&1`, never `which`

- For non-interactive `curl`, use: `curl --disable --fail --silent --location --show-error`. `--disable` skips `~/.curlrc` so behavior doesn't depend on the invoking user's config

- For non-interactive `wget`, use: `wget --no-config` (skips `~/.wgetrc` for the same reason)

- Always pass `--no-run-if-empty` and an explicit `--max-args=N` to `xargs`

- Prefer shell builtins, parameter expansion, and `=~` over external tools when they can do the job (`${var//pat/rep}` over `sed`, `${var%suffix}` over `cut`, `[[ "$s" =~ ^[0-9]+$ ]]` over `grep`). External commands are fine when the builtin form is unreadable.

## Pipelines

- Pipeline formatting: a pipeline that fits on one line stays on one line. When wrapping, put one segment per line with the `|` at the start of the continuation line, indented 2 spaces from the opening command.

- When suppressing pipefail in one spot: explicit `|| true` with comment, not blanket disable

- For pipelines whose per-stage exit codes matter, capture `PIPESTATUS` into a variable on the very next line — any subsequent command overwrites it:

  ```bash
  cmd_a | cmd_b | cmd_c
  status=( "${PIPESTATUS[@]}" )
  ```

## Concurrency

- **Process substitution `<(...)` is banned.** Process substitution runs the producer in a child process whose exit status is not visible to the parent — `set -e`, `pipefail`, and the `ERR` trap all operate inside that severed child. A failing producer silently leaves the consumer with empty input, and the parent script keeps running with partial state. Use a temp file instead (common consumers: `mapfile`, `comm`, `diff`, `paste`, `join`, `while read`):

  ```bash
  # wrong
  mapfile -t lines < <(producer | sort)

  # right
  tmp="$(mktemp)"
  producer | sort > "${tmp}"
  mapfile -t lines < "${tmp}"
  ```

  No exceptions. For `while read -r ...; do ...; done` loops, the same temp-file pattern replaces both the banned `< <(cmd)` form and the subshell-trap `cmd | while read ...` form (see "Never pipe into `while`" under Control flow).

- **Backgrounded commands `cmd &` are banned.** Background jobs sever exit-status propagation in the same way process substitution does (the parent never observes failure unless it `wait`s, and `set -e` cannot help). For the common case of detaching a GUI launcher from the terminal so the shell prompt returns immediately, use `exec setsid --fork`:

  ```bash
  # wrong
  kate "$@" > '/dev/null' 2>&1 &
  disown

  # right (must be the last statement in the calling script — exec does not return)
  exec setsid --fork kate "$@" > '/dev/null' 2>&1
  ```

  The bitwise-AND operator inside `(( ))` (e.g. `(( x & 0xff ))`) is unaffected by this rule — only standalone `cmd &` (and `cmd & disown`) is banned.

## Security

- SUID and SGID are forbidden on shell scripts. Use `sudo` to grant elevated access instead.

## File layout

- File layout: only the shebang, strict-mode pragma, IFS, sourced libraries / `set` options, and constants appear before function definitions. All functions are grouped together below constants. No executable code is interleaved between function definitions.

- `main` function: top-level scripts containing one or more helper functions must wrap entry logic in `function main() { ... }`, defined as the last function. The final non-comment line of the script must be `main "$@"`. Scripts with zero helper functions may use straight-line code with no `main`. Library files (sourced helpers) are exempt. Keep arg-count guards and any `getopt` option parsing whose results modify `$@` at top-level above the `main` call — `main` should receive already-validated, already-parsed args.

## Comments

- Comment tricky, non-obvious, or important code sections; explain *why*, not *what*.

- Use `TODO:` (all caps, no author identifier) to mark deferred work.

## Quality gates

- All shell scripts must pass `shellcheck` before being considered complete

- Format shell scripts with: `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --write <files>`

- Verify formatting (no in-place changes) with: `shfmt --list --indent 2 --case-indent --binary-next-line --space-redirects --diff <files>`

- All shell scripts must pass the verify command above before being considered complete

- Use `# shellcheck disable=SCxxxx` only with a same-line comment justifying why

## Consistency

- Consistency tiebreaker: when picking between equivalent options, match the existing patterns in surrounding code rather than introducing a third variant. But "we've always done it this way" is not a reason to keep an outdated style when the rule book has changed — apply current rules to new code.
