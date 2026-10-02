pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.forms
import qs.components.methods
import qs.components.reusable

// The Keybinds page's editor for axiom's own binds (Hyprland.binds):
// presets, then one row per bind, with a search and a sort that only
// change what's shown. Edits wait in KeybindManager's draft until Save.
ColumnLayout {
  id: root

  // What the last preset did, shown next to the presets
  property string presetResult: ""

  spacing: Widget.spacing * 2

  // A merge's reason code (merge_hypr_binds.py) as text, with its detail
  function reasonText(entry) {
    switch (entry.reason) {
    case "key":
      return I18n.tr("its key isn't plain text");
    case "function":
      return I18n.tr("it runs a Lua function");
    case "options":
      return I18n.tr("axiom binds don't have its options: {0}", entry.detail);
    case "shared":
      return I18n.tr("it's made in a shared module");
    case "notOnly":
      return I18n.tr("it isn't the only call on its line");
    case "statement":
      return I18n.tr("it's part of a larger statement");
    case "followed":
      return I18n.tr("something else follows it on its line");
    case "used":
      return I18n.tr("it's kept in {0}, which the file uses", entry.detail);
    case "unclosed":
      return I18n.tr("the call isn't closed");
    case "changed":
      return I18n.tr("the file changed");
    case "notUser":
      return I18n.tr("it isn't one of user/*.lua");
    case "syntax":
      return I18n.tr("the file wouldn't parse without it ({0})", entry.detail);
    case "crashed":
      return I18n.tr("the merge script failed ({0})", entry.detail);
    }
    return entry.detail || String(entry.reason ?? "");
  }

  Component.onDestruction: KeybindManager.stopRecording()

  // --- Presets ---

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    RowLayout {
      Layout.fillWidth: true

      StyledText {
        text: I18n.tr("Presets")
        textColor: Theme.accent
        font.bold: true
      }

      StyledText {
        text: root.presetResult
        opacity: 0.7
        textSize: Appearance.fontSize - 2
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.leftMargin: Widget.spacing
      }
    }

    Flow {
      Layout.fillWidth: true
      spacing: Widget.spacing

      Repeater {
        model: KeybindManager.presets

        delegate: StyledContainer {
          id: preset
          required property var modelData

          width: Math.min(parent.width, Math.max(260, (parent.width - Widget.spacing * 3) / 4))
          implicitHeight: presetColumn.implicitHeight + Widget.padding * 2
          backgroundColor: presetArea.containsMouse ? Theme.backgroundHighlight : Theme.backgroundAlt

          ColumnLayout {
            id: presetColumn
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Widget.padding
            spacing: 2

            RowLayout {
              Layout.fillWidth: true

              StyledText {
                text: preset.modelData.title
                font.bold: true
                elide: Text.ElideRight
                Layout.fillWidth: true
              }

              StyledText {
                text: "+" + preset.modelData.binds.length
                textColor: Theme.accent
                textSize: Appearance.fontSize - 1
              }
            }

            StyledText {
              text: preset.modelData.description
              opacity: 0.7
              textSize: Appearance.fontSize - 2
              wrapMode: Text.WordWrap
              Layout.fillWidth: true
            }
          }

          MouseArea {
            id: presetArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              const result = KeybindManager.applyPreset(preset.modelData.id);
              root.presetResult = result.skipped > 0 ? I18n.tr("Added {0}, skipped {1} already bound", result.added, result.skipped) : I18n.tr("Added {0}", result.added);
            }
          }
        }
      }
    }
  }

  // --- The binds ---

  ColumnLayout {
    Layout.fillWidth: true
    spacing: Widget.spacing

    // What the last merge did, and what it left behind
    IssueList {
      readonly property var merge: HyprlandConfigManager.lastMerge
      visible: merge !== null
      Layout.fillWidth: true
      issues: {
        if (!merge)
          return [];
        const name = file => file.split("/").pop();
        const found = [];
        if (merge.saveFailed)
          found.push({
            "level": "error",
            "text": I18n.tr("axiom's config couldn't be saved, so nothing moved")
          });
        else
          found.push({
            "level": "info",
            "text": merge.removed > 0 ? I18n.tr("Moved {0} binds into axiom and saved; the files they came from are backed up beside them", merge.moved) : I18n.tr("Moved {0} binds into axiom", merge.moved)
          });
        for (const moved of merge.remapped ?? [])
          found.push({
            "level": "info",
            "text": I18n.tr("{0} is on {1} now: axiom uses {2}", KeybindManager.actionLabels[moved.action] ?? moved.action, moved.to, moved.from)
          });
        for (const file of merge.tracked ?? [])
          found.push({
            "level": "info",
            "text": I18n.tr("{0} is in a git repository: commit or revert the change there", Paths.shortenHome(file))
          });
        for (const kept of merge.kept)
          found.push({
            "level": "warning",
            "text": I18n.tr("{0} stays in {1}: {2}", kept.key || "?", `${name(kept.file)}:${kept.line}`, root.reasonText(kept))
          });
        for (const failed of merge.failed)
          found.push({
            "level": "error",
            "text": failed.line > 0 ? I18n.tr("Left the bind at {0} where it is, and out of axiom's: {1}", `${name(failed.file)}:${failed.line}`, root.reasonText(failed)) : I18n.tr("Left the binds in {0} where they are, and out of axiom's: {1}", name(failed.file), root.reasonText(failed))
          });
        for (const error of merge.errors)
          found.push({
            "level": "warning",
            "text": error
          });
        return found;
      }
    }

    RowLayout {
      Layout.fillWidth: true

      StyledText {
        text: I18n.tr("Axiom binds")
        textColor: Theme.accent
        font.bold: true
      }

      StyledText {
        text: KeybindManager.issueCount > 0 ? I18n.tr("{0} with issues", KeybindManager.issueCount) : I18n.tr("Click a key to record a combo. Changes apply on Save.")
        textColor: KeybindManager.issueCount > 0 ? Theme.warning : Theme.foreground
        opacity: KeybindManager.issueCount > 0 ? 1 : 0.6
        textSize: Appearance.fontSize - 2
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.leftMargin: Widget.spacing
      }

      StyledTextButton {
        visible: !(KeybindManager.canMerge && KeybindManager.mergeableCount > 0) && KeybindManager.userConflicts.length > 0
        implicitHeight: Widget.height
        iconText: "delete_sweep"
        text: I18n.tr("Remove {0} binds your Hyprland config also has", KeybindManager.userConflicts.length)
        onClicked: KeybindManager.removeUserConflicts()
      }

      // Managed mode: the user's binds move in instead
      StyledTextButton {
        visible: KeybindManager.canMerge && KeybindManager.mergeableCount > 0
        enabled: !HyprlandConfigManager.merging
        implicitHeight: Widget.height
        iconText: "merge"
        text: I18n.tr("Merge {0} binds from your Hyprland config", KeybindManager.mergeableCount)
        onClicked: KeybindManager.mergeUserBinds()
      }

      StyledTextButton {
        implicitHeight: Widget.height
        iconText: "add"
        text: I18n.tr("Add bind")
        onClicked: KeybindManager.addBind(undefined, true)
      }
    }

    RowLayout {
      visible: KeybindManager.binds.length > 0
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledTextEntry {
        id: search
        Layout.fillWidth: true
        Layout.preferredHeight: Widget.height
        placeholderText: I18n.tr("Search binds by key, action or label")
        Component.onCompleted: input.text = KeybindManager.editQuery
        onTextChanged: KeybindManager.editQuery = text
        // Add bind clears the search
        Connections {
          target: KeybindManager
          function onEditQueryChanged() {
            if (search.input.text !== KeybindManager.editQuery)
              search.input.text = KeybindManager.editQuery;
          }
        }
      }

      StyledText {
        text: I18n.tr("Sort")
        opacity: 0.7
      }

      SchemaComboBox {
        label: ""
        // I18n.tr("Saved order") I18n.tr("Key") I18n.tr("Action") I18n.tr("Section")
        options: ["manual", "key", "action", "section"]
        optionLabels: ({
            "manual": I18n.tr("Saved order"),
            "key": I18n.tr("Key"),
            "action": I18n.tr("Action"),
            "section": I18n.tr("Section")
          })
        currentValue: KeybindManager.editSort
        onSelectionChanged: value => KeybindManager.editSort = value
        Layout.fillWidth: false
        Layout.preferredWidth: 180
      }
    }

    FilterChips {
      visible: KeybindManager.binds.length > 0
      Layout.fillWidth: true
      groups: [
        {
          "id": "editSection",
          "options": KeybindManager.editSectionOptions.map(option => ({
                "value": option.key,
                "label": option.title + "  " + option.count
              }))
        },
        {
          "id": "editMod",
          "options": KeybindManager.editModOptions.map(mod => ({
                "value": mod,
                "label": KeyNames.modifierLabel(mod)
              }))
        },
        {
          "id": "editIssues",
          "options": KeybindManager.issueCount > 0 || KeybindManager.editIssuesOnly ? [
            {
              "value": "issues",
              "label": I18n.tr("With issues") + "  " + KeybindManager.issueCount
            }
          ] : []
        }
      ]
      selection: ({
          "editSection": KeybindManager.editSectionFilter,
          "editMod": KeybindManager.editModFilter,
          "editIssues": KeybindManager.editIssuesOnly ? ["issues"] : []
        })
      filtering: KeybindManager.editFiltering
      onToggled: (group, value) => {
        if (group === "editIssues")
          KeybindManager.editIssuesOnly = !KeybindManager.editIssuesOnly;
        else
          KeybindManager.toggleFilter(group, value);
      }
      onCleared: KeybindManager.clearEditFilters()
    }

    StyledText {
      visible: KeybindManager.binds.length === 0
      text: I18n.tr("No binds yet. Add one, or start from a preset.")
      opacity: 0.6
      Layout.fillWidth: true
    }

    StyledText {
      visible: KeybindManager.editQuery.trim() !== "" || KeybindManager.editFiltering
      text: KeybindManager.visibleIndices.length > 0 ? I18n.tr("Showing {0} of {1}", KeybindManager.visibleIndices.length, KeybindManager.binds.length) : KeybindManager.editQuery.trim() !== "" ? I18n.tr("No binds match \"{0}\"", KeybindManager.editQuery.trim()) : I18n.tr("No keybinds match the filters")
      opacity: 0.6
      textSize: Appearance.fontSize - 2
      Layout.fillWidth: true
    }

    // By count: rows follow edits in place instead of rebuilding. Each
    // row's bind comes from the filtered, sorted list.
    Repeater {
      model: KeybindManager.visibleIndices.length

      delegate: BindEditorRow {
        required property int index
        bindIndex: KeybindManager.visibleIndices[index] ?? -1
      }
    }

    StyledTextButton {
      implicitHeight: Widget.height
      iconText: "add"
      text: I18n.tr("Add bind")
      onClicked: KeybindManager.addBind()
    }
  }
}
