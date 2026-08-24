#!/usr/bin/env bash

### MISC

# @description Extract the major version number from a JDK version string or artifact ID.
# Output: stdout — major version number (e.g. "21")
# @arg $1 version string or artifact ID (e.g. "21.0.3-tem" or "21")
function sdkman_jdks::get_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r version="$1"
  if [[ "${version}" =~ ^([0-9]+) ]]; then
    printf '%s' "${BASH_REMATCH[1]}"
  else
    log::die "Unexpected version: ${version}"
  fi
}

### BASIC OPERATIONS

# @description Install a specific JDK artifact via SDKMAN.
# @arg $1 jdk artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::install_jdk() {
  args::check_exactly_1_arg "$@"
  sdk install java "$1" | sdkman::clean_output
}

# @description Uninstall a specific JDK artifact via SDKMAN.
# @arg $1 jdk artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::uninstall_jdk() {
  args::check_exactly_1_arg "$@"
  sdk uninstall java "$1" | sdkman::clean_output
}

# @description Set the given JDK artifact as the SDKMAN default for java.
# @arg $1 artifact ID (e.g. "21.0.3-tem")
function sdkman_jdks::set_default_jdk_by_id() {
  args::check_exactly_1_arg "$@"
  sdk default java "$1" | sdkman::clean_output
}

### FORMATTED JDK INFO

# @description Fetch the remote Temurin JDK catalog, newest first. Always performs a network
#   round-trip: `sdk list java` issues an uncached HTTPS request to the SDKMAN API (~0.4s).
#   Callers want sdkman_jdks::get_tem_jdk_catalog, which memoizes this per process.
#   The installed/in-use markers `sdk list java` prints are deliberately discarded — installed
#   state is owned by the candidates dir (see sdkman_jdks::get_formatted_installed_tem_jdks).
#   Vendor rows are selected by the `-tem` suffix on the trailing Identifier column, not by a
#   fixed field index: SDKMAN dropped the Dist and Status columns from the table, so the old
#   `$4 == tem` / print-`$6` form silently matched nothing and every caller saw an empty catalog
#   — `sdkman-clean` died with "Java version 8 is not available" and `sdkman-update` skipped
#   every JDK without a word. Keying on `$NF` parses the 4-column and 6-column layouts alike.
#   Rows SDKMAN marks "local only" are dropped: those versions sit in the candidates dir but the
#   API no longer serves them, so they are not available to install, and every consumer of this
#   catalog means exactly that. Left in, one that sorted above the newest remote row for its major
#   would make install_latest_tem_jdk hand `sdk install java` an undownloadable artifact and make
#   prune_tem_jdks_for_major_version keep it while uninstalling the current one (#304).
#   The marker is matched by shape rather than by column, for the same reason `$NF` is: it is a
#   `+` among the Use column's `> * +` glyphs today and was the literal text `local only` in the
#   six-column layout's Status column. No other cell can collide — a Version always carries
#   digits, an Identifier ends in `-tem`, and a Vendor is alphabetic.
# Output: stdout — lines with fields: major;version;artifact-id
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::fetch_tem_jdk_catalog() {
  args::check_no_args "$@"
  sdk list java \
    | awk --field-separator '|' 'NF >= 4 && $NF ~ /-tem[[:space:]]*$/ {
      for (i = 1; i <= NF; i++) {
        marker = $i
        gsub(/^[ \t]+|[ \t]+$/, "", marker)
        if ((marker ~ /^[>*+ ]+$/ && marker ~ /\+/) || marker == "local only") next
      }
      gsub(/^[ \t]+|[ \t]+$/, "", $3)
      gsub(/^[ \t]+|[ \t]+$/, "", $NF)
      match($3, /^[0-9]+/)
      if (RSTART == 0) next
      print substr($3, RSTART, RLENGTH) ";" $3 ";" $NF
    }'
}

# @description Print the path of this process's Temurin catalog memo file.
#   Keyed on $$, which — unlike BASHPID — is stable inside subshells and pipeline segments, so
#   every caller in a pipeline resolves the same path. Lives under XDG_RUNTIME_DIR because that
#   directory is per-user and mode 0700, so a predictable filename there carries none of the
#   symlink-hijack risk the same name would carry in a world-writable /tmp.
# Output: stdout — absolute path to this process's memo file
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::catalog_cache_file() {
  args::check_no_args "$@"
  printf '%s/sdkman-tem-jdk-catalog.%s' "${XDG_RUNTIME_DIR}" "$$"
}

# @description Print the Temurin JDK catalog, fetching it at most once per process.
#   The memo is a file rather than a variable because callers invoke this from inside pipelines,
#   and a pipeline segment runs in a subshell whose variable writes are discarded — a variable
#   memo would never register a single hit.
# Output: stdout — lines with fields: major;version;artifact-id
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_tem_jdk_catalog() {
  args::check_no_args "$@"
  local cache_file
  cache_file="$(sdkman_jdks::catalog_cache_file)"
  readonly cache_file
  # PIDs get recycled and XDG_RUNTIME_DIR survives until the user's last session ends, so a memo
  # left by an earlier same-PID process can outlive it. /proc/$$ is stamped at process start and
  # does not change, so a memo not newer than it belongs to a dead namesake and must be refetched.
  if [[ ! "${cache_file}" -nt "/proc/$$" ]]; then
    local catalog_tmp
    files::create_temp catalog_tmp
    # Fetch to a temp file and promote it only on success, so a failed or partial response is
    # never cached for the rest of the process. The check must be explicit rather than left to
    # errexit: callers reach this from `if`/`||` contexts (e.g.
    # sdkman_jdks::check_available_tem_jdk_major_version), and errexit is disabled inside a
    # function invoked that way. Partial output is still emitted, matching what the bare
    # `sdk list java | awk` pipeline did before the memo existed.
    if ! sdkman_jdks::fetch_tem_jdk_catalog > "${catalog_tmp}"; then
      cat "${catalog_tmp}"
      return 1
    fi
    files::move_no_prompt_quiet "${catalog_tmp}" "${cache_file}"
  fi
  cat "${cache_file}"
}

# @description Print all available Temurin JDKs in semicolon-delimited format, newest first.
#   The catalog half is memoized per process, so this costs at most one `sdk list java` round-trip
#   per run no matter how many times it is called. The installed column is re-derived from the
#   candidates dir on every call, so it stays correct across installs and uninstalls within a run
#   and the memo never needs invalidating.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_all_tem_jdks() {
  args::check_no_args "$@"
  local -a catalog_lines
  local catalog_tmp
  files::create_temp catalog_tmp
  sdkman_jdks::get_tem_jdk_catalog > "${catalog_tmp}"
  mapfile -t catalog_lines < "${catalog_tmp}"
  local catalog_line artifact_id
  for catalog_line in "${catalog_lines[@]}"; do
    artifact_id="${catalog_line##*;}"
    if sdkman_jdks::is_tem_jdk_artifact_installed "${artifact_id}"; then
      printf '%s;y\n' "${catalog_line}"
    else
      printf '%s;n\n' "${catalog_line}"
    fi
  done
}

### FILTERING

# @description Filter formatted JDK lines (from stdin) to only those marked as installed.
# Output: stdout — matching lines in semicolon-delimited format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::filter_for_installed() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '$4 == "y"'
}

# @description Filter formatted JDK lines (from stdin) to only those matching the given major version.
# Output: stdout — matching lines in semicolon-delimited format
# @arg $1 major version number
function sdkman_jdks::filter_for_major_version() {
  args::check_exactly_1_arg "$@"
  args::check_for_stdin
  awk --field-separator ';' --assign "major_version=$1" '$1 == major_version'
}

# @description Filter formatted JDK lines (from stdin) to retain only the first (latest) entry per major version.
# Output: stdout — one line per major version in semicolon-delimited format
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::filter_for_latest_per_major_version() {
  args::check_no_args "$@"
  args::check_for_stdin
  awk --field-separator ';' '!seen[$1]++'
}

### GET FIELDS

# @description Extract the major version field (column 1) from semicolon-delimited JDK lines on stdin.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_tem_jdk_major_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=1
}

# @description Extract the full version field (column 2) from semicolon-delimited JDK lines on stdin.
# Output: stdout — version strings, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_tem_jdk_version_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=2
}

# @description Extract the artifact ID field (column 3) from semicolon-delimited JDK lines on stdin.
# Output: stdout — artifact IDs, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_tem_jdk_artifact_id_field() {
  args::check_no_args "$@"
  args::check_for_stdin
  cut --delimiter ';' --fields=3
}

### AVAILABLE JDKS

# @description Print the latest available Temurin JDK entry per major version in semicolon-delimited format.
# Output: stdout — one line per major version: major;version;artifact-id;installed('y'/'n')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_latest_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version
}

# @description Print the latest available Temurin JDK entry for the given major version in semicolon-delimited format.
# Output: stdout — one line: major;version;artifact-id;installed('y'/'n')
# @arg $1 major java version
function sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_available_tem_jdk_major_version "${major_version}"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version \
    | sdkman_jdks::filter_for_major_version "${major_version}"
}

# @description Print all available Temurin JDK major version numbers, sorted numerically.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_available_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_all_tem_jdks \
    | sdkman_jdks::get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

# @description Print the highest available Temurin JDK major version number.
# Output: stdout — major version number (e.g. "21")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_latest_available_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_available_tem_jdk_major_versions \
    | text::last_line
}

# @description Die if the given major version is not available in the SDKMAN Temurin JDK list.
# @arg $1 major java version
function sdkman_jdks::check_available_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  if ! sdkman_jdks::get_available_tem_jdk_major_versions | grep::contains_word "${major_version}"; then
    log::die "Java version ${major_version} is not available"
  fi
}

### INSTALLED JDKS

# @description Print all installed Temurin JDK entries in semicolon-delimited format, newest first.
#   Reads the SDKMAN candidates directory rather than `sdk list java`, so it performs no network I/O
#   — `sdk list java` issues an uncached HTTPS request to the SDKMAN API on every invocation, which
#   dominated the runtime of every caller that looped over installed JDKs.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_installed_tem_jdks() {
  args::check_no_args "$@"
  local -r java_candidates_dir="${SDKMAN_CANDIDATES_DIR}/java"
  local candidate_dir artifact_id version major_version
  # An unmatched glob stays literal, so the dir check doubles as the missing/empty-dir guard.
  # The `current` symlink is excluded by the `*-tem` pattern, not by the dir check.
  for candidate_dir in "${java_candidates_dir}"/*-tem; do
    dirs::exists "${candidate_dir}" || continue
    artifact_id="${candidate_dir##*/}"
    version="${artifact_id%-tem}"
    major_version="$(sdkman_jdks::get_jdk_major_version "${version}")"
    printf '%s;%s;%s;y\n' "${major_version}" "${version}" "${artifact_id}"
  done \
    | sort --version-sort --reverse
}

# @description Print installed Temurin JDK entries for the given major version in semicolon-delimited format.
# Output: stdout — lines with fields: major;version;artifact-id;installed('y')
# @arg $1 major version
function sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::get_formatted_installed_tem_jdks \
    | sdkman_jdks::filter_for_major_version "${major_version}"
}

# @description Print the latest installed Temurin JDK entry per major version in semicolon-delimited format.
# Output: stdout — one line per major version: major;version;artifact-id;installed('y')
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_installed_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version
}

# @description Print the latest installed Temurin JDK entry for the given major version in semicolon-delimited format.
# Output: stdout — one line: major;version;artifact-id;installed('y')
# @arg $1 major java version
function sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_installed_tem_jdk_major_version "${major_version}"
  sdkman_jdks::get_formatted_installed_tem_jdks \
    | sdkman_jdks::filter_for_latest_per_major_version \
    | sdkman_jdks::filter_for_major_version "${major_version}"
}

# @description Print all installed Temurin JDK major version numbers, sorted numerically.
# Output: stdout — major version numbers, one per line
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_installed_tem_jdk_major_versions() {
  args::check_no_args "$@"
  sdkman_jdks::get_formatted_installed_tem_jdks \
    | sdkman_jdks::get_formatted_tem_jdk_major_version_field \
    | sort --numeric-sort \
    | uniq
}

# @description Print the highest installed Temurin JDK major version number.
# Output: stdout — major version number (e.g. "21")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_latest_installed_tem_jdk_major_version() {
  args::check_no_args "$@"
  sdkman_jdks::get_installed_tem_jdk_major_versions \
    | text::last_line
}

# @description Die if the given major version has no installed Temurin JDK.
# @arg $1 major java version
function sdkman_jdks::check_installed_tem_jdk_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  if ! sdkman_jdks::get_installed_tem_jdk_major_versions | grep::contains_word "${major_version}"; then
    log::die "Java version ${major_version} is not installed"
  fi
}

# @description Return true if a Temurin JDK with the given artifact ID is currently installed.
#   A direct candidate-dir test rather than a scan of the formatted installed list: this is called
#   once per catalog line while annotating sdkman_jdks::get_formatted_all_tem_jdks, where the
#   pipeline form would fork several processes per line.
# @arg $1 artifact ID (e.g. "21.0.3-tem")
# @exitcode 0 if true
# @exitcode 1 if false
function sdkman_jdks::is_tem_jdk_artifact_installed() {
  args::check_exactly_1_arg "$@"
  local -r artifact_id="$1"
  [[ "${artifact_id}" == *-tem ]] && dirs::exists "${SDKMAN_CANDIDATES_DIR}/java/${artifact_id}"
}

# @description Print the artifact ID of the latest installed Temurin JDK for the given major version.
# Output: stdout — artifact ID (e.g. "21.0.3-tem")
# @arg $1 major java version
function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "${major_version}" \
    | text::first_line \
    | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
}

### INSTALLING JDKS

# @description Install the latest available Temurin JDK for the given major version.
# @arg $1 major version
function sdkman_jdks::install_latest_tem_jdk() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_available_tem_jdk_major_version "${major_version}"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly latest_artifact_id
  sdkman_jdks::install_jdk "${latest_artifact_id}"
}

# @description Install the latest available Temurin JDK for every available major version.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::install_latest_tem_jdks() {
  args::check_no_args "$@"
  local -a major_versions
  local major_versions_tmp
  files::create_temp major_versions_tmp
  sdkman_jdks::get_available_tem_jdk_major_versions > "${major_versions_tmp}"
  mapfile -t major_versions < "${major_versions_tmp}"
  for major_version in "${major_versions[@]}"; do
    sdkman_jdks::install_latest_tem_jdk "${major_version}"
  done
}

### SETTING DEFAULT JDK

# @description Set the SDKMAN default java to the latest installed Temurin JDK for the given major version.
# @arg $1 major java version
function sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  sdkman_jdks::check_installed_tem_jdk_major_version "${major_version}"
  local new_default_artifact_id
  new_default_artifact_id="$(
    sdkman_jdks::get_formatted_latest_installed_tem_jdk_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly new_default_artifact_id
  sdkman_jdks::set_default_jdk_by_id "${new_default_artifact_id}"
}

# @description Return true if a default java is currently set (the SDKMAN java/current symlink exists).
# @exitcode 0 if a default java is set
# @exitcode 1 if no default java is set
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::has_default_jdk() {
  args::check_no_args "$@"
  symlinks::exists "${SDKMAN_CANDIDATES_DIR}/java/current"
}

# @description Print the major version of the current default java. Dies if no default is set.
# Output: stdout — major version number (e.g. "17")
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::get_current_default_jdk_major_version() {
  args::check_no_args "$@"
  local target
  target="$(symlinks::get_target "${SDKMAN_CANDIDATES_DIR}/java/current")"
  readonly target
  local -r artifact="${target##*/}"
  sdkman_jdks::get_jdk_major_version "${artifact}"
}

# @description Set the SDKMAN default java to the latest installed Temurin JDK of the current default's major version.
# Falls back to the highest installed major version when no default is currently set.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::set_default_jdk_to_latest_patch_of_current_major() {
  args::check_no_args "$@"
  local major_version
  if sdkman_jdks::has_default_jdk; then
    major_version="$(sdkman_jdks::get_current_default_jdk_major_version)"
  else
    major_version="$(sdkman_jdks::get_latest_installed_tem_jdk_major_version)"
  fi
  readonly major_version
  sdkman_jdks::set_default_sdk_to_latest_installed_for_major_version "${major_version}"
}

### PRUNE JDKS

# @description Uninstall all installed Temurin JDKs for the given major version except the latest available.
# @arg $1 major java version
function sdkman_jdks::prune_tem_jdks_for_major_version() {
  args::check_exactly_1_arg "$@"
  local -r major_version="$1"
  local latest_artifact_id
  latest_artifact_id="$(
    sdkman_jdks::get_formatted_latest_available_tem_jdk_for_major_version "${major_version}" \
      | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field
  )"
  readonly latest_artifact_id
  local -a artifact_ids
  local artifact_ids_tmp
  files::create_temp artifact_ids_tmp
  sdkman_jdks::get_formatted_installed_tem_jdks_for_major_version "${major_version}" \
    | sdkman_jdks::get_formatted_tem_jdk_artifact_id_field \
      > "${artifact_ids_tmp}"
  mapfile -t artifact_ids < "${artifact_ids_tmp}"
  for artifact_id in "${artifact_ids[@]}"; do
    if [[ "${artifact_id}" != "${latest_artifact_id}" ]]; then
      sdkman_jdks::uninstall_jdk "${artifact_id}"
    fi
  done
}

# @description Uninstall all outdated installed Temurin JDKs across every installed major version.
# shellcheck disable=SC2120 # called with no args by callers, shellcheck can't see all call sites
# @noargs
function sdkman_jdks::prune_tem_jdks() {
  args::check_no_args "$@"
  local -a major_versions
  local major_versions_tmp
  files::create_temp major_versions_tmp
  sdkman_jdks::get_installed_tem_jdk_major_versions > "${major_versions_tmp}"
  mapfile -t major_versions < "${major_versions_tmp}"
  for major_version in "${major_versions[@]}"; do
    sdkman_jdks::prune_tem_jdks_for_major_version "${major_version}"
  done
}
