# PERF-019: Hilfsflächen nicht als Fensterkarten aufnehmen

2026-09-06, Codex. P03/P04/P10. Funktionaler Fixture-Kurzvergleich bestanden;
volle Performance-Abnahme NOT RUN: scheduled overnight, 2026-09-07 03:00 Berlin.

## Änderung

Bisher gab ein einziges AX-Standardfenster alle ScreenCaptureKit-Flächen desselben
Prozesses frei. Jetzt benötigt jede aufgenommene Fläche ihre eigene AX-Zuordnung.
Der Geometrie-Fallback ohne passenden Titel akzeptiert nur noch eine aufsummierte
Positions-/Größenabweichung von höchstens acht logischen Punkten; sonst konnte
bereits ein einzelner verfügbarer AX-Kandidat einem fremden Hilfsfenster zugeordnet
werden. Bestehender Match-Cache und Wiederholungsmechanismus bleiben erhalten.
[Begrenzter Diff](fix.diff), [gesamter Produkt-/Testdiff](source.diff).

## Nachweise

[Build](build.log) erfolgreich, [zwei gezielte vorhandene Tests](tests.log)
bestanden (Inventur-Hysterese und Browser-Titelabgleich). Diese Tests ersetzen
keinen Live-Nachweis für das Matching.

[Fixture.swift](Fixture.swift) erstellt ein normales Fenster und eine unbenannte
Hilfsfläche ohne AX-Fensterrolle. [Inspect.swift](Inspect.swift) wurde mit dem
unveränderten WindowService vor bzw. nach dem Fix gegen dieselbe laufende Szene
kompiliert. [Inventurdaten](inventory.txt): Baseline nimmt beide Fixture-Flächen
auf, davon eine ohne AX-Match; Kandidat nimmt nur das normale Fenster auf.
Chromes echtes Fenster ID 8139 wird auf beiden Varianten korrekt zugeordnet.
Gesamtbestand sinkt genau um diese eine Hilfsfläche von neun auf acht.

Die signierte Release-App unter `/Applications/OpenPlane.app` wurde installiert
und per Such-Eingabe live geprüft: genau ein Ergebnis für die Fixture, normale
Vorschau. Screenshot `/tmp/openplane-window-filter/after-fixture.png` visuell
kontrolliert. [Live-Ablauf](live.py); Quellen/Build-/Fixture-Hashes und Umgebung
stehen in [environment.json](environment.json).

## Aussagegrenzen und offene Abnahme

Das ursprüngliche Chrome-Doppelbild war in der aktuellen Sitzung nicht mehr
vorhanden. Die konkrete Zuordnung des schwarzen Bereichs im Nutzerbild zu einer
Chrome-Hilfsfläche bleibt daher eine Hypothese. Der zugrunde liegende allgemeine
Fehler wurde mit kontrollierter Hilfsfläche reproduziert und behoben.

Ein Inventurdurchgang pro Variante, ein Suchpfad in der installierten App;
frische Diagnoseprozesse, bestehende warme Benutzer-Apps, kein Cache-Reset.
Keine konkurrierenden Builds während der Live-Prüfung. Kein fünf-Paar-Vergleich.
Idle-CPU vorher/nachher, Aktions-CPU, zusätzliche CPU, Speicher, präzise Latenz
und präsentierte Bildzeiten nicht gemessen; kein Performancegewinn behauptet.

Chrome Backspace/Return mit Profilwahl, mehrere echte Fenster, Minimierung,
bewegte/vergrößerte Fenster ohne Titel und andere App-Typen sowie Core-Smoke:
NOT RUN: scheduled overnight. Der strengere Fallback kann bei zeitlich versetzten
Geometriedaten die Erkennung bis zum nächsten Versuch verzögern; nachts prüfen.
Fehlende kalibrierte Beobachter bleiben BLOCKED. Folgeaufgaben
[PERF-001/003/007/019](../../backlog.md); PERF-019 bleibt VERIFY.

Kandidaten-Hash und Signatur geprüft. Eigene Fixture beendet, keine fremden
Fenster geschlossen, keine Einstellungen umgeschaltet. Suchnavigation kann
normalen Auswahl-/Kamerazustand verändern. Vordergrund zurück zu Codex; Build-,
Test- und Diagnosejobs beendet. Keine neue dauerhafte Hilfsfenster-Infrastruktur.
