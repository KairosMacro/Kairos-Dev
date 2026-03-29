class Movement {
	__New() {
		this.current_paths := []
		this.is_running := false
		this.is_paused := false
		this.pending_coconut := false
		this.coco_enabled := false
		this.active_keys := Map()

		this.hive_slot := 1
		this.is_claimed := 1
	}

	Pause() {
		this.is_paused := true
	}

	Resume() {
		this.is_paused := false
	}

	Stop() {
		this.is_running := false
		this.is_paused := false
		this.ReleaseAllKeys()
	}

	Move(tiles) {
		s := QPC()
		dist_walked := 0
		last_tick := QPC()

		while (dist_walked < (tiles * 4) - 0.45) {
			if (!this.is_running)
				break
			if (this.is_paused) {
				while (this.is_paused && this.is_running)
					sleep 10
				last_tick := QPC()
			}
			current_tick := QPC()
			delta_time := (current_tick - last_tick) / 1000
			last_tick := current_tick
			dist_walked += this.DetectMovespeed(true) * delta_time
		}
		return QPC() - s
	}

	Walk(tiles, dir1, dir2?) {
		s := QPC()
		this.HoldKeys(dir1)
		if IsSet(dir2)
			this.HoldKeys(dir2)

		dist_walked := 0
		last_tick := QPC()
		
		while (dist_walked < (tiles * 4) - 0.45) {
			if (!this.is_running)
				break
			if (this.coco_enabled && this.pending_coconut) {
				this.ReleaseAllKeys()
				this.CatchCoconut()
				this.pending_coconut := false
				this.HoldKeys(dir1)
				if IsSet(dir2)
					this.HoldKeys(dir2)
				last_tick := QPC()
			}
			if (this.is_paused) {
				this.ReleaseAllKeys()
				while (this.is_paused && this.is_running)
					sleep 10
				if (this.is_running) {
					this.HoldKeys(dir1)
					if IsSet(dir2)
						this.HoldKeys(dir2)
				}
				last_tick := QPC()
			}
			current_tick := QPC()
			delta_time := (current_tick - last_tick) / 1000
			last_tick := current_tick
			dist_walked += this.DetectMovespeed(true) * delta_time
		}
		this.ReleaseKey(dir1)
		if IsSet(dir2)
			this.ReleaseKey(dir2)
	}

	DetectMovespeed(getMovespeed?) {
		s := QPC()
		global HastyGuards, BaseMovespeed, GiftedHasty, bitmaps
		win := Roblox.Get()
		static chdc := 0, hbm := 0, obm := 0, capW := 0, capH := 30
		if (!chdc || capW != win.w) {
			if (chdc) {
				SelectObject(chdc, obm)
				DeleteObject(hbm)
				DeleteDC(chdc)
			}
			chdc := CreateCompatibleDC()
			hbm := CreateDIBSection(win.w, capH, chdc)
			obm := SelectObject(chdc, hbm)
			capW := win.w
		}

		hhdc := GetDC()
		BitBlt(chdc, 0, 0, win.w, capH, hhdc, win.x, win.y + offsetY + 48)
		ReleaseDC(hhdc)
		pBMScreen := Gdip_CreateBitmapFromHBITMAP(hbm)

		Haste := 0
		x := 0
		loop 3 {
			if (Gdip_ImageSearch(pBMScreen, bitmaps["move"]["haste"], &location, x, 14, , , , , 6) != 1)
				break
			x := SubStr(location, 1, InStr(location, ",") - 1)
			y := SubStr(location, InStr(location, ",") + 1)
			if (Gdip_ImageSearch(pBMScreen, bitmaps["move"]["Melody"], , x + 2, , x + Max(16, 2 * y - 24), y, 12) = 0) {
				Haste++
				(Haste = 1) ? (x1 := x, y1 := y) : ""
			}
			x += 2 * y - 14
		}
		coconutHaste := (Haste = 2) * 10
		if Haste {
			loop 9 {
				if (Gdip_ImageSearch(pBMScreen, bitmaps["move"][Mod(11 - A_Index, 10)], , x1 + 2 * y1 - 44, Max(0, y1 - 18), x1 + 2 * y1 - 14, y1 - 1) = 1) {
					Haste := 1 + (A_Index = 1 || (Mod(11 - A_Index, 10) / 10))
					break
				}
				Haste := 1.1
			}
		} else
			haste := 1

		BearMorph := 0
		for bear in ["Brown", "Black", "Mother", "Panda", "Polar", "Science", "Gummy"] {
			if (Gdip_ImageSearch(pBMScreen, bitmaps["move"][bear], , , 25, , 27, 5, , 2) = 1) {
				BearMorph := 4
				break
			}
		}

		Multiplier := (Gdip_ImageSearch(pBMScreen, bitmaps["move"]["SuperSmoothie"], , , 25, , 27, 4, , 2) = 1) ? 1.25 : Gdip_ImageSearch(pBMScreen, bitmaps["move"]["Oil"], , , 25, , 27, 4, , 2) = 1 ? 1.2 : 1
		HastePlus := (Gdip_ImageSearch(pBMScreen, bitmaps["move"]["HastePlus"], , , 25, , 27, , , 2) = 1) ? 2 : 1

		Gdip_DisposeImage(pBMScreen)
		return ((BaseMovespeed + BearMorph + CoconutHaste) * Multiplier * Haste * HastePlus * (GiftedHasty ? 1.15 : 1) * (HastyGuards ? 1.1 : 1)) * (IsSet(getMovespeed) ? 1 : (QPC() - s) / 1000)
	}

	HoldKeys(key) {
		if (!this.active_keys.Has(key) || !this.active_keys[key]) {
			send "{" key " down}"
			this.active_keys[key] := true
		}
	}

	ReleaseKey(key) {
		if (this.active_keys.Has(key) && this.active_keys[key]) {
			send "{" key " up}"
			this.active_keys[key] := false
		}
	}

	ReleaseAllKeys() {
		for key, is_down in this.active_keys {
			if (is_down) {
				send "{" key " up}"
				this.active_keys[key] := false
			}
		}
	}

	GotoRamp() {
		if (this.is_claimed) {
			this.Walk(5, FwdKey)
			this.Walk(9.2 * this.hive_slot, RightKey)
		} else {
			this.Walk(30, FwdKey, RightKey)
			this.Walk(5, RightKey)
		}
	}

	GotoCannon() {
		static pBMCannon := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAABsAAAAMAQMAAACpyVQ1AAAABlBMVEUAAAD3//lCqWtQAAAAAXRSTlMAQObYZgAAAEdJREFUeAEBPADD/wDAAGBgAMAAYGAA/gBgYAD+AGBgAMAAYGAAwABgYADAAGBgAMAAYGAAwABgYADAAGBgAMAAYGAAwABgYDdgEn1l8cC/AAAAAElFTkSuQmCC")
		win := Roblox.Get()
		SendEvent "{Click " win.x + 350 " " win.y + offsetY + 100 " 0}"

		success := false
		loop 10 {
			this.HoldKeys(SC_Space)
			this.HoldKeys(RightKey)
			sleep 100
			this.ReleaseKey(SC_Space)
			this.Walk(2, RightKey)
			this.Walk(1.5, FwdKey, RightKey)
			this.HoldKeys(RightKey)

			DllCall("GetSystemTimeAsFileTime", "int64p", &s:=0)
			n := s, f := s + 100000000

			while (n < f) {
				pBMScreen := Gdip_BitmapFromScreen(win.x + win.w // 2 - 200 "|" win.y + offsetY "|400|125")
				if (Gdip_ImageSearch(pBMScreen, pBMCannon, , , , , , 2, , 2) = 1) {
					success := true
					Gdip_DisposeImage(pBMScreen)
					break
				}
				Gdip_DisposeImage(pBMScreen)
				DllCall("GetSystemTimeAsFileTime", "int64p", &n)
			}

			this.ReleaseKey(RightKey)

			if (success = 1) {
				Loop 10 {
					if (A_Index = 10) {
						success := false
						break
					}
					Sleep 500
					pBMScreen := Gdip_BitmapFromScreen(win.x + win.w // 2 - 200 "|" win.y + offsetY "|400|125")
					if (Gdip_ImageSearch(pBMScreen, pBMCannon, , , , , , 2, , 2) = 1) {
						Gdip_DisposeImage(pBMScreen)
						break 2
					} else
						this.Walk(1.5, LeftKey)
					Gdip_DisposeImage(pBMScreen)
				}
			}

			if (success = false) {
				this.ResetCharacter()
				this.GotoRamp()
			} else
				break
		}
	}

	ResetCharacter() {
		static hive_down := 0
		static pBMR := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAACgAAAAGCAAAAACUM4P3AAAAAnRSTlMAAHaTzTgAAAAXdEVYdFNvZnR3YXJlAFBob3RvRGVtb24gOS4wzRzYMQAAAyZpVFh0WE1MOmNvbS5hZG9iZS54bXAAAAAAADw/eHBhY2tldCBiZWdpbj0n77u/JyBpZD0nVzVNME1wQ2VoaUh6cmVTek5UY3prYzlkJz8+Cjx4OnhtcG1ldGEgeG1sbnM6eD0nYWRvYmU6bnM6bWV0YS8nIHg6eG1wdGs9J0ltYWdlOjpFeGlmVG9vbCAxMi40NCc+CjxyZGY6UkRGIHhtbG5zOnJkZj0naHR0cDovL3d3dy53My5vcmcvMTk5OS8wMi8yMi1yZGYtc3ludGF4LW5zIyc+CgogPHJkZjpEZXNjcmlwdGlvbiByZGY6YWJvdXQ9JycKICB4bWxuczpleGlmPSdodHRwOi8vbnMuYWRvYmUuY29tL2V4aWYvMS4wLyc+CiAgPGV4aWY6UGl4ZWxYRGltZW5zaW9uPjQwPC9leGlmOlBpeGVsWERpbWVuc2lvbj4KICA8ZXhpZjpQaXhlbFlEaW1lbnNpb24+NjwvZXhpZjpQaXhlbFlEaW1lbnNpb24+CiA8L3JkZjpEZXNjcmlwdGlvbj4KCiA8cmRmOkRlc2NyaXB0aW9uIHJkZjphYm91dD0nJwogIHhtbG5zOnRpZmY9J2h0dHA6Ly9ucy5hZG9iZS5jb20vdGlmZi8xLjAvJz4KICA8dGlmZjpJbWFnZUxlbmd0aD42PC90aWZmOkltYWdlTGVuZ3RoPgogIDx0aWZmOkltYWdlV2lkdGg+NDA8L3RpZmY6SW1hZ2VXaWR0aD4KICA8dGlmZjpPcmllbnRhdGlvbj4xPC90aWZmOk9yaWVudGF0aW9uPgogIDx0aWZmOlJlc29sdXRpb25Vbml0PjI8L3RpZmY6UmVzb2x1dGlvblVuaXQ+CiAgPHRpZmY6WFJlc29sdXRpb24+OTYvMTwvdGlmZjpYUmVzb2x1dGlvbj4KICA8dGlmZjpZUmVzb2x1dGlvbj45Ni8xPC90aWZmOllSZXNvbHV0aW9uPgogPC9yZGY6RGVzY3JpcHRpb24+CjwvcmRmOlJERj4KPC94OnhtcG1ldGE+Cjw/eHBhY2tldCBlbmQ9J3InPz77yGiWAAAAI0lEQVR42mNUYyAOMDJggOUMDAyRmAqXMxAHmBiobjWxngEAj7gC+wwAe1AAAAAASUVORK5CYII=")
		win := Roblox.Get()
		success := 0
		SendEvent "{Click " win.x + 350 " " win.y + offsetY + 100 " 0}"
		Loop 10 {
			Roblox.Activate()
			PrevKeyDelay := A_KeyDelay
			SetKeyDelay 250
			SendEvent "{" SC_Esc "}{" SC_R "}{" SC_Enter "}"
			SetKeyDelay PrevKeyDelay

			n := 0
			while ((n < 2) && (A_Index <= 80)) {
				sleep 100
				pBMScreen := Gdip_BitmapFromScreen(win.x "|" win.y "|" win.w "|50")
				n += (Gdip_ImageSearch(pBMScreen, pBMR, , , , , , 10) = (n = 0))
				Gdip_DisposeImage(pBMScreen)
			}
			sleep 1000
			if hive_down
				send "{" RotDown "}"
			region := win.x "|" win.y + 3 * win.h // 4 "|" win.w "|" win.h // 4
			sconf := win.w ** 2 // 3200
			loop 4 {
				sleep 250
				pBMScreen := Gdip_BitmapFromScreen(region), s := 0
				for i, k in bitmaps["hive"] {
					s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 4, , , sconf))
					if (s >= sconf) {
						Gdip_DisposeImage(pBMScreen)
						success := 1
						send "{" RotRight " 4}"
						if hive_down
							send "{" RotUp "}"
						SendEvent "{" ZoomOut " 5}"
						break 3
					}
				}
				Gdip_DisposeImage(pBMScreen)
				Send "{" RotRight " 4}"
				if (A_Index = 2) {
					if hive_down := !hive_down
						send "{" RotDown "}"
					else
						send "{" RotUp "}"
				}
			}
		}
	}

	FieldDriftCompensate() {
		win := Roblox.Get()
		center_x := win.w // 2
		center_y := win.h // 2

		dead_x := win.w * 0.02
		dead_y := win.h * 0.02

		held_x := ""
		held_y := ""
		miss := 0
		start := A_TickCount

		if !this.LocateSprinkler()
			return

		while (A_TickCount - start < 7000) { ; 7 second limit for sprinkler...
			if (this.LocateSprinkler(&x, &y) = 0) {
				if (miss++ > 3)
					break
				continue
			}
			miss := 0

			vec_x := x - center_x
			vec_y := y - center_y
			target_x := ""
			target_y := ""

			if (Abs(vec_x) > dead_x)
				target_x := (vec_x > 0) ? RightKey : LeftKey
			if (Abs(vec_y) > dead_y)
				target_y := (vec_y > 0) ? BackKey : FwdKey
			
			if (held_x != target_x) {
				if (held_x)
					this.ReleaseKey(held_x)
				if (target_x)
					this.HoldKeys(target_x)
				held_x := target_x
			}
			if (held_y != target_y) {
				if (held_y)
					this.ReleaseKey(held_y)
				if (target_y)
					this.HoldKeys(target_y)
				held_y := target_y
			}

			if (held_x = "" && held_y = "")
				break
		}
		this.ReleaseAllKeys()
	}

	LocateSprinkler(&x:="", &y:="") {
		global SprinklerImages
		static init := false
		static sprinkler_data := []
		static last_pos := ""

		win := Roblox.Get()
		hwnd := win.Hwnd

		center_x := win.w // 2
		center_y := win.h // 2

		if (!init) {
			for i, k in SprinklerImages {
				Gdip_GetImageDimensions(bitmaps[k], &nWidth, &nHeight)
				Gdip_LockBits(bitmaps[k], 0, 0, nWidth, nHeight, &nStride, &nScan, &nBitmapData)
				nWidth := NumGet(nBitmapData, 0, "UInt")
				nHeight := NumGet(nBitmapData, 4, "UInt")
				sprinkler_data.Push({width: nWidth, height: nHeight, stride: nStride, scan: nScan, name: k})
			}
			init := true
		}

		found := false
		name := ""
		best_x := 0
		best_y := 0
		min_dist := 999999
		v := 50

		ParsePos(pos_str, offset_x, offset_y, img_name) {
			Loop Parse, pos_str, "`n" {
				if (A_LoopField = "")
					continue
				cur_x := offset_x + SubStr(A_LoopField, 1, InStr(A_LoopField, ",") - 1)
				cur_y := offset_y + SubStr(A_LoopField, InStr(A_LoopField, ",") + 1)
				dist := Sqrt((cur_x - center_x)**2 + (cur_y - center_y)**2)
				if (dist < min_dist) {
					min_dist := dist
					best_x := cur_x
					best_y := cur_y
					found := true
					name := img_name
				}
			}
		}

		if (last_pos) {
			scan_w := Round(win.w * 0.2)
			scan_h := Round(win.h * 0.2)
			rel_x := last_pos.x - (scan_w // 2)
			rel_y := last_pos.y - (scan_h // 2)

			rel_x := Max(0, rel_x)
			rel_y := Max(0, rel_y)
			scan_w := Min(scan_w, win.w - rel_x)
			scan_h := Min(scan_h, win.h - rel_y)

			abs_x := win.x + rel_x
			abs_y := win.y + rel_y

			pBM := Gdip_BitmapFromScreen(abs_x "|" abs_y "|" scan_w "|" scan_h)
			Gdip_GetImageDimensions(pBM, &lWidth, &lHeight)
			Gdip_LockBits(pBM, 0, 0, lWidth, lHeight, &lStride, &lScan, &lBitmapData)

			for img in sprinkler_data {
				sx2 := lWidth - img.width
				sy2 := lHeight - img.height
				if (sx2 > 0 && sy2 > 0 && Gdip_MultiLockedBitsSearch(lStride, lScan, lWidth, lHeight, img.Stride, img.Scan, img.Width, img.Height, &pos, 0, 0, sx2, sy2, v, 1, 1) > 0) {
					ParsePos(pos, rel_x, rel_y, img.name)
				}
			}
			Gdip_UnlockBits(pBM, &lBitmapData)
			Gdip_DisposeImage(pBM)
		}
		if (!found) {
			scan_y_offset := offsetY + 75
			hWidth := win.w
			hHeight := win.h - scan_y_offset
			pBMScreen := Gdip_BitmapFromScreen(win.x "|" (win.y + scan_y_offset) "|" hWidth "|" hHeight)
			Gdip_LockBits(pBMScreen, 0, 0, hWidth, hHeight, &hStride, &hScan, &hBitmapData)

			for img in sprinkler_data {
				sx2 := hWidth - img.width
				sy2 := hHeight - img.height
				if (sx2 > 0 && sy2 > 0 && Gdip_MultiLockedBitsSearch(hStride, hScan, hWidth, hHeight, img.Stride, img.Scan, img.Width, img.Height, &pos, 0, 0, sx2, sy2, v, 1, 1) > 0) {
					ParsePos(pos, 0, scan_y_offset, img.name)
				}
			}
			Gdip_UnlockBits(pBMScreen, &hBitmapData)
			Gdip_DisposeImage(pBMScreen)
		}
		if (found) {
			x := best_x
			y := best_y
			tooltip "Located sprinkler: " name " at " x "," y, win.x + x + 10, win.y + y + 13
			last_pos := {x: x, y: y}
			return 1
		} else {
			x := "", y := ""
			last_pos := ""
			return 0
		}
	}

	TriggerCoconutCatch(x := false, y := false) {
		if (x = false)
			this.pending_coconut := false
		else
			this.pending_coconut := {x: x, y: y}
	}

	CatchCoconut() {
		win := Roblox.Get()
		center_x := win.w // 2
		center_y := win.h // 2
		dead_x := win.w * 0.035
		dead_y := win.h * 0.035

		start := A_TickCount
		scan_step := 0
		scan_count := 0
		scan_last := 0
		net_rot := 0

		SetTimer(SpamKeys, 10)

		while (A_TickCount - start < 10000) {
			current_coco := this.pending_coconut
			if (!current_coco) {
				this.UpdateHeldKeys([])
				if (scan_step < 160 && A_TickCount - scan_last > 50) {
					scan_last := A_TickCount
					scan_step++
					if (Mod(scan_count, 4) < 2) {
						send "{" RotLeft "}"
						net_rot++
					} else {
						send "{" RotRight "}"
						net_rot--
					}
					scan_count++
				}
				continue
			}
			scan_last := A_TickCount + 275
			scan_step := 0

			vec_x := current_coco.x - center_x
			vec_y := current_coco.y - center_y
			raw_x := ""
			raw_y := ""

			if (Abs(vec_x) > dead_x)
				raw_x := (vec_x > 0) ? RightKey : LeftKey
			if (Abs(vec_y) > dead_y)
				raw_y := (vec_y > 0) ? BackKey : FwdKey

			final_keys := this.TranslateDir(raw_x, raw_y, net_rot)
			this.UpdateHeldKeys(final_keys)
		}
		SetTimer(SpamKeys, 0)
		send "{" RotDown " 4}"
		this.ReleaseAllKeys()
		if (net_rot > 0)
			Send "{" RotRight " " Abs(net_rot) "}"
		else if (net_rot < 0)
			Send "{" RotLeft " " Abs(net_rot) "}"
		
		SpamKeys() {
			send "{" RotUp "}{" ZoomOut "}"
		}
	}

	TranslateDir(x_key, y_key, rot_offset) {
		if (x_key = "" && y_key = "")
			return []
		
		idx := 0
		if (y_key = FwdKey && x_key = LeftKey)
			idx := 8
		else if (y_key = FwdKey && x_key = RightKey)
			idx := 2
		else if (y_key = BackKey && x_key = LeftKey)
			idx := 6
		else if (y_key = BackKey && x_key = RightKey)
			idx := 4
		else if (y_key = FwdKey)
			idx := 1
		else if (y_key = BackKey)
			idx := 5
		else if (x_key = LeftKey)
			idx := 7
		else if (x_key = RightKey)
			idx := 3
		
		new_idx := idx + rot_offset
		while (new_idx > 8)
			new_idx -= 8
		while (new_idx < 1)
			new_idx += 8
		cycle := [
			[FwdKey],
			[FwdKey, RightKey],
			[RightKey],
			[RightKey, BackKey],
			[BackKey],
			[BackKey, LeftKey],
			[LeftKey],
			[LeftKey, FwdKey]
		]
		return cycle[new_idx]
	}

	UpdateHeldKeys(target_arr) {
		for key, is_down in this.active_keys {
			if (is_down) {
				keep := false
				for t_key in target_arr {
					if (key = t_key)
						keep := true
				}
				if (!keep)
					this.ReleaseKey(key)
			}
		}
		for t_key in target_arr
			this.HoldKeys(t_key)
	}
}
