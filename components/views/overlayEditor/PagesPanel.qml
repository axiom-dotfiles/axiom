pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// i18n: keys from the schema (view labels)
// Overlay editor, left: the overlay's pages in order (drag to reorder,
// click to edit), the pinned page after them, then the selected page's
// name and anything that blocks saving
Item {
  id: root

  required property var dragLayer

  readonly property var view: OverlayManager.selectedView()
  readonly property bool isCustom: root.view?.type === "Custom"
  readonly property real rowHeight: Widget.height + Widget.padding
  readonly property real rowStep: root.rowHeight + Widget.spacing / 2

  // StyledTextEntry writes each keystroke back to its `text`, which drops
  // any binding on it, so the name is pushed in rather than bound: on every
  // draft change unless it's being typed, always when another page is
  // selected. Each keystroke renames the page, so there's no pending edit
  // for a selection change to misplace.
  function syncName(force) {
    if (force || !nameEntry.input.activeFocus)
      nameEntry.text = OverlayManager.selectedView()?.name ?? "";
  }
  Connections {
    target: OverlayManager
    function onSelectedViewIndexChanged() {
      root.syncName(true);
    }
    function onLocalViewsChanged() {
      root.syncName(false);
    }
  }
  Component.onCompleted: root.syncName(true)

  TitledCard {
    title: I18n.tr("Overlay Editor")
    showActions: false

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

          delegate: ListEntryRow {
            id: entry
            required property int index
            readonly property var entryView: OverlayManager.localViews[entry.index] ?? ({})
            readonly property bool carried: root.dragLayer.draggingKind === "page-move" && root.dragLayer.dragging.index === entry.index

            width: pageList.width
            height: root.rowHeight
            y: entry.index * root.rowStep
            opacity: entry.carried ? 0.3 : 1
            icon: OverlayConfig.viewIcon(entry.entryView.type)
            label: OverlayConfig.viewLabel(entry.entryView, entry.index)
            selected: OverlayManager.selectedViewIndex === entry.index
            changed: OverlayManager.viewChanged(entry.index)
            onClicked: OverlayManager.selectView(entry.index)
            dragArea.dragLayer: root.dragLayer
            dragArea.payload: ({
                "kind": "page-move",
                "index": entry.index,
                "icon": entry.icon,
                "label": entry.label
              })

            badges: StyledText {
              visible: entry.entryView.type !== "Custom"
              text: I18n.tr("fixed")
              textColor: entry.ink
              textSize: Appearance.fontSize - 2
              opacity: 0.6
            }

            RowAction {
              row: entry
              danger: true
              iconText: "close"
              tooltipText: I18n.tr("Remove this page")
              onClicked: OverlayManager.removeView(entry.index)
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

      // The pages that aren't in config, always last
      Repeater {
        model: OverlayConfig.pinnedPages

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

      AddEntryButton {
        id: addButton
        text: I18n.tr("New page")
        onClicked: viewPicker.open()

        TypePickerPopup {
          id: viewPicker
          y: addButton.height + Widget.spacing / 2
          width: addButton.width
          types: OverlayConfig.availableViewTypes
          placeholderText: I18n.tr("Search page types")
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
        onTextChanged: {
          if (nameEntry.input.activeFocus)
            OverlayManager.renameView(OverlayManager.selectedViewIndex, nameEntry.text);
        }
      }
    }

    FieldGroup {
      visible: OverlayManager.problems.length > 0
      title: I18n.tr("Can't save yet")

      IssueList {
        issues: OverlayManager.problems.map(text => ({
              "level": "error",
              "text": text
            }))
      }
    }
  }
}
