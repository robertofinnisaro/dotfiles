// PALANTIR FIELD ATLAS v2 — the Super+G productivity overlay.
// Does not replace the existing overlay window or its IPC handler.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import qs
import qs.services
import qs.modules.lotr.overlay

Item {
    id: root
    anchors.fill: parent
    visible: GlobalStates.overlayOpen
    focus: GlobalStates.overlayOpen

    readonly property color ink: "#0b1518"
    readonly property color slab: "#112327"
    readonly property color emerald: "#9ed7bf"
    readonly property color gold: "#d7b776"
    readonly property color muted: "#8da6a1"
    property bool historyRevealed: false
    readonly property var atlasState: FieldAtlasState

    function close() { GlobalStates.overlayOpen = false; }

    function executeHypr(command) {
        close();
        Hyprland.dispatch(command);
    }

    function launch(command) {
        close();
        Quickshell.execDetached(command);
    }

    function clipPreview(entry) {
        const raw = String(entry ?? "");
        if (raw.indexOf("[[") >= 0) return "Image or binary entry";
        return raw.replace(/^\s*\S+\s+/, "").replace(/[\r\n\t]+/g, " ").slice(0, 67) || "Clipboard entry";
    }

    Keys.onPressed: (event) => {
        if (event.key === Qt.Key_Escape) {
            root.close();
            event.accepted = true;
        } else if (!notesEdit.activeFocus && event.key >= Qt.Key_1 && event.key <= Qt.Key_6
                   && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier))) {
            root.executeHypr("workspace " + (event.key - Qt.Key_0));
            event.accepted = true;
        }
    }

    Connections {
        target: GlobalStates
        function onOverlayOpenChanged() {
            if (GlobalStates.overlayOpen) {
                GlobalStates.commandDeckOpen = false;
                GlobalStates.overviewOpen = false;
                root.historyRevealed = false;
                Hyprland.refreshToplevels();
            } else {
                root.atlasState.flushNotes();
            }
        }
    }

    // Compact keyboard-navigable control reused throughout the atlas.
    component AtlasButton: Rectangle {
        id: button
        property string title: ""
        property bool selected: false
        property bool danger: false
        signal activated()
        radius: 9
        color: !enabled ? "#172023" : selected ? "#23483f" : area.containsMouse ? "#234044" : "#193137"
        border.color: selected ? "#9ed7bf" : danger ? "#8e6957" : "#3e6664"
        border.width: 1
        activeFocusOnTab: true
        Text {
            anchors.centerIn: parent
            width: parent.width - 12
            text: button.title
            color: !button.enabled ? "#647d79" : button.danger ? "#e0b5a5" : "#e4e9df"
            font { pixelSize: 12; bold: button.selected }
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        MouseArea {
            id: area
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            hoverEnabled: true
            enabled: button.enabled
            onClicked: button.activated()
        }
        Keys.onReturnPressed: button.activated()
        Keys.onEnterPressed: button.activated()
        Keys.onSpacePressed: button.activated()
    }

    // Dim the rest of the screen; the inner panel intercepts its own clicks.
    Rectangle {
        anchors.fill: parent
        color: "#090f12"
        opacity: 0.88
        MouseArea { anchors.fill: parent; onClicked: root.close() }
    }

    Rectangle {
        id: atlas
        anchors.centerIn: parent
        width: Math.min(parent.width - 28, 1070)
        height: Math.min(parent.height - 24, 818)
        radius: 16
        color: root.ink
        border { width: 1; color: "#a18a5f" }
        clip: true

        // Intercept clicks so the background click-to-dismiss does not trigger.
        MouseArea { anchors.fill: parent; onClicked: {} }

        Rectangle {
            id: heading
            anchors { top: parent.top; left: parent.left; right: parent.right }
            height: 93
            color: "#13272b"
            Rectangle {
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 1
                color: "#a18a5f"
            }
            Column {
                anchors { left: parent.left; leftMargin: 23; verticalCenter: parent.verticalCenter }
                spacing: 7
                Text { text: "MIDDLE-EARTH  /  FIELD OPERATIONS"; color: root.emerald; font { pixelSize: 10; letterSpacing: 2.1 } }
                Text { text: "THE FIELD ATLAS  /  MK II"; color: root.gold; font { family: "Cinzel"; pixelSize: atlas.width < 580 ? 23 : 30; bold: true; letterSpacing: 1.1 } }
            }
            AtlasButton {
                anchors { right: parent.right; rightMargin: 20; verticalCenter: parent.verticalCenter }
                width: 46; height: 37
                title: "ESC"
                onActivated: root.close()
            }
        }

        Flickable {
            id: scroller
            anchors { top: heading.bottom; bottom: footer.top; left: parent.left; right: parent.right; margins: 14 }
            contentWidth: width
            contentHeight: deck.implicitHeight + 28
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick

            GridLayout {
                id: deck
                x: 0; y: 14
                width: scroller.width
                columns: width < 740 ? 1 : 2
                columnSpacing: 12
                rowSpacing: 12

                // 1 — Workspaces. Quick jump without opening the overview.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: deck.width < 410 ? 221 : 182
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 13
                        Text { text: "I  /  THE SIX REALMS"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Text {
                            text: "CURRENT WORKSPACE  " + (Hyprland.focusedWorkspace?.name ?? "—")
                            color: root.muted; font.pixelSize: 11
                        }
                        Grid {
                            id: realms
                            width: parent.width; columns: width < 390 ? 3 : 6; spacing: 7
                            Repeater {
                                model: 6
                                delegate: AtlasButton {
                                    required property int index
                                    width: (realms.width - (realms.columns - 1) * realms.spacing) / realms.columns
                                    height: 38
                                    title: String(index + 1)
                                    selected: Hyprland.focusedWorkspace?.id === index + 1
                                    onActivated: root.executeHypr("workspace " + (index + 1))
                                }
                            }
                        }
                        Text { text: "Click a realm or press 1–6 • Super+Tab opens Atlas overview"; color: root.muted; font.pixelSize: 10; wrapMode: Text.WordWrap; width: parent.width }
                    }
                }

                // 2 — A live timer for uninterrupted work.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 182
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 10
                        Text { text: "II  /  THE WATCH"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Row {
                            width: parent.width; spacing: 12
                            Text { text: root.atlasState.focusClock(); color: root.emerald; font { pixelSize: 31; bold: true; family: "monospace" } }
                            Text { text: root.atlasState.focusRunning ? "FOCUS IN PROGRESS" : root.atlasState.focusSeconds === 0 ? "WATCH COMPLETE" : "ON STANDBY"; color: root.muted; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
                        }
                        Row {
                            width: parent.width; spacing: 7
                            AtlasButton { width: (parent.width - 14) / 3; height: 30; title: "15 MIN"; selected: root.atlasState.focusPreset === 15; onActivated: root.atlasState.setTimer(15) }
                            AtlasButton { width: (parent.width - 14) / 3; height: 30; title: "25 MIN"; selected: root.atlasState.focusPreset === 25; onActivated: root.atlasState.setTimer(25) }
                            AtlasButton { width: (parent.width - 14) / 3; height: 30; title: "50 MIN"; selected: root.atlasState.focusPreset === 50; onActivated: root.atlasState.setTimer(50) }
                        }
                        Row {
                            width: parent.width; spacing: 7
                            AtlasButton { width: (parent.width - 7) / 2; height: 30; title: root.atlasState.focusRunning ? "PAUSE" : "START / RESUME"; onActivated: { if (root.atlasState.focusSeconds === 0) root.atlasState.setTimer(root.atlasState.focusPreset); root.atlasState.focusRunning = !root.atlasState.focusRunning; } }
                            AtlasButton { width: (parent.width - 7) / 2; height: 30; title: "RESET"; onActivated: root.atlasState.setTimer(root.atlasState.focusPreset) }
                        }
                    }
                }

                // 3 — Window arrangement without memorising dispatchers.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 159
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 12
                        Text { text: "III  /  THE ACTIVE CHAMBER"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Text {
                            width: parent.width
                            text: Hyprland.activeToplevel?.title || "No active window"
                            color: root.emerald; font.pixelSize: 13; elide: Text.ElideRight
                        }
                        Row {
                            width: parent.width; spacing: 7
                            AtlasButton { width: (parent.width - 7) / 2; height: 38; title: "FLOAT / TILE"; enabled: Hyprland.activeToplevel !== null; onActivated: root.executeHypr("togglefloating") }
                            AtlasButton { width: (parent.width - 7) / 2; height: 38; title: "FULLSCREEN"; enabled: Hyprland.activeToplevel !== null; onActivated: root.executeHypr("fullscreen") }
                        }
                        Text { text: "The overlay closes before applying a window command"; color: root.muted; font.pixelSize: 10; width: parent.width; wrapMode: Text.WordWrap }
                    }
                }

                // 4 — Notes are saved automatically outside ~/dotfiles.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 230
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 9
                        Text { text: "IV  /  THE CHRONICLE"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Rectangle {
                            width: parent.width; height: 142
                            color: "#0c1a1e"; radius: 7; border.color: "#426762"
                            Flickable {
                                id: noteScroll
                                anchors.fill: parent; anchors.margins: 8
                                clip: true
                                contentWidth: width
                                contentHeight: Math.max(height, notesEdit.paintedHeight + 8)
                                TextEdit {
                                    id: notesEdit
                                    width: noteScroll.width
                                    height: Math.max(noteScroll.height, paintedHeight + 8)
                                    text: ""
                                    color: "#e4e9df"
                                    font.pixelSize: 13
                                    wrapMode: TextEdit.Wrap
                                    selectByMouse: true
                                    selectedTextColor: "#0b1518"
                                    selectionColor: "#9ed7bf"
                                    Component.onCompleted: {
                                        if (root.atlasState.notesReady) text = root.atlasState.notes;
                                    }
                                    onTextChanged: root.atlasState.setNotes(text)
                                    Keys.onEscapePressed: root.close()
                                    Connections {
                                        target: root.atlasState
                                        function onNotesReadyChanged() {
                                            if (root.atlasState.notesReady) notesEdit.text = root.atlasState.notes;
                                        }
                                    }
                                }
                            }
                        }
                        Text { text: "Autosaved • " + (root.atlasState.notesReady ? "Local state" : "Loading notes…"); color: root.muted; font.pixelSize: 10 }
                    }
                }

                // 5 — Clipboard history is concealed by default for privacy.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: root.historyRevealed ? 260 : 159
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 9
                        Text { text: "V  /  THE ARCHIVES"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Text { text: "Clipboard history is hidden until you choose to reveal it."; width: parent.width; color: root.muted; font.pixelSize: 11; wrapMode: Text.WordWrap }
                        AtlasButton { width: parent.width; height: 34; title: root.historyRevealed ? "HIDE CLIPBOARD" : "REVEAL LAST 3 ITEMS"; onActivated: {
                            root.historyRevealed = !root.historyRevealed;
                            if (root.historyRevealed) Cliphist.refresh();
                        } }
                        Repeater {
                            model: root.historyRevealed ? Cliphist.entries.slice(0, 3) : []
                            delegate: AtlasButton {
                                required property string modelData
                                width: parent.width; height: 30
                                title: root.clipPreview(modelData)
                                onActivated: {
                                    Cliphist.copy(modelData);
                                    root.atlasState.feedback = "Copied selected archive to clipboard";
                                    root.historyRevealed = false;
                                }
                            }
                        }
                        Text { visible: root.historyRevealed && Cliphist.entries.length === 0; text: "No clipboard entries (cliphist may not be running)"; color: root.muted; font.pixelSize: 10 }
                    }
                }

                // 6 — Media transport using the installed MPRIS service.
                Rectangle {
                    Layout.fillWidth: true; Layout.preferredHeight: 159
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 12
                        Text { text: "VI  /  THE MINSTREL"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Text { width: parent.width; text: MprisController.activePlayer ? (MprisController.activeTrack?.title || "Unknown track") : "No active music player"; color: root.emerald; font.pixelSize: 13; elide: Text.ElideRight }
                        Row {
                            width: parent.width; spacing: 7
                            AtlasButton { width: (parent.width - 14) / 3; height: 38; title: "PREV"; enabled: MprisController.canGoPrevious; onActivated: MprisController.previous() }
                            AtlasButton { width: (parent.width - 14) / 3; height: 38; title: MprisController.isPlaying ? "PAUSE" : "PLAY"; enabled: MprisController.canTogglePlaying; onActivated: MprisController.togglePlaying() }
                            AtlasButton { width: (parent.width - 14) / 3; height: 38; title: "NEXT"; enabled: MprisController.canGoNext; onActivated: MprisController.next() }
                        }
                        Text { text: "Supports compatible browsers and media players"; color: root.muted; font.pixelSize: 10 }
                    }
                }

                // Phase 2 — Framework hardware control (no privilege required).
                FrameworkPanel {
                    Layout.columnSpan: deck.columns
                    Layout.fillWidth: true
                }

                // 7 — Explicit one-click dispatches; no arbitrary user input passed to shell.
                Rectangle {
                    Layout.columnSpan: deck.columns
                    Layout.fillWidth: true; Layout.preferredHeight: deck.width < 740 ? 218 : 159
                    color: root.slab; radius: 12; border.color: "#345b5b"
                    Column {
                        anchors.fill: parent; anchors.margins: 15; spacing: 12
                        Text { text: "VII  /  RAPID ORDERS"; color: root.gold; font { pixelSize: 12; bold: true; letterSpacing: 1.1 } }
                        Grid {
                            id: orders
                            width: parent.width; spacing: 7; columns: width < 650 ? 2 : 3
                            AtlasButton { width: (orders.width - (orders.columns - 1) * 7) / orders.columns; height: 42; title: "TERMINAL"; onActivated: root.launch(["alacritty"]) }
                            AtlasButton { width: (orders.width - (orders.columns - 1) * 7) / orders.columns; height: 42; title: "FILES"; onActivated: root.launch(["pcmanfm-qt"]) }
                            AtlasButton { width: (orders.width - (orders.columns - 1) * 7) / orders.columns; height: 42; title: "LOCK SCREEN"; onActivated: root.launch(["hyprlock"]) }
                            AtlasButton { width: (orders.width - (orders.columns - 1) * 7) / orders.columns; height: 42; title: "COMMAND DECK"; onActivated: root.launch(["qs", "ipc", "call", "deck", "open"]) }
                            AtlasButton { width: (orders.width - (orders.columns - 1) * 7) / orders.columns; height: 42; title: "WORKSPACE ATLAS"; onActivated: { root.close(); GlobalStates.overviewOpen = true; } }
                            AtlasButton { width: (orders.width - (orders.columns - 1) * 7) / orders.columns; height: 42; title: "CAPTURE AREA"; onActivated: root.launch(["bash", "-lc", "sleep 0.25; \"$HOME/.config/quickshell/scripts/capture-region.sh\""]) }
                        }
                    }
                }
            }
        }

        Rectangle {
            id: footer
            anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
            height: 35
            color: "#13272b"
            Rectangle {
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 1
                color: "#496a61"
            }
            Text {
                anchors {
                    left: parent.left
                    leftMargin: 17
                    verticalCenter: parent.verticalCenter
                }
                width: parent.width - 34
                text: root.atlasState.feedback + "   •   ESC to close"
                elide: Text.ElideRight
                color: root.muted
                font.pixelSize: 11
            }
        }
    }
}
