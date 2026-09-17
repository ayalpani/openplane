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

- Panel-Drag in Canvas/Chronological und kompaktem Overview/All apps: Header mit
  Maus/Trackpad greifen, verschieben, Ränder erreichen, loslassen und neu öffnen.
  Dock unten/links/rechts sowie automatisch ausgeblendet, Displaywechsel prüfen.
  Panel bleibt innerhalb der sichtbaren Bildschirmfläche mit Greifabstand;
  Position wird gespeichert, Header-Klicks bedienen weiter ihre Schaltflächen.
  Overview passt Fenster in den freien Bereich ober-/unterhalb des Panels ein.
  Warme identische synthetische Fixture auf Baseline/Kandidat; Dragbeginn bis
  sichtbare Panelbewegung und Loslassen bis stabiles Layout, idle/action/additional
  CPU separat. Erste Verwendung nach Prozessstart separat messen.

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
- **Command-Tab (aktualisiert 2026-09-07):** öffnet nur die Übersicht im
  gewählten Modus. Wiederholtes Command-Tab beziehungsweise Command-Shift-Tab
  lässt die bestehende Auswahl unverändert; Command-Loslassen aktiviert nichts.
  Pfeile navigieren, Return/Klick öffnet. Normales Tab/Shift-Tab separat prüfen.
  Ein vollständiger Pfeiltastendruck einschließlich Key-up darf nur einen
  Nachbarn auswählen; gehaltene Tasten bleiben als eigene Variante erhalten.
- **Isolation:** mehrfach Canvas ↔ Chronological und Prozessneustart; gespeicherte
  freie Positionen und Kameras unverändert. Chronologischer Zoom bleibt beim
  Aktivieren eines Fensters und bei Rückkehr erhalten. Fokuswechsel außerhalb von
  OpenPlane einschließlich Wechseln innerhalb derselben App prüfen.
- **Messen:** Eingabe bis sichtbarer Auswahl und Kameraruhe; Moduswechsel bis
  stabilem Layout; tatsächlicher Fokus bis Einordnung beim nächsten Aufruf;
  Command-Tab bis Übersicht bereit, Return bis Ziel bereit. CPU idle/action/additional getrennt, zusätzlich
  Hintergrund-Idle mit Fokusbeobachtung, Speicher nach Wiederholungen.
- **Cache:** frischer OpenPlane-Prozess, zwei Aufwärmrunden, warmer Prozess;
  Vorschaucache und App-Prozesse unverändert gegenüber Baseline dokumentieren.
  Keine Aussage über historische Nutzung vor Prozessstart: Initialordnung basiert
  auf aktueller Fenster-Vordergrundreihenfolge.
- **Beleg:** automatisierte Listen-/Persistenztests ergänzen Live-Beobachtung;
  vollständige Eingabe-/Latenzadapter fehlen weiterhin, siehe PERF-022.

## P16 – All apps, Rückkehr und Fensteraktionen

Current behavior (2026-09-07, supersedes footer-card cases below): no All apps
card in window layouts. Use Views panel to open catalog. Verify Recent/Overview
with zero/one/many windows, arrows cannot select a removed footer, Return on empty
list does nothing, catalog entry/back restores camera/selection. Same fixture,
first/warm opens; measure input to settled target and idle/action/additional CPU
plus latency against prior build. Historical footer rendering cases are retired.

- **Fixture:** P15; zusätzlich installierte Test-App mit/ohne Fenster sowie sicher
  schließbares Testfenster. Keine Nutzerdokumente zum Testen schließen.
- **Pfad:** All apps am Listenende mit Return oder Klick öffnen; alphabetische
  Einträge prüfen, tippen/suchen, Treffer mit Pfeilen und Return/Klick starten.
  Escape stellt vorherige Auswahl und Kamera wieder her. Das Views-Panel wechselt direkt zu einer Fensteransicht; der separate Zurück-Button entfällt.
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


P11/P16 Backspace-Lifecycle (2026-09-07): In Canvas und Chronological zuerst nur
 das ausgewählte Fenster schließen. Nur wenn die vollständige AX-Fensterliste
 das ausgewählte Fenster enthält und genau ein Standardfenster bestätigt, App
 regulär beenden. Minimierte Fenster zählen mit; bei fehlender/unsicherer
 Inventarisierung niemals aus einem sichtbaren Fenster auf eine App mit nur einem
 Fenster schließen. Zwei leere Testfenster → Backspace schließt eines, Prozess
 bleibt; erneut Backspace auf dem letzten Fenster → Prozess endet. Dasselbe mit
 minimiertem zweitem Fenster, weiteren Spaces und Speicherdialogen wiederholen.
 Key-repeat darf keine Folgefenster schließen; Such- und Textfelder behalten
 Backspace als Texteingabe. Close Window im Kontextmenü bleibt ausdrücklich eine
 reine Fensteraktion. Messen: Tastendruck bis Fenster verschwindet/Prozess endet,
 Auswahl des verbleibenden Nachbarn, CPU idle/action/additional; AX-Abfragekosten
 separat. Kalte/warme Fenster-Inventarisierung mit gleichem Fixture-Aufbau prüfen.

P16 All apps-Karte (2026-09-07): Bei Chronological zum Listenende navigieren;
kompakte Karte mit kleinem Icon und ungekürztem „All apps“ gemeinsam mittig,
ohne äußeren Titel/Untertitel prüfen. Auswahlrand dünn, nach Wegnavigation weg.
Return und Klick öffnen weiterhin den Katalog, Zurück stellt die Karte wieder
her. Bei gespeichertem Zoom sowie verkleinert/vergrößert prüfen. Messgrenzen:
Auswahl bis fertig dargestellter Karte, Zoom bis fertigem Layout, Return/Klick bis
Katalog bereit. Gleiche Fenster-Fixture, Kamera und aufgewärmte Icon-/Text-Caches
für Baseline und Kandidat; kalten ersten Aufruf separat messen. Idle-, Aktions-
und zusätzliche CPU sowie Latenz getrennt berichten.

P12/P02 Browser previews (2026-09-07, replaces containment): filtering removed
at user request. Safe local normal/private fixtures must both render with the
legacy preference false/true, including new windows, refresh, focus, cold process
and warm capture. No Privacy toggle; browser disk cache stays disabled. Never
view user browser screenshots. Boundaries: discovery/request to fresh preview,
input/focus to refreshed preview; idle/action/additional CPU and latency separate.
Use identical fixtures and observer for baseline/candidate; restoring expected
browser rendering is not a performance regression by itself.

P15/P16 (2026-09-07 spacing): mixed portrait/landscape previews must use the same
240-world-unit gap as Canvas, including the footer/catalog. All apps icon and
text stay fixed in screen points at zoom 0.06/0.2/0.8/2; minimum card remains
large enough for its contents and clickable at its rendered edges. Select footer,
zoom, Return, Back and click after zoom; verify center preservation. Measure cold
and warmed layout separately, zoom-event to final layout and Return to catalog
ready. Compare same synthetic fixture/cache/zoom to baseline; idle/action/additional
CPU and latency separately. No user-window screenshot evidence.

P16 application grid (2026-09-07): open All apps, verify alphabetical left-to-right,
top-to-bottom tiles over available width. Resize narrow/wide; columns recompute.
Arrow keys follow grid neighbors, Tab follows alphabetical order. Selection stays
in view without recentering the whole grid. Scroll remaining rows, search/filter,
Return/click launch, failure message, Escape/Back restore windows. Same synthetic
catalog size and warmed icons for A/B; cold catalog scan separately. Measure
open→grid ready, resize→layout settled, input→selection visible; report idle/action/
additional CPU and latency separately. Never use user-window screenshot evidence.

## P17 – Overview: alle Fenster, gruppiert und gleichzeitig sichtbar

- Fixture: synthetische Fenster mit Quer-/Hochformat; 0/1/7/30/100 Fenster,
  mehrere Apps und mehrere Fenster je App, gleiche und lange Titel. Keine
  Screenshots realer Nutzerfenster als Beleg, insbesondere keine Browser-Inhalte.
- Settings → Overview und Übersicht-Shortcut: alle Gruppen und All apps müssen
  in der nutzbaren Fläche liegen, obere Fensterränder/Titel fächern nach rechts
  unten auf. Native Browser-Tabs werden nicht enumeriert; Einheiten sind Fenster.
- Nudge-Freifläche: auf Displays mit/ohne Safe-Area, bei Resize, erneutem Öffnen,
  Fit-all-Button und Vorschaugrößenänderung bleiben Karten einschließlich Titeln
  und Auswahlrand unterhalb des vollständigen hintergrundfarbenen Nudges.
  Eintritt/Refit bis stabile Geometrie messen, identische warme synthetische Fixture
  auf Baseline und Kandidat; erste Verwendung separat.
- Hoch/Runter durch Fenster einer Gruppe, Links/Rechts zwischen Gruppen, Tab
  durch Fenster, Return/Klick aktiviert exakt das markierte Fenster. Nur das
  Ziel hat primäre gelbe Hervorhebung. Kamera standardmäßig unverändert.
- Fenster hinzufügen/entfernen, selektiertes Fenster schließen, Größenänderung,
  Bildschirm-/Viewportwechsel, Suche/Leeren, All apps/Zurück und erneutes Öffnen.
  Leere/einzelne Liste bleibt bedienbar. Unveränderte Metadaten/Preview-Updates
  dürfen keine erneute Layoutsuche oder Kamerazentrierung auslösen.
- Canvas → Chronological → Overview → Canvas mehrfach und nach Neustart:
  freie Positionen und Canvas-Kamera bleiben erhalten; View mode wird gespeichert.
- Messen: Eintritt bis fertiges Layout, Inventar-/Größenänderung bis fertiges Layout,
  Pfeil bis Auswahl sichtbar, Return bis Ziel bereit. Kalte Icons/Previews separat;
  warmer gleicher Fensterbestand für Layout und Eingabepfade. Idle/action/additional
  CPU und Latenz getrennt; keine Gewinne durch fehlende Fenster oder unterdrückte
  erwartete Vorschauen behaupten. Vollständige Paare in autorisierter Nachtrunde.

## P18 – Camera follows selection, je Modus

- Settings per Maus und Tastatur ändern: Default Canvas/Chronological an,
  Overview aus. Gespeicherte Auswahl über Wechsel und Neustart erhalten.
- Aus: Pfeile/Tab/Suchergebnis ändern Ziel, nicht Kamera. An: vorhandene
  Zentrierung bleibt verfügbar. App-Katalog behält Scroll-into-view-Verhalten.
- Moduswechsel/Neuanordnung und explizites Fit all sind eigene Kameraaktionen;
  Aktivieren eines Fensters bleibt ein Wechsel in die Ziel-App.
- Grenzen: Toggle bis UI-Zustand, Navigation bis fertige Hervorhebung/Zentrierung;
  gleiche Startkamera/Fixture, warmer und kalter Pfad separat. CPU idle/action/
  additional sowie Latenz erfassen. Screenshot-Prüfung nur synthetisch.

P16 catalog zoom (2026-09-07): All apps hides grid dots and center guide, independent
of the saved canvas setting. Long app names occupy one fixed-height line and
truncate at the end. Wheel/trackpad pinch and keyboard zoom retain navigation,
search and return target. Captions fade from zoom .85 to .55; icons stop at 40pt,
frames compact to icon+24pt with >=16pt gap and reflow left-to-right. Test 0/1/15/100
apps, narrow/wide viewports, repeated zoom out/in, scrolled list, search/clear,
Back/Return/click and launch errors while captions hidden. Use synthetic fixtures;
never inspect user-window screenshots. Measure zoom input through final grid,
idle/action/additional CPU and latency separately on identical warm fixtures;
first-process usage separately, matched baseline per candidate identity.

## P19 – Configurable overview shortcut and native swipe prototype

- Settings → Open overview: record modified key, Escape cancel, invalid/unmodified/
  reserved key, registered conflict, Reset, panel close while recording. Verify
  persisted binding after restart, old binding inactive, same binding accepted.
- From another app and OpenPlane: custom key opens selected mode exactly once,
  no keystroke delivered to background app, held key/release and Command-Tab
  unchanged. Test permission recovery and shortcut registration failure.
- Optional Swipe up opens Overview: built-in/Magic Trackpad, local/global app
  focus, Mission Control enabled/disabled and three-finger drag enabled/disabled.
  Real upward three-finger gesture must open fitted Overview once; downward,
  horizontal, two-finger scrolling and pinch must not open it. No BTT dependency.
  Experimental until verified with physical gestures; simulated scroll is not proof.
- Synthetic R/L fixture, first process and warmed separately. Measure key/gesture
  through visible overview; idle/action/additional CPU, latency and correctness
  separately with baseline/candidate identity. Include repeated registration,
  recorder cancellation, mode changes and cleanup. Full pairs in nightly round.

## P20 – First-class views, names and movement settings

- P13/P20 progressive view settings (2026-09-08): root Views row → four quiet
  navigation rows → one view's name and movement settings. No mode switcher in
  detail; Configure with AI disclosure starts collapsed. Test all four rows,
  renamed views, external view switching, Back/Escape at both depths, disclosure
  open/close and field editing. Same cold/warm viewport fixture; measure input
  to usable destination and disclosure layout, idle/action/additional CPU and
  latency separately against settings-views build. P13/P20/P21 full variants
  and baseline pairs: NOT RUN: scheduled overnight.

- P13/P20 Settings hierarchy (2026-09-08): Settings → Views opens a separate
  scroll document with all four view choices, name, pan/follow and prompt settings.
  Global shortcut/appearance stay on root. Check click entry/back, Escape from
  detail then root (including All apps active), text editing and first/warm reopen.
  Verify per-view values follow the selected view and no settings change on Back.
  Measure input to correct usable subpage, identical viewport/cache fixture against
  previous flat Settings build; idle/action/additional CPU and first/settled latency
  separately. Full coverage and paired comparisons deferred to nightly P13/P20/P21.

Current navigation (2026-09-07): views replace Desktop tabs in the top nudge,
using the prior translucent selected-tab style. Separate pill overlay and plus
entry are removed. Tab cycles Canvas/Recent/Overview/All apps, Shift-Tab reverses,
wrapping; key repeat ignored; editing/search retain native Tab behavior. Fresh
preferences default to Overview; saved mode and legacy desktop data preserved.
Verify click/Tab/reverse across all modes, empty/multiple windows, active search,
Settings editing, viewport/safe-area changes and restart. First/warm conditions;
input to selected tab and settled layout. Same P20 fixture and CPU/latency observer
against prior build. Earlier desktop-switch and blue-pill cases are superseded.

- Rounded compact view pill: 20pt captions, text-sized segments, 240ms sliding
  blue selection. Click first/last/adjacent, fast reversal, Settings mode switch,
  keyboard focus/activation, Reduce Motion, long names and narrow viewport.
  Verify selected target and settled highlight agree, including resizing during
  transition. Measure click to first motion and settled target, cold/warm process,
  baseline same fixture; animation duration is not measured latency.

- All apps has no separate Back button. Verify direct Views-panel switching by
  click and Escape return (clear search first), restoring selection/camera. Check
  first/warm catalog opens and Settings open/closed; boundaries remain input to
  stable target view, with the same P20 baseline fixture and CPU/latency observer.

- Caption revision: default chronological label is Recent; custom names remain.
  Check 18pt overlay labels and enlarged vertical exclusion with Settings open/closed,
  mouse selection and keyboard navigation, narrow/wide screens and first/warm use.
  Measure input to selected label/layout settling against the prior P20 build.

- Always-visible Views overlay: switch Canvas/Chronological/Overview/All apps with
  Settings closed/open; rename each view, switch away/back and restart. Existing
  Canvas desktop geometry/camera remain separate; All apps does not persist into
  Canvas camera. Long names, small/large viewport, overlay hit areas and layout
  exclusion must remain correct.
- Overview movement defaults off. Horizontal/vertical wheel and minimap movement
  must not pan it; pointer-centered pinch must preserve center when movement is
  off. Zoom/activation still work. Toggle movement and verify per-view persistence.
  All apps defaults to bounded vertical list scrolling, no horizontal panning;
  same behavior from every entry mode, search/back, different zoom/list sizes.
- Text editing in Settings must not trigger search/navigation/activation.
- Synthetic R/L, first process and warm cache separately; overlay switch to stable
  layout, input to movement/no movement, name edit to label refresh. Same fixture
  and observer for baseline/candidate, separate idle/action/additional CPU/latency.

## P21 – Prompt-based view configuration prototype

- Only explicit Generate sends prompt + supported schema to OpenAI. No window
  titles, icons, screenshots, or other app data. Key only from environment or
  secure session field, never preferences/logs. Responses store=false, bounded
  tokens and timeout. Name/layout/pan/follow only; no code/permissions/privacy.
- Generate valid suggestion then Apply; nothing changes before Apply. Empty prompt,
  missing/invalid key, model access denied, refusal, malformed/incomplete response,
  timeout, repeat click, and switch view while request pending. Prompt persists per
  view, stale suggestions cannot apply to another view. Restart/session-key behavior.
- Deterministic response fixture for UI/performance baseline, real API call separate
  as external latency (synthetic prompt only). Measure input→loading, loading→proposal,
  Apply→stable view, local idle/action/additional CPU separately from remote timing.
  Full coverage and paired comparisons in authorized nightly round only.


P16 minimum catalog zoom (2026-09-07): stop at 0.5, where captions are gone and
40pt icons/64pt tiles reach their visible minimum. Twenty Shift-Up taps, held
Shift-Up and repeated outward pinch must not accumulate invisible zoom. One
Shift-Down tap or inward pinch must immediately grow the layout. Repeat during
rapid reversal and view changes, first/warm catalog, search and small/large lists.
Boundaries: key/pinch input to first visible size change and settled grid; separate
idle/action/additional CPU and latency, matched baseline fixture and observer.

P17 shared Overview headers (2026-09-07): one icon/title/count above the full app
stack; selected title and index update with arrows and clicks. Single/multiple
windows, long title truncation, closing selected window, new window, resize/zoom,
search, group tools and mode return must preserve correct headers and outlines.
No per-window captions/icons inside stacks. Header CPU now includes HUD grouping
and text drawing: compare first/warm P17 fixtures and view sizes, input to header
change plus stable scene; idle/action/additional CPU, latency and correctness.
Only synthetic window images may be inspected for this user's verification.

P01/P02/P07 sync regression (2026-09-07): compare displayed main camera and minimap transforms with the blue viewport during translation, zoom, rapid interruption and changing map fit. Sample all viewport edges; distinguish geometric error from actual display latency. Synthetic presentation-layer test exists; physical display and installed Release reproduction remain separate required checks.

P17 header alignment (2026-09-07): index uses spaces around slash (2 / 3). Icon, title and count share vertical center using measured text heights. Check synthetic icons, short/long titles, single/multi-window groups, click/arrow selection and zoom, first/warm HUD draws. Same P17 baseline fixture/observer; input to updated header, idle/action/additional CPU and latency.

P07/P17 history navigation (2026-09-07): click navigator Back/Forward (including
header mouse-down/up forwarding), immediately navigate arrows, then click selected
preview/Return. Overview with follow-selection off must keep fitted camera fixed;
Canvas/Recent/follow-enabled Overview use normal follow policy. Repeat with active
camera flight, empty/missing history node, catalog entry and rapid alternate Back/
Forward. Mouse interaction must be released before dispatch. First/warm fixtures;
input to selected target, next-input responsiveness and focus completion. Compare
idle/action/additional CPU and latency with same baseline fixture and method.

P17 caption format (2026-09-07): multi-window stack uses "1 von 3 · Title…" as one centered, tail-truncated line; singleton shows title only. Check single/multiple/long titles and selection changes via click/arrows, first/warm draw, existing P17 input-to-header boundary and baseline method. This supersedes trailing slash counters.

P17 shared Recent/Canvas header style (2026-09-08): Overview uses previewHeaderFont/layout, icon scale/badge rendering and title visibility from Recent/Canvas. Selection uses same title lift and bold weight. Shared stack row remains vertically centered, prefix only for multi-window stacks. Verify low/default/high zoom, selected/unselected/grouped, narrow titles and gap between groups. Existing itemGap already shared; cascading within a group remains intentional. Same P17 fixture/observer and input-to-header boundaries, first/warm conditions.

P17 actual shared renderer (2026-09-08): stack headers now use retained CanvasCardLayer icon/text layers and the same updatePreviewHeader/layoutPreviewHeader functions as Canvas/Recent. No separate HUD text drawing. Compare equal-zoom selected/unselected singletons across modes, truncation, badge position/shadow, low-zoom hiding; group prefix and header anchored to stack union. Verify selection updates, size changes, disappearing groups and repeated mode changes (no orphan headers). P15/P17 first/warm input-to-header boundaries, same fixture/method for CPU/latency comparison.

P11/P17 explicit window-close refresh (2026-09-08): Backspace/Close Window reports
successful AX close request to inventory; bounded 150ms follow-up (at most ten
scans) bypasses background deferral only while explicit requests are pending.
Inventory scans serialized. A requested window is removed on first scan absent
from both discovery and global CG inventory; normal transient-loss threshold stays
three scans. Test three Chrome fixture windows → close middle → two cards/counter;
close others, rapid repeat, blocked/failed close, save dialog cancel/confirm, process
quit and leaving overview mid-check. No premature removal, duplicates or orphan
headers. First/warm fixtures; close input to OS disappearance and scene removal
separately; idle/action/additional CPU and latency against same baseline method.

### P04/P13/P20 – Interrupted focus handoff (2026-09-09)

Enable/disable Swipe up in Settings, then activate selected window by Return,
preview click and navigator focus button. During the 600ms handoff inject a
trailing swipe and a view/layout replacement. Swipe must leave handoff intact;
other cancellation restores visible, opaque, keyboard-ready Overview state and
permits the next activation, without stale activation completion. Repeat after
window disappearance and with gesture disabled. Normal activation still completes
once. Use dedicated safe windows, same first/warm preview fixture and build
baseline. Boundaries input → usable target app or usable recovered overview.
Report idle/action/additional CPU and first/settled latency separately. Full
physical gesture race, core smoke and paired baseline runs scheduled overnight;
missing precise event/latency fixture remains PERF-025.

### P04/P17/P20 – Overview stack rotation (2026-09-09)

With three windows in one app and another app, Up/Down wraps within the app.
Selected preview must fully render above siblings; click hit order matches layers.
Navigate to another app and back: remembered front window and caption retained.
Close remembered window: actual MRU surviving sibling becomes front/selected;
check external close, unselected group, single and empty group, new windows and
preview-size changes. Preserve Canvas frames and Recent ordering. Native safe
fixture, first/warm cached previews, input to correct presented front and usable
Return target. Compare previous build with same fixture/method; idle/action/extra
CPU and latency separately. Full live variants/core smoke/A-B: scheduled overnight.

### P04/P20 – Stack boundary exits and Overview-first tabs (2026-09-09)

Supersedes cyclic trapping in stack rotation: Up/Down selects adjacent sibling
until the boundary, then uses spatial neighbor from another app. Single-window
apps immediately allow vertical exit. Two-row fixture with multi/single stacks:
Down from final sibling → next row; Up from first → preceding row; restore each
stack's remembered front. At outer edge retain selection. Left/Right unchanged.
Tab and Settings order Overview, Canvas, Recent, All apps; persisted string IDs
remain unchanged. Check forward/reverse Tab and all clicks, rename and saved view.
Measure input → selected/front content against previous build using identical
fixture and first/warm cache. Full live variants/core smoke/paired CPU and latency
checks NOT RUN: scheduled overnight.

### P04/P17/P20 – Perspective stack presentation (2026-09-09)

Active app window renders centered, largest and at the bottom/front of its stack.
Remaining cards recede upward at 90% per depth. Selection rotates presentation
without changing stable navigation order, stored Canvas frames or stack footprint.
Check 1/3/large counts, mixed aspect ratios, remembered front, close fallback,
visible back-card hit testing, Return transition aligned to rendered frame and
row exits. Synthetic native scene and safe live fixture; first/warm cached
previews. Measure input to front card and completed activation, idle/action/extra
CPU and latency separately against previous build. Full suite/paired runs deferred
NOT RUN: scheduled overnight; controlled fixture/observer under PERF-025.

### P04/P20 – Native stack movement (2026-09-09)

Within Overview stack, selection groups position, scale and zPosition in one
320ms Core Animation transition. Old front shrinks/rises/recedes, other windows
advance. Rapid reversal begins at presented geometry; hit testing uses presented
geometry/depth. Reduce Motion skips movement. Verify repeated arrows, reversal,
click mid-movement, Return, mode/size/inventory cancellation; no stale handoff.
Measure input→first presented change and settled stack with same synthetic/live
fixture, first/warm cached previews, idle/action/additional CPU separately. Full
variants/core smoke/matched baseline NOT RUN: scheduled overnight, PERF-025
for calibrated observer/controlled live fixture.

### P04/P20 – Overview caption visibility (2026-09-09)

Shared stack captions stay visible at low zoom (0.04/0.08/0.2), selected and
unselected, with existing shared font/position/ellipsis. Canvas/Recent retain
zoom fade. Test keyboard/mouse selection, zoom/pinch, resize and inventory fit;
stack movement unchanged. Same first/warm fixture, input→readable settled header,
idle/action/extra CPU and latency separately versus previous build. Full variants
and matched baseline NOT RUN: scheduled overnight; fixture/observer PERF-025.

### P04/P20 – Restore diagonal stacks (2026-09-09)

User rollback supersedes perspective and stackMovement: restore right/down
offset cards with remembered active window brought to front, shared visible
caption, Overview-first tabs and boundary row exits. No depth scaling or new
stack transition. Verify arrows/click/Return, close MRU fallback, Canvas restore,
headers at low zoom. Compare against stack-exit source snapshot and previous
installed build, same safe fixture/cache conditions. Full live/core smoke and
paired CPU/latency comparisons NOT RUN: scheduled overnight; PERF-025 observer
and controlled fixture requirements unchanged.

### P04/P20 – Opaque selection inset (2026-09-09)

Selected window preview receives 8pt inner gap between image and yellow stroke,
filled opaquely with the selected Canvas background color. Underlying windows
must not show through. Shared window renderer across Canvas/Recent/Overview;
app tiles unchanged. Test arrows/click, grouped selection, background change,
zoom and focus transition. Same first/warm fixture, input→settled outline;
idle/action/additional CPU and latency separately. Full variants/core smoke/
matched baseline NOT RUN: scheduled overnight; observer/fixture PERF-025.

P04/P20 selection matte correction: preserve original 4pt border-path outset;
fill existing transparent gap only, no 8pt added padding. Same selection/zoom/
background paths and baseline method as opaque selection inset; supersedes its
spacing requirement. Full variants NOT RUN: scheduled overnight.

### P04/P20 – Long caption rasterization (2026-09-09)

First/last/middle stack windows with short, 71-character and overflowing titles.
Native attributed captions must draw in fixed-height line and tail-truncate;
verify actual rendered pixels, not only string/opacity. Test selected/unselected,
Canvas/Recent/Overview, low zoom, native selection changes. Shared paragraph
truncation and explicit CATextLayer font size/wrapping. Before/after synthetic
fixture, same cache/viewport. Full live/core smoke/paired CPU and latency
NOT RUN: scheduled overnight; fixture/calibrated observer PERF-025.

### P04/P20/P22 – Opt-in Chrome tab counts and right Command (2026-09-09)

Both preferences start off. Chrome counts: Settings click/keyboard activation
shows explanatory copy before requesting Automation; denied permission leaves
option off. Background refresh and restart never request permission. Enabled
and Chrome running: refresh at most every two seconds while overview visible;
no page contents/URLs, only window name/bounds and tab count. Verify 0/1/12 tabs,
multiple windows, duplicate name+bounds (omit ambiguous count), tab open/close,
window move/close, app quit/relaunch, permission revoked, timeout, and disable
clearing labels immediately in Canvas/Recent/Overview. Counter precedes page
caption after stack position; single-line ellipsis and shared metrics retained.

Right Command: Settings click/keyboard toggle, press/release alone opens current
view; repeat closes without activating selection. Left Command, right-Command
chords including C/V/Tab/Shift, mouse chords and repeats must not toggle. Check
all four views, focus animation, shortcut recording, event-tap recovery and
restart with both options independently on/off. Cmd-Tab retains existing mode.
Restore original options after tests; never grant Automation on the user's
behalf just to complete a test.

Boundaries: input to permission dialog (separate user wait), then grant to first
correct caption; tab change to refreshed caption; modifier release to visible/
hidden overview. First and warm process with Chrome already open, same safe
window fixture; cold disabled path must do no Apple Events. Compare pre-change
binary and candidate with same input/fixture: idle CPU, action CPU, additional
CPU separately plus latency/correctness. Full live variants, core smoke and
five-pair comparisons NOT RUN: scheduled overnight; missing controlled browser
fixture/calibrated observer BLOCKED under PERF-025. Source/build identities in
results/2026-09-09-tabs-command/identity.json.

### P04/P07/P15/P20 – Separate desktop overlays (2026-09-09)

Persistent bottom-left search input, independent current-app/history bar, separate
Settings button, separately movable mini-map with fit/return and save-position
buttons over its surface. Test typing directly/clicking field/type-to-search,
up/down/Return, Escape/clear; current app bar and history remain accessible during
search. Clicking history must dispatch to its native button, not map dragging.
Mini-map grab strip moves only map, clamps above Dock and avoids fixed bars;
map click/pan still respects per-view movement policy. All four views show map.
Save/forget/return persists camera per automatic/catalog view, never writes Canvas
layout; existing Canvas saved-camera semantics retained. Test resize at 480/800/
1200 width, Dock/screen changes, no-item/single/large lists, restart and map drag.

Boundaries: input to filtered scene, history selection, saved/returned camera,
map settle and restored pointer/keyboard response. First/warm process with same
safe synthetic fixture and same saved map position. Compare baseline/candidate
idle CPU, action CPU, additional CPU and latency separately; Overview/catalog now
render the mini-map too. Full variants/core smoke/five-pair comparisons NOT RUN:
scheduled overnight. Calibrated observer/controlled live fixtures BLOCKED under
PERF-025; source/build identity in results/2026-09-09-separate-overlays/identity.json.

### P07/P20 – Keyboard-first Settings and search (2026-09-09)

⌘F focuses persistent Search apps from Canvas or Settings; ⌘, toggles sidebar.
Settings text button top right shares ViewModeControl font. Check all views and
sidebar resize, pointer click and keyboard shortcut equivalence. Settings focus
starts on Views; Tab/Shift-Tab cycle all enabled controls in current page (including
color swatches, switches, shortcut recorder, editable fields, expanded AI form,
Back/Close). Space/Return activates buttons; arrows traverse non-text controls;
text editing keeps native caret behavior. Focus outline must be visible and
focused controls scroll into view. Escape backs one level then closes sidebar.
No Sidebar key may switch Canvas view, activate a window or change its selection.
Repeat with macOS Keyboard Navigation disabled; restore test settings afterward.

Boundaries: key down → focused control/visible outline and settled scroll/sidebar;
Space/Return → new setting/page; ⌘F → editable search and first result. Same first/
warm safe fixture, compare baseline and candidate idle/action/additional CPU and
latency separately. Full controls/input variants/core smoke/five-pair comparisons
NOT RUN: scheduled overnight; calibrated observer and controlled live fixture
BLOCKED under PERF-025. Identity in results/2026-09-09-keyboard-settings/identity.json.

P07 search shortcut hint (2026-09-09): ⌘F stays right-aligned within the search
box, including while typing; clear button and text reserve separate space.
Check narrow/sidebar and full-width layout, mouse hint activation, ⌘F, typing,
Escape. Current native synthetic review and short installed AX check; full live
variants/core smoke and baseline idle/action/additional CPU/latency comparisons
NOT RUN: scheduled overnight. Observer BLOCKED under PERF-025. Identity and
report: results/2026-09-09-search-hint/.

P07/P20 light overlay styling (2026-09-09): search and position bars use 58%-opaque
white with black primary/secondary text and weaker shadow. Positions unchanged;
map/Settings unchanged. Verify idle/search/caret/selection/clear/shortcut and
history arrows, full/sidebar widths, light/dark backgrounds and app icon contrast.
Native synthetic review plus installed AX functional check; full variants/core
smoke and baseline idle/action/additional CPU/latency NOT RUN: scheduled overnight.
Observer BLOCKED under PERF-025. Evidence: results/2026-09-09-light-bars/.

### P07/P20 – Temporary overlay color controls (2026-09-09)

Use the same safe overlay fixture and initial values (black text 88%, white
background 58%) for baseline/candidate; check warm updates and cold relaunch.
Toggle both colors by click and Space/Return; drag both sliders, including
0%/100%, and adjust by arrows via Cmd-Shift-T, Tab/Shift-Tab; Escape returns
to Canvas. Both search and position bars must update, with readable percentage
feedback and unchanged layout. Verify editing caret/placeholder and persistence.
Measure input to both bars painted, idle CPU, action CPU and additional CPU
separately; continuous dragging must not stall navigation. Compare shared search
paths with light-bars baseline. Full variants/core smoke and paired comparisons:
NOT RUN: scheduled overnight. Calibrated observer BLOCKED under PERF-025.
Source/build and short functional evidence: results/2026-09-09-temporary-colors/.

P07 search trailing action swap (2026-09-09): inactive search shows Cmd-F;
click field, click hint or press Cmd-F to enter search, replacing hint with X
at the same center. X or Escape clears search and restores hint. Verify empty
and populated queries, stable text width, no overlap, mouse and keyboard paths.
Use the same warm search fixture and cold relaunch as temporary-colors baseline.
Measure input to trailing control replacement, idle/action/additional CPU and
latency separately. Full variants/core smoke and matched comparisons NOT RUN:
scheduled overnight; calibrated observer BLOCKED under PERF-025. Identity and
evidence: results/2026-09-09-search-swap/.

P07/P20 mouse-only temporary palette (2026-09-09): supersedes its Cmd-Shift-T
keyboard path above. Palette buttons and sliders must never become key views
or claim Tab/arrows. Click color or drag slider, then Tab/Shift-Tab must still
switch views; typing in search and Settings retains their established routing.
Search and current-path text use the same 20pt semibold font as view tabs.
Check clipping/ellipsis, short/long captions, empty/filled search, narrow viewport.
Compare same warm/cold fixture against search-swap baseline; measure input to
view change and overlay paint, idle/action/additional CPU and latency separately.
Full variants/core smoke and matched comparison NOT RUN: scheduled overnight.
Safe calibrated observer BLOCKED under PERF-025. Evidence and identity:
results/2026-09-09-mouse-palette/.

P07 search typography and app icon (2026-09-09): search placeholder Search apps…
and Cmd-F hint use regular 20pt font; preserve focus-to-X swap and query editing.
Current-app icon is 32pt in 48pt bar, 8pt top/bottom/left inset and 8pt text gap
(after any history controls). Check long app-name truncation, mouse/keyboard
activation, history hover, typing, Cmd-F, X/Escape and narrow viewport. Same
warm/cold fixture and observer as mouse-palette baseline; input-to-paint latency
and idle/action/additional CPU separately. Full variants/core smoke and paired
comparison NOT RUN: scheduled overnight; observer BLOCKED under PERF-025.
Evidence/source/build: results/2026-09-09-search-type/.

P07/P20 final overlay palette (2026-09-09): replaces temporary tuning controls
with fixed white text at 75% and black background at 10%; no palette hit area
or reserved layout remains. Verify cold launch, Cmd-F/click search, X/Escape,
Tab/Shift-Tab and restored available Overview/minimap area. Same fixture as
search-type baseline with final palette. Measure input-to-paint, idle/action/
additional CPU and latency separately. Full variants/core smoke and matched
comparison NOT RUN: scheduled overnight. Calibrated observer BLOCKED under
PERF-025; evidence and identity: results/2026-09-09-final-colors/.

### P11/P17 – Close confirmation handoff (2026-09-10)

Safe fixture: dedicated iTerm window/session configured to confirm close/quit,
plus an app with a save sheet. Backspace with one/multiple windows, Close Window
and Quit App must reveal a native modal/sheet above OpenPlane, never press its
confirmation. Cancel retains window/card; confirm removes it through inventory.
No-confirm close must leave overview in place. Test delayed prompt, repeat input,
mode switch/dismiss/focus during polling (no late focus steal), terminated app.
Polling is serialized off-main, max 20 checks with 150ms spacing, no idle timer.
Use same warm/cold fixture and observer against final-colors baseline; measure
request-to-visible-dialog and removal latency, idle/action/additional CPU.
Full variants/core smoke and matched baseline NOT RUN: scheduled overnight.
Safe destructive-session fixture/calibrated observer BLOCKED under PERF-025;
evidence/source/build: results/2026-09-10-close-dialog/.

P11/P17 dialog return (2026-09-10): after revealing native confirmation, return
to current OpenPlane view once modal/sheet is absent on two observations or
target process exits; reconcile inventory first. Cancel retains window, Confirm
removes only genuinely closed windows. AX failure is unavailable, never treated
as dismissal. Switching to another app, reopening OpenPlane, view change or new
close request cancels automatic return. Check slow confirmation/quit, transient
AX failure and consecutive sheets. Same safe fixture as close-dialog baseline.
Measure pending-dialog CPU separately from idle, action/additional CPU and
dismissal-to-overview latency. Full variants/core smoke and matched comparison:
NOT RUN: scheduled overnight; safe modal fixture/observer BLOCKED under PERF-025.
Evidence: results/2026-09-10-dialog-return/.

### P11/P17 – Direct close proof and frozen preview (2026-09-10)

On Backspace/Close Window/Quit App, preserve last preview and ignore in-flight
captures/loading/failure updates for requested IDs. Serialized AX probe checks
exact requested elements every 100ms, max 50 iterations. Successful absence
from app AXWindows or invalid element confirms removal; AX errors alone do not.
Remove confirmed card immediately; suppress stale discovery re-additions until
SC inventory drops ID. Duplicate Backspace must not send another close while
pending. Test safe Chrome two-window stack, close during capture, last-window
quit, cancel/save/beforeunload dialog, AX timeout and slow genuine close.
No user sessions may be closed by automation. Measure input-to-removal and
pending-close CPU separately from idle/action/additional CPU; same fixture as
dialog-return baseline. Full variants/core smoke and matched measurements
NOT RUN: scheduled overnight; safe live fixture/observer BLOCKED under PERF-025.

### P04/P17 – Native Overview entry animation (2026-09-10)

Right Command and overview shortcut share entry: discover while hidden, compute
final Overview, animate cards from real screen rects with Core Animation position
and transform for 450ms. No model frame/camera overwrite, no whole-overlay entry
fade; shared headers fade into final position. Test zero/one/many windows, stacks,
portrait/landscape, multiple screens, rapid toggle, arrow/click interruption,
window closing during entry, reduce motion. Existing Recent/Canvas semantics
remain. Measure shortcut-to-first-frame/settled layout and idle/action/additional
CPU, same scene against prior immediate-entry build. Full variants/core smoke
and paired comparison NOT RUN: scheduled overnight. Physical right-modifier
input and calibrated display observer BLOCKED under PERF-025.
Evidence and source/build: results/2026-09-10-close-entry/.

P04/P17 Overview entry depth (2026-09-10): snapshot macOS front-to-back visible
window IDs immediately before reveal. Hold that depth per card during 450ms
entry, then use normal Overview depth; unlisted cards stay behind visible ones.
Verify foreground window from a different app and within one stack, overlapping
windows, changing front window between calls, missing IDs, rapid interruption
and reduce motion. Match source/target rect fixture and baseline close-entry;
measure first-frame occlusion correctness, input-to-settled latency and idle/
action/additional CPU separately. Full variants/core smoke and paired comparison
NOT RUN: scheduled overnight. Physical input/calibrated display observer BLOCKED
under PERF-025. Evidence: results/2026-09-10-entry-depth/.

### P04/P17 – Animated return to overview origin (2026-09-10)

Capture actual foreground window/app when entering OpenPlane; selection changes
and view switching must not alter this return target. Right Command and plain Q
return through the same focus/zoom path as Return, but target saved origin; Return
still activates current selection. Q in search/Settings remains typing, Q repeat
does not activate twice, Cmd-Q unchanged. If exact window closes, prefer another
window of same app; if none, stay with explanatory status. Test Overview/Canvas/
Recent/All apps, changed cursor, two windows in same app, external app switch,
rapid entry cancellation and deleted origin. Existing focus completion and
cancellation semantics must hold. Search single navigation arrow packs left.
Compare same warm/cold fixture against entry-depth baseline, measuring input-to-
first-frame/handoff, idle/action/additional CPU separately. Full variants/core
smoke and paired comparison NOT RUN: scheduled overnight; physical bare-modifier
input/calibrated observer BLOCKED under PERF-025. Source/build and evidence:
results/2026-09-10-return-origin/.

### P04/P17 – Right Command toggle parity (2026-09-11)

From hidden and visible OpenPlane, press bare right Command two, three, and ten
times, including during discovery, entry, focus, return and dismissal. Every
recognized release counts; pending even presses cancel and odd presses cause one
transition after the active transition settles. Final visibility must match total
parity; return must target the original window through the shared focus path.
Repeat with cancellation, reduced motion and each view. Q/Return remain unchanged.
Measure from first/last release to correct settled endpoint, plus idle CPU, action
CPU and additional CPU separately, using the same safe fixture and first-process/
warm-cache conditions as return-origin baseline. Full variants, core smoke and
paired baseline comparison: NOT RUN: scheduled overnight. Physical bare-modifier
input and calibrated display observer: BLOCKED, PERF-025.
Evidence and source/build identity: results/2026-09-11-toggle-parity/.

### P04/P17 – Configurable transition speed (2026-09-11)

Settings → Open / return animation: native slider, 0.5×–4×, default 2×.
Check pointer changes and Tab/Shift-Tab focus, Left/Right adjustments, persistence
after reopening/restart. Right Command entry/return, Return/click selection and Q
origin return share speed; compare 1× (previous timings), 2× (half duration), and
limits. Verify activation occurs once and preview stays aligned during handoff;
rapid toggles retain parity. Test Overview, Recent, Canvas and reduced motion.
Use same safe window fixture with fresh process then warm previews. Measure input
to first frame and settled handoff plus idle/action/additional CPU separately.
Full variants/core smoke and paired baseline: NOT RUN: scheduled overnight.
Physical right Command and calibrated visual latency: BLOCKED under PERF-025.
Source/build/evidence: results/2026-09-11-transition-speed/.

### P04/P17 – Early navigation overlay fade (2026-09-11)

Right Command/Q origin return and Return/click focus: minimap including viewport,
background and controls, plus navigation chrome, fade to zero during first third
of camera travel. Window preview/backdrop/handoff timings remain unchanged.
At default 2× speed controls disappear after about 58 ms (0.3 × 7/12 ÷ 3).
Check cancellation restores all chrome, subsequent entry restores it, rapid
parity toggles, each view, selected/origin differing and configured speed limits.
Compare same safe fixture against transition-speed baseline, fresh and warm
previews; measure first-visible response, overlay-hidden time, completed handoff,
idle/action/additional CPU separately. Full variants/core smoke and paired
comparison NOT RUN: scheduled overnight. Physical modifier input/calibrated
visual observer BLOCKED under PERF-025. Evidence: results/2026-09-11-controls-fade/.

### P04/P07/P15/P20 – Remove the current-app/history strip (2026-09-17)

The bottom-left app-name strip and its Back/Forward controls are removed, including
app-level navigation history. This supersedes earlier strip/history cases in P07
and the September 7/9 overlay additions. Recent's window-use history remains.

On the signed Release app, check Overview, Canvas, Recent and All apps with empty
and populated scenes: no strip, app-name button, hover preview or history arrows;
the former strip area accepts normal canvas input and reserves no overlay space.
Use mouse selection, arrow keys, Return, Cmd-F, typed search, Escape, view clicks
and Tab/Shift-Tab. Search, selected-card headers, Settings, minimap dragging,
Fit/Save and normal activation must still work. Include narrow/full-width windows
and a minimap moved into the former strip area. Return to the starting view,
search and camera after each sequence.

Compare baseline e97c070 and candidate on the same safe fixture and observer.
Measure from input delivery to correct selection, filtered scene, view or native
window activation. Record idle CPU, action CPU and additional CPU separately,
along with correctness and latency; distinguish first/fresh previews from warm
repeated navigation. Do not report removing the requested strip as an optimization
of its former behavior. Full variant/core smoke and repeated pairs:
NOT RUN: scheduled overnight; see the removal report and PERF-025.

### P04/P07/P17/P20 – Centered search and handoff flash (2026-09-17)

Search is horizontally centered in the canvas at all viewport widths. Check
mouse focus, Cmd-F, typing, result arrows, Return and Escape across all four
presentations, with Settings open/closed, Dock sides and narrow/full widths.
Minimap clamping must avoid the centered search area, including dragging.

For handoff, compare source 805f1a0 and candidate using the same safe windows,
closed-app placeholders (including an icon to the right of the selected window),
selection, camera and transition speed. Exit via standalone right Command, Q,
Return and preview click in Canvas and Overview. Observe the entire transition
and its final frames: unrelated app icons/headers and navigation controls fade
out and remain hidden until overview preparation; reopening restores them.
Cover immediate reopen, repeated toggles, interruption, and a metadata refresh
between handoff and reopen. No unrelated app may activate.

Input delivery to the correct native target and disappearance of the overlay
is the completion boundary. Measure idle/action/additional CPU separately and
latency; distinguish first/fresh preview and warm repeat conditions. A hidden
layer unit check is not proof of compositor timing or physical right Command.
Full matched pairs/core smoke: NOT RUN: scheduled overnight. Physical modifier-
only input and frame-resolved capture remain PERF-025 capability gaps.
