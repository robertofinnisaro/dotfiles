import QtQuick

Item {
    width: 80
    height: 80

    property string label: "CPU"
    property real value: 0.5

    Canvas {
        anchors.fill: parent

        onPaint: {
            var ctx = getContext("2d")
            ctx.reset()

            var center = width / 2
            var radius = 30

            // background ring
            ctx.beginPath()
            ctx.arc(center, center, radius, 0, 2 * Math.PI)
            ctx.strokeStyle = "#1a1f2b"
            ctx.lineWidth = 4
            ctx.stroke()

            // value arc
            ctx.beginPath()
            ctx.arc(center, center, radius,
                    -Math.PI/2,
                    (-Math.PI/2) + (2 * Math.PI * value))
            // ctx.strokeStyle = "#00eaff"
            ctx.strokeStyle = "#39ff14"
            ctx.lineWidth = 4
            ctx.stroke()
        }
    }

    Text {
        anchors.centerIn: parent
        text: Math.round(value * 100) + "%"
        // color: "#00eaff"
        color: "#39ff14"
        font.pixelSize: 12
    }

    Text {
        anchors.top: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        text: label
        // color: "#cfefff"
        color: "#39ff14"
        font.pixelSize: 10
    }
}