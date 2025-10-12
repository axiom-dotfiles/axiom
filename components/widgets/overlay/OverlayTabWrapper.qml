pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config

Item {
  id: wrapper
  required property var screen
  property var viewsConfig: Menu.views || []
  property var viewsModel: buildViewsModel(viewsConfig)
  property int currentIndex: 0

  implicitWidth: contentContainer.implicitWidth
  implicitHeight: contentContainer.implicitHeight + controlPanel.height + 20

  function buildViewsModel(viewConfigArray) {
    if (!viewConfigArray || viewConfigArray.length === 0) {
      return [];
    }
    const array = viewConfigArray.filter(viewConf => viewConf.visible !== false).map(viewConf => {
      const componentType = "views/" + viewConf.type + ".qml";
      console.log("Loading view component:", componentType);
      if (!viewConf.type) {
        console.warn("Unknown view type in menu config:", viewConf);
        return null;
      }
      return {
        component: componentType,
        properties: viewConf.properties || {}
      };
    }).filter(item => item !== null);
    return array;
  }

  Item {
    id: contentContainer
    anchors {
      top: parent.top
      left: parent.left
      right: parent.right
    }
    implicitHeight: viewLoader.item ? viewLoader.item.implicitHeight + Menu.cardSpacing * 2 : 0
    implicitWidth: viewLoader.item ? viewLoader.item.implicitWidth + Menu.cardSpacing * 2 : 0
    clip: true

    Rectangle {
      id: mainContentBox
      anchors.centerIn: parent
      implicitHeight: contentContainer.implicitHeight
      implicitWidth: contentContainer.implicitWidth
      radius: Menu.cardBorderRadius
      color: Theme.backgroundAlt
      border.color: Theme.foreground
      border.width: Menu.cardBorderWidth

      transform: Translate {
        id: slideTransform
        x: 0
        Behavior on x {
          NumberAnimation {
            duration: Appearance.animationDuration
            easing.type: Easing.InOutQuad
          }
        }
      }

      Loader {
        id: viewLoader
        anchors.centerIn: parent
        sourceComponent: wrapper.viewsModel.length > 0 ? viewComponent : null

        Component {
          id: viewComponent

          Loader {
            source: wrapper.viewsModel[wrapper.currentIndex].component

            onLoaded: {
              if (item) {
                item.screen = wrapper.screen

                // Apply any additional properties from config
                const props = wrapper.viewsModel[wrapper.currentIndex].properties;
                for (const key in props) {
                  if (props.hasOwnProperty(key)) {
                    item[key] = props[key];
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Control panel with navigation
  Rectangle {
    id: controlPanel
    anchors {
      top: contentContainer.bottom
      topMargin: 20
      horizontalCenter: parent.horizontalCenter
    }
    width: controlLayout.implicitWidth + 20
    height: 40
    radius: 8
    color: Theme.background
    border.color: Theme.foreground
    border.width: 1

    RowLayout {
      id: controlLayout
      anchors.centerIn: parent
      spacing: 12

      // Left arrow
      Rectangle {
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: 4
        color: leftArrowMouse.containsMouse ? Theme.backgroundAlt : "transparent"
        border.color: Theme.foreground
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "‹"
          font.pixelSize: 20
          font.bold: true
          color: Theme.foreground
        }

        MouseArea {
          id: leftArrowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            wrapper.currentIndex = (wrapper.currentIndex - 1 + wrapper.viewsModel.length) % wrapper.viewsModel.length;
          }
        }
      }

      // View indicators
      Rectangle {
        Layout.preferredWidth: indicatorRow.implicitWidth + 12
        Layout.preferredHeight: 30
        radius: 4
        color: Theme.background
        border.color: Theme.foreground
        border.width: 1

        Row {
          id: indicatorRow
          anchors.centerIn: parent
          spacing: 6

          Repeater {
            model: wrapper.viewsModel.length

            Rectangle {
              id: indicatorDot
              property int index: index
              width: 12
              height: 12
              radius: 2
              color: wrapper.currentIndex === index ? Theme.accent : Theme.backgroundAlt
              border.color: Theme.foreground
              border.width: 1

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  wrapper.currentIndex = indicatorDot.index;
                }
              }

              Behavior on color {
                ColorAnimation {
                  duration: Appearance.animationDuration / 2
                }
              }
            }
          }
        }
      }

      // Right arrow
      Rectangle {
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: 4
        color: rightArrowMouse.containsMouse ? Theme.backgroundAlt : "transparent"
        border.color: Theme.foreground
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "›"
          font.pixelSize: 20
          font.bold: true
          color: Theme.foreground
        }

        MouseArea {
          id: rightArrowMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            wrapper.currentIndex = (wrapper.currentIndex + 1) % wrapper.viewsModel.length;
          }
        }
      }
    }
  }
}
