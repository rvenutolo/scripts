#!/usr/bin/env bash

# @description Return true if the given path exists and is a regular file.
# @arg $1 file path
function files::exists() {
  args::check_exactly_1_arg "$@"
  [[ -f $1 ]]
}

# @description Die if the given file does not exist.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::assert_exists() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! files::exists "${file}"; then
    log::die "${file} does not exist"
  fi
}

# @description Return true if the given path exists as any filesystem entry (regular file, directory, symlink, device, etc.).
# @arg $1 path to test
# @exitcode 0 if true
# @exitcode 1 if false
function files::any_exists() {
  args::check_exactly_1_arg "$@"
  [[ -e $1 ]]
}

# @description Return true if the given path is executable and is not a directory.
# Works for regular files and symlinks to regular files; returns false for directories,
# symlinks to directories, broken symlinks, and missing paths.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::is_executable() {
  args::check_exactly_1_arg "$@"
  [[ ! -d $1 && -x $1 ]]
}

# @description Die if the given path is not executable or is a directory.
# @arg $1 file path
function files::assert_executable() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! files::is_executable "${file}"; then
    log::die "${file} is not executable"
  fi
}

# @description Return true if the given path exists, is a regular file, and has size zero.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::is_empty() {
  args::check_exactly_1_arg "$@"
  [[ -f $1 && ! -s $1 ]]
}

# @description Return true if the given path exists, is a regular file, and has size greater than zero.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::is_non_empty() {
  args::check_exactly_1_arg "$@"
  [[ -f $1 && -s $1 ]]
}

# @description Die if the given file does not exist or is not empty.
# @arg $1 file path
function files::assert_empty() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! files::is_empty "${file}"; then
    log::die "${file} does not exist or is not empty"
  fi
}

# @description Die if the given file does not exist or has zero size.
# @arg $1 file path
function files::assert_non_empty() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if ! files::is_non_empty "${file}"; then
    log::die "${file} does not exist or is empty"
  fi
}

# @description Return true if the given file exists and is readable.
# @arg $1 file path
# @exitcode 0 if true
# @exitcode 1 if false
function files::is_readable() {
  args::check_exactly_1_arg "$@"
  [[ -r $1 ]]
}

# @description Print the size of a file in gigabytes (two decimal places).
# Output: stdout — size in GB, e.g. "1.23"
# @arg $1 file path
function files::size_gb() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  files::assert_exists "${file}"
  printf '%s\n' "scale=2; $(stat --format='%s' "${file}") / 1073741824" | bc
}

# @description Move a file, prompting if the destination already exists; skips if source and dest are byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::move() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      rm --force -- "${src}"
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Moving: ${src} -> ${dest}"
  dirs::create "$(dirname "${dest}")"
  mv -- "${src}" "${dest}"
  log::log "Moved: ${src} -> ${dest}"
}

# @description Move a file quietly, prompting if the destination already exists; skips if source and dest are byte-identical.
# Like files::move but suppresses the "Moving/Moved" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::move_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      rm --force -- "${src}"
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::create "$(dirname "${dest}")"
  mv -- "${src}" "${dest}"
}

# @description Move a file without prompting, overwriting destination if it exists. For programmatic temp-file-to-dest moves
# where interactive confirmation would be inappropriate. Creates parent directory of destination if needed.
# @arg $1 source file path
# @arg $2 destination file path
function files::move_no_prompt() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  log::log "Moving: ${src} -> ${dest}"
  dirs::create "$(dirname "${dest}")"
  mv --force -- "${src}" "${dest}"
  log::log "Moved: ${src} -> ${dest}"
}

# @description Move a file quietly without prompting, overwriting destination if it exists. Creates parent directory of
# destination if needed. Like files::move_no_prompt but suppresses the "Moving/Moved" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::move_no_prompt_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  dirs::create "$(dirname "${dest}")"
  mv --force -- "${src}" "${dest}"
}

# @description Move a file as root, prompting if the destination already exists; skips if byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_move() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      sudo rm --force -- "${src}"
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Moving: ${src} -> ${dest}"
  dirs::root_create "$(dirname "${dest}")"
  sudo mv -- "${src}" "${dest}"
  log::log "Moved: ${src} -> ${dest}"
}

# @description Move a file as root quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::root_move but suppresses the "Moving/Moved" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_move_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      sudo rm --force -- "${src}"
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Move ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::root_create "$(dirname "${dest}")"
  sudo mv -- "${src}" "${dest}"
}

# @description Copy a file, prompting if the destination already exists; skips if byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::copy() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Copying: ${src} -> ${dest}"
  dirs::create "$(dirname "${dest}")"
  cp "${src}" "${dest}"
  log::log "Copied: ${src} -> ${dest}"
}

# @description Copy a file quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::copy but suppresses the "Copying/Copied" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::copy_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if files::exists "${dest}"; then
    if cmp --silent "${src}" "${dest}"; then
      return 0
    else
      diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::create "$(dirname "${dest}")"
  cp "${src}" "${dest}"
}

# @description Copy a file as root, prompting if the destination already exists; skips if byte-identical.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_copy() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  log::log "Copying: ${src} -> ${dest}"
  dirs::root_create "$(dirname "${dest}")"
  sudo cp "${src}" "${dest}"
  log::log "Copied: ${src} -> ${dest}"
}

# @description Copy a file as root quietly, prompting if the destination already exists; skips if byte-identical.
# Like files::root_copy but suppresses the "Copying/Copied" log messages.
# @arg $1 source file path
# @arg $2 destination file path
function files::root_copy_quiet() {
  args::check_exactly_2_args "$@"
  local -r src="$1"
  local -r dest="$2"
  files::assert_exists "${src}"
  if [[ ${src} == "${dest}" ]]; then
    log::die "File paths are the same"
  fi
  if sudo test -f "${dest}"; then
    if sudo cmp --silent "${src}" "${dest}"; then
      return 0
    else
      sudo diff --color --unified "${dest}" "${src}" || true
      if ! prompt::yn "${dest} exists - Overwrite: ${src} -> ${dest}?"; then
        return 0
      fi
    fi
  else
    if ! prompt::yn "Copy ${src} -> ${dest}?"; then
      return 0
    fi
  fi
  dirs::root_create "$(dirname "${dest}")"
  sudo cp "${src}" "${dest}"
}

# @description Transform a root-owned file by streaming it through a filter command.
# Reads the file via `sudo cat`, pipes the content through `filter_cmd ...`, and writes the result
# back via `files::root_copy` (which shows a diff and prompts before overwriting). Skips if the
# filtered output is byte-identical to the original. The filter command must read its input from
# stdin and write the transformed content to stdout. Bash functions defined in the calling shell
# are valid filters (they are inherited by the pipeline subshell).
# @arg $1 file path to transform
# @arg $@ filter command and any args
function files::root_transform() {
  args::check_at_least_2_args "$@"
  local -r file="$1"
  shift
  files::assert_exists "${file}"
  files::create_temp tmp_transform_out
  # shellcheck disable=SC2154 # tmp_transform_out assigned by files::create_temp via nameref
  sudo cat "${file}" | "$@" >"${tmp_transform_out}"
  files::root_copy "${tmp_transform_out}" "${file}"
}

# @description Write content to a file, prompting if the file already exists; skips if content is identical.
# @arg $1 file path
# @arg $2 content to write
function files::write() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(<"${file}")" == "${content}" ]]; then
      return 0
    else
      diff --color --unified "${file}" - <<<"${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log::log "Writing ${file}"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >"${file}"
  log::log "Wrote ${file}"
}

# @description Write content to a file quietly, prompting if the file already exists; skips if content is identical.
# Like files::write but suppresses the "Writing/Wrote" log messages.
# @arg $1 file path
# @arg $2 content to write
function files::write_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(<"${file}")" == "${content}" ]]; then
      return 0
    else
      diff --color --unified "${file}" - <<<"${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >"${file}"
}

# @description Write content to a root-owned file, prompting if the file already exists; skips if content is identical.
# @arg $1 file path
# @arg $2 content to write
function files::root_write() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(sudo cat "${file}")" == "${content}" ]]; then
      return 0
    else
      sudo diff --color --unified "${file}" - <<<"${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  log::log "Writing ${file}"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee "${file}" >'/dev/null'
  log::log "Wrote ${file}"
}

# @description Write content to a root-owned file quietly, prompting if the file already exists; skips if content is identical.
# Like files::root_write but suppresses the "Writing/Wrote" log messages.
# @arg $1 file path
# @arg $2 content to write
function files::root_write_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  if files::exists "${file}"; then
    if [[ "$(sudo cat "${file}")" == "${content}" ]]; then
      return 0
    else
      sudo diff --color --unified "${file}" - <<<"${content}" || true
      if ! prompt::yn "${file} exists - Overwrite?"; then
        return 0
      fi
    fi
  fi
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee "${file}" >'/dev/null'
}

# @description Append content to a file, creating the file and any missing parent directories as needed.
# @arg $1 file path
# @arg $2 content to append
function files::append_to() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  log::log "Appending to ${file}"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >>"${file}"
  log::log "Appended to ${file}"
}

# @description Append content to a file quietly, creating the file and any missing parent directories as needed.
# Like files::append_to but suppresses the "Appending/Appended" log messages.
# @arg $1 file path
# @arg $2 content to append
function files::append_to_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  dirs::create "$(dirname "${file}")"
  printf '%s\n' "${content}" >>"${file}"
}

# @description Append content to a root-owned file, creating the file and any missing parent directories as needed.
# @arg $1 file path
# @arg $2 content to append
function files::root_append_to() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  log::log "Appending to ${file}"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee --append "${file}" >'/dev/null'
  log::log "Appended to ${file}"
}

# @description Append content to a root-owned file quietly, creating the file and any missing parent directories as needed.
# Like files::root_append_to but suppresses the "Appending/Appended" log messages.
# @arg $1 file path
# @arg $2 content to append
function files::root_append_to_quiet() {
  args::check_exactly_2_args "$@"
  local -r file="$1"
  local -r content="$2"
  dirs::root_create "$(dirname "${file}")"
  printf '%s\n' "${content}" | sudo tee --append "${file}" >'/dev/null'
}

# @description Create a temporary file under /tmp and set the named variable in the
# caller's scope to its path. The file is NOT cleaned up on exit — /tmp is managed by
# the OS (tmpfs reboot wipe, systemd-tmpfiles age-based cleanup), so process-level
# cleanup is unnecessary and adds complexity (EXIT-trap clobbering, multi-file accounting).
# @arg $1 variable name to receive the temp file path (nameref)
function files::create_temp() {
  args::check_exactly_1_arg "$@"
  local -n _files_create_temp_var="$1"
  _files_create_temp_var="$(mktemp)"
}

# @description Print the largest regular files under a directory, biggest first.
#              Paths containing embedded newlines are not handled and may produce corrupt rows.
# @arg $1 dir directory to scan
# @arg $2 count maximum number of rows to print
# @stdout tab-separated `<bytes>\t<path>` rows, largest first, at most <count> rows
function files::largest_files() {
  args::check_exactly_2_args "$@"
  local -r dir="$1"
  local -r count="$2"
  local tmp
  local sorted_tmp
  files::create_temp tmp
  files::create_temp sorted_tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  find "${dir}" -type f -printf '%s\t%p\n' >"${tmp}"
  # shellcheck disable=SC2154 # sorted_tmp assigned by files::create_temp via nameref
  sort --field-separator=$'\t' --key=1,1nr "${tmp}" >"${sorted_tmp}"
  head --lines="${count}" "${sorted_tmp}"
}

# @description Print the largest directories (cumulative apparent size) under a directory, biggest first.
#              Paths containing embedded newlines are not handled and may produce corrupt rows.
# @arg $1 dir directory to scan
# @arg $2 count maximum number of rows to print
# @stdout tab-separated `<bytes>\t<path>` rows, largest first, at most <count> rows
function files::largest_dirs() {
  args::check_exactly_2_args "$@"
  local -r dir="$1"
  local -r count="$2"
  local tmp
  local sorted_tmp
  files::create_temp tmp
  files::create_temp sorted_tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  du --bytes "${dir}" >"${tmp}"
  # shellcheck disable=SC2154 # sorted_tmp assigned by files::create_temp via nameref
  sort --field-separator=$'\t' --key=1,1nr "${tmp}" >"${sorted_tmp}"
  head --lines="${count}" "${sorted_tmp}"
}

# @description Print the largest entries (files and directories combined) under a directory, biggest first.
#              Paths containing embedded newlines are not handled and may produce corrupt rows.
# @arg $1 dir directory to scan
# @arg $2 count maximum number of rows to print
# @stdout tab-separated `<bytes>\t<path>` rows, largest first, at most <count> rows
function files::largest_all() {
  args::check_exactly_2_args "$@"
  local -r dir="$1"
  local -r count="$2"
  local tmp
  local sorted_tmp
  files::create_temp tmp
  files::create_temp sorted_tmp
  # shellcheck disable=SC2154 # tmp assigned by files::create_temp via nameref
  du --bytes --all "${dir}" >"${tmp}"
  # shellcheck disable=SC2154 # sorted_tmp assigned by files::create_temp via nameref
  sort --field-separator=$'\t' --key=1,1nr "${tmp}" >"${sorted_tmp}"
  head --lines="${count}" "${sorted_tmp}"
}

# @description Print the SHA-256 hash of a file or stdin. Dies if the file argument does not exist.
# Output: stdout — hex SHA-256 digest
# @arg $1 file path (optional; reads stdin if omitted)
function files::hash() {
  if [[ $# -gt 0 ]]; then
    args::check_exactly_1_arg "$@"
    local -r file="$1"
    files::assert_exists "${file}"
    sha256sum "${file}" | cut --delimiter=' ' --fields=1
  else
    args::check_for_stdin
    sha256sum | cut --delimiter=' ' --fields=1
  fi
}

# @description Find files with identical content under a directory. Pre-filters by byte size
# (only files sharing a size are hashed), then groups survivors by SHA-256. Emits one
# tab-separated `<bytes>\t<sha256>\t<path>` line per file belonging to a duplicate set
# (>1 member), sorted by size descending then hash, so set members are contiguous.
# Paths containing embedded newlines or tab characters are not handled and may produce corrupt output rows.
# If a candidate file is removed between enumeration and hashing, files::hash dies (fail-loud) and aborts the scan.
# @arg $1 dir optional directory to scan (default ".")
# @stdout tab-separated `size\thash\tpath` lines for duplicated files; empty if none
function files::find_duplicates() {
  args::check_at_most_1_arg "$@"
  local dir
  if args::no_args "$@"; then
    dir="."
  else
    dir="$1"
  fi
  local all_tmp dupsizes_tmp candidates_tmp hashed_tmp duphashes_tmp
  files::create_temp all_tmp
  # shellcheck disable=SC2154 # all_tmp assigned by files::create_temp via nameref
  files::create_temp dupsizes_tmp
  # shellcheck disable=SC2154 # dupsizes_tmp assigned by files::create_temp via nameref
  files::create_temp candidates_tmp
  # shellcheck disable=SC2154 # candidates_tmp assigned by files::create_temp via nameref
  files::create_temp hashed_tmp
  # shellcheck disable=SC2154 # hashed_tmp assigned by files::create_temp via nameref
  files::create_temp duphashes_tmp
  # shellcheck disable=SC2154 # duphashes_tmp assigned by files::create_temp via nameref

  find "${dir}" -type f -printf '%s\t%p\n' >"${all_tmp}"

  # sizes that occur more than once
  cut --fields=1 "${all_tmp}" | sort | uniq --repeated >"${dupsizes_tmp}"

  # keep only files whose size is in the repeated-size set
  awk --field-separator=$'\t' \
    'NR == FNR { sizes[$1]; next } ($1 in sizes)' \
    "${dupsizes_tmp}" "${all_tmp}" >"${candidates_tmp}"

  # hash each candidate -> size<TAB>hash<TAB>path
  local line size path hash
  while read -r line; do
    size="${line%%$'\t'*}"
    path="${line#*$'\t'}"
    hash="$(files::hash "${path}")"
    printf '%s\t%s\t%s\n' "${size}" "${hash}" "${path}"
  done <"${candidates_tmp}" >"${hashed_tmp}"

  # hashes that occur more than once
  cut --fields=2 "${hashed_tmp}" | sort | uniq --repeated >"${duphashes_tmp}"

  # keep only rows whose hash is duplicated, sorted by size desc then hash
  awk --field-separator=$'\t' \
    'NR == FNR { hashes[$1]; next } ($2 in hashes)' \
    "${duphashes_tmp}" "${hashed_tmp}" |
    sort --field-separator=$'\t' --key=1,1nr --key=2,2
}

# @description Print the SHA-256 hash of a file, or the empty string if the file does not exist.
# Intended for the "hash before / hash after" idiom where the destination file may not yet exist on first run.
# Output: stdout — hex SHA-256 digest, or empty string if the file is absent
# @arg $1 file path
function files::hash_if_exists() {
  args::check_exactly_1_arg "$@"
  local -r file="$1"
  if files::exists "${file}"; then
    sha256sum "${file}" | cut --delimiter=' ' --fields=1
  fi
}

# @description Compute a batch-rename plan. For each file, apply `sed s/<pattern>/<replacement>/`
#              to its basename (directory portion untouched). Emits surviving `old\tnew` pairs to
#              stdout and warns (stderr) for each skip: no-op (unchanged name), destination already
#              on disk, or a target duplicated within the batch.
#              Pattern/replacement must not contain an unescaped `/` (sed s/// delimiter).
# @arg $1 pattern sed BRE pattern matched against the basename
# @arg $2 replacement sed replacement string
# @arg $3 files one or more file paths to rename
# @stdout tab-separated `old\tnew` rename pairs for files that pass collision filtering
# @stderr a `log::warn` line for each skipped file
function files::plan_renames() {
  args::check_at_least_3_args "$@"
  local -r pattern="$1"
  local -r replacement="$2"
  if [[ ${pattern} == *'/'* || ${replacement} == *'/'* ]]; then
    log::die "pattern and replacement must not contain '/' (sed s/// delimiter)"
  fi
  shift 2
  local targets_tmp
  files::create_temp targets_tmp
  # shellcheck disable=SC2154 # targets_tmp assigned by files::create_temp via nameref
  local file dir base new_base new
  for file in "$@"; do
    dir="$(dirname "${file}")"
    base="$(basename "${file}")"
    # shellcheck disable=SC2001 # pattern is a BRE variable; ${//} only supports globs, not regex
    new_base="$(sed "s/${pattern}/${replacement}/" <<<"${base}")"
    if [[ ${dir} == '.' ]]; then
      new="${new_base}"
    else
      new="${dir}/${new_base}"
    fi
    if [[ ${new} == "${file}" ]]; then
      # Silent skip — pattern produced no change; no warning needed
      continue
    fi
    if files::exists "${new}"; then
      log::warn "Skipping ${file}: destination exists: ${new}"
      continue
    fi
    # No grep:: helper combines --line-regexp with --fixed-strings; raw grep is correct here.
    # The `if` consumes the exit status (0=match, 1=no-match), so set -e does not fire on no-match.
    if grep --quiet --line-regexp --fixed-strings -- "${new}" "${targets_tmp}"; then
      log::warn "Skipping ${file}: duplicate target within batch: ${new}"
      continue
    fi
    printf '%s\n' "${new}" >>"${targets_tmp}"
    printf '%s\t%s\n' "${file}" "${new}"
  done
}
