class ScannerEngine {
	is_running := false
	Detector := unset

	Data := Map()
	BuffStates := Map()
	PercentBuffers := Map()
	GummyStar := { slot: -1, pity: 0, lastUse: 0 }

	Profiles := Map(
		"scorch", { type: "passive", x1: 0, x2: 0, y1: 11, y2: 16, var: 30 }
		, "x-flame", { type: "passive", x1: 0, x2: 0, y1: 9, y2: 18, var: 30 }
		, "popstar", { type: "passive", x1: 0, x2: 0, y1: 7, y2: 19, var: 30 }
		, "gummymorph", { type: "passive", x1: 0, x2: 0, y1: 7, y2: 14, var: 30 }
		, "shower", { type: "passive", x1: 0, x2: 0, y1: 0, y2: 0, var: 30 }
		, "combo", { type: "passive", x1: 0, x2: 0, y1: 0, y2: 0, var: 30 }
		, "gummyballer", { type: "buff", x1: 0, x2: 0, y1: 0, y2: 0, var: 30 }
		, "supersmoothie", { type: "percent_buff", img: "smoothie", xOff: -5, colors: [0xffFEC650] }
		, "precise", { type: "percent_buff", img: "Precise", xOff: 4, colors: [0xff8F4EB4, 0xff774296, 0xff3E274C, 0xff211A24, 0xff201A24, 0xff221A26, 0xff55316A, 0xff8448A6] }
		, "combo_buff", { type: "percent_buff", img: "combo_buff", xOff: -3, colors: [0xff88633E, 0xff854C30, 0xffAE2317, 0xffAE2216, 0xff9D3321, 0xff835535, 0xff86613D] }
		, "gummystar", { type: "custom_bottom", method: "detect_gumdrops", x1: 0, x2: 0, y1: 6, y2: 17, var: 30 }
		, "glitter", { type: "custom_top", method: "detect_glitter" }
		, "bloom_red", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFFC9191 }
		, "bloom_blue", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF90A1FC }
		, "bloom_white", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFFCFCFC }
		, "bloom_scarlet", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFD58989 }
		, "bloom_cyan", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF8EE2EF }
		, "bloom_grey", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFBFBFBF }
		, "bloom_black", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF858585 }
		, "bloom_yellow", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFF7E6A7 }
		, "bloom_green", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFF91F482 }
		, "bloom_pink", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFFFC1E4 }
		, "bloom_violet", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFAF93D8 }
		, "bloom_merigold", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFECD48E }
		, "bloom_periwinkle", { type: "bloom", x1: 0, x2: 0, y1: 10, y2: 14, var: 21, col: 0xFFCBCEF6 }
	)

	__New() {
		this.Detector := Detection()

		for name in this.Profiles {
			this.Data[name] := (this.Profiles[name].type == "percent_buff") ? 0.0 : 0
		}
	}

	toggle(force_state := -1) {
		if (force_state != -1) {
			this.is_running := force_state
		} else {
			this.is_running ^= 1
		}

		if (this.is_running) {
			SetTimer(ObjBindMethod(this, "main_loop"), 100)
			return
		}
		SetTimer(ObjBindMethod(this, "main_loop"), 0)
	}

	main_loop(*) {
		if (!this.is_running) {
			return
		}

		win := Roblox.Get()
		if (!IsObject(win) || !win.ok) {
			return
		}

		bm_top := Gdip_BitmapFromScreen(win.x "|" win.y + win.offsetY + 48 "|" win.w "|32")
		bm_top_percent := Gdip_BitmapFromScreen(win.x "|" win.y + win.offsetY + 32 "|" win.w "|42")
		bm_bottom := Gdip_BitmapFromScreen(win.x + (win.w // 2) - 257 "|" win.y + win.h - 142 "|517|36")
		bm_hotbar := Gdip_BitmapFromScreen(win.x + (win.w // 2) - 261 "|" win.y + win.h - 102 "|517|68")

		if (!bm_top || !bm_top_percent || !bm_bottom || !bm_hotbar) {
			if (bm_top)
				Gdip_DisposeImage(bm_top)
			if (bm_top_percent)
				Gdip_DisposeImage(bm_top_percent)
			if (bm_bottom)
				Gdip_DisposeImage(bm_bottom)
			if (bm_hotbar)
				Gdip_DisposeImage(bm_hotbar)
			return
		}

		for name, profile in this.profiles {
			old_val := this.data.Has(name) ? this.data[name] : 0
			new_val := 0

			try {
				if (profile.type == "passive") {
					new_val := this.scan_passive(bm_bottom, name, profile)
				} else if (profile.type == "buff") {
					new_val := this.scan_buff(bm_top, name, profile)
				} else if (profile.type == "percent_buff") {
					new_val := this.scan_percent_buff(bm_top_percent, name, profile)
				} else if (profile.type == "custom") {
					method := profile.method
					new_val := this.%method%(bm_bottom, bm_hotbar)
				} else if (profile.type == "custom_top") {
					method := profile.method
					new_val := this.%method%(bm_top)
				}
			} catch {
				continue
			}

			if (new_val != old_val) {
				this.data[name] := new_val
			}
		}

		Gdip_DisposeImage(bm_top)
		Gdip_DisposeImage(bm_top_percent)
		Gdip_DisposeImage(bm_bottom)
		Gdip_DisposeImage(bm_hotbar)
	}

	scan_passive(pBitmap, name, profile) {
		icon := this.Detector.SearchIcon(pBitmap, bitmaps["buff"][name], profile.x1, profile.y1, profile.x2, profile.y2, profile.var)
		if (!icon.found)
			return -1

		slotX := Floor(icon.x // 40)
		return this.Detector.ReadDigits(pBitmap, slotX * 40, 22, (slotX * 40) + 34, 33, "passive")
	}

	scan_buff(pBitmap, name, profile) {
		if !this.BuffStates.Has(name)
			this.BuffStates[name] := { val: 0, fail: 0 }

		icon := this.Detector.SearchIcon(pBitmap, bitmaps["buff"][name], profile.x1, profile.y1, profile.x2, profile.y2, profile.var)
		if (!icon.found) {
			this.BuffStates[name].val := 0
			this.BuffStates[name].fail := 0
			return -1
		}
		val := this.Detector.ReadDigits(pBitmap, icon.x - 5, 0, icon.x + 38, 32, "auto", name)
		if (val > 1) {
			this.BuffStates[name].val := val
			this.BuffStates[name].fail := 0
		} else {
			if (++this.BuffStates[name].fail < 10)
				val := this.BuffStates[name].val
			else
				this.BuffStates[name].val := 0
		}
		return (val > 0) ? val : -1
	}

	scan_percent_buff(pBitmap, name, profile) {
		imgName := profile.HasProp("img") ? profile.img : name
		if !this.PercentBuffers.Has(name)
			this.PercentBuffers[name] := []

		icon := this.Detector.SearchIcon(pBitmap, bitmaps["buff"][imgName], 0, 0, 0, 0, 4)
		if (!icon.found) {
			this.PercentBuffers[name] := []
			return -1
		}
		lowY := this.Detector.ReadPercentageFill(pBitmap, icon.x + profile.xOff, 0, icon.y, profile.colors, 0)
		raw := Round((icon.y - lowY) / 38 * 100, 2) + 2
		this.PercentBuffers[name].Push(raw)
		if (this.PercentBuffers[name].Length > 6)
			this.PercentBuffers[name].RemoveAt(1)
		best := []
		for val1 in this.PercentBuffers[name] {
			current := []
			for val2 in this.PercentBuffers[name]
				if (Abs(val1 - val2) <= 5)
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

	detect_gumdrops(pBMBottom, pBMHotbar) {
		if (this.scan_passive(pBMBottom, "gummystar-1", this.profiles["gummystar"]) == -1 || this.scan_passive(pBMBottom, "gummystar-2", this.profiles["gummystar"]) == -1) {
			this.gummyStar.pity := 0
			return -1
		}

		if (this.gummyStar.slot == -1) {
			if (Gdip_ImageSearch(pBMHotbar, bitmaps["buff"]["gumdrop-1"], &loc, , , , , 5) == 1 || Gdip_ImageSearch(pBMHotbar, bitmaps["buff"]["gumdrop-2"], &loc, , , , , 5) == 1) {
				foundX := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				this.gummyStar.slot := Floor(foundX / 75)
			} else
				return this.gummyStar.pity
		}

		xOff := this.gummyStar.slot * 75
		xSize := xOff + 5
		yOff := 15
		ySize := yOff + 38
		if (Gdip_ImageSearch(pBMHotbar, bitmaps["buff"]["unused_slot"], &loc, xOff, yOff, xSize, ySize, 5) == 0) {
			if A_TickCount - this.gummyStar.lastUse >= 2015 {
				this.gummyStar.pity++
				this.gummyStar.lastUse := A_TickCount
			}
			if (this.gummyStar.pity >= 75)
				this.gummyStar.pity := 0
		}
		return this.gummyStar.pity
	}

	scan_bloom(pBitmap, name, profile) {
		icon := this.Detector.SearchIcon(pBitmap, bitmaps["buff"][name], profile.x1, profile.y1, profile.x2, profile.y2, profile.var)
		if (!icon.found)
			return -1
		slotX := Floor(icon.x / 38) * 38
		scanX := slotX + 6

		if !this.PercentBuffers.Has(name)
			this.PercentBuffers[name] := { val: 0, fail: 0 }
		state := this.PercentBuffers[name]

		if !this.Detector._IsColorMatch(Gdip_GetPixel(pBitmap, scanX, 37), profile.col, 100) {
			if (++state.fail < 15)
				return state.val
			return 0
		}
		state.fail := 0
		lowY := this.Detector.ReadPercentageFill(pBitmap, scanX, 0, 35, profile.col, 100)
		state.val := Round((36 - lowY) / 36, 2)
		return state.val
	}
}