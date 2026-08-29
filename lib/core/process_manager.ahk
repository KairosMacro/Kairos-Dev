class process_manager {
	static processes := Map()
	static crash_logs := Map()
	static heartbeats := Map()
	static max_crashes := 5
	static time_window := 60 ; 1 min
	static ping_timeout := 5
	static launch_buffer := 10

	static launch_script(script_path, params := [], use_32_bit := false) {
		if (this.is_locked_out(script_path))
			return -3

		exe_path := use_32_bit ? A_WorkingDir "\scripts\bin\AutoHotkey32.exe" : A_WorkingDir "\scripts\bin\AutoHotkey64.exe"
		target_script := A_WorkingDir "\" script_path

		if !FileExist(exe_path)
			return -1
		if !FileExist(target_script)
			return -2

		vars := ""
		for _, param in params
			vars .= '"' (param = "" ? "" : param) '" '

		main_pid := ProcessExist()
		Run('"' exe_path '" "' target_script '" "' main_pid '" ' vars,,, &new_pid)

		this.processes[script_path] := {pid: new_pid, params: params}
		this.heartbeats[script_path] := nowUnix() + this.launch_buffer
		this.update_heartbeat(script_path)
		return new_pid
	}

	static handle_crash(script_path) {
		now := nowUnix()
		if !this.crash_logs.Has(script_path)
			this.crash_logs[script_path] := []
		this.crash_logs[script_path].Push(now)

		if (this.is_locked_out(script_path))
			return 0

		stored_params := this.processes.Has(script_path) ? this.processes[script_path].params : []
		this.launch_script(script_path, stored_params)
	}

	static is_locked_out(script_path) {
		if !this.crash_logs.Has(script_path)
			return false

		now := nowUnix()
		recent_crashes := []

		for _, timestamp in this.crash_logs[script_path]
			if (now - timestamp <= this.time_window)
				recent_crashes.Push(timestamp)

		this.crash_logs[script_path] := recent_crashes
		return recent_crashes.Length >= this.max_crashes
	}

	static update_heartbeat(script_path) {
		this.heartbeats[script_path] := nowUnix()
	}

	static check_heartbeats() {
		now := nowUnix()

		for script_path, last_ping in this.heartbeats {
			if (now - last_ping > this.ping_timeout) {
				if this.processes.Has(script_path)
					try ProcessClose(this.processes[script_path].pid)
				this.heartbeats.Delete(script_path)
				this.handle_crash(script_path)
			}
		}
	}

	static broadcast_state(state_string) {
		payload := Map("action", "set_state", "state", state_string)
		for script_path, process_info in this.processes
			IPC.send_message("ahk_class AutoHotkey ahk_pid " process_info.pid, 1, payload)
	}

	static broadcast_setting(section, key, val) {
		payload := Map(
			"action", "update_setting",
			"section", section,
			"key", key,
			"value", val
		)
		for script_path, process_info in this.processes
			IPC.send_message("ahk_class AutoHotkey ahk_pid " process_info.pid, 1, payload)
	}

	static kill_all() {
		payload := Map("action", "exit")
		for script_path, process_info in this.processes
			IPC.send_message("ahk_class AutoHotkey ahk_pid " process_info.pid, 1, payload)

		sleep 500
		for script_path, process_info in this.processes
			if ProcessExist(process_info.pid)
				try ProcessClose(process_info.pid)
		this.processes.Clear()
		this.heartbeats.Clear()
	}
}
