pragma ComponentBehavior: Bound
import QtQuick
import qs.components.widgets.overlay.columns

BaseView {
  id: view

  SettingsPanel {}
  ThemeEditor {}
  ColorPreview {}
}
