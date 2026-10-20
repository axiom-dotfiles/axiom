# popouts
reviewed: e6137d2 2026-10-20  (full)

In good shape: the registry, the open/switch state machine, the stretch choreography and the pure helpers hold up, and the helpers are tested. After the fixes, every popout (FloatingPopout included) holds a claim, and the slide-under and submenu placement rules live in SurfaceContext with test rows. The next review should reread those fixes.

## Open findings
None.

## Contract
These hold:
- **Claims.** They register only while wanted and placed (edge popouts after `LayerOrigin.settled`, 400 ms timeout). Holders: BarPopouts, EdgePopout, FloatingPopout (`launcher:`/`switcher:<screen>`), SubPopout, DockWindow. A host shows only once `held`.
- **Resolve.** Ranks run pinned < dock < osd < bar < menu < launcher, and a submenu takes its parent's rank. Parent and child are exempt from each other. Residents yield and resume highest first, and a resuming claim is refused by an equal rank. A resident unpinned while away closes. A footprint change re-resolves through `update`.
- **Never moves.** `anchorRect` is taken only on a `currentData` change. The fullscreen and overlay `ClosedLatch`es follow only while closed. EdgePopout's dock-zone margin cancels the compositor's push.
- **Switching in place.** The latest payload wins while a grab is in flight. A switch calls off a close, a close during a switch defers the pending open, and `SwitchStill.end()` drops grabs in flight.
- **Mapping.** Content maps after `_payloadApplied` and `_layOut`. `wholeDepth` applies to horizontal and bottom/right bars, the peak across otherwise, and `roomForSubmenus` takes the screen's depth.
- **PillStretch.** It judges `ready` a turn late and latches it while open. Pushes go at the end of the pass, and BarContainer keeps each request part in its own map. `tracks` skips the Glide. `_slideLead` applies without `layerFrameSync`.
- **Parked cursor.** It arms only on the anchor's hover loss.
- **Tests.** SurfaceContext rules have tst rows (`joinsOf` is a passthrough to `EdgeAttach.joins`, which has rows). Every EdgeAttach function has rows.
- **Shadows.** Only through OutsideShadow, apart from FloatingPopout's documented copy behind its box. No literal durations, no `Quickshell.screens`, no compositor-name gating, and the UI Timers are one-shot.

## Coverage
Read deeply: BarPopouts, EdgePopout, EdgePlacement, PopoutWrapperBase, PopoutManager, PopoutClaim, PopoutGeometry, PillStretch, PillBarJoin, SubmenuHost, SwitchStill, ClosedLatch, LayerOrigin, PopoutAnchor, SubPopout (placement and lifetime), EdgeAttach (`place`/`_onPill`), BarContainer (`setRequest` and request maps).
Outlined: AttachedSurface, EdgeSurface, SubmenuSide, OutsideShadow, SurfaceShadow, SlideAnimation, FloatingPopout, StrokeOpening, SurfaceContext, SurfaceOutline, BarLayout, BarPanel, shell/OSD.
Skipped: scripts/dev/popout_matrix.py, content/SystemTray, parts/MenuSubmenu, AttachedSurface's drawing in depth. A next review should read AttachedSurface and SurfaceOutline deeply.

## History
- 2026-10-20 full: 6 findings (2 major, 2 cleanups, 2 minor); all six fixed (uncommitted at the time). One out-of-system problem recorded in issues.md (dangling screen object).
