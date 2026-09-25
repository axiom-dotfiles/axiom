pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base
import qs.components.hosts.overlay

// i18n: keys from the schema (view labels)
// Overlay editor, left: the overlay's pages in order (drag to reorder,
// click to edit), the pinned pages after them, then the selected page's
// name and anything that blocks saving
Item {
  id: root

  required property var dragLayer

  readonly property var view: OverlayManager.selectedView()
  readonly property bool isCustom: root.view?.type === "Custom"
  readonly property real rowHeight: Widget.height + Widget.padding
  readonly property real rowStep: root.rowHeight + Widget.spacing / 2

  // StyledTextEntry writes each keystroke back to its `text`, which drops
  // any binding on it, so the name is pushed in whenever the selected page
  // (or the draft) changes rather than bound
  function syncName() {
    if (!nameEntry.input.activeFocus)
      nameEntry.text = root.view?.name ?? "";
  }
  Connections {
    target: OverlayManager
    function onSelectedViewIndexChanged() {
      root.syncName();
    }
    function onLocalViewsChanged() {
      root.syncName();
    }
  }
  Component.onCompleted: root.syncName()

  TitledCard {
    color: Theme.background
    title: I18n.tr("Overlay Editor")
    dirty: OverlayManager.isDirty
    canSave: OverlayManager.problems.length === 0
    onSave: OverlayManager.saveChanges()
    onReset: OverlayManager.resetChanges()

    headerExtras: ColumnLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      // The configured pages: a drop target for page rows
      Item {
        id: pageList

        readonly property string targetKind: "pages"
        readonly property bool hovered: root.dragLayer.hoverTarget === pageList

        // Before the first row whose middle is below the point
        function indexAt(point) {
          const p = root.dragLayer.mapToItem(pageList, point.x, point.y);
          const count = OverlayManager.localViews?.length ?? 0;
          for (let i = 0; i < count; i++) {
            if (p.y < i * root.rowStep + root.rowHeight / 2)
              return i;
          }
          return count;
        }

        Layout.fillWidth: true
        Layout.preferredHeight: Math.max(0, (OverlayManager.localViews?.length ?? 0) * root.rowStep - Widget.spacing / 2)

        Component.onCompleted: root.dragLayer.registerTarget(pageList)
        Component.onDestruction: root.dragLayer.unregisterTarget(pageList)

        Repeater {
          model: OverlayManager.localViews?.length ?? 0

          delegate: StyledContainer {
            id: entry
            required property int index
            readonly property var entryView: OverlayManager.localViews[entry.index] ?? ({})
            readonly property bool selected: OverlayManager.selectedViewIndex === entry.index
            readonly property bool fixed: entry.entryView.type !== "Custom"
            readonly property bool carried: root.dragLayer.draggingKind === "page-move" && root.dragLayer.dragging.index === entry.index
            readonly property color ink: entry.selected ? Theme.background : Theme.foreground

            width: pageList.width
            height: root.rowHeight
            y: entry.index * root.rowStep
            backgroundColor: entry.selected ? Theme.accent : (entryArea.containsMouse ? Theme.backgroundHighlight : "transparent")
            borderWidth: 0
            opacity: entry.carried ? 0.3 : 1

            DragArea {
              id: entryArea
              anchors.fill: parent
              onDragStarted: (x, y) => root.dragLayer.begin({
                  "kind": "page-move",
                  "index": entry.index,
                  "icon": OverlayConfig.viewIcon(entry.entryView.type),
                  "label": OverlayConfig.viewLabel(entry.entryView, entry.index)
                }, entryArea, x, y)
              onDragMoved: (x, y) => root.dragLayer.move(entryArea, x, y)
              onDropped: root.dragLayer.end()
              onDragCanceled: root.dragLayer.cancel()
              onTapped: OverlayManager.selectView(entry.index)
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Widget.padding
              anchors.rightMargin: Widget.padding / 2
              spacing: Widget.spacing

              StyledIcon {
                text: OverlayConfig.viewIcon(entry.entryView.type)
                textColor: entry.selected ? Theme.background : Theme.accent
                Layout.preferredWidth: Appearance.fontSize * 1.5
              }

              StyledText {
                text: OverlayConfig.viewLabel(entry.entryView, entry.index)
                textColor: entry.ink
                font.bold: entry.selected
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              StyledText {
                visible: entry.fixed
                text: I18n.tr("fixed")
                textColor: entry.ink
                textSize: Appearance.fontSize - 2
                opacity: 0.6
              }

              // Unsaved edits to this page
              Rectangle {
                visible: OverlayManager.viewChanged(entry.index)
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: entry.selected ? Theme.background : Theme.accent
              }

              SquareIconButton {
                size: Widget.height - 6
                iconText: "close"
                iconColor: entry.ink
                backgroundColor: "transparent"
                hoverColor: Theme.error
                opacity: entry.selected || entryArea.containsMouse ? 1 : 0.35
                tooltipText: I18n.tr("Remove this page")
                onClicked: OverlayManager.removeView(entry.index)
              }
            }
          }
        }

        // Where the carried page would land
        Rectangle {
          visible: pageList.hovered
          z: 2
          width: pageList.width
          height: 3
          radius: 1.5
          y: Math.max(0, root.dragLayer.hoverIndex * root.rowStep - Widget.spacing / 4 - 1.5)
          color: Theme.accent
        }
      }

      // The page that isn't in config, always last
      Repeater {
        // Labels: I18n.tr("Overlay editor")
        model: [
          {
            "label": "Overlay editor",
            "icon": "view_quilt"
          }
        ]

        delegate: RowLayout {
          id: pinned
          required property var modelData
          Layout.fillWidth: true
          Layout.preferredHeight: root.rowHeight
          Layout.leftMargin: Widget.padding
          spacing: Widget.spacing
          opacity: 0.45

          StyledIcon {
            text: pinned.modelData.icon
            Layout.preferredWidth: Appearance.fontSize * 1.5
          }
          StyledText {
            text: I18n.tr(pinned.modelData.label)
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          StyledText {
            text: I18n.tr("pinned")
            textSize: Appearance.fontSize - 2
            Layout.rightMargin: Widget.padding
          }
        }
      }

      StyledContainer {
        id: addButton
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height
        backgroundColor: addArea.containsMouse ? Theme.backgroundHighlight : "transparent"
        borderColor: Theme.border
        borderWidth: 1

        StyledText {
          anchors.centerIn: parent
          text: "+  " + I18n.tr("New page")
          opacity: addArea.containsMouse ? 1 : 0.7
        }

        MouseArea {
          id: addArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: viewPicker.open()
        }

        TypePickerPopup {
          id: viewPicker
          y: addButton.height + Widget.spacing / 2
          width: addButton.width
          types: OverlayConfig.availableViewTypes
          onTypeSelected: type => OverlayManager.addView(type)
        }
      }
    }

    FieldGroup {
      visible: root.view !== null
      Layout.topMargin: Widget.spacing * 2
      title: I18n.tr("Page")
      description: root.isCustom ? I18n.tr("Its name shows in the page navigator.") : I18n.tr("A fixed page: it has no layout to edit.")

      StyledTextEntry {
        id: nameEntry
        Layout.fillWidth: true
        visible: root.isCustom
        placeholderText: I18n.tr("Page name")
        onAccepted: OverlayManager.renameView(OverlayManager.selectedViewIndex, nameEntry.text)

        Connections {
          target: nameEntry.input
          function onEditingFinished() {
            OverlayManager.renameView(OverlayManager.selectedViewIndex, nameEntry.text);
          }
        }
      }
    }

    FieldGroup {
      visible: OverlayManager.problems.length > 0
      title: I18n.tr("Can't save yet")

      Repeater {
        model: OverlayManager.problems

        StyledText {
          required property string modelData
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
          text: "•  " + modelData
          textColor: Theme.error
        }
      }
    }
  }
}
