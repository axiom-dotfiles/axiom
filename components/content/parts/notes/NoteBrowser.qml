pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Qt.labs.folderlistmodel
import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.parts.chat

// The notes folder, one level at a time: folders first, then notes. A
// folder opens on click; the path above goes back up. Notes and folders
// can be made, renamed and sent to the trash here.
Rectangle {
  id: root

  // The open note, highlighted
  property string current: ""
  // The folder shown (relative, "" for the top)
  property string folder: NotesManager.parentOf(root.current)
  property real maxHeight: 400

  signal picked(string path)

  // The row being renamed or confirming a delete (its path, "" for none)
  property string renaming: ""
  property string confirming: ""
  // "note" | "folder" while naming a new one, else ""
  property string creating: ""

  readonly property var crumbs: root.folder === "" ? [] : root.folder.split("/")

  function childPath(name) {
    return root.folder === "" ? name : root.folder + "/" + name;
  }

  function open(folder) {
    root.folder = folder;
    root.renaming = "";
    root.confirming = "";
    root.creating = "";
  }

  function remove(path) {
    root.confirming = "";
    NotesManager.trash(path);
  }

  implicitHeight: Math.min(root.maxHeight, content.implicitHeight + Widget.spacing * 2)
  color: Theme.background
  radius: Appearance.borderRadius
  border.color: Theme.border
  border.width: 1

  // Floats over the note, like a combo box's list
  layer.enabled: true
  layer.effect: MultiEffect {
    shadowEnabled: true
    shadowColor: "#40000000"
    shadowBlur: 0.5
    shadowVerticalOffset: 2
  }

  FolderListModel {
    id: folderModel
    folder: "file://" + NotesManager.absolute(root.folder === "" ? "" : root.folder + "/")
    nameFilters: NotesConfig.extensions.map(ext => "*." + ext)
    caseSensitive: false
    showDirsFirst: true
    showDotAndDotDot: false
    showHidden: NotesConfig.showHidden
    sortField: FolderListModel.Name
  }

  ColumnLayout {
    id: content
    anchors.fill: parent
    anchors.margins: Widget.spacing
    spacing: Widget.spacing / 2

    // Where we are, and new note / new folder
    RowLayout {
      Layout.fillWidth: true
      spacing: 2

      Flickable {
        Layout.fillWidth: true
        Layout.preferredHeight: 26
        contentWidth: crumbRow.implicitWidth
        contentX: Math.max(0, contentWidth - width)
        clip: true
        interactive: contentWidth > width

        Row {
          id: crumbRow
          height: parent.height
          spacing: 0

          Repeater {
            model: root.crumbs.length + 1
            delegate: Row {
              id: crumb
              required property int index
              readonly property bool last: index === root.crumbs.length
              height: crumbRow.height

              StyledIcon {
                visible: crumb.index > 0
                anchors.verticalCenter: parent.verticalCenter
                text: "chevron_right"
                textColor: Theme.foregroundAlt
                textSize: Appearance.fontSize - 2
              }
              Rectangle {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: (crumb.index === 0 ? crumbLabel.implicitWidth : crumbName.implicitWidth) + Widget.spacing * 1.5
                implicitHeight: 24
                radius: Appearance.borderRadius / 2
                color: crumbHover.hovered && !crumb.last ? Theme.backgroundHighlight : "transparent"

                // The top is an icon; a folder's name is text (a name like
                // "work" would draw as that icon)
                StyledIcon {
                  id: crumbLabel
                  visible: crumb.index === 0
                  anchors.centerIn: parent
                  text: "home"
                  textColor: crumb.last ? Theme.foreground : Theme.foregroundAlt
                  textSize: Appearance.fontSize + 1
                }
                StyledText {
                  id: crumbName
                  visible: crumb.index > 0
                  anchors.centerIn: parent
                  text: root.crumbs[crumb.index - 1] ?? ""
                  textColor: crumb.last ? Theme.foreground : Theme.foregroundAlt
                  textSize: Appearance.fontSize - 1
                  font.bold: crumb.last
                }
                HoverHandler {
                  id: crumbHover
                  cursorShape: crumb.last ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
                TapHandler {
                  enabled: !crumb.last
                  onTapped: root.open(root.crumbs.slice(0, crumb.index).join("/"))
                }
              }
            }
          }
        }
      }

      ChatIconButton {
        size: 26
        iconText: "note_add"
        iconColor: root.creating === "note" ? Theme.accent : Theme.foreground
        tooltipText: I18n.tr("New note")
        onClicked: root.creating = root.creating === "note" ? "" : "note"
      }
      ChatIconButton {
        size: 26
        iconText: "create_new_folder"
        iconColor: root.creating === "folder" ? Theme.accent : Theme.foreground
        tooltipText: I18n.tr("New folder")
        onClicked: root.creating = root.creating === "folder" ? "" : "folder"
      }
    }

    StyledTextEntry {
      id: nameField
      visible: root.creating !== ""
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height
      placeholderText: root.creating === "folder" ? I18n.tr("Folder name") : I18n.tr("Note name")
      onVisibleChanged: {
        text = "";
        if (visible)
          input.forceActiveFocus();
      }
      onAccepted: {
        if (root.creating === "folder")
          NotesManager.createFolder(root.folder, text, path => root.open(path));
        else
          NotesManager.createNote(root.folder, text, path => root.picked(path));
        root.creating = "";
      }
      input.Keys.onEscapePressed: root.creating = ""
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 1
      color: Theme.border
      opacity: 0.6
    }

    ListView {
      id: list
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.preferredHeight: contentHeight
      Layout.minimumHeight: Math.min(contentHeight, Widget.height)
      clip: true
      spacing: 2
      boundsBehavior: Flickable.StopAtBounds
      model: folderModel

      delegate: Rectangle {
        id: row

        required property string fileName
        required property bool fileIsDir
        readonly property string path: root.childPath(fileName)
        readonly property bool isCurrent: !fileIsDir && path === root.current
        readonly property bool editing: root.renaming === path
        readonly property bool confirming: root.confirming === path

        width: list.width
        implicitHeight: Math.max(Widget.height - 4, rowLayout.implicitHeight + Widget.spacing / 2)
        radius: Appearance.borderRadius / 2
        color: row.confirming ? Qt.alpha(Theme.error, 0.14) : row.isCurrent ? Qt.alpha(Theme.accent, 0.16) : rowHover.hovered ? Theme.backgroundHighlight : "transparent"

        HoverHandler {
          id: rowHover
          cursorShape: Qt.PointingHandCursor
        }
        TapHandler {
          enabled: !row.editing && !row.confirming
          onTapped: {
            if (row.fileIsDir)
              root.open(row.path);
            else
              root.picked(row.path);
          }
        }

        RowLayout {
          id: rowLayout
          anchors.fill: parent
          anchors.leftMargin: Widget.spacing
          anchors.rightMargin: 3
          spacing: Widget.spacing

          StyledIcon {
            text: row.fileIsDir ? "folder" : "description"
            fill: row.fileIsDir ? 1 : 0
            textColor: row.fileIsDir ? Theme.accent : row.isCurrent ? Theme.accent : Theme.foregroundAlt
            textSize: Appearance.fontSize + 1
          }

          StyledText {
            visible: !row.editing
            Layout.fillWidth: true
            text: row.confirming ? (NotesManager.canTrash ? I18n.tr("Move {0} to the trash?", row.fileName) : I18n.tr("Delete {0} for good?", row.fileName)) : row.fileIsDir ? row.fileName : NotesManager.titleOf(row.fileName)
            textColor: row.isCurrent ? Theme.accent : Theme.foreground
            textSize: Appearance.fontSize - 1
            elide: Text.ElideRight
          }

          StyledTextEntry {
            visible: row.editing
            Layout.fillWidth: true
            Layout.preferredHeight: Widget.height - 8
            text: row.fileIsDir ? row.fileName : NotesManager.titleOf(row.fileName)
            onVisibleChanged: {
              if (visible) {
                input.forceActiveFocus();
                input.selectAll();
              }
            }
            onAccepted: {
              NotesManager.rename(row.path, text, row.fileIsDir);
              root.renaming = "";
            }
            input.Keys.onEscapePressed: root.renaming = ""
          }

          StyledIcon {
            visible: row.fileIsDir && !row.editing && !row.confirming && !rowHover.hovered
            text: "chevron_right"
            textColor: Theme.foregroundAlt
            textSize: Appearance.fontSize
          }

          // Delete: confirm or cancel
          ChatIconButton {
            visible: row.confirming
            size: 24
            iconText: "check"
            iconColor: Theme.error
            iconSize: Appearance.fontSize - 1
            tooltipText: I18n.tr("Delete")
            onClicked: root.remove(row.path)
          }
          ChatIconButton {
            visible: row.confirming
            size: 24
            iconText: "close"
            iconSize: Appearance.fontSize - 1
            tooltipText: I18n.tr("Cancel")
            onClicked: root.confirming = ""
          }

          ChatIconButton {
            visible: rowHover.hovered && !row.editing && !row.confirming
            size: 24
            iconText: "edit"
            iconSize: Appearance.fontSize - 2
            tooltipText: I18n.tr("Rename")
            onClicked: {
              root.confirming = "";
              root.renaming = row.path;
            }
          }
          ChatIconButton {
            visible: rowHover.hovered && !row.editing && !row.confirming
            size: 24
            iconText: "delete"
            iconSize: Appearance.fontSize - 2
            tooltipText: I18n.tr("Delete")
            onClicked: {
              root.renaming = "";
              // Without a trash, deleting is for good: always asked
              if (NotesConfig.confirmDelete || !NotesManager.canTrash)
                root.confirming = row.path;
              else
                root.remove(row.path);
            }
          }
        }
      }
    }

    StyledText {
      visible: list.count === 0
      Layout.fillWidth: true
      Layout.topMargin: Widget.spacing
      Layout.bottomMargin: Widget.spacing
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      text: NotesManager.directoryMissing ? I18n.tr("The notes folder doesn't exist: {0}", NotesManager.directory) : root.folder === "" ? I18n.tr("No notes yet") : I18n.tr("This folder is empty")
      textColor: Theme.foregroundAlt
      textSize: Appearance.fontSize - 2
    }
  }
}
