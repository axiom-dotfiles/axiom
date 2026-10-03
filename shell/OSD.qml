pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.components.hosts.popout
import qs.components.surfaces.osd

// Every enabled OSD (OSD.osds), each on the screens its `monitors` puts it
// on: an EdgePopout, held off its edge when `detached` (as a dock or edge
// menu can be). A change opens every OSD holding that bar, on the target
// screen (the focused one), or on all of them in "all" mode. Hiding is the
// host's own hover-aware dismiss timer. Keyed by id, so editing an OSD's
// settings updates it in place instead of rebuilding every OSD.
Scope {
  Variants {
    model: OSDConfig.enabled ? OSDConfig.shownIds : []

    delegate: Scope {
      id: entry
      required property string modelData
      readonly property var osd: OSDConfig.osdById(modelData)
      readonly property bool valid: osd !== null
      readonly property var screens: valid ? General.screensFor(osd.monitors, osd.monitor) : []

      Variants {
        model: entry.screens

        delegate: EdgePopout {
          id: edgeHost
          required property ShellScreen modelData

          screen: modelData
          edge: Bar.getLocationFromString(entry.osd.edge)
          position: entry.osd.position / 100
          // Held off the edge, `gap` in from the frame lines there
          held: entry.osd.detached
          gap: entry.osd.gap
          triggerEnabled: entry.osd.openOnHover && !edgeTriggers.outranked
          overNamespace: "axiom-osd"
          // The strip spans the OSD's own length along the edge
          triggerLength: edgeHost.vertical ? (edgeHost.contentItem?.implicitHeight ?? 0) : (edgeHost.contentItem?.implicitWidth ?? 0)
          dismissDelay: entry.osd.timeout
          // The bars inside also report their own changes, so they must
          // exist while the OSD is closed
          keepLoaded: true

          content: Component {
            OSDContent {
              osd: entry.osd
              screenName: edgeHost.screen?.name ?? ""
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
    }
  }
}
