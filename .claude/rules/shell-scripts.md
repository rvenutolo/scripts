- Claude MUST use the helper functions in `functions/*.bash` whenever an applicable helper exists. Do not write inline equivalents for operations that already have a helper (file mutation, prompts, OS detection, downloads, path manipulation, logging, arg-count guards, executable existence, symlinks, etc.). Before writing inline shell, scan `functions/*.bash` for a matching helper.
- Claude may propose new helper functions when a piece of logic looks reusable across scripts, even if it is currently only needed in one place. Suggest the new helper (with proposed file and signature) rather than silently inlining.
- `set -euo pipefail` is mandatory at the top of every top-level script (not in library files under `functions/`).
- `[[ ]]` over `[ ]`, long CLI options, quoted `"${var}"` everywhere — enforced by shellcheck.
- Scripts under `set_up/` must be idempotent and self-gate — check current state before mutating, and exit cleanly when there is nothing to do.
- After `set -euo pipefail`, source the function library and guard arg count:

  ```bash
  #shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions.bash"
  check_no_args "$@"   # or check_exactly_N_args / check_at_least_N_args / check_at_most_N_args
  ```

- Library files under `functions/` get only the shebang — do NOT add `set -euo pipefail` or source `functions.bash`. Strict mode is owned by the parent script that sources them.
- Create new scripts via `main/new-script <path>` (handles header + exec bit).
- Document positional parameters above each function with `# $1 = description` comments (use `# $@ = ...` for varargs).
- Predicate functions (`is_*`, `*_exists`, etc.) end with a `[[ ... ]]` test or command whose exit status is the result — do not write explicit `return 0` / `return 1`.
- Library functions in `functions/*.bash` use the same `check_*_args "$@"` guards as top-level scripts (not only top-level scripts get them).
- Logging/erroring helpers: `log` / `log_with_date` / `die` from `functions/log.bash` (color-coded, stderr, prefixed with `${0##*/}`). These override the generic `log_info` / `log_warn` / `log_err` template from the global rules — do not use that template here.
- `die` includes caller context via `${BASH_SOURCE[1]}:${FUNCNAME[1]}:${BASH_LINENO[0]}` — preserve this when modifying the helper.
- Stdin presence: helpers `check_for_stdin` / `stdin_exists` from `functions/args.bash`. No inline `[[ -t 0 ]]`.
- Existence checks: helpers `file_exists` / `assert_file_exists` (`functions/files.bash`), `dir_exists` / `assert_dir_exists` (`functions/dirs.bash`), `symlink_exists` (`functions/symlinks.bash`). Use the `assert_*` variants for entry-point validation (they call `die` with a consistent message); use the bare predicates for branching. No inline `[[ -f X ]]` + manual `die` rolls.
- Interactive prompts: helpers `prompt_yn` / `prompt_ny` / `prompt_for_value` from `functions/prompt.bash`. Fall back to inline `read -rp $'\e[0;33mPrompt: \e[0m'` (colored `$'...'` form) only when no helper fits, and document why with a comment.
- Executable-on-`PATH` check: helper `executable_exists` from `functions/commands.bash` (uses `type -aPf`, excludes builtins/aliases/functions). Overrides the global rule's `command -v` recommendation for this repo.
- Idempotent file mutation (write/move/copy/link/append): helpers in `functions/files.bash` and `functions/symlinks.bash` — `write_file`, `append_to_file`, `move_file`, `copy_file`, `link_file`, `link_dir`. They implement the standard pattern: `cmp --silent` short-circuit on byte equality, `diff --color --unified ... || true` preview, `prompt_yn` confirmation, and parent-dir auto-creation via `create_dir "$(dirname "$dest")"`.
- Parent-dir auto-creation before writing/moving/copying: helpers `create_dir "$(dirname "${dest}")"` (or `root_create_dir` for sudo writes). No inline `mkdir --parents` / `mkdir -p`.
- Root-owned destinations: `root_*` variants (`root_write_file`, `root_append_to_file`, `root_move_file`, `root_copy_file`, `root_create_dir`). When no helper fits, use `sudo test -f`, `sudo cmp`, `sudo cat` for state checks, and `echo "${content}" | sudo tee [--append] "${file}" > '/dev/null'` for the write — no `sudo bash -c 'echo ... > ...'`.
- Symlinks: helpers `link_file` / `link_dir` from `functions/symlinks.bash`. No inline `ln --symbolic` / `ln -s` — the helpers handle the canonical-target short-circuit, diff/prompt confirmation, and parent-dir creation.
- Read values from `/etc/os-release` by sourcing it in a subshell, not by `grep`/`sed`/`awk`. The file is spec-defined as shell-sourceable, handles quoted values correctly, and exposes every field at once:

  ```bash
  # shellcheck disable=SC1091
  ( . /etc/os-release && printf '%s\n' "${ID}" )
  ```

  Use a subshell so the sourced variables don't leak.
- Use `find -printf '<fmt>'` for structured output (e.g. `find . -printf '%u:%g\n'`) instead of parsing default `find` output.
- Use `stat --format='<fmt>'` for file metadata. For non-integer arithmetic, pipe through `bc` (bash `(( ))` is integer-only): `echo "scale=2; $(stat --format='%s' "${f}") / 1073741824" | bc`.
- New scripts must be created executable (`chmod +x`). `main/new-script` already does this — prefer it over hand-creating files.
