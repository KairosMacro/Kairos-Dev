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

OnError(log_error)

config.Load()

class kairos_main {
	static BTN_W := 120
	static BTN_H := 20
	static BTN_Y := 280

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

	static init() {
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
		if (this.HasOwnProp("log_edit") && this.log_edit) {
			this.log_edit.Value .= msg "`r`n"
			SendMessage(0x0115, 7, 0, this.log_edit.hwnd)
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
				prefixes := ["precise", "smoothie", "gummy", "pop", "scorch", "shower", "morph", "baller", "combo", "combo_buff", "xflame"]

				for prefix in prefixes {
					warns_map[prefix "_enabled"] := Config.Get("warns", prefix "_enabled", 0)
					warns_map[prefix "_threshold"] := Config.Get("warns", prefix "_threshold", 25)
					warns_map[prefix "_volume"] := Config.Get("warns", prefix "_volume", 25)
					warns_map[prefix "_playonce"] := Config.Get("warns", prefix "_playonce", 0)
					warns_map[prefix "_soundfile"] := Config.Get("warns", prefix "_soundfile", "C:\Windows\Media\Windows Critical Stop.wav")
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
		this.main_gui := Gui("", "Kairos Macro")
		this.main_gui.OnEvent("Close", ObjBindMethod(this, "on_exit"))

		gui_x := Config.Get("main", "gui_x", "")
		gui_y := Config.Get("main", "gui_y", "")

		account_type := Config.Get("main", "account_type", "Main")

		tab_list := (account_type == "Main")
			? ["Home", "Tracker", "Warnings", "Boost Bar", "Comms", "Settings"]
			: ["Home", "Alt", "Boost Bar", "Comms", "Settings"]

		tabs := this.main_gui.Add("Tab3", "w450 h260", tab_list)

		tabs.UseTab("Home")

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

		this.main_gui.Add("GroupBox", "ys w200 h140", "Active Modules")

		if (account_type == "Main") {
			this.add_toggle("xs+220 ys+25", "Enable Magnifier", "main", "magnifier_enabled")
			this.add_toggle("xp y+10", "Enable Key Alignment", "main", "key_alignment_enabled")
			this.add_toggle("xp y+10", "Enable Tracker", "main", "tracker_enabled")
			this.add_toggle("xp y+10", "Enable Warnings", "main", "warns_enabled")
		} else {
			this.add_toggle("xs+220 ys+25", "Enable Alt Macro", "main", "alt_macro_enabled")
		}
		this.add_toggle("xp y+10", "Enable Boost Bar", "main", "boost_bar_enabled")
		tabs.UseTab("")

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

	static add_toggle(position, label, section, key) {
		chk := this.main_gui.Add("CheckBox", position " Checked" Config.Get(section, key, 0), label)
		chk.OnEvent("Click", (*) => this.update_and_broadcast(section, key, chk.Value))
	}

	static update_and_broadcast(section, key, val) {
		Config.Set(section, key, val)

		payload := Map("action", "update_setting", "section", section, "key", key, "value", val)
		process_manager.broadcast_state(payload)
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

		ih := InputHook("L1 T7", "{Escape}{Space}{Tab}{Enter}{Backspace}{Delete}{Insert}{Home}{End}{PgUp}{PgDn}{Up}{Down}{Left}{Right}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}")
		captured_key := ""

		mouse_callback := (this_hotkey) => (captured_key := StrReplace(this_hotkey, "$"), ih.Stop())
		mouse_keys := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]

		for key in mouse_keys {
			Hotkey("$" key, mouse_callback, "On")
		}

		ih.Start()
		ih.Wait()

		for key in mouse_keys {
			Hotkey("$" key, "Off")
		}

		gui_ctrl.Enabled := true

		final_key := ""
		if (captured_key != "") {
			final_key := captured_key
		} else if (ih.EndReason == "Max") {
			final_key := ih.Input
		} else if (ih.EndReason == "EndKey") {
			if (ih.EndKey != "Escape") {
				final_key := ih.EndKey
			}
		}

		if (final_key != "") {
			if (key_name ~= "start_hotkey|pause_hotkey|stop_hotkey") {
				blacklist := "|LButton|RButton|Enter|Space|Tab|Backspace|Escape|"
				if (InStr(blacklist, "|" final_key "|")) {
					MsgBox("You cannot bind '" final_key "' to this option.", "Invalid Keybind", 48 " T10")
					final_key := ""
				}
			}
		}

		if (final_key == "") {
			display_ctrl.Value := original_text
		} else {
			display_ctrl.Value := final_key
			Config.Set(section, key_name, final_key)
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