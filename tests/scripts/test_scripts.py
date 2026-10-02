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
    plain config dir and never touches a symlinked or git-tracked one
  - generate_theme.py turns an image into a valid dark/light pair (skipped
    when the venv can't be set up)

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
    "vscode": "json", "qt": "ini", "foot": "ini", "gtk": "css", "vesktop": "css", "ncspot": "toml", "firefox": "css",
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

    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.env = scratch_env(self.tmp)
        self.hypr = self.tmp / "hypr"
        self.hypr.mkdir()

    def tearDown(self):
        shutil.rmtree(self.tmp)

    def claim(self, action, directory=None):
        result = subprocess.run([str(SCRIPTS / "claim_hyprland.sh"), action, f"{directory or self.hypr}/",
                                 self.HEADER], env=self.env, capture_output=True, text=True, timeout=30)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def listing(self, directory=None):
        return sorted(str(p.relative_to(directory or self.hypr)) for p in (directory or self.hypr).rglob("*"))

    def test_new(self):
        self.assertEqual(self.claim("check"), "new")
        self.assertEqual(self.listing(), [])
        self.assertEqual(self.claim("claim"), "adopted")
        self.assertEqual(self.listing(), ["user"])

    def test_adopt_moves_the_old_config_to_user(self):
        (self.hypr / "hyprland.lua").write_text("-- mine\n")
        self.assertEqual(self.claim("check"), "adopt")
        self.assertEqual(self.listing(), ["hyprland.lua"])
        self.assertEqual(self.claim("claim"), "adopted")
        self.assertEqual((self.hypr / "user" / "00-previous.lua").read_text(), "-- mine\n")
        self.assertFalse((self.hypr / "hyprland.lua").exists())
        backups = list(self.hypr.glob("hyprland.lua.axiom-backup-*"))
        self.assertEqual(len(backups), 1)
        self.assertEqual(backups[0].read_text(), "-- mine\n")

    def test_stock_example_is_replaced_not_adopted(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\nhl.bind(\"SUPER + M\", hl.dsp.exit())\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        # Whitespace and blank lines don't make it the user's own
        (self.hypr / "hyprland.lua").write_text("-- example  \n\nhl.bind(\"SUPER + M\", hl.dsp.exit())\n")
        self.assertEqual(self.claim("check"), "stock")
        self.assertEqual(self.claim("claim"), "replaced")
        self.assertEqual(self.listing(), [str(p.relative_to(self.hypr)) for p in self.hypr.glob("*.axiom-backup-*")]
                         + ["user"])
        self.assertFalse((self.hypr / "hyprland.lua").exists())
        self.assertEqual(list((self.hypr / "user").iterdir()), [])

    def test_example_with_axiom_autostart_is_stock(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        (self.hypr / "hyprland.lua").write_text(
            "-- example\n" + 'hl.on("hyprland.start", function() hl.exec_cmd("qs -c axiom") end) -- axiom\n')
        self.assertEqual(self.claim("check"), "stock")
        self.assertEqual(self.claim("claim"), "replaced")

    def test_edited_example_is_adopted(self):
        example = self.tmp / "example.lua"
        example.write_text("-- example\n")
        self.env["AXIOM_HYPR_EXAMPLE"] = str(example)
        (self.hypr / "hyprland.lua").write_text("-- example\n-- mine\n")
        self.assertEqual(self.claim("check"), "adopt")
        self.assertEqual(self.claim("claim"), "adopted")

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


if __name__ == "__main__":
    unittest.main()
