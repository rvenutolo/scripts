#!/usr/bin/env bash

setup() {
  load '../test_helper/common'
  load '../test_helper/path_shim'
  CHECK="${SCRIPTS_DIR}/.ci/check-jsonschema"
}

@test "passes when shimmed check-jsonschema exits 0 for all targets" {
  path_shim::add 'check-jsonschema' '#!/usr/bin/env bash
printf "%s\n" "$*" >> "'"${BATS_TEST_TMPDIR}"'/calls.log"
exit 0'
  # Clear BASH_ENV so the script's bash startup does not re-source ~/.bashrc,
  # which would re-prepend the real nix check-jsonschema ahead of our shim.
  BASH_ENV='' run "${CHECK}"
  assert_success
  run wc -l < "${BATS_TEST_TMPDIR}/calls.log"
  [ "${output}" -ge 3 ]
}

@test "fails when shimmed check-jsonschema exits non-zero" {
  path_shim::add 'check-jsonschema' '#!/usr/bin/env bash
exit 1'
  # See note above: clear BASH_ENV so the shim is not shadowed by the real binary.
  BASH_ENV='' run "${CHECK}"
  assert_failure
  assert_output --partial 'schema validation failed'
}

@test "dies when check-jsonschema is not installed" {
  # The script's own `#!/usr/bin/env bash` startup sources ~/.bashrc via
  # BASH_ENV, which re-exports the full nix/sdkman PATH and re-adds
  # check-jsonschema regardless of the PATH we set here. Clear BASH_ENV so the
  # restricted PATH actually holds inside the script and the absence is real.
  path_shim::mkbin
  BASH_ENV='' PATH="${BATS_TEST_TMPDIR}/bin:/usr/bin:/bin" run "${CHECK}"
  assert_failure
  assert_output --partial 'check-jsonschema'
}

@test "dies when given an argument" {
  path_shim::add 'check-jsonschema' '#!/usr/bin/env bash
exit 0'
  run "${CHECK}" oops
  assert_failure
  assert_output --partial 'Expected no arguments'
}
