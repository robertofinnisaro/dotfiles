// Local PipeWire link indicators. An active stream is not a hardware access audit.
import QtQuick
import qs.services
import Quickshell.Services.Pipewire

Column {
    id: root
    spacing: 9
    readonly property var micStreams: Pipewire.linkGroups.values.filter(function(link) {
        return link.source && link.target && link.source.type === PwNodeType.AudioSource && link.target.type === PwNodeType.AudioInStream;
    })
    readonly property var videoStreams: Pipewire.linkGroups.values.filter(function(link) {
        return link.source && link.target && link.source.type === PwNodeType.VideoSource;
    })
    Rectangle {
        width: parent.width; height: 75; radius: 8
        color: root.micStreams.length > 0 ? "#44342d" : "#162c27"
        border.color: root.micStreams.length > 0 ? "#b79472" : "#4a6d5b"
        Text {
            x: 12; y: 11
            text: "MICROPHONE STREAMS"
            color: "#e5d3a8"; font.pixelSize: 12
        }
        Text {
            x: 12; y: 37
            text: root.micStreams.length > 0 ? "ACTIVE: " + root.micStreams.length + " PipeWire link(s)" : "No active PipeWire mic link observed"
            color: "#cadbd1"; font.pixelSize: 12
        }
    }
    Rectangle {
        width: parent.width; height: 75; radius: 8
        color: root.videoStreams.length > 0 ? "#44342d" : "#162c27"
        border.color: root.videoStreams.length > 0 ? "#b79472" : "#4a6d5b"
        Text {
            x: 12; y: 11
            text: "VIDEO / SCREEN CAPTURE"
            color: "#e5d3a8"; font.pixelSize: 12
        }
        Text {
            x: 12; y: 37
            text: root.videoStreams.length > 0 ? "ACTIVE: " + root.videoStreams.length + " PipeWire link(s)" : "No active PipeWire video link observed"
            color: "#cadbd1"; font.pixelSize: 12
        }
    }
    DeckTile {
        width: parent.width; height: 72
        glyph: "◉"; title: "Microphone mute"
        detail: Audio.source?.audio?.muted ? "MUTED" : "UNMUTED — TAP TO MUTE"
        selected: Audio.source?.audio?.muted ?? false
        enabledAction: Audio.source?.audio !== undefined && Audio.source?.audio !== null
        onActivated: Audio.toggleMicMute()
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: "Indicators reflect links visible to PipeWire, not guaranteed camera or microphone hardware use. They cannot identify every app, Wayland screencast or non-PipeWire camera access. Camera and screen sharing cannot be reliably distinguished here."
        color: "#8da598"; font.pixelSize: 11
    }
}
