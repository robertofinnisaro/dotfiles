// ORTHANC PHASE 4 / Contextual Seeing Stone mini-HUD.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: stone
    property bool opened: false
    property string appName: "No active chamber"
    property string appTitle: "Open a window to inspect its information"
    property string workspaceName: "—"
    property string realmName: "—"
    property string lastError: ""

    function showStone() { stone.opened = true; stone.refresh(); }
    function hideStone() { stone.opened = false; }
    function toggleStone() { if (stone.opened) stone.hideStone(); else stone.showStone(); }
    function refresh() {
        if (!stone.opened) return;
        if (!windowRead.running) windowRead.running = true;
        if (!realmRead.running) realmRead.running = true;
    }
    function command(dispatch) {
        stone.hideStone();
        Hyprland.dispatch(dispatch);
    }
    function launch(args) { stone.hideStone(); Quickshell.execDetached(args); }

    IpcHandler {
        target: "seeingStone"
        function open(): void { stone.showStone(); }
        function close(): void { stone.hideStone(); }
        function toggle(): void { stone.toggleStone(); }
    }
    Process {
        id: windowRead
        command: ["hyprctl", "-j", "activewindow"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const item = JSON.parse(this.text);
                    stone.appName = item.class || "No active chamber";
                    stone.appTitle = item.title || "No focused window";
                    stone.workspaceName = item.workspace && item.workspace.name ? item.workspace.name : "—";
                    stone.lastError = "";
                } catch (e) { stone.lastError = "Unable to read active-window details"; }
            }
        }
        onExited: (code, status) => { if (code !== 0) stone.lastError = "Hyprland query unavailable"; }
    }
    Process {
        id: realmRead
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/palantir-realms.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try { stone.realmName = JSON.parse(this.text).mode || "unknown"; }
                catch (e) { stone.realmName = "unavailable"; }
            }
        }
    }
    Timer { interval: 3500; repeat: true; running: stone.opened; onTriggered: stone.refresh() }

    PanelWindow {
        id: panel
        visible: stone.opened
        implicitWidth: Math.min(410, screen ? screen.width * 0.96 : 410)
        implicitHeight: 390
        anchors { bottom: true; right: true }
        margins { bottom: 22; right: 22 }
        exclusionMode: ExclusionMode.Ignore
        color: "#0c191a"
        WlrLayershell.namespace: "quickshell:seeing-stone"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        Rectangle {
            anchors.fill: parent
            color: "#112522"; border { color: "#b59963"; width: 2 } radius: 16
            focus: stone.opened
            Keys.onEscapePressed: stone.hideStone()
            Rectangle { anchors { top: parent.top; left: parent.left; right: parent.right } height: 4; color: "#af975e"; radius: 2 }
            Column {
                anchors { fill: parent; margins: 17 }
                spacing: 12
                Row {
                    width: parent.width; spacing: 14
                    Text { text: "◉"; color: "#e0c58e"; font.pixelSize: 32 }
                    Column {
                        spacing: 2
                        Text { text: "THE SEEING STONE"; color: "#e9d09b"; font { pixelSize: 19; bold: true; family: "Cinzel" } }
                        Text { text: "ORTHANC / LIVE CONTEXT"; color: "#9db8a6"; font { pixelSize: 11; letterSpacing: 1 } }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: "#65765b" }
                Text { text: stone.appName.toUpperCase(); color: "#d2e8d9"; font { pixelSize: 16; bold: true } elide: Text.ElideRight; width: parent.width }
                Text { text: stone.appTitle; color: "#a8c1b0"; font.pixelSize: 12; width: parent.width; elide: Text.ElideRight; maximumLineCount: 2; wrapMode: Text.Wrap }
                Text { text: "REALM  " + stone.realmName.toUpperCase() + "     WORKSPACE  " + stone.workspaceName; color: "#ead19e"; font.pixelSize: 11; elide: Text.ElideRight; width: parent.width }
                Text { visible: stone.lastError !== ""; text: stone.lastError; color: "#e2a897"; font.pixelSize: 11 }
                Grid {
                    width: parent.width; columns: 2; spacing: 9
                    Repeater {
                        model: [
                            { title: "Float", action: "togglefloating", desc: "Window mode" },
                            { title: "Fullscreen", action: "fullscreen", desc: "Expand view" },
                            { title: "Map", action: "map", desc: "Six realms" },
                            { title: "Field Atlas", action: "atlas", desc: "Daily operations" }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            width: (panel.width - 43)/2
                            height: 65; radius: 8
                            color: "#233c32"; border.color: "#607960"
                            Column {
                                anchors.centerIn: parent; spacing: 4
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.title; color: "#ecd2a0"; font { pixelSize: 14; bold: true } }
                                Text { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.desc; color: "#aec4b2"; font.pixelSize: 10 }
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (modelData.action === "map") stone.launch(["qs", "ipc", "call", "atlasMap", "open"]);
                                    else if (modelData.action === "atlas") stone.launch(["qs", "ipc", "call", "overlay", "toggle"]);
                                    else stone.command(modelData.action);
                                }
                            }
                        }
                    }
                }
                Row {
                    width: parent.width; spacing: 9
                    Rectangle {
                        width: (parent.width - 9)/2; height: 42; color: "#1b382f"; radius: 8; border.color: "#66836e"
                        Text { anchors.centerIn: parent; text: "REFRESH"; color: "#e0ceaa"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: stone.refresh() }
                    }
                    Rectangle {
                        width: (parent.width - 9)/2; height: 42; color: "#392b28"; radius: 8; border.color: "#9e7d62"
                        Text { anchors.centerIn: parent; text: "DISMISS"; color: "#e7d1b0"; font.pixelSize: 12 }
                        MouseArea { anchors.fill: parent; onClicked: stone.hideStone() }
                    }
                }
            }
        }
    }
}
