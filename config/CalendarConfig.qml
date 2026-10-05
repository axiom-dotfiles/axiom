pragma Singleton
import QtQuick
import qs.services

// Reader for the Calendar section (see CalendarManager). Account passwords
// are not config: see SecretsManager.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Calendar

  // Calendar.accounts as saved, for editing
  readonly property var savedAccounts: _c.accounts
  // Calendar.accounts, each with an `id` (numbered when left empty) and a
  // `name` (the username or the server's host when left empty)
  readonly property var accounts: _c.accounts.map((account, index) => Object.assign({}, account, {
      "id": account.id || "account-" + (index + 1),
      "name": account.name || account.username || root.hostOf(account.url) || I18n.tr("Account {0}", index + 1)
    }))
  // Every account's calendars, flattened: { id ("<account>|<href>"),
  // account, accountName, kind, href, name, color (the override, else the
  // server's, else the accent), enabled, readOnly, events (it holds
  // events), writable }
  readonly property var calendars: [].concat(...root.accounts.map(account => account.calendars.map(calendar => ({
          "id": account.id + "|" + calendar.href,
          "account": account.id,
          "accountName": account.name,
          "kind": account.kind,
          "href": calendar.href,
          "name": calendar.name || calendar.href,
          "color": String(calendar.color ? Theme.resolveColor(calendar.color) : (calendar.serverColor || Theme.accent)),
          "enabled": calendar.enabled,
          "readOnly": account.kind !== "caldav" || calendar.readOnly,
          "events": calendar.components.includes("VEVENT"),
          "writable": account.kind === "caldav" && !calendar.readOnly && calendar.components.includes("VEVENT")
        }))))
  // The calendars shown, and those of them new events can go to
  readonly property var shownCalendars: root.calendars.filter(calendar => calendar.enabled && calendar.events)
  readonly property var writableCalendars: root.shownCalendars.filter(calendar => calendar.writable)
  // Where a new event goes: the default calendar while it's shown and
  // writable, else the first that is ("" with none)
  readonly property string newEventCalendar: (root.writableCalendars.find(calendar => calendar.id === root.defaultCalendar) ?? root.writableCalendars[0])?.id ?? ""
  // calendar id -> its color, for the views
  readonly property var colors: root.calendars.reduce((map, calendar) => {
    map[calendar.id] = calendar.color;
    return map;
  }, {})

  readonly property string defaultCalendar: _c.defaultCalendar
  // Minutes
  readonly property int defaultDuration: _c.defaultDuration
  // Minutes before the start, -1 for none
  readonly property int defaultReminder: _c.defaultReminder
  readonly property bool reminders: _c.reminders
  // Minutes
  readonly property int syncInterval: _c.syncInterval
  readonly property int pastMonths: _c.pastMonths
  readonly property int futureMonths: _c.futureMonths
  readonly property int maxDots: _c.maxDots
  // The Clock & calendar module's events on the lock screen too
  readonly property bool showOnLockscreen: _c.showOnLockscreen
  readonly property bool use24Hour: _c.use24Hour
  // The language's time format, for event times
  readonly property string timeFormat: I18n.dateFormat(root.use24Hour ? "time24" : "time12")

  function calendar(id) {
    return root.calendars.find(calendar => calendar.id === id) ?? null;
  }

  function hostOf(url) {
    const match = String(url ?? "").match(/^[a-z]+:\/\/([^/:]+)/i);
    return match ? match[1] : "";
  }
}
