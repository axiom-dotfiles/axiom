pragma Singleton

import QtQuick
import "lib/ConfigLoader.js" as Loader

import qs.config
import qs.services

// Assuming 'Appearance' is a global singleton that provides the 'theme' property
// and the 'toggleDarkMode' signal. Adjust 'Appearance' to your actual signal source if it's different.

QtObject {
  id: root

  // This is the core reactive property. When Appearance.theme changes,
  // this property will automatically be re-evaluated, reloading the theme.
  property var themeData: Loader.loadTheme(Appearance.theme)

  // --- CRITICAL CHANGE ---
  // All 'readonly property' declarations have been changed to 'property'
  // to make them reactive. Now, when 'themeData' changes, all these
  // color properties will automatically update.

  // Base16 colors
  property color base00: themeData.colors.base00 ?? "#000000"
  property color base01: themeData.colors.base01 ?? "#111111"
  property color base02: themeData.colors.base02 ?? "#222222"
  property color base03: themeData.colors.base03 ?? "#333333"
  property color base04: themeData.colors.base04 ?? "#444444"
  property color base05: themeData.colors.base05 ?? "#555555"
  property color base06: themeData.colors.base06 ?? "#666666"
  property color base07: themeData.colors.base07 ?? "#777777"
  property color base08: themeData.colors.base08 ?? "#ff0000"
  property color base09: themeData.colors.base09 ?? "#ff8800"
  property color base0A: themeData.colors.base0A ?? "#ffff00"
  property color base0B: themeData.colors.base0B ?? "#00ff00"
  property color base0C: themeData.colors.base0C ?? "#00ffff"
  property color base0D: themeData.colors.base0D ?? "#0000ff"
  property color base0E: themeData.colors.base0E ?? "#ff00ff"
  property color base0F: themeData.colors.base0F ?? "#ff0088"

  // Semantic colors
  property color background: root[themeData.semantic.background] ?? base00
  property color backgroundAlt: root[themeData.semantic.backgroundAlt] ?? base01
  property color backgroundHighlight: root[themeData.semantic.backgroundHighlight] ?? base02
  property color foreground: root[themeData.semantic.foreground] ?? base05
  property color foregroundAlt: root[themeData.semantic.foregroundAlt] ?? base04
  property color foregroundHighlight: root[themeData.semantic.foregroundHighlight] ?? base06
  property color foregroundInactive: root[themeData.semantic.foregroundInactive] ?? base03
  property color border: root[themeData.semantic.border] ?? base03
  property color borderFocus: root[themeData.semantic.borderFocus] ?? base0D
  property color accent: root[themeData.semantic.accent] ?? base0D
  property color accentAlt: root[themeData.semantic.accentAlt] ?? base0E
  property color success: root[themeData.semantic.success] ?? base0B
  property color warning: root[themeData.semantic.warning] ?? base0A
  property color error: root[themeData.semantic.error] ?? base08
  property color info: root[themeData.semantic.info] ?? base0C
  property color red: root[themeData.semantic.red] ?? base08
  property color green: root[themeData.semantic.green] ?? base0B
  property color yellow: root[themeData.semantic.yellow] ?? base0A
  property color blue: root[themeData.semantic.blue] ?? base0D
  property color magenta: root[themeData.semantic.magenta] ?? base0E
  property color cyan: root[themeData.semantic.cyan] ?? base0C
  property color orange: root[themeData.semantic.orange] ?? base09
  property color grey: root[themeData.semantic.grey] ?? base03
  property color bg0: root[themeData.semantic.bg0] ?? base00
  property color bg1: root[themeData.semantic.bg1] ?? base01
  property color bg2: root[themeData.semantic.bg2] ?? base02
  property color bg3: root[themeData.semantic.bg3] ?? base03
  property color bg4: root[themeData.semantic.bg4] ?? base04
  property color bg5: root[themeData.semantic.bg5] ?? base05
  property color bg6: root[themeData.semantic.bg6] ?? base06

  property color userColor: root[themeData.semantic.green] ?? "#ff00ff"
  property color robotColor: root[themeData.semantic.yellow] ?? "#00ff00"

  property string name: root[themeData.name] ?? "Unknown"
  property string variant: root[themeData.variant] ?? "dark"
  property string paired: root[themeData.paired] ?? ""

  function reload() {
    root.themeData = Loader.loadTheme(Appearance.theme)
    console.log("Theme reloaded manually:", Appearance.theme)
  }

  Component.onCompleted: {
    console.log("Theme singleton initialized. Current theme:", Appearance.theme)
    ShellManager.toggleDarkMode.connect(function() {
      console.log("toggleDarkMode signal received.")

      if (Appearance.autoThemeSwitch && root.paired !== "") {
        console.log("Switching theme from '" + Appearance.theme + "' to '" + root.paired + "'")
        Appearance.theme = root.paired
      } else {
        if (!Appearance.autoThemeSwitch) {
            console.log("Auto theme switching is disabled.")
        }
        if (root.paired === "") {
            console.log("Current theme has no paired theme.")
        }
      }
    })
  }
}
