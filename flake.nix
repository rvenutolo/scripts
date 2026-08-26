{
  description = "rvenutolo/scripts — tooling devShell and formatter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default-linux";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    bats-support = {
      url = "github:bats-core/bats-support";
      flake = false;
    };
    bats-assert = {
      url = "github:bats-core/bats-assert";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
      bats-support,
      bats-assert,
    }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./.treefmt.nix);
      # nixpkgs' unstable-version convention, derived from the input's own
      # lastModifiedDate so a Renovate bump of flake.lock relabels the store path
      # too. A hardcoded date silently goes stale on the first bump, which is the
      # whole reason these stopped being hand-written fetchFromGitHub pins.
      unstableVersion =
        input:
        let
          d = input.lastModifiedDate;
        in
        "0-unstable-${builtins.substring 0 4 d}-${builtins.substring 4 2 d}-${builtins.substring 6 2 d}";
    in
    {
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.stdenv.hostPlatform.system}.config.build.check self;
      });

      devShells = eachSystem (
        pkgs:
        let
          # kcov collects coverage for the BATS suite (.github/actions/coverage).
          # kcov's bash engine sets PS4='kcov@${BASH_SOURCE}@${LINENO}@' with no
          # default expansion, so a `bash -c '… set -u …'` string — which has no
          # BASH_SOURCE — dies inside PS4 expansion with "BASH_SOURCE: unbound
          # variable" and the test around it fails (4 tests across
          # log/shdoc/user.bats). The `:-` guard is the whole fix; --replace-fail
          # makes a kcov bump that moves the line fail the build loudly instead of
          # silently un-patching. The escaped `\$` is for bash, so
          # substituteInPlace receives the literal `${BASH_SOURCE}`.
          kcovPatched = pkgs.kcov.overrideAttrs (prev: {
            # kcov's xtrace parser tracks single-quote state across lines, but only
            # honours backslash escapes outside a quote. Bash renders any value
            # containing a newline with ANSI-C quoting, where \' is an escaped
            # quote, so one such trace line leaves the parser latched in
            # INPUT_SINGLE_QUOTE and every later line is silently discarded — an
            # empty report, no error, exit 0. Any test writing a multi-line shim
            # body through a variable hits it.
            patches = (prev.patches or [ ]) ++ [ ./.nix/kcov-ansi-c-quoting.patch ];
            postPatch = (prev.postPatch or "") + ''
              substituteInPlace src/engines/bash-helper.sh src/engines/bash-helper-debug-trap.sh \
                --replace-fail "\''${BASH_SOURCE}" "\''${BASH_SOURCE:-}"
            '';
          });
        in
        {
          default = pkgs.mkShellNoCC {
            packages = with pkgs; [
              # formatters (also wired into treefmt)
              shfmt
              prettier
              yamlfmt
              taplo
              nixfmt
              (mdformat.withPlugins (ps: [
                ps.mdformat-gfm
                ps.mdformat-frontmatter
              ]))
              # linters / checks
              shellcheck
              yamllint
              markdownlint-cli2
              editorconfig-checker
              typos
              actionlint
              zizmor
              check-jsonschema
              yq-go
              jq
              lychee
              # tests / runtime
              commitlint
              # withLibraries, not bare bats: the wrapper this produces exports
              # BATS_LIB_PATH at its own share/bats, so test_helper/common.bash loads
              # bats-support and bats-assert with `bats_load_library`, and a bats that
              # is not this one fails loudly instead of silently missing them.
              (bats.withLibraries (l: [
                # Both libraries come from flake INPUTS pinned in flake.lock, not
                # from the nixpkgs releases. nixpkgs ships bats-assert 2.1.0,
                # which has no assert_stderr / refute_stderr: those live only on
                # master, and this repo's whole stderr convention -- plus
                # .ci/check-stderr-assertions, which enforces it -- is built on
                # them. Taking the release would break ~30 tests and silently
                # un-enforce a documented rule. flake.lock carries the rev and the
                # narHash together, so Renovate's nix manager updates both.
                #
                # .github/renovate.json carries one regex custom manager per repo
                # that tracks these revs against master, so the pins are not
                # frozen with nothing watching them. Renovate cannot compute a
                # fetchFromGitHub hash, though, so a rev bump it opens leaves the
                # hash below stale and CI red until it is regenerated by hand:
                #
                #   nix store prefetch-file --unpack --json \
                #     https://github.com/bats-core/bats-assert/archive/<rev>.tar.gz
                #
                # Take the "hash" field of that JSON. The red CI is the point --
                # the alternative is a silent freeze on a rev nobody revisits.
                (l.bats-support.overrideAttrs (_: {
                  src = bats-support;
                  version = unstableVersion bats-support;
                }))
                (l.bats-assert.overrideAttrs (_: {
                  src = bats-assert;
                  version = unstableVersion bats-assert;
                }))
              ]))
              parallel
              # flock, for `bats --jobs`. bats refuses to parallelize within a file
              # without it, and the nixpkgs bats wrapper does not carry it. Until the
              # gate went hermetic this resolved from the machine's /usr/bin and so
              # was invisible; under `nix develop --ignore-environment` the whole
              # suite dies on its absence.
              util-linux
              # nix itself. Three gates shell out to it -- run-all-checks,
              # .ci/check-devshell-provides, .ci/check-flake-eval-warnings -- and
              # `--ignore-environment` strips the host's nix off PATH along with
              # everything else. Declaring it here is what lets .ci/required-tools
              # drop its "nix cannot be provided by the devShell" exception instead
              # of trading it for a new one.
              nix
              just
              pwgen
              # bc, for files::size_gb. Payload tooling like pwgen above -- scripts/
              # expects it from the machine -- but test/functions/files.bats exercises
              # that helper from inside the hermetic gate, where an absent bc makes the
              # test pass while the helper exits 127.
              bc
              gawk
              kcovPatched # kcov with the PS4 guard above; only the coverage job runs it
              gh
              git
              coreutils
              findutils
              gnugrep
              # docs site — `mkdocs build` for the .justfile `docs` recipe and the
              # Pages workflow. withPackages, not python3Packages.mkdocs-material:
              # the bare package ships no bin/ directory at all, so it puts no
              # `mkdocs` on PATH, while this env provides mkdocs 1.6.1 and the
              # material theme 9.7.6 on the same site-packages.
              (python3.withPackages (ps: [ ps.mkdocs-material ]))
            ];

            # Activate the tracked git hooks for this clone. As a manual per-clone
            # step this silently never happens; the devShell is the one place
            # onboarding cannot skip. Tolerant of failure on purpose — a
            # devShell that aborts on hook setup is worse than inert hooks. Resolved via
            # git rather than the flake's store path so it configures the working clone,
            # not a read-only copy in the Nix store.
            shellHook = ''
              if hooks_repo_root="$(git rev-parse --show-toplevel 2>/dev/null)"; then
                "$hooks_repo_root/.ci/activate-githooks" \
                  || echo 'warning: could not activate tracked git hooks' >&2
              fi
            '';
          };
        }
      );
    };
}
