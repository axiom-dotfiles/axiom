pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components.methods

// i18n: keys from the schema (type labels, library group names)
// A library of types to add (the bar editor's widgets, the layouts
// editor's modules): an A–Z / By category switch over equal tiles, one
// `delegate` per type (given `modelData`; tiles take `tileWidth`), by
// label or under a heading per group (LibraryOrder). `types` are
// { type, label, group }; the caller keeps `grouped` and sets it on
// `groupingChosen`.
ColumnLayout {
  id: root

  required property var types
  // Group names in order (the schema's `x-libraryGroups`)
  property var groups: []
  property bool grouped: false
  property Component delegate
  property real minTileWidth: Appearance.fontSize * 14
  property int minColumns: 1

  readonly property int columns: Math.max(root.minColumns, Math.floor(scroll.availableWidth / root.minTileWidth))
  // Whole pixels: the layout rounds the rows' width down, and a row a
  // fraction too wide wraps its last tile
  readonly property real tileWidth: Math.floor((scroll.availableWidth - Widget.spacing * (root.columns - 1)) / root.columns)
  readonly property var sections: LibraryOrder.sections(root.types, root.groups, type => I18n.tr(type.label), root.grouped)

  signal groupingChosen(bool grouped)

  spacing: Widget.spacing

  SegmentRow {
    SegmentButton {
      text: I18n.tr("A–Z")
      active: !root.grouped
      onClicked: root.groupingChosen(false)
    }
    SegmentButton {
      text: I18n.tr("By category")
      active: root.grouped
      onClicked: root.groupingChosen(true)
    }
  }

  ScrollView {
    id: scroll
    Layout.fillWidth: true
    Layout.fillHeight: true
    clip: true
    ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
    contentWidth: availableWidth

    ColumnLayout {
      width: scroll.availableWidth
      spacing: Widget.spacing * 1.5

      Repeater {
        model: root.sections

        ColumnLayout {
          id: section
          required property var modelData
          Layout.fillWidth: true
          spacing: Widget.spacing

          // I18n.tr("Other")
          SectionHeading {
            visible: root.grouped
            title: I18n.tr(section.modelData.name || "Other")
          }

          Flow {
            Layout.fillWidth: true
            spacing: Widget.spacing

            Repeater {
              model: section.modelData.types
              delegate: root.delegate
            }
          }
        }
      }
    }
  }
}
