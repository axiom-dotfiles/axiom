pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.forms
import qs.components.reusable

// One of axiom's binds in the editor: key, action, argument and label on
// one line, its issues under it. Rows are modelled by position in the
// editor's filtered, sorted list (bindIndex is the bind's own index), so
// the text fields follow the bind when rows above it move.
StyledContainer {
  id: root

  required property int bindIndex
  readonly property var bind: KeybindManager.binds[root.bindIndex] ?? ({})
  readonly property var issues: KeybindManager.issues[root.bindIndex] ?? []
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
        index: root.bindIndex
        combo: root.bind.key ?? ""
        invalid: root.hasError
        Layout.fillWidth: true
        Layout.preferredWidth: 3
      }

      ActionPicker {
        currentValue: root.bind.action ?? ""
        onPicked: action => KeybindManager.setField(root.bindIndex, "action", action)
        Layout.fillWidth: true
        Layout.preferredWidth: 3
      }

      // The argument (a choice when the action has a fixed set, else text)
      // and the call (toggle, open or close). Kept (empty) for actions with
      // neither, so the columns line up.
      RowLayout {
        id: argument
        readonly property bool needed: KeybindManager.needsArgument(root.bind.action)
        readonly property var callOptions: KeybindManager.callOptions(root.bind.action)
        Layout.fillWidth: true
        Layout.preferredWidth: 2
        Layout.preferredHeight: Widget.height
        spacing: Widget.spacing / 2

        SchemaComboBox {
          visible: argument.needed && root.argumentOptions !== null
          label: ""
          options: root.argumentOptions ?? []
          currentValue: root.bind.argument ?? ""
          // I18n.tr("left") I18n.tr("right") I18n.tr("up") I18n.tr("down")
          // I18n.tr("region") I18n.tr("window") I18n.tr("screen")
          onSelectionChanged: value => KeybindManager.setField(root.bindIndex, "argument", value)
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height
        }

        StyledTextEntry {
          id: argumentText
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
          input.onEditingFinished: KeybindManager.setField(root.bindIndex, "argument", input.text)
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height
        }

        SchemaComboBox {
          visible: argument.callOptions !== null
          label: ""
          options: argument.callOptions ?? []
          optionLabels: KeybindManager.callLabels(root.bind.action)
          currentValue: root.bind.call ?? "toggle"
          onSelectionChanged: value => KeybindManager.setField(root.bindIndex, "call", value)
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height
        }

        // Holds the width when there's nothing to show
        Item {
          visible: !argument.needed && argument.callOptions === null
          Layout.fillWidth: true
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
          text: I18n.tr(HyprlandConfigManager.sectionFor(root.bind.action)) + "  ›"
          opacity: 0.5
          textSize: Appearance.fontSize - 1
        }

        StyledTextEntry {
          id: label
          Layout.fillWidth: true
          Layout.preferredHeight: Widget.height
          placeholderText: HyprlandConfigManager.defaultLabel(root.bind) || I18n.tr("Label")
          Component.onCompleted: input.text = root.bind.description ?? ""
          input.onEditingFinished: KeybindManager.setField(root.bindIndex, "description", input.text)
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
          onClicked: KeybindManager.setField(root.bindIndex, modelData[0], !on)
        }
      }

      // Moving only makes sense in the saved order, unfiltered
      SquareIconButton {
        visible: KeybindManager.reorderable
        size: Widget.height
        iconText: "expand_less"
        tooltipText: I18n.tr("Move up")
        enabled: root.bindIndex > 0
        onClicked: KeybindManager.moveBind(root.bindIndex, root.bindIndex - 1)
      }

      SquareIconButton {
        visible: KeybindManager.reorderable
        size: Widget.height
        iconText: "expand_more"
        tooltipText: I18n.tr("Move down")
        enabled: root.bindIndex < KeybindManager.binds.length - 1
        onClicked: KeybindManager.moveBind(root.bindIndex, root.bindIndex + 1)
      }

      SquareIconButton {
        size: Widget.height
        iconText: "close"
        tooltipText: I18n.tr("Remove")
        onClicked: KeybindManager.removeBind(root.bindIndex)
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
