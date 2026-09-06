# PERF-012: Absturz der Zoom-Debuganzeige

Datum: 2026-09-06, Codex. Funktionaler Fix in isolierter Reproduktion und
Live-Zoomprüfung bestanden. Gesamt-Performance-Abnahme: **BLOCKED** wegen
fehlender Ereignis-/Bildbeobachter und vollständiger Fixtures/Varianten.
Nachverfolgung: [PERF-001, 003–007 und 012](../../backlog.md).

## Änderung und Ursache

Die Debuganzeige verwendet dieselbe 12-Punkt-Monospace-Semibold-Schrift jetzt als
gehaltene Instanz pro Canvas. Zuvor wurde sie für jeden Zeichendurchlauf erneut
angefordert. Der [exakte Produktfix](fix.diff) ergänzt ein Feld plus Kommentar
und ersetzt die Schriftanforderung durch dieses Feld. Keine neue Abhängigkeit,
kein neuer Cache mit Invalidierungsregeln. Farbe, Textformat, Position, Hintergrund,
Animation, Eingabeverarbeitung und Zoomgrenzen bleiben unverändert.

Der alte Fehler tritt bei `NSString.size(withAttributes:)` in
`CoreText TAttributes::ApplyFont` als `NSInvalidArgumentException` (nil-Eintrag in
internem Dictionary) auf. [Isolierte Reproduktion](reproduce.swift) funktioniert
auch ohne OpenPlane-Zoom oder Szenenrendering. Die [kontrollierten Varianten](isolate.swift)
zeigen bei jeweils bis zu 100.000 Textvermessungen:

| Variante | Ergebnis |
| --- | --- |
| Monospace-Schrift pro Autorelease-Zyklus neu anfordern | Zwei Versuche, beide SIGABRT |
| Gleiche Monospace-Schrift über die gesamte Schleife halten | Zwei Versuche, beide 100.000 erfolgreich |
| Attribute und Schrift halten | 100.000 erfolgreich |
| Konstanten Text mit kurzlebiger Monospace-Schrift verwenden | SIGABRT |
| ASCII-x statt × mit kurzlebiger Monospace-Schrift | SIGABRT |
| Normale Systemschrift statt Monospace-Schrift | 100.000 erfolgreich; kein Produktvorschlag |

[Exitcodes](isolation-controlled.json), zugehörige `fresh-0/1`, `font-0/1`,
`attributes-0`, `fixed-0`, `ascii-0`, `system-0.log` sind erhalten.
`isolation.json` stammt aus einem vorherigen, nicht trennscharfen Versuch, in dem
auch Kontrollvarianten eine Schrift gehalten hatten; es ist kein Gegenbeweis.
Die Lebensdauer-/Anforderungskombination ist experimentell eingegrenzt; die genaue
interne macOS-Fehlerursache ist nicht bewiesen.

## Umgebung und Durchführung

[Commit, Dirty-Diff-Hash und Binärhashes](environment.json),
[vollständiger Produkt-/Test-Diff](source.diff), [Buildlog](build.log).
A enthält bereits die vorherige kleine Kamera-Aufräumänderung, B zusätzlich
nur den hier beschriebenen Produktfix. Beide als signierte Release-App unter
`/Applications/OpenPlane.app` ausgeführt; Signatur bei Installation geprüft.

- A: `c2d7f7dce2e109060dc68928f4fddebc83290c0e8db98fb846556a96b5b01fdc`.
- B: `1d35c809d486ab90f43904bb137c8d94186cd277fbe68191539d314057e42bd3`.
- Dieselbe Maschine wie im [vorigen Bericht](../2026-09-05-p02-fix/report.md):
  Mac14,10/M2 Pro, macOS 26.6.2, 3456 × 2234 Retina. Tatsächliche Bildrate und
  Hintergrundlast nicht kontinuierlich erfasst; frühere Strom-/Thermalangaben
  sind keine neue Messung für diesen Lauf.
- Persönliche Szene Desktop 2; Debuganzeige ausdrücklich **eingeschaltet**.
  Pro Variante eigener Preferences-Export und pro Prozessstart Wiederherstellung.
  Export-Hashes zwischen A und B verschieden: keine identische versionierte
  A/B-Fixture. Live-Fenster und Vorschaubilder unkontrolliert. Startkamera in den
  Routen identisch: Zoom 0,06, Zentrum `[1587.5938992302272, 10343.562891205906]`.
- [Live-Helfer](verify-live.py): fünf geplante Prozessstarts je Variante,
  je erste Route, zwei Aufwärmrouten und eine gemessene Warmroute. Neustart ist
  nicht OS-cache-kalt. Zunächst A, dann B; **keine fünf alternierenden A/B-Paare**.
- Je Route 45 native Shift-Abwärts-Taps, 0,5 s Pause, 45 Shift-Aufwärts-Taps.
  Tastendruck etwa 10 ms, zusätzliche Pause 50 ms. Gemessene Route etwa 6,6 s.
  Vor Warmmessung 5 s Idle, danach 1 s Nachlauf und 5 s Idle. CPU aus bestehendem
  Prozess-CPU-Zähler, 100 % entspricht einem Kern, nur OpenPlane-Prozess.
- Exklusiver Live-Test-Lock, entsperrter Desktop, Fokusprüfung, `caffeinate`.
  Keine eigenen Builds/Profiler während CPU-Läufen. Screenshots im separaten
  Smoke-Durchlauf. Beobachterkosten nicht separat kalibriert.

## Funktionale Ergebnisse

**Vorher:** [A-Rohdaten](live-A.json) enthalten acht abgeschlossene Routen über
zwei Prozesse. Im dritten Prozess (PID 1912) trat wieder der bekannte Absturz
auf; [frischer Crashbericht](OpenPlane-2026-09-06-003613.ips),
[extrahierter Stack](baseline-crash.json). Der Helfer meldete „Focus lost before
key event“; hier ist das durch den Crash erklärt, nicht durch einen gesperrten Desktop.

**Nachher:** [B-Rohdaten](live-B.json): fünf frische Prozesse, 20 vollständige
Routen, alle mit korrektem gespeichertem Kamera-Endzustand und ohne Helferfehler.
1.800 Taps wurden gepostet. Das sind **nicht 1.800 nachgewiesene Zoombewegungen**:
Annahme und Abschluss einzelner Eingaben fehlen, und viele Taps liegen schon an
der Zoomgrenze. Deshalb keine CPU-Sekunden je erfolgreicher Einzelaktion.

[84 Tests bestanden](tests.log), einschließlich neuem Regressionstest mit
1.200 Debug-Neuzeichnungen bei wechselndem Zoom. Unterschiedliche Bilddaten
am Anfang und Ende prüfen zusätzlich, dass die Anzeige nicht eingefroren wurde.

Separater [Live-Smoke mit Debuganzeige](smoke-debug-on-B.json): P01/P02/P03/P05/P06/P14
als Teilmengen; P04 ohne sichere App-Startfixture BLOCKED. Zoomgrenzen 0,06 und
1,25 sowohl mit Taps als auch mit jeweils vier Sekunden gehaltenen Zoomtasten
erreicht. Richtungswechsel und Pfeil-Unterbrechung zusätzlich angestoßen, deren
Einzelabschlüsse nicht instrumentiert. Screenshots visuell geprüft: korrektes
`Zoom 0.06×` bzw. `Zoom 1.25×`, gleiche Box, Schrift und Position. Persönliche
Screenshots verbleiben außerhalb des Repositorys, Pfade in den Smoke-Rohdaten.

## CPU-Teilbeobachtung

Mediane der Warmmessungen, [Einzelwerte und Streuung](summary.json).
A umfasst nur die zwei überlebenden Messungen, B fünf; daraus lässt sich kein
belastbarer Performancegewinn oder eine Regression ableiten.

| Phase | A, n=2 | B, n=5 |
| --- | ---: | ---: |
| Idle vorher, % eines Kerns | 1,86 | 2,28 |
| Aktion, % eines Kerns | 26,05 | 26,47 |
| Zusätzliche CPU, Prozentpunkte; Median der Trial-Differenzen | 24,19 | 24,58 |
| Idle nachher, % eines Kerns | 2,19 | 1,78 |
| Aktions-CPU Minimum–Maximum | 25,98–26,12 | 25,02–27,13 |

Reaktions-/Abschlusslatenz, präsentierte Bildzeiten und Physical Footprint:
**BLOCKED/NOT RUN**, fehlende kalibrierte Beobachter. AX-Startzeit im Smoke ist
nur grobe Start-bis-AX-Erreichbarkeit, keine erste sichtbare Reaktion.
P02-Pinch/Zeigerpfade, P13 Live-Umschaltung aller Debug-/Darstellungsvarianten,
S/R/L-Fixtures und vollständiger Core-Smoke bleiben offen (Backlog oben).
Kein voller 14-Fälle-Nachweis und keine neue Performancebaseline.

## Entscheidung und Abschluss

Den kleinen Stabilitätsfix behalten: klarer Vorher-Absturz, reproduzierbarer
isolierter Gegenversuch und erfolgreicher Kandidaten-Livelauf. PERF-012 bleibt
VERIFY hinsichtlich vollständiger Performance-Abnahme; der reproduzierte
Absturz ist in den geprüften Pfaden behoben. Keine Behauptung eines Zoom-CPU-Gewinns.

Die zuvor akzeptierte minimale Kamera-Aufräumänderung bleibt erhalten; dieser
Optimierungsansatz ist als ausgeschöpft dokumentiert (PERF-011). Größere
Zoom-Rendering-Änderungen sind nicht Bestandteil dieser Arbeit und werden erst
mit dem Nutzer gesondert besprochen.

Die geprüfte Release-Version B bleibt installiert. Die Helfer stellen die
ursprünglichen Einstellungen jeweils wieder her und prüfen den kompletten
Preferences-Export vor dem Neustart auf Gleichheit. Abschließende Hash-,
Signatur-, Prozess- und Crashprüfung siehe `completion.json`.
