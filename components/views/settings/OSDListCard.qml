pragma ComponentBehavior: Bound
import QtQuick
import qs.config
import qs.services

// The OSD section's first card (its `x-card`): the OSDs as tabs, one shown
// at a time: where it sits (a screen picker with presets), a Show button,
// and its settings and bars (EntryListCard).
EntryListCard {
  id: root

  sectionKey: "OSD"
  listKey: "osds"
  entryType: "OSDEntry"
  savedEntries: OSDConfig.osds
  title: I18n.tr("OSDs")
  pickerHint: I18n.tr("Click a spot to place it; fine-tune below. Show opens it as a change would.")
  idBase: "osd"
  // A second OSD held off the right edge, so it doesn't sit on the first
  seed: ({
      "edge": "Right",
      "detached": true,
      "bars": [
        {
          "type": "brightness",
          "icon": "",
          "showOsd": true
        }
      ]
    })
  labelOf: osd => OSDConfig.labelOf(osd)
  onShow: id => ShellManager.showOsd(id)
}
