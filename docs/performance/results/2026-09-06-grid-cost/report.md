# PERF-013: Kosten des Punktrasters

Status: An/Aus-Kostendiagnose abgeschlossen. 128er-Kachel nach visueller Prüfung verworfen. Vollständige Performance-Abnahme des Schalters **BLOCKED** (Beobachter/Fixtures/Varianten unten). Kein Optimierungsgewinn behauptet.

## Auftrag und begrenzte Änderung

Punkte als sichtbare Orientierung erhalten. Ihre Kosten beim Zoomen,
Kartennavigation und Desktopwechsel mit einem einfachen An/Aus-Schalter isolieren.
Nur bei nachgewiesenem Nutzen und unveränderter Optik einen Ersatzrenderer erwägen.

Der neue Menüeintrag `Show Grid Dots` ist standardmäßig an. Er unterdrückt im
Aus-Zustand auch die Rastervorbereitung, nicht nur die Ausgabe. Beim erneuten
Einschalten wird die Kachel für den aktuellen Zoom erneuert. [Produktdiff](switch.diff).
[85 Tests](tests.log) inklusive Aus/Zoom/An und bestehender Ausblendgrenze grün.
[Release-Build](build.log), [Quellstand](source.diff), [Hashes](environment.json).

## Bestehende Implementierung

`CanvasView.updateGrid` rasterisiert bereits eine kleine Kachel mit maximal
32 × 32 Punkten und wiederholt sie mit zwei CAReplicatorLayern. Die frühere
Darstellung zehntausender einzelner Ellipsen ist bereits ersetzt, siehe
[Historie](../../../gpu-navigation-performance.md#further-reduction-native-camera-flights).
Bei gleichbleibendem Zoom wird die Kachel wiederverwendet. Beim Zoomen wird sie
neu erzeugt. Unter Zoom 0,15 wird gar keine Kachel vorbereitet.

Abstand: 52 × Zoom; Punktdurchmesser: max(1, 2 × Zoom); Deckkraft zoomabhängig.
Ein einfaches Hochskalieren derselben Textur über den ganzen Zoombereich würde
somit auch Punktgröße, Schärfe und Deckkraft ändern. Das wäre kein gleichwertiger
Ersatz. Bei Desktopwechseln wird die Zielkamera unter der bestehenden Blende
zugewiesen, nicht als durchgehender Zoom interpoliert.

## Messverfahren und Grenzen

[Runner](compare.py), [Rohdaten](comparison.json), [Auswertung](summary.json).
Gleicher signierter Release-Build in `/Applications/OpenPlane.app`, fünf Paare
mit alternierender Reihenfolge an/aus bzw. aus/an. Pro Fall und Variante frischer
Prozess, erste Route, zwei Aufwärmrouten, gemessene Warmroute. Gemessene Phasen:
5 Sekunden Idle, Eingaberoute, 1 Sekunde Nachlauf, 5 Sekunden Idle.
Keine eigenen Builds, Tests oder Profiler parallel. Exklusiver Live-Test-Lock.

Persönliche bestehende Szene, zwei Desktops. Ein gemeinsamer gesicherter
Preferences-Export, vor jeder Variante wiederhergestellt; Kamerazooms für
P01/P06 kontrolliert auf 0,31 und 0,73 gesetzt. Debuganzeige auf beiden an.
Fixture-Hash in Rohdaten. Persönliche Fenster/Vorschauinhalte bleiben veränderlich;
keine vollständige versionierte S/R/L-Fixture. Kein OS-Cache-Reset.

P01: 20 native Pfeil-Taps pro Route. P02: 90 native Shift-Pfeil-Taps wie frühere
Teilmessung, obere/untere Zoomgrenze aus gespeicherter Kamera geprüft. Viele Taps
an Grenzen sind keine zusätzlichen Zoombewegungen. P06: sechs Tab-Wechsel mit
jeweils beobachteter geänderter Desktop-ID, abschließend gleicher Desktop und
unveränderte beide Kameras. Kamera-/Desktopbeobachtung erfolgt grob nach festem
Warteintervall; keine erste sichtbare Reaktions- oder Frame-Latenz.

CPU: Prozess-Nutzer+System-Zeit / monotone Wandzeit, 100 % = ein Kern.
WindowServer/GPU nicht enthalten. An/Aus-Differenz ist eine Kostenisolation bei
unterschiedlicher Darstellung und ausdrücklich kein Optimierungsgewinn.
Einzelannahme/-abschluss P01/P02, kalibrierte Frame-/Reaktionslatenz, Physical
Footprint und vollständige P01/P02/P06/P13-Varianten bleiben BLOCKED/NOT RUN.
Nachverfolgung: [PERF-001/003/004/007/013](../../backlog.md).

## Ergebnisse und Abschluss

Alle 120 Routen abgeschlossen: pro Fall und An/Aus je fünf erste, zehn Aufwärm-
und fünf gemessene Warmrouten. Insgesamt 240 beobachtete Desktopwechsel und
80 beobachtete Zoom-Grenzabschnitte; 800 gepostete P01-Eingaben ohne unabhängigen
Einzelabschlusszähler. Keine Helferfehler während der Routen.

| Fall | Idle vorher an/aus | Aktion an/aus | Zusätzlich an/aus, pp | Idle nachher an/aus | gepaarte CPU-Zeitersparnis aus, Median |
| --- | ---: | ---: | ---: | ---: | ---: |
| P01 | 1.14 / 1.14 | 6.15 / 6.19 | 4.99 / 5.05 | 1.08 / 1.12 | -1.16 % |
| P02 | 1.95 / 1.88 | 26.75 / 20.75 | 24.81 / 18.88 | 1.93 / 1.92 | 22.58 % |
| P06 | 1.16 / 1.12 | 10.29 / 9.50 | 8.97 / 8.35 | 1.16 / 1.20 | 6.73 % |

Der finale Preferences-Abgleich des Helfers schlug fehl, weil `defaults import`
den neuen, ursprünglich fehlenden `showGrid`-Schlüssel nicht entfernt. Der
Schlüssel wurde danach explizit entfernt und der vollständige Originalexport
vor Neustart erfolgreich geprüft: [Wiederherstellungsbeleg](restoration.json).
Die Rohdaten behalten den ursprünglichen Cleanup-Fehler bei.

Der Zoomunterschied ist in allen fünf Paaren stabil. Daraus folgt ein begrenzter
Versuch mit kleinerer Rasterkachel (128 statt 256 logische Punkte), weiterhin
allen Punkten. Der An/Aus-Unterschied ist eine Obergrenze, keine zu erwartende
vollständig erreichbare Ersparnis. Kartennavigation zeigt keinen Vorteil.

## Ergebnis des kleineren-Kachel-Versuchs

Die Änderung `ceil(256 / spacing)` → `ceil(128 / spacing)` wurde gebaut und
bestand erneut 85 Tests ([Build](build128.log), [Tests](tests128.log),
[Quellstand/Hashes](environment128.json), [Diff](source128.diff)). Der Versuch
wurde **vor einem CPU-A/B-Vergleich verworfen**: Gleiche Szene, gleiche Zoomstufe
0,15, gleicher Bildausschnitt zeigen veränderte Punktkanten. Im 128 × 128 Pixel
Ausschnitt unterscheiden sich 1.043 Pixel, maximal 30 von 255 je Farbkanal.
Die Unterschiede sind besonders in der vierfach vergrößerten Ansicht erkennbar;
daraus wird keine nachgewiesene schlechtere normale Bedienbarkeit abgeleitet.

Ursachenhypothese aus dem Code: `sceneImage` rundet die Bitmapgröße auf ganze
Pixel auf; die Kachelgrenzen sind bei beliebigem Zoom gebrochen. Ändert sich
die Kachelgröße, ändern sich Rundung, Abtastung und Punktkantendeckung. Kleinere
Kacheln sind daher nicht automatisch pixelgleich. Dies einfach mit zusätzlichen
Sonderregeln zu behandeln, wurde im Rahmen des minimalen Versuchs nicht verfolgt.

[Bewertung](candidate-evaluation.json), [erste Bildserie](visual.json),
[zweite Bildserie](visual-clear.json), [Ausschnittdifferenzen](visual-difference.json).
Screenshots bleiben privat unter `/tmp/openplane-grid/`. Die versuchte native
Scroll-Verschiebung der zweiten Serie ergab keine zuverlässig freie Fläche bei
allen Zooms; insbesondere 0,73 und 1,25 sind teils durch App-Vorschauen verdeckt.
Deren Pixelunterschiede sind **kein Rasterbeleg**. Der verwendete 0,15-Ausschnitt
zeigt ausschließlich Raster. Keine Behauptung vollständiger visueller Gleichheit,
keine gemessene CPU-/GPU-Ersparnis der 128er-Kachel.

Die Ein-Zeilen-Änderung wurde zurückgenommen, der bereits getestete 256er-Build
bleibt der finale Produktstand. Erhalten ist nur der standardmäßig aktive
Menüschalter. Nicht erneut lediglich die Kachelkonstante verkleinern und daraus
unveränderte Optik ableiten; ein neuer Versuch braucht einen neuen Ansatz zur
Pixelabbildung plus Bild-/GPU- und A/B-Beleg.

## Finale Verifikation und Entscheidung

Der Menüpfad „Menu → Show Grid Dots“ wurde per nativer Accessibility-Eingabe
an → aus → an bedient; gespeicherter Aus-Zustand beobachtet. Der Regressionstest
prüft zusätzlich aus → Zoomänderung → an, Neuaufbau und unveränderte Kamera.
Separater [Live-Smoke](smoke-B.json) mit finalem 256er-Build ergänzt gehaltene
Zoomtasten und Kernfall-Teilmengen. Nicht ersetzte Pflichtfälle und fehlende
Beobachter bleiben ausdrücklich offen; Details im Smoke-Artefakt.

Entscheidung: Punkte anlassen und bisheriges Rendering erhalten. Das Raster
hat messbare Zoomkosten, verwendet aber bereits die vom Nutzer vorgeschlagene
Bitmap-Wiederholung. Kein aufwendiger Rendererumbau allein für niedrigere CPU-
Mittelwerte. Der konkrete 128er-Versuch ist dokumentiert und verworfen, nicht
jede denkbare Rasteroptimierung ausgeschlossen. Keine neue Performancebaseline.

Finaler Hash, Einstellungen und beendete Testprozesse: `completion.json`.




Abschluss: Der installierte, signaturgeprüfte Build entspricht wieder exakt dem
85-Test-Quellstand mit 256er-Kacheln und Menüschalter. Der ursprüngliche komplette
Preferences-Export vom Beginn des An/Aus-Vergleichs wurde abschließend erfolgreich
wiederhergestellt und vor Neustart abgeglichen; der neue Schalter ist durch seinen
Standard an. Eigene Test-/Build-/Profilprozesse beendet. Kein neuer OpenPlane-
Crashbericht nach dem zuvor dokumentierten PERF-012-Baseline-Absturz.
