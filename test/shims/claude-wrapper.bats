bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  WRAPPER="${REPO_DIR}/scripts/non-interactive/claude"
  # A stub `claude` that prints the PATH it was exec'd with, then the argv the
  # wrapper handed it. path_shim prepends its bin dir to PATH, and
  # commands::executable_path strips only the repo's non-interactive/interactive/other
  # dirs, so the stub is what resolves. PATH stays the first line: the PATH-prepend
  # tests below assert on index 0.
  path_shim::mkbin
  cat > "${BATS_TEST_TMPDIR}/bin/claude" << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "${PATH}"
printf 'ARGS=%s\n' "$*"
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/claude"
  FIX="${BATS_TEST_TMPDIR}/fixture"
  mkdir --parents "${FIX}/real-shims"
  ln --symbolic "${FIX}/real-shims" "${FIX}/link-shims"
  REAL_SHIMS="$(cd -P -- "${FIX}/real-shims" && pwd -P)"
  # The wrapper derives the config dir from PWD unless CLAUDE_CONFIG_DIR is
  # set; set it so the test needs neither WORK_PROJECTS_DIR nor XDG_CONFIG_HOME.
  export CLAUDE_CONFIG_DIR="${BATS_TEST_TMPDIR}/cfg"
}

# run_wrapper <shims-dir> [args...] — BASH_ENV=SAFE_BASH_ENV so a child bash does
# not re-source ~/.bashrc and re-prepend the real PATH ahead of the stub claude.
run_wrapper() {
  local -r shims="$1"
  shift
  run env BASH_ENV="${SAFE_BASH_ENV}" \
    CLAUDE_SHIMS_DIR_OVERRIDE="${shims}" "${WRAPPER}" "$@"
}

@test "prepends the physical shim dir as the first PATH entry" {
  run_wrapper "${FIX}/link-shims"
  assert_success
  assert_line --index 0 --regexp "^${REAL_SHIMS}:"
  refute_output --partial 'guard inactive'
}

@test "warns and still execs claude when the shim dir is missing" {
  run_wrapper "${FIX}/absent"
  assert_success
  assert_output --partial 'claude shims dir missing'
  assert_output --partial 'guard inactive'
  refute_output --partial "${FIX}/absent:"
}

@test "resolves claude before the prepend: a claude inside the shim dir is never chosen" {
  cat > "${FIX}/real-shims/claude" << 'EOF'
#!/usr/bin/env bash
printf 'SHIM_CLAUDE_RAN\n'
EOF
  chmod +x "${FIX}/real-shims/claude"
  run_wrapper "${FIX}/real-shims"
  assert_success
  refute_output --partial 'SHIM_CLAUDE_RAN'
  assert_line --index 0 --regexp "^${REAL_SHIMS}:"
}

@test "passes --model opus[1m] --effort high ahead of the caller's arguments" {
  # /model and /effort persist their choice into settings.json, so without these
  # pins a one-off switch becomes every later session's default.
  run_wrapper "${FIX}/real-shims" --print 'hello'
  assert_success
  assert_line 'ARGS=--model opus[1m] --effort high --print hello'
}

@test "passes the pins even with no caller arguments" {
  run_wrapper "${FIX}/real-shims"
  assert_success
  assert_line 'ARGS=--model opus[1m] --effort high'
}

@test "the pinned model precedes a caller's own --model, which wins last" {
  # Claude Code parses --model last-wins, so the caller's value must come second.
  run_wrapper "${FIX}/real-shims" --model sonnet
  assert_success
  assert_line 'ARGS=--model opus[1m] --effort high --model sonnet'
}

@test "the pinned effort precedes a caller's own --effort, which wins last" {
  run_wrapper "${FIX}/real-shims" --effort max
  assert_success
  assert_line 'ARGS=--model opus[1m] --effort high --effort max'
}

# ---------- herdr orchestration ----------

# install_herdr_stub — a fake `herdr` that records every invocation to
# herdr.calls (space-joined args, one line per call) and answers the subset of
# subcommands the wrapper drives. `status server` reports running once the
# `server` subcommand has been called (unless server-broken exists, which models
# a server that never comes up); `workspace create` returns the JSON shape the
# real 0.8.2 CLI emits; a bare call (the TUI attach) prints ATTACHED. Written
# with a heredoc rather than path_shim::add so the tmpdir paths are baked in.
install_herdr_stub() {
  path_shim::mkbin
  cat > "${BATS_TEST_TMPDIR}/bin/herdr" << EOF
#!/usr/bin/env bash
# A bare call (the TUI attach) is recorded as ATTACH: bats drops an empty
# trailing line from \${lines[@]}, so an empty record could not be asserted.
printf '%s\n' "\${*:-ATTACH}" >> "${BATS_TEST_TMPDIR}/herdr.calls"
case "\${1:-}" in
  status)
    if [[ -e "${BATS_TEST_TMPDIR}/server-up" ]]; then
      printf 'status: running\n'
    else
      printf 'status: not running\n'
    fi
    ;;
  server)
    if [[ ! -e "${BATS_TEST_TMPDIR}/server-broken" ]]; then
      touch "${BATS_TEST_TMPDIR}/server-up"
    fi
    ;;
  workspace)
    printf '%s\n' '{"id":"cli:workspace:create","result":{"root_pane":{"pane_id":"w7:p1","workspace_id":"w7"},"workspace":{"workspace_id":"w7"}}}'
    ;;
  pane) ;;
  '') printf 'ATTACHED\n' ;;
  *)
    printf 'unexpected herdr subcommand: %s\n' "\$*" >&2
    exit 99
    ;;
esac
EOF
  chmod +x "${BATS_TEST_TMPDIR}/bin/herdr"
}

# run_wrapper_tty <shims-dir> [args...] — like run_wrapper, but under a
# pseudo-terminal from util-linux `script`, so stdin and stdout are TTYs and the
# wrapper takes its interactive branch. Extra environment assignments go in the
# TTY_ENV array (default empty). Every word is %q-quoted because `script
# --command` hands the string to a shell.
TTY_ENV=()
run_wrapper_tty() {
  local -r shims="$1"
  shift
  local cmd
  cmd="$(printf '%q ' env "BASH_ENV=${SAFE_BASH_ENV}" "CLAUDE_SHIMS_DIR_OVERRIDE=${shims}" \
    "${TTY_ENV[@]}" "${WRAPPER}" "$@")"
  run script --quiet --return --command "${cmd}" '/dev/null'
}

@test "herdr: without a TTY, claude is exec'd directly and herdr is never called" {
  install_herdr_stub
  run_wrapper "${FIX}/real-shims" 'hello'
  assert_success
  assert_output --partial 'ARGS=--model opus[1m] --effort high hello'
  assert [ ! -e "${BATS_TEST_TMPDIR}/herdr.calls" ]
}

@test "herdr: inside a herdr pane (HERDR_ENV=1), claude is exec'd directly" {
  install_herdr_stub
  TTY_ENV=('HERDR_ENV=1')
  run_wrapper_tty "${FIX}/real-shims" 'hello'
  assert_success
  assert_output --partial 'ARGS=--model opus[1m] --effort high hello'
  assert [ ! -e "${BATS_TEST_TMPDIR}/herdr.calls" ]
}

@test "herdr: CLAUDE_NO_HERDR=1 is an escape hatch to a direct exec" {
  install_herdr_stub
  TTY_ENV=('CLAUDE_NO_HERDR=1')
  run_wrapper_tty "${FIX}/real-shims" 'hello'
  assert_success
  assert_output --partial 'ARGS=--model opus[1m] --effort high hello'
  assert [ ! -e "${BATS_TEST_TMPDIR}/herdr.calls" ]
}

@test "herdr: when herdr is not installed, claude is exec'd directly" {
  run_wrapper_tty "${FIX}/real-shims" 'hello'
  assert_success
  assert_output --partial 'ARGS=--model opus[1m] --effort high hello'
}

@test "herdr: non-session flags bypass herdr" {
  install_herdr_stub
  local flag
  for flag in '-p' '--print' '-h' '--help' '-v' '--version' '--bg'; do
    run_wrapper_tty "${FIX}/real-shims" "${flag}" 'hello'
    assert_success
    assert_output --partial "ARGS=--model opus[1m] --effort high ${flag} hello"
  done
  assert [ ! -e "${BATS_TEST_TMPDIR}/herdr.calls" ]
}

@test "herdr: a subcommand anywhere in the args bypasses herdr" {
  install_herdr_stub
  local sub
  for sub in agents attach auth auto-mode doctor gateway import install logs mcp plugin plugins \
    project respawn rm setup-token stop kill ultrareview update; do
    run_wrapper_tty "${FIX}/real-shims" "${sub}" 'list'
    assert_success
    assert_output --partial "ARGS=--model opus[1m] --effort high ${sub} list"
  done
  assert [ ! -e "${BATS_TEST_TMPDIR}/herdr.calls" ]
}

@test "herdr: cold start launches the server, waits for it, and attaches" {
  install_herdr_stub
  run_wrapper_tty "${FIX}/real-shims"
  assert_success
  assert_output --partial 'ATTACHED'
  refute_output --partial 'ARGS='
  run cat "${BATS_TEST_TMPDIR}/herdr.calls"
  assert_line --index 0 'status server'
  assert_line 'server'
  assert_line --regexp '^workspace create '
  assert_line --regexp '^pane run w7:p1 claude$'
  # The final call is the bare attach.
  assert_line --index "$((${#lines[@]} - 1))" 'ATTACH'
}

@test "herdr: a running server is not started again" {
  install_herdr_stub
  touch "${BATS_TEST_TMPDIR}/server-up"
  run_wrapper_tty "${FIX}/real-shims"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/herdr.calls"
  refute_line 'server'
  assert_line --index 0 'status server'
  assert_line --index 1 --regexp '^workspace create '
}

@test "herdr: the workspace is created for PWD, labeled by basename, with the derived config dir" {
  install_herdr_stub
  touch "${BATS_TEST_TMPDIR}/server-up"
  run_wrapper_tty "${FIX}/real-shims"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/herdr.calls"
  assert_line "workspace create --cwd ${PWD} --label ${PWD##*/} --env CLAUDE_CONFIG_DIR=${CLAUDE_CONFIG_DIR} --focus"
}

@test "herdr: caller args are shell-quoted before being typed into the pane" {
  install_herdr_stub
  touch "${BATS_TEST_TMPDIR}/server-up"
  run_wrapper_tty "${FIX}/real-shims" '--resume' 'a b' "it's"
  assert_success
  run cat "${BATS_TEST_TMPDIR}/herdr.calls"
  assert_line "pane run w7:p1 claude '--resume' 'a b' 'it'\\''s'"
}

@test "herdr: the model and effort pins are not forwarded (the inner wrapper adds them)" {
  install_herdr_stub
  touch "${BATS_TEST_TMPDIR}/server-up"
  run_wrapper_tty "${FIX}/real-shims" 'hello'
  assert_success
  run cat "${BATS_TEST_TMPDIR}/herdr.calls"
  assert_line "pane run w7:p1 claude 'hello'"
  refute_output --partial '--model'
  refute_output --partial '--effort'
}

@test "herdr: dies when the server never comes up" {
  install_herdr_stub
  touch "${BATS_TEST_TMPDIR}/server-broken"
  run_wrapper_tty "${FIX}/real-shims"
  assert_failure
  assert_output --partial 'herdr server did not start'
  refute_output --partial 'ATTACHED'
  refute_output --partial 'ARGS='
}
