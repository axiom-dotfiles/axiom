#!/usr/bin/env python3
"""Smoke tests for the scripts in scripts/, each run in a scratch $HOME.

  - every shipped theme is complete (config/themes/theme.schema.json's
    required keys, hex colors, semantic names that resolve, pairs that exist)
  - every theme_*.sh integration renders every shipped theme (and any
    generated ones) into a scratch dir with no warnings, no unfilled
    ${VAR}s and only well-formed colors, and each output parses as its
    format (TOML, JSON, plist, INI; YAML and GTK CSS when PyYAML / PyGObject
    are installed). The apps they need (and pkill, which they signal
    running apps with) are stubbed
  - integration_hookup.py (Settings' Apply) adds each placement where it
    belongs, backs files up, follows symlinks, and does nothing twice
  - self_update.sh reports and applies updates on scratch git clones, and
    refuses the blocked cases
  - claim_hyprland.sh (the "managed" Hyprland mode's takeover) adopts a
    plain config dir and never touches a symlinked or git-tracked one, and
    its release gives back what the takeover set aside
  - generate_theme.py turns an image into a valid dark/light pair (skipped
    when the venv can't be set up)
  - calendar_sync.py reads a locally served .ics feed into occurrences, and
    edits events (new, one occurrence, excluded, the series moved) so they
    read back right (skipped when the venv can't be set up)

  python3 tests/scripts/test_scripts.py [-v] [TestCase[.test_name]]
"""
import configparser
import json
import os
import plistlib
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time
import tomllib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = ROOT / "scripts"
THEMES = ROOT / "config" / "themes"
BASES = [f"base0{c}" for c in "0123456789ABCDEF"]
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
# envsubst leaves nothing behind, so a ${VAR} left over is a template typo
UNFILLED = re.compile(r"\$\{[A-Z0-9_]+\}")
# The ncspot x-hookup's text: theme_ncspot.sh fills the lines between them
NCSPOT_MARKERS = "# axiom theme: begin (rewritten on every theme change)\n# axiom theme: end\n"
# Apps the integrations require or signal; stubs keep them from touching a
# running session
STUBS = ["alacritty", "bat", "btop", "foot", "fzf", "ghostty", "hx", "kitty", "lazygit",
         "nvim", "wezterm", "yazi", "qt5ct", "qt6ct", "pkill", "gsettings"]


def scratch_env(tmp):
    """Environment with $HOME, XDG dirs and stubbed apps under `tmp`."""
    tmp = Path(tmp)
    stubs = tmp / "stubs"
    stubs.mkdir()
    for name in STUBS:
        stub = stubs / name
        stub.write_text("#!/bin/sh\nexit 0\n")
        stub.chmod(stub.stat().st_mode | stat.S_IEXEC)
    env = dict(os.environ)
    env.update({
        "HOME": str(tmp / "home"),
        "XDG_CONFIG_HOME": str(tmp / "home" / ".config"),
        "XDG_STATE_HOME": str(tmp / "home" / ".local" / "state"),
        "XDG_RUNTIME_DIR": str(tmp / "run"),
        "PATH": f"{stubs}:{env['PATH']}",
        "GIT_CONFIG_GLOBAL": str(tmp / "gitconfig"),
        "GIT_CONFIG_NOSYSTEM": "1",
    })
    for key in ("HOME", "XDG_RUNTIME_DIR"):
        Path(env[key]).mkdir(parents=True, exist_ok=True)
    return env


def theme_problems(theme, names):
    problems = []
    for key in ("name", "variant", "colors", "semantic"):
        if key not in theme:
            problems.append(f"missing {key}")
    if theme.get("variant") not in ("dark", "light"):
        problems.append(f"variant {theme.get('variant')!r}")
    colors = theme.get("colors", {})
    for base in BASES:
        if not HEX.match(colors.get(base, "")):
            problems.append(f"colors.{base} = {colors.get(base)!r}")
    for key, value in theme.get("semantic", {}).items():
        if value not in BASES and not HEX.match(value):
            problems.append(f"semantic.{key} = {value!r}")
    if theme.get("paired") and theme["paired"] not in names:
        problems.append(f"paired theme {theme['paired']!r} doesn't exist")
    return problems


class Themes(unittest.TestCase):
    def test_shipped_themes_are_complete(self):
        files = sorted(THEMES.glob("*.json")) + sorted((THEMES / "generated").glob("*.json"))
        files = [f for f in files if f.name != "theme.schema.json"]
        names = {json.loads(f.read_text()).get("name") for f in files} | {f.stem for f in files}
        schema = json.loads((THEMES / "theme.schema.json").read_text())
        required = schema["properties"]["semantic"]["required"]
        self.assertGreater(len(files), 2)
        for f in files:
            with self.subTest(theme=f.name):
                theme = json.loads(f.read_text())
                self.assertEqual(theme_problems(theme, names), [])
                missing = [k for k in required if k not in theme["semantic"]]
                self.assertEqual(missing, [], "semantic keys missing")

    def test_theme_defaults_are_complete(self):
        defaults = json.loads((ROOT / "config" / "json" / "theme-defaults.json").read_text())
        for base in BASES:
            self.assertRegex(defaults["colors"][base], HEX)
        for variant in ("dark", "light"):
            for key, value in defaults["semantic"][variant].items():
                self.assertIn(value, BASES, f"{variant}.{key}")


def luminance(color):
    channels = [int(color[i:i + 2], 16) / 255 for i in (1, 3, 5)]
    r, g, b = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def contrast(a, b):
    high, low = sorted((luminance(a), luminance(b)), reverse=True)
    return (high + 0.05) / (low + 0.05)


class TerminalPalette(unittest.TestCase):
    """export_theme_colors / readable_text_colors keep text readable."""
    TEXT = ["RED", "GREEN", "YELLOW", "BLUE", "MAGENTA", "CYAN", "ORANGE",
            "ERROR", "WARNING", "SUCCESS", "INFO"]

    def palette(self, theme):
        script = (f'set -euo pipefail; source "{SCRIPTS}/lib/theme_env.sh"; '
                  f'load_theme "{theme}" >/dev/null; export_theme_colors; readable_text_colors; '
                  'env | grep -E "^(ANSI_[0-9]+|BACKGROUND|THEME_VARIANT|'
                  + "|".join(self.TEXT) + ')="')
        result = subprocess.run(["bash", "-c", script], capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        return dict(line.split("=", 1) for line in result.stdout.splitlines())

    def test_every_theme_is_readable(self):
        files = sorted(THEMES.glob("*.json")) + sorted((THEMES / "generated").glob("*.json"))
        for f in [f for f in files if f.name != "theme.schema.json"]:
            with self.subTest(theme=f.name):
                c = self.palette(f)
                bg = c["BACKGROUND"]
                for i in [*range(1, 7), *range(9, 15)]:
                    self.assertGreaterEqual(contrast(c[f"ANSI_{i}"], bg), 4.5, f"ANSI_{i} {c[f'ANSI_{i}']}")
                self.assertGreaterEqual(contrast(c["ANSI_8"], bg), 3.0, f"ANSI_8 {c['ANSI_8']}")
                for key in self.TEXT:
                    self.assertGreaterEqual(contrast(c[key], bg), 4.5, f"{key} {c[key]}")
                if c["THEME_VARIANT"] == "light":
                    self.assertLess(luminance(c["ANSI_0"]), luminance(bg), "black isn't dark")


# Each integration's output format, for the parse checks (the others are
# key=value lines, checked for their colors only)
FORMATS = {
    "alacritty": "toml", "helix": "toml", "wezterm": "toml", "yazi": "toml",
    "k9s": "yaml", "lazygit": "yaml", "bat": "plist", "nvim": "json",
    "vscode": "json", "zed": "json", "qt": "ini", "foot": "ini", "gtk": "css", "vesktop": "css", "ncspot": "toml", "firefox": "css",
}
COLOR = re.compile(r"#([0-9a-fA-F]+)\b")


class ThemeIntegrations(unittest.TestCase):
    THEMES = sorted(p for p in THEMES.glob("*.json") if p.name != "theme.schema.json") + \
        sorted((THEMES / "generated").glob("*.json"))

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.env = scratch_env(self.tmp)
        self.out = Path(self.tmp) / "out"

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_script(self, script, args):
        result = subprocess.run([str(script)] + [str(a) for a in args], env=self.env,
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, f"{script.name} failed:\n{result.stderr}")
        warnings = [line for line in result.stderr.splitlines() if line.startswith("Warning:")]
        self.assertEqual(warnings, [], f"{script.name} warned")
        return result

    def assert_rendered(self, root):
        files = [p for p in Path(root).rglob("*") if p.is_file()] if Path(root).is_dir() else [Path(root)]
        self.assertTrue(files, f"nothing written to {root}")
        for f in files:
            text = f.read_text()
            self.assertTrue(text.strip(), f"{f} is empty")
            self.assertEqual(UNFILLED.findall(text), [], f"{f} has unfilled variables")

    def assert_parses(self, key, root):
        """Each output file of an integration parses as its format"""
        fmt = FORMATS.get(key)
        files = [p for p in Path(root).rglob("*") if p.is_file()] if Path(root).is_dir() else [Path(root)]
        for f in files:
            text = f.read_text()
            odd = [m.group(0) for m in COLOR.finditer(text) if len(m.group(1)) not in (6, 8)]
            self.assertEqual(odd, [], f"{f}: malformed colors")
            if fmt == "toml":
                tomllib.loads(text)
            elif fmt == "json" and (f.suffix == ".json" or key == "nvim"):
                json.loads(text)
            elif fmt == "plist":
                plistlib.loads(f.read_bytes())
            elif fmt == "ini":
                configparser.ConfigParser(interpolation=None, strict=False).read_string(text)
            elif fmt == "yaml":
                try:
                    import yaml
                except ImportError:
                    return
                yaml.safe_load(text)
            elif fmt == "css" and f.suffix == ".css":
                self.assertEqual(text.count("{"), text.count("}"), f"{f}: unbalanced braces")
                if key == "gtk":
                    self.assert_gtk_css(f)

    def assert_gtk_css(self, path):
        """GTK's own parser, when PyGObject and GTK are installed"""
        version = "4.0" if path.parent.name == "gtk-4.0" else "3.0"
        check = (
            "import sys, gi\n"
            "gi.require_version('Gtk', sys.argv[1])\n"
            "from gi.repository import Gtk\n"
            "errors = []\n"
            "p = Gtk.CssProvider()\n"
            "p.connect('parsing-error', lambda p, s, e: errors.append(e.message))\n"
            "p.load_from_path(sys.argv[2])\n"
            "print('\\n'.join(errors))\n"
        )
        result = subprocess.run([sys.executable, "-c", check, version, str(path)], capture_output=True, text=True)
        if result.returncode != 0:
            return  # no PyGObject or no GTK of that version
        self.assertEqual(result.stdout.strip(), "", f"{path}: GTK CSS errors")

    def test_every_integration_renders(self):
        scripts = sorted(SCRIPTS.glob("theme_*.sh"))
        self.assertTrue(scripts)
        for theme in self.THEMES:
            for script in scripts:
                key = script.stem.removeprefix("theme_")
                with self.subTest(script=script.name, theme=theme.name):
                    target = self.out / theme.stem / key
                    if key == "hyprlock":
                        target = target / "hyprlock.conf"
                        args = [theme, target, "Sans", "file:///tmp/wall.png", "1", "Hey you", "Password..."]
                    elif key in ("gtk", "vscode"):
                        args = [theme, target]
                    elif key in ("vesktop", "firefox"):
                        target = target / "axiom.css"
                        args = [theme, target]
                    elif key == "ncspot":
                        target = target / "config.toml"
                        target.parent.mkdir(parents=True)
                        target.write_text("[theme]\n" + NCSPOT_MARKERS)
                        args = [theme, target]
                    else:
                        target = target / "axiom.out"
                        args = [theme, target]
                    self.run_script(script, args)
                    self.assert_rendered(target)
                    self.assert_parses(key, target)

    def test_ncspot_leaves_your_keys(self):
        config = self.out / "config.toml"
        config.parent.mkdir(parents=True)
        config.write_text('use_nerdfont = true\n\n[theme]\nprimary = "red"\n' + NCSPOT_MARKERS + '\n[keybindings]\n"q" = "quit"\n')
        theme = THEMES / "ayu-dark.json"
        self.run_script(SCRIPTS / "theme_ncspot.sh", [theme, config])
        first = config.read_text()
        data = tomllib.loads(first)
        self.assertEqual(data["theme"]["primary"], "red")
        self.assertIn("background", data["theme"])
        self.assertEqual(data["keybindings"], {"q": "quit"})
        self.run_script(SCRIPTS / "theme_ncspot.sh", [theme, config])
        self.assertEqual(config.read_text(), first)

    def test_nvim_module_compiles(self):
        luac = shutil.which("luac")
        if not luac:
            self.skipTest("no luac")
        module = SCRIPTS / "templates" / "nvim" / "axiom_theme.lua"
        result = subprocess.run([luac, "-p", str(module)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_nvim_palette_has_readable_accents(self):
        target = self.out / "nvim-theme.json"
        for theme in (THEMES / "ayu-light.json", THEMES / "submarine-sonar.json"):
            with self.subTest(theme=theme.name):
                self.run_script(SCRIPTS / "theme_nvim.sh", [theme, target])
                data = json.loads(target.read_text())
                semantic = data["semantic"]
                self.assertRegex(semantic["accent"], HEX)
                for key in ("accent", "accentAlt"):
                    self.assertGreaterEqual(contrast(data["text"][key], semantic["background"]), 4.5, key)

    def test_nvim_module_maps_shipped_themes(self):
        text = (SCRIPTS / "templates" / "nvim" / "axiom_theme.lua").read_text()
        mapped = set(re.findall(r'^\s*\["([\w-]+)"\] = scheme\(', text, re.M))
        shipped = {p.stem for p in THEMES.glob("*.json")} - {"theme.schema"}
        self.assertEqual(mapped - shipped, set(), "map entries without a theme")
        self.assertEqual(shipped - mapped - {"submarine-sonar", "submarine-sonar-light", "nord-light", "alucard"},
                         set(), "themes without a map entry")

    def test_hyprlock_keeps_its_own_variables(self):
        target = self.out / "hyprlock.conf"
        self.run_script(SCRIPTS / "theme_hyprlock.sh",
                        [THEMES / "tokyo-night.json", target, "Sans", "file:///w.png", "0", "Hi", "Pass"])
        text = target.read_text()
        self.assertIn("$TIME", text)
        self.assertIn("/w.png", text)
        self.assertNotIn("file://", text)


class HookupScript(unittest.TestCase):
    """integration_hookup.py on scratch configs (ThemeIntegrations' x-hookup)"""

    def setUp(self):
        self.tmp = tempfile.mkdtemp()
        self.env = scratch_env(self.tmp)
        self.env["SHELL"] = "/bin/bash"
        self.config = Path(self.env["XDG_CONFIG_HOME"])

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def hookup(self, action, key, schema=None, targets=None):
        args = [sys.executable, str(SCRIPTS / "integration_hookup.py"), action, key]
        if schema:
            args += ["--schema", str(schema)]
        if targets is not None:
            args += ["--targets", json.dumps(targets)]
        result = subprocess.run(args, env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def write(self, rel, text):
        path = self.config / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(text)
        return path

    def backups(self, path):
        return sorted(Path(path).parent.glob(Path(path).name + ".axiom-bak-*"))

    def test_every_hookup_applies_to_empty_configs(self):
        schema = json.loads((ROOT / "config/json/config.schema.json").read_text())
        for key, prop in schema["properties"]["ThemeIntegrations"]["properties"].items():
            with self.subTest(key=key):
                self.assertIn("x-hookup", prop)
                self.hookup("apply", key)
                for target in self.hookup("status", key)["targets"]:
                    if not target["copyOnly"] and not target["skipped"]:
                        self.assertTrue(target["done"], f"{key}: {target}")

    def test_per_profile_targets(self):
        home = Path(self.env["HOME"])
        root = home / ".mozilla" / "firefox"
        for profile in ("a.default-release", "b c.other"):
            (root / profile).mkdir(parents=True)
        (root / "profiles.ini").write_text(
            "[Profile0]\nIsRelative=1\nPath=a.default-release\n\n"
            "[Profile1]\nIsRelative=1\nPath=b c.other\n\n[General]\nVersion=2\n")
        (root / "a.default-release" / "user.js").write_text(
            'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", false);\n')
        targets = self.hookup("status", "firefox")["targets"]
        self.assertEqual(len(targets), 4)
        self.hookup("apply", "firefox")
        self.assertTrue(all(t["done"] for t in self.hookup("status", "firefox")["targets"]))
        for profile in ("a.default-release", "b c.other"):
            css = (root / profile / "chrome" / "userChrome.css").read_text()
            self.assertTrue(css.startswith('@import url("axiom.css");'))
            prefs = (root / profile / "user.js").read_text().splitlines()
            self.assertEqual(prefs[-1], 'user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);')
        # The theme script themes the same profiles
        result = subprocess.run([str(SCRIPTS / "theme_firefox.sh"), str(THEMES / "ayu-dark.json")],
                                env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        for profile in ("a.default-release", "b c.other"):
            self.assertTrue((root / profile / "chrome" / "axiom.css").is_file())

    def test_per_profile_without_profiles_is_skipped(self):
        targets = self.hookup("status", "firefox")["targets"]
        self.assertTrue(targets)
        self.assertTrue(all(t["skipped"] == "profiles" for t in targets))

    def test_end_keeps_a_symlink_and_backs_up(self):
        real = Path(self.tmp) / "dotfiles" / "kitty.conf"
        real.parent.mkdir()
        real.write_text("font_size 12\n")
        link = self.config / "kitty" / "kitty.conf"
        link.parent.mkdir(parents=True)
        link.symlink_to(real)
        status = self.hookup("status", "kitty")["targets"][0]
        self.assertTrue(status["link"])
        self.hookup("apply", "kitty")
        self.assertTrue(link.is_symlink())
        self.assertEqual(real.read_text(), "font_size 12\n\ninclude axiom.conf\n")
        self.assertEqual(len(self.backups(real)), 1)
        self.assertEqual(self.backups(real)[0].read_text(), "font_size 12\n")
        # Done: a second Apply changes nothing
        self.assertFalse(self.hookup("apply", "kitty")["results"][0]["changed"])
        self.assertEqual(len(self.backups(real)), 1)

    def test_given_targets_hook_hyprland_up(self):
        path = self.write("hypr/hyprland.lua", '-- mine\nhl.bind("SUPER + Q", hl.dsp.exec_cmd("kitty"))\n')
        include = {"file": str(path), "place": "start", "comment": "--", "accept": r"axiom\.setup\(",
                   "text": 'local ok, axiom = pcall(dofile, "/x/axiom/hyprland.lua")\nif ok then axiom.setup() end'}
        autostart = {"file": str(path), "place": "end", "comment": "--", "accept": r"(qs|quickshell) .*axiom",
                     "text": 'hl.on("hyprland.start", function() hl.exec_cmd("qs -p \'/x/axiom\'") end) -- axiom'}
        targets = [include, autostart]
        self.assertFalse(any(t["done"] for t in self.hookup("status", "hyprland", targets=targets)["targets"]))
        self.hookup("apply", "hyprland", targets=targets)
        lines = path.read_text().splitlines()
        self.assertEqual(lines[:2], include["text"].splitlines())
        self.assertEqual(lines[-1], autostart["text"])
        self.assertEqual(len(self.backups(path)), 1)
        self.assertTrue(all(t["done"] for t in self.hookup("status", "hyprland", targets=targets)["targets"]))
        # install.sh's own autostart line counts as done
        path.write_text('hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom\n')
        self.assertTrue(self.hookup("status", "hyprland", targets=[autostart])["targets"][0]["done"])

    def test_start_goes_first(self):
        path = self.write("gtk-3.0/gtk.css", "window { color: red; }\n")
        self.hookup("apply", "gtk")
        self.assertEqual(path.read_text().splitlines()[0], '@import url("axiom.css");')

    def test_top_comments_out_the_old_key(self):
        path = self.write("helix/config.toml", 'theme = "onedark"\n\n[editor]\nline-number = "relative"\n')
        status = self.hookup("status", "helix")["targets"][0]
        self.assertEqual(status["replaces"], ['theme = "onedark"'])
        self.hookup("apply", "helix")
        parsed = tomllib.loads(path.read_text())
        self.assertEqual(parsed["theme"], "axiom")
        self.assertEqual(parsed["editor"], {"line-number": "relative"})
        self.assertIn('# axiom: theme = "onedark"', path.read_text())

    def test_section_present_and_missing(self):
        path = self.write("yazi/theme.toml", '[flavor]\ndark = "x"\n\n[mgr]\nfoo = 1\n')
        self.hookup("apply", "yazi")
        self.assertEqual(tomllib.loads(path.read_text())["flavor"], {"dark": "axiom", "light": "axiom"})
        path.write_text("[mgr]\nfoo = 1\n")
        self.assertTrue(self.hookup("status", "yazi")["targets"][0]["createsSection"])
        self.hookup("apply", "yazi")
        self.assertEqual(tomllib.loads(path.read_text())["flavor"], {"dark": "axiom", "light": "axiom"})

    def test_keep_leaves_other_lines(self):
        path = self.write("foot/foot.ini", "include=~/mine.ini\n\n[main]\nfont=x\n")
        status = self.hookup("status", "foot")["targets"][0]
        self.assertEqual(status["alongside"], ["include=~/mine.ini"])
        self.hookup("apply", "foot")
        lines = path.read_text().splitlines()
        self.assertEqual(lines[0], "include=~/mine.ini")
        self.assertTrue(lines[1].startswith("include=") and lines[1].endswith("foot/axiom.ini"))

    def test_conflict_is_left_alone(self):
        path = self.write("alacritty/alacritty.toml", '[general]\nimport = ["~/mine.toml"]\n')
        status = self.hookup("status", "alacritty")["targets"][0]
        self.assertEqual(status["conflicts"], ['import = ["~/mine.toml"]'])
        result = self.hookup("apply", "alacritty")["results"][0]
        self.assertEqual(result["error"], "conflict")
        self.assertEqual(path.read_text(), '[general]\nimport = ["~/mine.toml"]\n')

    def test_accept_counts_another_spelling(self):
        self.write("btop/btop.conf", 'color_theme = "/home/me/.config/btop/themes/axiom.theme"\n')
        self.assertTrue(self.hookup("status", "btop")["targets"][0]["done"])

    def test_shellrc_and_fish(self):
        self.hookup("apply", "fzf")
        rc = Path(self.env["HOME"]) / ".bashrc"
        self.assertIn("export FZF_DEFAULT_OPTS_FILE=", rc.read_text())
        self.env["SHELL"] = "/usr/bin/fish"
        self.hookup("apply", "fzf")
        fish = self.config / "fish" / "conf.d" / "axiom.fish"
        self.assertTrue(fish.read_text().startswith("set -gx FZF_DEFAULT_OPTS_FILE "))

    def test_requires_skips(self):
        schema = {"properties": {"ThemeIntegrations": {"properties": {"x": {"x-hookup": [
            {"file": "{config}/x.conf", "place": "end", "text": "x", "requires": "axiom-no-such-command"}]}}}}}
        path = Path(self.tmp) / "schema.json"
        path.write_text(json.dumps(schema))
        self.assertEqual(self.hookup("status", "x", path)["targets"][0]["skipped"], "requires")
        self.hookup("apply", "x", path)
        self.assertFalse((self.config / "x.conf").exists())

    def test_copy_never_overwrites(self):
        module = self.write("nvim/lua/axiom_theme.lua", "-- mine\n")
        self.hookup("apply", "nvim")
        self.assertEqual(module.read_text(), "-- mine\n")
        module.unlink()
        self.hookup("apply", "nvim")
        self.assertEqual(module.read_text(), (SCRIPTS / "templates/nvim/axiom_theme.lua").read_text())


class SelfUpdate(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.env = scratch_env(self.tmp)
        self.env.update({"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
                         "GIT_COMMITTER_EMAIL": "t@t"})
        self.upstream = self.tmp / "upstream"
        self.git("init", "-q", "-b", "main", str(self.upstream), cwd=self.tmp)
        self.commit(self.upstream, "one")
        self.git("tag", "-a", "v1.0.0", "-m", "first", cwd=self.upstream)
        self.clone = self.tmp / "clone"
        self.git("clone", "-q", str(self.upstream), str(self.clone), cwd=self.tmp)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def git(self, *args, cwd):
        subprocess.run(["git", *args], cwd=cwd, env=self.env, check=True, capture_output=True)

    def commit(self, repo, name):
        (repo / f"{name}.txt").write_text(name)
        self.git("add", ".", cwd=repo)
        self.git("commit", "-q", "-m", name, cwd=repo)

    def release(self, tag, notes="notes"):
        self.commit(self.upstream, tag)
        self.git("tag", "-a", tag, "-m", notes, cwd=self.upstream)

    def run_update(self, *args, ok=True):
        result = subprocess.run([str(SCRIPTS / "self_update.sh"), *args, str(self.clone)], env=self.env,
                                capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return json.loads(result.stdout)

    def test_uptodate(self):
        report = self.run_update("check")
        self.assertEqual((report["state"], report["current"], report["blocked"]), ("uptodate", "v1.0.0", ""))

    def test_available_then_applied(self):
        self.release("v1.1.0", "Better things")
        report = self.run_update("check")
        self.assertEqual((report["state"], report["latest"], report["behind"]), ("available", "v1.1.0", 1))
        self.assertIn("Better things", report["notes"])
        applied = self.run_update("apply", "v1.1.0")
        self.assertEqual((applied["state"], applied["current"], applied["error"]), ("uptodate", "v1.1.0", ""))
        self.assertTrue((self.clone / "v1.1.0.txt").exists())

    def test_dirty_clone_is_blocked(self):
        self.release("v1.1.0")
        self.run_update("check")
        (self.clone / "one.txt").write_text("local edit")
        self.assertEqual(self.run_update("check")["blocked"], "dirty")
        self.run_update("apply", "v1.1.0", ok=False)
        self.assertEqual((self.clone / "one.txt").read_text(), "local edit")

    def test_diverged_clone_is_blocked(self):
        self.release("v1.1.0")
        self.commit(self.clone, "mine")
        report = self.run_update("check")
        self.assertEqual((report["state"], report["blocked"]), ("diverged", "diverged"))
        self.run_update("apply", "v1.1.0", ok=False)

    def test_other_branch_is_blocked(self):
        self.release("v1.1.0")
        self.git("checkout", "-q", "-b", "feature", cwd=self.clone)
        self.assertEqual(self.run_update("check")["blocked"], "branch")

    def test_only_the_latest_tag_applies(self):
        self.release("v1.1.0")
        self.release("v1.2.0")
        self.run_update("check")
        self.assertIn("not an available update", self.run_update("apply", "v1.1.0", ok=False)["error"])

    def test_not_a_clone(self):
        shutil.rmtree(self.clone / ".git")
        self.assertEqual(self.run_update("check")["blocked"], "nogit")

    def test_main_channel_follows_commits(self):
        self.commit(self.upstream, "two")
        self.assertEqual(self.run_update("check")["state"], "uptodate")
        report = self.run_update("--channel", "main", "check")
        self.assertEqual((report["channel"], report["state"], report["behind"], report["current"]),
                         ("main", "available", 1, "v1.0.0"))
        self.assertIn("- two", report["notes"])
        applied = self.run_update("--channel", "main", "apply", report["latest"])
        self.assertEqual((applied["state"], applied["ahead"], applied["error"]), ("uptodate", False, ""))
        self.assertTrue((self.clone / "two.txt").exists())
        # Back on tags, being past the newest release isn't a downgrade
        report = self.run_update("check")
        self.assertEqual((report["state"], report["ahead"]), ("uptodate", True))

    def test_main_channel_falls_back_to_master(self):
        self.git("branch", "-m", "main", "master", cwd=self.upstream)
        self.commit(self.upstream, "two")
        report = self.run_update("--channel", "main", "check")
        self.assertEqual((report["state"], report["error"]), ("available", ""))

    def test_main_channel_detached_clone(self):
        self.git("checkout", "-q", "v1.0.0", cwd=self.clone)
        self.commit(self.upstream, "two")
        report = self.run_update("--channel", "main", "check")
        self.assertEqual((report["state"], report["blocked"]), ("available", ""))
        self.run_update("--channel", "main", "apply", report["latest"])
        self.assertTrue((self.clone / "two.txt").exists())


class ClaimHyprland(unittest.TestCase):
    HEADER = "-- Generated by axiom"
    FALLBACK = "-- Given back by axiom"

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.env = scratch_env(self.tmp)
        self.hypr = self.tmp / "hypr"
        self.hypr.mkdir()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def claim(self, action, directory=None):
        extra = [self.FALLBACK]
        result = subprocess.run([str(SCRIPTS / "claim_hyprland.sh"), action, f"{directory or self.hypr}/",
                                 self.HEADER] + extra, env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def listing(self, directory=None):
        return sorted(str(p.relative_to(directory or self.hypr)) for p in (directory or self.hypr).rglob("*"))

    def test_new(self):
        self.assertEqual(self.claim("check"), "new")
        self.assertEqual(self.listing(), [])
        self.assertEqual(self.claim("claim"), "created")
        self.assertEqual(self.listing(), ["user"])

    def test_adopt_copies_the_old_config_to_user(self):
        (self.hypr / "hyprland.lua").write_text("-- mine\n")
        self.assertEqual(self.claim("check"), "adopt")
        self.assertEqual(self.listing(), ["hyprland.lua"])
        self.assertEqual(self.claim("claim"), "adopted:00-previous.lua")
        self.assertEqual((self.hypr / "user" / "00-previous.lua").read_text(), "-- mine\n")
        # Left for the managed one to replace: Hyprland never finds it missing
        self.assertEqual((self.hypr / "hyprland.lua").read_text(), "-- mine\n")
        backups = list(self.hypr.glob("hyprland.lua.axiom-backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "-- mine\n")

    def test_claiming_again_before_the_managed_write_reuses_the_copies(self):
        (self.hypr / "hyprland.lua").write_text("-- mine\n")
        self.assertEqual(self.claim("claim"), "adopted:00-previous.lua")
        before = self.listing()
        self.assertEqual(self.claim("claim"), "adopted:00-previous.lua")
        self.assertEqual(self.listing(), before)

    def test_stock_example_is_replaced_not_adopted(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\nhl.bind(\"SUPER + M\", hl.dsp.exit())\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        # Whitespace and blank lines don't make it the user's own
        (self.hypr / "hyprland.lua").write_text("-- example  \n\nhl.bind(\"SUPER + M\", hl.dsp.exit())\n")
        self.assertEqual(self.claim("check"), "stock")
        self.assertEqual(self.claim("claim"), "replaced")
        self.assertEqual(self.listing(), ["hyprland.lua"] + [str(p.relative_to(self.hypr)) for p in
                                                             self.hypr.glob("*.axiom-backup-*")] + ["user"])
        self.assertEqual(list((self.hypr / "user").iterdir()), [])
        # Again before the managed write: no second backup
        self.assertEqual(self.claim("claim"), "replaced")
        self.assertEqual(len(list(self.hypr.glob("*.axiom-backup-*"))), 1)

    def test_example_with_axiom_autostart_is_stock(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        (self.hypr / "hyprland.lua").write_text(
            "-- example\n" + 'hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom\n')
        self.assertEqual(self.claim("check"), "stock")
        self.assertEqual(self.claim("claim"), "replaced")
        # With -n, as install.sh writes it now
        (self.hypr / "hyprland.lua").write_text(
            "-- example\n" + 'hl.on("hyprland.start", function() hl.exec_cmd("qs -n -c axiom") end) -- axiom\n')
        self.assertEqual(self.claim("check"), "stock")

    def test_autogenerated_example_is_stock(self):
        # What Hyprland writes with no hyprland.lua at its first start: a
        # banner, the autogenerated line, and its own pick of launcher
        example = self.tmp / "example.lua"
        example.write_text('-- example\nlocal menu        = "hyprlauncher"\nhl.bind("SUPER + M", hl.dsp.exit())\n')
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        (self.hypr / "hyprland.lua").write_text(
            "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --\n"
            "-- AUTOGENERATED HYPRLAND CONFIG.                        --\n"
            "-- EDIT THIS CONFIG ACCORDING TO THE WIKI INSTRUCTIONS.  --\n"
            "-- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- -- --\n"
            "hl.config({ autogenerated = true }) -- remove this line to remove the warning\n"
            '-- example\nlocal menu        = "hyprland-run"\nhl.bind("SUPER + M", hl.dsp.exit())\n')
        self.assertEqual(self.claim("check"), "stock")
        self.assertEqual(self.claim("claim"), "replaced")

    def test_edited_example_is_adopted(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        (self.hypr / "hyprland.lua").write_text("-- example\n-- mine\n")
        self.assertEqual(self.claim("check"), "adopt")
        self.assertEqual(self.claim("claim"), "adopted:00-previous.lua")

    def test_adopting_again_keeps_the_earlier_one(self):
        (self.hypr / "user").mkdir()
        (self.hypr / "user" / "00-previous.lua").write_text("-- earlier\n")
        (self.hypr / "hyprland.lua").write_text("-- mine\n")
        name = self.claim("claim").split(":", 1)[1]
        self.assertRegex(name, r"^00-previous-[0-9-]+\.lua$")
        self.assertEqual((self.hypr / "user" / "00-previous.lua").read_text(), "-- earlier\n")
        self.assertEqual((self.hypr / "user" / name).read_text(), "-- mine\n")

    def test_adopted_config_no_longer_starts_or_loads_axiom(self):
        lines = [
            'hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom',
            'local ok, axiom = pcall(dofile, "/home/me/.local/state/axiom/hyprland.lua")',
            "if ok then axiom.setup() end",
            'hl.env("A", "b")',
        ]
        (self.hypr / "hyprland.lua").write_text("\n".join(lines) + "\n")
        self.claim("claim")
        text = (self.hypr / "user" / "00-previous.lua").read_text().splitlines()
        self.assertTrue(all(line.startswith("-- ") for line in text[:3]), text)
        self.assertEqual(text[3], 'hl.env("A", "b")')

    def test_ours_is_left_alone(self):
        (self.hypr / "hyprland.lua").write_text(self.HEADER + " (Hyprland mode: managed)\n")
        for action in ("check", "claim"):
            self.assertEqual(self.claim(action), "ours")
        self.assertEqual(self.listing(), ["hyprland.lua"])

    def test_header_must_start_the_file(self):
        (self.hypr / "hyprland.lua").write_text("-- mine\n" + self.HEADER + "\n")
        self.assertEqual(self.claim("check"), "adopt")

    def test_git_tracked_dir_is_blocked(self):
        (self.hypr / "hyprland.lua").write_text("-- mine\n")
        subprocess.run(["git", "init", "-q", str(self.hypr)], env=self.env, check=True)
        for action in ("check", "claim"):
            self.assertEqual(self.claim(action), f"blocked:git:{self.hypr.resolve()}")
        self.assertEqual((self.hypr / "hyprland.lua").read_text(), "-- mine\n")
        self.assertFalse((self.hypr / "user").exists())

    def test_dir_inside_a_repo_is_blocked(self):
        repo = self.tmp / "dotfiles"
        (repo / "hypr").mkdir(parents=True)
        subprocess.run(["git", "init", "-q", str(repo)], env=self.env, check=True)
        self.assertEqual(self.claim("claim", repo / "hypr"), f"blocked:git:{repo.resolve()}")
        self.assertEqual(self.listing(repo / "hypr"), [])

    def test_symlinked_dir_is_blocked(self):
        link = self.tmp / "linked"
        link.symlink_to(self.hypr)
        self.assertEqual(self.claim("claim", link), "blocked:link")
        self.assertEqual(self.listing(), [])

    def test_symlinked_file_is_blocked(self):
        real = self.tmp / "real.lua"
        real.write_text("-- mine\n")
        (self.hypr / "hyprland.lua").symlink_to(real)
        self.assertEqual(self.claim("claim"), "blocked:link")
        self.assertTrue((self.hypr / "hyprland.lua").is_symlink())
        self.assertFalse((self.hypr / "user").exists())

    def test_usage(self):
        result = subprocess.run([str(SCRIPTS / "claim_hyprland.sh"), "claim", str(self.hypr)], env=self.env,
                                capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)
        # release needs the fallback file
        result = subprocess.run([str(SCRIPTS / "claim_hyprland.sh"), "release", str(self.hypr), self.HEADER],
                                env=self.env, capture_output=True, text=True)
        self.assertEqual(result.returncode, 2)

    def write_ours(self):
        (self.hypr / "hyprland.lua").write_text(self.HEADER + " (Hyprland mode: managed)\n")

    def test_release_gives_the_adopted_config_back(self):
        lines = [
            'hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom',
            'hl.env("A", "b")',
        ]
        (self.hypr / "hyprland.lua").write_text("\n".join(lines) + "\n")
        (self.hypr / "hyprland.lua").chmod(0o600)
        self.claim("claim")
        (self.hypr / "user" / "10-mine.lua").write_text("-- mine\n")
        self.write_ours()
        self.assertEqual(self.claim("release"), "restored:user/00-previous.lua:1")
        # As it was, starting axiom again
        self.assertEqual((self.hypr / "hyprland.lua").read_text(), "\n".join(lines) + "\n")
        self.assertEqual((self.hypr / "hyprland.lua").stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.hypr / "user" / "00-previous.lua").exists())
        self.assertTrue((self.hypr / "user" / "10-mine.lua").exists())
        # Released, it isn't axiom's any more
        self.assertEqual(self.claim("release"), "notours")

    def test_release_takes_the_newest_adopted_config(self):
        (self.hypr / "user").mkdir()
        (self.hypr / "user" / "00-previous.lua").write_text("-- first\n")
        (self.hypr / "user" / "00-previous-20260101-000000.lua").write_text("-- second\n")
        (self.hypr / "user" / "00-previous-20260202-000000.lua").write_text("-- third\n")
        self.write_ours()
        self.assertEqual(self.claim("release"), "restored:user/00-previous-20260202-000000.lua:2")
        self.assertEqual((self.hypr / "hyprland.lua").read_text(), "-- third\n")

    def test_release_gives_the_replaced_example_back(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        (self.hypr / "hyprland.lua").write_text("-- example\n")
        self.assertEqual(self.claim("claim"), "replaced")
        self.write_ours()
        backup = next(self.hypr.glob("hyprland.lua.axiom-backup-*")).name
        self.assertEqual(self.claim("release"), f"restored:{backup}:0")
        self.assertEqual((self.hypr / "hyprland.lua").read_text(), "-- example\n")
        self.assertEqual(list(self.hypr.glob("hyprland.lua.axiom-backup-*")), [])

    def test_release_writes_the_fallback_when_nothing_was_set_aside(self):
        self.assertEqual(self.claim("claim"), "created")
        self.write_ours()
        self.assertEqual(self.claim("release"), "written")
        self.assertEqual((self.hypr / "hyprland.lua").read_text(), self.FALLBACK + "\n")
        self.assertEqual((self.hypr / "hyprland.lua").stat().st_mode & 0o777, 0o644)
        self.assertEqual(self.listing(), ["hyprland.lua", "user"])

    def test_claim_only_backs_up_what_release_wrote(self):
        self.write_ours()
        self.assertEqual(self.claim("release"), "written")
        self.assertEqual(self.claim("check"), "released")
        self.assertEqual(self.claim("claim"), "replaced")
        self.assertEqual(self.listing(), ["hyprland.lua", "user"])
        # Written for included mode, it also loads the module
        (self.hypr / "hyprland.lua").write_text(
            'local ok, axiom = pcall(dofile, "/home/me/.local/state/axiom/hyprland.lua")\n'
            "if ok then axiom.setup() end\n" + self.FALLBACK + "\n")
        self.assertEqual(self.claim("check"), "released")
        # Edited, it's the user's
        (self.hypr / "hyprland.lua").write_text(self.FALLBACK + "\n-- mine\n")
        self.assertEqual(self.claim("check"), "adopt")

    def test_restoring_a_file_that_loads_user_reports_none_left(self):
        (self.hypr / "user").mkdir()
        (self.hypr / "user" / "00-previous.lua").write_text('pcall(require, "user." .. name)\n')
        (self.hypr / "user" / "10-mine.lua").write_text("-- mine\n")
        self.write_ours()
        self.assertEqual(self.claim("release"), "restored:user/00-previous.lua:0")

    def test_release_leaves_a_config_that_isnt_ours(self):
        (self.hypr / "hyprland.lua").write_text("-- mine\n")
        self.assertEqual(self.claim("release"), "notours")
        self.assertEqual(self.claim("release", self.tmp / "missing"), "notours")
        self.assertEqual(self.listing(), ["hyprland.lua"])

    def test_release_never_writes_through_a_symlink(self):
        real = self.tmp / "real.lua"
        real.write_text(self.HEADER + "\n")
        (self.hypr / "hyprland.lua").symlink_to(real)
        self.assertEqual(self.claim("release"), "blocked:link")
        self.assertTrue((self.hypr / "hyprland.lua").is_symlink())
        self.assertEqual(real.read_text(), self.HEADER + "\n")


class MergeHyprBinds(unittest.TestCase):
    EXAMPLE = Path("/usr/share/hypr/hyprland.lua")

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.hypr = self.tmp / "hypr"
        (self.hypr / "user").mkdir(parents=True)

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def write(self, name, text):
        (self.hypr / "user" / name).write_text(text)

    def run_merge(self, *args):
        result = subprocess.run([sys.executable, str(SCRIPTS / "merge_hypr_binds.py"), *args],
                                capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def extract(self, *args):
        return self.run_merge("extract", str(self.hypr), *args)

    def remove(self, sites):
        return self.run_merge("remove", str(self.hypr), json.dumps(sites))

    def test_nothing_to_merge(self):
        self.assertEqual(self.extract(), {"binds": [], "sites": [], "kept": [], "remapped": [], "tracked": [],
                                          "errors": []})

    @unittest.skipUnless(EXAMPLE.exists(), "Hyprland's example config isn't installed")
    def test_example_config_moves_completely_onto_axiom_actions(self):
        shutil.copy(self.EXAMPLE, self.hypr / "user" / "00-previous.lua")
        found = self.extract()
        self.assertEqual(found["kept"], [])
        self.assertNotIn("lua", {b["action"] for b in found["binds"]})
        by_key = {b["key"]: b for b in found["binds"]}
        self.assertEqual(by_key["SUPER + 0"]["action"], "workspaceNth")
        self.assertEqual(by_key["SUPER + 0"]["argument"], "10")
        # Its split moves off SUPER + J, which axiom's focus down uses
        self.assertNotIn("SUPER + J", by_key)
        self.assertEqual(by_key["SUPER + X"]["action"], "toggleSplit")
        # Its special workspace leaves WASD's S for V, and its float V for Z
        self.assertNotIn("SUPER + S", by_key)
        self.assertNotIn("SUPER + SHIFT + S", by_key)
        self.assertEqual((by_key["SUPER + V"]["action"], by_key["SUPER + V"]["argument"]), ("toggleSpecial", "magic"))
        self.assertEqual((by_key["SUPER + SHIFT + V"]["action"], by_key["SUPER + SHIFT + V"]["argument"]), ("moveToSpecial", "magic"))
        self.assertEqual(by_key["SUPER + Z"]["action"], "toggleFloat")
        self.assertEqual(by_key["SUPER + mouse_down"]["argument"], "right")
        self.assertTrue(by_key["XF86AudioRaiseVolume"]["repeating"])
        done = self.remove(found["sites"])
        self.assertEqual(done["failed"], [])
        text = (self.hypr / "user" / "00-previous.lua").read_text()
        self.assertNotIn("hl.bind(", text)
        self.assertIn("hl.window_rule(", text)
        self.assertEqual(len(list((self.hypr / "user").glob("*.axiom-backup-*"))), 1)
        self.assertEqual(self.extract()["binds"], [])

    def test_mapping_and_raw_lua(self):
        self.write("binds.lua", "\n".join([
            'local mod = "SUPER"',
            'hl.bind(mod .. " + T", hl.dsp.exec_cmd("foot"), { description = "Apps: Foot" })',
            'hl.bind(mod .. " + K", hl.dsp.layout("swapsplit"))',
            'hl.bind(mod .. " + L", hl.dsp.window.move({ workspace = "e+1" }))',
            'hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })',
            "",
        ]))
        binds = {b["key"]: b for b in self.extract()["binds"]}
        self.assertEqual((binds["SUPER + T"]["action"], binds["SUPER + T"]["argument"]), ("exec", "foot"))
        self.assertEqual(binds["SUPER + T"]["description"], "Apps: Foot")
        self.assertEqual((binds["SUPER + K"]["action"], binds["SUPER + K"]["argument"]), ("lua", 'hl.dsp.layout("swapsplit")'))
        self.assertEqual((binds["SUPER + L"]["action"], binds["SUPER + L"]["argument"]), ("moveWindowStep", "right"))
        self.assertEqual(binds["SUPER + mouse:272"]["action"], "mouseDrag")

    def test_what_cant_move_stays(self):
        self.write("binds.lua", "\n".join([
            'hl.bind("SUPER + A", function() end)',
            'hl.bind("SUPER + B", hl.dsp.window.close(), { non_consuming = true })',
            'local used = hl.bind("SUPER + C", hl.dsp.window.close())',
            "used:set_enabled(false)",
            'hl.bind("SUPER + D", hl.dsp.window.close()) hl.bind("SUPER + E", hl.dsp.window.pin())',
            "for _, k in ipairs({ \"F\", \"G\" }) do",
            '  hl.bind("SUPER + " .. k, k == "F" and hl.dsp.window.close() or function() end)',
            "end",
            'hl.bind("SUPER + H", hl.dsp.window.pin())',
            "",
        ]))
        found = self.extract()
        self.assertEqual([b["key"] for b in found["binds"]], ["SUPER + H"])
        self.assertEqual(sorted(k["key"] for k in found["kept"]), ["SUPER + A", "SUPER + B", "SUPER + C", "SUPER + D", "SUPER + E", "SUPER + F", "SUPER + G"])
        self.remove(found["sites"])
        text = (self.hypr / "user" / "binds.lua").read_text()
        self.assertNotIn("SUPER + H", text)
        self.assertIn("SUPER + C", text)

    def test_unbind_of_a_moved_key_goes_too(self):
        self.write("binds.lua", 'hl.unbind("SUPER + Q")\nhl.bind("SUPER + Q", hl.dsp.exec_cmd("foot"))\nhl.unbind("SUPER + W")\n')
        found = self.extract()
        self.assertEqual(len(found["sites"]), 2)
        self.remove(found["sites"])
        self.assertEqual((self.hypr / "user" / "binds.lua").read_text(), 'hl.unbind("SUPER + W")\n')

    def test_multiline_call_and_trailing_comment(self):
        self.write("binds.lua", 'hl.bind(\n  "SUPER + Q",\n  hl.dsp.exec_cmd("a )"), -- (\n  { locked = true }\n) -- done\nhl.env("A", "b")\n')
        found = self.extract()
        self.assertTrue(found["binds"][0]["locked"])
        self.remove(found["sites"])
        self.assertEqual((self.hypr / "user" / "binds.lua").read_text(), 'hl.env("A", "b")\n')

    def test_shared_modules_are_left_alone(self):
        (self.hypr / "user" / "lib").mkdir()
        (self.hypr / "user" / "lib" / "keys.lua").write_text('return function() hl.bind("SUPER + Z", hl.dsp.window.pin()) end\n')
        self.write("binds.lua", 'require("user.lib.keys")()\n')
        found = self.extract()
        self.assertEqual(found["binds"], [])
        self.assertEqual(found["kept"][0]["reason"], "shared")

    def test_running_the_files_does_nothing_and_ends(self):
        marker = self.tmp / "ran"
        self.write("binds.lua", "\n".join([
            "for _, m in ipairs(hl.get_monitors()) do end",
            f'io.popen("touch {marker}")',
            f'io.open("{marker}", "w")',
            'print("noise")',
            'hl.bind("SUPER + Y", hl.dsp.window.close(), { locked = false })',
            "",
        ]))
        found = self.extract()
        self.assertFalse(marker.exists())
        self.assertEqual(found["errors"], [])
        self.assertEqual([b["key"] for b in found["binds"]], ["SUPER + Y"])
        self.assertFalse(found["binds"][0]["locked"])

    def test_only_reads_the_named_file(self):
        self.write("00-previous.lua", 'hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))\n')
        self.write("mine.lua", 'hl.bind("SUPER + J", hl.dsp.layout("togglesplit"))\n')
        found = self.extract("--only", "00-previous.lua")
        self.assertEqual([s["file"] for s in found["sites"]], [str((self.hypr / "user" / "00-previous.lua").resolve())])
        # The adopted example's key moves off axiom's, and says so
        self.assertEqual(found["remapped"], [{"from": "SUPER + J", "to": "SUPER + X", "action": "toggleSplit"}])
        # A file of the user's own keeps its key
        found = self.extract("--only", "mine.lua")
        self.assertEqual(found["binds"][0]["key"], "SUPER + J")
        self.assertEqual(found["remapped"], [])

    def test_a_failed_removal_names_its_sites(self):
        self.write("binds.lua", 'hl.bind("SUPER + Y", hl.dsp.window.close())\nhl.bind("SUPER + U", hl.dsp.window.pin())\n')
        found = self.extract()
        self.assertEqual([len(s["binds"]) for s in found["sites"]], [1, 1])
        path = self.hypr / "user" / "binds.lua"
        path.chmod(0o640)
        # The second call is gone by the time remove runs
        path.write_text('hl.bind("SUPER + Y", hl.dsp.window.close())\n')
        done = self.remove(found["sites"])
        self.assertEqual(done["removed"], 1)
        self.assertEqual([(f["line"], f["reason"]) for f in done["failed"]], [(2, "changed")])
        self.assertEqual(path.stat().st_mode & 0o777, 0o640)


class GenerateTheme(unittest.TestCase):
    def test_wallpaper_makes_a_valid_pair(self):
        tmp = Path(tempfile.mkdtemp())
        try:
            env = scratch_env(tmp)
            setup = subprocess.run([str(SCRIPTS / "setup_venv.sh")], env=env, capture_output=True, text=True,
                                   timeout=600)
            if setup.returncode != 0:
                message = f"venv setup failed:\n{setup.stderr[-500:]}"
                # Offline or without pip locally is fine; CI must run it
                if os.environ.get("CI"):
                    self.fail(message)
                self.skipTest(message)
            python = str(ROOT / ".venv" / "bin" / "python3")
            image = tmp / "wall.png"
            # Bands of colour, so every accent slot has something to pick from
            subprocess.run([python, "-c", (
                "from PIL import Image\n"
                "img = Image.new('RGB', (120, 80))\n"
                "cols = [(30, 40, 90), (200, 80, 60), (60, 160, 90), (220, 200, 80), (140, 60, 160)]\n"
                "for x in range(120):\n"
                "    for y in range(80):\n"
                "        img.putpixel((x, y), cols[(x // 24) % len(cols)])\n"
                f"img.save({str(image)!r})\n")], check=True, env=env)
            out = tmp / "themes"
            out.mkdir()
            (out / "pywal-dark-wal.json").write_text("{}")  # from before styles: removed
            result = subprocess.run([python, str(SCRIPTS / "generate_theme.py"), str(image), "--output_dir",
                                     str(out)], env=env, capture_output=True, text=True, timeout=300)
            self.assertEqual(result.returncode, 0, result.stderr)
            styles = ["alternate", "faithful", "muted", "tonal", "vibrant"]
            files = sorted(out.glob("*.json"))
            self.assertEqual([f.stem for f in files],
                             [f"wallpaper-{s}-{v}" for s in styles for v in ("dark", "light")])
            themes = {f.stem: json.loads(f.read_text()) for f in files}
            names = {t["name"] for t in themes.values()} | set(themes)
            for stem, theme in themes.items():
                with self.subTest(theme=stem):
                    self.assertEqual(theme["variant"], stem.rsplit("-", 1)[1])
                    self.assertEqual(theme_problems(theme, names), [])
            # Every style looks different from every other
            palettes = [tuple(sorted(themes[f"wallpaper-{s}-dark"]["colors"].items())) for s in styles]
            self.assertEqual(len(set(palettes)), len(styles))
        finally:
            shutil.rmtree(tmp)


CALENDAR_FEED = """BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//test//EN
X-WR-CALNAME:Team
X-APPLE-CALENDAR-COLOR:#3366CCFF
BEGIN:VEVENT
UID:weekly
DTSTART;TZID=Europe/Berlin:20260707T100000
DTEND;TZID=Europe/Berlin:20260707T103000
RRULE:FREQ=WEEKLY;COUNT=4
EXDATE;TZID=Europe/Berlin:20260714T100000
SUMMARY:Standup
BEGIN:VALARM
ACTION:DISPLAY
TRIGGER:-PT15M
END:VALARM
END:VEVENT
BEGIN:VEVENT
UID:weekly
RECURRENCE-ID;TZID=Europe/Berlin:20260721T100000
DTSTART;TZID=Europe/Berlin:20260721T120000
DTEND;TZID=Europe/Berlin:20260721T123000
SUMMARY:Standup (moved)
END:VEVENT
BEGIN:VEVENT
UID:trip
DTSTART;VALUE=DATE:20260710
DTEND;VALUE=DATE:20260713
SUMMARY:Trip
LOCATION:Coast
END:VEVENT
END:VCALENDAR
"""


class CalendarSync(unittest.TestCase):
    """calendar_sync.py: an .ics feed served locally (discover, sync and the
    occurrences it writes), and the edits it makes to events, without a
    server. Times in UTC (TZ), so the expected values don't depend on the
    machine. Skipped when the venv can't be set up."""

    @classmethod
    def setUpClass(cls):
        cls.tmp = Path(tempfile.mkdtemp())
        cls.env = dict(scratch_env(cls.tmp), TZ="UTC")
        setup = subprocess.run([str(SCRIPTS / "setup_venv.sh")], env=cls.env, capture_output=True, text=True,
                               timeout=600)
        if setup.returncode != 0:
            shutil.rmtree(cls.tmp)
            message = f"venv setup failed:\n{setup.stderr[-500:]}"
            if os.environ.get("CI"):
                raise AssertionError(message)
            raise unittest.SkipTest(message)
        cls.python = str(ROOT / ".venv" / "bin" / "python3")

    @classmethod
    def tearDownClass(cls):
        shutil.rmtree(cls.tmp, ignore_errors=True)

    def run_helper(self, command, request):
        result = subprocess.run([self.python, str(SCRIPTS / "calendar_sync.py"), command], input=json.dumps(request),
                                env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        return json.loads(result.stdout)

    def serve(self, directory):
        import functools
        import http.server
        import threading
        class Quiet(http.server.SimpleHTTPRequestHandler):
            def log_message(self, *args):
                pass

        server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), functools.partial(Quiet, directory=str(directory)))
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        return f"http://127.0.0.1:{server.server_address[1]}"

    def test_feed_discover_and_sync(self):
        site = self.tmp / "site"
        site.mkdir(exist_ok=True)
        (site / "team.ics").write_text(CALENDAR_FEED)
        url = self.serve(site) + "/team.ics"

        found = self.run_helper("discover", {"kind": "ics", "url": url})
        self.assertEqual(found["calendars"], [{"href": url, "name": "Team", "color": "#3366CC",
                                               "components": ["VEVENT"], "readOnly": True}])

        state = self.tmp / "state"
        ms = lambda *args: int(__import__("datetime").datetime(*args, tzinfo=__import__("datetime").timezone.utc)
                               .timestamp() * 1000)
        result = self.run_helper("sync", {
            "stateDir": str(state),
            "range": {"from": ms(2026, 7, 1), "to": ms(2026, 8, 1)},
            "accounts": [{"id": "feed", "kind": "ics", "url": url, "calendars": [{"href": url}]}],
        })
        self.assertTrue(result["ok"], result)
        self.assertEqual(result["errors"], [])
        events = json.loads((state / "events.json").read_text())["events"]
        self.assertEqual(stat.S_IMODE((state / "events.json").stat().st_mode), 0o600)
        self.assertEqual([(e["title"], e["start"]) for e in events], [
            ("Standup", ms(2026, 7, 7, 8)),           # 10:00 in Berlin's summer time
            ("Trip", ms(2026, 7, 10)),
            ("Standup (moved)", ms(2026, 7, 21, 10)),  # the override; the 14th is excluded
            ("Standup", ms(2026, 7, 28, 8)),
        ])
        first, trip, moved = events[0], events[1], events[2]
        self.assertEqual(first["calendar"], "feed|" + url)
        self.assertTrue(first["recurring"])
        self.assertEqual(first["repeat"], "custom")  # COUNT makes it more than a plain weekly rule
        self.assertEqual(first["reminder"], 15)
        self.assertEqual(first["alarms"], [ms(2026, 7, 7, 7, 45)])
        self.assertEqual(moved["rid"], f"T:{ms(2026, 7, 21, 8) // 1000}")
        self.assertEqual(moved["alarms"], [])
        self.assertTrue(trip["allDay"])
        self.assertEqual((trip["dayStart"], trip["dayEnd"], trip["location"]), ("2026-07-10", "2026-07-13", "Coast"))
        self.assertFalse(trip["recurring"])
        self.assertEqual(trip["rid"], "")

        # A feed that's gone keeps the last copy and reports it
        (site / "team.ics").unlink()
        result = self.run_helper("sync", {
            "stateDir": str(state),
            "range": {"from": ms(2026, 7, 1), "to": ms(2026, 8, 1)},
            "accounts": [{"id": "feed", "kind": "ics", "url": url, "calendars": [{"href": url}]}],
        })
        self.assertEqual([e["code"] for e in result["errors"]], ["notFound"])
        self.assertEqual(len(json.loads((state / "events.json").read_text())["events"]), 4)

    def test_edits(self):
        """New events, a moved occurrence, an excluded one and a shifted
        series, read back through the same expansion the sync uses."""
        script = r'''
import datetime as dt, json, sys
sys.path.insert(0, sys.argv[1])
import calendar_sync as c
import icalendar
utc = dt.timezone.utc
tz = c.local_zone()
ms = lambda *a: int(dt.datetime(*a, tzinfo=utc).timestamp() * 1000)
def occurrences(cal):
    obj = {"ics": cal.to_ical().decode(), "etag": ""}
    return [(o["title"], o["start"], o["rid"], o["repeat"], o["reminder"]) for o in
            c.expand_object("a|cal", "h", obj, dt.datetime(2026, 7, 1, tzinfo=utc), dt.datetime(2026, 8, 1, tzinfo=utc))]
out = {}
cal, uid = c.build_new({"title": "Gym", "allDay": False, "start": ms(2026, 7, 6, 18), "end": ms(2026, 7, 6, 19),
                        "repeat": "weekly", "reminder": 30, "location": "", "description": ""}, tz)
out["new"] = occurrences(cal)
rid = out["new"][1][2]
c.apply_occurrence(cal, {"title": "Gym (late)", "allDay": False, "start": ms(2026, 7, 13, 20), "end": ms(2026, 7, 13, 21)}, rid, tz)
c.exclude_occurrence(cal, out["new"][2][2], tz)
out["occurrence"] = occurrences(cal)
c.apply_series(cal, {"title": "Gym", "allDay": False, "start": ms(2026, 7, 6, 17), "end": ms(2026, 7, 6, 18),
                     "origStart": ms(2026, 7, 6, 18), "repeat": "weekly", "repeatChanged": False,
                     "reminder": 30, "reminderChanged": False}, tz)
out["shifted"] = occurrences(cal)
c.apply_series(cal, {"title": "Gym once", "allDay": False, "start": ms(2026, 7, 6, 17), "end": ms(2026, 7, 6, 18),
                     "origStart": ms(2026, 7, 6, 17), "repeat": "none", "repeatChanged": True,
                     "reminder": -1, "reminderChanged": True}, tz)
out["single"] = occurrences(cal)
day, _ = c.build_new({"title": "Holiday", "allDay": True, "dayStart": "2026-07-20", "dayEnd": "2026-07-22",
                      "repeat": "none", "reminder": -1}, tz)
out["allDay"] = [(o["title"], o["dayStart"], o["dayEnd"]) for o in
                 c.expand_object("a|cal", "h", {"ics": day.to_ical().decode()}, dt.datetime(2026, 7, 1), dt.datetime(2026, 8, 1))]
print(json.dumps(out))
'''
        result = subprocess.run([self.python, "-c", script, str(SCRIPTS)], env=self.env, capture_output=True,
                                text=True, timeout=60)
        self.assertEqual(result.returncode, 0, result.stderr)
        out = json.loads(result.stdout)
        utc = __import__("datetime").timezone.utc
        ms = lambda *args: int(__import__("datetime").datetime(*args, tzinfo=utc).timestamp() * 1000)
        rid = lambda *args: f"T:{ms(*args) // 1000}"
        self.assertEqual([tuple(o) for o in out["new"]], [
            ("Gym", ms(2026, 7, d, 18), rid(2026, 7, d, 18), "weekly", 30) for d in (6, 13, 20, 27)])
        # The 13th moved to 20:00 under its own title, the 20th gone
        self.assertEqual([tuple(o[:3]) for o in out["occurrence"]], [
            ("Gym", ms(2026, 7, 6, 18), rid(2026, 7, 6, 18)),
            ("Gym (late)", ms(2026, 7, 13, 20), rid(2026, 7, 13, 18)),
            ("Gym", ms(2026, 7, 27, 18), rid(2026, 7, 27, 18))])
        # An hour earlier: the override and the exclusion move with the series
        self.assertEqual([tuple(o[:3]) for o in out["shifted"]], [
            ("Gym", ms(2026, 7, 6, 17), rid(2026, 7, 6, 17)),
            ("Gym (late)", ms(2026, 7, 13, 20), rid(2026, 7, 13, 17)),
            ("Gym", ms(2026, 7, 27, 17), rid(2026, 7, 27, 17))])
        # No longer repeating: one event, no reminder, overrides dropped
        self.assertEqual([tuple(o) for o in out["single"]], [("Gym once", ms(2026, 7, 6, 17), "", "none", -1)])
        self.assertEqual([tuple(o) for o in out["allDay"]], [("Holiday", "2026-07-20", "2026-07-22")])

    def test_failures_are_json(self):
        self.assertEqual(self.run_helper("discover", {"kind": "caldav", "url": "https://example.invalid"})["code"],
                         "noPassword")
        unreachable = self.run_helper("discover", {"kind": "ics", "url": "http://127.0.0.1:9/feed.ics"})
        self.assertEqual(unreachable["code"], "network")
        self.assertEqual(self.run_helper("save", {"stateDir": str(self.tmp), "range": {"from": 0, "to": 1},
                                                  "accounts": [], "account": "nope", "calendar": "x",
                                                  "event": {}})["code"], "notFound")


class GreeterInstall(unittest.TestCase):
    """greeter_install.sh on a scratch root (AXIOM_GREETER_ROOT), as the
    current user standing in for both the user and greetd's user."""
    SESSION = "/usr/share/axiom-greeter/scripts/greeter/greeter-session.sh"

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.env = scratch_env(self.tmp)
        self.env.update({"GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@t", "GIT_COMMITTER_NAME": "t",
                         "GIT_COMMITTER_EMAIL": "t@t"})
        self.user = subprocess.run(["id", "-un"], capture_output=True, text=True, check=True).stdout.strip()
        self.root = self.tmp / "root"
        self.env["AXIOM_GREETER_ROOT"] = str(self.root)
        self.config = self.root / "etc/greetd/config.toml"
        self.config.parent.mkdir(parents=True)
        self.original = ('[terminal]\nvt = 1\n\n[default_session]\n# the greeter\n'
                         f'command = "agreety --cmd /bin/sh"\nuser = "{self.user}"\n')
        self.config.write_text(self.original)
        for name in ["greetd", "agreety"]:
            program = self.root / "usr/bin" / name
            program.parent.mkdir(parents=True, exist_ok=True)
            program.write_text("#!/bin/sh\n")
            program.chmod(0o755)
        link = self.root / "etc/systemd/system/display-manager.service"
        link.parent.mkdir(parents=True)
        link.symlink_to("/usr/lib/systemd/system/sddm.service")
        self.repo = self.tmp / "repo"
        for name in ["greeter.qml", "shell.qml", "scripts/greeter/greeter-session.sh", "tests/tst_x.qml",
                     "docs/notes.md"]:
            (self.repo / name).parent.mkdir(parents=True, exist_ok=True)
            (self.repo / name).write_text(name)
        policy = self.repo / "scripts/greeter/org.axiom.greeter.policy"
        policy.write_text((SCRIPTS / "greeter" / "org.axiom.greeter.policy").read_text())
        helper = self.repo / "scripts/greeter/greeter_install.sh"
        shutil.copy(SCRIPTS / "greeter" / "greeter_install.sh", helper)
        helper.chmod(0o755)
        self.policy = self.root / "usr/share/polkit-1/actions/org.axiom.greeter.policy"
        subprocess.run(["git", "init", "-q", "-b", "main", str(self.repo)], env=self.env, check=True)
        self.git("add", ".")
        self.git("commit", "-q", "-m", "x")
        self.git("tag", "-a", "v1.0", "-m", "v1.0")
        # The clone's upstream, where git installs fetch from
        self.upstream = self.tmp / "upstream.git"
        subprocess.run(["git", "clone", "-q", "--bare", str(self.repo), str(self.upstream)], env=self.env, check=True)
        self.git("remote", "add", "origin", str(self.upstream))

    def git(self, *args, cwd=None):
        return subprocess.run(["git", *args], cwd=cwd or self.repo, env=self.env, check=True,
                              capture_output=True, text=True).stdout.strip()

    def publish(self, name, text, tag=None):
        """A commit on the upstream's main (and a tag on it)."""
        (self.repo / name).write_text(text)
        self.git("commit", "-qam", f"{name}: {text}")
        if tag:
            self.git("tag", "-a", tag, "-m", tag)
        self.git("push", "-q", "origin", "main", "--tags")

    def copied(self, name="greeter.qml"):
        return (self.root / "usr/share/axiom-greeter" / name).read_text()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def run_script(self, action, ok=True, source="git", channel="tags", staged=""):
        args = [str(SCRIPTS / "greeter" / "greeter_install.sh"), action, str(self.repo)]
        if action in ("install", "update"):
            args += [self.user, staged, source, channel]
        elif action == "uninstall":
            args.append(self.user)
        else:
            args += [source, channel]
        result = subprocess.run(args, env=self.env, capture_output=True, text=True, timeout=60)
        self.assertEqual(result.returncode == 0, ok, result.stdout + result.stderr)
        return json.loads(result.stdout) if action != "hash" else result.stdout.strip()

    def command(self):
        return tomllib.loads(self.config.read_text())["default_session"]["command"]

    def test_check_before_install(self):
        report = self.run_script("check")
        self.assertEqual((report["greetd"], report["displayManager"], report["installed"], report["configured"]),
                         (True, "sddm", False, False))
        self.assertEqual(report["greeterUser"], self.user)
        self.assertEqual(report["url"], str(self.upstream))
        self.assertEqual(report["currentHash"], self.git("rev-parse", "v1.0^{commit}"))
        self.assertEqual(self.run_script("hash"), report["currentHash"])
        local = self.run_script("hash", source="local")
        self.assertRegex(local, "^[0-9a-f]{64}$")
        # A content hash: it doesn't move with the clock
        time.sleep(1.1)
        self.assertEqual(self.run_script("hash", source="local"), local)

    def test_check_as_root(self):
        """As root (pkexec, CI) check runs nothing as another user: its third
        argument is the source, never a user name."""
        args = ["unshare", "-r", str(SCRIPTS / "greeter" / "greeter_install.sh"), "check", str(self.repo), "local"]
        if os.geteuid() == 0:
            args = args[2:]
        elif not shutil.which("unshare") or subprocess.run(["unshare", "-r", "true"], capture_output=True).returncode:
            self.skipTest("no user namespaces to be root in")
        result = subprocess.run(args, env=self.env, capture_output=True, text=True, timeout=60)
        report = json.loads(result.stdout)
        self.assertEqual(report["url"], "")
        self.assertEqual(report["currentHash"], self.run_script("hash", source="local"))
        args[args.index("local")] = "git"
        self.assertEqual(json.loads(subprocess.run(args, env=self.env, capture_output=True, text=True,
                                                   timeout=60).stdout)["url"], str(self.upstream))

    def test_https_for_ssh_remotes(self):
        self.git("remote", "set-url", "origin", "git@github.com:axiom-dotfiles/axiom.git")
        self.assertEqual(self.run_script("check")["url"], "https://github.com/axiom-dotfiles/axiom.git")
        self.git("remote", "set-url", "origin", "ssh://git@example.org/me/axiom.git")
        self.assertEqual(self.run_script("check")["url"], "https://example.org/me/axiom.git")

    def test_install_copies_points_greetd_and_backs_up(self):
        bundle = self.root / "var/lib/axiom-greeter/config"
        bundle.mkdir(parents=True)
        (bundle / "greeter.json").write_text("{}")
        report = self.run_script("install")
        self.assertTrue(report["ok"], report)
        copy = self.root / "usr/share/axiom-greeter"
        self.assertTrue((copy / "greeter.qml").is_file())
        self.assertFalse((copy / "tests").exists())
        self.assertFalse((copy / "docs").exists())
        self.assertEqual((copy / "fallback/greeter.json").read_text(), "{}")
        self.assertEqual(self.command(), self.SESSION)
        parsed = tomllib.loads(self.config.read_text())
        self.assertEqual(parsed["default_session"]["user"], self.user)
        self.assertEqual(parsed["terminal"]["vt"], 1)
        self.assertEqual((self.config.parent / "config.toml.axiom-original").read_text(), self.original)
        self.assertEqual(Path(report["backup"]).read_text(), self.original)
        self.assertTrue((self.root / "var/lib/axiom-greeter/state").is_dir())
        report = self.run_script("check")
        self.assertEqual((report["installed"], report["configured"], report["bundleWritable"]), (True, True, True))
        self.assertEqual(report["installedHash"], report["currentHash"])

    def test_install_snapshots_a_staged_bundle(self):
        staged = self.tmp / "staged"
        staged.mkdir()
        (staged / "greeter.json").write_text('{"staged": true}')
        (staged / "theme.json").symlink_to("/etc/hostname")
        self.run_script("install", staged=str(staged))
        fallback = self.root / "usr/share/axiom-greeter/fallback"
        self.assertEqual((fallback / "greeter.json").read_text(), '{"staged": true}')
        self.assertFalse((fallback / "theme.json").exists())

    def test_update_again_changes_nothing_in_greetd(self):
        self.run_script("install")
        report = self.run_script("update")
        self.assertTrue(report["ok"], report)
        self.assertEqual(report["backup"], "")
        self.assertEqual(len(list(self.config.parent.glob("config.toml.axiom-bak-*"))), 1)

    def test_git_tags_takes_the_newest_release_only(self):
        self.publish("greeter.qml", "unreleased")
        self.run_script("install")
        self.assertEqual(self.copied(), "greeter.qml")
        report = self.run_script("check")
        self.assertEqual(report["installedSource"], "git:tags")
        self.assertEqual(report["installedHash"], report["currentHash"])
        self.publish("greeter.qml", "v1.10", tag="v1.10")
        self.publish("shell.qml", "v1.9", tag="v1.9")
        report = self.run_script("check")
        self.assertEqual(report["currentHash"], self.git("rev-parse", "v1.10^{commit}"))
        self.assertNotEqual(report["installedHash"], report["currentHash"])
        self.run_script("update")
        self.assertEqual(self.copied(), "v1.10")
        report = self.run_script("check")
        self.assertEqual(report["installedHash"], report["currentHash"])

    def test_git_main_follows_the_branch(self):
        self.publish("greeter.qml", "on main")
        self.run_script("install", channel="main")
        self.assertEqual(self.copied(), "on main")
        self.assertEqual(self.run_script("check", channel="main")["installedSource"], "git:main")

    def test_git_ignores_the_clone(self):
        """Uncommitted edits, local commits and a changed remote don't reach a git copy."""
        self.run_script("install")
        (self.repo / "greeter.qml").write_text("edited")
        self.git("commit", "-qam", "local only")
        other = self.tmp / "other.git"
        subprocess.run(["git", "clone", "-q", "--bare", str(self.repo), str(other)], env=self.env, check=True)
        self.git("tag", "-a", "v9.0", "-m", "v9.0")
        self.git("push", "-q", str(other), "v9.0")
        self.git("remote", "set-url", "origin", str(other))
        report = self.run_script("check")
        self.assertEqual(report["url"], str(self.upstream))
        self.assertEqual(report["installedHash"], report["currentHash"])
        self.run_script("update")
        self.assertEqual(self.copied(), "greeter.qml")

    def test_local_copies_the_working_tree(self):
        self.git("checkout", "-q", "-b", "feature")
        (self.repo / "greeter.qml").write_text("uncommitted")
        self.run_script("install", source="local")
        self.assertEqual(self.copied(), "uncommitted")
        self.assertFalse((self.root / "usr/share/axiom-greeter/docs").exists())
        report = self.run_script("check", source="local")
        self.assertEqual(report["installedSource"], "local")
        self.assertEqual(report["installedHash"], report["currentHash"])
        (self.repo / "greeter.qml").write_text("edited again")
        report = self.run_script("check", source="local")
        self.assertNotEqual(report["installedHash"], report["currentHash"])
        # A docs edit isn't code
        self.run_script("update", source="local")
        (self.repo / "docs/notes.md").write_text("more")
        report = self.run_script("check", source="local")
        self.assertEqual(report["installedHash"], report["currentHash"])

    def test_switching_source(self):
        self.run_script("install", source="local")
        self.assertEqual(self.run_script("check")["installedSource"], "local")
        self.run_script("update")
        self.assertEqual(self.run_script("check")["installedSource"], "git:tags")

    def test_refuses_a_release_without_a_login_screen(self):
        self.git("rm", "-q", "greeter.qml")
        self.git("commit", "-qm", "old")
        self.git("tag", "-a", "v2.0", "-m", "v2.0")
        self.git("push", "-q", "origin", "main", "--tags")
        self.assertIn("v2.0 has no login screen", self.run_script("install", ok=False)["error"])
        self.assertIn("has no login screen", self.run_script("install", ok=False, source="local")["error"])
        self.assertFalse((self.root / "usr/share/axiom-greeter").exists())

    def test_git_unreachable(self):
        self.git("remote", "set-url", "origin", str(self.tmp / "missing.git"))
        self.assertEqual(self.run_script("check")["currentHash"], "")
        self.assertIn("offline", self.run_script("install", ok=False)["error"])

    def test_policy_names_the_installed_helper(self):
        self.assertFalse(self.run_script("check")["helper"])
        self.run_script("install")
        self.assertTrue(self.run_script("check")["helper"])
        self.assertIn("<annotate key=\"org.freedesktop.policykit.exec.path\">/usr/share/axiom-greeter/scripts/greeter/greeter_install.sh<",
                      self.policy.read_text())
        self.run_script("uninstall")
        self.assertFalse(self.policy.exists())

    def test_section_without_a_command_gets_one(self):
        self.config.write_text(f'[default_session]\nuser = "{self.user}"\n\n[terminal]\nvt = 1\n')
        self.assertTrue(self.run_script("install")["ok"])
        parsed = tomllib.loads(self.config.read_text())
        self.assertEqual(parsed["default_session"], {"command": self.SESSION, "user": self.user})
        self.assertEqual(parsed["terminal"]["vt"], 1)

    def test_uninstall_restores_the_original(self):
        self.run_script("install")
        report = self.run_script("uninstall")
        self.assertTrue(report["ok"], report)
        self.assertEqual(self.config.read_text(), self.original)
        self.assertFalse((self.root / "usr/share/axiom-greeter").exists())
        self.assertFalse((self.root / "var/lib/axiom-greeter").exists())
        self.assertFalse((self.config.parent / "config.toml.axiom-original").exists())

    def test_reinstall_after_uninstall_restores_the_config_of_then(self):
        self.run_script("install")
        self.run_script("uninstall")
        changed = self.original.replace("vt = 1", "vt = 2")
        self.config.write_text(changed)
        self.run_script("install")
        self.run_script("uninstall")
        self.assertEqual(self.config.read_text(), changed)

    def test_refusals(self):
        (self.root / "usr/bin/agreety").unlink()
        self.assertFalse(self.run_script("check")["agreety"])
        self.assertIn("agreety", self.run_script("install", ok=False)["error"])
        self.config.unlink()
        self.assertIn("greetd isn't installed", self.run_script("install", ok=False)["error"])
        self.assertIn("usage", self.run_script("bogus", ok=False)["error"])

    def test_refuses_unknown_source_and_channel(self):
        self.assertIn("unknown source", self.run_script("install", ok=False, source="svn")["error"])
        self.assertIn("unknown channel", self.run_script("install", ok=False, channel="beta")["error"])


if __name__ == "__main__":
    unittest.main()
