{ pkgs, ... }:
let
  mdformatWithPlugins = pkgs.mdformat.withPlugins (ps: [
    ps.mdformat-gfm
    ps.mdformat-frontmatter
  ]);
in
{
  projectRootFile = "flake.nix";

  programs.shfmt.enable = true; # reads .editorconfig for style flags
  programs.prettier = {
    enable = true;
    includes = [ "*.json" ];
  };
  programs.yamlfmt.enable = true;
  programs.taplo.enable = true;
  programs.nixfmt.enable = true;

  # mdformat with plugins + wrap=keep via an explicit formatter entry, since the
  # treefmt-nix mdformat module does not expose plugin wiring.
  settings.formatter.mdformat = {
    command = "${mdformatWithPlugins}/bin/mdformat";
    options = [
      "--wrap"
      "keep"
    ];
    includes = [ "*.md" ];
  };

  settings.global.excludes = [
    "scripts/other/**"
    "test/bats/**"
    "test/test_helper/bats-support/**"
    "test/test_helper/bats-assert/**"
    ".shdoc/**"
    "site/**"
    "lib/**"
    ".docs/**"
    "flake.lock"
    "LICENSE"
    ".gitmodules"
  ];
}
