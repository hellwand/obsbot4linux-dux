#!/usr/bin/env bash
# Check that every QML file of the widget compiles and lints.
#
# Run it before every pull request:  scripts/check-qml.sh
#
# 1. qmlcachegen compiles each *.qml. This is a hard fail: it catches what makes the shell
#    refuse to load a file at run time, such as a property-change handler defined twice.
# 2. qmllint then reports what is left. The categories that only complain that the shell's own
#    import tree is not available here are switched off.
#
# The Qt 6 tools are looked up in this order:
#   1. $OBSBOT_QT6_DIR (the Qt install directory, or its bin/ or libexec/ directory); when set,
#      nothing else is searched
#   2. the directories reported by qtpaths6 in PATH (QT_INSTALL_LIBEXECS and QT_INSTALL_BINS)
#   3. /usr/lib/qt6 and /usr/lib64/qt6
# The script fails when a tool is not found. It never skips a check.

set -eu

repo=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

die() {
	echo "check-qml: $*" >&2
	exit 2
}

# Print the candidate directories for the Qt 6 tools, one per line.
candidate_dirs() {
	local root
	if [ -n "${OBSBOT_QT6_DIR:-}" ]; then
		printf '%s\n' "$OBSBOT_QT6_DIR" "$OBSBOT_QT6_DIR/bin" "$OBSBOT_QT6_DIR/libexec"
		return
	fi
	if command -v qtpaths6 >/dev/null 2>&1; then
		qtpaths6 --query QT_INSTALL_LIBEXECS 2>/dev/null || true
		qtpaths6 --query QT_INSTALL_BINS 2>/dev/null || true
	fi
	for root in /usr/lib/qt6 /usr/lib64/qt6; do
		printf '%s\n' "$root" "$root/bin" "$root/libexec"
	done
}

# Print the path of the Qt 6 tool $1, or return 1.
find_tool() {
	local dir
	while IFS= read -r dir; do
		if [ -n "$dir" ] && [ -x "$dir/$1" ] && [ -f "$dir/$1" ]; then
			printf '%s\n' "$dir/$1"
			return 0
		fi
	done < <(candidate_dirs)
	return 1
}

qmlcachegen=$(find_tool qmlcachegen) ||
	die "qmlcachegen (Qt 6) not found. Install the Qt 6 declarative tools, or set OBSBOT_QT6_DIR to the Qt 6 install directory."
qmllint=$(find_tool qmllint) ||
	die "qmllint (Qt 6) not found. Install the Qt 6 declarative tools, or set OBSBOT_QT6_DIR to the Qt 6 install directory."

# A Qt 5 tool in PATH would accept other options and judge QML by other rules.
for tool in "$qmlcachegen" "$qmllint"; do
	"$tool" --version 2>&1 | grep -q -E ' 6\.[0-9]+' ||
		die "$tool is not a Qt 6 tool"
done

shopt -s nullglob
files=("$repo"/*.qml)
[ "${#files[@]}" -gt 0 ] || die "no .qml files found in $repo"

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

echo "check-qml: qmlcachegen ($qmlcachegen)"
failed=0
for f in "${files[@]}"; do
	name=$(basename "$f")
	if ! "$qmlcachegen" --only-bytecode --resource-path "/$name" -o "$tmp/$name.cpp" "$f" 2>"$tmp/err"; then
		echo "FAIL $name" >&2
		cat "$tmp/err" >&2
		failed=1
	fi
done
[ "$failed" -eq 0 ] || die "qmlcachegen failed (see above)"

echo "check-qml: qmllint ($qmllint)"
"$qmllint" -W 0 \
	--unqualified disable --import disable --unresolved-type disable \
	--missing-property disable --id-shadows-member info --incompatible-type info \
	"${files[@]}" || die "qmllint reported problems (see above)"

echo "check-qml: ok (${#files[@]} files)"
