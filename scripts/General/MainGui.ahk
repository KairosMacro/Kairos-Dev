class MainGui {
	Selectors := Map()
	FeatureList := ["Alt Macro", "Tracker", "Warns", "Boost Bar", "Stat Monitor", "Key Alignment", "Magnifier"]
	FwdDown := false
	BackDown := false
	LeftDown := false
	RightDown := false
	ran := 0
	ListeningKeybind := ""

	__New() {
		this.width := 600
		this.height := 400

		this.Web := WebViewToo(, , , True)
		this.Web.OnEvent("Close", this.Exit.Bind(this))

		Settings := this.Web.CoreWebView2.Settings
		Settings.AreDefaultContextMenusEnabled := false
		Settings.IsZoomControlEnabled := false
		Settings.IsStatusBarEnabled := false
		Settings.IsSwipeNavigationEnabled := false
		Settings.AreBrowserAcceleratorKeysEnabled := false
		Settings.AreDevToolsEnabled := false

		this.FeatureRefreshers := Map(
			"BoostBarEnabled", () => (IsSet(Boost) && Boost) ? Boost.RefreshConfig() : 0,
			"WarnsEnabled", () => (IsSet(Warns) && Warns) ? Warns.RefreshConfig() : 0,
			"TrackerEnabled", () => (IsSet(Track) && Track) ? Track.RefreshConfig() : 0
		)

		this.Web.AddHostObjectToScript("drag", { func: (*) => (ControlClick(this.Web.Gui["NCLBUTTONDOWN_Sink"], this.Web.Gui, , "Left", 1), PostMessage(0x00A1, 2, , this.Web.Hwnd)) })
		this.Web.AddHostObjectToScript("minimizeWindow", { func: (*) => this.Web.Minimize() })
		this.Web.AddHostObjectToScript("closeWindow", { func: this.Exit.Bind(this) })
		this.Web.AddHostObjectToScript("ahkReady", { func: this.InitialSync.Bind(this) })
		this.Web.AddHostObjectToScript("ahkChangeSetting", { func: this.ChangeSetting.Bind(this) })

		this.Web.AddHostObjectToScript("ahk", {
			Start: this.start.Bind(this),
         Pause: this.pause.Bind(this),
         Stop: this.stop.Bind(this),
			OpenLink: ((url) => Run(url)),
			Action: this.HandleAction.Bind(this)
		})

		this.Web.Load("Frontend\index.html")
		this.Web.Show("w" this.width " h" this.height " Center")
		this.RegisterHotkeys()
	}

	InitialSync(*) {
		flatSettings := Map()
		for section, keys in Config.Data 
			for key, val in keys
				flatSettings[key] := val
		flatSettings["lbl_StartHotkey_Settings"] := Config.Get("Main", "StartHotkey", "F1")
		flatSettings["lbl_PauseHotkey_Settings"] := Config.Get("Main", "PauseHotkey", "F2")
		flatSettings["lbl_StopHotkey_Settings"] := Config.Get("Main", "StopHotkey", "F3")

		flatSettings["lbl_AlignmentKey_Settings"] := Config.Get("KeyAlignment", "AlignmentKey", "e")
		flatSettings["lbl_RebindHotkey_Settings"] := Config.Get("KeyAlignment", "RebindHotkey", "^+k")

		flatSettings["PresetList"] := Config.GetPresets()
		flatSettings["PresetDDL"] := Config.currentPreset
		flatSettings["PatternList"] := patternList
		this.Web.PostWebMessageAsJson(JSON.stringify(flatSettings))
	}

	ChangeSetting(val, section, key) {
		if (section = "Tracker" && key ~= "^(Precision|SuperSmoothie|CoconutCombo|Scorch|XFlame|GummyStar|GummyMorph|GummyBaller|PopStar)$") {
			this.UpdatePassives(key, val)
			return
		}
		Config.Set(section, key, val)
		Config.WriteIni()
		this.RefreshFeature(key)

		if (section = "Communicator") {
			if IsSet(Comms)
				Comms.UpdateSettings()
		}
		if (section = "BoostBar") {
			if IsSet(Boost) && Boost
				Boost.Draw()
		}
	}

	HandleAction(actionStr) {
		parts := StrSplit(actionStr, "|")
		action := parts[1]
		param1 := parts.Length > 1 ? parts[2] : ""
		param2 := parts.Length > 2 ? parts[3] : ""

		if (action = "LoadPreset")
			this.LoadPreset(param1)
		else if (action = "SavePreset")
			this.SavePreset()
		else if (action = "NewPreset")
			this.NewPreset(param1)
		else if (action = "DeletePreset")
			this.DeletePreset(param1)
		else if (action = "BrowseSound")
			this.BrowseSound(param1)
		else if (action = "TestSound")
			this.TestSound(param1)
		else if (action = "CaptureHotkey")
			this.CaptureHotkey(param1, param2)
		else if (action = "CopyFieldSettings")
			this.CopyFieldSettings()
		else if (action = "PasteFieldSettings")
			this.PasteFieldSettings()
	}

	BrowseSound(warnKey, *) {
			SelectedFile := FileSelect(1, , "Select Sound File", "Audio (*.wav; *.mp3)")
			if SelectedFile {
				Config.Set("Warns", warnKey "_SoundFile", SelectedFile)
				Config.WriteIni()
				js := "document.getElementById('" warnKey "_SoundFile').value = '" WebViewToo.EscapeJS(SelectedFile) "';"
				this.Web.ExecuteScript(js)
			}
		}

		TestSound(warnKey, *) {
			soundPath := Config.Get("Warns", warnKey "_SoundFile", "C:\Windows\Media\Windows Critical Stop.wav")
			vol := Config.Get("Warns", warnKey "_Volume", 25)
			if !FileExist(soundPath)
				soundPath := "C:\Windows\Media\Windows Critical Stop.wav"
			this.AudioPlayer := unset
			this.AudioPlayer := Audio(soundPath)
			try this.AudioPlayer.Play(vol)
		}

	Exit(*) {
		if (IsSet(Comms) && Comms.isEnabled) {
			Comms.Send("System", "Disconnect", Map("name", Comms.displayName))
			sleep 50
		}
		try this.Web.Gui.Hide()
		try this.Web.Close()
		sleep 50
		ExitApp()
	}

	; --- Functions ---
	GenerateUser(GuiCtrl, *) {
		name := "K" Random(10000000, 99999999) "X" Random(10000000, 99999999)
		this.Gui["Communicator_DweetName"].Value := name
		Config.Set("Communicator", "DweetName", name)
		Config.WriteIni()
		if IsSet(Comms)
			Comms.UpdateSettings()
	}

	PasteUser(GuiCtrl, *) {
		try {
			data := Trim(A_Clipboard)
			if (data = "") {
				ToolTip("Clipboard is empty.")
				SetTimer(ToolTip, -500)
				return
			}
			this.Gui["Communicator_DweetName"].Value := data
			Config.Set("Communicator", "DweetName", data)
			Config.WriteIni()

			if IsSet(Comms)
				Comms.UpdateSettings()
		} catch {
			ToolTip("Error Pasting.")
			SetTimer(ToolTip, -500)
		}
	}

	CaptureHotkey(Section, KeyName) {
		originalText := Config.Get(Section, KeyName, "")
		js := "document.getElementById('lbl_" KeyName "_Settings').innerText = '...';"
		this.Web.ExecuteScript(js)
		
		ih := InputHook("L1 T7", "{Escape}{Space}{Tab}{Enter}{Backspace}{Delete}{Insert}{Home}{End}{PgUp}{PgDn}{Up}{Down}{Left}{Right}{F1}{F2}{F3}{F4}{F5}{F6}{F7}{F8}{F9}{F10}{F11}{F12}")
		capturedKey := ""
		MouseCallback := (ThisHotkey) => (capturedKey := StrReplace(ThisHotkey, "$"), ih.Stop())
		mouseKeys := ["LButton", "RButton", "MButton", "XButton1", "XButton2"]
		for key in mouseKeys
			Hotkey("$" key, MouseCallback, "On")
		ih.Start()
		ih.Wait()

		for key in mouseKeys
			Hotkey("$" key, "Off")

		finalKey := ""
		if (capturedKey != "")
			finalKey := capturedKey
		else if (ih.EndReason = "Max")
			finalKey := ih.Input
		else if (ih.EndReason = "EndKey" && ih.EndKey != "Escape")
			finalKey := ih.EndKey
		
		if (finalKey != "") {
			if (KeyName ~= "StartHotkey|PauseHotkey|StopHotkey") {
				blacklist := "|LButton|RButton|Enter|Space|Tab|Backspace|Escape|"
				if InStr(blacklist, "|" finalKey "|") {
					MsgBox("You cannot bind '" finalKey "' to this option.", "Invalid Keybind", 48 " T10")
					finalKey := ""
				}
			}
		}

		if (finalKey = "")
			finalKey := originalText
		else {
			Config.Set(Section, KeyName, finalKey)
			Config.WriteIni()

			if (Section = "KeyAlignment" && IsSet(Aligner) && Aligner)
				Aligner.RefreshConfig()
			if (KeyName ~= "StartHotkey|PauseHotkey|StopHotkey") {
				try Hotkey(originalText, "Off")
				this.RegisterHotkeys()
			}
		}
		jsEnd := "document.getElementById('lbl_" KeyName "_Settings').innerText = '" finalKey "'; "
		jsEnd .= "if (document.getElementById('lbl_" KeyName "')) { "
		jsEnd .= "document.getElementById('lbl_" KeyName "').innerText = '" finalKey "'; }"
		
		this.Web.ExecuteScript(jsEnd)
	}

	UpdatePassives(key, isChecked) {
		current := Config.Get("Tracker", "Passives", "scorch")
		list := StrSplit(current, "|")

		name := StrLower(key)
		if (name = "xflame")
			name := "x-flame"
		else if (name = "precision")
			name := "precise"
		else if (name = "coconutcombo")
			name := "combo"
		
		newList := []
		for item in list
			if (item != name && item != "" && item != "precision" && item != "coconutcombo")
				newList.Push(item)

		if (isChecked)
			newList.Push(name)

		saveStr := ""
		for item in newList
			saveStr .= (A_Index > 1 ? "|" : "") item

		Config.Set("Tracker", "Passives", saveStr)
		Config.WriteIni()
		this.RefreshFeature("TrackerEnabled")
	}

	CopyFieldSettings(*) {
		settings := Config.Get("Alt", "DefaultField") "|" Config.Get("Alt", "Pattern") "|" Config.Get("Alt", "PatternSize") "|" Config.Get("Alt", "PatternWidth") "|" Config.Get("Alt", "SprinklerLocation") "|" Config.Get("Alt", "SprinklerDistance") "|" Config.Get("Alt", "CameraPitch")
		A_Clipboard := settings
		ToolTip("Settings copied to clipboard")
		SetTimer(ToolTip, -500)
	}

	PasteFieldSettings(*) {
		try {
			data := StrSplit(A_Clipboard, "|")
			if (data.Length < 7) { 
				ToolTip("Invalid settings format.")
				SetTimer(ToolTip, -500)
				return
			}

			Config.Set("Alt", "DefaultField", data[1])
			Config.Set("Alt", "Pattern", data[2])
			Config.Set("Alt", "PatternSize", data[3])
			Config.Set("Alt", "PatternWidth", data[4])
			Config.Set("Alt", "SprinklerLocation", data[5])
			Config.Set("Alt", "SprinklerDistance", data[6])
			Config.Set("Alt", "CameraPitch", data[7])
			Config.WriteIni()

			js := "var updates = {"
				. "'DefaultField': '" data[1] "',"
				. "'Pattern': '" data[2] "',"
				. "'PatternSize': '" data[3] "',"
				. "'PatternWidth': '" data[4] "',"
				. "'SprinklerLocation': '" data[5] "',"
				. "'SprinklerDistance': '" data[6] "',"
				. "'CameraPitch': '" data[7] "'"
				. "};"
				. "for (var id in updates) {"
				. "  var el = document.getElementById(id);"
				. "  if (el) el.value = updates[id];"
				. "}"
			this.Web.ExecuteScript(js)

			ToolTip("Settings pasted from clipboard")
			SetTimer(ToolTip, -500)
		} catch {
			ToolTip("Error pasting settings.")
			SetTimer(ToolTip, -500)
		}
	}

	ToggleFeature(GuiCtrl, *) {
		isChecked := GuiCtrl.Value
		FeatureName := StrReplace(GuiCtrl.Name, "Main_", "")
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

	EnforceFloat(GuiCtrl, *) {
		clean := RegExReplace(GuiCtrl.Value, "[^\d.]")
		clean := RegExReplace(clean, "^([^.]*\.)|\.", "$1")

		if (GuiCtrl.Value != clean) {
			pos := SendMessage(0x00B0, 0, 0, GuiCtrl)
			start := pos & 0xFFFF
			GuiCtrl.Value := clean
			SendMessage(0x00B1, start-1, start-1, GuiCtrl)
		}
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
		if (Key = "AccountType")
			Reload

		if (Key ~= "SlotTimer") {
			if IsSet(Boost) && Boost
				Boost.Draw()
		}

		if (Section = "BoostBar")
			if IsSet(Boost) && Boost
				Boost.Draw()
	}

	LoadPreset(presetName, *) {
		if !presetName
			return
		Config.SetPreset(presetName)
		this.InitialSync()
	}

	SavePreset(*) {
		Config.WriteIni()
	}

	NewPreset(presetName, *) {
		if (presetName = "")
			return
		presetName := RegExReplace(presetName, "[\\/:\*\?`"<>\|]", "")

		if (StrLower(presetName) ~= "i)^(config|global)$") {
			this.Web.ExecuteScript("alert('You cannot use global or config as a profile name.');")
			return
		}

		newPath := A_WorkingDir "\settings\" presetName ".ini"
		if FileExist(newPath) {
			this.Web.ExecuteScript("alert('A profile with this name already exists.');")
			return
		}
		try FileCopy(Config.path, newPath, 0)
		Config.SetPreset(presetName)
		this.InitialSync()
	}

	DeletePreset(presetName, *) {
		if (presetName ~= "i)^(config|global)$" || presetName = "")
			return
		filePath := A_WorkingDir "\settings\" presetName ".ini"
		if FileExist(filePath)
			FileDelete(filePath)
		Config.SetPreset("config")
		this.InitialSync()
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
		if (IsSet(Comms) && Comms.isEnabled && Comms.isServer)
			Comms.BroadcastStart()
		
		accountType := Config.Get("Main", "AccountType", "Main")

		Boost.Toggle()
		
		if (accountType = "Main") {
			if (Config.Get("Main", "TrackerEnabled", 0) || Config.Get("Main", "WarnsEnabled", 0))
				Scanner.Toggle(1)
			Track.Toggle()
			Warns.Toggle()
			Aligner.Toggle()
			Mag.Toggle()
			Stats.Toggle()
		} else if (accountType = "Alt") {
			Alt.Toggle()
		}
		this.Web.Gui.Minimize()
	}

	pause(*) {
		if this.ran != 1
			return
		State.IsPaused ^= 1

		if (State.IsPaused) {
			this.Web.Gui.Restore()

			if IsSet(Track) && Track.Fancy
				Track.Fancy.Hide()
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
				PostMessage(0x5000, 1, 0, , "ahk_class AutoHotkey ahk_pid " State.CurrentWalk.pid)
			DetectHiddenWindows false
		} else {
			this.Web.Gui.Minimize()

			if IsSet(Boost) && Boost
				Boost.Draw()
			if IsSet(Aligner) && Aligner
				Aligner.Draw()

			DetectHiddenWindows true
			if WinExist("ahk_class AutoHotkey ahk_pid " State.CurrentWalk.pid)
				PostMessage(0x5000, 0, 0, , "ahk_class AutoHotkey ahk_pid " State.CurrentWalk.pid)
			DetectHiddenWindows false

		}
		Pause -1
	}

	stop(*) {
		if (this.ran && IsSet(Stats) && Stats)
			Stats.Export()
		Reload
	}

	RegisterHotkeys() {
		try Hotkey(Config.Get("Main", "StartHotkey", "F1"), (*) => this.start(), "On")
		try Hotkey(Config.Get("Main", "PauseHotkey", "F2"), (*) => this.pause(), "On")
		try Hotkey(Config.Get("Main", "StopHotkey", "F3"), (*) => this.stop(), "On")
	}
}
