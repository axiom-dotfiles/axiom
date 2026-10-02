pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import qs.config
import qs.components.hosts.popout

// The status notifier items, one icon each, in a row (or column, on a
// vertical bar). Hovering an item with a menu opens it as a popout.
BarWidget {
  id: root

  readonly property int iconSize: properties.iconSize
  readonly property bool showPassive: properties.showPassive
  // Sized by the bar, as BarIconWidget does
  readonly property real padding: barConfig.widgetPadding
  readonly property real spacing: barConfig.widgetSpacing * 1.5
  // No item showing (none, or only passive ones while those are hidden):
  // a zero natural size, which the bar skips, as IconTextWidget's `hidden`
  readonly property bool hidden: items.implicitWidth <= 0

  implicitWidth: isVertical ? barConfig.widgetSize : hidden ? 0 : items.implicitWidth + padding * 2
  implicitHeight: isVertical ? (hidden ? 0 : items.implicitHeight + padding * 2) : barConfig.widgetSize

  Rectangle {
    anchors.fill: parent
    visible: !root.hidden
    radius: root.barConfig.radius
    color: Theme.resolveColor(root.properties.backgroundColor)
  }

  Grid {
    id: items
    anchors.centerIn: parent
    flow: root.isVertical ? Grid.TopToBottom : Grid.LeftToRight
    rows: root.isVertical ? Math.max(1, trayItems.count) : 1
    columns: root.isVertical ? 1 : Math.max(1, trayItems.count)
    spacing: root.spacing

    Repeater {
      id: trayItems
      model: SystemTray.items

      Item {
        id: trayItem
        required property SystemTrayItem modelData
        visible: root.showPassive || modelData.status !== Status.Passive
        width: root.iconSize
        height: root.iconSize

        Image {
          anchors.centerIn: parent
          source: {
            const appName = trayItem.modelData.id || trayItem.modelData.title || "";
            return (appName && IconConfig.overrides[appName]) || trayItem.modelData.icon || "";
          }
          sourceSize.width: root.iconSize
          sourceSize.height: root.iconSize
          fillMode: Image.PreserveAspectFit
          smooth: true
        }

        PopoutAnchor {
          popouts: root.popouts
          panel: root.panel
          popoutName: "SystemTray"
          openDelay: 150
          active: root.properties.showPopout && trayItem.modelData.hasMenu
          extraData: ({
              "trayItem": trayItem.modelData,
              "barConfig": root.barConfig,
              "isVertical": root.isVertical
            })
        }
      }
    }
  }
}
