#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 255
#Warn VarUnset, Off

SetWorkingDir A_ScriptDir "\..\.."
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
CoordMode "ToolTip", "Screen"
SendMode "Event"

#Include "..\..\lib\core\IPC.ahk"
#Include "..\..\lib\core\roblox.ahk"
#Include "..\..\lib\core\process_manager.ahk"
#Include "..\..\lib\core\Gdip_All.ahk"
#Include "..\..\lib\core\Gdip_ImageSearch.ahk"
#Include "..\..\lib\core\scanner.ahk"
#Include "..\..\lib\core\detector.ahk"
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"
#Include "..\..\lib\utils\config.ahk"

if !(pToken := Gdip_Startup())
	throw Error("GDI+ failed to start, exiting script.")

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"
#Include "..\..\assets\bitmaps\Buffs.ahk"
#Include "..\..\assets\bitmaps\Boosts.ahk"
#Include "..\..\assets\bitmaps\Icons.ahk"
#Include "..\..\assets\bitmaps\StatMonitor_Buffs.ahk"

TraySetIcon "Assets\Images\Kairos.ico"

class buff_scanner {
	static master_pid := ""
	static my_path := "scripts\general\buff_scanner.ahk"
	static current_state := "stopped"
	static scanner := unset
	static last_data_str := ""
	static is_standalone := (A_Args.Length == 0)

	static broadcast_func := ObjBindMethod(this, "broadcast_data")

	static init() {
		config.Load()
		this.scanner := ScannerEngine()
		this.update_subscriptions()

		if (!this.is_standalone) {
			this.master_pid := A_Args[1]
			IPC.init(ObjBindMethod(this, "handle_command"))
			SetTimer(ObjBindMethod(this, "send_heartbeat"), 2000)
			ready_payload := Map("action", "module_ready", "script", this.my_path)
			SetTimer(() => IPC.send_message("ahk_pid " this.master_pid, 1, ready_payload), -1)
		} else {
			ToolTip("Buff Scanner - Standalone Debug Mode`nPress F1 to Start, F2 to Stop", 10, 10)
			Hotkey("F1", (*) => this.start(), "On")
			Hotkey("F2", (*) => this.stop(), "On")
			Hotkey("F3", (*) => this.restart(), "On")
		}
	}

	static update_subscriptions() {
		if (this.is_standalone) {
			this.scanner.subscribed_profiles := this.scanner.profiles.Clone()
			return
		}

		subs := Map()

		if (Config.Get("main", "tracker_enabled", 0)) {
			passives := StrSplit(Config.Get("tracker", "passives", ""), "|")
			for _, p in passives {
				if (p != "" && this.scanner.profiles.Has(p))
					subs[p] := this.scanner.profiles[p]
			}
		}

		if (Config.Get("main", "warns_enabled", 0)) {
			warn_key_map := Map("precise", "precise", "smoothie", "supersmoothie", "gummy", "gummystar", "pop", "popstar", "scorch", "scorch", "shower", "shower", "morph", "gummymorph", "baller", "gummyballer", "combo", "combo", "combo_buff", "combo_buff", "x_flame", "x-flame")
			for prefix, s_key in warn_key_map {
				if (Config.Get("warns", prefix "_enabled", 0) && this.scanner.profiles.Has(s_key)) {
					subs[s_key] := this.scanner.profiles[s_key]
				}
			}
		}

		if (Config.Get("main", "boost_bar_enabled", 0)) {
			mode_to_key := Map("Re-Glitter", "glitter", "On Scorch Star", "scorch", "Re-Smoothie", "supersmoothie", "On Pop Star", "popstar", "On Gummyballer", "gummyballer", "On Star Shower", "shower", "On Gummy Star", "gummystar", "On Gummy Morph", "gummymorph", "On Coconut Combo", "combo", "On X-Flame", "x-flame")
			loop 7 {
				if (Config.Get("boost_bar", "slot_active_" A_Index, 0)) {
					modes := StrSplit(Config.Get("boost_bar", "slot_mode_" A_Index, "Timer"), "|")
					for _, mode in modes {
						if (mode_to_key.Has(mode) && this.scanner.profiles.Has(mode_to_key[mode])) {
							subs[mode_to_key[mode]] := this.scanner.profiles[mode_to_key[mode]]
						}
					}
				}
			}
		}

		if (Config.Get("main", "stat_monitor_enabled", 0)) {
			subs := this.scanner.profiles.Clone()
		}

		if (this.scanner.profiles.Has("boosts_handler"))
			subs["boosts_handler"] := this.scanner.profiles["boosts_handler"]

		this.scanner.subscribed_profiles := subs
	}

	static handle_command(data) {
		action := data["action"]

		if (action == "update_setting") {
			Config.Set(data["section"], data["key"], data["value"])
			this.update_subscriptions()
			return
		}

		if (action == "set_state") {
			if (!data.Has("state"))
				return
			switch data["state"] {
				case "running", "start", "resumed":
					this.start()
				case "stopped", "stop", "paused":
					this.stop()
			}
			return
		}

		if (action == "exit") {
			this.stop()
			ExitApp()
		}
	}

	static start() {
		if (this.current_state == "running")
			return
		this.current_state := "running"

		this.scanner.toggle(1)
		roblox.start_tracker()
		SetTimer(this.broadcast_func, 100)
	}

	static stop() {
		this.current_state := "stopped"

		this.scanner.toggle(0)
		roblox.stop_tracker()
		SetTimer(this.broadcast_func, 0)

		if (this.is_standalone)
			ToolTip("Scanner Stopped.", 10, 10)
		ExitApp()
	}

	static restart() {
		Reload()
	}

	static format_time(total_secs) {
		if (total_secs <= 0)
			return "0s"
		if (total_secs < 60)
			return total_secs "s"

		mins := Floor(total_secs / 60)
		secs := Mod(total_secs, 60)

		if (secs > 0)
			return mins "m " secs "s"
		return mins "m"
	}

	static format_buff_data(raw_data) {
		formatted := Map(
			"passives", Map(),
			"buffs", Map(),
			"field_boosts", Map(),
			"custom", Map()
		)

		passives_list := ["scorch", "x-flame", "popstar", "gummymorph", "shower", "combo", "gummyballer"]
		for _, key in passives_list {
			val := raw_data.Has(key) ? raw_data[key] : -1
			formatted["passives"][key] := Map(
				"is_active", val != -1,
				"stacks", val != -1 ? val : 0
			)
		}

		buffs_config := Map(
			"supersmoothie", 1200,
			"precise", 60,
			"combo_buff", 30
		)
		for key, max_time in buffs_config {
			val := raw_data.Has(key) ? raw_data[key] : -1
			if (val != -1) {
				pct := Round(val)
				secs := Round((val / 100) * max_time)
				formatted["buffs"][key] := Map(
					"is_active", true,
					"percent", pct,
					"time_left", this.format_time(secs),
					"raw_secs", secs
				)
			} else {
				formatted["buffs"][key] := Map("is_active", false, "percent", 0, "time_left", "0s", "raw_secs", 0)
			}
		}

		glitter_val := raw_data.Has("glitter") ? raw_data["glitter"] : -1
		glitter_mult := raw_data.Has("glitter_mult") ? raw_data["glitter_mult"] : "0"

		if (glitter_val > 0) {
			pct := Round(glitter_val * 100)
			secs := Round(glitter_val * 900)
			formatted["field_boosts"]["glitter"] := Map(
				"is_active", true,
				"percent", pct,
				"multiplier", glitter_mult,
				"time_left", this.format_time(secs),
				"raw_secs", secs
			)
		} else {
			formatted["field_boosts"]["glitter"] := Map("is_active", false, "percent", 0, "multiplier", "0", "time_left", "0s", "raw_secs", 0)
		}

		gummy_pity := raw_data.Has("gummystar") ? raw_data["gummystar"] : -1
		formatted["custom"]["gummy_pity"] := Map(
			"is_active", gummy_pity != -1,
			"pity_count", gummy_pity != -1 ? gummy_pity : 0
		)

		return formatted
	}

	static broadcast_data() {
		if (this.current_state != "running")
			return

		win := roblox.get()
		if (!IsObject(win) || !win.is_ok)
			return

		if (!this.scanner.HasOwnProp("data") || !IsObject(this.scanner.data))
			return

		standardized_data := this.format_buff_data(this.scanner.data)
		current_data_str := JSON.stringify(standardized_data)

		if (current_data_str == this.last_data_str)
			return

		this.last_data_str := current_data_str

		if (this.is_standalone) {
			display_str := "=== buff_scanner LIVE DATA ===`n"

			for category, items in standardized_data {
				display_str .= "`n[" StrUpper(category) "]`n"
				for key, data in items {
					if (data["is_active"]) {
						if (data.Has("time_left") && data.Has("multiplier")) {
							val := "x" data["multiplier"] " | " data["percent"] "% | " data["time_left"]
						} else if (data.Has("time_left")) {
							val := data["percent"] "% | " data["time_left"]
						} else if (data.Has("stacks")) {
							val := "Stacks: " data["stacks"]
						} else if (data.Has("pity_count")) {
							val := "Pity: " data["pity_count"]
						} else {
							val := ""
						}
						display_str .= "  > " key ": ACTIVE (" val ")`n"
					} else {
						display_str .= "  - " key ": inactive`n"
					}
				}
			}
			ToolTip(display_str, win.x + 350, 200)
		} else {
			payload := Map(
				"action", "sync_buff_data",
				"data", standardized_data
			)
			IPC.send_message("ahk_pid " this.master_pid, 1, payload)
		}
	}

	static send_heartbeat(*) {
		payload := Map("action", "heartbeat", "script", this.my_path)
		try IPC.send_message("ahk_pid " this.master_pid, 2, payload)
	}
}

buff_scanner.init()