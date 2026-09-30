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
  seed: ({
      "placement": "floating",
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

  // I18n.tr("Top edge") I18n.tr("Bottom edge") I18n.tr("Left edge") I18n.tr("Right edge")
  // I18n.tr("Center") I18n.tr("Upper third") I18n.tr("Lower third")
  // Places the picker offers: an edge's middle, or floating in the middle
  // or a third of the way up or down
  presets: [
    {
      "label": "Top edge",
      "values": {
        "placement": "edge",
        "edge": "Top",
        "position": 50
      },
      "x": 0.5,
      "y": 0
    },
    {
      "label": "Bottom edge",
      "values": {
        "placement": "edge",
        "edge": "Bottom",
        "position": 50
      },
      "x": 0.5,
      "y": 1
    },
    {
      "label": "Left edge",
      "values": {
        "placement": "edge",
        "edge": "Left",
        "position": 50
      },
      "x": 0,
      "y": 0.5
    },
    {
      "label": "Right edge",
      "values": {
        "placement": "edge",
        "edge": "Right",
        "position": 50
      },
      "x": 1,
      "y": 0.5
    },
    {
      "label": "Center",
      "values": {
        "placement": "floating",
        "x": 50,
        "y": 50
      },
      "x": 0.5,
      "y": 0.5
    },
    {
      "label": "Upper third",
      "values": {
        "placement": "floating",
        "x": 50,
        "y": 67
      },
      "x": 0.5,
      "y": 0.33
    },
    {
      "label": "Lower third",
      "values": {
        "placement": "floating",
        "x": 50,
        "y": 33
      },
      "x": 0.5,
      "y": 0.67
    }
  ]

  // Where an OSD sits, 0-1 from the top left of the screen
  spotOf: osd => {
    if (osd.placement === "floating")
      return Qt.point(osd.x / 100, 1 - osd.y / 100);
    const along = osd.position / 100;
    switch (osd.edge) {
    case "Top":
      return Qt.point(along, 0);
    case "Left":
      return Qt.point(0, along);
    case "Right":
      return Qt.point(1, along);
    }
    return Qt.point(along, 1);
  }
}
