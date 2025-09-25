pragma Singleton
import QtQuick

QtObject {
    signal togglePanelReservation(string panelId)
    signal togglePanelLock(string panelId)
}
