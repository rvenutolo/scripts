#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091 # resolved via SCRIPTS_DIR set by common.bash
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
}

# ---------- strings::is_empty ----------

@test "is_empty: true for empty string" {
  run strings::is_empty ''
  assert_success
}

@test "is_empty: false for single space" {
  run strings::is_empty ' '
  assert_failure
}

@test "is_empty: false for non-empty string" {
  run strings::is_empty 'x'
  assert_failure
}

@test "is_empty: false for newline" {
  run strings::is_empty $'\n'
  assert_failure
}

@test "is_empty: dies with no args" {
  run strings::is_empty
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "is_empty: dies with two args" {
  run strings::is_empty 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- strings::is_not_empty ----------

@test "is_not_empty: false for empty string" {
  run strings::is_not_empty ''
  assert_failure
}

@test "is_not_empty: true for single char" {
  run strings::is_not_empty 'x'
  assert_success
}

@test "is_not_empty: true for whitespace-only" {
  run strings::is_not_empty '   '
  assert_success
}

# ---------- strings::is_blank ----------

@test "is_blank: true for empty string" {
  run strings::is_blank ''
  assert_success
}

@test "is_blank: true for single space" {
  run strings::is_blank ' '
  assert_success
}

@test "is_blank: true for tab" {
  run strings::is_blank $'\t'
  assert_success
}

@test "is_blank: true for newline" {
  run strings::is_blank $'\n'
  assert_success
}

@test "is_blank: true for mixed whitespace" {
  run strings::is_blank $' \t\n '
  assert_success
}

@test "is_blank: false for single non-space char" {
  run strings::is_blank 'x'
  assert_failure
}

@test "is_blank: false for whitespace surrounding non-space" {
  run strings::is_blank '  x  '
  assert_failure
}

# ---------- strings::trim ----------

@test "trim: empty string -> empty string" {
  run strings::trim ''
  assert_success
  assert_output ''
}

@test "trim: no whitespace -> unchanged" {
  run strings::trim 'hello'
  assert_success
  assert_output 'hello'
}

@test "trim: leading spaces stripped" {
  run strings::trim '   hello'
  assert_success
  assert_output 'hello'
}

@test "trim: trailing spaces stripped" {
  run strings::trim 'hello   '
  assert_success
  assert_output 'hello'
}

@test "trim: both sides stripped" {
  run strings::trim '   hello   '
  assert_success
  assert_output 'hello'
}

@test "trim: tabs and newlines stripped" {
  run strings::trim $'\t\n hello \t\n'
  assert_success
  assert_output 'hello'
}

@test "trim: internal whitespace preserved" {
  run strings::trim '  hello  world  '
  assert_success
  assert_output 'hello  world'
}

@test "trim: whitespace-only input -> empty string" {
  run strings::trim '   '
  assert_success
  assert_output ''
}

# ---------- strings::ensure_trailing_slash ----------

@test "ensure_trailing_slash: empty string -> empty string" {
  run strings::ensure_trailing_slash ''
  assert_success
  assert_output ''
}

@test "ensure_trailing_slash: no trailing slash -> appended" {
  run strings::ensure_trailing_slash '/foo'
  assert_success
  assert_output '/foo/'
}

@test "ensure_trailing_slash: has trailing slash -> unchanged" {
  run strings::ensure_trailing_slash '/foo/'
  assert_success
  assert_output '/foo/'
}

@test "ensure_trailing_slash: just slash -> unchanged" {
  run strings::ensure_trailing_slash '/'
  assert_success
  assert_output '/'
}

@test "ensure_trailing_slash: relative path -> appended" {
  run strings::ensure_trailing_slash 'foo/bar'
  assert_success
  assert_output 'foo/bar/'
}
