pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.services
import qs.components.methods
import qs.components.hosts.popout

// The next event within `lookahead` minutes (or the one under way): "in 10
// min · Standup", "now · Standup", "15:00 · Dentist". Hidden with none.
// Hovering opens the calendar; a click opens the Calendar page on its day.
BarIconWidget {
  id: root

  Component.onCompleted: CalendarManager.acquire(root)
  Component.onDestruction: CalendarManager.release(root)

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
  readonly property real now: clock.date.getTime()
  readonly property real lookahead: root.properties.lookahead * 60000
  readonly property var event: CalendarEvents.nextEvent(CalendarManager.upcoming(root.now, root.now + root.lookahead, root.properties.showAllDay), root.now, root.lookahead, root.properties.showAllDay)
  readonly property int minutesAway: root.event ? Math.ceil((root.event.start - root.now) / 60000) : 0

  readonly property string when: {
    if (!root.event)
      return "";
    if (root.event.allDay)
      return I18n.tr("Today");
    if (root.minutesAway <= 0)
      return I18n.tr("now");
    if (root.minutesAway < 60)
      return I18n.tr("in {0} min", root.minutesAway);
    return I18n.formatDate(new Date(root.event.start), CalendarConfig.timeFormat);
  }

  hidden: root.event === null
  icon: "event"
  text: root.event ? I18n.tr("{0} · {1}", root.when, Utils.truncate(root.event.title || I18n.tr("(No title)"), root.properties.maxLength, "…")) : ""
  // Soon (a quarter hour or less): the warning color
  accentColor: root.event && !root.event.allDay && root.minutesAway <= 15 ? Theme.warning : Theme.resolveColor(properties.backgroundColor)

  clickable: true
  onClicked: CalendarManager.openPage({
    "kind": "day",
    "key": CalendarEvents.dayKey(root.event ? root.event.start : root.now)
  })

  PopoutAnchor {
    popouts: root.popouts
    panel: root.panel
    popoutName: "Calendar"
    openDelay: 150
    active: root.properties.showPopout
  }
}
