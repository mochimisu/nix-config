import QtQuick
import QtQuick.Controls
import Quickshell
import "Search.js" as AppSearch

FocusScope {
    id: phone
    signal dismissed()
    signal actionRequested(string action)
    property var services: null
    readonly property bool searching: search.text.length > 0
    signal launchRequested(var app)
    property bool depth: true
    property bool interactive: true
    property point lastPointerPosition: Qt.point(NaN, NaN)
    property alias query: search.text
    property var applications: DesktopEntries.applications.values
    readonly property var results: AppSearch.rank(applications, search.text)
    readonly property var detailApp: AppSearch.detailApp(results, search.text, grid.currentIndex)
    readonly property color ink: "#28585c"
    readonly property color mint: "#b8ece6"
    readonly property color pink: "#f5dbe9"
    focus: true
    onSearchingChanged: { if (!searching) homeInput.forceActiveFocus(); }
    onResultsChanged: grid.currentIndex = results.length ? 0 : -1

    function reset() {
        search.clear();
        grid.currentIndex = results.length ? 0 : -1;
        grid.contentY = 0;
        homeInput.forceActiveFocus();
    }
    function moveSelection(delta) {
        if (!interactive || !searching || !results.length) return;
        grid.currentIndex = Math.max(0, Math.min(results.length - 1, grid.currentIndex + delta));
        grid.positionViewAtIndex(grid.currentIndex, GridView.Contain);
        // The output crops the lower part of this viewport. Scroll selection
        // above that hidden area without shortening the painted app grid.
        const rowBottom = (Math.floor(grid.currentIndex / grid.columns) + 1) * grid.cellHeight;
        grid.contentY = Math.max(grid.contentY, rowBottom - grid.height + grid.bottomMargin);
    }
    function launchSelected() {
        if (interactive && searching && grid.currentIndex >= 0 && grid.currentIndex < results.length)
            launchRequested(results[grid.currentIndex]);
    }
    Keys.onEscapePressed: { if (searching) search.clear(); else dismissed(); }

    Item {
        x: -24; y: -24
        width: phone.width + 64; height: phone.height + 72
        // Keep rounded chassis edges in the antialiased scene geometry.
        // A transformed texture quad loses edge coverage despite mipmap filtering.
        Item {
            x: 24; y: 24
            width: phone.width; height: phone.height
            // Layered low-opacity silhouettes soften the shadow without a blur pass.
            Repeater {
                model: phone.depth ? 7 : 0
                Rectangle {
                    required property int index
                    x: 10 - index * 2
                    y: 15 - index * 2
                    width: phone.width - 4 + index * 4
                    height: phone.height - 8 + index * 4
                    radius: 37 + index * 2
                    color: "#183b42"
                    opacity: 0.025
                }
            }
            // The offset rear shell and stepped rim expose a restrained side wall.
            Rectangle {
                visible: phone.depth
                x: 28; y: 17
                width: phone.width - 12; height: phone.height - 12
                radius: 36
                antialiasing: true
                color: "#183d43"
                border.color: "#123139"
                border.width: 1
                Rectangle {
                    x: parent.width - 3; y: 120
                    width: 3; height: 45; radius: 1.5
                    color: "#658d8e"
                }
            }
            Rectangle {
                visible: phone.depth
                x: 17; y: 11
                width: phone.width - 12; height: phone.height - 12
                radius: 36
                antialiasing: true
                color: "#32686d"
                border.color: "#91b4b3"
                border.width: 1
            }

            Rectangle {
                anchors.fill: parent
                anchors.margins: 6
                radius: 36
                antialiasing: true
                color: phone.ink
                border.width: phone.depth ? 1 : 0
                border.color: "#b7d9d4"
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: phone.depth ? 6 : 5
                    radius: 31
                    antialiasing: true
                    gradient: Gradient {
                        GradientStop { position: 0; color: "#e2f6f0" }
                        GradientStop { position: 0.35; color: "#fbfcfa" }
                        GradientStop { position: 1; color: "#e9f5f2" }
                    }
                    border.width: 2
                    border.color: phone.depth ? "#86b8b2" : phone.mint
                }

            }

        }
    }

    Item {
        id: homeInput
        focus: true
        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) { phone.dismissed(); event.accepted = true; return; }
            if (event.text.length && !/[\x00-\x1f\x7f]/.test(event.text)
                    && !(event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))) {
                search.text = event.text;
                search.forceActiveFocus();
                event.accepted = true;
            }
        }
        Component.onCompleted: forceActiveFocus()
    }
    Column {
        id: header
        visible: phone.searching
        anchors { top: parent.top; left: parent.left; right: parent.right; topMargin: 25; leftMargin: 25; rightMargin: 25 }
        spacing: 14
        Row {
            width: parent.width
            Column {
                width: parent.width - 36
                spacing: 2
                Text { renderType: Text.CurveRendering;
                    text: (phone.services?.hostname || "HOST") + " / LAUNCHER"
                    color: "#648f91"
                    font { family: "Montserrat"; pixelSize: 9; bold: true; letterSpacing: 1.1 }
                }
                Row {
                    spacing: 8
                    Text { renderType: Text.CurveRendering;
                        text: phone.searching ? "Applications" : "Your phone"
                        color: phone.ink
                        font { family: "Montserrat"; pixelSize: phone.width < 320 ? 18 : 22; bold: true; italic: true }
                    }
                    Rectangle {
                        width: 32; height: 21; radius: 10
                        color: phone.mint
                        border { width: 1; color: phone.ink }
                        Text { renderType: Text.CurveRendering;
                            anchors.centerIn: parent
                            text: phone.results.length
                            color: phone.ink
                            font { pixelSize: 10; bold: true }
                        }
                    }
                }
                Row {
                    spacing: 3
                    Repeater {
                        model: ["#72c9c1", "#b7a7d8", "#e7b5cf", "#e6d891"]
                        Rectangle { required property color modelData; width: 17; height: 3; radius: 1; color: modelData }
                    }
                }
            }
            ToolButton {
                enabled: phone.interactive
                width: 32; height: 32
                text: "×"
                Accessible.name: "Close launcher"
                onClicked: phone.dismissed()
                contentItem: Text { renderType: Text.CurveRendering; text: parent.text; color: phone.ink; font.pixelSize: 25; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 12; color: parent.hovered ? phone.pink : "#e9f6f2"; border.color: phone.ink }
            }
        }
        TextField {
            renderType: TextInput.CurveRendering
            id: search
            objectName: "search"
            width: parent.width
            height: 40
            visible: phone.searching
            focus: phone.searching
            readOnly: false // Accept the first keystroke even while the phone enters.
            placeholderText: "Type to find an app…"
            Accessible.name: "Search apps"
            color: phone.ink
            placeholderTextColor: "#618083"
            selectionColor: phone.mint
            selectedTextColor: phone.ink
            font.pixelSize: 15
            leftPadding: 36
            rightPadding: 12
            font.weight: Font.DemiBold
            Item {
                x: 13; y: 12; width: 16; height: 16
                Rectangle { width: 10; height: 10; radius: 5; color: "transparent"; border { width: 2; color: phone.ink } }
                Rectangle { x: 9; y: 9; width: 7; height: 2; rotation: 45; color: phone.ink }
            }
            background: Rectangle {
                radius: 18; color: "#f6fffd"; border.width: 2; border.color: phone.ink
                Rectangle {
                    anchors.fill: parent; anchors.margins: 4
                    radius: 14; color: "transparent"
                    border.width: 1; border.color: search.activeFocus ? "#86c8c4" : "#c8ded9"
                }
            }
            Keys.onDownPressed: phone.moveSelection(grid.columns)
            Keys.onUpPressed: phone.moveSelection(-grid.columns)
            Keys.onRightPressed: event => { phone.moveSelection(1); event.accepted = true; }
            Keys.onLeftPressed: event => { phone.moveSelection(-1); event.accepted = true; }
            Keys.onTabPressed: phone.moveSelection(1)
            Keys.onBacktabPressed: phone.moveSelection(-1)
            Keys.onReturnPressed: phone.launchSelected()
            Keys.onEnterPressed: phone.launchSelected()
            Keys.onEscapePressed: { if (phone.searching) search.clear(); else phone.dismissed(); }
        }
    }

    Flickable {
        id: homeView
        objectName: "homeView"
        anchors { top: parent.top; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: phone.depth ? 12 : 11; leftMargin: phone.depth ? 12 : 11; rightMargin: phone.depth ? 12 : 11 }
        contentWidth: width
        contentHeight: controls.height
        bottomMargin: 110
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: phone.interactive && !phone.searching
        opacity: phone.searching ? 0 : 1
        visible: opacity > 0
        transform: Translate { x: phone.searching ? -12 : 0; Behavior on x { NumberAnimation { duration: 140 } } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        HomeControls {
            id: controls
            width: homeView.width
            services: phone.services
            interactive: phone.interactive && !phone.searching
            onActionRequested: action => phone.actionRequested(action)
        }
    }
    GridView {
        id: grid
        opacity: phone.searching && !phone.detailApp ? 1 : 0
        visible: opacity > 0
        enabled: phone.searching && !phone.detailApp
        transform: Translate { x: phone.searching ? 0 : 12; Behavior on x { NumberAnimation { duration: 140 } } }
        Behavior on opacity { NumberAnimation { duration: 140 } }
        objectName: "apps"
        anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 17; bottomMargin: 0; leftMargin: 22; rightMargin: 22 }
        readonly property int columns: width < 300 ? 3 : 4
        cellWidth: width / columns
        cellHeight: 104
        clip: true
        model: phone.results
        currentIndex: count ? 0 : -1
        // Extra scroll travel lets the last row clear the screen-edge crop.
        bottomMargin: 110
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Item {
            id: tile
            required property var modelData
            required property int index
            width: grid.cellWidth
            height: grid.cellHeight
            readonly property bool selected: tile.index === grid.currentIndex
            Rectangle {
                x: (parent.width - 60) / 2 + 1; y: 3
                width: 60; height: 60; radius: 21
                color: "#78aaa8"
            }
            Rectangle {
                anchors { top: parent.top; horizontalCenter: parent.horizontalCenter }
                width: 60; height: 60; radius: 21
                color: hit.containsMouse ? "#d6e9fb" : (tile.selected ? "#a7dfd7" : ["#e0f1ed", "#eee5f3", "#f6e6ee", "#f6f0d8"][tile.index % 4])
                border.color: phone.ink
                border.width: tile.selected ? 3 : 2
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 5
                    radius: 16
                    color: "transparent"
                    border.width: 1
                    border.color: "#faffff"
                }
                Behavior on color { ColorAnimation { duration: 100 } }
                Image {
                    id: icon
                    anchors.centerIn: parent
                    width: 36; height: 36
                    source: tile.modelData.icon ? Quickshell.iconPath(tile.modelData.icon, true) : ""
                    fillMode: Image.PreserveAspectFit
                    antialiasing: true
                    smooth: true
                    mipmap: true
                    sourceSize { width: 96; height: 96 }
                }
                Text { renderType: Text.CurveRendering;
                    anchors.centerIn: parent
                    visible: !icon.source.toString() || icon.status === Image.Error
                    text: tile.modelData.name.slice(0, 1).toUpperCase()
                    font { pixelSize: 25; bold: true }
                    color: phone.ink
                }
            }
            Text { renderType: Text.CurveRendering;
                anchors { top: parent.top; topMargin: 64; left: parent.left; right: parent.right; leftMargin: 3; rightMargin: 3 }
                text: tile.modelData.name
                color: phone.ink
                font { pixelSize: 11; weight: tile.selected ? Font.Bold : Font.DemiBold }
                lineHeight: 1.05
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
            Rectangle {
                visible: tile.selected
                x: (parent.width + 60) / 2 - 8; y: 0
                width: 10; height: 10; radius: 3
                color: "#f1d17e"
                border { width: 1; color: phone.ink }
                rotation: 45
            }
            MouseArea {
                id: hit
                enabled: phone.interactive
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // A stationary pointer must not override the top search match.
                onPositionChanged: mouse => {
                    const point = mapToGlobal(mouse.x, mouse.y);
                    const previous = phone.lastPointerPosition;
                    phone.lastPointerPosition = point;
                    if (containsMouse && !isNaN(previous.x)
                        && (Math.abs(point.x - previous.x) > 1 || Math.abs(point.y - previous.y) > 1))
                        grid.currentIndex = tile.index;
                }
                onClicked: phone.launchRequested(tile.modelData)
            }
        }
        Text { renderType: Text.CurveRendering;
            anchors.centerIn: parent
            visible: grid.count === 0
            text: "No apps found\nTry another name."
            color: "#618083"
            horizontalAlignment: Text.AlignHCenter
            font.pixelSize: 15
        }
    }
    AppDetail {
        objectName: "appDetail"
        anchors { top: header.bottom; bottom: parent.bottom; left: parent.left; right: parent.right; topMargin: 17; bottomMargin: 105; leftMargin: 25; rightMargin: 25 }
        app: phone.detailApp
        interactive: phone.interactive
        visible: !!app
        onLaunchRequested: app => phone.launchRequested(app)
    }

}
