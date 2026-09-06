# P06: Richtungsabhängiger Slide plus Fade

2026-09-06, Codex; PERF-017. Interaktive Umsetzung ausdrücklich vom Nutzer
gewünscht; volle Nachtrunde auf 2026-09-07 verschoben.

## Änderung und Status

Ankommende Karten und Raster gleiten 40 logische Punkte in ihre Endposition,
parallel zum bestehenden Fade, insgesamt weiterhin 180 ms. Ein höherer tatsächlicher
Desktopindex kommt von rechts, ein niedrigerer von links. Beim zyklischen Umlauf
gilt ebenfalls die räumliche Tab-Reihenfolge. Die Richtung wird beim Ausführen
des jeweiligen Warteschlangeneintrags bestimmt. Tabs und Navigator bleiben stehen.
Die vorhandene FIFO-Verarbeitung schneller einzelner Tab-Eingaben bleibt erhalten.

Zwei vorhandene Layer erhalten eine vorübergehende Core-Animation-Positionsanimation;
keine neue Szene, kein dauerhafter Desktop-Cache und keine Änderung der gespeicherten
Kamera. [Begrenzter Produktdiff](fix.diff), [gesamter Produkt-/Testdiff](source.diff).

Funktionale Kurzprüfung: PASS im unten beschriebenen Umfang.
Gesamte Performance-Abnahme: NOT RUN: scheduled overnight. Präzise
Eingabe-/Präsentationslatenz und Bildzeiten weiterhin BLOCKED wegen fehlender
kalibrierter Beobachter; Folgeaufgaben [PERF-001/003/007/017](../../backlog.md).

## Umgebung und Reproduktion

Quellstand, Diff-Hashes, signierte Release-Binäridentitäten, Mac, macOS, Display
und Stromversorgung stehen in [environment.json](environment.json).
Baseline ist die zuvor installierte FIFO-plus-Fade-Version, Kandidat ergänzt
nur den Slide. Beide wurden nacheinander in `/Applications/OpenPlane.app`
installiert und mit denselben gesicherten Benutzereinstellungen gestartet.
Der Fixture-Hash ist in [live.json](live.json) erhalten; private Einstellungen
und Bildschirmaufnahmen werden nicht ins Repository geschrieben.

Je Variante frischer App-Prozess; keine Behauptung kalter Systemcaches.
Eine Tab-Eingabe, danach Shift-Tab, jeweils etwa 0,95 Sekunden Abstand.
Pro Variante zwei angeforderte, zugestellte und abgeschlossene Desktopwechsel.
Beide gespeicherten Kamerazustände blieben bei jedem Wechsel exakt gleich;
Ausgangsdesktop und gesamte Einstellungen wurden danach wiederhergestellt.
Keine Aufwärmserie oder fünf A/B-Paare: bewusst kurze Funktionsprüfung gemäß
interaktiver Policy. Kein paralleler Build oder Profiler beim Live-Check.

## Belege und Ergebnisse

- [Release-Build](build.log): erfolgreich.
- [Zehn gezielte DesktopTabTests](tests.log): erfolgreich, null Fehler.
  Enthalten Richtungswechsel nach tatsächlicher Tab-Reihenfolge, 180-ms-Dauer,
  exakte Kamera, Entfernen der Animation und bestehende FIFO-Regressionstests.
- [Live-Rohdaten](live.json), [Runner](live.py): je zwei erfolgreiche Wechsel
  vor/nach Änderung, keine erfassten Fehler oder Timeouts.
- Vorher-/Nachher-Aufnahmen und Kontaktbögen unter
  `/tmp/openplane-desktop-slide/`: Fade der Baseline sowie Slide/Fade des
  Kandidaten bei Hin- und Rückwechsel visuell geprüft. Die Bewegung ist dezent;
  die eingehenden Inhalte erreichen ihre unveränderte Endposition.
  Die Kontaktbögen wurden auf 60 Bilder/s resampelt und sind ausdrücklich kein
  Nachweis tatsächlich präsentierter Bildzeiten oder gemessener Abschlusslatenz.

Idle-CPU vorher/nachher, Aktions-CPU, zusätzliche CPU, CPU-Sekunden/Aktion und
Speicher: nicht gemessen. Bildschirmaufnahme diente nur der visuellen Kontrolle;
ihre Kosten wurden nicht kalibriert. Kein CPU-Gewinn und keine vollständige
Performance-Freigabe werden behauptet.

## Offene Abnahme und Abschluss

P06 volle Eingabevarianten einschließlich schneller gemischter Folgen, Klicks,
Wrap und Unterbrechungen, Core-Smoke sowie CPU-/Speicher-Vergleich gegen die
festgehaltene Baseline: NOT RUN: scheduled overnight, ab 2026-09-07 03:00
Europe/Berlin. Fehlende Fixtures/Beobachter bleiben separat BLOCKED; Terminplanung
ersetzt keine Messung. PERF-017 bleibt VERIFY / Nachtrunde.

Die gewünschte Kandidatenversion ist installiert und ihre Signatur sowie ihr
Binär-Hash wurden abschließend geprüft. Einstellungen und vorheriger Vordergrund
wurden wiederhergestellt. Eigene Build-, Test- und Aufnahmejobs sind beendet.
[Abschlussnachweis](completion.json).
