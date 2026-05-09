#!/usr/bin/env bats

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
}

# Helper: invoke a fn via bash -c with stdin fed from a string.
prompt_via_stdin() {
  local -r stdin_str="$1"
  local -r cmd="$2"
  shift 2
  # shellcheck disable=SC2016 # single quotes intentional: $1+ expand in child shell
  run bash -c "
    source '${SCRIPTS_DIR}/functions.bash'
    ${cmd}
  " _ "$@" <<< "${stdin_str}"
}

# ---------- prompt::yn (default Y) ----------

@test "yn: auto_answer accepts default Y -> success" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run prompt::yn 'Continue?'
  assert_success
}

@test "yn: typed 'y' -> success" {
  prompt_via_stdin 'y' "prompt::yn 'Continue?'"
  assert_success
}

@test "yn: typed 'Y' -> success" {
  prompt_via_stdin 'Y' "prompt::yn 'Continue?'"
  assert_success
}

@test "yn: typed 'n' -> failure" {
  prompt_via_stdin 'n' "prompt::yn 'Continue?'"
  assert_failure
}

@test "yn: typed 'N' -> failure" {
  prompt_via_stdin 'N' "prompt::yn 'Continue?'"
  assert_failure
}

@test "yn: blank input accepts default Y -> success" {
  prompt_via_stdin '' "prompt::yn 'Continue?'"
  assert_success
}

@test "yn: dies with 0 args" {
  run prompt::yn
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "yn: dies with 2 args" {
  run prompt::yn 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- prompt::ny (default N) ----------

@test "ny: auto_answer accepts default N -> failure" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run prompt::ny 'Delete everything?'
  assert_failure
}

@test "ny: typed 'y' -> success" {
  prompt_via_stdin 'y' "prompt::ny 'Delete?'"
  assert_success
}

@test "ny: typed 'Y' -> success" {
  prompt_via_stdin 'Y' "prompt::ny 'Delete?'"
  assert_success
}

@test "ny: typed 'n' -> failure" {
  prompt_via_stdin 'n' "prompt::ny 'Delete?'"
  assert_failure
}

@test "ny: blank input accepts default N -> failure" {
  prompt_via_stdin '' "prompt::ny 'Delete?'"
  assert_failure
}

@test "ny: dies with 0 args" {
  run prompt::ny
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- prompt::for_value ----------

@test "for_value: typed value with default echoes typed" {
  prompt_via_stdin 'typed' "prompt::for_value 'Name' 'default-val'"
  assert_success
  [[ "${output}" == *'typed'* ]]
}

@test "for_value: blank input with default echoes default" {
  prompt_via_stdin '' "prompt::for_value 'Name' 'default-val'"
  assert_success
  [[ "${output}" == *'default-val'* ]]
}

@test "for_value: auto_answer with default echoes default" {
  # shellcheck disable=SC2030,SC2031
  export SCRIPTS_AUTO_ANSWER=y # intentional: export reaches child process via `run`
  run prompt::for_value 'Name' 'default-val'
  assert_success
  [[ "${output}" == *'default-val'* ]]
}

@test "for_value: typed value without default echoes typed" {
  prompt_via_stdin 'typed' "prompt::for_value 'Name'"
  assert_success
  [[ "${output}" == *'typed'* ]]
}

@test "for_value: dies with 0 args" {
  run prompt::for_value
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

@test "for_value: dies with 3 args" {
  run prompt::for_value 'a' 'b' 'c'
  assert_failure
  assert_output --partial 'Expected at most 2 arguments'
}
