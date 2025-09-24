pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
    property var configData: Loader.loadConfig()
    
    readonly property int height: configData.Bar.height ?? 30
    readonly property bool vertical: configData.Bar.vertical ?? false
    readonly property bool rightSide: configData.Bar.rightSide ?? false
    readonly property bool bottom: configData.Bar.bottom ?? false
    readonly property bool autoHide: configData.Bar.autoHide ?? false
    readonly property bool showOnAllMonitors: configData.Bar.showOnAllMonitors ?? false
}
