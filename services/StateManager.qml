pragma Singleton
import QtQuick
import Quickshell.Io
import qs.config

import qs.components.methods

QtObject {
  id: stateManager

  readonly property string stateDir: Config.statePath

  /**
     * @brief Creates a state handler for a specific service
     * @param serviceName The name of the service (e.g., "launcher")
     * @returns An object with save/load methods
     */
  function createStateHandler(serviceName) {
    const stateFile = serviceName + ".json";
    const fileView = fileViewComponent.createObject(stateManager, {
      path: Qt.resolvedUrl(stateDir + stateFile)
    });

    return {
      save: function (data) {
        try {
          const stateString = JSON.stringify(data, null, 2);
          fileView.setText(stateString);
          console.log(`[StateManager] ${serviceName} state saved.`);
          return true;
        } catch (e) {
          console.error(`[StateManager] Failed to save ${serviceName}:`, e);
          return false;
        }
      },
      load: function (defaultValue) {
        const filepath = stateDir + stateFile;
        console.log(`[StateManager] Loading ${serviceName} from`, filepath);
        const content = Utils.getFileContent(Qt.resolvedUrl(filepath));

        if (content) {
          try {
            const state = JSON.parse(content);
            console.log(`[StateManager] ${serviceName} loaded successfully.`);
            return state;
          } catch (e) {
            console.error(`[StateManager] Failed to parse ${serviceName}:`, e);
            return defaultValue;
          }
        } else {
          console.log(`[StateManager] No ${serviceName} state found.`);
          return defaultValue;
        }
      }
    };
  }

  property Component _componet: Component {
    id: fileViewComponent
    FileView {
      blockWrites: true
      atomicWrites: true
      onSaveFailed: error => {
        console.error("[StateManager] Save failed:", FileViewError.toString(error));
      }
    }
  }
}
