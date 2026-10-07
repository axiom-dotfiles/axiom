pragma Singleton
import QtQuick

// Sharing a config. Each setting's `x-scope` in the schema says whether it
// belongs to the look of a desktop or to the PC and person it runs for
// (inherited from the nearest ancestor that sets one; the root is machine):
//   look      how the desktop looks and is laid out
//   personal  habits that travel only when asked for: keybinds, apps,
//             commands, pinned and favourite apps
//   machine   what only means something here: monitors, wallpapers,
//             accounts, paths, hardware and services
// Example setups (examples/*.json) and exported configs hold the look (and,
// when asked, the personal) parts. Applying one replaces those parts of the
// running config and leaves the rest as the user set it.
QtObject {
  id: root

  // The parts of `config` a shared file holds: the look, and the personal
  // parts too when `personal` is set, never a takeover setting
  function pick(config, schema, personal = false) {
    return _pick(config, schema, "machine", _kept(personal), schema) ?? {};
  }

  // A copy of `current` with the example's parts in place of its own. Both
  // are whole configs of the same version (load the example first, so it is
  // migrated and filled). A part replaces the current one outright, so
  // nothing of the old layout (a bar, a menu) is left behind; inside it,
  // what isn't taken (a bar's monitor, a dock's pinned apps) stays the
  // user's, from the same item: by id or name, or else (machine values
  // only) by position. With no such item it is the default.
  function apply(current, example, schema, personal = false) {
    return _merge(current, example, schema, "machine", _kept(personal), true, schema);
  }

  // `config` without what loading fills back in: each key whose value is
  // the one it would get if it were missing
  function sparse(config, schema) {
    return _sparse(config, schema, schema);
  }

  // A copy of `config` with every `x-takeover` setting (one that takes
  // something over on this PC: the Hyprland mode, the lock screen, idle,
  // polkit, the greeter) as it is in `current`. Loading a saved config or
  // the defaults never changes them: each is switched by its own card,
  // which does the takeover or gives it back. `paths`: takeoverPaths(schema)
  // (ConfigManager.takeoverPaths).
  function keepTakeovers(config, current, paths) {
    const result = Utils.clone(config);
    for (const path of paths) {
      let from = current;
      let to = result;
      for (let i = 0; i < path.length - 1 && _isObject(from) && _isObject(to); i++) {
        from = from[path[i]];
        to = to[path[i]];
      }
      const key = path[path.length - 1];
      if (_isObject(from) && _isObject(to) && from[key] !== undefined)
        to[key] = Utils.clone(from[key]);
    }
    return result;
  }

  // Whether `a` and `b` are equal apart from the values at `paths` (as
  // keepTakeovers takes them), without copying either: a running config
  // against a snapshot, on every config change
  function equalApartFrom(a, b, paths) {
    if (paths.length === 0)
      return Utils.deepEqual(a, b);
    if (paths.some(path => path.length === 0))
      return true;
    if (!_isObject(a) || !_isObject(b))
      return Utils.deepEqual(a, b);
    const keys = Object.keys(a);
    if (keys.length !== Object.keys(b).length)
      return false;
    return keys.every(key => Object.prototype.hasOwnProperty.call(b, key) && equalApartFrom(a[key], b[key], paths.filter(path => path[0] === key).map(path => path.slice(1))));
  }

  // The paths ([key, …]) of the `x-takeover` settings, through objects only
  function takeoverPaths(schema) {
    const paths = [];
    const walk = (node, path, depth) => {
      node = SchemaValidation.resolveRef(node, schema);
      if (!node || depth > 20)
        return;
      if (node["x-takeover"] === true && path.length > 0) {
        paths.push(path);
        return;
      }
      for (const key in node.properties ?? {})
        walk(node.properties[key], path.concat([key]), depth + 1);
    };
    walk(schema, [], 0);
    return paths;
  }

  function _kept(personal) {
    return personal ? ["look", "personal"] : ["look"];
  }

  // { schema, scope } for `value` at `schema`: the $ref resolved, the oneOf
  // option for its type (schema null when none matches), the scope it has
  function _node(value, schema, scope, rootSchema) {
    let node = SchemaValidation.resolveRef(schema, rootSchema);
    scope = node?.["x-scope"] ?? scope;
    if (node?.oneOf)
      node = SchemaValidation.oneOfOption(value, node, rootSchema);
    return {
      schema: node ?? null,
      scope: node?.["x-scope"] ?? scope
    };
  }

  function _child(schema, key) {
    if (schema?.properties?.[key])
      return schema.properties[key];
    return typeof schema?.additionalProperties === "object" ? schema.additionalProperties : null;
  }

  function _isObject(value) {
    return typeof value === "object" && value !== null && !Array.isArray(value);
  }

  // Whether anything at or under `schema` has a kept scope
  function _carries(schema, scope, kept, rootSchema, depth = 0) {
    const node = SchemaValidation.resolveRef(schema, rootSchema);
    if (!node || depth > 40)
      return false;
    scope = node["x-scope"] ?? scope;
    if (kept.includes(scope))
      return true;
    const children = [].concat(node.oneOf ?? [], Object.values(node.properties ?? {}), node.items ? [node.items] : [], typeof node.additionalProperties === "object" ? [node.additionalProperties] : []);
    return children.some(child => _carries(child, scope, kept, rootSchema, depth + 1));
  }

  // `value` with only its kept parts, or undefined for none (a takeover
  // setting is never kept: loading one keeps the running value)
  function _pick(value, schema, scope, kept, rootSchema) {
    const node = _node(value, schema, scope, rootSchema);
    if (node.schema?.["x-takeover"] === true)
      return undefined;
    const keep = kept.includes(node.scope);
    if (Array.isArray(value)) {
      if (!keep)
        return undefined;
      return value.map(item => node.schema?.items ? _pick(item, node.schema.items, node.scope, kept, rootSchema) : Utils.clone(item)).filter(item => item !== undefined);
    }
    if (_isObject(value) && node.schema) {
      const result = {};
      for (const key in value) {
        const child = _child(node.schema, key);
        const picked = child ? _pick(value[key], child, node.scope, kept, rootSchema) : keep ? Utils.clone(value[key]) : undefined;
        if (picked !== undefined)
          result[key] = picked;
      }
      return keep || Object.keys(result).length > 0 ? result : undefined;
    }
    return keep ? Utils.clone(value) : undefined;
  }

  // The applied value at one place. `strict`: `current` is the example's
  // item by id or name all the way up, not just by position, so a personal
  // value not taken carries over from it.
  function _merge(current, example, schema, scope, kept, strict, rootSchema) {
    const node = _node(example !== undefined ? example : current, schema, scope, rootSchema);
    if (!kept.includes(node.scope))
      return _keep(current, example, node, kept, strict, rootSchema);
    if (example === undefined)
      return Utils.clone(current);
    if (Array.isArray(example)) {
      const items = node.schema?.items;
      return example.map((item, i) => {
        if (!items)
          return Utils.clone(item);
        const match = _match(current, item, i);
        return _merge(match.item, item, items, node.scope, kept, strict && match.strict, rootSchema);
      }).filter(item => item !== undefined);
    }
    if (_isObject(example) && node.schema) {
      // An item of another type has none of this one's values
      if (_isObject(current) && current.type !== example.type)
        current = undefined;
      const result = {};
      for (const key in example) {
        const child = _child(node.schema, key);
        const merged = child ? _merge(current?.[key], example[key], child, node.scope, kept, strict, rootSchema) : Utils.clone(example[key]);
        if (merged !== undefined)
          result[key] = merged;
      }
      return result;
    }
    return Utils.clone(example);
  }

  // A part not taken from the example: the user's (a personal one only from
  // a strict match), or else its default. Its kept parts are still taken.
  function _keep(current, example, node, kept, strict, rootSchema) {
    const usable = current !== undefined && (node.scope === "machine" || strict);
    if (_isObject(current) && _isObject(example) && node.schema && _carries(node.schema, node.scope, kept, rootSchema)) {
      const result = {};
      const keys = Object.keys(Object.assign({}, current, example));
      for (const key of keys) {
        const child = _child(node.schema, key);
        const merged = child ? _merge(usable ? current[key] : undefined, example[key], child, node.scope, kept, strict, rootSchema) : Utils.clone(usable ? current[key] : example[key]);
        if (merged !== undefined)
          result[key] = merged;
      }
      return result;
    }
    if (usable)
      return Utils.clone(current);
    return node.schema ? SchemaValidation.applyDefaults(undefined, node.schema, rootSchema) : undefined;
  }

  // The item of `list` that `item` (at `index` in its own list) stands for:
  // { item, strict }, strict when found by id or name
  function _match(list, item, index) {
    if (!Array.isArray(list))
      return {
        item: undefined,
        strict: false
      };
    for (const key of ["id", "name"]) {
      const value = item?.[key];
      if (typeof value !== "string" || value === "")
        continue;
      const found = list.find(other => other?.[key] === value);
      if (found !== undefined)
        return {
          item: found,
          strict: true
        };
    }
    return {
      item: list[index],
      strict: false
    };
  }

  function _sparse(value, schema, rootSchema) {
    const node = _node(value, schema, "", rootSchema).schema;
    if (Array.isArray(value))
      return value.map(item => node?.items ? _sparse(item, node.items, rootSchema) : Utils.clone(item));
    if (!_isObject(value) || !node)
      return Utils.clone(value);
    const result = {};
    for (const key in value) {
      const child = _child(node, key);
      // `type` picks a oneOf's option, which is how the rest fills in
      if (child && key !== "type" && Utils.deepEqual(value[key], SchemaValidation.applyDefaults(undefined, child, rootSchema)))
        continue;
      result[key] = child ? _sparse(value[key], child, rootSchema) : Utils.clone(value[key]);
    }
    return result;
  }
}
