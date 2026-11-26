import QtQuick

// Stub of the shell's DFilterChips (DCommon/Widgets/DFilterChips.qml) with its selection rule:
// a chip is highlighted when its index equals currentIndex, and a click assigns currentIndex
// (which breaks a binding on it) before it emits selectionChanged. click() does what a click on
// a chip does.
Flow {
    id: root

    property var model: []
    property int currentIndex: 0
    property bool showCheck: true
    signal selectionChanged(int index)

    function click(index) {
        root.currentIndex = index;
        root.selectionChanged(index);
    }

    Repeater {
        model: root.model
        Item {
            width: 10
            height: 10
        }
    }
}
