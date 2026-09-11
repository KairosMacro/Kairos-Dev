class ScannerEngine {
	is_running := false
	detector := unset
	active_field_override := "blueflower"

	data := Map()
	buff_states := Map()
	percent_buffers := Map()
	gummy_star := { slot: -1, pity: 0, last_use: 0 }

	subscribed_profiles := Map()

	profiles := Map(
		; --- BOTTOM PASSIVES ---
		"scorch", { type: "passive", img: "scorching_star", x1: 0, x2: 0, y1: 11, y2: 16, var: 30, dir: 1 }
		, "x-flame", { type: "passive", x1: 0, x2: 0, y1: 9, y2: 18, var: 30, dir: 1 }
		, "popstar", { type: "passive", img: "pop_star", x1: 0, x2: 0, y1: 7, y2: 19, var: 30, dir: 1 }
		, "gummymorph", { type: "passive", x1: 0, x2: 0, y1: 7, y2: 14, var: 30, dir: 1 }
		, "shower", { type: "passive", x1: 0, x2: 0, y1: 0, y2: 0, var: 30, dir: 1 }
		, "combo", { type: "passive", x1: 0, x2: 0, y1: 0, y2: 0, var: 30, dir: 1 }
		, "gummystar", { type: "custom_bottom", img: "gummy_star", method: "detect_gumdrops", x1: 0, x2: 0, y1: 10, y2: 17, var: 30, dir: 1 }
		; --- BOOSTS (RED / BLUE / WHITE) ---
		, "boosts_handler", { type: "special_boosts", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 7 }
		; --- STAT BUFFS (1x - 999x) ---
		, "focus", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "bomb", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "rage", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "inspire", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "balloon_aura", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "clock", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "honey_mark", { type: "stat_buff", x1: 0, x2: 0, y1: 20, y2: 50, var: 6, dir: 6 }
		, "pollen_mark", { type: "stat_buff", x1: 0, x2: 0, y1: 20, y2: 50, var: 6, dir: 6 }
		, "precise_mark", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "reindeer_guidance", { type: "stat_buff", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "mondo", { type: "stat_buff", x1: 0, x2: 0, y1: 20, y2: 46, var: 21, dir: 6 }
		, "map_corruption", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 30, dir: 6 }
		, "cool_breeze", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "precision", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "sticker_stack", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "puffshroom_blessing", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "robo_party", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "dark_heat", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "coconut_combo", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "festive_nymph", { type: "stat_buff", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		; --- SPECIAL 1x - 999x ---
		, "haste", { type: "special_haste", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "melody", { type: "boolean", x1: 0, x2: 0, y1: 15, y2: 40, var: 12, dir: 1 }
		, "balloon_blessing", { type: "special_balloon", x1: 0, x2: 0, y1: 20, y2: 50, var: 21, dir: 6 }
		; --- SCALING (Y30 TO Y50) ---
		, "flame_heat", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "bubble_bloat", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "comforting", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "motivating", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "satisfying", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "refreshing", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "invigorating", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "tide_blessing", { type: "scaling", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		; --- BEAR MORPHS (BOOLEAN) ---
		, "bear_brown", { type: "boolean", img: "brown", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		, "bear_black", { type: "boolean", img: "black", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		, "bear_panda", { type: "boolean", img: "panda", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		, "bear_polar", { type: "boolean", img: "polar", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		, "bear_gummy", { type: "boolean", img: "gummy", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		, "bear_science", { type: "boolean", img: "science", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		, "bear_mother", { type: "boolean", img: "mother", x1: 0, x2: 0, y1: 43, y2: 45, var: 8, dir: 2 }
		; --- GENERAL ON/OFF (BOOLEAN) ---
		, "oil", { type: "boolean", x1: 0, x2: 0, y1: 43, y2: 45, var: 4, dir: 2 }
		, "super_smoothie", { type: "boolean", x1: 0, x2: 0, y1: 43, y2: 45, var: 4, dir: 2 }
		, "bomb_sync_red", { type: "boolean", x1: 0, x2: 0, y1: 37, y2: 47, var: 20, dir: 6 }
		, "bomb_sync_blue", { type: "boolean", x1: 0, x2: 0, y1: 37, y2: 47, var: 20, dir: 6 }
		, "festive_blessing", { type: "boolean", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "beesmas_cheer", { type: "boolean", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "tabby_blessing", { type: "boolean", x1: 114, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "clouds", { type: "boolean", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "baby_love", { type: "boolean", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "festive_mark", { type: "boolean", x1: 0, x2: 0, y1: 30, y2: 50, var: 6, dir: 6 }
		, "flame_fuel", { type: "boolean", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 6 }
		, "guiding_star", { type: "boolean", x1: 0, x2: 0, y1: 30, y2: 50, var: 10, dir: 6 }
		, "stinger", { type: "boolean", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "enzyme", { type: "boolean", x1: 0, x2: 0, y1: 25, y2: 47, var: 0, dir: 6 }
		, "extract_red", { type: "boolean", x1: 0, x2: 0, y1: 31, y2: 47, var: 0, dir: 6 }
		, "extract_blue", { type: "boolean", x1: 0, x2: 0, y1: 31, y2: 47, var: 0, dir: 6 }
		, "glue", { type: "boolean", x1: 0, x2: 0, y1: 31, y2: 47, var: 0, dir: 6 }
		, "tropical_drink", { type: "boolean", x1: 0, x2: 0, y1: 31, y2: 47, var: 0, dir: 6 }
		, "purple_potion", { type: "boolean", x1: 0, x2: 0, y1: 40, y2: 47, var: 0, dir: 6 }
		, "marshmallow_bee", { type: "boolean", x1: 0, x2: 0, y1: 28, y2: 47, var: 0, dir: 6 }
		, "jellybean_sharing", { type: "boolean", x1: 0, x2: 0, y1: 30, y2: 50, var: 0, dir: 7 }
		; --- NON-STANDARD PERCENT BUFFS ---
		, "precise", { type: "percent_buff", img: "precision", x_off: 4, colors: [0xff8F4EB4, 0xff774296, 0xff3E274C, 0xff211A24, 0xff201A24, 0xff221A26, 0xff55316A, 0xff8448A6] }
		, "combo_buff", { type: "percent_buff", img: "combo_buff", x_off: -3, colors: [0xff88633E, 0xff854C30, 0xffAE2317, 0xffAE2216, 0xff9D3321, 0xff835535, 0xff86613D] }
		, "gummyballer", { type: "buff", x1: 0, x2: 0, y1: 0, y2: 0, var: 30 }
		, "glitter", { type: "custom_top", method: "detect_glitter" }
	)

	__New() {
		this.detector := detection()
		for name, profile in this.profiles {
			this.data[name] := (profile.type == "percent_buff" || profile.type == "scaling") ? 0.0 : 0
		}
		this.data["boost_red"] := 0
		this.data["boost_blue"] := 0
		this.data["boost_white"] := 0
	}

	get_image(name, fallback := "") {
		if (bitmaps.Has("stat_buff") && bitmaps["stat_buff"].Has(name))
			return bitmaps["stat_buff"][name]
		if (bitmaps.Has("buff") && bitmaps["buff"].Has(name))
			return bitmaps["buff"][name]
		if (fallback != "" && bitmaps.Has("buff") && bitmaps["buff"].Has(fallback))
			return bitmaps["buff"][fallback]
		return 0
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
		if (!this.is_running)
			return

		win := roblox.get()
		if (!IsObject(win) || !win.is_ok)
			return

		bm_top := Gdip_BitmapFromScreen(win.x "|" win.y + win.y_offset + 48 "|" win.w "|32")
		bm_top_percent := Gdip_BitmapFromScreen(win.x "|" win.y + win.y_offset + 36 "|" win.w "|38")
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

		for name, profile in this.subscribed_profiles {
			old_val := this.data.Has(name) ? this.data[name] : 0
			new_val := 0

			try {
				switch profile.type {
					case "passive":
						new_val := this.scan_passive(bm_bottom, name, profile)
					case "buff":
						new_val := this.scan_buff(bm_top, name, profile)
					case "stat_buff":
						new_val := this.scan_stat_buff(bm_top, name, profile)
					case "boolean":
						new_val := this.scan_boolean(bm_top, name, profile)
					case "scaling":
						new_val := this.scan_scaling(bm_top, name, profile)
					case "special_haste":
						new_val := this.scan_haste(bm_top, profile)
					case "special_balloon":
						new_val := this.scan_balloon(bm_top, profile)
					case "special_boosts":
						new_val := this.scan_boosts(bm_top, profile, win.w)
					case "percent_buff":
						new_val := this.scan_percent_buff(bm_top_percent, name, profile)
					case "custom_bottom":
						method := profile.method
						new_val := this.%method%(bm_bottom, bm_hotbar)
					case "custom_top":
						method := profile.method
						new_val := this.%method%(bm_top_percent)
				}
			} catch {
				continue
			}

			if (new_val != -2 && new_val != old_val)
				this.data[name] := new_val
		}

		Gdip_DisposeImage(bm_top)
		Gdip_DisposeImage(bm_top_percent)
		Gdip_DisposeImage(bm_bottom)
		Gdip_DisposeImage(bm_hotbar)
	}

	scan_passive(pBitmap, name, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		img_name := profile.HasProp("img") ? profile.img : name
		bmp := this.get_image(img_name)
		if (!bmp)
			return -1

		icon := this.detector.SearchIcon(pBitmap, bmp, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)
		if (!icon.found)
			return -1

		slot_x := Floor(icon.x // 40)
		return this.detector.ReadDigits(pBitmap, slot_x * 40, 22, (slot_x * 40) + 34, 33, "passive")
	}

	scan_buff(pBitmap, name, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		img_name := profile.HasProp("img") ? profile.img : name
		bmp := this.get_image(img_name)
		if (!bmp)
			return -1

		if (!this.buff_states.Has(name))
			this.buff_states[name] := { val: 0, fail: 0 }

		icon := this.detector.SearchIcon(pBitmap, bmp, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)
		if (!icon.found) {
			this.buff_states[name].val := 0
			this.buff_states[name].fail := 0
			return -1
		}

		val := this.detector.ReadDigits(pBitmap, icon.x - 5, 0, icon.x + 38, 32, "auto", name)
		if (val > 1) {
			this.buff_states[name].val := val
			this.buff_states[name].fail := 0
		} else {
			if (++this.buff_states[name].fail < 10)
				val := this.buff_states[name].val
			else
				this.buff_states[name].val := 0
		}
		return (val > 0) ? val : -1
	}

	scan_stat_buff(pBitmap, name, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		img_name := profile.HasProp("img") ? profile.img : name
		bmp := this.get_image(img_name)
		if (!bmp)
			return 0

		icon := this.detector.SearchIcon(pBitmap, bmp, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)
		if (!icon.found)
			return 0

		return this.detector.ReadDigits(pBitmap, icon.x - 5, 0, icon.x + 38, 32, "auto", name)
	}

	scan_boolean(pBitmap, name, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		img_name := profile.HasProp("img") ? profile.img : name
		bmp := this.get_image(img_name)
		if (!bmp)
			return 0

		icon := this.detector.SearchIcon(pBitmap, bmp, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)
		return icon.found ? 1 : 0
	}

	scan_scaling(pBitmap, name, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		img_name := profile.HasProp("img") ? profile.img : name
		bmp := this.get_image(img_name)
		if (!bmp)
			return 0.0

		icon := this.detector.SearchIcon(pBitmap, bmp, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)
		if (!icon.found)
			return 0.0

		slot_x := Floor(icon.x / 38) * 38
		return this.measure_boost(pBitmap, slot_x)
	}

	scan_haste(pBitmap, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		melody_bmp := this.get_image("melody")
		haste_bmp := this.get_image("haste")

		if (!melody_bmp || !haste_bmp)
			return 0

		melody_icon := this.detector.SearchIcon(pBitmap, melody_bmp, 0, 15, 0, 40, 12, 1)
		haste_icon := this.detector.SearchIcon(pBitmap, haste_bmp, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)

		if (!haste_icon.found)
			return 0

		if (melody_icon.found && Abs(melody_icon.x - haste_icon.x) < 5)
			return 0

		return this.detector.ReadDigits(pBitmap, haste_icon.x - 5, 0, haste_icon.x + 38, 32, "auto", "haste")
	}

	scan_balloon(pBitmap, profile) {
		dir := profile.HasProp("dir") ? profile.dir : 6
		bmp_100 := this.get_image("balloon_blessing_100")
		bmp_gen := this.get_image("balloon_blessing")

		if (bmp_100 && Gdip_ImageSearch(pBitmap, bmp_100, &loc, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, , dir) = 1) {
			return 100
		}

		if (!bmp_gen)
			return 0

		icon := this.detector.SearchIcon(pBitmap, bmp_gen, profile.x1, profile.y1, profile.x2, profile.y2, profile.var, dir)
		if (!icon.found)
			return 0

		return this.detector.ReadDigits(pBitmap, icon.x + 8, 15, icon.x + 36, 46, "auto", "balloon_blessing")
	}

	scan_boosts(pBitmap, profile, win_w) {
		red := 0, blue := 0, white := 0
		search_x := win_w

		boost_bmp := this.get_image("boost")
		boost_red_bmp := this.get_image("boost_red")
		boost_blue_bmp := this.get_image("boost_blue")

		if (!boost_bmp)
			return -2

		loop 3 {
			if (Gdip_ImageSearch(pBitmap, boost_bmp, &loc, 0, profile.y1, search_x, profile.y2, profile.var, , profile.dir) = 1) {
				x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				y := Integer(SubStr(loc, InStr(loc, ",") + 1))

				is_red := 0, is_blue := 0
				if (boost_red_bmp)
					is_red := Gdip_ImageSearch(pBitmap, boost_red_bmp, &r_loc, x - 30, 15, x - 4, 34, 20, , 1, 2)
				if (boost_blue_bmp)
					is_blue := Gdip_ImageSearch(pBitmap, boost_blue_bmp, &b_loc, x - 30, 15, x - 4, 34, 20, , 1, 2)

				val := this.detector.ReadDigits(pBitmap, x - 30, 15, x + 3, 50, "big")

				if (is_red == 2) {
					red := val
				} else if (is_blue == 2) {
					blue := val
				} else {
					white := val
				}
				search_x := x - (2 * y - 53)
			} else {
				break
			}
		}

		this.data["boost_red"] := red
		this.data["boost_blue"] := blue
		this.data["boost_white"] := white
		return -2
	}

	scan_percent_buff(pBitmap, name, profile) {
		img_name := profile.HasProp("img") ? profile.img : name
		bmp := this.get_image(img_name)
		if (!bmp)
			return -1

		if (!this.percent_buffers.Has(name) || !IsObject(this.percent_buffers[name]))
			this.percent_buffers[name] := { vals: [], fail: 0, last_val: -1 }

		icon := this.detector.SearchIcon(pBitmap, bmp, 0, 0, 0, 0, 4)

		if (!icon.found) {
			if (++this.percent_buffers[name].fail < 15) {
				return this.percent_buffers[name].last_val
			}
			this.percent_buffers[name].vals := []
			this.percent_buffers[name].last_val := -1
			return -1
		}

		this.percent_buffers[name].fail := 0

		low_y := this.detector.ReadPercentageFill(pBitmap, icon.x + profile.x_off, 0, icon.y, profile.colors, 0)
		raw := Round((icon.y - low_y) / 38 * 100, 2) + 2

		this.percent_buffers[name].vals.Push(raw)
		if (this.percent_buffers[name].vals.Length > 6)
			this.percent_buffers[name].vals.RemoveAt(1)

		best := []
		for _, val1 in this.percent_buffers[name].vals {
			current := []
			for _, val2 in this.percent_buffers[name].vals {
				if (Abs(val1 - val2) <= 5)
					current.Push(val2)
			}
			if (current.Length > best.Length)
				best := current
		}

		if (best.Length == 0) {
			this.percent_buffers[name].last_val := raw
			return raw
		}

		sum := 0
		for _, val in best
			sum += val

		final_val := Round(sum / best.Length, 2)
		this.percent_buffers[name].last_val := final_val

		return final_val
	}

	detect_gumdrops(pBMBottom, pBMHotbar) {
		if (this.scan_passive(pBMBottom, "gummystar-1", this.profiles["gummystar"]) == -1 || this.scan_passive(pBMBottom, "gummystar-2", this.profiles["gummystar"]) == -1) {
			this.gummy_star.pity := 0
			return -1
		}

		if (this.gummy_star.slot == -1) {
			if (Gdip_ImageSearch(pBMHotbar, bitmaps["buff"]["gumdrop-1"], &loc, , , , , 5) == 1 || Gdip_ImageSearch(pBMHotbar, bitmaps["buff"]["gumdrop-2"], &loc, , , , , 5) == 1) {
				found_x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				this.gummy_star.slot := Floor(found_x / 75)
			} else {
				return this.gummy_star.pity
			}
		}

		x_off := this.gummy_star.slot * 75
		x_size := x_off + 5
		y_off := 15
		y_size := y_off + 38
		if (Gdip_ImageSearch(pBMHotbar, bitmaps["buff"]["unused_slot"], &loc, x_off, y_off, x_size, y_size, 5) == 0) {
			if (A_TickCount - this.gummy_star.last_use >= 2015) {
				this.gummy_star.pity++
				this.gummy_star.last_use := A_TickCount
			}
			if (this.gummy_star.pity >= 75)
				this.gummy_star.pity := 0
		}
		return this.gummy_star.pity
	}

	detect_glitter(pBitmap) {
		field := (this.active_field_override != "") ? this.active_field_override : config.Get("alt", "default_field", "pepper")

		for _, variant in ["3", "1", "0"] {
			try {
				if (Gdip_ImageSearch(pBitmap, bitmaps["boost"][field . variant], &loc, , , , , variant == "3" ? 50 : 35) == 1) {
					comma_idx := InStr(loc, ",")
					x_coord := Integer(SubStr(loc, 1, comma_idx - 1))
					grid_x := Floor(x_coord / 38) * 38

					this.data["glitter_mult"] := variant
					return this.measure_boost(pBitmap, grid_x)
				}
			}
		}

		this.data["glitter_mult"] := "0"
		return 0
	}

	measure_boost(pBitmap, slot_x) {
		static fail_count := 0
		static last_val := 0

		is_booster(c) {
			return ((((c) & 0x00FF0000) >= 0x00b80000) && (((c) & 0x00FF0000) <= 0x00e10000)) && ((((c) & 0x0000FF00) >= 0x0000a400) && (((c) & 0x0000FF00) <= 0x0000cd00)) && ((((c) & 0x000000FF) >= 0x0000003a) && (((c) & 0x000000FF) <= 0x00000063))
		}

		scan_x := slot_x
		if (!is_booster(Gdip_GetPixel(pBitmap, scan_x, 37))) {
			if (++fail_count < 15)
				return last_val
			return 0
		}

		fail_count := 0
		low := 0
		high := 35

		while (low < high) {
			mid := Floor((low + high) / 2)
			if (is_booster(Gdip_GetPixel(pBitmap, scan_x, mid))) {
				high := mid
			} else {
				low := mid + 1
			}
		}

		last_val := Round((36 - low) / 36, 2)
		return last_val
	}
}