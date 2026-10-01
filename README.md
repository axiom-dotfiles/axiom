<div align="center">

# axiom

axiom is a complete, extensively customizable desktop shell for [Hyprland](https://hypr.land), written in QML, powered by [Quickshell](https://quickshell.org). Its bars, overlay pages, and edge menus are composed with drag and drop on your running desktop, and every setting is in the UI. You never have to write a config file.

<a href="https://github.com/axiom-dotfiles/axiom/stargazers"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/github/stars/axiom-dotfiles/axiom?style=for-the-badge&color=8c6c3e&labelColor=e1e2e7"><img alt="Stars" src="https://img.shields.io/github/stars/axiom-dotfiles/axiom?style=for-the-badge&color=e0af68&labelColor=1a1b26"></picture></a>
<a href="https://github.com/axiom-dotfiles/axiom/tags"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/github/v/tag/axiom-dotfiles/axiom?sort=semver&label=version&style=for-the-badge&color=b15c00&labelColor=e1e2e7"><img alt="Version" src="https://img.shields.io/github/v/tag/axiom-dotfiles/axiom?sort=semver&label=version&style=for-the-badge&color=ff9e64&labelColor=1a1b26"></picture></a>
<a href="https://github.com/axiom-dotfiles/axiom/commits/main"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/github/last-commit/axiom-dotfiles/axiom?style=for-the-badge&color=587539&labelColor=e1e2e7"><img alt="Latest Commit" src="https://img.shields.io/github/last-commit/axiom-dotfiles/axiom?style=for-the-badge&color=9ece6a&labelColor=1a1b26"></picture></a>
<a href="https://hypr.land"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/badge/Hyprland-0.55%2B-2e7de9?style=for-the-badge&labelColor=e1e2e7"><img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-0.55%2B-7aa2f7?style=for-the-badge&labelColor=1a1b26"></picture></a>
<a href="https://quickshell.org"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/badge/Quickshell-0.3.1%2B-9854f1?style=for-the-badge&labelColor=e1e2e7"><img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-0.3.1%2B-bb9af7?style=for-the-badge&labelColor=1a1b26"></picture></a>
<a href="LICENSE"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/badge/License-MIT-118c74?style=for-the-badge&labelColor=e1e2e7"><img alt="License" src="https://img.shields.io/badge/License-MIT-73daca?style=for-the-badge&labelColor=1a1b26"></picture></a>

[Why axiom](#why-axiom) · [Built in the shell](#built-in-the-shell) · [What's included](#whats-included) · [Install](#installation) · [Docs](#documentation)

</div>

<!-- TODO: replace with a 10-15s looping clip that autoplays (assets/demo.webp or .gif):
     drag a widget onto a bar and watch it appear, then switch from setup A to setup B. -->

## Why axiom?

I wanted a simple-to-use shell that puts as much customization as possible directly in your hands, without touching a single line of code.

In axiom the layout itself is what you edit:

- **Compose, don't configure.** Drag widgets into bars, and modules into overlay pages and edge menus. Every change shows on your real desktop as you make it. **Save** keeps it, **Reset** drops it.
- **Every option is in the UI.** The Settings page is generated from the schema that defines the config, so nothing is only reachable by hand. Your whole layout (bars, overlay pages, edge menus, docks) lives in that one config file, validated against the schema. Save a backup or grab a friend's!
- **Fits the setup you have.** By default axiom never touches your Hyprland config: everything it needs is applied at runtime. The installer can add the one line that starts axiom to your `hyprland.lua`, and asks first.

## Built in the shell

> [!NOTE]
> **The two desktops below were built entirely with axiom's editors and Settings page. No file was edited by hand.** They're two saved configs, and switching between them is one click under **Settings → Backups** (or `/config restore <name>` in the launcher).

| A: a pill bar and a transparent bar down the sides | B: one solid top bar |
| :---: | :---: |
| <img src="assets/screenshots/desktop.webp" alt="A pill bar on the left and a transparent bar on the right, inside the screen border"> | <img src="assets/screenshots/desktop-b.webp" alt="One solid bar across the top of the screen"> |
| <img src="assets/screenshots/overlay-home.webp" alt="The overlay's Home page, setup A"> | <img src="assets/screenshots/overlay-home-b.webp" alt="The overlay's Home page, setup B"> |

The editors that built them:

| Bar editor | Layouts: a page | Layouts: an edge menu |
| :---: | :---: | :---: |
| <img src="assets/screenshots/bar-editor.webp" alt="Bar editor, setup A"> | <img src="assets/screenshots/overlay-editor.webp" alt="Overlay editor, setup A"> | <img src="assets/screenshots/edge-menu-editor.webp" alt="Edge menu editor, setup A"> |

- **Bar editor:** any number of bars, on any monitor and edge, solid, transparent or split into pills. Drag widgets from the library into a bar's sections, and click one to edit it.
- **Layouts:** your overlay pages and edge menus in one editor. Drag modules from the library onto a page's grid, move them anywhere, and drag a corner to resize them in quarter cards. Edge menus use the same grid, in menus that slide out of any screen edge.

Everything else is on the **Settings** page, and every option can also be set from the launcher (`/config Appearance.font.size 14`).

### Menus that make room

In addition to standard floating menus, an integrated edge menu opens beside your bars instead of over your windows. The windows retile to make room, and get the space back when it closes:

| Closed | Open |
| :---: | :---: |
| <img src="assets/screenshots/menu-integrated-before.webp" alt="Two terminals side by side filling the screen"> | <img src="assets/screenshots/menu-integrated-after.webp" alt="The right menu open, with the right bar and both terminals pushed inwards to make room"> |

### Workspaces in two dimensions

Workspaces don't have to be a line numbered 1 to N. Set **Settings → Desktop → Workspaces → Layout** to **Grid per monitor**, and each monitor gets its own grid (5×5 by default, up to 10×10, I can't imagine why someone would need 100 workspaces, but it is possible) that you move around by row and column.

<!-- TODO: a short clip of moving around the grid: the slide direction sells it better than any screenshot. -->

| The workspace overview: the whole grid, live | The bar: your row, and the grid on hover |
| :---: | :---: |
| <img src="assets/screenshots/workspace-overlay.webp" alt="The workspace overview showing a 5×5 grid of workspaces with live window previews"> | <img src="assets/screenshots/popout-workspace-grid.webp" alt="The bar's workspace widget with its grid popout open, showing app icons in each cell" width="260"> |

- **The slides follow the grid.** Moving left or right slides sideways, and up or down slides vertically. This works with whatever Hyprland's own workspace animation is set to.
- **One setting, everywhere.** The bar widget, its grid popout, the workspace overview, the Workspaces module, the launcher's `/ws` and the `workspaces` IPC target all use the same layout. Nothing else keeps a count or a grid size of its own.
- **A grid per monitor, in a stable order.** The primary monitor comes first, so plugging one in or restarting Hyprland never reshuffles which workspaces belong to which monitor.
- **Move windows around it.** Drag a window onto another cell in the workspace overview, or take it along with you from the keyboard.
- **Keybinds included.** The **Keybinds** page has a **Grid with WASD** preset (<kbd>Super</kbd> + <kbd>W</kbd> <kbd>A</kbd> <kbd>S</kbd> <kbd>D</kbd> to move, add <kbd>Shift</kbd> to take the window along).

## What's included

One repository and one config for the whole desktop:

- **Bars** with 22 widget types, and popouts that grow out of the bar or the screen border
- **Overlay** of pages built from 25 modules: media, mixer, system graphs, weather, calendar, notes, AI chat and more
- **Edge menus**, floating over your windows or integrated beside them
- **Docks** on any edge, with pinning, drag to reorder and magnification
- **Theming:** base16 themes or ones generated from your wallpaper, applied to 18 other apps (GTK, Qt, kitty, Neovim, VS Code, …)
- **Launcher** for apps, windows, a calculator, clipboard history, emoji and `/` commands
- **Lockscreen** laid out from the same modules, with your wallpaper behind it
- Notifications, OSDs, power menu, workspace overview with live previews, a monitor layout editor, screenshots and recording, night light, idle, and a first-run setup

See **[all the features](docs/features.md)**, with screenshots of both setups.

## Installation

On Arch Linux, run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
```

Every package comes from the official repositories. The installer shows the one `sudo pacman` command it will run, and why, before running it, and asks before adding the line that starts axiom to your `hyprland.lua` (backing the file up first).

<details>
<summary><b>By hand</b>: on another distribution, or if you'd rather not pipe to bash</summary>

Install the requirements: [Hyprland](https://hypr.land) 0.55+ with its Lua config, [Quickshell](https://quickshell.org) 0.3.1+, the [Material Symbols](https://fonts.google.com/icons) font, `git`, `jq` and `python3`. Optional features have their own dependencies, listed in [the installation guide](docs/installation.md#requirements).

Then clone into Quickshell's config directory:

```bash
git clone https://github.com/axiom-dotfiles/axiom.git ~/.config/quickshell/axiom
```

Start it with Quickshell:

```bash
qs -c axiom
```

To start it with Hyprland, add this line to your `hyprland.lua`:

```lua
hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end)
```

</details>

> [!TIP]
> **Trying it costs nothing.** axiom starts in *detached* mode: it applies its keybinds at runtime, skips any key your config already uses, and never touches your Hyprland config. To stop using it, remove the `qs -c axiom` line from your `hyprland.lua`.

## Documentation

- **[Features](docs/features.md):** every surface in detail
- **[Installation and setup](docs/installation.md):** requirements, Hyprland modes, updates, locking with hypridle
- **[Keybinds, IPC and launcher](docs/usage.md):** binding keys to IPC targets, and launcher commands
- **[Configuration](docs/configuration.md):** the config file, themes, translations, troubleshooting
- **[Architecture](docs/architecture.md):** how every service and surface works, for contributors

## Contributing

Contributions are welcome. [Open an issue](https://github.com/axiom-dotfiles/axiom/issues/new/choose) for a bug or an idea, or fork the repository and open a pull request against `main`. CI runs the same checks as `scripts/check_all.sh`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the layout and conventions, and [docs/architecture.md](docs/architecture.md) for how it all fits together. There's no build step: `qs` interprets the QML and hot-reloads on save.

## Roadmap

- [x] Installer
- [x] v1.0, the first stable release
- [x] Onboarding and a setup wizard
- [x] Clipboard manager
- [x] Dock and edge menus
- [ ] AUR Package if there is interest
- [ ] Other Wayland compositor support
- [ ] More translations
- [ ] More widgets!

## Acknowledgments

axiom is built on:
- [Hyprland](https://hypr.land), the compositor it's made for
- [Quickshell](https://quickshell.org), the QML toolkit every surface is written in
- [Material Symbols](https://fonts.google.com/icons), the icons

The static themes are ports of [Catppuccin](https://catppuccin.com), [Gruvbox](https://github.com/morhetz/gruvbox), [Gruvbox Material](https://github.com/sainnhe/gruvbox-material), [Solarized](https://ethanschoonover.com/solarized/), [Tokyo Night](https://github.com/tokyo-night/tokyo-night-vscode-theme), [Rosé Pine](https://rosepinetheme.com), [Nord](https://www.nordtheme.com) (Nord Light after [threddast's](https://github.com/tinted-theming/schemes/blob/spec-0.11/base16/nord-light.yaml)), [Dracula and Alucard](https://draculatheme.com), [Everforest](https://github.com/sainnhe/everforest), [Kanagawa](https://github.com/rebelot/kanagawa.nvim), [One Dark/Light](https://github.com/atom/atom/tree/master/packages), [Ayu](https://github.com/ayu-theme/ayu-colors), [Nightfox](https://github.com/EdenEast/nightfox.nvim), [GitHub](https://github.com/primer/github-vscode-theme) and [Oxocarbon](https://github.com/nyoom-engineering/oxocarbon.nvim), most by way of [tinted-theming](https://github.com/tinted-theming/schemes)'s base16 palettes. Submarine Sonar is axiom's own.

And thanks to the Hyprland desktops that inspired it: [illogical-impulse](https://github.com/end-4/dots-hyprland), [caelestia-dots](https://github.com/caelestia-dots) and [JaKooLit's Hyprland-Dots](https://github.com/JaKooLit/Hyprland-Dots).

## License

[MIT](LICENSE)
