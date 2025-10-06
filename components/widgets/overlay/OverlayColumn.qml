import QtQuick

import qs.config

Item {
  id: overlayColumn


  Rectangle {
    id: background
    anchors.fill: parent
    color: Theme.background
    radius: Menu.cardBorderRadius
    border.color: Theme.border
    border.width: Menu.cardBorderWidth
  }

}
