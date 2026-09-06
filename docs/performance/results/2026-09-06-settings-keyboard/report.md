# PERF-020: Keyboard bei offenem Settings-Panel

2026-09-06; Codex; P01/P02/P03/P04/P06/P09/P13. Funktionale Kurzprüfung PASS;
volle Performance-Abnahme NOT RUN: scheduled overnight, 2026-09-07 03:00 Berlin.

Pauschalen early-return für das Panel aus dem gemeinsamen Navigationseinstieg
entfernt. Desktopwechsel und Suchbeginn schließen Settings nicht mehr. Die
bestehende Tastaturzuordnung und Texteditor-Guards bleiben erhalten; keine neue
parallele Tastaturimplementierung. Echter App-Fokus schließt weiterhin das Panel,
Escape behält die Reihenfolge Suche → Panel → Canvas. Globale Shortcuts unverändert.

[13 gezielte Tests](tests.log) bestanden. Neuer Handler-Test prüft Pfeiltasten,
Return/Keypad-Enter, Backspace, Shift-Return, Shift-Pfeil-Keydown/Keyup, Tab und
Shift-Tab mit tatsächlicher Desktopauswahl, Plus mit tatsächlicher Anlage sowie
Suchbeginn ohne Panelschließen und Texteditor-Vorrang. Bei Return/Backspace wird
in diesem Fixture die Annahme geprüft, kein echter App-Start/-Quit behauptet.

[Live-Rohdaten](live.json), [Runner](live.py): Panel geöffnet; Desktop per Klick
und + angelegt, Tab-Umlauf und Shift-Tab, Shift-Down/Up und Suchtext. Panel bleibt
bis zum abschließenden Screenshot offen. `/tmp/openplane-settings-keyboard/settings.png`
visuell geprüft. Gesamte ursprüngliche Preferences nach Test exakt wiederhergestellt,
beide temporären Desktops entfernt, signierter Kandidat installiert.

Persönliche Szene, neue App-Prozesse, keine Cachelöschung oder fünf A/B-Paare.
Idle-/Aktions-/zusätzliche CPU, Speicher und kalibrierte Antwort-/Bildzeiten nicht
ermittelt. Keine konkurrierenden Builds/Profiler im Live-Lauf. Alle weiteren
Live-Kombinationen inklusive sicherer Quit-Fixture, Texteditoren, globaler Shortcuts
und Core-Smoke sowie Ressourcenvergleiche nachts; fehlende Beobachter BLOCKED
[PERF-001/003/007/020](../../backlog.md). Keine volle Performancefreigabe.

[Build](build.log), [Identitäten](environment.json), [begrenzter Diff](fix.diff),
[vollständiger Produkt-/Testdiff](source.diff). Binärgleichheit/Signatur geprüft;
Einstellungen restauriert, eigene Jobs beendet, Vordergrund an Codex zurück.
