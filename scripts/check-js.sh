#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Run the tests of the widget's JavaScript modules (lib/*.mjs) twice: in node, and in the QML
# engine that the shell runs them in (the Qt 6 `qml` tool, offscreen). Both runs must pass and
# must count the same number of tests. Neither run is ever skipped.
#
# Run it before every pull request:  scripts/check-js.sh
#
# The Qt 6 `qml` tool is looked up like check-qml.sh looks up its tools: $OBSBOT_QT6_DIR, the
# directories qtpaths6 reports, then /usr/lib/qt6 and /usr/lib64/qt6.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

die() {
	echo "check-js: $*" >&2
	exit 2
}

candidate_dirs() {
	local root
	if [ -n "${OBSBOT_QT6_DIR:-}" ]; then
		printf '%s\n' "$OBSBOT_QT6_DIR" "$OBSBOT_QT6_DIR/bin"
		return
	fi
	if command -v qtpaths6 >/dev/null 2>&1; then
		qtpaths6 --query QT_INSTALL_BINS 2>/dev/null || true
	fi
	for root in /usr/lib/qt6 /usr/lib64/qt6; do
		printf '%s\n' "$root/bin"
	done
}

find_qml() {
	local dir
	while IFS= read -r dir; do
		if [ -n "$dir" ] && [ -x "$dir/qml" ] && [ -f "$dir/qml" ] &&
			"$dir/qml" --version 2>&1 | grep -q -E ' 6\.[0-9]+'; then
			printf '%s\n' "$dir/qml"
			return 0
		fi
	done < <(candidate_dirs)
	return 1
}

command -v node >/dev/null 2>&1 || die "node not found. Install Node.js 20 or newer."
qml=$(find_qml) || die "qml (Qt 6) not found. Install the Qt 6 declarative tools, or set OBSBOT_QT6_DIR."

shopt -s nullglob
tests=("$repo"/tests/*.test.mjs)
[ "${#tests[@]}" -gt 0 ] || die "no tests/*.test.mjs found"

echo "check-js: node $(node --version)"
node_out=$(node "$repo/tests/run.mjs" "${tests[@]}") || {
	printf '%s\n' "$node_out"
	die "node: tests failed"
}
printf '%s\n' "$node_out"
node_summary=$(printf '%s\n' "$node_out" | tail -n 1)

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# One module that imports every test module and runs them with the same harness as node
{
	i=0
	for f in "${tests[@]}"; do
		printf 'import * as t%d from "file://%s";\n' "$i" "$f"
		i=$((i + 1))
	done
	printf 'import { runAll } from "file://%s/tests/harness.mjs";\n' "$repo"
	printf 'export function run() {\n    return runAll({\n'
	i=0
	for f in "${tests[@]}"; do
		printf '        "%s": t%d,\n' "$(basename "$f")" "$i"
		i=$((i + 1))
	done
	printf '    });\n}\n'
} >"$tmp/all.mjs"

cat >"$tmp/Run.qml" <<'EOF'
import QtQml
import "all.mjs" as All

QtObject {
    Component.onCompleted: {
        const result = All.run();
        for (const line of result.lines)
            console.log("check-js:", line);
        Qt.exit(result.failed === 0 && result.passed > 0 ? 0 : 1);
    }
}
EOF

echo "check-js: qml ($qml)"
status=0
qml_out=$(QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 timeout 120 "$qml" "$tmp/Run.qml" 2>&1) || status=$?
printf '%s\n' "$qml_out" | grep -F 'check-js:' || true
[ "$status" -eq 0 ] || {
	printf '%s\n' "$qml_out" >&2
	die "qml: tests failed or did not load (exit $status)"
}
printf '%s\n' "$qml_out" | grep -q -F "check-js: $node_summary" ||
	die "qml ran another number of tests than node ($node_summary)"

echo "check-js: ok ($node_summary in node and in qml)"
