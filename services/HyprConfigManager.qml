pragma Singleton
import QtQuick

import Quickshell.Io

import qs.components.methods
import qs.config

/* HyprConfigManager handles reading Hyprland keybindings and configurations */
QtObject {
  id: root

  readonly property var keybindings: root._hyprctlProcess.running ? {} : root.readKeybindings()
  readonly property string mod: "SUPER"
  readonly property string mod2: "ALT"
  readonly property var hyprDir: Config.homeDirectory + ".config/hypr/"

  property var _hyprBindCache: ({})

  property Process _hyprctlProcess: Process {
    running: true
    command: ["hyprctl", "binds", "-j"]
    
    stdout: StdioCollector {
      id: bindsCollector
      
      onStreamFinished: {
        const hyprBindData = JSON.parse(bindsCollector.text);
        root._hyprBindCache = {};
        
        for (let i = 0; i < hyprBindData.length; i++) {
          const bindEntry = hyprBindData[i];
          const key = bindEntry.key;
          const action = `${bindEntry.dispatcher}, ${bindEntry.arg}`;
          
          if (!root._hyprBindCache[action]) {
            root._hyprBindCache[action] = [];
          }
          root._hyprBindCache[action].push(key);
        }
      }
    }
  }

  function readKeybindings() {
    const filepath = hyprDir + "hyprland/core/keybinds.conf";
    const content = _getFileContent(filepath);
    
    if (!content) {
      console.error("Could not read Hyprland config file:", filepath);
      return [];
    }

    const keybindings = {};
    let currentSection = null;
    const seenBindings = {};

    const lines = content.split("\n");
    
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim();
      
      if (line.includes("{{") && line.includes("}}")) {
        const match = line.match(/{{([^}]+)}}/);
        if (match) {
          currentSection = match[1].trim();
          if (!keybindings[currentSection]) {
            keybindings[currentSection] = [];
          }
        }
        continue;
      }
      
      if (currentSection === null || !line.startsWith("bind")) {
        continue;
      }
      
      const equalParts = line.split("=");
      if (equalParts.length < 2) continue;
      
      const bindDef = equalParts[1].trim();
      const parts = bindDef.split(",").map(p => p.trim());
      
      if (parts.length < 3) continue;
      
      let mod = parts[0];
      const bind = parts[1];
      let action = parts.slice(2).join(", ");
      
      // Clean up action
      if (action.includes("$scripts/")) {
        action = action.replace("$scripts/", "");
      }
      
      // Resolve mod variables
      mod = _resolveMod(mod);
      
      // Check cache and add bindings
      if (_hyprBindCache[action]) {
        _processCachedBindings(keybindings, currentSection, mod, bind, action, seenBindings);
      } else {
        _addBinding(keybindings, currentSection, mod, bind, action, seenBindings);
      }
    }

    return keybindings;
  }

  function _resolveMod(mod) {
    if (mod.includes("$mod2")) {
      mod = mod.replace("$mod2", root.mod2).trim();
    }
    if (mod.includes("$mod")) {
      mod = mod.replace("$mod", root.mod).trim();
    }
    return mod;
  }

  function _processCachedBindings(keybindings, section, mod, configBind, action, seenBindings) {
    const cachedBinds = _hyprBindCache[action];
    const bindMatches = cachedBinds.some(cachedBind => configBind.toString() === cachedBind.toString());
    
    if (!bindMatches) {
      console.log("Found cached binds for action:", action);
      console.log("Original bind:", configBind);
      console.log("Cached binds:", JSON.stringify(cachedBinds));
      
      // Add entries for cached binds that differ from config
      for (let i = 0; i < cachedBinds.length; i++) {
        _addBinding(keybindings, section, mod, cachedBinds[i], action, seenBindings);
      }
    } else {
      _addBinding(keybindings, section, mod, configBind, action, seenBindings);
    }
  }

  function _addBinding(keybindings, section, mod, bind, action, seenBindings) {
    const bindKey = `${mod}+${bind}:${action}`;
    
    if (!seenBindings[bindKey]) {
      keybindings[section].push({ mod, bind, action });
      seenBindings[bindKey] = true;
    } else {
      console.log("Skipping duplicate bind:", mod, "+", bind, "->", action);
    }
  }

  function _getFileContent(filepath) {
    return Utils.getFileContent(Qt.resolvedUrl(filepath));
  }
}
