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
      eachSystem =
        f: nixpkgs.lib.genAttrs (import systems) (system: f nixpkgs.legacyPackages.${system});
      treefmtEval = eachSystem (pkgs: treefmt-nix.lib.evalModule pkgs ./treefmt.nix);
    in
    {
      formatter = eachSystem (pkgs: treefmtEval.${pkgs.system}.config.build.wrapper);

      checks = eachSystem (pkgs: {
        formatting = treefmtEval.${pkgs.system}.config.build.check self;
      });

      devShells = eachSystem (pkgs: {
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
            # TODO: bashcov for coverage job — not packaged in nixpkgs-unstable; coverage handled in a later task
            gh
            git
            coreutils
            findutils
            gnugrep
          ];
        };
      });
    };
}
