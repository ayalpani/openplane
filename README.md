# OpenPlane

OpenPlane is a native macOS proof of concept that turns open windows into a
spatial, zoomable desktop. It started on **September 2, 2026** as an exploration
of a simple idea: apps should keep a memorable place on an infinite plane
without replacing the macOS window system.

OpenPlane discovers the windows in the current Space, presents them as movable
live previews, and transitions seamlessly into the real app when a window is
selected. Spotlight, the Dock, Finder, and the regular macOS apps remain in
charge of launching and running software.

## Proof of concept

- Pan with two fingers and pinch to zoom.
- Use the arrow keys to move between windows and Return to open one.
- Start typing to search visible windows.
- Arrange windows individually or with marquee group selection.
- Use the navigator panel for history, minimap, saved views, and canvas color.
- Return to OpenPlane through its Dock or app-switcher entry, the configurable
  Command-Tab shortcut, or Control-Option-Space.

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

## Current scope

The proof of concept targets macOS 26, the main display, and the current Space.
It is intentionally unsandboxed because controlling other applications' windows
requires macOS Accessibility access. Multi-display layouts, multiple Spaces,
persistent window arrangements, and a spatial app launcher are future work.
