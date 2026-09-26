// SchemaNumberField.qml
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.components.reusable

// i18n: keys from callers and the schema (titles, descriptions, type labels)
// An integer setting: a slider with a value box when the range is a
// comfortable drag (7 to 200 steps), otherwise a compact stepper beside the
// label, with ±10 buttons when the range is wide. The value box takes typed
// input and shows the `unit`. Stepper clicks are debounced, so a burst of
// them is one commit; the slider commits on release.
ColumnLayout {
  id: root

  required property string label
  property string description: ""
  required property int currentConfigValue
  property int minimum: 0
  property int maximum: 999
  property int stepSize: 1
  // Room kept free at the header's right end (the settings row's reset
  // button sits there)
  property int headerInset: 0
  // Shown after the value, e.g. "px", "%", "ms"
  property string unit: ""
  // "auto" picks by range; "slider" or "stepper" forces one
  property string mode: "auto"
  // ±10 buttons in stepper mode; defaults to wide ranges only
  property bool showCoarse: root.steps > 20
  readonly property int coarseStep: root.stepSize * 10

  // The value shown, ahead of the config while a commit is pending
  property int value: currentConfigValue

  // Compact, near the text's own height, so it doesn't outweigh the label
  property int controlHeight: Math.min(Widget.height, Appearance.fontSize + 10)
  readonly property int containerMargins: 2
  readonly property int buttonSize: controlHeight - (containerMargins * 2)

  readonly property int steps: Math.round((maximum - minimum) / Math.max(1, stepSize))
  readonly property bool isSlider: mode === "slider" || (mode === "auto" && steps >= 7 && steps <= 200)
  // Word units are translated; symbols (px, %, ms, ‰) pass through
  // I18n.tr("min") I18n.tr("days") I18n.tr("tokens")
  readonly property string unitText: root.unit === "" ? "" : I18n.tr(root.unit)

  signal committed(int value)

  Layout.fillWidth: true
  spacing: 4

  function clamp(v) {
    const snapped = root.minimum + Math.round((v - root.minimum) / Math.max(1, root.stepSize)) * root.stepSize;
    return Math.max(root.minimum, Math.min(root.maximum, snapped));
  }

  // Sets the shown value; commits at once, or after the burst settles
  function setValue(v, immediate) {
    root.value = root.clamp(v);
    if (immediate)
      root.commit();
    else
      commitTimer.restart();
  }

  function stepBy(delta) {
    root.setValue(root.value + delta, false);
  }

  function commit() {
    commitTimer.stop();
    if (root.value !== root.currentConfigValue)
      root.committed(root.value);
  }

  // Follow outside changes (a reload, a reset elsewhere) unless the user
  // is mid-edit
  onCurrentConfigValueChanged: {
    if (!commitTimer.running)
      root.value = root.currentConfigValue;
  }

  // Don't lose a pending step when the page goes away
  Component.onDestruction: {
    if (commitTimer.running)
      root.commit();
  }

  Timer {
    id: commitTimer
    interval: 400
    onTriggered: root.commit()
  }

  RowLayout {
    Layout.fillWidth: true
    Layout.rightMargin: root.headerInset
    spacing: Widget.spacing

    StyledText {
      text: I18n.tr(root.label)
      Layout.fillWidth: true
      elide: Text.ElideRight
    }

    // Stepper: [−10][−][ value ][+][+10]
    StyledContainer {
      visible: !root.isSlider
      borderColor: Theme.border
      Layout.preferredHeight: root.controlHeight
      Layout.preferredWidth: stepperRow.implicitWidth + root.containerMargins * 2

      RowLayout {
        id: stepperRow
        anchors.fill: parent
        anchors.margins: root.containerMargins
        spacing: 2

        StepButton {
          visible: root.showCoarse
          iconText: "−10"
          coarse: true
          enabled: root.value > root.minimum
          onClicked: root.stepBy(-root.coarseStep)
        }

        StepButton {
          iconText: "remove"
          enabled: root.value > root.minimum
          onClicked: root.stepBy(-root.stepSize)
        }

        ValueBox {
          Layout.fillHeight: true
          color: "transparent"
          border.width: 0
        }

        StepButton {
          iconText: "add"
          enabled: root.value < root.maximum
          onClicked: root.stepBy(root.stepSize)
        }

        StepButton {
          visible: root.showCoarse
          iconText: "+10"
          coarse: true
          enabled: root.value < root.maximum
          onClicked: root.stepBy(root.coarseStep)
        }
      }
    }
  }

  // Slider: track, then the value box
  RowLayout {
    visible: root.isSlider
    Layout.fillWidth: true
    spacing: Widget.spacing

    StyledSlider {
      Layout.fillWidth: true
      Layout.preferredHeight: root.controlHeight
      troughHeight: 6
      troughColor: Theme.border
      fillColor: Theme.accent
      handleColor: Theme.foreground
      handleWidth: 14
      handleHeight: 14
      handleRadius: 7
      // Not `value`: dragging assigns that, which would drop the binding
      targetValue: root.maximum > root.minimum ? (root.value - root.minimum) / (root.maximum - root.minimum) : 0
      onMoved: ratio => root.value = root.clamp(root.minimum + ratio * (root.maximum - root.minimum))
      onReleased: ratio => root.setValue(root.minimum + ratio * (root.maximum - root.minimum), true)
    }

    ValueBox {
      Layout.preferredHeight: root.controlHeight
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

  // Wide enough for the longest value in range, so it doesn't jitter
  TextMetrics {
    id: widest
    font.family: Appearance.fontFamily
    font.pixelSize: Appearance.fontSize
    text: String(Math.abs(root.minimum) > Math.abs(root.maximum) ? root.minimum : root.maximum)
  }

  component StepButton: StyledIconButton {
    // The ±10 buttons: text, smaller and dimmer than −/+
    property bool coarse: false
    Layout.preferredWidth: coarse ? Math.round(root.buttonSize * 1.4) : root.buttonSize
    Layout.preferredHeight: root.buttonSize
    Layout.fillWidth: false
    Layout.fillHeight: false
    iconSize: coarse ? Appearance.fontSize - 4 : Appearance.fontSize
    iconColor: coarse ? Theme.foregroundAlt : Theme.foreground
    autoRepeat: true
    autoRepeatDelay: 400
    autoRepeatInterval: 60
  }

  // The number (typed input, clamped on Enter or focus loss; Escape
  // reverts) with its unit. Wheel steps by one, or ten with Shift.
  component ValueBox: StyledContainer {
    id: box
    Layout.fillWidth: false
    readonly property int unitGap: root.unitText === "" ? 0 : 3
    Layout.preferredWidth: widest.advanceWidth + unitLabel.implicitWidth + box.unitGap + Widget.padding * 2
    border.color: input.activeFocus ? Theme.accent : Theme.border

    TextInput {
      id: input
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: unitLabel.left
      anchors.rightMargin: box.unitGap
      anchors.left: parent.left
      anchors.leftMargin: Widget.padding
      horizontalAlignment: root.unitText === "" ? Text.AlignHCenter : Text.AlignRight
      color: Theme.foreground
      font.family: Appearance.fontFamily
      font.pixelSize: Appearance.fontSize
      selectByMouse: true
      inputMethodHints: Qt.ImhFormattedNumbersOnly
      validator: RegularExpressionValidator {
        regularExpression: /-?\d*/
      }

      Binding on text {
        value: String(root.value)
        when: !input.activeFocus
      }

      function apply() {
        const parsed = parseInt(input.text, 10);
        if (!isNaN(parsed))
          root.setValue(parsed, true);
        input.text = String(root.value);
      }

      onActiveFocusChanged: {
        if (activeFocus)
          selectAll();
        else
          apply();
      }
      Keys.onReturnPressed: focus = false
      Keys.onEnterPressed: focus = false
      Keys.onEscapePressed: {
        text = String(root.value);
        focus = false;
      }
    }

    StyledText {
      id: unitLabel
      anchors.verticalCenter: parent.verticalCenter
      anchors.right: parent.right
      anchors.rightMargin: Widget.padding
      text: root.unitText
      textColor: Theme.foregroundAlt
      textSize: Appearance.fontSize - 2
    }

    WheelHandler {
      acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
      onWheel: event => {
        const dir = event.angleDelta.y > 0 ? 1 : (event.angleDelta.y < 0 ? -1 : 0);
        if (dir !== 0)
          root.stepBy(dir * ((event.modifiers & Qt.ShiftModifier) ? root.coarseStep : root.stepSize));
      }
    }
  }
}
