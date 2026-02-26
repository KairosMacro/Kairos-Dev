class StatMonitor {
	__New() {
		this.logs := [] ; {time (unix or A_TickCount):, data: (what was detected basically)}
		this.previousBuffs := Map() ; basically for "safety" since detection isn't perfect.
		this.currentBuffs := Map()
		this.isRunning := false

		this.scanStartTime := 0
		this.learningPeriod := 50000 ; guaranteed out of cooldown for passives
		this.confirmedPassives := []
		this.possiblePassives := ["scorching_star", "pop_star"]
	}

	Toggle() {
		if !Config.Get("Main", "StatMonitorEnabled", 0)
			return
		this.isRunning := true
		if (this.scanStartTime = 0)
			this.scanStartTime := A_TickCount
		SetTimer(this.RunScan.Bind(this), 1000)
	}

	Pause() {
		this.isRunning := false
		SetTimer(this.RunScan.Bind(this), 0)
		ToolTip(,,, 20)
	}

	Cleanup() {
		this.Pause()
	}

	RunScan() {
		if (!this.isRunning)
			return
		this.DetectBuffs()
		this.PrintOutput()
	}

	PrintOutput() {
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok 
			return
		out := "MONITOR`n"
		count := 0
		for buff, val in this.currentBuffs {
			if (val) {
				out .= buff ": " val "`n"
				count++
			}
		}
		if (count = 0) {
			out .= "No buffs detected."
		}
		ToolTip(out, win.x + 350, win.y + State.offsetY + 60, 20)
	}

; this will graph out based off the time, so the "res" of the graph might vary.
	DrawGraph() {
		; CHECK WHAT NEEDS TO BE GRAPHED TO DETERMINE RESOLUTION (if not detected at all, remove that section of the graph. so somehow this needs to be modular .....)
		; For on/off graphing - try figuring out a design that will make them easily readable in a compact area, i'll probably draw out some ideas on how to display it.

		; START DRAWING THE GRAPH

		; SAVE THE IMAGE "Graph.png" AND IF CONFIGURED, SEND TO A WEBHOOK IN DISCORD.

		; DISPOSE DISPOSE DISPOSE (cleanup)
	}

	DetectBuffs() {
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok 
			return
		
		if win.w <= 500
			return

		this.currentBuffs := Map()
		pBMTop := Gdip_BitmapFromScreen(win.x "|" win.y + State.offsetY + 30 "|" win.w "|" 50)
		pBMBottom := Gdip_BitmapFromScreen(win.x + (win.w // 2) - 257 "|" win.y + win.h - 142 "|517|36")

		; --------------------
		; STANDARD ON/OFF BUFFS (TOP)
		; --------------------
		onOffList := ["oil", "super_smoothie", "bomb_sync_red", "bomb_sync_blue"
							, "festive_blessing", "beesmas_cheer", "tabby_blessing", "clouds"
							, "baby_love", "festive_mark", "flame_fuel", "guiding_star"
							, "stinger", "enzyme", "extract_red", "extract_blue"
							, "glue", "tropical_drink", "purple_potion", "marshmallow_bee"
							, "jellybean_sharing"]
		; "galentine", "honeyday", "beesmas_repentance"
		for index, buffName in onOffList {
			rules := buff_params[buffName]
			if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"][buffName], &loc, rules.x1, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
				this.Verify(buffName, true, 0)
			} else {
				this.Verify(buffName, false, 0)
			}
		}

		; --------------------
		; BEAR MORPHS
		; --------------------
		bearActive := false
		bearList := ["brown", "black", "panda", "polar", "gummy", "science", "mother"]
		rules := buff_params["morph"]
		for index, bear in bearList {
			if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"][bear], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
				bearActive := true
				break
			}
		}
		this.Verify("bear_morph", bearActive, 0)

		; --------------------
		; STANDARD BUFFS (DIGITS) "1x - 10x"
		; --------------------
		digitList := ["focus", "bomb", "rage", "inspire", "balloon_aura", "clock"
						, "honey_mark", "pollen_mark", "precise_mark", "reindeer_guidance"
						, "mondo", "map_corruption", "cool_breeze", "precision", "sticker_stack"
						, "puffshroom_blessing", "robo_party", "dark_heat", "coconut_combo"]
		for index, buffName in digitList {
			rules := buff_params[buffName]
			if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"][buffName], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
				x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				val := this.ReadDigits(pBMTop, x, 20, x + 40, 46)
				this.Verify(buffName, val, 1)
			} else {
				this.Verify(buffName, 0, 1)
			}
		}

		; --------------------
		; BLESSING (1x- 100x) - USES A SPECIFIC BITMAP FOR 100x
		this.currentBuffs["balloon_blessing"] := 0
		rules := buff_params["balloon_blessing"]
		balloon := 0
		if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["balloon_blessing_100"], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
			balloon := 100
		} else if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["balloon_blessing"], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
			x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
			balloon := this.ReadDigits(pBMTop, x + 8, 15, x + 36, 46)
		}
		this.Verify("balloon_blessing", balloon, 1)

		; --------------------
		; SPECIAL BUFFS (DIGITS) Haste / Melody / Coco Haste
		; --------------------
		haste := 0, melody := 0
		searchX := 0
		rules := buff_params["haste"]
		mel := buff_params["melody"]
		loop 3 {
			if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["haste"], &loc, searchX, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
				x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["melody"], , x + 2, mel.y1, x + 34, mel.y2, mel.var) = 1) {
					melody := 1
				} else if (haste = 0) {
					haste := this.ReadDigits(pBMTop, x + 6, 15, x + 44, 50, "big")
				}
				searchX := x + 44
			} else {
				break
			}
		}
		this.Verify("haste", haste, 1)
		this.Verify("melody", melody, 0)

		; --------------------
		; SPECIAL BUFFS (DIGITS) Red / Blue / White Boost
		; --------------------
		red := 0, blue := 0, white := 0
		searchX := win.w
		rules := buff_params["boost"]
		loop 3 {
			if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["boost"], &loc, 0, rules.y1, searchX, rules.y2, rules.var, , rules.dir) = 1) {
				x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				y := Integer(SubStr(loc, InStr(loc, ",") + 1))
				r_red := buff_params["boost_red"]
				r_blue := buff_params["boost_blue"]

				isRed := Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["boost_red"], , x-30, 15, x-4, 34, r_red.var, r_red.trans, r_red.dir, r_red.instances)
				isBlue := Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"]["boost_blue"], , x-30, 15, x-4, 34, r_blue.var, r_blue.trans, r_blue.dir, r_blue.instances)

				val := this.ReadDigits(pBMTop, x - 30, 15, x + 3, 50, "big")
				if (isRed = 2) {
					red := val
				} else if (isBlue = 2) {
					blue := val
				} else {
					white := val
				}
				searchX := x - (2 * y - 53)
			} else {
				break
			}
		}
		this.Verify("boost_red", red, 1)
		this.Verify("boost_blue", blue, 1)
		this.Verify("boost_white", white, 1)

		; ---------------------
		; SCALED FILLS (0% - 100%) BASED OFF THE ICON
		; ---------------------
		scaledList := ["bubble_bloat", "comforting", "motivating", "satisfying", "refreshing", "invigorating", "tide_blessing", "flame_heat"]
		for index, buffName in scaledList {
			rules := buff_params["scaling"]
			if (Gdip_ImageSearch(pBMTop, bitmaps["stat_buff"][buffName], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
				x := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				val := this.ReadScaleFill(pBMTop, bitmaps["stat_buff"][buffName], x, buffName)
				this.Verify(buffName, val, 0)
			} else {
				this.Verify(buffName, 0, 0)
			}
		}

		; --------------------
		; PASSIVES (BOTTOM) - AUTO DETECT + TRACKING (fix, not working)
		; --------------------
		if (A_TickCount - this.scanStartTime < this.learningPeriod) {
			for index, buffName in this.possiblePassives {
				rules := buff_params[buffName]
				if (Gdip_ImageSearch(pBMBottom, bitmaps["stat_buff"][buffName], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1) {
					this.currentBuffs[buffName] := false
					hasBuff := false
					for item in this.confirmedPassives {
						if (item = buffName) {
							hasBuff := true
							break
						}
					}
					if !hasBuff {
						this.confirmedPassives.Push(buffName)
					}
				} else {
					hasBuff := false
					for item in this.confirmedPassives {
						if (item = buffName) {
							hasBuff := true
						}
					}
					if (hasBuff) {
						this.currentBuffs[buffName] := true
					}
				}
			}
		} else {
			for index, buffName in this.confirmedPassives {
				rules := buff_params[buffName]
				this.currentBuffs[buffName] := !(Gdip_ImageSearch(pBMBottom, bitmaps["stat_buff"][buffName], &loc, 0, rules.y1, 0, rules.y2, rules.var, , rules.dir) = 1)
			}
		}

		Gdip_DisposeImage(pBMTop), Gdip_DisposeImage(pBMBottom)
	}

	Verify(buffName, val, threshold := 1) {
		lastVal := this.previousBuffs.Has(buffName) ? this.previousBuffs[buffName] : 0
		if (val <= threshold && lastVal > threshold) {
			this.currentBuffs[buffName] := lastVal
		} else {
			this.currentBuffs[buffName] := val
		}
		this.previousBuffs[buffName] := val
	}

	ReadDigits(pBitmap, sX, sY, sW, sH, type := "auto") {
		if (type = "tiny" || type = "auto") {
			val := this.DetectNum(pBitmap, "tiny", sX, sY, sW, sH)
			if (val >= 100) {
				return val
			}
		}
		if (type = "big" || type = "auto") {
			val := this.DetectNum(pBitmap, "big", sX, sY, sW, sH)
			if (val > 0) {
				return val
			} 
		}
		return 1
	}

	DetectNum(pBitmap, numType, sX, sY, sW, sH) {
		offsets := (numType = "big") ? bigOffset : tinyOffset
		found := []
		priorityOrder := [8, 0, 6, 9, 4, 7, 2, 3, 5, 1]

		for idx in priorityOrder {
			currentX := sX
			while (Gdip_ImageSearch(pBitmap, bitmaps["stat_digits_" numType][idx], &loc, currentX, sY, sW, sH, , , 6)) {
				mX := Integer(SubStr(loc, 1, InStr(loc, ",") - 1))
				isOverlap := false
				for item in found {
					if (mX >= item.x && mX < item.x + item.w) || (item.x >= mX && item.x < mX + offsets[idx]) {
						isOverlap := true
						break
					}
				}
				if !isOverlap {
					found.Push({num: idx, x: mX, w: offsets[idx]})
				}
				currentX := mX + offsets[idx]
				if (currentX >= sW)
					break
			}
		}
		if (found.Length = 0)
			return 0
		Loop found.Length {
			i := A_Index
			Loop found.Length - i {
				j := i + A_Index
				if (found[i].x > found[j].x) {
					temp := found[i]
					found[i] := found[j]
					found[j] := temp
				}
			}
		}
		result := ""
		for item in found
			result .= item.num
		return Integer(result)
	}

	ReadScaleFill(pBitmap, bitmap, x, buffName) {
		if (Gdip_ImageSearch(pBitmap, bitmap, &loc, x, 6, x + 38, 44) = 1) {
			y := Integer(SubStr(loc, InStr(loc, ",") + 1))
			fillRatio := Min((44 - y) / 38, 1)
			if (buffName = "bubble_bloat") {
				return Round(fillRatio * 5 + 1, 2)
			} else if (buffName = "tide_blessing") {
				return Round(1.01 + 0.19 * (44.3 - y) / 38, 2)
			} else if (buffName = "flame_heat") {
				return Round(1 + fillRatio, 2)
			} else {
				return Round(fillRatio * 100)
			}
		}
		return 0
	}

	DetectBag() {

	}

	DetectHoney() {

	}
}