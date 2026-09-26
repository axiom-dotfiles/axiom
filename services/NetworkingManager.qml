pragma Singleton
import QtQuick
import Quickshell.Networking

import qs.config

// Wi-Fi state and actions over NetworkManager (Quickshell.Networking, D-Bus,
// so nothing polls). Named NetworkingManager so it doesn't shadow
// Quickshell's `Networking` singleton. Scanning runs only while something
// has acquireScan()ed it (the Wi-Fi popout or card).
QtObject {
  id: root

  readonly property var devices: Networking.devices?.values ?? []
  readonly property var wifiDevice: devices.find(d => d.type === DeviceType.Wifi) ?? null
  readonly property var wiredDevice: devices.find(d => d.type === DeviceType.Wired) ?? null
  readonly property bool available: wifiDevice !== null
  readonly property bool wifiEnabled: Networking.wifiEnabled
  readonly property bool hardwareBlocked: !Networking.wifiHardwareEnabled
  readonly property bool scanning: wifiDevice?.scannerEnabled ?? false

  // Named networks: connected first, then saved, then by name. The order
  // doesn't follow signal strength, so a row never jumps away from the
  // pointer that's about to click it
  readonly property var networks: (wifiDevice?.networks?.values ?? []).filter(n => n.name).sort((a, b) => {
    const rank = n => n.connected ? 0 : n.known ? 1 : 2;
    return rank(a) - rank(b) || a.name.localeCompare(b.name);
  })
  readonly property var activeNetwork: networks.find(n => n.connected) ?? null

  // The network whose password was just asked for (a secured network
  // clicked, or a failed attempt), and the last failure per network name
  property var passwordFor: null
  property var failures: ({})

  function setWifiEnabled(on) {
    Networking.wifiEnabled = on;
  }

  function toggleWifi() {
    setWifiEnabled(!wifiEnabled);
  }

  function acquireScan(owner) {
    _scanRegistry.acquire(owner, {});
  }

  function releaseScan(owner) {
    _scanRegistry.release(owner);
  }

  function isSecure(network) {
    const s = network?.security;
    return s !== undefined && s !== WifiSecurityType.Open && s !== WifiSecurityType.Owe;
  }

  // Only these take a PSK (see WifiNetwork.connectWithPsk)
  function takesPsk(network) {
    const s = network?.security;
    return s === WifiSecurityType.WpaPsk || s === WifiSecurityType.Wpa2Psk || s === WifiSecurityType.Sae;
  }

  // Connected: disconnect. Saved or open: connect. Secured and new: ask
  // for the password.
  function toggleNetwork(network) {
    if (!network || network.stateChanging)
      return;
    _clearFailure(network);
    if (network.connected) {
      network.disconnect();
    } else if (network.known || !isSecure(network)) {
      network.connect();
    } else if (takesPsk(network)) {
      passwordFor = network;
    } else {
      // Enterprise and WEP networks need settings this menu can't enter
      _setFailure(network, "unsupported");
    }
  }

  function connectWithPsk(network, psk) {
    if (!network || psk === "")
      return;
    _clearFailure(network);
    passwordFor = null;
    network.connectWithPsk(psk);
  }

  function cancelPassword() {
    passwordFor = null;
  }

  function forget(network) {
    _clearFailure(network);
    network?.forget();
  }

  function networkStatus(network) {
    if (!network)
      return "";
    const failure = failures[network.name];
    if (failure === "unsupported")
      return I18n.tr("Needs settings this menu can't set");
    if (failure === ConnectionFailReason.NoSecrets)
      return I18n.tr("Wrong password");
    if (failure !== undefined)
      return I18n.tr("Couldn't connect");
    switch (network.state) {
    case ConnectionState.Connecting:
      return I18n.tr("Connecting…");
    case ConnectionState.Disconnecting:
      return I18n.tr("Disconnecting…");
    case ConnectionState.Connected:
      return I18n.tr("Connected");
    }
    if (network.known)
      return I18n.tr("Saved");
    return I18n.tr(isSecure(network) ? "Secured" : "Open");
  }

  function failed(network) {
    return network ? failures[network.name] !== undefined : false;
  }

  // Signal strength 0-1
  function signalIcon(strength) {
    if (strength >= 0.75)
      return "signal_wifi_4_bar";
    if (strength >= 0.5)
      return "network_wifi_3_bar";
    if (strength >= 0.25)
      return "network_wifi_2_bar";
    return "network_wifi_1_bar";
  }

  // -- Private --
  property ConsumerRegistry _scanRegistry: ConsumerRegistry {}

  // Scan while anything wants it and the radio is on
  property Binding _scanner: Binding {
    when: root.wifiDevice !== null
    target: root.wifiDevice
    property: "scannerEnabled"
    value: root._scanRegistry.active && root.wifiEnabled
    restoreMode: Binding.RestoreNone
  }

  function _setFailure(network, reason) {
    const next = Object.assign({}, failures);
    next[network.name] = reason;
    failures = next;
  }

  function _clearFailure(network) {
    if (!network || failures[network.name] === undefined)
      return;
    const next = Object.assign({}, failures);
    delete next[network.name];
    failures = next;
  }

  // A wrong or missing password asks again
  property Instantiator _failureWatcher: Instantiator {
    model: root.networks

    delegate: Connections {
      required property var modelData
      target: modelData

      function onConnectionFailed(reason) {
        root._setFailure(modelData, reason);
        if (reason === ConnectionFailReason.NoSecrets && root.takesPsk(modelData))
          root.passwordFor = modelData;
      }

      function onConnectedChanged() {
        if (modelData.connected)
          root._clearFailure(modelData);
      }
    }
  }
}
