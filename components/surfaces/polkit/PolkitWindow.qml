pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets

import qs.components.reusable
import qs.config
import qs.services

// The polkit prompt on one screen: the whole screen dimmed, over the bars,
// and on the screen PolkitManager picked, a card with what is asking, the
// action, who to authenticate as and the password field. It's modal:
// clicks elsewhere do nothing, Escape or Cancel cancels the request. The
// password goes only to the request (PolkitManager.submit).
PanelWindow {
  id: root

  readonly property var flow: PolkitManager.flow
  readonly property bool shown: flow !== null
  // The card shows here: the picked screen, else (it's gone) the first
  readonly property bool hasCard: screen?.name === PolkitManager.screenName || (Quickshell.screens[0] === screen && !Quickshell.screens.some(s => s.name === PolkitManager.screenName))
  readonly property int pad: 18

  // The request's fixed text, kept while the card fades out after it ends
  property string message: ""
  property string actionId: ""
  property string iconName: ""
  // Submitted, waiting for polkit's answer
  property bool checking: false
  // Briefly after it opens the field takes no keys, so typing meant for
  // another window doesn't land in it
  property bool settled: false

  onFlowChanged: {
    checking = false;
    if (!flow)
      return;
    message = flow.message;
    actionId = flow.actionId;
    iconName = flow.iconName;
    entry.input.text = "";
    settled = false;
    settle.restart();
    Qt.callLater(root.takeFocus);
  }

  Timer {
    id: settle
    interval: 400
    onTriggered: root.settled = true
  }

  function takeFocus() {
    if (root.shown && root.hasCard)
      entry.input.forceActiveFocus();
  }

  function submit() {
    if (!root.flow || !root.flow.isResponseRequired || entry.input.text.length === 0)
      return;
    root.checking = true;
    PolkitManager.submit(entry.input.text);
    entry.input.text = "";
  }

  function identityLabel(identity) {
    if (!identity)
      return "";
    const name = identity.string;
    return identity.displayName && identity.displayName !== name ? I18n.tr("{0} ({1})", identity.displayName, name) : name;
  }

  Connections {
    target: root.flow
    ignoreUnknownSignals: true

    function onAuthenticationFailed() {
      root.checking = false;
      entry.input.text = "";
      shake.restart();
      root.takeFocus();
    }

    function onIsResponseRequiredChanged() {
      if (root.flow?.isResponseRequired) {
        root.checking = false;
        root.takeFocus();
      }
    }
  }

  anchors {
    left: true
    right: true
    top: true
    bottom: true
  }
  exclusionMode: ExclusionMode.Ignore
  color: "transparent"
  focusable: root.hasCard
  visible: shown || dim.opacity > 0

  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.namespace: "axiom-polkit"
  WlrLayershell.keyboardFocus: root.shown && root.hasCard ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

  Rectangle {
    id: dim
    anchors.fill: parent
    color: Appearance.darkMode ? Theme.background : Theme.foreground
    opacity: root.shown ? 0.75 : 0

    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
    }
  }

  // Modal: the dimmed screen takes clicks and does nothing with them
  MouseArea {
    anchors.fill: parent
  }

  Rectangle {
    id: card

    visible: root.hasCard
    anchors.centerIn: parent
    width: Math.min(480, root.width - 32)
    height: content.implicitHeight + root.pad * 2
    color: Theme.background
    border.color: Theme.border
    border.width: Appearance.borderWidth
    radius: Appearance.borderRadius

    opacity: root.shown ? 1 : 0
    scale: root.shown ? 1 : 0.97
    Behavior on opacity {
      NumberAnimation {
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
    }
    Behavior on scale {
      NumberAnimation {
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
    }

    ColumnLayout {
      id: content
      x: root.pad
      y: root.pad
      width: card.width - root.pad * 2
      spacing: root.pad

      // What is asking
      RowLayout {
        Layout.fillWidth: true
        spacing: root.pad

        Item {
          Layout.alignment: Qt.AlignTop
          implicitWidth: 40
          implicitHeight: 40

          IconImage {
            id: appIcon
            anchors.fill: parent
            source: root.iconName !== "" ? Quickshell.iconPath(root.iconName, true) : ""
            visible: source.toString() !== ""
          }

          StyledIcon {
            anchors.centerIn: parent
            visible: !appIcon.visible
            text: "admin_panel_settings"
            textColor: Theme.accent
            textSize: 32
          }
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: Widget.spacing / 2

          StyledText {
            Layout.fillWidth: true
            text: I18n.tr("Authentication required")
            textSize: Appearance.fontSizeLarge
            font.weight: Font.DemiBold
            wrapMode: Text.WordWrap
          }

          StyledText {
            Layout.fillWidth: true
            text: root.message
            wrapMode: Text.WordWrap
          }
        }
      }

      // The action
      GridLayout {
        Layout.fillWidth: true
        columns: 2
        columnSpacing: Widget.spacing * 2
        rowSpacing: Widget.spacing / 2

        StyledText {
          visible: actionDescription.visible
          text: I18n.tr("Action")
          opacity: 0.7
        }
        StyledText {
          id: actionDescription
          Layout.fillWidth: true
          visible: text !== ""
          text: PolkitManager.actionInfo.description ?? ""
          wrapMode: Text.WordWrap
        }

        StyledText {
          visible: vendor.visible
          text: I18n.tr("From")
          opacity: 0.7
        }
        StyledText {
          id: vendor
          Layout.fillWidth: true
          visible: text !== ""
          text: PolkitManager.actionInfo.vendor ?? ""
          wrapMode: Text.WordWrap
        }

        StyledText {
          visible: root.actionId !== ""
          text: I18n.tr("Action ID")
          opacity: 0.7
        }
        StyledText {
          Layout.fillWidth: true
          visible: root.actionId !== ""
          text: root.actionId
          textFamily: "monospace"
          textSize: Appearance.fontSize - 1
          elide: Text.ElideMiddle
        }

        StyledText {
          visible: (root.flow?.identities.length ?? 0) === 1
          text: I18n.tr("As")
          opacity: 0.7
        }
        StyledText {
          Layout.fillWidth: true
          visible: (root.flow?.identities.length ?? 0) === 1
          text: root.identityLabel(root.flow?.selectedIdentity)
          elide: Text.ElideRight
        }
      }

      // Who to authenticate as, when there's a choice
      ColumnLayout {
        Layout.fillWidth: true
        visible: (root.flow?.identities.length ?? 0) > 1
        spacing: Widget.spacing / 2

        StyledText {
          text: I18n.tr("Authenticate as")
          opacity: 0.7
        }

        Flow {
          Layout.fillWidth: true
          spacing: Widget.spacing

          Repeater {
            model: root.flow?.identities ?? []

            delegate: StyledTextButton {
              required property var modelData
              readonly property bool selected: root.flow?.selectedIdentity === modelData
              text: root.identityLabel(modelData)
              iconText: modelData.isGroup ? "group" : "person"
              backgroundColor: selected ? Theme.accent : Theme.backgroundHighlight
              textColor: selected ? Theme.background : Theme.foreground
              onClicked: {
                PolkitManager.selectIdentity(modelData);
                root.takeFocus();
              }
            }
          }
        }
      }

      // The answer
      ColumnLayout {
        id: answer
        Layout.fillWidth: true
        spacing: Widget.spacing / 2

        StyledTextEntry {
          id: entry
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height + Widget.padding
          placeholderText: (root.flow?.inputPrompt ?? "").trim().replace(/:$/, "") || I18n.tr("Password")
          readOnly: !(root.flow?.isResponseRequired ?? false) || root.checking || !root.settled

          Keys.onEscapePressed: PolkitManager.cancel()
          onAccepted: root.submit()
        }

        // Imperatively: the alias'd TextInput ignores a declarative echoMode
        Binding {
          target: entry.input
          property: "echoMode"
          value: root.flow?.responseVisible ? TextInput.Normal : TextInput.Password
        }

        StyledText {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.flow?.supplementaryMessage ?? ""
          textColor: root.flow?.supplementaryIsError ? Theme.error : Theme.foregroundAlt
          textSize: Appearance.fontSize - 1
          wrapMode: Text.WordWrap
        }

        // While polkit checks
        Item {
          Layout.fillWidth: true
          implicitHeight: 4
          visible: root.checking

          StyledContainer {
            width: parent.width * 0.3
            height: parent.height
            backgroundColor: Theme.accent

            SequentialAnimation on x {
              loops: Animation.Infinite
              running: root.checking && Appearance.animations

              NumberAnimation {
                from: 0
                to: answer.width * 0.7
                duration: Appearance.animSlow * 3
                easing.type: Easing.InOutQuad
              }
              NumberAnimation {
                from: answer.width * 0.7
                to: 0
                duration: Appearance.animSlow * 3
                easing.type: Easing.InOutQuad
              }
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Widget.spacing

        Row {
          Layout.fillWidth: true
          spacing: 14

          KeyHint {
            key: "↵"
            label: I18n.tr("authenticate")
          }
          KeyHint {
            key: "Esc"
            label: I18n.tr("cancel")
          }
        }

        StyledTextButton {
          text: I18n.tr("Cancel")
          onClicked: PolkitManager.cancel()
        }

        StyledTextButton {
          text: I18n.tr("Authenticate")
          iconText: "lock_open"
          backgroundColor: Theme.accent
          textColor: Theme.background
          onClicked: root.submit()
        }
      }
    }

    SequentialAnimation {
      id: shake

      NumberAnimation {
        target: content
        property: "x"
        to: root.pad + 20
        duration: Appearance.animFast
      }
      NumberAnimation {
        target: content
        property: "x"
        to: root.pad - 20
        duration: Appearance.animFast
      }
      NumberAnimation {
        target: content
        property: "x"
        to: root.pad + 20
        duration: Appearance.animFast
      }
      NumberAnimation {
        target: content
        property: "x"
        to: root.pad
        duration: Appearance.animFast
      }
    }
  }
}
