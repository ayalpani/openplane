# PERF-020: Runde Settings-Schieber

2026-09-06, Codex; P13. Funktionale Kurzprüfung PASS; volle Performance-Abnahme
NOT RUN: scheduled overnight, 2026-09-07 03:00 Europe/Berlin.

NSSwitch-Darstellung durch eine kleine NSButton-Unterklasse mit Schaltertyp und
eigener Zeichnung ersetzt: Bahn 38 × 22 Punkte, weißer Schieber exakt 18 × 18,
2 Punkte Innenabstand. Zustand, Target/Action und Accessibility-Schaltersemantik
laufen über AppKit; kein eigener Eingabehandler, Timer oder Animationsprozess.

[Build](build.log) erfolgreich. [Gezielter Panel-/Persistenztest](tests.log)
bestanden. [Live-Prüfung](live.json) mit [Runner](live.py): Grid aus/an und
Preferences-Wiederherstellung, Panel öffnen/schließen/Escape bestanden. Screenshot
`/tmp/openplane-round-switches/off.png` zeigt visuell geprüfte runde Schieber
in beiden Zuständen. Native AppKit-Prüfung, kein Storybook vorhanden.

Persönliche Szene, kein Cache-Reset, keine fünf A/B-Paare. Idle-/Aktions-/zusätzliche
CPU, Speicher und präzise Antwort-/Bildzeiten nicht gemessen. Keine konkurrierenden
Builds/Profiler beim Live-Test. Volle Tastatur-/Accessibility-Varianten, Core-Smoke
und Ressourcenvergleiche NOT RUN: scheduled overnight; fehlende Beobachter bleiben
BLOCKED, [PERF-001/003/007/020](../../backlog.md). Kein Performancegewinn behauptet.

[Quell-/Buildidentität](environment.json), [Diff](fix.diff),
[gesamter Produkt-/Testdiff](source.diff). Signierter Release-Kandidat installiert
und Hashgleichheit geprüft, Grid-Ausgangseinstellung wiederhergestellt, eigene
Jobs beendet und Vordergrund an Codex zurückgegeben.
