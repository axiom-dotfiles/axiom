# Installation and setup

[README](../README.md) · [Features](features.md) · [Installation](installation.md) · [Keybinds, IPC and launcher](usage.md) · [Configuration](configuration.md)

## Requirements

The whole shell runs on five things. Everything else is optional and only needed for the feature that uses it.

**Required**
- [Hyprland](https://hypr.land) 0.55 or newer, with its Lua config (`hyprland.lua`)
- [Quickshell](https://quickshell.org) 0.3.1 or newer (`qs`)
- [Material Symbols](https://fonts.google.com/icons) for icons (`ttf-material-symbols-variable`). Any font works for text
- `jq`, `python3`

<details open>
<summary><b>Optional</b>, for the features that use them</summary>

| Feature | Needs |
| --- | --- |
| Wallpaper transitions (optional backend) | `awww` |
| Network widget / module, Wi-Fi menu | NetworkManager, Quickshell built with its Networking module, and `ip` (iproute2) |
| Updates | `pacman-contrib` (`checkupdates`), plus `paru` or `yay` for AUR updates |
| Tailscale | `tailscale` |
| Screenshots | `wl-copy`; `satty` or `swappy` to annotate; `wf-recorder` to record |
| AI chat | `curl`; `secret-tool` (libsecret) to keep keys in your keyring; `wl-clipboard` to paste images |
| Launcher calculator | `qalc` (libqalculate), `wl-copy` |
| Launcher emoji picker | `wl-copy` to copy; `wtype` to type an emoji into the focused window (Shift+Enter) |
| Brightness (keys, OSD bar) | `brightnessctl` for a laptop panel; `ddcutil` for external monitors over DDC/CI (monitors that support it, with i2c access: the package's udev rule gives it to the logged-in user) |
| NVIDIA GPU stats | `nvidia-smi` (AMD is read from sysfs) |
| hyprlock mode | `hyprlock`, and `hypridle` to lock on idle |
| Idle (dim, lock, screen off, suspend) | `hypridle` |
| Login screen | `greetd` and its text login `agreety` (`greetd-agreety` on Arch), the fallback; `pkexec` (polkit) to install it |
| Calendar | `secret-tool` (libsecret) to keep account passwords in your keyring; the Python packages `icalendar` and `recurring-ical-events`, which the installer's venv holds (`scripts/requirements.txt`) |
| Importing a shared config | xdg-desktop-portal with a file chooser backend (GTK or KDE) and `python-gobject`; or `zenity` or `kdialog` |
| Polkit prompt | Nothing: axiom is the agent itself, and stops another one (hyprpolkitagent, KDE's, GNOME's) while it's on |
| Night light | `hyprsunset` or `wlsunset` |
| Clipboard history | `wl-clipboard`; `cliphist` to share the history with other apps |
| Notes | `gio` (glib2) to move deleted notes to the trash |
| Theme integrations | The app itself (`kitty`, `alacritty`, `foot`, `wezterm`, `ghostty`, `nvim`, `helix`/`hx`, VS Code or VSCodium, Zed (`zed`/`zeditor`), Firefox or a fork (LibreWolf, Zen, Floorp, Waterfox), Vesktop or Vencord, `zathura`, `ncspot`, `k9s`, `cava`, `btop`, `fzf` 0.49+, `lazygit`, `bat`, `yazi` 25.5+); `qt5ct`/`qt6ct` for Qt; `adw-gtk-theme` for GTK3 apps |

</details>

## Installation

On Arch Linux, run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
```

Every package it installs comes from the official repositories. It lists the optional features and offers them all at once (recommended), or one at a time, skipping any already installed. It then shows the one `sudo pacman` command it will run, and why, before running it. Then it clones the latest release into `~/.config/quickshell/axiom` and sets up the Python venv. Then it asks before adding the line that starts axiom to the end of your `hyprland.lua`, backing up the file first. Run from a text console (a TTY) outside Hyprland, it last offers to start Hyprland. `--yes` answers yes to every question, and `--minimal` installs only what's required. Running it again is safe. From a clone, run `./install.sh`: that clone is used wherever it is, and if it isn't at `~/.config/quickshell/axiom` (where `qs -c axiom` looks), the installer offers to link it there, or to move it.

<details>
<summary><b>By hand</b>, or on another distribution</summary>

Install the [requirements](#requirements), then clone into Quickshell's config directory:

```bash
git clone https://github.com/axiom-dotfiles/axiom.git ~/.config/quickshell/axiom
```

Start it from your Hyprland config (`hyprland.lua`):

```lua
hl.on("hyprland.start", function() hl.exec_cmd("qs -n -c axiom") end)
```

</details>

That's all Hyprland needs. How axiom sets up the rest is **Settings → Hyprland → Mode**:

| Mode | What it does |
| --- | --- |
| **Detached** (default) | Applies axiom's keybinds and required settings at runtime, and again after every Hyprland reload. It writes no files, and skips any keybind whose key your config already uses. |
| **Included** | Writes `~/.local/state/axiom/hyprland.lua` (under `$XDG_STATE_HOME` if it's set). Load it near the top of your `hyprland.lua`, and anything after it overrides axiom (see below). |
| **Managed** | axiom writes `~/.config/hypr/hyprland.lua` itself, from the **Managed config** settings: layout (dwindle or master; scrolling strips are a Workspaces setting, in every mode), gaps, borders, opacity, blur, shadows, animation styles, keyboard, mouse, cursor and touchpad, behavior (swallowing, VRR, focus), environment variables and autostart commands. It then loads your own `~/.config/hypr/user/*.lua` after it, in name order, as `require("user.<name>")`, so Hyprland reloads when one changes. Shared modules go in `user/lib/`, which isn't loaded on its own. `user/` itself may be a symlink, for example into a dotfiles repo. The first time, your old `hyprland.lua` is backed up and moved to `user/00-previous.lua` (or `00-previous-<date>.lua` if that exists; switching to another mode later moves it back), unless it's Hyprland's unchanged example config, which is only backed up (its binds and monitor rule would fight axiom's). Lines in it that start axiom or load its included module are commented out, since axiom's own `hyprland.lua` does both. Its binds then move onto the **Keybinds** page: each `hl.bind` that can move is deleted from `00-previous.lua` (a dated `.axiom-backup-<date>` copy stays beside it), and any that can't (a Lua function, a bind inside a function) stay there and win over axiom's. Your other files in `user/` are only changed when you press **Merge** on the Keybinds page. |

> [!IMPORTANT]
> Managed mode never takes over a `~/.config/hypr` that is a symlink or in a git repository.

For the included mode, add:

```lua
local ok, axiom = pcall(dofile, os.getenv("HOME") .. "/.local/state/axiom/hyprland.lua")
if ok then axiom.setup() end
```

> [!TIP]
> `setup()` applies everything switched on in the settings. To pick parts yourself, call `axiom.required()`, `axiom.binds()`, `axiom.theme()`, `axiom.blur()`, `axiom.layers()` (the stacking order of axiom's surfaces) and `axiom.monitors()` (the Monitors page's profiles) instead. `hl.unbind("KEY")` after it frees one of axiom's keys.

Whichever mode is set, axiom falls back to the runtime layer when its file isn't loaded, and logs why.

The same settings page holds switches for:
- **required settings:** `misc.allow_session_lock_restore`, the rule from Hyprland's example config that ignores apps' `maximize` requests (managed mode replaces that config, and without the rule apps like kitty reopen maximized), and a `workspaces` animation for the grid's slides
- **theme-colored window borders**
- **blur behind axiom's surfaces**
- **starting `awww-daemon`** (with the awww wallpaper backend)

Keybinds are edited on the **Keybinds** page, in every mode. Presets add the essentials, workspace keys, window management, Alt+Tab, strips and the media keys in one click (see [Keybinds](usage.md#keybinds)).

### Updates

axiom updates itself from the repository you cloned it from. It follows release tags (`v*`) by default, or every commit on `main` if you pick that channel under **Settings → Maintenance → axiom updates**. It checks when the shell starts and once a day, and the same page picks what happens next:

| Mode | What it does |
| --- | --- |
| **Notify me** (default) | Sends a notification. Clicking it opens **Settings → Maintenance → axiom updates**, which shows what's new and has an **Update** button. |
| **Update automatically** | Installs the update, reloads the shell, and notifies you. |
| **Off** | Never checks. **Check now** still works. |

An update only fast-forwards your clone. It won't touch a clone that has changed files, commits of its own, or a branch other than `main`. The page says why, and you update it yourself with git. Your config, state and generated themes aren't tracked by git, so an update never changes them.

## Locking with hypridle

For the `quickshell` and `hyprlock` lockscreen modes:

```ini
general {
    lock_cmd = qs -c axiom ipc call lockscreen lock
    before_sleep_cmd = loginctl lock-session
}
```

In `none` mode axiom doesn't register the `lockscreen` target. Point hypridle at your own locker, and set **Lockscreen → Lock command** so that axiom's lock buttons run it too.

## Login screen (greetd)

Axiom can be your login screen, as a [greetd](https://sr.ht/~kennylevinsen/greetd/) greeter laid out on the Layouts page like the lock screen. It's off unless you install it, from **Settings → Screen & Power → Login screen** or the first-run setup. Install asks for your password once (pkexec), then:

- copies axiom's code to `/usr/share/axiom-greeter`, owned by root. greetd's user runs this copy, since it can't read your home folder. Where the code comes from is **Code from** on the same settings page:
  - **Git** (default): root fetches it from the repository you cloned axiom from, the newest release or the main branch, following **axiom updates → Follow**. The address is recorded at install, so nothing that can write to your clone (a changed remote, a local commit, an edited file) can change what the login screen runs. A new release or commit sends a notification, and **Update** fetches it.
  - **Local**: your clone as it is, whatever branch is checked out, uncommitted changes included. Use it to work on axiom. Any program running as you could change that code before your next **Update**, and then your password prompt is the only check, so the settings page warns you while it's on.

  Switching between them, or changing which channel axiom updates follow, needs an **Update** to take effect.
- makes `/var/lib/axiom-greeter`. Its `config/` folder is yours: axiom exports the login screen's layout, look, theme, wallpapers and monitor layouts there whenever they change, so changing them needs no password. Only the parts of your config the login screen shows go there, and greetd's user can read them.
- installs a polkit action, so Update and Remove ask for your password by name ("update or remove axiom's login screen") and run root's copy of the setup script rather than the one in your home folder.
- backs up `/etc/greetd/config.toml` (`.axiom-original`, plus `.axiom-bak-<date>` for each change), then points only its `default_session` command at axiom's greeter, which runs in a Hyprland of its own.

To make greetd your display manager, disable the current one and enable greetd (the settings card shows the commands). If the login screen fails to start, it tries again with the config saved at install, then falls back to greetd's text login, `agreety`. **Remove** puts greetd's config back and deletes both folders and the polkit action. Logging in through `agreety` starts your login shell.

The login screen only shows modules made for it (a clock, a greeting, weather, battery, the login box, the session picker, the keyboard layout and power buttons); nothing on it can open apps. The power buttons can go on the lock screen too. Fonts and cursor themes installed only in your home folder don't reach it: install them system-wide.
