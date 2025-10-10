pragma Singleton

import QtQuick

import qs.config
import qs.services

QtObject {
  id: root

  property var _themeData: ConfigManager.theme

  // --- Base16 colors ---
  readonly property color base00: _themeData.colors.base00 ?? "#000000"
  readonly property color base01: _themeData.colors.base01 ?? "#111111"
  readonly property color base02: _themeData.colors.base02 ?? "#222222"
  readonly property color base03: _themeData.colors.base03 ?? "#333333"
  readonly property color base04: _themeData.colors.base04 ?? "#444444"
  readonly property color base05: _themeData.colors.base05 ?? "#555555"
  readonly property color base06: _themeData.colors.base06 ?? "#666666"
  readonly property color base07: _themeData.colors.base07 ?? "#777777"
  readonly property color base08: _themeData.colors.base08 ?? "#ff0000"
  readonly property color base09: _themeData.colors.base09 ?? "#ff8800"
  readonly property color base0A: _themeData.colors.base0A ?? "#ffff00"
  readonly property color base0B: _themeData.colors.base0B ?? "#00ff00"
  readonly property color base0C: _themeData.colors.base0C ?? "#00ffff"
  readonly property color base0D: _themeData.colors.base0D ?? "#0000ff"
  readonly property color base0E: _themeData.colors.base0E ?? "#ff00ff"
  readonly property color base0F: _themeData.colors.base0F ?? "#ff0088"

  // --- Semantic colors ---
  readonly property color background: root[_themeData.semantic.background] ?? base00
  readonly property color backgroundAlt: root[_themeData.semantic.backgroundAlt] ?? base01
  readonly property color backgroundHighlight: root[_themeData.semantic.backgroundHighlight] ?? base02
  readonly property color foreground: root[_themeData.semantic.foreground] ?? base05
  readonly property color foregroundAlt: root[_themeData.semantic.foregroundAlt] ?? base04
  readonly property color foregroundHighlight: root[_themeData.semantic.foregroundHighlight] ?? base06
  readonly property color foregroundInactive: root[_themeData.semantic.foregroundInactive] ?? base03
  readonly property color border: root[_themeData.semantic.border] ?? base03
  readonly property color borderFocus: root[_themeData.semantic.borderFocus] ?? base0D
  readonly property color accent: root[_themeData.semantic.accent] ?? base0D
  readonly property color accentAlt: root[_themeData.semantic.accentAlt] ?? base0E
  readonly property color success: root[_themeData.semantic.success] ?? base0B
  readonly property color warning: root[_themeData.semantic.warning] ?? base0A
  readonly property color error: root[_themeData.semantic.error] ?? base08
  readonly property color info: root[_themeData.semantic.info] ?? base0C
  readonly property color red: root[_themeData.semantic.red] ?? base08
  readonly property color green: root[_themeData.semantic.green] ?? base0B
  readonly property color yellow: root[_themeData.semantic.yellow] ?? base0A
  readonly property color blue: root[_themeData.semantic.blue] ?? base0D
  readonly property color magenta: root[_themeData.semantic.magenta] ?? base0E
  readonly property color cyan: root[_themeData.semantic.cyan] ?? base0C
  readonly property color orange: root[_themeData.semantic.orange] ?? base09
  readonly property color grey: root[_themeData.semantic.grey] ?? base03
  readonly property color bg0: root[_themeData.semantic.bg0] ?? base00
  readonly property color bg1: root[_themeData.semantic.bg1] ?? base01
  readonly property color bg2: root[_themeData.semantic.bg2] ?? base02
  readonly property color fg3: root[_themeData.semantic.bg3] ?? base03
  readonly property color fg2: root[_themeData.semantic.bg2] ?? base04
  readonly property color fg1: root[_themeData.semantic.bg1] ?? base05

  readonly property var stringToColorMap: ({
    "base00": base00,
    "base01": base01,
    "base02": base02,
    "base03": base03,
    "base04": base04,
    "base05": base05,
    "base06": base06,
    "base07": base07,
    "base08": base08,
    "base09": base09,
    "base0A": base0A,
    "base0B": base0B,
    "base0C": base0C,
    "base0D": base0D,
    "base0E": base0E,
    "base0F": base0F,
    "background": background,
    "backgroundAlt": backgroundAlt,
    "backgroundHighlight": backgroundHighlight,
    "foreground": foreground,
    "foregroundAlt": foregroundAlt,
    "foregroundHighlight": foregroundHighlight,
    "foregroundInactive": foregroundInactive,
    "border": border,
    "borderFocus": borderFocus,
    "accent": accent,
    "accentAlt": accentAlt,
    "success": success,
    "warning": warning,
    "error": error,
    "info": info,
    "red": red,
    "green": green,
    "yellow": yellow,
    "blue": blue,
    "magenta": magenta,
    "cyan": cyan,
    "orange": orange,
    "grey": grey,
    "bg0": bg0,
    "bg1": bg1,
    "bg2": bg2,
    "fg3": fg3,
    "fg2": fg2,
    "fg1": fg1
  })

  readonly property color userColor: root[_themeData.semantic.green] ?? "#ff00ff"
  readonly property color robotColor: root[_themeData.semantic.yellow] ?? "#00ff00"

  // --- Metadata ---
  readonly property string name: _themeData.name ?? "Unknown"
  readonly property string variant: _themeData.variant ?? "dark"
  readonly property string paired: _themeData.paired ?? ""
  property bool isGenerated: false

  function resolveColor(name) {
    const colorKey = name.includes('.') ? name.substring(name.lastIndexOf('.') + 1) : name;
  
    console.log("--------------------Resolving color for name: " + name)
    console.log("Stripped to key: " + colorKey)
    console.log("Keys available:", Object.keys(root.stringToColorMap))
    console.log("Resolved color:", stringToColorMap[colorKey])
    
    return root.stringToColorMap[colorKey] ?? name ?? "#ff00ff"
  }

  Component.onCompleted: {
    console.log("------------------ " + "Initialized : " + Appearance.theme + " ------------------")
  }
}
