class config {
	static currentPreset := "config"
	static path => A_WorkingDir "\settings\" this.currentPreset ".ini"
	static Data := Map()

	static Default := Map(
		"main", Map(
			"start_hotkey", "F1",
			"pause_hotkey", "F2",
			"stop_hotkey", "F3",
			"warns_enabled", 0,
			"boost_bar_enabled", 0,
			"alt_macro_enabled", 0,
			"tracker_enabled", 0,
			"key_alignment_enabled", 0,
			"magnifier_enabled", 0,
			"stat_monitor_enabled", 0,
			"always_on_top", 0,
			"hide_on_run", 0,
			"gui_x", A_ScreenWidth // 2 - 200,
			"gui_y", A_ScreenHeight // 2 - 100,
			"dark_mode", 1,
			"account_type", "Main"
		),
		"alt", Map(
			"move_speed", 29,
			"hive_slot", 1,
			"field_drift_comp", 1,
			"alt_number", 1,
			"default_field", "pepper",
			"pattern", "GeneralBooster",
			"pattern_size", 1,
			"pattern_width", 1,
			"rot_lr_amount", 0,
			"rot_lr_dir", "Right",
			"camera_pitch", 4,
			"shift_lock", 0,
			"sprinkler_location", "Center",
			"sprinkler_distance", 1,
			"priv_server", "",
			"claim_hive", 1,
			"ignore_inactive_honey", 0,
			"use_tool", 1,
			"coco_catch", 0
		),
		"boost_bar", Map(
			"slot_active_1", 0, "slot_timer_1", 100, "slot_mode_1", "Timer",
			"slot_active_2", 0, "slot_timer_2", 100, "slot_mode_2", "Timer",
			"slot_active_3", 0, "slot_timer_3", 100, "slot_mode_3", "Timer",
			"slot_active_4", 0, "slot_timer_4", 100, "slot_mode_4", "Timer",
			"slot_active_5", 0, "slot_timer_5", 100, "slot_mode_5", "Timer",
			"slot_active_6", 0, "slot_timer_6", 100, "slot_mode_6", "Timer",
			"slot_active_7", 0, "slot_timer_7", 100, "slot_mode_7", "Timer",
			"show_when_active", 1
		),
		"warns", Map(
			"precise_enabled", 0,
			"precise_threshold", 25,
			"precise_volume", 25,
			"precise_play_once", 0,
			"precise_sound_file", A_WorkingDir "\Assets\Audio\Precision.mp3",

			"smoothie_enabled", 0,
			"smoothie_threshold", 180,
			"smoothie_volume", 25,
			"smoothie_play_once", 1,
			"smoothie_sound_file", A_WorkingDir "\Assets\Audio\Smoothie.mp3",

			"pop_enabled", 0,
			"pop_threshold", 25,
			"pop_volume", 25,
			"pop_play_once", 0,
			"pop_sound_file", A_WorkingDir "\Assets\Audio\PopStar.mp3",

			"scorch_enabled", 0,
			"scorch_threshold", 25,
			"scorch_volume", 25,
			"scorch_play_once", 0,
			"scorch_sound_file", A_WorkingDir "\Assets\Audio\ScorchStar.mp3",

			"shower_enabled", 0,
			"shower_threshold", 20,
			"shower_volume", 25,
			"shower_play_once", 0,
			"shower_sound_file", A_WorkingDir "\Assets\Audio\Shower.mp3",

			"morph_enabled", 0,
			"morph_threshold", 25,
			"morph_volume", 25,
			"morph_play_once", 0,
			"morph_sound_file", A_WorkingDir "\Assets\Audio\GummyMorph.mp3",

			"gummy_enabled", 0,
			"gummy_threshold", 70,
			"gummy_volume", 27,
			"gummy_play_once", 0,
			"gummy_sound_file", A_WorkingDir "\Assets\Audio\GummyStar.mp3",

			"baller_enabled", 0,
			"baller_threshold", 901,
			"baller_volume", 25,
			"baller_play_once", 0,
			"baller_sound_file", A_WorkingDir "\Assets\Audio\Baller.mp3",

			"combo_enabled", 0,
			"combo_threshold", 35,
			"combo_volume", 25,
			"combo_play_once", 0,
			"combo_sound_file", A_WorkingDir "\Assets\Audio\CocoCombo.mp3",

			"x_flame_enabled", 0,
			"x_flame_threshold", 15,
			"x_flame_volume", 25,
			"x_flame_play_once", 0,
			"x_flame_sound_file", A_WorkingDir "\Assets\Audio\Xflames.mp3",

			"combo_buff_enabled", 0,
			"combo_buff_threshold", 15,
			"combo_buff_volume", 25,
			"combo_buff_play_once", 1,
			"combo_buff_sound_file", A_WorkingDir "\Assets\Audio\ComboBuff.mp3"
		),
		"tracker", Map(
			"passives", "scorch",
			"precision", 0,
			"super_smoothie", 0,
			"coconut_combo", 0,
			"scorch", 0,
			"x_flame", 0,
			"gummy_star", 0,
			"gummy_morph", 0,
			"gummy_baller", 0,
			"combo_buff", 0,
			"pop_star", 0,
		),
		"magnifier", Map(
			"zoom_factor", 1.3,
			"target_offset", -300,
			"offset_x", 260,
			"offset_y", 230,
			"fps", 30,
		),
		"key_alignment", Map(
			"alignment_key", "e",
			"rebind_hotkey", "^+k",
			"rot_right", ",",
			"rot_left", "."
		),
		"communicator", Map(
			"communication_enabled", 0,
			"display_name", "User_" Random(1000, 9999),
			"dweet_name", "K" Random(10000000, 99999999) "X" Random(10000000, 99999999)
		),
		"stat_monitor", Map(
			"enabled", 0
		),
		"guide", Map(
			"enabled", 0,
			"field", "pepper",
			"priv_link", ""
		)
	)

	static Init() {
		if !DirExist("settings")
			DirCreate "settings"
		globalPath := A_WorkingDir "\settings\global.ini"
		try
			this.currentPreset := IniRead(globalPath, "Global", "LastPreset", "config")
		catch
			this.currentPreset := "config"
	}

	static SetPreset(presetName) {
		this.currentPreset := presetName

		globalPath := A_WorkingDir "\settings\global.ini"
		IniWrite(presetName, globalPath, "Global", "LastPreset")

		this.Data.Clear()
		this.Load()
	}

	static GetPresets() {
		if !DirExist("settings")
			DirCreate "settings"
		list := []
		Loop Files A_WorkingDir "\settings\*.ini" {
			name := SubStr(A_LoopFileName, 1, -4)
			if (name != "global")
				list.Push(name)
		}
		if (list.Length = 0)
			list.Push("config")
		return list
	}

	static Load() {
		this.Init()

		for section, keys in this.Default {
			if !this.Data.Has(section)
				this.Data[section] := Map()
			for key, val in keys {
				this.Data[section][key] := val
			}
		}
		if FileExist(this.path)
			this.ReadIni()
		this.WriteIni()
	}

	static ReadIni() {
		try {
			iniFile := FileOpen(this.path, "r")
			str := iniFile.Read()
			iniFile.Close()
		} catch
			return

		currentSection := ""

		Loop Parse, str, "`n", "`r" {
			line := Trim(A_LoopField)
			if (line = "" || SubStr(line, 1, 1) = ";")
				continue

			if (SubStr(line, 1, 1) = "[" && SubStr(line, -1) = "]") {
				currentSection := SubStr(line, 2, -1)
				if !this.Data.Has(currentSection)
					this.Data[currentSection] := Map()
				continue
			}

			if (p := InStr(line, "=")) && (currentSection != "") {
				key := Trim(SubStr(line, 1, p - 1))
				val := Trim(SubStr(line, p + 1))
				if IsInteger(val)
					val := Integer(val)
				if IsFloat(val)
					val := Round(Float(val), 2)
				this.Data[currentSection][key] := val
			}
		}
	}

	static WriteIni() {
		if !DirExist("settings") {
			DirCreate("settings")
		}

		ini_str := ""
		for section, keys in this.Data {
			ini_str .= "[" section "]`r`n"
			for key, val in keys {
				if IsFloat(val) {
					val := Round(val, 2)
				}
				ini_str .= key "=" val "`r`n"
			}
			ini_str .= "`r`n"
		}

		f := FileOpen(this.path, "w", "UTF-8")
		f.Write(ini_str)
		f.Close()
	}

	static Set(section, key, val) {
		if (this.Data.Has(section))
			this.Data[section][key] := val
		else
			this.Data[section] := Map(key, val)
		this.WriteIni()
		if (IsSet(process_manager))
			process_manager.broadcast_setting(section, key, val)
	}
	static Get(section, key, defaultVal := "") => (this.Data.Has(section) && this.Data[section].Has(key)) ? this.Data[section][key] : defaultVal
}
