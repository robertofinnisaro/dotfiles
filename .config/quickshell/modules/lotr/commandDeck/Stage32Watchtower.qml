// The Watchtower: searchable, grouped history supplied by the existing Notifications singleton.
import QtQuick
import qs
import qs.services

Column {
    id: root
    spacing: 10
    property string searchText: ""
    property bool priorityOnly: false
    property int quietRemaining: 0
    readonly property var groups: Notifications.appNameList.filter(function(app) {
        const entries = Notifications.groupsByAppName[app]?.notifications ?? [];
        return entries.some(function(n) { return root.matches(n); });
    })

    function matches(n) {
        if (!n) return false;
        if (priorityOnly && String(n.urgency).toLowerCase().indexOf("critical") === -1) return false;
        const query = searchText.trim().toLowerCase();
        if (!query) return true;
        return (String(n.appName || "") + " " + String(n.summary || "") + " " + String(n.body || "")).toLowerCase().indexOf(query) >= 0;
    }
    function quiet(minutes) {
        if (minutes === 0) {
            quietRemaining = 0;
            Notifications.silent = false;
            return;
        }
        quietRemaining = minutes;
        Notifications.silent = true;
    }
    Timer {
        interval: 60000
        repeat: true
        running: root.quietRemaining > 0
        onTriggered: {
            if (!Notifications.silent) { root.quietRemaining = 0; return; }
            root.quietRemaining = Math.max(0, root.quietRemaining - 1);
            if (root.quietRemaining === 0) Notifications.silent = false;
        }
    }
    Rectangle {
        width: parent.width; height: 59; radius: 9
        color: "#162b28"; border.color: "#4b7060"
        TextInput {
            id: filterInput
            anchors { left: parent.left; right: parent.right; top: parent.top; bottom: parent.bottom; leftMargin: 13; rightMargin: 85; topMargin: 13; bottomMargin: 13 }
            color: "#dfede4"; font.pixelSize: 15
            verticalAlignment: TextInput.AlignVCenter
            clip: true
            selectByMouse: true
            text: root.searchText
            onTextChanged: root.searchText = text
        }
        Text {
            visible: !filterInput.text.length
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 13 }
            text: "Search saved alerts…"; color: "#839f92"; font.pixelSize: 14
        }
        Rectangle {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 6 }
            width: 70; height: 47; radius: 7
            color: "#28473d"; border.color: "#b79c69"
            Text { anchors.centerIn: parent; text: "KEYS"; color: "#ead5ad"; font.pixelSize: 12 }
            MouseArea {
                anchors.fill: parent
                onClicked: {
                    GlobalStates.oskOpen = true;
                    filterInput.forceActiveFocus();
                }
            }
        }
    }
    Row {
        width: parent.width; spacing: 8
        DeckTile {
            width: (parent.width - 8) / 2; height: 63
            glyph: "!"; title: "Priority only"; detail: root.priorityOnly ? "FILTER ON" : "ALL ALERTS"
            selected: root.priorityOnly
            onActivated: root.priorityOnly = !root.priorityOnly
        }
        DeckTile {
            width: (parent.width - 8) / 2; height: 63
            glyph: "✓"; title: "Mark read"; detail: Notifications.unread + " unread"
            onActivated: Notifications.markAllRead()
        }
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: root.quietRemaining > 0 ? "Quiet watch: " + root.quietRemaining + " min remaining (until session restart)" : (Notifications.silent ? "Quiet watch is enabled manually" : "Silence notifications for a chosen period")
        color: "#afc5b8"; font.pixelSize: 11
    }
    Row {
        width: parent.width; spacing: 8
        DeckTab {
            width: (parent.width - 16) / 3; height: 54
            title: "30 MIN"; selected: root.quietRemaining > 0 && root.quietRemaining <= 30
            onActivated: root.quiet(30)
        }
        DeckTab {
            width: (parent.width - 16) / 3; height: 54
            title: "60 MIN"; selected: root.quietRemaining > 30
            onActivated: root.quiet(60)
        }
        DeckTab {
            width: (parent.width - 16) / 3; height: 54
            title: "ALERTS ON"; selected: !Notifications.silent
            onActivated: root.quiet(0)
        }
    }
    Text {
        width: parent.width
        text: root.groups.length + " MATCHING APPLICATIONS"
        color: "#e2c993"; font { pixelSize: 11; bold: true }
    }
    Text {
        visible: root.groups.length === 0
        width: parent.width; wrapMode: Text.WordWrap
        text: "No saved alerts match the current filter."
        color: "#a7baae"; font.pixelSize: 12
    }
    Repeater {
        model: root.groups
        delegate: Column {
            id: group
            required property string modelData
            width: root.width
            spacing: 6
            readonly property var entries: (Notifications.groupsByAppName[modelData]?.notifications ?? []).filter(function(n) { return root.matches(n); })
            Rectangle {
                width: parent.width; height: 37; radius: 6
                color: "#254138"
                Text {
                    anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 12 }
                    text: group.modelData + "  (" + group.entries.length + ")"
                    color: "#e6d29f"; font { pixelSize: 12; bold: true }
                }
            }
            Repeater {
                model: group.entries
                delegate: Rectangle {
                    id: notificationRow
                    required property var modelData
                    width: group.width; height: Math.max(100, summaryText.implicitHeight + bodyText.implicitHeight + 58)
                    radius: 7; color: "#142924"; border.color: "#405e51"
                    Text {
                        id: summaryText
                        x: 11; y: 10; width: parent.width - 103
                        wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: String(notificationRow.modelData.summary || "(No title)")
                        color: "#ebdfc3"; font { pixelSize: 13; bold: true }
                    }
                    Text {
                        id: bodyText
                        x: 11; anchors.top: summaryText.bottom; anchors.topMargin: 5
                        width: parent.width - 103
                        wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
                        textFormat: Text.PlainText
                        text: String(notificationRow.modelData.body || "")
                        color: "#adc5b8"; font.pixelSize: 12
                    }
                    Rectangle {
                        anchors { right: parent.right; top: parent.top; topMargin: 15; rightMargin: 10 }
                        width: 80; height: 55; radius: 7
                        color: removeArea.containsMouse ? "#4a302b" : "#2a3932"
                        border.color: "#8e7860"
                        Text { anchors.centerIn: parent; text: "Dismiss"; color: "#eedcb4"; font.pixelSize: 12 }
                        MouseArea {
                            id: removeArea; anchors.fill: parent
                            hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                            onClicked: Notifications.discardNotification(notificationRow.modelData.notificationId)
                        }
                    }
                }
            }
        }
    }
    Text {
        width: parent.width; wrapMode: Text.WordWrap
        text: "History is provided by your existing notification service. Search, priority filtering and dismissal work on saved alerts; expired app actions are not replayed."
        color: "#82998d"; font.pixelSize: 11
    }
}
