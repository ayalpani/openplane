# OpenPlane

Licensed under the [MIT License](LICENSE). The Lucide-derived app icon is
covered by the ISC license; see [third-party notices](THIRD_PARTY_NOTICES.md).

OpenPlane is a native macOS proof of concept that turns open windows into a
spatial, zoomable desktop. It started on **September 2, 2026** as an exploration
of a simple idea: apps should keep a memorable place on an infinite plane
without replacing the macOS window system.

OpenPlane discovers the windows in the current Space, presents them as movable
live previews, and transitions seamlessly into the real app when a window is
selected. Spotlight, the Dock, Finder, and the regular macOS apps remain in
charge of launching and running software.

## Proof of concept

- Pan with two fingers and pinch to zoom. Press Shift-Down to zoom in and
  Shift-Up to zoom out.
- Use the arrow keys to move spatially between windows and closed app places;
  the highlighted target stays centered, and Return opens it.
- Press Backspace to close the selected window. If it is the app’s confirmed
  last window, quit the app instead. Minimized windows count too. Backspace still
  deletes text in search and text fields and does nothing on closed app places.
- Start typing to search open windows and closed app cards. Closed cards always
  keep their normal appearance; only nonmatching open windows dim. Up/Down selects a result and
  Return opens its window or starts its closed app. An empty search dims nothing.
- Arrange windows and closed cards individually or with marquee group selection.
- Shift-click or Shift-Return toggles an item in the green group selection;
  arrow keys move the current highlight without changing the group. Drag a
  member or the space between members to move the group without opening apps.
  Resize the dotted selection frame to change its members; releasing the mouse
  fits the frame tightly around the selected items again.
- The selection frame encloses each member's visible border, icon, and visible
  title, with a uniform 12-point gap on all sides at every zoom level. Soft
  shadows are excluded from these bounds. Edges and corners remain draggable
  without visible handles.
- Drag an app window to manifest its place. Positions persist independently for
  each OpenPlane desktop, and a closed app remains as a launchable card.
- Click and release a window or closed app card to activate it; dragging moves
  it without activating it.
- Use the navigator panel for history, minimap, saved views, and canvas color.
- Multiple desktops appear as name tabs in the top nudge. Click a name to switch;
  the active name has a subtle background and remains directly editable. Long tab
  rows scroll horizontally. A desktop change fades out and in over 0.28 seconds,
  with no camera travel; each desktop retains its own arrangement and zoom.
- Tab cycles to the next desktop; Shift-Tab cycles backward, wrapping at either
  end. These shortcuts only apply in Plane mode, outside search and title editing.
- Return to OpenPlane through its Dock or app-switcher entry, the configurable
  Command-Tab shortcut, or Control-Option-Space.

## Optional chronological layout

Settings → **View mode → Chronological** arranges individual windows vertically
by their last actual use. The existing **Canvas** mode and its saved desktops,
positions and cameras remain separate and intact. Both modes retain zoom and
canvas gestures. Up/Down follows the chronological window list; Return opens the
selected window. Moving a card is temporary in Chronological: reopening the
overview or a structural window change restores the vertical arrangement.

With **Use ⌘Tab for OpenPlane** enabled, Command-Tab simply opens the overview
in the selected mode. Repeating it while the overview is visible keeps the
selection; releasing Command never activates a window. Use arrows to navigate
and Return or a click to open the selected window. Window history starts with
the OpenPlane process.

**All apps** at the end opens a searchable installed-app catalog; its back arrow
returns to the window list. Window context menus distinguish **Close Window**
from **Quit App**. Backspace closes one window first and quits only when a full
application-window check confirms that it is the last window.

## Run

OpenPlane uses automatic Apple Development signing with the configured Personal
Team so macOS can retain Screen Recording and Accessibility approval across
normal rebuilds.

1. Build the **OpenPlane** scheme in Release configuration.
2. Copy `OpenPlane.app` to `/Applications` and launch that installed copy.
3. Grant Screen Recording and Accessibility access when prompted. Keep using
   the same installed bundle after granting access.
4. Use Spotlight or the Dock as usual. Press **Control-Option-Space** to return
   to the canvas.

Xcode can also run the Debug build directly. Reinstall the Release build when
intentionally testing the copy in `/Applications`.

## Navigation regression checks

Arrow navigation prefers targets in the same row or column. Diagonal targets
remain reachable when no aligned target exists. A sideways target must advance
by at least half the smaller card's dimension in the requested direction to
qualify as a diagonal; small placement offsets must not change its direction.
Touching edges alone do not count as row/column alignment. There is no wrapping.
Windows and closed cards use the same selection rule.

Run the regression suite with:

```sh
xcodebuild -project OpenPlane.xcodeproj -scheme OpenPlane -configuration Debug \
  -destination 'platform=macOS' -parallel-testing-enabled NO \
  PRODUCT_BUNDLE_IDENTIFIER=com.yalpani.openplane.tests test
```

The view fixtures share saved preferences, so run them serially in a separate
preferences domain to keep tests independent of the installed app's desktops.

`CanvasMathTests` includes the captured Finder → Down → LibreOffice layout and
the earlier OpenCode → Left → zsh regression. A matrix checks 14 layouts in all
four directions, mirrored, at three scales, and in both candidate orders:
near-sideways offsets, diagonal fallback, aligned/nearest targets, mixed sizes,
overlaps, touching edges, ties, and empty boundaries. Additional cases cover
mixed window/placeholder IDs and camera centering without changing zoom.

`DesktopNavigationTests` freezes the full desktop approved on September 5, 2026:
22 nodes from 21 apps, all 88 directional choices, and a 31-step walk visiting
every node. It also repeats the full matrix with different camera settings and
candidate orders. The [reference scenario](docs/navigation-reference.md) lists
every expected destination. These expectations are fixed, not generated from
the implementation at test time.

After installing a navigation change, also check the actual key path: highlight
the closed Finder card, press Down, and verify LibreOffice becomes highlighted
and centered. Right from Finder should still select Wispr Flow; Down from the
bottommost card should leave the selection and camera unchanged. Arrow keys
must not launch either app.

`CanvasSelectionTests` sends mouse and keyboard events through the actual canvas
handlers: single/multiple/toggled-off selection, Shift-Return (including keypad
Return and key repeat), closed-card marquee, resize-and-snap, member/background
drag, persisted closed homes, refresh, and plain-click activation. Geometry tests
also cover mixed open/closed IDs at multiple zoom levels. After installing a
selection change, verify a mixed open-window/closed-card group in the real app,
including Shift-click, Shift-Return, frame resizing, and dragging from either kind
of member without launching it.

`DesktopTabTests` exercises actual tab clicks, Tab/Shift-Tab cycling and text-entry guards,
both halves of the fade, independent
camera restoration, rapid switching, adding a desktop, renaming, scrolling a
12-desktop row, and drawing the tabs and debug overlay at each transition stage.

## Performance testing is part of development

Every new or changed user-visible function needs a live-UI performance case and
measured verification on the installed signed Release app. Unit tests alone are
not sufficient. Missing tooling or measurements must be reported as blocked or
not run, never as a pass. Documentation-only changes may be marked not applicable.

- [Mandatory performance policy](docs/performance/policy.md): measurement conditions,
  idle/action CPU, latency, cold/warm states, repeated comparisons and completion gates.
- [Live runbooks](docs/performance/runbooks.md): navigation, zoom, app activation and
  launch, OpenPlane startup, desktops, dragging/groups, search and all other current
  function families. New functionality must extend this catalog.
- [Result template](docs/performance/report-template.md): raw evidence, interpretation,
  limitations and follow-up tasks.
- [Performance backlog and agent workflow](docs/performance/backlog.md): required
  tooling and the future measure → interpret → fix → retest cycle.

The original arrow-navigation CPU burst and a newer bounded live pilot are
partly automated. The pilot executes subsets of seven families and records
missing coverage. These runbooks do not imply full verification or automatic
implementation by an agent. Historical measurements remain below.

## Human review workspace

[Review Desk](review-desk/README.md) turns actual test evidence into proposals
with accept/reject/defer/investigate decisions, a persistent audit trail and a
local handoff queue. Run `python3 review-desk/server.py` and open
`http://127.0.0.1:8766`. The live pilot covers measured subsets of seven families;
the dashboard exposes all missing coverage and never treats a partial run as a
full pass. Accepting work does not start an implementation agent.

## Canvas rendering

Cards are retained Core Animation layers under a shared camera transform.
Panning reuses their contents; preview updates and selection affect the relevant
card layers. The background grid and fixed controls are separate. See the
[GPU navigation measurements](docs/gpu-navigation-performance.md) for live test
results and remaining limitations.

## Current scope

The proof of concept targets macOS 26, the main display, and the current Space.
It is intentionally unsandboxed because controlling other applications' windows
requires macOS Accessibility access. Multi-display layouts, multiple Spaces,
cloud synchronization, and automatic layout cleanup are future work.

Browser preview filtering and its Settings toggle have been removed. Normal and
private browser windows are displayed regardless of the legacy preference.
Browser previews remain memory-only and are not restored from disk cache.

View mode also offers **Overview**: separate windows are grouped by application
and cascaded with visible titles, then fitted together on the available screen.
Up/Down traverses a group; Left/Right moves between groups; Tab traverses windows.
Return or click activates the selected window. Browser tabs inside one native
window are not separate items. Privacy protection applies unchanged.

**Camera follows selection** is saved per mode. It defaults on in Canvas and
Chronological, off in Overview. Explicit Fit all, entering an arranged view and
layout changes still position the camera. Canvas placement/camera persistence is
independent of both automatic layouts.

### Overview input

Settings → Open overview records a global modified keyboard shortcut; Reset
restores Control–Option–Space. Native registration reports unavailable bindings.
No external mapping tool is required. Optional “Swipe up opens Overview” uses
macOS swipe events and is experimental: first free the Mission Control gesture
in macOS Trackpad settings. Physical three-finger delivery is not yet verified.

### View presets and prompt experiment

The floating Views control switches Canvas, Chronological, Overview and All apps
without opening Settings. View name and Canvas can be moved are saved separately
for each view. Overview defaults to a fixed camera; All apps defaults to bounded
vertical scrolling without free horizontal panning. Zoom remains available.

Settings → View prompt generates an OpenAI suggestion for name, layout, camera
movement and following. Apply suggestion explicitly adopts it; the prototype
selects/configures one of the four existing views rather than generating code or
creating arbitrary extra layouts. Only prompt/schema are sent, never window data.
Uses gpt-5-mini and OPENAI_API_KEY (or openai_api_key) inherited by the app process,
or a key entered into the secure field for that session. Keys are not persisted;
a normal Finder launch may not inherit a shell environment. Prompt text is saved
per view. The API response is requested with store=false.

Views now occupy the former desktop-tab area: Canvas, Recent, Overview and All apps. Tab / Shift-Tab cycle views while the overview has focus (outside text editing/search). Fresh installs default to Overview. Legacy saved desktop arrangements are retained internally.


### Keyboard-first interface

Every control must have a keyboard path and visible focus. Within OpenPlane,
⌘F focuses Search apps and ⌘, opens/closes Settings. In Settings, Tab/Shift-Tab
traverse enabled controls on the current page; Space/Return activates buttons;
Up/Down traverse controls when not editing text. Escape goes back one Settings
level, then closes the sidebar. Sidebar input must never navigate the underlying
Canvas. This does not require macOS Keyboard Navigation to be enabled.
