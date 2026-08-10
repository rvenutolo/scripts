{
  description = "rvenutolo/scripts — tooling devShell and formatter";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default-linux";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      treefmt-nix,
    }:
    let
      eachSystem = f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./.treefmt.nix);
    in
    {
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });

      devShells = eachSystem (
        pkgs:
        let
          # bashcov is not packaged in nixpkgs; provide it (with simplecov-cobertura
          # for the cobertura.xml the coverage job uploads to Codecov) via a pinned
          # bundlerEnv — gemset.nix lives under .nix/bashcov/. Includes its own ruby.
          bashcovEnv = pkgs.bundlerEnv {
            name = "bashcov-env";
            ruby = pkgs.ruby;
            gemdir = ./.nix/bashcov;
          };
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
              bats
              parallel
              pwgen
              gawk
              kcov
              bashcovEnv # bashcov + simplecov-cobertura (gemset under .nix/bashcov)
              gh
              git
              coreutils
              findutils
              gnugrep
            ];

            # Activate the tracked git hooks for this clone. Activation used to be a
            # manual per-clone step that silently never happened (#212); the devShell is
            # the one place onboarding cannot skip. Tolerant of failure on purpose — a
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
