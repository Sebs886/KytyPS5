# KytyPS5 附加功能整合包

把两个自制功能从"编译进某个版本"变成"可以跟着版本走"的形式。

- **金手指** —— 覆盖到模拟器根目录即可生效，**不需要编译**
- **DualSense 手柄触觉** —— 需要编译。**1016 起官方源码里自带了一份**（WASAPI 实现），
  但整合包用的是自己那份 SDL2 后端（用 `SDL_GameControllerSendEffect` 把右声道路由到手柄喇叭，
  喇叭路另垫 ×8 数字增益 —— 喇叭/马达这两个增益现在能在启动器里调，见「一之五、手柄音量」），
  所以 1016 上要跑一次 `dualsense\rebuild.cmd` 把实现层换掉；老版本则本来就靠它打补丁。
  两个现成 exe（1013 / 1014）在 `dualsense\` 下，版本对得上时 `install.cmd` 会直接替上，不用编译

---

## 一、怎么用（版本更新后的标准动作）

1. 解压/复制新版本模拟器到例如 `G:\KytyPS5-v20261016`
2. 双击本目录下的 **`install.cmd`**（会弹窗让你选模拟器目录，也可以直接把目录拖到 `install.cmd` 上）
   - 它会：备份原 `launcher.ps1`、`cheats\`、`kyty_emulator.exe` → 复制新启动器和金手指 → 保留你原来的设置（分辨率、游戏路径、金手指勾选状态、倾向值、手柄音量、VSync/HDR/帧生成等官方选项）
   - 如果这个版本**没有**手柄模块、而包里有对应版本编译好的 exe，会一并替换并提示你
   - **`install.cmd` 从不改 exe**：它只认"包里有没有现成的这个版本的 exe"，
     1016 及以后官方自带触觉时它会如实告诉你、保持不动（换实现层是 `rebuild.cmd` 的事）
3. 到此**金手指已经能用了**，直接双击模拟器的 `launcher.cmd` 即可
4. 要换触觉实现（新版官方自带、或版本对不上）时跑 **`dualsense\rebuild.cmd`**
   （第一次约 15 分钟起，换 PGO profile 的版本会全量重编，之后通常几分钟）

> 也可以把 `install.cmd` 直接放进模拟器目录里跑：它会自己去 `G:\KytyAddons` 找源文件，
> 不会把文件复制给自己。不过建议还是保留 `G:\KytyAddons` 这份原始包，那是给新版本打补丁的地方。

`install.cmd` 结束时会自动检测并告诉你：这个 exe 里有没有手柄模块、`run-windows.ps1` 支不支持 `-Patch`。

---

## 一之二、启动器上的 HDR 选项（v20261014 起）

1014 给 `run-windows.ps1` 加了 `-Hdr`（内部转成 `kyty_emulator.exe --hdr`）。整合包的启动器里已经带了这个勾选框，
勾上就会传 `-Hdr`。

**注意**：HDR 不是开了就有画面变化，它需要**两件事同时成立**：

1. Windows 里先把显示器设成「使用 HDR」→ 设置 → 系统 → 显示
2. 模拟器这边再勾上 HDR10

两边都到位，画面才会按 HDR10 输出；Windows 那边没开 HDR 时，模拟器会按 SDR 输出。这是模拟器的设计，不是 bug。

另外：**HDR 是整条输出链路的末端**，勾了之后如果觉得画面发灰、发白，优先怀疑是显示器的色温/亮度补偿（Windows HDR 校准）而不是模拟器。

旧版本（1013 及以前）没有 `-Hdr` 参数，启动器会自动**隐藏这一行**，不会出现一个点了没反应的开关。

---

## 一之三、世界倾向 / 人物倾向

这些控件都在启动器的 **Mods** 分组里，左侧标签是 `Tendency`：

```
Tendency   [ ] W1  Boletarian Palace    [ 120]    ← 5 个世界，逐个勾、逐个填
           [ ] W2  Stonefang Tunnel     [ 120]
           [ ] W3  Tower of Latria      [   0]
           [ ] W4  Shrine of Storms     [ 200]
           [ ] W5  Valley of Defilement [   0]
           [ ] Character tendency       [  60]    the same scale (-200 the dark path, +200 pure white)
           SAVEDATA0PlayerProfile1 · character 160 · world W1..W5 120/120/0/200/0   ← 灰字，开窗现读
           -200 pure black ... 0 neutral ... +200 pure white; a tick pins that one world ...
           [ ] Show the numbers next to the tendency icons (the game's own readout)
           [ ] Ask for the debug menu at boot (the menu itself comes from the "Debug menu: open in game" cheat)
```

**每个世界都是分开的**：勾哪个世界才写哪个世界，没勾的一个字节都不碰 —— 所以可以只把
Boletarian Palace 调成纯白，另外几个世界保持游戏里的原样。勾上的那个世界**每次启动都会被写回**，
游戏里挣来的变化下次启动就被覆盖（这就是"钉住"的意思）；不想钉了把勾去掉即可。

数字框 **-200 ~ +200 的整数**、步进 20，也可以直接输入。**开窗时五个框会自动填成存档里的现值**，
所以第一次打开就能看到游戏现在到底是什么状态，改起来只需要动要动的那一个。
**灰字那一行**写的是用的是哪个角色档、人物倾向多少、5 个世界各多少，同样是开窗时从存档现读的。

### 世界 → 存档槽：**这张表是实测出来的，不是按顺序推的**

⚠️ 这一节在 2026-10-17 晚**被推翻重写过一次**。旧版本按"存档槽 N = 世界 N"直接对应，
结果把 4 写进了世界 2 的框、游戏里却是**世界 4**亮了 —— 因为**存档槽号和世界编号根本不是一回事**。

做法：给 7 个槽各写一个**互不相同**的数（10/40/70/100/130/160/190），进游戏 Tendency 页逐个读回来：

| 槽 | 写进去 | 游戏里读回来 | 结论 |
|---|---|---|---|
| `World01` | 40 | Boletarian Palace (World 1) | 世界 1 |
| `World05` | 160 | Stonefang Tunnel (World 2) | **世界 2** |
| `World03` | 100 | Tower of Latria (World 3) | 世界 3 |
| `World02` | 70 | Shrine of Storms (World 4) | **世界 4** |
| `World04` | 130 | Valley of Defilement (World 5) | 世界 5 |
| `World00` | 10 | 没有世界响应 | Nexus（游戏不给它世界倾向） |
| `World06` | 190 | 没有世界响应 | 第六世界，**进不去** |

所以启动器里五行对应的槽是 **`1, 5, 3, 2, 4`**（写在 `$worldSlots`，注释里也抄了一遍）。
`World00` 和 `World06` 两行已经从界面上删掉：前者喂游戏没反应，后者是那个进不去的世界。

世界**编号和名字**本身（0=Nexus、1..5=五块拱心石）倒是四条独立线索互相对得上的：

* 游戏自己的传送数据 `misc/dspointsofinterest.txt`：`+cp11_loadLevel <世界> <区域>`，
  `m01_00`→0 Nexus、`m02_00`→1 Boletaria、`m06_00`→2 Stonefang、`m04_00`→3 Latria、
  `m03_00`→4 Shrine、`m05_00`→5 Valley、`m08_00`→8 教学关（不是 6）
* 调试菜单页面项 `Current - World 0 (Nexus)` … `World 5 (Valley of Defilement)`，`Next - World n` 六条成对
* 拱心石名称表 `0-1 Nexus` / `1-1 Boletarian Palace` … `5-1 Valley of Defilement`（另有 `8-1 Fort Entrance`）
* 属性名 `WorldStatus_NexusTendency` / `_BoletariaTendency` / `_StonefangTendency` /
  `_LatriaTendency` / `_StormsTendency` / `_ValleyTendency`

**错的只是"槽号等于世界号"这一步**：编号那套是对的，存档槽的排布是另外一套（很像 PS3 原版的布局）。

升级兼容：旧设置文件里 `tendencyWorlds` 是 **7 项、按槽号排**；新版是 **5 项、按世界排**。
启动器靠数组长度区分两者，旧文件会按 `$worldSlots` 重新取一遍，所以你之前设的数不会跑到别的世界上。


### 结论先放在前面（2026-10-16 定案）

**倾向不住在 convar 里，住在存档里。** `cp11_tendency_*` 那 14 个 convar 是**调试菜单自己的视图**，
游戏玩法根本不读它们，所以不管启动参数发什么值、游戏里那行数字都不会动
—— 这正是"填 200 进去还是显示 0.00"的原因。**前面几轮一直在这条路上绕，方向是错的。**

现在启动器改的是这个文件：

```
G:\KytyPS5-v20261016\_SaveData\PPSA01341\SAVEDATA0PlayerProfile<n>\USR-DATA
```

一个明文的键值表：`u32 version | u32 FNV-1a 32 of the payload | u32 payload_size | u32 reserved`，
后面一条条 `<u32 FNV-1a 32 of the UPPER-CASE name><u8 type><value>`。类型 `0x0a` = 4 字节 float，
16 个倾向字段全是这个类型：

| 字段 | 含义 |
|---|---|
| `Tendency_Player_BlackWhite` / `Tendency_Player_LeftRight` | **人物倾向**（两条轴，游戏里始终同值） |
| `Tendency_World00_*` | 世界 0 = **Nexus** 楔之神殿 |
| `Tendency_World01_*` | 世界 1 = **Boletarian Palace**（柏雷塔尼亚王城） |
| `Tendency_World02_*` | 世界 2 = **Stonefang Tunnel**（石牙坑道） |
| `Tendency_World03_*` | 世界 3 = **Tower of Latria**（拉特里亚塔） |
| `Tendency_World04_*` | 世界 4 = **Shrine of Storms**（暴风祭祀场） |
| `Tendency_World05_*` | 世界 5 = **Valley of Defilement**（腐朽谷） |
| `Tendency_World06_*` | 这个版本里没有对应区域（空槽） |

每一对都是 `_BlackWhite` / `_LeftRight` 成对出现，加上人物那两条，一共 **16 个字段**。

量程是 **-200 ~ +200 的 float**：-200 纯黑，0 中性，+200 纯白。
一次"肉身死亡"是 **-60**，杀一个 boss 是 **+60**（王城）/ **+90**（其它世界），
所以 ±200 和游戏本身的记法是一致的。

### 证据链（三层，互相独立）

1. **游戏自己的取数代码。** eboot 从 `0x2cc33` 起有一段循环 `r12 = 0..6`，用 `sprintf` 生成
   `Tendency_World%02d_BlackWhite`（串在 `0x2422505`）和 `Tendency_World%02d_LeftRight`
   （串在 `0x23f382d`），把结果**按名字哈希**（`0xdd45d0`，就是 `fnv1a32(名字转大写)`）去查表，
   查到的 float 塞进一个 `{float bw; float lr}` 数组，最后整块拷给 UI
   —— **这就是图标旁那行数字的数据来源**。缺项时的默认值是 `0x3f000000`（0.5f），
   说明"键不存在"和"键为 0"是两回事。
2. **存档里真的躺着这些键。** 把 eboot 的字符串全部大写后做 FNV-1a32，再回存档里找，
   命中的键里就有全部 16 个倾向字段（另外还有 `MapUid`、`playTime`、`Player_Name`、
   `WorldStatus_MirrorMode` 等）。读出来的人物倾向是 **0.0** —— 和游戏里显示的 `0.00` 一致；
   世界倾向是 **-180 / +120 / 0 / 0 / 0 / +120 / 0**，说明游戏一直在往这里写真实数据。
3. **模拟器源码里的格式定义。** `src/loader/demonsSoulsWarp.cpp` 第 29 行、
   `tools/local/demons-souls-save.py` 都写着同一套格式，而且游戏的调试传送功能
   **本来就是靠改这个文件实现的** —— 说明改它是安全的、被支持的用法。

> `Tendency_Player_BlackWhite` / `_LeftRight` 这两个名字**在 eboot 里搜不到字面串**，
> 是按上面第 1、2 条的规律穷举了 12000 个候选名匹配出来的
> （哈希 `0xCD98E106` / `0x80205423`，两个角色档里都是 0.0）。

### 它是怎么写的

`launcher.ps1` 里新增 `Get-TendencySave` / `Get-WantedTendencies` / `Write-TendencyToSave`：

1. 在 `_SaveData\<title>\SAVEDATA0PlayerProfile*` 里找**最后被写过**的那个档
   （= 你上次玩的角色），不用你告诉它角色是谁；
2. **先验存档自己的校验和**（`u32 @4 == fnv1a32(payload)`），对不上就一个字都不改
   —— 不认识的存档不要动；
3. 逐条找 `<哈希><0x0a>`（9 字节一条），把 4 字节 float 改掉；键不存在就插在世界块前面
   （游戏是按哈希查的，表内位置无所谓）。**只有勾上的槽才进这个列表** ——
   没勾的世界连查都不查，所以不会被写；
4. 重算并回写 `@4` 的 FNV-1a 32 与 `@8` 的 payload 大小；
5. **原文件备份成 `USR-DATA.bak`**（每次覆盖同一个文件，不会堆一堆）。

哈希和扫描放在一个小 C# 辅助类里（`Add-Type`）：40 KB 的 payload 用 PowerShell 循环算
FNV-1a，每次启动都会慢到能感觉出来。

> 校验和这条是硬的：算错的话游戏直接**丢弃整个存档**。所以写之前先验一次，
> 写完再回读确认（`launcher.ps1 -DryRun` 会打印 `tendency save:` 与 `tendency writes:` 两行）。

### 怎么验证

**第一步：关掉游戏。** 存档被占用时写入会失败（启动器会弹框告诉你，不会静默）。

**第二步：只勾想改的那个世界。** 比如只把 **W1 Boletarian Palace** 勾上、填 `200`，其余世界一律不勾，
点 Play。进游戏看倾向图标 —— 王城的倾向应该偏到纯白，**另外几个世界一点没动**；
数值行也是（前提是勾了 "Show the numbers next to the tendency icons"，那一项**已被验证有效**）。
想回中性填 0，想纯黑填 -200。

**第三步：再开一次启动器**，看灰字那行有没有变成 `world W1..W5 120/200/0/200/0`
（只有 W2 那一位从 120 变成 200）。这一步不用进游戏，是确认写入成功最快的办法。

> **不想让它一直钉住就把勾去掉。** 勾着 = **每次启动都重写那一个世界**，你在游戏里挣来的
> 那个世界的倾向变化下次启动会被覆盖掉；没勾的世界完全不受影响。
> 倾向是**启动时写进去的，不是实时改的**：改完必须重进游戏。

想不开窗口先自查，用 `launcher.ps1 -DryRun`，它会打印两行：

```
tendency save: SAVEDATA0PlayerProfile1  ·  character 160  ·  world W1..W5 120/120/0/200/0
tendency writes: Tendency_World05_BlackWhite=200 Tendency_World05_LeftRight=200 Tendency_Player_BlackWhite=60 Tendency_Player_LeftRight=60
```

第一行是**现在存档里的值**，按 **W1..W5 = 世界 1..5** 排（背后是槽 1、5、3、2、4，见上面那张表）；
第二行是**这次将要写进去的**，只有你勾上的世界会出现在这里，而且写的是**槽名**
（上例勾的是 W2 Stonefang，所以是 `World05`）。两行一致 = 无事可做；不一致 = 点 Play 就会写。

> "Show the numbers next to the tendency icons" 这一项仍然走 convar
> （`cp11_uiShowNumericalTendencyData=true`），它**确实有效**——因为它只是个显示开关，
> 不参与数值本身。日志 `G:\KytyPS5-v20261016\logs\<最新>.out.log` 里能看到：
>
> ```
> Game args: G:/Game/PPSA01341-app0/packagecmdlineargs.txt read with
> +cp11_callHomeLockDownEnabled=false
> +doIndexBufferCulling=false
> +cp11_uiShowNumericalTendencyData=true
> ```
>
> `cp11_callHomeLockDownEnabled=false` 是游戏文件里本来就有的，`doIndexBufferCulling=false`
> 是这一版**自己的**默认 convar，都要保留。**倾向数值本身已经不在这个列表里了。**

### 2026-10-16 修的四个 bug

**bug 1：选了倾向、点 `launcher.cmd` 弹错闪退，而且之后再也打不开启动器。**

根因在数字框的构造顺序。两条倾向数字框原来是用一个 `New-Object -Property @{...}`
把 `Minimum` / `Maximum` / `Value` 一次性塞进去的，而**哈希表的应用顺序并不保证**。
一旦 `Value` 先于 `Maximum` 生效，`200` 就会撞上 `NumericUpDown` 的默认上限 `100`，
报"在此对象上只允许介于 -200 和 100 之间的值"。更糟的是这个 `200` 当时已经被写进了
`launcher-settings.json`，于是**之后每次启动都必然在同一行崩** —— 表现出来就是"启动器再也打不开"。

修法两条：

* 数字框改由函数 `New-TendencyBox` 构造：先设 `Minimum` / `Maximum`，最后才写**已经钳过范围**的 `Value`；
* 窗口最前面加一个全局 `trap`：将来万一还有别的坏设置，会弹对话框把异常和 `settings` 路径显示出来，
  **而不是让窗口无声无息地消失**。（这个 bug 当初难查，正因为它连一条事件日志都没留下。）

**bug 2：倾向的勾选和数值进游戏完全不生效。**

启动器原来只做 `$env:KYTY_GAME_CONVARS = ...`，而 `run-windows.ps1` 里那个 `$environment`
**只从同目录的 `launch.json` 取值，不读进程环境**，于是它被自己那句默认值
（`doIndexBufferCulling=false`）覆盖，游戏只收到默认那一项。
修法：改成 `-Set "KYTY_GAME_CONVARS=<该版本自己的默认值>;<我们要传的>"`。

> 那对引号是必需的：`;` 在 PowerShell 里是语句分隔符，不加引号只会传进第一项。

（现在这条只用于"显示倾向数值"和调试菜单两个开关，倾向数值本身已经不走了。）

**bug 3：人物倾向填 200 进游戏毫无变化；"显示倾向数值"勾了也不显示。**

同一个根：**用错了游戏的语言**。

1. **布尔写法错了**（这条是硬的、有游戏自己文件作证的）。启动器发的是
   `cp11_uiShowNumericalTendencyData=1`，而游戏自己所有地方都写 `true`：
   `coredata\enginesupport\dsshortcutbuttons.xml` 是 `cp11_toggleDebugMenu = true`，
   游戏自带的 `PackageCmdLineArgs.txt` 是 `+cp11_callHomeLockDownEnabled=false`。
   `=1` 就是引擎不认的那个拼法 → 数值显示一直不出现。修法：布尔一律 `=true`。
   **这一条今天被验证了：改完数值显示就出来了。**
2. **量程**：`±200`、中性 `0`。这条来回错了两轮，直到这次从**存档里的真实数据**
   （-180 / +120）拿到独立证据才算定死。

修法：`ConvertTo-TendencyNumber` 钳到 **±200**、坏值回落 **0 = 中性**；
数字框 **-200 ~ +200 的整数、步进 20**。

> 顺带修掉一个**沉默**的计算 bug：钳位原来写的是 `[Math]::Max(0, [Math]::Min(1, $number))`。
> PowerShell 见到 `1`、`0` 这种整数字面量，会选中 `[Math]::Min(Int32, Int32)` 重载，把小数**直接截断** ——
> 结果 `0.5` 变成 `0`、`0.77` 变成 `1`，也就是**不管你在框里填什么，取到的都是 0 或 1**。
> 现在一律用 `0.0` / `1.0` 这种浮点字面量写钳位。这类 bug 不报错、不崩溃，只会静静地给你错的数。

**bug 4（根因，当晚才定案）：那 14 个 `cp11_tendency_*` convar 根本不是游戏读的值。**

前面三轮全都在"怎么把值塞进 convar"上打转，而真正的答案是：**塞进去也没用**。
它们只是调试菜单的视图。证据是游戏自己的取数代码（见上面"证据链"第 1 条）——
图标旁那行数字读的是**存档里按哈希查出来的 float**，和 convar 没有关系。
所以"启动器设 40、游戏里显示 0.00"不是量程问题、不是时机问题，是**找错了存储**。

修法：不再发倾向 convar，改成 `Write-TendencyToSave` **直接改存档**（见上面"它是怎么写的"）。
`Get-TendencyConvars` 现在只剩两个开关。

### 2026-10-16 晚：世界倾向从"一刀切"改成逐世界可调

第一版 `Write-TendencyToSave` 是**一个数字发给全部 7 个槽**（沿用原来那个"World tendency"框），
结果是调一个世界，六个世界的倾向一起被改 —— 这显然不是想要的。

改法：

* 那一个框拆成 **5 组「勾选框 + 数字框」**（`W1 Boletarian Palace` … `W5 Valley of Defilement`，
  每行背后的存档槽是 `1, 5, 3, 2, 4` —— 这是 2026-10-17 实测的表，别按序号推），
  按 4 列 × 3 行的紧凑表格排（`$worldGrid`）；
* **勾 = 钉住这个世界的值**，`Get-WantedTendencies` 只把勾上的世界写进列表，
  没勾的**一个字节都不碰**；
* 设置项从 `tendencyWorldOn`（一个 bool）+ `tendencyWorld`（一个数）
  变成 `tendencyWorldOn`（5 个 bool）+ `tendencyWorlds`（5 个数）；
* **开窗时五个框自动填成存档现值**（`Get-SavedWorldTendencies`），第一次打开就能看到游戏现在的
  状态，只需要动要动的那个；
* **老设置文件能平滑升级**：里面只有单个 `tendencyWorldOn`/`tendencyWorld`、没有 `tendencyWorlds`
  时，按"那个勾对全部世界生效、数值从存档现读"处理；而**旧的 7 项 `tendencyWorlds`（按槽号排）**
  会按 `$worldSlots` 重新取一遍（靠 `$storedBySlot` 区分两种长度），
  所以你之前设的数不会跑到别的世界上。
  默认值故意写成 `tendencyWorlds = @()`（空表）而不是一串 0：**空表才是"这个设置文件没有逐世界值"
  的标记**，一串 0 会和"真的把每个世界都钉成 0"混淆。

> 一个小坑值得记下来：勾选框**共用同一个事件处理脚本块**（`{ Sync-WorldBoxes }`），
> 而不是在循环里各建一个 `{ $box.Enabled = $on.Checked }`。因为 PowerShell 的脚本块是
> **事件触发时才去解析变量**的，循环结束后 `$on`/`$box` 只剩最后一轮的对象，
> 那样写的结果会是"点任何一个勾都只切换最后一个框"。

### 调试页怎么进 / 按哪个键（2026-10-16：答案是没有键）

**这个版本没有任何按键能打开调试菜单，手柄也不行。** 三条独立证据：

1. **游戏里唯一的绑定是主机版快捷菜单。** `misc\dsshortcutbuttons.xml` 里那条
   `<name>Toggle OG Debug Menu</name>` + `<command>cp11_toggleDebugMenu = true</command>`
   是给 PS5 系统级快捷菜单用的，Kyty 没这个概念；文件里其余条目全是 `UI Tests/…`
   自动化脚本（`Tendency 1/2`、`HUD`、`Inventory 1/2`…），也不是按键。
2. **模拟器的键位表里没有调试键。** 发布目录 `README.md` 的 `## Controls` 只有
   `W A S D`（左摇杆）、`T F G H`（右摇杆）、`J L K I`（×/○/□/△）、`Q E`（L1/R1）、
   `Left Shift` + `Left Ctrl`（L3/R3）、方向键（十字键）、`Enter`(OPTIONS)、
   `Backspace` + `Tab`（触摸板两半）、`F7`（鼠标视角）、`Space`（暂停）、`F11`（全屏）、
   `F9`/`F10`/`F8`（调试传送）。**键盘连 L2 / R2 都没有**，组合键也凑不出来。
3. **真正的原因：那一整段代码是死代码。** 每帧都会调用调试输入例程 `0xB2D870`
   （唯一调用点 `0xB28798`），但它的整个主体被这道闸门挡住：

   ```
   0xB2D893  mov  rax, qword ptr [rip + 0x244AA36]   ; rax = [0x2F782D0]
   0xB2D89A  cmp  byte ptr [rax], 1
   0xB2D89D  jne  0xB2DCCD                          ; ← 实际每帧都跳走
   ```

   `0x2F782D0` 是 `.bss` 里的一个 `bool*`，**整个镜像里没有任何一处写入过它**
   （全可执行段逐字节扫过 `mov [rip+…], r` / `lea` / SSE 存储，零命中；
   也没有任何 RELA 指向它），运行时就是 0。而 `0x2F782D0` 在 `vaddr` 从 0 开始的段里，
   于是解引用落到 **VA 0** —— 那里的字节是 `0xCC`（`int3` 对齐填充），`0xCC ≠ 1`，
   所以 `jne` **每帧都跳走**。这个指针本来是要靠"连上 Bluepoint 工具主机"填上的，见
   `misc\gamecommandlineargs.txt` 里的
   `+[PS5][!RetailBuild]LoadCmdsFromFile=/devlog/app/BPLastToolsHost.txt inline=true`。
   没有编辑器连进来 → 指针空 → 调试菜单相关的一切（**包括 `cp11_toggleDebugMenu`**）都无反应。
   **这就是启动器发那个开关没用、进游戏也什么都不显示的原因。**

**顺带查清了限定符表**（`0x816880`，决定 `misc\gamecommandlineargs.txt` 里
`+[限定符]` 哪些生效）：`shipping` 和 `ps5` 在本版**恒为真**（`0x816952` 直接 `mov al,1`）；
`PackageBuild` 为真（`0x8168EA` 读 `0x2EE5241`，即 `isapackagebuild.txt` 是否存在，文件在）；
`tools` / `debug` / `release` **恒为假**（命中后 `0x816933 xor eax,eax`）；
`RetailBuild = !(flags & 2)`（`0x816884 call 0x8469c0; test byte[rax],2; sete al`）。
所以 `DebugMenu.txt` 的加载只被 `RetailBuild` 单独卡住
（第 6 行 `+[!Tools][!RetailBuild]LoadCmdsFromFile=$/misc/DebugMenu.txt`，`!Tools` 本来就成立）。

**所以只有打补丁一条路。** 这次往 `cheats\PPSA01341_01.007.000.json` 里加了**两个默认关闭的
实验性 mod**（详情见 `cheats\README.md` 的 1.2 节）：

| mod | 位置 | 干了什么 |
|---|---|---|
| **Debug menu: open in game (experimental)** | `B2D870` / `B2D893` / `B2D97E` / `B2D983` / `B2D99F` | 把上面那道闸门 16 字节整体 NOP（顺带去掉空指针解引用）；再把菜单开关字节钉死在 1（三处 `mov r15b,1`） |
| **Dev build flags: RetailBuild off (experimental)** | `816868` / `816884` | 让 `RetailBuild` 限定符恒为假，于是开机载入 `$/misc/DebugMenu.txt`（菜单条目定义）和其余 `[!RetailBuild]` 配置 |

**建议的试法**：先在启动器的 Cheats 面板里**只勾第 1 个**（Debug menu: open in game），
进游戏看有没有反应；没反应再勾第 2 个（可以两个一起勾）。**两种情况都有信息量**：
崩溃 → 说明 `0xB2D942` 之前那段对象图还有别的未初始化依赖；还是不显示 → 说明缺的是菜单数据
（该开第 2 个）或渲染资源。**崩了就把它关掉重启即可，不影响存档。**

**渲染副作用提醒**：第 1 个 mod 是"永久把调试菜单置为打开"，如果真渲染出来了，
屏幕上会常驻一个调试叠加层。不想要就关掉它重启。

**✅ 那个"仍未定论"的问题已经定案了**（2026-10-16 晚）：那 14 个 `cp11_tendency_*` convar
**不是**游戏的输入，只是调试菜单的视图 —— 游戏读的是存档（见上面"证据链"）。
所以：

* **要改倾向，不用再碰调试菜单了**，用启动器那两行写存档即可，简单得多、也可靠得多。
* 这两个实验性 mod 现在只是"想看看游戏自己的调试叠加层长什么样"才需要，属于可选项。

先按上面试，把 `launcher.ps1 -DryRun` 的输出、灰字那行的内容、以及游戏里那行数字的变化告诉我。

---

## 一之四、启动器的界面结构（Mods 分组 + 官方原有选项）

1016 的官方启动器比 1014 多了不少东西。整合包的 `launcher.ps1` 在官方那份的基础上**新增了一个 `Mods` 分组框**，
官方原有的一行没删：

```
Game folder        [ G:\Game\PPSA01341-app0            ] [Browse...] [.zar...]
                   Demon's Souls (PPSA01341 01.007.000)
Resolution         [1920x1080 v]
                   [ ] Fullscreen   [x] Keep 16:9 (black bars)
Console language   [English (United States) v]
┌ Mods ───────────────────────────────────────────────────────────────────────┐
│ Cheats        [x] [PPSA01341_01.007.000.json v]                             │
│               ┌──────────────────────────────┐  ← cheat 文件里的每一条 mod │
│               │ [x] Max Souls (999,999,999)  │                              │
│               │ [x] Infinite HP (No Damage)  │   （框不住时这里会滚动）     │
│               │ ...                          │                              │
│               └──────────────────────────────┘                              │
│               [Select all] [Select none]    3 of 8 on                       │
│ Tendency         [ ] W1  Boletarian Palace     [ 120]                       │
│                  [ ] W2  Stonefang Tunnel      [ 120]                       │
│                  [ ] W3  Tower of Latria       [   0]                       │
│                  [ ] W4  Shrine of Storms      [ 200]                       │
│                  [ ] W5  Valley of Defilement  [   0]                       │
│                  [ ] Character tendency        [ 160]                       │
│                  SAVEDATA0PlayerProfile1 · character 160 · world W1..W5 ... │
│                  [ ] Show the numbers next to the tendency icons ...        │
│                  [ ] Ask for the debug menu at boot ...                     │
│ Controller volume [ ] Speaker   [100] %  ...                                │
│                   [ ] Vibration [100] %  ...                                │
└─────────────────────────────────────────────────────────────────────────────┘
                   [x] Red-zone protection (recommended)
                   [ ] Up to 120 fps (the game's own frames; movies stay at 60)
                   [ ] VSync (no screen tearing; adaptive sync displays keep it)
                   [ ] HDR (turn on "Use HDR" in Windows display settings first)
Render height      [1296 v]   Demon's Souls 3D; lower = faster, less sharp
Aspect ratio       [16:9 (PS5) v]  ...
Graphics           [Standard (PS5) v]  ...
Frame generation   [Off v] [Streamline...]  ...
Overlay            [Off v]   top right: frame rate and frame times; detailed: GPU, CPU, memory
                   [ ] Precompile on the efficiency cores only (slower, the PC stays responsive)
                   [Play] [Precompile shaders] [Export shader hints] [Logs folder] [README]
```

**`Mods` 分组里放的是「改游戏行为」的东西**，分两层：

| 层 | 内容 | 勾选状态存在哪 |
|---|---|---|
| **金手指**（`cheats\*.json`） | `Cheats` 总开关、金手指文件选择、文件里的每一条 mod | `launcher-settings.json` 的 `modStates`（键是 `<文件名>::<mod 名>`），**不写回 cheat 文件** |
| **KytyAddons 自己的开关** | 倾向（写存档）、调试读数 / 调试菜单、手柄喇叭 / 震动 | 同一个 `launcher-settings.json` |

两层之间**唯一的联动**是：`Cheats` 没勾时，金手指那一整块（文件选择 + mod 列表 + Select all/none）会**置灰**；
下面 KytyAddons 那部分**不受影响**，因为它们不依赖 cheat 文件。

两层在界面上**没有任何分隔文字**：金手指那几条除了 `Cheats` 之外**不带行标签**（列表左边缘与下面
`[Select all]` 对齐），下面紧接着就是 `Tendency` / `Controller volume` 那几行，整块读起来是一条连续的列表。
（早先版本曾在列表与 `Tendency` 之间插过一行灰字 `KytyAddons options - ...`，2026-10-16 晚去掉了。）

**倾向那一块是「每个世界一行」**：`W1`…`W5` 五行，各自一个勾选框 + 一个数字框，勾哪个写哪个，
**没勾的原封不动**（2026-10-16 晚之前是一个值写满所有世界，改一次会把所有章节的倾向一起冲掉）。
`Character tendency` 是人物倾向，和世界无关，单独一行。哪一行忘了勾就不会被写进存档 —— 这是刻意的，
代价是「以为改了其实没改」，所以灰字那行会实时把存档里的现值打出来供你对照。
**行号就是游戏里的世界号**（W2 就是 Stonefang），但每行背后写的存档槽不是同一个数字，
见上面「一之三」的实测表（`1, 5, 3, 2, 4`）。

官方原有的选项（显示 / 画质 / 输出 / 调试叠加层 / 工具按钮）留在 `Mods` 分组**之外**，原样保留：

| 分组 | 选项 | 传给 exe 的东西 |
|---|---|---|
| 显示 | 分辨率、全屏、Aspect fit、Render height、Aspect ratio | `-Width/-Height/-Fullscreen` … `-RenderHeight` |
| 画质 | Graphics、Quality | `-Graphics` / `-Quality` |
| 输出 | **VSync** | `-PresentMode Fifo` |
| 输出 | **HDR10** | `-Hdr` |
| 输出 | **Frame generation** + Streamline 运行时选择 | `-FrameGen` / `-Streamline` |
| 调试 | **Overlay（FPS HUD）** | `-Set KYTY_FPS_HUD=…` |
| 工具 | **Export shader hints** 按钮、Logs 文件夹、README | 不传参，直接调脚本 |

其中 Frame generation 那一行会先去找**带 NVIDIA 签名的 Streamline 运行时**，
找不到就只显示一行说明、不给你一个点了没反应的开关（和 HDR 在旧版本上的处理一样）。

**版本容错也保留了**：启动器先读一遍同目录的 `run-windows.ps1`，只传这一版**确实声明了**的参数。
某个未来版本去掉了 `-RenderHeight` 或 `-Patch`，界面会自动标注并跳过，不会因为参数不存在而启不来。

> 实现上，行是加进 `$rowTable` 指向的那张表里的：`Mods` 分组建好自己的内部网格后把 `$rowTable` 指过去，
> 加完再指回主表。所以分组里外都是同一个 `Add-Row`，不需要两套代码
> （改完实测：分组框 890×602，窗口 1009×1222，`In-Tree` 核对过 13 个控件在框内、12 个官方控件在框外）。

---

## 一之五、手柄音量（喇叭 / 震动强度）

启动器 **Mods 分组**里多了两行，**勾上才生效**（和倾向那两行一个用法）：

```
Controller volume  [ ] Speaker     [100] %   % of the pad's own speaker level - 100 % is the package default, 0 % mutes it (DualSense only)
                   [ ] Vibration   [100] %   % of the strength the package gives the pad's actuators - 100 % is the default, 0 % stops them
```

它们管的是 **DualSense 手柄自己的两路输出**，不是游戏的主音量（主音量还是 Windows 那个音量条）：

| 界面上的项 | 环境变量 | 包里的默认值 | 允许范围 | 管哪一路 |
|---|---|---|---|---|
| **Speaker** | `KYTY_DUALSENSE_SPEAKER_GAIN` | **8.0** | 0 ~ 64 | 手柄**喇叭** |
| **Vibration** | `KYTY_DUALSENSE_HAPTICS_GAIN` | **1.0** | 0 ~ 4 | 手柄**马达（触觉）** |

界面填的是**相对包里默认值**的百分比，所以 **100 % = 什么都不改**（就是现在听到/摸到的强度），
**不勾选**和**勾上填 100** 是同一个效果。数字框是 0 ~ 400 %、步进 25 %（步进取 25 是为了让每一档都落在整数增益上）。

**为什么喇叭要垫 ×8 才正常**：游戏送到手柄喇叭端口的那路音频**本身就很小** ——
Demon's Souls 峰值大约 -40 dB（`dualsense\v20261016\dualSenseHaptics.cpp` 的注释里写着），
不垫增益的话手柄自己那级放大只会把它埋进底噪里。所以：

* 觉得手柄声音**小** → 往上调（200 % 就是 ×16，400 % 是 ×32）；
* 觉得**吵** → 往下调；
* **0 % 就是静音**（喇叭那一路完全不出声，但**不影响游戏主音频**，也不影响震动）；
* 震动太大/太弱 → 调 Vibration，0 % 就是关掉马达那一路。

**实现方式：不需要重编译，也不用改任何游戏文件。**

* 这两个变量是整合包**自己那份 SDL2 后端**在读的（`libs/dualSenseHaptics.cpp`），上游官方那版没有它们 ——
  也就是说它跟着已有的补丁**早就在 exe 里**了（可以自查：`kyty_emulator.exe` 里搜得到
  `KYTY_DUALSENSE_SPEAKER_GAIN` 这个字符串，而且 `IAudioClient` 为 0，说明就是这份后端）；
* cpp 里是**启动时读一次**（`std::getenv`），所以改完要**重进游戏**才生效，游戏中途改没用；
* 启动器把值拼进 `run-windows.ps1 -Set "…,KYTY_DUALSENSE_SPEAKER_GAIN=10,KYTY_DUALSENSE_HAPTICS_GAIN=0"`
  一起交出去（和 `KYTY_GAME_CONVARS`、`KYTY_FPS_HUD` 走同一条路，理由见下一节那个坑）；
* 值超出范围会被 cpp 里的检查**丢掉并退回默认**，不会调出怪声或把音量钳成 0。

**怎么验证 / 怎么看当前值**：`launcher.ps1 -DryRun` 会**不开窗口**直接打印一行

```
controller volume: KYTY_DUALSENSE_SPEAKER_GAIN=10, KYTY_DUALSENSE_HAPTICS_GAIN=0
```

（上面这就是勾了 **125 % / 0 %** 的样子：`125 % × 8 = 10`、`0 % × 1 = 0`。什么都不勾时它打印
`(the package default: the pad speaker at gain 8, the actuators at gain 1)`。）

想看这条通路真的在跑，再设 `KYTY_DUALSENSE_HAPTICS_LOG=1`（这个不在界面上）：改 `launch.json` 的
`environment`，或临时在 `-Set` 里加上它，控制台就会打出设备名和每一路的状态。

> ⚠️ **只对 DualSense 有效**。这两路是 DualSense 的 USB 音频端点（四声道，前一对给喇叭、后一对给马达），
> DualShock 4 / Xbox 手柄没有这个端点，调了也不会有任何变化。

---

## 一之六、自适应扳机（trigger effect）：**已验证可用**

> **结论（2026-10-17 19:13 实测）**：不用改任何代码。带上探针进游戏拉弓，日志里立刻出现
> `mask=0x02 / mode=1 / send=0` 的请求序列，R2 有明显阻力。上游的实现本来就能用，
> 之前的"没效果"只是因为当时**没有做会触发它的动作**（在菜单里切开关不会）。

DS5 的自适应扳机走的是 **HID 输出报文**，和我们做的喇叭 / 马达（走 USB **音频**端点）是两条互不相干的通路，
理论上可以同时工作。这功能**上游本来就已经实现**了（不是整合包加的补丁）：

- `libs/libPad.cpp` 注册了 `scePadSetTriggerEffect`（NID `2JgFB2n9oUM`）和
  `scePadGetTriggerEffectState`（NID `znaWI0gpuo8`）
- `libs/controller.cpp` 的 `trigger_effect_to_dualsense()` 把 PS5 的 7 种效果模式
  （0 关 / 1 恒定阻力 / 2 两段 / 3 振动 / 4 斜率 / 5 多点 / 6 多点振动）**全部**转成 DualSense 的
  11 字节效果块；`GetTriggerEffectState` 也在
- 转出来的 32 字节结构（`enable_bits` + 右扳机 11 字节 + 左扳机 11 字节）与 SDL 内部的
  `DS5EffectsState_t` 偏移完全一致，SDL 2.33 会把它们原样塞进 USB 报文 `0x02`

游戏那边也有一套预设系统（eboot 里有 `controller_triggerEffectEnable`、
`CPOLdrPadTriggerEffectPreset`、`PlatformPadTriggerEffect`、`SendLeftTrigger`）。
**缺的只是"有没有真的走通"的证据**，所以 2026-10-17 在 exe 里加了检测日志。

### 加了哪些探针（全部 `std::printf`）

> ⚠️ 必须用 `printf` 而不是 `LOGF`：**release 配置里控制台的 `LOGF` 是静默的**，
> `PadSetVibration` 那些 `LOGF` 一行都不会出现在日志里。这也是之前看起来"什么都没发生"的原因。

| 日志行 | 位置 | 说明 |
|---|---|---|
| `Pad: trigger effect probe ready (...)` | `Libs::Controller::Initialize` | 启动就打。**有这行才说明这份 exe 带探针**；没这行的空日志不能当作"游戏没调用" |
| `Pad: host '<名字>' opened, SDL type N (DualSense/not a DualSense), rumble triggers 0/1` | `window.cpp` 手柄接入时 | SDL 把这手柄认成什么。type **7** 才是 DualSense |
| `Pad: device class parsed -> class %d, data_valid %d, unique payload %d` | `libPad.cpp` `PadDeviceClassParseData` | 游戏有没有来问"这是什么手柄"。`class 0` = **STANDARD，就是 DualSense 的正确值** |
| `Pad: controller information asked -> device_class %d (STANDARD), connected %d, count %d` | `PadGetControllerInformation` | 同上，另一条问法 |
| `Pad: trigger effect #N mask=0x.. converted=yes/no host=.. send=.. left[mode=.. data=..] right[...]` | `SetTriggerEffect` | **游戏真的下发了效果**。`send=0` 表示 SDL 已把报文交给手柄 |
| `Pad: trigger state poll #N -> left X, right Y` | `PadGetTriggerEffectState` | 游戏在轮询扳机状态（说明它在用这套机制） |
| `Pad: scePadSetTriggerEffect refused handle N` / `called with a null param` | `PadSetTriggerEffect` | 游戏调了但参数被拒 |

去重规则：**和上一次内容相同的请求只计数不打印**（游戏可能每帧都设一次），每个点位最多 32~64 行，
所以日志不会被刷爆。全部 `fflush(stdout)`，即使崩溃也不会丢。

### 怎么测

1. **先关掉模拟器**（exe 被占用装不进去）
2. 手柄**用 USB 线直连**（蓝牙也能发效果，但 USB 最稳，排除变量）
3. 双击 `launcher.cmd`，正常进游戏、读档
4. 进 **选项 → 手柄 / 控制器**，确认有扳机相关开关的话**打开**
5. 做几个会用到扳机的动作：**拉弓（R2 蓄力）**、挥刀砍墙、举盾 —— 各做几秒
6. 退出游戏，看最新那份日志：

```powershell
$f = Get-ChildItem 'G:\KytyPS5-v20261017\logs\*.out.log' | Sort-Object LastWriteTime | Select-Object -Last 1
"== $($f.Name) =="
Select-String -Path $f.FullName -Pattern 'Pad:'
```

（`logs\<日期时间>-<毫秒>.out.log` 每次启动一份，`err.log` 一般是空的。）

### 日志怎么读

| 看到什么 | 说明 | 下一步 |
|---|---|---|
| 连 `trigger effect probe ready` 都没有 | exe 被换回旧的了 | 重跑 `build-probe.ps1` |
| 只有 `probe ready`，一行 `trigger effect #` 都没有 | **游戏从未调用** `scePadSetTriggerEffect` | 先在游戏里真的做动作（拉弓 / 挥刀）；只切菜单不会调 |
| `host '...' opened, SDL type 2 (not a DualSense)` | SDL 把这手柄当成别的手柄（type 2 = Xbox One） | 换 USB 口/线，或先关掉 DS4Windows / Steam 输入之类的中间层 |
| `host=DualSense` + `send=0`，但 `left[mode=0] right[mode=0]` | 报文发出去了，可内容是**"关掉"**（`mode=0` = off） | 不是故障 —— 那是切开关的反应；要手感得靠玩法动作 |
| `host=DualSense` + `send=0`，`mode=1/2/3` 且字节非零 | 游戏确实要了效果，报文也到 SDL 了 | 跑 `probe_trigger.exe` 交叉验证；它也无效才是手柄/固件侧问题 |
| `converted=no` | 游戏下发的参数超出转换器的取值范围（它会拒掉） | 把那一行贴回来，改 `trigger_effect_to_dualsense()` |
| `trigger state poll` 有输出 | 游戏在等扳机状态回报 | 说明它在用这套机制，只剩手感核对 |
| `refused handle N` | 句柄不是 1（模拟器只开 1 号手柄） | 把 N 记下来 |

### 2026-10-17 第一次实测：菜单里开关开关不会有手感（不是故障）

第一次带探针的实测日志里只有这几行（`host=DualSense`、`send=0`）：

```
Pad: trigger effect #1 mask=0x03 converted=yes host=DualSense send=0 left[mode=0 data=00 00 00 00] right[mode=0 data=00 00 00 00]
```

**读法（两条都是关键，之前都容易读反）：**

- `send=0` 是 **成功**（SDL 的约定是 0 = ok，负数是错误）。所以"发给手柄"这一步没断。
- `mask=0x03` + 两个 `mode=0` 的意思是**把左右扳机都设成"关"**。整局只出现 1 次。
  对着 eboot 反汇编能对上：`CCPLdrPlatformPadTriggerEffect` 每帧把游戏选项同步到一个内部开关
  （`this+0xFA`），**只在开关值变化的那一帧**发一次"全关"。也就是说玩家在菜单里切那个选项，
  游戏确实收到了，但那次动作本身只是"关掉"。
- 真正的阻力来自玩法代码（拉弓、挥刀时才调 `SetFeedback` / `SetWeapon` / `SetVibration`），
  所以"在菜单里开开关关"本来就不会有手感，得**在游戏里做出那些动作**。
- `rumble triggers 0` 也**不是故障**：SDL 对 DualSense 的 `RumbleJoystickTriggers` 一律返回
  Unsupported（它指"扳机震动马达"，不是自适应扳机），和这功能无关。

### 2026-10-17 19:13 第二次实测：**正常，功能可用**

真在游戏里拉弓之后，日志立刻变了——28 行 `Pad:`，其中 25 条是真实的扳机请求：

```
Pad: trigger effect #1 mask=0x02 ... left[mode=0 ...] right[mode=0 data=00 00 00 00]
Pad: trigger effect #2 mask=0x02 ... left[mode=0 ...] right[mode=1 data=05 03 00 00]
Pad: trigger effect #4 mask=0x02 ... left[mode=0 ...] right[mode=0 data=05 03 00 00]
Pad: trigger effect #5 mask=0x02 ... left[mode=0 ...] right[mode=1 data=05 03 00 00]
...（一路交替到 #43）
```

**逐项对照游戏传进来的原始参数**（打印的是 `PadTriggerEffectParam`，不是转换后的 USB 字节）：

| 字段 | 值 | 含义 |
| --- | --- | --- |
| `mask` | `0x02` | 只设**右**扳机（bit0=左, bit1=右）——弓在右手，对得上 |
| `mode` | `1` / `0` | `1` = `FEEDBACK`（连续阻力），`0` = 关闭；拉弓/松开时交替 |
| `data[0]` | `0x05` | 阻力**起点区位 5**（10 个区位，55% 行程处开始变硬） |
| `data[1]` | `0x03` | 阻力**强度 3/8**（轻档，符合蓄力第一段） |
| `converted` | `yes` | 转成 DualSense 11 字节块：`0x21` 连续阻力，区位 5~9 填 3 |
| `send` | `0` | SDL 已把报文交给手柄，成功 |

结论：**链路从头到尾通了** —— 玩法发请求 → Kyty 转换 → SDL 发 USB 报文 `0x02` → 手柄出阻力。
用户实测 R2 有明显手感，无需再改代码。上一节"游戏还没开口要"的判断是对的：
功能本来就在，只是那次会话里没有做出会触发它的动作。

> `#N` 会跳号（3、6、9…不是缺行）：和上一条**完全相同**的请求只计数不打印，避免每帧刷屏。
> 这一版 64 行封顶，之后只累计计数。

### 主机侧单独测：`dualsense\probe_trigger.exe`

分不清"是模拟器没发出去"还是"手柄没反应"时，先跑这个（SDL2 静态链接，双击即可，不需要模拟器）：

```
G:\KytyAddons\dualsense\probe_trigger.exe        # 默认 3 轮，可跟数字改轮数
```

它用**和模拟器同一套**发送代码与字节转换，先震马达 1.2 秒（证明 HID 输出通路本身是通的），
然后依次给 R2、L2 发 `feedback`（20% 处一堵墙）/ `weapon`（20%→70% 递增阻力）/ `vibration`（30% 起嗡嗡）/ `off`，
每一步打印 `send=0 (ok)` 与否以及那 11 个字节。**R2/L2 有明确变化 ⇒ 主机侧没问题**，只差游戏发请求。

### 一个订正

我先前说 `PadGetControllerInformation` 里的 `device_class = 0` 应该是 1 —— **这是错的**。
`SCE_PAD_DEVICE_CLASS_STANDARD` 就是 **0**（`libPad.cpp` 里 `PadDeviceClassParseData` 的注释也这么写），
所以那一处不用改。

### 检测代码怎么保留

补丁在 **`dualsense\trigger-probe.patch`**（对 `src-active` 的 HEAD 导出，三个文件：
`src\libs\controller.cpp`、`src\libs\libPad.cpp`、`src\graphics\presentation\window\window.cpp`）。

> ⚠️ `rebuild.ps1` 会先从源码包**同步上游文件**进 `src-active`，`controller.cpp` / `libPad.cpp` 会被覆盖，
> 探针就没了。升级版本后想留着它，在 `rebuild.ps1` 跑完后、编译前手工 `git apply` 一次：
> ```
> git -C G:\kyty-build\src-active apply --ignore-whitespace G:\KytyAddons\dualsense\trigger-probe.patch
> ```
> 只想编探针版（不动上游源码、不重新下载源码包）就用 **`G:\kyty-build\build-probe.ps1`**：
> 它直接 `ninja`，编完校验 exe 里那几个字符串，再备份旧 exe 并安装到发布目录。

---

## 二、为什么金手指不用编译，手柄要编译

| 功能 | 实现方式 | 更新时 |
|---|---|---|
| 金手指 | `cheats\*.json`（etaHEN/GoldHEN 的 mods 格式）+ 启动器传给 `kyty_emulator.exe --game-patch` | 复制文件即可 |
| DualSense 触觉（整合包这份） | 模拟器内部把**手柄喇叭的音频流**接到触觉马达上 | 必须重新编译 |
| DualSense 触觉（1016 官方自带） | 上游自己实现的 WASAPI 版，直接开手柄的 USB 音频端点 | 官方版本自带，什么都不用做 |

手柄部分没法做成外挂 DLL，原因有两条，都是硬性的：

1. **SDL2 是静态链接进 exe 的**（目录里没有 `SDL2.dll`），没法用替换/拦截 DLL 的方式改行为
2. 触觉信号来自**模拟器内部的音频混音通路**（`audio.cpp` 里 pad speaker 端口的 PCM），外部程序拿不到这份数据

不过有一点值得知道：**官方版本本身就带基础震动**（`SDL_GameControllerRumble` + 对 PS5 手柄的 `SDL_GameControllerSendEffect`）。我加的是更上面一层——把手柄喇叭的音频转成触觉，震动更有层次。所以如果你只是要"手柄会震"，新版本不编译其实也震；要的是原来那套音频驱动触觉，才需要跑 `rebuild.cmd`。

### 2026-10-16 的重要变化：官方自己做了

`v20261016` 的源码里**多了一份上游自己的触觉实现** `src\libs\dualSenseHaptics.cpp`（633 行），
它和整合包这份（`dualsense\dualSenseHaptics.cpp`，605 行）是**两套完全不同的实现**：

| | 整合包这份 | 1016 官方自带 |
|---|---|---|
| 后端 | SDL2（`SDL_OpenAudioDevice`） | WASAPI（`IAudioClient` / `IAudioRenderClient`） |
| 匹配设备 | 按设备名 + hash 找 | 按 USB 接口路径 `VID_054C&PID_0CE6` 找 |
| 日志标记 | `DualSenseHaptics` | `KYTY_DUALSENSE_HAPTICS`（环境变量） |
| 可调项 | — | `KYTY_DUALSENSE_HAPTICS` / `_CHANNELS` / `_GAIN` / `_SPEAKER_GAIN` / `_ALL_CHANNELS` 等，配置写 `dualsense-haptics.txt` |
| 增益 | 单一通路 | 喇叭与马达**分开**给增益，喇叭默认 8.0 |

实测 `v20261016` 的 `kyty_emulator.exe` 里 `KYTY_DUALSENSE_HAPTICS`、`KYTY_DUALSENSE_SPEAKER_GAIN`、
`WASAPI` 全部命中，`DualSenseHaptics` **不命中** —— 也就是说官方那份是**在它自己源码里编译进去的**，
不是抄整合包这份。

### 结论：1016 上换成整合包这份 SDL2 后端

**做法：保留官方的接口，换掉实现层。**

一开始想按老路子「改 `audio.cpp` 的调用点」，查了才发现不可行：1016 的 `audio.cpp` 是一套
**路由共享单流**的架构（`Available()` / `Open(bool speaker)` / `SpeakerActive()` / `Close(bool)`），
和 addon 那套**每端口一条流**的 API（`Open(freq,speaker)` / `Queue(stream,…)` / `SetVibration` /
`Shutdown`）完全不兼容。硬改调用点等于把上游 1016 的新架构**退回旧版**，是明显的倒退。

所以改成：**`dualsense-v20261016.patch` 只替换 `src\libs\dualSenseHaptics.cpp/.h` 两个文件**，
用 SDL2 重新实现官方那套接口。好处是 **`audio.cpp`、`controller.cpp`、`controller.h` 一行都不用改**，
上游的架构、回声抑制（`SpeakerActive()`）全部保留，而设备发现与音频通路仍然是 addon 的 SDL2 那套
（按设备名找四声道端点 → `SDL_OpenAudioDevice` → `SDL_QueueAudio`，并且用
`SDL_GameControllerSendEffect` 把右声道路由到手柄喇叭、静音耳机）。

| | 现在编译进去的（SDL2 后端） | 1016 官方自带（WASAPI） |
|---|---|---|
| 后端 | SDL2（`SDL_OpenAudioDevice`） | WASAPI（`IAudioClient` / `IAudioRenderClient`） |
| 匹配设备 | 按设备名找四声道端点 | 按 USB 接口路径 `VID_054C&PID_0CE6` 找 |
| 喇叭路由 | `SDL_GameControllerSendEffect` 报 0x02（右声道→喇叭、耳机静音） | 端点通道对 |
| 数字增益 | 喇叭 ×8（+18 dB，与官方同值）、马达 ×1，两者都能用环境变量调 | 喇叭默认 ×8（+18 dB） |
| 配置开关 | `KYTY_DUALSENSE_HAPTICS=0` 关、`..._LOG=1` 打日志、`KYTY_DUALSENSE_SPEAKER_GAIN` / `KYTY_DUALSENSE_HAPTICS_GAIN` 调增益 | 五个环境变量 + `dualsense-haptics.txt` |

相应改的地方：

* `rebuild.ps1`：源码里已有 `src\libs\dualSenseHaptics.cpp`（1016+）→ 打 **`dualsense-v20261016.patch`**；
  老版本没有这个文件 → 仍打原来的 `dualsense.patch`
* 产物校验也变严了：新版**必须**命中 `DualSenseHaptics`。只命中 `KYTY_DUALSENSE_HAPTICS` 说明
  **替换没成功、退回官方那份了**，直接判失败（两个实现都带这个环境变量名，单看它分不出来）
* `install.cmd`：只装金手指/启动器，**不碰 exe**（exe 由 `rebuild.cmd` 生成），
  并在提示里说明这一版官方自带触觉

### 2026-10-16 第二次改：修掉喇叭的杂音

换成 SDL2 后端之后，喇叭出声时有杂音（官方 WASAPI 那版没有）。根因是**每次 `Write()` 都单独排一个块**：

`audio.cpp` 是把**手柄喇叭端口**和**振动端口**分成**两次调用**丢进来的（各一次 `Write()`），
而当时的实现每次调用都自己拼一个完整的**四声道**块、立刻 `SDL_QueueAudio` 排进去，
**没填的那一路声道补 0**。于是两路都在出声时，同一个混音周期里会排进**两个**块：
喇叭那一对声道前半块有声音、后半块是 0，振动的后一对反过来 ——
端点拿到的音频等于**实时长度的两倍**，而且每段都被另一路的静音段切断。
听感就是"劈啪 / 断续"的杂音。

修法：**两路先凑进同一个四声道块再排。** 具体是

* 用一个"待排块" `g_pending` 存住当前块；`Write()` 只把**自己那一路**填进去并做标记；
* 只有**两路都到齐**，或者下一块的标记显示这是新一轮时，才真正 `SDL_QueueAudio`；
* 队列落后（超过 `MAX_QUEUE_MS`，现提到 **100 ms**，与官方一致）时**整块丢掉**，
  而不是从队首挖掉一截 —— 挖一截会把波形切在半个采样上，那本身也是"咔"的一声。

另外把增益也对齐官方：喇叭路 ×8（`KYTY_DUALSENSE_SPEAKER_GAIN`，范围 0..64）、
马达路 ×1（`KYTY_DUALSENSE_HAPTICS_GAIN`，范围 0..4），写回端点前钳到 ±1.0，避免浮点超幅削顶。
**这两个值现在在启动器里能直接调**（勾选 + 百分比），见上面「一之五、手柄音量」。

> 想确认这条通路真的在跑：设 `KYTY_DUALSENSE_HAPTICS_LOG=1` 再进游戏，
> 控制台会打出设备名和每一路的状态（`DualSense speaker audio: …`）。
> 不设这个变量时**一句都不打**，日志里看不到任何 `DualSense` 字样是正常的。

### 顺带修掉的一个坑：PGO 换了却没人重编译

第一次编译直接链接失败：

```
lld-link: error: linking module flags 'ProfileSummary': IDs have conflicting values
```

原因是 **cmake 只记 `kyty.profdata` 的路径、不记内容**。上游每个版本会带一份新的
`tools\pgo\kyty.profdata`，同步进来之后 ninja 根本不知道编译选项变了，于是**旧对象用新 profile、
老对象用老 profile**，链接器一比对 ProfileSummary 就报冲突。当时 725 个对象里有 611 个是过期的。

修法：把 profile 的 **SHA-256 前 16 位写进编译宏**（`/DKYTY_PGO_PROFILE=<hash>`，宏本身没人读），
`CMakeCache.txt` 旁边存一份 `pgo.hash`。profile 一换，所有命令行都变，ninja 自然全量重编；
同时打印一行 `the PGO profile changed (…) : every object is rebuilt from it`。
**你以后跑 `rebuild.cmd` 换版本时不会再撞这个错。**

---

## 三、目录内容

```
KytyAddons\
  install.cmd            双击安装（金手指部分）
  install.ps1            安装逻辑（可 -Target 指定目录）
  launcher.ps1           启动器（官方全部选项 + Mods 分组：金手指 / 倾向 / 调试 / 手柄音量）
  cheats\                金手指文件（etaHEN mods json）
    PPSA01341_01.007.000.json
    README.md
    verify_cheat.py
  dualsense\
    kyty_emulator-haptics-v20261013.exe   已编译好的带触觉 exe（SDL2 版，版本对得上就直接替上）
    kyty_emulator-haptics-v20261014.exe   同上，1014 版（支持 HDR + 触觉）
    rebuild.cmd          双击重编译（一键：下载源码 → 打补丁 → 编译 → 安装）
    rebuild.ps1
    dualsense.patch         旧补丁，用于 1016 以前的版本（audio.cpp / controller.cpp / controller.h + 两个新文件）
    dualSenseHaptics.cpp    老 API 的 SDL2 实现（补丁失败时的兜底源文件）
    dualSenseHaptics.h
    dualsense-v20261016.patch  1016+ 用的补丁：只替换 libs 下那两个文件，接口保持官方那套
    v20261016\
      dualSenseHaptics.cpp  官方 API + SDL2 后端（补丁失败时的兜底源文件）
      dualSenseHaptics.h
```

---

## 四、启动器对版本的容错

`launcher.ps1` 会先读一遍同目录的 `run-windows.ps1`，**只传这一版确实声明了的参数**。
比如某个未来版本去掉了 `-RenderHeight` 或 `-Patch`，启动器会自动不传、并在界面上标注，不会因为参数不存在而启动失败。

---

## 五、编译脚本做了什么（`dualsense\rebuild.ps1`）

1. 读版本号（如 `v20261013`）：优先用 `kyty_emulator.exe --help` 打印的 `git = …`，读不到再退回用目录名推
   （**`v20261016` 没有 `--version` 参数**，传了只会打印 `missing value for --version`）
2. 从 codeload 下载该 tag 的源码
3. **按内容哈希同步**到固定目录 `G:\kyty-build\src-active`——没变的文件不重写，时间戳保留，所以 ninja 能跳过它们
4. 补上 codeload 包里缺失的子模块（复用已有缓存，各子模块 pin 一直没变）
5. 打补丁（失败时依次尝试 3-way、低上下文匹配，再失败就用兜底源文件）：
   - 源码里**已有** `src\libs\dualSenseHaptics.cpp`（1016+，官方自带触觉）→ 打
     **`dualsense-v20261016.patch`**，它只替换 `src\libs\dualSenseHaptics.cpp/.h`，
     接口保持官方那套，所以 `audio.cpp` / `controller.cpp` 一行都不改
   - 源码里**没有**这个文件（1013 / 1014）→ 打原来的 **`dualsense.patch`**，由它加文件并改调用点
   - 3-way 合并即使最后失败也会把带冲突标记的半成品写进树里，所以每次失败后脚本会先
     `git checkout -- .` 把被跟踪的文件还原，再试下一种方式
6. cmake + ninja 编译到固定目录 `G:\kyty-build\out-addons`
   - **PGO profile 换过就全量重编**（见第二节末尾）。cmake 只记 profile 的路径不记内容，
     脚本把它的 SHA-256 前 16 位写进编译宏，profile 一换 ninja 就发现命令行变了，
     不会留下"新老对象混编 → 链接报 ProfileSummary 冲突"
7. 校验产物：先看有没有触觉标记，再把 `kyty_emulator.exe` 备份后覆盖过去
   - 1016+（换实现层）**必须**命中 `DualSenseHaptics`；只命中 `KYTY_DUALSENSE_HAPTICS`
     说明替换没成功、退回官方那份了，直接判失败
   - 老版本两个标记命中任意一个即可

可选参数：

```
.\rebuild.ps1 -Target G:\KytyPS5-v20261014 -Version v20261014   # 指定目录和版本
.\rebuild.ps1 -NoInstall                                        # 只编译不安装
.\rebuild.ps1 -BuildRoot D:\kyty-build -DepsCache D:\...\3rdparty
.\rebuild.ps1 -Tarball D:\downloads\cx-v20261014.tar.gz         # 用本地源码包（断网/下载失败时）
```

> ⚠️ **改了 `dualsense\v20261016\dualSenseHaptics.*` 之后，必须重新导出补丁。**
> `rebuild.ps1` 每次都会把上游源码同步进 `src-active`（那两个文件因此被**覆盖回官方版**），
> 真正生效的是**补丁**；`v20261016\` 里的源文件只在"补丁打不上"时当兜底。
> 所以只改源文件不导补丁，下一次编译就会**静默地编译成官方 WASAPI 版**。
>
> 导出步骤（`<上游提交>` = `git -C G:\kyty-build\src-active log --oneline` 里**最新的**那条
> `upstream v20261016`，正常情况下就是 `HEAD~1`；同名的可能有几条，取最新的那条）：
>
> ```
> copy /y G:\KytyAddons\dualsense\v20261016\dualSenseHaptics.cpp G:\kyty-build\src-active\src\libs\
> copy /y G:\KytyAddons\dualsense\v20261016\dualSenseHaptics.h   G:\kyty-build\src-active\src\libs\
> git -C G:\kyty-build\src-active diff <上游提交> -- src/libs/dualSenseHaptics.cpp src/libs/dualSenseHaptics.h > G:\KytyAddons\dualsense\dualsense-v20261016.patch
> ```
>
> 导完务必验一次"补丁能干净打回上游"：
>
> ```
> git -C G:\kyty-build\src-active show <上游提交>:src/libs/dualSenseHaptics.cpp > ...\src\libs\dualSenseHaptics.cpp
> git -C G:\kyty-build\src-active show <上游提交>:src/libs/dualSenseHaptics.h   > ...\src\libs\dualSenseHaptics.h
> git -C G:\kyty-build\src-active apply --check G:\KytyAddons\dualsense\dualsense-v20261016.patch   # 无输出即 OK
> git -C G:\kyty-build\src-active apply         G:\KytyAddons\dualsense\dualsense-v20261016.patch
> ```
>
> 最后一步的 `apply` 不能省：`apply --check` 不改文件，走完上面这套源码文件才回到新实现。

codeload 偶尔会中途掐断连接（`curl: (56) schannel`）。脚本已带 `--retry-all-errors`，
失败的半成品会自动删除（不会留下一个坏包被下次误用）。如果反复失败，就手动在浏览器里打开

```
https://codeload.github.com/chenxiao07/KytyPS5/tar.gz/<版本号>
```

下载后用 `-Tarball` 指过去即可。

编译产物目录 `G:\kyty-build`（约 1 GB）可以删，删了下次就是完整重编。

---

## 六、已实测（2026-10-13，对 v20261013 跑完整流程）

```
sync into src-active      source: 3 copied          <- 第二次跑，只同步了 3 个文件
patch applied             --3way --ignore-whitespace
cmake configure           Configuring done (279.9s)
ninja                     [815/816] Linking CXX executable kyty_emulator.exe
built                     22,139,392 bytes, git = v20261013
```

产物里 `DualSenseHaptics`、`DualSense stream` 均命中，与手工编译安装的版本一致。
`G:\kyty-build\out-addons` 这个编译缓存已建好，下次换版本从这里增量。

耗时参考：首次（含下载、cmake 配置）约 25 分钟；已有缓存后只重编改动文件，通常几分钟。

### 2026-10-14 对 v20261014（增量 3 分 42 秒）

```
download: codeload chenxiao07/KytyPS5 v20261014
downloaded: 16,212,864 bytes
sync into src-active      source: 73 copied, 0 skipped   <- 1013→1014 改了 73 个文件
patch applied             --3way --ignore-whitespace
ninja                     [719/722] Linking CXX executable kyty_emulator.exe
built                     22,315,008 bytes, git = v20261014
installed                 G:\KytyPS5-v20261014\kyty_emulator.exe
```

**注意**：1014 换了编译器/链接器，产物 22,315,008 B（1013 是 22,140,416 B），但版本字符串正确，
`DualSenseHaptics`、`DualSense stream`、`--hdr` 三个标记全部命中，所以它同时满足触觉和 HDR。

编译产物已收进整合包 `dualsense\kyty_emulator-haptics-v20261014.exe`，
以后装 v20261014 直接 `install.cmd` 即可，不用再跑 `rebuild.cmd`。

### 2026-10-16 对 v20261016（金手指 + 启动器 + **重编译换触觉**）

先只装金手指和启动器（不碰 exe），再重编译把触觉后端换成整合包这份：

```
copied: launcher.ps1
copied: cheats\
cheats: PPSA01341_01.007.000.json (6 mods)
run-windows.ps1 has -Patch: the cheats will be applied
haptics: kyty_emulator.exe has the addon SDL2 DualSense backend
```

重编译（3 分 45 秒，全量重编，因为 PGO profile 换了）：

```
the release ships its own DualSense haptics: swapping in the addon's SDL2 backend
patch applied (--ignore-whitespace)
the PGO profile changed ( -> 53BC9E16AEB377A2): every object is rebuilt from it
ninja                     [719/720] Linking CXX executable kyty_emulator.exe
built                     G:\kyty-build\out-addons\kyty_emulator.exe (22,158,336 bytes)
haptics in it:            the addon's SDL2 port (DualSenseHaptics)
installed                 G:\KytyPS5-v20261016\kyty_emulator.exe (the old one is in _Backup)
```

产物校验（对 `G:\KytyPS5-v20261016\kyty_emulator.exe`，22,158,336 B，MD5
`38f035e192d7b82f11f7a284f2903cb0` —— 下面是**第二次重编译后**的结果）：

| 标记 | 官方原件 | 现在这份 |
|---|---|---|
| `DualSenseHaptics`（addon SDL2 后端） | 0 | **3** |
| `KYTY_DUALSENSE_HAPTICS`（环境变量开关，两者都有） | 1 | 3 |
| `KYTY_DUALSENSE_SPEAKER_GAIN`（增益开关，现在这份也读它） | 1 | 1 |
| `IAudioClient`（WASAPI） | 2 | **0** |
| `DualSense audio endpoint by name`（SDL2 找设备的那句） | 0 | 1 |

也就是说官方的 WASAPI 实现**已经被完整替换掉**，不是两份共存。

官方原件留在 `_Backup\kyty_emulator.exe.orig-official` 与 `_Backup\kyty_emulator.exe.bak-20261016-143913`
（都是 22,389,760 B，MD5 `553F0981CDB1103D0B1C8CB56A830B9A`），随时可以回退。

### 2026-10-16 第二次重编译（增量 1 分 21 秒，修喇叭杂音）

```
target:  G:\KytyPS5-v20261016
patch applied (--ignore-whitespace)
ninja                     [11/11] Linking CXX executable kyty_emulator.exe
built                     G:\kyty-build\out-addons\kyty_emulator.exe (22,158,336 bytes)
haptics in it:            the addon's SDL2 port (DualSenseHaptics)
installed                 G:\KytyPS5-v20261016\kyty_emulator.exe (the old one is in _Backup)
```

这次只改了 `dualSenseHaptics.cpp/.h` 两个文件，所以 ninja 只跑了 11 步（PGO profile 没变，
`pgo.hash` 起了作用，不必全量重编）。上一份 SDL2 产物被自动备份成
`_Backup\kyty_emulator.exe.bak-20261016-155540`（MD5 `1d190b75e214f5a5a73691defda874b4`），
想换回"有杂音"的那一版直接拿它替回去即可。

同时修掉了这四处（细节见各自小节）：

| 现象 | 根因 | 修在哪 |
|---|---|---|
| 最大魂量不生效 | 旧金手指打的 `0x20358C` / `0x203593` 与魂量毫无关系（只是把常量 256 写进别的字段） | `cheats\PPSA01341_01.007.000.json` 改打 `AddSouls` @ `0x4561E0` |
| 手柄喇叭有杂音 | 每次 `Write()` 单独排一个四声道块、两路各排一次，另一路声道补 0 → 2× 速率 + 互相切断 | `dualsense\v20261016\dualSenseHaptics.cpp`（待排块 + 增益对齐官方） |
| 选完倾向点启动器闪退、之后再也打不开 | `NumericUpDown` 的 `Value` 早于 `Maximum` 生效，且坏值已存进 `launcher-settings.json` | `launcher.ps1`（`New-TendencyBox` + 全局 `trap`） |
| 倾向数值进游戏不显示 | 只设了环境变量，而 `run-windows.ps1` 不读进程环境，值被它自己的默认值覆盖 | `launcher.ps1` 改用 `-Set "KYTY_GAME_CONVARS=…"` |
| 人物倾向填 200 / 40 都毫无变化（**根因**） | 那 14 个 `cp11_tendency_*` convar **不是游戏读的值**，只是调试菜单的视图；游戏从**存档**里按名字哈希取 float | `launcher.ps1` 新增 `Write-TendencyToSave`，改 `_SaveData\…\SAVEDATA0PlayerProfile*\USR-DATA` 里的 `Tendency_Player_BlackWhite` / `_LeftRight`，并重算 FNV-1a 校验 |
| 量程头两轮认错 | 先说 ±200 没证据、后说 0~1 也是错的。存档里的真实数据（-180 / +120）与注册时交给引擎的 `+200.0f` / `-200.0f` 都指向 **±200、中性 0** | `launcher.ps1`（`ConvertTo-TendencyNumber` / -200~200 数字框） |
| 勾了"显示倾向数值"也不显示 | 布尔写法错了：引擎只认 `=true`/`=false`，`=1` 不生效（游戏自己的 `dsshortcutbuttons.xml` 写的就是 `cp11_toggleDebugMenu = true`） | `launcher.ps1`（全部改成 `=true`） |
| 倾向数字框里填什么取到的都是 0 或 1 | `[Math]::Max(0, [Math]::Min(1, $x))` 选中了 `[Math]::Min(Int32, Int32)` 重载，把小数截断 | `launcher.ps1` 改用 `0.0` / `1.0` 浮点字面量 |

构建树 `G:\kyty-build\src-active` 现在是 `v20261016` + 整合包补丁（`git describe` 报 `v20261016`），
以后重编译从这里增量；`pgo.hash` 已写下当前 profile 的哈希，profile 没变时下次只重编改动文件。

> 小坑：`v20261016` 的 `kyty_emulator.exe` **没有 `--version` 这个参数**
> （传了会打印 `missing value for --version`）。版本横幅是 `--help` 打出来的第一行
> （`ver = 0.3.0, git = v20261016, date = 2026.10.16`）。`install.ps1` / `rebuild.ps1` 已改成读
> `--help`，读不到再退回用目录名推（`KytyPS5-v20261016` → `v20261016`）。

## 七、注意事项

- 安装/编译前请**先关掉模拟器**，exe 被占用会复制失败
- 每次安装都会在模拟器目录的 `_Backup\` 留一份备份，可以放心回退
- **别把 `install.ps1` 的内部变量写成和参数同名**（PowerShell 变量名不区分大小写）。脚本里原本有个
  `$tarball`（默认源码包路径）撞上了 `-Tarball` 参数，导致"版本源码还没下载"时被误判成
  "用户指定了本地包"而直接退出；已改名 `$archive`。以后加参数时留意这类重名。
- 补丁分两套，别搞混：`dualsense.patch`（1013 / 1014 用）改动 `audio.cpp` / `controller.cpp` / `controller.h`
  并新增文件；`dualsense-v20261016.patch`（1016+ 用）**只替换 `src\libs\dualSenseHaptics.cpp/.h`**，
  不碰 `audio.cpp`。官方只要没动这两个文件，补丁就一直好使；万一 `git apply` 失败，脚本会依次降级尝试，
  仍失败就用 `v20261016\` 里的源文件直接覆盖（所以源文件和补丁**要保持一致**，见第五节的导出步骤）
- 子模块（ffmpeg、SDL2、LibAtrac9 等）版本目前与 1013 一致，若上游升级了子模块，`rebuild.ps1` 里缓存的那份会不匹配，需要重新拉取

## 八、v20261019 移植记录（2026-10-19）

上游隔了一版（1018）连发了 1019，这一版改动比上次大得多。

### 补丁：不用重做

| 文件 | 1017 → 1019 | 结论 |
|---|---|---|
| `src/libs/dualSenseHaptics.cpp` / `.h` | **字节未变** | 补丁原样可用 |
| `src/libs/audio.cpp` | 103,746 → 107,181 | 官方新增 `KYTY_AUDIO_CUSHION_MS` 等诊断，与补丁无交集 |
| `src/libs/controller.cpp` | 27,476 → 27,800 | `Disconnect()` 改成"找不到就返回"（issue #49），与补丁无交集 |
| `controller.h` / `gamePatch.cpp` | 字节未变 | — |

`git apply --check` 对 1019 源码一次通过。

### 启动器：三方合并，不是手工抄

官方启动器从 353 行涨到 489 行，新增（都在，一行没丢）：

- `$resolutionsByRatio`：分辨率按 16:9 / 21:9 / 32:9 分组，宽高比与分辨率联动
- `$renderHeights` 多了 2160 / 1800 / 1620 / 1512，并由 `Get-MaxRenderHeight` 按 tile 用量算出上限
- `$upscalers`（Game / DLSS）+ `$rtxGpu` 检测 + `render_dlss`（两套上采样各记各的渲染高度）
- `$safeGpuTip` / `safegpu` → `KYTY_COMPUTE_CHAIN=0`
- `$cmd` / `$powershellCommand` 全路径（issue #47 / #55），`-Set` 改成 `$sets` 累加

合并做法（可复用）：临时 git 仓库 → 提交 1017 上游 → 提交"我们的 1017 版" → 用 `git diff`（带 `index`
行才有 3-way）生成上游补丁 → `git apply -3`。冲突只有 5 处（`$settings`、`Get-PlayCommand`、DryRun 行、
界面渲染块、`Read-Form`），逐个手工合。**关键是我们的 `-Set` 累加要并进官方的 `$sets`**，否则
`KYTY_COMPUTE_CHAIN` 和手柄增益会各发一个 `-Set`，后者覆盖前者。

### 构建

`pgo.hash` 变了（`53BC9E16…` → `ED1A61AF…`）⇒ 官方换了 PGO profile，**全部 727 个对象重编**，约 5 分钟。

### 验证（本次）

- exe：`git = v20261019`，23,198,208 字节；`DualSenseHaptics` / `KYTY_DUALSENSE_HAPTICS` / `SDL_QueueAudio`
  在、`IAudioClient` = 0（SDL2 后端生效）；`KYTY_COMPUTE_CHAIN` / `KYTY_AUDIO_CUSHION_MS` 也在（官方新功能保留）
- 与官方 exe 对比 `--help`：**35 行完全一致**，只有文件名不同
- 启动器：官方 17 个界面行、20 个设置键**一个不缺**，我们的键全部是额外的
- 界面探针：Resolution / Aspect ratio / Render height / Upscaler 四行都在；宽高比切 21:9 时分辨率换成
  2560x1080…，渲染高度上限自动降到 1800（21:9 装不下 2160）；非 RTX 机器 Upscaler 置灰
- 金手指：`verify_cheat.py` 4/4 通过
- 设置迁移：旧 29 键原样搬过来，`cheatFile` 指向新目录；DryRun 输出
  `World05=200` / `World02=0` / 喇叭增益 1.2（15 %）/ 震动 1（100 %）
