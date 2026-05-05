- Claude MUST use the helper functions in `functions/*.bash` whenever an applicable helper exists. Do not write inline equivalents for operations that already have a helper (file mutation, prompts, OS detection, downloads, path manipulation, logging, arg-count guards, executable existence, symlinks, etc.). Before writing inline shell, scan `functions/*.bash` for a matching helper.
- Claude may propose new helper functions when a piece of logic looks reusable across scripts, even if it is currently only needed in one place. Suggest the new helper (with proposed file and signature) rather than silently inlining.
- `set -Eeuo pipefail` is mandatory at the top of every top-level script (not in library files under `functions/`). The `-E` is required so the `ERR` trap inherits into shell functions and command substitutions.
- `IFS=$'\n\t'` is mandatory immediately after the strict-mode pragma. Library files in `functions/` do NOT set it (strict mode and IFS are owned by the parent script).
- `[[ ]]` over `[ ]`, long CLI options, quoted `"${var}"` everywhere — enforced by shellcheck.
- Scripts under `set_up/` must be idempotent and self-gate — check current state before mutating, and exit cleanly when there is nothing to do.
- Standard top-level skeleton — source the function library, enable the `ERR` trap, then guard arg count:

  ```bash
  #!/usr/bin/env bash

  set -Eeuo pipefail
  IFS=$'\n\t'

  #shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions.bash"
  enable_err_trap
  check_no_args "$@"   # or check_exactly_N_args / check_at_least_N_args / check_at_most_N_args
  ```

- `enable_err_trap` (from `functions/log.bash`) installs an `ERR` trap that prints a red, prefixed `ERROR: line N (exit C): cmd` line to stderr when any unhandled command fails under `set -e`. Call it once, immediately after sourcing `functions.bash`. It complements `die` (explicit user-visible failures) — the trap catches everything else.
- Standalone scripts that do NOT source this repo's `functions.bash` (everything in `misc/`) cannot call `enable_err_trap`. Inline the trap directly after the `IFS=` line. (Note: scripts that source `${DOCKER_COMPOSE_DIR}/functions.bash` DO have access to this repo's helpers — that file transitively sources `${SCRIPTS_DIR}/functions.bash` — so use `enable_err_trap` there, not the inline form.)

  ```bash
  trap 'printf "\033[0;31m[%s %s] ERROR: line %s (exit %s): %s\033[0m\n" "$(date +%T)" "${0##*/}" "${LINENO}" "$?" "${BASH_COMMAND}" >&2' ERR
  ```

- Library files under `functions/` get only the shebang — do NOT add `set -euo pipefail` or source `functions.bash`. Strict mode is owned by the parent script that sources them.
- Create new scripts via `main/new-script <path>` (handles header + exec bit).
- Document positional parameters above each function with `# $1 = description` comments (use `# $@ = ...` for varargs).
- Predicate functions (`is_*`, `*_exists`, etc.) end with a `[[ ... ]]` test or command whose exit status is the result — do not write explicit `return 0` / `return 1`.
- Library functions in `functions/*.bash` use the same `check_*_args "$@"` guards as top-level scripts (not only top-level scripts get them).
- Logging/erroring helpers from `functions/log.bash` (all color-coded, written to stderr, prefixed with `${0##*/}`): `log` (green, info-level), `log_with_date` (green, info-level with full date), `log_warn` (yellow, warn-level — use for non-fatal problems), `die` (red, error-level + `exit 1` with caller context). There is no separate `log_info` (use `log`) or `log_err` (use `die` if fatal, or `log_warn` if not).
- `die` includes caller context via `${BASH_SOURCE[1]}:${FUNCNAME[1]}:${BASH_LINENO[0]}` — preserve this when modifying the helper.
- Stdin presence: helpers `check_for_stdin` / `stdin_exists` from `functions/args.bash`. No inline `[[ -t 0 ]]`.
- Existence checks: helpers `file_exists` / `assert_file_exists` (`functions/files.bash`), `dir_exists` / `assert_dir_exists` (`functions/dirs.bash`), `symlink_exists` (`functions/symlinks.bash`). Use the `assert_*` variants for entry-point validation (they call `die` with a consistent message); use the bare predicates for branching. No inline `[[ -f X ]]` + manual `die` rolls.
- Interactive prompts: helpers `prompt_yn` / `prompt_ny` / `prompt_for_value` from `functions/prompt.bash`. Fall back to inline `read -rp $'\e[0;33mPrompt: \e[0m'` (colored `$'...'` form) only when no helper fits, and document why with a comment.
- Executable-on-`PATH` check: helper `executable_exists` from `functions/commands.bash` (uses `type -aPf`, excludes builtins/aliases/functions, and strips `main/` and `other/` from `PATH` so wrappers in those dirs don't mask the real binary). Overrides the global rule's `command -v` recommendation for this repo — `command -v` would return scripts in `main/` that mask command names (e.g. `mvn`, `gradle`).
- Executable-path resolution (when you need the absolute path, not just a yes/no): helper `executable_path` from `functions/commands.bash`. Same PATH-stripping as `executable_exists`. No inline `command -v BIN` or `which BIN` — those would return wrappers in `main/`/`other/` instead of the real binary.
- Idempotent file mutation (write/move/copy/link/append): helpers in `functions/files.bash` and `functions/symlinks.bash` — `write_file`, `append_to_file`, `move_file`, `copy_file`, `link_file`, `link_dir`. They implement the standard pattern: `cmp --silent` short-circuit on byte equality, `diff --color --unified ... || true` preview, `prompt_yn` confirmation, and parent-dir auto-creation via `create_dir "$(dirname "$dest")"`.
- Parent-dir auto-creation before writing/moving/copying: helpers `create_dir "$(dirname "${dest}")"` (or `root_create_dir` for sudo writes). No inline `mkdir --parents` / `mkdir -p`.
- Root-owned destinations: `root_*` variants (`root_write_file`, `root_append_to_file`, `root_move_file`, `root_copy_file`, `root_create_dir`). When no helper fits, use `sudo test -f`, `sudo cmp`, `sudo cat` for state checks, and `echo "${content}" | sudo tee [--append] "${file}" > '/dev/null'` for the write — no `sudo bash -c 'echo ... > ...'`.
- Symlinks: helpers `link_file` / `link_dir` from `functions/symlinks.bash`. No inline `ln --symbolic` / `ln -s` — the helpers handle the canonical-target short-circuit, diff/prompt confirmation, and parent-dir creation.
- Read values from `/etc/os-release` by sourcing it in a subshell, not by `grep`/`sed`/`awk`. The file is spec-defined as shell-sourceable, handles quoted values correctly, and exposes every field at once:

  ```bash
  # shellcheck disable=SC1091
  ( source '/etc/os-release' && printf '%s\n' "${ID}" )
  ```

  Use a subshell so the sourced variables don't leak.
- Use `find -printf '<fmt>'` for structured output (e.g. `find . -printf '%u:%g\n'`) instead of parsing default `find` output.
- Use `stat --format='<fmt>'` for file metadata. For non-integer arithmetic, pipe through `bc` (bash `(( ))` is integer-only): `echo "scale=2; $(stat --format='%s' "${f}") / 1073741824" | bc`.
- New scripts must be created executable (`chmod +x`). `main/new-script` already does this — prefer it over hand-creating files.
- Use `#!/usr/bin/env bash`
- Use `(( ))` for arithmetic; never `let` or `expr`
- Use `${var}` brace syntax for all variables EXCEPT single-character shell specials and positional parameters (`$?`, `$#`, `$$`, `$!`, `$@`, `$*`, `$1`–`$9`) — leave those unbraced. Positionals `${10}` and above still require braces.
- Quote command substitutions: `"$(cmd)"`
- Single-quote string literals when no expansion is needed: `'/dev/null'`, `'/etc/os-release'`, `'y'`. Reserve double quotes for expansion.
- Do not quote numeric option arguments: `--fields=1`, `--max-args=1` (not `--fields='1'`)
- Use `$(...)` not backticks
- Indent with 2 spaces; never tabs
- Constants and config: `readonly` and `UPPER_SNAKE_CASE` at top of script
- For script-level values derived from positional args, declare `readonly NAME="$1"` immediately after arg-count validation (still `UPPER_SNAKE_CASE` if treated as a constant for the rest of the script)
- Use `case ... in PATTERN) ;; *) ;; esac` instead of chained `[[ ]]` / `elif` when matching one variable against multiple string patterns
- Apply `${VAR:-}` defaults only to optional positional args (`"${2:-}"`) — required positionals are already validated by arg-count guards, so let `set -u` catch programming mistakes there. The existing rule about not defaulting well-known env vars still applies.
- Locals: `local` (or `local -r` for read-only) inside every function
- Functions: `snake_case`, defined with `function name() { ... }` (always use `function` keyword)
- Default safely under `set -u`: use `"${VAR:-default}"` for vars that may legitimately be unset; do NOT add defaults for well-known env vars expected to always be present (`HOME`, `USER`, `SDKMAN_DIR`, `PATH`, `SCRIPTS_DIR`, etc.) — let `set -u` catch them if missing
- When parsing decimal strings that may have leading zeros (e.g. `date +%H` → `09`), use `10#` in arithmetic context (`$((10#${var}))`) or strip via `%-H`/`%-M` with GNU date — bash arithmetic treats `08`/`09` as invalid octal
- Force-decimal numbers from external commands before arithmetic comparison
- Tempfiles: `tmp="$(mktemp)"` and `trap 'rm --force -- "${tmp}"' EXIT` for cleanup
- Heredocs: quote the terminator when no expansion wanted: `<<'EOF'`
- Use `printf '%s\n' "$x"` over `echo "$x"` when `$x` could start with `-` or contain backslashes
- Use `printf` (with explicit format string, including ANSI escapes like `'\033[0;32m%s\033[0m\n'` when colorizing) for any non-trivial output; never `echo -e`
- Use `--` before user-supplied paths in destructive commands (`rm --force --`, `mv --`)
- Iterate command output with `mapfile -t arr < <(cmd)`; never `for x in $(cmd)`
- Iterate positional parameters explicitly: `for x in "$@"; do ...; done`, not the implicit `for x; do ...; done` (clearer at a glance what is being iterated)
- Always pass `--no-run-if-empty` and an explicit `--max-args=N` to `xargs`
- Always use `read -r` (or `read -rp PROMPT`); never bare `read` (matches ShellCheck SC2162 — `-r` prevents backslash mangling)
- Scope `PATH` mutations inside a `( ... )` subshell so changes don't leak to the caller's environment
- For non-interactive `curl`, use: `curl --disable --fail --silent --location --show-error`. `--disable` skips `~/.curlrc` so behavior doesn't depend on the invoking user's config
- For non-interactive `wget`, use: `wget --no-config` (skips `~/.wgetrc` for the same reason)
- Network retry idiom for transient failures:

  ```bash
  tries=0
  until some_cmd; do
    (( tries += 1 ))
    if (( tries > 10 )); then
      die "Failed after 10 tries"
    fi
    sleep 15
  done
  ```

- Never parse `ls` output; use globs, `find`, or `fd`
- Avoid `eval`; if needed, justify with comment
- Use `source` instead of `.` when sourcing a file. The `source` keyword is more readable and unambiguous (a leading `.` is easy to overlook).
- When suppressing pipefail in one spot: explicit `|| true` with comment, not blanket disable
- All shell scripts must pass `shellcheck` before being considered complete (use the `./shellcheck-scripts` and `./check-scripts` wrappers documented in `CLAUDE.md`)
- Use `# shellcheck disable=SCxxxx` only with a same-line comment justifying why
- Set strict IFS alongside the strict-mode pragma: `IFS=$'\n\t'` immediately after `set -euo pipefail`
- Use `set -E` and an `ERR` trap for stack-trace-style error reporting in non-trivial scripts:

  ```bash
  set -Eeuo pipefail
  trap 'echo "error: line ${LINENO} (exit $?): ${BASH_COMMAND}" >&2' ERR
  ```

- Pin minimum bash version when using bash 4+ features (associative arrays, `mapfile`, `${var^^}`, etc.):

  ```bash
  if (( BASH_VERSINFO[0] < 4 )); then
    echo 'bash 4+ required' >&2
    exit 1
  fi
  ```

- Always check `cd` results: `cd "${dir}" || exit 1`. Prefer scoped subshells over `pushd`/`popd`: `(cd "${dir}" && do_thing)`
- SUID and SGID are forbidden on shell scripts. Use `sudo` to grant elevated access instead.
- All error messages must be written to stderr. The repo's logging helpers already follow this — `log`, `log_with_date`, `log_warn`, and `die` all write to stderr.
- Document non-trivial functions with a comment block above the definition: description, globals used or modified, arguments (using the `# $1 = description` style for each positional; `# $@ = ...` for varargs), outputs (stdout/stderr), and return value semantics. Library functions in `functions/*.bash` always require this; small internal helpers may be lighter.
- Comment tricky, non-obvious, or important code sections; explain *why*, not *what*.
- Use `TODO:` (all caps, no author identifier) to mark deferred work.
- Maximum line length is 80 characters. Wrap long strings via here-docs or embedded newlines. Long URLs and file paths may exceed when necessary.
- Pipeline formatting: a pipeline that fits on one line stays on one line. When wrapping, put one segment per line with the `|` at the start of the continuation line, indented 2 spaces from the opening command.
- Control flow opener: `; then` and `; do` on the same line as `if`/`while`/`for`. `else` on its own line. `fi`/`done` on their own line, aligned with the opener.
- `case` statement formatting: indent each alternative 2 spaces; multi-line alternatives put the pattern, the actions, and the closing `;;` on separate lines. Never use `;&` or `;;&` (fall-through) — write explicit cases instead.
- Single-character integer specials (`$?`, `$#`, `$$`, `$!`) are exempt from the "quote everything" rule — quoting is optional since they cannot contain whitespace or globs.
- Use `"$@"` to forward positional parameters; reach for `$*` only when you specifically need a single concatenated string.
- Use bash arrays for lists of elements or command-line flags to avoid quoting complications. Always expand with `"${array[@]}"` (quoted, `@` not `*`). Do not use arrays for complex data structures — bash arrays are not the right tool.
- In `[[ ]]`, prefer `==` over `=` for equality.
- Never use `<` or `>` inside `[[ ]]` for numeric comparison (those are lexicographic). Use `(( a < b ))` or `[[ a -lt b ]]` instead.
- Use `./*` rather than `*` when feeding glob results to commands so filenames beginning with `-` aren't treated as options.
- Never pipe into `while`: the loop runs in a subshell, so any variable assignments inside are lost. Use process substitution (`while read -r ...; do ...; done < <(cmd)`) or read into an array first with `mapfile -t arr < <(cmd)`.
- Avoid bare `(( expr ))` as a standalone statement when the expression can evaluate to zero — under `set -e`, an exit status of 1 from the arithmetic kills the script. Use `(( expr )) || true` (with a same-line comment), `: $(( expr ))` for side effects only, or capture the value with `result=$(( expr ))`.
- Inside `$(( … ))`, omit the `${}` braces — the shell auto-resolves bare variable names: `$(( count + 1 ))` not `$(( ${count} + 1 ))`.
- Never define aliases in scripts. Use shell functions instead (aliases are inert in non-interactive shells anyway).
- Library functions are namespaced with `::`: a helper in `functions/files.bash` is `files::exists`, in `functions/log.bash` is `log::info`, etc. Internal/private helpers (not used across files) may keep plain `snake_case`.
- Name loop variables after the items being iterated: `for file in "${files[@]}"` not `for x in "${files[@]}"`.
- When using command substitution to assign a `local`, declare and assign on separate lines so the command's exit status is observable (`local` always returns 0 and masks the substitution's exit status):

  ```bash
  # wrong — masks cmd's exit status
  local result="$(cmd)"

  # right
  local result
  result="$(cmd)"
  ```

- File layout: only the shebang, strict-mode pragma, IFS, sourced libraries / `set` options, and constants appear before function definitions. All functions are grouped together below constants. No executable code is interleaved between function definitions.
- For pipelines whose per-stage exit codes matter, capture `PIPESTATUS` into a variable on the very next line — any subsequent command overwrites it:

  ```bash
  cmd_a | cmd_b | cmd_c
  status=( "${PIPESTATUS[@]}" )
  ```

- Prefer shell builtins, parameter expansion, and `=~` over external tools when they can do the job (`${var//pat/rep}` over `sed`, `${var%suffix}` over `cut`, `[[ "$s" =~ ^[0-9]+$ ]]` over `grep`). External commands are fine when the builtin form is unreadable.
- Consistency tiebreaker: when picking between equivalent options, match the existing patterns in surrounding code rather than introducing a third variant. But "we've always done it this way" is not a reason to keep an outdated style when the rule book has changed — apply current rules to new code.
- File extensions: top-level executables (everything under `main/`, `install/`, `set_up/`, `misc/`) have no extension; library files under `functions/` use the `.bash` extension and are NOT executable.
- Filename conventions: executables use kebab-case (`new-script`, `format-scripts`, `run-install-scripts`); library files use snake_case with the `.bash` extension (`functions/files.bash`, `functions/log.bash`).
