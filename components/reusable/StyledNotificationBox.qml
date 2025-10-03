// Abstracts/StyledNotificationBox.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Notifications

Frame {
  id: component
  
  // -- Signals --
  // null
  
  // -- Public API --
  property var notification
  
  // -- Configurable Appearance --
  property color backgroundColor
  property color headerTextColor
  property color bodyTextColor
  property color actionButtonColor
  property color actionButtonTextColor
  property color actionButtonBorderColor
  property color criticalHighlightColor
  property real borderRadius
  property real borderWidth
  property string fontFamily
  property int appNameFontSize
  property int summaryFontSize
  property int bodyFontSize
  property int actionButtonFontSize
  property int contentPadding
  property int actionSpacing
  
  // -- Implementation --
  padding: contentPadding
  
  background: Rectangle {
    color: component.backgroundColor
    implicitHeight: 100
    radius: component.borderRadius
    border.width: component.notification.urgency === NotificationUrgency.Critical ? component.borderWidth + 1 : component.borderWidth
    border.color: component.notification.urgency === NotificationUrgency.Critical ? component.criticalHighlightColor : "transparent"
  }
  
  ColumnLayout {
    Layout.fillWidth: true
    
    RowLayout {
      Layout.fillWidth: true
      
      ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        
        Label {
          text: component.notification.appName
          color: component.headerTextColor
          font.family: component.fontFamily
          font.pixelSize: component.appNameFontSize
        }
        
        Label {
          text: component.notification.summary
          color: component.bodyTextColor
          font.bold: true
          font.family: component.fontFamily
          font.pixelSize: component.summaryFontSize
          wrapMode: Text.Wrap
        }
      }
      
      Button {
        icon.source: "image://theme/window-close"
        icon.color: component.headerTextColor
        flat: true
        Layout.alignment: Qt.AlignTop
        onClicked: component.notification.dismiss()
      }
    }
    
    Label {
      visible: component.notification.body.length > 0
      text: component.notification.body
      color: component.bodyTextColor
      font.family: component.fontFamily
      font.pixelSize: component.bodyFontSize
      wrapMode: Text.Wrap
      textFormat: Text.RichText
      Layout.topMargin: 4
      Layout.fillWidth: true
    }
    
    RowLayout {
      visible: component.notification.actions.length > 0
      spacing: component.actionSpacing
      Layout.topMargin: 12
      
      Repeater {
        model: component.notification.actions
        
        delegate: Button {
          text: modelData.text
          flat: true
          font.family: component.fontFamily
          font.pixelSize: component.actionButtonFontSize
          
          background: Rectangle {
            color: component.actionButtonColor
            radius: component.borderRadius > 2 ? component.borderRadius - 2 : component.borderRadius
            border.width: component.borderWidth
            border.color: component.actionButtonBorderColor
          }
          
          contentItem: Label {
            text: parent.text
            color: component.actionButtonTextColor
            font: parent.font
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
          }
          
          onClicked: modelData.invoke()
        }
      }
    }
  }
}
