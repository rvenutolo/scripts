# shellcheck disable=SC2016 # the fixture bodies below are literal .bats content; their ${...} and $(...) are text the lint must parse, never expansions

# Every fixture helper below is namespaced `fixture::`, which exists nowhere in
# scripts/functions/ or test/test_helper/. That is load bearing: this file's fixture
# bodies ARE vacuous arity tests by construction, and the lint scans the real tree
# including this file. Because `fixture::*` never resolves against the real guard
# map, the lint reaches this content, abstains, and stays silent. Using a real helper
# name in a fixture would make the lint flag its own test file.

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  load '../test_helper/git_fixture'
  CHECK="${REPO_DIR}/.ci/check-vacuous-arity-tests"
  FIXTURE_TEST="${BATS_TEST_TMPDIR}/test"
  FIXTURE_FUNCTIONS="${BATS_TEST_TMPDIR}/functions"
  mkdir --parents "${FIXTURE_TEST}/test_helper" "${FIXTURE_FUNCTIONS}"
  # The check resolves REPO_DIR via `git rev-parse --show-toplevel`, so it needs a
  # git repo as cwd. common.bash leaves cwd at BATS_TEST_TMPDIR, which is
  # deliberately not a repo (#248 hardening), so give it a throwaway fixture repo.
  FIXTURE_REPO="${BATS_TEST_TMPDIR}/repo"
  git_fixture::init "${FIXTURE_REPO}"
  cd "${FIXTURE_REPO}" || return 1
  # An empty EXEMPT by default: the shipped array is empty, and a test that seeds it
  # does so explicitly.
  export EXEMPT_OVERRIDE=''
  export TEST_DIR_OVERRIDE="${FIXTURE_TEST}"
  export FUNCTIONS_DIR_OVERRIDE="${FIXTURE_FUNCTIONS}"
}

# @description Append a guarded fixture helper to the fixture function library.
# @arg $1 name fully namespaced function name
# @arg $2 guard args::check_* suffix, e.g. exactly_1_arg
make_function() {
  local -r name="$1"
  local -r guard="$2"
  cat >> "${FIXTURE_FUNCTIONS}/fixture.bash" << EOF
function ${name}() {
  args::check_${guard} "\$@"
}
EOF
}

# @description Write a fixture .bats file from a literal body.
#              Fixture tests are written with a leading `%%` sentinel, translated to
#              `@test` here. A literal `@test` at column 0 cannot appear in this file:
#              BATS preprocesses its own source and would read the fixture strings as
#              real test definitions, truncating them at the first embedded one.
#              It also means the lint, scanning the real tree, sees no test blocks
#              here at all.
#
#              `@@STDERR@@` is a second sentinel of the same kind, translated to a
#              stderr expansion here. A fixture body that spelled the raw glob
#              literally would be flagged by check-stderr-assertions, which scans the
#              real tree and cannot tell a fixture string from an assertion. The
#              translated fixture on disk still carries the real glob, so what the
#              lint under test sees is unchanged. The substitution below is safe from
#              that rule itself because the rule requires a `[[` on the same line.
# @arg $1 body full file contents, with `%%` where `@test` belongs and `@@STDERR@@`
#         where a stderr expansion belongs
make_test() {
  printf '%s\n' "$1" | sed 's/^%%/@test/; s/@@STDERR@@/${stderr}/' > "${FIXTURE_TEST}/sample.bats"
}

# ---------- core detection rule ----------

@test "flags a bare assert_failure whose arg count violates its guard" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies with 2 args" {
  run fixture::takes_one a b
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'takes_one: dies with 2 args'
  assert_output --partial 'Expected exactly 1 argument'
}

@test "does not flag a call whose arg count satisfies its guard" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: returns false" {
  run fixture::takes_one a
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "does not flag a predicate-false test on a guarded helper" {
  make_function 'fixture::is_thing' 'exactly_1_arg'
  make_test '%% "is_thing: false for no" {
  run fixture::is_thing no
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "does not flag a violating call that already asserts the message" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies with 2 args" {
  run fixture::takes_one a b
  assert_failure
  assert_output --partial "Expected exactly 1 argument"
}'
  run "${CHECK}"
  assert_success
}

@test "does not flag a helper that declares no arity guard" {
  printf '%s\n' '#!/usr/bin/env bash' 'function fixture::unguarded() {' '  return 1' '}' \
    > "${FIXTURE_FUNCTIONS}/fixture.bash"
  make_test '%% "unguarded: fails" {
  run fixture::unguarded a b c
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

# ---------- guard kinds ----------

@test "no_args: flags a call with an argument" {
  make_function 'fixture::takes_none' 'no_args'
  make_test '%% "takes_none: dies with args" {
  run fixture::takes_none extra
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "at_most_1_arg: flags two args, allows zero and one" {
  make_function 'fixture::at_most_one' 'at_most_1_arg'
  make_test '%% "at_most_one: dies with 2" {
  run fixture::at_most_one a b
  assert_failure
}

%% "at_most_one: fine with 0" {
  run fixture::at_most_one
  assert_failure
}

%% "at_most_one: fine with 1" {
  run fixture::at_most_one a
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected at most 1 argument'
  assert_output --partial 'dies with 2'
  refute_output --partial 'fine with 0'
  refute_output --partial 'fine with 1'
}

@test "exactly_2_args: flags one arg and three args, allows two" {
  make_function 'fixture::takes_two' 'exactly_2_args'
  make_test '%% "takes_two: dies with 1" {
  run fixture::takes_two a
  assert_failure
}

%% "takes_two: dies with 3" {
  run fixture::takes_two a b c
  assert_failure
}

%% "takes_two: fine with 2" {
  run fixture::takes_two a b
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
  assert_output --partial 'dies with 1'
  assert_output --partial 'dies with 3'
  refute_output --partial 'fine with 2'
}

@test "at_least_2_args: flags one arg, allows two and three" {
  make_function 'fixture::at_least_two' 'at_least_2_args'
  make_test '%% "at_least_two: dies with 1" {
  run fixture::at_least_two a
  assert_failure
}

%% "at_least_two: fine with 2" {
  run fixture::at_least_two a b
  assert_failure
}

%% "at_least_two: fine with 3" {
  run fixture::at_least_two a b c
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
  assert_output --partial 'dies with 1'
  refute_output --partial 'fine with 2'
  refute_output --partial 'fine with 3'
}

@test "exactly_3_args and at_least_3_args report the plural message" {
  make_function 'fixture::takes_three' 'exactly_3_args'
  make_function 'fixture::at_least_three' 'at_least_3_args'
  make_test '%% "takes_three: dies with 2" {
  run fixture::takes_three a b
  assert_failure
}

%% "at_least_three: dies with 2" {
  run fixture::at_least_three a b
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected exactly 3 arguments'
  assert_output --partial 'Expected at least 3 arguments'
}

@test "at_least_1_arg reports the singular message" {
  make_function 'fixture::at_least_one' 'at_least_1_arg'
  make_test '%% "at_least_one: dies with 0" {
  run fixture::at_least_one
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

# ---------- what counts as an output assertion ----------

@test "assert_line clears the test" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies" {
  run fixture::takes_one a b
  assert_failure
  assert_line --partial "Expected"
}'
  run "${CHECK}"
  assert_success
}

@test "refute_output clears the test" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies" {
  run fixture::takes_one a b
  assert_failure
  refute_output --partial "unexpected"
}'
  run "${CHECK}"
  assert_success
}

@test "the stderr glob form clears the test" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies" {
  run --separate-stderr fixture::takes_one a b
  assert_failure
  [[ "@@STDERR@@" == *"Expected exactly 1 argument"* ]]
}'
  run "${CHECK}"
  assert_success
}

@test "assert_failure with an exit code is still vacuous" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies" {
  run fixture::takes_one a b
  assert_failure 1
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- pairing ----------

@test "pairs assert_failure with the nearest preceding run, not the whole body" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "two runs: the first is vacuous" {
  run fixture::takes_one a b
  assert_failure
  run cat /dev/null
  assert_output ""
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "reports both invocations when one test has two vacuous runs" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "two vacuous runs" {
  run fixture::takes_one
  assert_failure
  run fixture::takes_one a b
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'with 0 arg(s)'
  assert_output --partial 'with 2 arg(s)'
}

# ---------- abstentions ----------

@test "abstains on a dynamic argument list" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "dynamic" {
  run fixture::takes_one "${arr[@]}"
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "abstains on command substitution" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "cmdsub" {
  run fixture::takes_one "$(make_fixture "a.json" "{\"k\": \"v\"}")"
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "abstains on a run line that continues onto the next line" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "continued" {
  run fixture::takes_one "a
b"
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "treats ANSI-C quoting as a single argument" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "ansi-c" {
  run fixture::takes_one $'"'"' \t '"'"'
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "abstains on an external command" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "external" {
  run cat /nonexistent
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "abstains on a variable target" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "variable" {
  run "${CHECK}" extra
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "abstains on bash -c with trailing positional arguments" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "indirect" {
  run bash -c "fixture::takes_one \"\$1\"" _ /some/path
  assert_failure
}'
  run "${CHECK}"
  assert_success
}

@test "resolves the simple bash -c shape" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "dual mode: dies with 2 args" {
  run bash -c "source lib.bash; fixture::takes_one a b"
  assert_failure
}'
  run "${CHECK}"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- exemptions ----------

@test "an EXEMPT entry suppresses its invocation" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "takes_one: dies with 2 args" {
  run fixture::takes_one a b
  assert_failure
}'
  EXEMPT_OVERRIDE="${FIXTURE_TEST}/sample.bats::fixture::takes_one#2" run "${CHECK}"
  assert_success
}

@test "two space-separated EXEMPT entries both take effect" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "zero args" {
  run fixture::takes_one
  assert_failure
}

%% "two args" {
  run fixture::takes_one a b
  assert_failure
}'
  EXEMPT_OVERRIDE="${FIXTURE_TEST}/sample.bats::fixture::takes_one#0 ${FIXTURE_TEST}/sample.bats::fixture::takes_one#2" \
    run "${CHECK}"
  assert_success
}

@test "an EXEMPT entry naming no invocation is stale" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "clean" {
  run fixture::takes_one a
  assert_failure
}'
  EXEMPT_OVERRIDE='nowhere.bats::fixture::nope#9' run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

@test "an EXEMPT entry naming an unflagged invocation is stale" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "satisfies the guard" {
  run fixture::takes_one a
  assert_failure
}'
  EXEMPT_OVERRIDE="${FIXTURE_TEST}/sample.bats::fixture::takes_one#1" run "${CHECK}"
  assert_failure
  assert_output --partial 'stale EXEMPT entry'
}

# ---------- the lint's own contract ----------

@test "succeeds on a suite with no vacuous arity tests" {
  make_function 'fixture::takes_one' 'exactly_1_arg'
  make_test '%% "asserts properly" {
  run fixture::takes_one a b
  assert_failure
  assert_output --partial "Expected exactly 1 argument"
}'
  run "${CHECK}"
  assert_success
  assert_output ''
}

@test "dies when given an argument" {
  run "${CHECK}" extra
  assert_failure
  assert_output --partial 'Expected no arguments'
}

@test "--help exits 0 and names the script" {
  run "${CHECK}" --help
  assert_success
  assert_output --partial 'check-vacuous-arity-tests'
}
