pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import qs.components.reusable
import qs.components.methods

// i18n: keys from callers and the schema (titles, descriptions, type labels)
ColumnLayout {
  id: root
  required property string label
  required property var options
  required property string currentValue
  property string description: ""
  // Options are color names (Theme.resolveColor): paint the box and each
  // row in the color it names (an empty one, automatic, shows its label)
  property bool swatches: false
  // value -> label shown for it; values without one are shown translated
  property var optionLabels: ({})
  function optionLabel(value) {
    return root.optionLabels?.[value] ?? I18n.tr(value);
  }

  readonly property color _currentColor: root.swatches && root.currentValue ? Theme.resolveColor(root.currentValue) : Theme.backgroundAlt
  readonly property color _currentTextColor: root.swatches && root.currentValue ? Utils.getContrastColor(root._currentColor) : Theme.foreground

  signal selectionChanged(string newValue)

  Layout.fillWidth: true
  spacing: 4

  StyledText {
    text: I18n.tr(root.label)
    visible: root.label !== ""
    Layout.fillWidth: true
  }

  StyledContainer {
    id: comboContainer
    Layout.fillWidth: true
    Layout.preferredHeight: Widget.height
    backgroundColor: root._currentColor
    borderColor: comboBox.popup.visible ? Theme.accent : Theme.border

    RowLayout {
      anchors.fill: parent
      anchors.leftMargin: Widget.padding
      anchors.rightMargin: Widget.padding
      spacing: 0

      StyledText {
        text: root.swatches && root.currentValue ? root.currentValue : root.optionLabel(root.currentValue)
        textColor: root._currentTextColor
        Layout.fillWidth: true
        elide: Text.ElideRight
      }

      StyledIcon {
        text: "arrow_drop_down"
        textColor: root.swatches ? root._currentTextColor : Theme.accent
        textSize: Appearance.fontSize + 2
        Layout.preferredWidth: implicitWidth
      }
    }

    ComboBox {
      id: comboBox
      anchors.fill: parent
      model: root.options
      currentIndex: root.options.indexOf(root.currentValue)

      background: Item {}
      contentItem: Item {}
      indicator: Item {}

      onActivated: index => {
        root.selectionChanged(root.options[index]);
      }

      // Rows are inset from the popup's rounded border and rounded
      // themselves, so the background shows all the way around
      popup: Popup {
        y: comboContainer.height + Widget.spacing
        width: comboContainer.width
        padding: Widget.spacing

        background: DropdownSurface {
          color: Theme.backgroundAlt
          border.width: Appearance.borderWidth
        }

        contentItem: ListView {
          clip: true
          implicitHeight: Math.min(contentHeight, Widget.height * 10)
          spacing: root.swatches ? Widget.spacing / 2 : 0
          model: comboBox.popup.visible ? comboBox.delegateModel : null
          currentIndex: comboBox.highlightedIndex

          ScrollIndicator.vertical: ScrollIndicator {}
        }
      }

      delegate: Rectangle {
        id: optionDelegate
        required property int index
        required property string modelData
        readonly property color swatchColor: !root.swatches ? "transparent" : modelData ? Theme.resolveColor(modelData) : Theme.backgroundAlt

        width: ListView.view.width
        height: Widget.height
        radius: Widget.radius
        color: root.swatches ? swatchColor : (delegateArea.containsMouse ? Theme.backgroundHighlight : "transparent")
        border.width: root.swatches && (delegateArea.containsMouse || modelData === root.currentValue) ? Appearance.borderWidth * 2 : 0
        border.color: Utils.getContrastColor(swatchColor)

        StyledText {
          anchors.fill: parent
          anchors.leftMargin: Widget.padding
          anchors.rightMargin: Widget.padding
          text: root.swatches && optionDelegate.modelData ? optionDelegate.modelData : root.optionLabel(optionDelegate.modelData)
          textColor: root.swatches ? Utils.getContrastColor(optionDelegate.swatchColor) : Theme.foreground
          verticalAlignment: Text.AlignVCenter
          elide: Text.ElideRight
        }

        MouseArea {
          id: delegateArea
          anchors.fill: parent
          hoverEnabled: true
          // currentIndex stays bound to currentValue, which the caller
          // updates (or not, if it rejects the choice)
          onClicked: {
            comboBox.activated(optionDelegate.index);
            comboBox.popup.close();
          }
        }
      }
    }

    MouseArea {
      anchors.fill: parent
      onClicked: {
        comboBox.popup.open();
      }
    }
  }

  StyledText {
    visible: root.description !== ""
    text: I18n.tr(root.description)
    opacity: 0.7
    textSize: Appearance.fontSize - 2
    wrapMode: Text.WordWrap
    Layout.fillWidth: true
  }
}
