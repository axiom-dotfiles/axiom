pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Effects

import qs.config

// The shell's shadow or glow (the BarStyle section's, as the bars and the
// border cast it), as a layer effect for a surface with an exposed border:
// popouts, edge popouts (OSDs, edge menus, the launcher), docks, floating
// popouts. A free-standing surface's shadow falls away from the edge it
// grows out of (`edge`, a Bar.Location; -1 for none: it falls downward); a
// surface joined to the border or a bar (`falls` false) casts it evenly, as
// the border does, since a shadow shifted along a stroke it joins would
// cover that stroke. A glow always spreads evenly. Windows keep
// BarStyle.shadowReach of room past the surface for it.
MultiEffect {
  property int edge: -1
  property bool falls: true

  readonly property var look: BarStyle.values
  readonly property real offset: look.shadow === "glow" || !falls ? 0 : look.shadowSize / 4

  shadowEnabled: look.shadow !== "none"
  shadowColor: Bar.shadowColor(look)
  shadowBlur: 1
  blurMax: look.shadowSize
  shadowHorizontalOffset: edge === Bar.Left ? offset : edge === Bar.Right ? -offset : 0
  shadowVerticalOffset: edge === Bar.Bottom ? -offset : edge === Bar.Left || edge === Bar.Right ? 0 : offset
}
