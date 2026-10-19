param([switch]$DryRun, [switch]$ApplyTendency)
# A small settings window in front of run-windows.ps1 and precompile-windows.ps1 (launcher.cmd opens it). The
# settings and the console language names follow the KytyPS5 launcher (src/launcher, by the KytyPS5 developers);
# they are kept in launcher-settings.json next to this script. -DryRun prints the commands without a window,
# -ApplyTendency writes the tendency settings into the save and stops.
#
# This is the KytyAddons launcher: it is the official launcher of the release it came from (v20261019), with a
# "Mods" group added - the cheat file and the mods inside it, the Demon's Souls tendencies, the debug readout and
# menu, and the DualSense speaker / vibration levels. Everything the official launcher has is kept as it is. The
# switches that only some releases declare are passed through Test-RunParam, so the same file can be dropped onto
# a later release without changes.
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
# cmd.exe by its full path: Start-Process with a bare "cmd" opens whatever "cmd" it finds first, and a file of that
# name without an extension (in the working folder or on the PATH) made Windows ask which app should open it (issue #47).
$cmd = if ($env:ComSpec -and (Test-Path -LiteralPath $env:ComSpec)) { $env:ComSpec } else { Join-Path ([Environment]::SystemDirectory) 'cmd.exe' }
# Windows PowerShell by its path too: on a PC whose PATH lacks its folder, cmd.exe did not know "powershell" (issue #55).
$powershellExe = Join-Path ([Environment]::SystemDirectory) 'WindowsPowerShell\v1.0\powershell.exe'
$powershellCommand = if (Test-Path -LiteralPath $powershellExe) { "`"$powershellExe`"" } else { 'powershell' }
$settingsPath = Join-Path $root 'launcher-settings.json'
# A value the window cannot take must never leave the launcher unopenable: a saved setting outside
# a control's range threw out of the form build once (the window vanished with no message, and
# every later start did the same). Show what happened instead, naming the file to fix or delete.
trap {
	Add-Type -AssemblyName System.Windows.Forms -ErrorAction SilentlyContinue
	$detail = "$($_.Exception.Message)`r`n`r`n$($_.InvocationInfo.PositionMessage)`r`n`r`nsettings: $settingsPath"
	# -DryRun prints and is used from a console: a dialog would sit there waiting for a click.
	if ($DryRun) { $detail; exit 1 }
	[System.Windows.Forms.MessageBox]::Show($detail, 'KytyPS5 launcher') | Out-Null
	exit 1
}
$languages = 'Japanese', 'English (United States)', 'French (France)', 'Spanish (Spain)', 'German', 'Italian', 'Dutch',
	'Portuguese (Portugal)', 'Russian', 'Korean', 'Chinese (Traditional)', 'Chinese (Simplified)', 'Finnish', 'Swedish',
	'Danish', 'Norwegian', 'Polish', 'Portuguese (Brazil)', 'English (United Kingdom)', 'Turkish', 'Spanish (Latin America)',
	'Arabic', 'French (Canada)', 'Czech', 'Hungarian', 'Greek', 'Romanian', 'Thai', 'Vietnamese', 'Indonesian'
# The window's sizes for each aspect ratio of the 3D (below).
$resolutionsByRatio = @{
	'16:9' = '1280x720', '1920x1080', '2560x1440', '3840x2160'
	'21:9' = '2560x1080', '3440x1440', '3840x1600', '5120x2160'
	'32:9' = '3840x1080', '5120x1440', '7680x2160' }
# The height Demon's Souls renders its 3D at (run-windows.ps1 -RenderHeight); its output and UI stay 3840x2160.
$renderHeights = '2160 (native 4K)', '1800', '1620', '1512 (PS5 Pro)', '1440 (PS5)', '1296', '1152', '1080', '900'
# What makes the 3840x2160 image of the 3D (run-windows.ps1 -Upscaler): the game's TAA and stretch (the PS5's), or DLSS in
# place of Sony's PS5 Pro upscaler on the game's PS5 Pro path (NVIDIA's Streamline runtime, as frame generation).
$upscalers = 'Game (PS5)', 'DLSS (PS5 Pro path)'
# The aspect ratio of Demon's Souls' 3D (run-windows.ps1 -Aspect): wider sees more to the sides.
$ratios = '16:9 (PS5)', '21:9', '32:9'
# Demon's Souls' own settings for what a frame draws (run-windows.ps1 -Quality): shorter shadows, simpler distant detail;
# and smaller textures (run-windows.ps1 -TextureReduce: Low 1, Lowest 2; Standard leaves it to the emulator: 1 below
# 12 GB of video memory, else 0).
$qualities = 'Standard (PS5)', 'Low', 'Lowest'
# DLSS frame generation (run-windows.ps1 -FrameGen: the generated frames per rendered one, the multiplier less one).
$frameGens = 'Off', '2x', '3x', '4x', '5x', '6x'
# The emulator's own panel at the top right of the game image (KYTY_FPS_HUD 0, 1, 2).
$overlays = 'Off', 'Frame rate', 'Detailed'
# Safe GPU mode (KYTY_COMPUTE_CHAIN=0): Demon's Souls' compute work runs one dispatch after another instead of letting
# the GPU overlap them. Slower, but it stops the GPU hangs ("device lost", the driver resetting the display) that some
# PCs have: on an RTX 3080 Laptop with driver 566.07, 3 of 4 runs through 1-1 hung with overlap, none of 3 without it,
# at 25-48% less frame rate there (13.9-17.7 fps instead of 26.8 at 1-1, 21-22 instead of 28.8 at 2-2).
$safeGpuTip = "Prevents the crashes and blue screens that come from the graphics card hanging: 'device lost', the screen going`n" +
	"black while the graphics driver restarts (a TDR), or a VIDEO_TDR_FAILURE blue screen. The emulator then runs Demon's Souls'`n" +
	"compute work one step after another instead of letting the graphics card overlap the steps. The frame rate is about 37%`n" +
	"lower (on a laptop RTX 3080 at Boletaria: 17 fps instead of 27). It does not help MEMORY_MANAGEMENT blue screens, which`n" +
	"come from the RAM being full (see the README). Leave it off if the game runs without such crashes; a current graphics`n" +
	"driver can help too."

# The switches run-windows.ps1 declares in this folder. A release that does not declare one ends the run on it, so
# the optional switches are passed only when this version has them: this launcher is copied onto a later release as
# it is. The type may be an array ([string[]]$Set), hence the optional [] - a plain [a-z]+ would not see those.
$runScript = Join-Path $root 'run-windows.ps1'
$runText = if (Test-Path -LiteralPath $runScript) { Get-Content -LiteralPath $runScript -Raw } else { '' }
function Test-RunParam([string]$name) { return $runText -match "(?im)^[ \t]*\[[a-z]+(\[\])?[ \t]*\][ \t]*\`$$name\b" }

# The release's own KYTY_GAME_CONVARS value: Demon's Souls' engine settings (no XPR index-buffer
# culling). The -Set switch replaces a variable rather than adding to it, so the tendencies have to
# keep it in front of them. A release that has no such default leaves this empty.
$releaseGameConvars = ''
if ($runText -match "(?m)Contains\('KYTY_GAME_CONVARS'\)[^\r\n]*\{[^\r\n]*'KYTY_GAME_CONVARS'\]\s*=\s*'([^']*)'") {
	$releaseGameConvars = $Matches[1]
}

$settings = [ordered]@{ game = ''; resolution = '2560x1440'; fullscreen = $false; aspect = $true; language = 1;
	redzone = $true; ecores = $false; fps120 = $false; render = 1440; ratio = '16:9'; quality = 'standard';
	vsync = $false; hdr = $false; framegen = 0; hud = 0; streamline = '';
	# v20261019: the safe GPU mode (KYTY_COMPUTE_CHAIN=0), the DLSS upscaler and the render height it keeps
	# for itself. A settings file that predates them simply has no such keys and keeps the defaults here.
	safegpu = $false; upscaler = ''; render_dlss = 1080;
	cheats = $false; cheatFile = ''; modStates = @{};
	# tendencyWorlds starts EMPTY on purpose: an empty list is what says "this settings file never held
	# per-world values", which is the case that fills the seven boxes from the save instead. A list of
	# zeros would be indistinguishable from a file that really does pin every world to zero.
	tendencyWorlds = @(); tendencyWorldOn = @($false, $false, $false, $false, $false, $false, $false);
	tendencyCharacterOn = $false; tendencyCharacter = 0;
	tendencyDebug = $false; debugMenu = $false;
	dualSenseSpeakerOn = $false; dualSenseSpeaker = 100; dualSenseHapticsOn = $false; dualSenseHaptics = 100 }
$worldsInSettings = $false
if (Test-Path $settingsPath) {
	$saved = Get-Content $settingsPath -Raw | ConvertFrom-Json
	foreach ($property in $saved.PSObject.Properties) { if ($settings.Contains($property.Name)) { $settings[$property.Name] = $property.Value } }
	# The world tendency became one value per world. A settings file written before that holds the
	# single number and tick the launcher kept then, and no list: it is remembered here so the seven
	# boxes can be filled from the save instead of from that one stale number.
	$worldsInSettings = $null -ne $saved.PSObject.Properties['tendencyWorlds']
	# The per-mod switches: "<cheat file name>::<mod name>" -> bool (Read-Form saves them).
	$settings.modStates = @{}
	if ($saved.PSObject.Properties['modStates']) {
		foreach ($mod in $saved.modStates.PSObject.Properties) { $settings.modStates[$mod.Name] = [bool]$mod.Value }
	}
}
if (!$settings.game -and (Test-Path "$root\game-path.txt")) { $settings.game = (Get-Content "$root\game-path.txt" -TotalCount 1).Trim() }

# The efficiency cores (the lowest efficiency class of a hybrid CPU) as an affinity mask, or 0.
function Get-EfficiencyMask {
	Add-Type -Namespace KytyLauncher -Name CpuSets -MemberDefinition @'
[DllImport("kernel32.dll")]
static extern bool GetSystemCpuSetInformation(IntPtr information, uint length, out uint returned, IntPtr process, uint flags);
// Group 0's logical processors as (index, efficiency class) pairs.
public static int[] Query() {
	var result = new System.Collections.Generic.List<int>();
	uint length;
	GetSystemCpuSetInformation(IntPtr.Zero, 0, out length, IntPtr.Zero, 0);
	if (length == 0) return result.ToArray();
	IntPtr buffer = Marshal.AllocHGlobal((int)length);
	try {
		if (!GetSystemCpuSetInformation(buffer, length, out length, IntPtr.Zero, 0)) return result.ToArray();
		for (int offset = 0; offset < length; offset += Marshal.ReadInt32(buffer, offset)) {
			if (Marshal.ReadInt32(buffer, offset + 4) != 0 || Marshal.ReadInt16(buffer, offset + 12) != 0) continue;
			result.Add(Marshal.ReadByte(buffer, offset + 14));
			result.Add(Marshal.ReadByte(buffer, offset + 18));
		}
	} finally {
		Marshal.FreeHGlobal(buffer);
	}
	return result.ToArray();
}
'@
	$values = [KytyLauncher.CpuSets]::Query()
	$sets = for ($i = 0; $i + 1 -lt $values.Count; $i += 2) { [pscustomobject]@{ Cpu = $values[$i]; Class = $values[$i + 1] } }
	if (@($sets | ForEach-Object Class | Sort-Object -Unique).Count -lt 2) { return [int64]0 }
	$slowest = ($sets | Measure-Object Class -Minimum).Minimum
	$mask = [int64]0
	foreach ($set in $sets | Where-Object { $_.Class -eq $slowest -and $_.Cpu -lt 63 }) { $mask = $mask -bor ([int64]1 -shl $set.Cpu) }
	return $mask
}
$efficiencyMask = Get-EfficiencyMask

# A cheat file's mods: its "mods" array as name / the file's own "enabled" / description. The
# emulator defaults a mod to enabled when the field is missing (src/loader/gamePatch.cpp).
function Get-CheatMods([string]$file) {
	if (!$file -or !(Test-Path -LiteralPath $file)) { return @() }
	try { $json = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json } catch { return @() }
	if (!$json -or !$json.mods) { return @() }
	return @($json.mods | ForEach-Object {
		$on = $true
		if ($_.PSObject.Properties['enabled']) { $on = [bool]$_.enabled }
		[pscustomobject]@{ Name = [string]$_.name; On = $on; Description = [string]$_.description }
	})
}
# A mod's switch is remembered per cheat file: "<file name>::<mod name>" -> bool.
function Get-ModKey([string]$file, [string]$mod) { return "$(Split-Path $file -Leaf)::$mod" }
# The file this run patches with: a copy of the chosen one with each mod's "enabled" set to its
# switch, or the chosen file itself when the switches already match it. The emulator skips a mod
# whose "enabled" is false, so this is all it takes; the copy goes to cheats\_session and the file
# in cheats stays as it is (the launcher lists the folder's own .json files only).
function Get-SessionCheats {
	$file = [string]$settings.cheatFile
	if (!$file -or !(Test-Path -LiteralPath $file)) { return '' }
	$mods = Get-CheatMods $file
	if ($mods.Count -eq 0) { return $file }
	$wanted = @{}
	foreach ($mod in $mods) {
		$key = Get-ModKey $file $mod.Name
		$wanted[$mod.Name] = if ($settings.modStates.Contains($key)) { [bool]$settings.modStates[$key] } else { $mod.On }
	}
	$changed = $false
	foreach ($mod in $mods) { if ([bool]$wanted[$mod.Name] -ne $mod.On) { $changed = $true; break } }
	if (!$changed) { return $file }
	try {
		$json = Get-Content -LiteralPath $file -Raw -Encoding UTF8 | ConvertFrom-Json
		foreach ($mod in $json.mods) {
			$name = [string]$mod.name
			if ($wanted.Contains($name)) { $mod.enabled = [bool]$wanted[$name] }
		}
		$session = Join-Path (Join-Path $root 'cheats') '_session'
		New-Item -ItemType Directory -Force $session | Out-Null
		$out = Join-Path $session (Split-Path $file -Leaf)
		# No BOM, as the files in cheats: the emulator's JSON parser skips one anyway.
		[System.IO.File]::WriteAllText($out, ($json | ConvertTo-Json -Depth 100), (New-Object System.Text.UTF8Encoding($false)))
		return $out
	} catch {
		return $file
	}
}

# The game's own console variables ("convars"). The emulator appends these to the args file the
# game reads at boot (KYTY_GAME_CONVARS, src/loader/gameArgs.cpp), so engine values change without
# touching the game's files - Demon's Souls hands every line to its own console.
#
# The tendency names are the ones the game's own debug menu uses. The shipped misc\debugmenu.txt
# puts "Toggle Debug Tendency Values" on a "CP11 Tendency" page and binds it to
# cp11_uiShowNumericalTendencyData; the page itself is built in eboot and is bound to
# cp11_tendency_character_BW / _LR and cp11_tendency_world_current_0..5 / _next_0..5.
#
# The scale is -200 .. +200 with 0 as neutral: -200 pure black, 0 neutral, +200 pure white. That is
# the range the game itself registers - all fourteen of these convars are built by one engine call
# (0xc7c0) which is handed the two constants at 0x2500A5C (200.0f) and 0x2500A60 (-200.0f) and stores
# them into the convar object as its limits - and it is the range Demon's Souls sources describe for
# the hidden tendency numbers (a body-form death is -60, a boss +60..+180, the ends are +/-200).
# The value is a plain float seeded with 0.
#
# A boolean takes the literal true/false - the game's own coredata shortcut file writes
# "cp11_toggleDebugMenu = true" - so "=1" is the one spelling the engine does not accept.
#
# ANSWERED 2026-10-16: those fourteen values are NOT what the game plays with, which is why handing
# them a number at boot never moved the icon (the readout appeared, the value stayed 0.00). The game
# reads its tendency out of the SAVE. That is settled from the game's own code: at eboot 0x2cc33 a
# loop over 0..6 builds "Tendency_World%02d_BlackWhite" and "Tendency_World%02d_LeftRight", hashes
# each name and looks it up in the character's saved values, and the character's own tendency sits
# in the same table as "Tendency_Player_BlackWhite" / "Tendency_Player_LeftRight". All sixteen are
# 4-byte floats on the -200 .. +200 scale (0 neutral). So the tendency controls below write the save
# instead of sending convars; only the readout and the debug menu still travel as convars.
# What a saved tendency stands for. Anything the game would not understand - a missing key, an empty
# string - comes back as 0, the neutral value. [double]::TryParse always writes its out parameter,
# which is why a plain [ref] would turn every bad value into 0 by accident; the fallback is spelled
# out here so it is a decision rather than a side effect.
function ConvertTo-TendencyNumber($value) {
	$parsed = 0.0
	if (-not [double]::TryParse([string]$value, [ref]$parsed)) { $parsed = 0.0 }
	return [Math]::Max(-200.0, [Math]::Min(200.0, $parsed))
}
function Get-TendencyConvars {
	# Only the two switches still travel as convars. The values themselves used to as well, and that
	# was the bug: the game never reads cp11_tendency_* for gameplay, so a number set there did
	# nothing. They now go into the save (Write-TendencyToSave below).
	$pairs = @()
	if ($settings.tendencyDebug) { $pairs += 'cp11_uiShowNumericalTendencyData=true' }
	if ($settings.debugMenu) { $pairs += 'cp11_toggleDebugMenu=true' }
	return $pairs
}
# The pad's two output routes - its own speaker and its actuators - are levelled by the package's
# libs/dualSenseHaptics.cpp, which reads KYTY_DUALSENSE_SPEAKER_GAIN (0..64, 8.0 as shipped) and
# KYTY_DUALSENSE_HAPTICS_GAIN (0..4, 1.0) once, at start-up. The boxes ask for a percentage of what
# the package ships, so 100 % is "leave it as it is": the guest hands a pad speaker port audio about
# 40 dB below its main output (Demon's Souls peaks near -40 dB) and that gain is the only reason the
# pad is audible at all. 0 % of the speaker is a mute. Both go through run-windows.ps1 -Set.
function ConvertTo-DualSenseGain($percent, [double]$unity) {
	# Whole percentages, but the vibration route's fractions (0.25, 0.75) are not, so the result is
	# spelled out with the invariant culture: a comma decimal separator would be read as a key list.
	return (([double]$percent / 100.0) * $unity).ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
}
function Get-ControllerVolume {
	$pairs = @()
	if ($settings.dualSenseSpeakerOn) {
		$pairs += "KYTY_DUALSENSE_SPEAKER_GAIN=$(ConvertTo-DualSenseGain $settings.dualSenseSpeaker 8.0)"
	}
	if ($settings.dualSenseHapticsOn) {
		$pairs += "KYTY_DUALSENSE_HAPTICS_GAIN=$(ConvertTo-DualSenseGain $settings.dualSenseHaptics 1.0)"
	}
	return $pairs
}

# --- the character save -------------------------------------------------------------------------
# SAVEDATA0PlayerProfile<n>\USR-DATA under _SaveData\<title> is a plain key/value table:
#   u32 version | u32 FNV-1a 32 of the payload | u32 payload size | u32 reserved | then entries of
#   <u32 FNV-1a 32 of the upper-case name><u8 type><value>
# Type 0x0a is a 4-byte float and that is what every tendency field uses. The checksum covers
# everything from offset 16 on, so it has to be recomputed after a value changes or the game drops
# the save; the emulator's own debug-warp feature edits this file the same way. The name hash is the
# game's: FNV-1a 32 of the name with a-z folded to A-Z.
#
# The hash and the key scan walk a 40 KB payload, which a PowerShell loop would do slowly enough to
# be felt at every launch, so they live in a small C# helper. The type is added once: a second
# Add-Type of the same name would throw.
if (-not ('KytyAddons.TendencySave' -as [type])) {
	Add-Type -TypeDefinition @'
using System;
using System.Text;

namespace KytyAddons
{
	public static class TendencySave
	{
		public static uint Fnv1a32(byte[] data, int offset, int count)
		{
			uint hash = 2166136261u;
			for (int i = 0; i < count; i++) { hash ^= data[offset + i]; hash *= 16777619u; }
			return hash;
		}
		public static uint KeyOf(string name)
		{
			byte[] bytes = Encoding.ASCII.GetBytes(name.ToUpperInvariant());
			return Fnv1a32(bytes, 0, bytes.Length);
		}
		public static byte[] U32(uint value)
		{
			return new byte[] { (byte)value, (byte)(value >> 8), (byte)(value >> 16), (byte)(value >> 24) };
		}
		public static byte[] F32(float value) { return BitConverter.GetBytes(value); }
		// The offset of the single entry "<key><type>", -1 when there is none, -2 when there are several.
		public static int Find(byte[] data, uint key, byte type)
		{
			byte k0 = (byte)key, k1 = (byte)(key >> 8), k2 = (byte)(key >> 16), k3 = (byte)(key >> 24);
			int found = -1;
			for (int i = 16; i <= data.Length - 9; i++)
			{
				if (data[i] != k0 || data[i + 1] != k1 || data[i + 2] != k2 || data[i + 3] != k3 || data[i + 4] != type) continue;
				if (found >= 0) return -2;
				found = i;
			}
			return found;
		}
	}
}
'@
}

# The character save to write: the one played most recently, so the launcher never has to be told
# which character is about to be loaded. SAVEDATA0OptionsProfile0 is left alone (no tendency fields).
function Get-SaveTitle {
	$title = 'PPSA01341'
	if ($settings.game -match '([A-Z]{4}\d{5})-app0') { $title = $Matches[1] }
	return $title
}
function Get-TendencySave {
	$folder = Join-Path $root ("_SaveData\" + (Get-SaveTitle))
	if (-not (Test-Path -LiteralPath $folder)) { return @() }
	$found = @()
	foreach ($child in @(Get-ChildItem -LiteralPath $folder -Directory -ErrorAction SilentlyContinue)) {
		if ($child.Name -notlike 'SAVEDATA0PlayerProfile*') { continue }
		$file = Join-Path $child.FullName 'USR-DATA'
		if (Test-Path -LiteralPath $file) { $found += Get-Item -LiteralPath $file }
	}
	return @($found | Sort-Object LastWriteTime -Descending)
}
# What the window is about to write, as the name/value pairs the save uses. The character tendency is
# one value on two axes: the game keeps BlackWhite and LeftRight in step, so both get the same number.
# The world tendency is one value per world slot, and only the slots that are ticked are written - a
# world left unticked is not touched at all, which is what makes them adjustable one at a time.
function Get-WantedTendencies {
	$wanted = New-Object System.Collections.ArrayList
	if ($settings.tendencyCharacterOn) {
		$value = [single](ConvertTo-TendencyNumber $settings.tendencyCharacter)
		[void]$wanted.Add([pscustomobject]@{ Name = 'Tendency_Player_BlackWhite'; Value = $value })
		[void]$wanted.Add([pscustomobject]@{ Name = 'Tendency_Player_LeftRight'; Value = $value })
	}
	for ($index = 0; $index -lt $worldCount; $index++) {
		if (-not [bool]$settings.tendencyWorldOn[$index]) { continue }
		$value = [single](ConvertTo-TendencyNumber $settings.tendencyWorlds[$index])
		$slot = $worldSlots[$index]
		[void]$wanted.Add([pscustomobject]@{ Name = ('Tendency_World{0:00}_BlackWhite' -f $slot); Value = $value })
		[void]$wanted.Add([pscustomobject]@{ Name = ('Tendency_World{0:00}_LeftRight' -f $slot); Value = $value })
	}
	return @($wanted)
}
function Format-TendencyValue($value) {
	if ($null -eq $value) { return '?' }
	return ([double]$value).ToString('0.###', [System.Globalization.CultureInfo]::InvariantCulture)
}
function Read-TendencyField($data, [string]$name) {
	$at = [KytyAddons.TendencySave]::Find($data, [KytyAddons.TendencySave]::KeyOf($name), 0x0A)
	if ($at -lt 0) { return $null }
	return [System.BitConverter]::ToSingle($data, $at + 5)
}
# One line for the window: which save the tendencies are read from and what they hold right now. It
# is read when the window opens, so opening the launcher again is how a write is confirmed.
function Get-TendencyStatus {
	$files = @(Get-TendencySave)
	if ($files.Count -eq 0) { return 'no character save yet under _SaveData - the tendencies cannot be written' }
	$file = $files[0]
	$data = $null
	try { $data = [System.IO.File]::ReadAllBytes($file.FullName) } catch { return "the save could not be read: $($_.Exception.Message)" }
	if ($data.Length -lt 32) { return 'the save is too short to be a USR-DATA file' }
	$worlds = @()
	for ($index = 0; $index -lt $worldCount; $index++) {
		$slot = $worldSlots[$index]
		$worlds += Format-TendencyValue (Read-TendencyField $data ('Tendency_World{0:00}_BlackWhite' -f $slot))
	}
	return "$($file.Directory.Name)  ·  character $(Format-TendencyValue (Read-TendencyField $data 'Tendency_Player_BlackWhite'))  ·  world W1..W5 $($worlds -join '/')"
}
# The five worlds the game actually has, in the game's own order, each paired with the save slot its
# tendency lives in. The slot numbers are NOT the world numbers, and that was measured rather than
# assumed: with one distinct value per slot the game's Tendency page answered
#   01 -> World 1 (Boletarian Palace)      05 -> World 2 (Stonefang Tunnel)
#   03 -> World 3 (Tower of Latria)        02 -> World 4 (Shrine of Storms)
#   04 -> World 5 (Valley of Defilement)
# Slots 00 and 06 move nothing on that page at all: 00 is the Nexus (the game keeps no world
# tendency for it) and 06 is the sixth world, which cannot be entered, so neither gets a row.
# An earlier version of this launcher assumed slot N was world N and wrote 4 into world 2 - that is
# exactly what put a value on the wrong world, so do not "tidy" this table back into 1,2,3,4,5.
$worldCount = 5
$worldLabels = @('W1  Boletarian Palace', 'W2  Stonefang Tunnel', 'W3  Tower of Latria',
	'W4  Shrine of Storms', 'W5  Valley of Defilement')
# The save slot behind each row above, in the same order as $worldLabels.
$worldSlots = @(1, 5, 3, 2, 4)
# What the save holds for those five worlds right now, in row order; an empty list when there is no
# save to read. It is what the boxes are filled from the first time, so an upgrade shows the values
# the game actually has instead of the one number this launcher used to keep for all of them.
function Get-SavedWorldTendencies {
	$files = @(Get-TendencySave)
	if ($files.Count -eq 0) { return @() }
	$data = $null
	try { $data = [System.IO.File]::ReadAllBytes($files[0].FullName) } catch { return @() }
	if ($data.Length -lt 32) { return @() }
	$values = @()
	for ($index = 0; $index -lt $worldCount; $index++) {
		$slot = $worldSlots[$index]
		$value = Read-TendencyField $data ('Tendency_World{0:00}_BlackWhite' -f $slot)
		if ($null -eq $value) { return @() }
		$values += [double]$value
	}
	return @($values)
}
# A stored setting is either the per-row list of today or the single number/tick of an older file.
function Read-WorldSetting($saved, [int]$index) {
	if ($saved -is [bool] -or $saved -is [string] -or $saved -is [int] -or $saved -is [long] -or
		$saved -is [double] -or $saved -is [decimal] -or $saved -is [single]) { return $saved }
	$list = @($saved)
	if ($index -lt $list.Count) { return $list[$index] }
	return $null
}
$worldPinned = @($false) * $worldCount
$worldInitial = @(0.0) * $worldCount
$seedWorlds = @()
if (-not $worldsInSettings) { $seedWorlds = @(Get-SavedWorldTendencies) }
# A settings file from the seven-slot launcher kept one entry per SAVE SLOT (0..6), while these rows
# are the five worlds. The length tells the two apart, and re-indexing through $worldSlots is what
# carries a user's numbers across the upgrade instead of putting them on the wrong world.
$storedWorlds = @($settings.tendencyWorlds)
$storedOn = @($settings.tendencyWorldOn)
$storedBySlot = ($storedWorlds.Count -eq 7 -and $storedOn.Count -eq 7)
for ($index = 0; $index -lt $worldCount; $index++) {
	$lookup = $index
	if ($storedBySlot) { $lookup = $worldSlots[$index] }
	$ticked = Read-WorldSetting $storedOn $lookup
	if ($null -ne $ticked) { $worldPinned[$index] = [bool]$ticked }
	$stored = Read-WorldSetting $storedWorlds $lookup
	if ($null -ne $stored) { $worldInitial[$index] = ConvertTo-TendencyNumber $stored }
	elseif ($seedWorlds.Count -eq $worldCount) { $worldInitial[$index] = [double]$seedWorlds[$index] }
}
$settings.tendencyWorldOn = @($worldPinned)
$settings.tendencyWorlds = @($worldInitial)
# Write the values into the save and fix the checksum. A save whose own checksum does not verify is
# left untouched rather than rewritten - that is a file this launcher does not understand. The
# original is kept next to it as USR-DATA.bak.
function Write-TendencyToSave {
	$script:tendencyWriteOk = $false
	$wanted = @(Get-WantedTendencies)
	if ($wanted.Count -eq 0) { return '' }
	$files = @(Get-TendencySave)
	if ($files.Count -eq 0) { return 'no character save was found under _SaveData, so nothing was written' }
	$file = $files[0]
	$data = $null
	try { $data = [System.IO.File]::ReadAllBytes($file.FullName) } catch { return "the save could not be opened (is the game still running?): $($_.Exception.Message)" }
	if ($data.Length -lt 32) { return "$($file.Name) is too short to be a USR-DATA save" }
	$stored = [System.BitConverter]::ToUInt32($data, 4)
	if ($stored -ne [KytyAddons.TendencySave]::Fnv1a32($data, 16, $data.Length - 16)) {
		return "$($file.Name) does not pass its own checksum, so nothing was written"
	}
	$changed = 0
	foreach ($field in $wanted) {
		$at = [KytyAddons.TendencySave]::Find($data, [KytyAddons.TendencySave]::KeyOf($field.Name), 0x0A)
		if ($at -eq -2) { return "$($file.Name) holds more than one $($field.Name) entry, so nothing was written" }
		$bytes = [KytyAddons.TendencySave]::F32($field.Value)
		if ($at -lt 0) {
			# A key this save does not carry yet is added where the game keeps its world block. The
			# game looks a field up by hashed name, so its place inside the table does not matter.
			$anchor = [KytyAddons.TendencySave]::Find($data, [KytyAddons.TendencySave]::KeyOf('Tendency_World00_BlackWhite'), 0x0A)
			if ($anchor -lt 0) { return "$($file.Name) has no $($field.Name) entry and nowhere to add one, so nothing was written" }
			$entry = New-Object System.Collections.Generic.List[byte]
			$entry.AddRange([KytyAddons.TendencySave]::U32([KytyAddons.TendencySave]::KeyOf($field.Name)))
			$entry.Add([byte]0x0A)
			$entry.AddRange($bytes)
			$table = New-Object System.Collections.Generic.List[byte]
			$table.AddRange($data)
			$table.InsertRange($anchor, $entry)
			$data = $table.ToArray()
			$changed++
			continue
		}
		$same = $true
		for ($i = 0; $i -lt 4; $i++) { if ($data[$at + 5 + $i] -ne $bytes[$i]) { $same = $false; break } }
		if ($same) { continue }
		[Array]::Copy($bytes, 0, $data, $at + 5, 4)
		$changed++
	}
	if ($changed -eq 0) { $script:tendencyWriteOk = $true; return "$($file.Directory.Name) already held these values" }
	$payload = $data.Length - 16
	[Array]::Copy([KytyAddons.TendencySave]::U32([KytyAddons.TendencySave]::Fnv1a32($data, 16, $payload)), 0, $data, 4, 4)
	[Array]::Copy([KytyAddons.TendencySave]::U32([uint32]$payload), 0, $data, 8, 4)
	try {
		[System.IO.File]::WriteAllBytes($file.FullName + '.bak', [System.IO.File]::ReadAllBytes($file.FullName))
		[System.IO.File]::WriteAllBytes($file.FullName, $data)
	} catch { return "the save could not be written (is the game still running?): $($_.Exception.Message)" }
	$script:tendencyWriteOk = $true
	return "wrote $changed value(s) into $($file.Directory.Name)\USR-DATA (backup: USR-DATA.bak)"
}

# Frame generation needs NVIDIA's Streamline runtime, which no release ships: the Streamline SDK
# (github.com/NVIDIA-RTX/Streamline/releases) chosen with "Streamline..." (settings: streamline), else a "streamline"
# folder next to the emulator, else the SDK beside a local build (_Build\deps\streamline\sdk). The emulator loads
# only NVIDIA's own sl.interposer.dll (run-windows -StreamlineDir).
$exe = if (Test-Path "$root\kyty_emulator.exe") { "$root\kyty_emulator.exe" } else { "$root\_Build\windows\kyty_emulator.exe" }
$streamlineSdkUrl = 'https://github.com/NVIDIA-RTX/Streamline/releases'
# The runtime's folder in $dir (the folder itself or its bin\x64) when its sl.interposer.dll is signed by NVIDIA;
# $null otherwise.
function Find-Streamline([string]$dir) {
	if (!$dir) { return $null }
	foreach ($folder in @($dir, (Join-Path $dir 'bin\x64'))) {
		$file = Join-Path $folder 'sl.interposer.dll'
		if (Test-Path -LiteralPath $file) {
			$signature = Get-AuthenticodeSignature -LiteralPath $file
			if ($signature.Status -eq 'Valid' -and $signature.SignerCertificate.Subject -match 'O=NVIDIA Corporation') { return $folder }
			return $null
		}
	}
	return $null
}
function Resolve-Streamline {
	if ($settings.streamline) { return Find-Streamline $settings.streamline }
	if ($env:KYTY_STREAMLINE_DIR) { return Find-Streamline $env:KYTY_STREAMLINE_DIR }
	foreach ($dir in @((Join-Path (Split-Path $exe) 'streamline'), (Join-Path (Split-Path (Split-Path $exe)) 'deps\streamline\sdk'))) {
		$found = Find-Streamline $dir
		if ($found) { return $found }
	}
	return $null
}
$streamline = Resolve-Streamline
# DLSS (the upscaler and frame generation) needs an NVIDIA RTX graphics card: with none (AMD, Intel, GeForce GTX) both
# rows stay off and the game's own TAA makes the picture, at the render height the game's TAA keeps.
$rtxGpu = try {
	[bool](Get-CimInstance Win32_VideoController | Where-Object { $_.Name -match 'NVIDIA' -and $_.Name -match '\bRTX\b' })
} catch { $false }
$frameGenAvailable = [bool]$streamline -and $rtxGpu

function Get-PlayCommand {
	$size = $settings.resolution -split 'x'
	$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$root\run-windows.ps1`"", '-Prompt', '-Follow',
		'-Width', $size[0], '-Height', $size[1], '-Language', $settings.language)
	if ($settings.fullscreen) { $arguments += '-Fullscreen'; if ($settings.aspect -and (Test-RunParam 'AspectFit')) { $arguments += '-AspectFit' } }
	if (!$settings.redzone -and (Test-RunParam 'NoRedZone')) { $arguments += '-NoRedZone' }
	if ($settings.fps120 -and (Test-RunParam 'Fps120')) { $arguments += '-Fps120' }
	# Presents wait for the display's refresh (Vulkan FIFO): no tearing, and G-SYNC/FreeSync displays keep adapting.
	if ($settings.vsync -and (Test-RunParam 'PresentMode')) { $arguments += @('-PresentMode', 'Fifo') }
	# HDR10 output when Windows HDR is on for the display; SDR otherwise.
	if ($settings.hdr -and (Test-RunParam 'Hdr')) { $arguments += '-Hdr' }
	$dlss = $frameGenAvailable -and $settings.upscaler -eq 'dlss'
	# The upscaler's own render height (with DLSS always passed: the PS5 Pro path's own height is 1512).
	$height = if ($dlss) { [int]$settings.render_dlss } else { [int]$settings.render }
	if ((Test-RunParam 'RenderHeight') -and $height -gt 0 -and ($height -ne 1440 -or $dlss)) { $arguments += @('-RenderHeight', $height) }
	if ($settings.ratio -in '21:9', '32:9' -and (Test-RunParam 'Aspect')) { $arguments += @('-Aspect', $settings.ratio) }
	if ($settings.quality -in 'low', 'lowest' -and (Test-RunParam 'Quality')) {
		$arguments += @('-Quality', $settings.quality)
		# v20261017 and newer shrink the large textures with the quality preset (Low: their largest level left
		# out, Lowest: the two largest). v20261016 and older have no -TextureReduce and leave that to the
		# emulator's own video-memory rule, so the switch is passed only where run-windows.ps1 declares it.
		if (Test-RunParam 'TextureReduce') {
			$textureReduce = if ($settings.quality -eq 'lowest') { 2 } else { 1 }
			$arguments += @('-TextureReduce', $textureReduce)
		}
	}
	if ($frameGenAvailable -and [int]$settings.framegen -ge 2 -and (Test-RunParam 'FrameGen')) {
		$arguments += @('-FrameGen', ([int]$settings.framegen - 1))
	}
	if ($dlss -and (Test-RunParam 'Upscaler')) { $arguments += @('-Upscaler', 'dlss') }
	if ($frameGenAvailable -and ([int]$settings.framegen -ge 2 -or $dlss) -and (Test-RunParam 'StreamlineDir')) {
		$arguments += @('-StreamlineDir', "`"$streamline`"")
	}
	# Cheats: run-windows.ps1 -Patch loads the file as kyty_emulator.exe --game-patch <json>
	# (an etaHEN/GoldHEN "mods" file); the emulator patches the game when it starts.
	if ($settings.cheats -and $settings.cheatFile -and (Test-RunParam 'Patch')) { $arguments += @('-Patch', "`"$(Get-SessionCheats)`"") }
	if ($settings.game) { $arguments += @('-Game', "`"$($settings.game)`"") }
	# The emulator's panel (KYTY_FPS_HUD), the safe GPU mode, the readout, the debug menu and the controller
	# volume all go through run-windows.ps1's own -Set switch (KEY=VALUE, several pairs separated by commas).
	# An environment variable set here
	# would NOT arrive: run-windows.ps1 builds the environment it gives kyty_emulator.exe from
	# launch.json, then overwrites the two it looks after itself -- this file's KYTY_GAME_CONVARS
	# would be replaced by the release's own default, which is exactly what happened before the
	# tendencies were passed this way (the game's log showed only "+doIndexBufferCulling=false").
	# KYTY_GAME_CONVARS is the list the emulator appends to the game's packagecmdlineargs.txt, one
	# "+line" each (src/loader/gameArgs.cpp); Demon's Souls hands every line to its own console.
	if (Test-RunParam 'Set') {
		$pairs = @()
		if ([int]$settings.hud -ge 1) { $pairs += "KYTY_FPS_HUD=$([Math]::Min([int]$settings.hud, 2))" }
		# Safe GPU mode: no overlapping compute dispatches ($safeGpuTip).
		if ($settings.safegpu) { $pairs += 'KYTY_COMPUTE_CHAIN=0' }
		$convars = @(Get-TendencyConvars)
		if ($convars.Count -gt 0) {
			$pairs += "KYTY_GAME_CONVARS=$(@(@($releaseGameConvars) + $convars | Where-Object { $_ }) -join ';')"
		}
		$pairs += @(Get-ControllerVolume)
		if ($pairs.Count -gt 0) { $arguments += @('-Set', "`"$($pairs -join ',')`"") }
	}
	# The console stays for the live log; after a crash it waits for a key.
	return "$powershellCommand " + ($arguments -join ' ') + ' & if !errorlevel! neq 0 pause'
}
function Get-PrecompileCommand([string]$switch = '') {
	$arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$root\precompile-windows.ps1`"")
	if ($switch) { $arguments += $switch }
	if ($settings.ecores -and $efficiencyMask -ne 0) { $arguments += @('-Affinity', $efficiencyMask) }
	if ($settings.game) { $arguments += @('-Game', "`"$($settings.game)`"") }
	return "$powershellCommand " + ($arguments -join ' ') + ' & pause'
}
function Save-Settings { $settings | ConvertTo-Json | Set-Content $settingsPath -Encoding UTF8 }
if ($ApplyTendency) {
	# Write the tendencies into the save and stop, without opening the window: for a run started some
	# other way, or to read the result off a console. The exit code is 0 when the save ends up in the
	# state the settings ask for.
	$wanted = @(Get-WantedTendencies)
	if ($wanted.Count -eq 0) {
		"nothing to do: no tendency box is ticked (tendencyWorldOn / tendencyCharacterOn in $settingsPath)"
		exit 0
	}
	$result = Write-TendencyToSave
	"tendency save:   $(Get-TendencyStatus)"
	"tendency writes: $(@($wanted | ForEach-Object { "$($_.Name)=$(Format-TendencyValue $_.Value)" }) -join ' ')"
	$result
	if ($script:tendencyWriteOk) { exit 0 } else { exit 1 }
}
if ($DryRun) {
	"play:       cmd /v:on /s /c `"$(Get-PlayCommand)`""
	"precompile: cmd /s /c `"$(Get-PrecompileCommand)`""
	"hints:      cmd /s /c `"$(Get-PrecompileCommand '-ExportHints')`""
	"efficiency cores: 0x{0:X}" -f $efficiencyMask
	"frame generation: $(if ($frameGenAvailable) { "NVIDIA's Streamline runtime in $streamline" } elseif (!$rtxGpu) { 'no NVIDIA RTX graphics card (DLSS off)' } else { "no NVIDIA-signed Streamline runtime (settings: '$($settings.streamline)')" })"
	$convars = @(Get-TendencyConvars)
	"convars:   " + $(if ($convars.Count -gt 0) { "$(@(@($releaseGameConvars) + $convars | Where-Object { $_ }) -join ';')" } else { "(none; the release's own default is '$releaseGameConvars')" })
	$volume = @(Get-ControllerVolume)
	"controller volume: " + $(if ($volume.Count -gt 0) { "$($volume -join ', ')" } else { '(the package default: the pad speaker at gain 8, the actuators at gain 1)' })
	"tendency save: $(Get-TendencyStatus)"
	$wanted = @(Get-WantedTendencies)
	"tendency writes: " + $(if ($wanted.Count -gt 0) { "$(@($wanted | ForEach-Object { "$($_.Name)=$(Format-TendencyValue $_.Value)" }) -join ' ')" } else { '(nothing - no tendency box is ticked)' })
	return
}

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type -Namespace KytyLauncher -Name Dpi -MemberDefinition '[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();'
[KytyLauncher.Dpi]::SetProcessDPIAware() | Out-Null
[System.Windows.Forms.Application]::EnableVisualStyles()

$form = New-Object System.Windows.Forms.Form -Property @{
	Text = 'KytyPS5 launcher'; FormBorderStyle = 'FixedDialog'; MaximizeBox = $false; StartPosition = 'CenterScreen'
	AutoSize = $true; AutoSizeMode = 'GrowAndShrink'; Font = New-Object System.Drawing.Font('Segoe UI', 9); Padding = '12,12,12,8'
}
$grid = New-Object System.Windows.Forms.TableLayoutPanel -Property @{ ColumnCount = 2; AutoSize = $true; Dock = 'Fill' }
$form.Controls.Add($grid)
# A row: a label, then the controls side by side. Rows land in $rowTable, so one section can point it
# at a grid of its own and have its rows sit inside a group box (that is how the Mods group is built).
$rowTable = $grid
function Add-Row($label, [object[]]$controls) {
	$rowTable.Controls.Add((New-Object System.Windows.Forms.Label -Property @{ Text = $label; AutoSize = $true; Anchor = 'Left'; Margin = '0,6,8,6' }))
	$row = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ AutoSize = $true; WrapContents = $false; Margin = '0,0,0,0' }
	$row.Controls.AddRange($controls)
	$rowTable.Controls.Add($row)
}

$game = New-Object System.Windows.Forms.TextBox -Property @{ Text = $settings.game; Width = 440 }
$browse = New-Object System.Windows.Forms.Button -Property @{ Text = 'Browse...'; AutoSize = $true }
$browseZar = New-Object System.Windows.Forms.Button -Property @{ Text = '.zar...'; AutoSize = $true }
Add-Row 'Game folder' @($game, $browse, $browseZar)
$title = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray' }
Add-Row '' @($title)
# A game: its folder (eboot.bin and sce_sys) or the folder packed into a ZArchive (a .zar file).
function Read-GameParam([string]$game) {
	if (!$game) { return $null }
	if (Test-Path -LiteralPath "$game\sce_sys\param.json") { return Get-Content -LiteralPath "$game\sce_sys\param.json" -Raw -Encoding UTF8 | ConvertFrom-Json }
	$tool = @("$root\kyty_shader_precompile.exe", "$root\_Build\windows\kyty_shader_precompile.exe") | Where-Object { Test-Path $_ } | Select-Object -First 1
	if ($game -notmatch '\.zar$' -or !(Test-Path -LiteralPath $game -PathType Leaf) -or !$tool) { return $null }
	$copy = [IO.Path]::GetTempFileName()
	try {
		& $tool --game $game --param $copy 2>$null | Out-Null
		if ($LASTEXITCODE -eq 0) { return Get-Content -LiteralPath $copy -Raw -Encoding UTF8 | ConvertFrom-Json }
	} catch {
	} finally {
		Remove-Item -LiteralPath $copy -ErrorAction SilentlyContinue
	}
	return $null
}
function Update-Title {
	$title.Text = 'Choose the folder with eboot.bin and sce_sys (the game dump), or a .zar archive of it.'
	try {
		$json = Read-GameParam $game.Text.Trim()
		if ($json) {
			$title.Text = '{0} ({1} {2})' -f $json.localizedParameters.($json.localizedParameters.defaultLanguage).titleName,
				$json.titleId, $json.contentVersion
		}
	} catch {}
}
$browse.Add_Click({
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{ Description = 'The game folder (eboot.bin, sce_sys)' }
	if ($game.Text -and (Test-Path -LiteralPath $game.Text -PathType Container)) { $dialog.SelectedPath = $game.Text }
	if ($dialog.ShowDialog($form) -eq 'OK') { $game.Text = $dialog.SelectedPath }
})
# The game folder packed into a ZArchive (zarchive.exe <folder> <file.zar>): read without extracting it.
$browseZar.Add_Click({
	$dialog = New-Object System.Windows.Forms.OpenFileDialog -Property @{ Title = 'The game folder packed into a ZArchive'; Filter = 'ZArchive (*.zar)|*.zar' }
	if ($game.Text -and (Test-Path -LiteralPath $game.Text -PathType Leaf)) { $dialog.InitialDirectory = Split-Path $game.Text }
	if ($dialog.ShowDialog($form) -eq 'OK') { $game.Text = $dialog.FileName }
})
$game.Add_TextChanged({ Update-Title })
Update-Title

# The picture's size, shape and detail, side by side: the aspect ratio offers the resolutions of its shape (a 21:9
# picture in a 3840x2160 window was stretched back to 16:9) and the render heights whose 3D the game holds (no larger
# than its own 3840x2160 in GPU tiles: 21:9 at 2160 ended it at start-up, 1864 drew it red; src/loader/demonsSoulsRenderSize.h).
$ratio = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205 }
$ratio.Items.AddRange($ratios)
$ratio.SelectedItem = ($ratios | Where-Object { ($_ -split ' ')[0] -eq [string]$settings.ratio } | Select-Object -First 1)
if ($ratio.SelectedIndex -lt 0) { $ratio.SelectedIndex = 0 }
$ratioNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0'
	Text = '21:9 and 32:9 show more to the sides; the HUD keeps its shape, menus and movies are stretched' }
function Get-Ratio { ([string]$ratio.SelectedItem -split ' ')[0] }
function Get-RatioAspect { switch (Get-Ratio) { '21:9' { 64.0 / 27.0 } '32:9' { 32.0 / 9.0 } default { 16.0 / 9.0 } } }
$resolution = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205 }
# The ratio's resolutions; `wanted` kept when it is one of them, else the one nearest its height.
function Update-Resolutions([string]$wanted) {
	$list = $resolutionsByRatio[(Get-Ratio)]
	$resolution.Items.Clear()
	$resolution.Items.AddRange($list)
	$height = [int](($wanted -split 'x')[1])
	$resolution.SelectedItem = if ($list -contains $wanted) { $wanted } else {
		$list | Sort-Object { [Math]::Abs([int](($_ -split 'x')[1]) - $height) } | Select-Object -First 1
	}
}
Update-Resolutions $settings.resolution
$render = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205 }
# The highest render height whose 3D at the ratio fits the game's render target memory, made for 3840x2160: no more of
# the GPU's 64 KiB tiles (256x128, 128x128, 128x64, 64x64 pixels) than 3840x2160 (the emulator's FitsRenderTargets).
function Get-MaxRenderHeight {
	$aspectValue = Get-RatioAspect
	for ($h = 2160; $h -ge 720; $h -= 8) {
		$w = [Math]::Floor($h * $aspectValue / 8.0 + 0.5) * 8
		$fits = $true
		foreach ($tile in @(@(256, 128), @(128, 128), @(128, 64), @(64, 64))) {
			$tiles = [Math]::Ceiling($w / $tile[0]) * [Math]::Ceiling($h / $tile[1])
			if ($tiles -gt [Math]::Ceiling(3840 / $tile[0]) * [Math]::Ceiling(2160 / $tile[1])) { $fits = $false }
		}
		if ($fits) { return $h }
	}
	720
}
# Each upscaler keeps its own render height (settings render, render_dlss): the row shows the height last chosen for the
# chosen upscaler ($renderWanted) among those the ratio allows; one above them shows as the highest allowed (and comes
# back with a ratio that allows it), one not in the list as the upscaler's default.
function Get-RenderFallback { if ($script:renderForDlss) { 1080 } else { 1440 } }
function Select-RenderHeight {
	$most = Get-MaxRenderHeight
	$allowed = @($renderHeights | Where-Object { [int](($_ -split ' ')[0]) -le $most })
	$script:fillingRender = $true
	try {
		$render.Items.Clear()
		$render.Items.AddRange($allowed)
		if ($script:renderWanted -gt $most) { $render.SelectedIndex = 0; return }
		foreach ($wanted in @($script:renderWanted, (Get-RenderFallback))) {
			$render.SelectedItem = ($allowed | Where-Object { ($_ -split ' ')[0] -eq [string]$wanted } | Select-Object -First 1)
			if ($render.SelectedIndex -ge 0) { return }
		}
		$render.SelectedIndex = 0
	} finally {
		$script:fillingRender = $false
	}
}
$renderNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
function Update-RenderNote {
	$h = [int](([string]$render.SelectedItem -split ' ')[0])
	$w = [Math]::Floor($h * (Get-RatioAspect) / 8.0 + 0.5) * 8
	$renderNote.Text = "Demon's Souls' 3D at ${w}x${h}; higher = sharper, needs more GPU"
}
$render.Add_SelectedIndexChanged({
	if (!$script:fillingRender) { $script:renderWanted = [int](([string]$render.SelectedItem -split ' ')[0]) }
	Update-RenderNote
})
$renderForDlss = $frameGenAvailable -and $settings.upscaler -eq 'dlss'
$renderWanted = [int]$(if ($renderForDlss) { $settings.render_dlss } else { $settings.render })
Select-RenderHeight
Update-RenderNote
$ratio.Add_SelectedIndexChanged({
	Update-Resolutions ([string]$resolution.SelectedItem)
	Select-RenderHeight
	Update-RenderNote
})
$upscaler = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205; Enabled = $frameGenAvailable }
$upscaler.Items.AddRange($upscalers)
$upscaler.SelectedIndex = if ($frameGenAvailable -and $settings.upscaler -eq 'dlss') { 1 } else { 0 }
$upscalerNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
function Update-UpscalerNote {
	$upscalerNote.Text = if ($frameGenAvailable) { 'DLSS: NVIDIA RTX; 1440 = Quality, 1080 = Performance, 2160 = DLAA' }
		elseif (!$rtxGpu) { 'DLSS needs an NVIDIA RTX graphics card: here the game''s own TAA' }
		else { 'needs NVIDIA''s Streamline SDK (choose its folder under Frame generation)' }
}
Update-UpscalerNote
(New-Object System.Windows.Forms.ToolTip -Property @{ AutoPopDelay = 30000 }).SetToolTip($upscaler,
	"Game: the PS5's performance mode, its 3D anti-aliased by the game's TAA at the render height and stretched to 4K.`n" +
	"DLSS: the game's own PS5 Pro mode, Sony's upscaler (PSSR) replaced by NVIDIA DLSS: the 3D at the render height (2688x1512`n" +
	"at 1512, the PS5 Pro's; 1080 at least) made a 3840x2160 image the game finishes at 4K (bloom, depth of field, the HUD).`n" +
	"Sharper than the stretch, at some GPU cost. The in-game Cinematic mode stays native 4K without DLSS.`n" +
	"Each upscaler keeps its own render height. DLSS starts at 1080: on an RTX 5090 about the frame rate of the game's TAA`n" +
	"at 1440, with a sharper 4K image.")
$upscaler.Add_SelectedIndexChanged({
	# The height chosen goes back to the upscaler it was for; the newly chosen one's is shown.
	if ($script:renderForDlss) { $settings.render_dlss = $script:renderWanted } else { $settings.render = $script:renderWanted }
	$script:renderForDlss = $upscaler.SelectedIndex -eq 1
	$script:renderWanted = [int]$(if ($script:renderForDlss) { $settings.render_dlss } else { $settings.render })
	Select-RenderHeight
	Update-RenderNote
})
Add-Row 'Resolution' @($resolution)
Add-Row 'Aspect ratio' @($ratio, $ratioNote)
Add-Row 'Render height' @($render, $renderNote)
Add-Row 'Upscaler' @($upscaler, $upscalerNote)
$fullscreen = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Fullscreen'; AutoSize = $true; Checked = [bool]$settings.fullscreen }
$aspect = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Keep the aspect ratio (black bars)'; AutoSize = $true; Checked = [bool]$settings.aspect }
$aspect.Enabled = $fullscreen.Checked
$fullscreen.Add_CheckedChanged({ $aspect.Enabled = $fullscreen.Checked })
Add-Row '' @($fullscreen, $aspect)
$language = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 320 }
$language.Items.AddRange($languages)
$language.SelectedIndex = [Math]::Max(0, [Math]::Min($languages.Count - 1, [int]$settings.language))
Add-Row 'Console language' @($language)

# --- Mods ----------------------------------------------------------------------------------------
# Everything that is a mod rather than a plain video/audio setting goes into this one group box: the
# cheat file the emulator patches the game with (and the mods already inside it) plus the switches
# KytyAddons adds on top - the Demon's Souls tendencies, the debug readout and menu, and the
# DualSense speaker and vibration levels. The rows below are added to the group's own grid until
# $rowTable is pointed back at the main one.
$mods = New-Object System.Windows.Forms.GroupBox -Property @{ Text = 'Mods'; AutoSize = $true
	AutoSizeMode = 'GrowAndShrink'; Padding = '10,6,10,10'; Margin = '0,8,0,4' }
$modGrid = New-Object System.Windows.Forms.TableLayoutPanel -Property @{ ColumnCount = 2; AutoSize = $true
	AutoSizeMode = 'GrowAndShrink'; Location = '0,0' }
$mods.Controls.Add($modGrid)
$grid.Controls.Add($mods)
$grid.SetColumnSpan($mods, 2)
$rowTable = $modGrid

# Cheats : run-windows.ps1 -Patch hands the chosen file to the emulator's --game-patch, an
# etaHEN/GoldHEN "mods" JSON that patches the game when it starts. The files live in <root>\cheats.
$cheatFolder = Join-Path $root 'cheats'
New-Item -ItemType Directory -Force -Path $cheatFolder | Out-Null
$patchSupported = Test-RunParam 'Patch'
$cheatFiles = @(Get-ChildItem -LiteralPath $cheatFolder -Filter '*.json' -File -ErrorAction SilentlyContinue |
	Sort-Object Name | ForEach-Object { $_.FullName })
if ($settings.cheatFile -and (Test-Path -LiteralPath $settings.cheatFile) -and $cheatFiles -notcontains $settings.cheatFile) {
	$cheatFiles = @($settings.cheatFile) + $cheatFiles
}
$cheats = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Cheats'; AutoSize = $true
	Checked = ([bool]$settings.cheats -and $patchSupported); Enabled = ($cheatFiles.Count -gt 0 -and $patchSupported) }
$cheatList = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 340 }
foreach ($file in $cheatFiles) { [void]$cheatList.Items.Add((Split-Path $file -Leaf)) }
$selected = 0
for ($index = 0; $index -lt $cheatFiles.Count; $index++) { if ($cheatFiles[$index] -eq $settings.cheatFile) { $selected = $index } }
if ($cheatList.Items.Count -gt 0) { $cheatList.SelectedIndex = $selected }
$cheatList.Enabled = $cheats.Checked
Add-Row 'Cheats' @($cheats, $cheatList)
if ($cheatFiles.Count -eq 0) {
	Add-Row '' @((New-Object System.Windows.Forms.Label -Property @{ Text = 'no cheat file in the cheats folder'; AutoSize = $true; ForeColor = 'Gray' }))
} elseif (!$patchSupported) {
	Add-Row '' @((New-Object System.Windows.Forms.Label -Property @{ Text = 'this version''s run-windows.ps1 has no -Patch switch'; AutoSize = $true; ForeColor = 'Gray' }))
}
# The chosen file's mods, one check box each (the description is the box's tool tip): what the run
# applies. Get-SessionCheats writes the boxes' states into a copy, so the file in cheats is never
# touched. Switching the file rebuilds the list; the boxes follow the Cheats check box.
$modTip = New-Object System.Windows.Forms.ToolTip -Property @{ AutoPopDelay = 30000; InitialDelay = 400 }
$modPanel = New-Object System.Windows.Forms.Panel -Property @{ AutoScroll = $true; Width = 520; Height = 170; Margin = '0,0,0,0' }
$modFlow = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ FlowDirection = 'TopDown'; WrapContents = $false
	AutoSize = $true; AutoSizeMode = 'GrowAndShrink'; Dock = 'Top' }
$modPanel.Controls.Add($modFlow)
$modBoxes = New-Object System.Collections.Generic.List[System.Windows.Forms.CheckBox]
$modCount = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '10,7,0,7' }
function Update-ModCount {
	$on = @($modBoxes | Where-Object { $_.Checked }).Count
	$modCount.Text = if ($modBoxes.Count -eq 0) { '' } else { "$on of $($modBoxes.Count) on" }
}
function Update-ModList {
	$modFlow.Controls.Clear()
	$modBoxes.Clear()
	$file = if ($cheatList.SelectedIndex -ge 0 -and $cheatList.SelectedIndex -lt $cheatFiles.Count) { $cheatFiles[$cheatList.SelectedIndex] } else { '' }
	foreach ($mod in (Get-CheatMods $file)) {
		$key = Get-ModKey $file $mod.Name
		$on = if ($settings.modStates.Contains($key)) { [bool]$settings.modStates[$key] } else { $mod.On }
		$box = New-Object System.Windows.Forms.CheckBox -Property @{ Text = $mod.Name; Tag = $mod.Name; AutoSize = $true
			MaximumSize = New-Object System.Drawing.Size(490, 0); Checked = $on; Margin = '0,2,0,2' }
		if ($mod.Description) { $modTip.SetToolTip($box, $mod.Description) }
		$box.Add_CheckedChanged({ Update-ModCount })
		[void]$modFlow.Controls.Add($box)
		$modBoxes.Add($box)
	}
	# Tall enough for every box, at most 310 px (the panel scrolls beyond that).
	$modPanel.Height = [Math]::Min(310, [Math]::Max(56, $modBoxes.Count * 23 + 10))
	Update-ModCount
}
$modAll = New-Object System.Windows.Forms.Button -Property @{ Text = 'Select all'; AutoSize = $true; Margin = '0,0,6,0' }
$modNone = New-Object System.Windows.Forms.Button -Property @{ Text = 'Select none'; AutoSize = $true; Margin = '0,0,12,0' }
$modAll.Add_Click({ foreach ($box in $modBoxes) { $box.Checked = $true } })
$modNone.Add_Click({ foreach ($box in $modBoxes) { $box.Checked = $false } })
$modButtons = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ AutoSize = $true; WrapContents = $false; Margin = '0,0,0,0' }
$modButtons.Controls.AddRange(@($modAll, $modNone, $modCount))
Add-Row '' @($modPanel)
Add-Row '' @($modButtons)
$cheatList.Add_SelectedIndexChanged({ Update-ModList })
$cheats.Add_CheckedChanged({ $cheatList.Enabled = $cheats.Checked; $modPanel.Enabled = $cheats.Checked; $modButtons.Enabled = $cheats.Checked })
$modPanel.Enabled = $cheats.Checked
$modButtons.Enabled = $cheats.Checked
Update-ModList

# Red-zone protection and the video toggles below are ordinary settings rather than mods, so their
# rows go back into the main grid (the Mods group keeps whatever was added to $modGrid).
$rowTable = $grid
$redzone = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Red-zone protection (recommended)'; AutoSize = $true; Checked = [bool]$settings.redzone }
Add-Row '' @($redzone)
$fps120 = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Up to 120 fps (the game''s own frames; movies stay at 60)'; AutoSize = $true; Checked = [bool]$settings.fps120 }
Add-Row '' @($fps120)
$vsync = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'VSync (no screen tearing; adaptive sync displays keep it)'; AutoSize = $true; Checked = [bool]$settings.vsync }
Add-Row '' @($vsync)
# HDR : run-windows.ps1 -Hdr -> kyty_emulator.exe --hdr. Only a version that declares the switch has
# the row, so an older release does not show an option that would do nothing.
$hdr = $null
if (Test-RunParam 'Hdr') {
	$hdr = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'HDR (turn on "Use HDR" in Windows display settings first)'; AutoSize = $true
		Checked = [bool]$settings.hdr }
	Add-Row '' @($hdr)
}

# Back inside the Mods group for the addon switches.
$rowTable = $modGrid

# Tendency : the game's own values for world tendency and character tendency. They are floats on the
# game's own -200 .. +200 scale, 0 being neutral. World tendency is one value per world - the five
# worlds the game has, each on its own save slot, see $worldLabels/$worldSlots above - and each is
# written on its own, so a world can be set without dragging the other ones along. The game reads
# them out of the character save, so the launcher writes them there before the emulator starts and a
# change applies on the next start, not at once.
#
# The order matters, and it is spelled out rather than left to a -Property hashtable: Minimum/Maximum
# have to be in place before Value, because a NumericUpDown refuses a value outside the range it
# currently has. A saved 200 once landed while the maximum was still the default 100 and threw the
# window away on every start, which is why every setter below is on its own line.
function New-TendencyBox($saved) {
	$box = New-Object System.Windows.Forms.NumericUpDown
	$box.DecimalPlaces = 0
	$box.Minimum = -200
	$box.Maximum = 200
	$box.Increment = 20
	$box.Width = 74
	$box.Value = [decimal](ConvertTo-TendencyNumber $saved)
	return $box
}
# The five worlds as a two-wide table: a tick, a number, a tick, a number. Ticking a world is what
# pins it; the number beside an unticked world stays grey, and that world is not written at all.
$worldGrid = New-Object System.Windows.Forms.TableLayoutPanel -Property @{ ColumnCount = 4; RowCount = 3
	AutoSize = $true; AutoSizeMode = 'GrowAndShrink'; Margin = '0,0,0,0' }
$autoSize = [System.Windows.Forms.SizeType]::AutoSize
for ($column = 0; $column -lt 4; $column++) { $worldGrid.ColumnStyles.Add((New-Object System.Windows.Forms.ColumnStyle $autoSize)) }
for ($row = 0; $row -lt 3; $row++) { $worldGrid.RowStyles.Add((New-Object System.Windows.Forms.RowStyle $autoSize)) }
$tendencyWorldOn = @()
$tendencyWorlds = @()
for ($index = 0; $index -lt $worldCount; $index++) {
	$on = New-Object System.Windows.Forms.CheckBox -Property @{ Text = $worldLabels[$index]; AutoSize = $true; Checked = [bool]$worldPinned[$index] }
	$seed = $worldInitial[$index]
	$box = New-TendencyBox $seed
	$box.Enabled = [bool]$worldPinned[$index]
	$tendencyWorldOn += $on
	$tendencyWorlds += $box
	$worldGrid.Controls.Add($on)
	$worldGrid.Controls.Add($box)
}
# All seven share one handler, and it reads the two lists from script scope: a scriptblock built
# inside the loop above would not do - PowerShell resolves a handler's variables when the event
# fires, by which time the loop is long over and the loop's own names hold the last row.
function Sync-WorldBoxes { for ($index = 0; $index -lt $worldCount; $index++) { $tendencyWorlds[$index].Enabled = $tendencyWorldOn[$index].Checked } }
foreach ($on in $tendencyWorldOn) { $on.Add_CheckedChanged({ Sync-WorldBoxes }) }
Add-Row 'Tendency' @($worldGrid)
$tendencyCharacterOn = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Character tendency'; AutoSize = $true
	Checked = [bool]$settings.tendencyCharacterOn }
$tendencyCharacter = New-TendencyBox $settings.tendencyCharacter
$tendencyCharacter.Enabled = [bool]$settings.tendencyCharacterOn
$tendencyCharacterNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0'
	Text = 'the same scale (-200 the dark path, +200 pure white), written into the save before launching' }
Add-Row '' @($tendencyCharacterOn, $tendencyCharacter, $tendencyCharacterNote)
$tendencyCharacterOn.Add_CheckedChanged({ $tendencyCharacter.Enabled = $tendencyCharacterOn.Checked })
# Which save the numbers go into and what it holds right now. It is read when the window opens, so a
# write is confirmed by opening the launcher again; the values are also there for a run that has not
# been asked to change anything.
$tendencySaveNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'DimGray'; Margin = '6,2,0,0' }
Add-Row '' @($tendencySaveNote)
function Update-TendencyNote { $tendencySaveNote.Text = Get-TendencyStatus }
Update-TendencyNote
Add-Row '' @((New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'
	Text = '-200 pure black ... 0 neutral ... +200 pure white; a tick pins that one world and it is written every launch, an unticked world is left as the game has it' }))
$tendencyDebug = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Show the numbers next to the tendency icons (the game''s own readout)'; AutoSize = $true
	Checked = [bool]$settings.tendencyDebug }
Add-Row '' @($tendencyDebug)
# The debug menu is the only place both tendencies can be read and changed *while playing*: it has a
# "CP11 Tendency" page with World Tendency and Character Tendency. On this build the menu is LOCKED -
# the game's only entry point is the console shortcut in misc\dsshortcutbuttons.xml, the emulator has
# no key for it, and the whole input routine behind it is dead code. What actually opens it is the
# "Debug menu: open in game" cheat mod; this switch only leaves the game's own
# "cp11_toggleDebugMenu = true" in place for the moment the cheat has unlocked the menu.
$debugMenu = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Ask for the debug menu at boot (the menu itself comes from the "Debug menu: open in game" cheat)'; AutoSize = $true
	Checked = [bool]$settings.debugMenu }
Add-Row '' @($debugMenu)
Add-Row '' @((New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'
	Text = 'the way in is the cheat mod of that name - tick it in the cheats panel; this build has no key for the menu' }))
# The DualSense's speaker and its actuators, each as a percentage of the level the package already
# uses for it (100 % = what libs/dualSenseHaptics.cpp ships with). The percentages are held to 400 %
# because the two routes stop at gain 64 and gain 4; the odd 25 % step is what keeps every value a
# whole gain. Unticked means "not passed at all", which is the package's own default.
function New-VolumeBox($saved) {
	$box = New-Object System.Windows.Forms.NumericUpDown
	$box.DecimalPlaces = 0
	$box.Minimum = 0
	$box.Maximum = 400
	$box.Increment = 25
	$box.Width = 74
	# A missing or unusable value falls back to the default rather than to a mute or to a throw.
	# [double]::TryParse always writes its out parameter - it turns 'abc' into 0 and can hand back a
	# NaN - so its result is checked first, and the range test is written so that a NaN fails it.
	$percent = 100.0
	if (-not [double]::TryParse([string]$saved, [ref]$percent)) { $percent = 100.0 }
	if (-not ($percent -ge 0.0 -and $percent -le 400.0)) { $percent = 100.0 }
	$box.Value = [decimal]$percent
	return $box
}
$dsSpeakerOn = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Speaker'; AutoSize = $true
	Checked = [bool]$settings.dualSenseSpeakerOn }
$dsSpeaker = New-VolumeBox $settings.dualSenseSpeaker
$dsSpeaker.Enabled = [bool]$settings.dualSenseSpeakerOn
$dsSpeakerNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0'
	Text = '% of the pad''s own speaker level - 100 % is the package default, 0 % mutes it (DualSense only)' }
Add-Row 'Controller volume' @($dsSpeakerOn, $dsSpeaker, $dsSpeakerNote)
$dsSpeakerOn.Add_CheckedChanged({ $dsSpeaker.Enabled = $dsSpeakerOn.Checked })
$dsHapticsOn = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Vibration'; AutoSize = $true
	Checked = [bool]$settings.dualSenseHapticsOn }
$dsHaptics = New-VolumeBox $settings.dualSenseHaptics
$dsHaptics.Enabled = [bool]$settings.dualSenseHapticsOn
$dsHapticsNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0'
	Text = '% of the strength the package gives the pad''s actuators - 100 % is the default, 0 % stops them' }
Add-Row '' @($dsHapticsOn, $dsHaptics, $dsHapticsNote)
$dsHapticsOn.Add_CheckedChanged({ $dsHaptics.Enabled = $dsHapticsOn.Checked })
# Only the readout, the debug menu and the controller volume travel through run-windows.ps1 -Set; the
# tendency values themselves go into the save, so they work either way. A release without that switch
# loses those controls: disabled controls with a reason beat controls that quietly do nothing.
if (!(Test-RunParam 'Set')) {
	foreach ($control in @($tendencyDebug, $debugMenu, $dsSpeakerOn, $dsSpeaker, $dsHapticsOn, $dsHaptics)) { $control.Enabled = $false }
	Add-Row '' @((New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'
		Text = 'this version''s run-windows.ps1 has no -Set switch, so the readout, the debug menu and the controller volume cannot be passed' }))
}

# The Mods group ends here; the video settings that follow are rows of the main grid again.
$rowTable = $grid

# Safe GPU mode (v20261019): KYTY_COMPUTE_CHAIN=0, no overlapping compute dispatches ($safeGpuTip).
$safeGpu = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Safe GPU mode: prevents GPU-hang crashes and blue screens, but the frame rate is about 37% lower'; AutoSize = $true; Checked = [bool]$settings.safegpu }
(New-Object System.Windows.Forms.ToolTip -Property @{ AutoPopDelay = 30000 }).SetToolTip($safeGpu, $safeGpuTip)
Add-Row '' @($safeGpu)
$quality = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 205 }
$quality.Items.AddRange($qualities)
$quality.SelectedItem = ($qualities | Where-Object { ($_ -split ' ')[0] -eq [string]$settings.quality } | Select-Object -First 1)
if ($quality.SelectedIndex -lt 0) { $quality.SelectedIndex = 0 }
$qualityNote = New-Object System.Windows.Forms.Label -Property @{ Text = 'shorter shadows, simpler detail, smaller textures; faster on weaker PCs'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
$qualityTips = New-Object System.Windows.Forms.ToolTip
$qualityTips.SetToolTip($quality, "Standard: the PS5's picture. With less than 12 GB of video memory, large textures leave out their largest level`n(half the size per side) so that they fit.`nLow: shorter sun shadows, simpler distant detail, textures half the size per side.`nLowest: shorter still, no ambient shadowing or torch shadows, textures a quarter the size per side.")
Add-Row 'Graphics' @($quality, $qualityNote)
$frameGen = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160; Enabled = $frameGenAvailable }
$frameGen.Items.AddRange($frameGens)
$frameGen.SelectedItem = if ($frameGenAvailable -and [int]$settings.framegen -ge 2) { "$([int]$settings.framegen)x" } else { 'Off' }
if ($frameGen.SelectedIndex -lt 0) { $frameGen.SelectedIndex = 0 }
$frameGenFolder = New-Object System.Windows.Forms.Button -Property @{ Text = 'Streamline...'; AutoSize = $true }
$frameGenNote = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
function Update-FrameGenNote {
	$frameGenNote.Text = if ($frameGenAvailable) { 'DLSS; NVIDIA RTX 40 or newer (3x and up: RTX 50)' }
		elseif (!$rtxGpu) { 'DLSS: needs an NVIDIA RTX 40 or newer graphics card' }
		else { 'needs NVIDIA''s Streamline SDK: download it, then choose its folder' }
}
Update-FrameGenNote
$frameGenTips = New-Object System.Windows.Forms.ToolTip
$frameGenTips.SetToolTip($frameGen, "Shown frames = the game's frames x the multiplier. With VSync on, they are capped at the display's refresh`n(a 60 Hz display at 2x runs the game at 30 fps). The game's frames stay at 60 with 'Up to 120 fps' too:`nframe generation needs them evenly spaced.")
$frameGenTips.SetToolTip($frameGenFolder, "The NVIDIA Streamline SDK (a release zip from $streamlineSdkUrl), unpacked: its folder or its bin\x64.`nOnly NVIDIA-signed files are used; nothing of NVIDIA's comes with the emulator.")
$frameGenFolder.Add_Click({
	$dialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
		Description = "The unpacked NVIDIA Streamline SDK ($streamlineSdkUrl), or its bin\x64 folder" }
	if ($settings.streamline -and (Test-Path -LiteralPath $settings.streamline)) { $dialog.SelectedPath = $settings.streamline }
	if ($dialog.ShowDialog($form) -ne 'OK') { return }
	$found = Find-Streamline $dialog.SelectedPath
	if (!$found) {
		[void][System.Windows.Forms.MessageBox]::Show($form, "No sl.interposer.dll signed by NVIDIA in that folder or its bin\x64.`nDownload the Streamline SDK from $streamlineSdkUrl and choose the unpacked folder.", 'Frame generation')
		return
	}
	$settings.streamline = $dialog.SelectedPath
	$script:streamline = $found
	# (Without an NVIDIA RTX graphics card the folder is kept, the rows stay off.)
	$script:frameGenAvailable = $rtxGpu
	$frameGen.Enabled = $rtxGpu
	$upscaler.Enabled = $rtxGpu
	Update-FrameGenNote
	Update-UpscalerNote
})
Add-Row 'Frame generation' @($frameGen, $frameGenFolder, $frameGenNote)
$hud = New-Object System.Windows.Forms.ComboBox -Property @{ DropDownStyle = 'DropDownList'; Width = 160 }
$hud.Items.AddRange($overlays)
# (An older launcher saved true for the frame rate.)
$hud.SelectedIndex = [Math]::Max(0, [Math]::Min($overlays.Count - 1, [int]$settings.hud))
$hudNote = New-Object System.Windows.Forms.Label -Property @{ Text = 'top right: frame rate and frame times; detailed: GPU, CPU, memory. F8 in the game switches it'; AutoSize = $true; ForeColor = 'Gray'; Margin = '6,6,0,0' }
Add-Row 'Overlay' @($hud, $hudNote)
$ecores = New-Object System.Windows.Forms.CheckBox -Property @{ Text = 'Precompile on the efficiency cores only (slower, the PC stays responsive)'; AutoSize = $true
	Checked = ([bool]$settings.ecores -and $efficiencyMask -ne 0); Enabled = ($efficiencyMask -ne 0) }
Add-Row '' @($ecores)

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel -Property @{ AutoSize = $true; Margin = '0,10,0,0' }
$play = New-Object System.Windows.Forms.Button -Property @{ Text = 'Play'; AutoSize = $true; Font = New-Object System.Drawing.Font('Segoe UI', 9, [System.Drawing.FontStyle]::Bold) }
$precompile = New-Object System.Windows.Forms.Button -Property @{ Text = 'Precompile shaders'; AutoSize = $true }
$share = New-Object System.Windows.Forms.Button -Property @{ Text = 'Export shader hints'; AutoSize = $true }
(New-Object System.Windows.Forms.ToolTip).SetToolTip($share, ('The shaders your play recorded, without the game''s code, as my-hints-<game>.hints: ' +
	'attached to a GitHub issue, the next packages precompile them for everyone.'))
$logs = New-Object System.Windows.Forms.Button -Property @{ Text = 'Logs folder'; AutoSize = $true }
$readme = New-Object System.Windows.Forms.Button -Property @{ Text = 'README'; AutoSize = $true }
$buttons.Controls.AddRange(@($play, $precompile, $share, $logs, $readme))
$grid.Controls.Add($buttons)
$grid.SetColumnSpan($buttons, 2)
$credit = New-Object System.Windows.Forms.Label -Property @{ AutoSize = $true; ForeColor = 'Gray'; Margin = '0,8,0,0'
	Text = 'Settings follow the KytyPS5 launcher (src/launcher) by the KytyPS5 developers. The Mods group (cheat file, tendencies, debug switches, controller volume) added by KytyAddons.' }
$grid.Controls.Add($credit)
$grid.SetColumnSpan($credit, 2)
$form.AcceptButton = $play

function Read-Form {
	$settings.game       = $game.Text.Trim()
	$settings.resolution = [string]$resolution.SelectedItem
	$settings.fullscreen = $fullscreen.Checked
	$settings.aspect     = $aspect.Checked
	$settings.language   = $language.SelectedIndex
	$settings.redzone    = $redzone.Checked
	$settings.fps120     = $fps120.Checked
	$settings.vsync      = $vsync.Checked
	if ($hdr) { $settings.hdr = $hdr.Checked }
	$settings.safegpu    = $safeGpu.Checked
	# Each upscaler keeps its own render height (render for the game's TAA, render_dlss for DLSS); a
	# release without -RenderHeight has no such row and keeps whatever it was saved with.
	if (Test-RunParam 'RenderHeight') {
		$height = [int](([string]$render.SelectedItem -split ' ')[0])
		if ($renderForDlss) { $settings.render_dlss = $height } else { $settings.render = $height }
	}
	$settings.ratio      = ([string]$ratio.SelectedItem -split ' ')[0]
	$settings.quality    = ([string]$quality.SelectedItem -split ' ')[0].ToLowerInvariant()
	# (Kept as it was where the DLLs are missing.)
	if ($frameGenAvailable) { $settings.framegen = if ($frameGen.SelectedIndex -gt 0) { $frameGen.SelectedIndex + 1 } else { 0 } }
	$settings.hud        = $hud.SelectedIndex
	if ($frameGenAvailable) { $settings.upscaler = if ($upscaler.SelectedIndex -eq 1) { 'dlss' } else { '' } }
	$settings.ecores     = $ecores.Checked
	# Tendency is stored as the plain float the game uses, on its own -200 .. +200 scale with 0 as
	# neutral; the number boxes are integer, so what is written back is a whole number too. The world
	# side is one entry per slot in the game's own order, and the tick is what says that world is
	# pinned - an unticked world is never written, so its number there does not matter.
	$pinned = @()
	$values = @()
	for ($index = 0; $index -lt $worldCount; $index++) {
		$pinned += [bool]($tendencyWorldOn[$index].Checked)
		$values += [Math]::Round([double]($tendencyWorlds[$index].Value), 0)
	}
	$settings.tendencyWorldOn      = $pinned
	$settings.tendencyWorlds       = $values
	$settings.tendencyCharacterOn  = $tendencyCharacterOn.Checked
	$settings.tendencyCharacter    = [Math]::Round([double]$tendencyCharacter.Value, 0)
	$settings.tendencyDebug        = $tendencyDebug.Checked
	$settings.debugMenu            = $debugMenu.Checked
	# The controller volume is kept as whole percentages of the package's own gain (100 = as shipped).
	$settings.dualSenseSpeakerOn   = $dsSpeakerOn.Checked
	$settings.dualSenseSpeaker     = [Math]::Round([double]$dsSpeaker.Value, 0)
	$settings.dualSenseHapticsOn   = $dsHapticsOn.Checked
	$settings.dualSenseHaptics     = [Math]::Round([double]$dsHaptics.Value, 0)
	$settings.cheats     = $cheats.Checked -and $patchSupported
	if ($cheatList.SelectedIndex -ge 0 -and $cheatList.SelectedIndex -lt $cheatFiles.Count) {
		$settings.cheatFile = $cheatFiles[$cheatList.SelectedIndex]
	}
	# Each mod's switch of the chosen cheat file, as "<file name>::<mod name>" -> bool.
	if ($settings.cheatFile) {
		foreach ($box in $modBoxes) { $settings.modStates[(Get-ModKey $settings.cheatFile ([string]$box.Tag))] = $box.Checked }
	}
	Save-Settings
}
# Left-over guard ----------------------------------------------------------------------------------
# The emulator commits a 13.5 GB backing store for the guest when it starts, and gives it back only
# when the process really exits. A run that hangs while exiting keeps it, and once such a process is
# stuck in the driver it cannot be ended at all. The next start then dies at "could not reserve 13824
# MB for guest direct memory" before any window appears, which reads exactly like the option that was
# just changed being broken. Ask here instead, where the process can be named and its memory counted.
function Get-LeftoverEmulator {
	$name = [System.IO.Path]::GetFileNameWithoutExtension($exe)
	foreach ($process in @(Get-Process -Name $name -ErrorAction SilentlyContinue)) {
		$started = 'an unknown time'
		try { $started = $process.StartTime.ToString('HH:mm') } catch { }
		[pscustomobject]@{
			Id        = $process.Id
			Started   = $started
			Committed = $process.PrivateMemorySize64
			Threads   = $process.Threads.Count
			Hung      = ($process.MainWindowHandle -eq 0) -and (-not $process.Responding)
		}
	}
}
function Format-Gigabytes([double]$bytes) { return '{0:N1} GB' -f ($bytes / 1GB) }
# $true when the launcher may start. $false when the user cancelled, or when a left-over process
# survived being ended - that one has to be cleared by a reboot.
function Confirm-EmulatorIdle {
	$left = @(Get-LeftoverEmulator)
	if ($left.Count -eq 0) { return $true }
	$report = ($left | ForEach-Object {
		'  PID {0}: {1} committed, started {2}, {3} thread(s)' -f $_.Id, (Format-Gigabytes $_.Committed), $_.Started, $_.Threads
	}) -join "`r`n"
	$hung = @($left | Where-Object { $_.Hung })
	if ($hung.Count -gt 0) {
		$text = "An earlier run of the emulator is still holding its memory:`r`n`r`n$report`r`n`r`nThat process has no window and does not answer, so it most likely hung while exiting. It keeps about 13.5 GB committed, and a new start fails at `"could not reserve 13824 MB`" before any window appears.`r`n`r`nEnd it and start anyway?"
	} else {
		$text = "The emulator is already running:`r`n`r`n$report`r`n`r`nA second copy asks for another 13.5 GB of committed memory. End the running one and start a fresh one?"
	}
	$answer = [System.Windows.Forms.MessageBox]::Show($text, 'KytyPS5 launcher', 'YesNoCancel', 'Warning')
	if ($answer -eq [System.Windows.Forms.DialogResult]::Cancel) { return $false }
	if ($answer -eq [System.Windows.Forms.DialogResult]::No) { return $true }
	foreach ($process in $left) {
		try { Stop-Process -Id $process.Id -Force -ErrorAction Stop } catch { }
	}
	Start-Sleep -Milliseconds 800
	$still = @(Get-LeftoverEmulator)
	if ($still.Count -eq 0) { return $true }
	$ids = ($still | ForEach-Object { "PID $($_.Id)" }) -join ', '
	[System.Windows.Forms.MessageBox]::Show("$ids did not end. A process stuck in the graphics driver cannot be stopped from here - reboot Windows to release its memory, then start the emulator again.", 'KytyPS5 launcher', 'OK', 'Error') | Out-Null
	return $false
}

$play.Add_Click({
	if (-not (Confirm-EmulatorIdle)) { return }
	Read-Form
	# The tendencies go into the save before the emulator starts, so the value is in place for the
	# load that follows. A failure is shown rather than swallowed - a silently unwritten save is
	# exactly the thing this used to look like.
	$asked = (@(Get-WantedTendencies)).Count -gt 0
	$result = Write-TendencyToSave
	Update-TendencyNote
	if ($asked -and -not $script:tendencyWriteOk) {
		[System.Windows.Forms.MessageBox]::Show("The tendency settings were not applied.`r`n`r`n$result", 'KytyPS5 launcher') | Out-Null
	}
	Start-Process $cmd -ArgumentList "/v:on /s /c `"$(Get-PlayCommand)`"" -WorkingDirectory $root
	$form.Close()
})
$precompile.Add_Click({
	if (-not (Confirm-EmulatorIdle)) { return }
	Read-Form
	Start-Process $cmd -ArgumentList "/s /c `"$(Get-PrecompileCommand)`"" -WorkingDirectory $root
})
$share.Add_Click({
	if (-not (Confirm-EmulatorIdle)) { return }
	Read-Form
	Start-Process $cmd -ArgumentList "/s /c `"$(Get-PrecompileCommand '-ExportHints')`"" -WorkingDirectory $root
})
$logs.Add_Click({
	$folder = if (Test-Path "$root\_Build") { "$root\_Build\run-logs" } else { "$root\logs" }
	New-Item -ItemType Directory -Force $folder | Out-Null
	Start-Process explorer.exe $folder
})
$readme.Add_Click({
	$file = @("$root\README.md", "$root\docs\PORTABLE-README.md") | Where-Object { Test-Path $_ } | Select-Object -First 1
	if ($file) { Start-Process notepad.exe "`"$file`"" }
})
$form.Add_FormClosing({ Read-Form })
[void]$form.ShowDialog()
