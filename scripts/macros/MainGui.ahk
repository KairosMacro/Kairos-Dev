class MainGui {
	Selectors := Map()
	Gui := unset
	FeatureList := ["Warns", "Boost Bar", "Alt Macro", "Key Alignment", "Tracker", "Magnifier", "StatMonitor"]
	FwdDown := false
	BackDown := false
	LeftDown := false
	RightDown := false
	ran := 0
	__New() {
		this.Gui := Gui((Config.Get("Main", "AlwaysOnTop", 0) ? "+AlwaysOnTop " : "") " +Border +OwnDialogs", "Kairos")
		this.Gui.Show("x" Config.Get("Main", "GuiX", A_ScreenWidth // 2 - 200) " y" Config.Get("Main", "GuiY", A_ScreenHeight // 2 - 100) " w400 h220")
		this.FeatureRefreshers := Map(
			"BoostBarEnabled", () => (IsSet(Boost) && Boost) ? Boost.RefreshConfig() : 0,
			"WarnsEnabled", () => (IsSet(Warns) && Warns) ? Warns.RefreshConfig() : 0,
			"TrackerEnabled", () => (IsSet(Track) && Track) ? Track.RefreshConfig() : 0
		)

		; General UI
		this.Gui.OnEvent("Close", (*) => ExitApp())
		this.Gui.SetFont("s8 cDefault Norm")
		(GuiCtrl := this.Gui.Add("Text", "x400 y205 w90 -Wrap +BackgroundTrans", "v" version)), GuiCtrl.Move(396 - (TextWidth := this.TextExtend("v" version, GuiCtrl)))
		this.Gui.Add("Button", "x5 y198 w65 h20 -Wrap vStartButton", "Start (" Config.Get("Main", "StartHotkey", "F1") ")").OnEvent("Click", this.start.Bind(this))
		this.Gui.Add("Button", "x75 y198 w65 h20 -Wrap vPauseButton", "Pause (" Config.Get("Main", "PauseHotkey", "F2") ")").OnEvent("Click", this.pause.Bind(this))
		this.Gui.Add("Button", "x145 y198 w65 h20 -Wrap vStopButton", "Stop (" Config.Get("Main", "StopHotkey", "F3") ")").OnEvent("Click", this.stop.Bind(this))

		TabArr := ["Main", "Alt", "Tracker", "Warnings", "Boost Bar", "Communicator", "Key Alignment"]
		(TabCtrl := this.Gui.Add("Tab", "x0 y-1 w440 h240 -Wrap " (Config.Get("Main", "DarkMode", 1) ? "cFFFFFF" : "C000000"), TabArr)).OnEvent("Change", (*) => TabCtrl.Focus())
		SendMessage 0x1331, 0, 20, , TabCtrl
		; --- Main Tab ---
		TabCtrl.UseTab("Main")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y20 w110 h165 -Wrap", "")
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
		this.Gui.Add("GroupBox", "x10 y20 w265 h130 -Wrap", "")
		this.Gui.Add("Text", "x20 y22 w103 h20 -Wrap", "Warning Settings")
		this.Gui.SetFont("s8 cDefault Norm")

		this.Gui.Add("Text", "x45 y35 w80", "Active")
		this.Gui.Add("Text", "x130 y35 w60", "Threshold")
		this.Gui.Add("Text", "x200 y35 w70", "Audio/Misc")

		WarnItems := [
			["Precise", "Precision"]
			, ["SuperSmoothie", "Super Smoothie"]
		]

		yPos := 55
		for item in WarnItems {
			key := item[1]
			name := item[2]
			this.Gui.Add("CheckBox", "x20 y" yPos " w20 h20 vWarns_" key "_Enabled Checked" Config.Get("Warns", key "_Enabled", 0)).OnEvent("Click", this.SaveConfig.Bind(this))
			this.Gui.Add("Text", "x40 y" yPos + 3 " w80", name)

			this.Gui.Add("Edit", "x130 y" yPos " w50 h20 Number vWarns_" key "_Threshold", Config.Get("Warns", key "_Threshold", 25)).OnEvent("Change", this.SaveConfig.Bind(this))
			this.Gui.Add("Text", "x185 y" yPos + 3 " w20", "s")

			btn := this.Gui.Add("Button", "x200 y" yPos " w60 h22", "Settings")
			btn.OnEvent("Click", this.OpenWarnSettings.Bind(this, key, name))
			yPos := yPos + 30
		}

		; --- Boost Bar Tab ---
		TabCtrl.UseTab("Boost Bar")
		this.Gui.Add("Text", "x20 y25 w40", "Active")
		this.Gui.Add("Text", "x75 y25 w60", "Timers")
		this.Gui.Add("Text", "x130 y25 w80", "Modes")

		loop 7 {
			yPos := 45 + ((A_Index - 1) * 20)
			i := A_Index

			this.Gui.Add("Text", "x10 y" yPos " w36 h20 -Wrap", "Slot " i ":")
			this.Gui.Add("CheckBox", "x50 y" yPos - 2 " w20 h20 vBoostBar_SlotActive" i " Checked" Config.Get("BoostBar", "SlotActive" i, 0)).OnEvent("Click", this.SaveConfig.Bind(this))
			this.Gui.Add("Edit", "x75 y" yPos - 3 " w50 h20 Number vBoostBar_SlotTimer" i, Config.Get("BoostBar", "SlotTimer" i, 100)).OnEvent("Change", this.SaveConfig.Bind(this))

			currentModes := Config.Get("BoostBar", "SlotMode" i, "Timer")
			display := currentModes = "" ? "None" : (StrSplit(currentModes, "|").Length > 1 ? "Multiple" : currentModes)

			btn := this.Gui.Add("Button", "x130 y" yPos - 3 " w70 h21 vBoostBar_Config" i, display)
			btn.OnEvent("Click", this.OpenModeSelector.Bind(this, i, btn))
		}

		this.Gui.Add("Text", "x290 y25", "Show when active")
		this.Gui.Add("CheckBox", "x270 y22 w20 h20 vBoostBar_ShowWhenActive Checked" Config.Get("BoostBar", "ShowWhenActive", 1)).OnEvent("Click", this.SaveConfig.Bind(this))

		; --- Alt Tab ---
		TabCtrl.UseTab("Alt")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y20 w185 h170")
		this.Gui.Add("Text", "x20 y22", "Alt Settings")
		this.Gui.SetFont("s8 cDefault Norm")
		this.Gui.SetFont("s8 w400")

		this.Gui.Add("Text", "x20 y45", "MoveSpeed:")
		this.Gui.Add("Edit", "x95 y42 w60 h20 vAlt_Movespeed", Config.Get("Alt", "Movespeed", 29)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x20 y70", "Hive Slot:")
		this.Gui.Add("Edit", "x95 y68 w60 h20 vAlt_HiveSlot", Config.Get("Alt", "HiveSlot", 1)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x20 y95", "Alt Number:")
		this.Gui.Add("Edit", "x95 y92 w40 h20 Number vAlt_AltNumber", Config.Get("Alt", "AltNumber", 1)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x40 y120", "Shift Lock")
		this.Gui.Add("CheckBox", "x20 y117 w20 h20 vAlt_ShiftLock Checked" Config.Get("Alt", "ShiftLock", 0)).OnEvent("Click", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x120 y120", "Drift Comp")
		this.Gui.Add("CheckBox", "x100 y117 w20 h20 vAlt_FieldDriftComp Checked" Config.Get("Alt", "FieldDriftComp", 1)).OnEvent("Click", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x40 y143", "Claim Hive")
		this.Gui.Add("CheckBox", "x20 y140 w20 h20 vAlt_ClaimHive Checked" Config.Get("Alt", "ClaimHive", 1)).OnEvent("Click", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x120 y143", "Ignore Inactive")
		this.Gui.Add("CheckBox", "x100 y140 w20 h20 vAlt_IgnoreInactiveHoney Checked" Config.Get("Alt", "IgnoreInactiveHoney", 0)).OnEvent("Click", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x20 y165", "Priv Server:")
		this.Gui.Add("Edit", "x80 y163 w110 h20 vAlt_PrivServer", Config.Get("Alt", "PrivServer", "")).OnEvent("Change", this.SaveConfig.Bind(this))



		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x205 y20 w185 h170")
		this.Gui.Add("Text", "x215 y22", "Field Settings")

		this.Gui.SetFont("s8 w400")
		this.Gui.Add("Button", "x300 y22 w40 h16", "Copy").OnEvent("Click", this.CopyFieldSettings.Bind(this))
		this.Gui.Add("Button", "x345 y22 w40 h16", "Paste").OnEvent("Click", this.PasteFieldSettings.Bind(this))

		this.Gui.SetFont("s8 cDefault Norm")

		this.Gui.Add("Text", "x215 y45", "Field:")
		fieldArr := ["sunflower", "dandelion", "mushroom", "blueflower", "clover", "strawberry", "spider", "bamboo", "pineapple", "stump", "cactus", "pumpkin", "pinetree", "rose", "mountaintop", "pepper", "coconut"]
		(GuiCtrl := this.Gui.Add("DropDownList", "x255 y42 w100 vAlt_DefaultField Choose" ObjIndexOf(fieldArr, Config.Get("Alt", "DefaultField", "pepper")), fieldArr)).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x215 y70", "Pattern:")
		this.Gui.Add("DropDownList", "x270 y68 w110 vAlt_Pattern Choose" ObjIndexOf(patternList, Config.Get("Alt", "Pattern", "GeneralBooster")), patternList).OnEvent("Change", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x215 y95", "Size:")
		this.Gui.Add("Edit", "x240 y92 w40 h20 Number vAlt_PatternSize", Config.Get("Alt", "PatternSize"))
		this.Gui.Add("UpDown", "Range1-10", Config.Get("Alt", "PatternSize"))

		this.Gui.Add("Text", "x285 y95", "Width:")
		this.Gui.Add("Edit", "x320 y92 w40 h20 Number vAlt_PatternWidth", Config.Get("Alt", "PatternWidth"))
		this.Gui.Add("UpDown", "Range1-10", Config.Get("Alt", "PatternWidth"))

		this.Gui.Add("Text", "x215 y123", "Sprinkler:")
		sprinklerArr := ["Center", "Upper Left", "Left", "Lower Left", "Lower", "Lower Right", "Right", "Upper Right", "Upper"]
		this.Gui.Add("DropDownList", "x265 y120 w80 vAlt_SprinklerLocation Choose" ObjIndexOf(sprinklerArr, Config.Get("Alt", "SprinklerLocation", "Center")), sprinklerArr).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("Edit", "x350 y120 w30 h20 Number vAlt_SprinklerDistance", Config.Get("Alt", "SprinklerDistance", 1)).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("UpDown", "Range0-10", Config.Get("Alt", "SprinklerDistance", 1))

		this.Gui.Add("Text", "x215 y150", "Rotation:")
		this.Gui.Add("Edit", "x260 y148 w40 h20 Number vAlt_RotationAmount", Config.Get("Alt", "RotationAmount", 0)).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("UpDown", "Range0-8", Config.Get("Alt", "RotationAmount", 0))
		this.Gui.Add("DropDownList", "x320 y148 w60 vAlt_RotationDirection Choose" ObjIndexOf(["Right", "Left"], Config.Get("Alt", "RotationDirection", "Right")), ["Right", "Left"]).OnEvent("Change", this.SaveConfig.Bind(this))

		; --- Communicator Tab ---
		TabCtrl.UseTab("Communicator")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y20 w380 h150")
		this.Gui.Add("Text", "x20 y21", "Connection Settings")
		this.Gui.SetFont("s8 cDefault Norm")

		this.Gui.Add("Text", "x45 y40", "Enable Communication")
		this.Gui.Add("CheckBox", "x25 y37 w20 h20 vCommunicator_CommunicationEnabled Checked" Config.Get("Communicator", "CommunicationEnabled", 0)).OnEvent("Click", this.SaveConfig.Bind(this))

		this.Gui.Add("Text", "x25 y60 w350 h30", "Both the Main and Alt must have the EXACT same 'Channel' name for this to work.")
		this.Gui.Add("Text", "x25 y93", "Channel Name:")
		(GuiCtrl := this.Gui.Add("Edit", "x110 y90 w180 h20 vCommunicator_DweetName", Config.Get("Communicator", "DweetName", "you might wanna change this..."))).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("Button", "x300 y90 w80 h20", "Generate").OnEvent("Click", this.GenerateUser.Bind(this))
		this.Gui.Add("Text", "x25 y130 w80", "Status:")
		role := Config.Get("Main", "AltMacroEnabled", 0) ? "Client" : "Server"
		this.Gui.Add("Text", "x60 y130 w200 vCommsStatus", role)

		; --- Tracker Tab ---
		TabCtrl.UseTab("Tracker")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y20 w130 h170")
		this.Gui.Add("Text", "x20 y22", "Tracker Settings")
		this.Gui.SetFont("s8 cDefault Norm")

		passives := Config.Get("Tracker", "Passives", "Scorch")
		has := (str) => InStr("|" passives "|", "|" str "|")

		TrackerItems := Map(
			"scorch", "Scorch"
			, "popstar", "Pop Star"
			, "x-flame", "X-Flame"
			, "gummystar", "Gummy Star"
			, "gummymorph", "Gummy Morph"
			, "gummyballer", "Gummy Baller"
			, "supersmoothie", "Super Smoothie"
		)

		yPos := 42
		for key, name in TrackerItems {
			varName := StrReplace(key, "-", "")
			this.Gui.Add("CheckBox", "x25 y" yPos " w20 h20 vTracker_" varName " Checked" has(key)).OnEvent("Click", this.UpdatePassives.Bind(this))
			this.Gui.Add("Text", "x45 y" yPos + 3, name)
			yPos := yPos + 20
		}

		; --- Key Alignment Tab ---
		TabCtrl.UseTab("Key Alignment")
		this.Gui.SetFont("w700")
		this.Gui.Add("GroupBox", "x10 y20 w380 h150")
		this.Gui.Add("Text", "x20 y21", "Key Alignment Settings")
		this.Gui.SetFont("s8 cDefault Norm")

		this.Gui.Add("Text", "x25 y45", "Alignment Key:")
		this.Gui.Add("Edit", "x100 y45 w100 vKeyAlignment_AlignmentKey", Config.Get("KeyAlignment", "AlignmentKey", "e")).OnEvent("Change", this.SaveConfig.Bind(this))
		this.Gui.Add("Text", "x25 y75", "Rebind Hotkey:")
		this.Gui.Add("Edit", "x100 y75 w100 vKeyAlignment_RebindHotkey", Config.Get("KeyAlignment", "RebindHotkey", "^+k")).OnEvent("Change", this.SaveConfig.Bind(this))

		; --- Dark Mode ---
		SetWindowTheme(this.Gui, Config.Get("Main", "DarkMode", 1))
		SetWindowAttribute(this.Gui, Config.Get("Main", "DarkMode", 1))
		this.RegisterHotkeys()

		; --- OnExit ---
		OnExit((*) => (IsSet(Stats) && Stats) ? Stats.Export() : 0)
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
				Boost.RefreshConfig()
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

	UpdatePassives(GuiCtrl, *) {
		current := Config.Get("Tracker", "Passives", "scorch")
		list := StrSplit(current, "|")

		name := StrLower(StrReplace(GuiCtrl.Name, "Tracker_", ""))
		if (name = "xflame")
			name := "x-flame"
		
		newList := []
		found := false
		for item in list {
			if (item = name)
				found := true
			else if (item != "")
				newList.Push(item)
		}

		if (GuiCtrl.Value)
			newList.Push(name)
		saveStr := ""
		for item in newList
			saveStr .= (A_Index > 1 ? "|" : "") item
		Config.Set("Tracker", "Passives", saveStr)
		Config.WriteIni()
		this.RefreshFeature("TrackerEnabled")
	}

	OpenWarnSettings(warnKey, name, *) {
		static WarnGui := ""
		GuiClose(*) {
			if (IsSet(WarnGui) && IsObject(WarnGui))
				try WarnGui.Destroy(), WarnGui := ""
		}
		GuiClose()

		WarnGui := Gui("+Owner" this.Gui.Hwnd " +AlwaysOnTop +Border +ToolWindow", name " Settings")
		WarnGui.SetFont("s8 cDefault Norm", "Tahoma")
		WarnGui.OnEvent("Close", (*) => GuiClose())

		SaveLocal(*) {
			Config.Set("Warns", warnKey "_Volume", WarnGui["Volume"].Value)
			Config.Set("Warns", warnKey "_PlayOnce", WarnGui["PlayOnce"].Value)
			Config.WriteIni()
			this.RefreshFeature("WarnsEnabled")
		}

		BrowseSound(*) {
			SelectedFile := FileSelect(1, , "Select Sound File", "Audio (*.wav; *.mp3)")
			if SelectedFile {
				WarnGui["SoundFile"].Value := SelectedFile
				Config.Set("Warns", warnKey "_SoundFile", SelectedFile)
				Config.WriteIni()
			}
		}

		TestLocalAudio(*) {
			soundPath := WarnGui["SoundFile"].Value
			if !FileExist(soundPath)
				soundPath := "C:\Windows\Media\Windows Critical Stop.wav"
			this.AudioPlayer := unset
			this.AudioPlayer := Audio(soundPath)
			vol := WarnGui["Volume"].Value
			try this.AudioPlayer.Play(vol)
		}

		col := (Config.Get("Main", "DarkMode", 1) ? "White" : "Black")
		WarnGui.Add("Text", "x15 y15 w50 c" col, "Volume:")
		WarnGui.Add("Edit", "x65 y12 w50 Number vVolume", Config.Get("Warns", warnKey "_Volume", 25)).OnEvent("Change", SaveLocal)
		WarnGui.Add("UpDown", "Range0-100", Config.Get("Warns", warnKey "_Volume", 25))
		WarnGui.Add("Text", "x120 y15 c" col, "%")

		WarnGui.Add("CheckBox", "x15 y40 w20 h20 vPlayOnce Checked" Config.Get("Warns", warnKey "_PlayOnce", 0)).OnEvent("Click", SaveLocal)
		WarnGui.Add("Text", "x35 y43 w60 c" col, "Play Once")

		WarnGui.Add("Text", "x15 y70 w50 c" col, "Sound:")
		WarnGui.Add("Button", "x60 y67 w60 h22", "Browse").OnEvent("Click", BrowseSound)
		WarnGui.Add("Button", "x125 y67 w60 h22", "Test").OnEvent("Click", TestLocalAudio)
		WarnGui.Add("Edit", "x15 y95 w220 h20 ReadOnly vSoundFile", Config.Get("Warns", warnKey "_SoundFile", "C:\Windows\Media\Windows Critical Stop.wav"))

		WarnGui.Show("w250 h130")
		SetWindowTheme(WarnGui, Config.Get("Main", "DarkMode", 1))
		SetWindowAttribute(WarnGui, Config.Get("Main", "DarkMode", 1))
	}

	CopyFieldSettings(*) {
		settings := Config.Get("Alt", "DefaultField") "|" Config.Get("Alt", "Pattern") "|" Config.Get("Alt", "PatternSize") "|" Config.Get("Alt", "PatternWidth") "|" Config.Get("Alt", "SprinklerLocation") "|" Config.Get("Alt", "SprinklerDistance") "|" Config.Get("Alt", "RotationAmount") "|" Config.Get("Alt", "RotationDirection")
		A_Clipboard := settings
		ToolTip("Settings copied to clipboard")
		SetTimer(ToolTip, -500)
	}

	PasteFieldSettings(*) {
		try {
			data := StrSplit(A_Clipboard, "|")
			if (data.Length != 8) {
				ToolTip("Invalid settings.")
				SetTimer(ToolTip, -500)
				return
			}

			Config.Set("Alt", "DefaultField", data[1])
			Config.Set("Alt", "Pattern", data[2])
			Config.Set("Alt", "PatternSize", data[3])
			Config.Set("Alt", "PatternWidth", data[4])
			Config.Set("Alt", "SprinklerLocation", data[5])
			Config.Set("Alt", "SprinklerDistance", data[6])
			Config.Set("Alt", "RotationAmount", data[7])
			Config.Set("Alt", "RotationDirection", data[8])
			Config.WriteIni()

			this.Gui["Alt_DefaultField"].Text := data[1]
			this.Gui["Alt_Pattern"].Text := data[2]
			this.Gui["Alt_PatternSize"].Value := data[3]
			this.Gui["Alt_PatternWidth"].Value := data[4]
			this.Gui["Alt_SprinklerLocation"].Text := data[5]
			this.Gui["Alt_SprinklerDistance"].Value := data[6]
			this.Gui["Alt_RotationAmount"].Value := data[7]
			this.Gui["Alt_RotationDirection"].Text := data[8]
			ToolTip("Settings pasted from clipboard")
			SetTimer(ToolTip, -500)
		} catch {
			ToolTip("Error pasting settings.")
			SetTimer(ToolTip, -500)
		}
	}

	ToggleFeature(GuiCtrl, *) {
		isChecked := GuiCtrl.Value
		FeatureName := GuiCtrl.Name
		Config.Set("Main", FeatureName, isChecked)
		Config.WriteIni()

		if (FeatureName = "AltMacroEnabled") {
			role := isChecked ? "Client" : "Server"
			try this.Gui["CommsStatus"].Text := role
			if IsSet(Comms)
				Comms.UpdateSettings()
		}
		this.RefreshFeature(FeatureName)
	}

	SaveConfig(GuiCtrl, *) {
		p := InStr(GuiCtrl.Name, "_")
		if !p
			return
		Section := SubStr(GuiCtrl.Name, 1, p - 1)
		Key := SubStr(GuiCtrl.Name, p + 1)

		val := (GuiCtrl.Type = "DDL") ? GuiCtrl.Text : GuiCtrl.Value
		Config.Set(Section, Key, val)
		Config.WriteIni()

		if (Section = "BoostBar")
			this.RefreshFeature("BoostBarEnabled")
		else if (Section = "Warns")
			this.RefreshFeature("WarnsEnabled")
		else if (Section = "Tracker")
			this.RefreshFeature("TrackerEnabled")
		else if (Section = "Main" && (Key = "BoostBarEnabled" || Key = "WarnsEnabled" || Key = "TrackerEnabled"))
			this.RefreshFeature(Key)
		else if (Section = "Communicator")
			if IsSet(Comms)
				Comms.UpdateSettings()

		if (Key = "DarkMode") {
			SetWindowTheme(this.Gui, GuiCtrl.Value)
			SetWindowAttribute(this.Gui, GuiCtrl.Value)
		}

		if (Key ~= "SlotTimer") {
			if IsSet(Boost) && Boost
				Boost.Draw()
		}

		if (Section = "BoostBar")
			if IsSet(Boost) && Boost
				Boost.Draw()
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
		if this.ran
			return
		this.ran++
		State.offsetY := GetYOffset(, &fail)
		try {
		if fail
			msgbox "Failed to get y-Offset, this either means`n1. Your font is NOT the default size (e.g. font scale or broken roblox updates)`n2. Your font is wrong (e.g. custom font w/bloxstrap)`n3. the 'Pollen' text at the top is being covered`n4. Graphical issues`n5. I made a mistake...`n6. You don't have roblox open.", "Kairos", 16
		}
		if (IsSet(Comms) && Comms.isEnabled && Comms.isServer) {
			Comms.BroadcastStart()
			
		}
		Track.Toggle()
		Warns.Toggle()
		Boost.Toggle()
		Alt.Toggle()
		Aligner.Toggle()
		Mag.Toggle()
		Stats.Toggle()
		this.Gui.Show("Hide")
	}

	pause(*) {
		if this.ran != 1
			return
		State.IsPaused ^= 1

		if (State.IsPaused) {
			this.Gui.Show("")
			this.Gui.Title := "Kairos (Paused)"
			this.Gui["PauseButton"].Text := "Resume (" Config.Get("Main", "PauseHotkey", "F2") ")"

			if IsSet(Track) && Track.Fancy
				WinSetExStyle("-0x20", "ahk_id " Track.Fancy.Hwnd)
			if IsSet(Warns) && Warns.Fancy
				Warns.Fancy.Hide()
			if IsSet(Boost) && Boost {
				Boost.Draw()
				Boost.FollowWindow()
			}
			if IsSet(Aligner) && Aligner
				Aligner.Draw()
			if IsSet(Mag) && Mag.Gui
				Mag.Gui.Hide()
			if IsSet(Stats) && Stats
				Stats.Pause()

			DetectHiddenWindows true
			if WinExist("ahk_class AutoHotkey ahk_pid " State.CurrentWalk.pid)
				send "{F16}"
			DetectHiddenWindows false
		} else {
			this.Gui.Hide()
			this.Gui.Title := "Kairos"
			this.Gui["PauseButton"].Text := "Pause (" Config.Get("Main", "PauseHotkey", "F2") ")"

			if IsSet(Track) && Track.Fancy
				WinSetExStyle("+0x20", "ahk_id " Track.Fancy.Hwnd)
			if IsSet(Boost) && Boost
				Boost.Draw()
			if IsSet(Aligner) && Aligner
				Aligner.Draw()

			DetectHiddenWindows true
			if WinExist("ahk_class AutoHotkey ahk_pid " State.CurrentWalk.pid)
				send "{F14}"
			DetectHiddenWindows false

		}
		Pause -1
	}

	stop(*) {
		if (IsSet(Stats) && Stats)
			Stats.Export()
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
