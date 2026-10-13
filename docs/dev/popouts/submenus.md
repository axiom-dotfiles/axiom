# Submenus (one level deep)

> **Files:** `components/hosts/popout/SubPopout.qml`, `components/hosts/popout/SubmenuHost.qml`, `components/hosts/popout/SubmenuSide.qml`, `components/hosts/popout/BarPopouts.qml`, `components/hosts/popout/EdgePopout.qml`, `components/hosts/popout/AttachedSurface.qml`, `components/content/parts/MenuSubmenu.qml`, `components/content/SystemTray.qml`
> **Config:** none
> **Related:** [Hosts and switching](hosts-and-switching.md), [Edge attach](edge-attach.md), [Surface context](surface-context.md), [Registry](registry.md), [Edge menu submenus](../edge-menus/editing-submenus.md)

Every popout host can open one submenu beside its box. This doc covers how the submenu is placed, how it joins the parent's side, and what it hands back to the parent to draw.

### The submenu host
- **One per popout host:** every popout host owns one `hosts/popout/SubPopout` (`submenu`).
- **Opening one:** a `PopoutAnchor` in the host's content opens content in the submenu (`content/<name>.qml`, chosen by the payload's `name`).
  - Examples of such anchors: the tray's entries, an edge menu's modules.
  - The content is given `wrapper` and the payload's fields.
  - It opens beside the parent's box, level with what opened it.
- **Inside a submenu:** an anchor there replaces the submenu in place.
- **The parent's `SubmenuHost`** (the submenu's `slot`):
  - **What it exposes:** what the submenu attaches to, namely `attachBox`, the side's free and join ends, and `popupScreenOrigin`/`Placed`.
  - **What it takes back from the submenu:**
    - `submenuHole` and `submenuBox`, which the parent's `EdgeSurface` reads.
    - `submenuJoinSpan`, which the parent's `EdgePlacement` reads as `joinSpan`, together with `joinReach`, in its own coordinates.
    - Its `FrameNudge`, in the parent's `window`, redraws the hole as the submenu slides.
  - **What it asks back for:** `parentStretch`, drawn as `shownStretchTop`/`Bottom`.
- **Edge popouts:** an edge popout's box doesn't join or stretch for a submenu.
- **Same parent side for both parent kinds:** `BarPopouts` and `EdgePopout` each hold one `SubmenuHost`, and both expose:
  - `attachBox`
  - `side`: a `hosts/popout/SubmenuSide`, which has:
    - `joinTop`/`joinBottom`, `freeTop`/`freeBottom`
    - `growsUp`, and squared corners
    - `parentStretch`, drawn as `shownStretchTop`/`Bottom` with the corners it squares
    - `flushStart`/`EndThrough`
- **Reaching the pill:** a joined submenu's `joinReach` reaches the pill through `EdgeAttach.reachStretch`. Both go through `EdgePlacement.reach`.

### Lifetime
- **In PopoutManager:** the submenu is registered as its parent's.
- **Closing with the parent:** it closes with the parent. It also closes when the parent switches content, or gives way to a popout over it.
- **Keeping the parent up:** it keeps the parent open while it's open (`PopoutWrapperBase.childOpen`, from its `submenuHost`).
- **Closing with the pointer off the parent:** this takes the parent with it (`ownHovered`).
- **Tray cascade:** a submenu that closes with the pointer off both the tray menu and its icon (the pointer left, or an entry was picked) closes the menu at once (`content/SystemTray`). This is a cascade, not the menu's own dismiss delay after it.

### Position
- **Opening level with its anchor:** the anchor is measured inside the parent's box (the slot's `anchorOffsetOf(item)`, through `AttachedSurface.contentBox`). So one opened while the parent still slides out lands where the parent comes to rest.
- **Vertical limits:** it stays within the screen's room up and down, inside what's reserved at its top and bottom (`SubPopout.screenFrom`/`screenTo`).
- **Taller content:** content that may be taller (`parts/MenuSubmenu`) scrolls past `maxContentHeight`.
- **Where the stretch goes:**
  - **On a top or bottom edge** the stretch is across the box, so the window keeps that room from the start. A window growing while it shows is drawn for a frame with its old contents squeezed into the new size.
    - A horizontal bar's popout window takes the screen's whole depth (`BarPopouts.wholeDepth`).
    - An edge popout with `roomForSubmenus` (a floating menu holding a `Submenu` module) takes the screen's depth across its edge.
  - **On a side edge** it stretches along the edge, inside the window (`EdgePlacement`'s `aligned`/`contentLength`).

### Switching in place
- **Gliding between submenus:** another submenu of the same popout, whether a sibling item's or one drilled into, glides level with its item and resizes. Bar popouts do the same; see [Hosts and switching](hosts-and-switching.md#switching-in-place).
- **The popup:** it spans everywhere a submenu of that menu can sit (and keeps the largest size since it opened), masked to the surface.

### Placement along the parent's side
- **Placed like a bar popout along a pill:** `EdgeAttach.place` in pill mode, with the parent's box at rest and the slot's `attachBox` as the pill.
  - Its first item stays level with the hovered one, moved only to stay within reach or nudged (tray submenus use `nudge`; see [Edge attach](edge-attach.md#nudge-tray-submenus)).
- **No room for its fillet:** the side runs flush to a free end of the parent's side.
  - `side.freeTop`/`freeBottom` are its far edge's ends, plus its bar side too on a detached box.
  - The parent squares its corner there, and a detached box's near corner too (`AttachedSurface.startNearRadius`/`endNearRadius`).
- **At the bar side** of a solid bar's box, a pill's, an island's or a merged box, it joins the stroke the parent grows from instead.
  - The join is `side.joinTop`/`joinBottom` at `side.attachLine`, through `AttachedSurface.joinStart`/`joinEnd`. On a bare screen edge it runs straight.
  - This works the way a popout joins the perpendicular border.
  - Its window keeps no shadow room past that line.
- **Longer than the side:** the submenu stretches the parent's box past its far end.

### What the submenu hands back
- **`SubPopout.parentStretch`** is `{ top, bottom, squareTop, squareBottom, joinReach }`.
  - `BarPopouts` draws it: `shownStretchTop`/`Bottom`, the corner flags, and the window keeping room for it as it does for its box.
- **Meeting a pill, the way a bar popout does:**
  - A joined submenu keeps its outer fillet only where what it joins already reaches past it and past the corner beyond.
    - That reach is `side.strokeFrom`/`strokeTo`: the pill or island as the box stretches it, otherwise the bar's ends.
    - This is decided in `SubPopout.joinFillets`.
  - Otherwise its wall runs straight up (`straightJoins`) into the pill or island.
    - `BarPopouts.pillStretch` stretches that to the wall (`joinReach`, within the ends it may reach) and squares it there.
- **The parent's own wall:** while a submenu is joined, the parent's wall on that side, if it ran flush into the pill's end, stops at the attach edge instead of running on through the backfill (`AttachedSurface.flushStartThrough`/`flushEndThrough`). The stroke it continued now carries on under the submenu.
- **Covering the backfill row:** on a pill or island the submenu also covers the parent's backfill row beside it (`AttachedSurface.joinBackfill`, `side.backfill`).
  - That row is plain fill past its joined end, outside its shadowed outline, and its window keeps that row.
  - Without this, the parent's glow showed there as a dash.
- **Shadow:**
  - A submenu casts its parent's shadow look (`host.popupSurface`).
  - Unbacked, a parent's own shadow leaves out its submenu's box (`AttachedSurface.shadowHoles`, from `SubPopout`'s `submenuBox`).
  - See [Shadows](shadows.md).
