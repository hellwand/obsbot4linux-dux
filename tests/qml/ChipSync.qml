import QtQuick
import "../.."

// The highlighted chip of a chip row follows the value it shows, whatever changed it: the
// camera (another client, the pill's middle click, the camera itself), a click on a chip, or
// both in turn. SettingChips is the chip row of the tracking mode in the popout
// (TrackingSection) and in the desktop widget (DesktopSide); a plain ChipRow is the camera
// picker and the gimbal step. Run by scripts/check-components.sh.
Item {
    id: test

    property int failed: 0
    property int passed: 0

    // The part of CameraLink that SettingChips reads; `revision` tells the bindings, like
    // CameraLink's own revision.
    QtObject {
        id: link
        property int revision: 0
        property var values: ({
                "tracking.mode": "close_up"
            })
        function value(path) {
            return revision >= 0 ? values[path] : null;
        }
        function has(path) {
            return true;
        }
        function blocked(path) {
            return null;
        }
        function status(path) {
            return "camera";
        }
        function setting(path) {
            return null;
        }
        function choices(path, labels) {
            return revision >= 0 ? ["static", "normal", "upper_body", "close_up"].map(v => ({
                            value: v,
                            label: v,
                            selectable: true
                        })) : [];
        }
        // The widget's own value shows from the request on (spec 5 rule 4)
        function set(path, value) {
            change(path, value);
        }
        function change(path, value) {
            const next = Object.assign({}, values);
            next[path] = value;
            values = next;
            revision += 1;
        }
    }

    SettingChips {
        id: modeRow
        stacked: true
        link: link
        path: "tracking.mode"
        text: "Tracking mode"
    }

    property int picked: 0
    ChipRow {
        id: plainRow
        label: "Step"
        options: ["5°", "1°"]
        currentIndex: test.picked
        onSelected: index => test.picked = index
    }

    // The DFilterChips inside a row
    function chipsOf(row) {
        for (const child of row.children)
            if (child.selectionChanged !== undefined && child.showCheck !== undefined)
                return child;
        return null;
    }

    // A click on the chip of option `index` (the right-aligned layout reverses the chips)
    function click(row, index) {
        chipsOf(row).click(row.chipIndex(index));
    }

    function highlighted(row) {
        return row.chipIndex(chipsOf(row).currentIndex);
    }

    function expect(name, row, index) {
        if (highlighted(row) === index && row.currentIndex === index) {
            passed += 1;
        } else {
            failed += 1;
            console.log("FAIL " + name + ": highlighted chip " + highlighted(row) + ", shown value's chip " + row.currentIndex + ", expected " + index);
        }
    }

    function modeIndex(mode) {
        return ["static", "normal", "upper_body", "close_up"].indexOf(mode);
    }

    Component.onCompleted: {
        expect("start", modeRow, modeIndex("close_up"));

        // The owner's report: Close-up -> Static from elsewhere, the row kept Close-up
        link.change("tracking.mode", "static");
        expect("camera changes the mode before any click", modeRow, modeIndex("static"));
        link.change("tracking.mode", "normal");
        expect("camera changes the mode again", modeRow, modeIndex("normal"));

        click(modeRow, modeIndex("close_up"));
        expect("a click on Close-up", modeRow, modeIndex("close_up"));
        link.change("tracking.mode", "static");
        expect("camera changes the mode after a click", modeRow, modeIndex("static"));
        click(modeRow, modeIndex("normal"));
        expect("a click on Normal", modeRow, modeIndex("normal"));
        link.change("tracking.mode", "upper_body");
        expect("camera reads back another mode after the click", modeRow, modeIndex("upper_body"));

        // A click on the chip already shown sends nothing and keeps it
        click(modeRow, modeIndex("upper_body"));
        expect("a click on the shown chip", modeRow, modeIndex("upper_body"));

        // A plain ChipRow (camera picker, gimbal step): the same rule
        test.picked = 1;
        expect("plain row: value changes before any click", plainRow, 1);
        click(plainRow, 0);
        expect("plain row: a click", plainRow, 0);
        test.picked = 1;
        expect("plain row: value changes after a click", plainRow, 1);

        console.log("check-components: " + passed + " passed, " + failed + " failed");
        Qt.exit(failed === 0 && passed > 0 ? 0 : 1);
    }
}
