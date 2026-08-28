setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  # Capture the real check path BEFORE any cd into the fixture repo — REPO_DIR
  # from common.bash points at the real repo here, and the tests cd away.
  CHECK="${REPO_DIR}/.ci/check-nameref-convention"
  REPO="${BATS_TEST_TMPDIR}/repo"

  mkdir --parents "${REPO}/scripts/functions" "${REPO}/scripts/other"
  git_fixture::init "${REPO}"

  # shell_scripts::find exits 1 on an empty scan and find_root_only requires a
  # root-level script, so the fixture needs one even though it binds no nameref.
  printf '#!/usr/bin/env bash\ntrue\n' > "${REPO}/run-thing"
  chmod +x "${REPO}/run-thing"
  # A compliant binding, so the default tree passes and each test adds exactly
  # one violation of its own.
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '__topic_fill_ref' guard
}

# Write a library file at ${REPO}/$1 defining function $2, which binds a nameref
# named $3. Pass `guard` as $4 for the shared-helper guard, `inline` for the
# standalone bracket-test form, or omit it for no guard at all.
#
# Every line is composed through printf rather than written literally, because
# the lint under test scans the real repo tree — including this .bats file — so
# a literal binding line here would be reported as a violation of the real tree.
# shellcheck disable=SC2016 # the $1/${out_name} inside these format strings are fixture text, not expansions
write_helper() {
  local -r path="$1"
  local -r func="$2"
  local -r name="$3"
  local -r guard="${4:-}"
  {
    printf '#!/usr/bin/env bash\n\n'
    printf 'function %s() {\n' "${func}"
    printf '  %s -r out_name="$1"\n' 'local'
    case "${guard}" in
      guard) printf "  namerefs::assert_available \"\${out_name}\" '%s'\n" "${name}" ;;
      inline) printf "  if [[ \"\$1\" == '%s' ]]; then exit 125; fi\n" "${name}" ;;
      *) ;;
    esac
    printf '  %s -n %s="${out_name}"\n' 'local' "${name}"
    printf '  %s=()\n' "${name}"
    printf '}\n'
  } > "${REPO}/${path}"
}

# Append a second, role-suffixed binding to the helper written above.
# shellcheck disable=SC2016 # the $1/${out_name} inside these format strings are fixture text, not expansions
add_second_binding() {
  local -r path="$1"
  local -r func="$2"
  local -r name="$3"
  {
    printf '\nfunction %s() {\n' "${func}"
    printf '  %s -r a_name="$1"\n' 'local'
    printf '  %s -r b_name="$2"\n' 'local'
    printf "  namerefs::assert_available \"\${a_name}\" '%s_first_ref'\n" "${name}"
    printf "  namerefs::assert_available \"\${b_name}\" '%s_second_ref'\n" "${name}"
    printf '  %s -n %s_first_ref="${a_name}"\n' 'local' "${name}"
    printf '  %s -n %s_second_ref="${b_name}"\n' 'local' "${name}"
    printf '}\n'
  } >> "${REPO}/${path}"
}

# Run the check against the fixture repo. Must cd first so the check's
# `git rev-parse --show-toplevel` resolves to the fixture.
run_check() {
  cd "${REPO}" || return 1
  run "${CHECK}" "$@"
}

@test "passes on a clean fixture tree" {
  run_check
  assert_success
  refute_output
}

@test "fails when the bound name does not follow the convention" {
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '_out_ref' guard
  run_check
  assert_failure 1
  assert_output --partial 'scripts/functions/topic.bash'
  assert_output --partial 'must be named __topic_fill_ref'
}

@test "fails when a correctly named binding has no guard" {
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '__topic_fill_ref'
  run_check
  assert_failure 1
  assert_output --partial 'has no guard'
  assert_output --partial '__topic_fill_ref'
}

@test "reports both rules when a binding is misnamed and unguarded" {
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '_out_ref'
  run_check
  assert_failure 1
  assert_output --partial 'must be named __topic_fill_ref'
  assert_output --partial 'has no guard'
}

@test "accepts the standalone inline bracket-test guard" {
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '__topic_fill_ref' inline
  run_check
  assert_success
}

@test "accepts a role-suffixed name when one function binds two namerefs" {
  add_second_binding 'scripts/functions/topic.bash' 'topic::pair' '__topic_pair'
  run_check
  assert_success
}

@test "a guard naming a different nameref does not satisfy the guard rule" {
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '__topic_fill_ref' guard
  # Point the guard at some other reserved name: it parses as a guard, but not
  # for the name actually bound, which is exactly how a rename desyncs the two.
  sed --in-place "s/'__topic_fill_ref'/'__topic_other_ref'/" "${REPO}/scripts/functions/topic.bash"
  run_check
  assert_failure 1
  assert_output --partial 'has no guard'
}

@test "declare -n and typeset -n are matched, not just local -n" {
  local kw
  for kw in declare typeset; do
    {
      printf '#!/usr/bin/env bash\n\n'
      printf 'function topic::fill() {\n'
      # shellcheck disable=SC2016 # the $1/${out_name} inside these format strings are fixture text, not expansions
      printf '  %s -n _out_ref="$1"\n' "${kw}"
      printf '}\n'
    } > "${REPO}/scripts/functions/topic.bash"
    run_check
    assert_failure 1
    assert_output --partial 'must be named __topic_fill_ref'
  done
}

@test "fails when a nameref is bound outside any function" {
  {
    printf '#!/usr/bin/env bash\n\n'
    # shellcheck disable=SC2016 # the $1/${out_name} inside these format strings are fixture text, not expansions
    printf '%s -n __loose_ref="$1"\n' 'declare'
  } > "${REPO}/scripts/functions/topic.bash"
  run_check
  assert_failure 1
  assert_output --partial 'bound outside any function'
}

@test "scripts/other/ is out of scope" {
  {
    printf '#!/usr/bin/env bash\n\n'
    printf 'function vendored::fill() {\n'
    # shellcheck disable=SC2016 # the $1/${out_name} inside these format strings are fixture text, not expansions
    printf '  %s -n _out_ref="$1"\n' 'local'
    printf '}\n'
  } > "${REPO}/scripts/other/vendored"
  chmod +x "${REPO}/scripts/other/vendored"
  run_check
  assert_success
}

@test "an EXEMPT entry suppresses the violation it names" {
  write_helper 'scripts/functions/topic.bash' 'topic::fill' '_out_ref' guard
  cd "${REPO}" || return 1
  run env EXEMPT_OVERRIDE='scripts/functions/topic.bash::_out_ref' "${CHECK}"
  assert_success
}

@test "an EXEMPT entry naming no such file is stale" {
  cd "${REPO}" || return 1
  run env EXEMPT_OVERRIDE='scripts/functions/gone.bash::__gone_ref' "${CHECK}"
  assert_failure 1
  assert_output --partial 'EXEMPT entry names no such file'
}

@test "an EXEMPT entry that suppresses no violation is stale" {
  cd "${REPO}" || return 1
  run env EXEMPT_OVERRIDE='scripts/functions/topic.bash::__topic_fill_ref' "${CHECK}"
  assert_failure 1
  assert_output --partial 'EXEMPT entry suppresses no violation'
}

@test "--help prints usage and exits 0" {
  run_check --help
  assert_success
  assert_output --partial 'nameref'
}

@test "rejects unexpected arguments" {
  run_check extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}
