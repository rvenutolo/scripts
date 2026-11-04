#!/usr/bin/env bash

# @description Find and print all pom.xml file paths under a directory, excluding target/ trees.
# Output: stdout — sorted list of pom.xml paths, one per line
# @arg $1 root directory to search (optional; defaults to current directory)
function mvn::list_pom_files() {
  args::check_at_most_1_arg "$@"
  if args::no_args "$@"; then
    local -r dir="."
  else
    local -r dir="$1"
  fi
  find "${dir}" \
    -type 'd' \( ! -readable -o ! -executable \) -prune \
    -o -name 'target' -prune \
    -o -type 'f' -name 'pom.xml' -print \
    | sort
}

# @description Print a regex that matches pre-release Maven versions (alpha, beta, milestone, RC/CR),
#   for passing to the Versions plugin as `-Dmaven.version.ignore=<regex>`.
#   Qualifiers match in any case after `-` or `.`, with an optional number and trailing qualifiers
#   (`2.0-M4-groovy-3.0`). The short forms `a`/`b` count only with a number (`-b1`), so a bare
#   `-b` or a word like `-amd64` is kept. A project's own `<ignoredVersions>` config takes
#   precedence over the property.
# @noargs
# @stdout the regex, on one line; it contains no comma, since the property splits on commas
function mvn::prerelease_ignore_regex() {
  args::check_no_args "$@"
  printf '%s\n' '(?i).*[-.]((alpha|beta|milestone|m|rc|cr)([-.]?\d+)?|[ab][-.]?\d+)([-.].*)?'
}
