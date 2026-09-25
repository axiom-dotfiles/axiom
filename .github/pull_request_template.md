## What this changes

<!-- What and why. Link the issue it fixes: "Fixes #123". -->

## How it was tested

<!-- What you did to check it, e.g. reloaded the shell and opened the page, and `scripts/log.sh` stayed clean. -->

## Checklist

- [ ] `scripts/log.sh` shows no new warnings after a reload
- [ ] `scripts/check_structure.py` passes (after adding, renaming or moving QML files)
- [ ] Changed QML is formatted with `/usr/lib/qt6/bin/qmlformat -i`
- [ ] New user-visible text is wrapped in `I18n.tr()` and `scripts/check_i18n.py` is clean
- [ ] New settings are in `config/json/config.schema.json` with a default, and a reader property
- [ ] A config layout change bumps `version` and extends `ConfigMigration`
- [ ] README.md is updated for new features or dependencies
