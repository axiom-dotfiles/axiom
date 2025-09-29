import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Io

import qs.components.reusable
import qs.config

PanelWindow {
  id: rootWindow

  screen: modelData
  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  color: "transparent"
  focusable: true

  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay

  property bool shown: false

  function toggle() {
    shown = !shown;
    if (shown) {
      searchInput.input.text = "";
      searchInput.input.forceActiveFocus();
    }
  }

  IpcHandler {
    target: "appLauncher"

    function toggle() {
      rootWindow.toggle();
    }

    function show() {
      console.log("Showing app launcher");
      if (!rootWindow.shown)
        rootWindow.toggle();
    }

    function hide() {
      if (rootWindow.shown)
        rootWindow.toggle();
    }
  }

  visible: shown
  onClosed: shown = false

  HyprlandFocusGrab {
    id: grab
    active: rootWindow.shown
    windows: [rootWindow]
    onCleared: rootWindow.shown = false
  }

  property var filteredApps: []
  property string filterText: searchInput.text.trim().toLowerCase()
  property int maxResults: 7

  onFilterTextChanged: updateFilteredApps()

  function updateFilteredApps() {
    if (filterText === "") {
      filteredApps = [];
      return;
    }

    const allApps = DesktopEntries.applications.values;
    let filtered = allApps.filter(app => !app.noDisplay && (app.name.toLowerCase().includes(filterText) || app.genericName.toLowerCase().includes(filterText) || app.keywords.some(k => k.toLowerCase().includes(filterText))));
    filtered.sort((a, b) => a.name.localeCompare(b.name));
    filteredApps = filtered.slice(0, maxResults);
    resultsView.currentIndex = 0;
  }

  Rectangle {
    anchors.fill: parent
    color: Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.15)
  }

  Item {
    id: launcherContainer
    width: 700
    height: 500
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.verticalCenter: parent.verticalCenter
    anchors.verticalCenterOffset: -parent.height / 6

    StyledContainer {
      width: parent.width
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.top: parent.top
      containerColor: Theme.background
      containerBorderColor: Theme.border
      containerBorderWidth: Appearance.borderWidth

      Column {
        id: mainLayout
        width: parent.width
        spacing: Appearance.screenMargin / 2

        StyledTextEntry {
          id: searchInput
          placeholderText: "Search Applications..."
          width: parent.width
          focus: rootWindow.shown

          Keys.onEscapePressed: rootWindow.toggle()
          onAccepted: launchSelected()

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
              if (filteredApps.length > 0) {
                resultsView.forceActiveFocus();
                resultsView.Keys.pressed(event);
                event.accepted = true;
              }
            }
          }
        }

        StyledContainer {
          width: parent.width
          height: Math.min(resultsView.contentHeight, 450)
          visible: filteredApps.length > 0
          clip: true
          Behavior on height {
            NumberAnimation {
              duration: 150
              easing.type: Easing.InOutQuad
            }
          }

          StyledScrollView {
            anchors.fill: parent
            contentPadding: 0

            ListView {
              id: resultsView
              model: filteredApps
              currentIndex: 0

              Keys.onPressed: event => {
                if (event.key === Qt.Key_Up) {
                  decrementCurrentIndex();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                  incrementCurrentIndex();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Enter || event.key === Qt.Key_Return) {
                  launchSelected();
                  event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                  rootWindow.toggle();
                  event.accepted = true;
                }
              }

              delegate: Item {
                id: delegate
                width: ListView.view.width
                height: 60
                required property var modelData
                required property int index
                property bool isCurrent: ListView.isCurrentItem

                Rectangle {
                  anchors.fill: parent
                  radius: Appearance.borderRadius
                  color: isCurrent ? Theme.accent : (ma.containsMouse ? Theme.backgroundHighlight : "transparent")
                }

                MouseArea {
                  id: ma
                  anchors.fill: parent
                  hoverEnabled: true
                  onClicked: {
                    resultsView.currentIndex = delegate.index;
                    launchSelected();
                  }
                  onPositionChanged: {
                    if (containsMouse)
                      resultsView.currentIndex = delegate.index;
                  }
                }

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Widget.padding
                  anchors.rightMargin: Widget.padding
                  spacing: Widget.padding

                  Image {
                    id: appIcon
                    width: 36
                    height: 36
                    sourceSize: Qt.size(width, height)
                    fillMode: Image.PreserveAspectFit
                    source: Quickshell.iconPath(delegate.modelData.icon, "application-x-executable")
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Column {
                    anchors.verticalCenter: parent.verticalCenter
                    width: delegate.width - appIcon.width - (Widget.padding * 3)
                    spacing: 2

                    Text {
                      text: delegate.modelData.name
                      color: delegate.isCurrent ? Theme.background : Theme.foreground
                      font.pixelSize: Appearance.fontSize
                      font.bold: true
                      elide: Text.ElideRight
                      width: parent.width
                    }

                    Text {
                      text: delegate.modelData.genericName || ""
                      color: delegate.isCurrent ? Qt.rgba(Theme.background.r, Theme.background.g, Theme.background.b, 0.8) : Theme.foregroundAlt
                      font.pixelSize: Appearance.fontSize - 4
                      visible: text !== ""
                      elide: Text.ElideRight
                      width: parent.width
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  function launchSelected() {
    if (filteredApps.length > 0 && resultsView.currentIndex >= 0 && resultsView.currentIndex < filteredApps.length) {
      const appEntry = filteredApps[resultsView.currentIndex];
      if (appEntry) {
        appEntry.execute();
        rootWindow.toggle();
      }
    }
  }
}
