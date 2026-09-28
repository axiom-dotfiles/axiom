import Quickshell

import qs.config
import qs.components.surfaces.wallpaper

// The built-in wallpaper backend: one background window per screen
Scope {
  Variants {
    model: Appearance.wallpaperBackend === "quickshell" ? Quickshell.screens : []
    delegate: WallpaperWindow {
      required property ShellScreen modelData
      screen: modelData
    }
  }
}
