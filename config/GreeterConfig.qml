pragma Singleton
import QtQuick
import qs.services

// Reader for the Greeter section: axiom as the greetd login screen
// (GreeterManager sets it up; in the greeter itself, this is the bundle it
// was handed). Named GreeterConfig because `Greeter` is the shell entry
// type.
QtObject {
  id: root

  readonly property var _c: ConfigManager.config.Greeter

  // Set up as the login screen (GreeterManager's install)
  readonly property bool enabled: _c.enabled
  // Where the login box shows: a monitor name, empty for the primary
  readonly property string monitor: _c.monitor
  readonly property bool rememberUser: _c.rememberUser
  // The login screen's ScreenLayout, as saved (the greeter shows the saved
  // one; the layouts editor's draft is GreeterManager.editor.localLayout)
  readonly property var layout: _c.layout
}
