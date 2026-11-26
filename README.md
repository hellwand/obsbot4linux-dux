# obsbot4linux-dux

Dux (DankMaterialShell) bar widget and desktop preview for OBSBOT webcams, the desktop
frontend of [obsbot4linux](https://github.com/hellwand/obsbot4linux). Formerly `dms-obsbot-control`.

Install obsbot4linux 1.0 or newer first: the commands for each distribution are on the
[project page](https://hellwand.github.io/obsbot4linux/#install).

![Popout with the preview off](assets/screenshot.png)

## Supported cameras

The widget supports every camera that
[obsbot4linux supports](https://github.com/hellwand/obsbot4linux#supported-cameras).
It takes the camera's name and video device from obsbot4linux, and its controls follow
each camera's description: a control shows only when the camera offers that setting, and
its values, bounds, step and unit come from the description, so a camera with other
tracking modes or ranges shows its own. A card without any such setting stays hidden. A
value the widget has no name for is shown as text.

When obsbot4linux lists more than one camera, the popout header and the desktop widget
have a camera picker. A camera obsbot4linux marks as **untested** is controlled as usual
and carries the mark "untested". An
**unsupported** camera is listed with the mark "unsupported" and gets no controls; the
widget shows how to report it (`obsbot4linux devices --report`).

The popout is 920 px wide (at most 90 % of the screen width and at least 720 px; the left column takes 55 %, so the preview is larger). The left column is always there: Preview and Framing, so you can
watch the picture while changing settings. The right column is a tab bar with three tabs:
Tracking (Tracking, Zone, Presets), Picture (Picture, Image) and Device (Camera, Sleep, Audio,
Gestures, Factory reset). The tab area is as high as the tallest tab, so the popout does
not jump when switching; the last selected tab is remembered (`lastTab`). Collapsible
cards start closed, one open per tab, and a closed card lists its settings under the title.

**Arrange cards:** the edit (pencil) button in the header switches the popout into arrange
mode (it then reads as a check mark: click it to finish). Cards fold up and show a
handle at the right of the title; drag a card by its handle within its tab, or drop it on
another tab's button to move it to the end of that tab; a line shows where it will land.
Preview and Framing stay in the left column. Nothing can be dragged outside this
mode. "Reset layout" restores the default order. The order is saved per tab as
card ids in `cardTabs` (plugin settings), hidden and unsupported cards keep their
place in it, and cards that are not in the saved list join their default tab at the end.
An order saved by 0.16.0 or older (`cardOrderLeft`, `cardOrderRight`) is migrated: each card
goes to its default tab, ordered by its place in the old column.

- header: OBSBOT Control, the camera model and its state, a spinner while a
  command is in flight, Awake switch
- preview frame (16:9, Qt Multimedia at 720p): live picture while the preview
  runs (no other app can use the camera meanwhile; it stops when the popout
  closes), otherwise a hint with one action: Start preview (also while the
  camera sleeps: opening the stream wakes it), or
  Retry when the camera or obsbot4linux can't be reached
- tracking: AI mode, speed, tracked hand, hand
  return position (return here, go, clear), follow new targets (with zone tracking on
  the camera keeps tracking and takes the next person after the target leaves the
  area); "searching" in the status while it has lost
  its target; optionally the tracked target's box over the preview (popout and
  desktop widget)
- framing: pan/tilt d-pad with live pose and a 5°/1° step switch, center, zoom beside it; the left and
  right arrows follow the picture (flipped while mirror is on); an arrow sends only the move
  and leaves the tracking mode as it is; "Use current pose as start pose" and "Go to start pose"
  (the pose the camera takes at power-on), with the stored start pose shown when obsbot4linux
  reports it, and "Start mode" chips for the tracking mode stored with it
- presets: as many slots as the camera has, with name and pose; Recall, Save current pose
  (sends no name; a preset without one shows "(unnamed)" here only), Rename and Delete (two-click confirmation); a note while zone tracking follows new targets, because a
  recall makes the next zone return end in Static
- zone: zone tracking on/off, the area (pan and tilt range,
  "Full area"), the return position with "Return here" (current pose) and "Go to return
  position", all read back from the camera. Leaving the area stops tracking (Static, back to the return
  position) unless "Follow new targets" is on, then the camera waits for the next person
  Zone views: the camera's named poses with Go, Rename, Delete and "Save current
  pose as view"; in a tracking mode Go only applies the zoom, in Static the full pose
- hand tracking (Tracking card, while Hand is the mode): area sliders, pan and tilt
  switches, return time and a gimbal switch (the camera cannot report it, the switch shows
  "not known" until it is set here)
- picture: HDR, exposure Auto / Manual and metering Face / Global; exposure time is greyed out,
  with the reason, until the exposure is manual
- camera: field of view, status LED brightness and LED blink (the camera cannot report it, the switch shows "not known" until it is set here), mirror, invert; read-only firmware, anti-flicker, frame rate, digital zoom
- sleep: auto-sleep (a switch and its time) and the picture while asleep; tracking mode at power-on, stored in the camera (the camera applies it when it is powered on, not when it wakes from sleep); the camera ignores a stored wake-up zoom, so it is shown only in the Camera card
- image adjustments: brightness, contrast, saturation, sharpness, backlight
  compensation, reset to defaults (the camera's own defaults of these sliders, in one request)
- audio: noise reduction, pickup distance, microphone volume, automatic gain, microphone while asleep
- gestures: gesture switches and zoom ratio
- factory reset with a two-click confirmation
- bar icon: videocam (accent) awake, videocam_off asleep, usb_off dimmed while
  unplugged (or hidden, see settings), a red dot while any application streams from the camera

Bar icon interactions:

| Input        | Action                                                                                 |
| ------------ | -------------------------------------------------------------------------------------- |
| Left click   | Open the popout                                                                        |
| Right click  | Wake / sleep the camera                                                                |
| Middle click | Tracking on/off: Static, and back to the last other mode (Normal Tracking if none yet) |
| Mouse wheel  | Zoom in / out by 0.1 per notch, within the camera's zoom range, while it is awake      |
| Hover        | Tooltip with the state, e.g. "Tiny 2 Lite · Awake · Static"                            |

On air: a red dot on the bar icon shows whenever an application streams from the
camera (a browser, OBS, ffmpeg, the widget's own preview). The tooltip and the
popout header add "On air: Chrome" and the like, the Control Center tile "On air".
This relies on obsbot4linux's detection of
[streaming applications](https://github.com/hellwand/obsbot4linux#streaming-applications),
which looks at processes that map the camera's capture buffers.

Control Center tile: the icon wakes or sleeps the camera, the subtitle shows its
state. A 4 × 4 tile shows the tracking modes and speed; the tile's detail page
also has the tracked hand.

Settings page: switches for "Mouse wheel zooms" and "Middle click toggles tracking"
(both on by default).
Right click is always sleep/wake. Further switches, all applied at once:

| Setting                                                                                                                                                                                                          | Key                                                                                                                                                                      | Default |
| ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | ------- |
| Hide the bar icon without a camera: follows the daemon's device list, no polling; the icon returns when the camera is plugged in again (off: the icon stays, dimmed)                                             | `hideWithoutCamera`                                                                                                                                                      | off     |
| Status text in the bar: Static / Tracking (or the name of another tracking mode) / Asleep / Offline (no camera, dimmed) / Pick camera / Unsupported next to the icon in a fixed-width slot, horizontal bars only | `statusTextInBar`                                                                                                                                                        | off     |
| Popout cards: Preview, Framing, Camera, Sleep, Tracking, Zone, Presets, Picture, Image, Audio, Gestures, Factory reset                                                                                           | `cardPreview`, `cardFraming`, `cardCamera`, `cardSleep`, `cardTracking`, `cardZone`, `cardPresets`, `cardPicture`, `cardImage`, `cardAudio`, `cardGestures`, `cardReset` | on      |

The card switches affect the popout only (not the bar icon actions or the Control
Center tile). A card the connected camera does not support stays hidden whatever its
switch says. Hidden cards close up; a tab without cards drops out of the tab bar, and if a whole column
(left, or all tabs) is empty the popout narrows from 920 px to the one column that is left.

## Desktop widget

The plugin also provides a desktop widget: add **OBSBOT Control** in Settings → Desktop
Widgets (it is listed next to the other desktop widgets) and place it like any other. Like the
popout it has one fixed layout, a single card with the controls arranged
around the picture:

- **Picture area** (640 × 360 on a normal screen, smaller on a narrow or short one, 16:9, top left): dark with the "Preview is off" hint and a **Start
  preview** button while the preview is off (also while the camera is asleep, the preview wakes it; Retry when
  the camera is not reachable); the live picture while it runs, with **Stop preview** on hover. Stopping frees the
  camera.
- **Right of the picture:** status with the camera state (Awake, Asleep, Offline) and the tracking
  mode, a red "On air" dot while another app reads the camera, the tracking mode chips and the
  tracking speed chips.
- **Below the picture:** zoom (slider and − / +) on the left, the presets saved in the camera in the
  middle (three equal slots in slot order, all in the same colour with no "active" mark, since the camera
  cannot report the active preset; an empty slot stays blank; long names are elided, the full name is the tooltip; a click recalls one) and **Sleep** / **Wake** at the right end
  (**Retry** when the camera is not reachable). Asleep and offline grey the other controls out.

The height follows the bottom row's content and is not saved; the width is fixed. The preview never
starts by itself: while it runs no other app can use the camera, and a small red dot in the
corner shows that.

- The preview keeps running until you close it, the camera goes to sleep or is unplugged,
  or the widget is unloaded (switched off or removed in Desktop Widgets, or the desktop
  is being edited). It does not stop when you merely look elsewhere.
- Only one preview runs at a time: starting it on the desktop switches the popout's
  preview off and the other way round (also for two desktop widgets, e.g. on two screens).
  The bar icon's red dot and "On air: preview" count the desktop preview too.
- The desktop widget has its own connection to the obsbot4linux daemon and its own camera picker.
- While the desktop is being edited the widget is inert (no buttons, no hover).

Camera access goes through [OBSBot4Linux](https://github.com/hellwand/obsbot4linux) 1.0: the widget
connects to the obsbot4linux daemon on its Unix socket (`$XDG_RUNTIME_DIR/obsbot4linux.sock`,
or the path in `OBSBOT4LINUX_SOCKET`), gets every state change from it (also changes made from
the CLI or by the camera itself) and sends each request the user makes, one at a time, nothing
chained to it. A value the widget sends shows at once and stays until the daemon answers. The
widget never starts, stops or restarts the daemon: without it the header and the preview frame
show the command that starts its socket; with a daemon older than 1.0 still running they say so.

## Install

Needs `obsbot4linux` 1.0 or newer on PATH (a 1.0.0 release candidate counts as 1.0.0); the
plugin checks this when it is enabled and refuses to activate with an older version or without
it (the camera itself does not have to be plugged in). Packages for Arch, Debian/Ubuntu,
Fedora/openSUSE and a plain tarball are on its
[releases page](https://github.com/hellwand/obsbot4linux/releases).

The widget talks to the obsbot4linux daemon, which systemd starts on demand through its user
socket. Enable the socket once:

```sh
systemctl --user enable --now obsbot4linux.socket
```

The widget runs no `obsbot4linux watch` process any more.

The live preview also needs `qt6-multimedia`; without it the preview frame says so and every
other control still works.

From the DMS plugin browser, or manually:

```sh
git clone https://github.com/hellwand/obsbot4linux-dux.git \
    ~/.config/dms/plugins/obsbot4linuxDux
dms ipc call plugins enable obsbot4linuxDux
```

Then add the `obsbot4linuxDux` widget to a bar in DMS settings.
After changing QML, run `dms restart` (`plugins reload` keeps cached components).
Before sending a change, run `scripts/check-qml.sh` (needs the Qt 6 tools; it compiles and lints every QML file).
CI runs it and shellcheck on every pull request into `develop` (or a `release/*` branch); a change lands there only after the pull request's `required` check is green.
Also run `scripts/check-js.sh` (needs Node.js 20 or newer and the Qt 6 `qml` tool): it runs the tests of the
JavaScript modules in `lib/` in node and in the QML engine. `scripts/check-components.sh` (the Qt 6 `qml`
tool) runs the tests of shared QML components in `tests/qml/` against stubs of the shell's components. `tests/fixtures/` is generated from an obsbot4linux
checkout with `node scripts/sync-fixtures.mjs <checkout>`; do not edit those files by hand.

## Update

```sh
dms plugins update obsbot4linuxDux
dms restart
```

`dms plugins update` follows this repository's `main`, which only ever points at a released
version; work happens on `develop`. Update the widget and obsbot4linux together: widget 1.0 needs
obsbot4linux 1.0 or newer, and a 0.x widget refuses obsbot4linux 1.0. After updating obsbot4linux,
restart its daemon (`systemctl --user restart obsbot4linux.service`) or log out and in again, so
that no daemon older than 1.0 keeps running. The restart only stops a daemon that systemd started;
one the 0.x widget started (`obsbot4linux watch`) keeps running until you log out and in again.

## Development

The code was written with Claude Code (AI) and reviewed and tested on a
Tiny 2 Lite.

## Releasing

1. Land a commit "Release X.Y.Z" on `develop` through a pull request: it sets `version` in
   `plugin.json` and turns the `## [Unreleased]` entries of `CHANGELOG.md` into a
   `## [X.Y.Z] - date` section.
2. Dry run: `gh workflow run release.yml --ref develop -f version=X.Y.Z`. It runs the checks,
   prints the release it would create and whether `main` can follow, and creates nothing. Do this
   before the tag: tags `v*` cannot be moved or deleted in this repository, so a tag on a bad
   release commit burns the version.
3. Push the signed tag `vX.Y.Z` on that commit. The Release workflow checks that the tag equals the
   `plugin.json` version, that the commit is on `develop` or a `release/*` branch and was green as
   a pull request, and that the section exists; then it creates the GitHub release, with that
   CHANGELOG section as notes, and marks the commit `released`. If a check fails, nothing is
   created.
4. Move `main`: `git push origin <commit>:main`. GitHub accepts it only for a fast-forward to a
   released commit.
5. A fix for an older line: branch `release/X.Y` from that line's newest tag, land the fix and
   "Release X.Y.Z" there through pull requests, then steps 2-4 with `--ref release/X.Y`. `main`
   follows only if it is still on that line (step 2 says which).

## License

GPL-3.0-or-later, see [LICENSE](LICENSE).
