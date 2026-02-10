class Communicator {
	isServer := false
	thingName := ""
	lastDweet := ""

	__New() {
		this.isServer := !Config.Get("Main", "AltMacroEnabled", 0)
		this.thingName := Config.Get("Communicator", "DweetName", "hey maybe change this...")

		if (this.isServer) {
			this.server := dweet(this.thingName)
			OnMessage(0x004A, this.Message.Bind(this))
		} else {
			this.client := dweet(this.thingName) ; just cosmetic
			SetTimer(this.ReadDweet.Bind(this), 1000)
		}
	}

	Message(wParam, lParam, *) {
		try {
			address := NumGet(lParam + 2 * A_PtrSize, "Ptr")
			text := StrGet(address)
			this.server.SendMessage(text)
		}
	}

	ReadDweet(*) {
		try {
			msg := JSON.Parse(this.client.RecieveMessage())
			if (msg["timestamp"] = this.lastDweet)
				return
			this.LastDweet := msg["timestamp"]
			this.ProcessMessage(msg)
		}
	}

	; message Struct: {"action": [string], "data": [any], "timestamp": [int]}
	ProcessMessage(msg) {
		if  msg["action"] = "update stats" {
			
		}
	}
}
