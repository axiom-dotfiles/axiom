.pragma library
.import QtQuick as QtQuick

function loadConfig() {
    try {
        var file = new XMLHttpRequest()
        file.open("GET", Qt.resolvedUrl("../config.json"), false)
        file.send()
        
        if (file.status === 200) {
            return JSON.parse(file.responseText)
        }
    } catch (e) {
        console.error("Failed to load config.json:", e)
    }
    
    // Return defaults if loading fails
    return {
        Config: {},
        Display: {},
        Appearance: {},
        Bar: {},
        Widget: {}
    }
}

function loadTheme(themeName) {
    try {
        var file = new XMLHttpRequest()
        var path = Qt.resolvedUrl("../themes/" + themeName + ".json")
        file.open("GET", path, false)
        file.send()
        
        if (file.status === 200) {
            return JSON.parse(file.responseText)
        }
    } catch (e) {
        console.error("Failed to load theme:", themeName, e)
    }
    
    // Return a default dark theme if loading fails
    return {
        name: "Default",
        variant: "dark",
        colors: {
            base00: "#1a1a1a",
            base01: "#2a2a2a",
            base02: "#3a3a3a",
            base03: "#4a4a4a",
            base04: "#5a5a5a",
            base05: "#bababa",
            base06: "#cacaca",
            base07: "#dadada",
            base08: "#ff6565",
            base09: "#ffb86c",
            base0A: "#f1fa8c",
            base0B: "#50fa7b",
            base0C: "#8be9fd",
            base0D: "#6272a4",
            base0E: "#bd93f9",
            base0F: "#ff79c6"
        },
        semantic: {
            background: "base00",
            backgroundAlt: "base01",
            backgroundHighlight: "base02",
            foreground: "base05",
            foregroundAlt: "base04",
            foregroundHighlight: "base06",
            foregroundInactive: "base03",
            border: "base03",
            borderFocus: "base0D",
            accent: "base0D",
            accentAlt: "base0E",
            success: "base0B",
            warning: "base0A",
            error: "base08",
            info: "base0C"
        }
    }
}

function saveConfig(config) {
    // This would need to be implemented with a proper backend
    // For now, just log the intention
    console.log("Saving config:", JSON.stringify(config, null, 2))
}
