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
#Include "..\..\lib\core\Gdip_ImageSearch.ahk"
#Include "..\..\lib\core\scanner.ahk"
#Include "..\..\lib\core\detector.ahk"
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"
#Include "..\..\lib\utils\audio.ahk"
#Include "..\..\lib\utils\custom_tooltip.ahk"

if !(pToken := Gdip_Startup()) {
	throw Error("GDI+ failed to start, exiting script.")
}

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"
#Include "..\..\assets\bitmaps\Buffs.ahk"
#Include "..\..\assets\bitmaps\Icons.ahk"

TraySetIcon "Assets\Images\Kairos.ico"

class buff_warns {
	static master_pid := ""
	static my_path := "scripts\main\buff_warns.ahk"
	static default_sound_file := "C:\Windows\Media\Windows Critical Stop.wav"
	static min_sound_delay := 1000
	static max_sound_delay := 5000
	static default_warn_threshold := 25
	static default_warn_volume := 25
	static loop_interval := 150
	static startup_timer := 0

	static current_state := "stopped"
	static scanner := unset
	static tooltip_gui := 0

	static cached_audios := Map()
	static last_played_timestamps := Map()
	static has_played_states := Map()

	static warn_profiles := Map(
		"Precision", { conf: "precise", key: "precise", max: 60, mult: 0.6 }
		, "Super Smoothie", { conf: "smoothie", key: "supersmoothie", max: 1200, mult: 12.0 }
		, "Gummy Star", { conf: "gummy", key: "gummystar", max: 75 }
		, "Pop Star", { conf: "pop", key: "popstar", max: 30 }
		, "Scorching Star", { conf: "scorch", key: "scorch", max: 30 }
		, "Star Shower", { conf: "shower", key: "shower", max: 25 }
		, "Gummy Morph", { conf: "morph", key: "gummymorph", max: 30 }
		, "Gummyballer", { conf: "baller", key: "gummyballer", max: 1000 }
		, "Coconut Combo", { conf: "combo", key: "combo", max: 40 }
		, "Combo Buff", { conf: "combo_buff", key: "combo_buff", max: 30, mult: 0.3 }
		, "X-Flame", { conf: "x_flame", key: "x-flame", max: 25 }
	)

	static settings := Map(
		"main", Map(
			"warns_enabled", 0
		)
		, "warns", Map()
	)

	static check_func := ObjBindMethod(this, "check_loop")
	static heartbeat_func := ObjBindMethod(this, "send_heartbeat")

	static init() {
		if (A_Args.Length > 0) {
			this.master_pid := A_Args[1]
		}
		this.scanner := ScannerEngine()
		this.tooltip_gui := GdipTooltip()

		if (this.master_pid) {
			SetTimer(this.heartbeat_func, 2000)
		}

		IPC.init(ObjBindMethod(this, "handle_command"))
		this.startup_timer := ObjBindMethod(this, "request_startup_settings")
		SetTimer(this.startup_timer, 250)
		this.request_startup_settings()
	}

	static request_startup_settings() {
		payload := Map(
			"action", "request_startup_settings",
			"script", this.my_path,
			"pid", ProcessExist()
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
			return
		}
		if (action == "exit") {
			this.cleanup()
			ExitApp
		}
	}

	static start() {
		if (this.current_state == "running")
			return
		this.current_state := "running"
		this.scanner.Toggle(1)
		Roblox.start_tracker()
		SetTimer(this.check_func, this.loop_interval)

		if (this.settings["main"].Has("warns_enabled") && this.settings["main"]["warns_enabled"]) {
			if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Show")) {
				this.tooltip_gui.Show("Warns: ON")
				SetTimer(() => this.tooltip_gui.Hide(), -500)
			}
		}
	}

	static stop() {
		if (this.current_state == "stopped")
			return
		this.current_state := "stopped"
		this.scanner.Toggle(0)
		Roblox.stop_tracker()
		SetTimer(this.check_func, 0)
		if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Show")) {
			this.tooltip_gui.Show("Warns: OFF")
			SetTimer(() => this.tooltip_gui.Hide(), -500)
		}
	}

	static pause() {
		if (this.current_state == "paused")
			return
		this.current_state := "paused"
		this.scanner.Toggle(0)
		SetTimer(this.check_func, 0)
		if (this.tooltip_gui && HasMethod(this.tooltip_gui, "Show")) {
			this.tooltip_gui.Show("Warns: PAUSED")
			SetTimer(() => this.tooltip_gui.Hide(), -500)
		}
	}

	static cleanup() {
		this.stop()
	}

	static check_loop(*) {
		if (this.current_state != "running" || !this.settings["main"].Has("warns_enabled") || !this.settings["main"]["warns_enabled"]) {
			return
		}

		debug_str := "=== WARNS DEBUG ===`n"

		for warn_name, profile in this.warn_profiles {
			prefix := profile.conf
			enabled_key := prefix "_enabled"
			is_enabled := this.settings["warns"].Has(enabled_key) ? this.settings["warns"][enabled_key] : 0

			if (!is_enabled) {
				continue
			}

			if (!this.has_played_states.Has(warn_name)) {
				this.has_played_states[warn_name] := false
			}
			if (!this.last_played_timestamps.Has(warn_name)) {
				this.last_played_timestamps[warn_name] := 0
			}

			current_val := 0
			if (this.scanner.Data.Has(profile.key)) {
				current_val := this.scanner.Data[profile.key]
			}

			threshold_key := prefix "_threshold"
			threshold := this.settings["warns"].Has(threshold_key) ? this.settings["warns"][threshold_key] : this.default_warn_threshold

			debug_str .= warn_name " -> Raw: " current_val " | Thresh: " threshold "`n"

			if (current_val <= 0) {
				this.has_played_states[warn_name] := false
				continue
			}

			is_triggered := false
			ratio := 1.0

			if (profile.HasProp("mult")) {
				scaled_val := Round(profile.mult * current_val)
				debug_str .= "   Scaled: " scaled_val "`n"
				if (scaled_val <= threshold) {
					is_triggered := true
					ratio := scaled_val / threshold
				}
			}

			if (!profile.HasProp("mult")) {
				if (current_val >= threshold) {
					is_triggered := true
					denominator := Max(1, profile.max - threshold)
					ratio := Max(0, Min(1, (profile.max - current_val) / denominator))
				}
			}

			if (is_triggered) {
				debug_str .= "   >>> TRIGGERED! Ratio: " Round(ratio, 2) "`n"
				this.handle_alert(warn_name, ratio)
			} else {
				this.has_played_states[warn_name] := false
			}
		}

		ToolTip(debug_str, 10, 250, 19)
	}

	static handle_alert(warn_name, ratio) {
		prefix := this.warn_profiles[warn_name].conf

		vol_key := prefix "_volume"
		play_once_key := prefix "_play_once"
		sound_key := prefix "_sound_file"

		vol := this.settings["warns"].Has(vol_key) ? this.settings["warns"][vol_key] : this.default_warn_volume
		should_play_once := this.settings["warns"].Has(play_once_key) ? this.settings["warns"][play_once_key] : 0
		sound_path := this.settings["warns"].Has(sound_key) ? this.settings["warns"][sound_key] : this.default_sound_file

		if (should_play_once) {
			if (!this.has_played_states[warn_name]) {
				this.play_sound(sound_path, vol)
				this.has_played_states[warn_name] := true
			}
			return
		}

		delay := this.min_sound_delay + (ratio * (this.max_sound_delay - this.min_sound_delay))
		if (A_TickCount - this.last_played_timestamps[warn_name] >= delay) {
			this.last_played_timestamps[warn_name] := A_TickCount
			this.play_sound(sound_path, vol)
		}
	}

	static play_sound(path, vol) {
		if (!FileExist(path)) {
			if (FileExist(this.default_sound_file)) {
				path := this.default_sound_file
			} else {
				tooltip "Warning: Default sound file not found."
				return
			}
		}

		if (!this.cached_audios.Has(path)) {
			try {
				this.cached_audios[path] := Audio(path)
			}
		}

		if (this.cached_audios.Has(path)) {
			this.cached_audios[path].Play(vol)
		}
	}

	static send_heartbeat(*) {
		payload := Map(
			"action", "heartbeat"
			, "script", this.MY_PATH
		)
		try IPC.send_message("ahk_pid " this.MASTER_PID, 2, payload)
	}

}

buff_warns.init()