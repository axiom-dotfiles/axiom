pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.components.hosts.popout
import qs.components.surfaces.osd

// Every enabled OSD (OSD.osds), each on the screens its `monitors` puts it
// on: an EdgePopout for an edge OSD, a FloatingOSD for a floating one. A
// change opens every OSD holding that bar, on the target screen (the
// focused one), or on all of them in "all" mode. Hiding is the host's own
// hover-aware dismiss timer.
Item {
  id: osdRoot
  anchors.fill: parent

  // By a joined key, so editing an OSD's settings updates it in place
  // instead of rebuilding every OSD
  readonly property string _idsKey: OSDConfig.enabled ? OSDConfig.shownIds.join("\n") : ""

  Repeater {
    model: osdRoot._idsKey ? osdRoot._idsKey.split("\n") : []

    delegate: Item {
      id: entry
      required property string modelData
      readonly property var osd: OSDConfig.osdById(modelData)
      readonly property bool valid: osd !== null
      readonly property var screens: valid ? General.screensFor(osd.monitors) : []

      Variants {
        model: entry.valid && entry.osd.placement === "edge" ? entry.screens : []

        delegate: EdgePopout {
          id: edgeHost
          required property ShellScreen modelData

          screen: modelData
          edge: Bar.getLocationFromString(entry.osd.edge)
          position: entry.osd.position / 100
          triggerEnabled: entry.osd.openOnHover
          // The strip spans the OSD's own length along the edge
          triggerLength: {
            const item = edgeHost.contentItem;
            if (!item)
              return 200;
            return edgeHost.vertical ? item.implicitHeight : item.implicitWidth;
          }
          dismissDelay: entry.osd.timeout
          // The bars inside also report their own changes, so they must
          // exist while the OSD is closed
          keepLoaded: true

          content: Component {
            OSDContent {
              osd: entry.osd
              screenName: edgeHost.screen?.name ?? ""
              onEdge: true
              edgeVertical: edgeHost.vertical
              onPoked: force => edgeTriggers.poke(force)
            }
          }

          OSDTriggers {
            id: edgeTriggers
            host: edgeHost
            osd: entry.osd
          }
        }
      }

      Variants {
        model: entry.valid && entry.osd.placement === "floating" ? entry.screens : []

        delegate: FloatingOSD {
          id: floatingHost
          required property ShellScreen modelData

          screen: modelData
          xFraction: entry.osd.x / 100
          yFraction: entry.osd.y / 100
          dismissDelay: entry.osd.timeout

          content: Component {
            OSDContent {
              osd: entry.osd
              screenName: floatingHost.screen?.name ?? ""
              onPoked: force => floatingTriggers.poke(force)
            }
          }

          OSDTriggers {
            id: floatingTriggers
            host: floatingHost
            osd: entry.osd
          }
        }
      }
    }
  }
}
