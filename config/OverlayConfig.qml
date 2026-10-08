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
  // "general" | "primary" | "focused" | "all" (see General.screensFor)
  readonly property string monitors: ConfigManager.config.Overlay.monitors
  readonly property bool closeOnEscape: ConfigManager.config.Overlay.closeOnEscape
  readonly property bool closeOnOutsideClick: ConfigManager.config.Overlay.closeOnOutsideClick

  // The pages that aren't in config, after the configured ones: the
  // layouts editor (overlay pages and edge menus), which can't be removed.
  // Labels: I18n.tr("Layouts")
  readonly property var pinnedPages: [
    {
      "type": "Layouts",
      "icon": "dashboard_customize",
      "label": "Layouts"
    }
  ]

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
        // Its options shown first, in order (their `x-order`)
        "propertiesOrder": def.properties?.properties?.["x-order"] ?? [],
        // The size a module is added at ([w, h] in grid units, four to a
        // card; `x-defaultSize`), null when not declared
        "defaultSize": def["x-defaultSize"] ?? null,
        // The least a drop into a gap shrinks it to (`x-minSize`), null
        // when not declared
        "minSize": def["x-minSize"] ?? null,
        // A tool page (`x-tool`), shown apart from the user's own pages
        "tool": def["x-tool"] === true,
        // Material Symbols name (`x-icon`)
        "icon": def["x-icon"] ?? "extension",
        // Where a module may be placed (`x-hosts`): "overlay", "edgeMenu",
        // "lockscreen" (only modules that list it)
        "hosts": def["x-hosts"] ?? ["overlay", "edgeMenu"],
        // Part of every grid on its hosts (`x-required`): never removed,
        // duplicated or offered in the library
        "required": def["x-required"] === true,
        // The property shown on its layouts editor tile (`x-canvasDetail`),
        // and the color property filling it (`x-canvasFill`), else ""
        "canvasDetail": def["x-canvasDetail"] ?? "",
        "canvasFill": def["x-canvasFill"] ?? ""
      };
    }).filter(t => t !== null);
  }
  readonly property var availableModuleTypes: _oneOfTypes("OverlayModule")
  // A Custom page's own fields (name, icon), for the layouts editor
  readonly property var customViewSchema: ConfigManager.configSchema.definitions.CustomOverlayView.properties
  readonly property var availableViewTypes: _oneOfTypes("OverlayView")
  // The module types a host's library offers: "overlay" pages,
  // "edgeMenu"s or the "lockscreen" (required ones are always there)
  function modulesFor(host) {
    return availableModuleTypes.filter(t => t.hosts.includes(host) && !t.required);
  }
  // The required module types on a host
  function requiredFor(host) {
    return availableModuleTypes.filter(t => t.hosts.includes(host) && t.required).map(t => t.type);
  }
  function isRequired(type) {
    return moduleInfo(type)?.required ?? false;
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
  // What opens a page by name (`openOverlayPage`, a bar Button or bind's
  // `overlayPage` action): a Custom page's name, other pages' type; "" for
  // a Custom page with no name
  function pageKey(view) {
    return view?.type === "Custom" ? view.name ?? "" : view?.type ?? "";
  }
  function viewIcon(type) {
    return pinnedPages.find(page => page.type === type)?.icon ?? viewInfo(type)?.icon ?? "dashboard";
  }
  // A page's icon: a Custom page's own, else its type's
  function pageIcon(view) {
    return (view?.type === "Custom" && view.icon) || viewIcon(view?.type);
  }
  function isTool(type) {
    return viewInfo(type)?.tool ?? false;
  }

  // The page to open for a module type (what openOverlayPage takes): the
  // named Custom page where it's biggest, "" when no page has it
  function pageWithModule(type) {
    let best = "";
    let bestArea = 0;
    (views ?? []).forEach(view => {
      if (view?.type !== "Custom" || !view.name || view.visible === false)
        return;
      (view.modules ?? []).forEach(module => {
        const area = module?.type === type ? module.place.w * module.place.h : 0;
        if (area > bestArea) {
          best = view.name;
          bestArea = area;
        }
      });
    });
    return best;
  }

  // Card grid layout (see GridPlacement for the geometry). Card radius/border
  // follow Appearance so the overlay matches the shell.
  readonly property int cardUnit: GridPlacement.cardUnit
  readonly property int cardSpacing: GridPlacement.cardSpacing
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
  // The card size for `width` × `height` px of free space: what fits,
  // capped at the reference cardUnit, then scaled by Overlay size
  function cardUnitFor(width, height) {
    const fit = Math.min(height / fitCardsHigh, width / fitCardsWide);
    return Math.round(Math.max(minCardUnit, Math.min(cardUnit, fit) * size / 100));
  }

  // One grid unit (a quarter card) at the reference card size
  readonly property real gridUnit: GridPlacement.unitOf(cardUnit)
  function span(n, unit) {
    return GridPlacement.span(n, unit);
  }
  function slotShape(rect) {
    return GridPlacement.slotShape(rect);
  }

  // The size [w, h] a module is added at: its declared one, else a card.
  // Modules take any size (each lays itself out for its slot), so this is
  // only a starting point
  function defaultSize(type) {
    return moduleInfo(type)?.defaultSize ?? [4, 4];
  }

  // The least [w, h] a module dropped into a gap is shrunk to fit it: its
  // declared one, else half its default size. Like the default, only a
  // starting point: it can still be resized smaller
  function minSize(type) {
    return moduleInfo(type)?.minSize ?? defaultSize(type).map(n => Math.max(1, Math.ceil(n / 2)));
  }
}
