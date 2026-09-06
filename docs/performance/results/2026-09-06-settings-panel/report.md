# PERF-020: Settings als Seitenpanel

2026-09-06, Codex. P13; Viewport-Regressionsfamilien P01/P02/P03/P06.
Funktionale Kurzprüfung PASS im beschriebenen Umfang. Volle Performance-Abnahme
NOT RUN: scheduled overnight, ab 2026-09-07 03:00 Europe/Berlin.

## Ergebnis

Settings-Zahnrad ersetzt die bisherige Farbpalette als Einstieg. Weißes rechtes
Panel mit Hintergrundfarben, gruppierten Zeilen, dezenten Icons und nativen blauen
Schaltern, angelehnt an die Nutzervorlage. Keine erfundenen Profil-/Kontofunktionen.
Die bisherigen acht Einstellungsaktionen werden mit unveränderter Speicherlogik
verwendet; Desktop-Aktionen bleiben im Navigator-Menü.

Ein gemeinsamer Container teilt die Breite zwischen Canvas und Panel. Bei normaler
Displaybreite belegt das Panel 380 Punkte. Karten behalten Weltpositionen und
Zoom; Kamera-Mittelpunkt bleibt erhalten, der Viewport und seine Bedienelemente
werden schmaler. Keine dauerhafte Neuanordnung oder zusätzliche Desktop-Szene.
Beim Fokussieren einer echten App wird das Panel vor der Kameraausrichtung geschlossen.
[Begrenzter Diff](fix.diff), [vollständiger Produkt-/Testdiff](source.diff).

## Prüfung

- [Release-Build](build.log) erfolgreich, Kandidat signiert in `/Applications`.
- [Elf gezielte DesktopTabTests](tests.log) bestanden. Neuer Test prüft echte
  Öffnungsaktion, kleinere Canvasbreite, unveränderte Kamera und persistierte
  Platzierungen, Grid-Schalter und Speicherung, Wiederherstellung voller Breite.
- [Live-Rohdaten](live.json), [Ablauf](live.py): Öffnen, Grid aus/an inklusive
  Preferences-Abgleich, Schließen-X, erneutes Öffnen und Escape bestanden.
  Der Settings-Button verschiebt sich um genau 380 logische Punkte und kehrt
  danach exakt an seine alte Position zurück. Grid-Ausgangszustand wiederhergestellt.
- Visuelle Prüfung `/tmp/openplane-settings/panel.png` und `grid-toggled.png`:
  weiße Fläche, lesbare ungekürzte Zeilen, sichtbare Gruppen/Schalter; Canvas
  endet an der Panelgrenze, Navigator liegt in der reduzierten Arbeitsfläche.
  Native AppKit-Oberfläche ohne Storybook; direkt installierte Release-App geprüft.
- Ein erster Live-Versuch erreichte die Schließaktion nicht, weil der erwartete
  AX-Button nicht mehr gefunden wurde. Ursache nicht isoliert; Rohfehler in
  [live-first-attempt.json](live-first-attempt.json) erhalten. Wiederholung mit
  demselben Build bestand. Kein verschwiegenes PASS für den ersten Versuch.

## Messgrenzen und nächste Abnahme

Persönliche Szene, kein versioniertes Referenzfixture. Frisch gestartete App,
anschließend wiederholte Panelöffnungen, keine Cachelöschung. Kein fünf-Paar-A/B.
CPU vorher/nachher, Aktions-CPU, zusätzliche CPU, Speicher, präzise Reaktions- und
Bildzeiten nicht gemessen. Screenshots dienen ausschließlich visueller Prüfung;
kein Performancegewinn oder vollständige Freigabe behauptet.

Volle acht Schalter, Farbwahl, Tastaturfokus, kleine Höhen/Breiten, Such-/Desktop-
wechsel, Fokus-/Zoompfade, Core-Smoke und wiederholte Ressourcenvergleiche:
NOT RUN: scheduled overnight. Fehlende kalibrierte Beobachter weiterhin BLOCKED;
Folgeaufgaben [PERF-001/003/007/020](../../backlog.md). PERF-020 bleibt VERIFY.

[Umgebung/Hashes](environment.json) identifizieren den schmutzigen Quellstand,
Baseline und installierten Kandidaten. Signatur und Binärgleichheit geprüft.
Grid-Einstellung wiederhergestellt, kein fremdes Fenster geschlossen. Eigene
Build-/Testjobs beendet, Vordergrund zu Codex zurückgestellt. Die ältere eigene
Fenster-Filter-Fixture wurde ebenfalls beendet (ihr gestarteter Pfad war von
macOS von `/tmp` auf `/private/tmp` normalisiert worden).
