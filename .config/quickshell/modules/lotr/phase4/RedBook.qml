// ORTHANC / The Red Book: every keybind, read from the live niri config.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: book
    property bool opened: false
    property var sections: []
    property string loadError: ""

    function toggleBook() {
        book.opened = !book.opened;
        if (book.opened) reader.running = true;
    }

    IpcHandler {
        target: "redBook"
        function toggle(): void { book.toggleBook(); }
    }

    Process {
        id: reader
        command: ["python3", Quickshell.shellPath("scripts/palantir-keybinds.py")]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    book.sections = JSON.parse(this.text);
                    book.loadError = "";
                } catch (e) {
                    book.loadError = "Could not read your keybinds";
                }
            }
        }
    }

    PanelWindow {
        id: window
        visible: book.opened
        color: "#0b1519"
        anchors { top: true; bottom: true; left: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.namespace: "quickshell:red-book"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: book.opened ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#0b1519"
            border { color: "#947b4c"; width: 2 }
            focus: book.opened
            Keys.onEscapePressed: book.opened = false

            Column {
                id: heading
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                spacing: 6
                Text { text: "ORTHANC  /  THE ARCHIVES"; color: "#a8c6b2"; font { pixelSize: 11; letterSpacing: 2 } }
                Text { text: "THE RED BOOK OF WESTMARCH"; color: "#f0d59d"; font { family: "Cinzel"; pixelSize: Math.min(26, window.width / 26); bold: true } }
                Text { text: "Every keybind on this system · read from your niri config · Escape closes"; color: "#b6c8bf"; font.pixelSize: 12 }
            }
            Rectangle {
                anchors { right: parent.right; top: parent.top; margins: 18 }
                width: 48; height: 45; radius: 8
                color: "#22332e"; border.color: "#9d8254"
                Text { anchors.centerIn: parent; text: "×"; color: "#edd7a6"; font.pixelSize: 27 }
                MouseArea { anchors.fill: parent; onClicked: book.opened = false }
            }
            Text {
                visible: book.loadError !== ""
                anchors.centerIn: parent
                text: book.loadError
                color: "#eab4a3"; font.pixelSize: 14
            }
            Flickable {
                anchors { top: heading.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 15; bottomMargin: 16; leftMargin: 18; rightMargin: 18 }
                clip: true
                contentWidth: width
                contentHeight: pages.implicitHeight + 20
                boundsBehavior: Flickable.StopAtBounds
                Flow {
                    id: pages
                    width: parent.width
                    spacing: 10
                    Repeater {
                        model: book.sections
                        delegate: Rectangle {
                            id: page
                            required property var modelData
                            width: pages.width >= 1000 ? (pages.width - 20) / 3 : pages.width >= 640 ? (pages.width - 10) / 2 : pages.width
                            height: pageContents.implicitHeight + 26
                            radius: 12
                            color: "#152825"
                            border.color: "#527263"
                            Column {
                                id: pageContents
                                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 13 }
                                spacing: 7
                                Text { text: page.modelData.title.toUpperCase(); color: "#f0d4a1"; font { family: "Cinzel"; pixelSize: 13; bold: true } }
                                Repeater {
                                    model: page.modelData.binds
                                    delegate: Item {
                                        id: bind
                                        required property var modelData
                                        width: pageContents.width
                                        height: Math.max(keys.height, action.implicitHeight)
                                        Text {
                                            id: keys
                                            width: parent.width * 0.48
                                            text: bind.modelData.keys
                                            color: "#e4c98b"
                                            font { pixelSize: 12; bold: true }
                                            wrapMode: Text.Wrap
                                        }
                                        Text {
                                            id: action
                                            anchors { left: keys.right; right: parent.right; leftMargin: 8 }
                                            text: bind.modelData.action
                                            color: "#d5e6da"
                                            font.pixelSize: 12
                                            wrapMode: Text.Wrap
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
