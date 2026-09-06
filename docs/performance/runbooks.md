# Live-Performance-Runbooks

Alle Fälle verwenden die [gemeinsame Messvorschrift](policy.md). Die Angaben
unten sind Testdefinitionen, keine Behauptung einer vorhandenen Automatisierung.
Ein Runbook wird erst ausgeführt, wenn seine Fixture, Eingabe und Beobachter
bereit sind. Rohdaten und Status gehören in einen [Bericht](report-template.md).

Ein ausführbarer [Live-Pilot und Entscheidungs-Dashboard](../../review-desk/README.md)
erfasst inzwischen Teilmengen von sieben Familien. Dessen aktuelle Messungen
stehen in `results/`; alle nicht abgedeckten Kriterien bleiben ausdrücklich offen.

## Abdeckung und Ausführungsumfang

| ID | Funktionsfamilie | Stand |
| --- | --- | --- |
| P01 | Räumliche Pfeiltasten-Navigation, Auswahl und Navigator | CPU-Burst teilautomatisiert; Endzustände/Latenzen fehlen im Runner |
| P02 | Zoomen: Tastatur und Pinch, Unterbrechen und Grenzen | Pilot für Tastatur-Taps; Halten/Pinch und vollständige Messung fehlen |
| P03 | Laufende App aktivieren und zu OpenPlane zurückkehren | Finder-Rückkehrpilot; genaue Bereitschafts-/Latenzmessung fehlt |
| P04 | Geschlossene Apps starten, dieselbe/verschiedene/alle | Runbook; sichere App-Fixture und Startmessung fehlen |
| P05 | OpenPlane-Prozess starten und beenden | Pilot bis AX-Canvas; vollständiger Startbeobachter fehlt |
| P06 | Zwischen OpenPlane-Desktops wechseln | Tab-CPU-Pilot; vollständiger Live-Messadapter fehlt |
| P07 | Kamera verschieben, Minimap, gespeicherte Ansicht | Runbook; Maus-/Trackpad-Messadapter fehlt |
| P08 | Karten und Gruppen auswählen, verschieben, Auswahlrahmen ändern | Runbook; Live-Messadapter fehlt |
| P09 | Suchen, Ergebnisse navigieren und öffnen | Such-CPU-Pilot; Ergebnis-/Latenzbeobachter fehlt |
| P10 | Fenster entdecken, Vorschauen erneuern, schließen und wiederöffnen | Runbook; kontrollierte Fensterquelle fehlt |
| P11 | Ausgewählte App beenden und geschlossene Karte weiterverwenden | Runbook; sichere App-Fixture fehlt |
| P12 | Desktops anlegen/umbenennen, viele Tabs, Zustände speichern | Runbook; Live-Messadapter fehlt |
| P13 | Einstellungen, Darstellung und alternative Shortcut-Pfade | Runbook; Variantenmanifest fehlt |
| P14 | Leerlauf und längere gemischte Nutzung | 60-Sekunden-Idle-Pilot; Dauerlauf-/Speicherbeobachter fehlt |
| P15 | Chronological Mode, Fokusverlauf, Moduswechsel und Command-Tab | Kurzer Live-Funktionstest; vollständige Messadapter fehlen |
| P16 | All apps, Rückkehr und Fensteraktionen | Kurzer Katalog-/Starttest; vollständige Fixtures/Messadapter fehlen |

**Core-Smoke pro Produktänderung:** je ein kurzer Live-Durchlauf von P01
(100 Tasten), P02 (ein voller Zoomzyklus plus Umkehr), P03 (drei Hin-/Rückwechsel),
P04 (ein Test-App-Start), P05 (ein OpenPlane-Start), P06 (zehn Desktop-Wechsel)
und P14 (30 Sekunden Leerlauf). Das findet grobe Regressionen und ersetzt keine
vollständigen Wiederholungen der vom Change betroffenen Fälle.

**Vollständige Prüfung:** erste Verwendung, zwei Aufwärmläufe und fünf gepaarte
Warmläufe gemäß Policy; Startfälle nach ihrer eigenen Zustandsdefinition.
Varianten nicht zu einem einzigen Durchschnitt zusammenwerfen. Pro Variante
Erfolgskriterien abgleichen. Bei einer neuen Funktion hier einen Fall mit ID,
Eingaben, Szenario, Abschluss und Metriken ergänzen, bevor sie als abgedeckt gilt.

## P01 – Hin- und Herfahren zwischen Karten

- **Setup:** R auf beiden Desktops; offene Fenster und geschlossene Karten,
  mehrere Fenster derselben App, Gruppe/Suche zunächst aus. Ausgangskarte und
  Kamera je Lauf exakt setzen. Ein zweiter Durchgang verwendet L.
- **Eingaben:** 25-mal Rechts, Runter, Links, Hoch, insgesamt 100 Tastendrücke
  mit angeforderten 80 ms Abstand. Separat die feste Referenzroute durch alle
  Karten laufen; zufälliges Hin und Her besucht nicht automatisch jede Karte.
- **Varianten:** 40 ms schnelle Links-/Rechts-Umkehr; echte gehaltene Taste mit
  dokumentierter Wiederholrate; Rand ohne Nachbar; gleicher App-Prozess versus
  andere App; offene/geschlossene Karte; bestehende Gruppe; beide Auswahl-
  Animationsmodi. Reale Zustellintervalle und wirklich wechselnde Ziele zählen.
- **Abschluss/Korrektheit:** richtige Karte markiert, Kamera am richtigen Ziel,
  Titel/Icon/Navigator/Minimap aktuell. Am Rand unverändert; kein App-Start.
  Unterbrochene Animation ohne Sprung und ohne unbeabsichtigte Zoomänderung.
- **Messen:** CPU-Phasen, CPU-Sekunden pro Zustellung und erfolgreichem Wechsel,
  erste Auswahlreaktion, Kameraruhe, Bildzeiten, Speicher nach Wiederholungen.

Vorhandener Teiltest, **nur wenn genau die beiden benannten Desktops vorliegen**:

```sh
python3 scripts/measure-navigation.py /tmp/openplane-navigation-run.json --trials 5
```

Der Runner verwendet aktuell fest `Hahaha` und `Desktop 2`, 100 Tasten, fünf
Sekunden Idle vorher/nachher und eine Sekunde Nachlauf. Er prüft Sitzung/Fokus
und Desktopname, aber setzt Auswahl/Kamera nicht pro Trial zurück, wärmt nicht
explizit auf und misst keine Einzelereignis- oder Bildlatenzen. Deshalb ist er
ein CPU-Teiltest und noch kein vollständiger Policy-Runner. Aufwärmen/Reset und
sichtbare Erwartungen bis zur Erweiterung separat kontrollieren und protokollieren.

## P02 – Voll hinein- und herauszoomen

- **Setup:** R, dann L; Start bei minimalem Zoom, feste Kamera/Ankerposition.
  Aktuelle Grenzen: 0,06 bis 1,25, vor dem Lauf gegen die getestete Version prüfen.
- **Eingaben:** Shift-Runter halten bis zur oberen Grenze, loslassen, 500 ms
  warten; Shift-Hoch halten bis zur unteren Grenze, loslassen, 500 ms warten.
  Zehn vollständige Zyklen pro Messlauf. Nie eine feste Wartezeit als Beweis für
  das Erreichen einer Grenze nehmen; Zoom/Endzustand beobachten.
- **Varianten:** einzelne Taps statt Halten; gleichwertige echte Pinch-Gesten;
  fünf schnelle Richtungswechsel vor dem Endpunkt; Zoom anschließend sofort mit
  Pfeilnavigation unterbrechen; ausgewählte Gruppe und Suchanzeige separat.
  Unterschiedliche Fenster-/Vorschaugrößen und nicht-binäre Zoomwerte einbeziehen.
- **Abschluss/Korrektheit:** Grenzwerte werden eingehalten, Anker bleibt korrekt,
  keine klemmenden Modifikatortasten, kein Nachzoomen nach Key-up/Gestenende.
  Raster, Titel, Ränder, Minimap und Auswahlrahmen passen während/nach dem Zoom.
- **Messen:** Reaktion auf Anfang/Umkehr/Loslassen, Zeit bis Grenze und Ruhe,
  Bildzeiten über den gesamten Zoomweg, CPU und Speicher pro Zyklus. Erste
  Raster-/Textvorbereitung getrennt von warmen Zyklen ausweisen.

Begrenzter CPU-Vergleich für PERF-011: 45 einzelne Shift-Runter-Taps mit
angeforderten 50 ms Abstand, 500 ms Pause, 45 Shift-Hoch-Taps. Vor jeder
installierten Variante dieselben gesicherten Preferences wiederherstellen und
das gespeicherte Minimum 0,06 mit identischer Kamera prüfen. Erste Route und
zwei Aufwärmrouten separat; danach eine gemessene Route mit den Standardphasen.
Fünf A/B-Paare, Reihenfolge alternierend. Erwartung: identische Endkamera,
unveränderte Darstellung und Animation; angeforderte Taps sind keine gezählten
abgeschlossenen Zoomschritte. Persönliche Live-Fenster und OS-Caches sind dabei
unkontrolliert. Diese CPU-Teilroute ersetzt weder die zehn Zyklen noch Halten,
Pinch, Umkehr, Gruppen-/Suchvarianten oder die Bild-/Latenzprüfung oben.

Wiederaufnahme PERF-011 (2026-09-06): Wegen Abbrüchen im Debug-Textpfad wird
zusätzlich `showDebugInformation=false` auf **beiden** Builds als eigene Variante
gemessen; ursprüngliche Einstellung danach wiederherstellen. Nicht mit der
eingeschalteten Anzeige vergleichen oder als deren Fehlerbehebung werten.
Der direkte CGEvent-Helfer sendet je Tap Key-down, 10 ms später Key-up und wartet
50 ms; Shift ist im Ereignis gesetzt. Posting-Zeitstempel und Vordergrund-PID
werden pro Tap erfasst/geprüft. Das beweist Posting, nicht Annahme oder sichtbaren
Abschluss. Die übrigen Phasen, Kamera-Resets und A/B-Vorgaben bleiben gleich.

Zusätzliche Regression PERF-012 (P02/P13): Debuganzeige explizit einschalten,
gleichen persönlichen oder versionierten Szenenstart auf A/B verwenden. Fünf
Prozessstarts mit je erster Route, zwei Aufwärmrouten und gemessener Tap-Route
wie oben. Anzeige muss bei wechselndem Zoom ihren formatierten Wert aktualisieren;
Font, Farbe, Position und Hintergrund bleiben erhalten. Prozessende/Crashberichte
nach PID mitzählen und bei Absturz abbrechen, nicht als Fokusproblem aussortieren.
Grenzwerte und Darstellung separat im Live-Smoke prüfen. Originale Einstellung
wiederherstellen. CPU-Phasen/Posting-Zeitstempel bleiben Teilmessungen; ohne
Frame-/Latenzbeobachter keine volle Abnahme. Halten/Pinch sowie Ein-/Ausschalten
und erneutes Aktivieren der Anzeige gehören zu den vollständigen Varianten.

## P03 – Bereits laufende App öffnen und zurückwechseln

- **Setup:** Test-App mit eindeutigem Fenster läuft und ist bedienbereit.
  OpenPlane zeigt ihre Karte; keine Start-/Netzwerkdialoge im Testinhalt.
- **Eingaben:** Return auf die Karte; nach bestätigter Zielbereitschaft über
  Control-Option-Space zurück. Zehnmal dieselbe App, dann eine feste Runde durch
  alle laufenden Test-Apps; Reihenfolge zwischen Paaren kontrolliert wechseln.
- **Varianten:** Mausklick auf Karte; Navigator-Klick; nächstes Fenster derselben
  App; Zurück/Vorwärts; Hover-Vorschau; Rückkehr über Dock und, falls aktiviert,
  Command-Tab. Minimiertes Fenster separat von normal sichtbarem Fenster testen.
- **Abschluss/Korrektheit:** richtige App **und** richtiges Fenster vorne und
  per harmloser Testinteraktion bedienbar. Rückkehr zeigt die erwartete Kamera
  und Auswahl. „Prozess ist frontmost“ allein ist kein Beleg für Bedienbarkeit.
- **Messen:** OpenPlane-Eingabe bis Fokusübergabe, bis sichtbarem Ziel und bis
  Bedienbarkeit getrennt; Rückkehr bis nutzbarem Canvas; OpenPlane-CPU und Ziel-
  App-CPU separat, Übergangsbilder/Fehler. Das sind Aktivierungszeiten, keine Starts.

## P04 – Geschlossene Apps starten

- **Setup:** Manifest sicherer Test-Apps mit Bundle-ID, Version, lokalem
  Testdokument, Bereitschaftsmerkmal und Timeout. Standard-Timeout zunächst
  30 Sekunden, abweichende App-Verträge im Manifest. Kein ungesicherter Inhalt.
  Prozessabwesenheit und geschlossene Karte vor jedem Neustart bestätigen.
- **Route A:** dieselbe Test-App fünfmal starten und dazwischen regulär beenden;
  erst weiter, wenn Prozess beendet und OpenPlane-Karte geschlossen ist.
- **Route B:** mehrere unterschiedliche Apps nacheinander starten, jede erst
  nach Bereitschaft der vorherigen. Zwischen Läufen festgelegten Zustand herstellen.
- **Route C:** jede startbare App des Szenarios einmal öffnen; mindestens fünf
  Runden, Reihenfolge dokumentiert rotieren. Mehrere Fenster derselben App
  erzeugen keinen zweiten Prozessstart. Nicht startbare Karten begründet ausweisen.
- **Zusatz:** drei unabhängige Starts über die Live-Oberfläche rasch anstoßen;
  parallel laufende Starts separat auswerten, nicht mit seriellen Starts mitteln.
- **Cachebedingungen:** Prozess-Neustart mit möglicherweise warmem OS-Cache,
  erste Verwendung nach Boot, vorhandene versus neue OpenPlane-Vorschau separat.
  Nicht dieselbe App zehnmal aktivieren und das als zehn Starts berichten.
- **Abschluss/Korrektheit:** Startauftrag, Prozessstart, erstes Ziel-Fenster und
  app-spezifische Bedienbarkeit als getrennte Zeitpunkte. Dummy-Fenster oder
  Splash-Screen zählen nicht als fertig. Prozess-PIDs über den Start neu ermitteln.
- **Messen:** Mittelwert/Median/Min/Max **pro App**, Erfolg/Timeout sowie Runde bis
  letzte App bereit. Ein Gesamtmittel nur zusätzlich, mit App-Mix und Gewichtung.
  CPU bis Bereitschaft, OpenPlane-Anteil getrennt vom Zielprozess und dessen
  Hilfsprozessen. Netzwerkabhängige Inhalte als eigene Variante behandeln.
- **Diagnose:** gleiche Test-App zusätzlich über Dock unter gleichen Bedingungen
  starten. Der Vergleich kann OpenPlane-Anteil eingrenzen, beweist aber wegen
  unterschiedlicher Startpfade nicht automatisch eine bestimmte Ursache.

## P05 – OpenPlane selbst starten

- **Setup:** OpenPlane-Prozess beendet; gespeicherte R- beziehungsweise L-Szene,
  Bildschirmrechte bereits erteilt. Ziel-Apps bleiben in manifestiertem Zustand.
- **Eingaben:** installierte App über Dock/Finder starten. Fünf frische Prozesse
  je Variante, jeweils regulär beenden; OS-Cachezustand korrekt benennen.
- **Varianten:** erster Start mit leerem Testprofil/Einrichtung separat, bestehendes
  Profil mit vielen Karten, erster Start nach Boot, erneutes Anzeigen des bereits
  laufenden Canvas als eigener P03-Rückkehrfall. Berechtigungsdialoge und menschliche
  Wartezeit gehören nicht in den normalen Startdurchschnitt.
- **Abschluss:** sichtbares Canvas, erste richtige Auswahlreaktion, vollständige
  erwartete Vorschauen und Hintergrundberuhigung einzeln messen. Fehlende/absichtlich
  geschlossene Vorschauen müssen gegen Manifest statt gegen „alle nicht leer“ geprüft werden.
- **Messen:** Launch-Ereignis bis jeden Meilenstein, kumulierte Prozess-CPU ab
  Prozessstart, Peak-/Ruhe-Speicher, Timeouts und wiederhergestellte Einstellungen.
  Ein beendeter Prozess hat keinen messbaren Idle-CPU-Wert: vorher `N/A`, nachher messen.

## P06 – OpenPlane-Desktops wechseln

- **Setup:** zwei unterschiedlich angeordnete Desktops mit verschiedenen Zooms.
- **Eingaben:** 50 Wechsel Tab/Shift-Tab mit 350 ms Abstand; separat 50 Wechsel
  mit 80 ms Abstand während der laufenden Überblendung; zusätzlich Tab-Klicks.
- **Abschluss/Korrektheit:** Desktop-Titel, Karten, Auswahl und gespeicherte Kamera
  gehören zum richtigen Desktop. Einzelne Tab-/Shift-Tab-Anschläge während der
  Überblendung werden in Eingabereihenfolge abgearbeitet. OS-Autorepeat bleibt
  ignoriert. Zugestellte und abgeschlossene Wechsel getrennt zählen; nach dem
  letzten Tastendruck auf das vollständige Abarbeiten warten. Titel-/Sucheditor
  respektieren. Am Listenende bleibt das bisherige zyklische Verhalten erhalten.
- **Messen:** akzeptierter Wechsel bis vollständig bedienbarer Desktop, CPU pro
  akzeptiertem Wechsel, Bildaussetzer, Speicher und Nachlauf/Persistenz.

## P07 – Freie Kamerafahrt und Navigator

- **Setup:** R/L, festes Zoom, Kamera-Startpunkt und gespeicherte Ansicht.
- **Eingaben:** zehn horizontale/vertikale Zwei-Finger-Pan-Fahrten gleicher
  Strecke/Dauer; zehn Minimap-Klicks auf feste Punkte und zehn Minimap-Drags.
  Ansicht speichern/sperren, wegfahren und über den vorhandenen UI-Pfad zurückkehren.
- **Abschluss/Korrektheit:** Weltpositionen der Karten unverändert; Minimap und
  Kamera synchron; gespeicherte Ansicht korrekt. Hover-Vorschau und History
  zeigen aktuelle Titel/Icons und öffnen weiterhin die richtigen Fenster.
- **Messen:** Eingabe bis Kamerareaktion, Ende bis Ruhe, Bildzeiten, CPU und
  Speicher; Navigator-Hover/Fade und History separat zu P03 protokollieren.

## P08 – Auswählen, Verschieben und Gruppieren

- **Setup:** offene und geschlossene Karten; Gruppen von 1, 5 und 20 Elementen,
  unterschiedliche Vorschaugrößen, jeweils kleines/mittleres/großes Zoom.
- **Eingaben:** Shift-Klick/Shift-Return an/aus; Rechteckauswahl; Einzelkarte und
  Gruppe je zehnmal auf fester Route ziehen, auch aus dem Zwischenraum der Gruppe;
  Auswahlrahmen an Kanten/Ecken ziehen und loslassen. Gruppe während Kamerafahrt ändern.
- **Abschluss/Korrektheit:** richtige Gruppenmitgliedschaft; grüner Rahmen folgt
  sichtbaren Grenzen und rastet beim Loslassen ein; Karten bewegen sich ohne App-
  Aktivierung. Rahmenänderung ändert die Auswahl und darf nicht still als Skalieren
  echter App-Fenster interpretiert werden. Positionen nach Neustart erhalten.
- **Messen:** erste Drag-/Auswahlreaktion, Bildzeiten während Drag, CPU je Gruppengröße,
  Loslassen bis Ruhe/Speicherung, Speicher. Keine billigere Darstellung auf Kosten
  falscher Gruppenränder oder verlorener Persistenz als Gewinn akzeptieren.

## P09 – Suche

- **Setup:** feste Suchbegriffe für viele/ein/kein Ergebnis, gemischte offene und
  geschlossene Karten, mehrere Fenster einer App. Ausgangssuche leer.
- **Eingaben:** je zehnmal langsam und schnell tippen, löschen, Up/Down navigieren,
  per Return öffnen und zurückkehren, Escape; Paste und lange Anfrage als Varianten.
- **Abschluss/Korrektheit:** erwartete Treffer und Dimmung; geschlossene Karten
  bleiben normal dargestellt; leere Suche dimmt nichts. Backspace löscht Text
  und beendet keine App. Ergebnisöffnung erfüllt P03 oder P04.
- **Messen:** zugestellte Eingabe bis korrektem Treffer-/Highlightbild, CPU pro
  Query, Bildzeiten und Speicher nach zehn kompletten Suchzyklen.

## P10 – Fensterbestand und Live-Vorschauen

- **Setup:** kontrollierte lokale Test-App/Fenster mit sichtbarer laufender Uhr
  oder Zähler; initiale Fensteranzahl und erwartete Vorschauzustände dokumentiert.
- **Eingaben:** Fenster einzeln und im Burst öffnen, Titel/Inhalt ändern, minimieren,
  wiederherstellen und schließen; jeweils zehn Zyklen. Währenddessen P01/P02 ausführen.
- **Abschluss/Korrektheit:** Fenster erkannt/entfernt, Kartenposition erhalten,
  Vorschau zeigt den neuen Zähler/Titel; erlaubte Redaktionen bleiben wirksam.
  Geänderte Titel/Icons dürfen nicht wegen eines Caches veralten.
- **Messen:** echtes Fensterereignis bis Canvas-Reaktion und Vorschau-Frische,
  CPU im ruhigen Zustand versus Änderungsburst, Speicher/Peak, Navigationseinbußen.
  Update-Frequenz und Netz-/Videoquelle festlegen, damit A und B dieselbe Arbeit sehen.

## P11 – App beenden

- **Setup:** dedizierte entbehrliche Test-App ohne ungesicherte Nutzerdaten.
- **Eingaben:** zehnmal öffnen, markieren, Backspace einmal drücken, Beendigung
  beobachten; Tastaturwiederholung und bereits geschlossene Karte separat prüfen.
- **Abschluss/Korrektheit:** richtige App beendet, geschlossene Karte am erhaltenen
  Ort; andere Apps unverändert. Gesonderter Test mit lokalem Dummy-Dokument und
  Speicherdialog: Abbrechen funktioniert; Dialogwartezeit separat melden.
- **Messen:** Eingabe bis Quit-Anforderung und geschlossener Karte, CPU/Nachlauf;
  erneuter Start über P04. Keine erzwungenen Prozessabbrüche für schnellere Werte.

## P12 – Desktops bearbeiten und speichern

- **Setup:** zwei und zwölf Desktop-Tabs; ausschließlich Testprofil.
- **Eingaben:** Desktop anlegen, umbenennen, Textcursor bedienen, Tab-Leiste
  horizontal scrollen, wechseln; zehn Bearbeitungszyklen. Kamera/Karten ändern,
  während einer Bewegung regulär beenden und wieder starten.
- **Abschluss/Korrektheit:** Namen, Reihenfolge und individuelle Anordnung/Kamera
  gespeichert; Tab im Texteditor wechselt nicht unbeabsichtigt den Desktop.
- **Messen:** Eingabe bis sichtbarer Änderung, Nachlauf/Speicherarbeit, Start-
  Wiederherstellung über P05; keine Schreiblast proportional zu jedem Animationsbild.

## P13 – Einstellungen und alternative Bedienpfade

- **Setup:** Manifest aller vorhandenen Navigator-/Settings-Menüpunkte und
  Standardwerte; jeden neuen Menüpunkt hier ergänzen.
- **Eingaben:** Menü/Popover zehnmal öffnen/schließen; Hintergrundfarbe, gespeicherte
  Ansicht, Landscape-Vorschauen, Debuganzeige, Center Guide, Auswahlanimationsmodus,
  geschlossene Karten, private Vorschauen und Command-Tab-Einstellung jeweils
  ändern und zurücksetzen. Betroffene P01/P02/P03/P10-Variante danach ausführen.
- **Abschluss/Korrektheit:** sichtbare Einstellung, Speicherung, Shortcut-Routing
  und Zugriffsschutz stimmen. Für private Vorschauen nur lokale Dummy-Inhalte.
- **Messen:** Öffnen und Einstellung bis sichtbarer Wirkung, CPU/Idle-Nachlauf,
  Speicher nach Wiederholung. Debug-Overlay bleibt für Baseline/Kandidat gleich;
  dessen eigener Aufwand wird separat geprüft.

## P14 – Leerlauf und gemischte Dauernutzung

- **Setup:** R, danach L; 60 Sekunden sichtbarer Leerlauf ohne Eingabe; separates
  Intervall mit laufender Test-App im Vordergrund und OpenPlane im Hintergrund.
- **Eingaben:** zehn gleiche Runden P01-Navigation, ein Zoomzyklus, P03-Aktivierung
  und Rückkehr, Desktop-Wechsel, Suche und Drag; feste Reihenfolge protokollieren.
- **Abschluss/Korrektheit:** je Runde erwarteter Zustand; am Ende 30 Sekunden
  Ruhe. Keine weiterlaufenden Kamera-Timer, festhängenden Tasten oder Testprozesse.
- **Messen:** CPU je Phase, Speicher nach Aufwärmen/jeder Runde/Nachruhe, Wakeups
  falls Beobachter vorhanden, Rückkehrlatenz und Fehler. Monotones Wachstum oder
  dauerhaft erhöhte Idle-CPU als eigene Aufgabe untersuchen.

## Abbruch und Wiederherstellung für alle Fälle

Bei Sperre, unerwartetem Fokusverlust, falscher Fixture, menschlicher Interaktion,
Dialog oder abgestürztem Beobachter Eingaben sofort stoppen; bereits erzeugte
Daten mit Abbruchgrund behalten. Einzelereignisse nicht in den nächsten Lauf
weiterlaufen lassen. Tasten/Gesten lösen, eigene Testjobs regulär beenden,
Testfenster schließen und gesicherten Nutzerzustand wiederherstellen. Abschließend
korrekte installierte Version und das Ende aller eigenen Jobs kontrollieren.

## RD01 — Review Desk decision list (browser companion)

Fixture: local server on an isolated port and a disposable `--state-dir`, using a
completed run with proposals. Never save QA decisions into the user's workspace.
Open the list at desktop and narrow widths; expand/collapse each proposal with
pointer and keyboard; select, save and reload each decision; verify the comment,
audit and source report. Open a historical run and a raw case; create a disposable
review request. Discuss a proposal including an unsaved question: verify the copied
text includes run/proposal IDs, original evidence, limitations, dependencies and
question. Verify the originating Codex conversation opens, then manually paste;
no agent or implementation may start merely from selection. If clipboard access
fails, verify the manual-copy dialog. Browser security blocks are reported, never
bypassed. Do not submit the QA context to a live agent.

Performance: record a first load separately, then five warm page loads and five
paired idle/action trials of expand, save and context preparation, preserving raw
input-to-visible timings and browser process CPU. Include observer overhead and
all rendered proposal content. API response time alone is not UI performance.
Current simplification: functional subsets executed; full performance comparison
BLOCKED pending a calibrated browser input-to-pixel/CPU observer. This companion
page does not change the native app; native P01–P14 results are not re-certified.


## Begrenzte Rasterkosten-Diagnose (PERF-013; P01/P02/P06/P13)

Gleicher Release-Build, gleiche gesicherte Szene, `Show Grid Dots` an/aus in
fünf alternierenden Paaren. Standard ist an. Abschalten dient ausschließlich
Kostenisolation und ist kein Optimierungserfolg. Debuganzeige in beiden gleich.
Je Prozess/Fall erste Route, zwei Aufwärmrouten, eine gemessene Warmroute;
5 s Idle vorher, feste native Eingaberoute, 1 s Nachlauf, 5 s Idle nachher.
P02: 45 Shift-Abwärts-Taps, 500 ms, 45 Shift-Aufwärts-Taps wie PERF-011.
P01: wiederholte Pfeilrunde rechts/unten/links/oben bei sichtbarem Raster.
P06: gerade Anzahl Tab-Wechsel zwischen zwei Desktops mit verschiedenen Zooms
oberhalb 0,15, Enddesktop und beide Kameras prüfen. Startzustand zwischen Varianten
wiederherstellen; angeforderte/gepostete Eingaben und beobachtete Endzustände
getrennt zählen. Ohne Einzelabschluss-/Bildbeobachter bleibt die Abnahme BLOCKED.
Separat Menü an/aus/an per Live-Eingabe prüfen, Zoomgrenzen und Rasterausblendung
unter 0,15; Gedrückthalten, Richtungswechsel und Unterbrechung im Smoke.
Originale App-Einstellungen nach Messung wiederherstellen. Ersatzrenderer nur
nach gemessenem Nutzen untersuchen; identische Punkte, Weltverankerung, Größe,
Deckkraft und Schärfe über Zoom und Display-Skalierung sind Abnahmekriterien.


PERF-013 Anschlussversuch: 256er- gegen 128er-Kachel im sonst gleichen Build,
Raster auf beiden an; dieselben P01/P02/P06-Routen, fünf alternierende Paare.
An/Aus-Werte nicht als Vorher/Nachher verwenden. Rasterphase, Punktgröße,
Deckkraft, Schärfe und Kachelnähte separat bei 0,15/0,31/0,73/1,25 vergleichen.
Dieselbe vollständige Live-Abnahme bleibt erforderlich; fehlende Bild-/GPU-
Beobachtung als offen ausweisen, nicht aus CPU allein ableiten.


P06 Tempoangleichung (PERF-014): Desktopüberblendung verwendet dieselben 180 ms
wie App-Kartennavigation statt bisher 280 ms. Fünf alternierende A/B-Paare,
gleiche zwei Desktop-Kameras; sechs Tab-Wechsel pro Route mit beobachtetem
Desktop-ID-Wechsel und unveränderten Kameras. Erste Route und zwei Aufwärmrouten
separat, Standard-CPU-Phasen wie PERF-013. Zusatzprüfung: 50 Tab/Shift-Tab-Taps
mit angeforderten 80 ms Abständen, zugestellte Eingaben und beobachtete Wechsel
getrennt; während Überblendung ignorierte Tasteneingaben nicht als abgeschlossen
zählen. Tab-Klicks und Wiederherstellung separat. Die Zeitkonstante ist eine
konfigurierte Animationsdauer, keine gemessene präsentierte Bildlatenz.


P06 Direktüberblendung (PERF-015, ersetzt die Zwischenblende aus PERF-014):
Neuer Desktop samt Kamera/Layout wird sofort bereitgestellt. Core Animation
überblendet Szenen- und HUD-Inhalt direkt über 180 ms; keine einfarbige Abdeckung,
kein Kameraflug. Tabs bleiben bedienbar und wechseln zum Ziel. Kurzer Tagestest:
je ein Tab-/Shift-Tab-Hin/Rückwechsel auf Baseline/Kandidat, gespeicherte Kameras
und Zieldesktop prüfen, tatsächliche Übergangsbilder separat auf Überlagerung
statt Farbblitz prüfen. Vollständige Varianten, schnelle Eingaben, CPU-/Speicher-
und präsentierte Bildzeit-A/B-Prüfung NOT RUN: scheduled overnight (PERF-015).


P06 Eingabewarteschlange (PERF-016): Vier temporäre Desktops, unterschiedliche
Kamerazooms. Drei Tab-Anschläge mit 15 ms Pause zwischen 10-ms-Taps: vom ersten
über zweiten/dritten zum vierten Desktop; drei Shift-Tab zurück. Gemischt
Tab/Shift-Tab/Tab muss alle drei Richtungen der Reihe nach ausführen. Pro Schritt
unveränderte 180-ms-Direktüberblendung. Kein Zusammenfassen gegensinniger Schritte,
kein Überschreiben eines wartenden Tastendrucks. Temporäre Desktops danach über
vollständigen Preferences-Export entfernen und Originalzustand prüfen.
Kurzer Vorher/Nachher-Livecheck tagsüber, vollständige 50-Eingaben-/CPU-/Frame-/
Speicher- und Mischpfadprüfung NOT RUN: scheduled overnight (PERF-016).


P06 Richtungshinweis (PERF-017): Direkter Fade plus 40 logische Punkte Slide der
ankommenden Karten/Raster über dieselben 180 ms. Tab bewegt immer von links nach
rechts, auch vom letzten zum ersten Desktop. Die Eingaberichtung bleibt in der
Warteschlange erhalten. Direkte Klicks verwenden die tatsächliche Indexrichtung.
Tabs und Navigator bleiben stationär. Kurzer Tagestest: gezielte Richtungs-/Kamera-/
FIFO-Tests mit mehrfachen Umläufen sowie kurzer Live-Umlauf auf dem signierten
Release. Gleiche gespeicherte Kameras, keine Cachelöschung, jeden abgeschlossenen
Schritt zählen; keine Kamera-/Layoutverschiebung nach Ende. Messgrenze: Keydown bis
stabile Zielszene, inklusive wartender Schritte. Vollständiger Baselinevergleich
für CPU (idle/action/additional), Framezeiten, Speicher und Mischpfade:
NOT RUN: scheduled overnight (PERF-017), ab 2026-09-07.
[Umlauf-Korrektur](results/2026-09-06-tab-wrap/report.md).


P03/P04/P09 Regression PERF-018: App-Prozess läuft, aber hat kein Fenster;
Platzhalter zeigt Closed. Return auf ausgewählter Karte, Suchergebnis-Return und
Mausklick prüfen. Öffnungsauftrag muss ein echtes Fenster anfordern; Canvas darf
nicht allein wegen erfolgreicher Prozessaktivierung verschwinden. Erwartet:
Opening bis Fenster erkannt, dann richtige App/Fenster und aktualisierte Vorschau;
bei ausbleibendem Fenster sichtbarer Fehler nach bestehendem Timeout. Auch echten
Prozessneustart, schon offenes/minimiertes Fenster und mehrfaches Return prüfen.
Cache: laufender fensterloser Prozess separat von beendetem Prozess. Messgrenze:
Eingabe bis sichtbarem richtigen Fenster und Rückkehr bis aktualisierter Vorschau;
CPU/Idle/zusätzliche CPU und Ziel-App-Kosten getrennt. Kurzer Live-Vergleich mit
Chrome vorhanden; volle Varianten/CPU-Abnahme NOT RUN: scheduled overnight,
2026-09-07 03:00 Europe/Berlin. Fehlende kalibrierte Beobachter bleiben BLOCKED.


P03/P04/P10 Regression PERF-019: Eine App mit normalem AX-Standardfenster plus
zusätzlicher großer, unbenannter Hilfsfläche öffnen. Nur das Bedienfenster darf
eine Karte erhalten; Hilfsfläche darf keinen AX-Match stehlen. Fixture-Quelle:
`results/2026-09-06-window-filter/Fixture.swift`. Chrome-Neustart über Backspace
und Return einschließlich Profilwahl zusätzlich prüfen; echte Mehrfenster-,
Minimierungs-, Titelwechsel- und Größenänderungspfade erhalten. Eingaben: Suche,
Return, Klick und Rückkehr. Erste Inventur nach Prozessstart separat von warmer
Inventur messen, gleicher Fensterbestand auf A/B. Abschluss: genau eine Karte
pro echtem Fenster, passende Vorschau ohne Hilfsflächenrand, korrektes Fokusziel.
CPU/Idle/zusätzliche CPU, Erkennungslatenz und Vorschau-Bildzeiten getrennt.
Kurzer Fixture-Vergleich vorhanden; volle Varianten und wiederholte Messungen
NOT RUN: scheduled overnight (2026-09-07), fehlende Beobachter bleiben BLOCKED.


P13 Einstellungen-Seitenpanel (PERF-020): Settings-Zahnrad öffnet rechts ein
weißes Panel (380 logische Punkte bei normaler Bildschirmbreite); Canvas erhält
den verbleibenden Platz, ohne Karten-Weltpositionen oder Kamerazoom zu ändern.
Eingaben: Zahnrad erneut, Schließen-X und Escape; jeden Schalter und Farbwahl
mit anschließender Wiederherstellung prüfen, Scrollen bei kleiner Bildschirmhöhe.
Native Tastaturbedienung/Tab-Fokus, Suchbeginn und Desktopwechsel bei offenem
Panel sowie Fokusübergang in Ziel-App ergänzen. P01/P02/P03/P06: korrekte
Treffer-/Zoom-/Navigatorkoordinaten in kleinerem Viewport, volle Breite nach
Schließen und unveränderte persistierte Kamera/Platzierungen.
Cache: erste Öffnung separat, dann warme Wiederholungen; gleiche Kamera und
Fensterfixture vor jedem A/B-Paar. Grenze: Klick bis nutzbares Panel bzw.
restaurierter Canvas, Schalter bis sichtbarer Effekt und gespeicherter Zustand.
Idle-, Aktions-, zusätzliche CPU, Bild-/Antwortzeiten und Speicher getrennt.
Kurze interaktive Prüfung vorhanden; volle Varianten, Core-Smoke und fünf
Vergleichspaare NOT RUN: scheduled overnight, ab 2026-09-07 03:00 Berlin.
Fehlende kalibrierte Beobachter bleiben BLOCKED.


P06/P13 Desktop-Plus und Settings-Einstieg (PERF-021): Plus-Button nach dem
letzten Tab erstellt genau einen Desktop; Tastaturzeichen + ebenfalls, mit/ohne
Shift je Tastaturlayout. Wiederholte Key-downs nicht vervielfachen; Texteingabe
in Suche/Titelfeld darf keine Desktops erzeugen. Tab/Shift-Tab besucht nur
bestehende Desktops, inklusive zyklischem Umlauf, niemals den Plus-Button.
Lange Tab-Reihe horizontal scrollbar, Plus dahinter. Minimap-Kopf rechts öffnet
Settings; Footer enthält ausschließlich Suche, Gesamtansicht und Ansichtssperre.
Erste Verwendung und warmer Zustand getrennt, gleiche gespeicherte Desktops auf
A/B; Messgrenze Eingabe bis zusätzlicher ausgewählter Desktop/bedienbares Panel.
Kameras/Platzierungen und Aktionsanzahl kontrollieren; CPU/Latenz/Bildzeiten
getrennt. Volle Varianten inkl. Keypad/Layouts/Autorepeat, Core-Smoke und
Ressourcenvergleich NOT RUN: scheduled overnight (2026-09-07).

P13/PERF-021 Nachbesserung: Settings-Zahnrad muss auch bei heller macOS-Appearance
auf dunkler Minimap sichtbar bleiben (fest hell gerendertes Symbol). Footer:
Suche links mit 8 Punkten Rand, Gesamtansicht und Schloss rechts mit 8 Punkten
Rand, je 40 Punkte Trefferfläche. Bei Panelöffnung und Navigator-Verschiebung
prüfen. Kurzer Sicht-/Öffnungstest vorhanden; volle Varianten nachts.

P13/PERF-020 Schalterdarstellung: Kreisrunder 18-Punkte-Schieber in 38 × 22
Punkte Bahn, bei Aus links und bei An rechts. Native NSButton-Schaltersemantik
mit eigener Zeichnung; Klick, Leertaste und Accessibility-Wert/Zustand prüfen.
Grid aus/an als kurzer Live-Test mit Wiederherstellung; volle Tastatur-/AX- und
Performance-Abnahme NOT RUN: scheduled overnight.

P13/PERF-020 Panelbewegung und Zeilen: Öffnen/Schließen 180 ms, Canvas-Viewport
bewegt sich mit; Reduce Motion ohne Bewegung. Schnelles Öffnen/Schließen muss
am letzten gewünschten Zustand enden, keine alte Fläche zurücklassen. Text,
Icon und Schalter lösen jeweils genau eine identische Aktion aus; Herausziehen
vor Loslassen darf nicht schalten. Icons 26 Punkte ohne Hintergrundcontainer.
Kurzer Text-/Icon-Klicktest und getrennte Video-Sichtprüfung; vollständige
Tastatur-/Unterbrechungs-/CPU-/Bildzeit-Abnahme NOT RUN: scheduled overnight.

P13/PERF-020 Keyboard bei offenem Panel: Keine globale Eingabesperre. Bestehende
Pfeil-, Shift-Pfeil-Zoom-, Return/Keypad-Enter-, Shift-Return-, Backspace-,
Tab/Shift-Tab-, Plus- und Suchpfade auch mit geöffnetem Settings testen. Panel
bleibt bei Desktopwechsel/Neuanlegen/Suche offen; echter App-Fokus verlässt
weiterhin den Canvas. Texteditoren behalten Eingaben. Escape zuerst Suche, dann
Panel. Globale Canvas-Shortcuts bleiben unverändert. Kurzer Live-Subset und
Handlerregression vorhanden; volle Kombinationen inkl. sicherer Quit-Fixture
und Ressourcenmessungen NOT RUN: scheduled overnight.

P13 Settings-Lesbarkeit/Farbauswahl (PERF-020): 440-pt-Panel mit 16-pt-Zeilen,
kleineres Fenster ebenfalls prüfen; Text darf Schalter nicht überdecken. Öffnen
und Schließen per Settings-/Close-Button, Farben per Klick wählen, aktiver Ring
mit 2 pt transparentem Gap; Swatch-Mitte und freie Canvasfläche farbgleich.
Bestehende Klickpfade Text/Icon/Schalter sowie Tastatur bleiben. Gleiche Szene und
Preferences, keine Cacheleerung; Messgrenze Klick bis stabile Panel-/Canvasdarstellung.
CPU idle/action/additional, Latenz/Frames vergleichen; Auswahlwechsel zählen.
Kurzer Live-Check siehe [Bericht](results/2026-09-06-settings-size/report.md), volle
Vergleichsprüfung NOT RUN: scheduled overnight.

P13 Settings-Mausgrenze (PERF-020): Mit ausgewählter Gruppe an rechter Canvasgrenze
in Settings hinein-/hinausfahren, auch über rechnerisch außerhalb liegende Griffe.
Panel zeigt Pfeilcursor; kein Desktop-Hover/Resize/Drag/Kontextmenü oder Kamera-Scroll
vom Panel aus. Text/Icon/Schalter bleiben klickbar, Keyboard weiterhin global.
Panel bei ruhendem Cursor öffnen/schließen; bestehende Canvas-Drags separat prüfen.
Gleiche Szene/Gruppe/Kameras vor/nach, keine Cacheleerung. Grenze: Mausbewegung bis
sichtbarer Cursor-/Hoverreaktion; abgeschlossene Klicks zählen, CPU idle/action/
additional und Frame/Latenz vergleichen. Voller Vergleich NOT RUN: scheduled overnight.
[Kurzer Test](results/2026-09-06-settings-pointer/report.md).

P04/P13 Auswahlanimation: Ab 2026-09-06 ausschließlich sofortiger Beginn von
Titel/Rahmen und gleichzeitigem Abbau der alten Auswahl. Kein Settings-Schalter;
alte gespeicherte Aus-Werte dürfen das Verhalten nicht zurückbringen. Pfeile/Klick,
gleiche und andere App, Mehrfachauswahl bei offener/geschlossener Sidebar prüfen.
180 ms unverändert, jede Navigation zählen. Gleiche Szene/Kamera, warmer Cache;
Messgrenze Eingabe bis stabile Hervorhebung/Kamera. CPU idle/action/additional und
Frame/Latenzvergleich NOT RUN: scheduled overnight.
[Entscheidung/Prüfung](results/2026-09-06-selection-fixed/report.md).

## P15 – Chronological Mode: Liste, Fokusverlauf und Moduswechsel

- **Fixture:** gleiche App-Versionen und Fenster wie Baseline; mindestens zwei
  eindeutig benannte Fenster einer App und ein Fenster einer zweiten App. Freie
  Desktop-Positionen, Kamera, ausgewähltes Fenster und Shortcut-Einstellung sichern.
- **Pfad:** Settings → View mode → Chronological; A1, B1, A2 tatsächlich aktivieren,
  Übersicht öffnen: A2, B1, A1. Vorschauauswahl darf diese Reihenfolge nicht ändern.
  Hoch/Runter, Return, Klick, Scrollen, Pinch und Shift-Pfeil-Zoom separat prüfen.
- **Varianten:** neue/geschlossene Fenster, Entfernung der Auswahl und eines
  Vorgängers, Größenänderung, neue Fenster während Auswahl, schnelles Umkehren,
  Gruppe verschieben, nächste Übersicht richtet neu aus. Leere Liste/Einzelfenster.
  Direkt während Settings-Schließanimation navigieren; Ziel bleibt zentriert.
- **Command-Tab:** erster Schritt zum vorherigen Fenster, mehrere Tabs bei
  gehaltenem Command, Shift rückwärts, Loslassen aktiviert genau einmal; schneller
  vollständiger Tastendruck vor Abschluss der Inventarisierung. Escape und
  Moduswechsel brechen ab. All-apps-Karte wird dabei übersprungen.
- **Isolation:** mehrfach Canvas ↔ Chronological und Prozessneustart; gespeicherte
  freie Positionen und Kameras unverändert. Chronologischer Zoom bleibt beim
  Aktivieren eines Fensters und bei Rückkehr erhalten. Fokuswechsel außerhalb von
  OpenPlane einschließlich Wechseln innerhalb derselben App prüfen.
- **Messen:** Eingabe bis sichtbarer Auswahl und Kameraruhe; Moduswechsel bis
  stabilem Layout; tatsächlicher Fokus bis Einordnung beim nächsten Aufruf;
  Command-Loslassen bis Ziel bereit. CPU idle/action/additional getrennt, zusätzlich
  Hintergrund-Idle mit Fokusbeobachtung, Speicher nach Wiederholungen.
- **Cache:** frischer OpenPlane-Prozess, zwei Aufwärmrunden, warmer Prozess;
  Vorschaucache und App-Prozesse unverändert gegenüber Baseline dokumentieren.
  Keine Aussage über historische Nutzung vor Prozessstart: Initialordnung basiert
  auf aktueller Fenster-Vordergrundreihenfolge.
- **Beleg:** automatisierte Listen-/Persistenztests ergänzen Live-Beobachtung;
  vollständige Eingabe-/Latenzadapter fehlen weiterhin, siehe PERF-022.

## P16 – All apps, Rückkehr und Fensteraktionen

- **Fixture:** P15; zusätzlich installierte Test-App mit/ohne Fenster sowie sicher
  schließbares Testfenster. Keine Nutzerdokumente zum Testen schließen.
- **Pfad:** All apps am Listenende mit Return oder Klick öffnen; alphabetische
  Einträge prüfen, tippen/suchen, Treffer mit Pfeilen und Return/Klick starten.
  Sichtbarer Zurück-Pfeil stellt vorherige Auswahl und Kamera wieder her.
- **Varianten:** Suche ohne Treffer, Suche löschen, Escape (Suche zuerst, dann
  zurück), laufende App, geschlossene App, fehlende App/Startfehler, Katalog erneut
  öffnen; Fensterbestand ändert sich im Katalog. Mehrere installierte Kopien
  erzeugen keine doppelten Bundle-IDs; eingebettete Hilfs-Apps fehlen.
- **Fensteraktionen:** Kontextmenü Close Window versus Quit App; Command-W bei
  Fensterauswahl, Suchfeld darf den globalen Fenster-Schließpfad nicht auslösen.
  Speicherdialoge respektieren; App ohne Fenster bleibt im Katalog startbar.
- **Messen:** All apps bis erste Einträge, Suchzeichen bis gefilterte Darstellung,
  Return/Klick bis Ziel bereit, Zurück bis alte Ansicht steht; CPU idle/action/
  additional, Speicher und Katalogwachstum. Frischer und warmer Katalog getrennt;
  gestarteter/beendeter Zielprozess und Vorschaucache explizit dokumentieren.
- **Abnahme:** P04/P09/P10/P11/P13 bleiben zusätzlich relevant. Fehlende sichere
  Fixtures und Beobachter sind BLOCKED, keine aus Unit-Tests abgeleiteten Live-Pässe.
