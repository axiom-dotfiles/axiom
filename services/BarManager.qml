pragma Singleton
import QtQuick

import qs.config
import qs.services

QtObject {
  id: root

  property var previewConfig: ({})
  property var fullConfig: ({})
  property var isDirty: false

  Component.onCompleted: {
    loadConfig();
  }

  function applyBar() {
  }

  function loadConfig() {
    fullConfig = {};
    previewConfig = {};
    fullConfig = JSON.parse(JSON.stringify(Bar.bars))
    previewConfig = Bar.bars[0]
  }

  function updateBar() {
    for (let i = 0; i < fullConfig.length; i++) {
      if (fullConfig[i].id === previewConfig.id) {
        fullConfig[i] = JSON.parse(JSON.stringify(previewConfig))
        break;
      }
    }
  }

  function applyChanges() {
    Bar.bars = JSON.parse(JSON.stringify(fullConfig))
    isDirty = false;
  }
}
