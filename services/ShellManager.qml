pragma Singleton
import QtQuick

QtObject {
  signal togglePanelReservation(string panelId)
  signal togglePanelLock(string panelId)
  signal togglePanelLocation(string panelId)

  function togglePinnedPanel(panelId) {
    console.log("Toggling pinned state for panelId:", panelId);
    togglePanelReservation(panelId);
    togglePanelLock(panelId);
    togglePanelLocation(panelId);
  }
}
