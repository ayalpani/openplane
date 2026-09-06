# PERF-015: Direkte Desktopüberblendung

Nutzerauftrag: Neuen Desktop innerhalb der vorhandenen 180 ms einfaden, ohne
auffälligen Wechsel über die Hintergrundfarbe. Tagesprüfung gemäß aktualisierter
Policy: gezielte Tests und kurzer Live-Vergleich. Vollständige Performance-Abnahme
**NOT RUN: scheduled overnight**, fehlende kalibrierte Beobachter weiterhin BLOCKED.
Nachverfolgung: [PERF-001/003/007/015](../../backlog.md).

## Änderung

[Produktdiff](fix.diff), [Quellstand/Hashes](environment.json), [vollständiger Diff](source.diff).
Die bisherige einfarbige NSView-Abdeckung und das verzögerte Anwenden des neuen
Desktops in der Animationsmitte entfallen. Kamera und Anordnung werden sofort
innerhalb einer Core-Animation-Transaktion aktualisiert. `CATransition.fade`
überblendet Szenen- und HUD-Inhalt direkt in 180 ms mit Ease-in/Ease-out.
Keine dauerhaft zweite Desktop-Szene, keine eigene Bitmap-Snapshot-Verwaltung.
Der bestehende Display-Link beendet das Eingabefenster und bearbeitet vorgemerkte
Klickziele; die Überblendung selbst zeichnet Core Animation. Tabs bleiben außerhalb
der überblendeten Szene. Eingabeannahmeregeln und gespeicherte Kameras unverändert.

## Prüfung

- [Release-Build](build-final.log) erfolgreich; signiert unter `/Applications/OpenPlane.app`.
- Sieben gezielte DesktopTabTests bestanden: [finaler Testlauf](tests-verified.log).
  Neue Erwartung: Zielkamera sofort bereit, keine einfarbige Abdeckung eingefügt,
  keine Kamerafahrt während der Überblendung, exakte Rückkehr, schnelle Klickziele,
  Tab/Shift-Tab, neuer Desktop und Textbearbeitung weiterhin korrekt.
- Frühe Testläufe versuchten, die native CATransition nach AppKit-Verarbeitung
  aus den Layer-Animationsschlüsseln zurückzulesen; dort wurden keine zwei
  Animationen gefunden. Diese Annahme ist kein geeigneter Nachweis sichtbarer
  Übergangsbilder. Die ursprünglichen Fehlprotokolle bleiben erhalten. Der finale
  Test prüft Struktur/Zustand; der tatsächliche Überblendungseffekt wurde zusätzlich
  anhand der Live-Aufnahme geprüft, nicht durch Entfernen der Prüfung behauptet.
- [Live-Helfer](live.py), [Rohdaten](live.json): Baseline und Kandidat je ein
  Tab-/Shift-Tab-Hin/Rückwechsel, insgesamt vier beobachtete Desktopwechsel.
  Beide gespeicherten Kameras und Ausgangsdesktop jeweils erhalten.
- Beide Versionen separat vier Sekunden aufgenommen, keine CPU-Messung gleichzeitig.
  Sichtprüfung: Baseline zeigt die annähernd einfarbige Zwischenphase; Kandidat
  zeigt alte und neue Karten gleichzeitig mit wechselnden Deckungsanteilen.
  Direkte Überblendung bestätigt, kein einfarbiger Zwischenblitz in der Aufnahme.
  Private Videos `/tmp/openplane-crossfade/before.mov` und `after.mov`, abgeleitete
  Kontaktbögen im selben privaten Ordner. Resampling des Kontaktbogens ist kein
  Beleg unabhängiger präsentierter Frames oder kalibrierter Millisekundenlatenz.

Persönliche Szene auf demselben Mac wie PERF-014, gemeinsamer Preferences-Export
(Hash in Rohdaten). Keine vollständige S/R/L-Fixture; Live-Vorschauinhalte nicht
statisch. Keine CPU-/GPU-/Speichergewinnaussage. Die 180 ms sind konfigurierte Dauer;
Zeit zur Vorbereitung des neuen Desktops kommt als noch zu messender Anteil hinzu.
Native Zwischenbilder können zusätzlichen temporären Grafikspeicher benötigen.
Fünf A/B-Paare, sämtliche Varianten/Core-Smoke und Latenz-/Frame-/Speicherabnahme
bleiben der Nachtrunde vorbehalten. Keine neue Performancebaseline.

## Abschluss

Geprüfter Kandidat installiert, Signatur und Hash verifiziert; ursprüngliche
Einstellungen und Vordergrund wiederhergestellt. Eigene Test-/Aufnahmejobs beendet.
[Abschlussbeleg](completion.json). Funktionaler kurzer Test bestanden; volle
Performance-Abnahme bleibt offen.
