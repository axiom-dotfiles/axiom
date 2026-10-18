pragma Singleton
import QtQuick

// Groups themes into the families the theme list shows (a dark/light pair
// is one theme) and finds the family a theme name belongs to, for
// ThemeManager. No file access, processes or services.
QtObject {
  id: root

  // `themes`: [{ name, label, variant, paired, preview }]. Returns one family
  // { label, dark, light, darkPreview, lightPreview, shared, generated,
  // community } per dark theme and per light theme no dark names, sorted by
  // label. A dark joins the light its `paired` names. A light names one dark
  // back: that pair is the family's main one, labelled by the words their
  // names share ("Tokyo Night" + "Tokyo Day" = "Tokyo"); every other dark
  // naming it shares it (`shared`) and keeps its own label ("Tokyo Storm").
  function build(themes, generated, community = false) {
    const byName = themes.reduce((map, theme) => {
      map[theme.name] = theme;
      return map;
    }, {});
    const lightOf = theme => {
      const pair = byName[theme.paired];
      return theme.variant === "dark" && pair && pair.variant === "light" ? pair : null;
    };
    const claimed = {};
    const families = [];
    const add = (dark, light, label, shared) => families.push({
        "label": label,
        "dark": dark?.name ?? "",
        "light": light?.name ?? "",
        "darkPreview": dark?.preview ?? null,
        "lightPreview": light?.preview ?? null,
        "shared": shared,
        "generated": generated,
        "community": community
      });
    for (const theme of themes) {
      const light = lightOf(theme);
      if (!light)
        continue;
      claimed[light.name] = true;
      const main = light.paired === theme.name;
      add(theme, light, main ? root.commonLabel(theme.label, light.label) : theme.label, !main);
    }
    for (const theme of themes) {
      if (theme.variant === "dark" ? !lightOf(theme) : !claimed[theme.name])
        add(theme.variant === "dark" ? theme : null, theme.variant === "light" ? theme : null, theme.label, false);
    }
    return families.sort((a, b) => a.label.localeCompare(b.label));
  }

  // The leading words `a` and `b` share, or `a` when they share none
  function commonLabel(a, b) {
    const wordsA = a.split(" ");
    const wordsB = b.split(" ");
    let n = 0;
    while (n < wordsA.length && n < wordsB.length && wordsA[n] === wordsB[n])
      n++;
    return n > 0 ? wordsA.slice(0, n).join(" ") : a;
  }

  // The family `theme` belongs to, or null. A light several families share
  // belongs to the one whose dark is `lightFrom` (the dark it was switched
  // to light from), else to its main family.
  function current(families, theme, lightFrom) {
    const withLight = families.filter(family => family.light === theme);
    return families.find(family => family.dark === theme) ?? withLight.find(family => family.dark === lightFrom) ?? withLight.find(family => !family.shared) ?? withLight[0] ?? null;
  }
}
