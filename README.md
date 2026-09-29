<div align="center">

# axiom

**Build your Hyprland desktop by dragging it into place.**

axiom is a complete desktop shell for [Hyprland](https://hypr.land), written in QML for [Quickshell](https://quickshell.org). Its bars, overlay pages, edge menus and docks are composed with drag and drop on your running desktop, and every setting is in the UI. You never write a config file.

[![Stars](https://img.shields.io/github/stars/axiom-dotfiles/axiom?style=for-the-badge&logoColor=ebdbb2&labelColor=282828&color=d79921)](https://github.com/axiom-dotfiles/axiom)
[![Latest Commit](https://img.shields.io/github/last-commit/axiom-dotfiles/axiom?style=for-the-badge&logoColor=ebdbb2&labelColor=282828&color=98971a)](https://github.com/axiom-dotfiles/axiom)
[![Hyprland](https://img.shields.io/badge/Hyprland-0.55%2B-458588?style=for-the-badge&labelColor=282828)](https://hypr.land)
[![Quickshell](https://img.shields.io/badge/Quickshell-0.3.1%2B-b16286?style=for-the-badge&labelColor=282828)](https://quickshell.org)
[![License](https://img.shields.io/badge/License-MIT-689d6a?style=for-the-badge&labelColor=282828)](LICENSE)

[Why axiom](#-why-axiom) · [Built in the shell](#%EF%B8%8F-built-in-the-shell) · [What's included](#-whats-included) · [Install](#-installation) · [Docs](#-documentation)

</div>

<!-- TODO: replace with a 10-15s looping clip that autoplays (assets/demo.webp or .gif):
     drag a widget onto a bar and watch it appear, then switch from setup A to setup B. -->
https://github.com/user-attachments/assets/a53f62e0-e2bc-4834-a05f-92b6cb115c35

## 💡 Why axiom

<!-- TODO: a sentence or two, in your own words, on why you built it. -->

In most Hyprland shells, changing the layout means editing config files and reloading. A settings panel, where there is one, tunes options on a layout that's already fixed.

In axiom the layout itself is what you edit:

- 🧱 **Compose, don't configure.** Drag widgets into bars, and modules into overlay pages and edge menus. Every change shows on your real desktop as you make it. **Save** keeps it, **Reset** drops it.
- 🧬 **Every option is in the UI.** The Settings page is generated from the schema that defines the config, so nothing is only reachable by hand.
- 🛡️ **Built not to break.** An invalid config never replaces the running one, old configs migrate themselves, and a new monitor layout reverts on its own unless you keep it.
- 🤝 **Fits the setup you have.** By default axiom writes no files and leaves your `hyprland.lua` alone. When you're ready, it can write and manage the whole Hyprland config for you instead.

## 🛠️ Built in the shell

> [!NOTE]
> **The two desktops below were built entirely with axiom's editors and Settings page. No file was edited by hand.** They're two saved configs, and switching between them is one click under **Settings → Backups** (or `/config restore <name>` in the launcher).

| A: pill bars down the sides | B: one solid top bar |
| :---: | :---: |
| <img src="assets/screenshots/desktop.webp" alt="A pill bar on the left and a transparent bar on the right, inside the screen border"> | <img src="assets/screenshots/desktop-b.webp" alt="One solid bar across the top of the screen"> |
| <img src="assets/screenshots/overlay-home.webp" alt="The overlay's Home page, setup A"> | <img src="assets/screenshots/overlay-home-b.webp" alt="The overlay's Home page, setup B"> |

The editors that built them:

| Bar editor | Overlay editor | Edge menu editor |
| :---: | :---: | :---: |
| <img src="assets/screenshots/bar-editor.webp" alt="Bar editor, setup A"> | <img src="assets/screenshots/overlay-editor.webp" alt="Overlay editor, setup A"> | <img src="assets/screenshots/edge-menu-editor.webp" alt="Edge menu editor, setup A"> |

- **Bar editor:** any number of bars, on any monitor and edge, solid, transparent or split into pills. Drag widgets from the library into a bar's sections, and click one to edit it.
- **Overlay editor:** pages of cards, built by dragging modules and cell layouts onto a page. It only offers modules that fit a slot's shape.
- **Edge menu editor:** the same modules and cells, in menus that slide out of any screen edge. **Show on screen** keeps the menu open while you edit it.
- **Settings:** every option, also settable from the launcher (`/config Appearance.font.size 14`).

### 🧲 Menus that make room

An integrated edge menu opens beside your bars instead of over your windows. The windows retile to make room, and get the space back when it closes:

| Closed | Open |
| :---: | :---: |
| <img src="assets/screenshots/menu-integrated-before.webp" alt="Two terminals side by side filling the screen"> | <img src="assets/screenshots/menu-integrated-after.webp" alt="The right menu open, with the right bar and both terminals pushed inwards to make room"> |

## 📦 What's included

One repository and one config for the whole desktop:

- 📊 **Bars** with 22 widget types, and popouts that grow out of the bar or the screen border
- 🗂️ **Overlay** of pages built from 24 modules: media, mixer, system graphs, weather, calendar, notes, AI chat and more
- 🧲 **Edge menus**, floating over your windows or integrated beside them
- ⚓ **Docks** on any edge, with pinning, drag to reorder and magnification
- 🎨 **Theming:** base16 themes or ones generated from your wallpaper, applied to 18 other apps (GTK, Qt, kitty, Neovim, VS Code, …)
- 🚀 **Launcher** for apps, windows, a calculator, clipboard history, emoji and `/` commands
- 🔔 Notifications, OSDs, a lockscreen, power menu, workspace overlay with live previews, a monitor layout editor, screenshots and recording, night light, idle, and a first-run setup

See **[all the features](docs/features.md)**, with screenshots of both setups.

## 🚀 Installation

On Arch Linux, run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
```

Every package comes from the official repositories. The installer shows the one `sudo pacman` command it will run, and why, before running it, and asks before adding the line that starts axiom to your `hyprland.lua` (backing the file up first). Running it again is safe.

<details>
<summary><b>By hand</b>, or on another distribution</summary>

Install the requirements: [Hyprland](https://hypr.land) 0.55+ with its Lua config, [Quickshell](https://quickshell.org) 0.3.1+, the [Material Symbols](https://fonts.google.com/icons) font, `jq` and `python3`. Optional features have their own dependencies, listed in [the installation guide](docs/installation.md#-requirements).

Then clone into Quickshell's config directory:

```bash
git clone https://github.com/axiom-dotfiles/axiom.git ~/.config/quickshell/axiom
```

And start it from your `hyprland.lua`:

```lua
hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end)
```

</details>

> [!TIP]
> **Trying it costs nothing.** axiom starts in *detached* mode: it applies its keybinds at runtime, skips any key your config already uses, and writes no files. To stop using it, remove that one line.

## 📚 Documentation

- **[Features](docs/features.md):** every surface in detail, with screenshots of both setups
- **[Installation and setup](docs/installation.md):** requirements, Hyprland modes, updates, locking with hypridle
- **[Keybinds, IPC and launcher](docs/usage.md):** IPC targets and launcher commands
- **[Configuration](docs/configuration.md):** the config file, themes, translations, troubleshooting
- **[Architecture](docs/architecture.md):** how every service and surface works, for contributors

## 🤝 Contributing

Contributions are welcome. [Open an issue](https://github.com/axiom-dotfiles/axiom/issues/new/choose) for a bug or an idea, or fork the repository and open a pull request against `main`. CI runs the same checks as `scripts/check_all.sh`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the layout and conventions, and [docs/architecture.md](docs/architecture.md) for how it all fits together. There's no build step: `qs` interprets the QML and hot-reloads on save.

## 🗺️ Roadmap

- [x] Installer
- [x] v1.0, the first stable release
- [x] Onboarding and a setup wizard
- [x] Clipboard manager
- [x] Dock and edge menus
- [x] Collaboration: CI, issue and pull request templates, changes through PRs
- [ ] Other Wayland compositor support
- [ ] More translations
- [ ] More widgets!

## 🙏 Acknowledgments

axiom is built on:
- [Hyprland](https://hypr.land), the compositor it's made for
- [Quickshell](https://quickshell.org), the QML toolkit every surface is written in
- [Material Symbols](https://fonts.google.com/icons), the icons

Four of the five theme pairs are ports of [Catppuccin](https://catppuccin.com), [Gruvbox](https://github.com/morhetz/gruvbox), [Solarized](https://ethanschoonover.com/solarized/) and [Tokyo Night](https://github.com/tokyo-night/tokyo-night-vscode-theme). Submarine Sonar is axiom's own.

And thanks to the Hyprland desktops that inspired it: [illogical-impulse](https://github.com/end-4/dots-hyprland), [caelestia-dots](https://github.com/caelestia-dots) and [JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots).

## 📄 License

[MIT](LICENSE)
