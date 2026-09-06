# PERF-021: Desktop-Plus und Settings im Minimap-Kopf

2026-09-06, Codex; P06/P13. Funktionale Kurzprüfung PASS;
volle Performance-Abnahme NOT RUN: scheduled overnight, 2026-09-07 03:00 Berlin.

Plus-Button nach dem letzten Desktop-Tab, zusätzlicher Tastaturpfad über das
Zeichen + (Shift zulässig, Autorepeat ignoriert). Tab/Shift-Tab wechselt nur
zwischen bestehenden Desktops. Titelbearbeitung und Suche behalten Texteingaben.
Das bisherige Desktop-Menü ist entfernt. Der Minimap-Knopf oben rechts ist jetzt
ein helles Settings-Zahnrad. Footer: Suche, Gesamtansicht, Ansichtssperre;
kein doppelter Farb-/Settings-Zugang. Einstellungen und Farben bleiben im Panel.

[Zwölf gezielte DesktopTabTests](tests.log) bestanden: neuer Test für Position
des Plus-Buttons, Klick/Plus-Taste, exakte Kamera, zyklisches Tab ohne Anlegen und
einen einzigen Settings-Knopf oberhalb des Footers. Vorhandene Panel-/FIFO-Tests
bleiben enthalten. Die anschließende reine Zahnrad-Farbkorrektur wurde gebaut
und visuell geprüft, ohne erneuten gesamten Testlauf.

[Live-Rohdaten](live.json), [Ablauf](live.py): je ein Desktop durch Plus-Klick und
Plus-Tastaturzeichen hinzugefügt; einmal Tab wechselt vom letzten zum ersten,
ohne weiteren Desktop. Settings-Kopf öffnet Panel. Zwei temporäre Desktops im
Cleanup entfernt, gesamte ursprüngliche Preferences vor Neustart exakt verglichen.
Ein erster Versuch scheiterte an einer AX-Meldung „Application isn’t running“;
[Fehler erhalten](live-first-attempt.json). Kein neuer OpenPlane-Crashbericht
gefunden. Derselbe Ablauf bestand beim erneuten Start.

Screenshots privat unter `/tmp/openplane-desktop-add/`: Tab-Zeile, Footer und
Panel visuell geprüft. Native AppKit-Oberfläche, keine Storybook-Surface.
Baseline-App vor Änderung gesichert, keine vollständige A/B-Messkampagne.
Persönliche Desktopfixture, neue OpenPlane-Prozesse, keine Systemcache-Löschung.
Kein konkurrierender Build/Profiler während Live-Eingaben.

CPU idle vorher/nachher, Aktions-CPU, zusätzliche CPU, Speicher und kalibrierte
Antwort-/Bildzeiten nicht gemessen. Kein Performancegewinn behauptet. Volle
Tastaturlayout-/Keypad-/Autorepeat-/Texteditorvarianten, lange Tab-Reihe, Core-Smoke
und Ressourcenvergleiche NOT RUN: scheduled overnight. Fehlende Beobachter
BLOCKED; [PERF-001/003/007/021](../../backlog.md). PERF-021 bleibt VERIFY.

[Umgebung/Hashes](environment.json), [begrenzter Diff](fix.diff),
[Produkt-/Testdiff](source.diff), [Build](build.log). Gewünschter signierter
Release-Kandidat installiert und Binärgleichheit geprüft. Eigene Jobs beendet;
ursprünglicher Desktopzustand restauriert, Vordergrund an Codex zurückgegeben.
