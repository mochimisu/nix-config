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
    Item {
        width: parent.width; height: 128
        Canvas {
            id: wallpaper
            // Transparent texels let filtering cover the transformed outer edge.
            x: -1; y: -1
            width: parent.width * 2 + 4; height: parent.height * 2 + 4
            scale: 0.5
            transformOrigin: Item.TopLeft
            // Rasterize the rounded wallpaper clip at the phone layer's density.
            layer.enabled: wallpaper.GraphicsInfo.api !== GraphicsInfo.Software
            layer.textureSize: Qt.size(width, height)
            layer.smooth: true
            layer.mipmap: true
            smooth: true
            antialiasing: true
            property string imageUrl: home.services ? home.services.wallpaper : ""
            onImageUrlChanged: { if (imageUrl) loadImage(imageUrl); requestPaint(); }
            onImageLoaded: requestPaint()
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
            Component.onCompleted: { if (imageUrl) loadImage(imageUrl); }
            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                ctx.scale(2, 2);
                ctx.translate(1, 1);
                const paintWidth = width / 2 - 2, paintHeight = height / 2 - 2;
                const r = 31;
                ctx.beginPath();
                ctx.moveTo(0, paintHeight); ctx.lineTo(0, r);
                ctx.quadraticCurveTo(0, 0, r, 0);
                ctx.lineTo(paintWidth - r, 0); ctx.quadraticCurveTo(paintWidth, 0, paintWidth, r);
                ctx.lineTo(paintWidth, paintHeight); ctx.closePath(); ctx.clip();
                ctx.fillStyle = "#d1eae4"; ctx.fillRect(0, 0, paintWidth, paintHeight);
                if (imageUrl && isImageLoaded(imageUrl)) {
                    const image = ctx.createImageData(imageUrl);
                    const scale = Math.max(paintWidth / image.width, paintHeight / image.height);
                    const w = image.width * scale, h = image.height * scale;
                    ctx.drawImage(imageUrl, (paintWidth - w) / 2, (paintHeight - h) / 2, w, h);
                }
            }
        }
        Column {
            x: 13; y: 13; spacing: 3
            Text { renderType: Text.CurveRendering; text: home.services ? Qt.formatDateTime(home.services.now, "h:mm AP") : "—"; color: "#ffffff"; style: Text.Outline; styleColor: "#203a42"; font { pixelSize: 22; bold: true; italic: true } }
            Text { renderType: Text.CurveRendering; text: home.services ? Qt.formatDateTime(home.services.now, "ddd, MMM d") : ""; color: "#ffffff"; style: Text.Outline; styleColor: "#203a42"; font { pixelSize: 11; bold: true } }
        }
        Column {
            anchors { right: parent.right; top: parent.top; margins: 13 } spacing: 4
            Text { renderType: Text.CurveRendering; text: "↓ " + (home.services ? home.services.download : "—"); color: "#ffffff"; style: Text.Outline; styleColor: "#203a42"; font { pixelSize: 10; bold: true } }
            Text { renderType: Text.CurveRendering; text: "↑ " + (home.services ? home.services.upload : "—"); color: "#ffffff"; style: Text.Outline; styleColor: "#203a42"; font { pixelSize: 10; bold: true } }
        }
        Text { renderType: Text.CurveRendering; x: 13; anchors.bottom: parent.bottom; anchors.bottomMargin: 14; text: "QUICK CONTROLS"; color: "#ffffff"; style: Text.Outline; styleColor: "#203a42"; font { pixelSize: 10; bold: true; letterSpacing: 2 } }
    }
    Row {
        x: 13; width: parent.width - 26; spacing: 7
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
                width: (home.width - 40) / 3; height: 64
                enabled: home.interactive && !!home.services && (modelData.key !== "mute" || home.services.audioReady)
                Accessible.name: modelData.title + ": " + modelData.value
                onClicked: modelData.key === "mute" ? home.services.toggleMute() : home.actionRequested(modelData.key)
                background: Rectangle { radius: 15; color: parent.hovered ? "#bedfdc" : parent.modelData.color; border { width: 2; color: home.ink } }
                contentItem: Column {
                    spacing: 2
                    Item {
                        anchors.horizontalCenter: parent.horizontalCenter; width: 18; height: 18
                        Image { id: controlIcon; anchors.fill: parent; source: Quickshell.iconPath(modelData.icon, true); fillMode: Image.PreserveAspectFit }
                        Text { renderType: Text.CurveRendering; anchors.centerIn: parent; visible: !controlIcon.source.toString() || controlIcon.status === Image.Error; text: modelData.glyph; color: home.ink; font { pixelSize: 18; bold: true } }
                    }
                    Text { renderType: Text.CurveRendering; width: parent.width; text: modelData.title; horizontalAlignment: Text.AlignHCenter; color: home.ink; font { pixelSize: 11; bold: true } }
                    Text { renderType: Text.CurveRendering; width: parent.width; text: modelData.value; elide: Text.ElideRight; horizontalAlignment: Text.AlignHCenter; color: home.ink; font.pixelSize: 9 }
                }
            }
        }
    }
    Rectangle {
        x: 13; width: parent.width - 26; height: 40; radius: 18; color: "#e5f2ee"; border { width: 2; color: home.ink }
        Text { renderType: Text.CurveRendering; x: 12; anchors.verticalCenter: parent.verticalCenter; text: "VOL"; color: home.ink; font { pixelSize: 10; bold: true } }
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
        x: 13; width: parent.width - 26; height: 36; enabled: home.interactive
        text: "Screen capture  ↗"
        onClicked: home.actionRequested("capture")
        background: Rectangle { radius: 17; color: parent.hovered ? "#b8ded8" : "#d8eae6"; border { width: 2; color: home.ink } }
        contentItem: Text { renderType: Text.CurveRendering; text: parent.text; color: home.ink; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font { pixelSize: 13; bold: true; italic: true } }
    }
}
