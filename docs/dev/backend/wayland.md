# Wayland protocols per compositor

> **Files:** `backend/internal/wayland/wire/`, `tests/fixtures/wayland/`
> **Related:** [The axiom binary](README.md), [Compositor contract](../compositor/contract.md)

What each compositor offers, for planning what the daemon does over its own Wayland connection (branch 2: idle, gamma, clipboard, typing). `axiom debug wayland-globals [--json]` lists a running compositor's globals. The captures are in `tests/fixtures/wayland/globals-<compositor>.json`:
- Hyprland 0.55: the live session.
- sway 1.12 (SwayFX 0.6): headless (`WLR_BACKENDS=headless`).
- niri 26.04: nested in a window (its winit backend).

A nested or headless compositor has no real outputs, so protocols tied to outputs can be missing there that a session on a TTY offers. Check niri's gamma and output power on a real niri session before relying on them being absent.

| Protocol | For | Hyprland | sway | niri |
|---|---|---|---|---|
| `ext_idle_notifier_v1` | idle (replace hypridle) | v2 | v2 | v2 |
| `zwp_idle_inhibit_manager_v1` | idle inhibit | v1 | v1 | v1 |
| `ext_session_lock_manager_v1` | lock screen | v1 | v1 | v1 |
| `zwlr_gamma_control_manager_v1` | night light (gamma) | v1 | v1 | — |
| `hyprland_ctm_control_manager_v1` | night light (CTM) | v2 | — | — |
| `ext_data_control_manager_v1` | clipboard (ext) | v1 | v1 | v1 |
| `zwlr_data_control_manager_v1` | clipboard (wlr) | v2 | v2 | v2 |
| `zwp_virtual_keyboard_manager_v1` | typing (replace wtype) | v1 | v1 | v1 |
| `ext_image_copy_capture_manager_v1` | screen capture (ext) | v1 | v1 | — |
| `zwlr_screencopy_manager_v1` | screen capture (wlr) | v3 | v3 | v3 |
| `zwlr_output_power_manager_v1` | DPMS | v1 | v1 | — |
| `zwlr_foreign_toplevel_manager_v1` | window list (wlr) | v3 | v3 | v3 |
| `ext_foreign_toplevel_list_v1` | window list (ext) | v1 | v1 | v1 |
| `ext_workspace_manager_v1` | workspaces (ext) | v1 | v1 | v1 |
| `zwlr_output_manager_v1` | output config | v4 | v4 | v4 |
| `wp_security_context_manager_v1` | security context | v1 | v1 | v1 |

### What it means for branch 2
- **Idle:** `ext_idle_notifier_v1` everywhere, so the daemon can replace hypridle on all three, with inhibitors (`zwp_idle_inhibit_manager_v1`) respected by the compositor.
- **Clipboard:** `ext_data_control_manager_v1` everywhere, with `zwlr_data_control` as the fallback. In-memory history can replace `wl-paste --watch` and cliphist.
- **Typing:** `zwp_virtual_keyboard_manager_v1` everywhere, so `wtype` can go.
- **Night light:**
  - `zwlr_gamma_control` on Hyprland and sway; Hyprland also has CTM, which hyprsunset uses.
  - niri (nested) shows neither, so until a TTY session proves otherwise, niri keeps wlsunset, or night light is unavailable there.
