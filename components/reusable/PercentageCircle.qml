pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// A ring gauge: a thin track with a round-capped arc over it, like a
// StyledSlider bent into a circle, and an icon in the middle
Item {
  id: root

  property real percentage: 0
  property string iconText: "●"
  property color iconColor: Theme.background
  property color fillColor: Theme.accentAlt
  property color trackColor: Theme.backgroundHighlight
  // The stroke, as a share of the side, but never thinner than a slider's trough
  property real thickness: Math.max(4, side * 0.07)

  readonly property real side: Math.min(root.width, root.height)

  implicitWidth: 120
  implicitHeight: 120

  Canvas {
    id: ring
    anchors.centerIn: parent
    width: root.side
    height: root.side

    onPaint: {
      const ctx = getContext("2d");
      const centre = width / 2;
      const radius = centre - root.thickness / 2;
      ctx.clearRect(0, 0, width, height);
      if (radius <= 0)
        return;
      ctx.lineWidth = root.thickness;

      ctx.beginPath();
      ctx.arc(centre, centre, radius, 0, 2 * Math.PI, false);
      ctx.strokeStyle = root.trackColor;
      ctx.stroke();

      // A round cap would draw a dot at zero
      const share = Math.max(0, Math.min(1, root.percentage / 100));
      if (share <= 0)
        return;
      ctx.beginPath();
      ctx.arc(centre, centre, radius, -Math.PI / 2, -Math.PI / 2 + share * 2 * Math.PI, false);
      ctx.lineCap = "round";
      ctx.strokeStyle = root.fillColor;
      ctx.stroke();
    }

    Connections {
      target: root
      function onPercentageChanged() {
        ring.requestPaint();
      }
      function onFillColorChanged() {
        ring.requestPaint();
      }
      function onTrackColorChanged() {
        ring.requestPaint();
      }
      function onThicknessChanged() {
        ring.requestPaint();
      }
    }
  }

  StyledIcon {
    anchors.centerIn: parent
    text: root.iconText
    textColor: root.iconColor
    textSize: root.side * 0.3
  }

  Behavior on percentage {
    NumberAnimation {
      duration: Appearance.animSlow
      easing.type: Easing.OutCubic
    }
  }
}
