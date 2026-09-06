# P02: CPU-Arbeit beim Zoomen untersuchen

## Fragestellung und Status

2026-09-05, Codex. Begrenzte Diagnose zu `inspect-current-p02` aus
[review-004](../2026-09-05-review-004/report.md). Keine Produktänderung,
kein Kandidat B, keine A/B- oder vollständige P02-Freigabe.

**Gesamtstatus: BLOCKED für vollständige Performance-Verifikation.**
CPU-Teilwiederholung und Stackprofil liefern einen konkreten Fix-Kandidaten.
Akzeptierte/abgeschlossene Einzelaktionen, erste sichtbare Reaktion,
Animationsabschluss und präsentierte Bildzeiten sind noch nicht zuverlässig
beobachtbar: [PERF-003 und PERF-004](../../backlog.md).
Die Diagnose ist keine Bestätigung vollständiger funktionaler Korrektheit.

Betroffen: P02, einzelne Shift-Pfeiltasten. Halten, Pinch, schnelle Umkehr,
Unterbrechung durch Navigation, Gruppen-/Suchzustand und große Referenzszene:
NOT RUN. Core-Smoke: NOT RUN, weil keine Produkt-, Abhängigkeits- oder
Buildänderung durchgeführt wurde. Dokumentation/Diagnoseartefakte selbst:
NOT APPLICABLE bezüglich neuer Produktfunktionen.

## Reproduzierbare Umgebung

- Signierte vorhandene Release-App `/Applications/OpenPlane.app`, 0.1 (2),
  Team `9FTHA7LGRQ`; kein Neubau und keine Installation.
- Binär-SHA256 `e7980cfbca7204c752b0d6527e09d37027ee8b9d7bf092010c74555937142277`:
  identisch mit review-004. Commit `09707146f1e93862bfb9e7b734681f28cd1e7020`;
  auch der nach der Pilotmethode berechnete Produkt-Diff-Hash stimmt überein.
  [Umgebung](environment.json), [vorhandener Produkt-Diff](source.diff).
- Apple M2 Pro, Mac14,10, macOS 26.6.2, internes Display 3456 × 2234 Retina,
  Netzbetrieb, keine von `pmset` gemeldete Thermal-/Performance-Warnung.
  Tatsächliche Bildwiederholrate nicht erfasst.
- Persönliche Live-Szene „Desktop 2“, andere Apps bleiben offen. Kein eingefrorenes
  S/R/L-Szenario. Sie unterscheidet sich vom Pilot auf „Hahaha“; daher **kein
  zahlenmäßiger Vorher/Nachher-Vergleich zulässig**, trotz identischem Build.
- Exportierte Preferences nur vorübergehend außerhalb des Repositorys gesichert.
  Hash und exakte Start-/Endkamera stehen in den JSON-Dateien. Keine persönlichen
  Fensterinhalte/Screenshots im Repository.
- Ein exklusiver Live-Test-Lock. Keine eigenen Builds oder Profiler während der
  CPU-Phasen. Stackprofil und Instruments-Versuche separat.

## Ausführung und Rohdaten

[Reproduktionsskript](diagnose.py) verwendet die vorhandenen Mach-CPU-Zähler und
sendet echte Tasteneingaben über System Events. Fokus und entsperrte Sitzung werden
geprüft. Erst 45 Herauszoom-Taps, zwei Sekunden Ruhe, gespeichertes Minimum 0,06
prüfen. Vor jedem CPU-Trial muss die gespeicherte Kamera exakt dem Reset entsprechen.
Das prüft den gespeicherten Endzustand, nicht die einzelnen sichtbaren Zwischenbilder.

Route: 45 Shift-Runter-Taps, angeforderte 50 ms Abstand, 500 ms Pause,
45 Shift-Hoch-Taps. Phasen: 5 s Idle vorher, Route, 1 s Nachlauf, 5 s Idle nachher.
Erste Route separat, danach zwei Aufwärmrouten und fünf gemessene Warmläufe.
„Erste Route“ bedeutet hier erste Route nach Reset im vorhandenen Prozess,
keine cache-kalte Messung. OS-/Preview-Caches und Fensteränderungen unkontrolliert.

- [CPU-Rohdaten](cpu.json): Phasen, PID, CPU-Sekunden, Dauer, Kamera und Status.
- [Stackprofil](sample.txt), [Profilablauf](sample.json), [Samplerlog](sample.log):
  23 Sekunden bei angefordertem 1-ms-Sampling, drei Routen mit zusammen 270 Taps.
  Sampling liefert Stackbeobachtungen, keine exakten CPU-Anteile oder Bildlatenzen.
- [Instruments-Versuch](profile.json), [Log](profile.log): keine verwertbare
  Time-Profiler-Aufzeichnung. Der erste Diagnosehelfer wartete auf einen anderen
  Starttext als den tatsächlich ausgegebenen und brach nach 25 Sekunden ab.
  Das ist eine Einschränkung dieses Diagnoseversuchs, kein belegter Produktfehler.
- [Bildzeit-Versuch](frames.json), [Log](frames.log): korrigierte Starterkennung,
  „Animation Hitches“, drei echte Zoomrouten. Instruments meldete nach 25 Sekunden
  das Aufnahmeende, schloss aber auch innerhalb der anschließenden Wartefrist
  nicht ab. Nach 40 Sekunden Wartezeit nach Ende der Eingaberouten wurde der
  eigene Prozess beendet. Beide Trace-Exporte scheiterten mit
  „Document Missing Template Error“. Keine verwertbaren Bildzeitdaten;
  Ursache des Instruments-Abschlussproblems ungeklärt, Folgearbeit PERF-003.
- [Aggregierte Stackbeobachtungen](sample-summary.json): inklusive Zählungen;
  verschachtelte Funktionen überlappen. Nicht addieren oder als CPU-% interpretieren.

Angeforderte Taps werden gezählt; Betriebssystemzustellung, vom Produkt akzeptierte
Eingaben und erfolgreich abgeschlossene Bewegungen bleiben `null`. Keine Division
von CPU-Zeit durch 90 als „CPU je erfolgreicher Aktion“.

## CPU-Teilergebnis

Fünf gemessene Warmläufe; 100 % entspricht einem CPU-Kern, nur OpenPlane.
[Auswertung](cpu-summary.json). B und A/B-Differenzen: NOT RUN, kein Kandidat.

| Größe | Median | Minimum–Maximum |
| --- | ---: | ---: |
| Idle vorher | 1,02 % | 0,86–1,35 % |
| Aktions-CPU | 25,51 % | 25,14–25,76 % |
| Zusätzliche CPU, pro Trial berechnet | 24,28 Prozentpunkte | siehe Rohdaten |
| Nachlauf-CPU | 1,15 % | 0,23–1,33 % |
| Idle nachher | 1,02 % | 0,82–1,29 % |
| Routendauer einschließlich Eingabehelfer | 7,205 s | siehe Rohdaten |

Alle acht Routen endeten mit derselben gespeicherten Kamera wie vor der Route.
Das bestätigt den persistierten Endzustand, keine fehlerfreie Darstellung während
der Bewegung. CPU je erfolgreicher Aktion, Reaktions-/Abschlusslatenz und
präsentierte Bildzeiten: BLOCKED, fehlende Beobachter. Speicher: NOT RUN als
vergleichende Messung; das Sampler-Footprint ist nur ein Diagnosewert.

## Profilbefund und Verbindung zum Code

1. `stepKeyboardTapZoom` setzt `camera` (CanvasView.swift:1656).
2. Der Setter ruft erst `updateSceneCamera()` auf und bei geändertem Zoom danach
   `synchronizeScene()` (Zeilen 399–400).
3. `updateSceneCamera` besitzt eine eigene Core-Animation-Transaktion
   (Zeilen 874–899). `synchronizeScene` besitzt ebenfalls eine Transaktion und
   ruft am Ende wiederum `updateSceneCamera` auf (Zeilen 1000–1038).
4. Das Profil enthält tatsächlich teure Commit-/Display-Pfade unter beiden
   Aufrufen. Beispielsweise führen 865 inklusive Beobachtungen unter dem ersten
   Kamera-Update und 1113 unter der Szenensynchronisation in den jeweiligen
   `CA::Transaction::commit`-Pfad. Das sind einzelne Stackbaum-Zweige, keine
   vollständigen oder unabhängig addierbaren CPU-Zeitmessungen.
5. Darunter liegen unter anderem CATextLayer-Zeichnung und Backing-Store-Arbeit.
   Karten-Textflächen ändern ihre Größe während des Zooms
   (`updateSelectionAppearance`, Zeilen 1262–1266). Das erklärt mögliche
   Textneuzeichnung trotz unverändertem Titelinhalt.
6. Das Raster wird bei geändertem Zoom neu rasterisiert (`updateGrid`, Zeilen
   922–942); der Zoom-Guard verhindert bereits die zweite Rasterisierung beim
   zweiten Kamera-Update desselben Zustands. Dieser Aufwand würde durch den
   vorgeschlagenen Fix nicht automatisch verschwinden.

**Belegt:** Zoom führt in diesen Darstellungspfad; Commit-/Zeichenarbeit ist im
Live-Profil sichtbar. **Hypothese:** Die separate erste Kamera-Transaktion erzeugt
vermeidbare Zwischenarbeit, bevor die Kartengeometrie desselben Zoomschritts stimmt.
Wie viel durch Zusammenfassung entfällt, ist unbewiesen. Nicht jede Textzeichnung
ist überflüssig: Titelgröße, Kürzung, Ränder und Zoomdarstellung müssen erhalten bleiben.

## Wichtige Einschränkung der Pilotroute

`CanvasMath.steppedZoom` (CanvasModel.swift:1050) nutzt den Faktor
`(maximumZoom / minimumZoom)^(1/5)`. Fünf reguläre Zielschritte reichen somit über
den gesamten Bereich 0,06–1,25. Bei 45 Taps je Richtung liegen viele Eingaben
potenziell bereits am begrenzten Ziel; die laufende Animation kann noch folgen.
90 Taps sind weder 90 sichtbare Zoomschritte noch zehn vollständige Zyklen.
Der neue Versuch bewahrt die alte Eingabefolge zur Diagnose; eine spätere
Abnahme muss tatsächliche Bewegungen und Grenz-No-ops getrennt zählen.

## Begrenzter Fix-Vorschlag und A/B-Abnahme

[PERF-011](../../backlog.md): Im Kamera-Setter bei Zoomänderung direkt
`synchronizeScene()` verwenden; nur bei unverändertem Zoom separat
`updateSceneCamera()` aufrufen. `synchronizeScene` aktualisiert die Kamera bereits
innerhalb seiner Transaktion. Zunächst nur diesen gemeinsamen Aufrufpunkt ändern.
Kein Textcache, keine Zoomdrosselung, keine geänderte Animation und kein Entfernen
sichtbarer Arbeit. Erst mit A/B-Messung entscheiden, ob der Versuch behalten wird.

Vor einem Fix-Versuch benötigen P02-Live-Fixture und Beobachter den begrenzten
Ausbau aus PERF-001/003/004. Ausgangspunkt ist eine **frische** Baseline derselben
Szene und Eingabemethode, nicht der hier gemessene persönliche Zustand.

Abnahme auf signierten Release-Apps aus `/Applications`:

- Gleiche feste Kamera/Anker, Szene, Displaybedingungen und Cachevorbereitung.
  Erste Verwendung separat, zwei Aufwärmläufe, fünf Paare A/B, B/A im Wechsel.
- Vollständige P02-Route mit zehn beobachteten Zyklen; Taps, Halten, Pinch,
  Umkehr/Loslassen, Unterbrechung, Gruppe und Suche separat. Grenz-No-ops
  separat von erfolgreichen Zustandsänderungen zählen.
- CPU-Phasen und CPU-Sekunden pro erfolgreichem Zyklus, erste sichtbare Reaktion,
  Abschluss, präsentierte Bildzeiten und Speicher erfassen. Beobachterkosten
  auf A und B gleich und separat kalibriert; Profile außerhalb dieser Läufe.
- Vorgeschlagenes Nutzensziel für diesen Versuch: mindestens 10 % weniger
  CPU-Sekunden je erfolgreichem Zyklus in mindestens vier von fünf Paaren,
  bei unveränderter Arbeitsmenge. Das ist ein Vorschlag, kein bestehendes
  Produktbudget und kein versprochener Gewinn. Große Streuung: INCONCLUSIVE.
- Keine verlorenen Eingaben, verlängerte Animation, zusätzliche Bildaussetzer,
  schlechtere Reaktion oder falsche Bilder. Grenzen, Anker, Raster, Titel,
  Kürzung, Ränder, Minimap, Auswahl und Vorschauen müssen stimmen.
- Core-Smoke gemäß Policy; wegen gemeinsamem Kamera-/Renderingpfad auch die
  betroffenen P01/P07/P06/P13-Varianten vorab konkret festlegen und prüfen.
  Bei fehlender Abdeckung bleibt die Freigabe BLOCKED.

Keine Baseline oder Board-Entscheidung wird durch diese Diagnose geändert.

## Abschluss

Alle vier Diagnoseaufrufe haben den Preferences-Export nach regulärem Beenden
von OpenPlane wieder importiert und vor dem Neustart auf vollständige
Plist-Gleichheit geprüft. Danach dieselbe installierte App gestartet und die
vorherige Vordergrund-App aktiviert. Temporäre Preferences-Backups gelöscht;
die Wiederherstellung ist in jedem Ablauf-JSON als `restored: true` erfasst.
Keine eigenen Eingabe-, Build- oder Profiljobs bleiben laufen.

Produktquellen und installierte Binärdatei unverändert. Nur Diagnoseartefakte,
dieser Bericht und der deduplizierte Backlog-Eintrag PERF-011 wurden ergänzt.
Syntaxprüfung des Diagnosehelfers und Artefakt-/Datenkonsistenz geprüft;
keine neuen Produkt-Unit-Tests erforderlich, da kein Produktcode geändert wurde.
