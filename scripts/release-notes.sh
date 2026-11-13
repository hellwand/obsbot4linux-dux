#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Release guard and release notes: prints the CHANGELOG.md section of a release. Fails, with the
# reason, unless TAG is vX.Y.Z, plugin.json has that version at SHA, and CHANGELOG.md at SHA has a
# non-empty "## [X.Y.Z]" (or "## X.Y.Z") section. The section text, without surrounding blank
# lines, is the release notes.
#
# Usage: release-notes.sh SHA TAG       (reads plugin.json and CHANGELOG.md from the commit SHA)
set -euo pipefail
sha=${1:?usage: release-notes.sh SHA TAG}
tag=${2:?usage: release-notes.sh SHA TAG}
fail() {
	echo "release refused: $*" >&2
	exit 1
}

[[ $tag =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]] || fail "$tag is not a tag of the form vX.Y.Z"
ver=${tag#v}
git rev-parse --verify --quiet "$sha^{commit}" >/dev/null || fail "$sha is not a commit"

have=$(git show "$sha:plugin.json" | jq -r '.version // empty') || fail "cannot read plugin.json at $sha"
[ "$have" = "$ver" ] || fail "plugin.json has version \"$have\" at $sha, the tag is $tag"

notes=$(git show "$sha:CHANGELOG.md" | awk -v v="$ver" '
	/^## / { on = ($2 == v || $2 == "[" v "]"); next }
	on
' | sed -e '/./,$!d' | sed -e ':a' -e '/^\n*$/{$d;N;ba' -e '}')
[ -n "${notes//[[:space:]]/}" ] || fail "CHANGELOG.md has no non-empty section for $ver at $sha"
printf '%s\n' "$notes"
