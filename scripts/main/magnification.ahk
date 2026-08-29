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
#Include "..\..\lib\utils\JSON.ahk"
#Include "..\..\lib\utils\utility.ahk"

if !(pToken := Gdip_Startup())
	throw Error("GDI+ failed to start, exiting script.")

(bitmaps := Map()).CaseSense := false
#Include "..\..\assets\bitmaps\Offset.ahk"


TraySetIcon "Assets\Images\Kairos.ico"


class magnification {
	static master_pid := ""
	static my_path := "scripts\main\magnification.ahk"
	static startup_timer := 0
	static is_running := false
	static width := 594
	static height := 36
	static hdc_screen := 0
	static hdc_gui := 0
	static src := { x: 0, y: 0, w: 0, h: 0 }
	static gui_obj := ""

	static settings := Map(
		"main", Map(
			"magnifier_enabled", 1
			, "boost_bar_enabled", 1
			, "show_when_active", 1
		)
		, "magnifier", Map(
			"zoom_factor", 1.3
			, "target_offset", -300
			, "offset_x", 260
			, "offset_y", 230
			, "fps", 30
		)
	)

	static update_func := ObjBindMethod(this, "update")

	static init() {
		if (A_Args.Length > 0)
			this.master_pid := A_Args[1]

		this.gui_obj := Gui("-Caption +E0x20 +AlwaysOnTop +ToolWindow +OwnDialogs ", "Magnifying Glass")
		this.gui_obj.BackColor := "Black"
		if (this.master_pid)
			SetTimer(ObjBindMethod(this, "send_heartbeat"), 2000)
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
				return
			}

			if (this.settings[section].Has(key)) {
				this.settings[section][key] := val

				if (key == "magnifier_enabled") {
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
		if (this.is_running)
			return
		Roblox.GetYOffset()
		Roblox.StartTracker(50)
		this.is_running := true
		this.gui_obj.Show("NA")
		this.hdc_screen := DllCall("GetDC", "Ptr", 0, "Ptr")
		this.hdc_gui := DllCall("GetDC", "Ptr", this.gui_obj.hwnd, "Ptr")
		DllCall("SetStretchBltMode", "Ptr", this.hdc_gui, "Int", 4)
		SetTimer(this.update_func, 1000 // this.settings["magnifier"]["fps"])
	}

	static stop() {
		if (!this.is_running)
			return
		this.is_running := false
		SetTimer(this.update_func, 0)
		if (this.hdc_screen)
			DllCall("ReleaseDC", "Ptr", 0, "Ptr", this.hdc_screen)
		if (this.hdc_gui)
			DllCall("ReleaseDC", "Ptr", this.gui_obj.hwnd, "Ptr", this.hdc_gui)
		this.hdc_screen := 0
		this.hdc_gui := 0
		this.gui_obj.Hide()
	}

	static cleanup() {
		this.stop()
		this.gui_obj.Destroy()
	}

	static follow_window() {
		try {
			win := Roblox.Get()
			if (IsObject(win) && win.ok) {
				this.src.x := win.x + (win.w // 2) + this.settings["magnifier"]["target_offset"]
				this.src.y := win.y + win.offsetY
				this.src.w := this.width
				this.src.h := this.height

				gui_w := Floor(this.width * this.settings["magnifier"]["zoom_factor"])
				gui_h := Floor(this.height * this.settings["magnifier"]["zoom_factor"])
				target_x := win.x + (win.w // 2) - (gui_w // 2)
				target_y := win.y + win.h + win.offsetY - this.settings["magnifier"]["offset_y"]

				if (this.is_running && this.settings["main"]["magnifier_enabled"]) {
					this.gui_obj.Show("NA x" target_x " y" target_y " w" gui_w " h" gui_h)
				} else {
					this.gui_obj.Hide()
				}
			} else {
				this.gui_obj.Hide()
			}
		}
	}

	static send_heartbeat() {
		payload := Map("action", "heartbeat", "script", this.my_path)
		IPC.send_message("ahk_pid " this.master_pid, 2, payload)
	}

	static update() {
		if (!this.hdc_gui || !this.hdc_screen)
			return
		DllCall("gdi32\StretchBlt"
			, "Ptr", this.hdc_gui
			, "Int", 0
			, "Int", 0
			, "Int", this.src.w * this.settings["magnifier"]["zoom_factor"]
			, "Int", this.src.h * this.settings["magnifier"]["zoom_factor"]
			, "Ptr", this.hdc_screen
			, "Int", this.src.x
			, "Int", this.src.y
			, "Int", this.src.w
			, "Int", this.src.h
			, "UInt", 0x00CC0020)
	}
}

magnification.init()