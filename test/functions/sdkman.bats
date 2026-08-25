# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell; HOME mutations are intentional and correctly scoped per-test

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/text.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/grep.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/sdkman.bash"

  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdk() {
    printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/sdk.calls"
    if [[ -f "${BATS_TEST_TMPDIR}/sdk.stdout" ]]; then
      cat "${BATS_TEST_TMPDIR}/sdk.stdout"
    fi
  }
  export -f sdk
}

# ---------- clean_output ----------

@test "clean_output: strips ANSI and empty lines" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/strings.bash'
    source '${SCRIPTS_DIR}/functions/text.bash'
    source '${SCRIPTS_DIR}/functions/grep.bash'
    source '${SCRIPTS_DIR}/functions/sdkman.bash'
    printf '\033[0;32mhello\033[0m\n\nworld\n' | sdkman::clean_output
  "
  assert_success
  assert_line --index 0 'hello'
  assert_line --index 1 'world'
}

@test "clean_output: dies with args" {
  run bash -c "
    source '${SCRIPTS_DIR}/functions/log.bash'
    source '${SCRIPTS_DIR}/functions/args.bash'
    source '${SCRIPTS_DIR}/functions/strings.bash'
    source '${SCRIPTS_DIR}/functions/text.bash'
    source '${SCRIPTS_DIR}/functions/grep.bash'
    source '${SCRIPTS_DIR}/functions/sdkman.bash'
    printf 'x\n' | sdkman::clean_output extra
  "
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "clean_output: no output on empty stdin" {
  # BATS run redirects stdin from /dev/null (not a tty), so check_for_stdin passes;
  # the function succeeds with empty output when given empty stdin via run.
  run sdkman::clean_output < /dev/null
  assert_success
  assert_output ''
}

# ---------- update_metadata ----------

@test "update_metadata: invokes sdk update" {
  printf 'metadata refreshed\n' > "${BATS_TEST_TMPDIR}/sdk.stdout"
  run sdkman::update_metadata
  assert_success
  run cat "${BATS_TEST_TMPDIR}/sdk.calls"
  assert_output 'update'
}

@test "update_metadata: dies with args" {
  run sdkman::update_metadata extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- find_sdkmanrc_file ----------

@test "find_sdkmanrc_file: finds .sdkmanrc in the start directory" {
  mkdir --parents "${BATS_TEST_TMPDIR}/proj"
  touch "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  run sdkman::find_sdkmanrc_file "${BATS_TEST_TMPDIR}/proj"
  assert_success
  assert_output "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
}

@test "find_sdkmanrc_file: finds .sdkmanrc in an ancestor directory" {
  mkdir --parents "${BATS_TEST_TMPDIR}/proj/module/src"
  touch "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  run sdkman::find_sdkmanrc_file "${BATS_TEST_TMPDIR}/proj/module/src"
  assert_success
  assert_output "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
}

@test "find_sdkmanrc_file: nearest .sdkmanrc wins over a more distant ancestor" {
  mkdir --parents "${BATS_TEST_TMPDIR}/proj/module"
  touch "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  touch "${BATS_TEST_TMPDIR}/proj/module/.sdkmanrc"
  run sdkman::find_sdkmanrc_file "${BATS_TEST_TMPDIR}/proj/module"
  assert_success
  assert_output "${BATS_TEST_TMPDIR}/proj/module/.sdkmanrc"
}

@test "find_sdkmanrc_file: empty when no ancestor holds an .sdkmanrc" {
  mkdir --parents "${BATS_TEST_TMPDIR}/proj/module"
  run sdkman::find_sdkmanrc_file "${BATS_TEST_TMPDIR}/proj/module"
  assert_success
  assert_output ''
}

@test "find_sdkmanrc_file: terminates on a relative start directory holding the file" {
  touch "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::find_sdkmanrc_file '.'
  assert_success
  assert_output './.sdkmanrc'
}

@test "find_sdkmanrc_file: terminates on a relative start directory with no file" {
  # `dirname .` is `.`, so a missing termination guard would spin forever here.
  run sdkman::find_sdkmanrc_file '.'
  assert_success
  assert_output ''
}

@test "find_sdkmanrc_file: dies with no args" {
  run sdkman::find_sdkmanrc_file
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "find_sdkmanrc_file: dies with 2 args" {
  run sdkman::find_sdkmanrc_file "${BATS_TEST_TMPDIR}" extra
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- get_sdkmanrc_file_value ----------

@test "get_sdkmanrc_file_value: reads a plain key=value line" {
  printf 'java=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_value: reads a non-java key" {
  printf 'java=21.0.3-tem\ngradle=8.5\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'gradle'
  assert_success
  assert_output '8.5'
}

@test "get_sdkmanrc_file_value: tolerates whitespace around key, = and value" {
  printf '   java   =   21.0.3-tem   \n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_value: tolerates CRLF line endings" {
  printf 'java=21.0.3-tem\r\ngradle=8.5\r\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_value: ignores blank lines and whole-line comments" {
  printf '# Enable auto-env through the sdkman_auto_env config\n\n#java=99.0.0-tem\njava=21.0.3-tem\n' \
    > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_value: strips a spaced trailing comment" {
  printf 'java=21.0.3-tem # pinned for the enforcer\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_value: strips an unspaced trailing comment" {
  printf 'java=21.0.3-tem#pinned\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_value: last assignment of the key wins" {
  printf 'java=21.0.3-tem\njava=25.0.4-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output '25.0.4-tem'
}

@test "get_sdkmanrc_file_value: empty when the key is absent" {
  printf 'gradle=8.5\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output ''
}

@test "get_sdkmanrc_file_value: empty when the key is assigned an empty value" {
  printf 'java=\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output ''
}

@test "get_sdkmanrc_file_value: empty on an empty file" {
  : > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output ''
}

@test "get_sdkmanrc_file_value: does not match a key that merely starts with the requested one" {
  printf 'javafx=17.0.1-zulu\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java'
  assert_success
  assert_output ''
}

@test "get_sdkmanrc_file_value: dies when the file does not exist" {
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/nope" 'java'
  assert_failure
  assert_output --partial 'does not exist'
}

@test "get_sdkmanrc_file_value: dies with 1 arg" {
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "get_sdkmanrc_file_value: dies with 3 args" {
  run sdkman::get_sdkmanrc_file_value "${BATS_TEST_TMPDIR}/.sdkmanrc" 'java' extra
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- sdkmanrc_java_home ----------

@test "sdkmanrc_java_home: resolves the pinned JDK from the start directory" {
  export SDKMAN_DIR="${BATS_TEST_TMPDIR}/sdkman"
  mkdir --parents "${SDKMAN_DIR}/candidates/java/21.0.3-tem" "${BATS_TEST_TMPDIR}/proj"
  printf 'java=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  run sdkman::sdkmanrc_java_home "${BATS_TEST_TMPDIR}/proj"
  assert_success
  assert_output "${SDKMAN_DIR}/candidates/java/21.0.3-tem"
}

@test "sdkmanrc_java_home: resolves the pin from an ancestor of a submodule directory" {
  export SDKMAN_DIR="${BATS_TEST_TMPDIR}/sdkman"
  mkdir --parents "${SDKMAN_DIR}/candidates/java/25.0.4-tem" "${BATS_TEST_TMPDIR}/proj/module"
  printf 'java=25.0.4-tem\n' > "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  run sdkman::sdkmanrc_java_home "${BATS_TEST_TMPDIR}/proj/module"
  assert_success
  assert_output "${SDKMAN_DIR}/candidates/java/25.0.4-tem"
}

@test "sdkmanrc_java_home: empty when no ancestor holds an .sdkmanrc" {
  export SDKMAN_DIR="${BATS_TEST_TMPDIR}/sdkman"
  mkdir --parents "${SDKMAN_DIR}/candidates/java/21.0.3-tem" "${BATS_TEST_TMPDIR}/proj"
  run --separate-stderr sdkman::sdkmanrc_java_home "${BATS_TEST_TMPDIR}/proj"
  assert_success
  refute_output
  refute_stderr
}

@test "sdkmanrc_java_home: empty when .sdkmanrc declares no java key" {
  export SDKMAN_DIR="${BATS_TEST_TMPDIR}/sdkman"
  mkdir --parents "${SDKMAN_DIR}/candidates/java/21.0.3-tem" "${BATS_TEST_TMPDIR}/proj"
  printf 'gradle=8.5\n' > "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  run --separate-stderr sdkman::sdkmanrc_java_home "${BATS_TEST_TMPDIR}/proj"
  assert_success
  refute_output
  refute_stderr
}

@test "sdkmanrc_java_home: warns to stderr and prints nothing when the pinned JDK is not installed" {
  export SDKMAN_DIR="${BATS_TEST_TMPDIR}/sdkman"
  mkdir --parents "${SDKMAN_DIR}/candidates/java/21.0.3-tem" "${BATS_TEST_TMPDIR}/proj"
  printf 'java=99.0.0-tem\n' > "${BATS_TEST_TMPDIR}/proj/.sdkmanrc"
  run --separate-stderr sdkman::sdkmanrc_java_home "${BATS_TEST_TMPDIR}/proj"
  assert_success
  refute_output
  assert_stderr --partial 'pins java=99.0.0-tem'
  assert_stderr --partial 'not installed'
}

@test "sdkmanrc_java_home: dies with no args" {
  run sdkman::sdkmanrc_java_home
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "sdkmanrc_java_home: dies with 2 args" {
  run sdkman::sdkmanrc_java_home "${BATS_TEST_TMPDIR}" extra
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- get_sdkmanrc_file_java_artifact_id ----------

@test "get_sdkmanrc_file_java_artifact_id: extracts artifact id from .sdkmanrc" {
  printf 'java=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  assert_output '21.0.3-tem'
}

@test "get_sdkmanrc_file_java_artifact_id: empty when no java= entry" {
  printf 'gradle=8.5\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  assert_output ''
}

@test "get_sdkmanrc_file_java_artifact_id: dies when file missing" {
  run sdkman::get_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "get_sdkmanrc_file_java_artifact_id: dies with wrong arg count" {
  run sdkman::get_sdkmanrc_file_java_artifact_id
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "get_sdkmanrc_file_java_artifact_id: shares the tolerant parser (CRLF, spacing, trailing comment)" {
  printf '# pin\r\n  java  =  25.0.4-tem  # for the enforcer\r\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  assert_output '25.0.4-tem'
}

@test "get_sdkmanrc_file_java_artifact_id: last assignment wins" {
  printf 'java=21.0.3-tem\njava=25.0.4-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::get_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  assert_output '25.0.4-tem'
}

# ---------- overwrite_sdkmanrc_file_java_artifact_id ----------

@test "overwrite_sdkmanrc_file_java_artifact_id: rewrites java= line" {
  printf 'java=21.0.3-tem\ngradle=8.5\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" '21.0.5-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_line --index 0 'java=21.0.5-tem'
  assert_line --index 1 'gradle=8.5'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: dies when file missing" {
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/nope" '21'
  assert_failure
  assert_output --partial 'does not exist'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: dies with wrong arg count" {
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: rewrites an indented line, preserving indentation and spacing" {
  printf '  java  =  21.0.3-tem\ngradle=8.5\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" '21.0.5-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_line --index 0 '  java  =  21.0.5-tem'
  assert_line --index 1 'gradle=8.5'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: preserves a trailing comment" {
  printf 'java=21.0.3-tem # pinned for the enforcer\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" '21.0.5-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_output 'java=21.0.5-tem # pinned for the enforcer'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: preserves a CRLF line ending" {
  printf 'java=21.0.3-tem\r\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" '21.0.5-tem'
  assert_success
  run od --address-radix=n --format=c "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_output --partial '\r'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: leaves a whole-line comment untouched" {
  printf '#java=99.0.0-tem\njava=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" '21.0.5-tem'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_line --index 0 '#java=99.0.0-tem'
  assert_line --index 1 'java=21.0.5-tem'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: writes sed replacement metacharacters literally" {
  printf 'java=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  run sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" 'a&b/c\d'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_output 'java=a&b/c\d'
}

@test "overwrite_sdkmanrc_file_java_artifact_id: round-trips through the reader on a tolerant line shape" {
  # The invariant that keeps rewrite_sdkmanrc_file_java_version honest: anything the reader can find,
  # the writer can rewrite. A reader-only match makes the rewrite a silent no-op that reports success.
  printf '  java  =  21.0.3-tem  # pinned\r\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  sdkman::overwrite_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc" '25.0.4-tem'
  run sdkman::get_sdkmanrc_file_java_artifact_id "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  assert_output '25.0.4-tem'
}

# ---------- rewrite_sdkmanrc_file_java_version ----------

@test "rewrite_sdkmanrc_file_java_version: no-op when current artifact already installed" {
  printf 'java=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::is_tem_jdk_artifact_installed() { return 0; }
  export -f sdkman_jdks::is_tem_jdk_artifact_installed
  run sdkman::rewrite_sdkmanrc_file_java_version "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_output 'java=21.0.3-tem'
}

@test "rewrite_sdkmanrc_file_java_version: rewrites to latest installed when current absent" {
  printf 'java=21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::is_tem_jdk_artifact_installed() { return 1; }
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::get_jdk_major_version() { printf '21'; }
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() { printf '21.0.7-tem'; }
  export -f sdkman_jdks::is_tem_jdk_artifact_installed
  export -f sdkman_jdks::get_jdk_major_version
  export -f sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version
  run sdkman::rewrite_sdkmanrc_file_java_version "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_output 'java=21.0.7-tem'
}

@test "rewrite_sdkmanrc_file_java_version: dies when file missing" {
  run sdkman::rewrite_sdkmanrc_file_java_version "${BATS_TEST_TMPDIR}/nope"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "rewrite_sdkmanrc_file_java_version: dies with wrong arg count" {
  run sdkman::rewrite_sdkmanrc_file_java_version
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "rewrite_sdkmanrc_file_java_version: rewrites an indented java line" {
  printf '  java = 21.0.3-tem\n' > "${BATS_TEST_TMPDIR}/.sdkmanrc"
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::is_tem_jdk_artifact_installed() { return 1; }
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::get_jdk_major_version() { printf '21'; }
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() { printf '21.0.7-tem'; }
  export -f sdkman_jdks::is_tem_jdk_artifact_installed
  export -f sdkman_jdks::get_jdk_major_version
  export -f sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version
  run sdkman::rewrite_sdkmanrc_file_java_version "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/.sdkmanrc"
  assert_output '  java = 21.0.7-tem'
}

# ---------- list_all_sdkmanrc_files ----------

@test "list_all_sdkmanrc_files: returns sorted .sdkmanrc paths under HOME" {
  export HOME="${BATS_TEST_TMPDIR}/fakehome"
  mkdir --parents "${HOME}/proj1" "${HOME}/proj2/sub"
  touch "${HOME}/proj1/.sdkmanrc"
  touch "${HOME}/proj2/sub/.sdkmanrc"
  run sdkman::list_all_sdkmanrc_files
  assert_success
  assert_line --index 0 "${HOME}/proj1/.sdkmanrc"
  assert_line --index 1 "${HOME}/proj2/sub/.sdkmanrc"
}

@test "list_all_sdkmanrc_files: empty when none present" {
  export HOME="${BATS_TEST_TMPDIR}/emptyhome"
  mkdir --parents "${HOME}"
  run sdkman::list_all_sdkmanrc_files
  assert_success
  assert_output ''
}

@test "list_all_sdkmanrc_files: dies with args" {
  run sdkman::list_all_sdkmanrc_files extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- rewrite_sdkmanrc_file_java_versions ----------

@test "rewrite_sdkmanrc_file_java_versions: rewrites every .sdkmanrc under HOME" {
  export HOME="${BATS_TEST_TMPDIR}/fakehome"
  mkdir --parents "${HOME}/a" "${HOME}/b"
  printf 'java=21.0.3-tem\n' > "${HOME}/a/.sdkmanrc"
  printf 'java=21.0.3-tem\n' > "${HOME}/b/.sdkmanrc"
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::is_tem_jdk_artifact_installed() { return 1; }
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::get_jdk_major_version() { printf '21'; }
  # shellcheck disable=SC2329 # invoked indirectly via export -f by sdkman functions under test
  function sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version() { printf '21.0.7-tem'; }
  export -f sdkman_jdks::is_tem_jdk_artifact_installed
  export -f sdkman_jdks::get_jdk_major_version
  export -f sdkman_jdks::get_latest_installed_tem_jdk_artifact_id_for_major_version
  run sdkman::rewrite_sdkmanrc_file_java_versions
  assert_success
  run cat "${HOME}/a/.sdkmanrc"
  assert_output 'java=21.0.7-tem'
  run cat "${HOME}/b/.sdkmanrc"
  assert_output 'java=21.0.7-tem'
}

@test "rewrite_sdkmanrc_file_java_versions: no-op when no .sdkmanrc files present" {
  export HOME="${BATS_TEST_TMPDIR}/emptyhome"
  mkdir --parents "${HOME}"
  run sdkman::rewrite_sdkmanrc_file_java_versions
  assert_success
  assert_output ''
}

@test "rewrite_sdkmanrc_file_java_versions: dies with args" {
  run sdkman::rewrite_sdkmanrc_file_java_versions extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- init ----------

# Write a fake ${SDKMAN_DIR}/bin/sdkman-init.sh that exercises the two workarounds sdkman::init
# exists for: it calls `complete` at source time, and it reads an unbound variable. Both would
# abort a strict-mode script if sdkman::init had not relaxed things first.
fake_sdkman_dir() {
  local -r sdkman_dir="${BATS_TEST_TMPDIR}/sdkman"
  mkdir --parents "${sdkman_dir}/bin"
  cat > "${sdkman_dir}/bin/sdkman-init.sh" << 'INIT_EOF'
if [[ "$(type -t complete)" == 'function' ]]; then
  printf 'COMPLETE_STUBBED\n'
fi
complete -F _sdk sdk
printf 'UNBOUND_READ_OK:%s\n' "${DEFINITELY_NOT_SET_ANYWHERE}"
printf 'INIT_SOURCED\n'
function sdk() { printf 'sdk %s\n' "$*"; }
INIT_EOF
  printf '%s' "${sdkman_dir}"
}

# Run a snippet in a real strict-mode shell, the way production scripts invoke sdkman::init.
# A child shell is required because the behaviour under test *is* strict-mode state, which bats
# does not set. BASH_ENV is unset so a re-sourced ~/.bashrc cannot clobber SCRIPTS_DIR.
run_strict() {
  local -r snippet="$1"
  local -r script="${BATS_TEST_TMPDIR}/strict.bash"
  {
    printf '%s\n' 'set -Eeuo pipefail'
    printf '%s\n' "IFS=\$'\\n\\t'"
    # shellcheck disable=SC2016 # single quotes are deliberate: the snippet is evaluated by the child shell, not here
    printf '%s\n' 'source "${SCRIPTS_DIR}/.functions.bash"'
    printf '%s\n' 'log::enable_err_trap'
    printf '%s\n' "${snippet}"
  } > "${script}"
  run env --unset=BASH_ENV "SCRIPTS_DIR=${SCRIPTS_DIR}" "SDKMAN_DIR=$(fake_sdkman_dir)" bash "${script}"
}

@test "init: sources sdkman-init.sh and defines sdk" {
  run_strict '( sdkman::init; sdk hello )'
  assert_success
  assert_line --index 2 'INIT_SOURCED'
  assert_line --index 3 'sdk hello'
}

@test "init: stubs the complete builtin before sourcing" {
  run_strict '( sdkman::init )'
  assert_success
  assert_line --index 0 'COMPLETE_STUBBED'
}

@test "init: relaxes set -u for the calling subshell" {
  # The fake init reads an unbound variable; under set -u that would abort.
  run_strict '( sdkman::init )'
  assert_success
  assert_line --index 1 'UNBOUND_READ_OK:'
}

@test "init: detaches the ERR trap in the calling subshell" {
  # shellcheck disable=SC2016 # single quotes are deliberate: the snippet is evaluated by the child shell, not here
  run_strict '( sdkman::init; if [[ -z "$(trap -p ERR)" ]]; then printf "NO_ERR_TRAP\n"; else printf "ERR_TRAP_PRESENT\n"; fi )'
  assert_success
  assert_output --partial 'NO_ERR_TRAP'
}

@test "init: leaves the parent shell's strict mode untouched" {
  # shellcheck disable=SC2016 # single quotes are deliberate: the snippet is evaluated by the child shell, not here
  run_strict '( sdkman::init ) > /dev/null
case $- in *u*) printf "PARENT_STILL_U\n" ;; *) printf "PARENT_LOST_U\n" ;; esac
if [[ -n "$(trap -p ERR)" ]]; then printf "PARENT_KEPT_TRAP\n"; else printf "PARENT_LOST_TRAP\n"; fi'
  assert_success
  assert_line --index 0 'PARENT_STILL_U'
  assert_line --index 1 'PARENT_KEPT_TRAP'
}

@test "init: dies when called outside a subshell" {
  run_strict 'sdkman::init'
  assert_failure
  assert_output --partial 'must be called from inside a subshell'
}

# The run_strict tests above exercise sdkman::init in a real strict-mode child
# shell, which is the only place its strict-mode effects are observable. That
# child is a separate process, so nothing it runs is attributed to sdkman::init
# by the coverage harness (#310). This one drives the same body in-process:
# bats already forks each @test, so BASHPID differs from $$ and the
# subshell guard is satisfied without a child shell.
@test "init: sources sdkman-init.sh and stubs complete when run in-process" {
  local sdkman_dir
  sdkman_dir="$(fake_sdkman_dir)"
  SDKMAN_DIR="${sdkman_dir}" run sdkman::init
  assert_success
  assert_output --partial 'COMPLETE_STUBBED'
  assert_output --partial 'UNBOUND_READ_OK:'
  assert_output --partial 'INIT_SOURCED'
}

@test "init: dies with args" {
  run sdkman::init extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}
