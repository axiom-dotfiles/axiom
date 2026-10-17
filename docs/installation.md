# Installation and setup

[README](../README.md) · [Features](features.md) · [Installation](installation.md) · [Keybinds, IPC and launcher](usage.md) · [Configuration](configuration.md)

## Requirements

The whole shell runs on five things. Everything else is optional and only needed for the feature that uses it.

**Required**
- A Wayland compositor: [Hyprland](https://hypr.land) 0.55+ with its Lua config (`hyprland.lua`), [niri](https://github.com/YaLTeR/niri) 26.04+, or [sway](https://swaywm.org) 1.12+ (SwayFX adds blur and rounded corners). What each supports is in the [README](../README.md#compositors)
- [Quickshell](https://quickshell.org) 0.3.2 or newer (`qs`)
- [Material Symbols](https://fonts.google.com/icons) for icons (`ttf-material-symbols-variable`). Any font works for text
- `jq`, `python3`

<details open>
<summary><b>Optional</b>, for the features that use them</summary>

| Feature | Needs |
| --- | --- |
| Wallpaper transitions (optional backend) | `awww` (not packaged for Fedora) |
| Network widget / module, Wi-Fi menu | NetworkManager, Quickshell built with its Networking module, and `ip` (iproute2) |
| Updates | Arch: `pacman-contrib` (`checkupdates`), plus `paru` or `yay` for AUR updates. Fedora: `dnf` (nothing extra). Hidden on other distributions |
| Tailscale | `tailscale` |
| Screenshots | `wl-copy`; `satty` or `swappy` to annotate; `wf-recorder` to record, and `pactl` (libpulse; works with pipewire-pulse) to record the system's sound |
| AI chat | `curl`; `secret-tool` (libsecret) to keep keys in your keyring; `wl-clipboard` to paste images |
| Launcher calculator | `qalc` (libqalculate), `wl-copy` |
| Launcher emoji picker | `wl-copy` to copy; `wtype` to type an emoji into the focused window (Shift+Enter) |
| Brightness (keys, OSD bar) | `brightnessctl` for a laptop panel; `ddcutil` for external monitors over DDC/CI (monitors that support it, with i2c access: the package's udev rule gives it to the logged-in user) |
| NVIDIA GPU stats | `nvidia-smi` (AMD is read from sysfs) |
| Idle (dim, lock, screen off, suspend) | `hypridle` (it runs on every compositor) |
| Login screen | `greetd` and its text login `agreety` (`greetd-agreety` on Arch), the fallback; `pkexec` (polkit) to install it |
| Themes generated from the wallpaper | The Python packages numpy and Pillow (`python-numpy python-pillow` on Arch, `python3-numpy python3-pillow` on Fedora) |
| Calendar | The Python package icalendar (`python-icalendar` on Arch, `python3-icalendar` on Fedora); `secret-tool` (libsecret) to keep account passwords in your keyring |
| Browse buttons for folders, importing a shared config | xdg-desktop-portal with a file chooser backend (`xdg-desktop-portal-gtk` or KDE's) and `python-gobject`; or `zenity` or `kdialog`. Without them, type the path |
| Polkit prompt | Nothing: axiom is the agent itself, and stops another one (hyprpolkitagent, KDE's, GNOME's) while it's on |
| Night light | `wlsunset`, or `hyprsunset` on Hyprland |
| X11 apps (Steam, games, older apps) | On niri, `xwayland-satellite` (niri runs X11 apps only through it); on sway, Xwayland (`xorg-xwayland` on Arch, `xorg-x11-server-Xwayland` on Fedora). Hyprland's package brings Xwayland itself |
| Clipboard history | `wl-clipboard`; `cliphist` to share the history with other apps |
| Notes | `gio` (glib2) to move deleted notes to the trash |
| Theme integrations | The app itself (`kitty`, `alacritty`, `foot`, `wezterm`, `ghostty`, `nvim`, `helix`/`hx`, VS Code or VSCodium, Zed (`zed`/`zeditor`), Firefox or a fork (LibreWolf, Zen, Floorp, Waterfox), Vesktop or Vencord, `zathura`, `ncspot`, `k9s`, `cava`, `btop`, `fzf` 0.49+, `lazygit`, `bat`, `yazi` 25.5+); `qt5ct`/`qt6ct` for Qt; `adw-gtk-theme` for GTK3 apps |

</details>

## Installation

On Arch Linux, Fedora, or a distribution based on either (CachyOS, EndeavourOS, Manjaro, Nobara, …), run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
```

It first prints its plan: the distribution, the compositor and each step. Then:

1. **The compositor.** It uses the one you're running; else the one an earlier run set up; else, with several installed, it asks which one you use. It also offers to start axiom from every other one installed (each asked, default no). With none installed, it asks: Hyprland (the default, with every feature, and what the login screen runs), niri, or sway. It doesn't install SwayFX, which replaces sway in place (the AUR's `swayfx` on Arch, COPR `swayfx/swayfx` on Fedora). `--compositor hyprland|sway|niri|none` picks without asking.
2. **Packages.** It lists the optional features and offers them all at once (recommended), or one at a time, skipping any already installed. A feature with no package on your distribution is listed as not available there (wallpaper transitions on Fedora). It then shows the one `sudo pacman` or `sudo dnf` command it will run, and why, before running it.
   - On Arch, every package comes from the official repositories.
   - On Fedora, quickshell comes from the COPR `errornointernet/quickshell` and Hyprland and its tools (hypridle, hyprsunset, satty) from `nett00n/hyprland`: Fedora's own quickshell is too old, and Hyprland left its repositories. A COPR is a third-party repository on Fedora's build service, so each one is shown and asked separately, and only enabled when something you picked needs it. The icon font isn't packaged there either: it's downloaded into `~/.local/share/fonts`, as you.
3. **The clone.** It clones the latest release into `~/.config/quickshell/axiom`.
4. **Autostart.** It asks before adding the line that starts axiom to the end of the compositor's config (`hyprland.lua`, sway's `config`, niri's `config.kdl`), backing up the file first. A config that doesn't exist yet starts as the compositor's own default one, so its starter keybinds are there too.

Run from a text console (a TTY) outside a graphical session, it last offers to start the compositor. `--yes` answers yes to every question, `--minimal` installs only what's required, and `--dry-run` prints every command it would run and changes nothing. Running it again is safe. From a clone, run `./install.sh`: that clone is used wherever it is, and if it isn't at `~/.config/quickshell/axiom` (where `qs -c axiom` looks), the installer offers to link it there, or to move it.

<details>
<summary><b>By hand</b>, or on another distribution</summary>

Install the [requirements](#requirements), then clone into Quickshell's config directory:

```bash
git clone https://github.com/axiom-dotfiles/axiom.git ~/.config/quickshell/axiom
```

`qs -c axiom` starts it once. To start it with your session, add its line to your compositor's config (`-n` keeps a second copy from starting):

| Compositor | File | Line |
| --- | --- | --- |
| Hyprland | `~/.config/hypr/hyprland.lua` | `hl.on("hyprland.start", function() hl.exec_cmd("qs -n -c axiom") end)` |
| niri | `~/.config/niri/config.kdl` | `spawn-sh-at-startup "qs -n -c axiom"` |
| sway | `~/.config/sway/config` | `exec qs -n -c axiom` |

</details>

That start-up line is all your compositor needs. Which compositor you're on is picked up at start, and settings it can't use are left out of the settings page. What each one supports is in the [README](../README.md#compositors).

## Compositor modes

How axiom sets up the rest of the compositor (its keybinds, the window look, input, monitor profiles and a few required settings) is **Settings → Compositor → Mode**. The modes work the same on every compositor; only the files differ.

| Mode | What it does |
| --- | --- |
| **Detached** (default) | Applies axiom's part at runtime, and again after every reload of the compositor's config. It skips any keybind whose key your config already uses, and never edits your config. niri only takes settings from files, so there axiom has niri load a wrapper (in `~/.local/state/axiom/`) that includes your config and then axiom's part, while axiom runs. |
| **Included** | Writes axiom's part to a file in `~/.local/state/axiom/` (under `$XDG_STATE_HOME` if it's set), which your config loads (see below). |
| **Managed** | axiom writes the compositor's whole config itself, from the settings: everything above, plus **Windows and focus**, **Session** (environment variables, autostart commands) and the compositor's own section (**Hyprland**, **niri** or **Sway**: layout, animations, and the like). It then loads your own files from a `user/` folder beside it, so you can still add anything axiom doesn't cover. |

Keybinds are edited on the **Keybinds** page in every mode. Presets add the essentials, workspace keys, window management, Alt+Tab, strips and the media keys in one click (see [Keybinds](usage.md#keybinds)). Whichever mode is set, axiom falls back to the runtime layer when its file isn't loaded, and the Compositor card says why.

### Included mode

Load axiom's file from your config. The Compositor card shows the line with **Copy** and **Add it for me** (which backs your config up first):

| Compositor | File axiom writes | Where to load it |
| --- | --- | --- |
| Hyprland | `~/.local/state/axiom/hyprland.lua` | Near the top of `hyprland.lua`, so your own lines after it win |
| niri | `~/.local/state/axiom/niri.kdl` | An `include` at the end of `config.kdl`: axiom's look wins, and your binds still win over axiom's |
| sway | `~/.local/state/axiom/sway.conf` | An `include` anywhere in your sway config |

For Hyprland:

```lua
local ok, axiom = pcall(dofile, os.getenv("HOME") .. "/.local/state/axiom/hyprland.lua")
if ok then axiom.setup() end
```

> [!TIP]
> On Hyprland, `setup()` applies everything switched on in the settings. To pick parts yourself, call `axiom.required()`, `axiom.binds()`, `axiom.look()` (the settings' Window look: themed borders, the shape, gaps), `axiom.input()` (the settings' Input), `axiom.blur()`, `axiom.layers()` (the stacking order of axiom's surfaces) and `axiom.monitors()` (the Monitors page's profiles) instead. `hl.unbind("KEY")` after it frees one of axiom's keys.

### Managed mode

| Compositor | axiom writes | Your own files |
| --- | --- | --- |
| Hyprland | `~/.config/hypr/hyprland.lua` | `~/.config/hypr/user/*.lua`, loaded in name order as `require("user.<name>")`. Shared modules go in `user/lib/`, which isn't loaded on its own |
| niri | `~/.config/niri/config.kdl` | `~/.config/niri/user/*.kdl`, included in name order |
| sway | `~/.config/sway/config` | `~/.config/sway/user/*`, included |

- **Taking over.** The first time, your old config is backed up and moved into `user/` as `00-previous` (dated if one exists already), unless it's the compositor's unchanged example config, which is only backed up. Lines in it that start axiom or load its included file are commented out, since axiom's config does both. Switching to another mode later moves it back.
- **Your binds** move onto the **Keybinds** page: each one axiom can express is taken out of `00-previous` (a dated backup stays beside it), and any it can't stay there and win over axiom's. Your other files in `user/` are only changed when you press **Merge** on the Keybinds page.
- **Asking first.** When there's a config of yours to take over, axiom waits for you to allow it (a notification, or **Allow** on the Compositor card), once per compositor. A config imported or carried over from another machine never counts as allowed.

> [!IMPORTANT]
> Managed mode never takes over a config folder that is a symlink or in a git repository.

`user/` itself may be a symlink, for example into a dotfiles repo.

### Required settings and switches

The Compositor section also holds switches for:
- **required settings:** what axiom's surfaces need from the compositor (on Hyprland: `misc.allow_session_lock_restore`, a rule ignoring apps' `maximize` requests, and a `workspaces` animation for the grid's slides)
- **theme-colored window borders**, the window shape, gaps, shadows and opacity (**Window look**)
- **blur behind axiom's surfaces** (Hyprland, SwayFX)
- **starting `awww-daemon`** (with the awww wallpaper backend)

The window look and **Input** (keyboard, mouse, touchpad, cursor) apply in every mode once switched on.

## Updates

axiom updates itself from the repository you cloned it from. It follows release tags (`v*`) by default, or every commit on `main` if you pick that channel under **Settings → Maintenance → axiom updates**. It checks when the shell starts and once a day, and the same page picks what happens next:

| Mode | What it does |
| --- | --- |
| **Notify me** (default) | Sends a notification. Clicking it opens **Settings → Maintenance → axiom updates**, which shows what's new and has an **Update** button. |
| **Update automatically** | Installs the update, reloads the shell, and notifies you. |
| **Off** | Never checks. **Check now** still works. |

An update only fast-forwards your clone. It won't touch a clone that has changed files, commits of its own, or a branch other than `main`. The page says why, and you update it yourself with git. Your config, state and generated themes aren't tracked by git, so an update never changes them.

## Idle and locking

axiom can run hypridle for you, on any compositor, from **Settings → Screen & Power → Idle**: dim, lock, screen off and suspend timeouts. It writes its own hypridle config and replaces a hypridle you already run (and starts yours again if you turn it off).

To keep your own idle daemon instead, point its lock command at axiom's built-in lock screen:

```ini
# hypridle.conf
general {
    lock_cmd = qs -c axiom ipc call lockscreen lock
    before_sleep_cmd = loginctl lock-session
}
```

```bash
# swayidle
swayidle -w timeout 300 'qs -c axiom ipc call lockscreen lock' before-sleep 'qs -c axiom ipc call lockscreen lock'
```

With **Lockscreen → Mode** set to `none`, axiom doesn't register the `lockscreen` target. Point your idle daemon at your own locker, and set **Lockscreen → Lock command** so that axiom's lock buttons run it too.

## Login screen (greetd)

Axiom can be your login screen, as a [greetd](https://sr.ht/~kennylevinsen/greetd/) greeter laid out on the Layouts page like the lock screen. It's off unless you install it, from **Settings → Screen & Power → Login screen** or the first-run setup. Install asks for your password once (pkexec), then:

- copies axiom's code to `/usr/share/axiom-greeter`, owned by root. greetd's user runs this copy, since it can't read your home folder. Where the code comes from is **Code from** on the same settings page:
  - **Git** (default): root fetches it from the repository you cloned axiom from, the newest release or the main branch, following **axiom updates → Follow**. The address is recorded at install, so nothing that can write to your clone (a changed remote, a local commit, an edited file) can change what the login screen runs. A new release or commit sends a notification, and **Update** fetches it.
  - **Local**: your clone as it is, whatever branch is checked out, uncommitted changes included. Use it to work on axiom. Any program running as you could change that code before your next **Update**, and then your password prompt is the only check, so the settings page warns you while it's on.

  Switching between them, or changing which channel axiom updates follow, needs an **Update** to take effect.

- makes `/var/lib/axiom-greeter`. Its `config/` folder is yours: axiom exports the login screen's layout, look, theme, wallpapers and monitor layouts there whenever they change, so changing them needs no password. Only the parts of your config the login screen shows go there, and greetd's user can read them.
- installs a polkit action, so Update and Remove ask for your password by name ("update or remove axiom's login screen") and run root's copy of the setup script rather than the one in your home folder.
- backs up `/etc/greetd/config.toml` (`.axiom-original`, plus `.axiom-bak-<date>` for each change), then points only its `default_session` command at axiom's greeter. The greeter runs in a Hyprland of its own, whichever compositor you log in to, so Hyprland has to be installed for it.

To make greetd your display manager, disable the current one and enable greetd (the settings card shows the commands). If the login screen fails to start, it tries again with the config saved at install, then falls back to greetd's text login, `agreety`. **Remove** puts greetd's config back and deletes both folders and the polkit action. Logging in through `agreety` starts your login shell.

The login screen only shows modules made for it (a clock, a greeting, weather, battery, the login box, the session picker, the keyboard layout and power buttons); nothing on it can open apps. The power buttons can go on the lock screen too. Fonts and cursor themes installed only in your home folder don't reach it: install them system-wide.
