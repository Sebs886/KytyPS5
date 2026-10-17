param([string]$Target = '')
# Copies the addons onto a KytyPS5 release folder: the launcher with the cheat switches and the
# cheats folder. Nothing is compiled, so this works on any version - copy the folder over a new
# release and the cheats are there again.
#   .\install.ps1                        a dialog picks the emulator folder
#   .\install.ps1 -Target G:\KytyPS5-v20261014
#   .\install.cmd                        the same, from a double click (keeps the window open)
# It may also be run from inside the emulator folder: it then finds the addon package by itself
# (G:\KytyAddons or a folder next to the emulator one) and skips what is already in place.
$ErrorActionPreference = 'Stop'
$scriptDir = $PSScriptRoot
$stamp     = Get-Date -Format 'yyyyMMdd-HHmmss'

function Say($message, $color = 'Gray') { Write-Host $message -ForegroundColor $color }

function Test-SamePath($a, $b) {
	$left  = if (Test-Path -LiteralPath $a) { (Resolve-Path -LiteralPath $a).Path } else { $null }
	$right = if (Test-Path -LiteralPath $b) { (Resolve-Path -LiteralPath $b).Path } else { $null }
	return ($left -and $right -and ($left -ieq $right))
}

function Test-Addon($dir) { return ($dir -and (Test-Path -LiteralPath "$dir\launcher.ps1") -and (Test-Path -LiteralPath "$dir\cheats")) }

# The emulator folder: the parameter, a dialog, or the newest KytyPS5-* folder on G:\.
if (!$Target) {
	$candidates = @(Get-ChildItem -LiteralPath 'G:\' -Directory -Filter 'KytyPS5-v*' -ErrorAction SilentlyContinue |
		Sort-Object Name -Descending)
	if ($candidates.Count -eq 1) {
		$Target = $candidates[0].FullName
	} elseif ($candidates.Count -gt 1) {
		Add-Type -AssemblyName System.Windows.Forms
		$dialog = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
			Description        = 'The KytyPS5 folder (kyty_emulator.exe, run-windows.ps1)'
			SelectedPath       = $candidates[0].FullName
			ShowNewFolderButton = $false
		}
		if ($dialog.ShowDialog() -ne 'OK') { Say 'No folder chosen.' 'Yellow'; exit 1 }
		$Target = $dialog.SelectedPath
	}
}
if (!$Target -or !(Test-Path -LiteralPath $Target -PathType Container)) { Say "No such folder: $Target" 'Red'; exit 1 }
if (!(Test-Path -LiteralPath "$Target\kyty_emulator.exe" -PathType Leaf)) {
	Say "Not a KytyPS5 release folder (no kyty_emulator.exe): $Target" 'Red'; exit 1
}
Say "target:  $Target"

# Where the files come from: normally this script's own folder. When the addon was copied into the
# emulator folder, look for a real addon package instead, so nothing is copied onto itself.
$addon = $null
if ($scriptDir -ne $Target -and (Test-Addon $scriptDir)) { $addon = $scriptDir }
else {
	$places  = @(Get-ChildItem -LiteralPath 'G:\' -Directory -Filter 'KytyAddons*' -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
	$upOne   = Split-Path -LiteralPath $Target
	if ($upOne) { $places += @(Get-ChildItem -LiteralPath $upOne -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName }) }
	foreach ($place in $places) { if ($place -ne $Target -and (Test-Addon $place)) { $addon = $place; break } }
}
if (!$addon -and (Test-Addon $Target) -and ((Get-Content -LiteralPath "$Target\launcher.ps1" -Raw) -match 'Get-SessionCheats')) {
	# No package found, but the launcher here is already the addon one: nothing left to copy.
	$addon = $Target
}
if (!$addon) { Say 'No addon files found: put install.ps1 next to launcher.ps1 and cheats\, or keep the package in G:\KytyAddons.' 'Red'; exit 1 }
Say "source:  $addon"

# The banner ("ver = 0.3.0, git = v20261016, date = ...") is printed by --help: --version is not an
# option in v20261016 ("missing value for --version"). The release folder's name is the last resort,
# KytyPS5-v20261016 -> v20261016.
$exeVersion = ((& "$Target\kyty_emulator.exe" --help 2>&1 | Select-String 'git =') -replace '.*git = ', '' -split ',')[0].Trim()
if (!$exeVersion -and (Split-Path -LiteralPath $Target -Leaf) -match '(v\d+[a-z0-9]*)$') { $exeVersion = $Matches[1] }
Say "version: $exeVersion"

# Back up what this overwrites.
$backup = Join-Path $Target '_Backup'
New-Item -ItemType Directory -Force -Path $backup | Out-Null
if (Test-Path -LiteralPath "$Target\launcher.ps1") {
	Copy-Item -LiteralPath "$Target\launcher.ps1" -Destination "$backup\launcher.ps1.bak-$stamp" -Force
	Say "backed up launcher.ps1 -> _Backup\launcher.ps1.bak-$stamp"
}
if (Test-Path -LiteralPath "$Target\cheats") {
	Copy-Item -LiteralPath "$Target\cheats" -Destination "$backup\cheats-$stamp" -Recurse -Force
	Say "backed up cheats      -> _Backup\cheats-$stamp"
}

# The launcher and the cheats (a run's own cheats\_session is left alone).
if (Test-SamePath "$addon\launcher.ps1" "$Target\launcher.ps1") {
	Say 'in place: launcher.ps1 (already the addon one)'
} else {
	Copy-Item -LiteralPath "$addon\launcher.ps1" -Destination "$Target\launcher.ps1" -Force
	Say 'copied:   launcher.ps1'
}
if (Test-SamePath "$addon\cheats" "$Target\cheats") {
	Say 'in place: cheats\ (already the addon one)'
} else {
	New-Item -ItemType Directory -Force -Path "$Target\cheats" | Out-Null
	# -Path, not -LiteralPath: LiteralPath takes the * literally and would copy nothing.
	# A run's own cheats\_session is left alone.
	Copy-Item -Path "$addon\cheats\*" -Destination "$Target\cheats" -Recurse -Force -Exclude '_session'
	Say 'copied:   cheats\'
}

# The settings: keep everything the launcher already wrote and only own the cheat keys. The key list
# used to be written out here, which silently dropped every option added to the launcher since (the
# per-world tendencies, the controller volumes): a copied launcher then found its settings truncated.
# Copying the file's own properties keeps install.ps1 out of that business -- a key this version does
# not know is still carried over untouched.
$settingsPath = Join-Path $Target 'launcher-settings.json'
$settings = [ordered]@{}
if (Test-Path -LiteralPath $settingsPath) {
	try {
		$saved = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
		foreach ($property in $saved.PSObject.Properties) {
			if ($property.Name -eq 'modStates') { continue }
			$settings[$property.Name] = $property.Value
		}
		if ($saved.PSObject.Properties['modStates']) {
			$map = @{}
			foreach ($mod in $saved.modStates.PSObject.Properties) { $map[$mod.Name] = [bool]$mod.Value }
			$settings['modStates'] = $map
		}
	} catch { Say 'the saved settings could not be read; only the cheat keys are written' 'Yellow' }
}
# Nothing here invents the launcher's other options: whatever is missing keeps the default the
# launcher has, and the tendencies are left missing on purpose so that the first window open fills
# them from the save (the launcher reads the absence of "tendencyWorlds" as "never set per world").
if (!$settings.Contains('cheats')) { $settings['cheats'] = $true }
if (!$settings.Contains('game') -or !$settings['game']) {
	$gamePath = Join-Path $Target 'game-path.txt'
	if (Test-Path -LiteralPath $gamePath) { $settings['game'] = (Get-Content -LiteralPath $gamePath -TotalCount 1).Trim() }
}

# The cheat file: the Demon's Souls one when it fits the folder, else the first one.
$cheatFiles = @(Get-ChildItem -LiteralPath "$Target\cheats" -Filter '*.json' -File | Sort-Object Name)
if ($cheatFiles.Count -eq 0) { Say 'no cheat file copied (the addon cheats folder is empty)' 'Yellow' }
else {
	$chosen = $cheatFiles | Where-Object { $_.Name -like 'PPSA01341*' } | Select-Object -First 1
	if (!$chosen) { $chosen = $cheatFiles[0] }
	$settings['cheatFile'] = $chosen.FullName
	$settings['cheats']    = $true
	# A switch per mod; one the file does not switch on stays off (the experimental ones).
	$mods = @()
	try { $mods = @((Get-Content -LiteralPath $chosen.FullName -Raw | ConvertFrom-Json).mods) } catch {}
	if (!$settings.Contains('modStates') -or !($settings['modStates'] -is [hashtable])) { $settings['modStates'] = @{} }
	foreach ($mod in $mods) {
		$key = "$($chosen.Name)::$($mod.name)"
		if (!$settings['modStates'].Contains($key)) {
			$settings['modStates'][$key] = if ($mod.PSObject.Properties['enabled']) { [bool]$mod.enabled } else { $true }
		}
	}
	Say "cheats:  $($chosen.Name) ($($mods.Count) mods)"
}
$settings | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $settingsPath -Encoding UTF8
Say 'wrote:   launcher-settings.json (the cheats are on)'

# What the copy can and cannot do.
$runText = if (Test-Path -LiteralPath "$Target\run-windows.ps1") { Get-Content -LiteralPath "$Target\run-windows.ps1" -Raw } else { '' }
$patchSupported = $runText -match "(?im)^[ \t]*\[[a-z]+\][ \t]*\`$Patch\b"
Write-Host ''
if ($patchSupported) { Say 'run-windows.ps1 has -Patch: the cheats will be applied' 'Green' }
else { Say 'run-windows.ps1 has no -Patch switch: the cheats cannot be applied on this version' 'Yellow' }

# The DualSense haptics need a compiled exe. The package carries the one already built for a
# version, so a release of that version gets them without rebuilding; any other version needs
# dualsense\rebuild.cmd.
$bytes = [System.IO.File]::ReadAllBytes("$Target\kyty_emulator.exe")
$text  = [System.Text.Encoding]::ASCII.GetString($bytes)
# Both implementations carry the KYTY_DUALSENSE_HAPTICS environment switch (the addon's SDL2 backend
# documents it too), so the class name is what tells them apart. Checked first for that reason: an
# exe that has had the SDL2 backend compiled in must not be reported as the release's own.
if ($text -match 'DualSenseHaptics') {
	Say 'haptics: kyty_emulator.exe has the addon SDL2 DualSense backend' 'Green'
}
elseif ($text -match 'KYTY_DUALSENSE_HAPTICS') {
	# v20261016 and later carry their own DualSense haptics in the release itself. install.cmd does
	# not swap them: that is dualsense\rebuild.cmd's job. Its options are environment variables or
	# dualsense-haptics.txt, see the README.
	Say 'haptics: this release ships its own DualSense haptics (KYTY_DUALSENSE_HAPTICS)' 'Green'
	Say '         the addon SDL2 backend is not in it - run dualsense\rebuild.cmd to swap it in' 'Yellow'
}
else {
	$built = $null
	foreach ($file in @(Get-ChildItem -LiteralPath "$addon\dualsense" -Filter 'kyty_emulator-haptics-*.exe' -File -ErrorAction SilentlyContinue | Sort-Object Name -Descending)) {
		if ($file.Name -match '-(v\d+)\.exe$' -and $Matches[1] -eq $exeVersion) { $built = $file; break }
	}
	if ($built) {
		Copy-Item -LiteralPath "$Target\kyty_emulator.exe" -Destination "$backup\kyty_emulator.exe.bak-$stamp" -Force
		Copy-Item -LiteralPath $built.FullName -Destination "$Target\kyty_emulator.exe" -Force
		Say "copied:   kyty_emulator.exe (DualSense haptics, $exeVersion); the original is in _Backup" 'Green'
	} else {
		Say "haptics: no exe built for $exeVersion - run dualsense\rebuild.cmd once to compile them in" 'Yellow'
	}
}
Write-Host ''
if ($scriptDir -eq $Target) {
	Say 'note: the addon sits inside the emulator folder. Keep the original package too' 'Yellow'
	Say '      (G:\KytyAddons) - that is what a new release is patched from.' 'Yellow'
}
Say 'done. The launcher (launcher.cmd) now has the Cheats row.' 'Green'
