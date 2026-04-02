@echo off
cd %~dp0

rem https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands

if exist "Main.ahk" (
	if exist "scripts\EXE\AutoHotkey64.exe" (
		start "" "%~dp0scripts\EXE\AutoHotkey64.exe" "%~dp0Main.ahk"
		exit
	)
)
