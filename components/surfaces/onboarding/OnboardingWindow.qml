pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

import qs.config
import qs.services
import qs.components.hosts.overlay
import qs.components.surfaces.onboarding.pages

// The onboarder (OnboardingManager): one page at a time over the dimmed
// screen, with the step bar where the overlay has its page navigator. It
// sits in the same reserved area as the overlay (OverlayPanel) with the
// same OverlayGrid, so its cards are the size the overlay's will be, and
// the Welcome page's size setting shows on it at once.
PanelWindow {
  id: root

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }

  // As OverlayPanel: inside the bars' and border's reserved area, lined up
  // with their inner stroke; at a bare screen edge, at the edge
  readonly property var _edges: Bar.edgesFor(root.screen)
  function _margin(side, open) {
    if (open)
      return 0;
    if (root._edges[side]?.background === "transparent")
      return HyprlandManager.gapsOut[side] ?? 0;
    return -Appearance.borderWidth;
  }
  margins {
    left: root._margin("left", Bar.screenEdgeOpen(root.screen, Bar.Left))
    right: root._margin("right", Bar.screenEdgeOpen(root.screen, Bar.Right))
    top: root._margin("top", Bar.screenEdgeOpen(root.screen, Bar.Top))
    bottom: root._margin("bottom", Bar.screenEdgeOpen(root.screen, Bar.Bottom))
  }

  color: "transparent"
  focusable: true
  WlrLayershell.namespace: "axiom-onboarding"
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
  WlrLayershell.layer: WlrLayer.Overlay
  exclusionMode: ExclusionMode.Normal
  exclusiveZone: 0

  // Esc (or Skip setup) asks first
  property bool confirmingQuit: false

  Item {
    id: content
    anchors.fill: parent
    focus: true
    Keys.onEscapePressed: root.confirmingQuit = !root.confirmingQuit

    // Everything above the step bar, as the overlay's page area
    Item {
      id: pageArea
      anchors {
        top: parent.top
        left: parent.left
        right: parent.right
        bottom: stepBar.top
        bottomMargin: Widget.padding * 2
      }

      Loader {
        id: page
        anchors.centerIn: parent
        // Shrinks a page that still doesn't fit, as OverlayPages does
        scale: Math.min(1, (pageArea.width - OverlayConfig.cardSpacing * 2) / Math.max(1, implicitWidth), (pageArea.height - OverlayConfig.cardSpacing * 2) / Math.max(1, implicitHeight))
        sourceComponent: {
          switch (OnboardingManager.pageId) {
          case "hyprland":
            return hyprlandPage;
          case "monitors":
            return monitorsPage;
          case "apps":
            return appsPage;
          case "workspaces":
            return workspacesPage;
          case "look":
            return lookPage;
          case "integrations":
            return integrationsPage;
          case "checks":
            return checksPage;
          case "finish":
            return finishPage;
          }
          return welcomePage;
        }
        opacity: status === Loader.Ready ? 1 : 0
        Behavior on opacity {
          NumberAnimation {
            duration: Appearance.animNormal
          }
        }
      }
    }

    // This screen's card size, worked out as the overlay's is
    OverlayGrid {
      id: grid
      availableWidth: pageArea.width - OverlayConfig.cardSpacing * 4
      availableHeight: pageArea.height - OverlayConfig.cardSpacing * 4
    }

    StepBar {
      id: stepBar
      anchors {
        bottom: parent.bottom
        bottomMargin: Widget.padding * 2
        horizontalCenter: parent.horizontalCenter
      }
      maxWidth: content.width - Widget.padding * 4
      confirmingQuit: root.confirmingQuit
      onQuitRequested: root.confirmingQuit = true
      onQuitCancelled: root.confirmingQuit = false
      onQuitConfirmed: OnboardingManager.close()
    }
  }

  Component {
    id: welcomePage
    WelcomePage {
      grid: grid
    }
  }
  Component {
    id: hyprlandPage
    HyprlandPage {
      grid: grid
    }
  }
  Component {
    id: monitorsPage
    MonitorsPage {
      grid: grid
      screen: root.screen
    }
  }
  Component {
    id: appsPage
    AppsPage {
      grid: grid
    }
  }
  Component {
    id: workspacesPage
    WorkspacesPage {
      grid: grid
    }
  }
  Component {
    id: lookPage
    LookPage {
      grid: grid
      screen: root.screen
    }
  }
  Component {
    id: integrationsPage
    IntegrationsPage {
      grid: grid
    }
  }
  Component {
    id: checksPage
    ChecksPage {
      grid: grid
    }
  }
  Component {
    id: finishPage
    FinishPage {
      grid: grid
    }
  }
}
