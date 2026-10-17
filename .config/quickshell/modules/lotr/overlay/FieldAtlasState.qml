// State lives outside Overlay.qml's on-demand Loader, so the focus timer
// continues when Super+G is closed and the notes editor keeps its text.
pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: state
    property int focusSeconds: 25 * 60
    property int focusPreset: 25
    property bool focusRunning: false
    property string feedback: "Ready for the next expedition"
    property string notes: ""
    property bool notesReady: false

    function focusClock() {
        const m = Math.floor(focusSeconds / 60);
        const s = focusSeconds % 60;
        return String(m).padStart(2, "0") + ":" + String(s).padStart(2, "0");
    }

    function setTimer(minutes) {
        focusRunning = false;
        focusPreset = minutes;
        focusSeconds = minutes * 60;
        feedback = "Watch reset to " + minutes + " minutes";
    }

    function setNotes(text) {
        if (!notesReady || text === notes) return;
        notes = text;
        notesSaveTimer.restart();
    }

    function flushNotes() {
        if (!notesReady || !notesSaveTimer.running) return;
        notesSaveTimer.stop();
        notesFile.setText(notes);
    }

    Timer {
        interval: 1000
        repeat: true
        running: state.focusRunning
        onTriggered: {
            if (state.focusSeconds > 0) state.focusSeconds--;
            if (state.focusSeconds === 0) {
                state.focusRunning = false;
                state.feedback = "The watch is complete — take a break";
                Quickshell.execDetached(["notify-send", "Field Atlas", "The watch is complete. Take a break."]);
            }
        }
    }

    FileView {
        id: notesFile
        path: Quickshell.statePath("palantir-field-notes.txt")
        atomicWrites: true
        onLoaded: {
            state.notes = notesFile.text();
            state.notesReady = true;
        }
        onLoadFailed: (error) => {
            // On the first run, the notes file does not exist yet.
            state.notesReady = true;
        }
        onSaved: state.feedback = "Field notes saved";
        onSaveFailed: (error) => state.feedback = "Notes could not be saved — check qs log";
    }

    Timer {
        id: notesSaveTimer
        interval: 650
        repeat: false
        onTriggered: notesFile.setText(state.notes)
    }
}
