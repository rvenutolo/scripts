#!/usr/bin/env bats
# shellcheck disable=SC2030,SC2031 # BATS isolates each @test in its own subshell

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/path_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/os_release_fixture.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/os.bash"
}

# ---------- release_field ----------

@test "release_field: returns ID value" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::release_field 'ID'
  assert_success
  assert_output 'ubuntu'
}

@test "release_field: returns VERSION_CODENAME value" {
  os_release_fixture::create 'ID=ubuntu' 'VERSION_CODENAME=jammy' > /dev/null
  os_release_fixture::install_source_override
  run os::release_field 'VERSION_CODENAME'
  assert_success
  assert_output 'jammy'
}

@test "release_field: returns empty string for absent field" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::release_field 'NONEXISTENT_FIELD'
  assert_success
  assert_output ''
}

@test "release_field: handles double-quoted values" {
  os_release_fixture::create 'ID="ubuntu"' 'VERSION_CODENAME="jammy"' > /dev/null
  os_release_fixture::install_source_override
  run os::release_field 'ID'
  assert_success
  assert_output 'ubuntu'
}

@test "release_field: handles single-quoted values" {
  os_release_fixture::create "ID='fedora'" > /dev/null
  os_release_fixture::install_source_override
  run os::release_field 'ID'
  assert_success
  assert_output 'fedora'
}

@test "release_field: dies with no args" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::release_field
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "release_field: dies with too many args" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::release_field 'ID' 'extra'
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- id ----------

@test "id: returns ID field via fixture" {
  os_release_fixture::create 'ID=arch' > /dev/null
  os_release_fixture::install_source_override
  run os::id
  assert_success
  assert_output 'arch'
}

@test "id: returns empty when ID absent" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::id
  assert_success
  assert_output ''
}

@test "id: dies with args" {
  os_release_fixture::create 'ID=arch' > /dev/null
  os_release_fixture::install_source_override
  run os::id 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- codename ----------

@test "codename: returns VERSION_CODENAME field via fixture" {
  os_release_fixture::create 'ID=ubuntu' 'VERSION_CODENAME=jammy' > /dev/null
  os_release_fixture::install_source_override
  run os::codename
  assert_success
  assert_output 'jammy'
}

@test "codename: returns empty when VERSION_CODENAME absent" {
  os_release_fixture::create 'ID=arch' > /dev/null
  os_release_fixture::install_source_override
  run os::codename
  assert_success
  assert_output ''
}

@test "codename: dies with args" {
  os_release_fixture::create 'ID=ubuntu' 'VERSION_CODENAME=jammy' > /dev/null
  os_release_fixture::install_source_override
  run os::codename 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- arch ----------

@test "arch: returns dpkg output (amd64)" {
  path_shim::add 'dpkg' "#!/usr/bin/env bash
printf '%s\\n' 'amd64'"
  run os::arch
  assert_success
  assert_output 'amd64'
}

@test "arch: returns dpkg output (arm64)" {
  path_shim::add 'dpkg' "#!/usr/bin/env bash
printf '%s\\n' 'arm64'"
  run os::arch
  assert_success
  assert_output 'arm64'
}

@test "arch: dies with args" {
  path_shim::add 'dpkg' "#!/usr/bin/env bash
printf '%s\\n' 'amd64'"
  run os::arch 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_arch ----------

@test "is_arch: matches ID=arch" {
  os_release_fixture::create 'ID=arch' > /dev/null
  os_release_fixture::install_source_override
  run os::is_arch
  assert_success
}

@test "is_arch: rejects ID=ubuntu" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::is_arch
  assert_failure
}

@test "is_arch: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_arch
  assert_failure
}

@test "is_arch: dies with args" {
  os_release_fixture::create 'ID=arch' > /dev/null
  os_release_fixture::install_source_override
  run os::is_arch 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_cachyos ----------

@test "is_cachyos: matches ID=cachyos" {
  os_release_fixture::create 'ID=cachyos' > /dev/null
  os_release_fixture::install_source_override
  run os::is_cachyos
  assert_success
}

@test "is_cachyos: rejects ID=arch" {
  os_release_fixture::create 'ID=arch' > /dev/null
  os_release_fixture::install_source_override
  run os::is_cachyos
  assert_failure
}

@test "is_cachyos: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_cachyos
  assert_failure
}

@test "is_cachyos: dies with args" {
  os_release_fixture::create 'ID=cachyos' > /dev/null
  os_release_fixture::install_source_override
  run os::is_cachyos 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_fedora ----------

@test "is_fedora: matches ID=fedora" {
  os_release_fixture::create 'ID=fedora' > /dev/null
  os_release_fixture::install_source_override
  run os::is_fedora
  assert_success
}

@test "is_fedora: rejects ID=ubuntu" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::is_fedora
  assert_failure
}

@test "is_fedora: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_fedora
  assert_failure
}

@test "is_fedora: dies with args" {
  os_release_fixture::create 'ID=fedora' > /dev/null
  os_release_fixture::install_source_override
  run os::is_fedora 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_debian ----------

@test "is_debian: matches ID=debian" {
  os_release_fixture::create 'ID=debian' > /dev/null
  os_release_fixture::install_source_override
  run os::is_debian
  assert_success
}

@test "is_debian: rejects ID=ubuntu" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::is_debian
  assert_failure
}

@test "is_debian: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_debian
  assert_failure
}

@test "is_debian: dies with args" {
  os_release_fixture::create 'ID=debian' > /dev/null
  os_release_fixture::install_source_override
  run os::is_debian 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_ubuntu ----------

@test "is_ubuntu: matches ID=ubuntu" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::is_ubuntu
  assert_success
}

@test "is_ubuntu: rejects ID=debian" {
  os_release_fixture::create 'ID=debian' > /dev/null
  os_release_fixture::install_source_override
  run os::is_ubuntu
  assert_failure
}

@test "is_ubuntu: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_ubuntu
  assert_failure
}

@test "is_ubuntu: dies with args" {
  os_release_fixture::create 'ID=ubuntu' > /dev/null
  os_release_fixture::install_source_override
  run os::is_ubuntu 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_leap ----------

@test "is_leap: matches ID=opensuse-leap" {
  os_release_fixture::create 'ID=opensuse-leap' > /dev/null
  os_release_fixture::install_source_override
  run os::is_leap
  assert_success
}

@test "is_leap: rejects ID=opensuse-tumbleweed" {
  os_release_fixture::create 'ID=opensuse-tumbleweed' > /dev/null
  os_release_fixture::install_source_override
  run os::is_leap
  assert_failure
}

@test "is_leap: rejects ID=leap (not opensuse-leap)" {
  os_release_fixture::create 'ID=leap' > /dev/null
  os_release_fixture::install_source_override
  run os::is_leap
  assert_failure
}

@test "is_leap: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_leap
  assert_failure
}

@test "is_leap: dies with args" {
  os_release_fixture::create 'ID=opensuse-leap' > /dev/null
  os_release_fixture::install_source_override
  run os::is_leap 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}

# ---------- is_tumbleweed ----------

@test "is_tumbleweed: matches ID=opensuse-tumbleweed" {
  os_release_fixture::create 'ID=opensuse-tumbleweed' > /dev/null
  os_release_fixture::install_source_override
  run os::is_tumbleweed
  assert_success
}

@test "is_tumbleweed: rejects ID=opensuse-leap" {
  os_release_fixture::create 'ID=opensuse-leap' > /dev/null
  os_release_fixture::install_source_override
  run os::is_tumbleweed
  assert_failure
}

@test "is_tumbleweed: rejects ID=tumbleweed (not opensuse-tumbleweed)" {
  os_release_fixture::create 'ID=tumbleweed' > /dev/null
  os_release_fixture::install_source_override
  run os::is_tumbleweed
  assert_failure
}

@test "is_tumbleweed: rejects empty ID" {
  os_release_fixture::create 'NAME=mystery' > /dev/null
  os_release_fixture::install_source_override
  run os::is_tumbleweed
  assert_failure
}

@test "is_tumbleweed: dies with args" {
  os_release_fixture::create 'ID=opensuse-tumbleweed' > /dev/null
  os_release_fixture::install_source_override
  run os::is_tumbleweed 'extra'
  assert_failure
  assert_output --partial 'Expected no arguments'
}
