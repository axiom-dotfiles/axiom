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

  // Workspaces centered
  Loader {
    id: workspacesLoader
    anchors.centerIn: parent
  }

  // Top/Left group
  Loader {
    id: leftGroupLoader
    anchors {
      left: barConfig.vertical ? undefined : parent.left
      top: barConfig.vertical ? parent.top : undefined
      horizontalCenter: barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: barConfig.vertical ? undefined : parent.verticalCenter
      leftMargin: barConfig.vertical ? 0 : Appearance.screenMargin
      topMargin: barConfig.vertical ? Appearance.screenMargin : 0
    }
  }

  // Left-Center/Top-Center group
  Loader {
    id: leftCenterGroupLoader
    anchors {
      right: barConfig.vertical ? undefined : workspacesLoader.left
      bottom: barConfig.vertical ? workspacesLoader.top : undefined
      horizontalCenter: barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: barConfig.vertical ? undefined : parent.verticalCenter
      rightMargin: barConfig.vertical ? 0 : Appearance.screenMargin
      bottomMargin: barConfig.vertical ? Appearance.screenMargin : 0
    }
  }

  // Right-Center/Bottom-Center group
  Loader {
    id: rightCenterGroupLoader
    anchors {
      left: barConfig.vertical ? undefined : workspacesLoader.right
      top: barConfig.vertical ? workspacesLoader.bottom : undefined
      horizontalCenter: barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: barConfig.vertical ? undefined : parent.verticalCenter
      leftMargin: barConfig.vertical ? 0 : Appearance.screenMargin
      topMargin: barConfig.vertical ? Appearance.screenMargin : 0
    }
  }

  // Bottom/Right group
  Loader {
    id: rightGroupLoader
    anchors {
      right: barConfig.vertical ? undefined : parent.right
      bottom: barConfig.vertical ? parent.bottom : undefined
      horizontalCenter: barConfig.vertical ? parent.horizontalCenter : undefined
      verticalCenter: barConfig.vertical ? undefined : parent.verticalCenter
      rightMargin: barConfig.vertical ? 0 : Appearance.screenMargin
      bottomMargin: barConfig.vertical ? Appearance.screenMargin : 0
    }
  }
}
