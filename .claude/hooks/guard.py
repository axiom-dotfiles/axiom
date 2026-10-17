#!/usr/bin/env python3
"""PreToolUse guard: refuses the tool calls AGENTS.md › "Never, while testing"
forbids, so they're enforced rather than only written down.

Claude Code runs it before every Bash, Edit and Write call (.claude/settings.json
› hooks) with the call as JSON on stdin; a refusal is printed as a `deny`
decision with the rule it breaks. The rules with an exception (scratch dirs,
the windowed greeter) live here; .claude/settings.json › permissions.deny
repeats the plain ones. Tests: tests/scripts/test_guard.py.

Bash commands are split into simple commands (on ; && || | & and newlines,
into `bash -c`/`sh -c` strings) and each is judged on its argv, with leading
VAR=value assignments (and `export VAR=…` earlier in the same command) as its
environment. Best effort: it stops mistakes, not an adversary.
"""
import json
import os
import re
import shlex
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent.parent
HOME = Path(os.path.expanduser("~")).resolve()
# The live config.json (DataDirs.xdg), and where an install from before the
# XDG folders kept it (still read until it's moved over, and on a rollback)
LIVE_CONFIG = Path(os.environ.get("XDG_CONFIG_HOME") or HOME / ".config").resolve() / "axiom/config.json"
LEGACY_CONFIG = REPO / "config/user/config.json"
SCHEMA = REPO / "config/json/config.schema.json"
SEPARATORS = {";", "&&", "||", "|", "&", "\n", "|&"}
WRAPPERS = {"sudo", "env", "nohup", "exec", "command", "time", "timeout", "setsid"}
SHELLS = {"bash", "sh", "zsh"}
QS = {"qs", "quickshell"}
QS_VALUE_OPTS = {"-c", "--config", "-p", "--path", "-m", "--manifest", "-i", "--id", "--pid", "--log-rules", "-n", "--newest"}
SAFE_QS = {"ipc", "log", "list", "msg"}


class Denied(Exception):
    pass


def deny(rule, why):
    raise Denied(f"Blocked by AGENTS.md › {rule}: {why}")


# --------------------------------------------------------------- parsing

def split_commands(command):
    """[(env, argv)] for each simple command in a shell command line."""
    try:
        lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=";&|")
        lexer.whitespace_split = True
        tokens = list(lexer)
    except ValueError:
        tokens = command.split()
    out, current, exported = [], [], {}
    for token in tokens + [";"]:
        if token in SEPARATORS or set(token) <= set(";&|"):
            if current:
                out.extend(simple(current, exported))
            current = []
        else:
            current.append(token)
    return out


ASSIGN = re.compile(r"^([A-Za-z_][A-Za-z0-9_]*)=(.*)$", re.S)


def simple(tokens, exported):
    env = dict(exported)
    i = 0
    while i < len(tokens) and ASSIGN.match(tokens[i]):
        name, value = ASSIGN.match(tokens[i]).groups()
        env[name] = value
        i += 1
    argv = tokens[i:]
    if not argv:
        exported.update(env)
        return []
    if argv[0] == "export":
        for token in argv[1:]:
            if ASSIGN.match(token):
                name, value = ASSIGN.match(token).groups()
                exported[name] = value
        return []
    # Wrappers: judge the command they run
    while argv and Path(argv[0]).name in WRAPPERS:
        argv = argv[1:]
        while argv and (argv[0].startswith("-") or ASSIGN.match(argv[0]) or re.fullmatch(r"\d+[smhd]?", argv[0])):
            if ASSIGN.match(argv[0]):
                name, value = ASSIGN.match(argv[0]).groups()
                env[name] = value
            argv = argv[1:]
    if not argv:
        return []
    command_flag = next((i for i, a in enumerate(argv[1:-1], 1) if re.fullmatch(r"-[a-z]*c[a-z]*", a)), None)
    if Path(argv[0]).name in SHELLS and command_flag is not None:
        inner = argv[command_flag + 1]
        return [(dict(env, **e), a) for e, a in split_commands(inner)]
    # A script run through a shell (`bash scripts/claim_sway.sh …`): judge the script
    if Path(argv[0]).name in SHELLS:
        rest = argv[1:]
        while rest and rest[0].startswith("-"):
            rest = rest[1:]
        if rest:
            return [(env, rest)]
    return [(env, argv)]


def resolve(path, cwd, env=None):
    path = os.path.expanduser(expand_vars(path, env or {}))
    return (Path(cwd) / path).resolve() if not os.path.isabs(path) else Path(path).resolve()


def expand_vars(value, env):
    """$VAR / ${VAR} from the command's environment, then this process's."""
    return re.sub(r"\$(?:\{(\w+)\}|(\w+))", lambda m: env.get(m[1] or m[2], os.environ.get(m[1] or m[2], m[0])), value)


# The live config folders: ~/.config and XDG_CONFIG_HOME
CONFIG_HOMES = {HOME / ".config", LIVE_CONFIG.parent.parent}


def live_config_path(path, cwd, env):
    """Whether `path` is a live config folder or inside one (or HOME itself),
    as written and with its links followed; a scratch dir inside the repo isn't."""
    expanded = os.path.expanduser(expand_vars(path, env))
    written = Path(os.path.normpath(expanded if os.path.isabs(expanded) else os.path.join(cwd, expanded)))
    for target in {written, resolve(path, cwd, env)}:
        if target == REPO or REPO in target.parents:
            continue
        if target == HOME or any(target == home or home in target.parents for home in CONFIG_HOMES):
            return True
    return False


def scratch(value):
    """Whether an env value (HOME, XDG_CONFIG_HOME, …) points away from the live system."""
    if not value:
        return False
    if "$" in value:
        return True  # a variable the agent made (mktemp): trust it
    real = resolve(value, "/")
    return real != HOME and real != HOME / ".config" and real != Path("/")


# ----------------------------------------------------------------- rules

def check_argv(env, argv, cwd):
    name = Path(argv[0]).name
    args = argv[1:]

    # Lock the built-in locker
    if name == "loginctl" and any(a.startswith("lock-session") for a in args):
        deny("Never, while testing", "don't lock the session; only the user can type the password. Test LockSurface in a hidden window.")
    if name == "hyprlock":
        deny("Never, while testing", "don't lock the screen; only the user can type the password.")

    # Simulate cursor movement
    if name in {"ydotool", "dotool", "dotoolc", "wlrctl"} or any("movecursor" in a or "cursor.move" in a for a in argv):
        deny("Never, while testing", "don't simulate cursor movement; check logs and reason through bindings, or ask the user to look.")

    # The shell itself, and its IPC
    if name in QS:
        check_qs(env, args)

    # Greetd
    if name in {"systemctl", "service", "pkill", "killall"} and any("greetd" in a for a in args):
        if name in {"pkill", "killall"} or any(a in {"restart", "stop", "start", "reload", "kill", "disable", "enable", "mask", "try-restart", "reload-or-restart"} for a in args):
            deny("Never, while testing", "don't restart or stop greetd: it ends the session.")

    # Greeter install / update / uninstall
    if name == "greeter_install.sh" and args and args[0] in {"install", "update", "uninstall"}:
        if not scratch(env.get("AXIOM_GREETER_ROOT", "")):
            deny("Never, while testing", "greeter_install.sh install/update/uninstall only with a scratch AXIOM_GREETER_ROOT=<dir>.")

    # A compositor claim (managed mode) on the live config: Hyprland's, sway's
    if re.fullmatch(r"claim_\w+\.sh", name) and len(args) >= 2 and args[0] in {"claim", "release"}:
        if live_config_path(args[1], cwd, env):
            deny("Never, while testing", f"{name} claim/release only on a scratch dir, never the live compositor config.")

    # Moving binds out of the live compositor config's files (managed mode's
    # bind merge): Hyprland's, sway's. Run directly or through python
    merge = argv if re.fullmatch(r"merge_\w+_binds\.py", name) else None
    if merge is None and name.startswith("python"):
        at = next((i for i, a in enumerate(args) if re.fullmatch(r"merge_\w+_binds\.py", Path(a).name)), None)
        merge = args[at:] if at is not None else None
    if merge and len(merge) >= 3 and merge[1] == "remove":
        if live_config_path(merge[2], cwd, env):
            deny("Never, while testing", f"{Path(merge[0]).name} remove only on a scratch dir, never the live compositor config.")

    # Ending, reconfiguring or swapping the config of the niri session
    # itself: only a nested niri (NIRI_SOCKET aimed at another one than the
    # session's own) may be told to
    if name == "niri" and args[:1] == ["msg"]:
        rest = [a for a in args[1:] if a not in {"-j", "--json"}]
        changes = rest[:1] == ["output"] or (rest[:1] == ["action"] and rest[1:2] in (["quit"], ["load-config-file"]))
        socket = env.get("NIRI_SOCKET", os.environ.get("NIRI_SOCKET", ""))
        if changes and (not socket or socket == os.environ.get("NIRI_SOCKET", "")):
            deny("Never, while testing", "niri msg output / action quit / load-config-file only on a nested niri (NIRI_SOCKET=<its socket>), never the live session.")

    # A theme integration's hookup on the real configs
    if name == "integration_hookup.py" or (name.startswith("python") and any(Path(a).name == "integration_hookup.py" for a in args)):
        rest = args[[Path(a).name for a in args].index("integration_hookup.py") + 1:] if name.startswith("python") else args
        if "apply" in rest and not (scratch(env.get("HOME", "")) or scratch(env.get("XDG_CONFIG_HOME", ""))):
            deny("Never, while testing", "integration_hookup.py apply only with a scratch HOME or XDG_CONFIG_HOME.")

    # Self-update on the live repo
    if name == "self_update.sh" and "apply" in args:
        rest = args[args.index("apply") + 1:]
        if len(rest) < 2 or resolve(rest[1], cwd) == REPO:
            deny("Never, while testing", "self_update.sh apply only on a scratch clone (give its dir), never the live repo.")

    # The real config.json
    if name in {"rm", "unlink", "trash", "trash-put", "shred", "mv"}:
        paths = [a for a in args if not a.startswith("-")]
        if name == "mv":
            paths = paths[:-1]  # the sources
        for a in paths:
            target = resolve(a, cwd)
            # The file, or a folder holding it up to its config folder (the repo for the old one)
            for config, top in ((LIVE_CONFIG, LIVE_CONFIG.parent), (LEGACY_CONFIG, REPO)):
                if target == config or target in config.parents and (target == top or top in target.parents):
                    deny("Never, while testing", f"don't delete or move the real config.json ({config}); use `ipc call onboarding goTo <n>`.")
    if name == "git" and args[:1] == ["clean"] and any(re.fullmatch(r"-[a-zA-Z]*[xX][a-zA-Z]*", a) for a in args[1:]):
        deny("Never, while testing", "git clean -x/-X deletes the gitignored config/user/ and config/state/ (an install's data before it moves to the XDG folders).")

    # qmlformat -i replaces the inode
    if name == "qmlformat" and any(a in {"-i", "--inplace"} for a in args):
        deny("Formatting", "qmlformat -i replaces the file's inode, so qs stops reloading it; verify.sh formats in place.")



def check_qs(env, args):
    i, sub, rest = 0, None, []
    while i < len(args):
        a = args[i]
        if a in QS_VALUE_OPTS:
            i += 2
            continue
        if a.startswith("-"):
            i += 1
            continue
        sub, rest = a, args[i + 1:]
        break
    options = args[:i]
    if sub == "ipc":
        call = [a for a in rest if not a.startswith("-")]
        if call[:1] == ["call"]:
            target, fn = (call[1:3] + ["", ""])[:2]
            if target == "lockscreen" and fn == "lock":
                deny("Never, while testing", "don't lock the built-in locker; only the user can type the password. Test LockSurface in a hidden window.")
            if target == "monitors" and fn == "keep":
                deny("Never, while testing", "don't Keep a monitor layout.")
            if target == "selfUpdate" and fn == "update":
                deny("Never, while testing", "don't apply a self-update to the live repo.")
        return
    if sub in SAFE_QS:
        return
    greeter = env.get("AXIOM_GREETER") == "1" and any(o.endswith("greeter.qml") for o in options)
    if sub == "kill":
        flags = options + rest
        if any(o in {"-i", "--id", "--pid"} for o in flags) or any(o.endswith("greeter.qml") for o in flags):
            return
        deny("Running / reloading", "the shell runs detached; never stop it from this session (`qs kill` only the greeter instance you started: `qs kill -p <…>/greeter.qml` or `-i <id>`).")
    if sub is None:
        if greeter:
            return
        deny("Running / reloading", "the shell runs detached; never start another from this session (the windowed greeter: AXIOM_GREETER=1 AXIOM_GREETER_WINDOWED=1 qs -p \"$PWD/greeter.qml\").")


# ---------------------------------------------------- Edit/Write config.json

def takeover_paths(schema):
    out = []

    def walk(node, path):
        if not isinstance(node, dict):
            return
        if node.get("x-takeover") is True:
            out.append(path)
        for key, child in (node.get("properties") or {}).items():
            walk(child, path + [key])

    walk(schema, [])
    return out


def value_at(config, path):
    for key in path:
        if not isinstance(config, dict) or key not in config:
            return None
        config = config[key]
    return config


def check_config_edit(tool, tool_input):
    path = tool_input.get("file_path", "")
    if not path or Path(path).resolve() not in {LIVE_CONFIG, LEGACY_CONFIG}:
        return
    try:
        before_text = Path(path).resolve().read_text()
    except OSError:
        return
    if tool == "Write":
        after_text = tool_input.get("content", "")
    else:
        old, new = tool_input.get("old_string", ""), tool_input.get("new_string", "")
        after_text = before_text.replace(old, new) if tool_input.get("replace_all") else before_text.replace(old, new, 1)
    try:
        before, after = json.loads(before_text), json.loads(after_text)
        schema = json.loads(SCHEMA.read_text())
    except (ValueError, OSError):
        return  # an invalid file never replaces the running config: nothing to guard
    for path in takeover_paths(schema):
        if value_at(before, path) != value_at(after, path):
            deny("Never, while testing", f"`{'.'.join(path)}` takes something over on this PC (x-takeover: compositor mode, locker, idle, polkit, greeter). Ask the user before changing it in the live config.")


# ------------------------------------------------------------------ main

def check(call):
    tool, tool_input = call.get("tool_name", ""), call.get("tool_input") or {}
    if tool == "Bash":
        for env, argv in split_commands(tool_input.get("command", "")):
            check_argv(env, argv, call.get("cwd") or str(REPO))
    elif tool in {"Edit", "Write"}:
        check_config_edit(tool, tool_input)


def main():
    try:
        call = json.load(sys.stdin)
    except ValueError:
        return 0
    try:
        check(call)
    except Denied as refusal:
        print(json.dumps({"hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": str(refusal),
        }}))
    return 0


if __name__ == "__main__":
    sys.exit(main())
