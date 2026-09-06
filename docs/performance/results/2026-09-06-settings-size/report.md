# PERF-020: Lesbarere Settings und Farbauswahl

Settings-Zeilen 16 statt 13,5 pt, Überschriften 28/14 pt, Panel maximal 440 statt
380 pt breit. Zeilen passen sich an schmalere Viewports an. Auswahlring mit 2 pt
transparentem Abstand zur Farbe. Expand previews unverändert, erklärender Tooltip.

Gezielter Viewport-/Kamera-/Settings-Test PASS ([tests.log](tests.log)),
Release-Build PASS ([build.log](build.log)). Kurzer Live-Check des signierten
Release in /Applications, Panel geöffnet und Screenshot visuell geprüft;
[Runner](live.py), [Rohdaten](live.json), private Aufnahme
/tmp/openplane-settings-size/after.png. Native AppKit-Oberfläche, kein Storybook.
Farbvergleich im Screenshot: freier Canvas und Mitte des ausgewählten Orange-Felds
beide RGBA (168,122,86,255), inklusive Screenshot-Farbprofil. Quellfarben identisch.
Preferences wiederhergestellt. [Identität](environment.json), [Fix](fix.diff).

Idle-/Aktions-/zusätzliche CPU und kalibrierte Latenz-/Framezeiten nicht gemessen.
P13 Ressourcenvergleich zur vorherigen Tab-Wrap-Version und volle Variantenprüfung
NOT RUN: scheduled overnight (2026-09-07 03:00 Berlin). Fehlende Messbeobachter
BLOCKED, [PERF-001/003/007/020](../../backlog.md). Keine volle Performancefreigabe.
