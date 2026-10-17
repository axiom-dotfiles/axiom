#!/usr/bin/env python3
"""Tests for .claude/hooks/guard.py, the PreToolUse guard enforcing
AGENTS.md › "Never, while testing". Run: python3 tests/scripts/test_guard.py"""
import importlib.util
import json
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

REPO = Path(__file__).resolve().parent.parent.parent
spec = importlib.util.spec_from_file_location("guard", REPO / ".claude/hooks/guard.py")
guard = importlib.util.module_from_spec(spec)
spec.loader.exec_module(guard)

HOME = str(guard.HOME)


def denied(command, cwd=str(REPO)):
    try:
        guard.check({"tool_name": "Bash", "tool_input": {"command": command}, "cwd": cwd})
    except guard.Denied:
        return True
    return False


class Bash(unittest.TestCase):
    def blocks(self, *commands):
        for command in commands:
            self.assertTrue(denied(command), command)

    def allows(self, *commands):
        for command in commands:
            self.assertFalse(denied(command), command)

    def test_ordinary_commands_pass(self):
        self.allows("scripts/dev/verify.sh", "git status && git diff HEAD", "qs -c axiom ipc call overlay toggle",
                    "scripts/log.sh -g lock", "grep -rn 'lockscreen lock' docs", "echo 'qs kill'", "qs log -f")

    def test_locking(self):
        self.blocks("qs -c axiom ipc call lockscreen lock", "qs ipc call lockscreen lock", "loginctl lock-session",
                    "sleep 1 && hyprlock", "bash -c 'qs -c axiom ipc call lockscreen lock'")

    def test_cursor(self):
        self.blocks("ydotool mousemove 10 10", "hyprctl dispatch movecursor 10 10", "wlrctl pointer move 5 5",
                    "hyprctl eval 'hl.dsp.cursor.move(1, 1)'")

    def test_shell_lifecycle(self):
        self.blocks("qs kill", "qs -c axiom kill", "qs -c axiom", "qs -c axiom -d", "quickshell -p shell.qml &")
        self.allows('AXIOM_GREETER=1 AXIOM_GREETER_WINDOWED=1 AXIOM_GREETER_DIR=/tmp/g qs -p "$PWD/greeter.qml"',
                    'qs kill -p "$PWD/greeter.qml"', "qs kill -i abc123", "qs list")

    def test_ipc_takeovers(self):
        self.blocks("qs -c axiom ipc call monitors keep", "qs -c axiom ipc call selfUpdate update")
        self.allows("qs -c axiom ipc call monitors revert", "qs -c axiom ipc call onboarding goTo 2")

    def test_greetd_and_greeter(self):
        self.blocks("sudo systemctl restart greetd", "systemctl stop greetd.service", "pkill greetd",
                    "scripts/greeter/greeter_install.sh install . me")
        self.allows("systemctl status greetd", "scripts/greeter/greeter_install.sh check .",
                    "AXIOM_GREETER_ROOT=/tmp/x scripts/greeter/greeter_install.sh install . me",
                    'export AXIOM_GREETER_ROOT="$tmp"; scripts/greeter/greeter_install.sh uninstall . me')

    def test_claim_sway(self):
        self.blocks(f"scripts/claim_sway.sh claim {HOME}/.config/sway axiom", "scripts/claim_sway.sh release ~/.config/sway h f")
        self.allows("scripts/claim_sway.sh claim /tmp/scratch/sway axiom", "scripts/claim_sway.sh check ~/.config/sway axiom")

    def test_merge_binds(self):
        self.blocks("scripts/merge_sway_binds.py remove ~/.config/sway '[]'", f"python3 scripts/merge_hypr_binds.py remove {HOME}/.config/hypr '[]'")
        self.allows("scripts/merge_sway_binds.py extract ~/.config/sway", "scripts/merge_sway_binds.py remove /tmp/scratch/sway '[]'")

    def test_claim_niri(self):
        self.blocks(f"scripts/claim_niri.sh claim {HOME}/.config/niri axiom", "scripts/merge_niri_binds.py remove ~/.config/niri '[]'")
        self.allows("scripts/claim_niri.sh claim /tmp/scratch/niri axiom", "scripts/claim_niri.sh check ~/.config/niri axiom")

    def test_niri_session(self):
        with mock.patch.dict(os.environ, {"NIRI_SOCKET": "/run/user/1000/niri.wayland-1.100.sock"}):
            self.blocks("niri msg action quit", "niri msg action load-config-file --path /tmp/x.kdl",
                        "niri msg output DP-1 off", "niri msg -j action quit")
            self.allows("niri msg -j windows", "niri msg action focus-workspace 2",
                        "NIRI_SOCKET=/run/user/1000/niri.wayland-2.200.sock niri msg action quit",
                        "export NIRI_SOCKET=/run/user/1000/niri.wayland-2.200.sock; niri msg output winit scale 1")

    def test_claim_hyprland(self):
        self.blocks(f"scripts/claim_hyprland.sh claim {HOME}/.config/hypr axiom", "scripts/claim_hyprland.sh release ~/.config/hypr h f")
        self.allows("scripts/claim_hyprland.sh claim /tmp/scratch/hypr axiom", "scripts/claim_hyprland.sh check ~/.config/hypr axiom")

    def test_scripts_run_through_a_shell_and_variables(self):
        self.blocks("bash scripts/claim_sway.sh claim ~/.config/sway axiom", "sh scripts/claim_hyprland.sh claim ~/.config/hypr axiom",
                    "bash scripts/greeter/greeter_install.sh install . me")
        self.assertTrue(denied("scripts/claim_sway.sh claim $HOME/.config/sway axiom", cwd="/tmp"))
        self.assertTrue(denied("scripts/claim_sway.sh claim ${HOME}/.config/sway axiom", cwd="/tmp"))
        self.assertTrue(denied("export D=~/.config/hypr; scripts/merge_hypr_binds.py remove $D '[]'", cwd="/tmp"))
        self.blocks("bash -lc 'qs -c axiom kill'")
        self.allows("scripts/claim_sway.sh claim scratch/sway axiom", "bash scripts/claim_sway.sh claim /tmp/s axiom")

    def test_a_custom_xdg_config_home_is_live(self):
        with mock.patch.object(guard, "CONFIG_HOMES", guard.CONFIG_HOMES | {Path("/srv/conf")}):
            self.assertTrue(denied("scripts/claim_sway.sh claim /srv/conf/sway axiom"))

    def test_integration_hookup(self):
        self.blocks("python3 scripts/integration_hookup.py apply kitty", "scripts/integration_hookup.py apply kitty",
                    f"HOME={HOME} python3 scripts/integration_hookup.py apply kitty")
        self.allows("HOME=/tmp/h python3 scripts/integration_hookup.py apply kitty",
                    'XDG_CONFIG_HOME="$scratch" scripts/integration_hookup.py apply kitty',
                    "python3 scripts/integration_hookup.py status kitty")

    def test_self_update(self):
        self.blocks("scripts/self_update.sh apply v1.2", f"scripts/self_update.sh --channel main apply v1.2 {REPO}",
                    "scripts/self_update.sh apply v1.2 .")
        self.allows("scripts/self_update.sh check", "scripts/self_update.sh apply v1.2 /tmp/clone")

    def test_live_config_file(self):
        self.blocks(f"rm {guard.LIVE_CONFIG}", f"rm -rf {guard.LIVE_CONFIG.parent}", f"mv {guard.LIVE_CONFIG} /tmp/x",
                    "rm ~/.config/axiom/config.json" if not os.environ.get("XDG_CONFIG_HOME") else f"rm {guard.LIVE_CONFIG}",
                    "rm config/user/config.json", "rm -rf config/user", "mv config/user/config.json /tmp/x",
                    f"rm {REPO}/config/user/config.json", "git clean -fdx", "git clean -X -f")
        self.allows("rm /tmp/config.json", f"cp {guard.LIVE_CONFIG} /tmp/backup.json", "cp config/user/config.json /tmp/backup.json",
                    f"rm {guard.LIVE_CONFIG.parent}/saved/old.json", "git clean -fd", "mv /tmp/new.json /tmp/other.json")

    def test_qmlformat_inplace(self):
        self.blocks("qmlformat -i shell.qml", "/usr/lib/qt6/bin/qmlformat --inplace shell.qml")
        self.allows("/usr/lib/qt6/bin/qmlformat shell.qml")


class ConfigEdits(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.config = Path(self.dir.name) / "config.json"
        self.config.write_text(json.dumps({"Idle": {"enabled": False}, "Bar": {"x": 1}}, indent=2))
        self.patch = mock.patch.object(guard, "LIVE_CONFIG", self.config.resolve())
        self.patch.start()

    def tearDown(self):
        self.patch.stop()
        self.dir.cleanup()

    def edit(self, old, new):
        try:
            guard.check({"tool_name": "Edit", "tool_input": {"file_path": str(self.config), "old_string": old, "new_string": new}})
        except guard.Denied:
            return True
        return False

    def test_takeover_paths_come_from_the_schema(self):
        paths = guard.takeover_paths(json.loads(guard.SCHEMA.read_text()))
        self.assertIn(["Idle", "enabled"], paths)
        self.assertGreaterEqual(len(paths), 5)

    def test_takeover_change_refused(self):
        self.assertTrue(self.edit('"enabled": false', '"enabled": true'))

    def test_other_changes_pass(self):
        self.assertFalse(self.edit('"x": 1', '"x": 2'))

    def test_other_files_pass(self):
        guard.check({"tool_name": "Write", "tool_input": {"file_path": os.devnull, "content": "{}"}})


class Hook(unittest.TestCase):
    def test_deny_json(self):
        import subprocess
        out = subprocess.run(["python3", str(REPO / ".claude/hooks/guard.py")], capture_output=True, text=True,
                             input=json.dumps({"tool_name": "Bash", "tool_input": {"command": "qs kill"}}))
        decision = json.loads(out.stdout)["hookSpecificOutput"]
        self.assertEqual(decision["permissionDecision"], "deny")
        self.assertIn("AGENTS.md", decision["permissionDecisionReason"])
        allowed = subprocess.run(["python3", str(REPO / ".claude/hooks/guard.py")], capture_output=True, text=True,
                                 input=json.dumps({"tool_name": "Bash", "tool_input": {"command": "ls"}}))
        self.assertEqual(allowed.stdout, "")


if __name__ == "__main__":
    unittest.main()
