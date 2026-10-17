import QtQuick

Rectangle {
    id: root
    property string glyph: "◇"
    property string title: "Action"
    property string detail: ""
    property bool selected: false
    property bool enabledAction: true
    property color glow: "#a8d9c1"
    signal activated()

    radius: 11
    color: selected ? "#183629" : (hit.containsMouse ? "#1a2928" : "#111e20")
    border.width: 1
    border.color: selected ? glow : (hit.containsMouse ? "#58776f" : "#354743")
    opacity: enabledAction ? 1 : 0.42

    Row {
        anchors { fill: parent; leftMargin: 13; rightMargin: 10 }
        spacing: 12
        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: root.glyph
            width: 24
            font { pixelSize: 21; family: "Noto Sans Symbols 2" }
            color: root.selected ? "#dfbd78" : root.glow
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 48
            spacing: 5
            Text {
                width: parent.width
                text: root.title
                color: "#e1ebdd"
                font { family: "Cinzel"; pixelSize: 13; bold: true }
                elide: Text.ElideRight
            }
            Text {
                width: parent.width
                text: root.detail
                color: "#9fafaa"
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    MouseArea {
        id: hit
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: root.enabledAction ? Qt.PointingHandCursor : Qt.ArrowCursor
        enabled: root.enabledAction
        onClicked: root.activated()
    }
}
