pragma Singleton
import QtQuick

// Sway's config and command text from axiom's settings (SwayManager,
// SwayConfigWriter), as HyprLua/HyprConfigLua are for Hyprland
// (docs/dev/compositor/sway-backend.md).
QtObject {
  id: root

  // A string as one argument of a sway command: quoted when it holds
  // anything but plain word characters
  function quote(text) {
    const value = String(text ?? "");
    return /^[A-Za-z0-9_.:+\-\/]+$/.test(value) ? value : `"${value.replace(/\\/g, "\\\\").replace(/"/g, "\\\"")}"`;
  }

  // Sway's output names for Wayland's transforms 0-7
  readonly property var transforms: ["normal", "90", "180", "270", "flipped", "flipped-90", "flipped-180", "flipped-270"]

  // How sway names a monitor rule's output: a description ("desc:Make Model
  // Serial") is sway's own identifier for it, quoted
  function outputName(output) {
    const value = String(output ?? "");
    return quote(value.startsWith("desc:") ? value.slice(5).trim() : value);
  }

  // A monitor rule (the MonitorRule schema) as one `output` command. Sway
  // has no mirroring, color management or SDR settings: those are left out
  // (supports.monitorMirror / monitorColor are off). A "preferred" mode
  // leaves the mode as it is.
  function outputCommand(rule) {
    const name = outputName(rule.output);
    if (rule.disabled)
      return `output ${name} disable`;
    const parts = [`output ${name} enable`];
    const mode = String(rule.mode ?? "");
    if (mode !== "" && mode !== "preferred")
      parts.push("mode " + (/@[\d.]+$/.test(mode) ? mode + "Hz" : mode));
    parts.push(`pos ${Math.round(rule.x ?? 0)} ${Math.round(rule.y ?? 0)}`);
    parts.push(`scale ${rule.scale ?? 1}`);
    parts.push("transform " + (transforms[rule.transform ?? 0] ?? "normal"));
    parts.push("adaptive_sync " + ((rule.vrr ?? 0) > 0 ? "on" : "off"));
    if (rule.bitdepth === 10)
      parts.push("render_bit_depth 10");
    return parts.join(" ");
  }

  // Every rule's command, as one command line sway runs in order (disabled
  // outputs last, so an output isn't turned off before another takes over)
  function outputCommands(rules) {
    const sorted = (rules ?? []).filter(rule => !rule.disabled).concat((rules ?? []).filter(rule => rule.disabled));
    return sorted.map(rule => outputCommand(rule)).join("; ");
  }
}
