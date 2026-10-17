// PALANTÍR STAGE 3.2+3.3 / Phase 3 completion. Orthanc theme retained.
// Built atop Stage 3.1: four tabs, IPC, Realms and keys unchanged.
// Existing deck IPC, GlobalShortcut and Quickshell keyboard remain compatible.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Wayland
import qs
import qs.services

Scope {
    id: root
    property int activeTab: 0
    property string diskUse: "—"
    property string powerProfile: "unknown"
    property string realm: "rivendell"
    property string realmMessage: "Choose a realm to apply its visual profile."
    property string frameworkMode: "unknown"
    property bool realmBusy: realmApply.running
    property bool confirmClear: false
    property bool autoRealmEnabled: false
    property string autoRealmMessage: "Auto Realms: off"

    function setOpen(open) {
        GlobalStates.commandDeckOpen = open;
        if (open) {
            GlobalStates.overviewOpen = false;
            GlobalStates.overlayOpen = false;
            root.refreshStatus();
        }
    }
    function refreshStatus() {
        if (!GlobalStates.commandDeckOpen) return;
        if (!diskProc.running) diskProc.running = true;
        if (!powerRead.running) powerRead.running = true;
        if (!realmRead.running) realmRead.running = true;
        if (!frameworkRead.running) frameworkRead.running = true;
    }
    function setRealm(mode) {
        if (realmApply.running) return;
        if (root.autoRealmEnabled) {
            Quickshell.execDetached(["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/palantir-auto-realm.py", "disable"]);
            root.autoRealmEnabled = false;
        }
        if (["shire", "rivendell", "mordor", "palantir"].indexOf(mode) < 0) return;
        root.realmMessage = "Applying " + mode + "…";
        realmApply.command = ["bash", "-lc", "python3 \"$HOME/.config/quickshell/scripts/palantir-realms.py\" apply " + mode];
        realmApply.running = true;
    }
    function setFrameworkMode(mode) {
        if (["auto", "tablet", "laptop"].indexOf(mode) < 0) return;
        Quickshell.execDetached(["bash", "-lc", "python3 \"$HOME/.config/hypr/scripts/palantir-framework12.py\" mode " + mode]);
        refreshLater.restart();
    }
    function toggleKeyboard() {
        GlobalStates.oskOpen = !GlobalStates.oskOpen;
        root.setOpen(false);
    }
    function openApp(command) {
        root.setOpen(false);
        Quickshell.execDetached(command);
    }
    function capture() {
        root.setOpen(false);
        Quickshell.execDetached(["bash", "-lc", "sleep 0.25; \"$HOME/.config/quickshell/scripts/capture-region.sh\""]);
    }

    Process {
        id: diskProc
        command: ["df", "-P", "/"]
        stdout: StdioCollector {
            onStreamFinished: {
                const match = this.text.match(/(\d+)%/);
                root.diskUse = match ? match[1] + "%" : "—";
            }
        }
    }
    Process {
        id: powerRead
        command: ["bash", "-lc", "\"$HOME/.config/quickshell/scripts/power-profile.sh\" get"]
        stdout: StdioCollector {
            onStreamFinished: root.powerProfile = this.text.trim() || "unavailable"
        }
        onExited: (code, status) => { if (code !== 0) root.powerProfile = "unavailable"; }
    }
    Process {
        id: realmRead
        command: ["bash", "-lc", "python3 \"$HOME/.config/quickshell/scripts/palantir-realms.py\" status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.realm = data.mode || "rivendell";
                } catch (e) {
                    root.realmMessage = "Realm status unavailable";
                }
            }
        }
    }
    Process {
        id: realmApply
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.realm = data.mode || root.realm;
                    root.realmMessage = "Realm active: " + root.realm.toUpperCase();
                } catch (e) {
                    root.realmMessage = "Unable to read realm response. Try CLI diagnostics.";
                }
            }
        }
        onExited: (code, status) => {
            if (code !== 0) root.realmMessage = "Realm change failed; run palantir-realms.py from a terminal.";
            refreshLater.restart();
        }
    }
    Process {
        id: frameworkRead
        command: ["bash", "-lc", "python3 \"$HOME/.config/hypr/scripts/palantir-framework12.py\" status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.frameworkMode = data.mode || "unavailable";
                } catch (e) {
                    root.frameworkMode = "unavailable";
                }
            }
        }
    }
    Process {
        id: autoRealmRead
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/palantir-auto-realm.py", "status"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.autoRealmEnabled = data.enabled === true;
                    root.autoRealmMessage = data.message || "Auto Realms status unknown";
                } catch (e) { root.autoRealmMessage = "Auto Realms unavailable"; }
            }
        }
    }
    Process {
        id: autoRealmToggle
        command: ["true"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.autoRealmEnabled = data.enabled === true;
                    root.autoRealmMessage = data.message || "Auto Realms updated";
                } catch (e) { root.autoRealmMessage = "Auto Realms change failed"; }
            }
        }
        onExited: (code, status) => { if (code === 0 && root.autoRealmEnabled) autoRealmTick.running = true; }
    }
    Process {
        id: autoRealmTick
        command: ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/palantir-auto-realm.py", "tick"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const data = JSON.parse(this.text);
                    root.autoRealmEnabled = data.enabled === true;
                    root.autoRealmMessage = data.message || root.autoRealmMessage;
                    if (data.realm && !realmRead.running) realmRead.running = true;
                } catch (e) { root.autoRealmMessage = "Auto Realms check failed"; }
            }
        }
    }
    Component.onCompleted: autoRealmRead.running = true
    Timer {
        interval: 60000; repeat: true; running: root.autoRealmEnabled
        onTriggered: { if (!autoRealmTick.running) autoRealmTick.running = true; }
    }
    function changeAutoRealm() {
        if (autoRealmToggle.running) return;
        const action = root.autoRealmEnabled ? "disable" : "enable";
        autoRealmToggle.command = ["python3", Quickshell.env("HOME") + "/.config/quickshell/scripts/palantir-auto-realm.py", action];
        autoRealmToggle.running = true;
    }
    Timer { id: refreshLater; interval: 700; onTriggered: root.refreshStatus() }
    Timer { id: clearCancel; interval: 5500; onTriggered: root.confirmClear = false }
    Timer { interval: 20000; repeat: true; running: GlobalStates.commandDeckOpen; onTriggered: root.refreshStatus() }

    PanelWindow {
        id: panel
        visible: GlobalStates.commandDeckOpen
        implicitWidth: Math.min(490, screen ? screen.width * 0.96 : 490)
        anchors { top: true; bottom: true; right: true }
        exclusionMode: ExclusionMode.Ignore
        color: "#0b1415"
        WlrLayershell.namespace: "quickshell:palantir"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: GlobalStates.commandDeckOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

        Rectangle {
            anchors.fill: parent
            color: "#0c1819"
            border { color: "#9a8252"; width: 1 }
            focus: GlobalStates.commandDeckOpen
            Keys.onEscapePressed: root.setOpen(false)

            Rectangle {
                id: header
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 127
                color: "#112322"
                Rectangle {
                    anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                    height: 1
                    color: "#997c48"
                }
                Text {
                    x: 19; y: 13
                    text: "MIDDLE-EARTH / TACTICAL OPERATIONS"
                    color: "#a7c9b6"
                    font { pixelSize: 10; letterSpacing: 1.5 }
                }
                Text {
                    x: 18; y: 36
                    text: "THE PALANTÍR"
                    color: "#e7d29d"
                    font { family: "Cinzel"; bold: true; pixelSize: 27; letterSpacing: 1.1 }
                }
                Text {
                    x: 19; y: 91
                    text: "STAGE III   //   " + ["THE WATCH", "DEVICES", "FOUR REALMS", "OPERATIONS"][root.activeTab]
                    color: "#8faf9f"
                    font.pixelSize: 11
                }
                Rectangle {
                    x: parent.width - 132; y: 20; width: 69; height: 41; radius: 8
                    color: keyboardArea.containsMouse ? "#304b40" : "#19332d"
                    border.color: GlobalStates.oskOpen ? "#dbbb7e" : "#608678"
                    Text { anchors.centerIn: parent; text: "KEYS"; color: "#ecd5a5"; font { pixelSize: 12; bold: true } }
                    MouseArea {
                        id: keyboardArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.toggleKeyboard()
                    }
                }
                Rectangle {
                    x: parent.width - 54; y: 20; width: 36; height: 41; radius: 8
                    color: closeArea.containsMouse ? "#4c342a" : "#19312d"
                    border.color: "#a1815d"
                    Text { anchors.centerIn: parent; text: "×"; color: "#ecd5a5"; font.pixelSize: 24 }
                    MouseArea {
                        id: closeArea
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setOpen(false)
                    }
                }
            }

            Rectangle {
                id: tabs
                anchors { top: header.bottom; left: parent.left; right: parent.right }
                height: 66
                color: "#11201f"
                Row {
                    anchors { fill: parent; leftMargin: 12; rightMargin: 12; topMargin: 10; bottomMargin: 10 }
                    spacing: 7
                    DeckTab { width: (parent.width - 21)/4; height: parent.height; title: "WATCH"; selected: root.activeTab === 0; onActivated: { root.activeTab = 0; scroller.contentY = 0 } }
                    DeckTab { width: (parent.width - 21)/4; height: parent.height; title: "DEVICES"; selected: root.activeTab === 1; onActivated: { root.activeTab = 1; scroller.contentY = 0 } }
                    DeckTab { width: (parent.width - 21)/4; height: parent.height; title: "REALMS"; selected: root.activeTab === 2; onActivated: { root.activeTab = 2; scroller.contentY = 0 } }
                    DeckTab { width: (parent.width - 21)/4; height: parent.height; title: "TOOLS"; selected: root.activeTab === 3; onActivated: { root.activeTab = 3; scroller.contentY = 0 } }
                }
            }

            Flickable {
                id: scroller
                anchors { top: tabs.bottom; bottom: footer.top; left: parent.left; right: parent.right }
                clip: true
                contentWidth: width
                contentHeight: sections.implicitHeight + 20
                boundsBehavior: Flickable.StopAtBounds
                flickableDirection: Flickable.VerticalFlick

                Column {
                    id: sections
                    width: scroller.width - 28
                    x: 14
                    topPadding: 14
                    bottomPadding: 14
                    spacing: 13

                    // WATCH / Existing telemetry plus actionable notifications.
                    Column {
                        visible: root.activeTab === 0
                        width: parent.width
                        spacing: 12
                        Rectangle {
                            width: parent.width; height: 170; radius: 12
                            color: "#122924"; border.color: "#497968"
                            Text { x: 15; y: 13; text: "01  /  THE SEEING STONE"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                            Column {
                                x: 17; y: 42; spacing: 11
                                Text { text: "CPU       " + (ResourceUsage.cpuUsage * 100).toFixed(0) + "%"; color: "#dcebe3"; font.pixelSize: 16 }
                                Text { text: "MEMORY  " + (ResourceUsage.memoryUsedPercentage * 100).toFixed(0) + "%"; color: "#dcebe3"; font.pixelSize: 16 }
                                Text { text: "DISK       " + root.diskUse; color: "#dcebe3"; font.pixelSize: 16 }
                                Text { text: "BATTERY  " + (Battery.available ? Math.round(Battery.percentage*100) + "%" : "N/A"); color: "#e2c78f"; font.pixelSize: 16 }
                            }
                            Canvas {
                                x: parent.width - 130; y: 44; width: 114; height: 114
                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    ctx.strokeStyle = "rgba(218,186,118,0.55)";
                                    ctx.lineWidth = 1;
                                    for (let r of [27, 39, 51]) { ctx.beginPath(); ctx.arc(57,57,r,0,Math.PI*2); ctx.stroke(); }
                                    ctx.beginPath(); ctx.moveTo(57,2); ctx.lineTo(57,112); ctx.moveTo(2,57); ctx.lineTo(112,57); ctx.stroke();
                                }
                            }
                        }
                        Text { text: "02  /  THE WATCHTOWER"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        DeckTile {
                            width: parent.width; height: 75
                            glyph: "◉"; title: "Notifications"
                            detail: Notifications.unread + " UNREAD / " + Notifications.list.length + " SAVED"
                            selected: Notifications.unread > 0
                            onActivated: { Notifications.markAllRead(); }
                        }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 76
                                glyph: "◐"; title: "Quiet Watch"
                                detail: Notifications.silent ? "DO NOT DISTURB" : "ALERTS ACTIVE"
                                selected: Notifications.silent
                                onActivated: Notifications.silent = !Notifications.silent
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 76
                                glyph: "⌫"; title: "Clear History"
                                detail: root.confirmClear ? "TAP AGAIN TO CONFIRM" : "Remove saved alerts"
                                selected: root.confirmClear
                                onActivated: {
                                    if (root.confirmClear) {
                                        Notifications.discardAllNotifications();
                                        Notifications.markAllRead();
                                        root.confirmClear = false;
                                        clearCancel.stop();
                                    } else {
                                        root.confirmClear = true;
                                        clearCancel.restart();
                                    }
                                }
                            }
                        }
                        Stage32Watchtower { width: parent.width }
                        Text { text: "04  /  FIELD OPERATIONS"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 79
                                glyph: "▦"; title: "Field Atlas"; detail: "Super + G controls"
                                onActivated: { root.setOpen(false); GlobalStates.overlayOpen = true; }
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 79
                                glyph: "⌨"; title: "The Scribe"; detail: "On-screen keyboard"
                                onActivated: root.toggleKeyboard()
                            }
                        }
                    }

                    // DEVICES / Local services and explicit framework controls.
                    Column {
                        visible: root.activeTab === 1
                        width: parent.width; spacing: 12
                        Text { text: "01  /  SYSTEM CHANNELS"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 82
                                glyph: "⌁"; title: "Wi-Fi"; detail: Network.wifiEnabled ? (Network.networkName || "CONNECTED") : "OFFLINE"
                                selected: Network.wifiEnabled
                                onActivated: Network.toggleWifi()
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 82
                                glyph: "ᛒ"; title: "Bluetooth"; detail: BluetoothStatus.available ? BluetoothStatus.activeDeviceCount + " CONNECTED" : "NO ADAPTER"
                                selected: BluetoothStatus.enabled
                                enabledAction: BluetoothStatus.available
                                onActivated: Quickshell.execDetached(["bluetoothctl", "power", BluetoothStatus.enabled ? "off" : "on"])
                            }
                        }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 82
                                glyph: "♫"; title: "Speakers"
                                detail: Audio.sink?.audio?.muted ? "MUTED" : Math.round(Audio.value * 100) + "%"
                                selected: !(Audio.sink?.audio?.muted ?? true)
                                enabledAction: Audio.sink?.audio !== undefined && Audio.sink?.audio !== null
                                onActivated: Audio.toggleMute()
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 82
                                glyph: "◉"; title: "Microphone"
                                detail: Audio.source?.audio?.muted ? "MUTED" : "UNMUTED"
                                selected: !(Audio.source?.audio?.muted ?? true)
                                enabledAction: Audio.source?.audio !== undefined && Audio.source?.audio !== null
                                onActivated: Audio.toggleMicMute()
                            }
                        }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 76
                                glyph: "+"; title: "Volume +"; detail: "Raise speakers"
                                enabledAction: Audio.sink?.audio !== undefined && Audio.sink?.audio !== null
                                onActivated: Audio.incrementVolume()
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 76
                                glyph: "−"; title: "Volume −"; detail: "Lower speakers"
                                enabledAction: Audio.sink?.audio !== undefined && Audio.sink?.audio !== null
                                onActivated: Audio.decrementVolume()
                            }
                        }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 76
                                glyph: "☀"; title: "Light +"; detail: "Increase brightness"
                                onActivated: Brightness.increaseBrightness()
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 76
                                glyph: "◌"; title: "Light −"; detail: "Decrease brightness"
                                onActivated: Brightness.decreaseBrightness()
                            }
                        }
                        DeckTile {
                            width: parent.width; height: 74
                            glyph: "☾"; title: "Night Sight"; detail: Hyprsunset.active ? "WARM DISPLAY" : "NEUTRAL DISPLAY"
                            selected: Hyprsunset.active
                            onActivated: Hyprsunset.toggle()
                        }
                        Stage32Devices { width: parent.width }
                        Text { text: "03  /  FRAMEWORK 12"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Text { width: parent.width; wrapMode: Text.WordWrap; text: "Posture: " + root.frameworkMode + "  ·  explicit control (no hidden sensor override)"; color: "#a8bcb2"; font.pixelSize: 11 }
                        Row {
                            width: parent.width; spacing: 7
                            DeckTab { width: (parent.width - 14)/3; height: 52; title: "AUTO"; selected: root.frameworkMode === "auto"; onActivated: root.setFrameworkMode("auto") }
                            DeckTab { width: (parent.width - 14)/3; height: 52; title: "TABLET"; selected: root.frameworkMode === "tablet"; onActivated: root.setFrameworkMode("tablet") }
                            DeckTab { width: (parent.width - 14)/3; height: 52; title: "LAPTOP"; selected: root.frameworkMode === "laptop"; onActivated: root.setFrameworkMode("laptop") }
                        }
                        Text { text: "04  /  POWER MANAGEMENT"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        DeckTile {
                            width: parent.width; height: 77
                            glyph: "⚙"; title: "Power profile"; detail: root.powerProfile === "unavailable" ? "Backend unavailable / not changed" : root.powerProfile + "  •  toggle balanced / saver"
                            enabledAction: root.powerProfile !== "unavailable" && root.powerProfile !== "unknown"
                            onActivated: {
                                const next = root.powerProfile === "power-saver" ? "balanced" : "power-saver";
                                Quickshell.execDetached(["bash", "-lc", "\"$HOME/.config/quickshell/scripts/power-profile.sh\" set " + next]);
                                refreshLater.restart();
                            }
                        }
                        Text { text: "Privacy: microphone status reflects PipeWire's default input mute state, not hardware camera access."; width: parent.width; wrapMode: Text.WordWrap; color: "#819c91"; font.pixelSize: 11 }
                    }

                    // REALMS / Changes are reversible within the current Hyprland session.
                    Column {
                        visible: root.activeTab === 2
                        width: parent.width; spacing: 12
                        Text { text: "01  /  THE FOUR REALMS"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Text { width: parent.width; wrapMode: Text.WordWrap; text: "Runtime visual profiles only. These do not alter your power manager, physical input devices, or dotfiles."; color: "#a4b9ac"; font.pixelSize: 12 }
                        DeckTile {
                            width: parent.width; height: 90
                            glyph: "❧"; title: "The Shire"; detail: "Low effects • quiet visual performance"
                            selected: root.realm === "shire"
                            enabledAction: !root.realmBusy
                            onActivated: root.setRealm("shire")
                        }
                        DeckTile {
                            width: parent.width; height: 90
                            glyph: "✧"; title: "Rivendell"; detail: "Restore your original Hyprland effects"
                            selected: root.realm === "rivendell"
                            enabledAction: !root.realmBusy
                            onActivated: root.setRealm("rivendell")
                        }
                        DeckTile {
                            width: parent.width; height: 90
                            glyph: "◆"; title: "Mordor"; detail: "Reduce animation & blur for gaming"
                            selected: root.realm === "mordor"
                            enabledAction: !root.realmBusy
                            onActivated: root.setRealm("mordor")
                        }
                        DeckTile {
                            width: parent.width; height: 90
                            glyph: "⌘"; title: "The Palantír"; detail: "Original effects • touch-first tools"
                            selected: root.realm === "palantir"
                            enabledAction: !root.realmBusy
                            onActivated: root.setRealm("palantir")
                        }
                        Rectangle {
                            width: parent.width; height: 66; radius: 9; color: "#192c29"; border.color: "#547467"
                            Text {
                                anchors { fill: parent; margins: 13 }
                                text: root.realmMessage
                                verticalAlignment: Text.AlignVCenter
                                wrapMode: Text.WordWrap
                                color: "#d3bc8b"; font.pixelSize: 12
                            }
                        }
                        DeckTile {
                            width: parent.width; height: 78
                            glyph: "⌨"; title: "The Scribe"; detail: "Touch keyboard, available in every realm"
                            onActivated: root.toggleKeyboard()
                        }
                        DeckTile {
                            width: parent.width; height: 86
                            glyph: "◈"; title: "Adaptive Realms (opt-in)"
                            detail: root.autoRealmEnabled ? "ON: Battery → Shire, AC → Rivendell" : "OFF: Keep manual Realm selection"
                            selected: root.autoRealmEnabled
                            onActivated: root.changeAutoRealm()
                        }
                        Text {
                            width: parent.width; wrapMode: Text.WordWrap
                            text: root.autoRealmMessage + " · Auto choices only adjust blur and animations. Any manual Realm selection disables automation."
                            color: "#abc4af"; font.pixelSize: 11
                        }
                        Text { width: parent.width; text: "The Shire and Mordor use the same safe visual overrides for now. Hardware power tuning requires backend verification."; wrapMode: Text.WordWrap; color: "#80978d"; font.pixelSize: 11 }
                    }

                    // TOOLS / Safe access to existing operations.
                    Column {
                        visible: root.activeTab === 3
                        width: parent.width; spacing: 12
                        // ORTHANC PHASE 4 / Map and contextual stone
                        Text { text: "ORTHANC  /  LIVE CARTOGRAPHY"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 88
                                glyph: "✧"; title: "Middle-earth Map"; detail: "6 realms / live windows"
                                onActivated: root.openApp(["qs", "ipc", "call", "atlasMap", "open"])
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 88
                                glyph: "◉"; title: "Seeing Stone"; detail: "Contextual quick actions"
                                onActivated: root.openApp(["qs", "ipc", "call", "seeingStone", "open"])
                            }
                        }
                        Text { text: "01  /  RAPID ORDERS"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 80
                                glyph: "▦"; title: "Atlas"; detail: "Workspaces"
                                onActivated: { root.setOpen(false); GlobalStates.overviewOpen = true; }
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 80
                                glyph: "▤"; title: "Archives"; detail: "Clipboard"
                                onActivated: root.openApp(["qs", "ipc", "call", "search", "clipboardToggle"])
                            }
                        }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 80
                                glyph: "◫"; title: "Capture"; detail: "Screenshot"
                                onActivated: root.capture()
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 80
                                glyph: "⚿"; title: "Secure"; detail: "Lock screen"
                                onActivated: root.openApp(["hyprlock"])
                            }
                        }
                        Row {
                            width: parent.width; spacing: 9
                            DeckTile {
                                width: (parent.width - 9)/2; height: 80
                                glyph: "⌂"; title: "Library"; detail: "Files"
                                onActivated: root.openApp(["pcmanfm-qt"])
                            }
                            DeckTile {
                                width: (parent.width - 9)/2; height: 80
                                glyph: ">_"; title: "Console"; detail: "Terminal"
                                onActivated: root.openApp(["alacritty"])
                            }
                        }
                        DeckTile {
                            width: parent.width; height: 81
                            glyph: "⌨"; title: "The Scribe  /  Keyboard"; detail: "Show or hide Quickshell's on-screen keyboard"
                            onActivated: root.toggleKeyboard()
                        }
                        DeckTile {
                            width: parent.width; height: 81
                            glyph: "⏻"; title: "Council of Departure"; detail: "Power menu with confirmation"
                            onActivated: root.openApp(["bash", "-lc", "\"$HOME/.config/quickshell/scripts/power-menu.sh\""])
                        }
                        Text { text: "02  /  SYSTEM HEALTH"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        DeckTile {
                            width: parent.width; height: 78
                            glyph: "+"; title: "The Steward"; detail: "Open desktop diagnostics in terminal"
                            onActivated: root.openApp(["bash", "-lc", "alacritty -e bash -lc '\"$HOME/.config/hypr/scripts/palantir-doctor.sh\"; read -rp \"Press Enter to close\"'"])
                        }
                        Stage32Health { width: parent.width; active: GlobalStates.commandDeckOpen && root.activeTab === 3 }
                        Text { text: "03  /  PRIVACY WATCH"; color: "#ddc28e"; font { pixelSize: 12; bold: true } }
                        Stage32Privacy { width: parent.width }
                    }
                }
            }

            Rectangle {
                id: footer
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 41
                color: "#102321"
                border { color: "#3a5147"; width: 1 }
                Text {
                    anchors.centerIn: parent
                    text: "PALANTÍR   //   SUPER + D   //   ESC TO CLOSE"
                    color: "#bfb294"
                    font { pixelSize: 10; letterSpacing: 1 }
                }
            }
        }
    }

    IpcHandler {
        target: "deck"
        function toggle(): void { root.setOpen(!GlobalStates.commandDeckOpen); }
        function open(): void { root.setOpen(true); }
        function close(): void { root.setOpen(false); }
        function quiet(): void { Notifications.silent = !Notifications.silent; }
    }
    GlobalShortcut {
        name: "commandDeckToggle"
        description: "Toggle the Palantir command deck"
        onPressed: root.setOpen(!GlobalStates.commandDeckOpen)
    }
}
