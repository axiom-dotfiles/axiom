// EdgeSlideContainer.qml - Fixed animation container with proper state management
import QtQuick
import Quickshell

import qs.config

Item {
  id: root

  // Core properties
  property bool active: false

  // Edge configuration - determines slide direction
  enum Edge {
    Left,
    Right,
    Top,
    Bottom
  }
  property int edge: EdgeSlideContainer.Edge.Right

  // Animation configuration
  property int animationDuration: Appearance.animations ? Appearance.animationDuration : 0
  property var easingType: Easing.OutCubic

  // Optional fade animation
  property bool enableFade: true
  property int fadeAnimationDuration: 200

  // Content
  default property alias content: contentArea.children

  // Animation state tracking
  signal animationCompleted
  property bool __isAnimating: false

  // Size management
  implicitWidth: Math.max(1, contentArea.implicitWidth)
  implicitHeight: Math.max(1, contentArea.implicitHeight)

  // Clip content during animation
  clip: true

  // Main animation wrapper
  Item {
    id: contentWrapper
    width: parent.width
    height: parent.height

    // Calculate positions based on current size
    property real hiddenX: {
      switch (root.edge) {
      case EdgeSlideContainer.Edge.Left:
        return -root.width;
      case EdgeSlideContainer.Edge.Right:
        return root.width;
      default:
        return 0;
      }
    }

    property real hiddenY: {
      switch (root.edge) {
      case EdgeSlideContainer.Edge.Top:
        return -root.height;
      case EdgeSlideContainer.Edge.Bottom:
        return root.height;
      default:
        return 0;
      }
    }

    property real visibleX: 0
    property real visibleY: 0

    // Initialize position
    Component.onCompleted: {
      // Start from hidden position
      if (!root.active) {
        x = hiddenX;
        y = hiddenY;
        opacity = root.enableFade ? 0 : 1;
      }
    }

    // Manual animation control for better timing
    ParallelAnimation {
      id: showAnimation

      NumberAnimation {
        target: contentWrapper
        property: "x"
        from: contentWrapper.hiddenX
        to: contentWrapper.visibleX
        duration: root.animationDuration
        easing.type: root.easingType
      }

      NumberAnimation {
        target: contentWrapper
        property: "y"
        from: contentWrapper.hiddenY
        to: contentWrapper.visibleY
        duration: root.animationDuration
        easing.type: root.easingType
      }

      NumberAnimation {
        target: contentWrapper
        property: "opacity"
        from: 0
        to: 1
        duration: root.enableFade ? root.fadeAnimationDuration : 0
        easing.type: Easing.InOutQuad
      }

      onStarted: {
        root.__isAnimating = true;
      }

      onFinished: {
        root.__isAnimating = false;
        root.animationCompleted();
      }
    }

    ParallelAnimation {
      id: hideAnimation

      NumberAnimation {
        target: contentWrapper
        property: "x"
        from: contentWrapper.visibleX
        to: contentWrapper.hiddenX
        duration: root.animationDuration
        easing.type: root.easingType
      }

      NumberAnimation {
        target: contentWrapper
        property: "y"
        from: contentWrapper.visibleY
        to: contentWrapper.hiddenY
        duration: root.animationDuration
        easing.type: root.easingType
      }

      NumberAnimation {
        target: contentWrapper
        property: "opacity"
        from: 1
        to: 0
        duration: root.enableFade ? root.fadeAnimationDuration : 0
        easing.type: Easing.InOutQuad
      }

      onStarted: {
        root.__isAnimating = true;
      }

      onFinished: {
        root.__isAnimating = false;
        root.animationCompleted();
      }
    }

    // Content area
    Item {
      id: contentArea
      anchors.fill: parent
    }
  }

  // Handle active changes
  onActiveChanged: {
    if (root.implicitWidth <= 0 || root.implicitHeight <= 0) {
      console.warn("EdgeSlideContainer: Invalid size, skipping animation");
      return;
    }

    // Stop any running animations
    showAnimation.stop();
    hideAnimation.stop();

    if (active) {
      // Ensure we start from hidden position
      if (!__isAnimating) {
        contentWrapper.x = contentWrapper.hiddenX;
        contentWrapper.y = contentWrapper.hiddenY;
        if (enableFade)
          contentWrapper.opacity = 0;
      }
      showAnimation.start();
    } else {
      // Ensure we start from visible position
      if (!__isAnimating) {
        contentWrapper.x = contentWrapper.visibleX;
        contentWrapper.y = contentWrapper.visibleY;
        if (enableFade)
          contentWrapper.opacity = 1;
      }
      hideAnimation.start();
    }
  }

  // Update positions when size changes (defensive)
  onWidthChanged: {
    if (!__isAnimating && !active) {
      contentWrapper.x = contentWrapper.hiddenX;
    }
  }

  onHeightChanged: {
    if (!__isAnimating && !active) {
      contentWrapper.y = contentWrapper.hiddenY;
    }
  }

  // Public API
  function show() {
    active = true;
  }

  function hide() {
    active = false;
  }

  function toggle() {
    active = !active;
  }

  function reset() {
    showAnimation.stop();
    hideAnimation.stop();
    __isAnimating = false;

    if (active) {
      contentWrapper.x = contentWrapper.visibleX;
      contentWrapper.y = contentWrapper.visibleY;
      contentWrapper.opacity = 1;
    } else {
      contentWrapper.x = contentWrapper.hiddenX;
      contentWrapper.y = contentWrapper.hiddenY;
      contentWrapper.opacity = enableFade ? 0 : 1;
    }
  }
}
