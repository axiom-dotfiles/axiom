pragma Singleton
import QtQuick

/* Shell manager manages global options and signals */
QtObject {
  signal togglePanelReservation(string panelId)
  signal togglePanelLock(string panelId)
  signal togglePanelLocation(string panelId)

  signal toggleDarkMode()

  signal lockScreen()
  signal openPowerMenu()

  function togglePinnedPanel(panelId) {
    console.log("Toggling pinned state for panelId:", panelId);
    togglePanelReservation(panelId);
    togglePanelLock(panelId);
    togglePanelLocation(panelId);
  }
}
