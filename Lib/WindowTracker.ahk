class WindowTracker {
	static state := { hwnd: 0, x: 0, y: 0, w: 0, h: 0, ok: false, ts: 0 }
	static interval := 50
	static _timerFn := 0

	static Start(intervalMs := 50) {
		this.interval := intervalMs
		this._timerFn := ObjBindMethod(this, "Update")
		this.Update()
		SetTimer(this._timerFn, intervalMs)
	}

	static Stop() {
		if this._timerFn
			SetTimer(this._timerFn, 0)
	}

	static Get() {
		return this.state
	}

	static Update(*) {
		global windowX, windowY, windowWidth, windowHeight
		hwnd := GetRobloxHWND()
		if !hwnd {
			this.state := { hwnd: 0, x: 0, y: 0, w: 0, h: 0, ok: false, ts: A_TickCount }
			return
		}
		if !GetRobloxClientPos(hwnd) {
			this.state := { hwnd: hwnd, x: 0, y: 0, w: 0, h: 0, ok: false, ts: A_TickCount }
			return
		}
		this.state := { hwnd: hwnd, x: windowX, y: windowY, w: windowWidth, h: windowHeight, ok: true, ts: A_TickCount }
	}
}
