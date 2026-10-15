pragma ComponentBehavior: Bound
import Quickshell.Hyprland

// Hyprland's focus grab, for surfaces that close (or drop keyboard focus)
// on a click outside them: while `active`, keyboard focus stays in
// `windows` and a click anywhere else ends the grab (`cleared`). Here so
// the surfaces name no compositor (HyprlandManager's comment). Not a
// singleton: each surface makes its own.
HyprlandFocusGrab {}
