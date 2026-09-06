# Performance-Aufgaben und künftiger Agentenablauf

Dies ist der dauerhafte lokale Backlog. Es werden hiermit weder externe Tickets
versendet noch Agenten oder wiederkehrende Jobs gestartet. Priorität gilt zuerst
dem Aufbau des Testprozesses; der Navigator-Umbau wartet zugunsten dieser Arbeit.

## Aufgabenregister

| ID | Aufgabe | Status | Abnahme / Abhängigkeit |
| --- | --- | --- | --- |
| PERF-001 | Versionierte, sichere Live-Fixtures S/R/L mit zwei Desktops | READY | Manifest mit App-/Fenster-IDs, lokalen Dummy-Daten, Layout/Zoom/Settings und Reset; fehlende Apps erkannt; Originalzustand wiederherstellbar. R an Geometrie-Referenz orientieren, keine persönlichen Dokumente kopieren. |
| PERF-002 | Vorhandenen Pfeiltasten-Runner zu P01 ausbauen | WAITING: 001 | Szenario statt fester Desktopnamen; reproduzierbarer Start pro Trial, separate erste/warm-Läufe, A/B-Paare, akzeptierte Ziele und Metadaten, Abbruch/Cleanup. Vorhandene CPU-Zähler und Mach-Timebase-Selbstprüfung weiterverwenden. |
| PERF-003 | Live-Latenz-, Bildzeit- und Speicherbeobachter | READY | Eingabe, erste sichtbare Reaktion und Abschluss unabhängig korrelierbar; Auflösung/Overhead kalibriert; Bildpräsentation nicht mit Callback gleichgesetzt; PID-Wechsel und fehlende Rechte behandelt. Zunächst P01/P03/P05 als begrenzter Pilot. |
| PERF-004 | P02-Zoomrunner mit echten Key-down/Key-up und Gesten | WAITING: 001, 003 | Grenzen beobachtet, zehn Zyklen plus Umkehr, erste/warm-Läufe, Tasten garantiert gelöst; Pinch nur dann als getestet markieren, wenn der echte Eingabepfad ausgeführt wurde. |
| PERF-005 | P03/P04-App-Aktivierungs- und Startmessung | WAITING: 001, 003 | Bereitschaftsvertrag pro App; dieselbe/mehrere/alle Apps; Prozesszustände getrennt; fünf Neustarts je App; Durchschnitt pro App und Fehler/Timeout; keine fremden Dokumente beenden. |
| PERF-006 | P05-OpenPlane-Startmessung | WAITING: 001, 003 | Fünf Neustarts, Canvas/Interaktion/Vorschauen als getrennte Meilensteine, vollständige CPU-/Speicherzuordnung ab Prozessstart; bestehendes Profil und Ersteinrichtung getrennt. |
| PERF-007 | Übrige Live-Familien P06–P14 automatisieren | WAITING: 001, 003 | Vor Vergabe in einzelne Aufgaben pro Runbook aufteilen; jede mit Eingabefixture, Erwartungen, Rohdaten, Wiederherstellung und mindestens einem nachgewiesenen Fehler-/Abbruchfall. |
| PERF-008 | Berichte interpretieren, Budgets kalibrieren, Befunde deduplizieren | WAITING: 002, 003 | Schema prüfen; CPU total/zusätzlich korrekt; ungültige/fehlende Messungen blockieren; Erst-/Warmläufe trennen; deterministische Testdaten für Regression, Streuung, fehlende Felder und Doppelbefunde. Budgets nicht selbst hochsetzen. |
| PERF-009 | Begrenzte Agentenübergabe und Entwicklungs-Gate | WAITING: 008 | Exklusiver Live-Test-Lease, begrenzte Aufgabenübergabe, Pflicht-Retest, Abbruch/Resume, Ressourcenlimit und menschlicher Review. Zuerst manuell auslösen; kein Scheduler in diesem Schritt. |
| PERF-010 | Navigator-Darstellung ohne wiederholtes Aufbauen aktualisieren | EVIDENCE; zurückgestellt | P01/P03/P07/P13, passende Cache-Invalidierung, volle Funktion/Accessibility erhalten; neue fünf-Paar-Messung. Diagnose unten ist Obergrenze, kein fertiger Gewinn. |
| PERF-011 | Zoom-Kamera und Kartengeometrie gemeinsam an Core Animation übergeben | VERIFY / BLOCKED | Kandidat installiert, 83 Tests bestanden. Fünf vollständige Debug-off-Paare: Aktions-CPU 27,42 → 26,27 %, gepaarte CPU-Zeit −1,4 bis −7,1 %. Kleine Teilverbesserung; 10-%-Nutzensziel nicht erfüllt. Volle Abnahme/Beobachter offen, Debug-on-Absturz siehe 012. |
| PERF-012 | Absturz beim Zeichnen der Zoom-Debuganzeige | VERIFY | Schriftinstanz pro Canvas halten; identische Darstellung. Isolierte Reproduktion mit kurzlebiger Monospace-Schrift stürzt ab, gehaltene Schrift besteht 100.000 Messungen; 84 Tests inkl. 1.200 Debug-Redraws grün. Frische Baseline auch live abgestürzt; Kandidat besteht 20 Zoomrouten über fünf Starts sowie gehaltene Zoomtasten, Anzeige visuell geprüft. Funktionaler Fix bestätigt; vollständige Performance-Abnahme weiterhin offen, siehe neuen Bericht. |

| PERF-013 | Kosten des Punktrasters isolieren, Darstellung erhalten | EVIDENCE / Schalter VERIFY | Fünf vollständige An/Aus-Paare je P01/P02/P06: Zoom 26,75 → 20,75 % CPU, Desktopwechsel 10,29 → 9,50 %, Navigation kein Vorteil. Aus ist Diagnose, kein Gewinn. Standardmäßig aktiver Menüschalter bleibt. 128er-Kachel wegen veränderter Punktkanten vor CPU-A/B verworfen; 256er-Darstellung erhalten. Volle Frame-/GPU-/Variantenabnahme offen. [Bericht](results/2026-09-06-grid-cost/report.md). |

| PERF-014 | Desktopwechsel an Tempo der App-Kartennavigation angleichen | VERIFY / Prüfung gekürzt | Gemeinsame 180-ms-Dauer statt 280 ms installiert; eine Produktzeile. 85 Tests in 5,569 s bestanden; zwei vollständige P06-A/B-Paare, 19 Routen insgesamt. Weitere Live-Prüfung auf Nutzerwunsch beendet; schnelle Eingaben/Core-Smoke NOT RUN, volle Frame-/Latenzabnahme offen. [Bericht](results/2026-09-06-desktop-speed/report.md). |

| PERF-015 | Desktop direkt überblenden statt über Hintergrundfarbe | VERIFY / Nachtrunde | Core-Animation-Fade für Szene und HUD über 180 ms; Zielkamera sofort gesetzt, kein einfarbiges Overlay. Kurzer Live-Hin/Rückvergleich und sichtbare Zwischenbilder geprüft. Volle CPU-/Frame-/Speicher- und Variantenabnahme NOT RUN: scheduled overnight. [Bericht](results/2026-09-06-desktop-crossfade/report.md). |

| PERF-016 | Schnelle Desktop-Tab-Anschläge vollständig abarbeiten | VERIFY / Nachtrunde | Tab/Shift-Tab während Überblendung in FIFO-Reihenfolge ausführen; relative Ziele erst beim Abarbeiten berechnen. Bestehende 180-ms-Direktüberblendung, zyklische Navigation und Autorepeat-Regel erhalten. Gezielte Tests und kurzer Burst-Vergleich; volle Performance-/Variantenabnahme nachts. [Bericht](results/2026-09-06-tab-queue/report.md). |

| PERF-017 | Desktop-Fade mit dezenter richtungsabhängiger Bewegung | VERIFY / Nachtrunde | 40 Punkte Slide der ankommenden Karten/Raster zusammen mit Fade, insgesamt 180 ms. Tab-Richtung bleibt auch beim zyklischen Umlauf vorwärts; Klickrichtung aus Desktopreihenfolge. Kamera exakt erhalten, FIFO bleibt. [Umlauf-Korrektur](results/2026-09-06-tab-wrap/report.md). Gezielte Tests und kurzer Live-Bildvergleich; volle Performanceabnahme ab nächster Nachtrunde. [Bericht](results/2026-09-06-desktop-slide/report.md). |
| PERF-018 | Laufende App ohne Fenster wieder öffnen | VERIFY / Nachtrunde | Aktivierung allein ließ Canvas verschwinden, ohne Chrome-Fenster zu öffnen. Einheitlicher Öffnungspfad wartet auf Fenster; kurzer Live-Vergleich 0 → 1 Fenster bestätigt. P03/P04/P09 volle Varianten und Performance offen. [Bericht](results/2026-09-06-reopen-window/report.md). |
| PERF-019 | Hilfsfenster als falsche Vorschaukarten | VERIFY / Nachtrunde | Fensterindividuelle AX-Zuordnung statt Prozessfreigabe; unbenannter Geometrie-Fallback begrenzt. Hilfsfenster-Fixture vor/nach bestätigt, Chrome-Echtfenster erhalten. Ursprüngliche Chrome-Startsequenz und volle P03/P04/P10-Abnahme offen. [Bericht](results/2026-09-06-window-filter/report.md). |
| PERF-020 | Einstellungen als separates Seitenpanel | VERIFY / Nachtrunde | Weiße gruppierte Einstellungen rechts, eigener Viewport statt Overlay; Kamera/Platzierungen bleiben erhalten. Elf gezielte Tests und kurzer Live-Schalter-/Schließtest bestanden. Volle P13 und Viewport-Regressionsfälle offen. [Bericht](results/2026-09-06-settings-panel/report.md). [Runde Schieber](results/2026-09-06-round-switches/report.md). [Animation/Zeilen](results/2026-09-06-settings-motion/report.md). [Keyboard](results/2026-09-06-settings-keyboard/report.md). |
| PERF-021 | Desktop-Plus und eindeutiger Settings-Einstieg | VERIFY / Nachtrunde | Plus nach letzter Desktop-Registerkarte und +-Taste; Tab nur bestehende Desktops. Settings im Minimap-Kopf, Footer bereinigt. [Bericht](results/2026-09-06-desktop-add/report.md). [Sichtbarkeit/Ausrichtung](results/2026-09-06-minimap-controls/report.md). |

`READY` bedeutet ausführbare Entwicklungsaufgabe, nicht fertige Testfähigkeit.
`WAITING` braucht erst die genannten Bausteine. Für große Registerpunkte muss der
Analyse-Schritt vor Delegation einen konkreten, begrenzten Teilauftrag erzeugen.

## Bestehende Befunde

### PERF-012: Mehrere vermeintliche Fokusabbrüche waren App-Abstürze

Fix vom 2026-09-06: [Bericht und Rohdaten](results/2026-09-06-debug-label/report.md).
Der Text-/CoreText-Fehler lässt sich ohne OpenPlane mit wiederholtem Anfordern
und Freigeben von `NSFont.monospacedSystemFont` reproduzieren, auch mit konstantem
Text und ohne Multiplikationszeichen. Eine gehaltene Schriftinstanz verhindert
den Fehler in den kontrollierten Tests. Der Canvas hält deshalb genau diese
Schrift mit unveränderten Parametern für seine Lebensdauer. Keine Deaktivierung
der Anzeige, keine geänderte Schrift oder abgefangene/verschluckte Exception.
Die genaue interne Ursache in macOS ist damit nicht bewiesen; der auslösende
Aufruf-/Lebenszykluspfad und der wirksame Fix sind experimentell eingegrenzt.

Die Wiederaufnahme am 6. September ordnete mehrere Abbrüche anhand ihrer PIDs
den [Crashberichten](results/2026-09-05-p02-fix/crash-summary.json) zu.
Beide Builds sind betroffen, auch A ohne PERF-011. Der Stack führt über
`drawDebugInformation` → `sizeWithAttributes` → CoreText `TAttributes::ApplyFont`
zu „attempt to insert nil object“. Die genaue Ursache ist noch unbewiesen.
Die frühere reine Fokus-/Sitzungserklärung war unvollständig.

Begrenzter Auftrag: Attribute-/Font-Lebensdauer und mögliche Wiedereintritte
im Debug-Textpfad untersuchen, reproduzierbaren Test ergänzen und den Fehler
bei eingeschalteter Anzeige beheben. Danach P02/P13 und Core-Smoke sowie
CPU/Latenzvergleich mit identischem Debugzustand. Die separat gemessene Variante
mit ausgeschalteter Anzeige dient nur der Isolation von PERF-011, nicht als
Fehlerbehebung oder Freigabe. Keine dauerhafte Änderung der Nutzereinstellung.

### PERF-011: Zoom-Update als begrenzter Fix-Kandidat

Entscheidung nach Nutzerbesprechung: winzige Bereinigung behalten, den Ansatz
„doppelten Kamera-Aufruf entfernen“ als **ausgeschöpft** festhalten. Nicht erneut
als großen CPU-Hebel versuchen, sofern keine neue konkrete Evidenz vorliegt.
Der größere Zoom-Darstellungsaufwand ist eine andere Untersuchung und folgt erst
nach der Absturzbehebung; kein weiterer Optimierungsversuch in PERF-012.

Aktueller Stand 2026-09-06: [abgeschlossener CPU-Teilvergleich und Live-Smoke](results/2026-09-05-p02-fix/report.md).
Fünf vollständige Paare AB/BA/AB/BA/AB mit identischer Startkamera, nativen
Tasteneingaben und auf beiden Builds ausgeschalteter Debuganzeige. CPU-Zeit
in allen Paaren niedriger (Median der gepaarten Reduktionen 3,53 %), aber
vorgeschlagenes 10-%-Ziel nicht erreicht. Kandidat bleibt uncommittiert erhalten
und installiert; ursprüngliche Einstellungen wiederhergestellt. P01/02/03/05/06/14
als Live-Smoke-Teilmengen auf A/B ausgeführt, Screenshots an Zoomgrenzen angesehen.
P04/volle Varianten sowie Bild-/Latenzbeobachtung fehlen; keine volle Abnahme.
Mehrere frühere Fokusabbrüche konnten App-Abstürzen zugeordnet werden (PERF-012).

Historischer Zwischenstand: [Fix-Versuch und unvollständiger Vergleich](results/2026-09-05-p02-fix/report-initial.md).
Die vorgeschlagene Verzweigung ist umgesetzt und gebaut; 83 Tests erfolgreich.
Ein Paar zeigt 26,59 → 21,78 % Aktions-CPU, aber 7,06 → 8,42 s Eingabedauer;
CPU-Sekunden nur 1,878 → 1,835. Kein belastbarer Gewinn. Nach zwei Fokusabbrüchen
weitere Eingaben gestoppt; Vordergrund `loginwindow`. Ursprüngliche App wieder
installiert. Sichtbare Sitzung, gültige Paare und Live-Smoke vor Abschluss nötig.

[Diagnose und genaue A/B-Abnahme](results/2026-09-05-p02-diagnosis/report.md)
zu `2026-09-05-review-004:inspect-current-p02`. Keine Produktänderung.
Der Kamera-Setter ruft erst `updateSceneCamera`, bei Zoomänderung anschließend
`synchronizeScene` auf, das die Kamera nochmals innerhalb seiner Transaktion
aktualisiert. Das separate Live-Stackprofil zeigt Commit-/Zeichenarbeit unter
beiden Aufrufen. Hypothese: Ein direkter Aufruf der Szenensynchronisation beim
Zoom spart die erste separate Übergabe. Keine Zusage einer bestimmten Ersparnis.

Umfang eines späteren Versuchs: nur die Verzweigung im Kamera-Setter;
gleiche Geometrie, Inhalte, Eingaben und Animationen. Kein neuer Cache und kein
Raster-/Textumbau. Abnahme mit frischer Baseline derselben festen Szene,
gezählten erfolgreichen Zyklen, Bild-/Reaktionszeiten, Speicher und Core-Smoke;
genaue Varianten und vorgeschlagenes Nutzensziel stehen im Bericht.

Die fehlende P02-Beobachtung ergänzt **PERF-003/004**, statt dafür eine zweite
allgemeine Messinfrastruktur-Aufgabe anzulegen: zugestellte Taps, Grenz-No-ops,
abgeschlossene Bewegungen und tatsächliche Bildpräsentation unterscheiden.
Die Pilotroute mit 45 Taps je Richtung ist keine Zählung erfolgreicher Zoomschritte.
PERF-011 bleibt offen bis zu frischem A/B-Nachweis und funktionaler Prüfung.

### PERF-010: Navigator ist ein belegter Kandidat

Im [Diagnosebericht](../gpu-navigation-performance.md) und den
[Rohdaten](../navigator-diagnostic-cpu.json) senkte ein eingefrorener Navigator
die OpenPlane-CPU während echter Pfeiltasten-Navigation von 8,16 auf 5,19 % und
von 7,78 auf 4,93 % auf den zwei Desktops. Je Variante zwei Läufe, alte Methode;
noch keine Erfüllung der neuen fünf-Paar-Vorgabe. Kamera/Minimap/Auswahl blieben
aktiv, die Navigator-Aktualisierung wurde diagnostisch weggelassen.

Interpretation: ungefähr drei CPU-Prozentpunkte lagen in diesem Versuch am
Navigator-Update samt ausgelöster Darstellung/Layoutarbeit. Titel, Icon, Fade,
Tooltip und Accessibility sind damit nicht einzeln als Ursache isoliert.
36 % sind eine experimentelle Obergrenze. Vollständige Funktionalität muss bei
einer Umsetzung erhalten bleiben. Diese Aufgabe ist noch nicht umgesetzt.

Abnahme zusätzlich zu CPU/Latenz: richtiger App-Name/Icon sofort sichtbar,
Fensterwechsel innerhalb einer App, Titel-/Icon-Änderung, Hover/History, Klick,
Suche, Desktopwechsel und Accessibility stimmen. Speichergewinn/-kosten nach
vielen verschiedenen Apps messen; Cacheeinträge dürfen nicht unbegrenzt wachsen.

### Bereits bearbeitete Probleme nicht neu eröffnen ohne neue Evidenz

Retained Canvas, native Kamerafahrten und der Rundungsfehler bei unterbrochenen
Fahrten sind im [bestehenden Bericht](../gpu-navigation-performance.md) beschrieben.
Die letzten 83 Unit-/Regressionstests sind historische Evidenz; sie ersetzen
weder heutige Live-Abdeckung noch eine neue Vorher-/Nachher-Messung.

## Vorlage für einen abgeleiteten Arbeitsauftrag

```text
ID / Titel:
Status: TRIAGE | READY | ASSIGNED | IN PROGRESS | VERIFY | DONE | BLOCKED
Runbook-ID, Variante, Szenario, Cachezustand:
Report-ID und Rohdatenlinks, Baseline-/Kandidat-Hash:
Beobachtetes Problem und Reproduktion:
Messgültigkeit / Streuung / Größe / Häufigkeit im Nutzerablauf:
Hypothese (ausdrücklich kein gesicherter Befund):
Erwartetes Verhalten und unveränderliche Funktionen:
Kleinster sinnvoller Arbeitsumfang / ausdrücklich ausgeschlossener Umfang:
Messbare Abnahme, funktionale Checks, nötige A/B-Fälle:
Abhängigkeiten, Testgeräte-/UI-Lease, Ressourcen-/Zeitgrenze:
Verantwortlicher Agent/Mensch, Versuchszähler:
Ergebnis, Retest-Bericht, Entscheidung/Review:
```

## So soll der Kreislauf später laufen

1. **Auslösen:** Change nennt Runbook-IDs; eine manuelle Entwicklungsaktion startet
   zunächst den Testlauf. Neue Funktion ohne Fall wird als Abdeckungslücke gemeldet.
2. **Ressourcen sichern:** genau ein Besitzer für Test-Mac/Live-Sitzung; andere
   Builds/Agenten dürfen die Messung nicht beeinflussen. Timeout und Cleanup schon
   vor Eingaben registrieren, Nutzerinteraktion stoppt die Automatik.
3. **Messen:** Baseline und Kandidat nach Policy. Daten schreiben, auch bei Abbruch.
   Ohne entsperrte Sitzung/korrekte Fixture `BLOCKED`, keine Tastatureingaben auf
   Verdacht. Für lange Abläufe aussagekräftige Fortschrittsmeldungen ermöglichen.
4. **Validieren und interpretieren:** Parser prüft Schema, Versionen, Prozess-
   Zuordnung, Cachezustände, Messgrenzen und Fehlerrate vor einer Bewertung.
   Unvollständige Werte erzeugen zuerst eine Messinfrastruktur-Aufgabe.
5. **Befund ableiten:** nach Runbook + Symptom + vermuteter Komponente + Fixture
   deduplizieren; neue Evidenz an bestehende Aufgabe hängen. Häufige Core-Abläufe
   und reproduzierbare Regressionen priorisieren; Fremd-App-Startkosten nicht
   automatisch als OpenPlane-Fehler etikettieren.
6. **Begrenzten Fix zuweisen:** Agent erhält Auftrag nach obiger Vorlage, Mess-
   belege und Funktionsvertrag. Zunächst höchstens eine Fix-Aufgabe gleichzeitig
   in diesem Projekt; höchstens zwei erfolglose Optimierungsversuche pro Befund,
   dann `BLOCKED`/Review statt Endlosschleife. Keine Delegation ohne konkrete Aufgabe.
7. **Prüfen:** Agent führt funktionale Checks und gleiche Live-Fälle erneut aus.
   Niedrigere CPU durch längere Wartezeiten, stale Inhalte, deaktivierte Effekte
   oder ausgelassene Ereignisse ist keine erfolgreiche Optimierung.
8. **Abschließen:** Review akzeptiert Ergebnis oder fordert weitere Untersuchung.
   Aufgabe erst mit Retest-Beleg `DONE`; Baseline bewusst aktualisieren. Automatische
   Agentenarbeit beinhaltet keine automatische Veröffentlichung/Merge/Budgetlockerung.
   Aktive Testjobs enden, normale App und Einstellungen werden wiederhergestellt.

Automatisierbar sind später Datenaufnahme, Auswertung, Aufgabenentwurf und
begrenzte Agentenübergabe. Der heutige Stand ist die Prozessdefinition und das
Aufgabenregister. Die technische Ausführung dieser Kette ist noch offen.


## Erster ausführbarer Review-Desk-Pilot

[Review Desk](../../review-desk/README.md) implementiert jetzt die lokale
Entscheidungsvorlage, gespeicherte Entscheidungen, Audit-Historie, Export und
Arbeitswarteschlange. Ein begrenzter Live-Runner erfasst Teilmengen von sieben
Runbook-Familien. P01 hat noch keine vollständige Fixture-/A/B-Steuerung;
P02/P03/P05/P06/P09/P14 liefern nur die im Bericht beschriebenen Teilmessungen.
PERF-002/004/005/006/007 sind damit teilweise begonnen, nicht vollständig erledigt.
Eine datengestützte Auswertung erzeugt einen begrenzten Untersuchungsauftrag aus
auffälligen CPU-Werten. PERF-008 bleibt für volle Policy-Auswertung offen.

Der Human-in-the-loop-Teil von PERF-009 ist als lokaler Pilot vorhanden.
Angenommene Vorschläge werden in die Warteschlange übernommen; ein Agent wird
noch nicht automatisch beauftragt und kein Fix wird automatisch ausgeführt.
Ergebnisse, Einschränkungen und Vorschläge stehen beim jeweiligen Lauf unter
`results/`, Entscheidungen separat in der lokalen Review-Desk-Ablage.


### Ausführung tagsüber / nachts (Nutzerentscheidung 2026-09-06)

Kleine Änderungen tagsüber kurz funktional prüfen; vollständige Live-Suite und
fünf-Paar-Messungen in die tägliche 03:00-Nachtrunde verschieben. Automation:
`openplane-n-chtliche-performance-suite`, Nachtfenster 03:00–07:00 Europe/Berlin.
Zunächst offene Abnahme PERF-014 und weitere offene Fälle anhand des tatsächlich
getesteten Quell-/Buildstands bearbeiten. Bereits vorhandene Belege nicht pauschal
wiederholen; fehlende Fähigkeiten aus PERF-001/003–007 bleiben BLOCKED. Keine
automatischen Produktänderungen. Planung allein schließt keinen Prüfpunkt.

Verifikation dieser Prozessänderung: NOT APPLICABLE (nur Dokumentation und
Terminplanung, keine Produkt-/Laufzeitänderung); keine neue Live-Suite gestartet.


Nachtrunde 2026-09-06 vom Nutzer vor Live-Eingaben auf morgen verschoben:
[Vorprüfung/NOT RUN](results/2026-09-06-night-001/report.md). Nächster regulärer
Termin 2026-09-07 03:00 Europe/Berlin; Animation wird jetzt interaktiv bearbeitet.

PERF-020 Ergänzung: [Settings-Schrift, Panelbreite und Farbring](results/2026-09-06-settings-size/report.md); volle Performanceabnahme weiterhin offen.

PERF-020 Ergänzung: [Mausgrenze des Settings-Panels](results/2026-09-06-settings-pointer/report.md); volle Varianten-/Performanceprüfung nachts.

PERF-020 Vereinfachung: [Sofortige Auswahl als einziges Verhalten](results/2026-09-06-selection-fixed/report.md), Nachtrunden-Abnahme offen.

## PERF-022 – Chronological Mode und All apps vollständig live abnehmen

- Status: OPEN; Teil-Funktionstest vorhanden, vollständige Messadapter BLOCKED.
- Bericht: [Chronological-Prototyp](results/2026-09-07-chronological/report.md).
- Fälle: P15/P16 sowie betroffene Varianten P01–P04, P09–P14. Sichere
  Mehrfenster-Fixture, gehaltenes Command mit einzeln gesteuerten Key-ups,
  Fokus-/Frame-Latenzbeobachter und reproduzierbare App-Startfehler bereitstellen.
- Erste CPU-Stichproben des Prototyps sind wegen unterschiedlicher Aufwärmung und
  Messdauer INCONCLUSIVE. Gleiche Fixture, gleiche Quellen/Binäridentität und
  Messgrenzen verwenden; idle/action/additional und Latenz getrennt berichten.
- Abschluss erst nach frischer Live-Funktionsprüfung und vollständigem gepaartem
  Vergleich; keine Regression durch verloren gegangene Fokusereignisse, falsche
  Return-Ziele oder Überschreiben freier Canvas-Positionen akzeptieren.
- Vollständige Varianten: NOT RUN: scheduled overnight, autorisierte 03:00-Runde.
  Keine neue Automation und keine unbeaufsichtigten Produktänderungen anlegen.
