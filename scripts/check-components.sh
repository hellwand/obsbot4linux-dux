#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Run the tests of the widget's shared QML components (tests/qml/*.qml) in the Qt 6 `qml` tool,
# offscreen, against stubs of the shell's components (tests/qml/stubs). Each test exits 0 only
# when every check in it passed. No test is ever skipped.
#
# Run it before every pull request:  scripts/check-components.sh
#
# The Qt 6 `qml` tool is looked up like check-js.sh looks it up: $OBSBOT_QT6_DIR, the
# directories qtpaths6 reports, then /usr/lib/qt6 and /usr/lib64/qt6.

set -euo pipefail

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

die() {
	echo "check-components: $*" >&2
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
			QT_QPA_PLATFORM=offscreen "$dir/qml" --version 2>&1 | grep -q -E ' 6\.[0-9]+'; then
			printf '%s\n' "$dir/qml"
			return 0
		fi
	done < <(candidate_dirs)
	return 1
}

qml=$(find_qml) || die "qml (Qt 6) not found. Install the Qt 6 declarative tools, or set OBSBOT_QT6_DIR."

shopt -s nullglob
tests=("$repo"/tests/qml/*.qml)
[ "${#tests[@]}" -gt 0 ] || die "no tests/qml/*.qml found"

echo "check-components: qml ($qml)"
failed=0
for t in "${tests[@]}"; do
	name=${t#"$repo"/}
	status=0
	out=$(QT_QPA_PLATFORM=offscreen QT_FORCE_STDERR_LOGGING=1 timeout 60 "$qml" -I "$repo/tests/qml/stubs" "$t" 2>&1) || status=$?
	if [ "$status" -eq 0 ] && printf '%s\n' "$out" | grep -q -E 'check-components: [1-9][0-9]* passed, 0 failed'; then
		echo "ok   $name: $(printf '%s\n' "$out" | grep -o -E '[0-9]+ passed' | tail -n 1)"
	else
		echo "FAIL $name (exit $status)" >&2
		printf '%s\n' "$out" >&2
		failed=1
	fi
done
[ "$failed" -eq 0 ] || die "component tests failed (see above)"
echo "check-components: ok (${#tests[@]} files)"
