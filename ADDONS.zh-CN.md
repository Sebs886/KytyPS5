# KytyPS5 整合包 · 恶魔之魂

> **本文是这个 fork 的功能说明。** 这里讲的每一样东西都在仓库 `addons/` 下（启动器、金手指、DualSense 后端），
> 和上游的全部差异就是 `git diff v20261017`。覆盖包在
> [v20261017-addons 发布页](https://github.com/Sebs886/KytyPS5/releases/tag/v20261017-addons)。
> 逆向过程与逐地址记录见 [addons/NOTES.zh-CN.md](addons/NOTES.zh-CN.md)。

在 [KytyPS5](https://github.com/chenxiao07/KytyPS5) 模拟器（上游 v20261017）上叠了三样东西：
**金手指**、**逐世界倾向**、**DualSense 手柄喇叭与震动**。自适应扳机不用改，原版就能用。

- 只想玩 👉 [安装](#安装)
- 出了问题 👉 [常见问题](#常见问题)
- 想知道每个地址是怎么挖出来的 👉 [NOTES.zh-CN.md](addons/NOTES.zh-CN.md)（工程笔记，很长，可以当资料查）

---

## 它到底加了什么

| 功能 | 一句话 | 要不要重编译 |
| --- | --- | --- |
| **金手指** | 8 条 mod（魂 / HP / 耐力 / MP …），启动器里逐条勾 | 不用 |
| **世界倾向** | 直接把数值写进存档，五个世界各调各的 | 不用 |
| **手柄喇叭 / 震动** | 把官方那套 WASAPI 后端换成 SDL2，两路声音不会再互相切断，音量可调 | 要（包里有编好的 exe） |
| **自适应扳机** | 上游本来就实现了，实测正常，一行没改 | 不用 |

---

## 安装

### 方式一：用发布页的覆盖包（推荐，约 8 MB）

1. 下载上游完整包 **v20261017**，解压到任意目录：
   <https://github.com/chenxiao07/KytyPS5/releases/tag/v20261017>
2. 把 `KytyPS5-addons-v20261017.zip` 解压后**覆盖**到同一个目录（同意替换 `kyty_emulator.exe`）。
3. 双击 **`launcher.cmd`**（不是 `run.cmd`）。第一次启动会让你选游戏目录，选含 `eboot.bin` 的那一层。

### 方式二：用本仓库的源码

把仓库下载下来（或 `git clone`），双击里面的 `addons/install.cmd`，选模拟器目录
（也可以把目录直接拖到它上面）就行，效果和覆盖包一样。

### 装的时候会发生什么

- 旧文件先备份到模拟器目录的 `_Backup\` 里，随时能回退。
- 你自己的设置（分辨率、游戏路径、勾过哪些金手指、倾向值、手柄音量…）**全部保留**。
- 如果这个版本的 exe 本来就自带手柄模块，安装程序会告诉你，不会多此一举。

> **动手前先关掉模拟器** —— exe 被占用会复制失败。

### 如果 Windows 提示"脚本未数字签名"

从浏览器下载的 zip 带了"来自网络"标记，解除一下即可：

```powershell
Get-ChildItem *.ps1 | Unblock-File
```

（或者右键 `launcher.ps1` → 属性 → 勾"解除锁定"。）

---

## 启动器里多了什么

官方的显示 / 画质 / 输出选项原样保留，改动都集中在新增的 **`Mods`** 分组里：

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

其中 `SAVEDATA0PlayerProfile1 · character 160` 那行是**灰字**，开窗时从存档现读，用来对照"到底写进去没有"。

### 金手指：勾哪条开哪条

| 默认开 | 默认关 |
| --- | --- |
| Max Souls（魂 999,999,999） | Player Never Dies（不死） |
| Infinite HP（玩家不受伤害） | One Hit Kill（一击必杀，实验性） |
| Infinite Stamina（不耗耐力） | Debug menu: open in game（实验性） |
| Infinite MP | Dev build flags: RetailBuild off（实验性） |

`Cheats` 总开关不勾就整块置灰，等于一条都不加载。偏移是按 **01.007.000（PPSA01341）** 写的，
换游戏版本会写错地址 —— 那时候用 `addons/cheats/verify_cheat.py` 对着 `eboot.bin` 复核一遍。

### 世界倾向：**要勾才写**

游戏里的倾向不存在启动参数里，而是存在存档里，所以启动器是直接改存档文件：

```
_SaveData\PPSA01341\SAVEDATA0PlayerProfile<n>\USR-DATA
```

三条规则，记住就不会踩坑：

1. **勾了才写**。没勾的世界一个字节都不动 —— 想只把 Stonefang 调成纯白、其它世界保持原样，就只勾它。
2. **启动时才生效**。改完要重进游戏，游戏开着的时候改是没用的。
3. **勾着 = 一直钉住**。每次启动都会写回你设的值，游戏里挣来的变化下次启动会被覆盖；不想钉了去掉勾。

量程 **−200（纯黑）~ 0（中性）~ +200（纯白）**。

**存档里的槽号不是世界号。** 这是实测出来的，和"按顺序排"的直觉相反：

| 游戏里的世界 | W1 Boletarian | W2 Stonefang | W3 Latria | W4 Shrine | W5 Valley |
| --- | --- | --- | --- | --- | --- |
| 实际写进存档 | `World01` | **`World05`** | `World03` | **`World02`** | `World04` |

所以界面上是 **5 行、按世界号排**，每行背后写哪个槽已经固定好了，你不用管。旧版本的设置文件
（7 项、按槽号）会被自动换算过来，之前设过的数不会跑到别的世界上。

### 手柄音量

两行都用**包里默认值的百分比**表示，**100 % = 什么都不改**：

| 项 | 管哪一路 | 范围 |
| --- | --- | --- |
| Speaker | 手柄**喇叭** | 0 ~ 400 %（0 % 静音） |
| Vibration | 手柄**马达 / 触觉** | 0 ~ 400 %（0 % 关掉） |

这是手柄自己的两路输出，**不影响游戏主音量**（那个还是 Windows 音量条）。

### 调试菜单

这个版本里**没有任何按键能打开调试菜单**：游戏里唯一绑定的入口是控制台快捷命令，
而输入例程本身被 `.bss` 里一个恒为假的指针挡着（整段是死代码）。所以给了两条实验性 mod 从代码侧撬开：
`Debug menu: open in game` + `Dev build flags: RetailBuild off`。**默认关、可能崩**，好奇再试。

---

## 常见问题

**改了倾向，游戏里那行数字还是 0.00？**
先确认三件事：游戏已关闭、那一行**勾了**、改完是**重新进游戏**的。另外灰字那行是存档现值，
开窗就能看到到底写进去没有；不想开窗可以用 `launcher.ps1 -DryRun`，只读不写。

**世界 2 设成 200，结果世界 4 变了？**
旧版启动器的锅（它以为槽号就是世界号），已经修好：现在世界 2 写 `World05`，世界 4 写 `World02`。
见上面那张表。

**手柄扳机没有阻力？**
先在游戏里**真的拉弓蓄力 / 挥刀砍几下** —— 在菜单里开关"扳机效果"是不会有手感的，游戏那时只发一次
"两侧全关"。还不行就跑 `addons/dualsense/probe_trigger.exe`：它不启动模拟器，直接给 R2/L2 依次发四种效果，
先震一下马达证明通路。工具活、游戏死 = 游戏侧；两边都死 = 手柄或系统侧。

**手柄没声音 / 声音太小？**
游戏送到手柄喇叭的那路音频本身就很小（峰值约 −40 dB），包里有 ×8 增益兜着。还是小就调 Speaker，
400 % 就是 ×32。

**怎么确认装的是整合版？**
`kyty_emulator.exe` 里同时搜得到 `DualSenseHaptics` 和 `KYTY_DUALSENSE_HAPTICS` 两个字符串就是整合版；
上游原版一个都没有。

**启动报错、进不去游戏？**
先看模拟器目录 `logs\` 里最新的 `.out.log`，再试 `_Backup\` 里回退一个文件。

---

## 跟着版本更新

上游发了新版本时：

1. 解压新版本到新目录；
2. 双击 `addons/install.cmd` 选那个目录（金手指和启动器立刻可用）；
3. 如果新版本没有手柄模块、或者你想换成整合包这套 SDL2 后端，跑一次 `addons/dualsense/rebuild.cmd`。

`addons/install.cmd` **从不擅自改 exe**，它只会在包里有"正好这个版本"的现成 exe 时才替换并提示你。

## 自己从源码重编（可选）

```powershell
cd addons/dualsense
.\rebuild.cmd -Target G:\KytyPS5-v20261017 -Version v20261017
```

一条命令做完：下载该 tag 的源码 → 打补丁 → 编译 → 装回模拟器目录。
第一次约 15 分钟，之后改了东西通常 1~2 分钟（只重编变化的文件）。**金手指不需要编译**。

需要 Visual Studio 2026（C++ 工作负载、Clang 20+）、CMake、Ninja。

## 文件都在哪

```
addons\
  launcher.ps1                 启动器（官方选项 + Mods 分组）
  install.ps1 / install.cmd    把启动器和金手指复制进任意版本目录
  cheats\                      金手指文件、说明、校验脚本
  dualsense\                   SDL2 后端：补丁、rebuild.ps1、现成 exe、扳机探针
  NOTES.zh-CN.md               工程笔记（逆向过程、每个地址）
ADDONS.md                      英文版功能说明
ADDONS.zh-CN.md                本文件
src\libs\dualSenseHaptics.*    本 fork 唯一改动的上游文件
```

## 许可与来源

- 本项目是 [chenxiao07/KytyPS5](https://github.com/chenxiao07/KytyPS5) 的 fork，同样 **GPL-2.0**。
- 分发二进制时同时提供源码，源码在仓库的 `addons/` 与 `src/libs/dualSenseHaptics.*` 里。
- 仓库地址：<https://github.com/Sebs886/KytyPS5>　发布页：<https://github.com/Sebs886/KytyPS5/releases/tag/v20261017-addons>
- 需要自备正版游戏与固件文件，本包不含任何游戏数据。只针对 **恶魔之魂 PS5 版 01.007.000（PPSA01341）**。
