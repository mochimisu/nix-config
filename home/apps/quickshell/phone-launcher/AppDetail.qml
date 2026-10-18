import QtQuick
import QtQuick.Controls
import Quickshell

Flickable {
    id: detail
    property var app: null
    signal launchRequested(var app)
    readonly property bool compact: height < 340
    clip: true
    contentWidth: width
    contentHeight: Math.max(height, card.implicitHeight + 24)
    boundsBehavior: Flickable.StopAtBounds
    onAppChanged: contentY = 0
    Column {
        id: card
        width: parent.width
        y: Math.max(8, (detail.height - implicitHeight) / 2)
        spacing: detail.compact ? 7 : 12
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: detail.compact ? 64 : 100; height: width; radius: detail.compact ? 22 : 30
            color: "#b8ece6"; border {width: 2; color: "#28585c"}
            antialiasing: true
            Rectangle { anchors.fill: parent; anchors.margins: 6; radius: 24; color: "transparent"; border {width: 2; color: "#faffff"} antialiasing: true }
            Image {
                id: icon
                anchors.centerIn: parent
                width: detail.compact ? 40 : 64; height: width
                source: detail.app?.icon ? Quickshell.iconPath(detail.app.icon, true) : ""
                sourceSize {width: 192; height: 192}
                fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; antialiasing: true
            }
            Text {
                anchors.centerIn: parent
                visible: !icon.source.toString() || icon.status === Image.Error
                text: String(detail.app?.name || "").slice(0,1).toUpperCase()
                color: "#28585c"; font {pixelSize: 38; bold: true} renderType: Text.CurveRendering
            }
        }
        Text {
            width: parent.width; text: detail.app?.name || ""
            color: "#28585c"; font {family:"Montserrat"; pixelSize: detail.compact ? 20 : 23; bold: true}
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: 3; elide: Text.ElideRight
            renderType: Text.CurveRendering
        }
        Text {
            width: parent.width; text: detail.app?.genericName || ""
            visible: text.length > 0 && text !== detail.app?.name
            color: "#52777a"; font {pixelSize: 12; weight: Font.DemiBold}
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; renderType: Text.CurveRendering
        }
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 48; height: 3; radius: 1.5; color: "#b7a7d8" }
        Text {
            width: parent.width; text: detail.app?.comment || ""
            visible: text.length > 0
            color: "#52777a"; font.pixelSize: 13
            horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap; maximumLineCount: detail.compact ? 2 : 4; elide: Text.ElideRight
            renderType: Text.CurveRendering
        }
        Button {
            objectName: "openApp"
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(parent.width, 210); height: 44
            enabled: detail.interactive && !!detail.app
            text: "Open application  →"
            Accessible.name: "Open " + (detail.app?.name || "application")
            onClicked: detail.launchRequested(detail.app)
            contentItem: Text { text: parent.text; color: "#28585c"; font {pixelSize: 13; bold:true} horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; renderType: Text.CurveRendering }
            background: Rectangle {radius: 16; color: parent.hovered ? "#f5dbe9" : "#b8ece6"; border {width: 2; color: "#28585c"} antialiasing:true}
        }
        Text { visible: !detail.compact; anchors.horizontalCenter: parent.horizontalCenter; text: "Enter to open · Esc to clear"; color:"#648f91"; font.pixelSize:10; renderType: Text.CurveRendering }
    }
}
