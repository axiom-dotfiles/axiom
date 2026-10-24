# Scripts (`scripts/`)

External scripts the shell runs (theming, wallpaper, self-update, Hyprland claim, greeter) and the dev checks (`check_*.py`, `run_tests.sh`, `log.sh`, `dev/`).

**Recipe:** `docs/recipes/theme-integration.md`; verify with `scripts/dev/verify.sh`.

- Shell scripts pass `shellcheck -x -S warning`; Python is checked by `tests/scripts/test_scripts.py`. A script's test class gets a line in `scripts/dev/verify.sh`'s `script_tests` map, so changing the script runs it (the whole file takes ~15 s).
- **Theme integrations** (`theme_<key>.sh`, docs `docs/dev/theming/theme-integrations.md`): `source lib/theme_env.sh`, `usage_or_help`, `require_cmds`, `load_theme`, `export_theme_colors`, `render_template` from `templates/<key>_template.<ext>`. Copy `theme_alacritty.sh` (or `theme_zathura.sh` for a live reload). Write only the integration's own `axiom.*` file; only `integration_hookup.py` edits a user's config, on the user's click. Also: a schema `ThemeIntegrations.<key>` boolean with `x-hookup`, a `config/ThemeIntegrations.qml` property, `ThemeManager._integrationCommands` if the binary isn't `<key>`, and a `FORMATS` entry in `tests/scripts/test_scripts.py`.
- Test hookups, `self_update.sh` and `greeter/greeter_install.sh` only on scratch dirs (`HOME`/`XDG_CONFIG_HOME`, scratch clones, `AXIOM_GREETER_ROOT`), never the live system.
- Files the shell watches are written atomically (temp file + rename).
