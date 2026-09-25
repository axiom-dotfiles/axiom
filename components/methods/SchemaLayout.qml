pragma Singleton
import QtQuick

/**
 * Turns the config schema into the settings page's layout: categories
 * (`x-category` on each top-level section, in schema order), each made of
 * groups (the section's own fields, then one per nested object), each made
 * of form rows for SchemaField. Keys marked `x-settings: false` are
 * skipped (edited elsewhere: the bar editor, the Themes page, ...).
 * Depends on the schema only, so it's safe as a Repeater model.
 */
QtObject {
  id: root

  // Flattens an object schema into form rows:
  //   { kind: "group", title, path }         for a nested object
  //   { kind: "field", title, path, schema } for an editable value
  //   { kind: "array", title, path, schema } for an array of objects
  function rows(objectSchema, path) {
    const result = [];
    for (const key in objectSchema.properties ?? {}) {
      const prop = objectSchema.properties[key];
      if (prop["x-settings"] === false)
        continue;
      const propPath = path.concat(key);
      if (prop.type === "object" && prop.properties) {
        const children = rows(prop, propPath);
        if (children.length > 0) {
          result.push({
            "kind": "group",
            "title": prop.title ?? key,
            "path": propPath
          });
          result.push(...children);
        }
      } else if (prop.type === "array" && prop.items?.properties) {
        result.push({
          "kind": "array",
          "title": prop.title ?? key,
          "path": propPath,
          "schema": prop
        });
      } else if (["boolean", "integer", "string"].includes(prop.type) || (prop.type === "array" && prop.items?.type === "string")) {
        result.push({
          "kind": "field",
          "title": prop.title ?? key,
          "path": propPath,
          "schema": prop
        });
      }
    }
    return result;
  }

  // `x-showIf: { sibling: value | [values] | { not: value } }`: whether
  // it holds, with valueOf(key) giving a sibling's value. A key starting
  // with `/` is a dotted path from the config's root ("/Workspaces.layout"),
  // which valueOf resolves too (callers use SettingsManager.configValueAt).
  function showIfHolds(condition, valueOf) {
    if (!condition)
      return true;
    return Object.keys(condition).every(key => {
      const want = condition[key];
      const value = valueOf(key);
      // Passed in from another file, a schema array arrives as a list
      // object, not a JS Array
      if (want !== null && typeof want === "object" && typeof want.length === "number")
        return Array.prototype.includes.call(want, value);
      if (want !== null && typeof want === "object")
        return value !== want.not;
      return value === want;
    });
  }

  // One section as cards: { kind, key, title, description, section, path,
  // rows, showIf, showIfParent }. The section's direct values make the
  // first card (titled by the section), each nested object the next ones.
  // Fields with `x-group` go on a card of that name instead, so one object
  // can make several cards. A nested object's `x-showIf` (on its siblings)
  // applies to all its cards. A section's `x-card` names a hand-built card
  // (settings/<name>Card.qml) that goes first.
  function groups(schema, sectionKey) {
    const section = schema.properties[sectionKey];
    const sectionTitle = section.title ?? sectionKey;
    const result = [];
    if (section["x-card"])
      result.push({
        "kind": "card",
        "key": sectionKey + ":" + section["x-card"],
        "card": section["x-card"],
        "title": sectionTitle,
        "description": "",
        "section": sectionTitle,
        "path": [sectionKey],
        "rows": [],
        "showIf": null,
        "showIfParent": []
      });

    // Cards by title, in order of first appearance
    const cards = [];
    function cardFor(title, base) {
      let card = cards.find(c => c.title === title && c.path.join(".") === base.path.join("."));
      if (!card) {
        card = Object.assign({
          "kind": "rows",
          "title": title,
          "rows": []
        }, base);
        card.key = base.path.join(".") + (title === base.defaultTitle ? "" : ":" + title);
        cards.push(card);
      }
      return card;
    }

    function place(objectSchema, path, base) {
      for (const key in objectSchema.properties ?? {}) {
        const prop = objectSchema.properties[key];
        if (prop["x-settings"] === false)
          continue;
        const fieldRows = root.rows({
          "properties": {
            [key]: prop
          }
        }, path);
        if (fieldRows.length > 0)
          cardFor(prop["x-group"] ?? base.defaultTitle, base).rows.push(...fieldRows);
      }
    }

    // Direct values first, then each nested object
    const direct = {};
    const nested = [];
    for (const key in section.properties ?? {}) {
      const prop = section.properties[key];
      if (prop.type === "object" && prop.properties)
        nested.push(key);
      else
        direct[key] = prop;
    }
    place({
      "properties": direct
    }, [sectionKey], {
      "defaultTitle": sectionTitle,
      "description": section.description ?? "",
      "section": sectionTitle,
      "path": [sectionKey],
      "showIf": null,
      "showIfParent": []
    });
    for (const key of nested) {
      const prop = section.properties[key];
      if (prop["x-settings"] === false)
        continue;
      place(prop, [sectionKey, key], {
        "defaultTitle": prop.title ?? key,
        "description": prop.description ?? "",
        "section": sectionTitle,
        "path": [sectionKey, key],
        "showIf": prop["x-showIf"] ?? null,
        "showIfParent": [sectionKey]
      });
    }
    // A description belongs to the object's first card only
    const seen = new Set();
    for (const card of cards) {
      const path = card.path.join(".");
      if (seen.has(path))
        card.description = "";
      seen.add(path);
      delete card.defaultTitle;
    }
    return result.concat(cards);
  }

  // [{ name, sections: [key], links: [page type] }], in schema order.
  // A section without `x-category` is a category of its own.
  function categories(schema) {
    const result = [];
    for (const key in schema?.properties ?? {}) {
      const section = schema.properties[key];
      if (section.type !== "object" || section["x-settings"] === false || groups(schema, key).length === 0)
        continue;
      const name = section["x-category"] ?? section.title ?? key;
      let category = result.find(c => c.name === name);
      if (!category) {
        category = {
          "name": name,
          "sections": [],
          "links": []
        };
        result.push(category);
      }
      category.sections.push(key);
      for (const link of section["x-links"] ?? [])
        if (!category.links.includes(link))
          category.links.push(link);
    }
    return result;
  }
}
