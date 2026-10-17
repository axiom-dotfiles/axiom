pragma Singleton
import QtQuick

// Which distribution this is (from its os-release) and what installs a
// command there: each command's package per distribution, and the shell
// lines that install a set of them, for the onboarder's hints. Adding a
// distribution is one column in `packages`, one entry in `distros`, and its
// test rows. No file access, processes or services.
QtObject {
  id: root

  // How each distribution installs: `install` is followed by the package
  // names, `repo` by a third-party repository to enable first
  readonly property var distros: ({
      "arch": {
        "install": "sudo pacman -S --needed"
      },
      "fedora": {
        "install": "sudo dnf install",
        "repo": "sudo dnf copr enable -y"
      }
    })

  // The Material Symbols Rounded variable font, for distributions without a
  // package of it
  readonly property string iconFontUrl: "https://github.com/google/material-design-icons/raw/master/variablefont/MaterialSymbolsRounded%5BFILL,GRAD,opsz,wght%5D.ttf"

  // Hyprland and its tools left Fedora's own repositories; this COPR builds
  // them (and quickshell) for every current release
  readonly property string _hyprCopr: "nett00n/hyprland"

  // { key: { distro: package } }, a key being a command (or "iconFont").
  // A package is a name, { name, repo } (from a repository enabled first),
  // { file, to } (a download), or null: nothing to install there (the
  // feature doesn't apply). Every key names every distribution.
  readonly property var packages: ({
      "iconFont": {
        "arch": "ttf-material-symbols-variable",
        "fedora": {
          "file": root.iconFontUrl,
          "to": "~/.local/share/fonts/MaterialSymbolsRounded.ttf"
        }
      },
      "qalc": {
        "arch": "libqalculate",
        "fedora": "qalculate"
      },
      "brightnessctl": {
        "arch": "brightnessctl",
        "fedora": "brightnessctl"
      },
      "ddcutil": {
        "arch": "ddcutil",
        "fedora": "ddcutil"
      },
      "wl-copy": {
        "arch": "wl-clipboard",
        "fedora": "wl-clipboard"
      },
      "jq": {
        "arch": "jq",
        "fedora": "jq"
      },
      "checkupdates": {
        "arch": "pacman-contrib",
        "fedora": null
      },
      "secret-tool": {
        "arch": "libsecret",
        "fedora": "libsecret"
      },
      "gio": {
        "arch": "glib2",
        "fedora": "glib2"
      },
      "python3": {
        "arch": "python",
        "fedora": "python3"
      },
      "notify-send": {
        "arch": "libnotify",
        "fedora": "libnotify"
      },
      "hypridle": {
        "arch": "hypridle",
        "fedora": {
          "name": "hypridle",
          "repo": root._hyprCopr
        }
      },
      "hyprlock": {
        "arch": "hyprlock",
        "fedora": {
          "name": "hyprlock",
          "repo": root._hyprCopr
        }
      },
      "hyprsunset": {
        "arch": "hyprsunset",
        "fedora": {
          "name": "hyprsunset",
          "repo": root._hyprCopr
        }
      },
      "wlsunset": {
        "arch": "wlsunset",
        "fedora": "wlsunset"
      },
      "cliphist": {
        "arch": "cliphist",
        "fedora": "cliphist"
      },
      "wtype": {
        "arch": "wtype",
        "fedora": "wtype"
      },
      "wf-recorder": {
        "arch": "wf-recorder",
        "fedora": "wf-recorder"
      },
      "satty": {
        "arch": "satty",
        "fedora": {
          "name": "satty",
          "repo": root._hyprCopr
        }
      },
      "pactl": {
        "arch": "libpulse",
        "fedora": "pulseaudio-utils"
      },
      "powerprofilesctl": {
        "arch": "power-profiles-daemon",
        "fedora": "power-profiles-daemon"
      }
    })

  // The distribution family an os-release file names: its ID, else the
  // first of its ID_LIKE we know ("arch" for CachyOS or Manjaro, "fedora"
  // for Nobara), else ""
  function distroFamily(osRelease) {
    const fields = String(osRelease ?? "").split("\n").reduce((all, line) => {
      const match = line.trim().match(/^([A-Z_]+)=(.*)$/);
      if (match)
        all[match[1]] = match[2].trim().replace(/^(["'])(.*)\1$/, "$2");
      return all;
    }, {});
    const ids = [fields.ID ?? ""].concat((fields.ID_LIKE ?? "").split(/\s+/)).map(id => id.toLowerCase());
    return ids.find(id => id !== "" && root.distros[id] !== undefined) ?? "";
  }

  // What installs `key` on `distro`, as { name, repo } or { file, to };
  // null when nothing does or the distribution is unknown
  function packageFor(distro, key) {
    if (root.distros[distro] === undefined)
      return null;
    const entry = root.packages[key]?.[distro];
    if (entry === undefined)
      return {
        "name": key
      };
    if (entry === null)
      return null;
    return typeof entry === "string" ? {
      "name": entry
    } : entry;
  }

  // Whether `key` means anything on `distro` (an unknown one: yes)
  function applies(distro, key) {
    return root.distros[distro] === undefined || root.packageFor(distro, key) !== null;
  }

  // The shell lines that install `keys` on `distro`, in order: repositories
  // to enable, one install of every package, then downloads. [] for an
  // unknown distribution or nothing to install
  function installLines(distro, keys) {
    const how = root.distros[distro];
    if (how === undefined)
      return [];
    const unique = list => list.filter((item, i) => list.indexOf(item) === i);
    const found = unique(keys ?? []).map(key => root.packageFor(distro, key)).filter(entry => entry !== null);
    const lines = how.repo === undefined ? [] : unique(found.filter(entry => entry.repo).map(entry => entry.repo)).map(repo => `${how.repo} ${repo}`);
    const names = unique(found.filter(entry => entry.name).map(entry => entry.name));
    if (names.length > 0)
      lines.push(`${how.install} ${names.join(" ")}`);
    for (const entry of found.filter(entry => entry.file)) {
      const dir = entry.to.slice(0, entry.to.lastIndexOf("/"));
      lines.push(`mkdir -p ${dir} && curl -fLo ${entry.to} '${entry.file}' && fc-cache -f`);
    }
    return lines;
  }

  // One line that installs `key` ("" when nothing does)
  function installCommand(distro, key) {
    return root.installLines(distro, [key]).join(" && ");
  }
}
