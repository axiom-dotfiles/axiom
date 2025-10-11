pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services

import qs.components.widgets.overlay.modules.keybinds

RowLayout {
  id: root
  spacing: Menu.cardSpacing

  property var keybinds: HyprConfigManager.readKeybindings()

  KeybindDisplay { keybinds: root.keybinds}
}
