# Umgebungen

OpenPlane ist eine native macOS-App ohne Server.

## Staging

- Ort: Arashs Mac, `/Applications/OpenPlane.app`.
- Weg: Branch auf dem Mac auschecken, Tests laufen lassen
  (`xcodebuild test -project OpenPlane.xcodeproj -scheme OpenPlane`),
  Release bauen
  (`xcodebuild -project OpenPlane.xcodeproj -scheme OpenPlane -configuration Release -derivedDataPath build`),
  laufende App beenden, `build/Build/Products/Release/OpenPlane.app` nach
  `/Applications` kopieren und starten.
- Kurzer Live-Funktionscheck der geänderten Funktion laut `AGENTS.md`.

## Production

- Merge des auf Staging geprüften Stands in `main`, nur nach ausdrücklichem Ja.
