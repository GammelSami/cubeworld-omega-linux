# Cube World Omega on Linux

🇩🇪 [Deutsche Anleitung](README.de.md)

Play the **Cube World Omega** beta on Linux. You need beta access, the Wollay launcher
from [wollay.com](https://wollay.com) and **git** (not installed? see [Problems](#problems)).

*Unofficial, not made by Wollay.*

## Install

**1.** Download the launcher (`Wollay-Launcher-…-Setup.exe`) from wollay.com.
Leave it in your **Downloads** folder (if it's somewhere else, the installer will ask you for it).

**2.** Open a **terminal**, paste this line and press **Enter**:

```sh
git clone https://github.com/GammelSami/cubeworld-omega-linux ~/Games/cubeworld-omega-linux && ~/Games/cubeworld-omega-linux/install.sh
```

The first time takes a few minutes. Just wait.

**3.** The launcher opens. **Sign in.** The game downloads by itself.
Then press **Play**.
If the sign-in in your browser doesn't get back to the launcher, delete the cookies for
wollay.com in your browser and sign in again.

**Done!** Next time, start **Cube World Omega** from your app menu.

> This puts the scripts in `Games/cubeworld-omega-linux` in your home folder and the game in
> `Games/CubeWorldOmega`. Don't move or delete these folders. The game needs them.

## Problems?

- **Launcher window is very small** (big/4K screen): run
  `~/Games/cubeworld-omega-linux/install.sh --dpi 192`
- **"git: command not found"**: install git (Ubuntu/Debian/Mint: `sudo apt install git`,
  Arch/CachyOS/Manjaro: `sudo pacman -S git`, Fedora: `sudo dnf install git`,
  openSUSE: `sudo zypper install git`) and try step 2 again.
- **Anything else**: right-click **Cube World Omega** in your app menu and choose
  **Create bug report** (or run `~/Games/cubeworld-omega-linux/report.sh`). This saves a file in
  your Downloads folder, without your login data.
  [Open an issue](https://github.com/GammelSami/cubeworld-omega-linux/issues), say what happened
  and attach the file.

## Update or uninstall

**Update:** when there are new fixes here, right-click **Cube World Omega** in your app menu
and choose **Update Linux wrapper**. Or paste this into a terminal and press **Enter**
(the game itself updates in the launcher):

```sh
git -C ~/Games/cubeworld-omega-linux pull
```

**Uninstall everything:** `~/Games/cubeworld-omega-linux/uninstall.sh`

## What does it do?

It installs the Windows launcher with Proton (via [umu](https://github.com/Open-Wine-Components/umu-launcher))
in `~/Games/CubeWorldOmega` and fixes three things that don't work under Wine:

- **Downloads get stuck.** A small local proxy downloads the game files for the launcher.
  Only connections to wollay.com and the Google sign-in services it uses go through it. For this, a private certificate is
  trusted **only inside the game's Wine folder**, not by your system or browser.
- **Red and blue are swapped in game.** A small Vulkan layer fixes the colours. It is only
  active for this game. Without it, the game looks like this:

  ![Cube World Omega under Wine without the fix: orange sky, bright green grass](docs/swapped-colours.jpg)
- **The launcher sometimes crashes on start.** It is restarted automatically.

Details for nerds: [docs/TECHNICAL.md](docs/TECHNICAL.md)

## License

MIT
