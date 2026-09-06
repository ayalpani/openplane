# Verbindliche Regeln für Performance-Tests

Stand: 2026-09-06. Gilt für OpenPlane und seine Entwicklung durch Menschen und
Agenten. Einstieg: [Runbooks](runbooks.md), [Berichtsvorlage](report-template.md),
[Aufgaben und Automatisierung](backlog.md).

## Zweck und heutiger Stand

Performance gehört zur Fertigstellung jeder Funktion. Ein richtiges Ergebnis,
das sich langsam anfühlt, ist nicht vollständig geprüft. Die Live-Oberfläche
ist der maßgebliche Testpfad: echte Tastatur-, Maus- oder Trackpad-Eingaben an
der installierten App, mit Prüfung des sichtbaren Ergebnisses.

Diese Dokumente legen die Regeln und Testfälle fest. Der inzwischen vorhandene
[Live-Pilot mit Review Desk](../../review-desk/README.md) erfasst Teilmengen von
sieben Familien und legt Messberichte unter `results/` ab. Zusätzlich bestehen
der [Pfeiltasten-CPU-Test](../../scripts/measure-navigation.py) und historische
[Messberichte](../gpu-navigation-performance.md). Präzise Start-/Bildlatenzen,
volle Variantenabdeckung und feste Live-Fixtures fehlen weiterhin. Der Pilot
ist kein vollständiger Testdienst oder selbständig arbeitender Entwicklungsagent.

## Interaktive Arbeit und Nachtrunde

Nutzerentscheidung vom 2026-09-06: Die vollständige Live-Suite gehört in die
Nachtrunde, nicht standardmäßig in die Wartezeit jeder kleinen Änderung.

- Tagsüber: schnelle relevante automatische Tests und ein kurzer Live-Funktionstest
  der Änderung. Keine routinemäßigen fünf A/B-Paare oder wiederholten vollständigen
  Core-Smokes für kleine Änderungen. Gezielte Diagnose bei einem konkreten Fehler
  bleibt sinnvoll; umfangreiche Messkampagnen in die Nachtrunde verlagern.
- Nachts: ausstehende volle Live-Abnahmen mit Core-Smoke, Varianten und den unten
  definierten Wiederholungen/A/B-Paaren. Planung täglich 03:00 Europe/Berlin,
  Desktop-Eingaben nur 03:00–07:00 einschließlich rechtzeitiger Wiederherstellung.
  Bei unverändertem vollständig geprüftem Stand keine unnötige Wiederholung.
- Aufgeschobene Prüfungen als `NOT RUN: scheduled overnight` mit Fall-IDs und
  Quell-/Buildstand dokumentieren. Fehlende Fähigkeiten bleiben `BLOCKED`.
  Eine geplante Nachtrunde ist kein Prüfergebnis und keine volle Freigabe.
- Bei gesperrtem/belegtem Desktop nicht erzwingen oder tagsüber nachholen.
  Vorher App/Einstellungen sichern, exklusiven Test-Lock verwenden, danach
  wiederherstellen. Nur neue relevante Ergebnisse oder neue Blockaden melden.
- Vor einem Release bleiben volle Abnahme und sichtbare Prüfungslücken Pflicht.
  Die Nachtrunde prüft und dokumentiert; sie entwickelt keine automatischen Fixes.

Die Codex-Automation `openplane-n-chtliche-performance-suite` führt die Nachtrunde
in diesem Task aus. Die noch fehlenden Runner/Fixtures entstehen nicht durch
Terminplanung; ihre Blockaden bleiben im Backlog nachvollziehbar.

## Verbindliche Regeln im Entwicklungsprozess

1. **Vor der Umsetzung:** betroffene Runbook-IDs benennen. Für neue Funktionen
   neue IDs beziehungsweise Varianten ergänzen, einschließlich Ein-/Ausgabepfad,
   Datenmenge, Erwartung und beobachtbarem Abschluss. Vorhandenes Verhalten als
   Baseline identifizieren; notwendige längere Baseline-Messungen für die
   Nachtrunde vormerken. Bei einer neuen Funktion eine Erstbaseline aufbauen und
   gemeinsame bestehende Abläufe gegen die Vorgängerversion prüfen.
2. **Während der Umsetzung:** funktionale Regressionstests und sinnvolle interne
   Invarianten ergänzen. Direkte Handler-Tests sind kein Live-Performance-Test.
3. **Vor interaktiver Fertigmeldung:** gezielte kurze Prüfung gemäß obiger
   Aufteilung ausführen und ausstehende Live-Abnahmen ausdrücklich nennen.
   Die volle Nachtrunde umfasst bei Produktcode-, Abhängigkeits- oder
   Buildänderungen auch den Core-Smoke. Gemeinsame Rendering-/Eingabe-/Persistenz-
   änderungen benötigen dort vollständige betroffene Familien. Eine kurze
   Tagesprüfung wird nicht als vollständige Performance-Abnahme dargestellt.
4. **Vor einem Release:** alle unterstützten Funktionsfamilien und Eingabevarianten
   des Katalogs im Referenzszenario prüfen; Core-Fälle zusätzlich in der großen
   Szene. Fehlende Abdeckung bleibt sichtbar und blockiert die Behauptung einer
   vollständig performancegeprüften Version. Eine bewusste Ausnahme muss der
   verantwortliche Mensch mit Umfang und Begründung im Bericht festhalten.
5. **Nach der Messung:** Daten interpretieren, Ergebnisstatus setzen, Befunde mit
   Belegen in begrenzte Folgeaufgaben überführen. Keine automatische Änderung
   von Budgets oder Baselines, nur damit ein Test grün wird.

Reine Dokumentationsänderungen ohne Laufzeitwirkung benötigen keine Live-Messung;
der Bericht/Änderungstext nennt `NOT APPLICABLE: documentation only`.

## Feste Messumgebung und Szenario

- Die signierte Release-App aus `/Applications/OpenPlane.app` testen. Commit,
  uncommitted Diff/Hash, Binär-Hash, Buildkonfiguration und Signatur festhalten.
  Ein Commit allein identifiziert eine schmutzige Arbeitskopie nicht eindeutig.
- Hardware, macOS, Bildschirmauflösung, Skalierung, Bildwiederholrate, Strommodus,
  Netz-/Akkubetrieb und auffällige thermische/sonstige Last dokumentieren.
- Sichtbare, entsperrte Sitzung; passende Screen-Recording-/Accessibility-Rechte;
  Fokus vor Eingaben und nach Übergängen prüfen. Bei App-Aktivierung ist der
  Fokuswechsel zur Ziel-App erwartet, bei Pfeiltasten innerhalb OpenPlane nicht.
- Keine Builds, Debugger, Sample-Profiler, Bildschirmaufnahme oder laufende
  Aktivitätsanzeige zusätzlich zum vereinbarten Messverfahren. Messaufwand eines
  benötigten Beobachters muss auf beiden Varianten identisch sein und separat
  kalibriert werden. Profile und Screenshots möglichst in getrennten Diagnoseläufen.
- Ein versioniertes Szenario beschreibt App-Bundle-IDs und Versionen, Testfenster,
  lokale Testdateien, offene/geschlossene Apps, Desktop-Anordnung, Kamerazoom,
  Auswahl, Gruppen, Suche, Einstellungen, Vorschauzustand und Startposition.
  Vor **jedem** gepaarten Lauf denselben Anfangszustand wiederherstellen.
- Drei Szenariogrößen vorbereiten: `S` mit 3 Apps; `R` orientiert an der bestehenden
  [22-Karten-/21-App-Referenz](../navigation-reference.md); `L` mit zunächst
  50 Karten und mehreren Fenstern pro App. R und L sind erst dann ausführbare
  Live-Fixtures, wenn Manifest und lokale, sichere Testinhalte angelegt sind.
  Die bestehende Swift-Geometriefixture öffnet selbst keine echten Apps.
- Zwei Desktops mit unterschiedlichen, exakt gespeicherten Zoomwerten verwenden.
  Nicht nur bequem darstellbare Werte wie 0,125: der frühere Rundungsfehler trat
  bei unterbrochenen Fahrten mit 0,1655411772 auf.
- Nur dedizierte Testfenster/-dokumente für Öffnen, Beenden und Verschieben
  verwenden. Keine fremden ungesicherten Dokumente schließen, keine Nutzercaches
  löschen. Original-App und Einstellungen sichern, nach Abschluss wiederherstellen.

## Was gemessen und wie es benannt wird

| Messgröße | Verbindliche Bedeutung |
| --- | --- |
| OpenPlane-CPU | Nutzer- plus System-CPU-Zeit des OpenPlane-Prozesses über die ganze Phase; `100 × CPU-Sekunden / reale Sekunden`. 100 % entspricht einem Kern. |
| Leerlauf vorher/nachher | Eigene Phasen ohne Eingaben in gleicher sichtbarer App-Situation. Beide Werte berichten. |
| Zusätzliche CPU | Aktions-CPU minus Leerlauf-vorher in **Prozentpunkten**; nur interpretieren, wenn der Leerlauf vergleichbar ist. Nachlaufabweichungen separat erklären. |
| CPU-Sekunden/Aktion | CPU-Zeit geteilt durch tatsächlich ausgeführte Aktionen; verhindert, dass langsamere Eingaben als Verbesserung erscheinen. |
| Reaktionslatenz | Vom zugestellten Eingabeereignis bis zur ersten sichtbaren richtigen Reaktion. Shell-Prozessstart oder Animations-Callback allein reichen nicht. |
| Abschlusslatenz | Vom Ereignis bis zum im Runbook definierten sichtbaren und bedienbaren Endzustand. Geplante Animationsdauer zusätzlich nennen. |
| Bildzeiten | Tatsächliche präsentierte Bilder, Ausreißer und verpasste Bildintervalle relativ zur Bildschirmrate. Ein Display-Link-Callback beweist kein präsentiertes Bild. |
| Speicher | Gleiche Metrik, bevorzugt Process Physical Footprint: vor Aktion, Peak bei festgelegter Abtastung, nach Beruhigung und nach Wiederholungen. Resident Memory nicht damit vermischen. |
| Fehler | Falsches Ziel, verloren gegangene Eingabe, Hänger, Timeout, Absturz und veraltete Anzeige mitzählen. Nicht aus Latenzen still entfernen. |
| Andere Prozesse | Ziel-App, Hilfsprozesse, WindowServer und Systemlast getrennt benennen; keine GPU-/Gesamtrechner-Aussage aus OpenPlane-CPU ableiten. |

Für jedes Runbook sind CPU, Latenz und Korrektheit erforderlich; Speicher und
Bildzeiten nach dessen Vorgabe. Kann eine Größe noch nicht zuverlässig gemessen
werden, bleibt dieses Teilkriterium `BLOCKED`, nicht null oder bestanden.
Video-/AX-Polling-Latenzen brauchen Zeitauflösung und Beobachterkosten im Bericht;
präzise Millisekundenwerte dürfen nicht aus grobem Polling abgeleitet werden.

## Phasen, Wiederholungen und Caches

Standard für eine kontinuierliche Interaktion:

`5 s Leerlauf → festes Eingabeskript → 1 s Nachlauf → 5 s Leerlauf`

Der Nachlauf muss lang genug sein, um die konfigurierte Animation und verzögerte
Speicherung abzudecken. Beim Starten anderer Apps gilt stattdessen das explizite
Bereitschaftskriterium mit Timeout. Wird der Leerlauf nachher nicht erreicht,
zusätzlich 30 Sekunden beobachten und verbleibende Arbeit als Befund melden.

- Den **ersten Lauf separat aufbewahren**. Dann zwei vollständige Aufwärmläufe
  mit derselben Route ausführen und fünf gemessene Warmläufe pro Variante,
  Szenario und relevantem Desktop. Aufwärmen gehört zum Protokoll, nicht in den
  gemittelten Warmwert. Das ist eine neue Vorgabe; alte Zwei-/Drei-Lauf-Experimente
  werden nicht rückwirkend als fünf Läufe dargestellt.
- Baseline und Kandidat in fünf Paaren mit abwechselnder Reihenfolge A/B, B/A
  messen. Fixture, Aufwärmen und Startzustand je Paar gleich herstellen. Bei
  hoher Streuung auf zehn Paare erweitern oder die Störquelle beseitigen.
- Für Prozessstarts: fünf getrennte Neustarts pro App und Variante. Jeden ersten
  Start nach einem Boot beziehungsweise nach einer ausdrücklich kontrollierten
  Cachevorbereitung gesondert ausweisen, nicht zu den Warmstarts mischen.
- Cachezustände explizit benennen: **erste Verwendung im frischen OpenPlane-Prozess**,
  **warmer OpenPlane-Prozess**, **Ziel-App-Prozess beendet/gestartet**, **Ziel-App
  bereits aktiv**, **erster Start nach Boot**. Ein Prozessneustart leert weder
  Dateisystem- noch persistente App-Caches.
- Kein pauschales `purge` und kein Löschen globaler Browser-/System-/Nutzercaches.
  Ein zukünftiger Cache-Reset darf nur eigene, eindeutig benannte Testcaches
  betreffen und muss verifiziert werden. Ohne nachgewiesenen Reset heißt das
  Ergebnis nicht „cache-kalt“. Ein solcher Adapter ist noch nicht implementiert.
- Cachewachstum zusätzlich durch zehn vollständige Durchläufe prüfen. Danach
  30 Sekunden beruhigen lassen und retained Speicher mit dem Zustand nach dem
  Aufwärmen vergleichen. Wiederverwendung muss auch nach echten Titel-/Icon-
  Änderungen, Fensterschließen und erneutem Öffnen korrekt sein.

## Auswertung und Entscheidungsregeln

Pro Fall und Cachezustand Anzahl, arithmetischen Mittelwert, Median, Minimum und
Maximum der Einzellatenzen berichten. Für CPU die Phasenwerte pro Lauf behalten
und deren Median vergleichen. Rohwerte nie durch den einen günstigsten Lauf
ersetzen. Fehlgeschlagene Versuche mit Grund getrennt erhalten.

p95 nur bei mindestens 100 vergleichbaren Einzelereignissen ausweisen, dazu
Stichprobengröße und Streuung je Lauf nennen. Fünf Starts ergeben keinen
belastbaren Tail-Latenz-Nachweis; keine künstliche Präzision oder unabhängige
Stichproben aus stark korrelierten Bildern behaupten.

Es gibt noch keine kalibrierten absoluten Produktbudgets. Folgende **vorläufige
Untersuchungsschwellen** gelten, bis pro Fall Budgets aus stabilen Messungen
festgelegt wurden; sie sind keine erlaubte Verschlechterung:

- CPU: mehr als 10 % relativ **und** 1 Prozentpunkt absolut über der Baseline.
- Latenz: mehr als 10 % relativ **und** 20 ms absolut bei gleichem Endkriterium.
- Speicher nach Beruhigung: mehr als 10 % **und** 10 MiB zusätzlicher Footprint,
  oder über wiederholte gleichartige Zyklen weiter wachsender Speicher.
- Neue Fehlaktionen, Hänger, verlorene Eingaben oder sichtbare Darstellungsfehler
  sind unabhängig von Mittelwerten ein Fehler. Häufigere Bildaussetzer separat
  untersuchen, auch wenn durchschnittliche CPU sinkt.

Ein reproduzierbarer Schwellenübertritt in mindestens vier der fünf gepaarten
Läufe blockiert die Performance-Freigabe und erzeugt eine Regressionsaufgabe.
Widersprüchliche Werte, starke Baseline-Streuung oder Störeinflüsse ergeben
`INCONCLUSIVE`; kein nachgewiesener Gewinn. Kleine auffällige Veränderungen
unter den Schwellen bleiben dokumentiert. Ein akzeptiertes fallbezogenes Budget
hat Vorrang; Änderungen brauchen Begründung und menschliche Prüfung.

Status: `PASS` (alle erforderlichen Kriterien nachweislich erfüllt), `REGRESSION`,
`INCONCLUSIVE`, `BLOCKED`, `NOT RUN`, `NOT APPLICABLE` (mit konkretem Grund).
Eine CPU-Teilprüfung kann bestanden sein, während der Gesamtfall wegen fehlender
Latenzmessung weiterhin `BLOCKED` ist.

## Vom Befund zur nächsten Aufgabe

`Messung → Gültigkeitsprüfung → Interpretation → deduplizierter Befund →
begrenzte Agent-Aufgabe → Fix → gleiche Live-Tests → Review → neue Baseline`

Der Messagent liefert Daten und Beobachtungen; er muss Hypothesen als solche
kennzeichnen. Der Analyse-Schritt unterscheidet Messfehler, Produktregression,
Optimierungspotenzial und externe App-Latenz. Aufgabe und Abnahmekriterien müssen
vor einer späteren automatischen Übergabe feststehen. Nur ein Agent darf die
Testoberfläche für zeitkritische Läufe besitzen; Builds und UI-Läufe anderer
Aufgaben warten. Kein endloser Optimierungsloop und keine automatischen Commits,
Merges oder Baseline-Verschiebungen. Details und noch fehlende Bausteine stehen
im [Backlog](backlog.md).
