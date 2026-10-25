# shellcheck disable=SC2016 # single-quoted jq programs reference jq variables ($id, $sha), never shell ones

bats_require_minimum_version 1.5.0

readonly OLD_SHA='1111111111111111111111111111111111111111'
readonly NEW_SHA='2222222222222222222222222222222222222222'
readonly PINNED_ID='pinned@pins'

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  SCRIPT="${REPO_DIR}/scripts/non-interactive/claude-plugins-update"
  export XDG_CONFIG_HOME="${BATS_TEST_TMPDIR}/config"
  SHARED_SETTINGS="${XDG_CONFIG_HOME}/claude/shared/settings.json"
  CALLS="${BATS_TEST_TMPDIR}/claude.calls"
  export CALLS
  mkdir --parents "$(dirname "${SHARED_SETTINGS}")"
  printf '{\n  "enabledPlugins": {}\n}\n' > "${SHARED_SETTINGS}"
  install_fake_claude
}

# A stateful stand-in for the real claude CLI. It records every call as
# "<profile> <args>" and mutates the fixture the way the real CLI does:
# uninstall drops the plugin's install record and its enabledPlugins key, and
# install records the marketplace's pinned commit and appends the key at the END
# of enabledPlugins -- the reorder the script must undo.
# FAKE_CLAUDE_FAIL_UNINSTALL / FAKE_CLAUDE_FAIL_INSTALL force those commands to
# exit 1; FAKE_CLAUDE_INSTALL_EXTRA_KEY makes install also enable a second
# plugin, which is a real content change rather than a reorder.
install_fake_claude() {
  path_shim::add 'claude' "$(
    cat << 'EOF'
#!/usr/bin/env bash
set -Eeuo pipefail
printf '%s %s\n' "${CLAUDE_CONFIG_DIR##*/}" "$*" >> "${CALLS}"
installed="${CLAUDE_CONFIG_DIR}/plugins/installed_plugins.json"
settings="${CLAUDE_CONFIG_DIR}/settings.json"
id="${*: -1}"
function rewrite() {
  local -r file="$1"
  shift
  local tmp
  tmp="$(mktemp)"
  jq "$@" "${file}" > "${tmp}"
  # cat rather than mv so a symlinked settings.json stays a symlink.
  cat "${tmp}" > "${file}"
  rm --force -- "${tmp}"
}
case "$2" in
  list)
    jq --compact-output '[.plugins | keys[] | {id: .}]' "${installed}"
    ;;
  uninstall)
    if [[ -n "${FAKE_CLAUDE_FAIL_UNINSTALL:-}" ]]; then
      exit 1
    fi
    rewrite "${installed}" --arg id "${id}" 'del(.plugins[$id])'
    rewrite "${settings}" --arg id "${id}" 'del(.enabledPlugins[$id])'
    ;;
  install)
    if [[ -n "${FAKE_CLAUDE_FAIL_INSTALL:-}" ]]; then
      exit 1
    fi
    location="$(jq --raw-output --arg m "${id##*@}" '.[$m].installLocation' \
      "${CLAUDE_CONFIG_DIR}/plugins/known_marketplaces.json")"
    sha="$(jq --raw-output --arg n "${id%@*}" '.plugins[] | select(.name == $n) | .source.sha' \
      "${location}/.claude-plugin/marketplace.json")"
    rewrite "${installed}" --arg id "${id}" --arg sha "${sha}" \
      '.plugins[$id] = [{scope: "user", gitCommitSha: $sha}]'
    rewrite "${settings}" --arg id "${id}" '.enabledPlugins[$id] = true'
    if [[ -n "${FAKE_CLAUDE_INSTALL_EXTRA_KEY:-}" ]]; then
      rewrite "${settings}" '.enabledPlugins["extra@pins"] = true'
    fi
    ;;
esac
EOF
  )"
}

# Create a profile config dir whose settings.json is a symlink to the shared
# settings file, as chezmoi lays it out.
# $1 = profile name
make_profile() {
  local -r profile="$1"
  local -r dir="${XDG_CONFIG_HOME}/claude/${profile}"
  mkdir --parents "${dir}/plugins"
  ln --symbolic "${SHARED_SETTINGS}" "${dir}/settings.json"
  printf '{"version": 2, "plugins": {}}\n' > "${dir}/plugins/installed_plugins.json"
  printf '{}\n' > "${dir}/plugins/known_marketplaces.json"
}

# Register a marketplace in a profile with the given plugin entries.
# $1 = profile name
# $2 = marketplace name
# $3 = JSON array of marketplace plugin entries
add_marketplace() {
  local -r profile="$1"
  local -r marketplace="$2"
  local -r plugins_json="$3"
  local -r dir="${XDG_CONFIG_HOME}/claude/${profile}/plugins"
  local -r location="${dir}/marketplaces/${marketplace}"
  mkdir --parents "${location}/.claude-plugin"
  jq --null-input --argjson p "${plugins_json}" '{name: "m", plugins: $p}' \
    > "${location}/.claude-plugin/marketplace.json"
  update_json "${dir}/known_marketplaces.json" --arg m "${marketplace}" --arg l "${location}" \
    '.[$m] = {source: {source: "github"}, installLocation: $l}'
}

# A marketplace entry pinning a commit.
# $1 = plugin name
# $2 = pinned sha
pinned_entry() {
  jq --null-input --compact-output --arg n "$1" --arg s "$2" \
    '{name: $n, source: {source: "github", repo: "o/r", ref: "main", sha: $s}}'
}

# Record an installed plugin and enable it in the shared settings.
# $1 = profile name
# $2 = plugin id
# $3 = recorded commit sha, or the literal null
# $4 = scope (optional, default user)
add_installed() {
  local -r profile="$1"
  local -r id="$2"
  local -r sha="$3"
  local -r scope="${4:-user}"
  update_json "${XDG_CONFIG_HOME}/claude/${profile}/plugins/installed_plugins.json" \
    --arg id "${id}" --argjson sha "$(jq --null-input --compact-output --arg s "${sha}" \
      'if $s == "null" then null else $s end')" --arg scope "${scope}" \
    '.plugins[$id] = [{scope: $scope, version: "1.0.0", gitCommitSha: $sha}]'
  update_json "${SHARED_SETTINGS}" --arg id "${id}" '.enabledPlugins[$id] = true'
}

# Apply a jq program to a JSON file in place.
# $1 = file
# $@ rest = jq arguments
update_json() {
  local -r file="$1"
  shift
  jq "$@" "${file}" > "${file}.tmp"
  mv "${file}.tmp" "${file}"
}

# The single-profile drift fixture most tests start from: one pinned plugin
# installed at OLD_SHA, enabled ahead of a second plugin so a reinstall that
# appends its key visibly reorders enabledPlugins.
make_drifted_profile() {
  make_profile 'personal'
  add_marketplace 'personal' 'pins' "[$(pinned_entry 'pinned' "${NEW_SHA}"), $(pinned_entry 'other' "${NEW_SHA}")]"
  add_installed 'personal' "${PINNED_ID}" "${OLD_SHA}"
  add_installed 'personal' 'other@pins' "${NEW_SHA}"
}

# Run the script; any arguments are extra NAME=value settings for the fake claude.
run_script() {
  # BASH_ENV=SAFE_BASH_ENV: a child bash would otherwise re-source the user's
  # interactive ~/.bashrc, restoring the real PATH ahead of the shim dir.
  run --separate-stderr env "BASH_ENV=${SAFE_BASH_ENV}" "PATH=${PATH}" "$@" "${SCRIPT}"
}

@test "reinstalls a plugin whose installed commit differs from its marketplace pin" {
  make_drifted_profile
  run_script
  assert_success
  run grep --fixed-strings "personal plugin uninstall --keep-data --scope user ${PINNED_ID}" "${CALLS}"
  assert_success
  run grep --fixed-strings "personal plugin install --yes --scope user ${PINNED_ID}" "${CALLS}"
  assert_success
}

@test "uninstalls before installing, after every plugin update has run" {
  make_drifted_profile
  run_script
  assert_success
  # One word per call, in call order, so the whole sequence is a single comparable line.
  run awk '$3 ~ /^(update|uninstall|install)$/ { printf "%s ", $3 }' "${CALLS}"
  assert_output 'update update uninstall install '
}

@test "records the pinned commit after the reinstall" {
  make_drifted_profile
  run_script
  assert_success
  run jq --raw-output --arg id "${PINNED_ID}" '.plugins[$id][0].gitCommitSha' \
    "${XDG_CONFIG_HOME}/claude/personal/plugins/installed_plugins.json"
  assert_output "${NEW_SHA}"
}

@test "leaves a plugin alone when its installed commit matches its pin" {
  make_profile 'personal'
  add_marketplace 'personal' 'pins' "[$(pinned_entry 'pinned' "${NEW_SHA}")]"
  add_installed 'personal' "${PINNED_ID}" "${NEW_SHA}"
  run_script
  assert_success
  run grep --extended-regexp 'plugin (uninstall|install) ' "${CALLS}"
  assert_failure 1
}

@test "checks plugins from every marketplace, not only one" {
  make_profile 'personal'
  add_marketplace 'personal' 'official' "[$(pinned_entry 'tool' "${NEW_SHA}")]"
  add_installed 'personal' 'tool@official' "${OLD_SHA}"
  run_script
  assert_success
  run grep --fixed-strings 'plugin install --yes --scope user tool@official' "${CALLS}"
  assert_success
}

@test "skips a plugin whose marketplace source is a relative path" {
  make_profile 'personal'
  add_marketplace 'personal' 'official' '[{"name": "local", "source": "./plugins/local"}]'
  add_installed 'personal' 'local@official' "${OLD_SHA}"
  run_script
  assert_success
  run grep --extended-regexp 'plugin (uninstall|install) ' "${CALLS}"
  assert_failure 1
}

@test "skips a plugin whose marketplace source pins no commit" {
  make_profile 'personal'
  add_marketplace 'personal' 'official' '[{"name": "url", "source": {"source": "url", "url": "https://x.invalid/r.git"}}]'
  add_installed 'personal' 'url@official' "${OLD_SHA}"
  run_script
  assert_success
  run grep --extended-regexp 'plugin (uninstall|install) ' "${CALLS}"
  assert_failure 1
}

@test "skips a plugin with no recorded commit" {
  make_profile 'personal'
  add_marketplace 'personal' 'pins' "[$(pinned_entry 'pinned' "${NEW_SHA}")]"
  add_installed 'personal' "${PINNED_ID}" 'null'
  run_script
  assert_success
  run grep --extended-regexp 'plugin (uninstall|install) ' "${CALLS}"
  assert_failure 1
}

@test "skips a drifted plugin installed outside user scope" {
  make_profile 'personal'
  add_marketplace 'personal' 'pins' "[$(pinned_entry 'pinned' "${NEW_SHA}")]"
  add_installed 'personal' "${PINNED_ID}" "${OLD_SHA}" 'project'
  run_script
  assert_success
  run grep --extended-regexp 'plugin (uninstall|install) ' "${CALLS}"
  assert_failure 1
}

@test "restores settings.json byte-for-byte when the reinstall only reorders it" {
  make_drifted_profile
  cp "${SHARED_SETTINGS}" "${BATS_TEST_TMPDIR}/settings.before"
  run_script
  assert_success
  run cmp "${BATS_TEST_TMPDIR}/settings.before" "${SHARED_SETTINGS}"
  assert_success
  run test -L "${XDG_CONFIG_HOME}/claude/personal/settings.json"
  assert_success
}

@test "leaves settings.json and warns when the reinstall changes its content" {
  make_drifted_profile
  run_script 'FAKE_CLAUDE_INSTALL_EXTRA_KEY=1'
  assert_success
  assert_stderr --partial 'settings.json'
  run jq --raw-output '.enabledPlugins["extra@pins"]' "${SHARED_SETTINGS}"
  assert_output 'true'
}

@test "counts a failed uninstall, skips the install, and exits 1" {
  make_drifted_profile
  run_script 'FAKE_CLAUDE_FAIL_UNINSTALL=1'
  assert_failure 1
  assert_stderr --partial "Failed to uninstall plugin ${PINNED_ID}"
  run grep --fixed-strings "plugin install --yes --scope user ${PINNED_ID}" "${CALLS}"
  assert_failure 1
}

@test "names the manual install command when the reinstall fails after uninstalling" {
  make_drifted_profile
  run_script 'FAKE_CLAUDE_FAIL_INSTALL=1'
  assert_failure 1
  assert_stderr --partial "claude plugin install --scope user ${PINNED_ID}"
}

@test "keeps checking the remaining plugins after a failed reinstall" {
  make_profile 'personal'
  add_marketplace 'personal' 'pins' "[$(pinned_entry 'a' "${NEW_SHA}"), $(pinned_entry 'b' "${NEW_SHA}")]"
  add_installed 'personal' 'a@pins' "${OLD_SHA}"
  add_installed 'personal' 'b@pins' "${OLD_SHA}"
  run_script 'FAKE_CLAUDE_FAIL_INSTALL=1'
  assert_failure 1
  run grep --fixed-strings 'plugin uninstall --keep-data --scope user b@pins' "${CALLS}"
  assert_success
}

@test "fails when an installed plugin's marketplace is not registered" {
  make_profile 'personal'
  add_installed 'personal' 'orphan@gone' "${OLD_SHA}"
  run_script
  assert_failure 1
  assert_stderr --partial 'orphan@gone'
}

@test "reinstalls drifted plugins in every profile" {
  make_drifted_profile
  make_profile 'work'
  add_marketplace 'work' 'pins' "[$(pinned_entry 'pinned' "${NEW_SHA}")]"
  # The shared settings already enable PINNED_ID; only the work install record is new.
  update_json "${XDG_CONFIG_HOME}/claude/work/plugins/installed_plugins.json" --arg id "${PINNED_ID}" \
    --arg sha "${OLD_SHA}" '.plugins[$id] = [{scope: "user", gitCommitSha: $sha}]'
  run_script
  assert_success
  run grep --fixed-strings "work plugin install --yes --scope user ${PINNED_ID}" "${CALLS}"
  assert_success
  run grep --fixed-strings "personal plugin install --yes --scope user ${PINNED_ID}" "${CALLS}"
  assert_success
}

@test "succeeds on a profile with no installed-plugins record" {
  make_profile 'personal'
  rm "${XDG_CONFIG_HOME}/claude/personal/plugins/installed_plugins.json"
  path_shim::add 'claude' "$(
    cat << 'EOF'
#!/usr/bin/env bash
if [[ "$2" == 'list' ]]; then
  printf '[]\n'
fi
EOF
  )"
  run_script
  assert_success
}
