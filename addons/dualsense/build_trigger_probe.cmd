@echo off
rem Builds probe_trigger.exe from probe_trigger.cpp.
rem
rem Needs clang-cl and lld-link on PATH (rebuild.ps1 sets them up: Visual Studio's
rem Clang plus the MSVC/SDK lib paths) and a KytyPS5 build tree in KYTY_BUILD, the
rem folder rebuild.ps1 works in - it holds src-active\3rdparty\SDL2\include and
rem out-addons\3rdparty\SDL2\SDL2-static.lib. Override the location if yours differs.
setlocal
if "%KYTY_BUILD%"=="" set "KYTY_BUILD=G:\kyty-build"
pushd "%~dp0"
clang-cl /nologo /std:c++20 /EHsc /O2 /D_USE_STD_VECTOR_ALGORITHMS=0 /c ^
	/I "%KYTY_BUILD%\src-active\3rdparty\SDL2\include" /Fo:probe_trigger.obj probe_trigger.cpp || goto :fail
lld-link /nologo /SUBSYSTEM:CONSOLE /OUT:probe_trigger.exe probe_trigger.obj ^
	"%KYTY_BUILD%\out-addons\3rdparty\SDL2\SDL2-static.lib" ^
	version.lib winmm.lib imm32.lib setupapi.lib ole32.lib oleaut32.lib uuid.lib advapi32.lib ^
	gdi32.lib user32.lib shell32.lib dinput8.lib libcmt.lib libvcruntime.lib libucrt.lib ^
	oldnames.lib kernel32.lib || goto :fail
popd
echo OK
exit /b 0
:fail
popd
echo build failed
exit /b 1
