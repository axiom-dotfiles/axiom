pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io

import qs.config

/**
 * Chat API keys, which never go in config.json. A provider's key is the
 * first of:
 *   1. its `keyEnv` environment variable (e.g. ANTHROPIC_API_KEY)
 *   2. the keyring (Secret Service, through `secret-tool`), under
 *      `service axiom provider <id>`
 *   3. $XDG_STATE_HOME/axiom/secrets.json ({ "<id>": "…" }, mode 600)
 * setKey() stores a key in the keyring when one answers, else in the file.
 * Keys go to secret-tool and the file through stdin, never argv.
 */
QtObject {
  id: root

  readonly property string stateDir: Paths.userStatePath.replace(/\/$/, "")
  readonly property string secretsPath: stateDir + "/secrets.json"

  // Whether a Secret Service answered (null until the probe finishes)
  property var keyringAvailable: null

  // { providerId: "env" | "keyring" | "file" | "none" | "unneeded" }, for
  // the settings card. refresh() fills it in.
  property var statuses: ({})

  // Where a provider's key would come from; "" while it's being looked up
  function status(provider) {
    if (!provider)
      return "none";
    if (provider.auth === "none")
      return "unneeded";
    if (provider.keyEnv && Quickshell.env(provider.keyEnv))
      return "env";
    return root.statuses[provider.id] ?? "";
  }

  // Calls back with the provider's key, "" when there is none
  function withKey(provider, callback) {
    if (provider.auth === "none")
      return callback("");
    const fromEnv = provider.keyEnv ? Quickshell.env(provider.keyEnv) : "";
    if (fromEnv)
      return callback(fromEnv);
    if (root._cache[provider.id] !== undefined)
      return callback(root._cache[provider.id]);
    root._lookup(provider.id, key => callback(key));
  }

  // Looks every provider's key up again (after it changed elsewhere)
  function refresh(providers) {
    root._cache = {};
    root._secrets = root._read();
    for (const provider of providers ?? [])
      if (provider.auth !== "none")
        root._lookup(provider.id, () => {});
  }

  function setKey(provider, key) {
    const trimmed = String(key ?? "").trim();
    if (trimmed === "")
      return root.clearKey(provider);
    root._cache[provider.id] = trimmed;
    if (root.keyringAvailable) {
      root._run(["secret-tool", "store", "--label=" + "Axiom: " + (provider.name || provider.id), "service", "axiom", "provider", provider.id], trimmed, ok => {
        if (!ok) {
          console.warn("[SecretsManager] The keyring refused the key for", provider.id + "; saving it to", root.secretsPath);
          root._storeFile(provider.id, trimmed);
          return;
        }
        root._setStatus(provider.id, "keyring");
        // One place per key: the file's copy would outlive a later clear
        if (root._secrets[provider.id] !== undefined)
          root._storeFile(provider.id, undefined);
      });
      return;
    }
    root._storeFile(provider.id, trimmed);
  }

  function clearKey(provider) {
    delete root._cache[provider.id];
    if (root._secrets[provider.id] !== undefined)
      root._storeFile(provider.id, undefined);
    if (root.keyringAvailable)
      root._run(["secret-tool", "clear", "service", "axiom", "provider", provider.id], null, () => root._lookup(provider.id, () => {}));
    else
      root._setStatus(provider.id, "none");
  }

  // Keys ConfigMigration pulled out of an old config: into the file, as
  // before (the keyring may not be up this early)
  function store(entries) {
    Object.keys(entries).forEach(id => root._storeFile(id, entries[id]));
  }

  // -- Private --

  property var _secrets: _read()
  // Keys looked up this session, so each request doesn't run secret-tool
  property var _cache: ({})

  function _setStatus(id, value) {
    const next = Object.assign({}, root.statuses);
    next[id] = value;
    root.statuses = next;
  }

  function _lookup(id, callback) {
    const fromFile = () => {
      const key = root._secrets[id] ?? "";
      root._cache[id] = key;
      root._setStatus(id, key ? "file" : "none");
      callback(key);
    };
    if (!root.keyringAvailable)
      return fromFile();
    root._run(["secret-tool", "lookup", "service", "axiom", "provider", id], null, (ok, out) => {
      const key = ok ? out.trim() : "";
      if (!key)
        return fromFile();
      root._cache[id] = key;
      root._setStatus(id, "keyring");
      callback(key);
    });
  }

  function _storeFile(id, key) {
    const merged = Object.assign({}, root._secrets);
    if (key === undefined)
      delete merged[id];
    else
      merged[id] = key;
    root._secrets = merged;
    if (key !== undefined)
      root._setStatus(id, "file");
    else if (root.statuses[id] === "file")
      root._setStatus(id, "none");
    // chmod also fixes an existing file's mode
    root._run(["sh", "-c", "umask 077 && mkdir -p \"$(dirname \"$1\")\" && cat > \"$1\" && chmod 600 \"$1\"", "sh", root.secretsPath], JSON.stringify(merged, null, 2), ok => {
      if (!ok)
        console.warn("[SecretsManager] Failed to write", root.secretsPath);
    });
  }

  function _read() {
    const content = FileManager.read("file://" + root.secretsPath);
    if (!content)
      return {};
    try {
      return JSON.parse(content);
    } catch (e) {
      console.warn("[SecretsManager] Could not parse", root.secretsPath, e);
      return {};
    }
  }

  // Runs a command, writing `input` (if any) to its stdin, then calls
  // back with (ok, stdout, stderr)
  function _run(command, input, callback) {
    const process = _processComponent.createObject(root, {
      command: command,
      input: input ?? "",
      stdinEnabled: input !== null && input !== undefined
    });
    process.done.connect((ok, out, err) => {
      callback(ok, out, err);
      process.destroy();
    });
    process.running = true;
  }

  property Component _processComponent: Component {
    Process {
      id: process
      property string input: ""
      signal done(bool ok, string out, string err)

      stdout: StdioCollector {
        id: out
      }
      stderr: StdioCollector {
        id: err
      }
      onStarted: {
        if (!process.stdinEnabled)
          return;
        process.write(process.input);
        process.input = "";
        process.stdinEnabled = false;
      }
      onExited: code => process.done(code === 0, out.text, err.text)
    }
  }

  Component.onCompleted: {
    // `lookup` of something never stored fails quietly (exit 1, nothing on
    // stderr) when a Secret Service answers, and complains when none does
    root._run(["sh", "-c", "command -v secret-tool >/dev/null || { echo 'secret-tool is not installed' >&2; exit 127; }; exec secret-tool lookup service axiom-probe probe probe"], null, (ok, out, err) => {
      root.keyringAvailable = err.trim() === "";
      if (!root.keyringAvailable)
        console.log("[SecretsManager] No keyring:", err.trim(), "- keys go to", root.secretsPath);
      root.refresh(ChatConfig.providers);
    });
  }
}
