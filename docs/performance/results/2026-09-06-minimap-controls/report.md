# PERF-021: Sichtbare Settings und ausgerichteter Footer

2026-09-06, Codex; P13. Funktionale Kurzprüfung PASS, volle Performance-Abnahme
NOT RUN: scheduled overnight, ab 2026-09-07 03:00 Europe/Berlin.

Settings-Zahnrad wird als fest helles, 24-Punkte-Bild gezeichnet, damit dynamische
AppKit-Templatefarben nicht schwarz auf dem dunklen Minimap-Hintergrund erscheinen.
Footer: Suche links, Gesamtansicht und Sperre rechts, jeweils 8 Punkte Rand und
40 Punkte große Trefferflächen. Keine Änderung der Einstellungsaktionen.

[Zwei relevante Tests](tests.log) bestanden (Settings-Viewport/Persistenz und
Desktop-Plus/einziger Settings-Einstieg). [Release-Build](build.log) erfolgreich.
[Live-Prüfung](live.json), [Runner](live.py): AX-Positionen bestätigen Ausrichtung;
Settings öffnet und schließt das Panel. Ganzer Bildschirm in
`/tmp/openplane-minimap-controls/full.png` visuell geprüft: helles Zahnrad sichtbar,
gewünschte Footer-Ausrichtung. Der erste Ausschnitt `minimap.png` enthielt nicht
die Minimap und wurde nicht als Sichtnachweis verwendet. Native AppKit-Prüfung,
kein Storybook vorhanden.

Persönliche Szene, frisch gestarteter Kandidat, keine Einstellungen verändert,
keine Caches gelöscht. Keine Builds/Profiler während des Live-Checks. Ein
Öffnen/Schließen, keine fünf A/B-Paare. Idle-/Aktions-/zusätzliche CPU, Speicher,
kalibrierte Antwort- und Bildzeiten nicht gemessen; kein Performancegewinn behauptet.
Volle P13-Varianten und Core-Smoke NOT RUN: scheduled overnight; fehlende
Beobachter bleiben BLOCKED, [PERF-001/003/007/021](../../backlog.md).

[Quell-/Buildidentität](environment.json), [begrenzter Diff](fix.diff),
[vollständiger Produkt-/Testdiff](source.diff). Signierter Kandidat installiert,
Binärgleichheit geprüft. Eigene Jobs beendet, Vordergrund an Codex zurückgegeben.

Nachtrag: Auf Nutzerwunsch Settings-Symbol auf 22 × 22 logische Punkte wie
Suche/Schloss reduziert; Trefferfläche bleibt bei allen 40 × 40. Reine
Größenkorrektur, keine neuen Unit-Tests. Erneuter Release-Build und kurzer
Live-Öffnungs-/Schließcheck in `size-build.log`, `size-build.json`,
`size-source.diff` und `size-live.json`; volle Abnahme bleibt nachts offen.
