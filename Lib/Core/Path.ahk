class Path {
	static Execute(movement, name := "", timeout := 120) {
		if !this.Run(movement, name)
			return false
		KeyWait "F14", "D T5 L"
		KeyWait "F14", "T" timeout " L"
		this.End()
		return true
	}

	static Run(movement, name := "", vars := "") {
		DetectHiddenWindows true
		if WinExist("ahk_pid " State.currentWalk.pid " ahk_class AutoHotkey")
			this.End()
		imgStr := "["
		for index, imgName in State.SprinklerImages
			imgStr .= '"' imgName '", '
		imgStr := RTrim(imgStr, ", ") "]"
		script :=
		(
		'
		#SingleInstance Off
		#NoTrayIcon
		Persistent()
		ProcessSetPriority("AboveNormal")
		KeyHistory 0
		ListLines 0
		DetectHiddenWindows 1
		CoordMode "Mouse", "Screen"
		CoordMode "Pixel", "Screen"
		OnExit(ExitFunc)
		#Include "' A_WorkingDir '\Lib\Utils\"
		#Include "Gdip_All.ahk"
		#Include "Gdip_ImageSearch.ahk"
		#Include "Utility.ahk"
		#Include "JSON.ahk"
		
		#Include "' A_WorkingDir '\Lib\Core\"
		#Include "Roblox.ahk"
		#Include "Move.ahk"
		#Include "Scheduler.ahk"
		
		global movespeed := ' Alt.Movespeed '
		global both := (Mod(movespeed*1000, 1265) = 0) || (Mod(Round((movespeed+0.005)*1000), 1265) = 0)
		global HastyGuards := (both || Mod(movespeed*1000, 1100) < 0.00001)
		global GiftedHasty := (both || Mod(movespeed*1000, 1150) < 0.00001)
		global BaseMovespeed := round(movespeed / (both ? 1.265 : (HastyGuards ? 1.1 : (GiftedHasty ? 1.15 : 1))), 0)
		
		global bitmaps := Map()
		bitmaps.CaseSense := false
		global pToken := Gdip_Startup()
		#Include "' A_ScriptDir '\Assets\Bitmaps\"
		#Include "Offset.ahk"
		#Include "Movement.ahk"
		#Include "General.ahk"
		#Include "Sprinkler.ahk"
		
		global offsetY := ' State.offsetY '
		global SprinklerImages := ' imgStr '
		' KeyVars() '
		Roblox.StartTracker(50)
		Roblox.Update()
		
		global MoveSys := Movement()
		MoveSys.coco_enabled := ' Alt.CocoCatch '
		MoveSys.hive_slot := ' Alt.HiveSlot '
		MoveSys.is_claimed := ' Alt.ClaimHiveEnabled '
		MoveSys.pitch := ' Alt.CameraPitch '
		
		global field := "' Alt.DefaultField '"
		global fieldWidth := ' State.FieldSize[Alt.DefaultField].width '
		global fieldHeight := ' State.FieldSize[Alt.DefaultField].height '
		global size := ' Alt.PatternSize '
		global reps := ' Alt.PatternWidth '
		global pitch := ' Alt.CameraPitch '
		
		global AltNumber := ' Alt.AltNumber '
		
		gotoRamp() => MoveSys.GotoRamp()
		gotoCannon() => MoveSys.GotoCannon()
		Reset() => MoveSys.ResetCharacter()
		
		
		walk(tiles, dir1, dir2?) => MoveSys.Walk(tiles, dir1, dir2?)
		move(tiles) => MoveSys.Move(tiles)
		FieldDriftCompensate() => MoveSys.FieldDriftCompensate()
		LocateSprinkler(&x:="", &y:="") => MoveSys.LocateSprinkler(&x, &y)
		nm_CameraRotation(Dir, count) {
			Static LR := 0, UD := 0, init := OnExit((*) => send("{" Rot%(LR > 0 ? "Left" : "Right")% " " Mod(Abs(LR), 8) "}{" Rot%(UD > 0 ? "Up" : "Down")% " " Abs(UD) "}"), -1)
			send "{" Rot%Dir% " " count "}"
			Switch Dir,0 {
				Case "Left": LR -= count
				Case "Right": LR += count
				Case "Up": UD -= count
				Case "Down": UD += count
			}
		}
		
		' vars '
		global index := 0
		OnMessage(0x5000, IPC_Receive_Control)
		OnMessage(0x5001, IPC_Receive_Coconut_Pos)
		OnMessage(0x5002, IPC_Receive_Coconut_Clear)
		
		IPC_Receive_Control(wParam, lParam, *) {
			if (wParam = 1)
				MoveSys.Pause()
			else if (wParam = 0)
				MoveSys.Resume()
			else if (wParam = 2)
				SetTimer(start, -1)
			else if (wParam = 3)
				SetTimer(TriggerDriftComp, -1)
			else if (wParam = 4)
				MoveSys.pending_coco_scan := true
			else if (wParam = 5)
				MoveSys.coco_scan_ready := true
		}
		
		IPC_Receive_Coconut_Pos(wParam, lParam, *) {
			MoveSys.TriggerCoconutCatch(wParam, lParam)
		}

		IPC_Receive_Coconut_Clear(wParam, lParam, *) {
			MoveSys.TriggerCoconutCatch(0, 0)
		}
		
		start()
		return
		
		start() {
			global index
			index++
			MoveSys.is_running := true
			send "{F14 down}"
			' movement '
			send "{F14 up}"
			MoveSys.is_running := false
		}
		
		TriggerDriftComp() {
			MoveSys.is_running := true
			send "{F14 down}"
			MoveSys.FieldDriftCompensate()
			send "{F14 up}"
			MoveSys.is_running := false
		}
		
		ExitFunc(*) {
			MoveSys.Stop()
			Send "{' LeftKey ' up}{' RightKey ' up}{' FwdKey ' up}{' BackKey ' up}{' SC_Space ' up}{F14 up}{' SC_E ' up}"
			try Gdip_Shutdown(pToken)
		}
		'
		)
		shell := ComObject("WScript.Shell")
		exec := shell.Exec('"' exe_path64 '" /script /force *')
		exec.StdIn.Write(script), exec.StdIn.Close()

		if WinWait("ahk_class AutoHotkey ahk_pid " exec.ProcessID, , 2) {
			DetectHiddenWindows false
			State.currentWalk := { pid: exec.ProcessID, name: name }
			return true
		} else {
			DetectHiddenWindows false
			return false
		}
	}

	static End() {
		if (!State.currentWalk.HasOwnProp("pid") || State.currentWalk.pid = "")
			return
		DetectHiddenWindows true
		try WinClose "ahk_class AutoHotkey ahk_pid " State.currentWalk.pid
		if (State.currentWalk.HasOwnProp("cocoPID") && State.currentWalk.cocoPID)
			try ProcessClose(State.currentWalk.cocoPID) 
		State.currentWalk := { pid: "", name: "" }
		DetectHiddenWindows false
	}
}

KeyVars() {
	return
	(
	'
	FwdKey:="' FwdKey '"
	LeftKey:="' LeftKey '"
	BackKey:="' BackKey '"
	RightKey:="' RightKey '"
	RotLeft:="' RotLeft '"
	RotRight:="' RotRight '"
	RotUp:="' RotUp '"
	RotDown:="' RotDown '"
	ZoomIn:="' ZoomIn '"
	ZoomOut:="' ZoomOut '"
	SC_E:="' SC_E '"
	SC_R:="' SC_R '"
	SC_L:="' SC_L '"
	SC_Esc:="' SC_Esc '"
	SC_Enter:="' SC_Enter '"
	SC_LShift:="' SC_LShift '"
	SC_Space:="' SC_Space '"
	SC_1:="' SC_1 '"
	TCFBKey:="' TCFBKey '"
	AFCFBKey:="' AFCFBKey '"
	TCLRKey:="' TCLRKey '"
	AFCLRKey:="' AFCLRKey '"
	'
	)
}
