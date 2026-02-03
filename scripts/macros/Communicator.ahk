#Requires AutoHotkey v2.0
#NoTrayIcon
#SingleInstance Force

#Include "%A_ScriptDir%\..\..\lib"
#Include "Gdip_All.ahk"
#Include "JSON.ahk"
#Include "Discord.ahk"
#Include "nowUnix.ahk"
#include "Auxiliary.ahk"

#Warn VarUnset, Off
SetWorkingDir A_ScriptDir "\.."

if (A_Args.Length = 0) {
	MsgBox "This script needs to be run by Natro Macro! You are not supposed to run it manually."
	ExitApp
}

;-----------------
; Initialize
;-----------------
; general
MacroState := 0
AccountType := A_Args[1]
; discord
discordMode := A_Args[2]
discordCheck := A_Args[3]
MainChannelCheck := A_Args[4]
MainChannelID := A_Args[5]
ReportChannelCheck := A_Args[6]
ReportChannelID := A_Args[7]
WebhookEasterEgg := A_Args[8]
DiscordUID := A_Args[9]
Webhook := A_Args[10]
BotToken := A_Args[11]
CommunicationChannelID := A_Args[12]
; Socket
IP := A_Args[13]
PortNumber := A_Args[14]
IdentifiedConnections := {}
CommunicatorSocket := 0
CommunicatorIsConnected := false
; general
CommunicationStyle := A_Args[15]
CommunicationID := (AccountType = "Main Acc" ? -1 : A_Args[16])
; override valuies
if BotToken != "" && CommunicationStyle = "Discord" && AccountType != "Main Acc"
	discordMode := 1
; misc
OnExit(ExitFunc, -1)
OnMessage(0x5550, SelfReload)
OnMessage(0x004A, SendMessageToAlts)
DetectHiddenWindows 1
;-----------------
; Discord
;-----------------
ReadMessages() {
	static LastLoggedMessage := ""
	if MacroState != 2
		return { error: "Macro not running" }
	if CommunicationChannelID = 0 || BotToken = "" || CommunicationStyle != "Discord" || AccountType = "Main Acc"
		return { error: "Discord communication not set up" }

	messages := discord.GetRecentMessages(CommunicationChannelID)
	if !IsObject(messages) || messages = -1 || messages.Length = 0
		return { error: "No new messages" }

	for i, msg in messages {
		if msg["content"] = ""
			continue
		try {
			jsonObj := JSON.parse(msg["content"])
			if jsonObj.Count = 0
				continue
			return jsonObj
		} catch
			continue
	}
	return { error: "No valid JSON found" }
}

;-----------------
; Function
;-----------------
SendMessageToAlts(wParam, lParam, *) {
	try {
		StringAddress := NumGet(lParam + 2 * A_PtrSize, "Ptr")
		StringText := StrGet(StringAddress)
		jsonObj := JSON.parse(StringText)
	} catch
		return
	if !IsObject(jsonObj)
		return

	if Webhook != "" && CommunicationStyle = "Discord" && AccountType = "Main Acc" {
		payload := Map("content", JSON.Stringify(jsonObj))
		try discord.SendMessageAPI(JSON.stringify(payload), "application/json", , Webhook)
		catch
			return
	}
}

GetMessages(*) {
	if MacroState != 2
		return 0
	if CommunicationStyle = "Discord" && AccountType != "Main Acc" {
		msg := ReadMessages()
		if !IsObject(msg) || msg.HasOwnProp("error")
			return 0
	} else
		return 0
	return msg
}

Interpreter(msg, *) {
	discord_wrong_identifier := ((msg.Has("identifier") && discordMode > 0) ? CommunicationID != msg["identifier"] : 0)
	if !IsObject(msg) || msg.HasOwnProp("error") || discord_wrong_identifier
		return
	try Send_WM_COPYDATA(JSON.stringify(msg), "natro_macro ahk_class AutoHotkey", 1)
}

SelfReload(*) { ; to refresh vals, it has to be ran by natro_macro.ahk
	Critical
	if (A_Args.Length > 0) {
		LastReload := A_Args[A_Args.Length] ; keep A_TickCount at the end
		if (IsNumber(LastReload) && (A_TickCount - LastReload < 5000)) {
			return
		}
	}
	exe_path64 := (A_Is64bitOS && FileExist("scripts\executables\AutoHotkey64.exe")) ? (A_WorkingDir "\scripts\executables\AutoHotkey64.exe") : A_AhkPath
	path := '"' exe_path64 '" /script "' A_WorkingDir '\scripts\macros\Communicator.ahk" ', vars := ""
	for i, x in A_Args
		vars .= '"' (x = "" ? " " : A_Index = A_Args.Length ? A_TickCount : x) '" '
	Run path " " vars
	ExitApp
}

nm_UpdateConnectionTotal(num) {
	Critical
	DetectHiddenWindows 1
	try SendMessage(0x5561, num, , , "natro_macro ahk_class AutoHotkey")
	DetectHiddenWindows 0
}

Send_WM_COPYDATA(StringToSend, TargetScriptTitle, wParam := 0)
{
	CopyDataStruct := Buffer(3 * A_PtrSize)
	SizeInBytes := (StrLen(StringToSend) + 1) * 2
	NumPut("Ptr", SizeInBytes
		, "Ptr", StrPtr(StringToSend)
		, CopyDataStruct, A_PtrSize)

	try
		s := SendMessage(0x004A, wParam, CopyDataStruct, , TargetScriptTitle)
	catch
		return -1
	else
		return s
}

ExitFunc(*) {
	Critical
	try CommunicatorSocket.Close()
	try CommunicatorSocket.Cleanup()
	ExitApp
}


/* FOR OTHER SCRIPTS TO USE COMMUNICATOR
sendInstructions(instuctions) {
	if !IsObject(instuctions)
		return
	DetectHiddenWindows 1
	CopyDataStruct := Buffer(A_PtrSize * 3)
	StringToSend := JSON.stringify(instuctions)
	SizeInBytes := (StrLen(StringToSend) + 1) * 2
	NumPut("Ptr", SizeInBytes, "Ptr", StrPtr(StringToSend), CopyDataStruct, A_PtrSize)
	try WinExist("Communicator.ahk ahk_class AutoHotkey") ? SendMessage(0x004A, 0, CopyDataStruct, , , , , , 5000) : ""
	DetectHiddenWindows 0
}

WM_COPYDATA(wParam, lParam, *){
	Critical
	global LastGuid, PMondoGuid, MondoAction, MondoBuffCheck, currentWalk, FwdKey, BackKey, LeftKey, RightKey, SC_Space
	StringAddress := NumGet(lParam + 2*A_PtrSize, "Ptr")  ; Retrieves the CopyDataStruct's lpData member.
	StringText := StrGet(StringAddress)  ; Copy the string out of the structure.
	if (wParam = 1) { ; message from Communicator.ahk
		try message := JSON.parse(StringText)
		catch
			return 0
		if (message.Has("type") && message["type"] = "Tad Alt" && message["action"] = "Go to Field") {
			nm_TempGather(message["field"], message["time"],,1)
		}
		if (message.Has("type") && message["type"] = "Tad Alt" && message["action"] = "Update Time") {
			global TempGather_StartTime := message["unix"]
		}
		return 0
	} else {
		InStr(StringText, ": ") ? nm_setStatus(SubStr(StringText, 1, InStr(StringText, ": ")-1), SubStr(StringText, InStr(StringText, ": ")+2)) : nm_setStatus(StringText)
	}
	return 0
}

nm_LaunchCommunicator() {
	global CommunicationID
	path := '"' exe_path64 '" /script "' A_WorkingDir '\submacros\Communicator.ahk" '
	params := [AccountType, discordMode, discordCheck, MainChannelCheck, MainChannelID, ReportChannelCheck, ReportChannelID, WebhookEasterEgg
	, DiscordUID, CommunicationWebhook, CommunicationBotToken, CommunicationChannelID, CommunicationIP, PortNumber, CommunicationStyle
	, CommunicationID, A_TickCount]
	vars := ""
	for i, x in params
		vars .= '"' (x = "" ? "" : x) '" '
	Run path " " vars
}
nm_LaunchCommunicator()


*/
