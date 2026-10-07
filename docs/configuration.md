# Configuration

[README](../README.md) · [Features](features.md) · [Installation](installation.md) · [Keybinds, IPC and launcher](usage.md) · [Configuration](configuration.md)

## The config file

Everything is configured from inside the shell (see [Built in the shell](../README.md#built-in-the-shell)). Open the overlay, and use the **Settings**, **Bar editor**, **Layouts**, **Keybinds**, **Monitors** and **Themes** pages. Any single setting can also be set from the launcher: `/config Appearance.font.size 14`.

- Settings are saved to `config/user/config.json`. You never need to open it, but the shell watches that file and reloads when it changes, so editing it by hand also works.
- Configs from older versions are migrated automatically.
- `config/json/config.schema.json` defines every option and its default. It also generates the Settings page.
- Chat API keys are entered in **Settings → Modules → Chat** and stored in your keyring (or `$XDG_STATE_HOME/axiom/secrets.json`, mode 600, without one). A provider's environment variable (`ANTHROPIC_API_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`) wins over a stored key. Conversations are saved in `$XDG_STATE_HOME/axiom/chats/`.

> [!IMPORTANT]
> An invalid `config.json` never replaces the running config. The shell keeps the last good one and refuses to save until the file is fixed.

### Saved configurations

Your whole setup (bars, overlay pages, edge menus, docks, the lock and login screens, every setting) is one file, so it can be kept and swapped as a whole:

- **Settings → Maintenance → Saved configurations** saves the current config under a name, and restores or deletes saved ones. Restoring replaces the current config.
- The launcher does the same: `/config save <name>` and `/config restore <name>`.
- Saved configs are plain copies of `config.json` in `config/user/saved/`. Copy one to another machine, or share it, and restore it there.

### Example setups

axiom ships the setups from the README in `examples/`. Apply one from **Settings → Maintenance → Example setups**, or with `/config example <name>` in the launcher.

- An example holds only the look and the layout: the theme, font and shape, the bars and their style, overlay pages, edge menus, docks, OSDs, popouts, the lock screen layout, workspaces, notifications' placement, the power menu and the window switcher.
- Everything else stays as it is: wallpapers, monitors, apps, keybinds, calendars, chat providers, Hyprland, idle and the login screen.
- Your current config is saved first, as `before-<name>`, so going back is one **Restore** away.
- An example is a partial `config.json` with a `_example` header (`title`, `description`). What it may hold is each setting's `x-scope` in `config/json/config.schema.json`. If it uses a font you don't have, the text falls back to another; a theme you don't have falls back to the default palette.

### Sharing a setup

- **Settings → Maintenance → Share → Export** writes the current look and layout to `~/axiom-<name>-<date>-<time>.json`, holding only what differs from the defaults. Monitors, wallpapers, accounts and paths are never in it. Keybinds, apps and commands are left out unless you switch them on.
- **Import…** opens a file (an export, an example or a whole `config.json`) and applies it the way an example applies, after saving the current config as `before-<name>`. A file without a `version`, or from a newer axiom, is refused.
- If the file holds keybinds, apps and commands, you can take those too, but the switch is off by default: a command runs as you, so read every command in a file someone else made before turning it on.

### Themes

- Hand-made themes live in `config/themes/`, and generated ones in `config/themes/generated/`.
- A theme is a base16 palette (`base00`–`base0F`) plus optional semantic overrides. See `config/themes/theme.schema.json`.
- To add a theme, drop a JSON file in `config/themes/`. To make a dark/light pair, give each file a `paired` field naming the other.

### Translations

- Pick a language in **Settings → General → Language**.
- To add a language, create `config/i18n/<code>.json` (see `ja.json`). It shows up in the dropdown right away.
- Missing strings fall back to English. `scripts/check_i18n.py` reports what's missing.

## Troubleshooting

View the shell's log with:

```bash
scripts/log.sh          # warnings and errors since the last reload
scripts/log.sh --debug  # include console.log output
scripts/log.sh -f       # follow
```

A clean reload prints only `Reloading configuration...` and `Configuration Loaded`.

Icons showing as words (`wifi`, `battery_full`) mean the icon font is missing: install `ttf-material-symbols-variable` and restart the shell.
