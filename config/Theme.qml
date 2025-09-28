pragma Singleton

import QtQuick
import "lib/ConfigLoader.js" as Loader

// Import the global configuration singleton
import qs.config // E.g., Appearance, Config

QtObject {
  id: root

  // This property reactively binds to the GLOBAL configuration setting.
  // When ThemeManager sets Config.theme, this 'themeData' property will
  // automatically be re-evaluated, updating all colors below.
  property var themeData: Loader.loadTheme(Appearance.theme)

  // --- Base16 colors ---
  readonly property color base00: themeData.colors.base00 ?? "#000000"
  readonly property color base01: themeData.colors.base01 ?? "#111111"
  readonly property color base02: themeData.colors.base02 ?? "#222222"
  readonly property color base03: themeData.colors.base03 ?? "#333333"
  readonly property color base04: themeData.colors.base04 ?? "#444444"
  readonly property color base05: themeData.colors.base05 ?? "#555555"
  readonly property color base06: themeData.colors.base06 ?? "#666666"
  readonly property color base07: themeData.colors.base07 ?? "#777777"
  readonly property color base08: themeData.colors.base08 ?? "#ff0000"
  readonly property color base09: themeData.colors.base09 ?? "#ff8800"
  readonly property color base0A: themeData.colors.base0A ?? "#ffff00"
  readonly property color base0B: themeData.colors.base0B ?? "#00ff00"
  readonly property color base0C: themeData.colors.base0C ?? "#00ffff"
  readonly property color base0D: themeData.colors.base0D ?? "#0000ff"
  readonly property color base0E: themeData.colors.base0E ?? "#ff00ff"
  readonly property color base0F: themeData.colors.base0F ?? "#ff0088"

  // --- Semantic colors ---
  readonly property color background: root[themeData.semantic.background] ?? base00
  readonly property color backgroundAlt: root[themeData.semantic.backgroundAlt] ?? base01
  readonly property color backgroundHighlight: root[themeData.semantic.backgroundHighlight] ?? base02
  readonly property color foreground: root[themeData.semantic.foreground] ?? base05
  readonly property color foregroundAlt: root[themeData.semantic.foregroundAlt] ?? base04
  readonly property color foregroundHighlight: root[themeData.semantic.foregroundHighlight] ?? base06
  readonly property color foregroundInactive: root[themeData.semantic.foregroundInactive] ?? base03
  readonly property color border: root[themeData.semantic.border] ?? base03
  readonly property color borderFocus: root[themeData.semantic.borderFocus] ?? base0D
  readonly property color accent: root[themeData.semantic.accent] ?? base0D
  readonly property color accentAlt: root[themeData.semantic.accentAlt] ?? base0E
  readonly property color success: root[themeData.semantic.success] ?? base0B
  readonly property color warning: root[themeData.semantic.warning] ?? base0A
  readonly property color error: root[themeData.semantic.error] ?? base08
  readonly property color info: root[themeData.semantic.info] ?? base0C
  readonly property color red: root[themeData.semantic.red] ?? base08
  readonly property color green: root[themeData.semantic.green] ?? base0B
  readonly property color yellow: root[themeData.semantic.yellow] ?? base0A
  readonly property color blue: root[themeData.semantic.blue] ?? base0D
  readonly property color magenta: root[themeData.semantic.magenta] ?? base0E
  readonly property color cyan: root[themeData.semantic.cyan] ?? base0C
  readonly property color orange: root[themeData.semantic.orange] ?? base09
  readonly property color grey: root[themeData.semantic.grey] ?? base03
  readonly property color bg0: root[themeData.semantic.bg0] ?? base00
  readonly property color bg1: root[themeData.semantic.bg1] ?? base01
  readonly property color bg2: root[themeData.semantic.bg2] ?? base02
  readonly property color bg3: root[themeData.semantic.bg3] ?? base03
  readonly property color bg4: root[themeData.semantic.bg4] ?? base04
  readonly property color bg5: root[themeData.semantic.bg5] ?? base05
  readonly property color bg6: root[themeData.semantic.bg6] ?? base06

  readonly property color userColor: root[themeData.semantic.green] ?? "#ff00ff"
  readonly property color robotColor: root[themeData.semantic.yellow] ?? "#00ff00"

  // --- Metadata ---
  readonly property string name: themeData.name ?? "Unknown"
  readonly property string variant: themeData.variant ?? "dark"
  readonly property string paired: themeData.paired ?? ""
  property bool isGenerated: false

  /*
   * Soft-reload of the theme. Call this function after changing
   * Appearance.theme to immediately apply the new theme.
  */
  function reload() {
    if (isGenerated) {
      root.themeData = Loader.loadTheme("generated/" + Appearance.theme)
    }
    root.themeData = Loader.loadTheme(Appearance.theme)
    console.log("------------ SOFT RELOADED THEME ----------------")
    console.log("Theme.qml: reloaded manually for:", Appearance.theme)
  }

  Component.onCompleted: {
    console.log("------------------ " + "Initialized : " + Appearance.theme + " ------------------")
  }
}
