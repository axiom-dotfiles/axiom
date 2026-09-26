pragma ComponentBehavior: Bound
import QtQuick
import Quickshell.Services.SystemTray
import qs.config
import qs.components.hosts.popout

Item {
  id: root

  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  property bool isVertical: barConfig.vertical
  readonly property int iconSize: properties.iconSize
  property int leftPadding: 8
  property int rightPadding: 8
  property int topPadding: 4
  property int bottomPadding: 4
  property int spacing: 6
  readonly property bool showPassive: properties.showPassive
  property color backgroundColor: Theme.backgroundAlt
  property int backgroundRadius: Appearance.borderRadius
  property color backgroundBorderColor: "transparent"
  property real backgroundBorderWidth: 0

  implicitWidth: isVertical ? root.barConfig.widgetSize : (layoutLoader.item ? layoutLoader.item.implicitWidth + leftPadding + rightPadding : 0)
  implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + topPadding + bottomPadding : 0) : root.barConfig.widgetSize

  Rectangle {
    anchors.fill: parent
    radius: root.backgroundRadius
    color: root.backgroundColor
  }

  Loader {
    id: layoutLoader
    anchors.centerIn: parent
    sourceComponent: isVertical ? columnComponent : rowComponent

    Component {
      id: rowComponent
      Row {
        spacing: root.spacing
        leftPadding: root.leftPadding
        rightPadding: root.rightPadding

        Repeater {
          model: SystemTray.items
          delegate: trayItemDelegate
        }
      }
    }

    Component {
      id: columnComponent
      Column {
        spacing: root.spacing
        topPadding: root.topPadding
        bottomPadding: root.bottomPadding

        Repeater {
          model: SystemTray.items
          delegate: trayItemDelegate
        }
      }
    }
  }

  Component {
    id: trayItemDelegate

    Item {
      id: delegateRoot
      required property QtObject modelData
      readonly property QtObject ti: modelData
      visible: ti && (root.showPassive || ti.status !== Status.Passive)
      width: visible ? root.iconSize : 0
      height: visible ? root.iconSize : 0

      Image {
        id: iconImage
        anchors.centerIn: parent
        source: {
          if (!delegateRoot.ti)
            return "";
          const appName = delegateRoot.ti.id || delegateRoot.ti.title || "";
          if (appName && IconConfig.overrides[appName]) {
            return IconConfig.overrides[appName];
          }
          return delegateRoot.ti.icon || "";
        }
        sourceSize.width: root.iconSize
        sourceSize.height: root.iconSize
        fillMode: Image.PreserveAspectFit
        smooth: true
      }

      PopoutAnchor {
        id: anchor
        popouts: root.popouts
        panel: root.panel
        popoutName: "SystemTray"
        openDelay: 150
        active: !!(delegateRoot.ti && delegateRoot.ti.hasMenu)
        extraData: ({
            trayItem: delegateRoot.ti,
            barConfig: root.barConfig,
            isVertical: root.isVertical
          })
      }
    }
  }
}
