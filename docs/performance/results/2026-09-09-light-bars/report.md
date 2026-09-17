# Light translucent search and position bars

2026-09-09. Styling only: white alpha .58, black primary alpha .88 and secondary
.72; weaker shadow. Dark template history/clear icons, dark search caret and
light text-field appearance. Positions and mini-map styling unchanged.

PASS: two targeted native keyboard/search and grouped-renderer tests. Current
synthetic rendering reviewed. Contrast calculation on black/white underlays:
primary 6.18–16.56:1, secondary 4.76–9.23:1 (ideal sRGB alpha model, not a live
pixel measurement; contrast.json). Signed Release build/install/signature PASS.
Live AX: ⌘F focuses search, query entered, Escape clears; app/caption/shortcut
controls present. No user window screenshots captured or viewed. Tests cleaned up.

Baseline binary 2eff33af36d2c6622adc5e08bc1ed8356d4920a4d94cae0b405cca40991827d9.
Candidate/source identity recorded. Full P07/P20 variants/core smoke and paired
idle/action/additional CPU/latency NOT RUN: scheduled overnight. Calibrated
observer BLOCKED under PERF-025 (../../backlog.md). No performance gain claimed.
