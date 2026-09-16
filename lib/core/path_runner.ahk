/************************************************************************
 * @description: Child-process walk engine (ported from Kairos Lib/Core/
 * Path.ahk). Builds a standalone AHK v2 script around a path/pattern's
 * movement text (walk(), gotoRamp(), Rotate(), etc.), pipes it into a
 * fresh AutoHotkey process over stdin, and controls it via WM messages
 * (0x5000: pause/resume/restart/driftcomp). The child holds F14 down
 * while movement is running so the parent can KeyWait on it.
 ***********************************************************************/

class Path {
	static currentWalk := { pid: "", name: "" }
	static SprinklerImages := ["saturator"]
	static FieldSize := Map(
		"sunflower", { width: 33, height: 20 }
		, "dandelion", { width: 36, height: 18 }
		, "mushroom", { width: 32, height: 23 }
		, "blueflower", { width: 43, height: 17 }
		, "clover", { width: 29, height: 26 }
		, "strawberry", { width: 22, height: 26 }
		, "spider", { width: 28, height: 26 }
		, "bamboo", { width: 39, height: 18 }
		, "pineapple", { width: 33, height: 23 }
		, "stump", { width: 11, height: 9 }
		, "cactus", { width: 33, height: 18 }
		, "pumpkin", { width: 33, height: 17 }
		, "pinetree", { width: 31, height: 23 }
		, "rose", { width: 31, height: 20 }
		, "mountaintop", { width: 24, height: 28 }
		, "pepper", { width: 27, height: 21 }
		, "coconut", { width: 30, height: 21 }
	)

	static GetFieldSize(field) {
		f := StrLower(StrReplace(field, " "))
		return this.FieldSize.Has(f) ? this.FieldSize[f] : { width: 30, height: 20 }
	}

	static Execute(movement, name := "", timeout := 120, vars := "") {
		if !this.Run(movement, name, vars)
			return false
		KeyWait "F14", "D T5 L"
		KeyWait "F14", "T" timeout " L"
		this.End()
		return true
	}

	static Run(movement, name := "", vars := "") {
		DetectHiddenWindows true
		if WinExist("ahk_pid " this.currentWalk.pid " ahk_class AutoHotkey")
			this.End()
		script := this.Build(movement, vars)
		shell := ComObject("WScript.Shell")
		exec := shell.Exec('"' exe_path64 '" /script /force *')
		exec.StdIn.Write(script), exec.StdIn.Close()

		if WinWait("ahk_class AutoHotkey ahk_pid " exec.ProcessID, , 2) {
			DetectHiddenWindows false
			this.currentWalk := { pid: exec.ProcessID, name: name }
			return true
		} else {
			DetectHiddenWindows false
			return false
		}
	}

	static Build(movement, vars := "") {
		imgStr := "["
		for index, imgName in this.SprinklerImages
			imgStr .= '"' imgName '", '
		imgStr := RTrim(imgStr, ", ") "]"

		field := StrLower(StrReplace(Config.Get("Alt", "DefaultField", "pepper"), " "))
		dims := this.GetFieldSize(field)
		movespeed := Config.Get("Alt", "Movespeed", 29)
		shiftlock := Config.Get("Alt", "ShiftLock", 0)

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
			SendMode "Event"
			OnExit(ExitFunc)
			#Include "' A_WorkingDir '\lib\core\Gdip_All.ahk"
			#Include "' A_WorkingDir '\lib\core\Gdip_ImageSearch.ahk"
			#Include "' A_WorkingDir '\lib\core\roblox.ahk"
			#Include "' A_WorkingDir '\lib\core\movement.ahk"
			
			; QPC/HyperSleep are defined inline (NOT via lib\core\utility.ahk)
			; because patterns like GeneralBooster define their own nowUnix(),
			; which would collide with the copy in utility.ahk at load time.
			QPC() {
				static _ := 0, f := (DllCall("QueryPerformanceFrequency", "int64*", &_), _ /= 1000)
				return (DllCall("QueryPerformanceCounter", "int64*", &_), _ / f)
			}
			HyperSleep(ms) {
				static freq := (DllCall("QueryPerformanceFrequency", "Int64*", &f := 0), f)
				DllCall("QueryPerformanceCounter", "Int64*", &begin := 0)
				current := 0, finish := begin + ms * freq / 1000
				while (current < finish) {
					if ((finish - current) > 30000) {
						DllCall("Winmm.dll\timeBeginPeriod", "UInt", 1)
						DllCall("Sleep", "UInt", 1)
						DllCall("Winmm.dll\timeEndPeriod", "UInt", 1)
					}
					DllCall("QueryPerformanceCounter", "Int64*", &current)
				}
			}
			
			global movespeed := ' movespeed '
			global both := (Mod(movespeed*1000, 1265) = 0) || (Mod(Round((movespeed+0.005)*1000), 1265) = 0)
			global HastyGuards := (both || Mod(movespeed*1000, 1100) < 0.00001)
			global GiftedHasty := (both || Mod(movespeed*1000, 1150) < 0.00001)
			global BaseMovespeed := round(movespeed / (both ? 1.265 : (HastyGuards ? 1.1 : (GiftedHasty ? 1.15 : 1))), 0)
			
			global bitmaps := Map()
			bitmaps.CaseSense := false
			global pToken := Gdip_Startup()
			#Include "' A_WorkingDir '\assets\bitmaps\Offset.ahk"
			#Include "' A_WorkingDir '\assets\bitmaps\Movement.ahk"
			#Include "' A_WorkingDir '\assets\bitmaps\General.ahk"
			#Include "' A_WorkingDir '\assets\bitmaps\Sprinkler.ahk"
			#Include "' A_WorkingDir '\assets\bitmaps\Reset.ahk"
			
			global offsetY := ' roblox.Get().y_offset '
			global SprinklerImages := ' imgStr '
			' KeyVars() '
			Roblox.start_tracker()
			Roblox.Update()
			
			global MoveSys := Movement()
			MoveSys.coco_enabled := ' Config.Get("Alt", "CocoCatch", 0) '
			MoveSys.hive_slot := ' Config.Get("Alt", "HiveSlot", 1) '
			MoveSys.is_claimed := ' Config.Get("Alt", "ClaimHive", 1) '
			MoveSys.pitch := ' Config.Get("Alt", "CameraPitch", 4) '
			
			global field := "' field '"
			global fieldWidth := ' dims.width '
			global fieldHeight := ' dims.height '
			global size := ' Config.Get("Alt", "PatternSize", 1) '
			global reps := ' Config.Get("Alt", "PatternWidth", 1) '
			global pitch := ' Config.Get("Alt", "CameraPitch", 4) '
			global shiftlock := ' shiftlock '
			global MoveMethod := "' Config.Get("Alt", "MoveMethod", "cannon") '"
			global AltNumber := ' Config.Get("Alt", "AltNumber", 1) '
			
			gotoRamp() => MoveSys.GotoRamp()
			gotoCannon() => MoveSys.GotoCannon()
			Reset() => MoveSys.ResetCharacter()
			
			walk(tiles, dir1, dir2?) => MoveSys.Walk(tiles, dir1, dir2?)
			move(tiles) => MoveSys.Move(tiles)
			FieldDriftCompensate() => MoveSys.FieldDriftCompensate()
			LocateSprinkler(&x:="", &y:="") => MoveSys.LocateSprinkler(&x, &y)
			
			Rotate(n) {
				if (n = 0)
					return
				send "{" (n > 0 ? RotRight : RotLeft) " " Abs(n) "}"
				sleep 50
			}
			
			EnableShift(state := 0) {
				state := state ? 1 : 0
				if !shiftlock
					return
				win := Roblox.Get()
				if !win.ok
					return
				pBMScreen := Gdip_BitmapFromScreen(win.x + 5 "|" win.y + win.h - 54 "|50|50")
				if (Gdip_ImageSearch(pBMScreen, bitmaps["shiftlock"], , , , , , 2) != state)
					send "{" SC_LShift "}"
				Gdip_DisposeImage(pBMScreen)
				sleep 50
			}
			
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
		return script
	}

	static Pause() => this.PostControl(1)
	static Resume() => this.PostControl(0)

	static PostControl(wParam) {
		if (!this.currentWalk.HasOwnProp("pid") || this.currentWalk.pid = "")
			return false
		DetectHiddenWindows true
		sent := false
		if WinExist("ahk_class AutoHotkey ahk_pid " this.currentWalk.pid) {
			try PostMessage(0x5000, wParam, 0, , "ahk_class AutoHotkey ahk_pid " this.currentWalk.pid), sent := true
		}
		DetectHiddenWindows false
		return sent
	}

	static End() {
		if (!this.currentWalk.HasOwnProp("pid") || this.currentWalk.pid = "")
			return
		DetectHiddenWindows true
		try WinClose "ahk_class AutoHotkey ahk_pid " this.currentWalk.pid
		if (this.currentWalk.HasOwnProp("cocoPID") && this.currentWalk.cocoPID)
			try ProcessClose(this.currentWalk.cocoPID)
		this.currentWalk := { pid: "", name: "" }
		DetectHiddenWindows false
	}
}

; Never leave an orphaned walk child holding movement keys.
OnExit((*) => Path.End())