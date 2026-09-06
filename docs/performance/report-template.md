# Vorlage: Live-Performance-Bericht

Kopieren nach `docs/performance/results/YYYY-MM-DD-<thema>.md`. Rohdaten mit
stabilen relativen Links referenzieren; private Screenshots, Nutzerdokumente und
vollständige persönliche Preferences bleiben außerhalb des Repositorys.
Die Vorlage ist kein Messergebnis. Leere Felder nicht als null interpretieren.

## Fragestellung und Status

- Report-ID / Datum / ausführender Mensch oder Agent:
- Change / Hypothese / betroffene Funktion:
- Runbook-IDs und Varianten:
- Gesamtstatus: PASS / REGRESSION / INCONCLUSIVE / BLOCKED / NOT RUN / NOT APPLICABLE
- Fehlende Prüfungen und Grund / verknüpfte Aufgaben:
- Funktionalität vollständig erhalten? Beleg oder Einschränkung:

## Reproduzierbare Umgebung

| Feld | Baseline A | Kandidat B |
| --- | --- | --- |
| Commit, Dirty-Diff-Artefakt und Hash | | |
| App-Binär-Hash, Signatur, Buildkonfiguration | | |
| Installierter Pfad, Version, Prozess/Hilfsprozess-Zuordnung | | |
| Hardware, macOS, Bildschirmrate/Auflösung/Skalierung | | |
| Strommodus, thermische Hinweise, Hintergrundlast | | |
| Fixture-ID/Hash, App-Versionen und Testdateien | | |
| Desktop, Startauswahl, Kamera inkl. exaktem Zoom | | |
| Gruppen-/Such-/Settings-/Vorschauzustand | | |
| Cachezustand und verifizierte Vorbereitung | | |
| Beobachter, Auflösung, Messaufwand, Uhr/CPU-Einheiten | | |

## Ausführung

- Eingabesequenz, Zustellintervalle, Strecke, Dauer, Wiederholungen:
- Sichtbares Reaktions- und Abschlusskriterium, Timeout:
- Reset vor jedem Lauf, erste Verwendung, zwei Aufwärmläufe:
- Fünf A/B-Paare und Reihenfolge; Abweichungen begründen:
- Angeforderte / zugestellte / akzeptierte / erfolgreiche Aktionen:
- Ungültige, abgebrochene, fehlgeschlagene Läufe mit Grund und Rohdatenlink:
- Funktionale Beobachtungen und separate Screenshot-/Profilreferenzen:

## Rohdatenvertrag

JSON/CSV je nach Beobachter; ein Datensatz pro Lauf mit mindestens:
`report_id`, `case_id`, `variant`, `build_hash`, `fixture_hash`, `pair_id`,
`cache_state`, `warmup`, `trial`, `desktop`, `status`, `invalid_reason`,
`action_count_requested/delivered/accepted/succeeded`, `phases`, `events`,
`errors`, `artifacts`.

Pro Phase: Name, monotone Start-/Endzeit, Dauer in Sekunden, pro gemessenem
Prozess CPU-Zeit in Sekunden und daraus CPU-Prozent. Ereignisse: Eingabetyp,
Ziel-ID aus Testmanifest, monotone Zustellzeit, erste sichtbare Reaktion,
Bereitschaft/Abschluss, Erfolg/Timeout. Speicher mit Metrik, Einheit und Zeitpunkt;
Bildzeiten mit Herkunft, Einheit und Abtastrate. Fehlende Werte `null` plus Grund.
Ein PID-Wechsel darf nicht mit CPU-Zählern des vorherigen Prozesses verrechnet werden.

Der vorhandene Pfeiltasten-Runner liefert nur einen Teil dieser Felder. Seine
Originaldaten erhalten und die fehlenden Metadaten im Bericht ergänzen; noch
nicht erfasste Ereignisse nicht nachträglich erfinden.

## Ergebnisse

Tabellen je Runbook, Desktop, Fixture, Cachezustand und gegebenenfalls Ziel-App.

| Phase / Größe | A | B | Differenz absolut | Differenz relativ | n / Streuung |
| --- | --- | --- | --- | --- | --- |
| Idle-CPU vorher, % eines Kerns | | | Prozentpunkte | | |
| Aktions-CPU, % eines Kerns | | | Prozentpunkte | | |
| Zusätzliche CPU gegenüber Idle vorher | | | Prozentpunkte | | |
| CPU-Sekunden je erfolgreicher Aktion | | | Sekunden | | |
| Nachlauf-CPU / Idle-CPU nachher | | | Prozentpunkte | | |
| Reaktionslatenz, ms | | | ms | | |
| Abschlusslatenz, ms | | | ms | | |
| Startlatenz je Ziel-App, ms | | | ms | | |
| Bildzeiten / verpasste Bildintervalle | | | | | |
| Speicher vorher / Peak / nach Ruhe, MiB | | | MiB | | |
| Fehler / Timeouts / falsche Ziele | | | Anzahl | | |

Latenzen: Mittelwert, Median, Minimum, Maximum; p95 nur bei ausreichender
Stichprobe gemäß Policy. CPU: alle Phasenwerte und Median je Variante. Relative
Differenzen bei Baseline null `N/A`. Erste/kalte Läufe nicht mit Warmwerten mischen.
Startdurchschnitte je App berichten; optionales Gesamtmittel mit App-Gewichtung.

## Interpretation und Entscheidung

- Beobachtung, unmittelbar durch Daten belegt:
- Hypothese / alternative Erklärung / benötigtes Profil:
- Messgültigkeit, Streuung, Beobachterkosten und Grenzen der Aussage:
- Angewandtes Budget / Untersuchungsschwelle; reproduzierbarer Übertritt:
- Funktionale oder visuelle Verschlechterung, auch bei sinkender CPU:
- Entscheidung und verknüpfte Befund-/Aufgaben-IDs:
- Nächster begrenzter Schritt / verantwortlicher Agent oder Mensch:
- Baseline bleibt unverändert oder begründete, überprüfte Aktualisierung:

## Abschluss

- Originale App/Einstellungen wiederhergestellt beziehungsweise gewünschte
  getestete Release-Version installiert und Hash verifiziert:
- Eigene Eingaben, Mess-, Build- und Profilprozesse beendet:
- Offene Performance-Prüfungen in Fertigmeldung/Review ausdrücklich genannt:
