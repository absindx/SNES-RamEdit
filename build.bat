@echo off
setlocal enabledelayedexpansion
pushd %~dp0

set OutputName=RamEdit
set MainSource=Main
set Emulator=..\Mesen-S\Mesen-S.exe
set Assembler=..\Asar\asar.exe
set AssembleOptions=--symbols=wla --fix-checksum=on
rem                 --verbose

echo --------------------------------------------------
echo               %date% %time%
echo --------------------------------------------------

rem Erase files to avoid patch mode
move /Y "%OutputName%.sfc" "%OutputName%.sfc.old" > NUL 2>&1

:Assemble
%Assembler% %AssembleOptions% %MainSource%.asm "%OutputName%.sfc" > build.log 2>&1
type build.log

if "%1"=="" goto Return
	rem Force reload from commandline
	start %Emulator% "%OutputName%"
	start %Emulator% "%OutputName%.sfc"

:Return
popd
