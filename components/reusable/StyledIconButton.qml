// qs/components/reusable/StyledIconButton.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.components.methods

ToolButton {
  id: root

  // -- Signals --
  // null

  // -- Public API --
  property string iconText: ""
  property string tooltipText: ""

  // -- Configurable Appearance --
  property int iconSize: Appearance.fontSize
  property color iconColor: Theme.foreground
  property color backgroundColor: "transparent"
  property color hoverColor: Theme.backgroundHighlight
  property color pressColor: Theme.backgroundAlt
  property color borderColor: "transparent"
  property int borderWidth: Appearance.borderWidth
  property real borderRadius: Widget.radius

  // -- Implementation --

  Layout.fillHeight: true
  Layout.fillWidth: true
  Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

  opacity: enabled ? 1.0 : 0.4
  scale: root.pressed ? 0.92 : 1.0

  Behavior on scale {
    NumberAnimation {
      duration: Appearance.animFast
    }
  }

  HoverHandler {
    cursorShape: Qt.PointingHandCursor
  }

  LazyLoader {
    active: root.hovered && root.tooltipText !== ""
    StyledToolTip {
      target: root
      text: root.tooltipText
    }
  }

  contentItem: StyledIcon {
    text: root.iconText
    font.pixelSize: root.iconSize
    color: root.iconColor
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }

  background: Rectangle {
    color: Utils.fadeable(root.pressed ? root.pressColor : (root.hovered ? root.hoverColor : root.backgroundColor), root.hoverColor, root.backgroundColor)
    border.color: root.borderColor
    border.width: root.borderWidth
    radius: root.borderRadius

    Behavior on color {
      ColorAnimation {
        duration: Appearance.animNormal
      }
    }
  }
}
