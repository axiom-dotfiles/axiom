pragma Singleton
import QtQuick

import qs.services

QtObject {
  property int distanceFromWorkspaceContainer: ConfigManager.config.Menu.distanceFromWorkspaceContainer ?? 10
  property bool startMenuPinned: ConfigManager.config.Menu.startMenuPinned ?? false
}
