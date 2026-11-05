import QtQuick
import Quickshell
import Quickshell.Wayland

/**
 * A transparent layer that catches clicks outside a panel, so they dismiss it instead of
 * reaching the windows underneath. The panel must sit on the Overlay layer to stay above this.
 */
PanelWindow {
    id: root
    property bool active: false
    signal dismissed()

    visible: active
    color: "transparent"
    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    WlrLayershell.namespace: "quickshell:click-away"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onClicked: root.dismissed()
    }
}
