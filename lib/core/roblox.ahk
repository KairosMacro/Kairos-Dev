/***********************************************************
 * @description: Functions for automating the Roblox window
 * @author SP (Merged & Refactored), FenixJK (WindowTracker)
 ***********************************************************/
class Roblox {
	static state := { hwnd: 0, x: 0, y: 0, w: 0, h:0 , offsetY: 0, ok: false, ts: 0 }
	static interval := 50

	static StartTracker(intervalMs := 50) {
		this.interval := intervalMs
		this.Update()
		SetTimer(ObjBindMethod(this, "Update"), intervalMs)
	}

	static StopTracker() {
		SetTimer(ObjBindMethod(this, "Update"), 0)
	}

	static Get() {
		return this.state
	}

	static Update(*) {
		hwnd := this.GetHWND()
		if !hwnd {
			this.state := { hwnd: 0, x: 0, y: 0, w: 0, h: 0, offsetY: this.state.offsetY, ok: false, ts: A_TickCount }
			return
		}
		this.state.hwnd := hwnd
		this.state.ok := this.GetClientPos(hwnd)
		this.state.ts := A_TickCount
	}

	static GetHWND() {
		if (hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe"))
			return hwnd
		else if (WinExist("Roblox ahk_exe ApplicationFrameHost.exe")) {
			try return ControlGetHwnd("ApplicationFrameInputSinkWindow1")
			catch TargetError
				return 0
		}
		return 0
	}

	static GetClientPos(hwnd?) {
		if !IsSet(hwnd)
			hwnd := this.GetHWND()
		try {
			WinGetClientPos(&x, &y, &w, &h, "ahk_id " hwnd)
			this.state.x := x
			this.state.y := y
			this.state.w := w
			this.state.h := h
			return 1
		} catch TargetError {
			this.state.x := 0, this.state.y := 0, this.state.w := 0, this.state.h := 0
			return 0
		}
	}

	static GetYOffset(hwnd?, &fail?, noFocus?) {
		static hRoblox := 0

		if !IsSet(hwnd)
			hwnd := this.GetHWND()
		if IsSet(fail)
			fail := 0

		if (hwnd && hwnd = hRoblox && this.state.offsetY != 0) {
			fail := 0
			return this.state.offsetY
		} else if WinExist("ahk_id " hwnd) {
			if !IsSet(noFocus)
				this.Activate()
			this.GetClientPos(hwnd)
			pBMScreen := Gdip_BitmapFromScreen(this.state.x + this.state.w // 2 "|" this.state.y "|60|100")
			loop 20 {
				if ((Gdip_ImageSearch(pBMScreen, bitmaps["toppollen"], &pos, , , , , 5) = 1) && (Gdip_ImageSearch(pBMScreen, bitmaps["toppollenfill"], , x := SubStr(pos, 1, (comma := InStr(pos, ",")) - 1), y := SubStr(pos, comma + 1), x + 41, y + 10, 5) = 0)) {
					Gdip_DisposeImage(pBMScreen)
					hRoblox := hwnd
					fail := 0
					this.state.offsetY := y - 14
					return this.state.offsetY
				} else {
					if (A_Index = 20) {
						Gdip_DisposeImage(pBMScreen)
						fail := 1
						return 0
					} else {
						sleep 50
						Gdip_DisposeImage(pBMScreen)
						pBMScreen := Gdip_BitmapFromScreen(this.state.x + this.state.w // 2 "|" this.state.y "|60|100")
					}
				}
			}
		}
		return 0
	}

	static Activate() {
		try {
			WinActivate "ahk_exe RobloxPlayerBeta.exe"
			return 1
		} catch
			return 0
	}

	static Close() {
		if (this.GetHWND()) {
			this.Activate()
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
	}

	static Join(placeID, jobID := "") {

	}
}
