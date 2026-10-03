pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.reusable

// The Dock section's first card (its `x-card`): the docks as tabs, one
// shown at a time: where it sits (a screen picker with presets), Show, its
// pinned apps (with a search to add more) and its settings
// (EntryListCard).
EntryListCard {
  id: root

  readonly property var pinned: root.entry?.pinned ?? []

  sectionKey: "Dock"
  listKey: "docks"
  entryType: "DockEntry"
  savedEntries: DockConfig.docks
  title: I18n.tr("Docks")
  description: (SettingsManager.localConfig?.Dock?.enabled ?? DockConfig.enabled) ? "" : I18n.tr("Docks are off: turn on Enabled below to show them.")
  pickerHint: I18n.tr("Click a spot to place it; fine-tune below. Show slides a hidden dock in.")
  idBase: "dock"
  labelOf: dock => DockConfig.labelOf(dock)
  onShow: id => DockManager.show(id)

  function pinApp(id) {
    if (!root.pinned.includes(id))
      root.edit({
        "pinned": root.pinned.concat([id])
      });
  }

  function unpinAt(index) {
    root.edit({
      "pinned": root.pinned.filter((_, i) => i !== index)
    });
  }

  function movePinned(index, by) {
    const to = index + by;
    if (to < 0 || to >= root.pinned.length)
      return;
    const pinned = root.pinned.slice();
    pinned.splice(to, 0, pinned.splice(index, 1)[0]);
    root.edit({
      "pinned": pinned
    });
  }

  // The pinned apps, with a search to pin more
  entryContent: [
    StyledText {
      text: I18n.tr("Pinned apps")
      font.bold: true
      Layout.fillWidth: true
    },
    StyledText {
      visible: root.pinned.length === 0
      text: I18n.tr("None yet: search below, or right-click a running app on the dock and pick Keep in dock.")
      textColor: Theme.foregroundAlt
      textSize: Appearance.fontSize - 2
      wrapMode: Text.WordWrap
      Layout.fillWidth: true
    },
    Repeater {
      model: root.pinned.length

      delegate: AppRow {
        id: pinnedRow
        required property int index
        readonly property string appId: root.pinned[index]
        readonly property var entry: DockManager.entryFor(appId)

        Layout.fillWidth: true
        iconSource: DockManager.iconFor(appId, null)
        name: entry?.name || appId
        detail: entry ? "" : I18n.tr("No app with this id")

        StyledIconButton {
          iconText: "arrow_upward"
          tooltipText: I18n.tr("Move up")
          enabled: pinnedRow.index > 0
          Layout.fillWidth: false
          Layout.preferredWidth: Widget.height - 4
          Layout.preferredHeight: Widget.height - 4
          onClicked: root.movePinned(pinnedRow.index, -1)
        }

        StyledIconButton {
          iconText: "arrow_downward"
          tooltipText: I18n.tr("Move down")
          enabled: pinnedRow.index < root.pinned.length - 1
          Layout.fillWidth: false
          Layout.preferredWidth: Widget.height - 4
          Layout.preferredHeight: Widget.height - 4
          onClicked: root.movePinned(pinnedRow.index, 1)
        }

        StyledIconButton {
          iconText: "close"
          tooltipText: I18n.tr("Remove")
          hoverColor: Theme.error
          Layout.fillWidth: false
          Layout.preferredWidth: Widget.height - 4
          Layout.preferredHeight: Widget.height - 4
          onClicked: root.unpinAt(pinnedRow.index)
        }
      }
    },
    StyledTextEntry {
      id: search
      placeholderText: I18n.tr("Search apps to pin…")
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height
    },
    Flow {
      Layout.fillWidth: true
      spacing: Widget.spacing / 2

      // Modelled by count, so a keystroke rebinds the rows instead of
      // rebuilding them
      Repeater {
        id: matches
        readonly property var apps: root.entry ? LauncherManager.searchApps(search.text, 24).filter(app => !root.pinned.includes(app.id)).slice(0, 8) : []
        model: matches.apps.length

        delegate: StyledTextButton {
          id: result
          required property int index
          readonly property var app: matches.apps[result.index] ?? {
            "id": "",
            "name": ""
          }
          implicitHeight: Widget.height - 4
          iconText: "add"
          text: result.app.name
          onClicked: {
            root.pinApp(result.app.id);
            search.text = "";
          }
        }
      }
    },
    StyledSeparator {
      separatorColor: Theme.accent
      Layout.fillWidth: true
    }
  ]

  // A pinned app: its icon and name, then the buttons given as children
  component AppRow: RowLayout {
    id: row
    property string iconSource: ""
    property string name: ""
    property string detail: ""
    default property alias buttons: extra.data

    spacing: Widget.spacing

    Image {
      Layout.preferredWidth: Widget.height - 8
      Layout.preferredHeight: Widget.height - 8
      sourceSize: Qt.size(64, 64)
      source: row.iconSource
      asynchronous: true
    }

    StyledText {
      text: row.name
      elide: Text.ElideRight
      Layout.fillWidth: true
    }

    StyledText {
      visible: row.detail !== ""
      text: row.detail
      textColor: Theme.error
      textSize: Appearance.fontSize - 2
    }

    RowLayout {
      id: extra
      spacing: 2
    }
  }
}
