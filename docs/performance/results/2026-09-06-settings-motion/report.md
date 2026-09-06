# PERF-020: Panelanimation, klickbare Zeilen und freie Icons

2026-09-06, Codex; P13. Funktionale Kurzprüfung PASS; volle Performance-Abnahme
NOT RUN: scheduled overnight, 2026-09-07 03:00 Europe/Berlin.

Panel öffnet/schließt mit 180-ms-AppKit-Frameanimation; Canvas-Viewport verändert
sich gleichzeitig, Weltkoordinaten bleiben erhalten. Bei Reduce Motion entfällt
die Bewegung. Generationsprüfung schützt vor veralteten Abschlussaktionen.
Settings-Zeilen verwenden einen nativen transparenten Button für Text/Icon/Leerraum
und dieselbe Aktion wie der Schalter. Keine erfundenen Untermenüs: alle aktuellen
Zeilen sind boolesche Einstellungen, Hintergrundfarben bereits direkt auswählbar.
Icons jetzt 26 statt 18 Punkte, ohne graue Kachel.

[Build](build.log) erfolgreich. [Gezielter Paneltest](tests.log) bestanden,
einschließlich Treffer auf Icon/Text, je einmal Schalten, Persistenz und Kamera.
[Live-Rohdaten](live.json), [Runner](live.py): echter Koordinatenklick auf Grid-Text
schaltet aus, Klick auf Icon wieder an; Ausgangseinstellung verifiziert.
Video `/tmp/openplane-settings-motion/motion.mov` und Kontaktbögen zeigen
Zwischenpositionen beim Öffnen und Schließen; Panelbild visuell geprüft.
Kontaktbögen wurden resampelt, keine kalibrierte Bildzeit-/Latenzmessung.

Persönliche Szene; frischer App-Prozess, keine Cachelöschung. Ein Öffnen/Schließen
und zwei Zeilenklicks, keine fünf A/B-Paare. Idle-/Aktions-/zusätzliche CPU,
Speicher und präzise Reaktions-/Bildzeiten nicht gemessen. Aufnahme getrennt von
Build/Profiler, keine CPU-Aussage aus Video. Volle Unterbrechungs-, Reduce-Motion-,
Tastatur-, Drag-out- und Ressourcenprüfung sowie Core-Smoke nachts; fehlende
Beobachter BLOCKED gemäß [PERF-001/003/007/020](../../backlog.md).

[Hashes](environment.json), [Diff](fix.diff), [Produkt-/Testdiff](source.diff).
Signierter Release-Kandidat installiert und Hashgleichheit geprüft. Grid-
Einstellung wiederhergestellt, eigene Jobs beendet, Vordergrund an Codex zurück.
Native AppKit-Sichtprüfung; keine Storybook-Oberfläche.
