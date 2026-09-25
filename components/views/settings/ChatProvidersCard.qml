pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import qs.components.methods
import qs.components.reusable

// The Chat category's first card (the section's `x-card`): each provider's
// API key (where it comes from, and a field to store one: in the keyring,
// or the secrets file without one), a connection test, and fetching its
// model list. Keys never go through the settings draft or config.json.
StyledContainer {
  id: root

  implicitHeight: column.implicitHeight + Widget.padding * 2
  backgroundColor: Theme.backgroundAlt

  // One request at a time per provider: { providerId: { busy, ok, text } }
  property var results: ({})

  function _setResult(id, result) {
    const next = Object.assign({}, root.results);
    next[id] = result;
    root.results = next;
  }

  // Lists the provider's models: a test of address and key both. With
  // `store`, the list replaces the provider's models in the settings draft
  // (saved with the page's Save).
  function fetchModels(provider, store) {
    if (root.results[provider.id]?.busy)
      return;
    root._setResult(provider.id, {
      busy: true,
      ok: false,
      text: ""
    });
    SecretsManager.withKey(provider, key => {
      if (provider.auth !== "none" && !key) {
        root._setResult(provider.id, {
          busy: false,
          ok: false,
          text: I18n.tr("No API key")
        });
        return;
      }
      const request = requestComponent.createObject(root, {
        kind: provider.kind
      });
      request.finished.connect((state, body) => {
        const ids = ChatProtocol.parseModels(provider.kind, body);
        request.destroy();
        if (ids === null) {
          root._setResult(provider.id, {
            busy: false,
            ok: false,
            text: I18n.tr("That address didn't answer like a {0} API.", provider.kind)
          });
          return;
        }
        const models = ChatProtocol.chatModels(provider, ids);
        if (store && models.length > 0)
          root._storeModels(provider, models);
        root._setResult(provider.id, {
          busy: false,
          ok: true,
          text: store ? I18n.tr("{0} models listed: Save to keep them", models.length) : I18n.tr("Connected: {0} models", models.length)
        });
      });
      request.failed.connect((status, message) => {
        request.destroy();
        root._setResult(provider.id, {
          busy: false,
          ok: false,
          text: status > 0 ? `${status}: ${message}` : message
        });
      });
      request.start(ChatProtocol.modelsRequest(provider, key), "");
    });
  }

  function _storeModels(provider, models) {
    const providers = JSON.parse(JSON.stringify(SettingsManager.localConfig?.Chat?.providers ?? ConfigManager.config.Chat.providers));
    const index = ChatConfig.providers.findIndex(p => p.id === provider.id);
    if (index < 0 || !providers[index])
      return;
    providers[index].models = models;
    if (!models.includes(providers[index].defaultModel))
      providers[index].defaultModel = "";
    SettingsManager.setValue(["Chat", "providers"], providers);
  }

  Component {
    id: requestComponent
    ChatRequest {
      stream: false
    }
  }

  // Keys may have changed outside the shell (secret-tool, the file)
  Component.onCompleted: SecretsManager.refresh(ChatConfig.providers)

  ColumnLayout {
    id: column
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.margins: Widget.padding
    spacing: Widget.spacing * 1.5

    RowLayout {
      Layout.fillWidth: true
      spacing: Widget.spacing

      StyledText {
        text: I18n.tr("API keys")
        textColor: Theme.accent
        textSize: Appearance.fontSize + 1
        font.bold: true
        Layout.fillWidth: true
      }

      StyledText {
        text: SecretsManager.keyringAvailable === null ? "" : SecretsManager.keyringAvailable ? I18n.tr("Stored in your keyring") : I18n.tr("No keyring: stored in {0}", SecretsManager.secretsPath.replace(Paths.homeDirectory, "~/"))
        textColor: Theme.foregroundAlt
        textSize: Appearance.fontSize - 2
        elide: Text.ElideMiddle
        Layout.maximumWidth: 320
      }
    }

    Repeater {
      model: ChatConfig.providers.length

      delegate: StyledContainer {
        id: row
        required property int index
        readonly property var provider: ChatConfig.providers[index]
        readonly property string status: SecretsManager.status(provider)
        readonly property var result: root.results[provider.id] ?? null

        Layout.fillWidth: true
        implicitHeight: rowColumn.implicitHeight + Widget.padding * 1.5
        backgroundColor: Theme.background

        ColumnLayout {
          id: rowColumn
          anchors.top: parent.top
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Widget.padding * 0.75
          spacing: Widget.spacing

          RowLayout {
            Layout.fillWidth: true
            spacing: Widget.spacing

            StyledText {
              text: row.provider.name
              font.bold: true
            }
            StyledText {
              Layout.fillWidth: true
              text: row.provider.baseUrl
              textColor: Theme.foregroundInactive
              textSize: Appearance.fontSize - 3
              textFamily: "monospace"
              elide: Text.ElideRight
            }

            // Where the key comes from
            Rectangle {
              readonly property color tone: {
                switch (row.status) {
                case "env":
                case "keyring":
                case "file":
                case "unneeded":
                  return Theme.success;
                case "none":
                  return Theme.warning;
                }
                return Theme.foregroundAlt;
              }
              implicitWidth: statusText.implicitWidth + Widget.padding * 1.5
              implicitHeight: statusText.implicitHeight + 4
              radius: height / 2
              color: Qt.alpha(tone, 0.18)
              border.color: Qt.alpha(tone, 0.6)
              border.width: 1

              StyledText {
                id: statusText
                anchors.centerIn: parent
                text: {
                  switch (row.status) {
                  case "env":
                    return I18n.tr("From ${0}", row.provider.keyEnv);
                  case "keyring":
                    return I18n.tr("In keyring");
                  case "file":
                    return I18n.tr("In secrets file");
                  case "none":
                    return I18n.tr("No key");
                  case "unneeded":
                    return I18n.tr("No key needed");
                  }
                  return I18n.tr("Checking…");
                }
                textSize: Appearance.fontSize - 3
                font.bold: true
              }
            }
          }

          // A key to store (not for env keys, which win anyway)
          RowLayout {
            visible: row.provider.auth !== "none" && row.status !== "env"
            Layout.fillWidth: true
            spacing: Widget.spacing / 2

            StyledTextEntry {
              id: keyField
              Layout.fillWidth: true
              Layout.preferredHeight: Widget.height
              placeholderText: row.status === "none" ? I18n.tr("Paste an API key") : I18n.tr("Paste a new key to replace it")
              input.echoMode: TextInput.Password
              onAccepted: saveKey.clicked()
            }

            StyledTextButton {
              id: saveKey
              implicitHeight: Widget.height
              visible: keyField.text.trim() !== ""
              text: I18n.tr("Save")
              backgroundColor: Theme.accent
              textColor: Theme.background
              onClicked: {
                SecretsManager.setKey(row.provider, keyField.text);
                keyField.text = "";
              }
            }

            StyledTextButton {
              implicitHeight: Widget.height
              visible: row.status === "keyring" || row.status === "file"
              text: I18n.tr("Remove")
              onClicked: SecretsManager.clearKey(row.provider)
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Widget.spacing / 2

            StyledText {
              Layout.fillWidth: true
              text: row.result?.busy ? I18n.tr("Connecting…") : row.result?.text ?? ""
              textColor: row.result?.busy ? Theme.foregroundAlt : row.result?.ok ? Theme.success : Theme.error
              textSize: Appearance.fontSize - 2
              wrapMode: Text.Wrap
              maximumLineCount: 3
              elide: Text.ElideRight
            }

            StyledTextButton {
              implicitHeight: Widget.height - 4
              enabled: !row.result?.busy
              text: I18n.tr("Test")
              iconText: "network_check"
              onClicked: root.fetchModels(row.provider, false)
            }

            StyledTextButton {
              implicitHeight: Widget.height - 4
              enabled: !row.result?.busy
              text: I18n.tr("Fetch models")
              iconText: "download"
              onClicked: root.fetchModels(row.provider, true)
            }
          }
        }
      }
    }

    StyledText {
      Layout.fillWidth: true
      text: I18n.tr("A key in the provider's environment variable wins over a stored one. Keys are never written to config.json.")
      opacity: 0.6
      textSize: Appearance.fontSize - 2
      wrapMode: Text.WordWrap
    }
  }
}
