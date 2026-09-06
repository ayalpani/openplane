# PERF-016: Schnelle Desktop-Tabs vollständig ausführen

Nutzerauftrag: Mehrere schnell hintereinander gedrückte Tab-Tasten dürfen nicht
während der Desktopüberblendung verworfen werden. Drei Schritte vom ersten
Desktop sollen beim vierten landen, einschließlich aller Zwischenwechsel.

## Ursache und Änderung

Der bisherige Handler gab während jeder Desktopüberblendung sofort `true` zurück,
bevor er Tab verarbeitete. Zusätzlich konnte die einzige vorgemerkte Desktop-
Änderung nur ein Ziel halten. Der neue Handler lässt gültige Tab-/Shift-Tab-
Einzelanschläge durch und hält Änderungen in einer FIFO-Liste. Relative Ziele
werden erst beim Ausführen aus dem dann aktuellen Desktop bestimmt. Somit werden
weder drei Schritte zu einem Ziel zusammengezogen noch gegensinnige Schritte
gegeneinander verrechnet. Auch mehrere vorgemerkte Tab-Klicks bleiben in Reihenfolge.

Pro Schritt weiterhin 180 ms direkte Core-Animation-Überblendung. Bestehende
Textbearbeitungs-/Shortcut-Ausnahmen und ignoriertes OS-Autorepeat bleiben erhalten.
Das bislang zyklische Randverhalten bleibt zunächst erhalten. Die Nachfrage zum
gewünschten Stoppen am Listenende ist davon getrennt. Keine neuen Abhängigkeiten
oder allgemeine Queue-Infrastruktur: eine Liste anstelle des einzelnen Slots.

[Produktdiff](fix.diff), [Quellstand/Hashes](environment.json),
[vollständiger Produkt-/Testdiff](source.diff), [Release-Build](build-final.log).
Ein anfänglicher Compilefehler durch ein überflüssiges Swift-Argumentlabel wurde
korrigiert; Originalprotokolle bleiben erhalten. Finaler Build erfolgreich.

## Gezielte Verifikation

[Neun DesktopTabTests bestanden](tests-final.log). Zwei zusätzliche Regressionen
prüfen drei schnelle Vorwärts-/Rückwärtsschritte über vier Desktops, Reihenfolge
bei Tab/Shift-Tab/Tab, unveränderte Kameras und ignorierte automatische Wiederholung.
Bestehende Tests für Klicks, Textbearbeitung und Direktüberblendung bleiben grün.

[Kurzer Live-Helfer](live.py), [Rohdaten](live.json): signierte Release-App unter
`/Applications/OpenPlane.app`, gleicher temporärer Vier-Desktop-Preferences-Export
auf Baseline/Kandidat. Desktopnamen und IDs nur temporär, persönliche Ausgangs-
Preferences gesichert und abschließend vollständig zurückgespielt/abgeglichen.
Je Burst drei native Taps von etwa 10 ms, dazwischen angeforderte 15 ms Pause.
Anschließend gespeicherte Desktop-IDs beobachtet, beide Richtungen und Kameras
geprüft. Tabellenwerte sind einsbasierte Positionen; Rohdaten-Indizes nullbasiert.

| Variante / Eingaben | Beobachtete Desktopfolge | Endposition |
| --- | --- | --- |
| Vorher, 3 × Tab ab 1 | 2 | 2: zwei Schritte verschluckt |
| Nachher, 3 × Tab ab 1 | 2 → 3 → 4 | 4 |
| Nachher, 3 × Shift-Tab ab 4 | 3 → 2 → 1 | 1 |
| Nachher, Tab/Shift-Tab/Tab ab 1 | 2 → 1 → 2 | 2 |

Alle neun Kandidaten-Schritte in Eingabereihenfolge beobachtet; gespeicherte
Kameras unverändert. Abnahme hier: funktionaler schneller Tastatur-Burst, keine
Performance-Zertifizierung. Das Polling beobachtet gespeicherten Zustand, nicht
präsentierte Bildlatenz. Keine CPU-/GPU-/Speichergewinnaussage.

## Nachtprüfung und Abschluss

Gesamtperformance **NOT RUN: scheduled overnight**: fünf A/B-Paare, längere
50-Eingaben-Bursts, weitere Misch-/Unterbrechungsvarianten, vollständiger Core-Smoke,
Latenz-/Frame-/Speicherprüfung. Kalibrierte Beobachter/Fixtures fehlen weiterhin;
[PERF-001/003/007/016](../../backlog.md). Keine CPU-Mittelwerte durch weniger
abgeschlossene Aktionen verbessern. Das geänderte Verhalten soll mehr Eingaben
abarbeiten und darf dadurch mehr Gesamtarbeit leisten.

Geprüften Kandidaten installiert, ursprüngliche Desktops/Einstellungen und
Vordergrund wiederhergestellt, eigene Testjobs beendet: [Abschluss](completion.json).
