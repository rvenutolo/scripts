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
  # Style is NOT set here — see .editorconfig, which shfmt reads directly.
  settings.formatter.shfmt = {
    command = "${pkgs.shfmt}/bin/shfmt";
    # Only --write: shfmt reads .editorconfig for style, but ONLY when given no parser
    # or printer flag. Passing -i/-ci/-bn/-sr here would silently disable that and
    # fork the style definition. --write/--list/--diff are top-level flags and do not
    # disable it. Style lives in .editorconfig; keep it there.
    options = [ "--write" ];
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
    ".shdoc/**"
    "site/**"
    "lib/**"
    ".docs/**"
    "flake.lock"
    "LICENSE"
    ".gitmodules"
  ];
}
