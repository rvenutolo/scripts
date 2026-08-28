bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  SHIM_DIR="${REPO_DIR}/scripts/shims/claude"
  # shellcheck disable=SC1091
  source "${SHIM_DIR}/lib.bash"
}

@test "positional_args: fills the caller's array with the non-option arguments" {
  local -a out=()
  shim::positional_args out 'ds' '--signal' -f 'firefox'
  assert_equal "${#out[@]}" 1
  assert_equal "${out[0]}" 'firefox'
}

@test "positional_args: the reserved out-array nameref name is refused without running" {
  # The shim is standalone — builtins only, no log::die — so the guard prints its own
  # line and exits 125, the same code the shims use for "refused; real binary not run".
  # Refusing is the fail-safe direction: a mangled argument list must never reach
  # the real pkill.
  run --separate-stderr shim::positional_args '__shim_positional_args_ref' 'ds' '--signal' 'firefox'
  assert_failure 125
  assert_stderr --partial 'out-array may not be named __shim_positional_args_ref'
}

@test "positional_args: a caller array named _shim_out works" {
  # _shim_out was the internal nameref name before the collision-proof convention.
  local -a _shim_out=()
  shim::positional_args _shim_out 'ds' '--signal' 'firefox'
  assert_equal "${#_shim_out[@]}" 1
  assert_equal "${_shim_out[0]}" 'firefox'
}
