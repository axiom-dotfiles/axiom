<div align="center">

# axiom

**A complete desktop shell for [Hyprland](https://hypr.land) that you build by dragging things around on your own screen.**

Bars, overlay pages, edge menus, the lock screen and even the login screen are all laid out with drag and drop. Every setting is in the UI, and you never have to write a config file. Written in QML on [Quickshell](https://quickshell.org).

<a href="https://github.com/axiom-dotfiles/axiom/stargazers"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/github/stars/axiom-dotfiles/axiom?style=for-the-badge&color=8c6c3e&labelColor=e1e2e7"><img alt="Stars" src="https://img.shields.io/github/stars/axiom-dotfiles/axiom?style=for-the-badge&color=e0af68&labelColor=1a1b26"></picture></a>
<a href="https://github.com/axiom-dotfiles/axiom/tags"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/github/v/tag/axiom-dotfiles/axiom?sort=semver&label=version&style=for-the-badge&color=b15c00&labelColor=e1e2e7"><img alt="Version" src="https://img.shields.io/github/v/tag/axiom-dotfiles/axiom?sort=semver&label=version&style=for-the-badge&color=ff9e64&labelColor=1a1b26"></picture></a>
<a href="https://github.com/axiom-dotfiles/axiom/commits/main"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/github/last-commit/axiom-dotfiles/axiom?style=for-the-badge&color=587539&labelColor=e1e2e7"><img alt="Latest Commit" src="https://img.shields.io/github/last-commit/axiom-dotfiles/axiom?style=for-the-badge&color=9ece6a&labelColor=1a1b26"></picture></a>
<a href="https://hypr.land"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/badge/Hyprland-0.55%2B-2e7de9?style=for-the-badge&labelColor=e1e2e7"><img alt="Hyprland" src="https://img.shields.io/badge/Hyprland-0.55%2B-7aa2f7?style=for-the-badge&labelColor=1a1b26"></picture></a>
<a href="https://quickshell.org"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/badge/Quickshell-0.3.1%2B-9854f1?style=for-the-badge&labelColor=e1e2e7"><img alt="Quickshell" src="https://img.shields.io/badge/Quickshell-0.3.1%2B-bb9af7?style=for-the-badge&labelColor=1a1b26"></picture></a>
<a href="LICENSE"><picture><source media="(prefers-color-scheme: light)" srcset="https://img.shields.io/badge/License-MIT-118c74?style=for-the-badge&labelColor=e1e2e7"><img alt="License" src="https://img.shields.io/badge/License-MIT-73daca?style=for-the-badge&labelColor=1a1b26"></picture></a>

[Highlights](#highlights) · [Built in the shell](#built-in-the-shell) · [What's included](#whats-included) · [Install](#installation) · [Docs](#documentation)

<!-- TODO: hero clip of the editors in action (drag a widget onto a bar, drag a module onto a page,
     resize it, Save), recorded by hand: it needs a real pointer. Until then, the theme clip below. -->
<img src="assets/screenshots/demo-themes.webp" alt="The overlay's Home page switching between six themes, every card recoloring at once">

</div>

> [!TIP]
> **Trying it costs nothing.** axiom never touches your Hyprland config unless you ask it to. It applies its keybinds at runtime, skips any key you already use, and goes away when you remove its one start-up line.

## Highlights

<table>
<tr>
<td width="50%" valign="top">

### 🧩 Drag and drop everything

One grid editor lays out your **overlay pages**, your **edge menus**, the **lock screen** and the **login screen**. Drag modules in from the library, move them, and pull a corner to resize them. The bar editor works the same way for widgets. Every change shows live on your desktop: **Save** keeps it, **Reset** throws it away.

<img src="assets/screenshots/overlay-editor.webp" alt="The Layouts editor: the Home page's modules on a grid, with the module library below">

</td>
<td width="50%" valign="top">

### 🎨 A bar that looks like yours

Pick solid, transparent, pills, one floating bar, or floating pills. Then choose the widget style (filled, tinted, outline, underline, coloured icons), shape (rounded, capsule, slant, arrow) and grouping (separate, merged, powerline). Add separators, an accent line, shadows or glow. Widget colors pick themselves so neighbours never clash. Any number of bars, on any edge of any monitor.

<img src="assets/screenshots/bar-styles.webp" alt="One bar in five styles: floating powerline pills, solid filled, floating outline with glow, underlined slants with chevrons, transparent with coloured icons">

</td>
</tr>
<tr>
<td valign="top">

### ↔️ Menus that make room

Edge menus slide out of any screen edge when you rest the pointer there, or from a button or a key. A floating menu opens over your windows. An *integrated* one pushes your bars and windows aside like a sidebar, and gives the space back when it closes.

<img src="assets/screenshots/demo-menus.webp" alt="The right menu opening beside the bar while the windows retile to make room, then a floating menu on the left">

</td>
<td valign="top">

### 🧭 Workspaces in two dimensions

Make each monitor a **grid** of workspaces and move by row and column: the slide follows the direction. You can also make a monitor a scrolling **strip**. The bar, its popout, the overview and your keybinds all follow the same layout. **Alt+Tab** shows your windows most recently used first, with live previews; a quick tap just swaps the last two.

<img src="assets/screenshots/demo-workspaces.webp" alt="Sliding right, down, left and up around a grid of workspaces">

</td>
</tr>
<tr>
<td valign="top">

### 📅 Your calendar, built in

Connect iCloud, Fastmail, Nextcloud or any CalDAV account, plus `.ics` feeds. Events appear in the bar's calendar, in modules, on a full Calendar page, and as reminders. You can edit events in place, and `/event fri 3pm Dentist` adds one from the launcher.

<img src="assets/screenshots/calendar-page.webp" alt="The Calendar page: a month of events from two calendars, and the day's agenda">

</td>
<td valign="top">

### 🌈 One theme, every app

Choose from 42 base16 themes in dark and light pairs, or generate one from your wallpaper. A theme recolors the shell and 23 other apps: GTK, Qt, kitty, Neovim, VS Code, Zed, Firefox, btop and more. Light and dark can also switch on a schedule.

<img src="assets/screenshots/themes-light.webp" alt="The Themes page in a light theme: wallpapers, theme list and palette">

</td>
</tr>
<tr>
<td valign="top">

### ⚡ A launcher that does everything

The launcher covers apps, windows, a calculator with units and currencies, clipboard history, emoji, web search and shell commands. It also asks your AI chat a question, and runs `/` commands that control the shell itself (`/theme`, `/volume 40`, `/config Appearance.font.size 14`).

<img src="assets/screenshots/launcher-commands.webp" alt="The launcher listing slash commands">

</td>
<td valign="top">

### 🔒 The whole desktop, not just a bar

Lock screen and greetd login screen, laid out on the same grid. A polkit password prompt. Notifications, OSDs, docks, a power menu, a workspace overview with live previews, a monitor layout editor, AI chat, notes, screenshots and recording. All of it is one config, and all of it can be edited from the shell.

<img src="assets/screenshots/lockscreen.webp" alt="The lock screen: a greeting, password field, media, weather and a clock and calendar over the blurred wallpaper">

</td>
</tr>
</table>

See **[all the features](docs/features.md)**, with screenshots of every surface.

## Built in the shell

> [!NOTE]
> **Everything on this page was built with axiom's own editors and its Settings page. No file was edited by hand.** A whole setup is one config: save it under **Settings → Maintenance → Saved configurations**, share it, and switch between setups in one click (or `/config restore <name>` in the launcher).

<!-- TODO(B/C): when the second and third setups are built, turn this into an A | B | C table
     (desktop-b/-c, overlay-home-b/-c), as in docs/features.md. -->

| The desktop | The overlay |
| :---: | :---: |
| <img src="assets/screenshots/desktop.webp" alt="The desktop: a floating pill bar on the left, a transparent bar on the right and the dock at the top, inside the screen border"> | <img src="assets/screenshots/overlay-home.webp" alt="The overlay's Home page: Wi-Fi, quick actions, media, notifications, calendar, mixer, network, weather and more"> |

The editors that built it:

| Bar editor | Layouts: a page | Layouts: the lock screen |
| :---: | :---: | :---: |
| <img src="assets/screenshots/bar-editor.webp" alt="The bar editor: the bar's sections as a strip on the left, the widget library on the right"> | <img src="assets/screenshots/overlay-editor.webp" alt="The Layouts editor on the Home page"> | <img src="assets/screenshots/layouts-lockscreen.webp" alt="The Layouts editor on the lock screen, a screen-sized grid"> |

- **Bar editor:** each bar's sections are drawn the way the bar draws them, on the side of the page matching the bar's edge. Drag widgets in from the library, click one to edit it, copy one bar's style onto another, and see which widgets don't fit on which screen.
- **Layouts:** overlay pages, edge menus, the lock screen and the login screen, all on one grid. Each page or menu lists what opens it and adds a bar button or a keybind for it in one click.
- **Settings:** generated from the schema that defines the config, so every option is on it. Every option can also be set from the launcher.

## What's included

One repository and one config for the whole desktop:

- **Bars** with 23 widget types, in any style. Their popouts grow out of the bar or the screen border.
- **Overlay** pages built from 27 modules: media, mixer, system graphs, weather, calendar and agenda, notes, AI chat, quick actions and more.
- **Edge menus**, floating over your windows or integrated beside them.
- **Workspaces** as a line, a grid per monitor or scrolling strips, plus a live overview and **Alt+Tab**.
- **Calendar** from CalDAV accounts and `.ics` feeds, with an editor, reminders and quick add.
- **Theming:** 42 base16 themes or ones generated from your wallpaper, applied to 23 other apps.
- **Launcher** for apps, windows, math, the clipboard, emoji and `/` commands for the whole shell.
- **Lock screen** and **login screen** (greetd), laid out from the same modules, plus a **polkit** prompt.
- **Docks** on any edge with pinning and magnification, **OSDs**, notifications and a power menu.
- A **monitor** layout editor, AI chat, notes, screenshots and recording, night light, idle, translations, and a first-run setup.

## Installation

On Arch Linux, run the installer:

```bash
curl -fsSL https://raw.githubusercontent.com/axiom-dotfiles/axiom/main/install.sh | bash
```

Every package comes from the official repositories. Before running anything, the installer shows the one `sudo pacman` command it will run and why. It asks before adding the line that starts axiom to your `hyprland.lua`, and backs that file up first. On first start, a short setup walks you through the look, monitors, workspaces, apps and integrations.

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

To start it with Hyprland, add this line to your `hyprland.lua` (`-n` keeps a second copy from starting):

```lua
hl.on("hyprland.start", function() hl.exec_cmd("qs -n -c axiom") end)
```

</details>

By default axiom runs in *detached* mode: it applies what it needs at runtime and never writes your Hyprland config. If you'd rather it did, it can also write a file you include, or manage `hyprland.lua` for you (see [Hyprland modes](docs/installation.md#installation)).

## Documentation

- **[Features](docs/features.md):** every surface in detail, with screenshots
- **[Installation and setup](docs/installation.md):** requirements, Hyprland modes, updates, locking, the login screen
- **[Keybinds, IPC and launcher](docs/usage.md):** keybind presets, IPC targets and every launcher command
- **[Configuration](docs/configuration.md):** the config file, backups, themes, translations, troubleshooting
- **[Architecture](docs/architecture.md):** how every service and surface works, for contributors

## Contributing

Contributions are welcome. [Open an issue](https://github.com/axiom-dotfiles/axiom/issues/new/choose) for a bug or an idea, or fork the repository and open a pull request against `main`. CI runs the same checks as `scripts/check_all.sh`.

See [CONTRIBUTING.md](CONTRIBUTING.md) for the layout and conventions, and [docs/architecture.md](docs/architecture.md) for how it all fits together. There's no build step: `qs` interprets the QML and hot-reloads on save.

## Roadmap

- [x] Installer, onboarding and a setup wizard
- [x] v1.0, the first stable release
- [x] Clipboard manager, dock and edge menus
- [x] One grid editor for pages, menus, the lock screen and the login screen
- [x] Bar styles
- [x] Alt+Tab, scrolling strips
- [x] Calendar (CalDAV and .ics)
- [x] Login screen (greetd) and polkit prompt
- [ ] AUR package, if there is interest
- [ ] Other Wayland compositors
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
