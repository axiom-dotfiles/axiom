pragma Singleton
import QtQuick
import qs.services

// Reader for the OSD section (the volume, microphone and brightness
// on-screen displays). Named
// OSDConfig because `OSD` is the module type.
QtObject {
  readonly property var _c: ConfigManager.config.OSD

  readonly property bool enabled: _c.enabled
  // Level change per wheel notch (0-1); 0 when scrolling is off
  readonly property real scrollStep: _c.scrollToChange ? _c.scrollStep / 100 : 0
  // [OSDEntry] (see the schema): each with its own placement and bars,
  // { type, app, icon, showOsd }, type being master | other | microphone |
  // brightness | app. Goes through a string so a reload that leaves the
  // list unchanged doesn't rebuild the OSDs.
  readonly property string _osdsJson: JSON.stringify(_c.osds)
  readonly property var osds: JSON.parse(_osdsJson)
  // The enabled ones, by id: what the shell builds
  readonly property var shownIds: osds.filter(osd => osd.enabled).map(osd => osd.id)
  // The streams the App bars of every OSD match, which the Other apps bars
  // skip
  readonly property var excludedApps: [].concat(...osds.map(osd => osd.bars.filter(bar => bar.type === "app" && bar.app !== "").map(bar => bar.app)))

  function osdById(id) {
    return osds.find(osd => osd.id === id) ?? null;
  }

  // Whether an OSD opens for a bar of this type
  function opensFor(osd, type) {
    return osd.bars.some(bar => bar.type === type && bar.showOsd);
  }

  // The name on its tab: its own, else its bars'
  function labelOf(osd) {
    if (osd.name)
      return osd.name;
    // I18n.tr("System volume") I18n.tr("Other apps") I18n.tr("Microphone") I18n.tr("Brightness")
    const names = {
      "master": "System volume",
      "other": "Other apps",
      "microphone": "Microphone",
      "brightness": "Brightness"
    };
    const parts = osd.bars.map(bar => bar.type === "app" ? (bar.app || I18n.tr("An app")) : I18n.tr(names[bar.type]));
    return parts.length > 0 ? parts.join(", ") : I18n.tr("Empty OSD");
  }
}
