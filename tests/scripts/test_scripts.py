#!/usr/bin/env python3
"""Smoke tests for the scripts in scripts/, each run in a scratch $HOME.

  - every shipped theme is complete (config/themes/theme.schema.json's
    required keys, hex colors, semantic names that resolve, pairs that exist)
  - every theme_*.sh integration renders a dark and a light theme into a
    scratch dir with no warnings and no unfilled ${VAR}s. The apps they
    need (and pkill, which they signal running apps with) are stubbed
  - self_update.sh reports and applies updates on scratch git clones, and
    refuses the blocked cases
  - generate_theme.py turns an image into a valid dark/light pair (skipped
    when the venv can't be set up)

  python3 tests/scripts/test_scripts.py [-v] [TestCase[.test_name]]
"""
import json
import os
import re
import shutil
import stat
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent.parent
SCRIPTS = ROOT / "scripts"
THEMES = ROOT / "config" / "themes"
BASES = [f"base0{c}" for c in "0123456789ABCDEF"]
HEX = re.compile(r"^#[0-9a-fA-F]{6}$")
# envsubst leaves nothing behind, so a ${VAR} left over is a template typo
UNFILLED = re.compile(r"\$\{[A-Z0-9_]+\}")
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


class ThemeIntegrations(unittest.TestCase):
    THEMES = ["tokyo-night.json", "catppuccin-latte.json"]

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

    def test_every_integration_renders(self):
        scripts = sorted(SCRIPTS.glob("theme_*.sh"))
        self.assertTrue(scripts)
        for theme in self.THEMES:
            for script in scripts:
                key = script.stem.removeprefix("theme_")
                with self.subTest(script=script.name, theme=theme):
                    target = self.out / theme / key
                    if key == "hyprlock":
                        target = target / "hyprlock.conf"
                        args = [THEMES / theme, target, "Sans", "file:///tmp/wall.png", "1", "Hey you", "Password..."]
                    elif key in ("gtk", "vscode"):
                        args = [THEMES / theme, target]
                    else:
                        target = target / "axiom.out"
                        args = [THEMES / theme, target]
                    self.run_script(script, args)
                    self.assert_rendered(target)

    def test_hyprlock_keeps_its_own_variables(self):
        target = self.out / "hyprlock.conf"
        self.run_script(SCRIPTS / "theme_hyprlock.sh",
                        [THEMES / "tokyo-night.json", target, "Sans", "file:///w.png", "0", "Hi", "Pass"])
        text = target.read_text()
        self.assertIn("$TIME", text)
        self.assertIn("/w.png", text)
        self.assertNotIn("file://", text)


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
            result = subprocess.run([python, str(SCRIPTS / "generate_theme.py"), str(image), "--output_dir",
                                     str(out), "--backend", "colorthief"], env=env, capture_output=True,
                                    text=True, timeout=300)
            self.assertEqual(result.returncode, 0, result.stderr)
            files = sorted(out.glob("*.json"))
            self.assertEqual(len(files), 2, [f.name for f in files])
            themes = [json.loads(f.read_text()) for f in files]
            names = {t["name"] for t in themes} | {f.stem for f in files}
            self.assertEqual(sorted(t["variant"] for t in themes), ["dark", "light"])
            for f, theme in zip(files, themes):
                with self.subTest(theme=f.name):
                    self.assertEqual(theme_problems(theme, names), [])
        finally:
            shutil.rmtree(tmp)


if __name__ == "__main__":
    unittest.main()
