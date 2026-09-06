# PERF-017: Tab-Umlauf behält Slide-Richtung

2026-09-06. Tab trägt seine Bewegungsrichtung durch die bestehende FIFO-Warteschlange;
der Sprung vom letzten zum ersten Desktop slidet weiter von links nach rechts.
Direkte Klicks behalten die Indexrichtung. Dauer 180 ms und Strecke 40 Punkte bleiben.
Keine neue Tastenzuordnung.

14 gezielte DesktopTabTests PASS ([Log](tests.log)); neuer Test prüft sieben
Anschläge mit zwei Umläufen, alle Zielkameras, Richtung, Dauer, persistierte Seiten
und vollständig abgearbeitete Warteschlange. [Build](build.log) PASS.

Kurzer Live-Test auf signiertem Release in /Applications PASS: letzter → erster →
zweiter Desktop, zwei abgeschlossene Anschläge mit geprüften Ziel-IDs.
[Runner](live.py), [Rohdaten](live.json). Private Aufnahme
/tmp/openplane-tab-wrap/wrap.mov und Bildfolge frames.png visuell geprüft:
Überblendung mit Bewegung, beide Ziele erreicht. Keine kalibrierte Frameauswertung.
Preferences vollständig wiederhergestellt; eigene Aufnahme beendet.

[Quell-/Buildidentität](environment.json), [begrenzter Fix](fix.diff),
[vollständiger Produkt-/Testdiff](source.diff). Baselinebinary im Live-Protokoll:
vorheriger Settings-Keyboard-Build; kein neuer gemessener A/B-Vergleich.
Persönliche Szene, keine Cachelöschung. Idle-, Aktions- und zusätzliche CPU sowie
kalibrierte Latenz/Framezeiten nicht gemessen; keine Performancegewinn-Behauptung.
Voller P06-Baselinevergleich, schnelle gemischte Eingaben und Core-Smoke:
NOT RUN: scheduled overnight, 2026-09-07 03:00 Europe/Berlin.
Fehlende Messbeobachter weiterhin BLOCKED, siehe
[PERF-001/003/007/017](../../backlog.md). Keine volle Performancefreigabe.
