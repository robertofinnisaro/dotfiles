import QtQuick

Rectangle {
    id: root
    property string title: "TAB"
    property bool selected: false
    signal activated()
    radius: 8
    color: selected ? "#27483b" : (area.containsMouse ? "#22332f" : "#152624")
    border.width: 1
    border.color: selected ? "#d3b57a" : "#436056"

    Text {
        anchors.centerIn: parent
        text: root.title
        color: root.selected ? "#eed8a1" : "#acbfb4"
        font.pixelSize: 11
        font.bold: root.selected
    }
    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.activated()
    }
}
