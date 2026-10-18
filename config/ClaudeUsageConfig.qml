pragma Singleton
import QtQuick
import qs.services

// Reader for the ClaudeUsage section: the Claude Code logins every Claude
// usage widget reports on (see ClaudeUsageManager).
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.ClaudeUsage

  // [{ label, configDir }], configDir as typed (may hold ~)
  readonly property var accounts: _c.accounts
  readonly property int intervalMinutes: _c.intervalMinutes
}
