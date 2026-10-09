pragma Singleton
import QtQuick
import Quickshell
import qs.services

// Reader for the General section.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.General

  readonly property string displayName: _c.displayName || Quickshell.env("USER") || "user"
  // Monitor for the lockscreen input, launcher, power menu and overlay
  // Language for the shell's text, dates and clock (see I18n): "en" | "ja"
  readonly property string language: _c.language
  readonly property string primaryMonitor: _c.primaryMonitor || (root.outputs[0]?.name ?? "")
  // "primary" | "focused" | "all": where the power menu (and the overlay,
  // launcher and OSD, unless their own `monitors` says otherwise) appear:
  // the primary monitor, the focused one, or every monitor at once (see
  // ShellManager.showsOn). The workspace overview is on every screen.
  readonly property string monitors: _c.monitors
  // The connected monitors: Quickshell.screens without the stand-ins shown
  // while none is (Qt's nameless placeholder, Hyprland's headless FALLBACK).
  // Surfaces are built only on these: a window left on a stand-in when the
  // monitors come back is moved off a screen Qt then frees, which can crash qs.
  readonly property var outputs: Array.from(Quickshell.screens).filter(s => s.name !== "" && s.name !== "FALLBACK")
  // The screens they're built on
  readonly property var screens: root.monitors === "primary" ? root.screensNamed(root.primaryMonitor) : root.outputs

  // The screen named `name` (as a one-screen list), else the primary
  // monitor, else the first screen
  function screensNamed(name) {
    const all = root.outputs;
    const named = all.filter(s => s.name === name);
    if (named.length > 0)
      return named;
    const primary = all.filter(s => s.name === root.primaryMonitor);
    return primary.length > 0 ? primary : all.slice(0, 1);
  }

  // The screens a surface with its own `monitors` setting is built on:
  // "general" (the above) | "primary" (the primary monitor) | "focused"
  // (every screen, opening on the focused one) | "all" (every screen,
  // opening on all of them) | "monitor" (the one named `name`, else the
  // primary monitor)
  function screensFor(mode, name) {
    const all = root.outputs;
    if (mode === "focused" || mode === "all")
      return all;
    if (mode === "primary")
      return root.screensNamed(root.primaryMonitor);
    if (mode === "monitor")
      return root.screensNamed(name ?? "");
    return root.screens;
  }
}
