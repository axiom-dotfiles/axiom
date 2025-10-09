import QtQuick
import qs.config

// Reusable animation components for notifications
QtObject {
  id: animations

  // Configuration
  property int defaultDuration: Appearance.animationDuration
  property int quickDuration: Appearance.animationDuration / 2
  property int slowDuration: Appearance.animationDuration * 2

  // Easing curves
  property var slideInEasing: Easing.OutCubic
  property var slideOutEasing: Easing.InCubic
  property var bounceEasing: Easing.OutBack
  property var smoothEasing: Easing.InOutCubic

  // Factory functions for creating animations
  function createSlideIn(target, fromY, toY) {
    return Qt.createQmlObject(`
            import QtQuick
            ParallelAnimation {
                NumberAnimation {
                    target: ${target}
                    property: "y"
                    from: ${fromY}
                    to: ${toY}
                    duration: ${defaultDuration}
                    easing.type: ${slideInEasing}
                }
                NumberAnimation {
                    target: ${target}
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: ${defaultDuration}
                    easing.type: ${slideInEasing}
                }
            }
        `, target);
  }

  function createSlideOut(target, fromY, toY) {
    return Qt.createQmlObject(`
            import QtQuick
            ParallelAnimation {
                NumberAnimation {
                    target: ${target}
                    property: "y"
                    from: ${fromY}
                    to: ${toY}
                    duration: ${defaultDuration}
                    easing.type: ${slideOutEasing}
                }
                NumberAnimation {
                    target: ${target}
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: ${defaultDuration}
                    easing.type: ${slideOutEasing}
                }
            }
        `, target);
  }

  function createFadeIn(target) {
    return Qt.createQmlObject(`
            import QtQuick
            NumberAnimation {
                target: ${target}
                property: "opacity"
                from: 0
                to: 1
                duration: ${quickDuration}
                easing.type: ${smoothEasing}
            }
        `, target);
  }

  function createFadeOut(target) {
    return Qt.createQmlObject(`
            import QtQuick
            NumberAnimation {
                target: ${target}
                property: "opacity"
                from: 1
                to: 0
                duration: ${quickDuration}
                easing.type: ${smoothEasing}
            }
        `, target);
  }

  function createScale(target, fromScale, toScale) {
    return Qt.createQmlObject(`
            import QtQuick
            NumberAnimation {
                target: ${target}
                property: "scale"
                from: ${fromScale}
                to: ${toScale}
                duration: ${defaultDuration}
                easing.type: ${bounceEasing}
            }
        `, target);
  }

  function createShake(target) {
    return Qt.createQmlObject(`
            import QtQuick
            SequentialAnimation {
                loops: 2
                NumberAnimation {
                    target: ${target}
                    property: "x"
                    to: ${target}.x + 5
                    duration: 50
                }
                NumberAnimation {
                    target: ${target}
                    property: "x"
                    to: ${target}.x - 5
                    duration: 50
                }
                NumberAnimation {
                    target: ${target}
                    property: "x"
                    to: ${target}.x
                    duration: 50
                }
            }
        `, target);
  }

  // Predefined animation components that can be instantiated
  property Component slideInFromTop: Component {
    ParallelAnimation {
      property var target
      property real fromY: -100
      property real toY: 0

      NumberAnimation {
        target: parent.target
        property: "y"
        from: parent.fromY
        to: parent.toY
        duration: defaultDuration
        easing.type: slideInEasing
      }

      NumberAnimation {
        target: parent.target
        property: "opacity"
        from: 0
        to: 1
        duration: defaultDuration
        easing.type: slideInEasing
      }
    }
  }

  property Component slideOutToTop: Component {
    ParallelAnimation {
      property var target
      property real fromY: 0
      property real toY: -100

      NumberAnimation {
        target: parent.target
        property: "y"
        from: parent.fromY
        to: parent.toY
        duration: defaultDuration
        easing.type: slideOutEasing
      }

      NumberAnimation {
        target: parent.target
        property: "opacity"
        from: 1
        to: 0
        duration: defaultDuration
        easing.type: slideOutEasing
      }
    }
  }

  property Component bounceIn: Component {
    ParallelAnimation {
      property var target

      NumberAnimation {
        target: parent.target
        property: "scale"
        from: 0
        to: 1
        duration: defaultDuration
        easing.type: bounceEasing
      }

      NumberAnimation {
        target: parent.target
        property: "opacity"
        from: 0
        to: 1
        duration: quickDuration
        easing.type: smoothEasing
      }
    }
  }

  property Component smoothMove: Component {
    NumberAnimation {
      property var target
      property string propertyName: "y"
      property real to: 0

      target: parent.target
      property: parent.propertyName
      to: parent.to
      duration: defaultDuration
      easing.type: smoothEasing
    }
  }
}
