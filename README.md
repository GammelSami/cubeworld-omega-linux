# Cube World Omega on Linux

Play the **Cube World Omega** beta on Linux. You need beta access and the Wollay launcher
from [wollay.com](https://wollay.com).

*Unofficial, not made by Wollay.* [Deutsche Anleitung](README.de.md)

## Install

**1.** Download the launcher (`Wollay-Launcher-…-Setup.exe`) from wollay.com.
Leave it in your **Downloads** folder.

**2.** Open a **terminal**, paste this line and press **Enter**:

```sh
git clone https://github.com/GammelSami/cubeworld-omega-linux ~/cubeworld-omega-linux && ~/cubeworld-omega-linux/install.sh
```

The first time takes a few minutes. Just wait.

**3.** The launcher opens. **Sign in.** The game downloads by itself.
Then press **Play**.

**Done!** Next time, start **Cube World Omega** from your app menu.

> Don't move or delete the `cubeworld-omega-linux` folder in your home folder. The game needs it.

## Problems?

- **Launcher window is very small** (big/4K screen): run
  `~/cubeworld-omega-linux/install.sh --dpi 192`
- **"git: command not found"**: install git (e.g. `sudo apt install git`, `sudo pacman -S git`
  or `sudo dnf install git`) and try step 2 again.
- **Anything else**: [open an issue](https://github.com/GammelSami/cubeworld-omega-linux/issues)
  and attach `~/Games/CubeWorldOmega/launcher.log` and `~/Games/CubeWorldOmega/proxy.log`.

## Update or uninstall

- Update these scripts: `git -C ~/cubeworld-omega-linux pull`
  (the game itself updates in the launcher)
- Uninstall everything: `~/cubeworld-omega-linux/uninstall.sh`

## What does it do?

It installs the Windows launcher with Proton (via [umu](https://github.com/Open-Wine-Components/umu-launcher))
in `~/Games/CubeWorldOmega` and fixes three things that don't work under Wine:

- **Downloads get stuck.** A small local proxy downloads the game files for the launcher.
  Only connections to wollay.com go through it. For this, a private certificate is
  trusted **only inside the game's Wine folder**, not by your system or browser.
- **Red and blue are swapped in game.** A small Vulkan layer fixes the colours. It is only
  active for this game.
- **The launcher sometimes crashes on start.** It is restarted automatically.

Details for nerds: [docs/TECHNICAL.md](docs/TECHNICAL.md)

## License

MIT
