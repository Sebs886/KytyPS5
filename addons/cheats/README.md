# 金手指（Cheats）

这个文件夹放 Demon's Souls（PPSA01341）的金手指文件，由启动器 `launcher.cmd` 的
**Cheats (金手指)** 勾选框决定是否加载。

当前文件 `PPSA01341_01.007.000.json` 共 **6 条**，默认开启 **4 条**：
Max Souls (999,999,999) / Infinite HP / Infinite Stamina / Infinite MP。
另外 2 条（Player Never Dies、One Hit Kill）默认 `"enabled": false`。

> **2026-10-16 起是 6 条而不是 7 条**：原来的 `Max Souls` 与 `No Souls Loss On Death`
> 被**合并成一条** —— 这两条本来就是同一件事（"魂不减少"），而且旧的那对地址
> 根本碰不到魂量（详见 1.1 节）。

**每一条金手指在启动器里都有独立开关**（见 0.1 节），不用再手改 JSON 文件。
开关本身在启动器界面的 **`Mods` 分组框**里（`Cheats` 总开关 → 文件下拉框 → 下面的逐条勾选框），
同组下面还有 KytyAddons 自己的那几项（倾向、调试、手柄音量）—— 见主 README 的"一之四"节。

> **已安装位置**：`G:\KytyPS5-v20261014` 与 `G:\KytyPS5-v20261016`。
> 各自的 `launcher-settings.json` 里 `cheatFile` 指向自己目录下的这份金手指。
> 换模拟器版本只用整份 `cheats` 文件夹复制过去即可。

---

## 0. 快速开始

```
双击 launcher.cmd  ->  勾 Cheats (金手指)  ->  下拉框选 PPSA01341_01.007.000.json  ->  Play
```

设置记在 `launcher-settings.json`（`cheats` / `cheatFile` / `modStates`）。命令行等价写法：

```
run.cmd -Patch "cheats\PPSA01341_01.007.000.json"
```

### 0.1 逐条开关

勾上 **Cheats** 后，启动器 `Mods` 分组框里会把选中文件里的每一条金手指列成一个勾选框。
这一块**没有行标签**，直接接在 `Cheats` 那一行下面、与 `[ Select all ]` 左对齐：

```
┌ Mods ───────────────────────────────────────────────────────────────────────┐
│ Cheats        [x]  [PPSA01341_01.007.000.json                 ]             │
│               [x] Max Souls (999,999,999)                                   │
│               [x] Infinite HP  (Player - No Damage)                         │
│               [ ] Player Never Dies (revive)                                │
│               [x] Infinite Stamina (Player - No Stamina Consume)            │
│               [x] Infinite MP                                               │
│               [ ] One Hit Kill (experimental)                               │
│               [ ] Debug menu: open in game (experimental)                   │
│               [ ] Dev build flags: RetailBuild off (experimental)           │
│               [ Select all ] [ Select none ]   4 of 8 on                    │
│ ...（倾向、调试读数 / 调试菜单、手柄喇叭 / 震动）                           │
└─────────────────────────────────────────────────────────────────────────────┘
```

* 鼠标悬停在任一条上会显示它的完整说明（`description`）。
* **Select all / Select none** 一键全开 / 全关；右边的 `x of 8 on` 实时显示开启条数。
* 不勾 **Cheats** 时**只有金手指这一块**置灰，等于不加载任何金手指；
  同组下面 KytyAddons 那几项不受影响（它们不依赖 cheat 文件）。
  （金手指那几条与 KytyAddons 那几项之间**没有分隔文字**，整块就是一条连续的列表 ——
  早先版本曾在中间插一行灰字 `KytyAddons options - ...`，2026-10-16 晚去掉了。）
* 每条的状态按**文件名 + 条目名**分别记忆在 `launcher-settings.json` 的 `modStates` 里，
  换金手指文件互不干扰；第一次打开某文件时，用文件自带的 `"enabled"` 作为初始值。
* **`cheats\` 里的 JSON 文件永远不被修改**：点 Play 时，启动器只在你改过默认值的情况下，
  按当前勾选生成一份副本到 `cheats\_session\` 交给模拟器；勾选和文件默认值一致时，
  直接沿用原文件（日志里也就不会出现 `_session` 路径）。

启动日志（`logs\*.out.log`）里应出现：

```
Game cheat: matched eboot.bin with source base 0x0
Successfully applied cheat: Max Souls (999,999,999)
Successfully applied cheat: Infinite HP  (Player - No Damage)
...（默认共 4 行，等于开启的条数）
```

只要看到 `source base 0x0` 和对应条数的 `Successfully applied cheat`，补丁就全部打上了
（条数应等于 Mods 列表里打勾的数量）。如果只看到 `Game cheat: waiting for the matching module`，
说明**一个字节都没打**（见第 4 节）。

---

## 1. 现有金手指一览

| # | 名称 | 机制（eboot RVA，括号内为 JSON 里的 `offset`） | 置信度 |
| --- | --- | --- | --- |
| 1 | Max Souls (999,999,999) | `0x4561E0`（`4561E0` / `456200` / `456203`）：把 `AddSouls()` 的钳位尾拆掉，存回的值**恒等于 999,999,999** | 已实锤 |
| 2 | Infinite HP (Player - No Damage) | `0x32D690`（`32D690`）的 `cmp [rax],1` + `jne` 改 `cmp [rax],1` + `nop nop`，强制游戏自带的 `cp11_characters_playerNoDamage` 生效 | 高 |
| 3 | Player Never Dies (revive) | `0x325979 / 0x32AE61 / 0x32D7B6 / 0x32FD1A` 四处同样 5 字节窗口改 NOP，强制 `cp11_characters_playerNoDead` | 高 |
| 4 | Infinite Stamina | `0x331A6F`（`331A6F`）的 `jne` 改 NOP，强制 `cp11_characters_playerNoStaminaConsume`；**外加 `0x3261FF`（`3261FF`）`lea ecx,[rax-1]` → `mov ecx,eax` + `nop`** | 高 |
| 5 | Infinite MP | `0x3259F2` + `0x3259FA`，让 `SetMp()` 永远写上限 | 中高 |
| 6 | One Hit Kill (experimental) | `0x32D6FD` 的 `sub esi,r12d` 改 `xor esi,esi`，伤害直接 `SetHp(0)` | 实验 |
| 7 | Debug menu: open in game (experimental) | `0xB2D893`（`B2D893`）把 `[[0x2F782D0]]==1` 这道闸门整体 NOP 掉；`0xB2D97E / 0xB2D983 / 0xB2D99F`（`4189C7 / 4520E7 / 4180F701`）三处改写 `r15b=1`，把调试菜单的开关字节钉死在 1 | 实验 |
| 8 | Dev build flags: RetailBuild off (experimental) | `0x816884`（`816884`）的 `call 0x8469c0; test [rax],2; sete al` 换成 `xor eax,eax` + NOP + 原跳转，让引擎的 `RetailBuild` 限定符恒为假，从而加载 `misc\DebugMenu.txt` | 实验 |

**推荐测试顺序**：先只开 1–5 进游戏确认血量/耐力/魔力都不掉、被打不死；
再单独开 6 确认一击必杀。若开 6 后自己也一碰就死，单独关掉 6 即可（说明该伤害路径
没走玩家豁免分支）。7 / 8 是调试菜单专用、默认关闭，见 1.2 节。

### 1.1 2026-10-16 修掉的两个 bug

这两个都是"看着像没生效"，根因都在模拟器**打补丁的方式**上，不在金手指的想法上。

**bug 1：最大魂量不起作用。**

**根因：旧金手指打的那两个地址和魂量毫无关系。** 把 `0x203593` 反汇编出来是

```
0x203593  41898d80000000   mov dword ptr [r13 + 0x80], ecx      ; 此处 ecx = 0x100
```

一段链表销毁代码把自己算出来的 **256** 写进某个对象的 `+0x80`。所以那条金手指
只是改坏了一个不相干的字段，魂量一个字节都没碰到 —— 进游戏当然毫无变化。
（当时给出的"被后面的 `No Souls Loss On Death` 覆盖了"那个诊断也是错的，
`0x3B9ACA00` / `0x2500A44` 是 999999999 之类的说法同样站不住。）

真正的魂量在这里（`PlayerStatus*` 从对象 `+0x828` 取，`0x37A950` 开头就是
`cmp qword ptr [r14 + 0x828], 0` → `mov rdi, qword ptr [r14 + 0x828]`）：

| 用途 | 偏移 | 佐证 |
| --- | --- | --- |
| 携带魂量（现在的魂） | `+0x80`，**int32** | 游戏自己的 `cp11_setSouls [souls]` / `cp11_addSouls [souls]` 写的就是它 |
| 累计魂量（总魂） | `+0x88`，**qword** | 对应 `cp11_setCumulativeSouls` |

所有魂量变化 —— 打怪掉魂、捡魂、买东西、升级扣魂、读档恢复 —— 都只走**同一个**例程：

```
AddSouls(player, delta)   @ RVA 0x4561E0
  0x4561E7  448bb780000000   mov r14d, [rdi + 0x80]        ; old
  0x4561EE  baffc99a3b       mov edx, 0x3b9ac9ff           ; 上限 999,999,999
  0x4561F6  418d0c36         lea ecx, [r14 + rsi]          ; new = old + delta
  0x4561FA  81f9ffc99a3b     cmp ecx, 0x3b9ac9ff
  0x456200  0f42d1           cmovb edx, ecx                ; edx = min(new, 上限)
  0x456203  31c0             xor eax, eax
  0x456205  85c9             test ecx, ecx
  0x456207  0f49c2           cmovns eax, edx               ; new < 0 时保持 0
  0x45620A  898780000000     mov [rdi + 0x80], eax         ; 存回
```

也就是 `存回 = clamp(old + delta, 0, 999999999)`。全库**只有 5 个调用点**，
恰好覆盖上述每一类变化：

| 调用点 | 传入的 delta |
| --- | --- |
| `0x37A925` | 正数（掉魂量 × 倍率，`vmulss` / `vcvttss2si` 算出来的） |
| `0x37A97C` | 正数 |
| `0x37B065` | 正数 |
| `0x37B0DE` | `neg r14d`，**负数 = 扣魂**（买东西 / 升级） |
| `0x648C80` | `[PlayerStatus+0x80] - [obj+0x240]`，把魂"设成"一个存着的值 |

修法：把**两个**条件都拆掉，让存回去的值恒等于上限。

| 地址 | 原字节 | 改为 | 作用 |
| --- | --- | --- | --- |
| `0x456200` | `0F42D1` | `909090` | `cmovb` 变 NOP，`edx` 不再被改写，一直是 999,999,999 |
| `0x456203` | `31C0` | `89D0` | `xor eax,eax` 变 `mov eax,edx`，`eax` 也拿到上限 |

> ⚠️ **两条缺一不可。** 只改第一条的话：`edx` 固然是上限，但紧跟的 `xor eax,eax`
> 又把结果清成 0，而 `cmovns` 只在 `new >= 0` 时才把 `edx` 搬进 `eax` ——
> 于是**扣魂（负 delta）时魂被清成 0**，一买东西就掉光。

> 合并成一条 mod 仍然正确（两条本来就重复，且扁平表里重叠时后写的赢），
> 但这次修好的原因是**地址对了**，不是"不重叠了"。

> 仍未实证的一点：**死亡掉魂**是否也走 `AddSouls`。上面 5 个调用点里没有明显的
> 死亡/血迹流程，所以那一支有可能是**直接写** `[PlayerStatus+0x80]`（全库这类
> `mov dword ptr [reg+0x80], ...` 有 1000+ 处，没法靠静态反汇编筛出来）。
> 若实测"死一次魂就归零"，就用游戏自己的开关关掉掉魂：
> `cp11_allowSoulDrop=0`（启动器的 `-Set` 能传 convar，见主 README）。

**bug 2：Infinite Stamina 在跑动时不起作用。**

游戏有**两处**不相干的扣耐力代码，只有一处看 `cp11_characters_playerNoStaminaConsume`
开关（`0x331A68`，老金手指打的就是这里）。**跑/冲刺的扣耐力在另一条路径上**，位于
每帧例程 `0x325FF0` 开头，`0x3261FF` 是 `lea ecx,[rax-1]`（每 0.1 秒扣 1 点），
它**不查任何开关**。修法：新增一条写入 `3261FF: 8D48FF → 89C190`，
把"减 1"改成"原值"，这条路径也就不扣了。

---

### 1.2 2026-10-16：调试菜单（"游戏中按哪个键"= 没有键）

**问题**：进游戏按不出调试页，也不知道按哪个键。

**结论：这个版本没有任何键能开它，手柄也不行。** 三条独立证据：

1. **游戏里唯一的绑定是主机版快捷菜单。** `misc\dsshortcutbuttons.xml` 里那条
   `<name>Toggle OG Debug Menu</name>` / `<command>cp11_toggleDebugMenu = true</command>`
   是给 PS5 系统级快捷菜单用的，Kyty 没有这个概念；文件里其余条目全是
   `UI Tests/…` 的自动化脚本（`Tendency 1/2`、`HUD`、`Inventory 1/2`…），也不是按键。
2. **模拟器的键位表里没有调试键。** 见发布目录 `README.md` 的 `## Controls`：
   `W A S D` / `T F G H` / `J L K I` / `Q E` / `Left Shift`+`Left Ctrl` / 方向键 /
   `Enter`(OPTIONS) / `Backspace`+`Tab`(触摸板两半) / `F7` / `Space` / `F11` /
   `F9`+`F10`+`F8`（调试传送）。**键盘连 L2 / R2 都没有**，所以组合键也凑不出来。
3. **真正的原因：那一整段代码是死代码。** 每帧都会调用调试输入例程
   `0xB2D870`（唯一调用点 `0xB28798`，前面紧挨着 `mov rdi, r14`），但它的整个主体
   （`0xB2D893`~`0xB2DCCD`）被这道闸门挡住：

   ```
   0xB2D893  mov  rax, qword ptr [rip + 0x244AA36]   ; rax = [0x2F782D0]
   0xB2D89A  cmp  byte ptr [rax], 1
   0xB2D89D  jne  0xB2DCCD                          ; ← 实际总是跳走
   ```

   `0x2F782D0` 是个 `.bss` 里的 `bool*`，**在整个镜像里没有任何一处写入过它**
   （全可执行段逐字节扫过 `mov [rip+…], r` / `lea` / SSE 存储，零命中），也没有
   任何 RELA 指向它，所以运行时它是 0。而 `0x2F782D0` 所在段 `vaddr` 从 0 开始，
   于是 `[rax]` 落到 **VA 0**——那里的字节是 `0x00CC……` 的 `int3` 对齐填充
   （`0xCC ≠ 1`），所以 `jne` **每帧都跳走**。这段代码本来是要靠"连上 Bluepoint
   工具主机"填上那个指针的，见 `misc\gamecommandlineargs.txt`：

   ```
   +[PS5][!RetailBuild]LoadCmdsFromFile=/devlog/app/BPLastToolsHost.txt inline=true
   ```

   没有编辑器连进来 → 指针空 → 调试菜单相关的一切（含 `cp11_toggleDebugMenu`）
   都不会有反应。**这也解释了为什么启动器发 `cp11_toggleDebugMenu=true` 没用。**

**顺带查清的限定符表**（`0x816880`，决定 `misc\gamecommandlineargs.txt` 里
`+[限定符]` 哪些生效）：

| 限定符 | 本版结果 | 依据 |
| --- | --- | --- |
| `shipping` | **恒为真** | `0x816952` 直接 `mov al,1` |
| `ps5` | **恒为真** | 同上（`0x816841 je 0x816952`） |
| `PackageBuild` | **真** | `0x8168EA` 读 `0x2EE5241`，即 `gameversion.txt` 同级 `isapackagebuild.txt` 是否存在（该文件存在） |
| `tools` / `debug` / `release` | 恒为假 | `0x816894` / `0x8168CE` / `0x8168F9` 命中后 `0x816933 xor eax,eax` |
| `RetailBuild` | `!(flags & 2)` | `0x816884 call 0x8469c0; test byte[rax],2; sete al` |

**因此 `DebugMenu.txt` 的加载被 `RetailBuild` 单独卡住**：
`misc\gamecommandlineargs.txt` 第 6 行是
`+[!Tools][!RetailBuild]LoadCmdsFromFile=$/misc/DebugMenu.txt`，`!Tools` 本来就成立
（`tools` 恒假），只有 `!RetailBuild` 不成立。

**两条补丁（mods 7 / 8，默认关闭）：**

- **mod 7「Debug menu: open in game」** —— 拆掉上面那道闸门（`0xB2D893` 起 16 字节
  全 NOP，顺带也去掉了对空指针的解引用），再把菜单自己的开关字节钉死在 1：菜单可见性
  送给调试菜单对象 vtable 槽 `+0x18`（`0xB97EF0`，尾部经 `0x828920` 写
  `[obj+8] = sil`），`sil` 取自 `r15b`，而 `r15b` 在 `0xB2D97E / 0xB2D983 / 0xB2D99F`
  三处由手柄组合键状态算出 —— 三处全改 `mov r15b,1`。这样下一句
  `0xB2DBEF or r12b,r15b; je 0xB2DC2B`（真正决定要不要走绘制调用）也不会跳过。
- **mod 8「Dev build flags: RetailBuild off」** —— 让 `RetailBuild` 恒为假，
  于是 `$/misc/DebugMenu.txt`（菜单条目定义：`Toggle DS Debug Menu`、
  `ToggleDebugCamera`、`Quicksave` 子菜单、`!DemoMode` 子菜单）在开机时被载入，
  同时 `[!RetailBuild]` 的几条也跟着生效（`DSPointsOfInterest.txt` /
  `GameAppPointsOfInterest.txt` 的载入、`cp11_summoning_level_based=false` 等）。

**⚠ 没在游戏里验证过。** 建议：**先只开 7** 进游戏看有没有反应；不行再开 8（可以两个一起开）。
两种情况都有信息量：崩了 → 说明 `0xB2D942` 之前那段对象图还有别的未初始化依赖；
还是不显示 → 说明缺的是菜单数据（该开 8）或渲染资源。

**渲染路径的副作用提醒**：mod 7 是把调试菜单"永久置为打开"，如果它真渲染出来了，
屏幕上会常驻一个调试叠加层（含它的绘制调用）。不想要就关掉 mod 7 重启。

**✅ 那个"未决问题"当晚就定案了（2026-10-16）：那 14 个 convar 不是游戏的输入，只是调试菜单的视图。**
游戏读的是**存档**里的 float：eboot `0x2cc33` 起有一段循环 `0..6`，用 `sprintf` 生成
`Tendency_World%02d_BlackWhite` / `_LeftRight` 再按名字哈希查表；人物倾向在同表的
`Tendency_Player_BlackWhite` / `Tendency_Player_LeftRight`。它们住在
`_SaveData\PPSA01341\SAVEDATA0PlayerProfile<n>\USR-DATA`（明文键值表，类型 `0x0a` = float，
量程 ±200），校验和是 `fnv1a32(payload)`。

* **要改倾向不用碰调试菜单了** —— 启动器那两行（世界/人物倾向）现在直接写存档，
  细节见 `G:\KytyAddons\README.md` 的"一之三"节。
* **mod 7 / mod 8 因此降级成纯好奇向的可选项**（想看看游戏自己的调试叠加层才需要），
  和倾向已经没关系了。

---

## 2. 为什么这几个是"游戏自带的开关"

这份 eboot 是 **未剥离调试符号的 Bluepoint/From 内部版本**，里面完整保留了
`cp11_characters_*` 一整套作弊 convar：

```
cp11_characters_playerNoDamage        cp11_characters_allNoDamage
cp11_characters_playerNoDead          cp11_characters_allNoDead
cp11_characters_playerNoHit           cp11_characters_allNoHit
cp11_characters_playerNoStaminaConsume    cp11_characters_allNoStaminaConsume
cp11_characters_playerNoManaConsume       cp11_characters_allNoManaConsume
```

convar 名 -> 运行时 bool 地址（BSS）：

| 标志地址 | convar |
| --- | --- |
| `0x27CBC60` | `playerNoDead` |
| `0x27CBD50` | `playerNoDamage` |
| `0x27CBF30` | `playerNoStaminaConsume` |
| `0x27CC020` | `playerNoManaConsume` ← **本版没人读它** |
| `0x27CC200` | `allNoDamage` |
| `0x27CC3E0` | `allNoStaminaConsume` |

代码里的判定长这样，非常规整：

```
lea rax, [rip + 0x27CBD50]      ; &playerNoDamage
cmp byte ptr [rax], 1
jne 0x32d6a9                    ; 标志没开 -> 正常受伤
mov rax, [rbx]
mov rdi, rbx
call qword ptr [rax + 0x120]    ; IsPlayer()
jne 0x32d869                    ; 是玩家 -> 直接跳过整段伤害流程
```

把 `jne` 抹成 `nop`，就等于"这个开关恒为真"，而且完全走游戏自己的逻辑，
不会破坏 HUD、不会出现数值错乱。

> 两个坑，值得记下来：
> * `playerNoManaConsume` / `playerNoHit` 在本版是**死开关** —— 全库只有注册代码和
>   调试面板引用了它们，没有任何读取点。所以"无限魔力"没法用 convar 实现（见第 3 节）。
> * bool 在 **BSS** 里，开局被 convar 构造流程写 0。直接在 BSS 写 1 会被覆盖掉，
>   所以只能改**读取处的跳转**，不能改标志本身。

---

## 3. 状态结构布局（已实锤）

| 用途 | 偏移 | 佐证 |
| --- | --- | --- |
| HP 当前 | `+0x710` | `SetHp` @ `0x325890`；不死逻辑用 `SetHp(1)` 复活 |
| MP 当前 | `+0x71C` | `SetMp` @ `0x3259E0`，被 `+0x720` 钳位 |
| MP 上限 | `+0x720` | 魔力回复函数 @ `0x3356E3`：`min(MP+regen, [rbx+0x720])` |
| 耐力当前 | `+0x724` | 耐力消耗函数 @ `0x331A30` 写它，下限 `-50` |
| 耐力上限 | `+0x728` | 同函数 |
| HP 上限 | `+0x730` | 回满血逻辑用 `(max - cur) + hp` |
| 携带魂量 | `+0x80`（int32） | `AddSouls` @ `0x4561E0` 的读写字段；对应 `cp11_setSouls` / `cp11_addSouls` |
| 累计魂量 | `+0x88`（qword） | 同函数尾段；对应 `cp11_setCumulativeSouls` |

关键函数：

| 地址 | 作用 |
| --- | --- |
| `0x4561E0` | **`PlayerStatus::AddSouls(player, delta)`** —— 魂量唯一的增减入口，钳到 `[0, 999999999]`；全库只有 5 个调用点（见 1.1 节） |
| `0x325890` | `PlayerStatus::SetHp(value)`（钳到 `[0, maxHp]`，HP<=0 触发死亡流程） |
| `0x3259E0` | `PlayerStatus::SetMp(value)`（钳到 `[0, maxMp]`） |
| `0x32D5xx` | **受伤主流程**：`playerNoDamage` / `allNoDamage` / `playerNoDead` 判定都在这 |
| `0x32B340` | 一个按 `[obj+4]`（kind 2/5/6）分派的效果例程，操作 `+0x73C/+0x740/+0x744` |
| `0x331A30` | 耐力消耗 |

⚠️ **重要修正**：`+0x73C / +0x740 / +0x744`（配 `+0x748/+0x74C/+0x750`）**不是** 血/魔/耐。
它们只是被 `0x325700` 那段"把镜像值填到上限"的辅助逻辑顺手写一遍。
早期版本的金手指把它们当成血量来改，是错的 —— 现已全部改用上表的真实偏移。

---

## 4. 文件格式与匹配机制（决定了为什么必须版本完全一致）

```json
{
    "name": "Demon's Souls",          // 可选，仅作说明
    "id": "PPSA01341",                // 必填，必须等于游戏 TITLE_ID
    "version": "01.007.000",          // 必填，必须等于游戏 APP_VER
    "process": "eboot.bin",           // 必填，主程序名
    "mods": [
        {
            "name": "无限生命",
            "type": "checkbox",
            "enabled": true,          // false 时整条被跳过（想单独测试就改这里）
            "memory": [
                { "offset": "32D690", "off": "8038017514", "on": "8038019090" }
            ]
        }
    ]
}
```

`off` / `on` 是**偶数长度连续十六进制**，长度必须相等，不能有空格、`0x`、`-`。

### 4.1 模拟器的算法（源码 `src/loader/gamePatch.cpp`）

1. `LoadPlan()`：把所有 **enabled** 的 mod 的 `memory` 项**按顺序压进同一个扁平表**。
2. `Matches()`：取扁平表里**第一条 `off` 非全 0** 的项当**锚点**，在整个可加载段里搜它。
3. 对每个命中位置算 `source_base = 锚点.offset - 命中位置`；
4. `TranslateAndValidate()`：**扁平表里每一条 `off` 非全 0 的项**都必须在
   `offset - source_base` 处逐字节匹配。
5. 第一个能全部通过的位置胜出；`ApplyWrites()` 再按扁平表顺序把 `on` memcpy 进去
   （**重叠时后写的赢**）。

**所以：整个文件只有一个全局锚点、一个全局 `source_base`，不是每条 mod 各算各的。**
本文件的锚点是第 1 条 `Max Souls` 的第一项：`off` 填的是 `AddSouls()` **19 字节的
函数序言** `554889E5415653448BB780000000BAFFC99A3B`（`on` 与 `off` 相同，等于不改字节）。
这个串在全库里唯一，顺带把匹配**钉死在这个函数上** —— 换一份 eboot 会直接匹配失败，
而不会跑到别的地址上乱写。实测 `source base 0x0`，即**文件里的 `offset` 就是模拟器的 RVA**。

### 4.2 坐标系（踩过的坑，务必记住）

`decrypted/eboot.bin` 的**主 PT_LOAD 段是 `p_offset=0x4000 / p_vaddr=0x0`**，所以：

```
文件偏移 = RVA + 0x4000        （仅主代码段）
```

即 `eboot+0x32D690`（RVA）在文件里的字节位置是 **`0x331690`**。用十六进制编辑器肉眼
核对时千万不要搞混 —— 早期版本正是拿文件偏移当 RVA，所有地址整体偏高 `0x4000`，
结果 6 条金手指"逐条校验通过但一条都不生效"。

`verify_cheat.py` 现在**完全复刻**上面的算法（全局锚点 + 全表校验），
并会打印 `source base` 和重叠提示：

```
python cheats\verify_cheat.py cheats\PPSA01341_01.007.000.json "G:\Game\PPSA01341-app0"
```

---

## 5. 移植到其它版本 / 自己加金手指

`offset` 是 **eboot 内的 RVA**（运行时基址 `0x900000000`，`offset = 运行时地址 - 0x900000000`）。

步骤：

1. 先用 `verify_cheat.py` 看旧金手指的锚点在新版里还在不在（`[no ]` 就是没了）；
2. 用 IDA / Ghidra 载入 `decrypted\eboot.bin`（基址 `0x900000000`）定位同样逻辑的指令；
3. 把 `offset` 改成新 RVA、`off` 填**你这版 eboot 里真实的字节**、`on` 填补丁后字节；
4. 再跑 `verify_cheat.py` 确认 `[OK ]`。

定位技巧：

* 找 `lea rax, [rip+disp]` 后面跟 `cmp byte ptr [rax],1` / `jne` 的，就是 convar 判定点；
* `test byte ptr [rbx+0x7d9], 4` / `test byte ptr [rbx+0x7d8], 0x20` 这类是"每条角色"级的
  免伤/免耗位；
* 想找某个 convar 的存储地址：在 convar 注册函数（本版 `0x355760`–`0x3562xx`）里，
  紧跟名字字符串 `lea` 之后的 `lea rdi, [...]` 是 ConVar 对象、`lea rdx, [...]` 是绑定的 bool。

> 提示：`off` 的**第一条**建议写一处**全库唯一**的模式（`on` 与 `off` 相同即可，等于不改），
> 后面各条写相对它的地址 —— 这样锚点唯一，整个文件才不会被搜到别处去。

---

## 6. 注意

* 想单独测试某一条：在启动器的 **Mods** 列表里取消勾选即可，其余不受影响；
  等价地，也可以把该 mod 的 `"enabled"` 改成 `false`（启动器下次打开会读到这个值）。
* 金手指是**启动时一次性**打补丁，游戏运行中不能开关；要换就回启动器改设置重开。
* 第 6 条（一击必杀）是唯一没把握的一条，行为"改动目标 HP 为 0"，请单独试。
* ⚠️ **加新条目时先确认地址没和别人重叠**：所有开启条目会被摊平成一张表按顺序写，
  重叠时**后写的赢**（这就是 1.1 节 bug 1 的成因）。加之前跑一遍 `verify_cheat.py`，
  它会直接把重叠报出来。
* 联机 / 存档风险自负，重要存档先备份 `_SaveData`。
