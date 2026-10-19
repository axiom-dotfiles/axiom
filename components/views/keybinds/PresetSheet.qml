pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable
import qs.components.content.parts

// The Keybinds editor's presets, over the list: the presets on the left,
// on the right what the chosen one would do bind by bind
// (KeybindManager.presetPlan), each new or taken key with a checkbox, and
// Apply for the checked ones. Like any edit it waits for Save, and Undo
// takes it back.
Popup {
  id: root

  property string presetId: ""
  // Its plan, and the keys (BindKeys.keyId) checked
  property var plan: []
  property var chosen: []
  readonly property var preset: KeybindManager.presets.find(p => p.id === root.presetId) ?? null

  function choose(id) {
    root.presetId = id;
    root.plan = KeybindManager.presetPlan(id);
    root.chosen = root.plan.filter(step => step.chosen).map(step => step.id);
  }

  function toggle(id) {
    root.chosen = root.chosen.includes(id) ? root.chosen.filter(c => c !== id) : root.chosen.concat([id]);
  }

  modal: true
  focus: true
  padding: Widget.padding
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside
  onAboutToShow: root.choose(root.presetId !== "" ? root.presetId : (KeybindManager.presets[0]?.id ?? ""))

  // Solid, over a dimmed list: the page itself may be see-through
  background: DropdownSurface {
    color: Theme.background
  }

  Overlay.modal: Rectangle {
    color: Qt.alpha(Theme.background, 0.6)
  }

  contentItem: ColumnLayout {
    spacing: Widget.spacing * 1.5

    RowLayout {
      Layout.fillWidth: true

      SectionHeading {
        title: I18n.tr("Presets")
        description: I18n.tr("Sets of binds to start from. Pick what to add; keys already in use are left alone unless you tick them.")
      }

      SquareIconButton {
        size: Widget.height
        iconText: "close"
        tooltipText: I18n.tr("Close")
        Layout.alignment: Qt.AlignTop
        onClicked: root.close()
      }
    }

    RowLayout {
      Layout.fillWidth: true
      Layout.fillHeight: true
      spacing: Widget.spacing * 2

      // The presets
      StyledScrollView {
        id: presetScroll
        Layout.preferredWidth: root.width * 0.32
        Layout.fillHeight: true
        contentPadding: 0

        ColumnLayout {
          width: presetScroll.availableWidth
          spacing: 2

          Repeater {
            model: KeybindManager.presets

            delegate: ListEntryRow {
              id: presetRow
              required property var modelData
              icon: presetRow.modelData.replaces ? "swap_horiz" : "playlist_add"
              label: presetRow.modelData.title
              selected: root.presetId === presetRow.modelData.id
              onClicked: root.choose(presetRow.modelData.id)

              badges: StyledText {
                text: presetRow.modelData.binds.length
                textColor: presetRow.ink
                opacity: 0.6
                textSize: Appearance.fontSize - 2
              }
            }
          }
        }
      }

      StyledSeparator {
        Layout.fillHeight: true
        Layout.preferredWidth: 1
        opacity: 0.3
      }

      // What it would do
      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Widget.spacing

        StyledText {
          text: root.preset?.title ?? ""
          font.bold: true
          textSize: Appearance.fontSize + 2
        }

        StyledText {
          text: root.preset?.description ?? ""
          opacity: 0.7
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }

        StyledScrollView {
          id: planScroll
          Layout.fillWidth: true
          Layout.fillHeight: true
          contentPadding: 0

          ColumnLayout {
            width: planScroll.availableWidth
            spacing: 2

            Repeater {
              model: root.plan

              delegate: StyledContainer {
                id: step
                required property var modelData
                readonly property bool can: step.modelData.status !== "same"
                readonly property bool on: step.can && root.chosen.includes(step.modelData.id)
                readonly property var parts: KeyNames.split(step.modelData.bind.key)
                readonly property var taken: KeybindManager.binds[step.modelData.takenBy] ?? null

                Layout.fillWidth: true
                implicitHeight: Widget.height + Widget.padding / 2
                backgroundColor: stepArea.containsMouse && step.can ? Theme.backgroundHighlight : "transparent"
                borderWidth: 0
                opacity: step.can ? 1 : 0.5

                MouseArea {
                  id: stepArea
                  anchors.fill: parent
                  hoverEnabled: true
                  enabled: step.can
                  cursorShape: Qt.PointingHandCursor
                  onClicked: root.toggle(step.modelData.id)
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Widget.padding / 2
                  anchors.rightMargin: Widget.padding / 2
                  spacing: Widget.spacing

                  StyledIcon {
                    text: !step.can ? "check" : step.on ? "check_box" : "check_box_outline_blank"
                    textColor: step.on ? Theme.accent : Theme.foreground
                  }

                  RowLayout {
                    Layout.preferredWidth: Widget.height * 5
                    Layout.maximumWidth: Widget.height * 5
                    spacing: Widget.spacing / 2
                    clip: true

                    Repeater {
                      model: step.parts.mods

                      delegate: KeyCap {
                        required property string modelData
                        text: KeyNames.modifierLabel(modelData)
                      }
                    }

                    KeyCap {
                      text: KeybindManager.displayKey(step.parts.key)
                    }

                    Item {
                      Layout.fillWidth: true
                    }
                  }

                  StyledText {
                    text: BindActions.defaultLabel(step.modelData.bind) || (KeybindManager.actionLabels[step.modelData.bind.action] ?? "")
                    elide: Text.ElideRight
                    Layout.fillWidth: true
                  }

                  StyledText {
                    text: {
                      switch (step.modelData.status) {
                      case "same":
                        return I18n.tr("Already bound");
                      case "taken":
                        return I18n.tr("Replaces {0}", step.taken ? (step.taken.description || BindActions.defaultLabel(step.taken) || KeybindManager.actionLabels[step.taken.action]) : "");
                      }
                      return I18n.tr("New");
                    }
                    textColor: step.modelData.status === "taken" ? Theme.warning : Theme.foreground
                    opacity: step.modelData.status === "taken" ? 1 : 0.6
                    textSize: Appearance.fontSize - 2
                    elide: Text.ElideRight
                    Layout.maximumWidth: parent.width * 0.4
                  }
                }
              }
            }
          }
        }

        RowLayout {
          Layout.fillWidth: true
          spacing: Widget.spacing

          readonly property int replacing: root.plan.filter(step => step.status === "taken" && root.chosen.includes(step.id)).length
          readonly property int adding: root.plan.filter(step => step.status === "new" && root.chosen.includes(step.id)).length

          StyledText {
            text: parent.replacing > 0 ? I18n.tr("Adds {0}, replaces {1}", parent.adding, parent.replacing) : I18n.tr("Adds {0}", parent.adding)
            opacity: 0.7
            Layout.fillWidth: true
          }

          StyledTextButton {
            implicitHeight: Widget.height
            text: I18n.tr("Cancel")
            onClicked: root.close()
          }

          StyledTextButton {
            implicitHeight: Widget.height
            iconText: "done"
            text: I18n.tr("Apply")
            enabled: root.chosen.length > 0
            opacity: enabled ? 1 : 0.5
            backgroundColor: Theme.accent
            textColor: Theme.background
            onClicked: {
              KeybindManager.applyPreset(root.presetId, root.chosen);
              root.close();
            }
          }
        }
      }
    }
  }
}
