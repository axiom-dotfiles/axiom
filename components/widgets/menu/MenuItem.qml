// in/your/path/MenuItem.qml
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

import qs.components.reusable
import qs.config

/*
 * MenuItem acts as a wrapper for content within a menu list (like a ColumnLayout).
 * It handles filling the width and allows for an optional height override.
 * If no height is specified, it sizes to its content.
 *
 * Example:
 * MenuItem {
 *   heightOverride: 40
 *   StyledTextButton { text: "Click Me" }
 * }
 */
StyledContainer {
    id: menuItem

    // --- Public API ---

    // Set a specific height for this item. If -1, height is determined by its content.
    property real heightOverride: -1

    // Allows content to be placed directly inside <MenuItem> tags.
    default property alias content: contentHolder.data

    // --- Layout ---

    // Ensure it fills the width of the parent Layout.
    Layout.fillWidth: true

    // Set the height based on the override or the content's bounding box.
    height: heightOverride > -1 ? heightOverride : contentHolder.childrenRect.height

    // --- Internal Implementation ---

    // Make the container transparent by default to act as a pure wrapper.
    // The content inside (e.g., a button) can provide its own background.
    containerColor: "transparent"

    // This Item holds the actual content and is used to calculate the
    // automatic height based on its children.
    Item {
        id: contentHolder
        anchors.fill: parent
    }
}
