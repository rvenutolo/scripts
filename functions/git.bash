#!/usr/bin/env bash

# @description Return true if the given path is inside a git repository (work tree, bare repo, or .git dir).
# @arg $1 dir path
function git::is_git_repo() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  git -C "${dir}" rev-parse --git-dir > '/dev/null' 2>&1
}

# @description Die if the given path is not inside a git repository.
# @arg $1 dir path
# @exitcode 0 if true
# @exitcode 1 if false
function git::assert_git_repo() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  if ! git::is_git_repo "${dir}"; then
    log::die "${dir} is not a git repo"
  fi
}

# @description Resolve the toplevel (work-tree root) of the repo containing the given dir.
# Validates the path is a git repo first. Dies if not.
# @arg $1 dir path inside a git repo
# @stdout absolute path of the repo's toplevel
function git::repo_root() {
  args::check_exactly_1_arg "$@"
  local -r dir="$1"
  git::assert_git_repo "${dir}"
  git -C "${dir}" rev-parse --show-toplevel
}

# @description Get the configured user.name for the given repo. Dies if unset or empty.
# Resolution follows the standard git config chain (local > global > system).
# @arg $1 repo path inside a git repo
# @stdout the configured user.name
function git::canonical_name() {
  args::check_exactly_1_arg "$@"
  local -r repo="$1"
  local name
  name="$(git -C "${repo}" config --get user.name)" \
    || log::die "user.name not set in git config for ${repo}"
  strings::is_not_empty "${name}" || log::die "user.name is empty in git config for ${repo}"
  printf '%s\n' "${name}"
}

# @description Get the configured user.email for the given repo. Dies if unset or empty.
# Resolution follows the standard git config chain (local > global > system).
# @arg $1 repo path inside a git repo
# @stdout the configured user.email
function git::canonical_email() {
  args::check_exactly_1_arg "$@"
  local -r repo="$1"
  local email
  email="$(git -C "${repo}" config --get user.email)" \
    || log::die "user.email not set in git config for ${repo}"
  strings::is_not_empty "${email}" || log::die "user.email is empty in git config for ${repo}"
  printf '%s\n' "${email}"
}

# @description Write distinct identities (union of author and committer) from every commit reachable
# via --all to out_file. One identity per line, tab-separated as: name<TAB>email. Sorted, deduped.
# Dies if the repo has no commits.
# @arg $1 repo path inside a git repo
# @arg $2 out_file destination file (overwritten)
function git::write_distinct_identities() {
  args::check_exactly_2_args "$@"
  local -r repo="$1"
  local -r out_file="$2"
  files::create_temp _gwdi_raw
  # shellcheck disable=SC2154 # _gwdi_raw assigned by files::create_temp via nameref
  git -C "${repo}" log --all --format='%aN%x09%aE%x0A%cN%x09%cE' > "${_gwdi_raw}"
  if [[ ! -s "${_gwdi_raw}" ]]; then
    log::die "No commits found in ${repo}"
  fi
  sort --unique "${_gwdi_raw}" > "${out_file}"
}

# @description Pretty-print identities from a tab-separated name<TAB>email file as bullet list to stderr.
# Emits prefix_msg via log::log, then one '  name <email>' line per file row.
# @arg $1 prefix_msg log line printed before the bullets
# @arg $2 file path to identities file (tab-separated name<TAB>email)
function git::print_identities() {
  args::check_exactly_2_args "$@"
  local -r prefix_msg="$1"
  local -r file="$2"
  local name email
  log::log "${prefix_msg}"
  while IFS=$'\t' read -r name email; do
    printf '  %s <%s>\n' "${name}" "${email}" >&2
  done < "${file}"
}

# @description Interactively prompt the user (via prompt::ny, default-no) for each identity in
# distinct_file. Each accepted identity is appended (verbatim) to selected_file. selected_file is
# truncated on entry. distinct_file is read via FD 3 so the prompt's stdin is preserved.
# @arg $1 distinct_file source file (tab-separated name<TAB>email rows)
# @arg $2 selected_file destination file for picked rows (overwritten then appended)
function git::prompt_select_identities() {
  args::check_exactly_2_args "$@"
  local -r distinct_file="$1"
  local -r selected_file="$2"
  local name email
  : > "${selected_file}"
  while IFS=$'\t' read -r -u 3 name email; do
    if prompt::ny "Is '${name} <${email}>' your identity?"; then
      printf '%s\t%s\n' "${name}" "${email}" >> "${selected_file}"
    fi
  done 3< "${distinct_file}"
}

# @description Count commits across --all whose author identity (name<TAB>email) matches any line
# in selected_file. Output is a single integer.
# @arg $1 repo path inside a git repo
# @arg $2 selected_file tab-separated name<TAB>email file
# @stdout match count (integer)
function git::count_author_matches() {
  args::check_exactly_2_args "$@"
  local -r repo="$1"
  local -r selected_file="$2"
  git -C "${repo}" log --all --format='%aN%x09%aE' \
    | grep --fixed-strings --line-regexp --count --file="${selected_file}" || true
}

# @description Count commits across --all whose committer identity (name<TAB>email) matches any line
# in selected_file. Output is a single integer.
# @arg $1 repo path inside a git repo
# @arg $2 selected_file tab-separated name<TAB>email file
# @stdout match count (integer)
function git::count_committer_matches() {
  args::check_exactly_2_args "$@"
  local -r repo="$1"
  local -r selected_file="$2"
  git -C "${repo}" log --all --format='%cN%x09%cE' \
    | grep --fixed-strings --line-regexp --count --file="${selected_file}" || true
}

# @description Count commits across --all whose author OR committer identity (name<TAB>email)
# matches any line in selected_file. A commit where both author and committer match is counted
# once, not twice. Output is a single integer.
# @arg $1 repo path inside a git repo
# @arg $2 selected_file tab-separated name<TAB>email file
# @stdout match count (integer)
function git::count_author_or_committer_matches() {
  args::check_exactly_2_args "$@"
  local -r repo="$1"
  local -r selected_file="$2"
  local commits_file
  files::create_temp commits_file
  # shellcheck disable=SC2154 # commits_file assigned by files::create_temp via nameref
  git -C "${repo}" log --all --format='%aN%x09%aE%x1F%cN%x09%cE' > "${commits_file}"
  awk -F '\x1F' '
    NR == FNR { sel[$0] = 1; next }
    sel[$1] || sel[$2] { c++ }
    END { print c + 0 }
  ' "${selected_file}" "${commits_file}"
}

# @description Populate the named array with the command (and any leading args) to invoke
# git-filter-repo. Prefers the local binary; falls back to running it via `nix run` from
# nixpkgs-unstable. Dies if neither git-filter-repo nor nix is on PATH.
# @arg $1 array_name name of an existing array variable to populate (via nameref)
function git::resolve_filter_repo_cmd() {
  args::check_exactly_1_arg "$@"
  local -n _grfrc_arr="$1"
  if commands::executable_exists git-filter-repo; then
    _grfrc_arr=(git-filter-repo)
  else
    log::log 'git-filter-repo not on PATH; falling back to: nix run github:NixOS/nixpkgs/nixpkgs-unstable#git-filter-repo'
    commands::executable_exists nix || log::die 'Neither git-filter-repo nor nix is available'
    _grfrc_arr=(nix run 'github:NixOS/nixpkgs/nixpkgs-unstable#git-filter-repo' --)
  fi
}
