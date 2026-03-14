class Warnings {
	IsRunning := false
	IsActive := false
	AudioPlayer := unset

	AudioCache := Map()
	LastPlayed := Map()
	HasPlayed := Map()
	EnabledWarns := []

	WarnProfiles := Map(
		"Precise", { loc: "buff", img: "Precise", mult: 0.6, x: 9, colors: [0xff8F4EB4, 0xff774296, 0xff3E274C, 0xff211A24, 0xff201A24, 0xff221A26, 0xff55316A, 0xff8448A6], var: 0 }
		, "SuperSmoothie", { loc: "buff", img: "smoothie", mult: 12.0, x: -5, colors: [0xffFEC650], var: 0}
		, "PopStar", { loc: "passive", img: "popstar", count: 30 }
		, "ScorchStar", { loc: "passive", img: "scorch", count: 30 }
		, "StarShower", { loc: "passive", img: "shower", count: 25 }
		, "GummyMorph", { loc: "passive", img: "gummymorph", count: 30 }
		, "GummyStar", { loc: "passive", img: "gummystar", count: 75 }
		, "GummyBaller", { loc: "buff", img: "gummyballer", count: 1000 }
	)

	__New() {
		this.scanner := Detection()
		this.Fancy := GdipTooltip()
		this.RefreshConfig()
		Scheduler.Add("Warnings.CheckLoop", this.CheckLoop.Bind(this), 150, () => this.IsActive)
	}

	Cleanup(*) {
		this.IsRunning := false
	}

	Toggle() {
		this.IsRunning ^= 1
		this.IsActive := this.IsRunning && Config.Get("Main", "WarnsEnabled", 0)

		if Config.Get("Main", "WarnsEnabled", 0)
			this.Fancy.Show("Warns: " (this.IsActive ? "ON" : "OFF"))
		SetTimer () => this.Fancy.Hide(), -500
	}

	CheckLoop(*) {
		if (State.IsPaused)
			return
		static minTime := 500
		static maxTime := 5000
		if (!this.IsRunning || !WinActive("Roblox"))
			return
		
		for warnName, profile in this.WarnProfiles {
			if (!Config.Get("Warns", warnName "_Enabled", 0))
				continue
			if (!this.HasPlayed.Has(warnName))
				this.HasPlayed[warnName] := false
			if (!this.LastPlayed.Has(warnName))
				this.LastPlayed[warnName] := 0

			threshold := Config.Get("Warns", warnName "_Threshold", 25)
			isTriggered := false
			ratio := 1.0
			currentVal := 0
			if (profile.HasProp("colors")) {
				percent := Round(this.DetectPercent(warnName, profile.colors), 2)
				if (percent = 0) {
					this.HasPlayed[warnName] := false
					continue
				}
				currentVal := Round(profile.mult * percent)
				if (currentVal <= threshold) {
					isTriggered := true
					ratio := currentVal / threshold
				}
			} else if (profile.HasProp("count")) {
				currentVal := this.DetectNumber(warnName)
				if (currentVal = 0) {
					this.HasPlayed[warnName] := false
					continue
				}
				if (currentVal >= threshold) {
					isTriggered := true
					denominator := Max(1, profile.count - threshold)
					ratio := Max(0, Min(1, (profile.count - currentVal) / denominator))
				}
			}
			if (isTriggered) {
				vol := Config.Get("Warns", warnName "_Volume", 25)
				playOnce := Config.Get("Warns", warnName "_PlayOnce", 0)
				soundPath := Config.Get("Warns", warnName "_SoundFile", "C:\Windows\Media\Windows Critical Stop.wav")

				if (playOnce) {
					if (!this.HasPlayed[warnName]) {
						this.PlaySound(soundPath, vol)
						this.HasPlayed[warnName] := true
					}
				} else {
					calcDelay := minTime + (ratio * (maxTime - minTime))
					delay := Min(Max(minTime, calcDelay), maxTime)
					if (A_TickCount - this.LastPlayed[warnName] > delay) {
						this.LastPlayed[warnName] := A_TickCount
						this.PlaySound(soundPath, vol)
					}
				}
			} else
				this.HasPlayed[warnName] := false
		}
	}

	PlaySound(path, vol) {
		if !FileExist(path)
			path := "C:\Windows\Media\Windows Critical Stop.wav"
		if !this.AudioCache.Has(path)
			this.AudioCache[path] := Audio(path)
		this.AudioCache[path].Play(vol)
	}

	RefreshConfig() {

	}

	DetectPercent(buffName, colors) {
		static buffers := Map(), bufferSize := 6, tolerance := 5
		if !buffers.Has(buffName)
			buffers[buffName] := []
		buff := buffers[buffName]

		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return 0

		region := win.x "|" win.y + State.offsetY + 32 "|" win.w "|" 42
		pBMScreen := FrameCache.Get(region)
		if !pBMScreen
			return 0

		imgName := this.WarnProfiles[buffName].img
		icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][imgName], 0, 0, 0, 0, 4)
		if (!icon.found) {
			buffers[buffName] := []
			return 0
		}

		lowY := this.scanner.ReadPercentageFill(pBMScreen, icon.x + this.WarnProfiles[buffName].x, 0, icon.y, colors, 0)
		raw := Round((icon.y - lowY) / 38 * 100, 2) + 2

		buff.Push(raw)
		if (buff.Length > bufferSize)
			buff.RemoveAt(1)

		best := []
		for val1 in buff {
			current := []
			for val2 in buff {
				if (Abs(val1 - val2) <= tolerance)
					current.Push(val2)
			}
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

	DetectNumber(buffName) {
		win := WindowTracker.Get()
		if !IsObject(win) || !win.ok
			return 0
			
		profile := this.WarnProfiles[buffName]
		
		if (profile.loc = "passive") {
			region := win.x + (win.w // 2) - 257 "|" win.y + win.h - 142 "|517|36"
			pBMScreen := FrameCache.Get(region)
			if !pBMScreen
				return 0
				
			icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][profile.img], 0, 0, 0, 0, 30)
			if (!icon.found)
				return 0
				
			slotX := icon.x // 40
			return this.scanner.ReadDigits(pBMScreen, slotX * 40, 22, (slotX * 40) + 34, 33, "passive")
			
		} else if (profile.loc = "buff") {
			region := win.x "|" win.y + State.offsetY + 48 "|" win.w "|" 32
			pBMScreen := FrameCache.Get(region)
			if !pBMScreen
				return 0
				
			icon := this.scanner.SearchIcon(pBMScreen, bitmaps["buff"][profile.img], 0, 0, 0, 0, 30)
			if (!icon.found)
				return 0
				
			return this.scanner.ReadDigits(pBMScreen, icon.x - 13, 0, icon.x + 25, 32, "auto")
		}
		
		return 0
	}
}
