pragma ComponentBehavior: Bound

import QtQuick

import qs.services
import qs.config

Rectangle {
  id: root

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
      left: Bar.vertical ? undefined : parent.left
      top: Bar.vertical ? parent.top : undefined
      horizontalCenter: Bar.vertical ? parent.horizontalCenter : undefined
      verticalCenter: Bar.vertical ? undefined : parent.verticalCenter
      leftMargin: Bar.vertical ? 0 : Appearance.screenMargin
      topMargin: Bar.vertical ? Appearance.screenMargin : 0
    }
  }

  // Left-Center/Top-Center group
  Loader {
    id: leftCenterGroupLoader
    anchors {
      right: Bar.vertical ? undefined : workspacesLoader.left
      bottom: Bar.vertical ? workspacesLoader.top : undefined
      horizontalCenter: Bar.vertical ? parent.horizontalCenter : undefined
      verticalCenter: Bar.vertical ? undefined : parent.verticalCenter
      rightMargin: Bar.vertical ? 0 : Appearance.screenMargin
      bottomMargin: Bar.vertical ? Appearance.screenMargin : 0
    }
  }

  // Right-Center/Bottom-Center group
  Loader {
    id: rightCenterGroupLoader
    anchors {
      left: Bar.vertical ? undefined : workspacesLoader.right
      top: Bar.vertical ? workspacesLoader.bottom : undefined
      horizontalCenter: Bar.vertical ? parent.horizontalCenter : undefined
      verticalCenter: Bar.vertical ? undefined : parent.verticalCenter
      leftMargin: Bar.vertical ? 0 : Appearance.screenMargin
      topMargin: Bar.vertical ? Appearance.screenMargin : 0
    }
  }

  // Bottom/Right group
  Loader {
    id: rightGroupLoader
    anchors {
      right: Bar.vertical ? undefined : parent.right
      bottom: Bar.vertical ? parent.bottom : undefined
      horizontalCenter: Bar.vertical ? parent.horizontalCenter : undefined
      verticalCenter: Bar.vertical ? undefined : parent.verticalCenter
      rightMargin: Bar.vertical ? 0 : Appearance.screenMargin
      bottomMargin: Bar.vertical ? Appearance.screenMargin : 0
    }
  }
}
