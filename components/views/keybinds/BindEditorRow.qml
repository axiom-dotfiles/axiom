pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.forms
import qs.components.reusable

// One of axiom's binds in the editor: key, action, argument and label on
// one line, its issues under it. Rows are modelled by index, so the text
// fields follow the bind when rows above it move.
StyledContainer {
  id: root

  required property int index
  readonly property var bind: KeybindManager.binds[root.index] ?? ({})
  readonly property var issues: KeybindManager.issues[root.index] ?? []
  readonly property bool hasError: root.issues.some(issue => issue.level === "error")
  readonly property var argumentOptions: {
    const options = KeybindManager.argumentOptions(root.bind.action);
    const current = root.bind.argument ?? "";
    return options && current !== "" && !options.includes(current) ? [current].concat(options) : options;
  }

  Layout.fillWidth: true
  implicitHeight: column.implicitHeight + Widget.padding
  backgroundColor: Theme.backgroundAlt
  borderColor: root.hasError ? Theme.error : (root.issues.length > 0 ? Theme.warning : "transparent")

  // Text fields keep what's being typed; otherwise they follow the bind
  onBindChanged: {
    if (!argumentText.input.activeFocus)
      argumentText.input.text = root.bind.argument ?? "";
    if (!label.input.activeFocus)
      label.input.text = root.bind.description ?? "";
  }

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding / 2
    spacing: Widget.spacing / 2

    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      KeyRecorder {
        index: root.index
        combo: root.bind.key ?? ""
        invalid: root.hasError
        Layout.fillWidth: true
        Layout.preferredWidth: 3
      }

      SchemaComboBox {
        label: ""
        options: KeybindManager.actions
        optionLabels: KeybindManager.actionLabels
        currentValue: root.bind.action ?? ""
        onSelectionChanged: value => KeybindManager.setField(root.index, "action", value)
        Layout.fillWidth: true
        Layout.preferredWidth: 3
      }

      // The argument: a choice when the action has a fixed set, else text.
      // Kept (empty) for actions without one, so the columns line up.
      Item {
        id: argument
        readonly property bool needed: KeybindManager.needsArgument(root.bind.action)
        Layout.fillWidth: true
        Layout.preferredWidth: 2
        implicitHeight: Widget.height

        SchemaComboBox {
          anchors.fill: parent
          visible: argument.needed && root.argumentOptions !== null
          label: ""
          options: root.argumentOptions ?? []
          currentValue: root.bind.argument ?? ""
          // I18n.tr("left") I18n.tr("right") I18n.tr("up") I18n.tr("down")
          onSelectionChanged: value => KeybindManager.setField(root.index, "argument", value)
        }

        StyledTextEntry {
          id: argumentText
          anchors.fill: parent
          visible: argument.needed && root.argumentOptions === null
          placeholderText: {
            switch (KeybindManager.argumentKind(root.bind.action)) {
            case "resize":
              return I18n.tr("Step, e.g. 50 0");
            case "special":
              return I18n.tr("Workspace name");
            }
            return root.bind.action === "exec" ? I18n.tr("Command") : I18n.tr("Search text");
          }
          Component.onCompleted: input.text = root.bind.argument ?? ""
          input.onEditingFinished: KeybindManager.setField(root.index, "argument", input.text)
        }
      }

      // The label, after the section the action files it under (unless the
      // description names its own: "Section: Label")
      RowLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 4
        spacing: Widget.spacing / 2

        StyledText {
          visible: !HyprlandConfigManager.hasOwnSection(label.input.text)
          text: HyprlandConfigManager.sectionFor(root.bind.action) + "  ›"
          opacity: 0.5
          textSize: Appearance.fontSize - 1
        }

        StyledTextEntry {
          id: label
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height
          placeholderText: HyprlandConfigManager.defaultLabel(root.bind) || I18n.tr("Label")
          Component.onCompleted: input.text = root.bind.description ?? ""
          input.onEditingFinished: KeybindManager.setField(root.index, "description", input.text)
        }
      }

      // The bind's flags, lit when on
      Repeater {
        model: [["repeating", "repeat", I18n.tr("Repeat while held")], ["locked", "lock", I18n.tr("Works while locked")], ["release", "keyboard_capslock", I18n.tr("On release")]]

        delegate: SquareIconButton {
          id: flag
          required property var modelData
          readonly property bool on: root.bind[modelData[0]] === true
          size: Widget.height
          iconText: modelData[1]
          tooltipText: modelData[2]
          backgroundColor: on ? Theme.accent : Theme.backgroundAlt
          iconColor: on ? Theme.background : Theme.foreground
          opacity: on ? 1 : 0.5
          onClicked: KeybindManager.setField(root.index, modelData[0], !on)
        }
      }

      SquareIconButton {
        size: Widget.height
        iconText: "expand_less"
        tooltipText: I18n.tr("Move up")
        enabled: root.index > 0
        onClicked: KeybindManager.moveBind(root.index, root.index - 1)
      }

      SquareIconButton {
        size: Widget.height
        iconText: "expand_more"
        tooltipText: I18n.tr("Move down")
        enabled: root.index < KeybindManager.binds.length - 1
        onClicked: KeybindManager.moveBind(root.index, root.index + 1)
      }

      SquareIconButton {
        size: Widget.height
        iconText: "close"
        tooltipText: I18n.tr("Remove")
        onClicked: KeybindManager.removeBind(root.index)
      }
    }

    Repeater {
      model: root.issues

      delegate: RowLayout {
        id: issue
        required property var modelData
        readonly property color issueColor: modelData.level === "error" ? Theme.error : Theme.warning
        Layout.fillWidth: true
        Layout.leftMargin: Widget.padding / 2
        spacing: Widget.spacing / 2

        StyledIcon {
          Layout.alignment: Qt.AlignTop
          text: issue.modelData.level === "error" ? "cancel" : "warning"
          textColor: issue.issueColor
          textSize: Appearance.fontSize - 2
        }

        StyledText {
          text: issue.modelData.text
          textColor: issue.issueColor
          textSize: Appearance.fontSize - 2
          wrapMode: Text.WordWrap
          Layout.fillWidth: true
        }
      }
    }
  }
}
