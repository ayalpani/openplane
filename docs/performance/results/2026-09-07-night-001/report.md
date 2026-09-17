# Nachtrunde 2026-09-07: Zeitfenster verpasst

Status: NOT RUN. Der Trigger nennt 03:04 Europe/Berlin; die tatsächliche
Vorprüfung fand laut Systemzeit erst um 13:49 statt. Damit liegt die Ausführung
außerhalb des autorisierten Desktop-Fensters 03:00–07:00. Keine verspätete
Live-Prüfung gestartet. Keine Eingaben, Builds, Profiling, Installationen oder
App-/Einstellungsänderungen. Keine fremden Jobs beendet.

[Vorprüfung](preflight.json): entsperrte Sitzung, Test-Lock frei (sofort wieder
freigegeben), signierte installierte App. Commit 3d976d0 plus fremde lokale
Änderungen; [Dirty-Diff](source.diff) und Binärhash dokumentiert. Quellstand ist
nicht allein durch den Commit identifiziert. Keine neue Baseline festgelegt.

P01–P14 inklusive Core-Smoke, erste/warme Läufe und fünf A/B-Paare: NOT RUN wegen
Zeitfenster. Offene PERF-014–021-Abnahmen bleiben offen; auch P15/P16 und neuere
Input-Lifecycle-Varianten wurden nicht live ausgeführt. Keine Messwerte für
idle/action/additional CPU, Latenz, Frames oder gezählte abgeschlossene Aktionen.
Bestehende fehlende Fixtures/Beobachter aus PERF-001/003–007 bleiben BLOCKED;
Runbooks und Tagesberichte ersetzen keine volle Abnahme. Siehe
[Backlog](../../backlog.md). Keine Regression oder Performancefreigabe behauptet.

Die tägliche autorisierte Automation bleibt aktiv; nächstes reguläres Fenster
2026-09-08 03:00–07:00 Europe/Berlin. Keine zusätzliche Tageswiederholung geplant.
