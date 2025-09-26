// Abstracts/Icon.qml
import QtQuick
import qs.config as Config // Import global configuration

Image {
    id: root
    property string iconName: ""
    property color iconColor // Optional: for recoloring monochrome icons

    // This property computes the final source URL, respecting user overrides first.
    readonly property string finalIconSource: {
        // 1. Check for a user-defined override in the config
        if (Config.customIconOverrides && Config.customIconOverrides[iconName]) {
            return Config.customIconOverrides[iconName];
        }
        // 2. Handle absolute file paths
        if (iconName.startsWith("file://")) {
            return iconName;
        }
        // 3. Fall back to the system icon theme
        return "image://theme/" + iconName;
    }

    source: finalIconSource
    
    // As before, this can be uncommented if you need to colorize icons.
    /*
    layer.enabled: iconColor !== "transparent"
    layer.effect: ShaderEffect { ... }
    */
}
