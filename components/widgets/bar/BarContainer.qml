pragma ComponentBehavior: Bound

import QtQuick

import qs.config

Rectangle {
  id: root

  required property var barConfig
  property alias workspaces: workspacesLoader.sourceComponent
  property alias leftGroup: leftGroupLoader.sourceComponent
  property alias rightGroup: rightGroupLoader.sourceComponent
  property alias leftCenterGroup: leftCenterGroupLoader.sourceComponent
  property alias rightCenterGroup: rightCenterGroupLoader.sourceComponent

  property color backgroundColor: Theme.background
  property color foregroundColor: Theme.foreground
  property var screen
  property var popouts

  color: backgroundColor

  Rectangle {
    width: 0
    anchors {
      right: parent.right
      top: parent.top
      bottom: parent.bottom
    }
    color: root.foregroundColor
  }

  Loader {
    id: workspacesLoader
    anchors.centerIn: parent
  }

  Loader {
    id: leftGroupLoader
    anchors {
      left: root.barConfig.vertical ? undefined : parent.left
      top: root.barConfig.vertical ? parent.top : undefined
      horizontalCenter: root.barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: root.barConfig.vertical ? undefined : parent.verticalCenter
      leftMargin: root.barConfig.vertical ? 0 : Appearance.screenMargin
      topMargin: root.barConfig.vertical ? Appearance.screenMargin : 0
    }
  }

  Loader {
    id: leftCenterGroupLoader
    anchors {
      right: root.barConfig.vertical ? undefined : workspacesLoader.left
      bottom: root.barConfig.vertical ? workspacesLoader.top : undefined
      horizontalCenter: root.barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: root.barConfig.vertical ? undefined : parent.verticalCenter
      rightMargin: root.barConfig.vertical ? 0 : Appearance.screenMargin
      bottomMargin: root.barConfig.vertical ? Appearance.screenMargin : 0
    }
  }

  Loader {
    id: rightCenterGroupLoader
    anchors {
      left: root.barConfig.vertical ? undefined : workspacesLoader.right
      top: root.barConfig.vertical ? workspacesLoader.bottom : undefined
      horizontalCenter: root.barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: root.barConfig.vertical ? undefined : parent.verticalCenter
      leftMargin: root.barConfig.vertical ? 0 : Appearance.screenMargin
      topMargin: root.barConfig.vertical ? Appearance.screenMargin : 0
    }
  }

  Loader {
    id: rightGroupLoader
    anchors {
      right: root.barConfig.vertical ? undefined : parent.right
      bottom: root.barConfig.vertical ? parent.bottom : undefined
      horizontalCenter: root.barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: root.barConfig.vertical ? undefined : parent.verticalCenter
      rightMargin: root.barConfig.vertical ? 0 : Appearance.screenMargin
      bottomMargin: root.barConfig.vertical ? Appearance.screenMargin : 0
    }
  }
}
