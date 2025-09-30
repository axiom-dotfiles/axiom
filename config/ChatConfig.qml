pragma Singleton
import QtQuick

import qs.services

QtObject {
  property bool enabled: ConfigManager.config.ChatConfig.enabled ?? false
  property string defaultBackend: ConfigManager.config.ChatConfig.defaultBackend ?? "gemini"
  property string defaultModel: ConfigManager.config.ChatConfig.defaultModel ?? "gemini-2.5-pro"
  property var backends: ConfigManager.config.ChatConfig.backends ?? null
}

