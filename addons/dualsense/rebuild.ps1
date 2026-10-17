param(
	[string]$Target = '',
	[string]$Version = '',
	[string]$BuildRoot = 'G:\kyty-build',
	[string]$DepsCache = '',
	[string]$Tarball = '',
	[switch]$NoInstall
)
# Compiles the DualSense haptics into a KytyPS5 release. The emulator links SDL2 statically and has
# no plug-in interface, so the controller audio path has to be part of the program: this downloads
# the release's source, applies dualsense.patch, builds it and drops the program in.
#   .\rebuild.ps1                          the newest KytyPS5-v* folder, its own version
#   .\rebuild.ps1 -Target G:\KytyPS5-v20261014 -Version v20261014
#   .\rebuild.ps1 -NoInstall               build only, leave the release folder alone
# The source stays in <BuildRoot>\src-active and the objects in <BuildRoot>\out-addons, so the next
# version only recompiles what changed (a first build is about 15 minutes, an update a few).
# Not 'Stop': the tools below (cmake, ninja, tar, git) write warnings to stderr, and with 'Stop'
# every one of them ends the run. Their exit codes are checked where it matters instead.
$ErrorActionPreference = 'Continue'
$ProgressPreference    = 'SilentlyContinue'
$addon = $PSScriptRoot
function Say($message, $color = 'Gray') { Write-Host $message -ForegroundColor $color }
# Copies a tree file by file: only what really changed is written, so unchanged files keep their
# timestamp and ninja skips them. Links are skipped (Windows cannot copy some of a submodule's),
# and a file that cannot be copied is reported instead of ending the run.
function Sync-Files([string]$from, [string]$to) {
	$script:copied = 0
	$script:skipped = 0
	Get-ChildItem -LiteralPath $from -Recurse -File -ErrorAction SilentlyContinue |
		Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) } | ForEach-Object {
		$dest = Join-Path $to $_.FullName.Substring($from.Length + 1)
		if (Test-Path -LiteralPath $dest) {
			$same = (Get-Item -LiteralPath $dest).Length -eq $_.Length -and
			        (Get-FileHash -LiteralPath $_.FullName -Algorithm MD5).Hash -eq (Get-FileHash -LiteralPath $dest -Algorithm MD5).Hash
			if ($same) { return }
		}
		New-Item -ItemType Directory -Force -Path (Split-Path -LiteralPath $dest) | Out-Null
		try { Copy-Item -LiteralPath $_.FullName -Destination $dest -Force -ErrorAction Stop }
		catch { $script:skipped++; return }
		$script:copied++
	}
	return "$($script:copied) copied, $($script:skipped) skipped"
}

# ---- where to build -----------------------------------------------------------------------------
$vs   = 'C:\Program Files\Microsoft Visual Studio\18\Community'
$msvc = "$vs\VC\Tools\MSVC\14.51.36231"
$sdk  = 'C:\Program Files (x86)\Windows Kits\10'
$sdkv = '10.0.26100.0'
$env:INCLUDE = "$msvc\include;$msvc\atlmfc\include;$sdk\Include\$sdkv\ucrt;$sdk\Include\$sdkv\shared;$sdk\Include\$sdkv\um;$sdk\Include\$sdkv\winrt;$sdk\Include\$sdkv\cppwinrt"
$env:LIB     = "$msvc\lib\x64;$msvc\atlmfc\lib\x64;$sdk\Lib\$sdkv\ucrt\x64;$sdk\Lib\$sdkv\um\x64"
$env:PATH    = "C:\Program Files\AMD\ROCm\7.2\bin;$msvc\bin\Hostx64\x64;$sdk\bin\$sdkv\x64;$vs\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;$vs\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;$BuildRoot\toolchain\glslang\extracted\bin;$env:PATH"
$env:VCToolsInstallDir = "$msvc\"
$env:WindowsSdkDir     = "$sdk\"
$env:WindowsSDKVersion = "$sdkv\"

# ---- the release to build for -------------------------------------------------------------------
if (!$Target) {
	$Target = @(Get-ChildItem -LiteralPath 'G:\' -Directory -Filter 'KytyPS5-v*' -ErrorAction SilentlyContinue |
		Sort-Object Name -Descending | Select-Object -First 1).FullName
}
if (!$Target -or !(Test-Path -LiteralPath "$Target\kyty_emulator.exe" -PathType Leaf)) {
	Say "No KytyPS5 release folder (kyty_emulator.exe) at: $Target" 'Red'; exit 1
}
if (!$Version) {
	# The banner ("ver = 0.3.0, git = v20261016, date = ...") is printed by --help: --version is not an
	# option in v20261016 ("missing value for --version"). The release folder's name is the last
	# resort, KytyPS5-v20261016 -> v20261016.
	$Version = ((& "$Target\kyty_emulator.exe" --help 2>&1 | Select-String 'git =') -replace '.*git = ', '' -split ',')[0].Trim()
	if (!$Version -and (Split-Path -LiteralPath $Target -Leaf) -match '(v\d+[a-z0-9]*)$') { $Version = $Matches[1] }
}
if (!$Version) { Say 'Could not read the version; pass -Version v20261013' 'Red'; exit 1 }
Say "target:  $Target"
Say "version: $Version"

$srcDir  = Join-Path $BuildRoot 'src-active'
$outDir  = Join-Path $BuildRoot 'out-addons'
$stage   = Join-Path $BuildRoot "src-stage-$Version"
# Not $tarball: PowerShell variable names are case-insensitive, so that would be the same
# variable as the -Tarball parameter and the check below would read the default as a user path.
$archive = Join-Path $BuildRoot "tarballs\cx-$Version.tar.gz"
New-Item -ItemType Directory -Force -Path (Join-Path $BuildRoot 'tarballs') | Out-Null
New-Item -ItemType Directory -Force -Path $srcDir | Out-Null

# ---- the source ---------------------------------------------------------------------------------
# -Tarball <file> uses a local archive; a broken download is deleted, never left behind.
if ($Tarball) {
	if (Test-Path -LiteralPath $Tarball -PathType Leaf) { $archive = $Tarball }
	else { Say "no such archive: $Tarball" 'Red'; exit 1 }
}
$downloaded = $false
if (!(Test-Path -LiteralPath $archive) -or (Get-Item -LiteralPath $archive).Length -lt 1MB) {
	Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
	Say "download: codeload chenxiao07/KytyPS5 $Version"
	$downloaded = $true
	# codeload drops the connection now and then (curl 56); --retry-all-errors covers it, and a
	# short --max-time makes each attempt fail fast instead of hanging on a stalled one.
	& curl.exe -sS -L --retry-all-errors --retry 8 --retry-delay 4 --connect-timeout 30 --max-time 600 `
		-o $archive "https://codeload.github.com/chenxiao07/KytyPS5/tar.gz/$Version"
	if ($LASTEXITCODE -ne 0 -or !(Test-Path -LiteralPath $archive)) {
		Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue
		Say "the download failed (curl exit $LASTEXITCODE). Try again, or download" 'Red'
		Say "  https://codeload.github.com/chenxiao07/KytyPS5/tar.gz/$Version" 'Red'
		Say "  and pass it: .\rebuild.ps1 -Tarball <file>" 'Red'
		exit 1
	}
	Say "downloaded: $((Get-Item $archive).Length) bytes"
}
# No Select-Object -First here: closing the pipe early makes tar exit on a broken pipe, which
# looks exactly like a broken archive (and would delete a good one).
& tar -tzf $archive > $null 2>&1
if ($LASTEXITCODE -ne 0) {
	if ($downloaded) { Remove-Item -LiteralPath $archive -Force -ErrorAction SilentlyContinue }
	Say "not a readable tar.gz: $archive" 'Red'
	if (!$downloaded) { Say 'it was already there; delete it and run again to re-download' 'Yellow' }
	exit 1
}
# Best effort: a sandboxed host can refuse a bulk delete. The extraction below overwrites the
# files anyway, so a staging folder that survives is untidy, not fatal.
try { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } catch { Say "note: the old staging folder survived: $stage" 'Yellow' }
New-Item -ItemType Directory -Force -Path $stage | Out-Null
& tar -xzf $archive -C $stage --strip-components=1
if ($LASTEXITCODE -ne 0) { Say 'the extraction failed' 'Red'; exit 1 }
Say "extracted: $stage"

Say 'sync into src-active (unchanged files keep their timestamp)...'
Say "  source: $(Sync-Files $stage $srcDir)"
try { Remove-Item -LiteralPath $stage -Recurse -Force -ErrorAction SilentlyContinue } catch { Say "note: $stage could not be removed; it is overwritten on the next run" 'Yellow' }

# A codeload archive has no submodule contents; the pins have not moved so far, so the ones of an
# earlier build are reused (they are the same commits).
if (!$DepsCache) {
	$DepsCache = @((Join-Path $BuildRoot '3rdparty-cache'), (Join-Path $BuildRoot 'chenxiao07-src-1013\3rdparty') |
		Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1)
}
if (!$DepsCache) { Say 'no dependency cache (pass -DepsCache <folder>)' 'Yellow' }
else {
	Say "dependencies: $DepsCache"
	foreach ($dir in (Get-ChildItem -LiteralPath $DepsCache -Directory)) {
		# Synced, not copied wholesale: a folder left half-filled by an earlier run is completed,
		# and a submodule's links are skipped instead of ending the run.
		$result = Sync-Files $dir.FullName (Join-Path $srcDir "3rdparty\$($dir.Name)")
		if ($result -notmatch '^0 copied') { Say "  3rdparty\$($dir.Name): $result" }
	}
}

# ---- the haptics --------------------------------------------------------------------------------
if (!(Test-Path -LiteralPath "$srcDir\.git")) {
	& git -C $srcDir init -q
	& git -C $srcDir config core.autocrlf false
	Add-Content -LiteralPath "$srcDir\.git\info\exclude" -Value '3rdparty/' -Encoding ASCII
}
& git -C $srcDir add -A
& git -C $srcDir -c user.name=build -c user.email=build@local commit -q -m "upstream $Version" 2>$null

# v20261016 and later ship haptics of their own (src/libs/dualSenseHaptics.cpp exists and
# audio.cpp calls into it), but it is a different implementation with a different API: a WASAPI
# backend that opens the endpoint through IAudioClient. There the addon's SDL2 port is swapped in
# by dualsense-v20261016.patch, which keeps upstream's own API so audio.cpp and controller.cpp
# need no change at all. Older releases have no such file, and the original patch adds it.
$replacesRelease = Test-Path -LiteralPath "$srcDir\src\libs\dualSenseHaptics.cpp" -PathType Leaf
$patch = Join-Path $addon $(if ($replacesRelease) { 'dualsense-v20261016.patch' } else { 'dualsense.patch' })
if ($replacesRelease) {
	Say "the release ships its own DualSense haptics: swapping in the addon's SDL2 backend"
}
if (!(Test-Path -LiteralPath $patch)) { Say "no patch at $patch" 'Red'; exit 1 }
$applied = $false
foreach ($mode in @('--ignore-whitespace', '--3way --ignore-whitespace', '-C1 --ignore-whitespace')) {
	$out = & git -C $srcDir apply $mode.Split(' ') $patch 2>&1
	if ($LASTEXITCODE -eq 0) { $applied = $true; Say "patch applied ($mode)"; break }
	# --3way writes the half-merged file (conflict markers and all) into the tree even when it
	# then fails, and the commit below would keep it - so put the tracked files back first.
	& git -C $srcDir checkout -- . 2>$null
}
if (!$applied) {
	Say 'the patch did not apply; the addon source files are copied over instead' 'Yellow'
	$sources = if ($replacesRelease) { Join-Path $addon 'v20261016' } else { $addon }
	Copy-Item -LiteralPath "$sources\dualSenseHaptics.cpp", "$sources\dualSenseHaptics.h" -Destination "$srcDir\src\libs" -Force
}
if (!(Test-Path -LiteralPath "$srcDir\src\libs\dualSenseHaptics.cpp")) { Say 'dualSenseHaptics.cpp is missing' 'Red'; exit 1 }
& git -C $srcDir add -A
& git -C $srcDir -c user.name=build -c user.email=build@local commit -q -m "DualSense haptics" 2>$null
& git -C $srcDir tag -f $Version 2>$null
Say "source ready: $(& git -C $srcDir describe --tags --always --dirty)"

# ---- configure ----------------------------------------------------------------------------------
New-Item -ItemType Directory -Force -Path (Join-Path $outDir 'externals') | Out-Null
# ffmpeg is fetched as a zip the build would otherwise download; the unpacked folder comes along.
foreach ($item in (Get-ChildItem -LiteralPath (Join-Path $BuildRoot 'out\externals') -Filter 'ffmpeg-*' -ErrorAction SilentlyContinue)) {
	$dest = Join-Path $outDir "externals\$($item.Name)"
	if (!(Test-Path -LiteralPath $dest)) { Copy-Item -LiteralPath $item.FullName -Destination $dest -Recurse -Force }
}
$profdata = Join-Path $srcDir 'tools\pgo\kyty.profdata'
$pgoStamp = Join-Path $outDir 'pgo.hash'
$pgoHash  = if (Test-Path -LiteralPath $profdata) { (Get-FileHash -LiteralPath $profdata -Algorithm SHA256).Hash.Substring(0, 16) } else { '' }
$pgoOld   = if (Test-Path -LiteralPath $pgoStamp) { (Get-Content -LiteralPath $pgoStamp -Raw).Trim() } else { '' }
$configured = Test-Path -LiteralPath (Join-Path $outDir 'CMakeCache.txt')
if ($configured -and $pgoOld -ne $pgoHash) {
	Say "the PGO profile changed ($pgoOld -> $pgoHash): every object is rebuilt from it" 'Yellow'
}
if (!$configured -or $pgoOld -ne $pgoHash) {
	Say 'cmake configure...'
	# cmake records the profile's path and never its contents, so a release that ships a new
	# tools/pgo/kyty.profdata would otherwise leave the objects built against the old one and the
	# link would fail on the ProfileSummary module flag ("conflicting values"). Naming the profile's
	# hash in the compile flags is what gives ninja something to notice: a new profile changes every
	# command line, so those objects are rebuilt instead of mismatching. The macro is never read.
	$cmakeArgs = @("-DCMAKE_C_COMPILER=clang-cl", "-DCMAKE_CXX_COMPILER=clang-cl", "-DKYTY_BUILD_LAUNCHER=OFF",
		"-DCMAKE_C_FLAGS=/DWIN32 /D_WINDOWS /D_USE_STD_VECTOR_ALGORITHMS=0 /DKYTY_PGO_PROFILE=$pgoHash",
		"-DCMAKE_CXX_FLAGS=/DWIN32 /D_WINDOWS /EHsc /D_USE_STD_VECTOR_ALGORITHMS=0 /DKYTY_PGO_PROFILE=$pgoHash",
		"-DFETCHCONTENT_SOURCE_DIR_XBYAK=$BuildRoot/fetch/xbyak",
		"-DFETCHCONTENT_SOURCE_DIR_ZYDIS=$BuildRoot/fetch/zydis",
		"-DFETCHCONTENT_SOURCE_DIR_ZSTD=$BuildRoot/fetch/zstd",
		"-DFETCHCONTENT_SOURCE_DIR_ZARCHIVE_SOURCE=$BuildRoot/fetch/zarchive",
		"-DKYTY_MARCH=x86-64-v3")
	if ($pgoHash) { $cmakeArgs += "-DKYTY_PGO_USE=$($profdata -replace '\\','/')"; Say "PGO: $profdata" }
	else { $cmakeArgs += "-DKYTY_PGO_USE="; Say 'no tools/pgo/kyty.profdata: building without PGO' 'Yellow' }
	cmake -S $srcDir -B $outDir -G Ninja -DCMAKE_BUILD_TYPE=Release @cmakeArgs 2>&1 | Select-Object -Last 8
	if ($LASTEXITCODE -ne 0) { Say 'cmake failed' 'Red'; exit 1 }
	Set-Content -LiteralPath $pgoStamp -Value $pgoHash -Encoding ASCII
}

# ---- build --------------------------------------------------------------------------------------
Say 'ninja kyty_emulator (this takes a while)...'
Set-Location $outDir
ninja kyty_emulator 2>&1 | Select-Object -Last 20
if ($LASTEXITCODE -ne 0) { Say 'the build failed' 'Red'; exit 1 }
$exe = Join-Path $outDir 'kyty_emulator.exe'
if (!(Test-Path -LiteralPath $exe)) { Say 'no kyty_emulator.exe was built' 'Red'; exit 1 }
$text = [System.Text.Encoding]::ASCII.GetString([System.IO.File]::ReadAllBytes($exe))
# Both implementations mention KYTY_DUALSENSE_HAPTICS (the env switch), so that marker alone cannot
# tell them apart: the SDL2 backend is the one that also carries its own name in the log strings.
# When the release's own backend was supposed to be replaced, its marker surviving alone means the
# swap silently did not happen and the build must be rejected.
$marker = if ($text -match 'DualSenseHaptics') { "the addon's SDL2 port (DualSenseHaptics)" }
	elseif ($text -match 'KYTY_DUALSENSE_HAPTICS') { "the release's own (KYTY_DUALSENSE_HAPTICS)" }
	else { '' }
if (!$marker) { Say 'the build has no DualSense haptics at all: neither marker is in it' 'Red'; exit 1 }
if ($replacesRelease -and $marker -notmatch 'SDL2') {
	Say "the release's own backend is still in it: the swap did not happen (patch or copy failed)" 'Red'
	exit 1
}
Say "built: $exe ($((Get-Item $exe).Length) bytes)" 'Green'
Say "haptics in it: $marker" 'Green'
# The banner comes from --help (v20261016 has no --version), so this is only reported when there is
# something to report.
$versionLine = & $exe --help 2>&1 | Select-String 'git =' | Select-Object -First 1
if ($versionLine) { Say $versionLine.ToString().Trim() }
else { Say "the built exe reports no version banner; the source is tagged $Version" }

# ---- install ------------------------------------------------------------------------------------
if ($NoInstall) { Say '-NoInstall: the release folder was left alone.' 'Yellow'; exit 0 }
$backup = Join-Path $Target '_Backup'
New-Item -ItemType Directory -Force -Path $backup | Out-Null
Copy-Item -LiteralPath "$Target\kyty_emulator.exe" -Destination "$backup\kyty_emulator.exe.bak-$(Get-Date -Format 'yyyyMMdd-HHmmss')" -Force
Copy-Item -LiteralPath $exe -Destination "$Target\kyty_emulator.exe" -Force
Say "installed: $Target\kyty_emulator.exe (the old one is in _Backup)" 'Green'
