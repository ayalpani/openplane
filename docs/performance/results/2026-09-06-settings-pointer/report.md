# PERF-020: Settings-Mausgrenze

Canvas bleibt Tastatur-Responder und kann Mausbewegungen außerhalb seines Viewports
erhalten. updateHover prüfte bisher trotzdem Karten/Gruppen/Resize-Griffe außerhalb
der sichtbaren Fläche. Gemeinsamer Hover-Einstieg prüft jetzt bounds und setzt dort
Hoverzustand und Cursor zurück. Hit-Test, neue Mausaktionen, Scroll-/Magnify-Einstieg
und Kontextmenü beachten dieselbe Flächengrenze. Laufende Drag-Gesten bleiben intakt.
Settings registriert den normalen Pfeilcursor. Tastaturpfade unverändert.

Zwei gezielte Tests PASS: externe Mausbewegung setzt Handcursor zurück, Panelpunkt
wird vom Canvas-Hit-Test/Kontextmenü abgewiesen, externer MouseDown startet keine
Interaktion; bestehender Settings-Tastaturtest ebenfalls PASS. [Log](tests.log).
[Release-Build](build.log), [Identität](environment.json), [Fix](fix.diff).

Kurzer Live-Check: signierter Release /Applications, Settings öffnen, Maus quer durch
Panel bewegen, gespeicherte Desktopdaten unverändert. [Runner](live.py),
[Mausbewegung](move.swift), [Rohdaten](live.json), private Aufnahme
/tmp/openplane-settings-pointer/after.png. Preferences restauriert.
Native AppKit, keine Storybook-Stories. Kein vollständiger Varianten-/A/B-Lauf.

P13 Baselinevergleich zu Settings-Size-Build sowie Gruppen-/Resize-Griffe nahe der
Panelgrenze, Öffnen/Schließen bei ruhendem Cursor, Scroll/Magnify und Core-Smoke:
NOT RUN: scheduled overnight (2026-09-07 03:00 Berlin).
Idle-/Aktions-/zusätzliche CPU und kalibrierte Latenz/Framezeiten nicht gemessen.
Fehlende Beobachter BLOCKED [PERF-001/003/007/020](../../backlog.md).
Keine volle Performancefreigabe; keine CPUgewinn-Behauptung.
