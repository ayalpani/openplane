# PERF-020: Sofortige Auswahl als einziges Verhalten

Nutzerentscheidung: Animation unterscheidet sich bei 180 ms plus Kamerabewegung
zu wenig für eine eigene Einstellung. Schalter, Menüaktion, Zustand und verzögerte
Mathematik entfernt. Alter Preferences-Key wird beim Start entfernt; Auswahl beginnt
immer sofort. Dauer und Kamerabewegung bleiben gleich.

Zwei gezielte Tests PASS ([tests.log](tests.log)): sofortige Titel-/Rahmenphase und
Settings-Tastatursteuerung. [Build](build.log) PASS. Kurzer Live-Check des signierten
Release /Applications: Settings ohne Schalter, Rechts/Links-Navigation bei offenem
Panel. [Runner](live.py), [Rohdaten](live.json), private Aufnahme
/tmp/openplane-selection-fixed/after.png. Native AppKit, kein Storybook.
Preferences vor Relaunch restauriert; obsoleter Key wird erwartungsgemäß entfernt.
[Identität](environment.json), [Quellstand](source.diff).

Baseline: vorheriger Settings-Pointer-Build, Sofortmodus bereits verfügbar.
Idle-/Aktions-/zusätzliche CPU und kalibrierte Latenz/Framezeiten nicht gemessen.
P04/P13 voller Baselinevergleich und Variantenprüfung NOT RUN: scheduled overnight,
2026-09-07 03:00 Berlin. Fehlende Beobachter BLOCKED
[PERF-001/003/007/020](../../backlog.md). Keine volle Performancefreigabe.
