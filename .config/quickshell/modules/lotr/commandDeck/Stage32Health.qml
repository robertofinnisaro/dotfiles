// Read-only systemd service health; no automatic restarts and no privilege escalation.
import QtQuick
import Quickshell
import Quickshell.Io

Column {
    id: root
    property bool active: false
    property var entries: []
    property string message: "Tap Refresh to inspect system services"
    property bool busy: statusProcess.running
    spacing: 9

    function refresh() {
        if (!statusProcess.running) statusProcess.running = true;
    }
    onActiveChanged: { if (active) refresh(); }
    Timer { interval: 20000; repeat: true; running: root.active; onTriggered: root.refresh() }

    Process {
        id: statusProcess
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/palantir-health.py", "--json"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const parsed = JSON.parse(this.text);
                    root.entries = parsed.services || [];
                    root.message = parsed.note || "Status checked";
                } catch (e) {
                    root.entries = [];
                    root.message = "Unable to read health data. Run palantir-health.py from a terminal.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.message = "Health check returned an error; try the CLI diagnostic.";
        }
    }
    DeckTile {
        width: parent.width; height: 72
        glyph: "↻"; title: "Refresh services"; detail: root.busy ? "CHECKING" : "READ ONLY — NO RESTARTS"
        enabledAction: !root.busy
        onActivated: root.refresh()
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: root.message
        color: "#9ebdaf"; font.pixelSize: 12
    }
    Repeater {
        model: root.entries
        delegate: Rectangle {
            id: serviceRow
            required property var modelData
            width: root.width; height: 61; radius: 7
            color: "#152c27"; border.color: "#3c6153"
            Text {
                x: 12; y: 8; width: parent.width - 130
                text: serviceRow.modelData.title || "Service"
                elide: Text.ElideRight; color: "#e8dbb7"
                font.pixelSize: 13
            }
            Text {
                x: 12; y: 32; width: parent.width - 130
                text: serviceRow.modelData.scope || ""
                elide: Text.ElideRight; color: "#91aa9b"; font.pixelSize: 11
            }
            Text {
                anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 12 }
                text: serviceRow.modelData.status || "unknown"
                color: serviceRow.modelData.status === "active" ? "#b8dbb0" : (serviceRow.modelData.status === "failed" ? "#e3a9a2" : "#dbcb9c")
                font { pixelSize: 12; bold: true }
            }
        }
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: "Unmanaged or inactive does not necessarily mean broken. Use the existing Steward terminal diagnostic to investigate.";
        color: "#81968b"; font.pixelSize: 11
    }
}
