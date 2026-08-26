---
name: comment-archaeology-sweep
description: Cuts chronology out of code comments and runtime strings — issue/PR numbers, accounts of prior implementations, references to plan documents — while keeping the rationale a reader can act on. TRIGGER RULES — (1) When the user explicitly invokes the slash command `/comment-archaeology-sweep [path]`, run the skill immediately without asking. (2) When the user makes a natural-language request that sounds like this skill's purpose ("sweep the comments", "cut the issue numbers", "clean up the historical comments", "does this comment still earn its place", or any paraphrase), do NOT auto-run — first ask the user "Run the comment-archaeology-sweep skill on <path>?" and only proceed if they confirm. Never silently invoke the skill from a natural-language request. The skill applies its rubric autonomously, leaves the working tree dirty, and produces a rationale report. It does NOT commit.
agent: true
---

# comment-archaeology-sweep

Cut chronology out of comments and runtime strings while keeping the rationale intact.

## Trigger

Two paths:

1. **Slash command** — `/comment-archaeology-sweep [path]`. Run the skill immediately. No
   confirmation prompt.
1. **Natural-language paraphrase** — anything that sounds like this skill's purpose ("sweep the
   comments", "cut the issue numbers", "clean up the historical comments", "does this comment
   still earn its place", etc.). Do NOT auto-run. Ask first: "Run the comment-archaeology-sweep
   skill on `<path>`?" Proceed only on confirmation. If the user says no, handle the request
   however they prefer (or not at all).

Never silently invoke the skill from a natural-language request — the confirmation prompt is
mandatory in that path.

## The rubric

The single test:

> Would a reader who has never seen the issue tracker act differently because of this text?
> **Yes** → keep it, present tense, no number. **No** → cut it.

| #   | Shape                                              | Action                                                                                                                                                                                                                                                         |
| --- | -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 1   | Complete sentence + trailing `(#NNN)` / `(#N, #N)` | Strip the parenthetical, keep the terminal period. Mechanical.                                                                                                                                                                                                 |
| 2   | Number mid-sentence in load-bearing prose          | Rewrite present-tense without the number. If the sentence exists only to attribute, delete the sentence.                                                                                                                                                       |
| 3   | Pure archaeology block                             | Delete. If the current shape still needs explaining, keep one present-tense sentence stating the constraint.                                                                                                                                                   |
| 4   | Superseded-state narration                         | If the shape is a real trap, state the trap in the present tense; drop the account of who fell into it.                                                                                                                                                        |
| 5   | Runtime string carrying `(#NNN)`                   | Strip. Where a test asserts on the number, re-anchor the assertion on stable prose.                                                                                                                                                                            |
| 6   | Regression `@test` title                           | May keep the number — the defect is the test's subject. Prefer a one-line defect description over a bare `#NNN`.                                                                                                                                               |
| 7   | Never touch                                        | Lint self-reference devices (`y[q]`, `j[q]`, `@@STDERR@@` sentinels), `scripts/other/`, CLAUDE.md apart from the one verbatim `inherit_errexit` block. Prose inside an shdoc block may be edited; a `@description` / `@arg` / `@exitcode` tag is never gutted. |

Dispositions 3 and 4 differ in what survives. 3 deletes and may leave nothing. 4 always
leaves a present-tense statement of the trap, because the trap is why the code looks odd
and a reader who does not know it will "fix" the code.

`references/casebook.md` holds one worked before/after pair per disposition, lifted from the
PR that established this rubric, plus a section on two calls that went the other way. Read it
before the first Tier 2 judgment call of a run — the sentence under each pair is what transfers
between hits, not the diff itself.

## Inputs

An optional path — a file or a directory. With no argument, sweep the whole repo. Resolve the
root with `git rev-parse --show-toplevel`; a supplied path outside that root is an error.

## Target set

Build the target set from `git ls-files`, never a filesystem walk — a gitignored scratch file
sitting in the tree is not part of the corpus.

Excluded unconditionally: `scripts/other/` (third-party, never modified for any reason),
`.shdoc/`, `site/`, and markdown. CLAUDE.md's issue references are deliberate provenance for
decisions a reader is being told not to relitigate; they are out of scope. The single
exception is a code block in CLAUDE.md that reproduces a tree comment verbatim as a mandated
form — that must track the tree, or it instructs new code to reintroduce what was just cut.

## Workflow

1. Resolve the root, build the target set, and print hit counts by area **before editing
   anything**. Two enumerations: `#[0-9]{1,4}([^0-9]|$)` for numbered hits, and
   `used to|no longer|previously|formerly|had been|it replaced` for numberless narration.
1. **Tier 1** — strip trailing parentheticals (disposition 1) mechanically. Edit in place with
   `sed --in-place`. The `files::create_temp` → move idiom strips the executable bit off the
   destination and no gate in this repo catches it.
1. **Tier 2** — for each remaining hit, read the *whole comment block plus the code it
   describes* before deciding. Judging a comment line in isolation is how rationale gets cut:
   the sentence that looks like archaeology is often the one explaining why the line below it
   is not a mistake.
1. **Coupling check** — after any edit to a runtime string, grep the suite for assertions on
   the removed text and re-anchor them onto stable prose. Assertions on a bare number are the
   shape to look for; they fail loudly, but only if the suite is run.
1. **Reflow** — a stripped parenthetical or a deleted clause leaves ragged wrapping. shfmt does
   not reflow comments and neither does any other gate here, so rewrap the block yourself to
   120 characters at its existing comment column. After rewrapping, verify no comment line
   begins with `shellcheck` or `shfmt` — ShellCheck reads `# shellcheck ...` at the line start
   as a directive, failing with SC1072/SC1073. The trap is reflow-specific; the words are
   harmless mid-sentence. Reword to fix, never add a suppression. Verify with `grep -nE
   '^\s*#\s+(shellcheck|shfmt)\b' <changed-files>` and confirm each match is intentional.
1. **Verify** — `nix fmt`, then `./.ci/in-devshell ./run-all-checks`. Both clean. Then
   `git diff --summary` — it must print nothing. A `mode change` line means step 2 lost an
   executable bit.
1. **Report**, then stop.

## Never touch

- `scripts/other/`, for any reason, including formatting.
- Lint self-reference devices: bracket-obfuscated tool names (`y[q]`, `j[q]`), the
  `@@STDERR@@` sentinel, and any fixture line composed at runtime so a lint scanning the real
  tree does not flag itself. These look like typos and are load-bearing.
- shdoc tag names. Prose inside a `@description` may be edited; the tag is never removed or
  emptied, and `check-shdoc-headers` fails a bare word-bounded `TODO` in any annotation block.
- A regression `@test` title's number, unless you are replacing it with a one-line description
  of the defect. The defect is that test's subject.

## Report

Three parts. Under full autonomy this report is the review artifact, so it is not optional and
not a summary.

1. **Summary table** — hits by area, by disposition.
1. **Per-hit log** — one line each: `path:line — disposition N — <before> → <after | deleted>`.
1. **Left alone, and why** — every hit examined and not changed, with the reason. The
   decisions most worth a reviewer's eye are the ones that produce no diff, and they are
   invisible in `git diff`.

## Hands off git

Do not `git add`, `git commit`, `git branch`, or `git push`. The skill ends at a dirty working
tree plus the report. Commits here must be signed and PR titles are lint-gated; both are the
user's to get right.
