class Communicator {
	isServer := false
	thingName := ""
	lastDweet := ""

	__New() {
		this.UpdateSettings()
	}

	UpdateSettings() {
		this.isServer := !Config.Get("Main", "AltMacroEnabled", 0)
		this.thingName := Config.Get("Communicator", "DweetName", "you might wanna change this...")
		if (this.isServer) {
			this.server := dweet(this.thingName)
			SetTimer(this.ReadDweet.Bind(this), 0)
		} else {
			this.client := dweet(this.thingName)
			SetTimer(this.ReadDweet.Bind(this), 1000)
		}
	}

	BroadcastBuffs(state) {
		if (!this.isServer)
			return
		payload := Map(
			"action", "update stats",
			"data", state,
			"timestamp", nowUnix()
		)
		this.server.SendMessage(JSON.Stringify(payload))
	}

	ReadDweet(*) {
		if (this.isServer)
			return
		try {
			msg := this.client.ReceiveMessage()
			if (msg = "")
				return
			this.LastDweet := msg["timestamp"]
			this.ProcessMessage(msg)
		}
	}

	; message Struct: {"action": [string], "data": [any], "timestamp": [int]}
	ProcessMessage(msg) {
		if (msg["action"] = "update stats") {
			global Boost
			if (IsSet(Boost) && IsObject(Boost)) {
				newState := msg["data"]
				list := Type(newState) = "Map" ? newState : newState.OwnProps()
				for name, isActive in list {
					if (Boost.stats.BuffState.Has(name))
						Boost.stats.BuffState[name] := isActive
				}
			}
		}
	}
}
