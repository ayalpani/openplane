# Approved desktop navigation reference

Captured on **2026-09-05** from the desktop whose navigation the user explicitly
approved. This is a fixed regression baseline: **22 nodes from 21 apps**, with
14 open windows and 8 closed app cards. Paper contributes two separate windows.

[DesktopNavigationTests.swift](../OpenPlaneTests/DesktopNavigationTests.swift)
stores the exact captured centers and sizes, plus the expected result for all
**88 node/direction combinations**. It also checks a 31-step walk through every
node and repeats the full neighbor matrix with three camera configurations and
three candidate orders.

The fixture is self-contained. It does not require these apps to be installed,
does not read the user's current desktop, and contains no screenshots or document
contents. Stable fixture IDs replace transient macOS window IDs. Closed cards
use the captured 1728 × 1117 fullview dimensions; open windows retain their actual
persisted slot sizes, including the narrow QuickTime preview.

## Expected destinations

“Stay” means that no target exists in that direction. The selection stays at its
current node; there is no wrapping. Left followed by Right need not be an inverse
in an irregular layout; each move is evaluated from its current source.

| Source | State | Left | Right | Up | Down |
| --- | --- | --- | --- | --- | --- |
| OpenCode | Open | iTerm2 / zsh | Blender | ChatGPT | Google Chrome |
| Claude | Open | App Store | Ollama | Stay | ChatGPT |
| Activity Monitor | Open | WhatsApp | iTerm2 / zsh | Surfshark | QuickTime Player |
| App Store | Open | Slack | Claude | Stay | Surfshark |
| Music | Open | Google Chrome | Stay | Blender | AltTab |
| QuickTime Player | Open | Paper 1 | Google Chrome | Activity Monitor | LibreOffice |
| Finder | Closed | Paper 2 | Wispr Flow | iTerm2 / zsh | LibreOffice |
| Ollama | Closed | ChatGPT | Stay | Claude | Blender |
| Wispr Flow | Closed | Finder | AltTab | Google Chrome | LibreOffice |
| Google Chrome | Open | QuickTime Player | Music | OpenCode | Wispr Flow |
| iTerm2 / zsh | Open | Activity Monitor | OpenCode | BetterTouchTool | Finder |
| BetterTouchTool | Closed | Surfshark | ChatGPT | App Store | iTerm2 / zsh |
| AltTab | Closed | Wispr Flow | Stay | Music | LibreOffice |
| ChatGPT | Open | BetterTouchTool | Ollama | Claude | OpenCode |
| Surfshark | Closed | Slack | BetterTouchTool | App Store | Activity Monitor |
| Telegram | Open | Stay | Surfshark | Slack | WhatsApp |
| Slack | Open | Stay | Surfshark | App Store | Telegram |
| Paper 1 | Open | Stay | QuickTime Player | WhatsApp | Paper 2 |
| Paper 2 | Open | Paper 1 | QuickTime Player | Paper 1 | LibreOffice |
| WhatsApp | Closed | Stay | Activity Monitor | Telegram | Paper 1 |
| Blender | Open | OpenCode | Stay | Ollama | Music |
| LibreOffice | Closed | Paper 2 | Finder | QuickTime Player | Stay |

## Run and maintain

Run just this scenario, with a separate test-host preferences domain so the
user's running desktop is not used as test data:

```sh
xcodebuild -project OpenPlane.xcodeproj -scheme OpenPlane -configuration Debug \
  -destination 'platform=macOS' \
  PRODUCT_BUNDLE_IDENTIFIER=com.yalpani.openplane.navigation-tests \
  -only-testing:OpenPlaneTests/DesktopNavigationTests test
```

Expected destinations are deliberately written down, not computed by the
implementation during tests. If they change, investigate the regression.
Only update the baseline when the desired navigation behavior intentionally
changes; do not regenerate expectations merely to make a failing test green.

This scenario locks down spatial neighbor selection and chained routes.
Keyboard event routing, animation timing, app activation, and rendering still
need the installed-app checks described in the [README](../README.md).

