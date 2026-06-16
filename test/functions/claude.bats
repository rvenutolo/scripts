#!/usr/bin/env bats

# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell; CLAUDE_CONFIG_DIR mutations are intentional and correctly scoped per-test

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/env.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/misc.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/claude.bash"
}

# Write a session jsonl fixture with cwd, gitBranch, and two distinct last-prompt lines.
make_full_session() {
  local -r path="${BATS_TEST_TMPDIR}/full.jsonl"
  {
    printf '%s\n' '{"type":"user","cwd":"/home/me/proj","gitBranch":"main"}'
    printf '%s\n' '{"type":"last-prompt","lastPrompt":"first thing"}'
    printf '%s\n' '{"type":"assistant","cwd":"/home/me/other"}'
    printf '%s\n' '{"type":"last-prompt","lastPrompt":"second thing"}'
    printf '%s\n' '{"type":"last-prompt","lastPrompt":"third thing"}'
  } > "${path}"
  printf '%s\n' "${path}"
}

# Write a session jsonl fixture with no last-prompt lines and no cwd/gitBranch.
make_empty_session() {
  local -r path="${BATS_TEST_TMPDIR}/empty.jsonl"
  {
    printf '%s\n' '{"type":"user"}'
    printf '%s\n' '{"type":"assistant"}'
  } > "${path}"
  printf '%s\n' "${path}"
}

# Write a session jsonl fixture whose cwd/gitBranch/lastPrompt values are JSON null.
# A trailing last-prompt line with a null lastPrompt mirrors real session-end markers.
make_null_session() {
  local -r path="${BATS_TEST_TMPDIR}/null.jsonl"
  {
    printf '%s\n' '{"type":"user","cwd":null,"gitBranch":null}'
    printf '%s\n' '{"type":"last-prompt","lastPrompt":"real prompt"}'
    printf '%s\n' '{"type":"last-prompt","lastPrompt":null}'
  } > "${path}"
  printf '%s\n' "${path}"
}

# ---------- claude::encode_path ----------

@test "encode_path: config-style path replaces / and ." {
  run claude::encode_path '/home/x/.config/y'
  assert_success
  assert_output '-home-x--config-y'
}

@test "encode_path: lone slash -> dash" {
  run claude::encode_path '/'
  assert_success
  assert_equal "${output}" '-'
}

@test "encode_path: dotted path replaces every dot" {
  run claude::encode_path '/a/b.c.d/e'
  assert_success
  assert_output '-a-b-c-d-e'
}

@test "encode_path: trailing slash" {
  run claude::encode_path '/home/x/'
  assert_success
  assert_output '-home-x-'
}

@test "encode_path: relative path (no leading slash)" {
  run claude::encode_path 'a/b.c'
  assert_success
  assert_output 'a-b-c'
}

@test "encode_path: empty string -> empty" {
  run claude::encode_path ''
  assert_success
  assert_output ''
}

@test "encode_path: dies with 0 args" {
  run claude::encode_path
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "encode_path: dies with 2 args" {
  run claude::encode_path a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- claude::session_cwd ----------

@test "session_cwd: prints first cwd value" {
  local f
  f="$(make_full_session)"
  run claude::session_cwd "${f}"
  assert_success
  assert_output '/home/me/proj'
}

@test "session_cwd: empty when no cwd field" {
  local f
  f="$(make_empty_session)"
  run claude::session_cwd "${f}"
  assert_success
  assert_output ''
}

@test "session_cwd: empty when cwd value is JSON null" {
  local f
  f="$(make_null_session)"
  run claude::session_cwd "${f}"
  assert_success
  assert_output ''
}

@test "session_cwd: dies on missing file" {
  run claude::session_cwd "${BATS_TEST_TMPDIR}/nope.jsonl"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "session_cwd: dies with 0 args" {
  run claude::session_cwd
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "session_cwd: dies with 2 args" {
  run claude::session_cwd a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- claude::session_branch ----------

@test "session_branch: prints first gitBranch value" {
  local f
  f="$(make_full_session)"
  run claude::session_branch "${f}"
  assert_success
  assert_output 'main'
}

@test "session_branch: empty when no gitBranch field" {
  local f
  f="$(make_empty_session)"
  run claude::session_branch "${f}"
  assert_success
  assert_output ''
}

@test "session_branch: empty when gitBranch value is JSON null" {
  local f
  f="$(make_null_session)"
  run claude::session_branch "${f}"
  assert_success
  assert_output ''
}

@test "session_branch: dies on missing file" {
  run claude::session_branch "${BATS_TEST_TMPDIR}/nope.jsonl"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "session_branch: dies with 0 args" {
  run claude::session_branch
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "session_branch: dies with 2 args" {
  run claude::session_branch a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- claude::session_first_prompt ----------

@test "session_first_prompt: prints first last-prompt value" {
  local f
  f="$(make_full_session)"
  run claude::session_first_prompt "${f}"
  assert_success
  assert_output 'first thing'
}

@test "session_first_prompt: empty when no last-prompt lines" {
  local f
  f="$(make_empty_session)"
  run claude::session_first_prompt "${f}"
  assert_success
  assert_output ''
}

@test "session_first_prompt: dies on missing file" {
  run claude::session_first_prompt "${BATS_TEST_TMPDIR}/nope.jsonl"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "session_first_prompt: dies with 0 args" {
  run claude::session_first_prompt
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "session_first_prompt: dies with 2 args" {
  run claude::session_first_prompt a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- claude::session_last_prompt ----------

@test "session_last_prompt: prints last last-prompt value" {
  local f
  f="$(make_full_session)"
  run claude::session_last_prompt "${f}"
  assert_success
  assert_output 'third thing'
}

@test "session_last_prompt: differs from first prompt" {
  local f
  f="$(make_full_session)"
  local first last
  first="$(claude::session_first_prompt "${f}")"
  last="$(claude::session_last_prompt "${f}")"
  assert_equal "${first}" 'first thing'
  assert_equal "${last}" 'third thing'
  [[ "${first}" != "${last}" ]]
}

@test "session_last_prompt: skips trailing null lastPrompt, returns last real value" {
  local f
  f="$(make_null_session)"
  run claude::session_last_prompt "${f}"
  assert_success
  assert_output 'real prompt'
}

@test "session_last_prompt: empty when no last-prompt lines" {
  local f
  f="$(make_empty_session)"
  run claude::session_last_prompt "${f}"
  assert_success
  assert_output ''
}

@test "session_last_prompt: dies on missing file" {
  run claude::session_last_prompt "${BATS_TEST_TMPDIR}/nope.jsonl"
  assert_failure
  assert_output --partial 'does not exist'
}

@test "session_last_prompt: dies with 0 args" {
  run claude::session_last_prompt
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "session_last_prompt: dies with 2 args" {
  run claude::session_last_prompt a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- claude::projects_dir ----------

@test "projects_dir: prints CLAUDE_CONFIG_DIR/projects" {
  export CLAUDE_CONFIG_DIR=/tmp/whatever
  run claude::projects_dir
  assert_success
  assert_output '/tmp/whatever/projects'
}

@test "projects_dir: dies when CLAUDE_CONFIG_DIR empty" {
  CLAUDE_CONFIG_DIR='' run claude::projects_dir
  assert_failure
  assert_output --partial 'CLAUDE_CONFIG_DIR not set'
}

@test "projects_dir: dies with 1 arg" {
  export CLAUDE_CONFIG_DIR=/tmp/whatever
  run claude::projects_dir extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}
