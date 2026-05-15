#!/usr/bin/env bats

bats_require_minimum_version 1.5.0

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/test/test_helper/cli_shim.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/args.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/strings.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/grep.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/text.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/system.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/hosts.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/http.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/log.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/prompt.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/dirs.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/files.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/downloads.bash"
  # shellcheck disable=SC1091
  source "${SCRIPTS_DIR}/functions/packages.bash"
}

# Drop a `download <url> <path>` shim that writes ${BATS_TEST_TMPDIR}/csv to $2
# and records its invocation. Caller must seed csv file first.
install_download_shim() {
  path_shim::add download "$(
    cat << 'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${BATS_TEST_TMPDIR}/download.calls"
cp -- "${BATS_TEST_TMPDIR}/csv" "$2"
EOF
  )"
}

# Stub host detection: hostname=desktop, env vars set so hosts::is_personal && hosts::is_desktop true.
# universal.csv: personal+desktop = col 4
# distro.csv:    personal+desktop = col 2
# sdkman.csv:    personal+desktop = col 3
stub_personal_desktop() {
  path_shim::add hostname "$(
    cat << 'EOF'
#!/usr/bin/env bash
printf 'desktop\n'
EOF
  )"
  export PERSONAL_DESKTOP_HOSTNAME='desktop'
  export PERSONAL_LAPTOP_HOSTNAME='laptop'
  export WORK_LAPTOP_HOSTNAME='work'
}

# ---------- dpkg_package_installed ----------

@test "dpkg_package_installed: returns true when status is ok installed" {
  cli_shim::record_with_output dpkg-query 'foo;install ok installed'
  run packages::dpkg_package_installed foo
  assert_success
}

@test "dpkg_package_installed: returns false when status is deinstall" {
  cli_shim::record_with_output dpkg-query 'foo;deinstall ok config-files' 0
  run packages::dpkg_package_installed foo
  assert_failure
}

@test "dpkg_package_installed: returns false when dpkg-query returns nothing" {
  cli_shim::record_with_output dpkg-query '' 1
  run packages::dpkg_package_installed foo
  assert_failure
}

@test "dpkg_package_installed: returns false when status line does not match package name" {
  # dpkg-query might return output for a different package
  cli_shim::record_with_output dpkg-query 'bar;install ok installed' 0
  run packages::dpkg_package_installed foo
  assert_failure
}

@test "dpkg_package_installed: dies with no args" {
  run packages::dpkg_package_installed
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

@test "dpkg_package_installed: dies with too many args" {
  run packages::dpkg_package_installed a b
  assert_failure
  assert_output --partial 'Expected exactly 1 argument'
}

# ---------- get_universal ----------
# universal.csv columns: $1=row, $2=type, $3=pkg_name, $4=personal_desktop,
#                        $5=personal_laptop, $6=work_laptop, $7=server, $8=disabled_reason

@test "get_universal: returns sorted enabled packages for personal desktop" {
  stub_personal_desktop
  install_download_shim
  # col4=y means enabled for personal desktop; col8 empty = not disabled
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,zoom,y,n,n,n,
2,appimage,obs,y,y,y,n,
3,appimage,disabled-pkg,y,y,y,y,broken
4,flatpak,firefox,y,y,y,n,
CSV
  run packages::get_universal appimage --quiet
  assert_success
  assert_line --index 0 'obs'
  assert_line --index 1 'zoom'
  refute_output --partial 'firefox'
  refute_output --partial 'disabled-pkg'
}

@test "get_universal: excludes packages where host column is not y" {
  stub_personal_desktop
  install_download_shim
  # desktop col (col4) is n for these packages
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,laptop-only,n,y,y,n,
2,appimage,server-only,n,n,n,y,
CSV
  run packages::get_universal appimage --quiet
  assert_success
  assert_output ''
}

@test "get_universal: --ignore omits named packages" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,zoom,y,n,n,n,
2,appimage,obs,y,y,y,n,
CSV
  run packages::get_universal appimage --quiet --ignore obs
  assert_success
  assert_output 'zoom'
}

@test "get_universal: --ignore can omit multiple packages" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,zoom,y,n,n,n,
2,appimage,obs,y,y,y,n,
3,appimage,vlc,y,y,y,n,
CSV
  run packages::get_universal appimage --quiet --ignore obs zoom
  assert_success
  assert_output 'vlc'
}

@test "get_universal: emits disabled-package log when --quiet not set" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,disabled-pkg,y,y,y,y,broken
CSV
  run packages::get_universal appimage
  assert_success
  assert_output --partial 'Disabled package: disabled-pkg (broken)'
}

@test "get_universal: suppresses disabled-package log when --quiet set" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,disabled-pkg,y,y,y,y,broken
CSV
  run packages::get_universal appimage --quiet
  assert_success
  refute_output --partial 'Disabled package'
}

@test "get_universal: output is sorted alphabetically" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,zzz,y,n,n,n,
2,appimage,aaa,y,n,n,n,
3,appimage,mmm,y,n,n,n,
CSV
  run packages::get_universal appimage --quiet
  assert_success
  assert_line --index 0 'aaa'
  assert_line --index 1 'mmm'
  assert_line --index 2 'zzz'
}

@test "get_universal: dies on unknown package type" {
  run packages::get_universal 'bogus-type'
  assert_failure
  assert_output --partial 'Unexpected package list type'
}

@test "get_universal: dies with no args" {
  run packages::get_universal
  assert_failure
  assert_output --partial 'Expected at least 1 argument'
}

@test "get_universal: supports flatpak type" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,appimage,should-not-appear,y,n,n,n,
2,flatpak,org.mozilla.firefox,y,y,y,n,
CSV
  run packages::get_universal flatpak --quiet
  assert_success
  assert_output 'org.mozilla.firefox'
  refute_output --partial 'should-not-appear'
}

@test "get_universal: supports nixpkgs type" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,nixpkgs,ripgrep,y,n,n,n,
2,appimage,ignored,y,n,n,n,
CSV
  run packages::get_universal nixpkgs --quiet
  assert_success
  assert_output 'ripgrep'
}

@test "get_universal: supports nixpkgs-unstable type" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,nixpkgs-unstable,neovim,y,n,n,n,
2,nixpkgs,ignored,y,n,n,n,
CSV
  run packages::get_universal nixpkgs-unstable --quiet
  assert_success
  assert_output 'neovim'
}

# ---------- get_distro ----------
# distro.csv columns: $1=pkg_name, $2=personal_desktop, $3=personal_laptop,
#                     $4=work_laptop, $5=server, $6=disabled_reason

@test "get_distro: returns sorted enabled packages for personal desktop" {
  stub_personal_desktop
  # curl shim: success for HEAD check, then download shim handles the actual fetch
  cli_shim::record curl
  install_download_shim
  # col2=y means enabled for personal desktop; col6 empty = not disabled
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
git,y,y,y,n,
vim,y,y,y,n,
disabled-pkg,y,y,y,y,broken
not-for-desktop,n,y,y,n,
CSV
  run packages::get_distro 'ubuntu' 'noble' --quiet
  assert_success
  assert_line --index 0 'git'
  assert_line --index 1 'vim'
  refute_output --partial 'disabled-pkg'
  refute_output --partial 'not-for-desktop'
}

@test "get_distro: --ignore omits named packages" {
  stub_personal_desktop
  cli_shim::record curl
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
git,y,n,n,n,
vim,y,n,n,n,
curl,y,n,n,n,
CSV
  run packages::get_distro 'ubuntu' 'noble' --quiet --ignore git
  assert_success
  assert_output --partial 'vim'
  refute_output --partial 'git'
}

@test "get_distro: emits disabled-package log when --quiet not set" {
  stub_personal_desktop
  cli_shim::record curl
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
disabled-pkg,y,y,y,y,broken
CSV
  run packages::get_distro 'ubuntu' 'noble'
  assert_success
  assert_output --partial 'Disabled package: disabled-pkg (broken)'
}

@test "get_distro: suppresses disabled-package log when --quiet set" {
  stub_personal_desktop
  cli_shim::record curl
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
disabled-pkg,y,y,y,y,broken
CSV
  run packages::get_distro 'ubuntu' 'noble' --quiet
  assert_success
  refute_output --partial 'Disabled package'
}

@test "get_distro: output is sorted alphabetically" {
  stub_personal_desktop
  cli_shim::record curl
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
zzz,y,n,n,n,
aaa,y,n,n,n,
mmm,y,n,n,n,
CSV
  run packages::get_distro 'ubuntu' 'noble' --quiet
  assert_success
  assert_line --index 0 'aaa'
  assert_line --index 1 'mmm'
  assert_line --index 2 'zzz'
}

@test "get_distro: dies when HEAD check fails (no packages list for distro)" {
  stub_personal_desktop
  cli_shim::record_with_output curl '' 22
  run packages::get_distro 'ubuntu' 'noble'
  assert_failure
  assert_output --partial 'No packages list for ubuntu noble'
}

@test "get_distro: dies with too few args" {
  run packages::get_distro 'ubuntu'
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

@test "get_distro: dies with no args" {
  run packages::get_distro
  assert_failure
  assert_output --partial 'Expected at least 2 arguments'
}

# ---------- get_sdkman ----------
# sdkman.csv columns: $1=row, $2=sdk_name, $3=personal_desktop,
#                     $4=personal_laptop, $5=work_laptop, $6=server, $7=disabled_reason

@test "get_sdkman: returns sorted enabled packages for personal desktop" {
  stub_personal_desktop
  install_download_shim
  # col3=y means enabled for personal desktop; col7 empty = not disabled
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,gradle,y,y,y,n,
2,maven,y,y,y,n,
3,disabled-sdk,y,y,y,n,broken
CSV
  run packages::get_sdkman --quiet
  assert_success
  assert_line --index 0 'gradle'
  assert_line --index 1 'maven'
  refute_output --partial 'disabled-sdk'
}

@test "get_sdkman: excludes packages where host column is not y" {
  stub_personal_desktop
  install_download_shim
  # col3 (personal desktop) = n
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,laptop-only,n,y,y,n,
2,server-only,n,n,n,y,
CSV
  run packages::get_sdkman --quiet
  assert_success
  assert_output ''
}

@test "get_sdkman: --ignore omits named packages" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,gradle,y,y,y,n,
2,maven,y,y,y,n,
CSV
  run packages::get_sdkman --quiet --ignore gradle
  assert_success
  assert_output 'maven'
}

@test "get_sdkman: --ignore can omit multiple packages" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,gradle,y,y,y,n,
2,maven,y,y,y,n,
3,java,y,y,y,n,
CSV
  run packages::get_sdkman --quiet --ignore gradle maven
  assert_success
  assert_output 'java'
}

@test "get_sdkman: emits disabled-package log when --quiet not set" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,disabled-sdk,y,y,y,n,broken
CSV
  run packages::get_sdkman
  assert_success
  assert_output --partial 'Disabled package: disabled-sdk (broken)'
}

@test "get_sdkman: suppresses disabled-package log when --quiet set" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,disabled-sdk,y,y,y,n,broken
CSV
  run packages::get_sdkman --quiet
  assert_success
  refute_output --partial 'Disabled package'
}

@test "get_sdkman: output is sorted alphabetically" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,zzz,y,n,n,n,
2,aaa,y,n,n,n,
3,mmm,y,n,n,n,
CSV
  run packages::get_sdkman --quiet
  assert_success
  assert_line --index 0 'aaa'
  assert_line --index 1 'mmm'
  assert_line --index 2 'zzz'
}

@test "get_sdkman: returns empty output when no packages match" {
  stub_personal_desktop
  install_download_shim
  cat > "${BATS_TEST_TMPDIR}/csv" << 'CSV'
1,laptop-only,n,y,y,n,
CSV
  run packages::get_sdkman --quiet
  assert_success
  assert_output ''
}
