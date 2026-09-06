# PERF-018: Laufende App ohne Fenster wieder öffnen

2026-09-06; Codex; P03/P04/P09. Funktionaler Kurzvergleich PASS;
volle Performance-Abnahme NOT RUN: scheduled overnight, 2026-09-07 03:00 Berlin.

## Befund und begrenzte Änderung

Chrome lief mit null AX-Fenstern. Der bisherige Platzhalterpfad aktivierte einen
laufenden Prozess und blendete OpenPlane sofort aus. Der Prozess war danach
Chrome, aber es gab weiterhin kein Chrome-Fenster: Die Menüleiste und die noch
sichtbaren Fenster anderer Apps passten scheinbar nicht zusammen.

Der Sonderpfad wurde entfernt. Auch laufende fensterlose Apps erhalten jetzt den
vorhandenen NSWorkspace-Öffnungsauftrag. Die bestehende Fenstererkennung übernimmt
den Übergang erst bei einem Fenster; andernfalls bleibt der vorhandene sichtbare
Fehler nach Timeout. Keine neue Abstraktion oder zusätzliche Polling-Schleife.
[Begrenzter Diff](fix.diff), [gesamter Produkt-/Testdiff](source.diff).

## Nachweise

- [Build](build.log): signierte Release-App erfolgreich gebaut und installiert.
- [Tests](tests.log): zwei relevante vorhandene Tests bestanden (Such-Return nur
  einmal an richtiges Ziel; fremde Aktivierung während ausstehendem Start ignorieren).
  Diese Tests isolieren nicht den NSWorkspace-Reopen; dafür dient der Live-Vergleich.
- [Live-Rohdaten](live.json), [Runner](live.py): jeweils einmal Chrome über Suche
  ausgewählt und Return zugestellt. Baseline: null Fenster, Chrome frontmost.
  Kandidat: ein Fenster, Chrome frontmost. Kein fremdes Fenster geschlossen.
- Screenshots in `/tmp/openplane-reopen/` visuell geprüft: vorher ausgewählte
  Closed-Chrome-Karte; nachher echtes Chrome-Profilwahlfenster. Rückkehr nach
  OpenPlane zeigt dessen aktuelle Vorschau statt Closed.
- [Umgebung und Identitäten](environment.json): Commit, Dirty-Diff-Hashes und
  installierter Binär-Hash; Baseline-Hash zusätzlich in Live-Rohdaten.

## Grenzen und nächste Abnahme

Persönliche Szene, kein versioniertes Referenzfixture. Chrome-Prozess bereits
warm, fensterlos; OpenPlane je Variante frisch gestartet. Kein Cache-Reset,
keine Aufwärmserie oder fünf A/B-Paare. Pro Variante eine angeforderte Return-
Aktion; Baseline ohne Fenstererfolg, Kandidat mit Fenstererfolg. Die etwa
2,5 Sekunden bis zur Abfrage sind Beobachtungsabstand, keine gemessene Latenz.
Profilwahl wurde nicht bedient und kein Profil automatisch ausgewählt.

Idle-CPU vorher/nachher, Aktions-CPU, zusätzliche CPU, Speicher und Bildzeiten
nicht gemessen; keine Performanceverbesserung behauptet. Keine parallelen
Builds oder Profiler während Live-Eingaben. Exklusiver Live-Lock verwendet.

Direktes Karten-Return ohne Suche, Klick, mehrfaches Return, Prozessneustart,
minimierte Fenster, Fehlerpfad und Core-Smoke sowie wiederholte CPU-Vergleiche:
NOT RUN: scheduled overnight. Präzise Fensterbereitschaft/Präsentationslatenz
und volle Fixtures bleiben BLOCKED gemäß [PERF-001/003/007/018](../../backlog.md).
PERF-018 bleibt VERIFY, nicht vollständig abgeschlossen.

Gewünschte Kandidatenversion installiert, Hash und Signatur geprüft. Keine
Settings geändert/importiert; normale Suche/Öffnung kann Auswahl und Kamera
persistieren. Neu geöffnetes Chrome-Profilwahlfenster für den Nutzer belassen,
ursprünglichen Vordergrund wiederhergestellt. Eigene Test-/Buildjobs beendet.
