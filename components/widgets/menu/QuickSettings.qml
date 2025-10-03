pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts

import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable

StyledContainer {
  id: root

  RowLayout {
    anchors.fill: parent
    spacing: Widget.padding
    Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

    StyledRectButton {
      iconText: "󰖩"
      iconColor: Theme.background
      backgroundColor: Theme.base0A
      onClicked: Utils.launch("nm-connection-editor")
    }

    StyledRectButton {
      iconText: "󰂯"
      iconColor: Theme.background
      backgroundColor: Theme.base0B
      onClicked: Utils.launch("blueberry")
    }

    StyledRectButton {
      iconText: "󰃣"
      iconColor: Theme.background
      backgroundColor: Theme.base0C
      onClicked: Utils.launch("nwg-look")
    }

    StyledRectButton {
      iconText: "󰕾"
      iconColor: Theme.background
      backgroundColor: Theme.base0D
      onClicked: Utils.launch("pavucontrol")
    }

    StyledRectButton {
      iconText: "󰍛"
      iconColor: Theme.background
      backgroundColor: Theme.base0E
      onClicked: {
        ShellManager.togglePinnedPanel("mainMenu");
      }
    }
  }
}
