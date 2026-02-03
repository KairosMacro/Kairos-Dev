class PassiveScanner {
	IsRunning := false
	IsActive := false
	numOffset := Map(0, 7, 1, 2, 2, 6, 3, 6, 4, 7, 5, 6, 6, 7, 7, 7, 8, 7, 9, 7)

	modes := Map(
		"Scorch", { x1: 0, x2: 0, y1: 18, y2: 21, var: 16 }
		, "x-flame1", { x1: 0, x2: 0, y1: 12, y2: 19, var: 13 }
		, "x-flame2", { x1: 0, x2: 0, y1: 12, y2: 19, var: 13 }
		, "bloom_red",        { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFFF92222}
		, "bloom_blue",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF2142F9}
		, "bloom_white",      { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFFF9F9F9}
		, "bloom_scarlet",    { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFFAB1313}
		, "bloom_cyan",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF1DC4DE}
		, "bloom_grey",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF7F7F7F}
		, "bloom_black",      { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF0B0B0B}
		, "bloom_yellow",     { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFFEECC4F}
		, "bloom_green",      { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF23E805}
		, "bloom_pink",       { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFFFF82C9}
		, "bloom_violet",     { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF5E26B1}
		, "bloom_merigold",   { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFFDAA81C}
		, "bloom_periwinkle", { x1: 0, x2: 0, y1: 10, y2: 14, var: 19, col: 0xFF969CEC}
	)

	__New() {
		this.Fancy := GdipTooltip()
	}

	Toggle() {
		this.IsRunning ^= 1
		this.IsActive := this.IsRunning && Config.Get("Main", "PassiveScannerEnabled", 0)
		SetTimer(() => this.CheckLoop(), this.IsActive ? 100 : 0)
		SetTimer(() => this.Fancy.Hide(), this.IsActive ? 0 : -100)
	}

	Cleanup(*) {
		this.IsRunning := false
		SetTimer(() => this.CheckLoop(), 0)
	}

	CheckLoop() {
		if !this.IsRunning || !GetRobloxClientPos()
			return

		passiveNames := StrSplit(Config.Get("PassiveScanner", "Passives", "Scorch"), "|")
		msg := []
		for i in passiveNames {
			val := 0
			if i = "x-flame" {
				a := this.DetectPassive("x-flame1")
				b := this.DetectPassive("x-flame2")
				if (a = -1 && b = -1)
					val := -1
				else {
					val := (a = -1 ? 0 : a) + (b = -1 ? 0 : b)
				}
			} else {
				val := this.DetectPassive(i)
			}
			msg.Push([bitmaps["icon"][i], (val = -1 ? ": CD" : ": " val)])
		}

		for i in ["red", "blue", "white", "scarlet", "cyan", "grey", "black", "yellow", "green", "pink", "violet", "merigold", "periwinkle"] {
			bloomVal := this.DetectBlooms("bloom_" i)
			msg.Push([bitmaps["buff"]["bloom_" i], (bloomVal = -1 ? ": CD" : ": " bloomVal)])
		}


		this.Fancy.Show(msg)
		return
	}

	DetectPassive(name) {
		try {
			mode := this.modes[name]
			pBMScreen := Gdip_BitmapFromScreen(windowX + (windowWidth // 2) - 257 "|" windowY + windowHeight - 142 "|517|36")
			if (Gdip_ImageSearch(pBMScreen, bitmaps["buff"][name], &loc, mode.x1, mode.y1, mode.x2, mode.y2, mode.var) != 1)
				return -1
			foundX := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
			return this.DetectNumber(pBMScreen, Floor(foundX / 40))
		} finally
			Gdip_DisposeImage(pBMScreen)
	}

	DetectBlooms(name) {
		try {
			mode := this.modes[name]
			pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY + State.offsetY + 36 "|" windowWidth "|" 38)
			if (Gdip_ImageSearch(pBMScreen, bitmaps["buff"][name], &loc, mode.x1, mode.y1, mode.x2, mode.y2, mode.var) != 1)
				return -1
			foundX := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
			slotX := Floor(foundX / 38) * 38
			; verify that it's an actual bloom by doing the "percentage" stuff,
			return this.MeasureBuff(pBMScreen, slotX, mode.col)
		} finally
			Gdip_DisposeImage(pBMScreen)
	}

	MeasureBuff(pBitmap, slotX, color) {
		static fail := 0
		static last := 0

		inRange(pixel, color) {
			r := (pixel >> 16) & 0xFF
			g := (pixel >> 8) & 0xFF
			b := pixel & 0xFF

			cr := (color >> 16) & 0xFF
			cg := (color >> 8) & 0xFF
			cb := color & 0xFF

			tolerance := 100

			return (Abs(r - cr) <= tolerance) && (Abs(g - cg) <= tolerance) && (Abs(b - cb) <= tolerance)
		}

		scanX := slotX + 6
		if !inRange(Gdip_GetPixel(pBitmap, scanX, 37), color) {
			if (++fail < 10)
				return last
			return 0
		}

		fail := 0
		low := 0, high := 35
		while (low < high) {
			mid := Floor((low + high) / 2)
			if inRange(Gdip_GetPixel(pBitmap, scanX, mid), color)
				high := mid
			else
				low := mid + 1
		}
		return Round((36 - low) / 36, 2)
	}

	DetectNumber(pBitmap, slot) {
		searchX := slot * 40
		searchY := 22
		searchW := 34
		searchH := 11

		found := []

		loop 10 {
			idx := 10 - A_Index

			if (Gdip_ImageSearch(pBitmap, bitmaps["buff"][idx], &loc1, searchX, searchY, searchX + searchW, searchY + searchH, 6) = 1) {
				mX := SubStr(loc1, 1, InStr(loc1, ",") - 1)
				currentWidth := this.numOffset[idx]

				isOverlap := false
				for item in found {
					if (mX >= item.x && mX < item.x + item.w - 1) {
						isOverlap := true
						break
					}
					if (item.x >= mX && item.x < (mX + currentWidth - 1)) {
						isOverlap := true
						break
					}
				}
				if (!isOverlap) {
					found.Push({ num: idx, x: Integer(mX), w: currentWidth })
					if (Gdip_ImageSearch(pBitmap, bitmaps["buff"][idx], &loc2, mX + currentWidth - 1, searchY, searchX + searchW, searchY + searchH, 6) = 1) {
						mX2 := SubStr(loc2, 1, InStr(loc2, ",") - 1)
						found.Push({ num: idx, x: Integer(mX2), w: currentWidth })
					}
				}
			}
		}

		if (found.Length = 0) {
			return 0
		} else if (found.Length = 1) {
			return found[1].num
		} else {
			if (found[1].x < found[2].x) {
				return found[1].num . found[2].num
			} else {
				return found[2].num . found[1].num
			}
		}
	}
}
