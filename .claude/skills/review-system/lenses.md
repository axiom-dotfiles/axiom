# System review lenses

The checklist for `SKILL.md` Phase 3, walked through for each file read deeply (and, in `--deep` mode, the prompt for each agent with "Every reviewer" from `../review-branch/lenses.md`, reading "the system" for "the branch": everything in it is fair game, there are no pre-existing problems inside it). The `rules` lens is `../review-branch/lenses.md` › rules: use it as is.

## contract: are the docs true?
The system's docs are its contract. For every statement a doc makes about behaviour (who decides what, what never happens, which file owns what, what a member returns), find the code that makes it true. A statement no code backs, or code that does otherwise, is a finding: say which side is wrong. The doc's `Files:` header lists files that are gone or that no longer do what the doc says; a mechanism the code has that no doc mentions, in an area where the docs are otherwise complete.

## edges: correctness where it's rarely exercised
Bugs in long-lived code hide on the paths nobody takes daily. For each risky function walk:
- monitors added, removed, renamed, scaled; no monitor; several;
- a QML hot reload (state that should survive in `PersistentProperties`, handlers that double-connect, processes left running);
- startup order (a reader or service used before it's ready, a signal fired before the listener exists);
- each compositor the code runs under (what `supports` says vs what the code assumes);
- every setting it reads turned off, at its minimum and maximum, empty;
- rapid repeats (open/close/open, two requests in flight, a Process restarted while running);
- failure (a command missing, a file unreadable, malformed JSON, a socket gone).

## dead: what nothing uses
Members, files, schema keys, reader properties, `supports` keys, script flags, IPC functions, test helpers that nothing reaches. Grep repo-wide, and remember what's reached by name (bar widget and content `type`, `popoutName`, views, `x-card`/`x-intro`, IPC, schema annotations, `Qt.createComponent` strings). Also code that is alive but can't do anything: a branch whose condition is always false, a parameter every caller passes the same, a property always overwritten before it's read.

## duplication: the same job done twice
Inside the system (two components or functions doing one job, a helper copied with small changes), and against the shared pieces (`docs/dev/core/shared-ui-pieces.md`, `components/methods/`, `components/reusable/`). A decision a methods helper makes, worked out again elsewhere, counts double: it's also a rules break.

## shape: is the system as simple as it can be?
Step back from single lines: layers that only forward, two sources of truth for one fact, state kept in sync by hand that could be a binding, a manager whose job has shrunk to nothing, a generalisation with one user, special cases the general path already covers, an abstraction bent to fit what it wasn't meant for. Each finding names the simpler shape and what moves where; skip what is only taste.

## seams: how the rest of axiom uses it
Grep the system's public members from outside it (the scope's `[also in: …]` files are where it meets other systems). Users reaching into private (`_`) members or internals, decisions re-derived outside instead of read from the system, members used in a way the docs say not to, two users relying on contradictory behaviour.

## tests: are the decisions pinned down?
Each methods helper's decisions have test rows, including the edge cases the `edges` lens finds; each migration step has a case; each script with behaviour has a test class. A finding names the missing row and the bug it would catch, not "add more tests".

## parity (mode `parity`)
Build the table first: each contract member, `supports` key or rule × backend, one line per cell (`implemented` / `differs: how` / `missing`), from the code, not the docs. Then every cell that differs is either a declared `supports` gap (fine, check it's declared on every backend) or a finding. Look hardest at the same input giving a different shape: ids, names, ordering, units, empty states, events on reload.

## collection (mode `collection`)
Many files of one kind. Don't read each whole: grep each rule from the docs and the system's Checks across all of them (`grep -L` finds the ones missing a pattern, `grep -c` the outliers), build a small table (file × rule), then read only the odd ones out and the biggest. Findings are the files that break a rule, and patterns repeated in several files that belong in a base or shared piece.

## security (systems `security`, `greeter`)
What is reachable, shown or runnable while locked or in greeter mode; every unlock and authentication path (only PAM succeeds); secrets in argv, config, logs, environment or files with loose permissions; input from other processes (IPC, D-Bus, files the user can write) trusted without a check; a failure that fails open.
