pragma Singleton
import QtQuick
import qs.services

// Overlay: the configured views, plus the card grid's layout constants.
// (Named OverlayConfig because `Overlay` is the module type.)
QtObject {
  readonly property var views: ConfigManager.config.Overlay.views
  // Card size as a percentage of what fits the screen (see OverlayGrid)
  readonly property int size: ConfigManager.config.Overlay.size
  // "general" | "primaryBar" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: ConfigManager.config.Overlay.monitors
  readonly property bool closeOnEscape: ConfigManager.config.Overlay.closeOnEscape
  readonly property bool closeOnOutsideClick: ConfigManager.config.Overlay.closeOnOutsideClick

  // What the overlay editor offers, read from the schema's oneOfs so new
  // module/view types show up there automatically
  function _oneOfTypes(definition) {
    const schema = ConfigManager.configSchema;
    return (schema?.definitions?.[definition]?.oneOf ?? []).map(option => {
      const def = schema.definitions[option.$ref.replace("#/definitions/", "")];
      const type = def?.properties?.type;
      if (!type?.const)
        return null;
      return {
        "type": type.const,
        "label": type.description || type.const,
        "propertiesSchema": def.properties?.properties?.properties ?? null,
        // Slot shapes a module fits (`x-shapes`); views don't declare any
        "shapes": def["x-shapes"] ?? ["square", "horizontal", "vertical"],
        // Material Symbols name (`x-icon`)
        "icon": def["x-icon"] ?? "extension",
        // Where a module may be placed (`x-hosts`): "overlay", "edgeMenu"
        "hosts": def["x-hosts"] ?? ["overlay", "edgeMenu"]
      };
    }).filter(t => t !== null);
  }
  readonly property var availableModuleTypes: _oneOfTypes("OverlayModule")
  readonly property var availableViewTypes: _oneOfTypes("OverlayView")
  // The module types a host offers: "overlay" pages or "edgeMenu"s
  function modulesFor(host) {
    return availableModuleTypes.filter(t => t.hosts.includes(host));
  }
  function allowedIn(type, host) {
    const info = moduleInfo(type);
    return !info || info.hosts.includes(host);
  }

  function moduleInfo(type) {
    return availableModuleTypes.find(t => t.type === type) ?? null;
  }
  function viewInfo(type) {
    return availableViewTypes.find(t => t.type === type) ?? null;
  }
  // How a page is named and drawn in the page navigator and the overlay
  // editor: a Custom page by its name (or its place), others by type
  // (i18n: keys from the schema's view labels)
  function viewLabel(view, index) {
    if (view?.type === "Custom")
      return view.name || I18n.tr("Page {0}", index + 1);
    const label = viewInfo(view?.type)?.label ?? view?.type ?? "";
    return I18n.tr(label);
  }
  function viewIcon(type) {
    return viewInfo(type)?.icon ?? "dashboard";
  }

  // The page to open for a module type (what openOverlayPage takes): the
  // named Custom page where it has the biggest slot, "" when no page has it
  function pageWithModule(type) {
    let best = "";
    let bestArea = 0;
    (views ?? []).forEach(view => {
      if (view?.type !== "Custom" || !view.name || view.visible === false)
        return;
      (view.columns ?? []).forEach(column => (column?.cells ?? []).forEach(cell => {
          const layout = layouts[cell?.layout];
          Object.keys(cell?.slots ?? {}).forEach(slot => {
            if (cell.slots[slot]?.type !== type)
              return;
            const rect = layout?.slots?.[slot] ?? [0, 0, 1, 1];
            const area = rect[2] * rect[3];
            if (area > bestArea) {
              best = view.name;
              bestArea = area;
            }
          });
        }));
    });
    return best;
  }

  // Card grid layout — internal design constants, not user settings.
  // Card radius/border follow Appearance so the overlay matches the shell.
  // cardUnit is the reference card size: the largest a card gets at 100%
  // (each overlay's OverlayGrid sizes its cards to its screen, up to this).
  readonly property int cardUnit: 500
  readonly property int cardSpacing: 20
  readonly property int cardPadding: 12
  // A screen fits this many cards across its free height / width; the
  // smaller of the two sizes the cards, so height decides on landscape
  // screens and width on portrait ones. Cards never go below minCardUnit.
  readonly property real fitCardsHigh: 2.5
  readonly property real fitCardsWide: 4.5
  readonly property int minCardUnit: 280

  // Cells are laid out on a grid of half cards: a span of n half units is
  // n halves plus the n - 1 gaps between them, so span(2) is one card and
  // span(4) is two cards plus the gap between them. `unit` is the card
  // size (the reference cardUnit unless given).
  function halfUnitOf(unit) {
    return ((unit ?? cardUnit) - cardSpacing) / 2;
  }
  readonly property real halfUnit: halfUnitOf(cardUnit)
  function span(n, unit) {
    return n * halfUnitOf(unit) + (n - 1) * cardSpacing;
  }

  // A slot's shape, from its [col, row, colSpan, rowSpan] rect
  function slotShape(rect) {
    return rect[2] === rect[3] ? "square" : rect[2] > rect[3] ? "horizontal" : "vertical";
  }

  // Whether a module type may sit in a slot of the given rect
  function fits(type, rect) {
    const info = moduleInfo(type);
    return !info || info.shapes.includes(slotShape(rect));
  }

  // The one-slot layout a module gets a cell of its own in: a card if it
  // fits a square, else Tall or Wide
  function bestLayoutFor(type) {
    return ["Single", "Tall", "Wide", "Large"].find(name => fits(type, layouts[name].slots.main)) ?? "Single";
  }

  // How a column flows its cells: left to right, wrapping at the widest
  // cell. Returns the unscaled size, the number of rows and each cell's
  // { x, y, width, height, row }, matching the Flow in OverlayColumn.
  function columnFlow(cells, unit) {
    const sizes = (cells ?? []).map(cell => {
      const layout = layouts[cell.layout] ?? layouts.Single;
      return [span(layout.cols, unit), span(layout.rows, unit)];
    });
    const width = Math.max(0, ...sizes.map(size => size[0]));
    let x = 0, rowHeight = 0, height = 0, rows = 0;
    const rects = [];
    sizes.forEach(([w, h]) => {
      if (x > 0 && x + w > width + 0.5) {
        height += rowHeight + cardSpacing;
        x = 0;
        rowHeight = 0;
      }
      if (x === 0)
        rows++;
      rects.push({
        "x": x,
        "y": height,
        "width": w,
        "height": h,
        "row": rows - 1
      });
      x += w + cardSpacing;
      rowHeight = Math.max(rowHeight, h);
    });
    return {
      "width": width,
      "height": height + rowHeight,
      "rows": rows,
      "rects": rects
    };
  }

  // Cell layouts, keyed by the `layout` name in config (keep in sync with
  // the OverlayCell enum in the schema). cols/rows are the cell's size in
  // half units; each slot is [col, row, colSpan, rowSpan] in half units.
  readonly property var layouts: ({
      "Single": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "main": [0, 0, 2, 2]
        }
      },
      "Tall": {
        "cols": 2,
        "rows": 4,
        "slots": {
          "main": [0, 0, 2, 4]
        }
      },
      "Wide": {
        "cols": 4,
        "rows": 2,
        "slots": {
          "main": [0, 0, 4, 2]
        }
      },
      "Large": {
        "cols": 4,
        "rows": 4,
        "slots": {
          "main": [0, 0, 4, 4]
        }
      },
      "Grid2x2": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "topLeft": [0, 0, 1, 1],
          "topRight": [1, 0, 1, 1],
          "bottomLeft": [0, 1, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      },
      "Vert1x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "left": [0, 0, 1, 2],
          "right": [1, 0, 1, 2]
        }
      },
      "Vert1x2": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "left": [0, 0, 1, 2],
          "topRight": [1, 0, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      },
      "Vert2x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "topLeft": [0, 0, 1, 1],
          "bottomLeft": [0, 1, 1, 1],
          "right": [1, 0, 1, 2]
        }
      },
      "Horiz1x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "top": [0, 0, 2, 1],
          "bottom": [0, 1, 2, 1]
        }
      },
      "Horiz1x2": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "top": [0, 0, 2, 1],
          "bottomLeft": [0, 1, 1, 1],
          "bottomRight": [1, 1, 1, 1]
        }
      },
      "Horiz2x1": {
        "cols": 2,
        "rows": 2,
        "slots": {
          "topLeft": [0, 0, 1, 1],
          "topRight": [1, 0, 1, 1],
          "bottom": [0, 1, 2, 1]
        }
      }
    })
}
