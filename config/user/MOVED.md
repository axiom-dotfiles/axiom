# Moved

axiom now keeps its config and state in the XDG folders. These were copied there on 2026-10-15:

- `/home/travmonkey/.config/quickshell/axiom/config/user/` → `/home/travmonkey/.config/axiom/`
- `/home/travmonkey/.config/quickshell/axiom/config/state/` → `/home/travmonkey/.local/state/axiom/ui/`
- `/home/travmonkey/.config/quickshell/axiom/config/state/notes/` → `/home/travmonkey/.local/share/axiom/notes/`
- `/home/travmonkey/.config/quickshell/axiom/config/themes/generated/` → `/home/travmonkey/.local/state/axiom/themes/`

The copies here are no longer read (only an older axiom would read them) and can be deleted.
