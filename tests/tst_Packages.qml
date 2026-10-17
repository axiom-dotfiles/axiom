import QtQuick
import QtTest
import qs.components.methods

TestCase {
  name: "Packages"

  function test_distroFamily_data() {
    return [
      {
        "tag": "arch",
        "text": 'NAME="Arch Linux"\nID=arch\nBUILD_ID=rolling',
        "want": "arch"
      },
      {
        "tag": "cachyos",
        "text": 'NAME="CachyOS Linux"\nID="cachyos"\nID_LIKE="arch"',
        "want": "arch"
      },
      {
        "tag": "manjaro",
        "text": "ID=manjaro\nID_LIKE=arch",
        "want": "arch"
      },
      {
        "tag": "fedora",
        "text": 'NAME="Fedora Linux"\nVERSION_ID=44\nID=fedora',
        "want": "fedora"
      },
      {
        "tag": "nobara",
        "text": 'ID=nobara\nID_LIKE="rhel centos fedora"',
        "want": "fedora"
      },
      {
        "tag": "ubuntu",
        "text": "ID=ubuntu\nID_LIKE=debian",
        "want": ""
      },
      {
        "tag": "empty",
        "text": null,
        "want": ""
      }
    ];
  }

  function test_distroFamily(data) {
    compare(Packages.distroFamily(data.text), data.want);
  }

  // Each key names every distribution, so a new one can't be half added
  function test_everyKeyNamesEveryDistro() {
    for (const key of Object.keys(Packages.packages))
      for (const distro of Object.keys(Packages.distros))
        verify(Packages.packages[key][distro] !== undefined, `${key} has no ${distro} entry`);
  }

  function test_packageFor() {
    compare(Packages.packageFor("arch", "qalc"), {
      "name": "libqalculate"
    });
    compare(Packages.packageFor("fedora", "qalc"), {
      "name": "qalculate"
    });
    compare(Packages.packageFor("fedora", "hypridle"), {
      "name": "hypridle",
      "repo": "nett00n/hyprland"
    });
    compare(Packages.packageFor("fedora", "checkupdates"), null, "Arch only");
    compare(Packages.packageFor("arch", "foot"), {
      "name": "foot"
    }, "an unlisted command: its own name");
    compare(Packages.packageFor("", "qalc"), null, "unknown distribution");
  }

  function test_applies() {
    verify(Packages.applies("arch", "checkupdates"));
    verify(!Packages.applies("fedora", "checkupdates"));
    verify(Packages.applies("", "checkupdates"), "unknown distribution: shown");
  }

  function test_installLines_arch() {
    compare(Packages.installLines("arch", ["iconFont", "qalc", "wl-copy", "qalc"]), ["sudo pacman -S --needed ttf-material-symbols-variable libqalculate wl-clipboard"]);
    compare(Packages.installLines("arch", []), []);
  }

  function test_installLines_fedora() {
    const lines = Packages.installLines("fedora", ["hypridle", "qalc", "satty", "checkupdates", "iconFont"]);
    compare(lines.length, 3);
    compare(lines[0], "sudo dnf copr enable -y nett00n/hyprland", "the COPR first, once");
    compare(lines[1], "sudo dnf install hypridle qalculate satty", "checkupdates dropped");
    verify(lines[2].startsWith("mkdir -p ~/.local/share/fonts && curl -fLo ~/.local/share/fonts/MaterialSymbolsRounded.ttf '"), lines[2]);
    verify(lines[2].endsWith("' && fc-cache -f"), lines[2]);
    compare(Packages.installLines("fedora", ["qalc"]), ["sudo dnf install qalculate"], "no COPR unless needed");
    compare(Packages.installLines("fedora", ["checkupdates"]), [], "nothing to install");
  }

  function test_unknownDistro() {
    compare(Packages.installLines("", ["qalc"]), []);
    compare(Packages.installCommand("", "qalc"), "");
  }

  function test_installCommand() {
    compare(Packages.installCommand("arch", "hypridle"), "sudo pacman -S --needed hypridle");
    compare(Packages.installCommand("fedora", "hyprsunset"), "sudo dnf copr enable -y nett00n/hyprland && sudo dnf install hyprsunset");
    compare(Packages.installCommand("arch", ["greetd", "agreety"]), "sudo pacman -S --needed greetd greetd-agreety");
    compare(Packages.installCommand("fedora", ["greetd", "agreety"]), "sudo dnf install greetd", "agreety ships in greetd");
  }

  // Every distribution checks for updates, each with its own format
  function test_updates() {
    for (const distro of Object.keys(Packages.distros)) {
      const updates = Packages.updates(distro);
      verify(updates !== null, distro);
      verify(updates.check.length > 0 && updates.upgrade !== "" && updates.found.length > 0, distro);
      compare(Packages.parseUpdates(updates.format, ""), [], distro + ": no output, no updates");
    }
    compare(Packages.updates(""), null, "unknown distribution");
    verify(Packages.updates("arch").aur);
    verify(!Packages.updates("fedora").aur);
  }

  function test_parseUpdates_pacman() {
    compare(Packages.parseUpdates("pacman", "linux 6.9.1.arch1-1 -> 6.9.2.arch1-1\nnot an update line\n  mesa 1:24.1-1 -> 1:24.2-1  \n"), [
      {
        "name": "linux",
        "from": "6.9.1.arch1-1",
        "to": "6.9.2.arch1-1"
      },
      {
        "name": "mesa",
        "from": "1:24.1-1",
        "to": "1:24.2-1"
      }
    ]);
  }

  // dnf5's `check-update --quiet`, as Fedora 44 prints it (plus dnf4's
  // obsoletes block, whose installed rows are skipped)
  function test_parseUpdates_dnf() {
    const text = "Upgrades\n" + "ca-certificates.noarch             2026.2.90_v9.0.317-1.fc44 updates\n" + "elfutils-default-yama-scope.noarch 0.196-1.fc44              updates\n" + "glib2.x86_64                       2.88.4-1.fc44             updates\n" + "Obsoleting packages\n" + "grub2-tools.x86_64                 1:2.12-30.fc44            updates\n" + "    grub2-tools-efi.x86_64         1:2.12-28.fc44            @updates\n";
    compare(Packages.parseUpdates("dnf", text), [
      {
        "name": "ca-certificates",
        "from": "",
        "to": "2026.2.90_v9.0.317-1.fc44"
      },
      {
        "name": "elfutils-default-yama-scope",
        "from": "",
        "to": "0.196-1.fc44"
      },
      {
        "name": "glib2",
        "from": "",
        "to": "2.88.4-1.fc44"
      },
      {
        "name": "grub2-tools",
        "from": "",
        "to": "1:2.12-30.fc44"
      }
    ]);
    compare(Packages.parseUpdates("unknown", "a 1 -> 2"), []);
  }
}
