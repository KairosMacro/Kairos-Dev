class MainGui {
	Selectors := Map()
	Gui := unset
	FeatureList := ["Warns", "Boost Bar", "Alt Macro", "Key Alignment", "Passive Scanner", "Magnifier"]

	__New() {
		this.Gui := Gui((Config.Get("Main", "AlwaysOnTop", 0) ? "+AlwaysOnTop " : "") " +Border +OwnDialogs", "Kairos")
		this.Gui.Show("x" Config.Get("Main", "GuiX", A_ScreenWidth // 2 - 200) " y" Config.Get("Main", "GuiY", A_ScreenHeight // 2 - 100) " w400 h220")
		this.FeatureRefreshers := Map(
			"BoostBarEnabled", () => (IsSet(Boost) && Boost) ? Boost.RefreshConfig() : 0,
			"WarnsEnabled", () => (IsSet(Warns) && Warns) ? Warns.RefreshConfig() : 0,
			"PassiveScannerEnabled", () => (IsSet(Scorch) && Scorch) ? Scorch.RefreshConfig() : 0
		)

		; General UI
		this.Gui.OnEvent("Close", (*) => ExitApp())
		this.Gui.SetFont("s8 cDefault Norm")
		(GuiCtrl := this.Gui.Add("Text", "x400 y205 w90 -Wrap +BackgroundTrans", "v" version)), GuiCtrl.Move(396 - (TextWidth := this.TextExtend("v" version, GuiCtrl)))
		this.Gui.Add("Button", "x5 y198 w65 h20 -Wrap vStartButton", "Start (" Config.Get("Main", "StartHotkey", "F1") ")").OnEvent("Click", this.start.Bind(this))
		this.Gui.Add("Button", "x75 y198 w65 h20 -Wrap vPauseButton", "Pause (" Config.Get("Main", "PauseHotkey", "F2") ")").OnEvent("Click", this.pause.Bind(this))
		this.Gui.Add("Button", "x145 y198 w65 h20 -Wrap vStopButton", "Stop (" Config.Get("Main", "StopHotkey", "F3") ")").OnEvent("Click", this.stop.Bind(this))

		TabArr := ["Main", "Alt", "Warnings", "Boost Bar", "Alt", "Key Alignment", "Communicator", "Misc"]
		(TabCtrl := this.Gui.Add("Tab", "x0 y-1 w440 h240 -Wrap " (Config.Get("Main", "DarkMode", 1) ? "cFFFFFF" : "C000000"), TabArr)).OnEvent("Change", (*) => TabCtrl.Focus())
		SendMessage 0x1331, 0, 20, , TabCtrl
		; --- Main Tab ---
		TabCtrl.UseTab("Main")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y20 w110 h145 -Wrap", "")
		this.Gui.Add("Text", "x20 y22 w85 h20 -Wrap", "Main Features")
		this.Gui.SetFont("s8 cDefault Norm")
		for i in this.FeatureList {
			name := StrReplace(i, " ", "") "Enabled"
			isEnabled := Config.Get("Main", name, 0)
			(GuiCtrl := this.Gui.Add("CheckBox", "x15 y" 40 + (20 * (A_Index - 1)) " w20 h20 -Wrap v" name " Checked" isEnabled, "")).Section := "Main", GuiCtrl.OnEvent("Click", this.ToggleFeature.Bind(this))
			this.Gui.Add("Text", "x35 y" 43 + (20 * (A_Index - 1)) " w80 h20 -Wrap", i)
		}
		; --- Warnings Tab ---
		TabCtrl.UseTab("Warnings")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y35 w180 h140 -Wrap", "")
		this.Gui.Add("Text", "x20 y36 w103 h20 -Wrap", "Precision Settings")

		this.Gui.Add("Text", "x15 y65", "Threshold:")
		this.Gui.Add("Edit", "x76 y62 w50 Number vWarns_StartWarn", Config.Get("Warns", "StartWarn", 25)).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("UpDown", "Range0-60", Config.Get("Warns", "StartWarn", 25))
		this.Gui.Add("Text", "x+5 yp+3", "Seconds")

		this.Gui.Add("Text", "x15 y95", "Volume:")
		this.Gui.Add("Edit", "x61 y92 w50 Number vWarns_Volume", Config.Get("Warns", "Volume", 25)).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("UpDown", "Range0-100", Config.Get("Warns", "Volume", 25))
		this.Gui.Add("Text", "x+5 yp+3", "%")

		this.Gui.Add("Text", "x15 y123", "Sound:")
		this.Gui.Add("Button", "x+5 y119 w60 h20", "Browse").OnEvent("Click", this.SelectSound.Bind(this))
		this.Gui.Add("Button", "xp+60 yp w60 h20 vWarns_ResetSoundFile", "Test").OnEvent("Click", this.TestAudio.Bind(this))
		this.Gui.Add("Edit", "x15 y140 w170 h20 ReadOnly vWarns_SoundFile", Config.Get("Warns", "SoundFile", "C:\Windows\Media\Windows Critical Stop.wav"))

		; --- Boost Bar Tab ---
		TabCtrl.UseTab("Boost Bar")
		this.Gui.Add("Text", "x20 y35 w40", "Active")
		this.Gui.Add("Text", "x75 y35 w60", "Timer(s)")
		this.Gui.Add("Text", "x130 y35 w80", "Mode(s)")

		loop 7 {
			yPos := 55 + ((A_Index - 1) * 20)
			i := A_Index

			this.Gui.Add("Text", "x10 y" yPos " w36 -Wrap", "Slot " i ":")
			this.Gui.Add("CheckBox", "x50 y" yPos - 2 " w20 h20 vBoostBar_SlotActive" i " Checked" Config.Get("BoostBar", "SlotActive" i)).OnEvent("Click", this.SaveConfig.Bind(this))
			this.Gui.Add("Edit", "x75 y" yPos - 3 " w50 h20 Number vBoostBar_SlotTimer" i, Config.Get("BoostBar", "SlotTimer" i)).OnEvent("Change", this.SaveConfig.Bind(this))

			currentModes := Config.Get("BoostBar", "SlotMode" i, "Timer")
			display := currentModes = "" ? "None" : (StrSplit(currentModes, "|").Length > 1 ? "Multiple" : currentModes)

			btn := this.Gui.Add("Button", "x130 y" yPos - 3 " w70 h21 vBoostBar_Config" i, display)
			btn.OnEvent("Click", this.OpenModeSelector.Bind(this, i, btn))
		}

		; --- Alt Tab ---
		TabCtrl.UseTab("Alt")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y35 w185 h150")
		this.Gui.Add("Text", "x20 y36", "Alt Settings")
		this.Gui.SetFont("s8 cDefault Norm")
		this.Gui.SetFont("s8 w400")

		this.Gui.Add("Text", "x20 y58", "MoveSpeed:")
		this.Gui.Add("Edit", "x95 y55 w60 h20 vAlt_Movespeed", Config.Get("Alt", "Movespeed", 29)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x20 y88", "Hive Slot:")
		this.Gui.Add("Edit", "x95 y85 w60 h20 vAlt_HiveSlot", Config.Get("Alt", "HiveSlot", 1)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x205 y35 w185 h150")
		this.Gui.Add("Text", "x215 y36", "Field Settings")
		this.Gui.SetFont("s8 cDefault Norm")

		this.Gui.Add("Text", "x215 y58", "Field:")
		fieldArr := ["sunflower", "dandelion", "mushroom", "blueflower", "clover", "strawberry", "spider", "bamboo", "pineapple", "stump", "cactus", "pumpkin", "pinetree", "rose", "mountaintop", "pepper", "coconut"]
		(GuiCtrl := this.Gui.Add("DropDownList", "x255 y55 w100 vAlt_DefaultField Choose" ObjIndexOf(fieldArr, Config.Get("Alt", "DefaultField", "pepper")), fieldArr)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x215 y88", "Pattern:")
		this.Gui.Add("DropDownList", "x270 y85 w110 vAlt_Pattern Choose" ObjIndexOf(patternList, Config.Get("Alt", "Pattern", "GeneralBooster")), patternList).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x215 y115", "Size:")
		this.Gui.Add("Edit", "x240 y115 w40 h20 Number vAlt_PatternSize", Config.Get("Alt", "PatternSize"))
		this.Gui.Add("UpDown", "Range1-10", Config.Get("Alt", "PatternSize"))

		; --- Communicator Tab ---
		TabCtrl.UseTab("Communicator")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y35 w380 h150")
		this.Gui.Add("Text", "x20 y36", "Connection Settings")
		this.Gui.SetFont("s8 cDefault Norm")

		this.Gui.Add("Text", "x25 y60 w350 h30", "Both the Main and Alt must have the EXACT same 'Channel' name for this to work.")
		this.Gui.Add("Text", "x25 y93", "Channel Name:")
		(GuiCtrl := this.Gui.Add("Edit", "x110 y90 w180 h20 vCommunicator_DweetName", Config.Get("Communicator", "DweetName", "you might wanna change this..."))).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("Button", "x300 y90 w80 h20", "Generate").OnEvent("Click", this.GenerateUser.Bind(this))
		this.Gui.Add("Text", "x25 y130 w80", "Status:")
		role := Config.Get("Main", "AltMacroEnabled", 0) ? "Client" : "Server"
		this.Gui.Add("Text", "x110 y130 w200 vCommsStatus", role)

		; --- Key Alignment Tab ---

		; --- Dark Mode ---
		SetWindowTheme(this.Gui, Config.Get("Main", "DarkMode", 1))
		SetWindowAttribute(this.Gui, Config.Get("Main", "DarkMode", 1))
		this.RegisterHotkeys()
	}

	GenerateUser(GuiCtrl, *) {
		name := "K" Random(10000000, 99999999) "X" Random(10000000, 99999999)
		this.Gui["Communicator_DweetName"].Value := name
		Config.Set("Communicator", "DweetName", name)
		Config.WriteIni()
		if IsSet(Comms)
			Comms.UpdateSettings()
	}

	OpenModeSelector(index, GuiCtrl*) {
		static ModeGui := ""
		GuiClose(*) {
			if (IsSet(ModeGui) && IsObject(ModeGui))
				try ModeGui.Destroy(), ModeGui := ""
		}
		GuiClose()
		currentConfig := Config.Get("BoostBar", "SlotMode" index, "Timer")

		ModeGui := Gui("+Owner" this.Gui.Hwnd " +AlwaysOnTop +Border +ToolWindow", "Slot " index)
		ModeGui.SetFont("s8 cDefault Norm", "Tahoma")
		ModeGui.OnEvent("Close", (*) => GuiClose)

		UpdateConfig(*) {
			savedList := []
			for mode, ctrl in CheckBoxes {
				if (ctrl.Value)
					savedList.Push(mode)
			}

			saveString := ""
			for item in savedList
				saveString .= (A_Index > 1 ? "|" : "") item
			Config.Set("BoostBar", "SlotMode" index, saveString)
			Config.WriteIni()

			count := savedList.Length
			this.Gui["BoostBar_Config" index].Text := (count = 0) ? "None" : (count > 1 ? "Multiple" : saveString)

			if IsSet(Boost) && Boost
				Boost.Draw()
		}

		CheckBoxes := Map()
		ModeList := []
		for i in ["Timer", "ReGlitter", "On Scorch", "ReSmoothie", "On Pop Star", "On Baller", "On Shower", "On Gummy"]
			ModeList.Push(i)

		Columns := 2
		Margin := 10

		for index, modeName in ModeList {
			i := A_Index - 1
			col := Mod(i, Columns)
			row := Floor(i / Columns)
			isChecked := InStr("|" currentConfig "|", "|" modeName "|")
			x := Margin + (col * 100)
			y := Margin + (row * 25)
			cb := ModeGui.Add("CheckBox", "x" x " y" y " w20 h20 Checked" isChecked)
			cb.OnEvent("Click", UpdateConfig.Bind(this))
			ModeGui.Add("Text", "x" x + 20 " y" y + 3 " w100 h20 c" (Config.Get("Main", "DarkMode", 1) ? "White" : "Black"), modeName)
			CheckBoxes[modeName] := cb
		}
		TotalRows := Ceil(ModeList.Length / Columns)
		MinWidth := (Margin * 2) + (Columns * 100)
		MinHeight := (Margin * 2) + (TotalRows * 25)
		ModeGui.Show("w" MinWidth " h" MinHeight)
		SetWindowTheme(ModeGui, Config.Get("Main", "DarkMode", 1))
		SetWindowAttribute(ModeGui, Config.Get("Main", "DarkMode", 1))
	}

	TestAudio(GuiCtrl, *) {
		soundPath := Config.Get("Warns", "SoundFile", "C:\Windows\Media\Windows Critical Stop.wav")
		if !FileExist(soundPath) {
			soundPath := "C:\Windows\Media\Windows Critical Stop.wav"
		}
		this.AudioPlayer := unset
		this.AudioPlayer := Audio(soundPath)
		vol := Config.Get("Warns", "Volume", 25)
		this.AudioPlayer.Play(vol)
	}

	ToggleFeature(GuiCtrl, *) {
		isChecked := GuiCtrl.Value
		FeatureName := GuiCtrl.Name
		Config.Set("Main", FeatureName, isChecked)
		Config.WriteIni()
		this.RefreshFeature(FeatureName)
	}

	SaveConfig(GuiCtrl, *) {
		Split := StrSplit(GuiCtrl.Name, "_")
		if (Split.Length != 2)
			return
		Section := Split[1]
		Key := Split[2]

		val := (GuiCtrl.Type = "DDL") ? GuiCtrl.Text : GuiCtrl.Value
		Config.Set(Section, Key, val)
		Config.WriteIni()

		if (Section = "BoostBar")
			this.RefreshFeature("BoostBarEnabled")
		else if (Section = "Warns")
			this.RefreshFeature("WarnsEnabled")
		else if (Section = "PassiveScanner")
			this.RefreshFeature("PassiveScannerEnabled")
		else if (Section = "Main" && (Key = "BoostBarEnabled" || Key = "WarnsEnabled" || Key = "PassiveScannerEnabled"))
			this.RefreshFeature(Key)
		else if (Section = "Communicator")
			if IsSet(Comms)
				Comms.UpdateSettings()
		else if (Key = "AltMacroEnabled") {
			role := val ? "Client" : "Server"
			try this.Gui["CommsStatus"].Text := role
				if IsSet(Comms)
					Comms.UpdateSettings()
		}

		if (Key = "DarkMode") {
			SetWindowTheme(this.Gui, GuiCtrl.Value)
			SetWindowAttribute(this.Gui, GuiCtrl.Value)
		}

		if (Key ~= "SlotTimer") {
			if IsSet(Boost) && Boost
				Boost.Draw()
		}
	}

	RefreshFeature(FeatureName) {
		if (this.FeatureRefreshers.Has(FeatureName))
			this.FeatureRefreshers[FeatureName]()
	}

	SelectSound(GuiCtrl, *) {
		SelectedFile := FileSelect(1, , "Select Sound File", "Audio (*.wav; *.mp3)")
		if SelectedFile {
			this.Gui["Warns_SoundFile"].Value := SelectedFile
			Config.Set("Warns", "SoundFile", SelectedFile)
			Config.WriteIni()
		}
	}

	TextExtend(text, textCtrl) {
		hDC := DllCall("GetDC", "Ptr", textCtrl.Hwnd, "Ptr")
		hFold := DllCall("SelectObject", "Ptr", hDC, "Ptr", SendMessage(0x31, , , textCtrl), "Ptr")
		nSize := Buffer(8)
		DllCall("GetTextExtentPoint32", "Ptr", hDC, "Str", text, "Int", StrLen(text), "Ptr", nSize)
		DllCall("SelectObject", "Ptr", hDC, "Ptr", hFold)
		DllCall("ReleaseDC", "Ptr", textCtrl.Hwnd, "Ptr", hDC)
		return NumGet(nSize, 0, "UInt")
	}

	start(*) {
		static ran := 0
		if ran
			return
		ran++
		State.offsetY := GetYOffset(, &fail)
		if fail
			msgbox "Failed to get y-Offset, this either means`n1. Your font is NOT the default size (e.g. font scale or broken roblox updates)`n2. Your font is wrong (e.g. custom font w/bloxstrap)`n3. the 'Pollen' text at the top is being covered`n4. Graphical issues`n5. I made a mistake...`n6. You don't have roblox open.", "Kairos", 16
		Scorch.Toggle()
		Warns.Toggle()
		Boost.Toggle()
		Alt.Toggle()
		Aligner.Toggle()
		Mag.Toggle()
		this.Gui.Show("Hide")
	}

	pause(*) {
		static keyMap := Map("left", 0, "right", 0, "fwd", 0, "back", 0)
		DetectHiddenWindows true
		isPausing := !A_IsPaused

		this.Gui.Show(isPausing ? "" : "Hide")
		if WinExist("ahk_class AutoHotkey ahk_pid " State.currentWalk.pid) {
			Send "{F16}"
		}

		DetectHiddenWindows false
		Pause -1
	}

	stop(*) {
		Reload
	}

	RegisterHotkeys() {
		try {
			Hotkey(Config.Get("Main", "StartHotkey", "F1"), (*) => this.start())
			Hotkey(Config.Get("Main", "PauseHotkey", "F2"), (*) => this.pause())
			Hotkey(Config.Get("Main", "StopHotkey", "F3"), (*) => this.stop())
		}
	}
}
