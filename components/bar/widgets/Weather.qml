pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.components.hosts.popout

// Current conditions (from WeatherManager, for the Weather settings). Hovering opens a 5-day forecast.
BarIconWidget {
  id: root

  readonly property var source: WeatherManager.source
  Component.onCompleted: WeatherManager.acquire(root)
  Component.onDestruction: WeatherManager.release(root)

  readonly property var current: root.source.current
  readonly property var condition: root.source.condition

  icon: condition?.icon ?? "cloud"
  text: current ? `${Math.round(current.temperature_2m)}°` + (properties.showCondition ? ` ${condition.label}` : "") : "…"

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "WeatherForecast"
    active: root.properties.showPopout && root.source.weather !== null
  }
}
