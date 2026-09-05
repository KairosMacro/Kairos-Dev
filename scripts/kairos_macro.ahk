#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 255
#Warn VarUnset, Off

if (A_ScreenDPI != 96) {
	MsgBox "
	(
		Kairos is designed to work at 100% scaling. Please set your display scaling to 100% and restart the script.
		
		To fix this:
		1. Right-click on your desktop and select 'Display settings'.
		2. Under 'Scale', select '100%' from the dropdown menu.
		
		The script will close now.
	)", "Kairos - WARNING!!!", 48 " T30"
	ExitApp
}

TraySetIcon "..\assets\images\Kairos.ico"

SetWorkingDir A_ScriptDir "\.."
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
SendMode "Event"

#Include "..\lib\core\IPC.ahk"
#Include "..\lib\core\process_manager.ahk"
#Include "..\lib\utils\JSON.ahk"
#Include "..\lib\utils\config.ahk"
#Include "..\lib\utils\utility.ahk"
#Include "..\lib\utils\audio.ahk"

OnError(log_error)

config.Load()

class kairos_main {
	static BTN_W := 120
	static BTN_H := 20
	static BTN_Y := 280
	static WM_VSCROLL := 0x0115
	static SB_BOTTOM := 7

	static expected_modules := [
		"scripts\main\magnification.ahk",
		"scripts\main\key_alignment.ahk",
		"scripts\general\boost_bar.ahk",
		"scripts\main\buff_warns.ahk",
		"scripts\main\buff_tracker.ahk"
	]
	static ready_modules := Map()
	static loading_gui := unset
	static log_edit := unset
	static is_paused := false
	static ui_controls := Map()

	static selected_warn_prefix := "scorch"
	static warn_items := [
		["precise", "Precision", 60],
		["smoothie", "Super Smoothie", 1200],
		["gummy", "Gummy Star", 75],
		["pop", "Pop Star", 30],
		["scorch", "Scorch Star", 30],
		["shower", "Star Shower", 25],
		["morph", "Gummy Morph", 30],
		["baller", "Gummyballer", 1000],
		["combo", "Coco Combo", 40],
		["combo_buff", "Combo Buff", 30],
		["xflame", "X-Flame", 25]
	]
	static tracker_items := [
		["precise", "Precision"],
		["supersmoothie", "Super Smoothie"],
		["combo", "Coconut Combo"],
		["scorch", "Scorch Star"],
		["x-flame", "X-Flame"],
		["gummystar", "Gummy Star"],
		["gummymorph", "Gummy Morph"],
		["gummyballer", "Gummy Baller"],
		["popstar", "Pop Star"],
		["starshower", "Star Shower"],
		["cocoinspire", "Coconut Inspire"]
	]

	static init() {
		OnExit((*) => process_manager.kill_all())
		IPC.init(ObjBindMethod(this, "handle_command"))
		this.show_loading_screen()

		for index, script_path in this.expected_modules {
			this.ready_modules[script_path] := false
			this.log_msg("Launching: " script_path)
			process_manager.launch_script(script_path)
		}
		SetTimer(ObjBindMethod(process_manager, "check_heartbeats"), 2500)
	}

	static show_loading_screen() {
		this.loading_gui := Gui("-Caption +AlwaysOnTop +Border +ToolWindow", "Kairos Macro - Loading")

		this.loading_gui.SetFont("s12 Bold", "Segoe UI")
		this.loading_gui.Add("Text", "w350 h25 Center 0x200", "Initializing Modules...")

		this.loading_gui.SetFont("s8", "Segoe UI")
		this.loading_gui.Add("Text", "w350 h15 Center cGray", "(Press Esc to exit)")

		this.loading_gui.SetFont("s9", "Consolas")
		this.log_edit := this.loading_gui.Add("Edit", "w350 h150 ReadOnly", "Starting IPC Server...`r`n")

		Hotkey("Escape", (*) => this.on_exit(), "On")

		this.loading_gui.Show("NoActivate")
	}

	static log_msg(msg) {
		if (!this.HasOwnProp("log_edit") || !this.log_edit) {
			return
		}

		try {
			this.log_edit.Value .= msg "`r`n"
			SendMessage(this.WM_VSCROLL, this.SB_BOTTOM, 0, this.log_edit.hwnd)
		} catch {
			this.log_edit := false
			return
		}
	}

	static check_startup_completion() {
		for script_path, is_ready in this.ready_modules {
			if (!is_ready) {
				return
			}
		}

		this.log_msg("All modules ready, Enjoy boosting!!!")
		Sleep(750)
		this.loading_gui.Destroy()
		this.log_edit := false

		Hotkey("Escape", "Off")

		this.build_ui()
		this.register_hotkeys()
	}

	static handle_command(data) {
		action := data["action"]

		if (action == "module_ready") {
			script := data["script"]
			this.log_msg("[OK] Ready: " script)

			if (this.ready_modules.Has(script)) {
				this.ready_modules[script] := true
				this.check_startup_completion()
			}
			return
		}

		if (action == "request_startup_settings") {
			script := data["script"]
			this.log_msg("[REQ] Settings: " script)

			payload := Map(
				"action", "apply_startup_settings"
				, "settings", Map()
			)

			if (InStr(script, "magnification.ahk")) {
				payload["settings"] := Map(
					"main", Map(
						"magnifier_enabled", Config.Get("main", "magnifier_enabled", 0)
						, "boost_bar_enabled", Config.Get("main", "boost_bar_enabled", 0)
						, "show_when_active", Config.Get("main", "show_when_active", 1)
					)
					, "magnifier", Map(
						"zoom_factor", Config.Get("magnifier", "zoom_factor", 1.3)
						, "target_offset", Config.Get("magnifier", "target_offset", -300)
						, "offset_x", Config.Get("magnifier", "offset_x", 260)
						, "offset_y", Config.Get("magnifier", "offset_y", 230)
						, "fps", Config.Get("magnifier", "fps", 30)
					)
				)
			}

			if (InStr(script, "key_alignment.ahk")) {
				payload["settings"] := Map(
					"main", Map(
						"key_alignment_enabled", Config.Get("main", "key_alignment_enabled", 0)
					)
					, "key_alignment", Map(
						"alignment_key", Config.Get("key_alignment", "alignment_key", "e")
						, "rebind_hotkey", Config.Get("key_alignment", "rebind_hotkey", "^+k")
						, "rot_right", Config.Get("key_alignment", "rot_right", ",")
						, "rot_left", Config.Get("key_alignment", "rot_left", ".")
					)
				)
			}

			if (InStr(script, "boost_bar.ahk")) {
				payload["settings"] := Map(
					"main", Map(
						"boost_bar_enabled", Config.Get("main", "boost_bar_enabled", 0)
					)
					, "boost_bar", Map(
						"show_when_active", Config.Get("boost_bar", "show_when_active", 1)
						, "slot_active_1", Config.Get("boost_bar", "slot_active_1", 0)
						, "slot_timer_1", Config.Get("boost_bar", "slot_timer_1", 100)
						, "slot_mode_1", Config.Get("boost_bar", "slot_mode_1", "Timer")
						, "slot_active_2", Config.Get("boost_bar", "slot_active_2", 0)
						, "slot_timer_2", Config.Get("boost_bar", "slot_timer_2", 100)
						, "slot_mode_2", Config.Get("boost_bar", "slot_mode_2", "Timer")
						, "slot_active_3", Config.Get("boost_bar", "slot_active_3", 0)
						, "slot_timer_3", Config.Get("boost_bar", "slot_timer_3", 100)
						, "slot_mode_3", Config.Get("boost_bar", "slot_mode_3", "Timer")
						, "slot_active_4", Config.Get("boost_bar", "slot_active_4", 0)
						, "slot_timer_4", Config.Get("boost_bar", "slot_timer_4", 100)
						, "slot_mode_4", Config.Get("boost_bar", "slot_mode_4", "Timer")
						, "slot_active_5", Config.Get("boost_bar", "slot_active_5", 0)
						, "slot_timer_5", Config.Get("boost_bar", "slot_timer_5", 100)
						, "slot_mode_5", Config.Get("boost_bar", "slot_mode_5", "Timer")
						, "slot_active_6", Config.Get("boost_bar", "slot_active_6", 0)
						, "slot_timer_6", Config.Get("boost_bar", "slot_timer_6", 100)
						, "slot_mode_6", Config.Get("boost_bar", "slot_mode_6", "Timer")
						, "slot_active_7", Config.Get("boost_bar", "slot_active_7", 0)
						, "slot_timer_7", Config.Get("boost_bar", "slot_timer_7", 100)
						, "slot_mode_7", Config.Get("boost_bar", "slot_mode_7", "Timer")
					)
					, "tracker", Map(
						"passives", Config.Get("tracker", "passives", "scorch")
					)
				)
			}

			if (InStr(script, "buff_tracker.ahk")) {
				payload["settings"] := Map(
					"main", Map(
						"tracker_enabled", Config.Get("main", "tracker_enabled", 0)
					)
					, "tracker", Map(
						"passives", Config.Get("tracker", "passives", "scorch")
						, "offset_x", Config.Get("tracker", "offset_x", 0)
						, "offset_y", Config.Get("tracker", "offset_y", 0)
						, "zoom", Config.Get("tracker", "zoom", 1.0)
					)
				)
			}

			if (InStr(script, "buff_warns.ahk")) {
				warns_map := Map()
				prefixes := ["precise", "smoothie", "gummy", "pop", "scorch", "shower", "morph", "baller", "combo", "combo_buff", "x_flame"]

				for prefix in prefixes {
					warns_map[prefix "_enabled"] := Config.Get("warns", prefix "_enabled", 0)
					warns_map[prefix "_threshold"] := Config.Get("warns", prefix "_threshold", 25)
					warns_map[prefix "_volume"] := Config.Get("warns", prefix "_volume", 25)
					warns_map[prefix "_play_once"] := Config.Get("warns", prefix "_play_once", 0)
					warns_map[prefix "_sound_file"] := Config.Get("warns", prefix "_sound_file", "C:\Windows\Media\Windows Critical Stop.wav")
				}

				payload["settings"] := Map(
					"main", Map(
						"warns_enabled", Config.Get("main", "warns_enabled", 0)
					)
					, "warns", warns_map
				)
			}

			if (payload["settings"].Count > 0 && data.Has("pid")) {
				target_pid := data["pid"]
				SetTimer(() => IPC.send_message("ahk_pid " target_pid, 1, payload), -1)
			}
			return
		}

		if (action == "update_setting") {
			section := data["section"]
			key := data["key"]
			val := data["value"]
			try {
				Config.Set(section, key, val)
			} catch {
				return
			}

			if (this.HasOwnProp("ui_controls") && this.ui_controls.Has(section "_" key)) {
				this.ui_controls[section "_" key].Value := val
			}
			return
		}

		if (action == "save_setting") {
			try {
				Config.Set(data["section"], data["key"], data["value"])
			} catch as err {
				MsgBox("Error saving setting: " err.Message, "Kairos", 16)
			}
			return
		}
	}

	static build_ui() {
		if (this.HasOwnProp("main_gui") && this.main_gui) {
			return
		}

		this.main_gui := Gui("", "Kairos Macro")
		this.main_gui.OnEvent("Close", ObjBindMethod(this, "on_exit"))

		gui_x := Config.Get("main", "gui_x", "")
		gui_y := Config.Get("main", "gui_y", "")
		account_type := Config.Get("main", "account_type", "Main")

		tab_list := (account_type == "Main")
			? ["Home", "Tracker", "Warnings", "Boost Bar", "Comms", "Settings"]
			: ["Home", "Alt", "Boost Bar", "Comms", "Settings"]

		this.tabs := this.main_gui.Add("Tab3", "w450 h260", tab_list)

		this.tabs.UseTab("Home")
		this.build_home_tab(account_type)

		if (account_type == "Main") {
			this.tabs.UseTab("Tracker")
			this.build_tracker_tab()

			this.tabs.UseTab("Warnings")
			this.build_warnings_tab()
		}

		this.tabs.UseTab("Boost Bar")
		this.build_boost_bar_tab()

		this.tabs.UseTab("Settings")
		this.build_settings_tab()

		this.tabs.UseTab("")

		opt_start := "x15 y" this.BTN_Y " w" this.BTN_W " h" this.BTN_H
		btn_start := this.main_gui.Add("Button", opt_start, "Start (" Config.Get("main", "start_hotkey", "F1") ")")
		btn_start.OnEvent("Click", ObjBindMethod(this, "on_start"))

		opt_chain := "x+15 yp w" this.BTN_W " h" this.BTN_H
		btn_pause := this.main_gui.Add("Button", opt_chain, "Pause (" Config.Get("main", "pause_hotkey", "F2") ")")
		btn_pause.OnEvent("Click", ObjBindMethod(this, "on_pause"))

		btn_exit := this.main_gui.Add("Button", opt_chain, "Stop (" Config.Get("main", "stop_hotkey", "F3") ")")
		btn_exit.OnEvent("Click", ObjBindMethod(this, "on_stop"))

		pos_str := (gui_x != "" && gui_y != "") ? "x" gui_x " y" gui_y : "Center"
		this.main_gui.Show("NA " pos_str " NoActivate")
	}

	static build_home_tab(account_type) {
		this.main_gui.Add("GroupBox", "Section w200 h120", "Profile Manager")
		this.main_gui.Add("Text", "xs+10 ys+25 w50", "Presets:")

		presets := Config.GetPresets()
		active_index := this.get_array_index(presets, Config.currentPreset)
		this.preset_ddl := this.main_gui.Add("DropDownList", "x+10 yp-3 w120 Choose" active_index, presets)

		btn_load := this.main_gui.Add("Button", "xs+10 y+15 w55", "Load")
		btn_load.OnEvent("Click", ObjBindMethod(this, "load_preset"))

		btn_save := this.main_gui.Add("Button", "x+5 yp w55", "Save")
		btn_save.OnEvent("Click", ObjBindMethod(this, "save_preset"))

		btn_new := this.main_gui.Add("Button", "x+5 yp w55", "New")
		btn_new.OnEvent("Click", ObjBindMethod(this, "new_preset"))

		btn_del := this.main_gui.Add("Button", "xs+10 y+5 w175", "Delete Profile")
		btn_del.OnEvent("Click", ObjBindMethod(this, "delete_preset"))

		this.main_gui.Add("Text", "xs+10 y+20 w80", "Account Type:")
		type_ddl := this.main_gui.Add("DropDownList", "x+5 yp-3 w100 Choose" (account_type == "Main" ? 1 : 2), ["Main", "Alt"])
		type_ddl.OnEvent("Change", (*) => (Config.Set("main", "account_type", type_ddl.Text), Reload()))

		this.main_gui.Add("GroupBox", "ys w200 h140", "Enable Features")

		if (account_type == "Main") {
			this.add_toggle("xs+220 ys+25", "Enable Magnifier", "main", "magnifier_enabled")
			this.add_toggle("xp y+10", "Enable Key Alignment", "main", "key_alignment_enabled")
			this.add_toggle("xp y+10", "Enable Tracker", "main", "tracker_enabled")
			this.add_toggle("xp y+10", "Enable Warnings", "main", "warns_enabled")
		} else {
			this.add_toggle("xs+220 ys+25", "Enable Alt Macro", "main", "alt_macro_enabled")
		}
		this.add_toggle("xp y+10", "Enable Boost Bar", "main", "boost_bar_enabled")
	}

	static build_tracker_tab() {
		this.main_gui.Add("GroupBox", "Section w410 h185", "Tracker Settings")
		this.main_gui.SetFont("s8", "Segoe UI")

		passives_str := Config.Get("tracker", "passives", "scorch")
		has_passive := (str) => InStr("|" passives_str "|", "|" str "|")

		for index, item in this.tracker_items {
			key := item[1]
			name := item[2]

			col_offset := (Mod(index - 1, 2) == 0) ? 10 : 210
			row_offset := 15 + (Floor((index - 1) / 2) * 26)

			chk := this.main_gui.Add("CheckBox", "xs+" col_offset " ys+" row_offset " w15 h15 Checked" has_passive(key))
			chk.OnEvent("Click", ObjBindMethod(this, "update_passives", key, chk))

			this.main_gui.Add("Text", "xp+20 yp+1 w150", name)
		}
		this.main_gui.SetFont("s9", "Segoe UI")
	}

	static update_passives(key, chk_ctrl, *) {
		current := Config.Get("tracker", "passives", "scorch")
		list := StrSplit(current, "|")

		new_list := []
		for item in list {
			if (item != "" && item != key)
				new_list.Push(item)
		}

		if (chk_ctrl.Value)
			new_list.Push(key)

		save_str := ""
		for item in new_list
			save_str .= (A_Index > 1 ? "|" : "") item

		this.update_and_broadcast("tracker", "passives", save_str)
	}

	static build_warnings_tab() {
		this.main_gui.Add("GroupBox", "Section w420 h185", "Warning Settings")
		this.main_gui.SetFont("s8", "Segoe UI")

		for index, item in this.warn_items {
			key := item[1]
			name := item[2]
			max_val := item[3]

			col_offset := (Mod(index - 1, 2) == 0) ? 10 : 225
			row_offset := 15 + (Floor((index - 1) / 2) * 26)

			chk := this.main_gui.Add("CheckBox", "xs+" col_offset " ys+" row_offset " w15 h15 Checked" Config.Get("warns", key "_enabled", 0))
			chk.OnEvent("Click", this.create_setting_callback("warns", key "_enabled", chk, "Value"))

			this.main_gui.Add("Text", "xp+20 yp+1 w90", name)

			edit_thresh := this.main_gui.Add("Edit", "xp+70 yp-3 w35 h18 Number", Config.Get("warns", key "_threshold", 25))
			edit_thresh.OnEvent("Change", this.create_setting_callback("warns", key "_threshold", edit_thresh, "Value"))

			this.main_gui.Add("Text", "xp+38 yp+3 cGray", "/" max_val)

			btn_cfg := this.main_gui.Add("Button", "xp+35 yp-3 w25 h18", "...")
			btn_cfg.OnEvent("Click", ObjBindMethod(this, "open_warn_settings", key, name))
		}
		this.main_gui.SetFont("s9", "Segoe UI")
	}

	static open_warn_settings(warn_key, warn_name, *) {
		static warn_gui := unset
		if (IsSet(warn_gui) && warn_gui) {
			try warn_gui.Destroy()
			warn_gui := unset
		}

		warn_gui := Gui("+Owner" this.main_gui.hwnd " +AlwaysOnTop +Border +ToolWindow", warn_name " Settings")
		warn_gui.SetFont("s9", "Segoe UI")
		warn_gui.OnEvent("Close", (*) => (warn_gui.Destroy(), warn_gui := unset))

		save_local(*) {
			this.update_and_broadcast("warns", warn_key "_volume", warn_gui["volume"].Value)
			this.update_and_broadcast("warns", warn_key "_playonce", warn_gui["play_once"].Value)
		}

		browse_sound(*) {
			selected_file := FileSelect(1, , "Select Sound File", "Audio (*.wav; *.mp3)")
			if (!selected_file)
				return

			warn_gui["sound_file"].Value := selected_file
			this.update_and_broadcast("warns", warn_key "_sound_file", selected_file)
		}

		test_audio(*) {
			sound_path := warn_gui["sound_file"].Value
			if (!FileExist(sound_path)) {
				sound_path := "C:\Windows\Media\Windows Critical Stop.wav"
			}
			vol := warn_gui["volume"].Value
			try {
				kairos_main.test_audio_player := Audio(sound_path)
				kairos_main.test_audio_player.Play(vol)
			} catch as err {
				MsgBox("Error playing audio: " err.Message, "Kairos", 16)
			}
		}

		warn_gui.Add("Text", "x15 y15 w50", "Volume:")
		edit_vol := warn_gui.Add("Edit", "x65 y12 w50 Number vvolume", Config.Get("warns", warn_key "_volume", 25))
		edit_vol.OnEvent("Change", save_local)
		warn_gui.Add("UpDown", "Range0-100", Config.Get("warns", warn_key "_volume", 25))
		warn_gui.Add("Text", "x120 y15", "%")

		chk_play := warn_gui.Add("CheckBox", "x15 y40 w100 vplay_once Checked" Config.Get("warns", warn_key "_playonce", 0), "Play Once")
		chk_play.OnEvent("Click", save_local)

		warn_gui.Add("Text", "x15 y70 w50", "Sound:")
		btn_browse := warn_gui.Add("Button", "x60 y67 w55 h22", "Browse")
		btn_browse.OnEvent("Click", browse_sound)

		btn_test := warn_gui.Add("Button", "x120 y67 w55 h22", "Test")
		btn_test.OnEvent("Click", test_audio)

		warn_gui.Add("Edit", "x15 y95 w220 h20 ReadOnly vsound_file", Config.Get("warns", warn_key "_sound_file", "C:\Windows\Media\Windows Critical Stop.wav"))

		warn_gui.Show("w250 h130")
	}

	static build_boost_bar_tab() {
		this.main_gui.Add("GroupBox", "Section w300 h185", "Boost Bar Slots")
		this.main_gui.Add("Text", "xs+15 ys+20 w50", "Active")
		this.main_gui.Add("Text", "xs+75 ys+20 w50", "Timers")
		this.main_gui.Add("Text", "xs+150 ys+20 w50", "Modes")

		loop 7 {
			idx := A_Index
			y_pos := "ys+" (15 + (idx * 21))

			chk := this.main_gui.Add("CheckBox", "xs+20 " y_pos " w20 h20 Checked" Config.Get("boost_bar", "slot_active_" idx, 0))
			chk.OnEvent("Click", this.create_setting_callback("boost_bar", "slot_active_" idx, chk, "Value"))

			edit_timer := this.main_gui.Add("Edit", "xs+70 " y_pos " w40 h18 Number Center", Config.Get("boost_bar", "slot_timer_" idx, 100))
			edit_timer.OnEvent("Change", this.create_setting_callback("boost_bar", "slot_timer_" idx, edit_timer, "Value"))

			current_modes := Config.Get("boost_bar", "slot_mode_" idx, "Timer")
			display_text := (current_modes == "") ? "None" : (StrSplit(current_modes, "|").Length > 1 ? "Multiple" : current_modes)

			btn_mode := this.main_gui.Add("Button", "xs+130 " y_pos " w85 h20", display_text)
			btn_mode.OnEvent("Click", ObjBindMethod(this, "open_mode_selector", idx, btn_mode))
		}
	}

	static open_mode_selector(idx, btn_ctrl, *) {
		static mode_gui := unset
		if (IsSet(mode_gui) && mode_gui) {
			try mode_gui.Destroy()
			mode_gui := unset
		}

		current_config := Config.Get("boost_bar", "slot_mode_" idx, "Timer")
		mode_gui := Gui("+Owner" this.main_gui.hwnd " +AlwaysOnTop +Border +ToolWindow", "Slot " idx " Modes")
		mode_gui.SetFont("s9", "Segoe UI")
		mode_gui.OnEvent("Close", (*) => (mode_gui.Destroy(), mode_gui := unset))

		mode_list := ["Timer", "Re-Glitter", "On Scorch Star", "Re-Smoothie", "On Pop Star", "On Gummyballer", "On Star Shower", "On Gummy Star", "On Gummy Morph", "On Coconut Combo", "On X-Flame"]
		checkboxes := Map()

		update_config(*) {
			saved_list := []
			for mode, ctrl in checkboxes {
				if (ctrl.Value)
					saved_list.Push(mode)
			}

			save_str := ""
			for item in saved_list
				save_str .= (A_Index > 1 ? "|" : "") item

			this.update_and_broadcast("boost_bar", "slot_mode_" idx, save_str)
			count := saved_list.Length
			btn_ctrl.Text := (count == 0) ? "None" : (count > 1 ? "Multiple" : save_str)
		}

		for index, mode_name in mode_list {
			i := A_Index - 1
			col := Mod(i, 3)
			row := Floor(i / 3)
			is_checked := InStr("|" current_config "|", "|" mode_name "|")

			cb := mode_gui.Add("CheckBox", "x" (10 + (col * 110)) " y" (10 + (row * 38)) " w90 h30 Checked" is_checked, mode_name)
			cb.OnEvent("Click", update_config)
			checkboxes[mode_name] := cb
		}

		mode_gui.Show("w330 h155")
	}

	static build_settings_tab() {
		this.main_gui.Add("GroupBox", "Section w200 h160", "Hotkeys")

		this.add_hotkey_row("xs+10 ys+25", "Start Macro:", "main", "start_hotkey", "F1")
		this.add_hotkey_row("xs+10 y+10", "Pause Macro:", "main", "pause_hotkey", "F2")
		this.add_hotkey_row("xs+10 y+10", "Stop Macro:", "main", "stop_hotkey", "F3")
		this.add_hotkey_row("xs+10 y+10", "Align Key:", "key_alignment", "alignment_key", "e")
		this.add_hotkey_row("xs+10 y+10", "Rebind Key:", "key_alignment", "rebind_hotkey", "^+k")
	}

	static add_hotkey_row(pos, label, section, key, default_val) {
		this.main_gui.Add("Text", pos " w80", label)
		current_val := Config.Get(section, key, default_val)
		display := this.main_gui.Add("Edit", "x+5 yp-3 w60 ReadOnly Center", current_val)
		this.ui_controls[section "_" key] := display
		btn := this.main_gui.Add("Button", "x+5 yp w40", "Set")
		btn.OnEvent("Click", ObjBindMethod(this, "capture_hotkey", section, key, display, btn))
	}

	static create_setting_callback(section, key, ctrl, prop) {
		return (*) => this.update_and_broadcast(section, key, ctrl.%prop%)
	}

	static add_toggle(position, label, section, key) {
		chk := this.main_gui.Add("CheckBox", position " Checked" Config.Get(section, key, 0), label)
		chk.OnEvent("Click", (*) => this.update_and_broadcast(section, key, chk.Value))
	}

	static update_and_broadcast(section, key, val) {
		Config.Set(section, key, val)
		process_manager.broadcast_setting(section, key, val)
	}

	static get_array_index(arr, search_val) {
		for index, val in arr {
			if (val == search_val) {
				return index
			}
		}
		return 1
	}

	static load_preset(*) {
		selected := this.preset_ddl.Text
		if (selected != "") {
			Config.SetPreset(selected)
			Reload()
		}
	}

	static save_preset(*) {
		Config.WriteIni()
		ToolTip("Preset saved.")
		SetTimer(() => ToolTip(), -750)
	}

	static new_preset(*) {
		preset_name := InputBox("Enter a new preset name:", "New Preset", "w200 h100").Value
		if (preset_name == "") {
			return
		}

		preset_name := RegExReplace(preset_name, "[\\/:\*\?`"<>\|]", "")
		if (StrLower(preset_name) == "global") {
			MsgBox("Cannot use 'global' as a preset name.", "Kairos", 48)
			return
		}

		new_path := A_WorkingDir "\settings\" preset_name ".ini"
		try {
			FileCopy(Config.path, new_path, 1)
		}
		Config.SetPreset(preset_name)
		Reload()
	}

	static delete_preset(*) {
		selected := this.preset_ddl.Text
		if (selected == "config" || selected == "") {
			MsgBox("Cannot delete the default config profile.", "Kairos", 48)
			return
		}

		result := MsgBox("Are you sure you want to delete the profile '" selected "'?", "Delete Profile", "YesNo Icon?")
		if (result == "Yes") {
			file_path := A_WorkingDir "\settings\" selected ".ini"
			if (FileExist(file_path)) {
				FileDelete(file_path)
			}
			Config.SetPreset("config")
			Reload()
		}
	}

	static capture_hotkey(section, key_name, display_ctrl, gui_ctrl, *) {
		original_text := display_ctrl.Value
		display_ctrl.Value := "Listening..."
		gui_ctrl.Enabled := false

		ih := InputHook("T7")
		ih.KeyOpt("{All}", "E")
		ih.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}{LWin}{RWin}", "-E")

		captured_key := ""
		mouse_callback := (this_hotkey) => (captured_key := StrReplace(this_hotkey, "$"), ih.Stop())

		mouse_keys := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
		for key in mouse_keys {
			Hotkey("$" key, mouse_callback, "On")
			Hotkey("$^" key, mouse_callback, "On")
			Hotkey("$+" key, mouse_callback, "On")
			Hotkey("$!" key, mouse_callback, "On")
		}

		ih.Start()
		ih.Wait()

		for key in mouse_keys {
			Hotkey("$" key, "Off")
			Hotkey("$^" key, "Off")
			Hotkey("$+" key, "Off")
			Hotkey("$!" key, "Off")
		}

		gui_ctrl.Enabled := true

		final_key := ""

		mods := ""
		if (GetKeyState("Ctrl", "P"))
			mods .= "^"
		if (GetKeyState("Shift", "P"))
			mods .= "+"
		if (GetKeyState("Alt", "P"))
			mods .= "!"
		if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
			mods .= "#"

		if (captured_key != "") {
			final_key := RegExReplace(captured_key, "[\^\+!\#]", "")
		} else if (ih.EndReason == "EndKey") {
			if (ih.EndKey != "Escape") {
				final_key := ih.EndKey
			}
		}

		if (final_key != "") {
			if (StrLen(final_key) == 1) {
				final_key := StrLower(final_key)
			}

			final_key := mods . final_key

			if (key_name ~= "start_hotkey|pause_hotkey|stop_hotkey") {
				base_key := RegExReplace(final_key, "[\^\+!\#]", "")
				blacklist := "|LButton|RButton|Enter|Space|Tab|Backspace|Escape|"

				if (InStr(blacklist, "|" base_key "|")) {
					MsgBox("You cannot bind '" base_key "' to this option.", "Invalid Keybind", 48 " T10")
					final_key := ""
				}
			}

			if (final_key != "") {
				all_hotkeys := Map(
					"start_hotkey", Config.Get("main", "start_hotkey", "F1"),
					"pause_hotkey", Config.Get("main", "pause_hotkey", "F2"),
					"stop_hotkey", Config.Get("main", "stop_hotkey", "F3"),
					"alignment_key", Config.Get("key_alignment", "alignment_key", "e"),
					"rebind_hotkey", Config.Get("key_alignment", "rebind_hotkey", "^+k")
				)

				for current_name, current_bind in all_hotkeys {
					if (current_name != key_name && StrLower(current_bind) == StrLower(final_key)) {
						MsgBox("The keybind '" final_key "' is already in use by '" current_name "'. Please choose a different key.", "Keybind Overlap", 48)
						final_key := ""
						break
					}
				}
			}
		}

		if (final_key == "") {
			display_ctrl.Value := original_text
		} else {
			display_ctrl.Value := final_key
			Config.Set(section, key_name, final_key)

			if (key_name ~= "start_hotkey|pause_hotkey|stop_hotkey") {
				try Hotkey(original_text, "Off")
				this.register_hotkeys()
			}
		}
	}

	static on_start(*) {
		this.is_paused := false
		process_manager.broadcast_state("running")
	}

	static on_pause(*) {
		this.is_paused := !this.is_paused
		state_str := this.is_paused ? "paused" : "resumed"
		process_manager.broadcast_state(state_str)
	}

	static on_stop(*) {
		this.is_paused := false
		process_manager.kill_all()
		Reload()
	}

	static on_exit(*) {
		try {
			this.main_gui.GetPos(&x, &y)
			Config.Set("main", "gui_x", (x > 0) ? (x > A_ScreenWidth - 400 ? A_ScreenWidth - 400 : x) : 0)
			Config.Set("main", "gui_y", (y > 0) ? (y > A_ScreenHeight - 220 ? A_ScreenHeight - 220 : y) : 0)
			Config.WriteIni()
		}
		process_manager.kill_all()
		ExitApp()
	}

	static register_hotkeys() {
		try {
			Hotkey(Config.Get("main", "start_hotkey", "F1"), ObjBindMethod(this, "on_start"), "On")
			Hotkey(Config.Get("main", "pause_hotkey", "F2"), ObjBindMethod(this, "on_pause"), "On")
			Hotkey(Config.Get("main", "stop_hotkey", "F3"), ObjBindMethod(this, "on_stop"), "On")
		} catch as err {
			MsgBox("Error registering hotkeys: " err.Message, "Kairos", 16)
		}
	}
}

log_error(exception, mode) {
	time_str := FormatTime(A_Now, "yyyy-MM-dd HH:mm:ss")

	log := "====================`n"
	log .= "Time: " time_str "`n"
	log .= "Error: " exception.Message "`n"
	log .= "File: " exception.File "`n"
	log .= "Line: " exception.Line "`n"

	if (exception.Extra != "")
		log .= "Specifically: " exception.Extra "`n"
	log .= "Call Stack:`n" exception.Stack "`n"
	log .= "====================`n`n"

	if !DirExist("logs")
		DirCreate("logs")
	try FileAppend(log, A_WorkingDir "\logs\kairos_crash_log.txt")
	return 0
}

kairos_main.init()