---
name: review-branch
description: Thorough review of everything the current branch changes against main (bugs, regressions, dead or repeated code, simplification, illogical choices, axiom rule breaks, stale docs), with parallel reviewers and an adversarial verification pass. Use when the user says "review the branch", "review my changes", "code review", "is this branch ready", or runs /review-branch with a short description of what the branch is for.
argument-hint: "<what the branch is for> [base:<ref>] [fix] [quick]"
---

# Branch review

You are the lead reviewer of an axiom branch. The maintainer wants it merged only when it is correct, as simple as it can be, and follows every rule in `AGENTS.md`. Your job is to find what is actually wrong, prove it, and say exactly how to fix it. A review that pads the list with guesses is worse than a short one: the maintainer has to check each item.

Arguments: `$ARGUMENTS`
- Free text is the author's description of what the branch is for. It is a claim to check, not a fact.
- `base:<ref>` reviews against `<ref>` instead of `main`.
- `fix` applies the confirmed findings after the report (Phase 5). Without it the review changes no code.
- `quick` skips the verification agents (Phase 3): you verify the findings yourself.

## Phase 0: scope and brief

Work in `$SCRATCH/review/` (`$SCRATCH` = this session's scratchpad directory). If a `report.md` from an earlier run is there, move it to `report.prev.md`: Phase 4 says which of its findings are gone.

1. `mb=$(git merge-base <base> HEAD)`. The review covers `git diff $mb` (committed **and** uncommitted work) plus untracked files (`git ls-files -o --exclude-standard`). Save the diff to `diff.patch` (`git diff --no-color -U10 $mb`, then each untracked file appended with `git diff --no-color --no-index /dev/null <file>`), and the changed paths to `files.txt`. Nothing changed: say so and stop.
2. Read `git log --format='%h %s%n%b' $mb..HEAD`, `git diff --stat $mb`, and the whole diff yourself. You are the one who must understand the branch end to end; reviewers go deep on one angle each.
3. Write `brief.md` (reviewers read it first):
   - **Intent**: the description from the arguments, the commit messages, and what the diff shows. Where they disagree, say so.
   - **Claims**: every concrete thing the branch says it does ("fix X", "support Y on niri", an `issues.md` entry added or removed). Each one gets checked.
   - **Changes by area**: grouped by layer (methods, config/schema, services, UI, scripts, docs, tests), one line each.
   - **Docs to read**: the `docs/dev/` docs whose `Files:` header lists a changed file (`grep -rln '<path>' docs/dev --include='*.md' | grep -v generated/`), the local `AGENTS.md` of every touched directory, and `docs/dev/issues.md` entries touching the same files.
   - **Compositors**: whether the change reaches Hyprland, sway or niri paths, and which `CompositorManager.supports` keys it reads or adds.
   - **Size**: changed lines and files.
4. Start the mechanical checks in the background (Phase 1) and move on.

## Phase 1: mechanical checks (background)

`git status --porcelain > status.before`, then in one background Bash: `scripts/check_all.sh --no-docs; python3 scripts/gen_docs.py --check; python3 scripts/check_doc_drift.py`, output to `checks.log`. When it finishes, `git status --porcelain` again: a check that rewrote a file is itself a finding (unformatted QML, stale generated docs); restore nothing, report it.

Also read `scripts/log.sh` (the live shell, which runs this checkout): every `WARN`/`ERROR` not marked `(known: …)` that names a changed file, or that the change could plausibly cause, is a finding. The shell may not have reloaded the latest state; say so rather than guess.

Every failing check is a finding at blocker level. Don't send reviewers after what these checks already catch (format, lint baseline, structure, i18n keys, generated docs): they report what the checks can't.

## Phase 2: lens reviewers (parallel)

Read `lenses.md` (next to this file). Launch one `general-purpose` Agent per lens **in a single message** so they run together. Each prompt is: the "Every reviewer" contract from `lenses.md`, then that lens's section, then the paths to `brief.md`, `diff.patch` and `files.txt`, and the output file to write (`findings-<lens>.md`).

When the diff is over ~2500 changed lines or 40 files, split the `bugs` lens by area (e.g. services+methods / UI / scripts), each reviewer getting its own file list. Stay under ten agents in all.

While they run, do your own pass: check every **Claim** from the brief against the code. A "fix" that doesn't fix, or fixes a symptom one caller over, is the most valuable finding there is.

## Phase 3: verify

Merge the reviewers' findings with yours. Dedupe by root cause (two lenses reporting one cause = one finding citing both angles). Drop anything on lines the branch didn't change unless the branch made it wrong (a caller it broke, a doc it made false); those pre-existing ones go to Phase 4's last section.

Then every finding gets checked by someone who didn't raise it. Launch `general-purpose` verifier agents in one message, about six findings each, grouped by file, with this brief:

> You are checking another reviewer's findings on an axiom branch, and you expect some to be wrong. For each one, read the cited code, the whole function and its callers, and the docs it relies on, and try to prove it false: is the path actually reachable, is it handled elsewhere, does the "dead" code have a caller grep misses (loaded by name from a string, `x-card`, `popoutName`, `type`-dispatched files, IPC, schema), is the "rule" one AGENTS.md actually states, does the simpler version keep every behaviour? Answer per finding: `CONFIRMED` (you traced it: give the evidence), `PLAUSIBLE` (can't be settled without running the shell: say what would settle it), or `REFUTED` (say why). Correct the severity, line or fix if they're off. Change no files.

With `quick`, do this yourself instead. Drop `REFUTED`. Keep `PLAUSIBLE` only at major or above, marked as such.

## Phase 4: report

Write `report.md` and print it. Order by severity, then file. Nothing in it the maintainer can't act on.

```
# Review: <branch> vs <base> (<n> commits, <files> files, +<a> −<d>)

**Verdict:** ready / ready after the fixes below / needs rework: <one sentence why>
**Intent check:** <does the branch do what it says; any claim that doesn't hold>

## Blockers        (wrong behaviour, regressions, failing checks, safety rules broken)
## Major           (bugs on a less common path, rule breaks the checks miss, design that will bite)
## Cleanups        (dead code, duplication, simpler shape: each with the simpler version)
## Minor           (naming, comments or docs that mislead, small inconsistencies)

Each finding:
### <n>. <claim in a few words>  `path/File.qml:123`
<what is wrong, and the concrete scenario: the input, state or compositor, what happens, what should>
**Fix:** <the change, as code when it's short>
<!-- lens(es), verdict -->

## Checked and fine
<a few lines: risky things you looked at and found sound, so the maintainer knows what was covered>

## Questions for the author
<only where the intent can't be read from the code and the answer changes a finding>

## Pre-existing problems
<problems found outside the branch's changes: added to docs/dev/issues.md in its format, listed here by title>
```

If `report.prev.md` exists, add a line under the verdict: which earlier findings are now fixed, which still stand.

Adding the pre-existing problems to `docs/dev/issues.md` (its format is at its top; check it doesn't already have them) is the only edit a review makes without `fix`. Say that you did it.

## Phase 5: fix (only with `fix`)

Apply the Blockers, Major and Cleanups findings, smallest change each, following the repo rules (recipes, shared pieces, docs updated with the code). Skip a finding whose fix needs a decision from the maintainer and list it. Then `scripts/dev/verify.sh` until `verify ok`, read the log section and the docs it lists. Don't commit. Report what changed per finding, and anything that turned out different once you were in the code.
