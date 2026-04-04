class Communicator {
	isEnabled := false
	isServer := false
	displayName := ""
	channelToken := ""
	transport := ""

	__New() {
		this.UpdateSettings()
	}

	UpdateSettings() {
		if (this.transport) {
			this.transport.Disconnected()
			this.transport := ""
		}
		this.isEnabled := Config.Get("Communicator", "CommunicationEnabled", 0)
		if (!this.isEnabled) {
			if (IsSet(Main) && IsObject(Main))
				Main.Web.ExecuteScript("setCommsUI('Disabled');")
			return
		}
		this.isServer := !Config.Get("Main", "AltMacroEnabled", 0)
		this.channelToken := Config.Get("Communicator", "DweetName", "")
		this.displayName := Config.Get("Communicator", "DisplayName", "Unknown_User")
		this.transport := DweetTransport(this.channelToken, this.isServer, this.displayName)
		this.transport.OnMessage := this.RouteMessage.Bind(this)
		this.transport.Connect()

		if (IsSet(Main) && IsObject(Main))
			Main.Web.ExecuteScript("setCommsUI('Not Connected');")
		this.Send("System", "Handshake", {name: this.displayName})
	}

	Send(channel, action, data := "") {
		if (!this.isEnabled || !this.transport)
			return
		payload := Map(
			"sender", this.displayName
			, "role", this.isServer ? "Server" : "Client"
			, "channel", channel
			, "action", action
			, "data", data
			, "timestamp", nowUnix()
		)
		this.transport.Send(payload)
	}

	RouteMessage(msg) {
		if (IsSet(Main) && IsObject(Main))
			Main.Web.ExecuteScript("flashCommsConnected();")
		channel := msg["channel"]
		action := msg["action"]

		; handshake
		if (channel = "System") {
			if (action = "Handshake" || action = "HandshakeAck") {
				if (IsSet(Main) && IsObject(Main))
					Main.Web.ExecuteScript("setCommsUI('Connected', '" msg["sender"] "');")
				if (action = "Handshake")
					this.Send("System", "HandshakeAck", {name: this.displayName})
			}
		}

		; boostbar
		else if (channel = "BoostBar") {
			if (action = "UpdateStats" && msg["role"] = "Server") {
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

		; macro control
		else if (channel = "MacroControl") {
			if (action = "Start" && msg["role"] = "Server") {
				if (nowUnix() - msg["timestamp"] > 15)
					return
				if (IsSet(Main) && IsObject(Main))
					Main.start()
			}
		}

		; guid rot (coming idk when)
		else if (channel = "GuideRotation") {
			return
		}
	}

	BroadcastBuffs(state) {
		if (this.isServer)
			this.Send("BoostBar", "UpdateStats", state)
	}

	BroadcastStart() {
		if (this.isServer)
			this.Send("MacroControl", "Start")
	}
}
