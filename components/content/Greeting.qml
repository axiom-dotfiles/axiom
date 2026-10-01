pragma ComponentBehavior: Bound
import QtQuick
import Quickshell

import qs.config
import qs.components.reusable
import qs.components.content.base

// A line of text, as big as its slot allows: resizing the module resizes
// the text. {name} is the display name, {user} the user name and
// {greeting} good morning, afternoon or evening; empty text says hey to
// the display name.
// properties: { text, color, alignment: "left" | "center" | "right", bold }
Card {
  id: root

  // On the lock screen it's text on the background, whatever its
  // moduleBorders: a card box around a greeting looks like a mistake
  readonly property bool boxless: root.bare || root.host?.kind === "lockscreen"
  readonly property string template: root.properties.text
  readonly property bool wantsGreeting: root.template.includes("{greeting}")

  readonly property string greeting: {
    const hour = clock.hours;
    return hour >= 5 && hour < 12 ? I18n.tr("Good morning") : hour >= 12 && hour < 18 ? I18n.tr("Good afternoon") : I18n.tr("Good evening");
  }
  readonly property string shownText: root.template === "" ? I18n.tr("Hey {0}", General.displayName) : root.template.replace(/\{name\}/g, General.displayName).replace(/\{user\}/g, Quickshell.env("USER") ?? "").replace(/\{greeting\}/g, root.greeting)

  color: root.boxless ? "transparent" : Theme.background
  border.width: root.boxless ? 0 : Appearance.borderWidth

  SystemClock {
    id: clock
    enabled: root.wantsGreeting
    precision: SystemClock.Hours
  }

  StyledText {
    anchors.fill: parent
    anchors.margins: root.pad
    text: root.shownText
    textColor: Theme.resolveColor(root.properties.color)
    textSize: Math.max(8, Math.round(height))
    font.bold: root.properties.bold
    fontSizeMode: Text.Fit
    minimumPixelSize: 8
    wrapMode: Text.WordWrap
    elide: Text.ElideRight
    horizontalAlignment: root.properties.alignment === "left" ? Text.AlignLeft : root.properties.alignment === "right" ? Text.AlignRight : Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
  }
}
