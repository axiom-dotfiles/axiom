pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.components.reusable
import qs.components.content.base

// Current conditions and a 5-day forecast. Filled from the Weather widget's
// PopoutAnchor payload (the Open-Meteo response plus its WMO code lookup).
Panel {
  id: root

  property var weather: null
  property string placeName: ""
  property string unitSymbol: "°C"
  property var conditionFor: null

  readonly property var current: weather?.current ?? null
  readonly property var condition: current && conditionFor ? conditionFor(current.weather_code, current.is_day) : null
  readonly property var days: {
    const daily = weather?.daily;
    if (!daily || !conditionFor)
      return [];
    return daily.time.map((date, i) => ({
          "label": i === 0 ? I18n.tr("Today") : I18n.formatDate(new Date(date + "T12:00"), "ddd"),
          "icon": conditionFor(daily.weather_code[i], 1).icon,
          "max": Math.round(daily.temperature_2m_max[i]),
          "min": Math.round(daily.temperature_2m_min[i])
        }));
  }

  spacing: Widget.padding

  implicitWidth: Math.max(300, body.implicitWidth + margins * 2)

  StyledText {
    visible: root.placeName !== ""
    text: root.placeName
    font.bold: true
    textColor: Theme.accent
  }

  RowLayout {
    spacing: Widget.padding * 1.5

    StyledIcon {
      text: root.condition?.icon ?? ""
      textSize: Appearance.fontSize * 3
    }

    ColumnLayout {
      spacing: 2

      StyledText {
        text: root.current ? `${Math.round(root.current.temperature_2m)}${root.unitSymbol}  ${root.condition.label}` : ""
        textSize: Appearance.fontSize * 1.3
        font.bold: true
      }
      StyledText {
        text: root.current ? I18n.tr("Feels like {0}°  ·  {1}% humidity  ·  {2} {3}", Math.round(root.current.apparent_temperature), root.current.relative_humidity_2m, Math.round(root.current.wind_speed_10m), root.weather.current_units?.wind_speed_10m ?? "km/h") : ""
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 2
      }
    }
  }

  StyledSeparator {
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Widget.padding

    Repeater {
      model: root.days

      ColumnLayout {
        id: day
        required property var modelData
        Layout.fillWidth: true
        spacing: 2

        StyledText {
          Layout.alignment: Qt.AlignHCenter
          text: day.modelData.label
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
        }
        StyledIcon {
          Layout.alignment: Qt.AlignHCenter
          text: day.modelData.icon
          textSize: Appearance.fontSize * 1.5
        }
        StyledText {
          Layout.alignment: Qt.AlignHCenter
          text: `${day.modelData.max}° / ${day.modelData.min}°`
          textSize: Appearance.fontSize - 2
        }
      }
    }
  }
}
