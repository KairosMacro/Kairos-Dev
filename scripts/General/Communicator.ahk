class Communicator {
	isEnabled := false
	isServer := false
	displayName := ""
	channelToken := ""

	transports := Map()

	heartbeatTimer := ""
	pruneTimer := ""

	msgHistory := []
	activeConnections := Map()

	__New() {
		this.UpdateSettings()
	}

	UpdateSettings() {
		for name, transit in this.transports {
			transit.Disconnect()
		}
		this.transports.Clear()

		if (this.heartbeatTimer) {
			SetTimer(this.heartbeatTimer, 0)
			this.heartbeatTimer := ""
		}
		if (this.pruneTimer) {
			SetTimer(this.pruneTimer, 0)
			this.pruneTimer := ""
		}
		this.msgHistory := []
		this.activeConnections := Map()

		this.isEnabled := Config.Get("Communicator", "CommunicationEnabled", 0)
		if (!this.isEnabled) {
			if (IsSet(Main) && IsObject(Main))
				Main.Web.ExecuteScript("setCommsUI('Disabled');")
			return
		}

		this.isServer := (Config.Get("Main", "AccountType", "Main") = "Main")
		this.channelToken := Config.Get("Communicator", "DweetName", "")
		this.displayName := Config.Get("Communicator", "DisplayName", "Unknown_User")

		sysTransit := DweetTransport(this.channelToken, this.isServer, this.displayName)
		sysTransit.OnMessage := this.RouteMessage.Bind(this)
		sysTransit.Connect()
		this.transports["System"] := sysTransit

		BBTransit := DweetTransport(this.channelToken "_BoostBar", this.isServer, this.displayName)
		BBTransit.OnMessage := this.RouteMessage.Bind(this)
		BBTransit.Connect()
		this.transports["BoostBar"] := BBTransit

		if (!this.isServer) {
			privTransit := DweetTransport(this.channelToken "_" this.displayName, this.isServer, this.displayName)
			privTransit.OnMessage := this.RouteMessage.Bind(this)
			privTransit.Connect()
			this.transports["Private"] := privTransit
		}

		if (IsSet(Main) && IsObject(Main))
			Main.Web.ExecuteScript("setCommsUI('Not Connected');")
		this.Send("System", "Handshake", Map("name", this.displayName))

		this.heartbeatTimer := this.SendHeartbeat.Bind(this)
		SetTimer(this.heartbeatTimer, 15000)

		this.pruneTimer := this.PruneConnections.Bind(this)
		SetTimer(this.pruneTimer, 10000)
	}

	Send(channel, action, data := "") {
		if (!this.isEnabled || !this.transports)
			return
		
		targetLine := ""

		if (channel = "BoostBar" && this.transports.Has("BoostBar")) {
			targetLine := this.transports["BoostBar"]
		}

		else if (this.isServer && this.transports.Has(channel)) {
			targetLine := this.transports[channel]
		}
		else if (!this.isServer && channel = "System" && action != "Handshake" && this.transports.Has("Private")) {
			targetLine := this.transports["Private"]
		}

		else if (this.transports.Has("System")) {
			targetLine := this.transports["System"] 
		}

		if (!targetLine)
			return

		uniqueId := this.displayName "_" nowUnix() "_" Random(1000, 9999)
		payload := Map(
			"msgId", uniqueId
			, "sender", this.displayName
			, "role", this.isServer ? "Server" : "Client"
			, "channel", channel
			, "action", action
			, "data", data
			, "timestamp", nowUnix()
		)
		targetLine.Send(payload)
	}

	RouteMessage(msg) {
		if (!msg.Has("msgId"))
			return
		msgId := msg["msgId"]
		for id in this.msgHistory
			if (id = msgId)
				return
		this.msgHistory.InsertAt(1, msgId)
		if (this.msgHistory.Length > 20)
			this.msgHistory.Pop()
		
		sender := msg["sender"]
		channel := msg["channel"]
		action := msg["action"]
		isNewUser := !this.activeConnections.Has(sender)

		this.activeConnections[sender] := nowUnix()
		if (isNewUser) {
			this.RefreshUIConnectionState()
			if (this.isServer && sender != this.displayName) {
				newTrans := DweetTransport(this.channelToken "_" sender, this.isServer, this.displayName)
				newTrans.OnMessage := this.RouteMessage.Bind(this)
				newTrans.Connect()
				this.transports[sender] := newTrans
			}
		}
		if (IsSet(Main) && IsObject(Main))
			Main.Web.ExecuteScript("addMessageLog('" sender "', '" channel "', '" action "');")

		if (channel = "System") {
			if (action = "Handshake") {
				this.Send("System", "HandshakeAck", Map("name", this.displayName))
			}

			else if (action = "Disconnect") {
				if (this.activeConnections.Has(sender)) {
					this.activeConnections.Delete(sender)
					this.RefreshUIConnectionState()

					if (this.isServer && this.transports.Has(sender)) {
						this.transports[sender].Disconnect()
						this.transports.Delete(sender)
					}
				}
			}
		}

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

		else if  (channel = "MacroControl") {
			if (action = "Start" && msg["role"] = "Server") {
				if (nowUnix() - msg["timestamp"] > 15)
					return
				if (IsSet(Main) && IsObject(Main))
					Main.start()
			}
		}
	}

	RefreshUIConnectionState() {
		if (!IsSet(Main) || !IsObject(Main))
			return
		count := this.activeConnections.Count
		if (count = 0)
			Main.Web.ExecuteScript("setCommsUI('Not Connected');")
		else if (count = 1) {
			singleUser := ""
			for user in this.activeConnections {
				singleUser := user
				break
			}
			Main.Web.ExecuteScript("setCommsUI('Connected', '" WebViewToo.EscapeJS(singleUser) "');")
		} else
			Main.Web.ExecuteScript("setCommsUI('Connected', '" count " Users');")
	}

	BroadcastBuffs(state) {
		if (this.isServer)
			this.Send("BoostBar", "UpdateStats", state)
	}

	BroadcastStart() {
		if (this.isServer)
			this.Send("MacroControl", "Start")
	}

	SendHeartbeat() {
		if (this.isEnabled && this.transports) {
			this.Send("System", "Ping", Map("name", this.displayName))
		}
	}

	PruneConnections() {
		if (!this.isEnabled)
			return
		changed := false
		deadUsers := []

		for user, lastSeen in this.activeConnections
			if (nowUnix() - lastSeen > 45)
				deadUsers.Push(user)

		for _, user in deadUsers {
			this.activeConnections.Delete(user)
			changed := true
			if (this.isServer && this.transports.Has(user)) {
				this.transports[user].Disconnect()
				this.transports.Delete(user)
			}
		}

		if (changed)
			this.RefreshUIConnectionState()
	}
}
