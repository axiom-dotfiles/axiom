pragma Singleton
import QtQuick

import Quickshell.Io

import qs.components.methods
import qs.config

QtObject {
  id: hyprConfigManager

  // readonly property var keybindModel:
  readonly property var keybindings: readKeybindings()
  // readonly property var keybindModel: buildDisplayModel()
  readonly property string mod: "SUPER"
  readonly property string mod2: "ALT"
  readonly property var hyprDir: Config.homeDirectory + ".config/hypr/"

  // function translateMod(mod) {
  //   console.log("Translating mod:", mod);
  //   if (mod === "mod1") return hyprConfigManager.mod;
  //   if (mod === "mod2") return hyprConfigManager.mod2;
  // }

  function readKeybindings() {
    var filepath = hyprDir + "hyprland/core/keybinds.conf";
    var content = _getFileContent(filepath);
    if (!content) {
        console.error("Could not read Hyprland config file:", filepath);
        return [];
    }

    var keybindings = {};
    var currentSection = null;

    var lines = content.split("\n");
    for (var i = 0; i < lines.length; i++) {
        var line = lines[i].trim();
        if (line.includes("{{") && line.includes("}}")) {
            const extractedText = line.match(/{{([^}]+)}}/)[1];
            currentSection = extractedText.trim();
            if (!keybindings[currentSection]) {
                keybindings[currentSection] = [];
            }
        }
        if (currentSection === null) continue;
        if (line.startsWith("bind")) {
            var equalParts = line.split("=");
            if (equalParts.length < 2) continue;
            var bindDef = equalParts[1].trim();
            var parts = bindDef.split(",").map(function (p) { return p.trim(); });

            if (parts.length >= 3) {
                var mod = parts[0];  // e.g., "$mod SHIFT"
                var bind = parts[1]; // e.g., "h"

                var action = parts.slice(2).join(", ");
                if (action.includes("$scripts/")) {
                    action = action.replace("$scripts/", "");
                }

                if (mod.includes("$mod2")) {
                    mod = mod.replace("$mod2", hyprConfigManager.mod2).trim();
                }
                if (mod.includes("$mod")) {
                    mod = mod.replace("$mod", hyprConfigManager.mod).trim();
                }

                keybindings[currentSection].push({
                    mod: mod,
                    bind: bind,
                    action: action
                });
            }
        }
    }

    return keybindings;
}

  function _getFileContent(filepath) {
    try {
      // WAY faster than using FileView for reads for some reason
      var xhr = new XMLHttpRequest();
      xhr.open("GET", Qt.resolvedUrl(filepath), false);
      xhr.send();
      if (xhr.status === 200 || xhr.status === 0) {
        return xhr.responseText;
      }
    } catch (e) {
      console.error("Could not read file:", filepath, e);
    }
    return null;
  }
}
