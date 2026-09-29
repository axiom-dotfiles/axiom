pragma ComponentBehavior: Bound

import Quickshell
import QtQuick

import qs.config
import qs.components.hosts.popout

// Clock with a date, formatted for the shell's language (General.language:
// Japanese uses 午前/午後 and 時分秒 / 年月日); a custom `timeFormat` /
// `dateFormat` (Qt format strings) overrides that. On a vertical bar each
// is stacked into short lines.
Item {
  id: root

  property var barConfig
  property var popouts
  property var panel
  property var screen
  property var properties

  readonly property bool isVertical: barConfig.vertical
  readonly property bool japanese: I18n.language === "ja"
  readonly property bool use24Hour: properties.use24Hour
  readonly property bool showSeconds: properties.showSeconds
  readonly property bool showDate: properties.showDate
  readonly property color foregroundColor: Theme.resolveColor(properties.foregroundColor)

  readonly property int priority: 5

  implicitWidth: isVertical ? root.barConfig.widgetSize : (layoutLoader.item ? layoutLoader.item.implicitWidth + root.barConfig.widgetPadding * 2 : 0)
  implicitHeight: isVertical ? (layoutLoader.item ? layoutLoader.item.implicitHeight + root.barConfig.widgetPadding * 2 : 0) : root.barConfig.widgetSize

  SystemClock {
    id: clock
    precision: root.showSeconds || root.properties.timeFormat.includes("s") ? SystemClock.Seconds : SystemClock.Minutes
  }

  // AM/PM in the shell's language (午前/午後 in Japanese)
  function _meridiem(date) {
    return date.getHours() < 12 ? I18n.locale.amText : I18n.locale.pmText;
  }

  // One-line time and date, for a horizontal bar
  readonly property string timeText: {
    const date = clock.date;
    if (properties.timeFormat)
      return I18n.formatDate(date, properties.timeFormat);
    return I18n.formatDate(date, I18n.dateFormat((use24Hour ? "clock24" : "clock12") + (showSeconds ? "s" : "")));
  }
  readonly property string dateText: I18n.formatDate(clock.date, properties.dateFormat || I18n.dateFormat("mediumDate"))

  // Stacked lines for a vertical bar: [{ text, scale, bold, opacity }]
  readonly property var timeLines: {
    const date = clock.date;
    if (properties.timeFormat)
      return _split(timeText);
    if (japanese) {
      const lines = [];
      if (!use24Hour)
        lines.push(_line(_meridiem(date), 0.7, false, 0.9));
      // Number over its unit; the units are dictionary entries
      lines.push(_line(I18n.formatDate(date, use24Hour ? "H" : "h") + "\n" + I18n.tr("hour")));
      lines.push(_line(I18n.formatDate(date, "mm") + "\n" + I18n.tr("minute")));
      if (showSeconds)
        lines.push(_line(I18n.formatDate(date, "ss") + "\n" + I18n.tr("second")));
      return lines;
    }
    const lines = [_line(I18n.formatDate(date, use24Hour ? "HH" : "hh.ap").replace(/\.(am|pm)$/i, ""), 1.1, true), _line(I18n.formatDate(date, "mm"), 0.9, true)];
    if (showSeconds)
      lines.push(_line(I18n.formatDate(date, "ss"), 0.8, false, 0.8));
    if (!use24Hour)
      lines.push(_line(I18n.formatDate(date, "ap"), 0.7, false, 0.9));
    return lines;
  }
  readonly property var dateLines: {
    const date = clock.date;
    if (properties.dateFormat)
      return _split(dateText);
    if (japanese)
      return [_line(I18n.formatDate(date, "M") + "\n" + I18n.tr("month")), _line(I18n.formatDate(date, "d") + "\n" + I18n.tr("day")), _line(I18n.locale.dayName(date.getDay(), Locale.NarrowFormat))];
    return [_line(I18n.formatDate(date, "MMM"), 0.8), _line(I18n.formatDate(date, "dd"), 1.1, true), _line(I18n.formatDate(date, "ddd"), 0.7, false, 0.8)];
  }

  function _line(text, scale = 1, bold = false, opacity = 1) {
    return {
      "text": text,
      "scale": scale,
      "bold": bold,
      "opacity": opacity
    };
  }

  // A custom format's output, one word (or colon-separated field) per line
  function _split(text) {
    return text.split(/[\s:]+/).filter(part => part !== "").map(part => _line(part));
  }

  Rectangle {
    anchors.fill: parent
    color: Theme.resolveColor(root.properties.backgroundColor)
    radius: root.barConfig.radius
  }

  component ClockText: Text {
    color: root.foregroundColor
    font.family: Appearance.fontFamily
    font.pixelSize: root.barConfig.fontSize
  }

  component LineStack: Column {
    id: stack
    required property var lines
    spacing: root.japanese ? 2 : 0

    // Modelled by count, not by the line objects: those are rebuilt on
    // every clock tick, which would recreate the delegates each time
    Repeater {
      model: stack.lines.length

      delegate: ClockText {
        required property int index
        readonly property var line: stack.lines[index] ?? root._line("")
        x: Math.round((stack.width - width) / 2)
        horizontalAlignment: Text.AlignHCenter
        lineHeight: 0.9
        text: line.text
        font.pixelSize: root.barConfig.fontSize * line.scale
        font.bold: line.bold
        opacity: line.opacity
      }
    }
  }

  Loader {
    id: layoutLoader
    anchors.centerIn: parent
    sourceComponent: root.isVertical ? verticalComponent : horizontalComponent

    Component {
      id: horizontalComponent
      Row {
        spacing: root.barConfig.widgetSpacing * 2

        ClockText {
          text: root.dateText
          visible: root.showDate
        }

        Rectangle {
          width: 1
          height: root.barConfig.fontSize
          color: root.foregroundColor
          opacity: 0.5
          visible: root.showDate
          anchors.verticalCenter: parent.verticalCenter
        }

        ClockText {
          text: root.timeText
        }
      }
    }

    Component {
      id: verticalComponent
      Column {
        spacing: root.barConfig.widgetSpacing

        LineStack {
          lines: root.timeLines
          anchors.horizontalCenter: parent.horizontalCenter
        }

        Rectangle {
          width: parent.width * 0.6
          height: 1
          color: root.foregroundColor
          opacity: 0.3
          visible: root.showDate
          anchors.horizontalCenter: parent.horizontalCenter
        }

        LineStack {
          lines: root.dateLines
          visible: root.showDate
          anchors.horizontalCenter: parent.horizontalCenter
        }
      }
    }
  }

  PopoutAnchor {
    id: anchor
    popouts: root.popouts
    panel: root.panel
    popoutName: "Calendar"
    openDelay: 150
    active: root.properties.showCalendar
  }
}
