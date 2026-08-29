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
	static is_running := false
	static scanner := unset
	static startup_timer := 0

	static slot_w := 68
	static slot_h := 36
	static gap := 7
	static width := (68 * 7) + (7 * 6) + 4
	static height := 36

	static brush_back := 0
	static brush_off := 0
	static brush_on := 0
	static brush_special := 0
	static brush_multi := 0
	static brush_timer := 0
	static brush_running := 0

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
		"On Scorch", "scorch"
		, "On Gummy", "gummystar"
		, "ReGlitter", "glitter"
		, "ReSmoothie", "supersmoothie"
		, "On Shower", "shower"
		, "On Pop Star", "popstar"
		, "On Baller", "gummyballer"
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

		OnMessage(0x201, ObjBindMethod(this, "on_click"))
		OnMessage(0x204, ObjBindMethod(this, "on_right_click"))

		if (this.master_pid) {
			SetTimer(ObjBindMethod(this, "send_heartbeat"), 2000)
		}

		IPC.init(ObjBindMethod(this, "handle_command"))
		this.startup_timer := ObjBindMethod(this, "request_startup_settings")
		SetTimer(this.startup_timer, 250)
		this.request_startup_settings()
		SetTimer(ObjBindMethod(this, "follow_window"), 50)
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
			if (data["state"] == "running") {
				this.start()
				return
			}

			if (data["state"] == "toggle") {
				if (this.is_running) {
					this.stop()
					return
				}

				this.start()
				return
			}
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
			this.draw()

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
		if (this.is_running) {
			return
		}
		this.is_running := true

		if (this.settings["main"]["boost_bar_enabled"]) {
			this.scanner.Toggle(1)
			SetTimer(this.spam_func, 5)
		}
		this.draw()
		this.follow_window()
	}

	static stop() {
		if (!this.is_running) {
			return
		}
		this.is_running := false

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
			if (IsObject(win) && win.ok) {
				target_x := win.x + (win.w // 2) - 261
				target_y := win.y + win.h - 182
				should_show := this.settings["main"]["boost_bar_enabled"] && (!this.is_running || (this.is_running && this.settings["boost_bar"]["show_when_active"]))
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
		Gdip_FillRoundedRectangle(this.G, this.brush_back, 0, 0, this.width, this.height, 5)

		loop 7 {
			idx := A_Index
			is_slot_active := this.settings["boost_bar"]["slot_active_" idx]
			mode_str := this.settings["boost_bar"]["slot_mode_" idx]
			timer_val := this.settings["boost_bar"]["slot_timer_" idx]
			active_modes := (mode_str == "") ? [] : StrSplit(mode_str, "|")

			x := 2 + (idx - 1) * (this.slot_w + this.gap)
			y := 2

			if !(is_slot_active) {
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

		if (this.is_running) {
			Gdip_FillRectangle(this.G, this.brush_running, 0, this.height - 2, this.width, 2)
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
		loop 7 {
			slot_x := 2 + (A_Index - 1) * (this.slot_w + this.gap)
			if (x >= slot_x && x <= slot_x + this.slot_w) {
				if (y <= 18) {
					if (click_type == "Right") {
						this.open_mode_menu(A_Index)
					} else {
						try WinActivate("ahk_id " WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
						this.toggle_slot(A_Index)
					}
				} else if (y > 18 && y < 34) {
					this.open_edit(A_Index, slot_x, 20)
				}
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
		m := Menu()
		current_str := this.settings["boost_bar"]["slot_mode_" idx]
		has_mode(name) => InStr("|" current_str "|", "|" name "|")
		for mode_name in this.available_modes {
			m.Add(mode_name, ObjBindMethod(this, "toggle_mode", idx, mode_name))
			if has_mode(mode_name) {
				m.Check(mode_name)
			}
		}
		m.Show()
	}

	static toggle_mode(idx, mode_name, *) {
		current_str := this.settings["boost_bar"]["slot_mode_" idx]
		current_list := current_str == "" ? [] : StrSplit(current_str, "|")
		new_list := []
		found := false

		for item in current_list {
			if (item == mode_name) {
				found := true
			} else if (item != "") {
				new_list.Push(item)
			}
		}

		if (!found) {
			new_list.Push(mode_name)
		}

		new_str := ""
		for item in new_list {
			new_str .= (A_Index > 1 ? "|" : "") item
		}

		this.settings["boost_bar"]["slot_mode_" idx] := new_str
		this.save_settings_to_master("boost_bar", "slot_mode_" idx, new_str)
		this.draw()
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
		if (!this.is_running || !this.settings["main"]["boost_bar_enabled"]) {
			return
		}

		static last_fire := Map()
		now := A_TickCount

		loop 7 {
			idx := A_Index
			if (!this.settings["boost_bar"]["slot_active_" idx]) {
				if (last_fire.Has(idx)) {
					last_fire.Delete(idx)
				}
				continue
			}

			delay := this.settings["boost_bar"]["slot_timer_" idx]
			if (last_fire.Has(idx) && (now - last_fire[idx] < delay)) {
				continue
			}

			mode_str := this.settings["boost_bar"]["slot_mode_" idx]
			active_modes := (mode_str == "") ? [] : StrSplit(mode_str, "|")

			has_valid_condition := false
			for _, ui_mode_name in active_modes {
				if (ui_mode_name == "Timer" || ui_mode_name == "") {
					has_valid_condition := true
					break
				}

				scanner_key := this.available_modes.Has(ui_mode_name) ? this.available_modes[ui_mode_name] : ""

				try {
					if (scanner_key != "" && this.scanner.Data.Has(scanner_key) && this.scanner.Data[scanner_key] > 0) {
						has_valid_condition := true
						break
					}
				}
			}

			if (!has_valid_condition) {
				continue
			}

			Send(idx)
			last_fire[idx] := now
		}
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
		if (this.brush_back) {
			return
		}
		this.brush_back := Gdip_BrushCreateSolid(0xCC111111)
		this.brush_off := Gdip_BrushCreateSolid(0xFF333333)
		this.brush_on := Gdip_BrushCreateSolid(0xFF4cAF50)
		this.brush_special := Gdip_BrushCreateSolid(0xFF3480EB)
		this.brush_multi := Gdip_BrushCreateSolid(0xFF9C27B0)
		this.brush_timer := Gdip_BrushCreateSolid(0xFF222222)
		this.brush_running := Gdip_BrushCreateSolid(0xFFFF0000)
	}

	static dispose_brushes() {
		brushes := [
			this.brush_back, this.brush_off, this.brush_on,
			this.brush_special, this.brush_multi, this.brush_timer,
			this.brush_running
		]
		for _, handle in brushes {
			if (handle)
				Gdip_DeleteBrush(handle)
		}
		this.brush_back := 0
		this.brush_off := 0
		this.brush_on := 0
		this.brush_special := 0
		this.brush_multi := 0
		this.brush_timer := 0
		this.brush_running := 0
	}
}

boost_bar.init()