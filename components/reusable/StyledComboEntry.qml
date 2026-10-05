pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

// A choice from a list that drops down under the field, optionally typed
// (`editable`): typing filters the list and Enter takes what was typed, or
// the highlighted match. Up/Down move through the list (opening it), and
// Escape closes it. `options` is [{ value, label, icon? }]; `value` is the
// current choice, which the field shows unless it's being typed in (the
// push pattern: picking emits `picked`, the owner sets `value`).
Item {
  id: root

  property var options: []
  property string value: ""
  // Anything may be typed, not only the options
  property bool editable: false
  // Shown but not changeable
  property bool readOnly: false
  property alias placeholderText: entry.placeholderText
  property alias input: entry.input
  // A leading icon in the field
  property string icon: ""

  signal picked(string value)

  property string query: ""
  property int highlighted: 0

  readonly property var matches: {
    const query = root.query.trim().toLowerCase();
    if (!root.editable || query === "")
      return root.options;
    return root.options.filter(option => String(option.label).toLowerCase().includes(query) || String(option.value).toLowerCase().includes(query));
  }

  function labelOf(value) {
    return root.options.find(option => option.value === value)?.label ?? value;
  }

  function showValue() {
    entry.input.text = root.editable ? root.value : root.labelOf(root.value);
  }

  function openList() {
    if (root.readOnly || root.options.length === 0)
      return;
    root.highlighted = Math.max(0, root.matches.findIndex(option => option.value === root.value));
    dropdown.open();
    list.positionViewAtIndex(root.highlighted, ListView.Contain);
  }

  function move(step) {
    if (!dropdown.opened) {
      root.openList();
      return;
    }
    if (root.matches.length === 0)
      return;
    root.highlighted = Math.max(0, Math.min(root.matches.length - 1, root.highlighted + step));
    list.positionViewAtIndex(root.highlighted, ListView.Contain);
  }

  function pick(value) {
    dropdown.close();
    root.query = "";
    root.picked(value);
    Qt.callLater(root.showValue);
  }

  // Enter: the highlighted match from an open list, else what was typed
  function accept() {
    if (dropdown.opened && root.matches[root.highlighted])
      root.pick(root.matches[root.highlighted].value);
    else if (root.editable)
      root.pick(entry.input.text.trim());
  }

  implicitHeight: Widget.height
  implicitWidth: 200

  onValueChanged: if (!entry.input.activeFocus || !root.editable)
    root.showValue()
  onOptionsChanged: if (!entry.input.activeFocus || !root.editable)
    root.showValue()
  Component.onCompleted: root.showValue()

  StyledTextEntry {
    id: entry
    anchors.fill: parent
    readOnly: root.readOnly || !root.editable
    input.leftPadding: root.icon !== "" ? Appearance.fontSize * 1.6 : 0
    input.rightPadding: Appearance.fontSize * 1.6
    onTextChanged: {
      if (!root.editable || !entry.input.activeFocus)
        return;
      root.query = text;
      root.highlighted = 0;
      if (!dropdown.opened && root.matches.length > 0)
        root.openList();
    }
    onAccepted: root.accept()
    // The field passes these on (single-line text takes none of them)
    Keys.onUpPressed: root.move(-1)
    Keys.onDownPressed: root.move(1)
    Keys.onEscapePressed: event => {
      if (dropdown.opened)
        dropdown.close();
      else
        event.accepted = false;
    }

    // Leaving a typed field takes what's in it
    Connections {
      target: entry.input
      function onActiveFocusChanged() {
        if (!entry.input.activeFocus && root.editable && entry.input.text.trim() !== root.value)
          root.pick(entry.input.text.trim());
      }
    }

    StyledIcon {
      visible: root.icon !== ""
      anchors.left: parent.left
      anchors.leftMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: root.icon
      textColor: Theme.accent
    }

    StyledIcon {
      visible: !root.readOnly && root.options.length > 0
      anchors.right: parent.right
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      text: dropdown.opened ? "expand_less" : "expand_more"
      opacity: 0.7
    }
  }

  // A plain list (not typed) opens on a click anywhere on it; a typed one
  // only on its chevron, so the text stays clickable
  MouseArea {
    anchors.fill: parent
    anchors.leftMargin: root.editable ? parent.width - Appearance.fontSize * 2 : 0
    enabled: !root.readOnly
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      entry.input.forceActiveFocus();
      dropdown.opened ? dropdown.close() : root.openList();
    }
  }

  Popup {
    id: dropdown
    y: root.height + Widget.spacing / 2
    width: root.width
    padding: Widget.spacing / 2
    // The field keeps the keys: the list is driven from it
    focus: false
    closePolicy: Popup.CloseOnPressOutsideParent

    background: DropdownSurface {
      color: Theme.backgroundAlt
      border.width: Appearance.borderWidth
    }

    contentItem: ListView {
      id: list
      implicitHeight: Math.min(contentHeight, Widget.height * 6)
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: root.matches

      ScrollIndicator.vertical: ScrollIndicator {}

      delegate: Rectangle {
        id: option
        required property var modelData
        required property int index

        width: ListView.view.width
        height: Widget.height
        radius: Widget.radius
        color: index === root.highlighted ? Theme.backgroundHighlight : "transparent"

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Widget.padding
          anchors.rightMargin: Widget.padding
          spacing: Widget.spacing

          StyledIcon {
            visible: (option.modelData.icon ?? "") !== ""
            text: option.modelData.icon ?? ""
            textColor: Theme.accent
          }

          StyledText {
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: option.modelData.label
            font.bold: option.modelData.value === root.value
          }
        }

        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onEntered: root.highlighted = option.index
          onClicked: root.pick(option.modelData.value)
        }
      }
    }
  }
}
