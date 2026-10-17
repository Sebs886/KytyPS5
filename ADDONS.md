# KytyPS5 + addons

A fork of [chenxiao07/KytyPS5](https://github.com/chenxiao07/KytyPS5) that keeps four things on top of the
upstream portable Windows build, all of them for **Demon's Souls (PPSA01341)**:

* **a launcher with the switches the release does not have** — a cheat-file picker with one checkbox per
  mod, per-world world tendency, character tendency, the debug-menu switch and the controller volumes;
* **a DualSense backend of its own** — the upstream haptics (`src/libs/dualSenseHaptics.cpp`, a WASAPI
  backend that opens the audio endpoint through `IAudioClient`) is replaced by an SDL2 one that mixes the
  speaker and the actuators by hand, so their volumes are adjustable independently and the two do not cut
  each other off;
* **the tendency editor** — writes `Tendency_World*_*` / `Tendency_Player_*` straight into the save, one
  world at a time, so changing one world no longer flattens the others. The save's slot order is **not**
  the world order — it is `1, 5, 3, 2, 4` — see "Notes on the addons" below for how that was measured;
* **the cheat file** — eight mods for 01.007.000, four of them on by default, each traced back to the
  routine it patches (see `addons/cheats/README.md`).

Everything else is upstream, unchanged. `git diff v20261017` is the whole of it.

English summary: this fork adds a custom launcher (cheats, per-world tendency, controller volume), an
SDL2 DualSense backend in place of the WASAPI one, and a documented cheat file. Only
`src/libs/dualSenseHaptics.cpp` and `.h` differ from upstream; the launcher, cheats and the tooling that
builds them live under `addons/`. GPL-2.0, same as upstream.

## Using a release

The release asset is an **overlay**, not a complete build: unpack it over an upstream
`KytyPS5-v20261017`, replacing `kyty_emulator.exe` and adding `launcher.ps1` and `cheats\`.

1. Download the upstream `KytyPS5-v20261017` release and unpack it anywhere.
2. Unpack `KytyPS5-addons-v20261017.zip` over that folder (say yes to replacing `kyty_emulator.exe`).
3. Run `launcher.cmd` instead of `run.cmd`.

The launcher writes `launcher-settings.json` next to itself and keeps the game folder in it. On a fresh
install, tick **Cheats**, choose the file, and press **Play**.

If Windows complains that the scripts are not signed, the zip came through a browser that marked it:
`Unblock-File *.ps1` or the file's Properties → Unblock. `launcher.cmd` already passes
`-ExecutionPolicy Bypass`.

## Building it yourself

`addons/dualsense/rebuild.ps1` does the whole thing: it downloads the release's source, applies
`dualsense-v20261016.patch`, builds it with clang-cl + Ninja and drops the program into the release
folder.

```powershell
cd addons\dualsense
.\rebuild.ps1 -Target G:\KytyPS5-v20261017 -Version v20261017
```

It needs Visual Studio 2026 (C++ workload, Clang 20 or newer), CMake and Ninja. The first build takes
about fifteen minutes, a later one only recompiles what changed. `-NoInstall` builds without touching
the release folder.

The launcher, the cheats and the installer need no build at all — `addons\install.ps1 -Target <folder>`
copies them onto any release (v20261014 and newer; the optional switches it passes are checked against
`run-windows.ps1` first, so an older release does not fail on a switch it does not have).

## What is where

| Path | What it is |
| --- | --- |
| `addons/launcher.ps1` | the launcher: upstream's window plus a `Mods` group (cheats, tendencies, debug menu, controller volumes) |
| `addons/install.ps1`, `install.cmd` | copies the launcher and the cheats onto a release folder |
| `addons/cheats/` | the cheat file, `verify_cheat.py` (checks every offset against the game's `eboot.bin`) and its README |
| `addons/dualsense/` | the SDL2 backend, its patch, `rebuild.ps1`, plus the adaptive-trigger probe (`trigger-probe.patch`, `probe_trigger.exe` and its source) |
| `addons/NOTES.zh-CN.md` | the engineering notes behind all of it (Chinese: how the save format was worked out, every address, every dead end) |
| `src/libs/dualSenseHaptics.cpp`, `.h` | the only upstream files this fork changes |

## Notes on the addons

**Per-world tendency.** The save stores sixteen floats, nine bytes each, after a `u32 version | u32
checksum | u32 size | u32` header: `Tendency_Player_BlackWhite`, `_LeftRight`, then
`Tendency_World00..06_BlackWhite` / `_LeftRight`. The values run −200 (pure black) to +200 (pure white).
Only the worlds whose box is ticked are written; the rest are left byte for byte alone.

**Which slot is which world** is the one thing here that could not be read out of the executable. The
game's own world numbering (0 Nexus, 1 Boletarian Palace, 2 Stonefang Tunnel, 3 Tower of Latria, 4 Shrine
of Storms, 5 Valley of Defilement, 6 unused — the numbering jumps 5 → 8 and the tutorial is world 8) is
easy to establish, and every document written from it will tell you that slot *N* holds world *N*. It does
not. Writing one distinct value into each of the seven slots and reading the game's **Tendency** page back
gives:

| Slot | `World00` | `World01` | `World02` | `World03` | `World04` | `World05` | `World06` |
| --- | --- | --- | --- | --- | --- | --- | --- |
| World shown in game | — (Nexus) | 1 Boletarian Palace | **4 Shrine of Storms** | 3 Tower of Latria | 5 Valley of Defilement | **2 Stonefang Tunnel** | — (nothing) |

So the launcher holds the map as `1, 5, 3, 2, 4` and shows five rows, one per world that actually exists,
in the game's order. `World00` (Nexus, which has no world tendency) and `World06` (the sixth world, whose
archstone is not reachable in this build) are left out: writing them changes nothing anywhere in the game.

Older versions of this fork wrote slot *N* for world *N*. A settings file from one of those is still read
correctly — the stored list is seven entries long and is therefore taken as slot order and remapped, while
a five-entry list is taken as world order.

**Adaptive triggers** need no addon at all: upstream already converts `scePadSetTriggerEffect` through
`trigger_effect_to_dualsense()` into the 11-byte effect blocks and hands them to SDL, which puts them in a
USB output report of its own. It works — with the game's trigger effect option on, drawing a bow on a
DualSense sends `mode 1` (feedback) on the right trigger and releasing sends `mode 0`, 25 times in one
short session. What it does **not** do is reflect the menu switch: the game's
`CCPLdrPlatformPadTriggerEffect` component only mirrors that option into a byte and sends a one-off
"both triggers off" when it changes, so toggling the option in the menu can never be felt. The effect has
to come from gameplay. `addons/dualsense/trigger-probe.patch` adds `printf` traces to the way in and
`addons/dualsense/probe_trigger.exe` drives the same effects straight from the host, without the emulator,
to tell a game-side problem from a controller-side one.

**The debug menu.** There is no key that opens it in this build, and `cp11_toggleDebugMenu` cannot either:
the game's whole input routine is dead code behind a `bool*` in `.bss` that nothing in the executable
ever writes, so it reads through to address zero every frame. The launcher offers a cheat mod that patches
that branch instead, off by default and marked experimental.

**Cheats.** `kyty_emulator.exe --game-patch <json>` does not write at the offsets blindly: it searches for
the first entry whose `off` bytes are not zero, derives a source base from where those bytes are found, and
requires every other entry to match at that base. `verify_cheat.py` replicates that loader so a file can
be checked against a game's `eboot.bin` without starting the emulator. Run it after touching an offset.

**Controller volume.** The SDL2 backend mixes the speaker port and the actuator port into one four-channel
block before queueing it — queueing them separately doubles the rate and the two paths silence each other.
Volumes are percentages, 100 % being what the package does by default.

## Licence

GPL-2.0, the same as upstream — see `LICENSE`. The changes this fork makes are in `src/libs/` (listed
above) and under `addons/`; a build of this tree is what the release asset contains. Demon's Souls and its
files are not part of any of it.
