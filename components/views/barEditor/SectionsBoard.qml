pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// Bar editor: the selected bar's five sections side by side, in bar order,
// each a lane of draggable widget chips
Item {
  id: root

  required property var dragLayer

  property string _pendingZone: ""

  TypePickerPopup {
    id: addPopup
    types: Bar.availableWidgetTypes
    parent: root
    placeholderText: I18n.tr("Search widgets")
    onTypeSelected: type => BarManager.addWidget(root._pendingZone, type)
  }

  Card {
    color: Theme.background
    border.color: Theme.border

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Widget.padding
      spacing: Widget.spacing

      CardHeader {
        title: I18n.tr("Widgets")
        dirty: BarManager.isDirty
        onSave: BarManager.saveChanges()
        onReset: BarManager.resetChanges()
      }

      StyledText {
        Layout.fillWidth: true
        opacity: 0.6
        textSize: Appearance.fontSize - 2
        wrapMode: Text.WordWrap
        text: I18n.tr("Drag widgets to arrange them, across sections too, and click one to edit it. Changes show on the bar as you make them; Save keeps them.")
      }

      RowLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.topMargin: Widget.spacing / 2
        spacing: Widget.spacing

        Repeater {
          model: root.dragLayer.zones

          delegate: SectionLane {
            required property var modelData
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            dragLayer: root.dragLayer
            zone: modelData.key
            title: modelData.label
            onAddRequested: anchor => {
              root._pendingZone = modelData.key;
              addPopup.openAt(anchor);
            }
          }
        }
      }
    }
  }
}
