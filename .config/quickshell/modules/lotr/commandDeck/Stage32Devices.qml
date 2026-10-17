// Device routing: use existing PipeWire and Bluetooth singletons; paired devices only.
import QtQuick
import qs.services

Column {
    id: root
    spacing: 9
    function setVolume(frac) {
        if (!Audio.sink?.audio) return;
        Audio.sink.audio.volume = Math.max(0, Math.min(1, frac));
    }
    Text { text: "AUDIO OUTPUT"; color: "#e1cd98"; font { pixelSize: 11; bold: true } }
    Rectangle {
        width: parent.width; height: 78; radius: 8
        color: "#142824"; border.color: "#446956"
        Text {
            x: 13; y: 9
            text: "Volume  " + Math.round(Math.min(1, Audio.value) * 100) + "%"
            color: "#e0eadf"; font.pixelSize: 13
        }
        Rectangle {
            id: track
            x: 15; y: 44; width: parent.width - 30; height: 14; radius: 7
            color: "#41544c"
            Rectangle {
                height: parent.height; radius: 7
                width: parent.width * Math.max(0, Math.min(1, Audio.value))
                color: "#c0a774"
            }
            MouseArea {
                anchors { fill: parent; topMargin: -12; bottomMargin: -12 }
                enabled: Audio.sink?.audio !== undefined && Audio.sink?.audio !== null
                onPressed: mouse => root.setVolume(mouse.x / track.width)
                onPositionChanged: mouse => { if (pressed) root.setVolume(mouse.x / track.width); }
            }
        }
    }
    Text {
        text: "Select output (" + Audio.outputDevices.length + ")"
        color: "#afc8ba"; font.pixelSize: 11
    }
    Text {
        visible: Audio.outputDevices.length === 0
        text: "No output devices reported by PipeWire"; color: "#9bb2a5"; font.pixelSize: 12
    }
    Repeater {
        model: Audio.outputDevices
        delegate: DeckTile {
            required property var modelData
            width: root.width; height: 66
            glyph: "♫"; title: Audio.friendlyDeviceName(modelData)
            detail: Audio.sink === modelData ? "ACTIVE OUTPUT" : "TAP TO SELECT"
            selected: Audio.sink === modelData
            enabledAction: modelData !== null
            onActivated: Audio.setDefaultSink(modelData)
        }
    }
    Text { text: "AUDIO INPUT"; color: "#e1cd98"; font { pixelSize: 11; bold: true } }
    Repeater {
        model: Audio.inputDevices
        delegate: DeckTile {
            required property var modelData
            width: root.width; height: 66
            glyph: "◉"; title: Audio.friendlyDeviceName(modelData)
            detail: Audio.source === modelData ? "ACTIVE INPUT" : "TAP TO SELECT"
            selected: Audio.source === modelData
            onActivated: Audio.setDefaultSource(modelData)
        }
    }
    Text {
        visible: Audio.inputDevices.length === 0
        text: "No microphones reported by PipeWire"; color: "#9bb2a5"; font.pixelSize: 12
    }
    Text { text: "PAIRED BLUETOOTH DEVICES"; color: "#e1cd98"; font { pixelSize: 11; bold: true } }
    Text {
        visible: !BluetoothStatus.available
        width: parent.width; wrapMode: Text.WordWrap
        text: "No Bluetooth adapter reported."; color: "#a2b6aa"; font.pixelSize: 12
    }
    Text {
        visible: BluetoothStatus.available && (BluetoothStatus.connectedDevices.length + BluetoothStatus.pairedButNotConnectedDevices.length) === 0
        width: parent.width; wrapMode: Text.WordWrap
        text: "No paired Bluetooth devices. Pair a device using your existing Bluetooth manager first."
        color: "#a2b6aa"; font.pixelSize: 12
    }
    Repeater {
        model: BluetoothStatus.connectedDevices.concat(BluetoothStatus.pairedButNotConnectedDevices)
        delegate: DeckTile {
            required property var modelData
            width: root.width; height: 68
            glyph: "ᛒ"; title: modelData.name || modelData.deviceName || "Bluetooth device"
            detail: modelData.connected ? "CONNECTED • TAP TO DISCONNECT" : "PAIRED • TAP TO CONNECT"
            selected: modelData.connected
            enabledAction: BluetoothStatus.enabled
            onActivated: modelData.connected = !modelData.connected
        }
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: "Selection changes the default PipeWire route. Bluetooth shows already-paired devices only; authentication/pairing remains in your normal manager."
        color: "#84998e"; font.pixelSize: 11
    }
}
