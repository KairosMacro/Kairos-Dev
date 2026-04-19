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

		this.TrackerPassiveMap := Map(
			"Precision", "precise",
			"SuperSmoothie", "supersmoothie",
			"CoconutCombo", "combo",
			"Scorch", "scorch",
			"XFlame", "x-flame",
			"GummyStar", "gummystar",
			"GummyMorph", "gummymorph",
			"GummyBaller", "gummyballer",
			"PopStar", "popstar"
			,"ComboBuff", "combo_buff"
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

		passives := StrSplit(Config.Get("Tracker", "Passives", "scorch"), "|")
		for htmlId, scannerKey in this.TrackerPassiveMap {
			found := false
			for p in passives {
				if (p = scannerKey) {
					found := true
					break
				}
			}
			flatSettings[htmlId] := found ? 1 : 0
		}

		this.Web.PostWebMessageAsJson(JSON.stringify(flatSettings))
	}

	ChangeSetting(val, section, key) {
		Config.Set(section, key, val)
		Config.WriteIni()
		this.RefreshFeature(key)

		if (section = "Tracker" && this.TrackerPassiveMap.Has(key)) {
			passiveStr := ""
			for htmlId, scannerKey in this.TrackerPassiveMap {
				if (Config.Get("Tracker", htmlId, 0))
					passiveStr .= (passiveStr != "" ? "|" : "") scannerKey
			}
			Config.Set("Tracker", "Passives", passiveStr)
			Config.WriteIni()
			this.RefreshFeature("TrackerEnabled")
		}
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
		else if (action = "ExportConfig")
			this.ExportConfig()
		else if (action = "ImportConfig")
			this.ImportConfig()
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

	ExportConfig(*) {
		data := Map()
		; Start from defaults so every possible key is included
		for section, keys in Config.Default {
			sectionMap := Map()
			for key, val in keys
				sectionMap[key] := Config.Get(section, key, val)
			data[section] := sectionMap
		}
		; Also include any extra sections/keys in Config.Data not in Default
		for section, keys in Config.Data {
			if !data.Has(section)
				data[section] := Map()
			for key, val in keys {
				if !data[section].Has(key)
					data[section][key] := val
			}
		}
		jsonStr := JSON.stringify(data)

		; AES-256-CBC encrypt
		plainBuf := Buffer(StrPut(jsonStr, "UTF-8") - 1)
		StrPut(jsonStr, plainBuf, "UTF-8")

		; SHA-256 hash the secret to get a 32-byte AES key
		secret := "KairosEncryptionKey-v2-AES256"
		secretBuf := Buffer(StrPut(secret, "UTF-8") - 1)
		StrPut(secret, secretBuf, "UTF-8")
		hAlg := 0
		DllCall("Bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAlg, "Str", "SHA256", "Ptr", 0, "UInt", 0)
		hHash := 0, hashLen := 32, hashBuf := Buffer(32)
		DllCall("Bcrypt\BCryptCreateHash", "Ptr", hAlg, "Ptr*", &hHash, "Ptr", 0, "UInt", 0, "Ptr", secretBuf, "UInt", secretBuf.Size, "UInt", 0)
		DllCall("Bcrypt\BCryptHashData", "Ptr", hHash, "Ptr", secretBuf, "UInt", secretBuf.Size, "UInt", 0)
		DllCall("Bcrypt\BCryptFinishHash", "Ptr", hHash, "Ptr", hashBuf, "UInt", 32, "UInt", 0)
		DllCall("Bcrypt\BCryptDestroyHash", "Ptr", hHash)
		DllCall("Bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)

		; Generate random 16-byte IV
		iv := Buffer(16)
		DllCall("Bcrypt\BCryptGenRandom", "Ptr", 0, "Ptr", iv, "UInt", 16, "UInt", 0x00000002)

		; Open AES provider and set CBC chaining mode
		hAes := 0
		DllCall("Bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAes, "Str", "AES", "Ptr", 0, "UInt", 0)
		chainMode := "ChainingModeCBC"
		cmBuf := Buffer(StrPut(chainMode, "UTF-16") * 2)
		StrPut(chainMode, cmBuf, "UTF-16")
		DllCall("Bcrypt\BCryptSetProperty", "Ptr", hAes, "Str", "ChainingMode", "Ptr", cmBuf, "UInt", cmBuf.Size, "UInt", 0)

		; Generate symmetric key object
		hKey := 0
		DllCall("Bcrypt\BCryptGenerateSymmetricKey", "Ptr", hAes, "Ptr*", &hKey, "Ptr", 0, "UInt", 0, "Ptr", hashBuf, "UInt", 32, "UInt", 0)

		; PKCS7 pad plaintext to 16-byte blocks
		padLen := 16 - Mod(plainBuf.Size, 16)
		paddedBuf := Buffer(plainBuf.Size + padLen)
		DllCall("ntdll\RtlCopyMemory", "Ptr", paddedBuf, "Ptr", plainBuf, "UInt", plainBuf.Size)
		loop padLen
			NumPut("UChar", padLen, paddedBuf, plainBuf.Size + A_Index - 1)

		; Encrypt — copy IV since BCrypt modifies it in place
		ivCopy := Buffer(16)
		DllCall("ntdll\RtlCopyMemory", "Ptr", ivCopy, "Ptr", iv, "UInt", 16)
		cbCipher := 0
		DllCall("Bcrypt\BCryptEncrypt", "Ptr", hKey, "Ptr", paddedBuf, "UInt", paddedBuf.Size, "Ptr", 0, "Ptr", ivCopy, "UInt", 16, "Ptr", 0, "UInt", 0, "UInt*", &cbCipher, "UInt", 0)
		cipherBuf := Buffer(cbCipher)
		DllCall("ntdll\RtlCopyMemory", "Ptr", ivCopy, "Ptr", iv, "UInt", 16)
		DllCall("Bcrypt\BCryptEncrypt", "Ptr", hKey, "Ptr", paddedBuf, "UInt", paddedBuf.Size, "Ptr", 0, "Ptr", ivCopy, "UInt", 16, "Ptr", cipherBuf, "UInt", cbCipher, "UInt*", &cbCipher, "UInt", 0)

		DllCall("Bcrypt\BCryptDestroyKey", "Ptr", hKey)
		DllCall("Bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAes, "UInt", 0)

		; Prepend IV to ciphertext: [16-byte IV][ciphertext]
		outBuf := Buffer(16 + cbCipher)
		DllCall("ntdll\RtlCopyMemory", "Ptr", outBuf, "Ptr", iv, "UInt", 16)
		DllCall("ntdll\RtlCopyMemory", "Ptr", outBuf.Ptr + 16, "Ptr", cipherBuf, "UInt", cbCipher)

		; Base64 encode the final blob
		size := 0
		DllCall("Crypt32\CryptBinaryToStringW", "Ptr", outBuf, "UInt", outBuf.Size, "UInt", 0x40000001, "Ptr", 0, "UInt*", &size)
		b64 := Buffer(size * 2)
		DllCall("Crypt32\CryptBinaryToStringW", "Ptr", outBuf, "UInt", outBuf.Size, "UInt", 0x40000001, "Ptr", b64, "UInt*", &size)
		encoded := StrGet(b64, size, "UTF-16")

		savePath := FileSelect("S16", A_WorkingDir "\settings\" Config.currentPreset ".kairos", "Export Config", "Kairos Config (*.kairos)")
		if (savePath = "")
			return
		if !InStr(savePath, ".kairos")
			savePath .= ".kairos"
		f := FileOpen(savePath, "w", "UTF-8")
		f.Write(encoded)
		f.Close()
		this.Web.ExecuteScript("alert('Config exported successfully.');")
	}

	ImportConfig(*) {
		filePath := FileSelect(1, A_WorkingDir "\settings\", "Import Config", "Kairos Config (*.kairos)")
		if (filePath = "")
			return
		try {
			encoded := FileRead(filePath, "UTF-8")
			encoded := Trim(encoded, " `t`r`n")

			; Base64 decode
			size := 0
			DllCall("Crypt32\CryptStringToBinaryW", "Str", encoded, "UInt", 0, "UInt", 0x00000001, "Ptr", 0, "UInt*", &size, "Ptr", 0, "Ptr", 0)
			bin := Buffer(size)
			DllCall("Crypt32\CryptStringToBinaryW", "Str", encoded, "UInt", 0, "UInt", 0x00000001, "Ptr", bin, "UInt*", &size, "Ptr", 0, "Ptr", 0)

			if (size < 17) ; Need at least 16-byte IV + 1 block
				throw Error("File too small")

			; Extract IV (first 16 bytes) and ciphertext (rest)
			iv := Buffer(16)
			DllCall("ntdll\RtlCopyMemory", "Ptr", iv, "Ptr", bin, "UInt", 16)
			cipherLen := size - 16
			cipherBuf := Buffer(cipherLen)
			DllCall("ntdll\RtlCopyMemory", "Ptr", cipherBuf, "Ptr", bin.Ptr + 16, "UInt", cipherLen)

			; SHA-256 hash the secret to get the 32-byte AES key
			secret := "KairosEncryptionKey-v2-AES256"
			secretBuf := Buffer(StrPut(secret, "UTF-8") - 1)
			StrPut(secret, secretBuf, "UTF-8")
			hAlg := 0
			DllCall("Bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAlg, "Str", "SHA256", "Ptr", 0, "UInt", 0)
			hHash := 0, hashBuf := Buffer(32)
			DllCall("Bcrypt\BCryptCreateHash", "Ptr", hAlg, "Ptr*", &hHash, "Ptr", 0, "UInt", 0, "Ptr", secretBuf, "UInt", secretBuf.Size, "UInt", 0)
			DllCall("Bcrypt\BCryptHashData", "Ptr", hHash, "Ptr", secretBuf, "UInt", secretBuf.Size, "UInt", 0)
			DllCall("Bcrypt\BCryptFinishHash", "Ptr", hHash, "Ptr", hashBuf, "UInt", 32, "UInt", 0)
			DllCall("Bcrypt\BCryptDestroyHash", "Ptr", hHash)
			DllCall("Bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAlg, "UInt", 0)

			; Open AES provider with CBC mode
			hAes := 0
			DllCall("Bcrypt\BCryptOpenAlgorithmProvider", "Ptr*", &hAes, "Str", "AES", "Ptr", 0, "UInt", 0)
			chainMode := "ChainingModeCBC"
			cmBuf := Buffer(StrPut(chainMode, "UTF-16") * 2)
			StrPut(chainMode, cmBuf, "UTF-16")
			DllCall("Bcrypt\BCryptSetProperty", "Ptr", hAes, "Str", "ChainingMode", "Ptr", cmBuf, "UInt", cmBuf.Size, "UInt", 0)

			; Generate symmetric key object
			hKey := 0
			DllCall("Bcrypt\BCryptGenerateSymmetricKey", "Ptr", hAes, "Ptr*", &hKey, "Ptr", 0, "UInt", 0, "Ptr", hashBuf, "UInt", 32, "UInt", 0)

			; Decrypt
			ivCopy := Buffer(16)
			DllCall("ntdll\RtlCopyMemory", "Ptr", ivCopy, "Ptr", iv, "UInt", 16)
			cbPlain := 0
			DllCall("Bcrypt\BCryptDecrypt", "Ptr", hKey, "Ptr", cipherBuf, "UInt", cipherLen, "Ptr", 0, "Ptr", ivCopy, "UInt", 16, "Ptr", 0, "UInt", 0, "UInt*", &cbPlain, "UInt", 0)
			plainBuf := Buffer(cbPlain)
			DllCall("ntdll\RtlCopyMemory", "Ptr", ivCopy, "Ptr", iv, "UInt", 16)
			DllCall("Bcrypt\BCryptDecrypt", "Ptr", hKey, "Ptr", cipherBuf, "UInt", cipherLen, "Ptr", 0, "Ptr", ivCopy, "UInt", 16, "Ptr", plainBuf, "UInt", cbPlain, "UInt*", &cbPlain, "UInt", 0)

			DllCall("Bcrypt\BCryptDestroyKey", "Ptr", hKey)
			DllCall("Bcrypt\BCryptCloseAlgorithmProvider", "Ptr", hAes, "UInt", 0)

			; Remove PKCS7 padding
			if (cbPlain < 1)
				throw Error("Decryption failed")
			padVal := NumGet(plainBuf, cbPlain - 1, "UChar")
			if (padVal < 1 || padVal > 16)
				throw Error("Invalid padding")
			jsonStr := StrGet(plainBuf, cbPlain - padVal, "UTF-8")

			data := JSON.parse(jsonStr)
			for section, keys in data {
				for key, val in keys
					Config.Set(section, key, val)
			}
			Config.WriteIni()
			this.InitialSync()
			this.Web.ExecuteScript("alert('Config imported successfully.');")
		} catch as e {
			this.Web.ExecuteScript("alert('Import failed: invalid or corrupted file.');")
		}
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
		this.Web.ExecuteScript("document.getElementById('Communicator_DweetName').value = '" name "';")
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
			this.Web.ExecuteScript("document.getElementById('Communicator_DweetName').value = '" WebViewToo.EscapeJS(data) "';")
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
			try this.Web.ExecuteScript("document.getElementById('CommsStatus').innerText = '" role "';")
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
			this.Web.ExecuteScript("document.getElementById('Warns_SoundFile').value = '" WebViewToo.EscapeJS(SelectedFile) "';")
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
