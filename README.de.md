# Cube World Omega unter Linux

Spiele die **Cube World Omega** Beta unter Linux. Du brauchst Beta-Zugang und den
Wollay-Launcher von [wollay.com](https://wollay.com).

*Inoffiziell, nicht von Wollay.* [English](README.md)

## Installieren

**1.** Lade den Launcher (`Wollay-Launcher-…-Setup.exe`) von wollay.com herunter.
Lass ihn im Ordner **Downloads** liegen.

**2.** Öffne ein **Terminal**, füge diese Zeile ein und drücke **Enter**:

```sh
git clone https://github.com/GammelSami/cubeworld-omega-linux ~/cubeworld-omega-linux && ~/cubeworld-omega-linux/install.sh
```

Beim ersten Mal dauert das ein paar Minuten. Einfach warten.

**3.** Der Launcher öffnet sich. **Melde dich an.** Das Spiel lädt sich von selbst herunter.
Dann auf **Play** klicken.

**Fertig!** Ab jetzt startest du **Cube World Omega** über dein App-Menü.

> Verschiebe oder lösche den Ordner `cubeworld-omega-linux` in deinem Home-Ordner nicht. Das Spiel braucht ihn.

## Probleme?

- **Launcher-Fenster ist winzig** (großer/4K-Bildschirm): führe
  `~/cubeworld-omega-linux/install.sh --dpi 192` aus
- **„git: command not found“ / „Befehl nicht gefunden“**: installiere git (z. B.
  `sudo apt install git`, `sudo pacman -S git` oder `sudo dnf install git`) und wiederhole Schritt 2.
- **Alles andere**: [Issue öffnen](https://github.com/GammelSami/cubeworld-omega-linux/issues)
  und `~/Games/CubeWorldOmega/launcher.log` und `~/Games/CubeWorldOmega/proxy.log` anhängen.

## Aktualisieren oder deinstallieren

- Skripte aktualisieren: `git -C ~/cubeworld-omega-linux pull`
  (das Spiel selbst aktualisiert sich im Launcher)
- Alles deinstallieren: `~/cubeworld-omega-linux/uninstall.sh`

## Was macht das?

Es installiert den Windows-Launcher mit Proton (über [umu](https://github.com/Open-Wine-Components/umu-launcher))
in `~/Games/CubeWorldOmega` und behebt drei Dinge, die unter Wine nicht funktionieren:

- **Downloads bleiben hängen.** Ein kleiner lokaler Proxy lädt die Spieldateien für den Launcher.
  Nur Verbindungen zu wollay.com laufen darüber. Dafür wird ein eigenes Zertifikat **nur im
  Wine-Ordner des Spiels** vertraut, nicht von deinem System oder Browser.
- **Rot und Blau sind im Spiel vertauscht.** Ein kleiner Vulkan-Layer korrigiert die Farben.
  Er ist nur für dieses Spiel aktiv.
- **Der Launcher stürzt manchmal beim Start ab.** Er wird automatisch neu gestartet.

Technische Details: [docs/TECHNICAL.md](docs/TECHNICAL.md)
