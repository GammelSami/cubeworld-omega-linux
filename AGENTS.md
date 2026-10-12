# AGENTS.md

Linux wrapper for the Windows-only Wollay launcher (Cube World Omega beta).
Start with [docs/TECHNICAL.md](docs/TECHNICAL.md): it explains every workaround and why it exists.

## Users

- The READMEs are for players with no Linux knowledge (think: a 10-year-old). Keep them short,
  one copy-paste line per step, no jargon. README.md and README.de.md must always say the same.
- Users should never need more than: download the setup, paste one line, use the app menu.
  New user-facing features go into the right-click actions of the menu entry
  (`scripts/menu-entry.sh`), not into extra commands.

## Privacy

- Logs and bug reports must not contain tokens, user ids, e-mail addresses or home paths.
  Anything new that `report.sh` collects goes through its `redact()`.
- The proxy only intercepts wollay.com and the Google sign-in hosts. Don't widen `--allow-hosts`.

## Testing without breaking the user's game

- Never start a second launcher while one runs (`pgrep -f 'wollay-launcher\.exe'`): Proton
  queues it and reopens the launcher after the user closes it.
- Test installs with a throwaway `CWO_HOME` *and* `XDG_DATA_HOME`, otherwise you overwrite the
  real menu entry and Vulkan layer.
- Don't `pkill -f` a pattern that also matches your own shell's command line; kill by PID.
- On GNOME Wayland, synthetic clicks don't reach the launcher. Screenshots work:
  `DISPLAY=:0 import -window "$(xdotool search --name '^Wollay Launcher$')" shot.png`

## Wollay's servers

- Be gentle: the prefetch once sent thousands of chunk requests within seconds and got blocked
  by Cloudflare. Keep the probe, the worker limit and the failure circuit breaker.
- Before blaming Wine, check the game's own log (`<prefix>/drive_c/users/steamuser/AppData/Local/com.wollay.launcher/logs/client-latest.log`,
  also in every log folder as `client.log`). "GAME SIGN-IN FAILED. CHECK THE LAUNCHER." and
  "Realm list unavailable" were server problems so far.

## Code

- `update.sh` must not source other files of the repo: `git pull` replaces them while it runs.
- `vkswapfix/prebuilt/libVkLayer_CWO_swapchain_format.so` must keep working on old systems
  (currently needs glibc ≥ 2.14). Rebuild it whenever `swapfix.c` changes:
  `vkswapfix/build.sh`, copy `~/.local/share/cubeworld-omega-linux/libVkLayer_CWO_swapchain_format.so`
  to `vkswapfix/prebuilt/`, `strip` it, then check
  `objdump -T vkswapfix/prebuilt/*.so | grep -o 'GLIBC_[0-9.]*' | sort -uV | tail -1`.
- Commit with the GitHub noreply address, never a private e-mail.
