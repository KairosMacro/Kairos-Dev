#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 255
#Warn VarUnset, Off

SetWorkingDir A_ScriptDir "\..\.."
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SendMode "Event"

if (A_Args.Length = 0) {
	MsgBox "This macro needs to be ran by Kairos, please do not run it directly."
	ExitApp
}

#Include "..\..\lib\core\IPC.ahk"
#Include "..\..\lib\core\roblox.ahk"
#Include "..\..\lib\core\process_manager.ahk"
#Include "..\..\lib\core\Gdip_All.ahk"
#INclude "..\..\lib\core\Gdip_ImageSearch.ahk"
#Include "..\..\lib\core\scanner.ahk"
#Include "..\..\lib\core\detector.ahk"
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"
#Include "..\..\lib\utils\custom_tooltip.ahk"

if !(pToken := Gdip_Startup()) {
	throw Error("GDI+ failed to start, exiting script.")
}

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"
#Include "..\..\assets\bitmaps\Buffs.ahk"
#Include "..\..\assets\bitmaps\Icons.ahk"

TraySetIcon "Assets\Images\Kairos.ico"

class buff_tracker {
	static master_pid := ""
	static my_path := "scripts\main\buff_tracker.ahk"
	static loop_interval := 100
	static WM_EXITSIZEMOVE := 0x0232
	static startup_timer := 0

	static current_state := "stopped"
	static is_edit_mode := false
	static offset_x := 0
	static offset_y := 0

	static scanner := unset
	static tooltip_gui := 0

	static cooldowns := Map(
		"scorch", { last_not_found: 0, cooldown: 60000, duration: 45000 }
		, "x-flame", { last_not_found: 0, cooldown: 20000, duration: 0 }
		, "popstar", { last_not_found: 0, cooldown: 60000, duration: 45000 }
		, "gummystar", { last_not_found: 0, cooldown: 60000, duration: 45000 }
	)

	static caps := Map(
		"scorch", 30
		, "x-flame", 25
		, "popstar", 45
		, "gummystar", 75
		, "combo", 40
	)

	static settings := Map(
		"main", Map(
			"tracker_enabled", 0
		)
		, "tracker", Map(
			"passives", "scorch"
			, "offset_x", 0
			, "offset_y", 0
			, "zoom", 1.0
		)
	)

	static check_func := ObjBindMethod(this, "check_loop")
	static heartbeat_func := ObjBindMethod(this, "send_heartbeat")

	static init() {
		if (A_Args.Length > 0) {
			this.master_pid := A_Args[1]
		}
		this.scanner := ScannerEngine()
		this.tooltip_gui := GdipTooltip(true)

		if (this.master_pid) {
			SetTimer(this.heartbeat_func, 2000)
		}

		OnMessage(this.WM_EXITSIZEMOVE, ObjBindMethod(this, "on_drag_end"))

		IPC.init(ObjBindMethod(this, "handle_command"))
		this.startup_timer := ObjBindMethod(this, "request_startup_settings")
		SetTimer(this.startup_timer, 250)
		this.request_startup_settings()
	}

	static request_startup_settings() {
		payload := Map(
			"action", "request_startup_settings"
			, "script", this.MY_PATH
			, "pid", ProcessExist()
		)
		try IPC.send_message("ahk_pid " this.master_pid, 1, payload)
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
				case "toggle":
					(this.current_state == "running") ? this.stop() : this.start()
			}
			return
		}

		if (action == "apply_startup_settings") {
			if (this.HasOwnProp("startup_timer") && this.startup_timer) {
				SetTimer(this.startup_timer, 0)
				this.startup_timer := 0
			}

			for section_name, section_data in data["settings"] {
				if (!this.settings.Has(section_name)) {
					this.settings[section_name] := Map()
				}
				for key, val in section_data {
					this.settings[section_name][key] := val
				}
			}
			this.offset_x := this.settings["tracker"]["offset_x"]
			this.offset_y := this.settings["tracker"]["offset_y"]
			if (this.tooltip_gui) {
				this.tooltip_gui.Zoom := this.settings["tracker"]["zoom"]
			}

			ready_payload := Map(
				"action", "module_ready"
				, "script", this.my_path
			)
			SetTimer(() => IPC.send_message("ahk_pid " this.master_pid, 1, ready_payload), -1)
			return
		}

		if (action == "update_setting") {
			section := data["section"]
			key := data["key"]
			val := data["value"]

			if (!this.settings.Has(section)) {
				this.settings[section] := Map()
			}
			this.settings[section][key] := val

			if (key == "offset_x") {
				this.offset_x := val
			}
			if (key == "offset_y") {
				this.offset_y := val
			}
			if (key == "zoom" && this.tooltip_gui) {
				this.tooltip_gui.Zoom := val
			}
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
		this.scanner.Toggle(1)
		SetTimer(this.check_func, this.loop_interval)
	}

	static stop() {
		if (this.current_state == "stopped")
			return
		this.current_state := "stopped"
		this.scanner.Toggle(0)
		SetTimer(this.check_func, 0)
		if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Hide"))
			SetTimer(() => this.tooltip_gui.Hide(), -100)
	}

	static pause() {
		if (this.current_state == "paused")
			return
		this.current_state := "paused"
		this.scanner.Toggle(0)
		SetTimer(this.check_func, 0)
		if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Hide"))
			SetTimer(() => this.tooltip_gui.Hide(), -100)
	}

	static cleanup() {
		this.stop()
	}

	static check_loop(*) {
		if (this.current_state != "running" || this.is_edit_mode || !this.settings["main"].Has("tracker_enabled") || !this.settings["main"]["tracker_enabled"]) {
			return
		}

		if (this.tooltip_gui.Zoom != this.settings["tracker"]["zoom"]) {
			this.save_setting_to_master("tracker", "zoom", this.tooltip_gui.Zoom)
		}

		win := Roblox.Get()
		if (!IsObject(win) || !win.ok) {
			return
		}

		msg_queue := []
		passive_list := StrSplit(this.settings["tracker"]["passives"], "|")
		for passive_name in passive_list {
			if (!this.scanner.Profiles.Has(passive_name)) {
				continue
			}

			val := this.scanner.Data[passive_name]

			if (passive_name == "precise") {
				val := (val == -1) ? -1 : this.format_time(Round((val / 100) * 60))
			}
			if (passive_name == "combo_buff") {
				val := (val == -1) ? -1 : this.format_time(Round((val / 100) * 30))
			}
			if (passive_name == "supersmoothie") {
				val := (val == -1) ? -1 : this.format_time(Round((val / 100) * 1200))
			}

			msg_suffix := ""
			if (val == -1) {
				msg_suffix := ": N/A"
				if (this.cooldowns.Has(passive_name)) {
					cooldown_data := this.cooldowns[passive_name]
					if (cooldown_data.last_not_found != 0) {
						elapsed := QPC() - cooldown_data.last_not_found

						if (elapsed <= cooldown_data.duration) {
							active_rem := Round((cooldown_data.duration - elapsed) / 1000)
							msg_suffix := ": Active: " active_rem "s"
						}
						if (elapsed > cooldown_data.duration) {
							cd_rem := Round((cooldown_data.cooldown - elapsed) / 1000)
							msg_suffix := ": CD: " cd_rem "s"
						}
					}
				}
			}
			if (val != -1) {
				if (this.cooldowns.Has(passive_name)) {
					this.cooldowns[passive_name].last_not_found := QPC()
				}
				msg_suffix := ": " val
				if (this.caps.Has(passive_name)) {
					msg_suffix .= " / " this.caps[passive_name]
				}
			}

			icon_bmp := (IsSet(bitmaps) && bitmaps.Has("icon") && bitmaps["icon"].Has(passive_name)) ? bitmaps["icon"][passive_name] : 0
			msg_queue.Push([icon_bmp, msg_suffix])
		}
		target_x := (win.x + win.w // 2) + this.offset_x
		target_y := (win.y + win.h // 2) + this.offset_y
		this.tooltip_gui.Show(msg_queue, target_x, target_y)
	}

	static format_time(total_secs) {
		if (total_secs <= 60) {
			return total_secs "s"
		}

		mins := Floor(total_secs / 60)
		secs := Mod(total_secs, 60)

		if (secs > 0) {
			return mins "m " secs "s"
		}

		return mins "m"
	}

	static on_drag_end(w_param, l_param, msg, hwnd) {
		if (hwnd != this.tooltip_gui.hwnd) {
			return
		}

		win := Roblox.Get()
		if (!IsObject(win) || !win.ok) {
			return
		}

		WinGetPos(&gui_x, &gui_y, , , "ahk_id " this.tooltip_gui.hwnd)

		new_offset_x := gui_x - (win.x + win.w // 2)
		new_offset_y := gui_y - (win.y + win.h // 2)

		this.save_setting_to_master("tracker", "offset_x", new_offset_x)
		this.save_setting_to_master("tracker", "offset_y", new_offset_y)

		this.tooltip_gui._manualPos := false
	}

	static save_setting_to_master(section, key, val) {
		payload := Map(
			"action", "save_setting"
			, "section", section
			, "key", key
			, "value", val
		)
		try IPC.send_message("ahk_pid " this.MASTER_PID, 1, payload)

		if (!this.settings.Has(section)) {
			this.settings[section] := Map()
		}
		this.settings[section][key] := val
	}

	static send_heartbeat(*) {
		payload := Map(
			"action", "heartbeat"
			, "script", this.MY_PATH
		)
		try IPC.send_message("ahk_pid " this.MASTER_PID, 2, payload)
	}
}

buff_tracker.init()