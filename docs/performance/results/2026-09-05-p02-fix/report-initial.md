# PERF-011: Kameraaktualisierung beim Zoomen zusammenfassen

## Änderung und Status

2026-09-05/06, Codex. Im Kamera-Setter wird bei geändertem Zoom nur noch
`synchronizeScene()` aufgerufen. Diese Funktion aktualisiert die Kamera bereits
innerhalb ihrer eigenen Core-Animation-Transaktion. Bei reiner Verschiebung bleibt
`updateSceneCamera()` erhalten. Keine veränderte Animation, Eingabefilterung,
Titel-/Rasterdarstellung oder neue Caches. [Genauer Fix](fix.diff).

**Implementierung: vorhanden, Release erfolgreich gebaut, 83 Tests erfolgreich.**
**Performance-Ergebnis: INCONCLUSIVE; vollständige Live-Verifikation: BLOCKED.**
Kein belastbarer CPU-Gewinn. PERF-011 bleibt offen. Kein Commit, Merge oder neue
Baseline. Die bisherige Release-App wurde nach den abgebrochenen Versuchen
wiederhergestellt; der Kandidat liegt im Build-Verzeichnis und im Arbeitsbaum.

## Umgebung und Methode

[Build-/Quellidentität](environment.json), [Kandidaten-Diff inklusive vorheriger
Arbeitsbaumänderungen](candidate-source.diff), [Buildlog](build.log),
[Testlog](tests.log).

A: SHA256 `e7980cfbca7204c752b0d6527e09d37027ee8b9d7bf092010c74555937142277`.
B: SHA256 `c2d7f7dce2e109060dc68928f4fddebc83290c0e8db98fb846556a96b5b01fdc`.
Beide signierte Release-Apps, jeweils aus `/Applications/OpenPlane.app` ausgeführt.
Mac14,10/M2 Pro, macOS 26.6.2, persönlicher Desktop 2. Displaykonfiguration aus
vorheriger Diagnose: internes Retina-Display 3456 × 2234; tatsächliche Bildrate
nicht beobachtet. Energie-/Thermalzustand in dieser Serie nicht neu erfasst.

Gleicher Preferences-Export je Variante importiert; exakte Start-/Endkamera und
Fixture-Hash in den Rohdaten. Persönliche Fenster, Vorschauinhalte, andere Apps
und OS-Caches nicht eingefroren. Kein vollständiges S/R/L-Szenario. Kein direkter
Vergleich mit den 25,51 % der vorherigen Diagnose.

Geplant: fünf Paare A/B, B/A abwechselnd. Pro Installation erste Route separat,
zwei Aufwärmrouten, eine gemessene Warmroute. Reset auf gespeicherten Zoom 0,06.
Route: 45 Shift-Runter-Taps mit angeforderten 50 ms Abstand, 500 ms Pause,
45 Shift-Hoch-Taps. Standardphasen 5 s Idle, Route, 1 s Nachlauf, 5 s Idle.
Mach-Zähler für OpenPlane-CPU; 100 % entspricht einem Kern. Keine eigenen Builds,
Profiler oder anderen Testjobs während der CPU-Phasen.

[Erster Versuch](comparison.json), [exakt verwendeter Helfer](compare-first-attempt.py):
ein vollständiges Paar, danach Fokusverlust während des nächsten Resets;
sofortiger Eingabestopp. [Zweiter Versuch](comparison-retry.json),
[Helfer mit expliziter Aktivierung nach Start](compare.py): Fokusverlust bereits
beim Reset, keine vollständige Route. Abbrüche werden nicht als erfolgreiche
oder abgeschlossene Aktionen gezählt.

Die anschließende Vordergrundabfrage meldete `loginwindow`. Die vorhandene
IORegistry-Sitzungsprüfung meldete dagegen „unlocked“ ([Beleg](session-status.json));
sie reicht offensichtlich nicht als Nachweis einer nutzbaren sichtbaren Sitzung.
Keine weiteren Tastatureingaben nach dieser Diagnose. Nutzer um Rückkehr zum
normalen sichtbaren Desktop gebeten. Der Ursprung der Fokuswechsel ist damit
nicht sicher festgestellt; kein Produktfehler behauptet.

## Ein einziges vollständiges Paar — kein Gewinnnachweis

| Größe | A | B |
| --- | ---: | ---: |
| Idle-CPU vorher | 2,409 % | 1,939 % |
| Aktions-CPU | 26,591 % | 21,781 % |
| Zusätzliche CPU | 24,182 pp | 19,842 pp |
| Nachlauf-CPU | 1,140 % | 2,228 % |
| Idle-CPU nachher | 2,642 % | 1,749 % |
| Aktionsdauer inklusive Eingabehelfer | 7,062 s | 8,423 s |
| Tatsächliche Aktions-CPU-Zeit | 1,878 s | 1,835 s |

Die vermeintlichen 18,1 % weniger Aktions-CPU gehen mit **19,3 % längerer
Eingabefolge** einher. Die CPU-Sekunden unterscheiden sich nur um etwa **2,3 %**.
Die Zustellintervalle wurden nicht einzeln gemessen; Ursache der unterschiedlichen
Dauer unbekannt. Zudem unterscheiden sich die Idle-Werte. Deshalb keine
Optimierungsbehauptung aus den niedrigeren Prozentwerten.

Gespeicherte Start-/Endkamera stimmt für alle acht vollständig aufgezeichneten
Routen des ersten Paares überein. Angeforderte Taps: 90 je Route. Zugestellte,
akzeptierte und erfolgreich abgeschlossene Einzelaktionen: nicht beobachtet,
`null`. CPU-Sekunden je erfolgreicher Aktion deshalb nicht berechenbar.
Reaktions-/Abschlusslatenz, präsentierte Bildzeiten und vergleichender Speicher:
BLOCKED/NOT RUN. Die bisherigen Instruments-Probleme und Beobachterlücken
bleiben bestehen; [PERF-003/004](../../backlog.md).

## Funktionale Prüfung und verbleibende Abdeckung

83 bestehende Tests erfolgreich, ohne konkurrierende Live-Messung. Darunter
Zoom über mehrere Größen mit unveränderten Weltkoordinaten/Layeridentitäten,
Kameraverschiebung, unterbrochene Fahrten und Persistenz. Keine neuen Tests, die
nur die Verzweigung duplizieren. Diese Tests ersetzen keine Live-Prüfung.

| Live-Fall | Status / offene Prüfung |
| --- | --- |
| P02 Taps | PARTIAL: ein Paar, persistierte Endkamera korrekt; restliche Paare und sichtbare Korrektheit offen |
| P02 Halten, Pinch, Umkehr, Gruppe/Suche, R/L | NOT RUN: vollständiger Fixture-/Ereignisbeobachter fehlt, sichtbare Sitzung unzuverlässig |
| P01/P03/P05/P06/P14 Core-Smoke | NOT RUN: nach Fokusabbruch keine weitere Live-Steuerung |
| P04 Core-Smoke | BLOCKED: dedizierte Start-Fixture und Bereitschaftsbeobachter fehlen, PERF-001/005 |
| P07/P13 betroffene Kamera-/Settingsvarianten | NOT RUN: Pointer-/Variantenadapter fehlen, PERF-007 |

Der [vorbereitete Smoke-Helfer](smoke.py) wurde noch nicht ausgeführt; seine
Existenz ist keine Testevidenz. Native AppKit-App, keine Storybook-Stories.
Vorher/Nachher-Screenshots noch nicht aufgenommen. Relevante visuelle Risiken:
Geometrie und Kamera müssen im selben sichtbaren Bild zusammenpassen; Raster,
Titel/Kürzung, Minimap und Auswahl dürfen nicht kurzzeitig auseinanderlaufen.

## Nächster Schritt und Abnahme

Nach Wiederherstellung einer sichtbaren Sitzung fünf frische gepaarte Läufe mit
identischer Route durchführen. Reale Eingabedauer und CPU-Sekunden gemeinsam
bewerten; bei abweichenden Eingabekadenzen keinen Prozentgewinn behaupten.
Fokusverlust stoppt weiterhin Eingaben und erhält Rohdaten. Für vollständige
Abnahme bleiben die gezählten erfolgreichen P02-Zyklen und Bild-/Latenzbeobachter
sowie betroffene Varianten und Core-Smoke nach Policy erforderlich.

Der begrenzte Fix wird nur bei nachvollziehbarem Nutzen behalten; bei weiterhin
fehlendem Gewinn die eigene Änderung zurücknehmen. Vorgeschlagenes Nutzensziel
und vollständiger Funktionsvertrag im [Diagnosebericht](../2026-09-05-p02-diagnosis/report.md).
PERF-011 nicht schließen, bevor frische A/B-Evidenz und funktionale Prüfung vorliegen.

## Wiederherstellung

Beide Vergleichshelfer haben die bisherige App A und den jeweiligen ursprünglichen
Preferences-Export wiederhergestellt, Plist-Gleichheit vor dem Neustart geprüft
und die ursprüngliche Vordergrund-App zu aktivieren versucht. `restored: true`
in beiden Rohdateien bezieht sich auf erfolgreich ausgeführte Wiederherstellung;
die spätere loginwindow-Beobachtung verhindert eine Zusage über die sichtbare UI.
Temporäre Preferences-Backups entfernt. Keine eigenen Test-/Build-/Profiljobs
laufen weiter. Vorbestehende Änderungen im Arbeitsbaum wurden erhalten.
