#Requires AutoHotkey v2.0
#SingleInstance Force
#MaxThreads 255
#Warn VarUnset, Off

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
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"

if !(pToken := Gdip_Startup())
	throw Error("GDI+ failed to start, exiting script.")

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"

TraySetIcon "Assets\Images\Kairos.ico"

class key_alignment {
	static master_pid := ""
	static my_path := "scripts\main\key_alignment.ahk"
	static current_state := "stopped"
	static is_rebinding := false
	static is_action_running := false
	static startup_timer := 0

	static color_rebind := 0xFFFFA500
	static color_active := 0xFF4CAF50
	static color_inactive := 0xFFD32F2F
	static color_text := 0xFFFFFFFF
	static color_bg := 0xB31E1E1E

	static width := 140
	static height := 30
	static brush := 0
	static old_action_key := ""
	static old_rebind_key := ""

	static settings := Map(
		"main", Map(
			"key_alignment_enabled", 1
		)
		, "key_alignment", Map(
			"alignment_key", "e"
			, "rebind_hotkey", "^+k"
			, "rot_right", "Comma"
			, "rot_left", "Period"
			, "show_overlay", 1
		)
	)

	static follow_func := ObjBindMethod(this, "follow_window")
	static heartbeat_func := ObjBindMethod(this, "send_heartbeat")

	static init() {
		if (A_Args.Length > 0)
			this.master_pid := A_Args[1]

		win := Roblox.Get()

		this.gui_obj := Gui("-Caption +E0x80000 +E0x20 +AlwaysOnTop +ToolWindow +OwnDialogs", "Key Alignment")
		if (IsObject(win) && win.is_ok) {
			x_pos := win.x + win.w - this.width
			y_pos := win.y
		} else {
			x_pos := 0
			y_pos := 0
		}
		this.gui_obj.Show("NA x" x_pos " y" y_pos)

		this.hbm := CreateDIBSection(this.width, this.height)
		this.hdc := CreateCompatibleDC()
		this.obm := SelectObject(this.hdc, this.hbm)
		this.G := Gdip_GraphicsFromHDC(this.hdc)
		Gdip_SetSmoothingMode(this.G, 4)

		this.init_brushes()
		this.draw()

		if (this.master_pid)
			SetTimer(this.heartbeat_func, 2000)

		IPC.init(ObjBindMethod(this, "handle_command"))
		this.startup_timer := ObjBindMethod(this, "request_startup_settings")
		SetTimer(this.startup_timer, 250)
		this.request_startup_settings()
		SetTimer(this.follow_func, 50)
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
					this.current_state := "running"
				case "stopped", "stop":
					this.current_state := "stopped"
				case "paused":
					this.current_state := "paused"
				case "toggle":
					this.current_state := (this.current_state == "running") ? "stopped" : "running"
			}

			this.draw()
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
			this.refresh_hotkeys()
			this.draw()

			ready_payload := Map(
				"action", "module_ready"
				, "script", this.my_path
			)
			try SetTimer(() => IPC.send_message("ahk_pid " this.master_pid, 1, ready_payload), -1)
			return
		}

		if (action == "update_setting") {
			section := data["section"]
			key := data["key"]
			val := data["value"]

			if (!this.settings.Has(section) || !this.settings[section].Has(key))
				return

			this.settings[section][key] := val

			if (key == "alignment_key" || key == "rebind_hotkey" || key == "key_alignment_enabled" || key == "show_overlay") {
				this.refresh_hotkeys()
				this.draw()
				this.follow_window()
			}
			return
		}

		if (action == "exit") {
			this.cleanup()
			ExitApp()
		}
	}

	static refresh_hotkeys() {
		if (this.old_rebind_key != "")
			try Hotkey(this.old_rebind_key, "Off")

		if (this.old_action_key != "") {
			HotIf (*) => key_alignment.should_intercept()
			try Hotkey("$" this.old_action_key, "Off")
			HotIf
		}

		try {
			Hotkey(this.settings["key_alignment"]["rebind_hotkey"], (*) => this.start_rebind(), "On")
			this.old_rebind_key := this.settings["key_alignment"]["rebind_hotkey"]
		}

		HotIf (*) => key_alignment.should_intercept()
		try {
			Hotkey("$" this.settings["key_alignment"]["alignment_key"], (*) => this.perform_action(), "On")
			this.old_action_key := this.settings["key_alignment"]["alignment_key"]
		}
		HotIf
	}

	static register_action_hotkey(toggle_state) {
		try {
			if (toggle_state) {
				HotIf (*) => key_alignment.should_intercept()
				Hotkey("$" this.settings["key_alignment"]["alignment_key"], (*) => this.perform_action(), "On")
				this.old_action_key := this.settings["key_alignment"]["alignment_key"]
			} else {
				Hotkey("$" this.settings["key_alignment"]["alignment_key"], "Off")
			}
			HotIf
		}
	}

	static perform_action() {
		if (this.is_rebinding || this.is_action_running || !WinActive("Roblox ahk_exe RobloxPlayerBeta.exe"))
			return

		this.is_action_running := true
		was_right_click := GetKeyState("RButton", "P")

		if (was_right_click)
			Click("Up Right")

		Send("{" this.settings["key_alignment"]["rot_right"] "}")
		Sleep(6)
		Send("{" this.settings["key_alignment"]["rot_left"] "}")

		if (was_right_click)
			Click("Down Right")

		this.is_action_running := false
	}

	static start_rebind() {
		if (this.current_state == "running" || this.is_rebinding)
			return

		this.is_rebinding := true
		this.draw("Rebinding...")
		this.register_action_hotkey(false)

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
			if (StrLen(final_key) == 1)
				final_key := StrLower(final_key)

			final_key := mods . final_key
			base_key := RegExReplace(final_key, "[\^\+!\#]", "")
			blacklist := "|LButton|RButton|Enter|Space|Tab|Backspace|Escape|"

			if (InStr(blacklist, "|" base_key "|"))
				final_key := ""
		}

		if (final_key != "") {
			this.settings["key_alignment"]["alignment_key"] := final_key
			this.save_setting_to_master("key_alignment", "alignment_key", final_key)

			payload := Map("action", "update_setting", "section", "key_alignment", "key", "alignment_key", "value", final_key)
			IPC.send_message("ahk_pid " this.master_pid, 1, payload)
		}

		this.is_rebinding := false
		this.register_action_hotkey(true)
		this.draw()
	}

	static save_setting_to_master(section, key, val) {
		payload := Map(
			"action", "save_setting",
			"section", section,
			"key", key,
			"value", val
		)
		IPC.send_message("ahk_pid " this.master_pid, 1, payload)
	}

	static start() {
		if (this.current_state == "running")
			return
		this.current_state := "running"
		this.draw()
	}

	static stop() {
		if (this.current_state == "stopped")
			return
		this.current_state := "stopped"
		this.draw()
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
			is_enabled := this.settings["main"]["key_alignment_enabled"]
			show_overlay := this.settings["key_alignment"].Has("show_overlay") ? this.settings["key_alignment"]["show_overlay"] : 1

			if (!is_enabled || !show_overlay) {
				this.gui_obj.Hide()
				return
			}

			win := Roblox.Get()
			if (IsObject(win) && win.is_ok) {
				x_pos := win.x + win.w - this.width
				y_pos := win.y
			} else {
				x_pos := A_ScreenWidth - this.width
				y_pos := 32
			}

			this.gui_obj.Show("NA")
			UpdateLayeredWindow(this.gui_obj.hwnd, this.hdc, x_pos, y_pos, this.width, this.height)
		} catch {
			this.gui_obj.Hide()
		}
	}

	static send_heartbeat() {
		payload := Map("action", "heartbeat", "script", this.my_path)
		IPC.send_message("ahk_pid " this.master_pid, 2, payload)
	}

	static should_intercept() {
		if (this.is_rebinding || this.current_state != "running")
			return false
		return (this.current_state == "running" && this.settings["main"]["key_alignment_enabled"])
	}

	static draw(text := "") {
		Gdip_GraphicsClear(this.G)

		c_accent := this.is_rebinding ? this.color_rebind : (this.current_state == "running") ? this.color_active : this.color_inactive

		Gdip_FillRoundedRectangle(this.G, this.brush, 0, 0, this.width, this.height, 5)
		c_ind := Gdip_BrushCreateSolid(c_accent)
		Gdip_FillRoundedRectangle(this.G, c_ind, 5, 5, 5, 20, 2)
		Gdip_DeleteBrush(c_ind)

		disp_text := (text != "" ? text : "Align Key: " this.settings["key_alignment"]["alignment_key"])
		options := "x15 y6 w" (this.width - 20) " h" this.height " Left c" Format("{:08X}", this.color_text) " s11 Bold"
		Gdip_TextToGraphics(this.G, disp_text, options, "Segoe UI")

		UpdateLayeredWindow(this.gui_obj.hwnd, this.hdc)
	}

	static init_brushes() {
		if (this.brush)
			return
		this.brush := Gdip_BrushCreateSolid(this.color_bg)
	}

	static dispose_brushes() {
		if (this.brush)
			Gdip_DeleteBrush(this.brush)
		this.brush := 0
	}
}

key_alignment.init()