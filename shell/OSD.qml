pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.config
import qs.services
import qs.components.hosts.popout
import qs.components.surfaces.osd

Item {
  id: osdRoot
  anchors.fill: parent

  // Length of each bar along its axis; the OSD grows with the app count
  // in the other direction
  readonly property int barLength: 190
  readonly property int barSpacing: 20

  Variants {
    model: OSDConfig.enabled ? General.screensFor(OSDConfig.monitors) : []

    // One OSD per screen OSD.monitors puts it on; volume changes show it on
    // the target screen (the focused one), or on all of them in "all" mode.
    // Hiding is the popout's own hover-aware dismiss timer.
    delegate: EdgePopout {
      id: root
      required property ShellScreen modelData

      screen: modelData
      edge: OSDConfig.edge
      position: OSDConfig.position
      triggerEnabled: OSDConfig.openOnHover
      // The strip spans the OSD's own length along the edge
      triggerLength: {
        const item = root.contentItem;
        if (!item)
          return 200;
        return root.vertical ? item.implicitHeight : item.implicitWidth;
      }
      dismissDelay: OSDConfig.timeout
      // The bars inside also report their own changes, so they must
      // exist while the OSD is closed
      keepLoaded: true

      // Open (or keep open) on the target screen, or on every screen in
      // "all" mode; restarts the countdown
      function poke(force) {
        if (root.isOpen)
          root.updateDismissTimer();
        else if (force && ShellManager.showsOn(root.screen, OSDConfig.monitors))
          root.show();
      }

      // Picks up brightness changed outside axiom
      onIsOpenChanged: {
        if (root.isOpen)
          BrightnessManager.refresh(root.screen.name);
      }

      Connections {
        target: AudioManager

        function onVolumeChanged() {
          root.poke(true);
        }

        function onMutedChanged() {
          root.poke(true);
        }
      }

      content: Component {
        Item {
          id: box
          readonly property int margin: 15 - Widget.spacing

          implicitWidth: grid.implicitWidth + margin * 2
          implicitHeight: grid.implicitHeight + margin * 2

          GridLayout {
            id: grid
            anchors.fill: parent
            anchors.margins: box.margin
            // Vertical bars side by side, horizontal bars as rows; or,
            // along the edge, one line parallel to it (end to end when the
            // bars run along it too)
            readonly property bool rowFlow: OSDConfig.alongEdge ? !root.vertical : OSDConfig.vertical
            flow: rowFlow ? GridLayout.LeftToRight : GridLayout.TopToBottom
            columnSpacing: osdRoot.barSpacing
            rowSpacing: osdRoot.barSpacing

            Repeater {
              model: OSDConfig.bars

              delegate: OSDBar {
                required property var modelData

                entry: modelData
                screenName: root.screen?.name ?? ""
                Layout.preferredWidth: OSDConfig.vertical ? implicitWidth : osdRoot.barLength
                Layout.preferredHeight: OSDConfig.vertical ? osdRoot.barLength : implicitHeight
                onPoked: root.poke(modelData.showOsd)
              }
            }
          }
        }
      }
    }
  }
}
