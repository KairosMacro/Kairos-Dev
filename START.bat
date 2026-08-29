@echo off
cd /d "%~dp0"

rem https://learn.microsoft.com/en-us/windows-server/administration/windows-commands/windows-commands

if exist "scripts\kairos_macro.ahk" (
	if exist "scripts\bin\AutoHotkey64.exe" (
		start "" "%~dp0scripts\bin\AutoHotkey64.exe" "%~dp0scripts\kairos_macro.ahk"
		exit
	)
)
