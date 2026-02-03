class AltMacro {
	IsRunning := false
	IsActive := false

	__New() {
		importPaths()
		importPatterns()

		this.Settings()
		this.Fancy := GdipTooltip()
	}

	Settings() {
		this.HiveSlot := Config.Get("Alt", "HiveSlot", 1)
		this.Movespeed := Config.Get("Alt", "Movespeed", 36.68)
		this.AltNumber := Config.Get("Alt", "AltNumber", 1)
		this.FieldDriftComp := Config.Get("Alt", "FieldDriftComp", 1)
		this.DefaultField := Config.Get("Alt", "DefaultField", "pepper")
		this.Pattern := Config.Get("Alt", "Pattern", "GeneralBooster")

		this.PatternSize := Config.Get("Alt", "PatternSize", 5)
		this.PatternWidth := Config.Get("Alt", "PatternWidth", 5)
		this.RotationAmount := Config.Get("Alt", "RotationAmount", 0)
		this.RotationDirection := Config.Get("Alt", "RotationDirection", "right")
		this.ShiftLock := Config.Get("Alt", "ShiftLock", 0)
		this.SprinklerLocation := Config.Get("Alt", "SprinklerLocation", "Center")
		this.SprinklerDistance := Config.Get("Alt", "SprinklerDistance", 1)
	}

	Toggle() {
		this.IsRunning ^= 1
		this.IsActive := this.IsRunning && Config.Get("Main", "AltMacroEnabled", 0)
		if (this.IsActive) {
			this.Fancy.Show("Alt Macro: ON")
			ActivateRoblox()
			SetTimer(() => this.Fancy.Hide(), -500)
			SetTimer(this.MainLoop.Bind(this), 1000)
		} else {
			if Config.Get("Main", "AltMacroEnabled", 0)
				this.Fancy.Show("Alt Macro: OFF")
			SetTimer(() => this.Fancy.Hide(), -500)
			SetTimer(this.MainLoop.Bind(this), 0)
			this.Cleanup()
		}
	}

	MainLoop() {
		if !this.IsRunning
			return

		local inactiveHoney := 0
		this.Settings()
		this.Reset()
		fieldName := this.DefaultField
		this.GotoField(fieldName)
		send "{" SC_1 "}"
		sleep 500

		loop {
			MouseMove windowX + (windowWidth // 2), windowY + (windowHeight // 2)
			click "down"
			if !this.IsRunning {
				click "up"
				break
			}

			this.Gather(this.Pattern, fieldName, A_Index)

			while ((GetKeyState("F14") && (A_Index <= 3600)) || (A_Index = 1)) {
				if !this.IsRunning || this.IsDead() = true {
					click "up"
					break 2
				}

				if (Mod(A_Index, 10) = 0) {
					if (!this.ActiveHoney()) {
						if (++inactiveHoney >= 5) {
							click "up"
							break 2
						}
					} else
						inactiveHoney := 0
				}
				sleep 50
			}
			click "up"

			if (this.FieldDriftComp)
				FieldDriftCompensation()
		}
		this.Cleanup()
		sleep 500
	}

	Gather(patternName, field, index) {
		if !this.IsRunning
			return
		if !patterns.Has(patternName) {
			this.Fancy.Show("Pattern '" patternName "' does not exist!")
			return
		}

		DetectHiddenWindows true
		pathRunning := WinExist("ahk_class AutoHotkey ahk_pid " State.CurrentWalk.pid)
		if ((index = 1) || !pathRunning) {
			RunPath(patterns[patternName], "pattern", PatternVars(field))
		} else {
			Send "{F13}"
		}

		DetectHiddenWindows false
		if (KeyWait("F14", "D T5 L") = 0)
			EndPath()
	}

	GotoField(fieldName) {
		if !this.IsRunning
			return
		Send "{" LeftKey " up}{" RightKey " up}{" FwdKey " up}{" BackKey " up}{" SC_Space " up}{" SC_E " up}"
		field := StrReplace(fieldName, " ")
		if !paths["gtf"].Has(field) {
			MsgBox "Path not found: gtf-" field ".ahk"
			return
		}

		RunPath(paths["gtf"][field], , PathVars())
		KeyWait "F14", "D T5 L"
		KeyWait "F14", "T120 L"
		EndPath()
		sleep 100
	}

	Cleanup() {
		Critical
		EndPath()
		Click "up"
		Send "{" LeftKey " up}{" RightKey " up}{" FwdKey " up}{" BackKey " up}{" SC_Space " up}{F14 up}{" SC_E " up}"
	}

	ClaimHive() {

	}

	Reset() {
		static HiveDown := false
		local HiveConfirmed := false
		while (!HiveConfirmed) {
			ActivateRoblox()
			GetRobloxClientPos()
			PrevKeyDelay := A_KeyDelay
			SetKeyDelay(300)
			send "{" SC_Esc "}{" SC_R "}{" SC_Enter "}"
			n := 0
			while ((n < 2) && (A_Index <= 70)) {
				sleep 100
				pBMScreen := Gdip_BitmapFromScreen(windowX "|" windowY "|" windowWidth "|50")
				n += ((Gdip_ImageSearch(pBMScreen, bitmaps["emptyhealth"], , , , , , 10) || this.HealthBar()) = (n = 0))
				Gdip_DisposeImage(pBMScreen)
			}
			sleep 500

			if not this.atHive() {
				continue
			}

			if (HiveConfirmed = 0) {
				if (HiveDown)
					sendinput "{" RotDown "}"
				region := windowX "|" windowY + 3 * windowHeight // 4 "|" windowWidth "|" windowHeight // 4
				sconf := windowWidth ** 2 // 3200
				loop 4 {
					sleep 250
					pBMScreen := Gdip_BitmapFromScreen(region), s := 0
					for i, k in bitmaps["hive"] {
						s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 4, , , sconf))
						if (s >= sconf) {
							Gdip_DisposeImage(pBMScreen)
							HiveConfirmed := 1
							sendinput "{" RotRight " 4}" (HiveDown ? ("{" RotUp "}") : "")
							Send "{" ZoomOut " 5}"
							break 2
						}
					}
					Gdip_DisposeImage(pBMScreen)
					sendinput "{" RotRight " 4}" ((A_Index = 2) ? ("{" ((HiveDown := !HiveDown) ? RotDown : RotUp) "}") : "")
				}
			}
		}
	}

	HealthBar() {
		local detection := 0

		static isDead(c) => ((((c) & 0x00FF0000 >= 0x004D0000) && ((c) & 0x00FF0000 <= 0x00830000)) ; 4D4D4D-blackBG|838383-whiteBG
			&& (((c) & 0x0000FF00 >= 0x00004D00) && ((c) & 0x0000FF00 <= 0x00008300))
			&& (((c) & 0x000000FF >= 0x0000004D) && ((c) & 0x000000FF <= 0x00000083)))
		try {
			GetRobloxClientPos(hwnd := GetRobloxHWND())
			pBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth - 100 "|" windowY + State.offsetY "|50|24")

			p := Gdip_GetPixel(pBMScreen, 25, 12)
			if isDead(p)
				detection := 1
		} catch
			return 0
		finally
			Gdip_DisposeImage(pBMScreen)
		return detection
	}

	atHive() {
		static fail := 0
		ActivateRoblox()
		GetRobloxClientPos()
		pBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 - 150 "|" windowY + State.offsetY + 40 "|350|60")
		out := Gdip_ImageSearch(pBMScreen, bitmaps["colhey"], , , , , , 5)
		Gdip_DisposeImage(pBMScreen)
		fail := out = 1 ? 0 : fail + 1
		if fail > 3 {
			fail := 0
			return 1
		}
		return out
	}

	DetectSpawn() { ; some of the code was from hive check, repurposing it here since it seems to reliably detect hive slots even when the stuff is really bad
		ActivateRoblox()
		GetRobloxClientPos()
		loop 5
			send("{" ZoomIn "}"), sleep(50)
		send("{" RotDown " 11}"), sleep(100), send("{" RotUp " 5}")
		region := windowX "|" windowY "|" windowWidth "|" windowHeight // 4
		sconf := windowWidth ** 2 // 3200
		spawnConfirmed := 0
		loop 4 {
			sleep 250
			pBMScreen := Gdip_BitmapFromScreen(region), s := 0
			for i, k in bitmaps["spawn"] {
				s := Max(s, Gdip_ImageSearch(pBMScreen, k, , , , , , 5, , , sconf))
				if (s >= sconf) {
					Gdip_DisposeImage(pBMScreen)
					spawnConfirmed := 1
					Send "{" RotUp " 2}"
					loop 5
						send("{" ZoomOut "}"), sleep(50)
					break 2
				}
			}
			Gdip_DisposeImage(pBMScreen)
			sendinput "{" RotRight " 4}"
		}
		return spawnConfirmed
	}

	ActiveHoney() {
		static a := unset
		if !IsSet(a)
			a := Gdip_CreateBitmap(1, 1), pGraphics := Gdip_GraphicsFromImage(a), Gdip_GraphicsClear(pGraphics, 0xFFFFE280), Gdip_DeleteGraphics(pGraphics)

		if !GetRobloxClientPos()
			return false

		pBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 - 90 "|" windowY + State.offsetY "|70|34")
		if (Gdip_ImageSearch(pBMScreen, a, , , , , , 20) > 0) {
			Gdip_DisposeImage(pBMScreen)
			return true
		}

		Gdip_DisposeImage(pBMScreen)
		return false
	}

	isDead() {
		static LastDeath := 0
		if ((nowUnix() - LastDeath) < 5)
			return true

		pBMScreen := Gdip_BitmapFromScreen(windowX + windowWidth // 2 "|" windowY + windowHeight // 2 "|" windowWidth // 2 "|" windowHeight // 2)
		if (Gdip_ImageSearch(pBMScreen, bitmaps["died"], , , , , , 50) = 1) {
			Gdip_DisposeImage(pBMScreen)
			LastDeath := nowUnix()
			return true
		}
		Gdip_DisposeImage(pBMScreen)
		return false
	}
}
