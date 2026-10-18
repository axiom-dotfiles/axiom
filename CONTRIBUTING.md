# Contributing

Thanks for wanting to help. Bug reports, ideas, translations and code are all welcome.

## Reporting and requesting

[Open an issue](https://github.com/axiom-dotfiles/axiom/issues/new/choose) and pick the form that fits:

| Form | For |
| --- | --- |
| **Bug report** | Something broken or behaving wrongly |
| **New feature or component** | Something big: a new surface, page type, editor or subsystem |
| **Small feature or improvement** | A change to something that exists, a new setting or launcher command, or a small feature that stands on its own (a pomodoro timer, a todo list) |
| **Bar widget or module** | Something new for the bar, or a module for overlay pages, edge menus, the desktop, the lock screen or the login screen |
| **App theme request** | Another app that should follow axiom's theme |
| **Compositor or distribution support** | Running on another compositor, or installing on another distribution. Needs someone who runs it to test it |
| **Translation** | A new language, or wrong or untranslated text |

For a bug, paste the output of two commands from axiom's `scripts/` folder (`~/.config/quickshell/axiom/scripts/` for a clone, `/usr/share/axiom/scripts/` for a package): `bug_info.sh`, which prints your versions and setup, and `log.sh`, which shows the shell's log.

Each form adds its kind's label plus `triage`, which a maintainer swaps for `needs-info`, `help wanted`, `good first issue` or a `compositor: …` label once it's sorted. Platform requests also carry `needs-maintainer` until someone signs up to test them.

Questions and help with setting up go in [Discussions › Q&A](https://github.com/axiom-dotfiles/axiom/discussions/categories/q-a), ideas not ready to be a request in [Ideas](https://github.com/axiom-dotfiles/axiom/discussions/categories/ideas), and your setup in [Show and tell](https://github.com/axiom-dotfiles/axiom/discussions/categories/show-and-tell). Want to build something big? Open its request first, so we can agree on the shape before you build it.

**Want to translate?** Copy `config/i18n/template/language.json` to `config/i18n/<code>.json` (`de.json`), fill in `_meta.name` (the language's own name, `Deutsch`) and `_meta.locale` (`de_DE`), adjust the date formats, and translate the strings. Anything left empty shows in English, so a partial translation is fine to send. `scripts/check_i18n.py` lists what's missing. It shows up under **Settings → General → Language** right away.

**Want to add a theme?** Copy `config/themes/template/theme.json` to `config/themes/<name>.json`, set its `name`, `author` and `variant`, and replace the sixteen `base00`–`base0F` colors. The `semantic` names map onto those and are already sensible, so only change the ones your palette needs. For a dark/light pair, give each file a `paired` field naming the other. It shows up under **Themes** as soon as you save.

**Found a security problem?** Don't open an issue: report it privately as [SECURITY.md](SECURITY.md) describes.

## Setting up

axiom has no build step: Quickshell runs the QML as it is and reloads a file the moment you save it.

1. Fork the repository and clone your fork where Quickshell looks for it:
   ```bash
   git clone https://github.com/<you>/axiom.git ~/.config/quickshell/axiom
   ```
   (Already running axiom from a clone? Use that one, and add your fork as a remote.)
2. Turn on the pre-commit hook, which keeps what's generated up to date: the developer docs, the translation files (new text goes into every language, empty, and into the template a new language starts from) and the theme template:
   ```bash
   git config core.hooksPath .githooks
   ```
3. Start it with `qs -c axiom` (or let your compositor start it as usual).

## The workflow

1. **Branch** off `main`.
2. **Find your way in.** Use the table below to find the doc for what you're touching, and read it first. Check the [open issues](https://github.com/axiom-dotfiles/axiom/issues) in that area too.
3. **Edit and save.** The running shell reloads, so you see the change straight away.
4. **Check it** with `scripts/dev/verify.sh` until it prints `verify ok`. It formats your QML, runs the checks your change touches and shows the shell's log.
5. **Update the docs** that describe what you changed (verify.sh lists them).
6. **Open a pull request** against `main` and fill in the template, linking the issue it closes (`Fixes #123`). CI runs every check (`scripts/dev/verify.sh --all` locally).

Found an unrelated bug along the way? [Report it](https://github.com/axiom-dotfiles/axiom/issues/new?template=01-bug.yml) rather than fixing it in the same pull request.

## How it's laid out

```bash
shell.qml       # entrypoint: one top-level item per surface, plus services only reached by IPC
shell/          # top-level pieces, one per surface
components/
  methods/      # pure helpers with unit tests: no files, processes or side effects
  reusable/     # generic Styled* widgets, no feature logic
  forms/        # schema-driven form widgets for the settings page
  content/      # loadable panels by name: overlay modules and bar popouts
  hosts/        # where content appears: popouts, overlay pages and slots
  views/        # overlay pages by type, with their pieces in subfolders
  bar/          # the bar; bar/widgets/ holds the bar widget types
  surfaces/     # standalone windows (launcher, lock screen, toasts, dock, power menu, …)
services/       # *Manager singletons: state and every side effect (processes, files, the compositor)
config/         # config readers; json/ (the config schema), themes/, i18n/
scripts/        # scripts the shell runs (theming, wallpaper, updates, compositor configs) and the dev checks
tests/          # qmltestrunner tests and script tests
examples/       # the example setups
docs/           # user docs; docs/dev/ for contributors
```

Dependencies point one way: `methods/` helpers → config readers → services → UI. The UI never runs processes or writes files itself; it asks a service.

## Where to look

Read [AGENTS.md](AGENTS.md) before your first change: it holds the project's rules, for people and agents alike. How each part works is in [docs/dev/](docs/dev/README.md), one doc per topic.

| I want to… | Start at |
| --- | --- |
| Add a bar widget, overlay module, setting, launcher command, theme integration, … | Its recipe in [docs/recipes/](docs/recipes/): files to touch and one to copy |
| Change a bar widget or the bar's look | [docs/dev/bar/](docs/dev/bar/) |
| Change edge menus, overlay pages or modules | [docs/dev/edge-menus/](docs/dev/edge-menus/), [docs/dev/overlay/](docs/dev/overlay/) |
| Change a popout | [docs/dev/popouts/surface-context.md](docs/dev/popouts/surface-context.md) |
| Change a feature (launcher, lock screen, dock, notifications, …) | `docs/dev/features/<feature>.md` |
| Change something about settings or the config | [config-manager](docs/dev/core/config-manager.md), [schema-annotations](docs/dev/core/schema-annotations.md) |
| Build UI | [shared-ui-pieces](docs/dev/core/shared-ui-pieces.md): reuse what's there before drawing a new card or row |
| Work on compositor support, or add a compositor | [docs/dev/compositor/](docs/dev/compositor/README.md) |
| Work on themes or theming other apps | [docs/dev/theming/](docs/dev/theming/) |
| Find which file does something | `grep -n '<word>' docs/dev/generated/files.md` |
| Look up a setting: its default, and what reads it | `docs/dev/config/<Section>.md` |

## Testing your change

- **Use it.** Your change is live as soon as you save. For anything visual, add a screenshot to the pull request: `scripts/dev/shot.sh page <ViewType>` (or `launcher`, or `ipc <target> <open>`) takes one for you.
- **Read the log.** `scripts/log.sh` shows warnings and errors since the last reload (`--debug` adds `console.log`, `-f` follows).
- **Unit tests.** Changing a helper in `components/methods/` or a config migration? Add a case in `tests/` and run `scripts/run_tests.sh <Name>`.
- **Another compositor, or a fresh config.** `scripts/dev/nested.sh <sway|niri>` runs that compositor in a window with a second axiom inside it, on its own config, so you can try managed mode or a first start without touching your desktop.

More tricks for debugging the running shell are in [docs/dev/testing.md](docs/dev/testing.md).

## Using AI

Coding agents are welcome, and the repository is set up for them (`CLAUDE.md` imports AGENTS.md, and the recipes double as skills). You're still responsible for what you submit: read it, run it, and check the log.
