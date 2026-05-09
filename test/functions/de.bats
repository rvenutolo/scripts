#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/text.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/grep.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/de.bash"
}

# ---------- is_kde ----------

@test "is_kde: matches 'KDE'" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_kde
  assert_success
}

@test "is_kde: rejects 'kde' (case-sensitive)" {
  export XDG_CURRENT_DESKTOP='kde'
  run de::is_kde
  assert_failure
}

@test "is_kde: rejects 'GNOME'" {
  export XDG_CURRENT_DESKTOP='GNOME'
  run de::is_kde
  assert_failure
}

@test "is_kde: rejects 'pop:GNOME'" {
  export XDG_CURRENT_DESKTOP='pop:GNOME'
  run de::is_kde
  assert_failure
}

@test "is_kde: rejects empty XDG_CURRENT_DESKTOP" {
  export XDG_CURRENT_DESKTOP=''
  run de::is_kde
  assert_failure
}

@test "is_kde: rejects unset XDG_CURRENT_DESKTOP" {
  unset XDG_CURRENT_DESKTOP || true
  run de::is_kde
  assert_failure
}

@test "is_kde: dies with args" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_kde 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_gnome ----------

@test "is_gnome: matches 'GNOME'" {
  export XDG_CURRENT_DESKTOP='GNOME'
  run de::is_gnome
  assert_success
}

@test "is_gnome: matches 'ubuntu:GNOME'" {
  export XDG_CURRENT_DESKTOP='ubuntu:GNOME'
  run de::is_gnome
  assert_success
}

@test "is_gnome: rejects 'pop:GNOME'" {
  export XDG_CURRENT_DESKTOP='pop:GNOME'
  run de::is_gnome
  assert_failure
}

@test "is_gnome: rejects 'KDE'" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_gnome
  assert_failure
}

@test "is_gnome: rejects 'gnome' (case-sensitive)" {
  export XDG_CURRENT_DESKTOP='gnome'
  run de::is_gnome
  assert_failure
}

@test "is_gnome: rejects empty XDG_CURRENT_DESKTOP" {
  export XDG_CURRENT_DESKTOP=''
  run de::is_gnome
  assert_failure
}

@test "is_gnome: rejects unset XDG_CURRENT_DESKTOP" {
  unset XDG_CURRENT_DESKTOP || true
  run de::is_gnome
  assert_failure
}

@test "is_gnome: dies with args" {
  export XDG_CURRENT_DESKTOP='GNOME'
  run de::is_gnome 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_pop_shell ----------

@test "is_pop_shell: matches 'pop:GNOME'" {
  export XDG_CURRENT_DESKTOP='pop:GNOME'
  run de::is_pop_shell
  assert_success
}

@test "is_pop_shell: rejects 'GNOME'" {
  export XDG_CURRENT_DESKTOP='GNOME'
  run de::is_pop_shell
  assert_failure
}

@test "is_pop_shell: rejects 'ubuntu:GNOME'" {
  export XDG_CURRENT_DESKTOP='ubuntu:GNOME'
  run de::is_pop_shell
  assert_failure
}

@test "is_pop_shell: rejects 'KDE'" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_pop_shell
  assert_failure
}

@test "is_pop_shell: rejects empty XDG_CURRENT_DESKTOP" {
  export XDG_CURRENT_DESKTOP=''
  run de::is_pop_shell
  assert_failure
}

@test "is_pop_shell: rejects unset XDG_CURRENT_DESKTOP" {
  unset XDG_CURRENT_DESKTOP || true
  run de::is_pop_shell
  assert_failure
}

@test "is_pop_shell: dies with args" {
  export XDG_CURRENT_DESKTOP='pop:GNOME'
  run de::is_pop_shell 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_desktop_env ----------

@test "is_desktop_env: matches exact value (case-insensitive)" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_desktop_env 'kde'
  assert_success
}

@test "is_desktop_env: matches uppercase needle against lowercase XDG" {
  export XDG_CURRENT_DESKTOP='gnome'
  run de::is_desktop_env 'GNOME'
  assert_success
}

@test "is_desktop_env: matches word inside multi-token XDG value" {
  export XDG_CURRENT_DESKTOP='ubuntu:GNOME'
  run de::is_desktop_env 'gnome'
  assert_success
}

@test "is_desktop_env: rejects non-matching needle" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_desktop_env 'gnome'
  assert_failure
}

@test "is_desktop_env: rejects against empty XDG_CURRENT_DESKTOP" {
  export XDG_CURRENT_DESKTOP=''
  run de::is_desktop_env 'kde'
  assert_failure
}

@test "is_desktop_env: rejects against unset XDG_CURRENT_DESKTOP" {
  unset XDG_CURRENT_DESKTOP || true
  run de::is_desktop_env 'kde'
  assert_failure
}

@test "is_desktop_env: dies with no args" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_desktop_env
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "is_desktop_env: dies with too many args" {
  export XDG_CURRENT_DESKTOP='KDE'
  run de::is_desktop_env 'a' 'b'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}
