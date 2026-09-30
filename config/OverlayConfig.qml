pragma Singleton
import QtQuick
import qs.services
import qs.components.methods

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

  // Card grid layout (see OverlayLayout for the geometry). Card
  // radius/border follow Appearance so the overlay matches the shell.
  readonly property int cardUnit: OverlayLayout.cardUnit
  readonly property int cardSpacing: OverlayLayout.cardSpacing
  readonly property int cardPadding: 12
  // The inner padding a module lays its content out within (Card/Panel
  // `pad`): none when bare, less in a quarter slot
  function cardPad(compact, bare) {
    return bare ? 0 : compact ? cardPadding * 0.75 : cardPadding * 1.5;
  }
  // A screen fits this many cards across its free height / width; the
  // smaller of the two sizes the cards, so height decides on landscape
  // screens and width on portrait ones. Cards never go below minCardUnit.
  readonly property real fitCardsHigh: 2.5
  readonly property real fitCardsWide: 4.5
  readonly property int minCardUnit: 280

  readonly property var layouts: OverlayLayout.layouts
  readonly property real halfUnit: OverlayLayout.halfUnitOf(cardUnit)
  function halfUnitOf(unit) {
    return OverlayLayout.halfUnitOf(unit);
  }
  function span(n, unit) {
    return OverlayLayout.span(n, unit);
  }
  function slotShape(rect) {
    return OverlayLayout.slotShape(rect);
  }
  function columnFlow(cells, unit, target, extra) {
    return OverlayLayout.columnFlow(cells, unit, target, extra);
  }

  // Whether a module type may sit in a slot of the given rect
  function fits(type, rect) {
    const info = moduleInfo(type);
    return !info || OverlayLayout.fitsShapes(info.shapes, rect);
  }

  // The one-slot layout a module gets a cell of its own in: a card if it
  // fits a square, else Tall or Wide
  function bestLayoutFor(type) {
    return ["Single", "Tall", "Wide", "Large"].find(name => fits(type, layouts[name].slots.main)) ?? "Single";
  }
}
