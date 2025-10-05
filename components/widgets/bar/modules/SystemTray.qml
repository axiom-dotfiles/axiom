// SystemTray.qml - Fixed icon rendering
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray
import qs.config

Item {
  id: tray

  property var barConfig
  property var popouts
  property var panel
  property var screen

  Component.onCompleted: {
    // console.log("SystemTray initialized--------------------------------------------------------------");
    // console.log("Bar config:", JSON.stringify(barConfig));
    // console.log("Recieved popouts:", tray.popouts);
    // console.log("Recieved panel:", tray.panel);
  }

  property bool isVertical: barConfig.vertical
  property int iconSize: 18
  property int leftPadding: 8
  property int rightPadding: 8
  property int topPadding: 4
  property int bottomPadding: 4
  property int spacing: 6
  property bool showPassive: true
  property color backgroundColor: Theme.backgroundAlt
  property int backgroundRadius: 6
  property color backgroundBorderColor: "transparent"
  property real backgroundBorderWidth: 0

  // Track currently hovered item for popout positioning
  property var hoveredTrayItem: null
  property var hoveredItemGeometry: null

  // Dynamic dimensions based on orientation
  height: isVertical ? implicitHeight : Widget.height
  width: isVertical ? Widget.height : implicitWidth
  implicitWidth: isVertical ? Widget.height : (layoutLoader.item ? layoutLoader.item.implicitWidth + leftPadding + rightPadding : 0)
  implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + topPadding + bottomPadding : 0) : Widget.height
  Layout.preferredWidth: isVertical ? Widget.height : implicitWidth
  Layout.preferredHeight: isVertical ? implicitHeight : Widget.height

  Rectangle {
    anchors.fill: parent
    radius: tray.backgroundRadius
    color: tray.backgroundColor
  }

  Loader {
    id: layoutLoader
    anchors.centerIn: parent
    sourceComponent: isVertical ? columnComponent : rowComponent

    Component {
      id: rowComponent
      Row {
        spacing: tray.spacing
        leftPadding: tray.leftPadding
        rightPadding: tray.rightPadding

        Repeater {
          model: SystemTray.items
          delegate: trayItemDelegate
        }
      }
    }

    Component {
      id: columnComponent
      Column {
        spacing: tray.spacing
        topPadding: tray.topPadding
        bottomPadding: tray.bottomPadding

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
      visible: ti && (tray.showPassive || ti.status !== Status.Passive)
      width: visible ? tray.iconSize : 0
      height: visible ? tray.iconSize : 0

      Image {
        id: iconImage
        anchors.centerIn: parent
        source: {
          if (!delegateRoot.ti)
            return "";
          const appName = delegateRoot.ti.id || delegateRoot.ti.title || "";
          if (appName && Config.customIconOverrides[appName]) {
            return Config.customIconOverrides[appName];
          }
          return delegateRoot.ti.icon || "";
        }
        sourceSize.width: tray.iconSize
        sourceSize.height: tray.iconSize
        fillMode: Image.PreserveAspectFit
        smooth: true
      }

      MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onEntered: {
          if (!ti || !ti.hasMenu)
            return;

          // Calculate global position for anchor
          const globalPos = mapToItem(null, 0, 0);
          const parentPos = tray.mapToItem(null, 0, 0);

          tray.hoveredTrayItem = ti;
          tray.hoveredItemGeometry = {
            x: parentPos.x,
            y: parentPos.y,
            width: tray.width,
            height: tray.height,
            itemX: globalPos.x,
            itemY: globalPos.y,
            itemWidth: width,
            itemHeight: height
          };

          if (tray.popouts && tray.panel) {
            openMenuTimer.restart();
          }
        }

        onExited: {
          openMenuTimer.stop();
        }

        Timer {
          id: openMenuTimer
          interval: 150
          onTriggered: {
            if (tray.hoveredTrayItem && tray.hoveredTrayItem.hasMenu && tray.popouts && tray.panel) {
              tray.popouts.safeOpenPopout(tray.panel, "system-tray-menu", {
                trayItem: tray.hoveredTrayItem,
                anchorX: tray.hoveredItemGeometry.x,
                anchorY: tray.hoveredItemGeometry.y,
                anchorWidth: tray.hoveredItemGeometry.width,
                anchorHeight: tray.hoveredItemGeometry.height,
                isVertical: tray.isVertical
              });
            }
          }
        }
      }
    }
  }
}
