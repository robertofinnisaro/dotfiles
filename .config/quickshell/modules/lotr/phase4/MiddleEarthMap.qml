// ORTHANC PHASE 4 / Interactive Middle-earth workspace map.
// Isolated from the existing workspace overview; no wallpaper changes.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: atlas
    property bool opened: false
    property int selectedWorkspace: 1
    property var clients: []
    property string refreshError: ""
    readonly property var regions: [
        { name: "THE SHIRE", subtitle: "Quiet beginnings", mark: "01" },
        { name: "RIVENDELL", subtitle: "Knowledge and craft", mark: "02" },
        { name: "ROHAN", subtitle: "Swift dispatches", mark: "03" },
        { name: "GONDOR", subtitle: "The high watch", mark: "04" },
        { name: "MORIA", subtitle: "The deep works", mark: "05" },
        { name: "ORTHANC", subtitle: "Command and observation", mark: "06" }
    ]

    function showMap() {
        atlas.selectedWorkspace = Hyprland.focusedWorkspace ? Hyprland.focusedWorkspace.id : 1;
        if (atlas.selectedWorkspace < 1 || atlas.selectedWorkspace > 6) atlas.selectedWorkspace = 1;
        atlas.opened = true;
        atlas.refresh();
    }
    function closeMap() { atlas.opened = false; }
    function toggleMap() { if (atlas.opened) atlas.closeMap(); else atlas.showMap(); }
    function refresh() { if (atlas.opened && !clientScan.running) clientScan.running = true; }
    function windowsOn(num) {
        return atlas.clients.filter(function(c) { return c && c.workspace && c.workspace.id === num; });
    }
    function goTo(num) {
        if (num < 1 || num > 6) return;
        Hyprland.dispatch("workspace " + num);
        atlas.selectedWorkspace = num;
        atlas.refresh();
    }
    function focusClient(addr) {
        if (!addr || !/^0x[0-9a-f]+$/i.test(addr)) return;
        atlas.closeMap();
        Hyprland.dispatch("focuswindow address:" + addr);
    }

    Process {
        id: clientScan
        command: ["hyprctl", "-j", "clients"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    atlas.clients = Array.isArray(parsed) ? parsed : [];
                    atlas.refreshError = "";
                } catch (e) {
                    atlas.clients = [];
                    atlas.refreshError = "Window information temporarily unavailable";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) atlas.refreshError = "Could not query Hyprland windows";
        }
    }
    Timer { interval: 3000; repeat: true; running: atlas.opened; onTriggered: atlas.refresh() }

    IpcHandler {
        target: "atlasMap"
        function toggle(): void { atlas.toggleMap(); }
        function open(): void { atlas.showMap(); }
        function close(): void { atlas.closeMap(); }
    }

    PanelWindow {
        id: window
        visible: atlas.opened
        color: "#0b1519"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:orthanc-map"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: atlas.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#0b1519"
            border { color: "#947b4c"; width: 2 }
            focus: atlas.opened
            Keys.onEscapePressed: atlas.closeMap()
            Keys.onPressed: function(event) {
                if (event.key >= Qt.Key_1 && event.key <= Qt.Key_6) {
                    atlas.goTo(event.key - Qt.Key_0);
                    event.accepted = true;
                }
            }
            Canvas {
                anchors.fill: parent
                opacity: 0.24
                onPaint: {
                    const c = getContext("2d");
                    c.clearRect(0, 0, width, height);
                    c.strokeStyle = "#789983";
                    c.lineWidth = 1;
                    for (let i = 0; i < 8; i++) {
                        c.beginPath();
                        for (let x = 0; x < width; x += 15) {
                            let y = height * (0.13 + 0.12*i) + Math.sin(x/95 + i*2.2)*17 + Math.cos(x/38+i)*5;
                            if (x === 0) c.moveTo(x,y); else c.lineTo(x,y);
                        }
                        c.stroke();
                    }
                }
            }
            Column {
                id: heading
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 6
                Text { text: "ORTHANC  /  THE CARTOGRAPHER"; color: "#a8c6b2"; font { pixelSize: 11; letterSpacing: 2 } }
                Text { text: "THE MAP OF MIDDLE-EARTH"; color: "#f0d59d"; font { family: "Cinzel"; pixelSize: Math.min(26, window.width / 26); bold: true } }
                Text { text: "Six realms · live window census · tap a region to change workspace"; color: "#b6c8bf"; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
            }
            Rectangle {
                id: quit
                anchors { right: parent.right; top: parent.top; margins: 18 }
                width: 48; height: 45; radius: 8
                color: "#22332e"; border.color: "#9d8254"
                Text { anchors.centerIn: parent; text: "×"; color: "#edd7a6"; font.pixelSize: 27 }
                MouseArea { anchors.fill: parent; onClicked: atlas.closeMap() }
            }
            Flickable {
                anchors { top: heading.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 15; bottomMargin: 16; leftMargin: 18; rightMargin: 18 }
                clip: true
                contentWidth: width
                contentHeight: contents.implicitHeight + 20
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: contents
                    width: parent.width
                    spacing: 16
                    Grid {
                        id: regionGrid
                        width: parent.width
                        columns: 2
                        spacing: 10
                        Repeater {
                            model: 6
                            delegate: Rectangle {
                                required property int index
                                readonly property int number: index + 1
                                readonly property var region: atlas.regions[index]
                                readonly property bool isCurrent: Hyprland.focusedWorkspace && Hyprland.focusedWorkspace.id === number
                                width: (regionGrid.width - 10) / 2
                                height: Math.max(108, Math.min(154, window.height * 0.16))
                                radius: 12
                                color: atlas.selectedWorkspace === number ? "#234336" : "#152825"
                                Behavior on color { ColorAnimation { duration: 170 } }
                                border { color: isCurrent ? "#eccb8c" : atlas.selectedWorkspace === number ? "#8fb99a" : "#527263"; width: isCurrent ? 2 : 1 }
                                Canvas {
                                    anchors { fill: parent; margins: 8 }
                                    opacity: 0.4
                                    onPaint: {
                                        const ctx = getContext("2d");
                                        ctx.strokeStyle = "#a6c1a3"; ctx.lineWidth = 1;
                                        for (let j=0; j<3; j++) {
                                            ctx.beginPath(); ctx.moveTo(width*0.57, 14+j*17);
                                            ctx.bezierCurveTo(width*0.85, 12+j*8, width*0.73, height*0.9, width*0.98, height*0.8-j*10); ctx.stroke();
                                        }
                                    }
                                }
                                Column {
                                    anchors { fill: parent; margins: 13 }
                                    spacing: 5
                                    Text { text: region.mark + "   /   " + region.name; color: "#f0d4a1"; font { pixelSize: 15; bold: true; family: "Cinzel" } elide: Text.ElideRight; width: parent.width }
                                    Text { text: region.subtitle; color: "#b4c8ba"; font.pixelSize: 11 }
                                    Item { width: 1; height: 4 }
                                    Text { text: atlas.windowsOn(number).length + " OPEN WINDOWS"; color: "#dcece1"; font.pixelSize: 12 }
                                    Text { text: isCurrent ? "● ACTIVE REALM" : "TAP TO TRAVEL"; color: isCurrent ? "#f5d58d" : "#9ab5a8"; font { pixelSize: 11; bold: true } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: { atlas.selectedWorkspace = number; atlas.goTo(number); }
                                }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: "#826d45" }
                    Text { text: "WINDOWS  /  " + atlas.regions[atlas.selectedWorkspace-1].name; color: "#e3c892"; font { pixelSize: 15; bold: true } }
                    Text { visible: atlas.refreshError !== ""; text: atlas.refreshError; color: "#eab4a3"; font.pixelSize: 12 }
                    Text { visible: atlas.windowsOn(atlas.selectedWorkspace).length === 0; text: "No windows here yet. Select another realm or open an application."; color: "#a6bcb0"; font.pixelSize: 12; wrapMode: Text.WordWrap; width: parent.width }
                    Repeater {
                        model: atlas.windowsOn(atlas.selectedWorkspace)
                        delegate: Rectangle {
                            required property var modelData
                            width: contents.width; height: 55; radius: 8
                            color: "#172b29"; border.color: "#537164"
                            Text { anchors { left: parent.left; leftMargin: 13; verticalCenter: parent.verticalCenter } width: parent.width - 78; elide: Text.ElideRight; text: ((modelData.class || "APP") + "  /  " + (modelData.title || "Untitled")); color: "#d5e6da"; font.pixelSize: 13 }
                            Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter } text: "OPEN"; color: "#e4c98b"; font { pixelSize: 11; bold: true } }
                            MouseArea { anchors.fill: parent; onClicked: atlas.focusClient(modelData.address) }
                        }
                    }
                    Text { text: "1–6 select a realm · Escape closes · Original Super+Tab overview is unchanged"; color: "#91a79c"; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
                }
            }
        }
    }
}
