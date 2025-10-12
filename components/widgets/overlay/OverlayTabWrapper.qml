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

  implicitWidth: currentViewWidth + Menu.cardSpacing * 2
  implicitHeight: currentViewHeight + Menu.cardSpacing * 2 + controlPanel.height + 20

  // Store current view dimensions to avoid binding loops
  property real currentViewWidth: viewsRepeater.count > 0 && viewsRepeater.itemAt(wrapper.currentIndex) ? 
                                   viewsRepeater.itemAt(wrapper.currentIndex).implicitWidth : 0
  property real currentViewHeight: viewsRepeater.count > 0 && viewsRepeater.itemAt(wrapper.currentIndex) ? 
                                    viewsRepeater.itemAt(wrapper.currentIndex).implicitHeight : 0

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
    height: wrapper.currentViewHeight + Menu.cardSpacing * 2
    width: wrapper.currentViewWidth + Menu.cardSpacing * 2
    clip: true

    Behavior on height {
      NumberAnimation {
        duration: Appearance.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    Behavior on width {
      NumberAnimation {
        duration: Appearance.animationDuration
        easing.type: Easing.InOutQuad
      }
    }

    Rectangle {
      id: mainContentBox
      anchors.centerIn: parent
      width: contentContainer.width
      height: contentContainer.height
      radius: Menu.cardBorderRadius
      color: Theme.backgroundAlt
      border.color: Theme.foreground
      border.width: Menu.cardBorderWidth

      Item {
        id: viewsContainer
        anchors.fill: parent
        anchors.margins: Menu.cardSpacing

        Repeater {
          id: viewsRepeater
          model: wrapper.viewsModel

          Item {
            id: viewContainer
            required property int index
            required property var modelData
            
            anchors.centerIn: parent
            implicitWidth: viewWrapper.implicitWidth
            implicitHeight: viewWrapper.implicitHeight
            visible: wrapper.currentIndex === index
            opacity: wrapper.currentIndex === index ? 1 : 0

            OverlayViewWrapper {
              id: viewWrapper
              anchors.centerIn: parent
              screen: wrapper.screen
              viewModel: viewContainer.modelData
            }

            transform: Translate {
              id: slideTransform
              x: 0
            }

            Behavior on opacity {
              NumberAnimation {
                duration: Appearance.animationDuration / 2
                easing.type: Easing.InOutQuad
              }
            }

            Behavior on visible {
              enabled: false
            }

            states: [
              State {
                name: "left"
                when: viewContainer.index < wrapper.currentIndex
                PropertyChanges {
                  target: slideTransform
                  x: -100
                }
              },
              State {
                name: "center"
                when: viewContainer.index === wrapper.currentIndex
                PropertyChanges {
                  target: slideTransform
                  x: 0
                }
              },
              State {
                name: "right"
                when: viewContainer.index > wrapper.currentIndex
                PropertyChanges {
                  target: slideTransform
                  x: 100
                }
              }
            ]

            transitions: Transition {
              NumberAnimation {
                property: "x"
                duration: Appearance.animationDuration / 2
                easing.type: Easing.InOutQuad
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
    color: "transparent"
    border.color: Theme.foreground
    border.width: 0

    RowLayout {
      id: controlLayout
      anchors.centerIn: parent
      spacing: 12

      // Left arrow
      Rectangle {
        Layout.preferredWidth: 30
        Layout.preferredHeight: 30
        radius: Menu.cardBorderRadius
        color: leftArrowMouse.containsMouse ? Theme.backgroundHighlight : Theme.backgroundAlt
        border.color: Theme.border
        border.width: Menu.cardBorderWidth

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
        radius: Menu.cardBorderRadius
        color: Theme.backgroundAlt
        border.color: Theme.border
        border.width: Menu.cardBorderWidth

        Row {
          id: indicatorRow
          anchors.centerIn: parent
          spacing: 6

          Repeater {
            model: wrapper.viewsModel.length

            Rectangle {
              id: indicatorDot
              required property int index
              width: 12
              height: 12
              radius: Menu.cardBorderRadius
              color: wrapper.currentIndex === index ? Theme.accent : dotMouse.containsMouse ? Theme.foreground : Theme.background
              border.color: Theme.border
              border.width: Menu.cardBorderWidth

              MouseArea {
                id: dotMouse
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
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
        radius: Menu.cardBorderRadius
        color: rightArrowMouse.containsMouse ? Theme.backgroundHighlight : Theme.backgroundAlt
        border.color: Menu.cardBorderColor
        border.width: Menu.cardBorderWidth

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
