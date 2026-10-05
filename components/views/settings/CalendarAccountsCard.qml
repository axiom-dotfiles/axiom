pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.forms
import qs.components.methods
import qs.components.reusable

// The Calendar section's first card (its `x-card`): the accounts as tabs,
// one shown at a time: its address and username, its password (to the
// keyring, or the secrets file without one: never the settings draft or
// config.json), Connect, which finds its calendars, and the calendars, each
// shown or hidden, with its color and the one new events go to. Account
// and calendar edits go through the settings draft like any other row.
FoldingCard {
  id: root

  // The settings group key it folds under, from SettingsContent
  property string foldKey

  readonly property var accountSchema: ConfigManager.configSchema.definitions.CalendarAccount
  readonly property var accounts: SettingsManager.localConfig?.Calendar?.accounts ?? CalendarConfig.savedAccounts
  readonly property string defaultCalendar: SettingsManager.localConfig?.Calendar?.defaultCalendar ?? CalendarConfig.defaultCalendar
  property int selected: 0
  readonly property int current: Math.max(0, Math.min(root.selected, root.accounts.length - 1))
  readonly property var account: root.accounts[root.current] ?? null
  // The shown account's id as the reader fills it in (numbered when empty)
  readonly property string accountId: root.account ? (root.account.id || "account-" + (root.current + 1)) : ""
  readonly property string passwordStatus: root.accountId ? SecretsManager.secretStatus("calendar", root.accountId) : ""

  // Connect's state: { busy, ok, text }
  property var result: null
  property bool confirmRemove: false
  // False once destroyed, for callbacks that outlive the card
  property bool _alive: true
  Component.onDestruction: root._alive = false

  title: I18n.tr("Accounts")
  description: CalendarManager.available ? "" : I18n.tr("The calendar helper couldn't run (it needs python3 and pip, and the network the first time).")
  collapsed: SettingsManager.isCollapsed(root.foldKey)
  onToggled: SettingsManager.setCollapsed(root.foldKey, !root.collapsed)
  onCurrentChanged: {
    root.result = null;
    root.confirmRemove = false;
  }

  // Passwords may have changed outside the shell (secret-tool, the file)
  Component.onCompleted: SecretsManager.refreshSecrets("calendar", CalendarConfig.accounts.map(account => account.id))

  function _commit(accounts) {
    SettingsManager.setValue(["Calendar", "accounts"], accounts);
  }

  // Merges `values` into the shown account
  function edit(values) {
    const accounts = Utils.clone(root.accounts);
    Object.assign(accounts[root.current], values);
    root._commit(accounts);
  }

  function add() {
    const accounts = Utils.clone(root.accounts);
    accounts.push(SchemaValidation.applyDefaults({
      "id": Utils.freeId("account", accounts.map((account, index) => account.id || "account-" + (index + 1)))
    }, root.accountSchema, ConfigManager.configSchema));
    root._commit(accounts);
    root.selected = accounts.length - 1;
  }

  function remove() {
    if (!root.confirmRemove) {
      root.confirmRemove = true;
      return;
    }
    SecretsManager.clearSecret("calendar", root.accountId);
    const accounts = Utils.clone(root.accounts);
    accounts.splice(root.current, 1);
    root._commit(accounts);
    root.selected = Math.max(0, root.current - 1);
    root.confirmRemove = false;
  }

  // A provider's address, filled in when it's picked over an empty one or
  // another provider's
  readonly property var presetUrls: ({
      "icloud": "https://caldav.icloud.com",
      "fastmail": "https://caldav.fastmail.com",
      "nextcloud": ""
    })
  function _edited(path, value) {
    const values = {
      [path[0]]: value
    };
    if (path[0] === "preset") {
      const url = root.account.url ?? "";
      if (url === "" || Object.values(root.presetUrls).includes(url))
        values.url = root.presetUrls[value] ?? url;
    }
    root.edit(values);
  }

  // Finds the account's calendars and merges them in: new ones holding
  // events come in shown; ones the server no longer lists go
  function connect() {
    const account = Object.assign({}, root.account, {
      "id": root.accountId
    });
    const index = root.current;
    root.result = {
      "busy": true,
      "ok": false,
      "text": ""
    };
    CalendarManager.discover(account, null, result => {
      if (!root || !root._alive)
        return;
      if (!result.ok) {
        root.result = {
          "busy": false,
          "ok": false,
          "text": CalendarManager.errorText(result)
        };
        return;
      }
      const accounts = Utils.clone(root.accounts);
      const old = accounts[index]?.calendars ?? [];
      if (!accounts[index])
        return;
      accounts[index].id = account.id;
      accounts[index].calendars = result.calendars.map(found => {
        const known = old.find(calendar => calendar.href === found.href);
        return {
          "href": found.href,
          "name": found.name,
          "serverColor": found.color,
          "color": known?.color ?? "",
          "enabled": known?.enabled ?? found.components.includes("VEVENT"),
          "readOnly": found.readOnly,
          "components": found.components
        };
      });
      root._commit(accounts);
      const events = accounts[index].calendars.filter(calendar => calendar.components.includes("VEVENT")).length;
      root.result = {
        "busy": false,
        "ok": true,
        "text": I18n.tr("Found {0} calendars", events)
      };
    });
  }

  function setCalendar(href, values) {
    const accounts = Utils.clone(root.accounts);
    const calendar = accounts[root.current].calendars.find(c => c.href === href);
    Object.assign(calendar, values);
    root._commit(accounts);
  }

  headerExtras: StyledTextButton {
    implicitHeight: Widget.height - 4
    iconText: "add"
    text: I18n.tr("Add")
    onClicked: root.add()
  }

  StyledText {
    visible: root.accounts.length === 0
    Layout.fillWidth: true
    text: I18n.tr("No accounts yet. Add one for a CalDAV server (iCloud, Fastmail, Nextcloud, …) or an .ics subscription.")
    textColor: Theme.foregroundAlt
    wrapMode: Text.WordWrap
  }

  // One tab per account
  Flow {
    visible: root.accounts.length > 0
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    Repeater {
      model: root.accounts.length

      delegate: SegmentButton {
        id: tab
        required property int index
        readonly property var entry: root.accounts[tab.index]

        implicitHeight: Widget.height - 4
        text: tab.entry.name || tab.entry.username || CalendarConfig.hostOf(tab.entry.url) || I18n.tr("Account {0}", tab.index + 1)
        active: tab.index === root.current
        onClicked: root.selected = tab.index
      }
    }
  }

  SchemaPropertiesForm {
    visible: root.account !== null
    Layout.fillWidth: true
    propertiesSchema: root.accountSchema.properties
    order: root.accountSchema["x-order"] ?? []
    values: root.account ?? ({})
    onEdited: (path, value) => root._edited(path, value)
  }

  StyledText {
    visible: root.account?.kind === "caldav" && root.account?.preset === "icloud"
    Layout.fillWidth: true
    text: I18n.tr("iCloud needs an app-specific password: make one at account.apple.com (Sign-In and Security → App-Specific Passwords). Your username is your Apple Account's email.")
    textColor: Theme.foregroundAlt
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
  }

  // The password, never in the draft
  RowLayout {
    visible: root.account?.kind === "caldav"
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    StyledText {
      text: I18n.tr("Password")
    }
    StyledTextEntry {
      id: passwordField
      Layout.fillWidth: true
      Layout.preferredHeight: Widget.height
      placeholderText: root.passwordStatus === "keyring" || root.passwordStatus === "file" ? I18n.tr("Type a new one to replace it") : I18n.tr("The account's password")
      input.echoMode: TextInput.Password
      onAccepted: savePassword.clicked()
    }
    StyledTextButton {
      id: savePassword
      implicitHeight: Widget.height
      visible: passwordField.text !== ""
      text: I18n.tr("Save")
      backgroundColor: Theme.accent
      textColor: Theme.background
      onClicked: {
        SecretsManager.setSecret("calendar", root.accountId, I18n.tr("{0} calendar", root.account.name || CalendarConfig.hostOf(root.account.url)), passwordField.text);
        passwordField.text = "";
      }
    }
    StatusChip {
      color: root.passwordStatus === "keyring" || root.passwordStatus === "file" ? Theme.success : root.passwordStatus === "none" ? Theme.warning : Theme.foregroundAlt
      text: root.passwordStatus === "keyring" ? I18n.tr("In keyring") : root.passwordStatus === "file" ? I18n.tr("In secrets file") : root.passwordStatus === "none" ? I18n.tr("No password") : I18n.tr("Checking…")
    }
  }

  RowLayout {
    visible: root.account !== null
    Layout.fillWidth: true
    spacing: Widget.spacing / 2

    StyledText {
      Layout.fillWidth: true
      text: root.result?.busy ? I18n.tr("Connecting…") : root.result?.text ?? ""
      textColor: root.result?.busy ? Theme.foregroundAlt : root.result?.ok ? Theme.success : Theme.error
      textSize: Appearance.fontSize - 2
      wrapMode: Text.Wrap
    }
    StyledTextButton {
      implicitHeight: Widget.height - 4
      enabled: !root.result?.busy && (root.account?.url ?? "") !== ""
      iconText: "sync"
      text: (root.account?.calendars ?? []).length > 0 ? I18n.tr("Refresh calendars") : I18n.tr("Connect")
      onClicked: root.connect()
    }
    StyledTextButton {
      implicitHeight: Widget.height - 4
      iconText: "delete"
      text: root.confirmRemove ? I18n.tr("Click again to remove") : I18n.tr("Remove")
      hoverColor: Theme.error
      onClicked: root.remove()
    }
  }

  // The account's calendars
  StyledSeparator {
    separatorColor: Theme.accent
    visible: (root.account?.calendars ?? []).length > 0
    Layout.fillWidth: true
  }

  Repeater {
    model: (root.account?.calendars ?? []).length

    delegate: RowLayout {
      id: calendarRow
      required property int index
      readonly property var calendar: root.account.calendars[index] ?? ({})
      readonly property string calendarId: root.accountId + "|" + calendarRow.calendar.href
      readonly property bool holdsEvents: (calendarRow.calendar.components ?? []).includes("VEVENT")

      // Lists without events (iCloud's reminders) wait for to-dos
      visible: calendarRow.holdsEvents
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledSwitch {
        checked: calendarRow.calendar.enabled ?? false
        onToggled: root.setCalendar(calendarRow.calendar.href, {
          "enabled": checked
        })
      }
      Rectangle {
        Layout.preferredWidth: Appearance.fontSize * 0.8
        Layout.preferredHeight: width
        radius: width / 2
        color: calendarRow.calendar.color ? Theme.resolveColor(calendarRow.calendar.color) : (calendarRow.calendar.serverColor || Theme.accent)
      }
      StyledText {
        Layout.fillWidth: true
        text: calendarRow.calendar.name || calendarRow.calendar.href
        textFormat: Text.PlainText
        elide: Text.ElideRight
      }
      StatusChip {
        visible: calendarRow.calendar.readOnly ?? false
        color: Theme.foregroundAlt
        text: I18n.tr("Read-only")
      }
      SegmentButton {
        visible: !(calendarRow.calendar.readOnly ?? false) && root.account.kind === "caldav"
        Layout.fillWidth: false
        implicitHeight: Widget.height - 6
        text: I18n.tr("Default")
        active: root.defaultCalendar === calendarRow.calendarId
        onClicked: SettingsManager.setValue(["Calendar", "defaultCalendar"], active ? "" : calendarRow.calendarId)
      }
      StyledComboEntry {
        Layout.preferredWidth: Appearance.fontSize * 11
        icon: "palette"
        options: [
          {
            "value": "",
            "label": I18n.tr("Server color")
          }
        ].concat(Theme.baseColorNames.map(name => ({
              "value": name,
              "label": name
            })))
        value: calendarRow.calendar.color ?? ""
        onPicked: value => root.setCalendar(calendarRow.calendar.href, {
            "color": value
          })
      }
    }
  }

  StyledText {
    visible: (root.account?.calendars ?? []).some(calendar => !(calendar.components ?? []).includes("VEVENT"))
    Layout.fillWidth: true
    text: I18n.tr("Task lists (such as iCloud's reminders) aren't shown yet.")
    opacity: 0.6
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
  }
}
