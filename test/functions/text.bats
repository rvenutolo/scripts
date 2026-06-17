#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${REPO_DIR}/test/test_helper/dual_mode.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/text.bash"
}

# ---------- text::remove_ansi ----------

@test "remove_ansi: no ANSI -> unchanged (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' 'hello' 'hello'
}

@test "remove_ansi: no ANSI -> unchanged (file)" {
  dual_mode::assert_file 'text::remove_ansi' 'hello' 'hello'
}

@test "remove_ansi: single color sequence stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' $'\x1b[31mred\x1b[0m' 'red'
}

@test "remove_ansi: single color sequence stripped (file)" {
  dual_mode::assert_file 'text::remove_ansi' $'\x1b[31mred\x1b[0m' 'red'
}

@test "remove_ansi: bold + color stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' $'\x1b[1;31mbright\x1b[0m' 'bright'
}

@test "remove_ansi: clear-line K stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' $'foo\x1b[Kbar' 'foobar'
}

@test "remove_ansi: G cursor-position stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' $'\x1b[10Gtext' 'text'
}

@test "remove_ansi: multi-line input each line cleaned (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' \
    $'\x1b[31mline1\x1b[0m\n\x1b[32mline2\x1b[0m' \
    $'line1\nline2'
}

@test "remove_ansi: empty input (stdin)" {
  dual_mode::assert_stdin 'text::remove_ansi' '' ''
}

# ---------- text::remove_empty_lines ----------

@test "remove_empty_lines: no blank lines -> unchanged (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'a\nb\nc' $'a\nb\nc'
}

@test "remove_empty_lines: no blank lines -> unchanged (file)" {
  dual_mode::assert_file 'text::remove_empty_lines' $'a\nb\nc' $'a\nb\nc'
}

@test "remove_empty_lines: single blank line stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'a\n\nb' $'a\nb'
}

@test "remove_empty_lines: multiple blank lines stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'a\n\n\n\nb' $'a\nb'
}

@test "remove_empty_lines: whitespace-only lines stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'a\n   \n\t\nb' $'a\nb'
}

@test "remove_empty_lines: leading blanks stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'\n\na\nb' $'a\nb'
}

@test "remove_empty_lines: trailing blanks stripped (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'a\nb\n\n' $'a\nb'
}

@test "remove_empty_lines: all blank input -> empty (stdin)" {
  dual_mode::assert_stdin 'text::remove_empty_lines' $'\n   \n\t\n' ''
}

# ---------- text::first_line ----------

@test "first_line: single-line input (stdin)" {
  dual_mode::assert_stdin 'text::first_line' 'only' 'only'
}

@test "first_line: single-line input (file)" {
  dual_mode::assert_file 'text::first_line' 'only' 'only'
}

@test "first_line: multi-line returns first only (stdin)" {
  dual_mode::assert_stdin 'text::first_line' $'first\nsecond\nthird' 'first'
}

@test "first_line: multi-line returns first only (file)" {
  dual_mode::assert_file 'text::first_line' $'first\nsecond\nthird' 'first'
}

@test "first_line: empty input -> empty (stdin)" {
  dual_mode::assert_stdin 'text::first_line' '' ''
}

@test "first_line: blank first line returned as-is (stdin)" {
  dual_mode::assert_stdin 'text::first_line' $'\nsecond' ''
}

# ---------- text::last_line ----------

@test "last_line: single-line input (stdin)" {
  dual_mode::assert_stdin 'text::last_line' 'only' 'only'
}

@test "last_line: single-line input (file)" {
  dual_mode::assert_file 'text::last_line' 'only' 'only'
}

@test "last_line: multi-line returns last only (stdin)" {
  dual_mode::assert_stdin 'text::last_line' $'first\nsecond\nthird' 'third'
}

@test "last_line: multi-line returns last only (file)" {
  dual_mode::assert_file 'text::last_line' $'first\nsecond\nthird' 'third'
}

@test "last_line: empty input -> empty (stdin)" {
  dual_mode::assert_stdin 'text::last_line' '' ''
}

@test "last_line: trailing newline -> last non-empty content line (stdin)" {
  dual_mode::assert_stdin 'text::last_line' $'a\nb\n' 'b'
}

# ---------- text::skip_first_lines ----------

@test "skip_first_lines: skip 0 -> all lines (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' \"\$1\" | text::skip_first_lines 0" _ $'a\nb\nc'
  assert_success
  assert_output $'a\nb\nc'
}

@test "skip_first_lines: skip 1 -> drop first line (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' \"\$1\" | text::skip_first_lines 1" _ $'a\nb\nc'
  assert_success
  assert_output $'b\nc'
}

@test "skip_first_lines: skip 2 -> drop first two lines (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' \"\$1\" | text::skip_first_lines 2" _ $'a\nb\nc'
  assert_success
  assert_output 'c'
}

@test "skip_first_lines: skip count == total -> empty (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' \"\$1\" | text::skip_first_lines 3" _ $'a\nb\nc'
  assert_success
  assert_output ''
}

@test "skip_first_lines: skip count > total -> empty (stdin)" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' \"\$1\" | text::skip_first_lines 99" _ $'a\nb\nc'
  assert_success
  assert_output ''
}

@test "skip_first_lines: file mode skips first N lines" {
  printf '%s' $'a\nb\nc\nd' > "${BATS_TEST_TMPDIR}/in"
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; text::skip_first_lines \"\$1\" 2" _ "${BATS_TEST_TMPDIR}/in"
  assert_success
  assert_output $'c\nd'
}

@test "skip_first_lines: zero args fails" {
  run bash -c "source '${SCRIPTS_DIR}/.functions.bash'; printf '%s' \"\$1\" | text::skip_first_lines" _ $'a\nb'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
