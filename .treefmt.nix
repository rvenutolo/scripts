{ pkgs, ... }:
let
  mdformatWithPlugins = pkgs.mdformat.withPlugins (ps: [
    ps.mdformat-gfm
    ps.mdformat-frontmatter
  ]);
in
{
  projectRootFile = "flake.nix";

  programs.prettier = {
    enable = true;
    includes = [ "*.json" ];
  };
  programs.yamlfmt.enable = true;
  programs.taplo.enable = true;
  programs.nixfmt.enable = true;

  # shfmt via an explicit formatter entry rather than programs.shfmt, because that
  # module hardcodes `-s` (simplify) and settings.formatter.shfmt.options only APPENDS
  # to the module's list — there is no way to drop a flag the module sets. `-s` strips
  # quotes inside `[[ ]]`, which contradicts the repo's quote-every-expansion rule and,
  # for `=~`, silently turns a literal match into a regex match.
  #
  # Flags are spelled out rather than left to .editorconfig: shfmt ignores EditorConfig
  # entirely once any parser or printer flag is passed, and a formatter entry must pass
  # at least --write. Keep these in sync with the [*.{sh,bash}] section of
  # .editorconfig and the documented style in CLAUDE.md.
  settings.formatter.shfmt = {
    command = "${pkgs.shfmt}/bin/shfmt";
    options = [
      "--write"
      "--indent"
      "2"
      "--case-indent"
      "--binary-next-line"
      "--space-redirects"
    ];
    includes = [
      "*.sh"
      "*.bash"
      "*.envrc"
      "*.envrc.*"
    ];
  };

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
