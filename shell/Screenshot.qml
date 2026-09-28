pragma ComponentBehavior: Bound
import Quickshell

import qs.components.surfaces.screenshot
import qs.services

// The screenshot picker while ScreenshotManager is picking: on every screen
// for a region (each frozen, so nothing moves), only on the captured screen
// for an immediate `window` / `screen` shot
Scope {
  Variants {
    model: Quickshell.screens

    LazyLoader {
      id: loader
      required property ShellScreen modelData
      active: ScreenshotManager.picking && (ScreenshotManager.request?.kind === "region" || ScreenshotManager.request?.screen === modelData.name)

      ScreenshotPickerWindow {
        screen: loader.modelData
      }
    }
  }
}
