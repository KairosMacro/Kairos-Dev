class Tracker {
	IsRunning := false
	IsActive := false
	bloomStates := Map()
	buffStates := Map()
	numOffset := Map(0, 7, 1, 2, 2, 6, 3, 6, 4, 7, 5, 6, 6, 7, 7, 7, 8, 7, 9, 7)
	GummyStar := {slot: -1, pity: 0, lastUse: 0}

	OffsetX := 0
	OffsetY := 0
	EditMode := false
	cooldowns := Map(
		"scorch", { last_not_found: 0, cooldown: 60000, duration: 45000 },
		"x-flame", { last_not_found: 0, cooldown: 20000, duration: 0 },
		"popstar", { last_not_found: 0, cooldown: 60000, duration: 45000 },
		"gummystar", { last_not_found: 0, cooldown: 60000, duration: 45000 },
	)


	modes := Map(
		"scorch", { type: "passive", x1: 0, x2: 0, y1: 11, y2: 16, var: 30 }
		, "x-flame", { type: "passive", x1: 0, x2: 0, y1: 9, y2: 18, var: 30 }
		, "popstar", { type: "passive", x1: 0, x2: 0, y1: 7, y2: 19, var: 30 }
		, "gummymorph", { type: "passive", x1: 0, x2: 0, y1: 7, y2: 14, var: 30 }
		
		, "gummyballer", { type: "buff", x1: 0, x2: 0, y1: 0, y2: 0, var: 30 }
		, "supersmoothie", { type: "percent_buff", img: "smoothie", xOff: -5, colors: [0xffFEC650] }

		, "gummystar", { type: "custom", x1: 0, x2: 0, y1: 7, y2: 14, var: 30, method: "DetectGumdrops" }

		, "bloom_red",        { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFFC9191}
		, "bloom_blue",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF90A1FC}
		, "bloom_white",      { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFFCFCFC}
		, "bloom_scarlet",    { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFD58989}
		, "bloom_cyan",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF8EE2EF}
		, "bloom_grey",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFBFBFBF}
		, "bloom_black",      { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF858585}
		, "bloom_yellow",     { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFF7E6A7}
		, "bloom_green",      { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF91F482}
		, "bloom_pink",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFFFC1E4}
		, "bloom_violet",     { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFAF93D8}
		, "bloom_merigold",   { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFECD48E}
		, "bloom_periwinkle", { x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFCBCEF6}
	)

	__New() {
		this.scanner := Detection()
		this.Fancy := GdipTooltip(true)
		this.RefreshConfig()
		Scheduler.Add("Tracker.CheckLoop", this.CheckLoop.Bind(this), 100, () => this.IsActive)

		OnMessage(0x0232, this.OnDragEnd.Bind(this))
	}

	Toggle(*) {
		this.IsRunning ^= 1
		this.IsActive := this.IsRunning && Config.Get("Main", "TrackerEnabled", 0)
		SetTimer(() => this.Fancy.Hide(), this.IsActive ? 0 : -100)
	}

	Cleanup(*) {
		this.IsRunning := false
	}

	CheckLoop(*) {
		if (State.IsPaused || this.EditMode)
			return

		if (this.Fancy.Zoom != Config.Get("Tracker", "Zoom", 1.0)) {
			Config.Set("Tracker", "Zoom", this.Fancy.Zoom)
			Config.WriteIni()
		}

		win := WindowTracker.Get()
		if !this.IsRunning || !IsObject(win) || !win.ok
			return

		passiveNames := this.PassiveList
		msg := []

		for i in passiveNames {
			if !this.modes.Has(i)
				continue
			mode := this.modes[i]

			val := ""
			if (mode.type = "buff") {
				val := this.DetectBuffs(i)
			} else if (mode.type = "custom") {
				val := this.%mode.method%()
			} else if (mode.type = "percent_buff") {
				raw := this.DetectPercentBuff(i)
				if (raw != -1) {
					timeVal := Round(raw * 12)
					val := Floor(timeVal / 60) ":" Format("{:02}", Mod(timeVal, 60))
				} else
					val := -1
			} else {
				val := this.DetectPassive(i)
			}

			msgSuffix := ""
			if (val = -1) {
				if this.cooldowns.Has(i) {
					cooldown := this.cooldowns[i]
					if (cooldown.last_not_found = 0)
						msgSuffix := ": N/A"
					else {
						elapse := QPC() - cooldown.last_not_found
						if (elapse <= cooldown.duration)
							msgSuffix := ": Active: " Round((cooldown.duration - (QPC() - cooldown.last_not_found)) / 1000) "s"
						else
							msgSuffix := ": CD: " Round((cooldown.cooldown - (QPC() - cooldown.last_not_found)) / 1000) "s"
					}
				} else
					msgSuffix := ": N/A"
			} else {
				if this.cooldowns.Has(i)
					this.cooldowns[i].last_not_found := QPC()
				msgSuffix := ": " val
			}
			msg.Push([bitmaps["icon"][i], msgSuffix])
		}
		this.Fancy.Show(msg, (win.x + win.w // 2) + this.OffsetX, win.y + win.h // 2 + this.OffsetY)
		return
	}

	DetectPassive(name) {
		mode := this.modes[name]
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return -1
		region := win.x + (win.w // 2) - 257 "|" win.y + win.h - 142 "|517|36"
		pBMScreen := FrameCache.Get(region)
		if !pBMScreen
			return -1
		icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][name], mode.x1, mode.y1, mode.x2, mode.y2, mode.var)
		if (!icon.found)
			return -1
		slotX := Floor(icon.x / 40)
		return this.scanner.ReadDigits(pBMScreen, slotX * 40, 22, (slotX * 40) + 34, 33, "passive")
	}

	DetectBuffs(name) {
		mode := this.modes[name]
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return -1
		
		if !this.buffStates.Has(name)
			this.buffStates[name] := {val: 0, fail: 0}
		buff := this.buffStates[name]

		region := win.x "|" win.y + State.offsetY + 48 "|" win.w "|" 32
		pBMScreen := FrameCache.Get(region)
		if !pBMScreen
			return -1

		icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][name], mode.x1, mode.y1, mode.x2, mode.y2, mode.var)
		if (!icon.found) {
			if (++buff.fail < 10)
				return buff.val
			buff.val := 0
			return 0
		}
		current := this.scanner.ReadDigit(pBMScreen, icon.x - 13, 0, icon.x + 25, 32, "auto")
		if (current > 0) {
			buff.val := current
			buff.fail := 0
		} else {
			if (++buff.fail < 10)
				current := buff.val
			else
				buff.val := 0
		}
		return current
	}

	DetectPercentBuff(name) {
		mode := this.modes[name]
		imgName := mode.HasProp("img") ? mode.img : name 
		
		static buffers := Map(), bufferSize := 6, tolerance := 5
		if !buffers.Has(name)
			buffers[name] := []
		buff := buffers[name]

		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return -1

		region := win.x "|" win.y + State.offsetY + 32 "|" win.w "|" 42
		pBMScreen := FrameCache.Get(region)
		if !pBMScreen
			return -1

		icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][imgName], 0, 0, 0, 0, 4)
		if (!icon.found) {
			buffers[name] := []
			return -1
		}

		lowY := this.scanner.ReadPercentageFill(pBMScreen, icon.x + mode.xOff, 0, icon.y, mode.colors, 0)
		raw := Round((icon.y - lowY) / 38 * 100, 2) + 2
		buff.Push(raw)
		if (buff.Length > bufferSize)
			buff.RemoveAt(1)
		best := []
		for val1 in buff {
			current := []
			for val2 in buff
				if (Abs(val1 - val2) <= tolerance)
					current.Push(val2)
			if (current.Length > best.Length)
				best := current
		}
		if (best.Length = 0)
			return raw
		sum := 0
		for val in best
			sum += val
		return Round(sum / best.Length, 2)
	}

	DetectBlooms(name) {
		mode := this.modes[name]
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return -1
		region := win.x "|" win.y + State.offsetY + 36 "|" win.w "|" 38
		pBMScreen := FrameCache.Get(region)
		if !pBMScreen
			return -1
		icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][name], mode.x1, mode.y1, mode.x2, mode.y2, mode.var)
		if (!icon.found)
			return -1
		slotX := Floor(icon.x / 38) * 38
		scanX := slotX + 6
		
		if !this.bloomStates.Has(name)
			this.bloomStates[name] := {val: 0, fail: 0}
		state := this.bloomStates[name]
		
		if !this.scanner._IsColorMatch(Gdip_GetPixel(pBMScreen, scanX, 37), mode.col, 100) {
			if (++state.fail < 15)
				return state.val
			return 0
		}
		state.fail := 0
		lowY := this.scanner.ReadPercentageFill(pBMScreen, scanX, 0, 35, mode.col, 100)
		return Round((36 - lowY) / 36, 2)
	}

	DetectGumdrops() {
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return this.GummyStar.pity
		if (this.DetectPassive("gummystar") = -1) {
			this.GummyStar.pity := 0
			return -1
		}

		region := win.x + (win.w // 2) - 261 "|" win.y + win.h - 102 "|517|68"
		pBMScreen := FrameCache.Get(region)
		if !pBMScreen
			return this.GummyStar.pity
		if (this.GummyStar.slot = -1) {
			if (Gdip_ImageSearch(pBMScreen, bitmaps["buff"]["gumdrop"], &loc, , , , , 5) = 1) {
				foundX := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				this.GummyStar.slot := Floor(foundX / 75) ; 0 is slot 1
			} else {
				return this.GummyStar.pity
			}
		}

		xOff := this.GummyStar.slot * 75
		xSize := xOff + 5
		yOff := 15
		ySize := yOff + 38
		if (Gdip_ImageSearch(pBMScreen, bitmaps["buff"]["unused_slot"], &loc, xOff, yOff, xSize, ySize, 5) = 0) {
			if A_TickCount - this.GummyStar.lastUse >= 2010 {
				this.GummyStar.pity++
				this.GummyStar.lastUse := A_TickCount
			}
			if (this.GummyStar.pity >= 75) {
				this.GummyStar.pity := 0
			}
		}
		return this.GummyStar.pity
	}

	OnDragEnd(wParam, lParam, msg, hwnd) {
		if (hwnd = this.Fancy.hwnd) {
			win := WindowTracker.Get()
			if (IsObject(win) && win.ok) {
				WinGetPos(&guiX, &guiY, , , "ahk_id " this.Fancy.hwnd)
				this.OffsetX := guiX - (win.x + win.w // 2)
				this.OffsetY := guiY - (win.y + win.h // 2)
				Config.Set("Tracker", "OffsetX", this.OffsetX)
				Config.Set("Tracker", "OffsetY", this.OffsetY)
				Config.WriteIni()
				this.Fancy._manualPos := false
			}
		}
	}

	RefreshConfig() {
		this.PassiveList := StrSplit(Config.Get("Tracker", "Passives", "scorch"), "|")
		this.OffsetX := Config.Get("Tracker", "OffsetX", 0)
		this.OffsetY := Config.Get("Tracker", "OffsetY", 0)

		this.Fancy.Zoom := Config.Get("Tracker", "Zoom", 1)
	}
}
