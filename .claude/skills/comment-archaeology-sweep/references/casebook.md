# Casebook

Worked examples, one per disposition, lifted verbatim from the PR that swept `.codecov.yml`,
`flake.nix`, `check-scripts`, `run-tests`, and the `.githooks/pre-push` boilerplate by hand.
That sweep is where this skill's rubric came from — read backwards, the diffs below are the
rubric's proof, not just its illustration. Each pair carries one sentence on what made the
call go that way; that sentence is the part that transfers to the next file.

## Disposition 1 — trailing parenthetical

`check-scripts`, the `inherit_errexit` boilerplate shared by every gate script:

Before:

```bash
set -Eeuo pipefail
# Without this, errexit is off inside every $(...) subshell, so a helper called
# as `n="$(scan ...)"` runs past a failed command and this gate exits 0 (#290).
shopt -s inherit_errexit
```

After:

```bash
set -Eeuo pipefail
# Without this, errexit is off inside every $(...) subshell, so a helper called
# as `n="$(scan ...)"` runs past a failed command and this gate exits 0.
shopt -s inherit_errexit
```

The sentence already states the constraint completely on its own — a reader who has never
seen the tracker still knows exactly what breaks without the shopt — so the trailing
parenthetical was pure addition with nothing left to lose by cutting it.

## Disposition 2 — attribution-only sentence

`check-scripts`, the shebang-file skip inside the shfmt candidate loop:

Before:

```bash
  # skip is silent because the shellcheck step below reports it. See issue #206.
  if ! shell_scripts::is_shell_file "${candidate}"; then
```

After:

```bash
  # skip is silent because the shellcheck step below reports it.
  if ! shell_scripts::is_shell_file "${candidate}"; then
```

The sentence before it already explains the behavior in full; "See issue #206." adds no fact
a reader could act on, only a place to go read more history, so the whole clause was deleted
rather than rewritten.

## Disposition 3 — pure archaeology

`.codecov.yml`, the coverage-tool history above the `flags:` block:

Before:

```yaml
# Both measurements are deterministic: three full runs on an unchanged tree
# produce byte-identical per-line hits, so a moved number means the code moved
# (#307).
#
# Coverage used to be collected by bashcov, which handed bash a non-blocking
# pipe and silently dropped about three quarters of the trace, so both statuses
# were `informational: true` for a while — the number wandered ±4 points on an
# unchanged tree and a red status nobody could act on is worse than none. The
# post-fix baseline on main was 81.1% (1634 / 2015), against 54.1% collected
# through the lossy pipe.
#
# kcov then had a silent loss of its own: one `$'...'` trace line latched its
# quote parser and every later line was discarded, exit 0, no diagnostic (#310).
# Seven files read far below their real coverage — systemctl.bash 24% with every
# branch tested. With that patched and the genuine branch gaps filled, the
# functions baseline on main is 96.5% (1944 / 2015). Roughly 60 of the 71 lines
# still uncovered are lexer artifacts that can never be hit; see CLAUDE.md.
flags:
```

After:

```yaml
# Both measurements are deterministic: three full runs on an unchanged tree
# produce byte-identical per-line hits, so a moved number means the code moved.
#
# The functions baseline on main is 96.5% (1944 / 2015). Roughly 60 of the 71
# lines still uncovered are lexer artifacts that can never be hit; see CLAUDE.md.
flags:
```

Both deleted paragraphs describe a tool this repo no longer runs and a percentage it no
longer reports, so nothing in them helps a reader configuring the thresholds below — the
one fact that still does anything (the current baseline) survived as a single present-tense
sentence, and the rest went with the tool.

## Disposition 4 — superseded-state narration

This is the hardest call, because the line still needs to explain something — it just cannot
be allowed to explain it by narrating who used to hit the trap.

### Example A: `flake.nix`, the ANSI-C quoting patch comment

Before:

```nix
            # kcov's xtrace parser tracks single-quote state across lines, but only
            # honours backslash escapes outside a quote. Bash renders any value
            # containing a newline with ANSI-C quoting, where \' is an escaped
            # quote, so one such trace line left the parser latched in
            # INPUT_SINGLE_QUOTE and every later line was silently discarded — an
            # empty report, no error, exit 0. Any test writing a multi-line shim
            # body through a variable hit it (#310).
```

After:

```nix
            # kcov's xtrace parser tracks single-quote state across lines, but only
            # honours backslash escapes outside a quote. Bash renders any value
            # containing a newline with ANSI-C quoting, where \' is an escaped
            # quote, so one such trace line leaves the parser latched in
            # INPUT_SINGLE_QUOTE and every later line is silently discarded — an
            # empty report, no error, exit 0. Any test writing a multi-line shim
            # body through a variable hits it.
```

The bug is not history — the patch two lines below exists because kcov still parses this way
today — so swapping `left`/`was discarded`/`hit` for `leaves`/`is discarded`/`hits` turns a
past incident report into the present description of the trap the patch guards against.

### Example B: `check-scripts`, the shebang-gating rationale

Before:

```bash
# whether or not they carry a shebang. Gating shellcheck on the shebang alone left
# 31 of 83 test files silently unlinted (#215).
```

After:

```bash
# whether or not they carry a shebang. Gating shellcheck on the shebang alone would
# leave 31 of 83 test files silently unlinted.
```

`left` describes a defect that was fixed and is gone; `would leave` describes what happens if
a future edit reintroduces the shebang-only gate, which is the actual reason this line is
still here at all — the rewrite changes which failure mode the sentence is warning about.

## Disposition 5 — runtime string

`run-tests`'s tripwire message, plus the four assertions in `test/root/run-tests.bats` that
pinned it:

Before, `run-tests`:

```bash
    log::die "test suite mutated the real repo (#248) — before: [${before//$'\n'/ }] after: [${after//$'\n'/ }]"
```

After, `run-tests`:

```bash
    log::die "test suite mutated the real repo — before: [${before//$'\n'/ }] after: [${after//$'\n'/ }]"
```

Before, `test/root/run-tests.bats` (all four assertions):

```bash
  assert_output --partial '#248'
  assert_output --partial '#248'
  refute_output --partial '#248'
  refute_output --partial '#248'
```

After, same four, in order:

```bash
  assert_output --partial 'mutated the real repo'
  assert_output --partial 'mutated the real repo'
  refute_output --partial 'mutated the real repo'
  refute_output --partial 'mutated the real repo'
```

A runtime string is not just prose — a test can pin it — so cutting the number here is a
two-file edit: the assertions are coupled to the exact substring they check, and re-anchoring
them onto stable prose in the same change is what keeps the suite from silently checking
nothing the moment the string moves.

## Disposition 6 — regression `@test`

`test/ci/pre-push.bats`, the test proving the fixture-escape defense actually strips the
inherited git environment:

```bash
@test "strips repo-scoped git env before running the gate (#248)" {
```

The number stays because it is not attribution here, it is identity: this test exists to
guard one specific regression, the number is the fastest way to find every test protecting
against it, and the comment two lines above already carries the present-tense account of what
the defense does — the title's job is to name the defect, not re-explain it.

## Disposition 7 — never touch

`.ci/check-tree-scan-root` documents its own bracket-obfuscation device, so the sweep leaves
it exactly as it is:

```bash
# @description Print every offending line in a file as "LINENO: TEXT".
#              A line offends when it expands SCRIPTS_DIR and is neither a comment
#              nor the canonical library-sourcing line.
#              The patterns below deliberately spell the variable as
#              \$[{]SCRIPTS[_]DIR[}] and \$SCRIPTS[_]DIR rather than literally, so
#              this script does not flag its own source. Both devices are load
#              bearing: bracketing the braces defeats the braced pattern, and
#              bracketing the underscore defeats the unbraced one — without the
#              latter, the text `\$SCRIPTS_DIR(` inside the second regex contains a
#              literal $SCRIPTS_DIR and the lint flags itself.
```

This reads like a typo — a stray `[_]` sitting inside an otherwise ordinary variable name —
and "fixing" it back to a literal `SCRIPTS_DIR` makes the pattern match the pattern's own
source line, so the lint fails against itself the next time it runs. The same family of
device shows up as `y[q]` / `j[q]` in `.ci/check-errexit-predicate` and as the `@@STDERR@@`
sentinel in the stderr-assertion tests; all three exist for the identical reason and none of
them are comments about history, so none of them are this skill's business.

## Calls that went the other way

Two hits from that same sweep were examined and deliberately not cut on the first pass, for
reasons worth carrying forward.

**`flake.nix`, the bats-libraries comment.** The task sweeping `flake.nix` named four target
paragraphs and this one — "bats-support and bats-assert used to be git submodules under
`test/test_helper/`, loaded by relative path" — was not among them, so it was left alone as
outside that task's brief. A second pass overturned that call: no later step in the plan
revisits `flake.nix` at all, so leaving it there meant it would survive the entire sweep
regardless of which task's scope it fell outside of. It was cut in a follow-up commit, present
tense, the same way as the other disposition-4 hits. The lesson is that "out of this task's
scope" and "out of the sweep's scope" are two different questions, and only the second one
decides whether a hit gets left behind for good.

**`test/root/run-tests.bats`, two comments still carrying their numbers.** The tripwire
fixture comments — one describing the simulated fixture escape, one explaining why `BASH_ENV`
is set rather than unset — were left untouched even though they matched the same numbered
pattern as everything else in that file. `test/` is swept wholesale by a later step in this
series, so pulling these two into an earlier, narrowly-scoped change would have bought nothing
and blurred that change's boundary for a reviewer. Leaving a hit alone is the right call when
you can name the later step that owns it — the same repo scanned twice is fine; the same repo
edited by two overlapping changes at once is how a diff gets hard to review.
