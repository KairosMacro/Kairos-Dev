#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 255
#Warn VarUnset, Off
#NoTrayIcon

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
#Include "..\..\lib\core\Gdip_ImageSearch.ahk"
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

	static latest_buff_data := Map()

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
		this.tooltip_gui := GdipTooltip(true)

		if (this.master_pid) {
			SetTimer(this.heartbeat_func, 2000)
		}

		roblox.start_tracker()

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

		if (action == "sync_buff_data") {
			this.latest_buff_data := data["data"]
			return
		}

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
		SetTimer(this.check_func, this.loop_interval)
	}

	static stop() {
		if (this.current_state == "stopped")
			return
		this.current_state := "stopped"
		SetTimer(this.check_func, 0)
		if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Hide"))
			SetTimer(() => this.tooltip_gui.Hide(), -100)
	}

	static pause() {
		if (this.current_state == "paused")
			return
		this.current_state := "paused"
		SetTimer(this.check_func, 0)
		if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Hide"))
			SetTimer(() => this.tooltip_gui.Hide(), -100)
	}

	static cleanup() {
		this.stop()
	}

	static calculate_color(passive_name, current_val) {
		try {
			warn_prefix_map := Map(
				"combo", "combo"
				, "scorch", "scorch"
				, "x-flame", "x_flame"
				, "gummystar", "gummy"
				, "gummymorph", "morph"
				, "gummyballer", "baller"
				, "popstar", "pop"
				, "shower", "shower"
			)

			reverse_warn_prefix_map := Map(
				"precise", "precise"
				, "combo_buff", "combo_buff"
				, "supersmoothie", "smoothie"
			)

			warn_prefix := ""
			is_reverse := false

			if (warn_prefix_map.Has(passive_name)) {
				warn_prefix := warn_prefix_map[passive_name]
			} else if (reverse_warn_prefix_map.Has(passive_name)) {
				warn_prefix := reverse_warn_prefix_map[passive_name]
				is_reverse := true
			}

			max_val := 100
			if (this.caps.Has(passive_name)) {
				max_val := this.caps[passive_name]
			} else if (passive_name == "precise") {
				max_val := 60
			} else if (passive_name == "supersmoothie") {
				max_val := 1200
			} else if (passive_name == "gummystar") {
				max_val := 75
			} else if (passive_name == "popstar" || passive_name == "scorch" || passive_name == "gummymorph" || passive_name == "combo_buff") {
				max_val := 30
			} else if (passive_name == "shower" || passive_name == "x-flame") {
				max_val := 25
			} else if (passive_name == "combo") {
				max_val := 40
			} else if (passive_name == "gummyballer") {
				max_val := 1000
			}

			ratio := 0.0

			if (warn_prefix != "" && this.settings.Has("warns")) {
				warn_threshold := this.settings["warns"].Has(warn_prefix "_threshold") ? this.settings["warns"][warn_prefix "_threshold"] : 0
				is_enabled := this.settings["warns"].Has(warn_prefix "_enabled") ? this.settings["warns"][warn_prefix "_enabled"] : 0

				if (is_enabled && warn_threshold > 0) {
					if (is_reverse) {
						range := max_val - warn_threshold
						if (range <= 0) {
							range := 1
						}
						ratio := (current_val - warn_threshold) / range
					} else {
						ratio := current_val / warn_threshold
					}
				} else {
					ratio := current_val / max_val
				}
			} else {
				ratio := current_val / max_val
			}

			ratio := Max(0.0, Min(1.0, ratio))

			red_val := 0
			green_val := 0

			if (ratio <= 0.5) {
				red_val := 255
				green_val := Round(255 * (ratio / 0.5))
			} else {
				red_val := Round(255 * ((1.0 - ratio) / 0.5))
				green_val := 255
			}

			return Format("FF{:02X}{:02X}00", red_val, green_val)
		} catch {
			return "FFFFFFFF"
		}
	}

	static check_loop(*) {
		if (this.current_state != "running" || this.is_edit_mode || !this.settings["main"].Has("tracker_enabled") || !this.settings["main"]["tracker_enabled"]) {
			if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Hide")) {
				this.tooltip_gui.Hide()
			}
			return
		}

		if (this.tooltip_gui.Zoom != this.settings["tracker"]["zoom"]) {
			this.save_setting_to_master("tracker", "zoom", this.tooltip_gui.Zoom)
		}

		win := Roblox.Get()
		if (!IsObject(win) || !win.is_ok || !this.latest_buff_data.Has("passives")) {
			return
		}

		msg_queue := []
		passive_list := StrSplit(this.settings["tracker"]["passives"], "|")

		for passive_name in passive_list {
			if (passive_name == "") {
				continue
			}

			buff_info := this.get_standard_data(passive_name, this.latest_buff_data)
			is_active := buff_info["is_active"]

			msg_suffix := ""
			color_hex := "FFFFFFFF"

			if (!is_active) {
				msg_suffix := ": N/A"
				color_hex := "FF777777"

				if (this.cooldowns.Has(passive_name)) {
					cooldown_data := this.cooldowns[passive_name]
					if (cooldown_data.last_not_found != 0) {
						elapsed := QPC() - cooldown_data.last_not_found

						if (elapsed <= cooldown_data.duration) {
							active_rem := Round((cooldown_data.duration - elapsed) / 1000)
							msg_suffix := ": Active: " active_rem "s"
							color_hex := "FF4CAF50"
						} else if (elapsed > cooldown_data.duration) {
							cd_rem := Round((cooldown_data.cooldown - elapsed) / 1000)
							msg_suffix := ": CD: " cd_rem "s"
							cd_total := (cooldown_data.cooldown - cooldown_data.duration) / 1000
							ratio := Max(0, Min(1, cd_rem / cd_total))
							green_val := Round(255 * (1 - ratio))
							color_hex := Format("FFFF{:02X}00", green_val)
						}
					}
				}
			} else {
				if (this.cooldowns.Has(passive_name)) {
					this.cooldowns[passive_name].last_not_found := QPC()
				}

				num_val := 0
				if (buff_info.Has("time_left")) {
					msg_suffix := ": " buff_info["time_left"]
					num_val := buff_info["raw_secs"]
				} else if (buff_info.Has("stacks")) {
					msg_suffix := ": " buff_info["stacks"]
					num_val := buff_info["stacks"]
				}

				if (this.caps.Has(passive_name)) {
					msg_suffix .= " / " this.caps[passive_name]
				}

				color_hex := this.calculate_color(passive_name, num_val)
			}

			icon_bmp := (IsSet(bitmaps) && bitmaps.Has("icon") && bitmaps["icon"].Has(passive_name)) ? bitmaps["icon"][passive_name] : 0
			msg_queue.Push([icon_bmp, { Text: msg_suffix, Color: color_hex }])
		}

		if (msg_queue.Length == 0) {
			if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Hide")) {
				this.tooltip_gui.Hide()
			}
			return
		}

		target_x := (win.x + win.w // 2) + this.offset_x
		target_y := (win.y + win.h // 2) + this.offset_y
		this.tooltip_gui.Show(msg_queue, target_x, target_y)
	}

	static get_standard_data(passive_name, std_data) {
		if (std_data["passives"].Has(passive_name)) {
			return std_data["passives"][passive_name]
		}
		if (std_data["buffs"].Has(passive_name)) {
			return std_data["buffs"][passive_name]
		}
		if (passive_name == "gummystar" && std_data["custom"].Has("gummy_pity")) {
			val := std_data["custom"]["gummy_pity"]
			return Map("is_active", val["is_active"], "stacks", val["pity_count"])
		}
		return Map("is_active", false, "stacks", 0)
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
		if (!IsObject(win) || !win.is_ok) {
			return
		}

		WinGetPos(&gui_x, &gui_y, , , "ahk_id " this.tooltip_gui.hwnd)

		new_offset_x := gui_x - (win.x + win.w // 2)
		new_offset_y := gui_y - (win.y + win.h // 2)

		this.offset_x := new_offset_x
		this.offset_y := new_offset_y

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