// Copyright (C) 2021 The Qt Company Ltd.
// SPDX-License-Identifier: LicenseRef-Qt-Commercial OR GPL-3.0-only

import QtQuick
import QtQuick.VirtualKeyboard
import QtQuick.VirtualKeyboard.Components
import QtQuick.Layouts

KeyboardLayout {
    inputMode: InputEngine.InputMode.Latin
    keyWeight: 72

    KeyboardRow {
        Layout.fillWidth: true
        Key { key: Qt.Key_QuoteLeft; text: "`"; displayText: "~" }
        Key { key: Qt.Key_1; text: "1" }
        Key { key: Qt.Key_2; text: "2" }
        Key { key: Qt.Key_3; text: "3" }
        Key { key: Qt.Key_4; text: "4" }
        Key { key: Qt.Key_5; text: "5" }
        Key { key: Qt.Key_6; text: "6" }
        Key { key: Qt.Key_7; text: "7" }
        Key { key: Qt.Key_8; text: "8" }
        Key { key: Qt.Key_9; text: "9" }
        Key { key: Qt.Key_0; text: "0" }
        Key { key: Qt.Key_Minus; text: "-" }
        Key { key: Qt.Key_Equal; text: "=" }
        Key { key: Qt.Key_Backspace; displayText: "Back"; repeat: true; weight: 108 }
    }

    KeyboardRow {
        Layout.fillWidth: true
        Key { key: Qt.Key_Tab; text: "Tab"; weight: 108 }
        Key { key: Qt.Key_Q; text: "q" }
        Key { key: Qt.Key_W; text: "w" }
        Key { key: Qt.Key_E; text: "e" }
        Key { key: Qt.Key_R; text: "r" }
        Key { key: Qt.Key_T; text: "t" }
        Key { key: Qt.Key_Y; text: "y" }
        Key { key: Qt.Key_U; text: "u" }
        Key { key: Qt.Key_I; text: "i" }
        Key { key: Qt.Key_O; text: "o" }
        Key { key: Qt.Key_P; text: "p" }
        Key { key: Qt.Key_BracketLeft; text: "[" }
        Key { key: Qt.Key_BracketRight; text: "]" }
        Key { key: Qt.Key_Backslash; text: "\\" }
    }

    KeyboardRow {
        Layout.fillWidth: true
        Key { key: Qt.Key_CapsLock; displayText: "Caps"; weight: 126 }
        Key { key: Qt.Key_A; text: "a" }
        Key { key: Qt.Key_S; text: "s" }
        Key { key: Qt.Key_D; text: "d" }
        Key { key: Qt.Key_F; text: "f" }
        Key { key: Qt.Key_G; text: "g" }
        Key { key: Qt.Key_H; text: "h" }
        Key { key: Qt.Key_J; text: "j" }
        Key { key: Qt.Key_K; text: "k" }
        Key { key: Qt.Key_L; text: "l" }
        Key { key: Qt.Key_Semicolon; text: ";" }
        Key { key: Qt.Key_Apostrophe; text: "'" }
        Key { key: Qt.Key_Return; displayText: "Enter"; weight: 126 }
    }

    KeyboardRow {
        Layout.fillWidth: true
        Key { key: Qt.Key_Shift; displayText: "Shift"; weight: 162 }
        Key { key: Qt.Key_Z; text: "z" }
        Key { key: Qt.Key_X; text: "x" }
        Key { key: Qt.Key_C; text: "c" }
        Key { key: Qt.Key_V; text: "v" }
        Key { key: Qt.Key_B; text: "b" }
        Key { key: Qt.Key_N; text: "n" }
        Key { key: Qt.Key_M; text: "m" }
        Key { key: Qt.Key_Comma; text: "," }
        Key { key: Qt.Key_Period; text: "." }
        Key { key: Qt.Key_Slash; text: "/" }
        Key { key: Qt.Key_Shift; displayText: "Shift"; weight: 162 }
    }

    KeyboardRow {
        Layout.fillWidth: true
        Key { key: Qt.Key_unknown; displayText: "Fn"; noKeyEvent: true }
        Key { key: Qt.Key_Control; text: "Ctrl"; weight: 90 }
        Key { key: Qt.Key_Alt; text: "Alt"; weight: 90 }
        Key { key: Qt.Key_Space; text: " "; displayText: "Space"; weight: 612 }
        Key { key: Qt.Key_Alt; text: "Alt"; weight: 90 }
        Key { key: Qt.Key_Control; text: "Ctrl"; weight: 90 }
    }
}
