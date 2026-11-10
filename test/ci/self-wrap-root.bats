bats_require_minimum_version 1.5.0

# The self-wrapping gate scripts take their repository root from their own
# canonical path, never from the caller's working directory, so a gate started
# through a symlink, from a subdirectory, or from inside another repository
# grades the repository it belongs to. The behavioural cases run with
# IN_DEVSHELL and SCRIPTS_DIR set by common.bash, as the devShell sets them, so
# no case re-runs through .ci/in-devshell.

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/check-scripts"
  LINK_DIR="${BATS_TEST_TMPDIR}/bin"
  mkdir -- "${LINK_DIR}"
  ln --symbolic -- "${CHECK}" "${LINK_DIR}/check-scripts"
}

# Print the tracked files that re-run themselves through .ci/in-devshell, one
# repo-relative path per line.
wrapped_scripts() {
  local -r tracked_tmp="${BATS_TEST_TMPDIR}/tracked"
  # A read-only listing of the real repository, not a fixture, so git_fixture
  # (confined to BATS_TEST_TMPDIR) does not apply.
  git -C "${REPO_DIR}" ls-files -z > "${tracked_tmp}"
  local -a tracked=()
  mapfile -d '' -t tracked < "${tracked_tmp}"
  local path
  for path in "${tracked[@]}"; do
    if [[ "${path}" == test/* || ! -f "${REPO_DIR}/${path}" || -L "${REPO_DIR}/${path}" ]]; then
      continue
    fi
    if grep --quiet --extended-regexp '^[[:space:]]*exec .*in-devshell' -- "${REPO_DIR}/${path}"; then
      printf '%s\n' "${path}"
    fi
  done
}

@test "self-wrap: every wrapped script takes its repo root from its own path" {
  local -r scripts_tmp="${BATS_TEST_TMPDIR}/wrapped"
  wrapped_scripts > "${scripts_tmp}"
  local -a scripts=()
  mapfile -t scripts < "${scripts_tmp}"
  # A discovery that finds nothing would pass vacuously.
  assert [ "${#scripts[@]}" -gt 0 ]
  local failures='' path depth expected line stripped found_repo seen_test slashes i
  for path in "${scripts[@]}"; do
    slashes="${path//[^\/]/}"
    depth="${#slashes}"
    # shellcheck disable=SC2016 # the literal source text the script must carry
    expected='SELF_REPO="${SELF_PATH%'
    for ((i = 0; i <= depth; i++)); do
      expected+='/*'
    done
    expected+='}"'
    found_repo='n'
    seen_test='n'
    while IFS= read -r line; do
      stripped="${line#"${line%%[![:space:]]*}"}"
      if [[ "${stripped}" == \#* ]]; then
        continue
      fi
      if [[ "${stripped}" == *'rev-parse --show-toplevel'* && "${stripped}" != *'git -C '* && "${stripped}" != *'# cwd-root:'* ]]; then
        failures+=" ${path}(cwd root)"
      fi
      if [[ "${seen_test}" == 'n' && "${stripped}" == "${expected}" ]]; then
        found_repo='y'
      fi
      if [[ "${stripped}" == if*IN_DEVSHELL* ]]; then
        seen_test='y'
      fi
    done < "${REPO_DIR}/${path}"
    if [[ "${found_repo}" == 'n' ]]; then
      failures+=" ${path}(no SELF_REPO at depth ${depth})"
    fi
  done
  assert_equal "${failures}" ''
}

@test "self-wrap: a check run through a symlink from outside any repo grades its own repo" {
  mkdir -- "${BATS_TEST_TMPDIR}/elsewhere"
  cd "${BATS_TEST_TMPDIR}/elsewhere" || return 1
  run "${LINK_DIR}/check-scripts"
  assert_success
  refute_output --partial 'not a git repository'
}

@test "self-wrap: a check run through a symlink from another repo grades its own repo" {
  local -r other="${BATS_TEST_TMPDIR}/other"
  git_fixture::init "${other}"
  # An executable with no shdoc header, which check-shdoc-headers rejects.
  printf '#!/usr/bin/env bash\necho PAYLOAD_RAN\n' > "${other}/undocumented"
  chmod +x -- "${other}/undocumented"
  git_fixture::run "${other}" add --all
  cd "${other}" || return 1
  run "${LINK_DIR}/check-scripts"
  assert_success
  refute_output --partial 'undocumented'
}

@test "self-wrap: a check's path arguments stay relative to the caller's directory" {
  mkdir -- "${BATS_TEST_TMPDIR}/elsewhere"
  printf '#!/usr/bin/env bash\necho PAYLOAD_RAN\n' > "${BATS_TEST_TMPDIR}/elsewhere/clean"
  cd "${BATS_TEST_TMPDIR}/elsewhere" || return 1
  run "${LINK_DIR}/check-scripts" 'clean'
  assert_success
}
