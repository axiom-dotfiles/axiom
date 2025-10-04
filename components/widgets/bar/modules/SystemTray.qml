// Cannot be bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.SystemTray

import qs.config

Item {
  id: tray

  // Add orientation property
  property int orientation: Config.orientation  // Accept orientation from parent
  property bool isVertical: orientation === Qt.Vertical
  Component.onCompleted: {
    console.log("SystemTray orientation:", orientation, "isVertical:", isVertical);
  }

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

  // Dynamic dimensions based on orientation
  height: isVertical ? implicitHeight : Widget.height
  width: isVertical ? Widget.height : implicitWidth

  implicitWidth: isVertical ? Widget.height : (layoutLoader.item ? layoutLoader.item.implicitWidth + Widget.padding * 2 : 0)
  implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + Widget.padding * 2 : 0) : Widget.height

  Layout.preferredWidth: isVertical ? Widget.height : implicitWidth
  Layout.preferredHeight: isVertical ? implicitHeight : Widget.height

  Rectangle {
    anchors.fill: parent
    radius: tray.backgroundRadius
    color: tray.backgroundColor
    // border.color: tray.backgroundBorderColor
    // border.width: tray.backgroundBorderWidth
  }

  Loader {
    id: layoutLoader
    anchors.centerIn: parent
    sourceComponent: isVertical ? columnComponent : rowComponent

    Component {
      id: rowComponent
      Row {
        spacing: tray.spacing

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
      readonly property var ti: modelData
      visible: ti && (tray.showPassive || ti.status !== Status.Passive)
      width: visible ? tray.iconSize : 0
      height: visible ? tray.iconSize : 0

      Image {
        anchors.centerIn: parent
        source: {
          if (!ti)
            return "";

          const appName = ti.id || ti.title || "";
          // Best way to find app name quickly
          // console.log("App Name:", appName);

          if (appName && Config.customIconOverrides[appName]) {
            return Config.customIconOverrides[appName];
          }

          return ti.icon || "";
        }
        sourceSize.width: tray.iconSize
        sourceSize.height: tray.iconSize
        fillMode: Image.PreserveAspectFit
        smooth: true
      }

      QsMenuAnchor {
        id: menuAnchor
        anchor.item: parent
        anchor.edges: tray.isVertical ? Qt.RightEdge : Qt.BottomEdge
        menu: ti ? ti.menu : null
      }

      MouseArea {
        id: menuArea
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton

        onClicked: ev => {
          if (!ti)
            return;

          if (ev.button === Qt.RightButton) {
            if (ti.hasMenu)
              menuAnchor.open();
            return;
          }

          if (ev.button === Qt.LeftButton) {
            if (ti.onlyMenu && ti.hasMenu) {
              menuAnchor.open();
            } else if (ti.activate) {
              ti.activate();
            }
            return;
          }

          if (ev.button === Qt.MiddleButton && ti.secondaryActivate) {
            ti.secondaryActivate();
          }
        }

        onWheel: w => {
          if (ti && ti.scroll)
            ti.scroll(w.angleDelta.y, false);
        }
      }
    }
  }
}
