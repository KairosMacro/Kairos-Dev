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
#Include "..\..\lib\core\detector.ahk"
#Include "..\..\lib\core\scanner.ahk"
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"

if !(pToken := Gdip_Startup()) {
	throw Error("GDI+ failed to start, exiting script.")
}

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"
#Include "..\..\assets\bitmaps\Buffs.ahk"
#Include "..\..\assets\bitmaps\Boosts.ahk"

TraySetIcon "Assets\Images\Kairos.ico"

class boost_bar {
	static master_pid := ""
	static my_path := "scripts\general\boost_bar.ahk"
	static current_state := "stopped"
	static scanner := unset
	static startup_timer := 0

	static slot_w := 68
	static slot_h := 36
	static gap := 7
	static width := 537
	static height := 36

	static color_bg := 0xB31E1E1E
	static color_active := 0xFF4CAF50
	static color_inactive := 0xFFD32F2F

	static brush_bg := 0
	static brush_off := 0
	static brush_on := 0
	static brush_special := 0
	static brush_multi := 0
	static brush_timer := 0

	static mode_gui := 0
	static mode_checkboxes := Map()

	static cooldowns := Map(
		"scorch", { last_not_found: 0, cooldown: 60000, duration: 45000 },
		"x-flame", { last_not_found: 0, cooldown: 20000, duration: 0 },
		"popstar", { last_not_found: 0, cooldown: 60000, duration: 45000 },
		"gummystar", { last_not_found: 0, cooldown: 60000, duration: 45000 }
	)

	static settings := Map(
		"main", Map(
			"boost_bar_enabled", 0
		)
		, "boost_bar", Map(
			"show_when_active", 1
			, "slot_active_1", 0, "slot_timer_1", 100, "slot_mode_1", "Timer"
			, "slot_active_2", 0, "slot_timer_2", 100, "slot_mode_2", "Timer"
			, "slot_active_3", 0, "slot_timer_3", 100, "slot_mode_3", "Timer"
			, "slot_active_4", 0, "slot_timer_4", 100, "slot_mode_4", "Timer"
			, "slot_active_5", 0, "slot_timer_5", 100, "slot_mode_5", "Timer"
			, "slot_active_6", 0, "slot_timer_6", 100, "slot_mode_6", "Timer"
			, "slot_active_7", 0, "slot_timer_7", 100, "slot_mode_7", "Timer"
		)
	)

	static spam_func := ObjBindMethod(this, "spam_loop")

	static available_modes := Map(
		"Re-Glitter", "glitter"
		, "On Scorch Star", "scorch"
		, "Re-Smoothie", "supersmoothie"
		, "On Pop Star", "popstar"
		, "On Gummyballer", "gummyballer"
		, "On Star Shower", "shower"
		, "On Gummy Star", "gummystar"
		, "On Gummy Morph", "gummymorph"
		, "On Coconut Combo", "combo"
		, "On X-Flame", "x-flame"
	)

	static init() {
		if (A_Args.Length > 0) {
			this.master_pid := A_Args[1]
		}

		this.gui_obj := Gui("-Caption +E0x80000 +E0x08000000 +AlwaysOnTop +ToolWindow +OwnDialogs", "Boost Bar")
		this.gui_obj.Show("NA Hide")
		this.hbm := CreateDIBSection(this.width, this.height)
		this.hdc := CreateCompatibleDC()
		this.obm := SelectObject(this.hdc, this.hbm)
		this.G := Gdip_GraphicsFromHDC(this.hdc)
		Gdip_SetSmoothingMode(this.G, 4)

		this.init_brushes()
		this.draw()

		this.scanner := ScannerEngine()
		roblox.start_tracker()

		OnMessage(0x201, ObjBindMethod(this, "on_click"))
		OnMessage(0x204, ObjBindMethod(this, "on_right_click"))

		if (this.master_pid) {
			SetTimer(ObjBindMethod(this, "send_heartbeat"), 2000)
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
		IPC.send_message("ahk_pid " this.master_pid, 1, payload)
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
				SetTimer(ObjBindMethod(this, "follow_window"), 50)
			}

			for section_name, section_data in data["settings"] {
				if (!this.settings.Has(section_name)) {
					this.settings[section_name] := Map()
				}
				for key, val in section_data {
					this.settings[section_name][key] := val
				}
			}
			this.draw()

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

			if (!this.settings.Has(section)) {
				return
			}

			if (this.settings[section].Has(key)) {
				this.settings[section][key] := val
				this.draw()
				if (key == "boost_bar_enabled") {
					this.follow_window()
				}
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
		if (this.settings["main"]["boost_bar_enabled"]) {
			this.scanner.Toggle(1)
			SetTimer(this.spam_func, 5)
		}
		this.draw()
		this.follow_window()
	}

	static stop() {
		if (this.current_state == "stopped")
			return

		this.current_state := "stopped"
		this.scanner.Toggle(0)
		SetTimer(this.spam_func, 0)
		this.draw()
		this.follow_window()
	}

	static pause() {
		if (this.current_state == "paused")
			return

		this.current_state := "paused"
		this.scanner.Toggle(0)
		SetTimer(this.spam_func, 0)
		this.draw()
		this.follow_window()
	}

	static cleanup() {
		this.stop()
		this.dispose_brushes()
		SelectObject(this.hdc, this.obm)
		DeleteObject(this.hbm)
		DeleteDC(this.hdc)
		Gdip_DeleteGraphics(this.G)
		this.gui_obj.Destroy()
	}

	static follow_window() {
		try {
			win := Roblox.Get()
			if (IsObject(win) && win.is_ok) {
				target_x := win.x + (win.w // 2) - 261
				target_y := win.y + win.h - 182
				should_show := this.settings["main"]["boost_bar_enabled"] && (this.current_state != "running" || (this.current_state == "running" && this.settings["boost_bar"]["show_when_active"]))
				if (should_show) {
					this.gui_obj.Show("NA x" target_x " y" target_y " w" this.width " h" this.height)
				} else {
					this.gui_obj.Hide()
				}
			} else {
				this.gui_obj.Hide()
			}
		}
	}

	static draw(*) {
		Gdip_GraphicsClear(this.G)

		Gdip_FillRoundedRectangle(this.G, this.brush_bg, 0, 0, this.width, this.height, 5)

		c_accent := (this.current_state == "running") ? this.color_active : this.color_inactive
		c_ind := Gdip_BrushCreateSolid(c_accent)
		Gdip_FillRoundedRectangle(this.G, c_ind, 5, 5, 5, this.height - 10, 2)
		Gdip_DeleteBrush(c_ind)

		start_x := 15

		loop 7 {
			idx := A_Index
			is_active := this.settings["boost_bar"]["slot_active_" idx]
			mode_str := this.settings["boost_bar"]["slot_mode_" idx]
			timer_val := this.settings["boost_bar"]["slot_timer_" idx]
			active_modes := (mode_str == "") ? [] : StrSplit(mode_str, "|")

			x := start_x + (idx - 1) * (this.slot_w + this.gap)
			y := 2

			if (!is_active) {
				btn_color := this.brush_off
				display_text := "Off"
			} else {
				if (active_modes.Length > 1) {
					btn_color := this.brush_multi
					display_text := "Multi"
				} else if (active_modes.Length == 1 && active_modes[1] != "") {
					display_text := active_modes[1]
					btn_color := (active_modes[1] == "Timer") ? this.brush_on : this.brush_special
				} else {
					btn_color := this.brush_off
					display_text := "None"
				}
			}

			Gdip_FillRoundedRectangle(this.G, btn_color, x, y, this.slot_w, 16, 3)
			options := "x" x " y" y + 1 " w" this.slot_w " h16 Center vCenter cFFFFFFFF s9 Bold"
			Gdip_TextToGraphics(this.G, display_text, options, "Segoe UI")

			Gdip_FillRoundedRectangle(this.G, this.brush_timer, x, y + 18, this.slot_w, 14, 3)
			options := "x" x " y" y + 18 " w" this.slot_w " h14 Center vCenter cFFFFFFFF s10"
			Gdip_TextToGraphics(this.G, String(timer_val), options, "Segoe UI")
		}

		UpdateLayeredWindow(this.gui_obj.hwnd, this.hdc, , , this.width, this.height)
	}

	static on_click(wParam, lParam, msg, hwnd) {
		if (hwnd != this.gui_obj.hwnd) {
			return
		}
		x := lParam & 0xFFFF
		y := lParam >> 16
		this.handle_click(x, y, "Left")
	}

	static on_right_click(wParam, lParam, msg, hwnd) {
		if (hwnd != this.gui_obj.hwnd) {
			return
		}
		x := lParam & 0xFFFF
		y := lParam >> 16
		this.handle_click(x, y, "Right")
	}

	static handle_click(x, y, click_type) {
		start_x := 15

		loop 7 {
			slot_x := start_x + (A_Index - 1) * (this.slot_w + this.gap)

			if (x < slot_x || x > slot_x + this.slot_w)
				continue

			if (y <= 18) {
				if (click_type == "Right") {
					this.open_mode_menu(A_Index)
					return
				}

				try WinActivate("ahk_id " WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
				this.toggle_slot(A_Index)
				return
			}

			if (y > 18 && y < 34) {
				this.open_edit(A_Index, slot_x, 20)
				return
			}
		}
	}

	static toggle_slot(idx) {
		curr := this.settings["boost_bar"]["slot_active_" idx]
		new_val := !curr
		this.settings["boost_bar"]["slot_active_" idx] := new_val
		this.save_settings_to_master("boost_bar", "slot_active_" idx, new_val)
		this.draw()
	}

	static open_mode_menu(idx) {
		if (this.mode_gui) {
			this.close_mode_menu()
		}

		this.mode_gui := Gui("-Caption +AlwaysOnTop +ToolWindow +Border", "Slot " idx " Modes")
		this.mode_gui.BackColor := "1E1E1E"
		this.mode_gui.SetFont("s9 cWhite", "Segoe UI")
		this.mode_gui.OnEvent("Escape", (*) => this.close_mode_menu())

		this.mode_checkboxes.Clear()

		current_str := this.settings["boost_bar"]["slot_mode_" idx]
		has_mode(name) => InStr("|" current_str "|", "|" name "|")

		cb := this.mode_gui.Add("CheckBox", "x15 y10 w140 h20 Checked" has_mode("Timer"), "Timer")
		cb.OnEvent("Click", ObjBindMethod(this, "toggle_mode", idx, "Timer"))
		this.mode_checkboxes[cb.hwnd] := cb

		this.mode_gui.Add("Progress", "x10 y35 w150 h1 c444444 Background444444", 100)

		y_pos := 45
		for mode_name in this.available_modes {
			cb := this.mode_gui.Add("CheckBox", "x15 y" y_pos " w140 h20 Checked" has_mode(mode_name), mode_name)
			cb.OnEvent("Click", ObjBindMethod(this, "toggle_mode", idx, mode_name))
			this.mode_checkboxes[cb.hwnd] := cb
			y_pos += 25
		}

		WinSetTransparent(230, this.mode_gui.hwnd)

		WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this.gui_obj.hwnd)
		menu_w := 170
		menu_h := y_pos + 10
		start_x := 15

		slot_x := wx + start_x + (idx - 1) * (this.slot_w + this.gap)
		final_x := slot_x - (menu_w // 2) + (this.slot_w // 2)
		final_y := wy - menu_h - 10

		this.mode_gui.Show("x" final_x " y" final_y)

		SetTimer(ObjBindMethod(this, "check_menu_focus"), 100)
	}

	static toggle_mode(idx, mode_name, ctrl, *) {
		is_checked := ctrl.Value
		current_str := this.settings["boost_bar"]["slot_mode_" idx]
		current_list := current_str == "" ? [] : StrSplit(current_str, "|")

		new_list := []

		if (mode_name == "Timer" && is_checked) {
			new_list.Push("Timer")
		} else {
			for item in current_list {
				if (item != mode_name && item != "" && item != "Timer") {
					new_list.Push(item)
				}
			}
			if (is_checked) {
				new_list.Push(mode_name)
			}
		}

		new_str := ""
		for item in new_list {
			new_str .= (A_Index > 1 ? "|" : "") item
		}

		if (new_str == "") {
			new_str := "Timer"
		}

		this.settings["boost_bar"]["slot_mode_" idx] := new_str
		this.save_settings_to_master("boost_bar", "slot_mode_" idx, new_str)
		this.draw()

		if (this.mode_gui) {
			for hwnd, chk in this.mode_checkboxes {
				chk.Value := (InStr("|" new_str "|", "|" chk.Text "|") > 0)
			}
		}
	}

	static check_menu_focus() {
		if (this.mode_gui) {
			if (!WinActive("ahk_id " this.mode_gui.hwnd)) {
				this.close_mode_menu()
			}
		} else {
			SetTimer(ObjBindMethod(this, "check_menu_focus"), 0)
		}
	}

	static close_mode_menu() {
		if (this.mode_gui) {
			try this.mode_gui.Destroy()
			this.mode_gui := 0
			this.mode_checkboxes.Clear()
		}
		SetTimer(ObjBindMethod(this, "check_menu_focus"), 0)
	}

	static open_edit(idx, x, y) {
		temp_gui := Gui("-Caption +Owner" this.gui_obj.hwnd)
		temp_gui.SetFont("s10", "Segoe UI")
		WinGetPos(&wx, &wy, &ww, &wh, "ahk_id " this.gui_obj.hwnd)

		screen_x := wx + x
		screen_y := wy + y
		current_val := this.settings["boost_bar"]["slot_timer_" idx]

		ed := temp_gui.Add("Edit", "w" this.slot_w " h18 Center Number", current_val)

		submit_edit(*) {
			try {
				new_timer := Integer(ed.Value)
				this.settings["boost_bar"]["slot_timer_" idx] := new_timer
				this.save_settings_to_master("boost_bar", "slot_timer_" idx, new_timer)
			}
			temp_gui.Destroy()
			this.draw()
		}

		ed.OnEvent("LoseFocus", submit_edit)
		temp_gui.OnEvent("Escape", (*) => temp_gui.Destroy())
		HotIfWinActive("ahk_id " temp_gui.hwnd)
		Hotkey("Enter", submit_edit, "On")
		HotIf

		temp_gui.Show("x" screen_x " y" screen_y " NoActivate")
		ed.Focus()
		Send("^a")
	}

	static spam_loop(*) {
		if (this.current_state != "running" || !this.settings["main"]["boost_bar_enabled"]) {
			return
		}

		win := Roblox.Get()
		if (!IsObject(win) || !win.is_ok) {
			return
		}

		static last_fire := Map()
		now := A_TickCount
		debug_str := "=== BOOST BAR DIAGNOSTICS ===`n"

		loop 7 {
			idx := A_Index
			if (!this.settings["boost_bar"]["slot_active_" idx]) {
				debug_str .= "Slot " idx " | INACTIVE`n"
				if (last_fire.Has(idx)) {
					last_fire.Delete(idx)
				}
				continue
			}

			delay := this.settings["boost_bar"]["slot_timer_" idx]
			time_left := last_fire.Has(idx) ? delay - (now - last_fire[idx]) : 0
			debug_str .= "Slot " idx " | " (time_left > 0 ? "CD: " time_left "ms" : "READY") "`n"

			if (time_left > 0) {
				continue
			}

			mode_str := this.settings["boost_bar"]["slot_mode_" idx]
			active_modes := (mode_str == "") ? [] : StrSplit(mode_str, "|")

			has_valid_condition := false
			for _, ui_mode_name in active_modes {
				if (ui_mode_name == "Timer" || ui_mode_name == "") {
					has_valid_condition := true
					debug_str .= "  -> Mode: " ui_mode_name " (Auto-Trigger)`n"
					break
				}

				scanner_key := this.available_modes.Has(ui_mode_name) ? this.available_modes[ui_mode_name] : ""

				try {
					if (scanner_key != "" && this.scanner.Data.Has(scanner_key)) {
						val := this.scanner.Data[scanner_key]
						is_passive := InStr("|gummystar|popstar|scorch|shower|x-flame|", "|" scanner_key "|")

						if (is_passive) {
							equipped_passives := this.settings.Has("tracker") ? this.settings["tracker"]["passives"] : ""

							if (!InStr("|" equipped_passives "|", "|" scanner_key "|")) {
								debug_str .= "  -> Mode: " ui_mode_name " | Key: " scanner_key " | ERROR: NOT EQUIPPED`n"
								continue
							}

							is_active := false

							if (val == -1) {
								if (this.cooldowns.Has(scanner_key)) {
									cooldown_data := this.cooldowns[scanner_key]
									if (cooldown_data.last_not_found != 0) {
										elapsed := QPC() - cooldown_data.last_not_found
										if (elapsed <= cooldown_data.duration) {
											is_active := true
										}
									}
								} else {
									is_active := true
								}
							} else {
								if (this.cooldowns.Has(scanner_key)) {
									this.cooldowns[scanner_key].last_not_found := QPC()
								}
							}
						} else {
							is_active := (val > 0)
						}

						debug_str .= "  -> Mode: " ui_mode_name " | Key: " scanner_key " | Active: " is_active " (Raw: " val ")`n"

						if (InStr(ui_mode_name, "Re-") && !is_active) {
							has_valid_condition := true
							break
						} else if (InStr(ui_mode_name, "On ") && is_active) {
							has_valid_condition := true
							break
						}
					} else {
						debug_str .= "  -> Mode: " ui_mode_name " | Key: " scanner_key " | ERROR: NOT FOUND`n"
					}
				}
			}

			if (!has_valid_condition) {
				continue
			}

			Send(idx)
			debug_str .= "  *** FIRED KEY " idx " ***`n"
			last_fire[idx] := now
		}
		ToolTip(debug_str, 10, 300, 20)
	}

	static save_settings_to_master(section, key, val) {
		payload := Map(
			"action", "save_setting",
			"section", section,
			"key", key,
			"value", val
		)
		IPC.send_message("ahk_pid " this.master_pid, 1, payload)
	}

	static send_heartbeat(*) {
		payload := Map("action", "heartbeat", "script", this.my_path)
		IPC.send_message("ahk_pid " this.master_pid, 2, payload)
	}

	static init_brushes() {
		if (this.brush_bg)
			return
		this.brush_bg := Gdip_BrushCreateSolid(this.color_bg)
		this.brush_off := Gdip_BrushCreateSolid(0xFF333333)
		this.brush_on := Gdip_BrushCreateSolid(0xFF4cAF50)
		this.brush_special := Gdip_BrushCreateSolid(0xFF3480EB)
		this.brush_multi := Gdip_BrushCreateSolid(0xFF9C27B0)
		this.brush_timer := Gdip_BrushCreateSolid(0xFF222222)
	}

	static dispose_brushes() {
		brushes := [
			this.brush_bg, this.brush_off, this.brush_on,
			this.brush_special, this.brush_multi, this.brush_timer
		]
		for _, handle in brushes {
			if (handle)
				Gdip_DeleteBrush(handle)
		}
		this.brush_bg := 0
		this.brush_off := 0
		this.brush_on := 0
		this.brush_special := 0
		this.brush_multi := 0
		this.brush_timer := 0
	}
}

boost_bar.init()