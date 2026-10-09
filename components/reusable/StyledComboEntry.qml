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
    root._showText(root.editable ? root.value : root.labelOf(root.value));
  }

  // Typed in since it last showed a value: only then is the text taken as
  // a pick when the field loses focus. Text it was left showing (the value
  // changed while it had focus: what it edits switched under it) would be
  // picked onto what it edits now.
  property bool _typed: false
  // Sets the field's text without it counting as typing (which would
  // filter and reopen the list)
  function _showText(text) {
    root._typed = false;
    entry.input.text = text;
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
    // The field shows the pick before the owner hears of it: an owner that
    // moves focus on `picked` would otherwise have the stale text taken as
    // typed when the field loses focus, undoing the pick
    root._showText(root.editable ? value : root.labelOf(value));
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

  // Followed unless it's being typed over
  onValueChanged: if (!root._typed || !entry.input.activeFocus)
    root.showValue()
  onOptionsChanged: if (!root._typed || !entry.input.activeFocus)
    root.showValue()
  Component.onCompleted: root.showValue()

  StyledTextEntry {
    id: entry
    anchors.fill: parent
    readOnly: root.readOnly || !root.editable
    input.leftPadding: root.icon !== "" ? Appearance.fontSize * 1.6 : 0
    input.rightPadding: Appearance.fontSize * 1.6
    // One line, cut off rather than wrapped in a narrow field
    input.wrapMode: TextInput.NoWrap
    onTextEdited: {
      if (!root.editable)
        return;
      root._typed = true;
      root.query = entry.text;
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

    // Leaving a field typed in takes what's in it; one only looked at
    // shows the value again
    Connections {
      target: entry.input
      function onActiveFocusChanged() {
        if (entry.input.activeFocus || !root.editable)
          return;
        if (root._typed && entry.input.text.trim() !== root.value)
          root.pick(entry.input.text.trim());
        else
          root.showValue();
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
      text: "expand_more"
      opacity: 0.7
      // Turns over as the list opens
      rotation: dropdown.opened ? 180 : 0
      Glide on rotation {
        duration: Appearance.animNormal
      }
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
    transformOrigin: Item.Top

    // Grows down out of the field, as FloatingPopout does
    enter: Transition {
      NumberAnimation {
        property: "opacity"
        from: 0
        to: 1
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
      NumberAnimation {
        property: "scale"
        from: 0.95
        to: 1
        duration: Appearance.animNormal
        easing.type: Appearance.easing
      }
    }
    exit: Transition {
      NumberAnimation {
        property: "opacity"
        to: 0
        duration: Appearance.animFast
        easing.type: Appearance.easing
      }
    }

    background: DropdownSurface {
      color: Appearance.fill(Theme.backgroundAlt)
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
        color: index === root.highlighted ? Theme.backgroundHighlight : Qt.alpha(Theme.backgroundHighlight, 0)

        ColorGlide on color {}

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
