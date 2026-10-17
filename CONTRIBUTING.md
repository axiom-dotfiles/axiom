# Contributing

Thanks for wanting to help. Bug reports, ideas, translations and code are all welcome.

- **Found a bug?** [Open an issue](https://github.com/axiom-dotfiles/axiom/issues/new/choose) with what you did, what happened, your compositor, and the output of `scripts/log.sh` from your clone.
- **Have an idea?** Open a feature request first if it's big, so we can agree on the shape before you build it.
- **Want to translate?** Copy `config/i18n/ja.json` to `config/i18n/<code>.json` and fill it in. `scripts/check_i18n.py` lists what's missing. It shows up under **Settings → General → Language** right away.

## Setting up

axiom has no build step: Quickshell runs the QML as it is and reloads a file the moment you save it.

1. Fork the repository and clone your fork where Quickshell looks for it:
   ```bash
   git clone https://github.com/<you>/axiom.git ~/.config/quickshell/axiom
   ```
   (Already running axiom from a clone? Use that one, and add your fork as a remote.)
2. Turn on the pre-commit hook, which keeps the generated docs up to date:
   ```bash
   git config core.hooksPath .githooks
   ```
3. Start it with `qs -c axiom` (or let your compositor start it as usual).

## The workflow

1. **Branch** off `main`.
2. **Find your way in.** Use the table below to find the doc for what you're touching, and read it first. Check [`docs/dev/issues.md`](docs/dev/issues.md) for known problems in that area.
3. **Edit and save.** The running shell reloads, so you see the change straight away.
4. **Check it** with `scripts/dev/verify.sh`. It formats the QML you changed, runs the checks and tests your change touches, regenerates the docs, and shows the shell's log. Run it until it prints `verify ok`. A clean log is just `Reloading configuration...` and `Configuration Loaded`.
5. **Update the docs** that describe what you changed (verify.sh lists them).
6. **Open a pull request** against `main` and fill in the template. CI runs `scripts/check_all.sh` (the same as `scripts/dev/verify.sh --all`), and its summary shows what each check found.

Found an unrelated bug along the way? Add it to `docs/dev/issues.md` (the format is at the top) rather than fixing it in the same pull request.

## Where to look

The rules are in [AGENTS.md](AGENTS.md). It's short, and it's written for people and coding agents alike. Read it before your first change. How each part works is in [docs/dev/](docs/dev/README.md), one short doc per topic.

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

- **Use it.** Your change is live as soon as you save, so open the page, menu or popout and try it. A screenshot in the pull request helps for anything visual: `scripts/dev/shot.sh page <ViewType>` (or `launcher`, or `ipc <target> <open> [close]` for any other surface) opens it, takes the shot and closes it again.
- **Read the log.** `scripts/log.sh` shows warnings and errors since the last reload (`--debug` adds `console.log`, `-f` follows).
- **Unit tests.** Pure helpers in `components/methods/` and config migrations have tests in `tests/`. Changing one? Add a case, and run `scripts/run_tests.sh <Name>`.
- **Another compositor, or a fresh config.** `scripts/dev/nested.sh <sway|niri>` runs that compositor in a window with a second axiom inside it, on its own config, so you can try managed mode or a first start without touching your desktop.

More tricks for debugging the running shell are in [docs/dev/testing.md](docs/dev/testing.md).

## Using AI

Using a coding agent is fine. The repository is set up for it: `CLAUDE.md` imports AGENTS.md, and the recipes double as skills. You're responsible for what you submit, the same as for code you wrote by hand. Read it, run it, and check the log.
