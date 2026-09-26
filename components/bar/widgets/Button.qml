pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.reusable

// An icon (and optional label) that runs a built-in shell action or a
// shell command. Right and middle click can run their own commands, and
// the label can come from a command re-run on an interval.
BarIconWidget {
  id: root

  // First line of the label command's output (CommandManager runs it)
  readonly property string commandLabel: (CommandManager.outputs[properties.labelCommand] ?? "").split("\n")[0]

  function registerLabel() {
    CommandManager.acquire(root, {
      "command": root.properties.labelCommand,
      "interval": root.properties.labelInterval
    });
  }
  onPropertiesChanged: registerLabel()
  Component.onCompleted: registerLabel()
  Component.onDestruction: CommandManager.release(root)
  property bool _tooltipShown: false
  // Read by an edge menu this opened, which stays open while it's hovered
  readonly property bool hovered: mouseArea.containsMouse

  icon: properties.icon
  text: properties.labelCommand ? commandLabel : properties.label
  showText: text !== ""
  opacity: mouseArea.pressed ? 0.8 : 1

  function runAction() {
    switch (properties.action) {
    case "powerMenu":
      ShellManager.openPowerMenu();
      break;
    case "appLauncher":
      ShellManager.toggleAppLauncher();
      break;
    case "overlay":
      ShellManager.toggleOverlay();
      break;
    case "workspaceOverlay":
      ShellManager.toggleWorkspaceOverlay();
      break;
    case "edgeMenu":
      EdgeMenuManager.toggle(properties.menu, root);
      break;
    case "lock":
      ShellManager.sessionAction("lock");
      break;
    case "command":
      runCommand(properties.command);
      break;
    }
  }

  // The surface an action toggles, which hovering never closes
  readonly property var _surfaceFor: ({
      "powerMenu": "powermenu",
      "appLauncher": "launcher",
      "overlay": "overlay"
    })

  function hoverAction() {
    const surface = _surfaceFor[properties.action];
    if (surface && ShellManager.surfaceOpen(surface))
      return;
    if (properties.action === "edgeMenu" && EdgeMenuManager.isOpen(properties.menu))
      return;
    runAction();
  }

  function runCommand(command) {
    if (!command)
      return;
    Quickshell.execDetached(["sh", "-c", command]);
    // The command may change what the label shows (e.g. a toggle)
    if (properties.labelCommand)
      labelRefresh.restart();
  }

  // Shortly after a click, so the command has had time to act
  Timer {
    id: labelRefresh
    interval: 250
    onTriggered: CommandManager.refresh(root.properties.labelCommand)
  }

  // Hover outline, like the other clickable bar widgets
  Rectangle {
    anchors.fill: parent
    color: "transparent"
    radius: Appearance.borderRadius
    border.width: Appearance.borderWidth
    border.color: mouseArea.containsMouse ? Theme.border : "transparent"

    Behavior on border.color {
      ColorAnimation {
        duration: Appearance.animNormal
      }
    }
  }

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onContainsMouseChanged: {
      if (!containsMouse)
        root._tooltipShown = false;
    }
    onClicked: mouse => {
      if (mouse.button === Qt.RightButton)
        root.runCommand(root.properties.rightCommand);
      else if (mouse.button === Qt.MiddleButton)
        root.runCommand(root.properties.middleCommand);
      else
        root.runAction();
    }
  }

  // "Activate on hover": the click action once per hover, after the
  // popout open delay
  Timer {
    interval: PopoutConfig.openDelay
    running: mouseArea.containsMouse && root.properties.hoverActivate && root.properties.action !== "none"
    onTriggered: root.hoverAction()
  }

  // Tooltip after hovering for a moment
  Timer {
    id: tooltipDelay
    interval: 500
    running: mouseArea.containsMouse && root.properties.tooltip !== ""
    onTriggered: root._tooltipShown = true
  }

  PopupWindow {
    visible: root._tooltipShown && mouseArea.containsMouse && !!root.QsWindow.window
    color: "transparent"
    implicitWidth: tooltipBox.implicitWidth
    implicitHeight: tooltipBox.implicitHeight

    anchor.item: root
    anchor.edges: root.barConfig.top ? Edges.Bottom : root.barConfig.bottom ? Edges.Top : root.barConfig.left ? Edges.Right : Edges.Left
    anchor.gravity: anchor.edges
    anchor.margins.top: root.barConfig.top ? Widget.spacing : 0
    anchor.margins.bottom: root.barConfig.bottom ? Widget.spacing : 0
    anchor.margins.left: root.barConfig.left ? Widget.spacing : 0
    anchor.margins.right: root.barConfig.right ? Widget.spacing : 0

    StyledContainer {
      id: tooltipBox
      anchors.fill: parent
      implicitWidth: tooltipText.implicitWidth + Widget.padding * 2
      implicitHeight: tooltipText.implicitHeight + Widget.spacing * 2
      backgroundColor: Theme.background
      borderColor: Theme.border

      StyledText {
        id: tooltipText
        anchors.centerIn: parent
        text: root.properties.tooltip
      }
    }
  }
}
