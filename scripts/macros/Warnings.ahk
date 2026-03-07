class Warnings {
	IsRunning := false
	IsActive := false
	AudioPlayer := unset

	AudioCache := Map()
	LastPlayed := Map()
	HasPlayed := Map()
	EnabledWarns := []

	WarnProfiles := Map(
		"Precise", { img: "Precise", mult: 0.6, x: 9,colors: [0xff8F4EB4, 0xff774296, 0xff3E274C, 0xff211A24, 0xff201A24, 0xff221A26, 0xff55316A, 0xff8448A6] }
		, "SuperSmoothie", { img: "smoothie", mult: 12.0, x: -5, colors: [0xffFEC650]}
	)

	__New() {
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
		if !this.IsRunning || !WinActive("Roblox")
			return
		
		for warnName, profile in this.WarnProfiles {
			if !Config.Get("Warns", warnName "_Enabled", 0)
				continue
			percent := Round(this.DetectPercent(warnName, profile.colors), 2)

			if !this.HasPlayed.Has(warnName)
				this.HasPlayed[warnName] := false
			if !this.LastPlayed.Has(warnName)
				this.LastPlayed[warnName] := 0
			
			if (percent = 0) {
				this.HasPlayed[warnName] := false
				continue
			}

			secondsLeft := Round(profile.mult * percent)
			threshold := Config.Get("Warns", warnName "_Threshold", 25)
			if warnName = "SuperSmoothie" {
				tooltip secondsLeft "(" percent ")"
			}
			vol := Config.Get("Warns", warnName "_Volume", 25)
			playOnce := Config.Get("Warns", warnName "_PlayOnce", 0)
			soundPath := Config.Get("Warns", warnName "_SoundFile", "C:\Windows\Media\Windows Critical Stop.wav")

			if (secondsLeft <= threshold) {
				if (playOnce) {
					if (!this.HasPlayed[warnName]) {
						this.PlaySound(soundPath, vol)
						this.HasPlayed[warnName] := true
					}
				} else {
					ratio := secondsLeft / threshold
					calcDelay := minTime + (ratio * (maxTime - minTime))
					delay := Min(Max(minTime, calcDelay), maxTime)

					if (A_TickCount - this.LastPlayed[warnName] > delay) {
						this.LastPlayed[warnName] := A_TickCount
						this.PlaySound(soundPath, vol)
					}
				}
			} else {
				this.HasPlayed[warnName] := false
			}
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

		if (Gdip_ImageSearch(pBMScreen, bitmaps["buff"][this.WarnProfiles[buffName].img], &loc, , , , , 4, , 6) != 1) {
			buffers[buffName] := []
			return 0
		}

		x := SubStr(loc, 1, InStr(loc, ",") - 1)
		y := SubStr(loc, InStr(loc, ",") + 1)
		bottomY := y
		high := y
		low := 0

		while (low < high) {
			if (A_Index > 20)
				return 0
			mid := Floor((low + high) / 2)
			if ((ObjHasValue(colors, Gdip_GetPixel(pBMScreen, x + this.WarnProfiles[buffName].x, mid))))
				high := mid
			else
				low := mid + 1
		}

		raw := Round((bottomY - low) / 38 * 100, 2) + 2

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
}
