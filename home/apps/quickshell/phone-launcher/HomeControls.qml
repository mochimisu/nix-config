import QtQuick
import QtQuick.Controls
import Quickshell

Column {
    id: home
    property var services: null
    property bool interactive: true
    signal actionRequested(string action)
    spacing: 9
    readonly property color ink: "#28585c"
    Rectangle {
        width: parent.width; height: 115; radius: 20
        color: "#d1eae4"; border { color: home.ink; width: 2 }
        Image { anchors.fill: parent; anchors.margins: 6; source: home.services ? home.services.wallpaper : ""; fillMode: Image.PreserveAspectCrop }
        Rectangle { anchors.fill: parent; anchors.margins: 3; color: "#aaf1fff9"; radius: 17 }
        Column {
            x: 13; y: 13; spacing: 3
            Text { text: home.services ? Qt.formatDateTime(home.services.now, "h:mm AP") : "—"; color: home.ink; font { pixelSize: 22; bold: true; italic: true } }
            Text { text: home.services ? Qt.formatDateTime(home.services.now, "ddd, MMM d") : ""; color: home.ink; font { pixelSize: 11; bold: true } }
        }
        Column {
            anchors { right: parent.right; top: parent.top; margins: 13 } spacing: 4
            Text { text: "↓ " + (home.services ? home.services.download : "—"); color: home.ink; font { pixelSize: 10; bold: true } }
            Text { text: "↑ " + (home.services ? home.services.upload : "—"); color: home.ink; font { pixelSize: 10; bold: true } }
        }
        Text { x: 13; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; text: "QUICK CONTROLS"; color: home.ink; font { pixelSize: 10; bold: true; letterSpacing: 2 } }
    }
    Row {
        width: parent.width; spacing: 7
        Repeater {
            model: [
                {key: "network", glyph: "≋", icon: "network-wireless", title: "Network", value: home.services ? home.services.networkLabel : "Unavailable", color: "#dcefe9"},
                {key: "bluetooth", glyph: "ᛒ", icon: "bluetooth", title: "Bluetooth", value: home.services ? home.services.bluetoothLabel : "Unavailable", color: "#e9e2f2"},
                {key: "mute", glyph: "♪", icon: home.services && home.services.muted ? "audio-volume-muted" : "audio-volume-high", title: "Speaker", value: home.services ? home.services.audioLabel : "Unavailable", color: "#f3e4eb"}
            ]
            Button {
                focusPolicy: Qt.NoFocus
                required property var modelData
                objectName: modelData.key
                width: (home.width - 14) / 3; height: 64
                enabled: home.interactive && !!home.services && (modelData.key !== "mute" || home.services.audioReady)
                Accessible.name: modelData.title + ": " + modelData.value
                onClicked: modelData.key === "mute" ? home.services.toggleMute() : home.actionRequested(modelData.key)
                background: Rectangle { radius: 15; color: parent.hovered ? "#bedfdc" : parent.modelData.color; border { width: 2; color: home.ink } }
                contentItem: Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter; width: 18; height: 18
                        Image { id: controlIcon; anchors.fill: parent; source: Quickshell.iconPath(modelData.icon, true); fillMode: Image.PreserveAspectFit }
                        Text { anchors.centerIn: parent; visible: !controlIcon.source.toString() || controlIcon.status === Image.Error; text: modelData.glyph; color: home.ink; font { pixelSize: 18; bold: true } }
                    }
                    Text { width: parent.width; text: modelData.title; horizontalAlignment: Text.AlignHCenter; color: home.ink; font { pixelSize: 11; bold: true } }
                    Text { width: parent.width; text: modelData.value; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: home.ink; font.pixelSize: 9 }
                }
            }
        }
    }
    Rectangle {
        width: parent.width; height: 40; radius: 18; color: "#e5f2ee"; border { width: 2; color: home.ink }
        Text { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "VOL"; color: home.ink; font { pixelSize: 10; bold: true } }
        Slider {
            focusPolicy: Qt.NoFocus
            objectName: "volume"
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 48; rightMargin: 12 }
            from: 0; to: 1
            enabled: home.interactive && !!home.services && home.services.audioReady
            value: home.services ? home.services.volume : 0
            onMoved: home.services.setVolume(value)
            Accessible.name: "Speaker volume"
        }
    }
    Button {
        focusPolicy: Qt.NoFocus
        objectName: "capture"
        width: parent.width; height: 36; enabled: home.interactive
        text: "Screen capture  ↗"
        onClicked: home.actionRequested("capture")
        background: Rectangle { radius: 17; color: parent.hovered ? "#b8ded8" : "#d8eae6"; border { width: 2; color: home.ink } }
        contentItem: Text { text: parent.text; color: home.ink; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font { pixelSize: 13; bold: true; italic: true } }
    }
}
