# Clocks and time zones

> **Files:** `services/TimeZoneManager.qml`, `components/methods/TimeZones.qml`, `components/content/Clock.qml`, `components/content/WorldClocks.qml`, `components/bar/widgets/Time.qml`
> **Config:** module/widget `timezone` properties (no section of its own)
> **Related:** [Services pattern](../core/services-pattern.md), [Schema annotations](../core/schema-annotations.md), [Desktop](desktop.md), [Utility modules](../overlay/utility-modules.md)

How clocks show another time zone (the JS engine has no Intl), plus the Clock module's styles.

### Why a service is needed
- The QML JS engine has no `Intl`, and ignores `toLocaleString`'s `timeZone`.
- So other zones' UTC offsets come from `TimeZoneManager`.

### TimeZoneManager
- Used by clocks set to another zone: a Clock module's or a Time widget's `timezone`.
- **`acquire(owner, zone)` / `release(owner)`:**
  - a `ConsumerRegistry`;
  - `zone` may be a list, as WorldClocks asks for.
- **Reading a zone:**
  - Each zone asked for is read with `TZ="$zone" date +%z`. The zone is passed as an argument, never inside the shell text.
  - One read serves all of that zone's clocks.
  - It reads again past every half hour UTC, when daylight saving can change.
  - Nothing is read when no clock asks.
- **`offsetOf(zone)`** is null, meaning the system's time:
  - until the zone has been read;
  - for a zone not in `zones`. `zones` is the system's list, from `tzdata.zi` or `timedatectl`; it is also the `timezones` option list. Without this check, `date` would quietly give UTC.
- **Display:** a clock shows `methods/TimeZones.shift(date, offset)`, whose local fields read as that zone's wall clock.

### Clock module (`content/Clock`)
- Works on every host (overlay, desktop, lock screen, greeter, edge menus).
- **`style`:**
  - **`digital`:** one line, with the seconds and AM/PM small beside it.
  - **`stacked`:** hours over minutes, the minutes in the accent color.
  - **`analog`:** marks and hands as rotated Items. The hands turn clockwise through 0 with a `RotationAnimation`.
- All styles are sized to the slot from the font's digit height (`capRatio`), so the lines sit tight on their baselines.
- The date and a `label` go under it.
- `timezone` is handled through TimeZoneManager.
- The bar `Time` widget takes a `timezone` the same way.

### Picking a zone
- Long option lists use `x-control: "search"`; the time zones are one.
- In `SchemaField` that is a typed `StyledComboEntry`, which takes only listed values.
- See [Schema annotations](../core/schema-annotations.md).
