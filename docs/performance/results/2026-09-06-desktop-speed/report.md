# PERF-014: Desktopwechsel mit 180 statt 280 ms

Anlass: Nutzer empfindet die Desktopüberblendung als langsam und wünscht
explizit dasselbe Tempo wie beim Wechsel zwischen App-Karten.

## Änderung und Architektur

[Ein-Zeilen-Fix](fix.diff): `desktopTransitionDuration` verweist auf
`selectionTransitionDuration` (180 ms). Die App-Kartennavigation verwendet diesen
Wert sowohl für Auswahl als auch Kamerafahrt. Zuvor Desktop 280 ms.
Desktop-/Layoutwechsel weiterhin unter voll deckender Blende zur Hälfte der
Animation: geplant 90 statt 140 ms nach Beginn. Gesamtdauer geplant 180 statt
280 ms (−35,7 %). Dies sind konfigurierte Zeitwerte, keine präsentierten
Bildlatenzen oder CPU-Gewinnbehauptung.

Aktuell besteht eine gemeinsame retained Szene mit Karten-/Kamera-/Raster-
Layern. Desktopwechsel übernimmt Kamera und gespeicherte Anordnung in diese
Szene, aktualisiert Platzhalter, Tabs und Navigator und speichert Zustände.
Es gibt keine zwei vollständig vorbereiteten Desktop-Szenen, deren Z-Reihenfolge
nur getauscht wird. Eine solche Architektur wäre eine separate Änderung samt
Pflege der unsichtbaren Szene und zusätzlichem Layer-/Speicherbedarf; hier nicht
umgesetzt. Kamerageometrie, Raster, Blendenkurve und Eingabeannahmeregeln bleiben
unverändert. Tasteneingaben während einer Desktopüberblendung werden weiterhin
ignoriert; schnelle Tab-Klicks haben die bestehende Vormerkung des letzten Ziels.

## Identität und Tests

[Umgebung/Hashes](environment.json), [vollständiger Quellstand](source.diff),
[Release-Build](build.log), [85 erfolgreiche Tests](tests.log). Bestehende
Desktoptests prüfen Blendenphasen, Kameraerhalt, Eingabevarianten und schnelle
Zielwechsel. Kein neuer Test, der nur die geänderte Konstante abschreibt.

Beide signierte Release-Apps unter `/Applications/OpenPlane.app` getestet.
Gleiche Maschine wie [Rasterdiagnose](../2026-09-06-grid-cost/report.md),
Mac14,10/M2 Pro, macOS 26.6.2, Retina; Bildrate/thermische Last nicht durchgehend
beobachtet. Keine konkurrierenden eigenen Builds/Profiler während CPU-Messung.
Exklusiver Live-Test-Lock und Fokusprüfung; Einstellungen gesichert/wiederhergestellt.

## Live-Protokoll und Grenzen

[Runner](compare.py), [Rohdaten](comparison.json), [Auswertung](summary.json).
Geplant: fünf alternierende A/B-Paare (280/180, 180/280 usw.); ausgeführt: zwei vollständige Paare plus drei Routen des dritten Paares. Gemeinsamer Preferences-
Export, zwei bestehende Desktops mit Zoom 0,31 und 0,73; Raster und Debug an.
Export vor jeder Variante zurückgesetzt. Persönliche Live-Fensterinhalte bleiben
veränderlich, keine vollständige S/R/L-Fixture, kein OS-Cache-Reset.
Je Prozess eine erste Route, zwei Aufwärmrouten, eine gemessene Warmroute.
Sechs Tab-Wechsel je Route; nach jeweils etwa 450 ms Desktop-ID-Wechsel beobachtet,
abschließend gleiche Desktop-ID und beide Kameras unverändert. Standardphasen:
5 s Idle, Route, 1 s Nachlauf, 5 s Idle. CPU = OpenPlane-Nutzer+System-Zeit geteilt
durch monotone Wandzeit; 100 % = ein Kern. Das Warten begrenzt die Aussage über
maximalen Durchsatz. Beobachtungszeit nach festem Warten ist keine Reaktionslatenz.

Zusätzlicher Core-Smoke, 50 schnelle Tab/Shift-Tab-Eingaben und Tab-Klicks:
**NOT RUN**. Der Nutzer beanstandete die Prüfzeit und die längere Live-Prüfung
wurde daraufhin nicht fortgesetzt. [Vorbereiteter Helfer](smoke.py) wurde nicht
ausgeführt und ist kein Prüfnachweis. Die vorhandenen automatischen Desktop-
Regressionstests sind bestanden; die gesamte 85-Test-Suite dauerte 5,569 Sekunden.

Vollständige Performance-Abnahme **BLOCKED**: kalibrierte Reaktions-/Abschluss-
und Bildzeit-/Speicherbeobachter, vollständige Fixtures und Varianten fehlen.
Nachverfolgung [PERF-001/003/005/007/014](../../backlog.md). Kein vollständiger
14-Fälle-Nachweis; keine implizite Ausnahme oder neue Performancebaseline.

## Ergebnisse

19 abgeschlossene Routen, jeweils sechs beobachtete Desktopwechsel mit
unveränderten gespeicherten Kameras. Zwei vollständige gemessene A/B-Paare;
erste und Aufwärmrouten nicht in deren Median aufgenommen. Die laufende Route
brach bei der Vordergrundprüfung ab („Focus lost before key event“), zeitgleich
mit der Nutzerrückmeldung. Kein neuer OpenPlane-Crashbericht beobachtet. Keine
weiteren längeren Tests auf Wunsch des Nutzers; abgebrochene Route nicht als
Erfolg gezählt. Unvollständige Stichprobe: kein belastbarer Performance-Gewinn.

| Phase, Median | 280 ms, n=2 | 180 ms, n=2 |
| --- | ---: | ---: |
| idle_before | 1.17 | 1.21 |
| action | 10.17 | 8.52 |
| additional_cpu_pp | 9.00 | 7.32 |
| idle_after | 1.16 | 1.16 |

Die geprüfte Release-Version mit 180 ms ist installiert, Signatur und Binärhash
geprüft. Einstellungen durch den Helfer wiederhergestellt, eigene Testjobs
beendet: [Abschluss](completion.json). Keine Layer-Architekturänderung; keine
vollständige Performance-Freigabe. Die kürzere konfigurierte Dauer ist umgesetzt.

