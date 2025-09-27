pragma Singleton
import QtQuick
import "lib/ConfigLoader.js" as Loader

QtObject {
  property var configData: Loader.loadConfig()

  property bool enabled: configData.Chat.enabled ?? false
  property string defaultBackend: configData.Chat.defaultBackend ?? "gemini"
  property string currentBackend: defaultBackend
  property string defaultModel: configData.Chat.defaultModel ?? "gemini-2.5-pro"
  property string currentModel: defaultModel
  property var backends: configData.Chat.backends ?? null

  Component.onCompleted: {
    console.log("Chat configuration loaded:", JSON.stringify(configData.Chat));
  }
}

