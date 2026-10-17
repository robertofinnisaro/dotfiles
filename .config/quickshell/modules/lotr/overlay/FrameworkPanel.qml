// Phase 2: touchscreen/tablet controls for the Field Atlas.
// Uses a small external controller; no privileged operations in QML.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Rectangle {
    id: root
    implicitHeight: 182
    radius: 12
    color: "#112327"
    border.color: "#345b5b"

    property string mode: "unknown"
    property string orientation: "unknown"
    property bool tabletActive: false
    property bool switchDetected: false

    function setMode(value) {
        Quickshell.execDetached(["bash", "-lc", "python3 \"$HOME/.config/hypr/scripts/palantir-framework12.py\" mode " + value]);
        root.mode = value;
        refreshDelay.restart();
    }

    Process {
        id: statusProcess
        command: ["bash", "-lc", "python3 \"$HOME/.config/hypr/scripts/palantir-framework12.py\" status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.mode = String(data.mode ?? "unknown");
                    root.orientation = String(data.orientation ?? "unknown");
                    root.tabletActive = data.tablet === true;
                    root.switchDetected = data.switch_detected === true;
                } catch (error) {
                    root.mode = "offline";
                }
            }
        }
    }

    Timer {
        id: statusTimer
        interval: 5000
        repeat: true
        running: root.visible
        triggeredOnStart: true
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    Timer {
        id: refreshDelay
        interval: 750
        onTriggered: {
            if (!statusProcess.running) statusProcess.running = true;
        }
    }

    Column {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 11

        Text {
            text: "VIII  /  THE FRAMEWORK 12"
            color: "#d7b776"
            font.pixelSize: 12
            font.bold: true
            font.letterSpacing: 1.1
        }
        Text {
            width: parent.width
            text: "MODE  " + root.mode.toUpperCase() + "     /     "
                  + (root.tabletActive ? "TABLET ACTIVE" : "LAPTOP POSTURE")
                  + "     /     " + root.orientation.toUpperCase()
            color: "#9ed7bf"
            font.pixelSize: 11
            elide: Text.ElideRight
        }
        Row {
            width: parent.width
            spacing: 8
            Repeater {
                model: [
                    {"label": "SENSOR / AUTO", "value": "auto"},
                    {"label": "TABLET", "value": "tablet"},
                    {"label": "LAPTOP", "value": "laptop"},
                    {"label": "KEYBOARD", "value": "keyboard"}
                ]
                delegate: Rectangle {
                    id: action
                    required property var modelData
                    width: (parent.width - 24) / 4
                    height: 40
                    radius: 8
                    color: root.mode === modelData.value ? "#235249" : "#193137"
                    border.color: root.mode === modelData.value ? "#9ed7bf" : "#3e6664"
                    Text {
                        anchors.centerIn: parent
                        text: action.modelData.label
                        color: "#e4e9df"
                        font.pixelSize: 11
                        font.bold: root.mode === action.modelData.value
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (action.modelData.value === "keyboard") {
                                Quickshell.execDetached(["qs", "ipc", "call", "osk", "toggle"]);
                            } else {
                                root.setMode(action.modelData.value);
                            }
                        }
                    }
                }
            }
        }
        Text {
            width: parent.width
            text: root.switchDetected
                  ? "Hinge switch detected. Rotation follows accelerometer in tablet mode."
                  : "Switch status unknown. Select TABLET manually; Super+K opens the keyboard."
            color: "#8da6a1"
            font.pixelSize: 10
            wrapMode: Text.WordWrap
        }
    }
}
