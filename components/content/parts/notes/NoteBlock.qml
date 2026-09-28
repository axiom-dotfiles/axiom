pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.components.methods
import qs.components.reusable

// One block of a NoteEditor: a run of plain lines, or a task line with its
// checkbox. It reads its block from the editor on load() (not by binding),
// so typing never rebuilds anything.
Item {
  id: root

  required property int index
  required property var editor

  property string kind: "text"
  property bool checked: false
  property int depth: 0
  readonly property alias field: field
  readonly property bool isTask: root.kind === "task"
  readonly property bool shown: !(root.isTask && root.checked && !root.editor.showCompleted)

  visible: root.shown
  width: parent?.width ?? 0
  implicitHeight: root.shown ? field.implicitHeight : 0

  function load() {
    const block = root.editor.doc.blocks[root.index];
    if (!block)
      return;
    root.kind = block.kind;
    root.checked = NoteMarkdown.isChecked(block);
    root.depth = block.kind === "task" ? Math.floor(block.indent.replace(/\t/g, "  ").length / 2) : 0;
    if (field.text !== block.text)
      field.text = block.text;
  }

  function focusAt(pos) {
    field.forceActiveFocus();
    field.cursorPosition = Math.max(0, Math.min(pos, field.length));
  }

  Component.onCompleted: root.load()

  Connections {
    target: root.editor
    function onRestructured() {
      root.load();
    }
  }

  StyledIcon {
    id: box
    visible: root.isTask
    x: root.depth * Appearance.fontSize * 1.5
    // Centred on the first line
    y: Math.max(0, (field.lineHeight - height) / 2)
    text: root.checked ? "check_box" : "check_box_outline_blank"
    fill: root.checked ? 1 : 0
    textColor: root.checked ? Theme.accent : Theme.foregroundAlt
    textSize: Appearance.fontSize + 4

    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
      onTapped: root.editor.toggle(root.index)
    }
  }

  TextEdit {
    id: field

    // One line's height, for the checkbox
    readonly property real lineHeight: fontMetrics.height

    x: root.isTask ? box.x + box.width + Widget.spacing / 2 : 0
    width: root.width - x
    wrapMode: TextEdit.Wrap
    textFormat: TextEdit.PlainText
    color: root.checked ? Theme.foregroundAlt : Theme.foreground
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    font.strikeout: root.checked
    selectByMouse: true
    selectionColor: Theme.accent
    selectedTextColor: Theme.background

    FontMetrics {
      id: fontMetrics
      font: field.font
    }

    onTextChanged: root.editor.blockEdited(root.index, text)
    onActiveFocusChanged: {
      if (activeFocus) {
        root.editor.focusBlock = root.index;
        root.editor.focusPos = cursorPosition;
      }
    }
    onCursorPositionChanged: {
      if (activeFocus)
        root.editor.focusPos = cursorPosition;
    }
    onCursorRectangleChanged: {
      if (activeFocus)
        root.editor.ensureVisible(root, cursorRectangle);
    }

    Keys.onPressed: event => {
      const plain = !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.ShiftModifier));
      const noSelection = field.selectedText === "";
      switch (event.key) {
      case Qt.Key_Return:
      case Qt.Key_Enter:
        if (event.modifiers & Qt.ControlModifier) {
          // Ctrl+Enter checks a task off
          if (root.isTask) {
            root.editor.toggle(root.index);
            event.accepted = true;
          }
        } else if (root.isTask) {
          root.editor.splitTask(root.index, field.cursorPosition);
          event.accepted = true;
        } else if (!(event.modifiers & Qt.ShiftModifier)) {
          event.accepted = root.editor.continueList(field);
        }
        break;
      case Qt.Key_Backspace:
        if (plain && noSelection && field.cursorPosition === 0 && (root.isTask || root.index > 0)) {
          root.editor.mergeBack(root.index);
          event.accepted = true;
        }
        break;
      case Qt.Key_Delete:
        if (plain && noSelection && field.cursorPosition === field.length && root.index < root.editor.blockCount - 1) {
          root.editor.joinNext(root.index);
          event.accepted = true;
        }
        break;
      case Qt.Key_Tab:
      case Qt.Key_Backtab:
        if (root.isTask) {
          root.editor.indentTask(root.index, event.key === Qt.Key_Backtab || (event.modifiers & Qt.ShiftModifier) ? -1 : 1);
          event.accepted = true;
        }
        break;
      case Qt.Key_Up:
        if (plain && field.cursorRectangle.y < field.lineHeight / 2)
          event.accepted = root.editor.focusNeighbour(root.index, -1);
        break;
      case Qt.Key_Down:
        if (plain && field.cursorRectangle.y + field.cursorRectangle.height > field.contentHeight - field.lineHeight / 2)
          event.accepted = root.editor.focusNeighbour(root.index, 1);
        break;
      }
    }
  }
}
