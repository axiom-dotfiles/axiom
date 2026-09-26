pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import qs.config
import qs.components.reusable

// i18n: keys from callers and the schema (titles, descriptions, type labels)
// Shared "pick a type to add" popup (bar widgets, overlay views, ...).
// `types` is a list of { type, label }; the caller tracks what it opened
// this for.
Popup {
  id: root

  required property var types

  signal typeSelected(string type)

  width: 220
  padding: 0

  background: StyledContainer {
    backgroundColor: Theme.background
    borderColor: Theme.border

    layer.enabled: true
    // Qt 6 MultiEffect: Qt5Compat DropShadow fails to build its shader here
    layer.effect: MultiEffect {
      shadowEnabled: true
      shadowColor: "#40000000"
      shadowBlur: 0.5
      shadowVerticalOffset: 2
    }
  }

  contentItem: ListView {
    implicitHeight: Math.min(contentHeight, 320)
    clip: true
    model: root.types

    ScrollIndicator.vertical: ScrollIndicator {}

    delegate: Rectangle {
      id: rowDelegate
      required property var modelData

      width: ListView.view.width
      height: Widget.height
      color: rowArea.containsMouse ? Theme.backgroundHighlight : "transparent"

      StyledText {
        anchors.fill: parent
        anchors.leftMargin: Widget.padding
        anchors.rightMargin: Widget.padding
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        text: I18n.tr(rowDelegate.modelData.label)
      }

      MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          root.typeSelected(rowDelegate.modelData.type);
          root.close();
        }
      }
    }
  }
}
