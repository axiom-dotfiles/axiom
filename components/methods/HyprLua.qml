pragma Singleton
import QtQuick

// Hyprland's Lua config from schema fields: each field with `x-hypr` (the
// option's dotted path, or a list of paths) becomes one value of a nested
// hl.config({...}) table.
//   x-hyprScale   a factor for integers shown scaled (0.01 for a percent)
//   x-hyprValue   how the value is converted: "int" (a boolean as 0/1),
//                 "number" (an enum of numbers written as strings),
//                 "emptyIsDefault" ("default" → ""), "color" (a theme color
//                 name as rgba(hex + x-hyprAlpha, "ff" unless given))
//   x-hyprAlways  written even when it's the schema default; other fields
//                 are only written once changed, so Hyprland's own default
//                 (and the user's files) stay in charge otherwise
//   x-hyprIf      a boolean sibling: written (default or not) only when on
QtObject {
  id: root

  // A Lua string literal
  function string(text) {
    return '"' + String(text).replace(/\\/g, "\\\\").replace(/"/g, '\\"').replace(/\n/g, "\\n") + '"';
  }

  // A value as Lua: strings quoted, numbers without float noise
  function value(v) {
    if (typeof v === "string")
      return string(v);
    if (typeof v === "number")
      return String(Math.round(v * 10000) / 10000);
    return String(v);
  }

  function _convert(fieldSchema, v, resolveHex) {
    if (fieldSchema["x-hyprScale"] !== undefined)
      return v * fieldSchema["x-hyprScale"];
    switch (fieldSchema["x-hyprValue"]) {
    case "int":
      return v ? 1 : 0;
    case "number":
      return Number(v);
    case "emptyIsDefault":
      return v === "default" ? "" : v;
    case "color":
      return `rgba(${resolveHex(v)}${fieldSchema["x-hyprAlpha"] ?? "ff"})`;
    }
    return v;
  }

  function _set(table, path, v) {
    const keys = path.split(".");
    let node = table;
    for (const key of keys.slice(0, -1)) {
      if (typeof node[key] !== "object" || node[key] === null)
        node[key] = {};
      node = node[key];
    }
    node[keys[keys.length - 1]] = v;
  }

  // The nested option table for `values` (an object of `objectSchema`'s
  // fields). resolveHex(colorName) gives "rrggbb"; `overrides` maps option
  // paths to values that win over the fields (axiom's shape, say).
  function configTable(objectSchema, values, resolveHex, overrides) {
    const table = {};
    const props = objectSchema?.properties ?? {};
    for (const key in props) {
      const fieldSchema = props[key];
      const target = fieldSchema["x-hypr"];
      if (!target || values[key] === undefined)
        continue;
      const condition = fieldSchema["x-hyprIf"];
      if (condition ? !values[condition] : !fieldSchema["x-hyprAlways"] && values[key] === fieldSchema.default)
        continue;
      const v = _convert(fieldSchema, values[key], resolveHex);
      // A schema list reaches QML as a list object, not a JS Array
      const paths = typeof target === "string" ? [target] : Array.prototype.slice.call(target);
      for (const path of paths)
        _set(table, path, v);
    }
    for (const path in overrides ?? {})
      _set(table, path, overrides[path]);
    return table;
  }

  // A table as a Lua literal, keys sorted. Nested tables go on lines of
  // their own below the top level, until one fits on a line.
  function serialize(table, indent) {
    const pad = indent ?? "";
    const keys = Object.keys(table).sort();
    const entry = key => {
      const v = table[key];
      return `${key} = ${typeof v === "object" ? serialize(v, pad + "  ") : value(v)}`;
    };
    const flat = `{ ${keys.map(entry).join(", ")} }`;
    if (keys.length === 0)
      return "{}";
    if (pad !== "" && flat.length <= 100 && !flat.includes("\n"))
      return flat;
    return `{\n${keys.map(key => `${pad}  ${entry(key)},`).join("\n")}\n${pad}}`;
  }
}
