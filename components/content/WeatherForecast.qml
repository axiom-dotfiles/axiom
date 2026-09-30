pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.config
import qs.services
import qs.components.reusable
import qs.components.content.base

// Current conditions and a 5-day forecast: the Weather widget's popout,
// from the same WeatherSource (the widget passes its request and keeps it
// acquired).
Panel {
  id: root

  // The widget's WeatherManager request, from its payload
  property var weatherRequest: null

  readonly property var source: root.weatherRequest ? WeatherManager.sourceFor(root.weatherRequest) : null
  readonly property var current: root.source?.current ?? null
  readonly property var condition: root.source?.condition ?? null
  readonly property var daily: root.source?.weather?.daily ?? null

  spacing: Widget.padding

  implicitWidth: Math.max(300, body.implicitWidth + margins * 2)

  StyledText {
    visible: text !== ""
    text: root.source?.place?.name ?? ""
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
        text: root.current ? `${Math.round(root.current.temperature_2m)}${root.source.unitSymbol}  ${root.condition?.label ?? ""}` : ""
        textSize: Appearance.fontSize * 1.3
        font.bold: true
      }
      StyledText {
        text: root.source?.details ?? ""
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 2
      }
    }
  }

  StyledSeparator {
    separatorColor: Theme.accent
    Layout.fillWidth: true
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Widget.padding

    Repeater {
      model: root.daily?.time?.length ?? 0

      ColumnLayout {
        id: day
        required property int index
        Layout.fillWidth: true
        spacing: 2

        StyledText {
          Layout.alignment: Qt.AlignHCenter
          text: root.source.dayLabel(day.index)
          textColor: Theme.foregroundAlt
          textSize: Appearance.fontSize - 2
        }
        StyledIcon {
          Layout.alignment: Qt.AlignHCenter
          text: root.source.conditionFor(root.daily.weather_code[day.index], 1).icon
          textSize: Appearance.fontSize * 1.5
        }
        StyledText {
          Layout.alignment: Qt.AlignHCenter
          text: `${Math.round(root.daily.temperature_2m_max[day.index])}° / ${Math.round(root.daily.temperature_2m_min[day.index])}°`
          textSize: Appearance.fontSize - 2
        }
      }
    }
  }
}
