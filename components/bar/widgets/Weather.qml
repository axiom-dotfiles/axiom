pragma ComponentBehavior: Bound
import QtQuick

import qs.services
import qs.components.hosts.popout

// Current conditions (from WeatherManager). Hovering opens a 5-day forecast.
BarIconWidget {
  id: root

  // From config only (acquire() must not follow live values)
  readonly property var weatherRequest: ({
      "latitude": root.properties.latitude,
      "longitude": root.properties.longitude,
      "location": root.properties.location,
      "units": root.properties.units,
      "intervalMinutes": root.properties.intervalMinutes
    })
  readonly property var source: WeatherManager.sourceFor(weatherRequest)
  onWeatherRequestChanged: WeatherManager.acquire(root, weatherRequest)
  Component.onCompleted: WeatherManager.acquire(root, weatherRequest)
  Component.onDestruction: WeatherManager.release(root)

  readonly property var current: source.current
  readonly property var condition: source.condition

  icon: condition?.icon ?? "cloud"
  text: current ? `${Math.round(current.temperature_2m)}°` + (properties.showCondition ? ` ${condition.label}` : "") : "…"

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "WeatherForecast"
    active: root.properties.showPopout && source.weather !== null
    extraData: ({
        "weather": source.weather,
        "placeName": source.place?.name ?? "",
        "unitSymbol": source.unitSymbol,
        "conditionFor": source.conditionFor
      })
  }
}
