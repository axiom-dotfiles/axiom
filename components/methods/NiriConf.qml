pragma Singleton
import QtQuick

// niri's IPC requests the shell sends niri itself (NiriManager): monitor
// rules set now (docs/dev/compositor/niri-backend.md). axiom's config
// layer is the daemon's (internal/compositor/render).
QtObject {
  id: root

  // The connector a monitor rule's `output` names (a "desc:Make Model
  // Serial" is looked up in `details`, CompositorManager.withOutputDetails),
  // or "" when none is connected
  function connectorFor(output, details) {
    const value = String(output ?? "");
    if (!value.startsWith("desc:"))
      return value;
    const description = value.slice(5).trim();
    return (details ?? []).find(d => String(d.description ?? "").trim() === description)?.name ?? "";
  }

  // Monitor rules as niri's Output requests, to set them now; disabled
  // outputs last, so an output isn't turned off before another takes over
  function outputRequests(rules, details) {
    const sorted = (rules ?? []).filter(rule => !rule.disabled).concat((rules ?? []).filter(rule => rule.disabled));
    const requests = [];
    for (const rule of sorted) {
      const output = connectorFor(rule.output, details);
      if (output === "")
        continue;
      const send = action => requests.push({
          "Output": {
            "output": output,
            "action": action
          }
        });
      if (rule.disabled) {
        send("Off");
        continue;
      }
      send("On");
      const mode = MonitorLayout.parseMode(rule.mode);
      if (mode)
        send({
          "Mode": {
            "mode": {
              "Specific": {
                "width": mode.width,
                "height": mode.height,
                "refresh": mode.rate > 0 ? mode.rate : null
              }
            }
          }
        });
      send({
        "Scale": {
          "scale": {
            "Specific": Number(rule.scale ?? 1)
          }
        }
      });
      send({
        "Transform": {
          "transform": NiriState.transforms[rule.transform ?? 0] ?? "Normal"
        }
      });
      send({
        "Position": {
          "position": {
            "Specific": {
              "x": Math.round(rule.x ?? 0),
              "y": Math.round(rule.y ?? 0)
            }
          }
        }
      });
      send({
        "Vrr": {
          "vrr": {
            "vrr": (rule.vrr ?? 0) > 0,
            "on_demand": rule.vrr === 2
          }
        }
      });
    }
    return requests;
  }
}
