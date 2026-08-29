class IPC {
	static command_callback := ""

	static init(callback_func := "") {
		if (callback_func)
			this.command_callback := callback_func
		OnMessage(0x004A, ObjBindMethod(this, "receive_message"))
	}

	static receive_message(wParam, lParam, msg, hwnd) {
		string_address := NumGet(lParam + 2 * A_PtrSize, "Ptr")
		payload := StrGet(string_address)
		parsed_payload := json.parse(payload)

		if (wParam == 1 && this.command_callback) {
			this.command_callback.Call(parsed_payload)
		} else if (wParam == 2) {
			this.route_heartbeat(parsed_payload)
		}
		return 1
	}

	static send_message(target_script, w_param, payload_obj) {
		json_string := json.stringify(payload_obj)

		copy_data_struct := Buffer(3 * A_PtrSize)
		size_in_bytes := (StrLen(json_string) + 1) * 2
		NumPut("Ptr", size_in_bytes, "Ptr", StrPtr(json_string), copy_data_struct, A_PtrSize)

		DetectHiddenWindows true
		try
			return SendMessage(0x004A, w_param, copy_data_struct,, target_script)
		catch
			return -1
		finally
			DetectHiddenWindows false
	}

	static route_heartbeat(data) {
		process_manager.update_heartbeat(data["script"])
		return 1
	}
}
