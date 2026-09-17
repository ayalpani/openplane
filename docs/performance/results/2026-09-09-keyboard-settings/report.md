# Keyboard-first Settings

2026-09-09. Signed Release installed and signature verified.

⌘F focuses Search apps; ⌘, toggles Settings. Top-right Settings text replaces
icon and shares ViewModeControl.labelFont. Settings owns Tab/Shift-Tab,
Space/Return and non-editor Up/Down. Visible blue focus outline, automatic scroll
and current-page traversal include palette/buttons/switches/text fields; disabled
and hidden controls excluded. Escape goes back then closes. Input routing protects
underlying Canvas, including while editing. Keyboard-first contract in README.

PASS: 13 Overview tests. Native keyboard test opens Settings, enters Views/detail,
focuses editable name, tabs forward/back, escapes hierarchy, focuses search from
Settings and toggles sidebar closed. Shared existing selection/layout tests pass.
PASS: synthetic native screenshot reviewed after correcting top navigation
background position. No user window images captured or viewed.
PASS: live AX-only ⌘F + query, Escape clears; ⌘, opens sidebar with Views focused.
Further live Return traversal interrupted by user activity; input stopped without
clearing the user's new query. No test settings changed. Deeper keyboard traversal
validated in native automated fixture, not claimed as completed live.

Performance: baseline binary f6dd43e39eef166448dd594aa3afba902298e33196c06a5135e2ac96c4a8a786;
source baseline patch preserved. Candidate/source hashes in identity.json.
Idle/action/additional CPU and latency NOT RUN: scheduled overnight for P07/P20,
full variants and core smoke. No performance gain claimed. Controlled live fixture
and calibrated observer BLOCKED under PERF-025 (../../backlog.md).
