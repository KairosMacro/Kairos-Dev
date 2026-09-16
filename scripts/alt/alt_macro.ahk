#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 255
#Warn VarUnset, Off
#NoTrayIcon

SetWorkingDir A_ScriptDir "\..\.."
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SendMode "Event"

if (A_Args.Length == 0) {
	MsgBox "This macro needs to be ran by Kairos, please do not run it directly."
	ExitApp
}

#Include "..\..\lib\core\IPC.ahk"
#Include "..\..\lib\core\roblox.ahk"
#Include "..\..\lib\core\process_manager.ahk"
#Include "..\..\lib\core\Gdip_All.ahk"
#Include "..\..\lib\core\Gdip_ImageSearch.ahk"
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"
#Include "..\..\lib\utils\config.ahk"
#Include "..\..\lib\utils\custom_tooltip.ahk"
#Include "..\..\lib\utils\file_importer.ahk"
#Include "..\..\lib\core\path_runner.ahk"

if !(pToken := Gdip_Startup()) {
	throw Error("GDI+ failed to start, exiting script.")
}

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"
#Include "..\..\assets\bitmaps\Buffs.ahk"
#Include "..\..\assets\bitmaps\Movement.ahk"
#Include "..\..\assets\bitmaps\General.ahk"
#Include "..\..\assets\bitmaps\Sprinkler.ahk"
#Include "..\..\assets\bitmaps\Reset.ahk"

class alt_macro {
	static master_pid := ""
	static my_path := "scripts\alt\alt_macro.ahk"
	static current_state := "stopped"
	static startup_timer := 0
	static Fancy := 0
	static is_running := false
	static IGNORE_DO_NOT_REMOVE_IT_BREAKS_THE_MACRO := Gui()

	static slotMove := [
		[{ dir: "Right", dist: 4 }, { dir: ["Right", "Fwd"], dist: 20 }],
		[{ dir: ["Fwd", "Right"], dist: 13 }, { dir: "Fwd", dist: 6 }],
		[{ dir: "Fwd", dist: 20 }, { dir: "Back", dist: 4 }],
		[{ dir: ["Left", "Fwd"], dist: 13 }, { dir: "Fwd", dist: 6 }],
		[{ dir: "Left", dist: 4 }, { dir: ["Left", "Fwd"], dist: 20 }],
		[{ dir: ["Left", "Fwd"], dist: 12 }, { dir: "Left", dist: 13 }, { dir: ["Left", "Fwd"], dist: 10 }]
	]

	static settings := Map(
		"main", Map(
			"alt_macro_enabled", 0
		),
		"alt", Map(
			"hive_slot", 1,
			"move_speed", 29,
			"alt_number", 1,
			"field_drift_comp", 1,
			"default_field", "pepper",
			"pattern", "GeneralBooster",
			"use_tool", 1,
			"ignore_inactive_honey", 0,
			"pattern_size", 1,
			"pattern_width", 1,
			"rot_lr_amount", 0,
			"rot_lr_dir", "Right",
			"camera_pitch", 4,
			"shift_lock", 0,
			"sprinkler_location", "Center",
			"sprinkler_distance", 1,
			"priv_server", "",
			"claim_hive", 1,
			"coco_catch", 0
		)
	)

	static heartbeat_func := ObjBindMethod(this, "send_heartbeat")

	static init() {
		if (A_Args.Length > 0)
			this.master_pid := A_Args[1]

		this.Fancy := GdipTooltip()
		importPaths()
		importPatterns()

		if (this.master_pid)
			SetTimer(this.heartbeat_func, 2000)


		roblox.start_tracker()
		IPC.init(ObjBindMethod(this, "handle_command"))
		this.startup_timer := ObjBindMethod(this, "request_startup_settings")
		SetTimer(this.startup_timer, 250)
		this.request_startup_settings()
	}

	static request_startup_settings() {
		payload := Map("action", "request_startup_settings", "script", this.my_path, "pid", ProcessExist())
		try IPC.send_message("ahk_pid " this.master_pid, 1, payload)
	}

	static send_heartbeat(*) {
		payload := Map("action", "heartbeat", "script", this.my_path)
		IPC.send_message("ahk_pid " this.master_pid, 2, payload)
	}

	static handle_command(data) {
		action := data["action"]

		if (action == "set_state") {
			if (!data.Has("state"))
				return
			switch data["state"] {
				case "running", "start", "resumed":
					this.start()
				case "stopped", "stop":
					this.stop()
				case "paused":
					this.pause()
			}
			return
		}

		if (action == "apply_startup_settings") {
			if (this.HasOwnProp("startup_timer") && this.startup_timer) {
				SetTimer(this.startup_timer, 0)
				this.startup_timer := 0
			}

			for section_name, section_data in data["settings"] {
				if (!this.settings.Has(section_name))
					this.settings[section_name] := Map()
				for key, val in section_data
					this.settings[section_name][key] := val
			}

			ready_payload := Map(
				"action", "module_ready"
				, "script", this.my_path
			)
			SetTimer(ObjBindMethod(IPC, "send_message", "ahk_pid " this.master_pid, 1, ready_payload), -1)
			return
		}

		if (action == "update_setting") {
			section := data["section"]
			key := data["key"]
			val := data["value"]
			if (!this.settings.Has(section))
				this.settings[section] := Map()
			this.settings[section][key] := val
			return
		}

		if (action == "exit") {
			this.cleanup()
			ExitApp()
		}
	}

	static start() {
		if (this.current_state == "running")
			return
		this.current_state := "running"
		this.is_running := true

		if (this.settings["main"].Has("alt_macro_enabled") && this.settings["main"]["alt_macro_enabled"]) {
			this.Fancy.Show("Alt Macro: ON")
			roblox.activate()
			SetTimer(() => this.Fancy.Hide(), -500)
			SetTimer(ObjBindMethod(this, "main_loop"), 1000)
		}
	}

	static stop() {
		this.current_state := "stopped"
		this.is_running := false
		SetTimer(ObjBindMethod(this, "main_loop"), 0)
		this.cleanup()
	}

	static pause() {
		this.current_state := "paused"
		this.is_running := false
		SetTimer(ObjBindMethod(this, "main_loop"), 0)
		Path.Pause()
	}

	static cleanup() {
		Critical
		Path.End()
		Click("up")
	}

	static main_loop() {
		if (!this.is_running)
			return

		local inactiveHoney := 0

		if !(this.Reconnect())
			this.Reset()

		fieldName := this.settings["alt"]["default_field"]
		this.GotoField(fieldName)
		this.PlaceSprinkler()
		this.Rotation()
		this.EnableShift(1)
		Sleep(100)

		loop {
			if (!this.settings["alt"]["shift_lock"])
				MouseMove(A_ScreenWidth // 2, A_ScreenHeight // 2)

			if (this.settings["alt"]["use_tool"])
				Click("down")

			if (!this.is_running) {
				Click("up")
				break
			}

			this.Gather(this.settings["alt"]["pattern"], fieldName, A_Index)

			while (A_Index <= 3600) {
				if (KeyWait("F14", "T0.05 L") == 1) {
					Click("up")
					break
				}

				if (!this.is_running || this.isDead() || this.Reconnect()) {
					Click("up")
					break 2
				}

				if (Mod(A_Index, 10) == 0) {
					if (!this.ActiveHoney()) {
						if (++inactiveHoney >= 5) {
							Click("up")
							break 2
						}
					} else {
						inactiveHoney := 0
					}
				}
			}
			Click("up")

			if (this.settings["alt"]["field_drift_comp"] && Path.currentWalk.pid) {
				DetectHiddenWindows(true)
				if WinExist("ahk_class AutoHotkey ahk_pid " Path.currentWalk.pid) {
					PostMessage(0x5000, 3, 0, , "ahk_class AutoHotkey ahk_pid " Path.currentWalk.pid)
					if (KeyWait("F15", "D T1 L") == 1)
						KeyWait("F15", "T120 L")
				}
				DetectHiddenWindows(false)
			}
		}

		this.cleanup()
		Sleep(500)
	}

	static Gather(patternName, field, index) {
		if (!this.is_running)
			return
		if (!patterns.Has(patternName)) {
			this.Fancy.Show("Pattern '" patternName "' does not exist!")
			return
		}

		DetectHiddenWindows(true)
		pathRunning := WinExist("ahk_class AutoHotkey ahk_pid " Path.currentWalk.pid)

		if (index == 1 || !pathRunning) {
			Path.Run(patterns[patternName], "pattern")
			if (this.settings["alt"]["coco_catch"] && Path.currentWalk.pid) {
				Run('"' A_AhkPath '" "' A_WorkingDir '\scripts\Alt\CocoScanner.ahk" ' Path.currentWalk.pid, , "Hide", &cocoPID)
				Path.currentWalk.cocoPID := cocoPID
			}
		} else if (WinExist("ahk_class AutoHotkey ahk_pid " Path.currentWalk.pid)) {
			PostMessage(0x5000, 2, 0, , "ahk_class AutoHotkey ahk_pid " Path.currentWalk.pid)
		}

		DetectHiddenWindows(false)
		KeyWait("F14", "D T5 L")
	}

	static GotoField(fieldName) {
		if (!this.is_running)
			return

		field := StrReplace(fieldName, " ")
		if (!paths["gtf"].Has(field)) {
			MsgBox("Path not found: gtf-" field ".ahk")
			return
		}

		Path.Execute(paths["gtf"][field], "goto_" field)
		Sleep(100)
	}

	static PlaceSprinkler() {
		if (this.settings["alt"]["sprinkler_location"] == "Center") {
			Send("{" SC_1 "}")
			Sleep(500)
			return
		}

		fieldDims := Path.GetFieldSize(this.settings["alt"]["default_field"])
		scale := this.settings["alt"]["sprinkler_distance"] / 10
		loc := this.settings["alt"]["sprinkler_location"]
		moveX := 0
		moveY := 0

		if InStr(loc, "Upper")
			moveY := (fieldDims.height / 2) * scale
		else if InStr(loc, "Lower")
			moveY := -(fieldDims.height / 2) * scale

		if InStr(loc, "Left")
			moveX := -(fieldDims.width / 2) * scale
		else if InStr(loc, "Right")
			moveX := (fieldDims.width / 2) * scale

		if (moveY != 0) {
			key := (moveY > 0) ? FwdKey : BackKey
			Path.Execute('walk(' Abs(moveY) ', "' key '")', "sprinkler_y", 15)
		}
		if (moveX != 0) {
			key := (moveX > 0) ? RightKey : LeftKey
			Path.Execute('walk(' Abs(moveX) ', "' key '")', "sprinkler_x", 15)
		}
		Sleep(100)
		Send("{" SC_1 "}")
		Sleep(500)
	}

	static Rotation() {
		lr_amt := this.settings["alt"]["rot_lr_amount"]
		if (lr_amt > 0 && lr_amt <= 8) {
			lr_key := (this.settings["alt"]["rot_lr_dir"] == "Left") ? RotLeft : RotRight
			Send("{" lr_key " " lr_amt "}")
			Sleep(100)
		}
		targetPitch := this.settings["alt"]["camera_pitch"]
		currentPitch := 4
		diff := targetPitch - currentPitch

		if (diff > 0) {
			Send("{" RotDown " " diff "}")
			Sleep(100)
		} else if (diff < 0) {
			Send("{" RotUp " " Abs(diff) "}")
			Sleep(100)
		}
	}

	static EnableShift(state := 0) {
		win := roblox.get()
		if (!this.settings["alt"]["shift_lock"] || !win.is_ok)
			return

		roblox.activate()
		pBMScreen := Gdip_BitmapFromScreen(win.x + 5 "|" win.y + win.h - 54 "|50|50")
		if (pBMScreen) {
			if (Gdip_ImageSearch(pBMScreen, bitmaps["shiftlock"], , , , , , 2) != state)
				Send("{" SC_LShift "}")
			Gdip_DisposeImage(pBMScreen)
		}
		Sleep(50)
	}

	static Reconnect() {
		reconnect := 0
		win := roblox.get()

		if (!win.is_ok)
			reconnect := 1
		else {
			pBMScreen := Gdip_BitmapFromScreen(win.x + (win.w // 2) "|" win.y + win.h // 2 "|200|80")
			if (pBMScreen && Gdip_ImageSearch(pBMScreen, bitmaps["disconnected"], , , , , , 2) == 1)
				reconnect := 1
			if (pBMScreen)
				Gdip_DisposeImage(pBMScreen)
		}

		if (!reconnect)
			return 0

		Click("up")
		Path.End()
		link := Config.Get("alt", "priv_server", "")

		loop {
			success := 0
			roblox.close()
			roblox.join(link)

			loop 240 {
				if (roblox.get_hwnd()) {
					roblox.activate()
					break
				}
				if (A_Index == 240)
					break 2
				Sleep(1000)
			}

			loop 180 {
				roblox.activate()
				win := roblox.get()
				if (!win.is_ok) {
					Sleep(1000)
					continue
				}
				pBMScreen := Gdip_BitmapFromScreen(win.x "|" win.y + 30 "|" win.w "|" win.h - 30)
				if (!pBMScreen)
					continue

				if (Gdip_ImageSearch(pBMScreen, bitmaps["loading"], , , , , 150, 4) == 1) {
					Gdip_DisposeImage(pBMScreen)
					break
				}
				if (Gdip_ImageSearch(pBMScreen, bitmaps["science"], , , , , 150, 2) == 1) {
					Gdip_DisposeImage(pBMScreen)
					success := 1
					break 2
				}
				if (Gdip_ImageSearch(pBMScreen, bitmaps["disconnected"], , , , , , 2) == 1) {
					Gdip_DisposeImage(pBMScreen)
					continue 2
				}
				Gdip_DisposeImage(pBMScreen)
				if (A_Index == 180)
					break 2
				Sleep(1000)
			}

			loop 180 {
				roblox.activate()
				win := roblox.get()
				if (!win.is_ok)
					continue 2

				pBMScreen := Gdip_BitmapFromScreen(win.x "|" win.y + 30 "|" win.w "|" win.h - 30)
				if (!pBMScreen)
					continue

				if ((Gdip_ImageSearch(pBMScreen, bitmaps["loading"], , , , , 150, 4) == 0) || (Gdip_ImageSearch(pBMScreen, bitmaps["science"], , , , , 150, 2) == 1)) {
					Gdip_DisposeImage(pBMScreen)
					success := 1
					break 2
				}
				if (Gdip_ImageSearch(pBMScreen, bitmaps["disconnected"], , , , , , 2) == 1) {
					Gdip_DisposeImage(pBMScreen)
					continue 2
				}
				Gdip_DisposeImage(pBMScreen)
				if (A_Index == 180)
					break 2
				Sleep(1000)
			}
		}

		if (!success)
			return 0

		roblox.activate()
		win := roblox.get()
		MouseMove(win.x + (win.w // 2), win.y + (win.h // 2))
		Sleep(500)

		if (this.settings["alt"]["claim_hive"]) {
			if (this.ClaimHive())
				return 1
		} else {
			this.DetectSpawn()
			return 1
		}
	}

	static ClaimHive(ignoreCam := 0) {
		win := roblox.get()

		GetImg() {
			w_in := roblox.get()
			pBMScreen := Gdip_BitmapFromScreen(w_in.x + (w_in.w // 2) "|" w_in.y + w_in.y_offset "|400|125")
			while ((A_Index <= 20) && pBMScreen && (Gdip_ImageSearch(pBMScreen, bitmaps["FriendJoin"][1], , , , , , 3) == 1 || Gdip_ImageSearch(pBMScreen, bitmaps["FriendJoin"][2], , , , , , 3) == 1)) {
				Gdip_DisposeImage(pBMScreen)
				MouseMove(w_in.x + (w_in.w // 2) - 3, w_in.y + 24)
				Click()
				MouseMove(w_in.x + 350, w_in.y + w_in.y_offset + 100)
				Sleep(500)
				pBMScreen := Gdip_BitmapFromScreen(w_in.x + (w_in.w // 2) - 200 "|" w_in.y + w_in.y_offset "|400|125")
			}
			return pBMScreen
		}

		system := 1
		loop 5 {
			roblox.activate()
			win := roblox.get()
			MouseMove(win.x + 350, win.y + win.y_offset + 100)

			if (A_Index > 1) {
				PrevKeyDelay := A_KeyDelay
				SetKeyDelay(300)
				Send("{" SC_Esc "}{" SC_R "}{" SC_Enter "}")
				n := 0
				while ((n < 2) && (A_Index <= 70)) {
					Sleep(100)
					pBMScreen := Gdip_BitmapFromScreen(win.x "|" win.y "|" win.w "|50")
					if (pBMScreen) {
						n += ((Gdip_ImageSearch(pBMScreen, bitmaps["emptyhealth"], , , , , , 10) || this.HealthBar()) == (n == 0))
						Gdip_DisposeImage(pBMScreen)
					}
				}
				SetKeyDelay(PrevKeyDelay)
				Sleep(500)
			}
			if (!ignoreCam) {
				this.DetectSpawn()
			}

			if (system == 1) {
				movement := this.spawnMoveTo(this.slotMove[this.settings["alt"]["hive_slot"]])
				Path.Execute(movement, "claim_hive")
				Sleep(500)

				pBMScreen := GetImg()
				if (pBMScreen && Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) == 1) {
					Gdip_DisposeImage(pBMScreen)
					Send("{" SC_E " down}")
					Sleep(500)
					Send("{" SC_E " up}")
					MouseMove(win.x + 350, win.y + win.y_offset + 100)
					return 1
				} else if (this.atHive()) {
					MouseMove(win.x + 350, win.y + win.y_offset + 100)
					return 1
				}
				if (pBMScreen)
					Gdip_DisposeImage(pBMScreen)
				system := 0
				continue
			} else {
				Sleep(500)
				win := roblox.get()
				MouseMove(win.x + 350, win.y + win.y_offset + 100)
				Send("{" ZoomOut " 8}")

				movement := 'walk(4, "' RightKey '")`nwalk(20, "' RightKey '", "' FwdKey '")'
				Path.Execute(movement, "claim_hive")

				slots := Map()
				move := 'walk(9.2, "' LeftKey '")'
				Loop this.settings["alt"]["hive_slot"] {
					if (A_Index > 1) {
						Path.Execute(move, "claim_hive")
					}

					Sleep(500)
					pBMScreen := GetImg()
					if (pBMScreen && Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) == 1) {
						slots[A_Index] := 1
					}
					if (pBMScreen)
						Gdip_DisposeImage(pBMScreen)

					if (slots.Has(this.settings["alt"]["hive_slot"]) && (slots[this.settings["alt"]["hive_slot"]] == 1)) {
						break
					} else {
						if ((slot := ObjMinIndex(slots)) > 0) {
							movement := 'walk(' (this.settings["alt"]["hive_slot"] - slot) * 9.2 ', "' RightKey '")'
							Path.Execute(movement, "claim_hive")

							Sleep(500)
							pBMScreen := GetImg()
							if (pBMScreen && Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) == 1) {
								this.settings["alt"]["hive_slot"] := slot
								break
							}
							if (pBMScreen)
								Gdip_DisposeImage(pBMScreen)
						} else {
							Loop (6 - this.settings["alt"]["hive_slot"]) {
								Path.Execute(move, "claim_hive")
								Sleep(500)
								pBMScreen := GetImg()
								if (pBMScreen && Gdip_ImageSearch(pBMScreen, bitmaps["claimhive"], , , , , , 2, , 6) == 1) {
									this.settings["alt"]["hive_slot"] := A_Index
									break 2
								}
								if (pBMScreen)
									Gdip_DisposeImage(pBMScreen)
							}
						}
					}
					if (A_Index == 5)
						return 0
				}

				Send("{" SC_E " down}")
				Sleep(100)
				Send("{" SC_E " up}")
				MouseMove(win.x + 350, win.y + win.y_offset + 100)
				return 1
			}
		}
		return 0
	}

	static spawnMoveTo(moves) {
		script := ""
		for k in moves {
			if (Type(k.dir) == "Array")
				script .= 'walk(' k.dist ', "' %k.dir[1] "Key"% '", "' %k.dir[2] "Key"% '")`n'
			else
				script .= 'walk(' k.dist ', "' %k.dir "Key"% '")`n'
		}
		return script
	}

	static Reset() {
		static HiveDown := false
		this.EnableShift(0)
		win := roblox.get()
		this.Fancy.Show("Reset: Starting sequence...")

		Loop 5 {
			this.Fancy.Show("Reset: Attempt " A_Index " of 5")
			roblox.activate()
			win := roblox.get()
			PrevKeyDelay := A_KeyDelay
			SetKeyDelay(300)
			Send("{" SC_Esc "}{" SC_R "}{" SC_Enter "}")

			n := 0
			while ((n < 2) && (A_Index <= 50)) {
				Sleep(200)
				pBMScreen := Gdip_BitmapFromScreen(win.x "|" win.y "|" win.w "|50")
				if (pBMScreen) {
					n += ((Gdip_ImageSearch(pBMScreen, bitmaps["emptyhealth"], , , , , , 10) || this.HealthBar()) == (n == 0))
					Gdip_DisposeImage(pBMScreen)
				}
			}
			Sleep(750)
			SetKeyDelay(PrevKeyDelay)

			if (!this.settings["alt"]["claim_hive"]) {
				this.Fancy.Show("Reset: Checking spawn...")
				if (this.DetectSpawn()) {
					this.Fancy.Show("Reset: Spawn detected!")
					Sleep(1000)
					this.Fancy.Hide()
					return
				}
			} else {
				if (!this.atHive() && this.DetectSpawn()) {
					this.Fancy.Show("Reset: Claiming hive...")
					Sleep(500)
					if (this.ClaimHive(1)) {
						this.Fancy.Show("Reset: Hive claimed!")
						Sleep(1000)
						this.Fancy.Hide()
						return
					}
				}
				if (HiveDown)
					SendInput("{" RotDown "}")
				region := win.x "|" win.y + 3 * win.h // 4 "|" win.w "|" win.h // 4
				sconf := win.w ** 2 // 3200

				this.Fancy.Show("Reset: Scanning for hive...")
				loop 4 {
					Sleep(250)
					pBMScreen := Gdip_BitmapFromScreen(region)
					if (!pBMScreen)
						continue

					s := 0
					for i, k in bitmaps["hive"] {
						s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 5, , , sconf))
						if (s >= sconf) {
							Gdip_DisposeImage(pBMScreen)
							this.Fancy.Show("Reset: Hive located!")
							SendInput("{" RotRight " 4}" (HiveDown ? ("{" RotUp "}") : ""))
							Send("{" ZoomOut " 5}")
							Sleep(1000)
							this.Fancy.Hide()
							return
						}
					}
					Gdip_DisposeImage(pBMScreen)
					SendInput("{" RotRight " 4}" ((A_Index == 2) ? ("{" ((HiveDown := !HiveDown) ? RotDown : RotUp) "}") : ""))
				}
			}
		}

		this.Fancy.Show("Reset: Failed, reconnecting...")
		Sleep(1000)
		this.Fancy.Hide()
		roblox.close()
		if (this.Reconnect())
			return
	}

	static HealthBar() {
		detection := 0
		isDead(c) => ((((c) & 0x00FF0000 >= 0x004D0000) && ((c) & 0x00FF0000 <= 0x00830000)) && (((c) & 0x0000FF00 >= 0x00004D00) && ((c) & 0x0000FF00 <= 0x00008300)) && (((c) & 0x000000FF >= 0x0000004D) && ((c) & 0x000000FF <= 0x00000083)))
		try {
			win := roblox.get()
			pBMScreen := Gdip_BitmapFromScreen(win.x + win.w - 100 "|" win.y + win.y_offset "|50|24")
			if (pBMScreen) {
				p := Gdip_GetPixel(pBMScreen, 25, 12)
				if (isDead(p))
					detection := 1
				Gdip_DisposeImage(pBMScreen)
			}
		} catch {
			return 0
		}
		return detection
	}

	static atHive() {
		static fail := 0
		roblox.activate()
		win := roblox.get()
		pBMScreen := Gdip_BitmapFromScreen(win.x + win.w // 2 - 150 "|" win.y + win.y_offset + 40 "|350|60")
		if (!pBMScreen)
			return false

		out := (Gdip_ImageSearch(pBMScreen, bitmaps["honey"], , , , , , 5) == 1 || Gdip_ImageSearch(pBMScreen, bitmaps["collect"], , , , , , 5) == 1)
		Gdip_DisposeImage(pBMScreen)

		fail := out == 1 ? 0 : fail + 1
		if (fail > 3) {
			fail := 0
			return 1
		}
		return out
	}

	static DetectSpawn() {
		roblox.activate()
		win := roblox.get()
		loop 5 {
			Send("{" ZoomIn "}")
			Sleep(50)
		}
		Send("{" RotDown " 11}")
		Sleep(100)
		Send("{" RotUp " 5}")

		region := win.x "|" win.y "|" win.w "|" win.h // 4
		sconf := win.w ** 2 // 3200
		spawnConfirmed := 0

		loop 4 {
			Sleep(250)
			pBMScreen := Gdip_BitmapFromScreen(region)
			if (!pBMScreen)
				continue

			s := 0
			for i, k in bitmaps["spawn"] {
				s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 13, , , sconf))
				if (s >= sconf) {
					Gdip_DisposeImage(pBMScreen)
					spawnConfirmed := 1
					Send("{" RotUp " 2}")
					loop 5 {
						Send("{" ZoomOut "}")
						Sleep(50)
					}
					break 2
				}
			}
			Gdip_DisposeImage(pBMScreen)
			SendInput("{" RotRight " 4}")
		}
		return spawnConfirmed
	}

	static ActiveHoney() {
		static a := unset
		if (!IsSet(a)) {
			a := Gdip_CreateBitmap(1, 1)
			pGraphics := Gdip_GraphicsFromImage(a)
			Gdip_GraphicsClear(pGraphics, 0xFFFFE280)
			Gdip_DeleteGraphics(pGraphics)
		}

		win := roblox.get()
		if (!win.is_ok)
			return false

		if (this.settings["alt"]["ignore_inactive_honey"])
			return true

		pBMScreen := Gdip_BitmapFromScreen(win.x + win.w // 2 - 90 "|" win.y + win.y_offset "|70|34")
		if (!pBMScreen)
			return false

		if (Gdip_ImageSearch(pBMScreen, a, , , , , , 20) > 0) {
			Gdip_DisposeImage(pBMScreen)
			return true
		}

		Gdip_DisposeImage(pBMScreen)
		return false
	}

	static isDead() {
		static LastDeath := 0
		if ((nowUnix() - LastDeath) < 5)
			return true

		win := roblox.get()
		pBMScreen := Gdip_BitmapFromScreen(win.x + win.w // 2 "|" win.y + win.h // 2 "|" win.w // 2 "|" win.h // 2)
		if (!pBMScreen)
			return false

		if (Gdip_ImageSearch(pBMScreen, bitmaps["died"], , , , , , 50) == 1) {
			Gdip_DisposeImage(pBMScreen)
			LastDeath := nowUnix()
			return true
		}
		Gdip_DisposeImage(pBMScreen)
		return false
	}
}

alt_macro.init()