pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
    property var configData: Loader.loadConfig()

    property int distanceFromWorkspaceContainer: configData.Menu.distanceFromWorkspaceContainer ?? 10
    property bool startMenuPinned: configData.Menu.startMenuPinned ?? false
}
