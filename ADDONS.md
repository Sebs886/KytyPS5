# KytyPS5 add-ons · Demon's Souls

> **This is the fork's add-on guide.** Everything described here lives in this repository under `addons/`
> (the launcher, the cheats, the DualSense backend); `git diff v20261017` is the whole of it. Download the
> overlay from the [v20261017-addons release](https://github.com/Sebs886/KytyPS5/releases/tag/v20261017-addons).
> The engineering notes behind it — how the save format was worked out, every address, every dead end — are
> in [addons/NOTES.zh-CN.md](addons/NOTES.zh-CN.md) (Chinese).

Three things stacked on top of [KytyPS5](https://github.com/chenxiao07/KytyPS5) (upstream v20261017):
**cheats**, **per-world tendency** and **DualSense speaker / haptics**. Adaptive triggers need no work —
upstream already does them.

- Just want to play 👉 [Install](#install)
- Something is broken 👉 [Troubleshooting](#troubleshooting)
- Want to know where every address came from 👉 [NOTES.zh-CN.md](addons/NOTES.zh-CN.md) (engineering notes, long, Chinese)

---

## What it adds

| Feature | In one line | Rebuild needed? |
| --- | --- | --- |
| **Cheats** | 8 mods (souls / HP / stamina / MP …), one checkbox each in the launcher | No |
| **World tendency** | Writes the values straight into the save, one world at a time | No |
| **Controller speaker / haptics** | Replaces upstream's WASAPI backend with an SDL2 one, so the two audio paths no longer cut each other off, with adjustable volumes | Yes (a built exe ships in the package) |
| **Adaptive triggers** | Already implemented upstream, verified working, not a line changed | No |

---

## Install

### Option 1: the overlay from the release page (recommended, ~8 MB)

1. Download the full **v20261017** package from upstream and unpack it anywhere:
   <https://github.com/chenxiao07/KytyPS5/releases/tag/v20261017>
2. Unpack `KytyPS5-addons-v20261017.zip` **over** that folder (say yes to replacing `kyty_emulator.exe`).
3. Double-click **`launcher.cmd`** (not `run.cmd`). The first run asks for the game folder — pick the one
   that contains `eboot.bin`.

### Option 2: build it from this repository

Download or `git clone` the repository and double-click `addons/install.cmd`, then pick the emulator
folder — same result as the overlay.

### What installing does

- Everything it replaces is backed up to `_Backup\` in the emulator folder, so you can always roll back.
- Your own settings (resolution, game path, which cheats were ticked, tendency values, controller
  volumes …) are **kept**.
- If this build's exe already carries a haptics module, the installer says so and leaves it alone.

> **Close the emulator first** — a locked exe cannot be replaced.

### If Windows says the script is not digitally signed

The zip carries a "from the internet" mark; clear it once:

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

(Or right-click `launcher.ps1` → Properties → Unblock.)

---

## What is new in the launcher

Upstream's display / quality / output options are untouched. Everything new lives in one **`Mods`** group:

```
┌─ Mods ─────────────────────────────────────────────────┐
│ [x] Cheats   [PPSA01341_01.007.000.json ▾]             │
│     [x] Max Souls (999,999,999)                        │
│     [x] Infinite HP  (Player - No Damage)              │
│     …                                                  │
│     [Select all] [Select none]            4 of 8 on    │
│ Tendency      [ ] W1  Boletarian Palace     [ 120]     │
│               [ ] W2  Stonefang Tunnel      [ 120]     │
│               [ ] W3  Tower of Latria       [   0]     │
│               [ ] W4  Shrine of Storms      [ 200]     │
│               [ ] W5  Valley of Defilement  [   0]     │
│               [ ] Character tendency        [ 160]     │
│               SAVEDATA0PlayerProfile1 · character 160  │
│ Controller volume [ ] Speaker   [100] %                │
│                   [ ] Vibration [100] %                │
└────────────────────────────────────────────────────────┘
```

The `SAVEDATA0PlayerProfile1 · character 160` line is grey and read live from the save when the window
opens — that is your check that a write actually happened.

### Cheats: tick what you want

| On by default | Off by default |
| --- | --- |
| Max Souls (999,999,999) | Player Never Dies |
| Infinite HP (player takes no damage) | One Hit Kill (experimental) |
| Infinite Stamina | Debug menu: open in game (experimental) |
| Infinite MP | Dev build flags: RetailBuild off (experimental) |

The `Cheats` master switch greys the whole block out — nothing is loaded then. Offsets are written for
**01.007.000 (PPSA01341)**; another game version would patch the wrong addresses. Check a file against
`eboot.bin` with `addons/cheats/verify_cheat.py` before trusting it.

### World tendency: **a box has to be ticked**

Tendency does not live in a launch parameter, it lives in the save — so the launcher edits the save file:

```
_SaveData\PPSA01341\SAVEDATA0PlayerProfile<n>\USR-DATA
```

Three rules cover every mistake:

1. **Ticked = written.** An unticked world is not touched at all — set Stonefang to pure white and leave the
   other worlds exactly as the game has them.
2. **Applies at launch.** Quit the game, change, start again. Editing while it runs does nothing.
3. **Ticked = pinned.** Every launch writes your value back, so progress you make in game is overwritten next
   start. Untick it to let the game have its way again.

Range is **−200 (pure black) ~ 0 (neutral) ~ +200 (pure white)**.

**The save's slot numbers are not world numbers.** Measured, not guessed — and it is not the obvious order:

| World in game | W1 Boletarian | W2 Stonefang | W3 Latria | W4 Shrine | W5 Valley |
| --- | --- | --- | --- | --- | --- |
| Save slot written | `World01` | **`World05`** | `World03` | **`World02`** | `World04` |

That is why the window shows **five rows in world order** with the slot mapping baked in — you never see it.
Settings files from older versions (7 entries, slot order) are remapped automatically, so values you already
set do not jump to another world.

### Controller volume

Both rows are a percentage **of what the package does by default**, so **100 % changes nothing**:

| Row | Controls | Range |
| --- | --- | --- |
| Speaker | the pad's **speaker** | 0–400 % (0 % mutes) |
| Vibration | the pad's **actuators / haptics** | 0–400 % (0 % stops) |

These are the controller's own two outputs. They do **not** touch the game's main volume (that is still the
Windows slider).

### Debug menu

There is **no key that opens it** in this build: the game's only binding is a console shortcut command, and
the input routine behind it is dead code gated by a pointer in `.bss` that nothing ever writes. Two
experimental mods try to force it from the code side — `Debug menu: open in game` and
`Dev build flags: RetailBuild off`. **Off by default, may crash.** Curiosity only.

---

## Troubleshooting

**Tendency still shows 0.00?**
Check three things: the game is closed, that row is **ticked**, and you **restarted** the game. The grey line
shows what the save actually holds — or run `launcher.ps1 -DryRun`, which prints without writing.

**I set world 2 to 200 and world 4 changed?**
That was an old launcher bug (it assumed slot number = world number). Fixed: world 2 now writes `World05`
and world 4 writes `World02`, as in the table above.

**No resistance on the triggers?**
First **actually draw a bow or swing a weapon** in game — toggling "trigger effect" in the menu never produces
a feel, because the game sends one "both triggers off" when the switch changes and nothing else. If that does
not help, run `addons/dualsense/probe_trigger.exe`: it drives R2/L2 through four effects without the emulator and
buzzes the motors first to prove the path. Tool works + game does not = game side; neither works = pad or OS.

**No sound from the controller speaker, or too quiet?**
The stream the game sends to that port is very low to begin with (peaks around −40 dB), and the package
applies ×8 by default. Still quiet: raise Speaker — 400 % is ×32.

**How do I know this is the add-on build?**
`kyty_emulator.exe` contains both `DualSenseHaptics` and `KYTY_DUALSENSE_HAPTICS`; upstream has neither.

**It will not start?**
Look at the newest `.out.log` under the emulator's `logs\`, then try rolling back a file from `_Backup\`.

---

## Following a new upstream release

1. Unpack the new version into a new folder.
2. Run `addons/install.cmd` and point it at that folder — launcher and cheats work immediately.
3. If that release has no haptics module, or you want the SDL2 backend, run `addons/dualsense/rebuild.cmd` once.

`addons/install.cmd` **never swaps the exe on its own**; it only replaces it when the package holds a build for
exactly that version, and tells you when it does.

## Building from source (optional)

```powershell
cd addons/dualsense
.\rebuild.cmd -Target G:\KytyPS5-v20261017 -Version v20261017
```

One command does the lot: download that tag's source → apply the patch → build → install into the release
folder. About fifteen minutes the first time, then one or two minutes for later changes (only what changed is
recompiled). **The cheats need no build at all.**

Needs Visual Studio 2026 (C++ workload, Clang 20+), CMake and Ninja.

## Where everything lives

```
addons\
  launcher.ps1                 the launcher (upstream options + the Mods group)
  install.ps1 / install.cmd    copies the launcher and the cheats onto any release folder
  cheats\                      the cheat file, its README and verify_cheat.py
  dualsense\                   SDL2 backend: patches, rebuild.ps1, prebuilt exe, trigger probe
  NOTES.zh-CN.md               engineering notes (Chinese)
ADDONS.md                      this file
ADDONS.zh-CN.md                the same guide in Chinese
src\libs\dualSenseHaptics.*    the only upstream files this fork changes
```

## Licence and credits

- A fork of [chenxiao07/KytyPS5](https://github.com/chenxiao07/KytyPS5), **GPL-2.0** like upstream.
- Binaries are distributed together with their source: `addons/` and `src/libs/dualSenseHaptics.*` in the repo.
- Repository <https://github.com/Sebs886/KytyPS5> · release <https://github.com/Sebs886/KytyPS5/releases/tag/v20261017-addons>
- You need your own copy of the game and its firmware files; nothing here contains game data. Written for
  **Demon's Souls PS5 01.007.000 (PPSA01341)** only.
