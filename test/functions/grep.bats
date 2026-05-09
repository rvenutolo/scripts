#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091 # resolved via SCRIPTS_DIR set by common.bash
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/grep.bash"
}

# Run a stdin-required grep variant against a given haystack.
# $1 = function name
# $2 = haystack (piped to function)
# $3 = needle / pattern
function run_stdin_grep() {
  local -r fn="$1"
  local -r haystack="$2"
  local -r needle="$3"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; printf '%s' \"\$1\" | ${fn} \"\$2\"" _ "${haystack}" "${needle}"
}

# ---------- grep::contains_exactly ----------

@test "contains_exactly: needle present" {
  run_stdin_grep 'grep::contains_exactly' 'hello world' 'world'
  assert_success
}

@test "contains_exactly: needle absent" {
  run_stdin_grep 'grep::contains_exactly' 'hello world' 'xyz'
  assert_failure
}

@test "contains_exactly: regex meta is treated literally" {
  run_stdin_grep 'grep::contains_exactly' 'a.b' 'a.b'
  assert_success
}

@test "contains_exactly: regex meta does not match wildcard" {
  run_stdin_grep 'grep::contains_exactly' 'aXb' 'a.b'
  assert_failure
}

@test "contains_exactly: case-sensitive (does not match different case)" {
  run_stdin_grep 'grep::contains_exactly' 'HELLO' 'hello'
  assert_failure
}

@test "contains_exactly: dies with 0 args" {
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; printf '%s' 'data' | grep::contains_exactly"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "contains_exactly: dies with 2 args" {
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; printf '%s' 'data' | grep::contains_exactly 'a' 'b'"
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- grep::contains_exactly_ignore_case ----------

@test "contains_exactly_ignore_case: matches different case" {
  run_stdin_grep 'grep::contains_exactly_ignore_case' 'HELLO' 'hello'
  assert_success
}

@test "contains_exactly_ignore_case: matches mixed case" {
  run_stdin_grep 'grep::contains_exactly_ignore_case' 'HeLLo' 'hElLo'
  assert_success
}

@test "contains_exactly_ignore_case: still fails on missing needle" {
  run_stdin_grep 'grep::contains_exactly_ignore_case' 'HELLO' 'xyz'
  assert_failure
}

@test "contains_exactly_ignore_case: regex meta still literal" {
  run_stdin_grep 'grep::contains_exactly_ignore_case' 'aXb' 'a.b'
  assert_failure
}

# ---------- grep::contains_regex ----------

@test "contains_regex: simple regex matches" {
  run_stdin_grep 'grep::contains_regex' 'foobar' '^foo'
  assert_success
}

@test "contains_regex: anchored regex fails when not at start" {
  run_stdin_grep 'grep::contains_regex' 'xfoobar' '^foo'
  assert_failure
}

@test "contains_regex: regex meta works (dot matches any)" {
  run_stdin_grep 'grep::contains_regex' 'aXb' 'a.b'
  assert_success
}

@test "contains_regex: character class works" {
  run_stdin_grep 'grep::contains_regex' 'a5b' 'a[0-9]b'
  assert_success
}

@test "contains_regex: case-sensitive" {
  run_stdin_grep 'grep::contains_regex' 'FOO' 'foo'
  assert_failure
}

@test "contains_regex: multi-line haystack matches one line" {
  run_stdin_grep 'grep::contains_regex' $'one\ntwo\nthree' '^two$'
  assert_success
}

# ---------- grep::contains_regex_ignore_case ----------

@test "contains_regex_ignore_case: case-insensitive match" {
  run_stdin_grep 'grep::contains_regex_ignore_case' 'FOO' '^foo'
  assert_success
}

@test "contains_regex_ignore_case: still fails when pattern absent" {
  run_stdin_grep 'grep::contains_regex_ignore_case' 'FOO' '^bar'
  assert_failure
}

# ---------- grep::contains_perl_regex ----------

@test "contains_perl_regex: \\d matches digit" {
  run_stdin_grep 'grep::contains_perl_regex' 'a5b' '\d'
  assert_success
}

@test "contains_perl_regex: lookahead works" {
  run_stdin_grep 'grep::contains_perl_regex' 'foobar' 'foo(?=bar)'
  assert_success
}

@test "contains_perl_regex: lookahead fails when not followed" {
  run_stdin_grep 'grep::contains_perl_regex' 'foobaz' 'foo(?=bar)'
  assert_failure
}

@test "contains_perl_regex: case-sensitive by default" {
  run_stdin_grep 'grep::contains_perl_regex' 'FOO' '\bfoo\b'
  assert_failure
}

# ---------- grep::contains_perl_regex_ignore_case ----------

@test "contains_perl_regex_ignore_case: case-insensitive perl match" {
  run_stdin_grep 'grep::contains_perl_regex_ignore_case' 'FOO5' '\d'
  assert_success
}

@test "contains_perl_regex_ignore_case: case-insensitive word match" {
  run_stdin_grep 'grep::contains_perl_regex_ignore_case' 'FOO BAR' '\bfoo\b'
  assert_success
}

# ---------- grep::contains_word ----------

@test "contains_word: word match" {
  run_stdin_grep 'grep::contains_word' 'foo bar baz' 'bar'
  assert_success
}

@test "contains_word: substring is NOT a word match" {
  run_stdin_grep 'grep::contains_word' 'foobar' 'foo'
  assert_failure
}

@test "contains_word: word at start matches" {
  run_stdin_grep 'grep::contains_word' 'foo bar' 'foo'
  assert_success
}

@test "contains_word: word at end matches" {
  run_stdin_grep 'grep::contains_word' 'foo bar' 'bar'
  assert_success
}

@test "contains_word: regex meta is literal in word mode" {
  run_stdin_grep 'grep::contains_word' 'a.b foo' 'a.b'
  assert_success
}

@test "contains_word: case-sensitive" {
  run_stdin_grep 'grep::contains_word' 'FOO BAR' 'foo'
  assert_failure
}

# ---------- grep::contains_word_ignore_case ----------

@test "contains_word_ignore_case: matches different case" {
  run_stdin_grep 'grep::contains_word_ignore_case' 'FOO BAR' 'foo'
  assert_success
}

@test "contains_word_ignore_case: still requires word boundary" {
  run_stdin_grep 'grep::contains_word_ignore_case' 'FOOBAR' 'foo'
  assert_failure
}

# ---------- grep::contains_word_regex ----------

@test "contains_word_regex: regex matched as whole word" {
  run_stdin_grep 'grep::contains_word_regex' 'foo bar baz' 'b.r'
  assert_success
}

@test "contains_word_regex: regex matching part of larger word fails" {
  run_stdin_grep 'grep::contains_word_regex' 'foobar' 'foo'
  assert_failure
}

@test "contains_word_regex: case-sensitive" {
  run_stdin_grep 'grep::contains_word_regex' 'FOO' 'foo'
  assert_failure
}

# ---------- grep::contains_word_regex_ignore_case ----------

@test "contains_word_regex_ignore_case: case-insensitive regex word match" {
  run_stdin_grep 'grep::contains_word_regex_ignore_case' 'FOO BAR' 'b.r'
  assert_success
}

@test "contains_word_regex_ignore_case: word boundary still enforced" {
  run_stdin_grep 'grep::contains_word_regex_ignore_case' 'FOOBAR' 'b.r'
  assert_failure
}

# ---------- File-variant helpers ----------

# Helper: run a file-variant grep with given file content.
# $1 = function name
# $2 = file content (written to BATS_TEST_TMPDIR/in)
# $3 = needle/pattern
run_file_grep() {
  printf '%s' "$2" > "${BATS_TEST_TMPDIR}/in"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; $1 \"\$1\" \"\$2\"" _ "${BATS_TEST_TMPDIR}/in" "$3"
}

# ---------- grep::file_contains_exactly ----------

@test "file_contains_exactly: needle present" {
  run_file_grep 'grep::file_contains_exactly' 'hello world' 'world'
  assert_success
}

@test "file_contains_exactly: needle absent" {
  run_file_grep 'grep::file_contains_exactly' 'hello world' 'xyz'
  assert_failure
}

@test "file_contains_exactly: regex meta literal" {
  run_file_grep 'grep::file_contains_exactly' 'a.b' 'a.b'
  assert_success
}

@test "file_contains_exactly: case-sensitive" {
  run_file_grep 'grep::file_contains_exactly' 'HELLO' 'hello'
  assert_failure
}

@test "file_contains_exactly: dies on missing file" {
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; grep::file_contains_exactly /nonexistent 'x'"
  assert_failure
}

@test "file_contains_exactly: dies with 0 args" {
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; grep::file_contains_exactly"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "file_contains_exactly: dies with 1 arg" {
  printf '%s' 'data' > "${BATS_TEST_TMPDIR}/in"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; grep::file_contains_exactly \"\$1\"" _ "${BATS_TEST_TMPDIR}/in"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

@test "file_contains_exactly: dies with 3 args" {
  printf '%s' 'data' > "${BATS_TEST_TMPDIR}/in"
  run bash -c "source '${SCRIPTS_DIR}/functions.bash'; grep::file_contains_exactly \"\$1\" 'a' 'b'" _ "${BATS_TEST_TMPDIR}/in"
  assert_failure
  assert_output --partial 'Expected exactly 2 arguments'
}

# ---------- grep::file_contains_exactly_ignore_case ----------

@test "file_contains_exactly_ignore_case: matches different case" {
  run_file_grep 'grep::file_contains_exactly_ignore_case' 'HELLO' 'hello'
  assert_success
}

@test "file_contains_exactly_ignore_case: still fails on missing" {
  run_file_grep 'grep::file_contains_exactly_ignore_case' 'HELLO' 'xyz'
  assert_failure
}

# ---------- grep::file_contains_regex ----------

@test "file_contains_regex: anchored match" {
  run_file_grep 'grep::file_contains_regex' 'foobar' '^foo'
  assert_success
}

@test "file_contains_regex: anchored mismatch" {
  run_file_grep 'grep::file_contains_regex' 'xfoobar' '^foo'
  assert_failure
}

@test "file_contains_regex: dot matches any" {
  run_file_grep 'grep::file_contains_regex' 'aXb' 'a.b'
  assert_success
}

@test "file_contains_regex: multi-line file matches single line" {
  run_file_grep 'grep::file_contains_regex' $'one\ntwo\nthree' '^two$'
  assert_success
}

@test "file_contains_regex: case-sensitive" {
  run_file_grep 'grep::file_contains_regex' 'FOO' 'foo'
  assert_failure
}

# ---------- grep::file_contains_regex_ignore_case ----------

@test "file_contains_regex_ignore_case: case-insensitive match" {
  run_file_grep 'grep::file_contains_regex_ignore_case' 'FOO' '^foo'
  assert_success
}

# ---------- grep::file_contains_perl_regex ----------

@test "file_contains_perl_regex: \\d matches digit" {
  run_file_grep 'grep::file_contains_perl_regex' 'a5b' '\d'
  assert_success
}

@test "file_contains_perl_regex: lookahead works" {
  run_file_grep 'grep::file_contains_perl_regex' 'foobar' 'foo(?=bar)'
  assert_success
}

@test "file_contains_perl_regex: case-sensitive" {
  run_file_grep 'grep::file_contains_perl_regex' 'FOO' '\bfoo\b'
  assert_failure
}

# ---------- grep::file_contains_perl_regex_ignore_case ----------

@test "file_contains_perl_regex_ignore_case: case-insensitive perl match" {
  run_file_grep 'grep::file_contains_perl_regex_ignore_case' 'FOO BAR' '\bfoo\b'
  assert_success
}

# ---------- grep::file_contains_word ----------

@test "file_contains_word: word match" {
  run_file_grep 'grep::file_contains_word' 'foo bar baz' 'bar'
  assert_success
}

@test "file_contains_word: substring is not a word match" {
  run_file_grep 'grep::file_contains_word' 'foobar' 'foo'
  assert_failure
}

@test "file_contains_word: case-sensitive" {
  run_file_grep 'grep::file_contains_word' 'FOO BAR' 'foo'
  assert_failure
}

# ---------- grep::file_contains_word_ignore_case ----------

@test "file_contains_word_ignore_case: matches different case" {
  run_file_grep 'grep::file_contains_word_ignore_case' 'FOO BAR' 'foo'
  assert_success
}

@test "file_contains_word_ignore_case: requires word boundary" {
  run_file_grep 'grep::file_contains_word_ignore_case' 'FOOBAR' 'foo'
  assert_failure
}

# ---------- grep::file_contains_word_regex ----------

@test "file_contains_word_regex: regex matches whole word" {
  run_file_grep 'grep::file_contains_word_regex' 'foo bar baz' 'b.r'
  assert_success
}

@test "file_contains_word_regex: regex partial-word fails" {
  run_file_grep 'grep::file_contains_word_regex' 'foobar' 'foo'
  assert_failure
}

@test "file_contains_word_regex: case-sensitive" {
  run_file_grep 'grep::file_contains_word_regex' 'FOO' 'foo'
  assert_failure
}

# ---------- grep::file_contains_word_regex_ignore_case ----------

@test "file_contains_word_regex_ignore_case: case-insensitive word regex" {
  run_file_grep 'grep::file_contains_word_regex_ignore_case' 'FOO BAR' 'b.r'
  assert_success
}

@test "file_contains_word_regex_ignore_case: word boundary still enforced" {
  run_file_grep 'grep::file_contains_word_regex_ignore_case' 'FOOBAR' 'b.r'
  assert_failure
}
