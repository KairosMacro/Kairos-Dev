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
#Include "..\lib\utils\file_importer.ahk"

OnError(log_error)

config.Load()

class kairos_main {
	static MACRO_VERSION := "1.0.0"
	static GUI_W := 500
	static GUI_H := 300
	static BTN_W := 70
	static BTN_H := 20
	static BTN_Y := 280
	static WM_VSCROLL := 0x0115
	static SB_BOTTOM := 7

	static expected_modules := []
	static ready_modules := Map()
	static loading_gui := unset
	static log_edit := unset
	static is_paused := false
	static is_running := false
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
		["x_flame", "X-Flame", 25]
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
		["shower", "Star Shower"],
		["cocoinspire", "Coconut Inspire"]
	]

	static BTN_MOVE_W := 75
	static BTN_MOVE_H := 25

	static current_warn_key := ""
	static current_warn_max := 0
	static current_boost_slot := 0

	static boost_mode_chks := Map()

	static init() {
		OnExit((*) => process_manager.kill_all())
		IPC.init(ObjBindMethod(this, "handle_command"))
		this.show_loading_screen()

		account_type := Config.Get("main", "account_type", "Main")

		if (account_type == "Main") {
			this.expected_modules := [
				"scripts\general\buff_scanner.ahk",
				"scripts\main\magnification.ahk",
				"scripts\main\key_alignment.ahk",
				"scripts\general\boost_bar.ahk",
				"scripts\main\buff_warns.ahk",
				"scripts\main\buff_tracker.ahk"
			]
		} else {
			this.expected_modules := [
				"scripts\general\buff_scanner.ahk",
				"scripts\general\boost_bar.ahk",
				"scripts\alt\alt_macro.ahk"
			]
		}

		if (account_type != "Main") {
			importPatterns()
		}

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

		if (action == "sync_buff_data") {
			for script_path, proc_info in process_manager.processes {
				if (!InStr(script_path, "buff_scanner.ahk")) {
					IPC.send_message("ahk_class AutoHotkey ahk_pid " proc_info.pid, 1, data)
				}
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
				warns_map := Map()
				prefixes := ["precise", "smoothie", "gummy", "pop", "scorch", "shower", "morph", "baller", "combo", "combo_buff", "x_flame"]

				for prefix in prefixes {
					warns_map[prefix "_enabled"] := Config.Get("warns", prefix "_enabled", 0)
					warns_map[prefix "_threshold"] := Config.Get("warns", prefix "_threshold", 25)
				}

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
					, "warns", warns_map
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

			if (InStr(script, "alt_macro.ahk")) {
				payload["settings"] := Map(
					"main", Map(
						"alt_macro_enabled", Config.Get("main", "alt_macro_enabled", 0)
					),
					"alt", Map(
						"default_field", Config.Get("alt", "default_field", "pepper"),
						"pattern", Config.Get("alt", "pattern", "GeneralBooster"),
						"move_speed", Config.Get("alt", "move_speed", 29),
						"hive_slot", Config.Get("alt", "hive_slot", 1),
						"claim_hive", Config.Get("alt", "claim_hive", 1),
						"coco_catch", Config.Get("alt", "coco_catch", 0),
						"field_drift_comp", Config.Get("alt", "field_drift_comp", 1),
						"sprinkler_location", Config.Get("alt", "sprinkler_location", "Center"),
						"sprinkler_distance", Config.Get("alt", "sprinkler_distance", 1),
						"shift_lock", Config.Get("alt", "shift_lock", 0),
						"camera_pitch", Config.Get("alt", "camera_pitch", 4),
						"alt_number", Config.Get("alt", "alt_number", 1),
						"pattern_size", Config.Get("alt", "pattern_size", 1),
						"pattern_width", Config.Get("alt", "pattern_width", 1),
						"rot_lr_amount", Config.Get("alt", "rot_lr_amount", 0),
						"rot_lr_dir", Config.Get("alt", "rot_lr_dir", "Right"),
						"use_tool", Config.Get("alt", "use_tool", 1),
						"ignore_inactive_honey", Config.Get("alt", "ignore_inactive_honey", 0),
						"priv_server", Config.Get("alt", "priv_server", "")
					)
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
		if (this.HasOwnProp("main_gui") && this.main_gui)
			return

		this.main_gui := Gui("", "Kairos Macro")
		this.main_gui.OnEvent("Close", ObjBindMethod(this, "on_exit"))

		gui_x := Config.Get("main", "gui_x", "")
		gui_y := Config.Get("main", "gui_y", "")
		account_type := Config.Get("main", "account_type", "Main")

		tab_list := (account_type == "Main")
			? ["Home", "Tracker", "Warnings", "Boost Bar", "Comms", "Settings"]
			: ["Home", "Alt", "Boost Bar", "Comms", "Settings"]

		this.tabs := this.main_gui.Add("Tab3", "x-1 y-1 w" this.GUI_W + 2 " h" this.GUI_H - 23 " -Wrap", tab_list)

		this.tabs.UseTab("Home")
		this.build_home_tab(account_type)

		if (account_type == "Main") {
			this.tabs.UseTab("Tracker")
			this.build_tracker_tab()

			this.tabs.UseTab("Warnings")
			this.build_warnings_tab()
		} else {
			this.tabs.UseTab("Alt")
			this.build_alt_tab()
		}

		this.tabs.UseTab("Boost Bar")
		this.build_boost_bar_tab()

		this.tabs.UseTab("Settings")
		this.build_settings_tab()

		this.tabs.UseTab("")

		opt_start := "x15 y" this.BTN_Y " w" this.BTN_W " h" this.BTN_H
		this.btn_start_ctrl := this.main_gui.Add("Button", opt_start, "Start (" Config.Get("main", "start_hotkey", "F1") ")")
		this.btn_start_ctrl.OnEvent("Click", ObjBindMethod(this, "on_start"))

		opt_chain := "x+5 yp w" this.BTN_W " h" this.BTN_H
		this.btn_pause_ctrl := this.main_gui.Add("Button", opt_chain, "Pause (" Config.Get("main", "pause_hotkey", "F2") ")")
		this.btn_pause_ctrl.OnEvent("Click", ObjBindMethod(this, "on_pause"))

		this.btn_stop_ctrl := this.main_gui.Add("Button", opt_chain, "Stop (" Config.Get("main", "stop_hotkey", "F3") ")")
		this.btn_stop_ctrl.OnEvent("Click", ObjBindMethod(this, "on_stop"))

		this.main_gui.SetFont("s9", "Segoe UI")
		link_txt := '<a href="https://discord.gg/SWWfETTEjJ">Discord</a>  |  <a href="https://github.com/KairosMacro/Kairos">GitHub</a>'
		this.main_gui.Add("Link", "x+90 yp+1", link_txt)

		this.main_gui.SetFont("cGray")
		this.main_gui.Add("Text", "x+5 yp", "v" this.MACRO_VERSION)
		this.main_gui.SetFont("cDefault")

		pos_str := (gui_x != "" && gui_y != "") ? "x" gui_x " y" gui_y : "Center"
		this.main_gui.Show("w" this.GUI_W " h" this.GUI_H " NA " pos_str " NoActivate")
	}

	static build_home_tab(account_type) {
		this.main_gui.Add("GroupBox", "Section w200 h150", "Profile Manager")
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

		btn_export := this.main_gui.Add("Button", "xs+10 y+5 w85", "Export (.krs)")
		btn_export.OnEvent("Click", ObjBindMethod(this, "export_config"))

		btn_import := this.main_gui.Add("Button", "x+5 yp w85", "Import (.krs)")
		btn_import.OnEvent("Click", ObjBindMethod(this, "import_config"))

		this.main_gui.Add("Text", "xs+10 y+15 w80", "Account Type:")
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

	/*
	* `this.settings["alt"]["default_field"]`
	* `this.settings["alt"]["hive_slot"]`
	* `this.settings["alt"]["move_speed"]`
	* `this.settings["alt"]["shift_lock"]`
	* `this.settings["alt"]["use_tool"]`
	* `this.settings["alt"]["pattern"]`
	* `this.settings["alt"]["field_drift_comp"]`
	* `this.settings["alt"]["coco_catch"]`
	* `this.settings["alt"]["sprinkler_location"]`
	* `this.settings["alt"]["sprinkler_distance"]`
	* `this.settings["alt"]["rot_lr_amount"]`
	* `this.settings["alt"]["rot_lr_dir"]`
	* `this.settings["alt"]["camera_pitch"]`
	* `this.settings["alt"]["claim_hive"]`
	* `this.settings["alt"]["ignore_inactive_honey"]`
	* `this.settings["alt"]["priv_server"]`
	*/
	static build_alt_tab() {
		this.main_gui.SetFont("s8", "Segoe UI")
		GroupWidth := 205
		this.main_gui.Add("GroupBox", "Section x10 y25 w" GroupWidth " h190", "Alt Settings")

		this.main_gui.Add("Text", "xs+10 ys+23", "MoveSpeed:")
		editCtrl := this.main_gui.Add("Edit", "x105 ys+17 w60 h20 valt_move_speed", Config.Get("alt", "move_speed", 29))
		editCtrl.OnEvent("Change", (ctrl, *) => (this.enforce_float(ctrl), this.update_and_broadcast("alt", "move_speed", ctrl.Value)))

		this.main_gui.Add("Text", "xs+10 ys+45", "Hive Slot:")
		hiveCtrl := this.main_gui.Add("Edit", "x105 ys+43 w60 h20 Number valt_hive_slot", Config.Get("alt", "hive_slot", 1))
		hiveCtrl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "hive_slot", hiveCtrl.Value))

		this.main_gui.Add("Text", "xs+10 ys+70", "Alt Number:")
		altNumCtrl := this.main_gui.Add("Edit", "x105 ys+67 w40 h20 Number valt_alt_number", Config.Get("alt", "alt_number", 1))
		altNumCtrl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "alt_number", altNumCtrl.Value))

		this.main_gui.Add("Text", "xs+30 ys+95", "Shift Lock")
		chk_shift := this.main_gui.Add("CheckBox", "xs+10 ys+92 w20 h20 Checked" Config.Get("alt", "shift_lock", 0) " valt_shift_lock")
		chk_shift.OnEvent("Click", (*) => this.update_and_broadcast("alt", "shift_lock", chk_shift.Value))

		this.main_gui.Add("Text", "x130 ys+95", "Drift Comp")
		chk_drift := this.main_gui.Add("CheckBox", "x110 ys+92 w20 h20 Checked" Config.Get("alt", "field_drift_comp", 1) " valt_field_drift_comp")
		chk_drift.OnEvent("Click", (*) => this.update_and_broadcast("alt", "field_drift_comp", chk_drift.Value))

		this.main_gui.Add("Text", "xs+30 ys+118", "Claim Hive")
		chk_claim := this.main_gui.Add("CheckBox", "xs+10 ys+115 w20 h20 Checked" Config.Get("alt", "claim_hive", 1) " valt_claim_hive")
		chk_claim.OnEvent("Click", (*) => this.update_and_broadcast("alt", "claim_hive", chk_claim.Value))

		this.main_gui.Add("Text", "x130 ys+118", "Ignore Inactive")
		chk_ignore := this.main_gui.Add("CheckBox", "x110 ys+115 w20 h20 Checked" Config.Get("alt", "ignore_inactive_honey", 0) " valt_ignore_inactive_honey")
		chk_ignore.OnEvent("Click", (*) => this.update_and_broadcast("alt", "ignore_inactive_honey", chk_ignore.Value))

		this.main_gui.Add("Text", "xs+30 ys+140", "Use Tool")
		chk_tool := this.main_gui.Add("CheckBox", "xs+10 ys+137 w20 h20 Checked" Config.Get("alt", "use_tool", 0) " valt_use_tool")
		chk_tool.OnEvent("Click", (*) => this.update_and_broadcast("alt", "use_tool", chk_tool.Value))

		this.main_gui.Add("Text", "xs+10 ys+163", "Priv Server:")
		privCtrl := this.main_gui.Add("Edit", "x85 ys+161 w110 h20 valt_priv_server", Config.Get("alt", "priv_server", ""))
		privCtrl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "priv_server", privCtrl.Value))

		Group2 := GroupWidth + 15
		this.main_gui.Add("GroupBox", "x" Group2 " ys w" GroupWidth " h190", "Field Settings")

		btn_copy := this.main_gui.Add("Button", "x" Group2 + 100 " ys+2 w45 h18", "Copy")
		btn_copy.OnEvent("Click", ObjBindMethod(this, "copy_field_settings"))

		btn_paste := this.main_gui.Add("Button", "x" Group2 + 150 " ys+2 w45 h18", "Paste")
		btn_paste.OnEvent("Click", ObjBindMethod(this, "paste_field_settings"))

		this.main_gui.Add("Text", "x" Group2 + 5 " ys+25", "Field:")
		fieldArr := ["sunflower", "dandelion", "mushroom", "blueflower", "clover", "strawberry", "spider", "bamboo", "pineapple", "stump", "cactus", "pumpkin", "pinetree", "rose", "mountaintop", "pepper", "coconut"]
		field_ddl := this.main_gui.Add("DropDownList", "x" Group2 + 45 " ys+23 w100 Choose" this.get_array_index(fieldArr, Config.Get("alt", "default_field", "pepper")) " valt_default_field", fieldArr)
		field_ddl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "default_field", field_ddl.Text))

		this.main_gui.Add("Text", "x" Group2 + 5 " ys+50", "Pattern:")
		global patternlist
		pList := IsSet(patternlist) ? patternlist : ["GeneralBooster"]
		pattern_ddl := this.main_gui.Add("DropDownList", "x" Group2 + 60 " ys+50 w110 Choose" this.get_array_index(pList, Config.Get("alt", "pattern", "GeneralBooster")) " valt_pattern", pList)
		pattern_ddl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "pattern", pattern_ddl.Text))

		this.main_gui.Add("Text", "x" Group2 + 5 " ys+80", "Size:")
		edit_size := this.main_gui.Add("Edit", "x" Group2 + 40 " ys+78 w40 h20 Number valt_pattern_size", Config.Get("alt", "pattern_size", 1))
		this.main_gui.Add("UpDown", "Range1-10", Config.Get("alt", "pattern_size", 1))
		edit_size.OnEvent("Change", (*) => this.update_and_broadcast("alt", "pattern_size", edit_size.Value))

		this.main_gui.Add("Text", "x" Group2 + 90 " ys+80", "Width:")
		edit_width := this.main_gui.Add("Edit", "x" Group2 + 130 " ys+78 w40 h20 Number valt_pattern_width", Config.Get("alt", "pattern_width", 1))
		this.main_gui.Add("UpDown", "Range1-10", Config.Get("alt", "pattern_width", 1))
		edit_width.OnEvent("Change", (*) => this.update_and_broadcast("alt", "pattern_width", edit_width.Value))

		this.main_gui.Add("Text", "x" Group2 + 5 " ys+105", "Sprinkler:")
		sprinklerArr := ["Center", "Upper Left", "Left", "Lower Left", "Lower", "Lower Right", "Right", "Upper Right", "Upper"]
		sprink_ddl := this.main_gui.Add("DropDownList", "x" Group2 + 65 " ys+100 w80 Choose" this.get_array_index(sprinklerArr, Config.Get("alt", "sprinkler_location", "Center")) " valt_sprinkler_location", sprinklerArr)
		sprink_ddl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "sprinkler_location", sprink_ddl.Text))

		edit_sprink_dist := this.main_gui.Add("Edit", "x" Group2 + 147 " ys+100 w40 h24 Number valt_sprinkler_distance", Config.Get("alt", "sprinkler_distance", 1))
		this.main_gui.Add("UpDown", "Range0-10", Config.Get("alt", "sprinkler_distance", 1))
		edit_sprink_dist.OnEvent("Change", (*) => this.update_and_broadcast("alt", "sprinkler_distance", edit_sprink_dist.Value))

		this.main_gui.Add("Text", "x" Group2 + 5 " ys+130", "Rotation:")
		edit_rot := this.main_gui.Add("Edit", "x" Group2 + 60 " ys+128 w40 Number valt_rot_lr_amount", Config.Get("alt", "rot_lr_amount", 0))
		this.main_gui.Add("UpDown", "Range0-8", Config.Get("alt", "rot_lr_amount", 0))
		edit_rot.OnEvent("Change", (*) => this.update_and_broadcast("alt", "rot_lr_amount", edit_rot.Value))

		rot_dir_ddl := this.main_gui.Add("DropDownList", "x" Group2 + 102 " ys+128 w60 Choose" this.get_array_index(["Right", "Left"], Config.Get("alt", "rot_lr_dir", "Right")) " valt_rot_lr_dir", ["Right", "Left"])
		rot_dir_ddl.OnEvent("Change", (*) => this.update_and_broadcast("alt", "rot_lr_dir", rot_dir_ddl.Text))

		this.main_gui.SetFont("s9", "Segoe UI")
	}

	static build_tracker_tab() {
		this.main_gui.Add("GroupBox", "Section w410 h240", "Tracker Settings")
		this.main_gui.SetFont("s8", "Segoe UI")

		this.tracker_lv := this.main_gui.Add("ListView", "xs+10 ys+20 w290 h200 -Hdr", ["Key", "Name", "Status"])
		this.tracker_lv.OnEvent("ItemSelect", ObjBindMethod(this, "on_tracker_select"))

		btn_up := this.main_gui.Add("Button", "x+10 ys+20 w" this.BTN_MOVE_W " h" this.BTN_MOVE_H, "Move Up")
		btn_up.OnEvent("Click", ObjBindMethod(this, "move_tracker_item", -1))

		btn_down := this.main_gui.Add("Button", "xp y+5 w" this.BTN_MOVE_W " h" this.BTN_MOVE_H, "Move Down")
		btn_down.OnEvent("Click", ObjBindMethod(this, "move_tracker_item", 1))

		this.chk_enable := this.main_gui.Add("CheckBox", "xp y+15 w" this.BTN_MOVE_W " h20", "Enable")
		this.chk_enable.OnEvent("Click", ObjBindMethod(this, "on_enable_toggle"))

		this.populate_tracker_list()

		this.tracker_lv.ModifyCol(1, 0)
		this.tracker_lv.ModifyCol(2, 210)
		this.tracker_lv.ModifyCol(3, 60)
		this.main_gui.SetFont("s9", "Segoe UI")
	}

	static populate_tracker_list() {
		try {
			this.tracker_lv.Delete()
			saved_str := Config.Get("tracker", "passives", "scorch")
			saved_keys := StrSplit(saved_str, "|")

			added_keys := Map()

			for index, key in saved_keys {
				if (key == "")
					continue

				name := this.get_tracker_name(key)
				this.tracker_lv.Add("", key, name, "Enabled")
				added_keys[key] := true
			}

			for index, item in this.tracker_items {
				key := item[1]
				if (added_keys.Has(key))
					continue

				this.tracker_lv.Add("", key, item[2], "")
			}
		} catch as err {
			this.log_msg("Error populating tracker list: " err.Message)
		}
	}

	static get_tracker_name(search_key) {
		for index, item in this.tracker_items {
			if (item[1] == search_key)
				return item[2]
		}
		return "Unknown"
	}

	static on_tracker_select(gui_ctrl, item_index, selected) {
		if (!selected) {
			if (!this.tracker_lv.GetNext(0)) {
				this.chk_enable.Value := 0
			}
			return
		}

		status := this.tracker_lv.GetText(item_index, 3)
		this.chk_enable.Value := (status == "Enabled")
	}

	static on_enable_toggle(ctrl, *) {
		focused_row := this.tracker_lv.GetNext(0, "Focused")
		if (!focused_row)
			return

		key := this.tracker_lv.GetText(focused_row, 1)
		name := this.tracker_lv.GetText(focused_row, 2)
		status_text := ctrl.Value ? "Enabled" : ""

		this.tracker_lv.Modify(focused_row, "", key, name, status_text)
		this.save_tracker_order()
	}

	static move_tracker_item(direction, *) {
		focused_row := this.tracker_lv.GetNext(0, "Focused")
		if (!focused_row)
			return

		target_row := focused_row + direction
		if (target_row < 1 || target_row > this.tracker_lv.GetCount())
			return

		key := this.tracker_lv.GetText(focused_row, 1)
		name := this.tracker_lv.GetText(focused_row, 2)
		status := this.tracker_lv.GetText(focused_row, 3)

		this.tracker_lv.Delete(focused_row)
		this.tracker_lv.Insert(target_row, "Focus Select", key, name, status)

		this.save_tracker_order()
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

	static enforce_float(GuiCtrl, *) {
		clean := RegExReplace(GuiCtrl.Value, "[^\d.]")
		clean := RegExReplace(clean, "^([^.]*\.)|\.", "$1")

		if (GuiCtrl.Value != clean) {
			pos := SendMessage(0x00B0, 0, 0, GuiCtrl)
			start := pos & 0xFFFF
			GuiCtrl.Value := clean
			SendMessage(0x00B1, start - 1, start - 1, GuiCtrl)
		}
	}

	static copy_field_settings(*) {
		settings := Config.Get("alt", "default_field") "|" Config.Get("alt", "pattern") "|" Config.Get("alt", "pattern_size") "|" Config.Get("alt", "pattern_width") "|" Config.Get("alt", "sprinkler_location") "|" Config.Get("alt", "sprinkler_distance") "|" Config.Get("alt", "rot_lr_amount") "|" Config.Get("alt", "rot_lr_dir")
		A_Clipboard := settings
		ToolTip("Settings copied to clipboard")
		SetTimer(() => ToolTip(), -500)
	}

	static paste_field_settings(*) {
		try {
			data := StrSplit(A_Clipboard, "|")
			if (data.Length != 8) {
				ToolTip("Invalid settings.")
				SetTimer(() => ToolTip(), -500)
				return
			}

			Config.Set("alt", "default_field", data[1])
			Config.Set("alt", "pattern", data[2])
			Config.Set("alt", "pattern_size", data[3])
			Config.Set("alt", "pattern_width", data[4])
			Config.Set("alt", "sprinkler_location", data[5])
			Config.Set("alt", "sprinkler_distance", data[6])
			Config.Set("alt", "rot_lr_amount", data[7])
			Config.Set("alt", "rot_lr_dir", data[8])
			Config.WriteIni()

			process_manager.broadcast_setting("alt", "default_field", data[1])
			process_manager.broadcast_setting("alt", "pattern", data[2])
			process_manager.broadcast_setting("alt", "pattern_size", data[3])
			process_manager.broadcast_setting("alt", "pattern_width", data[4])
			process_manager.broadcast_setting("alt", "sprinkler_location", data[5])
			process_manager.broadcast_setting("alt", "sprinkler_distance", data[6])
			process_manager.broadcast_setting("alt", "rot_lr_amount", data[7])
			process_manager.broadcast_setting("alt", "rot_lr_dir", data[8])

			ToolTip("Settings pasted from clipboard")
			SetTimer(() => ToolTip(), -500)
			Reload()
		} catch {
			ToolTip("Error pasting settings.")
			SetTimer(() => ToolTip(), -500)
		}
	}

	static build_warnings_tab() {
		this.main_gui.Add("GroupBox", "Section w420 h225", "Warning Settings")
		this.main_gui.SetFont("s8", "Segoe UI")

		this.warns_lv := this.main_gui.Add("ListView", "xs+10 ys+20 w400 h90 -Hdr", ["Key", "Name", "Status", "Threshold", "Max"])
		this.warns_lv.OnEvent("ItemSelect", ObjBindMethod(this, "on_warn_select"))

		this.chk_warn_enable := this.main_gui.Add("CheckBox", "xs+10 y+15 w65 h20", "Enable")
		this.chk_warn_enable.OnEvent("Click", ObjBindMethod(this, "on_warn_toggle"))

		this.main_gui.Add("Text", "x+5 yp+3 w60", "Threshold:")
		this.edit_warn_thresh := this.main_gui.Add("Edit", "x+0 yp-3 w40 h18 Number Center")
		this.edit_warn_thresh.OnEvent("Change", ObjBindMethod(this, "on_warn_param_change", "threshold"))
		this.lbl_warn_max := this.main_gui.Add("Text", "x+5 yp+3 w35", "/ 0")

		this.main_gui.Add("Text", "x+5 yp w50", "Volume:")
		this.edit_warn_vol := this.main_gui.Add("Edit", "x+0 yp-3 w40 h18 Number Center")
		this.edit_warn_vol.OnEvent("Change", ObjBindMethod(this, "on_warn_param_change", "volume"))
		this.ud_warn_vol := this.main_gui.Add("UpDown", "Range0-100")

		this.chk_warn_playonce := this.main_gui.Add("CheckBox", "x+15 yp+3 w80 h20", "Play Once")
		this.chk_warn_playonce.OnEvent("Click", ObjBindMethod(this, "on_warn_param_change", "play_once"))

		this.main_gui.Add("Text", "xs+10 y+15 w40", "Sound:")
		this.edit_warn_sound := this.main_gui.Add("Edit", "x+0 yp-3 w235 h20 ReadOnly")

		this.btn_warn_browse := this.main_gui.Add("Button", "x+10 yp-1 w50 h22", "Browse")
		this.btn_warn_browse.OnEvent("Click", ObjBindMethod(this, "browse_warn_sound"))

		this.btn_warn_test := this.main_gui.Add("Button", "x+5 yp w50 h22", "Test")
		this.btn_warn_test.OnEvent("Click", ObjBindMethod(this, "test_warn_sound"))

		this.populate_warns_list()
		this.set_warn_controls_state(false)

		this.warns_lv.ModifyCol(1, 0)
		this.warns_lv.ModifyCol(2, 120)
		this.warns_lv.ModifyCol(3, 70)
		this.warns_lv.ModifyCol(4, 180)
		this.warns_lv.ModifyCol(5, 0)
		this.main_gui.SetFont("s9", "Segoe UI")
	}

	static set_warn_controls_state(is_enabled) {
		this.chk_warn_enable.Enabled := is_enabled
		this.edit_warn_thresh.Enabled := is_enabled
		this.edit_warn_vol.Enabled := is_enabled
		this.ud_warn_vol.Enabled := is_enabled
		this.chk_warn_playonce.Enabled := is_enabled
		this.btn_warn_browse.Enabled := is_enabled
		this.btn_warn_test.Enabled := is_enabled

		if (!is_enabled) {
			this.chk_warn_enable.Value := 0
			this.edit_warn_thresh.Value := ""
			this.lbl_warn_max.Text := "/ 0"
			this.edit_warn_vol.Value := ""
			this.chk_warn_playonce.Value := 0
			this.edit_warn_sound.Value := ""
		}
	}

	static populate_warns_list() {
		try {
			this.warns_lv.Delete()
			for index, item in this.warn_items {
				key := item[1]
				name := item[2]
				max_val := item[3]

				is_enabled := Config.Get("warns", key "_enabled", 0)
				status_text := is_enabled ? "Enabled" : ""

				current_threshold := Config.Get("warns", key "_threshold", 25)
				if (!IsNumber(current_threshold) || current_threshold == "") {
					current_threshold := 25
				}

				threshold_text := "Threshold: " current_threshold " / " max_val

				this.warns_lv.Add("", key, name, status_text, threshold_text, max_val)
			}
		} catch as err {
			this.log_msg("Error populating warns list: " err.Message)
		}
	}

	static on_warn_toggle(ctrl, *) {
		if (this.current_warn_key == "") {
			return
		}

		focused_row := this.warns_lv.GetNext(0, "Focused")
		if (!focused_row) {
			return
		}

		status_text := ctrl.Value ? "Enabled" : ""
		key := this.warns_lv.GetText(focused_row, 1)
		name := this.warns_lv.GetText(focused_row, 2)
		threshold := this.warns_lv.GetText(focused_row, 4)
		max_val := this.warns_lv.GetText(focused_row, 5)

		this.warns_lv.Modify(focused_row, "", key, name, status_text, threshold, max_val)
		this.update_and_broadcast("warns", key "_enabled", ctrl.Value)
	}

	static on_warn_param_change(param_type, ctrl, *) {
		if (this.current_warn_key == "") {
			return
		}

		key := this.current_warn_key
		val := ctrl.Value

		if (param_type == "threshold") {
			if (val == "") {
				val := 0
			}

			focused_row := this.warns_lv.GetNext(0, "Focused")
			if (focused_row) {
				name := this.warns_lv.GetText(focused_row, 2)
				status := this.warns_lv.GetText(focused_row, 3)
				max_val := this.warns_lv.GetText(focused_row, 5)

				threshold_text := "Threshold: " val " / " max_val
				this.warns_lv.Modify(focused_row, "", key, name, status, threshold_text, max_val)
			}
		}

		this.update_and_broadcast("warns", key "_" param_type, val)
	}

	static browse_warn_sound(*) {
		if (this.current_warn_key == "") {
			return
		}

		selected_file := FileSelect(1, , "Select Sound File", "Audio (*.wav; *.mp3)")
		if (!selected_file) {
			return
		}

		this.update_and_broadcast("warns", this.current_warn_key "_sound_file", selected_file)
		this.edit_warn_sound.Value := this.format_display_path(selected_file)
	}

	static test_warn_sound(*) {
		if (this.current_warn_key == "") {
			return
		}

		sound_path := Config.Get("warns", this.current_warn_key "_sound_file", "C:\Windows\Media\Windows Critical Stop.wav")
		if (!FileExist(sound_path)) {
			sound_path := "C:\Windows\Media\Windows Critical Stop.wav"
		}

		vol := Config.Get("warns", this.current_warn_key "_volume", 25)
		try {
			kairos_main.test_audio_player := Audio(sound_path)
			kairos_main.test_audio_player.Play(vol)
		} catch as err {
			MsgBox("Error playing audio: " err.Message, "Kairos", 16)
		}
	}

	static on_warn_select(gui_ctrl, item_index, selected) {
		if (!selected) {
			if (!this.warns_lv.GetNext(0)) {
				this.current_warn_key := ""
				this.set_warn_controls_state(false)
			}
			return
		}

		key := this.warns_lv.GetText(item_index, 1)
		max_val := this.warns_lv.GetText(item_index, 5)

		this.current_warn_key := key
		this.current_warn_max := max_val
		this.set_warn_controls_state(true)

		status := this.warns_lv.GetText(item_index, 3)
		this.chk_warn_enable.Value := (status == "Enabled")

		thresh_val := Config.Get("warns", key "_threshold", 25)
		this.edit_warn_thresh.Value := (IsNumber(thresh_val) && thresh_val != "") ? thresh_val : 25
		this.lbl_warn_max.Text := "/ " max_val

		vol_val := Config.Get("warns", key "_volume", 25)
		this.edit_warn_vol.Value := (IsNumber(vol_val) && vol_val != "") ? vol_val : 25

		play_val := Config.Get("warns", key "_play_once", 0)
		this.chk_warn_playonce.Value := (play_val == 1 || play_val == "1") ? 1 : 0

		raw_path := Config.Get("warns", key "_sound_file", "C:\Windows\Media\Windows Critical Stop.wav")
		this.edit_warn_sound.Value := this.format_display_path(raw_path)
	}

	static save_tracker_order() {
		active_passives := []
		total_rows := this.tracker_lv.GetCount()

		loop total_rows {
			row_idx := A_Index
			if (this.tracker_lv.GetText(row_idx, 3) == "Enabled") {
				key := this.tracker_lv.GetText(row_idx, 1)
				active_passives.Push(key)
			}
		}

		save_str := ""
		for index, item in active_passives {
			save_str .= (A_Index > 1 ? "|" : "") item
		}

		this.update_and_broadcast("tracker", "passives", save_str)
	}

	static format_display_path(file_path) {
		try {
			work_dir := A_WorkingDir
			if (InStr(file_path, work_dir)) {
				return StrReplace(file_path, work_dir, "root")
			}

			user_dir := EnvGet("USERPROFILE")
			if (InStr(file_path, user_dir)) {
				return StrReplace(file_path, user_dir, "~")
			}

			return file_path
		} catch {
			return file_path
		}
	}

	static build_boost_bar_tab() {
		this.main_gui.Add("GroupBox", "Section w420 h235", "Boost Bar Slots")
		this.main_gui.SetFont("s8", "Segoe UI")

		this.boost_lv := this.main_gui.Add("ListView", "xs+10 ys+20 w400 h80 -Hdr", ["Slot Num", "Name", "Status", "Timer", "Modes"])
		this.boost_lv.OnEvent("ItemSelect", ObjBindMethod(this, "on_boost_select"))

		this.chk_boost_enable := this.main_gui.Add("CheckBox", "xs+10 y+10 w75 h20", "Enable Slot")
		this.chk_boost_enable.OnEvent("Click", ObjBindMethod(this, "on_boost_toggle"))

		this.main_gui.Add("Text", "x+10 yp+3 w40", "Timer:")
		this.edit_boost_timer := this.main_gui.Add("Edit", "x+0 yp-3 w50 h18 Number Center")
		this.edit_boost_timer.OnEvent("Change", ObjBindMethod(this, "on_boost_timer_change"))

		this.main_gui.Add("Text", "xs+10 y+5 w400 0x10")

		mode_list := ["Timer", "Re-Glitter", "On Scorch Star", "Re-Smoothie", "On Pop Star", "On Gummyballer", "On Star Shower", "On Gummy Star", "On Gummy Morph", "On Coconut Combo", "On X-Flame"]
		this.boost_mode_chks := Map()

		for index, mode_name in mode_list {
			i := A_Index - 1
			col := Mod(i, 3)

			if (col == 0) {
				opt := (i == 0) ? "xs+15 y+0" : "xs+15 y+5"
			} else {
				opt := "x+5 yp"
			}

			w_val := (col == 0) ? "w120" : (col == 1 ? "w110" : "w125")

			cb := this.main_gui.Add("CheckBox", opt " " w_val " h16", mode_name)
			cb.OnEvent("Click", ObjBindMethod(this, "on_boost_mode_toggle"))
			this.boost_mode_chks[mode_name] := cb
		}

		this.populate_boost_list()
		this.set_boost_controls_state(false)

		this.boost_lv.ModifyCol(1, 0)
		this.boost_lv.ModifyCol(2, 50)
		this.boost_lv.ModifyCol(3, 60)
		this.boost_lv.ModifyCol(4, 50)
		this.boost_lv.ModifyCol(5, 210)

		this.main_gui.SetFont("s9", "Segoe UI")
	}

	static set_boost_controls_state(is_enabled) {
		this.chk_boost_enable.Enabled := is_enabled
		this.edit_boost_timer.Enabled := is_enabled

		for mode_name, cb in this.boost_mode_chks {
			cb.Enabled := is_enabled
			if (!is_enabled) {
				cb.Value := 0
			}
		}

		if (!is_enabled) {
			this.chk_boost_enable.Value := 0
			this.edit_boost_timer.Value := ""
		}
	}

	static populate_boost_list() {
		try {
			this.boost_lv.Delete()
			loop 7 {
				idx := A_Index
				is_enabled := Config.Get("boost_bar", "slot_active_" idx, 0)
				status_text := is_enabled ? "Enabled" : ""

				timer_val := Config.Get("boost_bar", "slot_timer_" idx, 100)
				if (!IsNumber(timer_val) || timer_val == "") {
					timer_val := 100
				}

				current_modes := Config.Get("boost_bar", "slot_mode_" idx, "Timer")
				mode_text := (current_modes == "") ? "None" : (StrSplit(current_modes, "|").Length > 1 ? "Multiple" : current_modes)

				this.boost_lv.Add("", idx, "Slot " idx, status_text, timer_val, mode_text)
			}
		} catch as err {
			this.log_msg("Error populating boost list: " err.Message)
		}
	}

	static on_boost_select(gui_ctrl, item_index, selected) {
		if (!selected) {
			if (!this.boost_lv.GetNext(0)) {
				this.current_boost_slot := 0
				this.set_boost_controls_state(false)
			}
			return
		}

		idx := this.boost_lv.GetText(item_index, 1)
		this.current_boost_slot := idx
		this.set_boost_controls_state(true)

		status := this.boost_lv.GetText(item_index, 3)
		this.chk_boost_enable.Value := (status == "Enabled")

		timer_val := Config.Get("boost_bar", "slot_timer_" idx, 100)
		this.edit_boost_timer.Value := (IsNumber(timer_val) && timer_val != "") ? timer_val : 100

		current_modes := Config.Get("boost_bar", "slot_mode_" idx, "Timer")
		for mode_name, cb in this.boost_mode_chks {
			cb.Value := InStr("|" current_modes "|", "|" mode_name "|")
		}
	}

	static on_boost_mode_toggle(*) {
		idx := this.current_boost_slot
		if (idx == 0) {
			return
		}

		saved_list := []
		for mode_name, cb in this.boost_mode_chks {
			if (cb.Value) {
				saved_list.Push(mode_name)
			}
		}

		save_str := ""
		for index, item in saved_list {
			save_str .= (A_Index > 1 ? "|" : "") item
		}

		this.update_and_broadcast("boost_bar", "slot_mode_" idx, save_str)

		count := saved_list.Length
		display_text := (count == 0) ? "None" : (count > 1 ? "Multiple" : save_str)

		focused_row := this.boost_lv.GetNext(0, "Focused")
		if (focused_row) {
			key_idx := this.boost_lv.GetText(focused_row, 1)
			name := this.boost_lv.GetText(focused_row, 2)
			status := this.boost_lv.GetText(focused_row, 3)
			timer := this.boost_lv.GetText(focused_row, 4)
			this.boost_lv.Modify(focused_row, "", key_idx, name, status, timer, display_text)
		}
	}

	static on_boost_toggle(ctrl, *) {
		if (this.current_boost_slot == 0) {
			return
		}

		focused_row := this.boost_lv.GetNext(0, "Focused")
		if (!focused_row) {
			return
		}

		status_text := ctrl.Value ? "Enabled" : ""
		idx := this.boost_lv.GetText(focused_row, 1)
		name := this.boost_lv.GetText(focused_row, 2)
		timer := this.boost_lv.GetText(focused_row, 4)
		modes := this.boost_lv.GetText(focused_row, 5)

		this.boost_lv.Modify(focused_row, "", idx, name, status_text, timer, modes)
		this.update_and_broadcast("boost_bar", "slot_active_" idx, ctrl.Value)
	}

	static on_boost_timer_change(ctrl, *) {
		if (this.current_boost_slot == 0) {
			return
		}

		val := ctrl.Value
		if (val == "") {
			val := 0
		}

		focused_row := this.boost_lv.GetNext(0, "Focused")
		if (focused_row) {
			idx := this.boost_lv.GetText(focused_row, 1)
			name := this.boost_lv.GetText(focused_row, 2)
			status := this.boost_lv.GetText(focused_row, 3)
			modes := this.boost_lv.GetText(focused_row, 5)

			this.boost_lv.Modify(focused_row, "", idx, name, status, val, modes)
		}

		this.update_and_broadcast("boost_bar", "slot_timer_" this.current_boost_slot, val)
	}

	static open_boost_mode_selector(*) {
		idx := this.current_boost_slot
		if (idx == 0) {
			return
		}

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
				if (ctrl.Value) {
					saved_list.Push(mode)
				}
			}

			save_str := ""
			for item in saved_list {
				save_str .= (A_Index > 1 ? "|" : "") item
			}

			this.update_and_broadcast("boost_bar", "slot_mode_" idx, save_str)

			count := saved_list.Length
			display_text := (count == 0) ? "None" : (count > 1 ? "Multiple" : save_str)

			focused_row := this.boost_lv.GetNext(0, "Focused")
			if (focused_row) {
				key_idx := this.boost_lv.GetText(focused_row, 1)
				name := this.boost_lv.GetText(focused_row, 2)
				status := this.boost_lv.GetText(focused_row, 3)
				timer := this.boost_lv.GetText(focused_row, 4)
				this.boost_lv.Modify(focused_row, "", key_idx, name, status, timer, display_text)
			}
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

		try Hotkey(Config.Get("main", "start_hotkey", "F1"), "Off")
		try Hotkey(Config.Get("main", "pause_hotkey", "F2"), "Off")
		try Hotkey(Config.Get("main", "stop_hotkey", "F3"), "Off")

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
		if GetKeyState("Ctrl", "P")
			mods .= "^"
		if GetKeyState("Shift", "P")
			mods .= "+"
		if GetKeyState("Alt", "P")
			mods .= "!"
		if (GetKeyState("LWin", "P") || GetKeyState("RWin", "P"))
			mods .= "#"

		if (captured_key != "") {
			final_key := RegExReplace(captured_key, "[\^\+!\#]", "")
		} else if (ih.EndReason == "EndKey") {
			if (ih.EndKey != "Escape")
				final_key := ih.EndKey
		}

		if (final_key != "") {
			if (StrLen(final_key) == 1)
				final_key := StrLower(final_key)

			final_key := mods . final_key

			if (key_name ~= "start_hotkey|pause_hotkey|stop_hotkey") {
				base_key := RegExReplace(final_key, "[\^\+!\#]", "")
				blacklist := "|LButton|RButton|Enter|Space|Tab|Backspace|Escape|"

				if InStr(blacklist, "|" base_key "|") {
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
			this.register_hotkeys()
		} else {
			display_ctrl.Value := final_key
			Config.Set(section, key_name, final_key)

			if (key_name ~= "start_hotkey|pause_hotkey|stop_hotkey") {
				this.register_hotkeys()

				if (key_name == "start_hotkey" && this.HasOwnProp("btn_start_ctrl"))
					this.btn_start_ctrl.Text := "Start (" final_key ")"
				else if (key_name == "pause_hotkey" && this.HasOwnProp("btn_pause_ctrl"))
					this.btn_pause_ctrl.Text := "Pause (" final_key ")"
				else if (key_name == "stop_hotkey" && this.HasOwnProp("btn_stop_ctrl"))
					this.btn_stop_ctrl.Text := "Stop (" final_key ")"
			}
		}
	}

	static on_start(*) {
		this.is_paused := false
		this.is_running := true
		process_manager.broadcast_state("running")
	}

	static on_pause(*) {
		if (!this.is_running)
			return

		this.is_paused := !this.is_paused
		state_str := this.is_paused ? "paused" : "resumed"
		process_manager.broadcast_state(state_str)
	}

	static on_stop(*) {
		this.is_paused := false
		this.is_running := false
		this.save_window_position()
		process_manager.kill_all()
		Reload()
	}

	static on_exit(*) {
		this.save_window_position()
		process_manager.kill_all()
		ExitApp()
	}

	static save_window_position() {
		try {
			this.main_gui.GetPos(&x, &y)

			if (x > -10000 && y > -10000) {
				Config.Set("main", "gui_x", x)
				Config.Set("main", "gui_y", y)
				Config.WriteIni()
			}
		}
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

	static export_config(*) {
		data := Map()
		for section, keys in Config.Default {
			sectionMap := Map()
			for key, val in keys
				sectionMap[key] := Config.Get(section, key, val)
			data[section] := sectionMap
		}

		for section, keys in Config.Data {
			if !data.Has(section)
				data[section] := Map()
			for key, val in keys {
				if !data[section].Has(key)
					data[section][key] := val
			}
		}

		jsonStr := JSON.stringify(data)

		savePath := FileSelect("S16", A_WorkingDir "\settings\" Config.currentPreset ".kairos", "Export Config", "Kairos Config (*.kairos)")
		if (savePath == "")
			return

		if !InStr(savePath, ".kairos")
			savePath .= ".kairos"

		f := FileOpen(savePath, "w", "UTF-8")
		f.Write(jsonStr)
		f.Close()

		MsgBox("Config exported successfully.", "Kairos", 64)
	}

	static import_config(*) {
		filePath := FileSelect(1, A_WorkingDir "\settings\", "Import Config", "Kairos Config (*.kairos)")
		if (filePath == "")
			return

		try {
			jsonStr := FileRead(filePath, "UTF-8")
			data := JSON.parse(jsonStr)

			for section, keys in data {
				for key, val in keys
					Config.Set(section, key, val)
			}

			Config.WriteIni()
			MsgBox("Config imported successfully.", "Kairos", 64)
			Reload()
		} catch {
			MsgBox("Import failed: invalid or corrupted file.", "Kairos", 16)
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