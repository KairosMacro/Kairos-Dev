class KeyAlignment {
	IsRunning := false
	IsActive := false
	IsRebinding := false
	IsActionRunning := false

	Width := 140
	Height := 30

	CurrentKey := "e"
	RebindHotkey := "^+k"

	__New() {
		this.CurrentKey := Config.Get("KeyAlignment", "AlignmentKey", "e")

		this.Gui := Gui("-Caption +E0x80000 +E0x20 +AlwaysOnTop +ToolWindow +OwnDialogs", "Key Alignment")
		r := WinExist("ahk_exe RobloxPlayerBeta.exe")
		xPos := r ? windowX + windowWidth - this.Width : A_ScreenWidth - this.Width
		yPos := r ? windowY : 32
		Config.Get("Main", "KeyAlignmentEnabled", 0) ? this.Gui.Show("NA x" xPos " y" yPos) : this.Gui.Hide()
		this.hbm := CreateDIBSection(this.Width, this.Height)
		this.hdc := CreateCompatibleDC()
		this.obm := SelectObject(this.hdc, this.hbm)
		this.G := Gdip_GraphicsFromHDC(this.hdc)
		Gdip_SetSmoothingMode(this.G, 4)

		SetTimer(this.FollowWindow.Bind(this), 10)

		Hotkey(this.RebindHotkey, (*) => this.StartRebind(), "On")

		this.Draw()
	}

	FollowWindow() {
		try {
			if hwnd := WinExist("Roblox ahk_exe RobloxPlayerBeta.exe") {
				WinGetClientPos(&wx, &wy, &ww, &wh, "ahk_id " hwnd)
				targetX := wx + ww - this.Width
				targetY := wy
				Config.Get("Main", "KeyAlignmentEnabled", 0) ? this.Gui.Show("NA x" targetX " y" targetY " w" this.Width " h" this.Height) : this.Gui.Hide()
			} else {
				this.Gui.Hide()
			}
		}
	}

	Toggle() {
		this.IsRunning ^= 1
		this.IsActive := this.IsRunning && Config.Get("Main", "KeyAlignmentEnabled", 0)
		if (this.IsActive) {
			this.Draw()
			this.RegisterActionHotkey(true)
		} else {
			this.Draw()
			this.RegisterActionHotkey(false)
		}
	}

	RegisterActionHotkey(State) {
		try {
			if (State)
				Hotkey(this.CurrentKey, (*) => this.PerformAction(), "On")
			else
				Hotkey(this.CurrentKey, "Off")
		}
	}

	PerformAction() {
		if (this.IsRebinding || this.IsActionRunning || !this.IsRunning)
			return

		this.IsActionRunning := true
		wasRightClick := GetKeyState("RButton", "P")
		if (wasRightClick)
			Click("up", "R")
		Send "{" RotRight "}"
		sleep 6
		Send "{" RotLeft "}"
		if (wasRightClick)
			Click("down", "R")
		this.IsActionRunning := false
	}

	StartRebind() {
		if this.IsRunning
			return

		this.IsRebinding := true
		this.Draw("Rebinding...")
		this.RegisterActionHotkey(false)

		ih := InputHook("L1 T3", "{Escape}")
		ih.Start()
		ih.Wait()

		if (ih.EndReason = "Max") {
			this.CurrentKey := ih.Input
			Config.Set("KeyAlignment", "AlignmentKey", this.CurrentKey)
			Config.WriteIni()
		}

		this.IsRebinding := false
		this.RegisterActionHotkey(true)
		this.Draw()
	}

	Draw(CustomText := "") {
		Gdip_GraphicsClear(this.G)

		cBack := Gdip_BrushCreateSolid(0xb31E1E1E)
		cBorder := Gdip_BrushCreateSolid(0xFF333333)
		cText := 0xFFFFFFFF
		cAccent := this.IsRebinding ? 0xFFFFA500 : this.IsRunning ? 0xFF4CAF50 : 0xFFD32F2F

		Gdip_FillRoundedRectangle(this.G, cBack, 0, 0, this.Width, this.Height, 5)

		cInd := Gdip_BrushCreateSolid(cAccent)
		Gdip_FillRoundedRectangle(this.G, cInd, 5, 5, 5, 20, 2)
		Gdip_DeleteBrush(cInd)

		DisplayText := (CustomText != "" ? CustomText : "Align Key: " this.CurrentKey)
		Options := "x15 y6 w" (this.Width - 20) " h" this.Height " Left c" Format("{:08X}", cText) " s11 Bold"
		Gdip_TextToGraphics(this.G, DisplayText, Options, "Segoe UI")

		Gdip_DeleteBrush(cBack)
		Gdip_DeleteBrush(cBorder)

		UpdateLayeredWindow(this.Gui.Hwnd, this.hdc, , , this.Width, this.Height)
	}

	Cleanup() {
		SelectObject(this.hdc, this.obm)
		DeleteObject(this.hbm)
		DeleteDC(this.hdc)
		Gdip_DeleteGraphics(this.G)
		this.Gui.Destroy()
	}
}
