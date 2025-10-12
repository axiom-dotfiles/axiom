pragma Singleton
import QtQuick

import qs.services

QtObject {
  property int distanceFromWorkspaceContainer: ConfigManager.config.Menu.distanceFromWorkspaceContainer ?? 10
  property bool startMenuPinned: ConfigManager.config.Menu.startMenuPinned ?? false
  property var views: ConfigManager.config.Menu.views ?? []

  property int cardUnit: ConfigManager.config.Menu.cardUnit ?? 200
  property int cardSpacing: ConfigManager.config.Menu.cardSpacing ?? 8
  property int cardPadding: ConfigManager.config.Menu.cardPadding ?? 8
  property int cardBorderRadius: ConfigManager.config.Menu.cardBorderRadius ?? 8
  property int cardBorderWidth: ConfigManager.config.Menu.cardBorderWidth ?? 1
  property int columns: ConfigManager.config.Menu.maxColumns ?? 4
}
