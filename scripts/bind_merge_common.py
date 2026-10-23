"""What every compositor's bind merge (merge_*_binds.py, the managed
takeover moving a user's binds into axiom) shares: axiom's actions as
BindActions.qml has them, and the commands that are one of them.

Not a script of its own: the merge scripts import it.

  ipc_action(command)     the axiom action a command calling axiom's IPC is
  media_action(command)   the axiom action a volume, brightness or media
                          command is (wpctl, pactl, brightnessctl, playerctl)
  REPEATING               the actions axiom repeats while held by default
  in_git(path)            whether a file is in a git repository
"""
import re
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
# What a call names, for actions that open and close (BindActions.calls)
CALLS = {"toggle": "toggle", "open": "open", "show": "open", "enable": "open",
         "close": "close", "hide": "close", "disable": "close"}


def _bind_actions():
    return (ROOT / "components/methods/BindActions.qml").read_text()


def ipc_actions():
    """BindActions.ipcActions as [(action, regex)]: each IPC call, its
    {call} and {0} as groups."""
    text = _bind_actions()
    table = text[text.index("ipcActions:"):text.index("compositorActions:")]
    actions = []
    for name, call in re.findall(r'"(\w+)": \["([^"]+)"', table):
        pattern = re.escape(call).replace(re.escape("{call}"), r"(?P<call>\w+)").replace(re.escape("{0}"), r"(?P<arg>\S+)")
        actions.append((name, re.compile(pattern + "$")))
    return actions


IPC = ipc_actions()


def repeating_actions():
    """The actions axiom repeats while held by default (BindActions.actionFlags)."""
    text = _bind_actions()
    table = text[text.index("actionFlags:"):text.index("flagNames:")]
    return {name for name, flags in re.findall(r'"(\w+)": \[([^\]]*)\]', table) if '"repeating"' in flags}


REPEATING = repeating_actions()
# The axiom binary, by name or path, maybe quoted (Paths.shellCommand)
AXIOM = r"""['"]?(?:\S*/)?axiom['"]?"""


def unquote(text):
    text = text.strip()
    if len(text) >= 2 and text[0] == text[-1] and text[0] in "\"'":
        return text[1:-1]
    return text


def ipc_action(command):
    """The axiom action a command calling axiom's IPC is ({ action, call,
    argument }), or None."""
    if re.fullmatch(AXIOM + r" +restart", command):
        return {"action": "restartShell"}
    if re.fullmatch(AXIOM + r" +lock", command):
        call = "lockscreen lock"
    else:
        match = re.fullmatch(AXIOM + r" +ipc +(.+)", command)
        if not match:
            return None
        call = match.group(1).strip()
    for name, pattern in IPC:
        found = pattern.match(call)
        if found:
            entry = {"action": name}
            groups = found.groupdict()
            if groups.get("call"):
                entry["call"] = CALLS.get(groups["call"], "toggle")
            if groups.get("arg"):
                entry["argument"] = unquote(groups["arg"])
            return entry
    return None


def media_action(command):
    """The axiom action a volume, brightness or media command is, or None:
    the commands the compositors' example configs bind media keys to."""
    words = command.split()
    if not words:
        return None
    tool, rest = words[0], " ".join(words[1:])
    if tool == "wpctl":
        limit = r"( -l [0-9.]+)?"
        if re.fullmatch(rf"set-volume{limit} @DEFAULT_AUDIO_SINK@ [0-9.]+%?\+{limit}", rest):
            return "volumeUp"
        if re.fullmatch(rf"set-volume{limit} @DEFAULT_AUDIO_SINK@ [0-9.]+%?-{limit}", rest):
            return "volumeDown"
        if rest == "set-mute @DEFAULT_AUDIO_SINK@ toggle":
            return "toggleMute"
        if rest == "set-mute @DEFAULT_AUDIO_SOURCE@ toggle":
            return "toggleMicMute"
    if tool == "pactl":
        if re.fullmatch(r"set-sink-volume @DEFAULT_SINK@ \+[0-9]+%", rest):
            return "volumeUp"
        if re.fullmatch(r"set-sink-volume @DEFAULT_SINK@ -[0-9]+%", rest):
            return "volumeDown"
        if rest == "set-sink-mute @DEFAULT_SINK@ toggle":
            return "toggleMute"
        if rest == "set-source-mute @DEFAULT_SOURCE@ toggle":
            return "toggleMicMute"
    if tool == "brightnessctl":
        if re.fullmatch(r"(-\S+ )*set (\+[0-9]+%|[0-9]+%\+)", rest):
            return "brightnessUp"
        if re.fullmatch(r"(-\S+ )*set [0-9]+%-", rest):
            return "brightnessDown"
    if tool == "playerctl":
        media = {"play-pause": "mediaPlayPause", "next": "mediaNext", "previous": "mediaPrevious", "stop": "mediaStop"}
        if rest in media:
            return media[rest]
    return None


def in_git(path):
    return subprocess.run(["git", "-C", str(Path(path).parent), "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).returncode == 0
