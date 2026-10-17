# Packaging: install.sh and packaged installs

> **Files:** `install.sh`, `scripts/check_packages.py`, `components/methods/Packages.qml`, `config/Paths.qml`
> **Config:** none
> **Related:** [Self-update](features/self-update.md), [Greeter install](features/greeter-install.md), [Onboarding](features/onboarding.md), [Config manager](core/config-manager.md)

How axiom gets onto a machine: the installer (a clone in the user's home) or a distribution package (root's copy in `/usr/share/axiom`). The user-facing side is `docs/installation.md`.

### Two package lists, kept in step
- `Packages.packages` (the onboarder's install hints) and install.sh's `PACKAGES` table both say what installs a dependency.
- They share keys: a command, a compositor by its lowercase name, `py:<module>`, `iconFont`, or a package without a command (`xdg-desktop-portal-gtk`).
- `scripts/check_packages.py` (CI, `check_all.sh`, `verify.sh` when one of them changes) fails when:
  - an install.sh key's Arch or Fedora package differs from `Packages.packages` (a COPR is `owner/project:name` there and `{ name, repo }` here; `download` is `{ file, to }`, the same URL and file; `-` and `n/a` are `null`);
  - a key in `REQUIRED`, `FEATURES` or a compositor isn't in `PACKAGES`.
- Adding an optional feature: its keys in `Packages.packages` (if new), a `PACKAGES` row and a `FEATURES` row.

### install.sh
- One self-contained file, wrapped in `main` so `curl | bash` reads all of it first. Questions and the package manager read `/dev/tty`.
- **Distribution:** `distro_family` follows `Packages.distroFamily`'s rule (os-release `ID`, else the first known `ID_LIKE`). Arch uses `pacman -T` / `pacman -S --needed`; Fedora `rpm -q --whatprovides` / `dnf install`, each COPR enabled first (`dnf copr enable`, the copr plugin installed if missing), and the icon font downloaded into `~/.local/share/fonts` as the user.
  - `PACKAGES` cells: a package, `owner/project:name` (from that COPR), `download`, `-` (nothing needed there: `checkupdates` on Fedora) or `n/a` (not packaged there: `awww` on Fedora, whose feature is listed as not available).
  - COPRs: quickshell from `errornointernet/quickshell` (the one quickshell's docs name; Fedora's own is too old), Hyprland and its tools from `nett00n/hyprland`. Each is asked separately; declining one a required package needs stops the install.
- **Compositor:** the main one is `--compositor` if given; else the running one (`HYPRLAND_INSTANCE_SIGNATURE`, `NIRI_SOCKET`, `SWAYSOCK`); else the installed one whose config already starts axiom (an earlier run's); else it asks among the installed ones; with none installed, it asks which to install (Hyprland by default, and without a terminal). The main one is what the session gets into (the TTY offer).
  - Every other installed compositor is offered the autostart line too, asked separately and defaulting to no: Hyprland may be there only for the login screen, whose feature installs it.
  - Each gets the autostart line its `*ConfigWriter.autostartTarget` writes (`AUTOSTART`), unless a line matching the same `accept` pattern is there. A missing config is seeded from the compositor's default (`/usr/share/hypr/hyprland.lua`, `/etc/sway/config`, `/usr/share/doc/niri/default-config.kdl`); with no default to seed from, it says what to add instead of writing a config with no binds.
  - Night light's tool and X11 apps' helper (`xwayland-satellite` on niri, Xwayland on sway) depend on the compositors (`FEATURES`' third column; `DependencyManager.tools`' `compositors`). The login screen's feature installs Hyprland, which it runs whatever the session's compositor is.
  - Versions: Hyprland below 0.55 warns; sway and niri below what axiom is tested with (`TESTED_SWAY`, `TESTED_NIRI`) only say so.
- **`--dry-run`:** every change goes through `run` / `sudo_run` / `append_line`, which print instead.
- **Packaged:** with `/usr/share/axiom/.packaged` and no clone, it skips the clone and only does packages and autostart.
- **Testing:** `--dry-run` on the host, and real runs in `fedora:latest` / `archlinux:latest` containers with a sudo user and `AXIOM_REPO` pointing at a mounted clone (copy install.sh out of the clone first, or it treats the read-only mount as the install). Never run it for real on the dev machine.

### What a package provides
A distribution package installs axiom for every user, read-only:
- The code in `/usr/share/axiom`, less what only development needs (tests, docs, CI, git hooks, `install.sh`, the check scripts, every `*.md`).
- The marker `/usr/share/axiom/.packaged`, holding the package's version (`<version>-<release>`).
- A link `/etc/xdg/quickshell/axiom` → `/usr/share/axiom`, so `qs -c axiom` finds it after `~/.config/quickshell/axiom` (a clone there still wins).
- Nothing writes under the code ([config-manager.md](core/config-manager.md) › Where files live). Python's bytecode cache can't be written there either, which Python ignores; ship none, since bytecode for one Python version goes stale on the next.
- No compositor as a hard dependency: any of Hyprland, sway (or SwayFX) and niri runs it.

### A packaged shell
`Paths.packagedVersion` reads the marker beside the code (`Paths.packaged` when there is one). It changes:
- **Self-update:** off ([self-update.md](features/self-update.md)): it never checks, its settings section (`"/$packaged": false`), the onboarder's rows and `/update` are hidden.
- **Login screen:** always the `package` source ([greeter-install.md](features/greeter-install.md)): the greeter runs `/usr/share/axiom` itself, and `Greeter.source` is hidden.
