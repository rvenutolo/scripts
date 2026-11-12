# Print every reference to the GitHub Actions `secrets` context in the given
# YAML files, one tab-separated line per reference:
#
#   FILE<TAB>LINENO<TAB>name<TAB>NAME      a fixed secret name, upper-cased,
#                                          from `secrets.NAME` or
#                                          `secrets['NAME']`
#   FILE<TAB>LINENO<TAB>context<TAB>TEXT   a use with no fixed name: the
#                                          `secrets` context inside a `${{ }}`
#                                          expression other than as a named
#                                          reference (`toJSON(secrets)`,
#                                          `secrets[format(...)]`), or
#                                          `secrets: inherit`
#
# Shared by .ci/check-secrets-documented and .ci/check-pr-workflows-no-secrets,
# so both lints read references the same way.
#
# A line wholly a YAML comment is skipped, except inside a block scalar
# (`run: |`), where a leading `#` is script text and Actions still substitutes
# expressions in it. Trailing comments are not stripped: a `#` inside a quoted
# string cannot be told apart from one without parsing, and counting a
# commented-out reference fails loudly where dropping a live one would not.
# Secret names are case-insensitive in GitHub, hence the upper-casing.

function indent_of(s) {
  match(s, /^ */)
  return RLENGTH
}

function scan(line,    rest, tok, masked, expr) {
  rest = line
  while (match(rest, NAMED)) {
    tok = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RSTART + RLENGTH)
    sub(/^[^s]?secrets[.[]/, "", tok)
    gsub(/[]'"]/, "", tok)
    gsub(/[[:space:]]/, "", tok)
    printf "%s\t%d\tname\t%s\n", FILENAME, FNR, toupper(tok)
  }
  masked = line
  gsub(NAMED, "\001", masked)
  rest = masked
  # An expression may hold a lone `}` (format('{0}')); only `}}` closes it.
  while (match(rest, /\$\{\{([^}]|\}[^}])*\}\}/)) {
    expr = substr(rest, RSTART, RLENGTH)
    rest = substr(rest, RSTART + RLENGTH)
    if (expr ~ /(^|[^A-Za-z0-9_.])secrets([^A-Za-z0-9_]|$)/) {
      printf "%s\t%d\tcontext\t%s\n", FILENAME, FNR, expr
    }
  }
  if (line ~ /^[[:space:]]*(-[[:space:]]+)?secrets:[[:space:]]*inherit([[:space:]]|$)/) {
    printf "%s\t%d\tcontext\tsecrets: inherit\n", FILENAME, FNR
  }
}

BEGIN {
  # The leading class is the left word boundary, so `mysecrets.X` is not a
  # reference.
  NAMED = "(^|[^A-Za-z0-9_.])secrets(\\.[A-Za-z_][A-Za-z0-9_]*|\\[[[:space:]]*['\"][A-Za-z_][A-Za-z0-9_]*['\"][[:space:]]*\\])"
}

FNR == 1 {
  in_block = 0
}

{
  if (in_block) {
    if ($0 ~ /^[[:space:]]*$/ || indent_of($0) > block_indent) {
      scan($0)
      next
    }
    in_block = 0
  }
  if ($0 ~ /^[[:space:]]*#/) {
    next
  }
  scan($0)
  if ($0 ~ /(:|^[[:space:]]*-)[[:space:]]+[|>][-+0-9]*[[:space:]]*(#.*)?$/) {
    in_block = 1
    block_indent = indent_of($0)
  }
}
