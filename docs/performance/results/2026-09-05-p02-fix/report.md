# PERF-011: Zoom-Update — abgeschlossener CPU-Teilvergleich

Stand: 2026-09-06, Codex. [Früherer Zwischenstand](report-initial.md).

## Ergebnis und Entscheidung

Die kleine Änderung im Kamera-Setter ist implementiert, gebaut und als signierte
Release-App installiert: Bei Zoomänderungen nur `synchronizeScene()` aufrufen,
weil diese Funktion die Kamera bereits innerhalb ihrer Transaktion aktualisiert.
Bei reinen Verschiebungen bleibt `updateSceneCamera()` erhalten. [Exakter Fix](fix.diff).
Keine geänderte Eingabefilterung, Animationsdauer, Geometrie oder neue Caches.

Fünf vollständige, alternierend angeordnete A/B-Paare liefern eine **kleine,
konsistente Senkung der gemessenen CPU-Zeit** im Teilfall mit ausgeschalteter
optionaler Debuganzeige. Aktions-CPU-Median: **27,42 → 26,27 %** eines Kerns.
CPU-Zeit-Median: **1,816 → 1,738 Sekunden** pro angeforderter Route.
Pro Paar sinkt die CPU-Zeit um 1,4–7,1 %, Median der gepaarten Reduktionen 3,53 %.

Das zuvor vorgeschlagene **10-%-Nutzensziel wurde nicht erreicht**. Es wird nicht
nachträglich abgesenkt. Die minimale Änderung bleibt als uncommitteter Kandidat
erhalten, aber PERF-011 wird nicht als abgenommen/erledigt geschlossen. Keine neue
Baseline, kein Merge und keine vollständige Performance-Freigabe.

**Gesamtstatus: BLOCKED für vollständige Verifikation.** Bild-/Reaktionslatenzen,
abgeschlossene Einzelbewegungen, volle P02-Varianten und Teile des Core-Smokes
fehlen weiterhin. Außerdem wurde ein realer, bereits in A vorhandener Absturz
mit eingeschalteter Debuganzeige nachgewiesen: [PERF-012](../../backlog.md).
Die Debuganzeige auszuschalten ist ausdrücklich keine Fehlerbehebung.

## Umgebung, Identität und Fixture

[Umgebung/Hashes](environment.json), [Kandidaten-Quellstand](candidate-source.diff),
[Release-Buildlog](build.log), [83 erfolgreiche Tests](tests.log).

- A: `e7980cfbca7204c752b0d6527e09d37027ee8b9d7bf092010c74555937142277`.
- B: `c2d7f7dce2e109060dc68928f4fddebc83290c0e8db98fb846556a96b5b01fdc`.
- Beide signierte Release-Apps 0.1 (2), Team 9FTHA7LGRQ, abwechselnd nach
  `/Applications/OpenPlane.app` kopiert und dort ausgeführt; Signatur je Wechsel geprüft.
- Mac14,10/M2 Pro, macOS 26.6.2; [Display](resumed-display.txt) 3456 × 2234 Retina,
  [Netzbetrieb](resumed-power.txt), [keine gemeldete Thermalwarnung](resumed-thermal.txt).
  Tatsächliche Bildschirmrate nicht beobachtet.
- Persönliche Live-Szene „Desktop 2“. Gleicher Preferences-Export je A/B-Variante,
  danach auf beiden `showDebugInformation=false`. Keine dauerhafte Änderung dieser
  Nutzereinstellung. Kein eingefrorenes S/R/L-Szenario; Vorschauinhalte, Fenster
  anderer Apps und OS-Caches bleiben unkontrolliert.
- Vor allen zehn gemessenen Routen identische gespeicherte Kamera:
  Zoom 0,06; Zentrum `[1587.5938992302272, 10406.562891205906]`.
  Fixture-Hash und volle Start-/Enddaten in den Rohdaten.
- Frischer OpenPlane-Prozess pro Installation, erste vollständige Route separat,
  zwei Aufwärmrouten, eine gemessene Warmroute. Kein Anspruch auf OS-cache-kalt.
- Exklusiver Live-Test-Lock; keine eigenen Builds/Profiler während der Messung.
  `caffeinate` verhindert während des jeweiligen Helfers Bildschirm-/Idle-Schlaf;
  beendet sich mit dem Helfer. Andere Nutzer-Apps wurden nicht beendet.

Diese Variante unterscheidet sich in Debugzustand und Eingabemethode von den
vorher gemessenen 25,51 % beziehungsweise vom ursprünglichen Pilot. **Kein direkter
Vorher/Nachher-Vergleich mit diesen alten Zahlen.** A/B hier haben denselben Modus.

## Ablauf und Rohdaten

[Finaler Vergleich](comparison-debug-off.json), [Helfer](compare-debug-off.py),
[direkte Tasteneingabe](direct-input.py), [Auswertung](debug-off-summary.json).

Route: 45 Shift-Runter-Taps, 500 ms Pause, 45 Shift-Hoch-Taps. Jeder native CGEvent-Tap
besteht aus Key-down, 10 ms Wartezeit, Key-up und 50 ms Wartezeit. Vordergrund-PID
vor/nach jedem Tap geprüft; Posting-Zeitstempel erfasst. Das beweist Posting,
nicht Verarbeitung durch OpenPlane oder abgeschlossene sichtbare Aktionen.

Phasen je Messroute: 5 s Idle vorher → Route → 1 s Nachlauf → 5 s Idle nachher.
Mach-CPU-Zähler des jeweiligen OpenPlane-PIDs, 100 % entspricht einem CPU-Kern.
CPU-Sekunden und reale Dauer getrennt; Nachlauf nicht still in die Aktion gerechnet.
Reihenfolge der fünf Paare: AB, BA, AB, BA, AB.

Alle 40 vollständigen Routen (erste, zwei Warm-ups, Messung je Installation)
enthalten 90 gepostete Taps und endeten mit ihrer korrekten gespeicherten Startkamera.
Akzeptierte Eingaben und abgeschlossene Bewegungen bleiben `null`: Viele Taps
liegen am begrenzten Zoomziel. CPU-Sekunden je erfolgreicher Einzelaktion sind
nicht bestimmbar. Diese Route ersetzt keine zehn vollständig beobachteten P02-Zyklen.

## Messwerte

Mediane der fünf gemessenen Warmläufe pro Variante:

| Größe | A | B | B minus A |
| --- | ---: | ---: | ---: |
| Idle vorher | 2,064 % | 1,905 % | −0,159 pp |
| Aktions-CPU | 27,422 % | 26,271 % | −1,151 pp |
| Zusätzliche CPU, pro Trial berechnet | 25,466 pp | 24,520 pp | −0,945 pp |
| Nachlauf-CPU | 0,397 % | 0,228 % | −0,169 pp |
| Idle nachher | 2,056 % | 2,031 % | −0,025 pp |
| Aktionsdauer | 6,622 s | 6,641 s | +0,020 s |
| Aktions-CPU-Zeit | 1,816 s | 1,738 s | −0,078 s |

Gepaarte Reduktionen der Aktions-CPU-Zeit: **1,46 %, 1,40 %, 4,30 %, 3,53 %, 7,09 %**.
Rohwerte einschließlich erster Verwendung/Aufwärmen erhalten. Kein p95 aus diesen
fünf Routen. Reaktions-/Abschlusslatenz und präsentierte Bildzeiten: BLOCKED,
PERF-003/004. Vergleichender Speicher: NOT RUN. Kein GPU-/Gesamtsystem- oder
Akkugewinn aus OpenPlane-CPU abgeleitet. Die kleine Differenz und die persönliche,
nicht vollständig kontrollierte Szene begrenzen die Verallgemeinerbarkeit.

## Abbrüche und neu erkannte Ursache

Die früheren [ersten](comparison.json) und [zweiten](comparison-retry.json)
Versuche sowie [Wiederaufnahme](comparison-resumed.json),
[AppleScript-Serie](comparison-stable.json) und [erster CGEvent-Versuch](comparison-direct.json)
sind separat erhalten und nicht Teil der fünf-Paar-Auswertung.
Ein Start scheiterte vor der Messung mit LaunchServices -609; andere Versuche
brachen mit Fokusverlust oder einem Eingabe-Timeout ab. Es wurde sofort gestoppt
und wiederhergestellt; unvollständige Routen wurden nicht als Erfolge gezählt.

**Korrektur der anfänglichen Einordnung:** Mehrere „Fokusverluste“ waren App-Abstürze,
nicht lediglich eine fehlende Desktop-Freigabe. Die [Crashbelege](crash-summary.json)
ordnen sie anhand der PIDs zu: 94782/95974 Kandidat B, 94967/96365 Baseline A.
Stack: `drawDebugInformation` → `sizeWithAttributes` → CoreText
`TAttributes::ApplyFont` → NSInvalidArgumentException „attempt to insert nil object“.
Die [Vordergrunddiagnose](focus-diagnostic.json) beobachtete UserNotificationCenter.
Die genaue Ursache im Textpfad ist noch ungeklärt. Beide Builds sind betroffen;
der Debug-off-Vergleich ist eine isolierte Variante, keine Reparatur dieses Fehlers.

## Live-Smoke und Sichtprüfung

[Baseline-Smoke](smoke-debug-off-A.json), [Kandidaten-Smoke](smoke-debug-off-B.json),
[ausgeführter Helfer](smoke-debug-off.py). Beide im Debug-off-Modus, danach ursprüngliche
Preferences wiederhergestellt. Keine aufgezeichneten Fehler in diesen Smoke-Läufen.

| Fall | Ausgeführt / Begrenzung |
| --- | --- |
| P01 | Je 100 echte Pfeiltasten; Eingabephase abgeschlossen, keine Zählung korrekter Einzelziele |
| P02 | Minimum 0,06 → Maximum 1,25 → Minimum 0,06 jeweils persistiert, Ankerzentrum innerhalb der Route gleich; fünf schnelle Umkehranforderungen und Pfeilunterbrechung zusätzlich gesendet |
| P03 | Je drei Finder-Aktivierungen und Rückkehr; korrekte Vordergrund-Apps beobachtet, keine erste-Pixel-/Bedienbarkeitslatenz |
| P05 | Je Start bis AX-Canvas; nur grobe Beobachterzeit, keine vollständige Readiness-Messung |
| P06 | Je zehn Tab-Eingaben, Enddesktop entspricht Startdesktop; keine Einzelübergangszählung |
| P14 | Je 30 s Idle, A 1,321 %, B 1,270 %; kein Dauertest |
| P04 | BLOCKED: dedizierte Start-Fixture und Bereitschaftskriterium fehlen, PERF-001/005 |
| P02 Halten/Pinch/Gruppe/Suche/R/L; P07/P13 | NOT RUN: vollständige Eingabe-/Fixture-/Variantenadapter fehlen, PERF-001/003/004/007 |

Vier Screenshots an Minimum/Maximum wurden visuell angesehen; keine auffällige
Änderung der Kartengeometrie, Auswahl oder Minimap. Bilder bleiben wegen persönlicher
Fensterinhalte außerhalb des Repositorys unter `/tmp/openplane-p02-ab/`; Pfade stehen
in den Smoke-JSONs. Kein pixelgenauer Vergleich: Live-Preview-Inhalte unterscheiden
sich und die Smoke-Startzentren liegen nach Neustart 21 Welteinheiten auseinander.
Die CPU-Paare hatten dagegen nachweislich dieselbe Startkamera. Screenshots prüfen
keine Zwischenbilder, flüssige Animation oder Reaktionslatenz. Native AppKit-App,
keine Storybook-Stories. 83 vorhandene Unit-/Regressionstests zuvor erfolgreich;
keine Produktänderung seit diesem Testlauf.

## Abschluss und offene Aufgaben

Kandidat B ist installiert und bleibt im Arbeitsbaum; kein Commit/Merge. Originale
Preferences einschließlich Debuganzeige wurden nach jedem Helfer wiederhergestellt
und vor Neustart auf Plist-Gleichheit geprüft. Die ursprüngliche Vordergrund-App
wurde wieder aktiviert. Alle eigenen Eingabe-, Wachhalte-, Build- und Profiljobs
sind beendet. Temporäre Preferences-Backups gelöscht; Produktquellen sonst unverändert.

PERF-011 bleibt VERIFY/BLOCKED: kleine CPU-Teilverbesserung, aber 10-%-Ziel nicht erfüllt
und keine vollständige Abnahme. PERF-012 hält den reproduzierten Debuganzeige-Absturz
fest. Vor einer vollständigen Performance-Freigabe sind diese Fehlerbehebung,
Beobachterlücken und fehlenden Live-Varianten erforderlich; Budgets werden nicht
nachträglich angepasst. Ein größerer Zoom-CPU-Gewinn ist weiterhin unbewiesen.
