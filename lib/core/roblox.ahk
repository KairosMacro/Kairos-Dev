/***********************************************************
 * @description: Functions for automating the Roblox window
 * @author SP (Merged & Refactored), FenixJK (WindowTracker)
 ***********************************************************/
class roblox {
	static state := { hwnd: 0, x: 0, y: 0, w: 0, h: 0, y_offset: 0, is_ok: false, ts: 0 }
	static interval := 50
	static is_tracking := false

	static start_tracker(interval := 50) {
		this.interval := interval
		this.update()
		SetTimer(ObjBindMethod(this, "update"), interval)
	}

	static stop_tracker() {
		this.is_tracking := false
		SetTimer(ObjBindMethod(this, "update"), 0)
	}

	static get() {
		return this.state
	}

	static update(*) {
		hwnd := this.get_hwnd()
		if (!hwnd) {
			this.state := { hwnd: 0, x: 0, y: 0, w: 0, h: 0, y_offset: 0, is_ok: false, ts: A_TickCount }
			return
		}

		if (this.state.hwnd != hwnd) {
			this.state.hwnd := hwnd
			this.state.y_offset := 0
		}

		this.state.is_ok := this.get_client_pos(hwnd)
		this.state.ts := A_TickCount

		if (this.state.is_ok && this.state.y_offset == 0) {
			this.get_y_offset(hwnd, , true)
		}
	}

	static get_hwnd() {
		if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
			return hwnd
		else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe")) {
			try return ControlGetHwnd("ApplicationFrameInputSinkWindow1")
			catch TargetError
				return 0
		}
		return 0
	}

	static get_client_pos(hwnd?) {
		if (!IsSet(hwnd))
			hwnd := this.get_hwnd()

		try {
			WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
			this.state.x := x
			this.state.y := y
			this.state.w := w
			this.state.h := h
			return true
		} catch TargetError {
			this.state.x := 0, this.state.y := 0, this.state.w := 0, this.state.h := 0
			return false
		}
	}

	static get_y_offset(hwnd?, &has_failed?, should_not_focus?) {
		if (!IsSet(hwnd))
			hwnd := this.get_hwnd()

		if (IsSet(has_failed)) {
			has_failed := false
		}

		if (hwnd && hwnd == this.state.hwnd && this.state.y_offset != 0)
			return this.state.y_offset

		if (!WinExist("ahk_id " hwnd)) {
			if (IsSet(has_failed))
				has_failed := true
			return 0
		}

		if (!IsSet(should_not_focus) || !should_not_focus)
			this.activate()

		this.get_client_pos(hwnd)
		scan_region := (this.state.x + (this.state.w // 2)) "|" this.state.y "|60|100"

		loop 20 {
			pBMScreen := Gdip_BitmapFromScreen(scan_region)
			if (!pBMScreen)
				continue

			has_top := Gdip_ImageSearch(pBMScreen, bitmaps["toppollen"], &pos, , , , , 5)
			if (has_top == 1) {
				idx := InStr(pos, ",")
				x_pos := Integer(SubStr(pos, 1, idx - 1))
				y_pos := Integer(SubStr(pos, idx + 1))

				has_fill := Gdip_ImageSearch(pBMScreen, bitmaps["toppollenfill"], , x_pos, y_pos, x_pos + 41, y_pos + 10, 5)
				if (has_fill == 0) {
					Gdip_DisposeImage(pBMScreen)
					this.state.y_offset := y_pos - 14
					return this.state.y_offset
				}
			}

			Gdip_DisposeImage(pBMScreen)

			if (A_Index == 20) {
				if (IsSet(has_failed)) {
					has_failed := true
				}
				return 0
			}
			Sleep(50)
		}
		return 0
	}

	static activate() {
		try {
			WinActivate "ahk_exe RobloxPlayerBeta.exe"
			return 1
		} catch
			return 0
	}

	static close() {
		hwnd := this.get_hwnd()
		if (!hwnd)
			return

		this.activate()
		PrevKeyDelay := A_KeyDelay
		SetKeyDelay 250 + PrevKeyDelay
		send "{" SC_Esc "}{" SC_L "}{" SC_Enter "}"
		SetKeyDelay PrevKeyDelay

		try WinClose "Roblox"
		sleep 500
		try WinClose "Roblox"
		sleep 4500

		; add filter to just the current user (this closes ALL if admin)
		for p in ComObjGet("winmgmts:").ExecQuery("SELECT * FROM Win32_Process WHERE Name LIKE '%Roblox%' OR CommandLine LIKE '%ROBLOXCORPORATION%' OR Name LIKE '%Bloxstrap%' OR Name LIKE '%Voidstrap%' Or Name LIKE '%Fishstrap%' Or Name LIKE '%FrostStrap%'")
			ProcessClose p.ProcessID
	}

	static join(placeID, jobID := "") {
		; (+) Might wanna work on this !!!!
	}
}