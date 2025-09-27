pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config
import qs.components.methods
import qs.components.reusable
import qs.components.widgets.menu

Item {
  id: root
  property string panelId: ""
  property real customWidth: 0
  property real customHeight: 0
  property real minimumScrollableHeight: 250
  property bool mediaPlaying: true
  property int panelMargin: 10
  property real topSectionHeight: 120
  property real quickSettingsHeight: 40

  MenuBottomArea {
    id: bottomArea
    anchors.bottom: parent.bottom
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottomMargin: root.panelMargin
    anchors.leftMargin: root.panelMargin
    anchors.rightMargin: root.panelMargin
    
    quickSettingsHeight: root.quickSettingsHeight
    mediaPlaying: root.mediaPlaying
    showMediaControl: true
  }

  ColumnLayout {
    id: topAreaLayout
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.bottom: bottomArea.top
    anchors.topMargin: root.panelMargin
    anchors.leftMargin: root.panelMargin
    anchors.rightMargin: root.panelMargin
    anchors.bottomMargin: bottomArea.visibleChildren.length > 0 ? root.panelMargin : 0
    spacing: root.panelMargin
    
    StyledContainer {
      id: topSection
      Layout.fillWidth: true
      Layout.preferredHeight: root.topSectionHeight // Layout respects preferred height
      containerBorderColor: Theme.border
      
      StyledText {
        anchors.centerIn: parent
        text: "Top Section - Reserved for Future Component"
        textColor: Theme.foregroundAlt
      }
      
      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          console.log("Top section clicked - toggling dark mode for demo.");
          ThemeManager.toggleDarkMode();
        }
      }
    }
    
    MainContent {
      id: tabbedContent
      Layout.fillWidth: true
      Layout.fillHeight: true // This is the key to making it fill the space
    }
  }
}
