pragma ComponentBehavior: Bound
import QtQuick
import qs.config

// The dot beside something with unsaved edits (a settings category, card
// or field; a bar, page or edge menu in its editor). `onAccent` for a
// selected row, which is filled with the accent itself.
Rectangle {
  property bool onAccent: false

  implicitWidth: 8
  implicitHeight: 8
  radius: 4
  color: onAccent ? Theme.background : Theme.accent
}
