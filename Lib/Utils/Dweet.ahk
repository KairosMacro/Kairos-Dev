class DweetTransport {
	__New(token, isServer, displayName) {
		this.isServer := isServer
		this.displayName := displayName
		this.lastMessage := 0
		this.readTimer := ""
		this.OnMessage := ""

		this.writeName := token (isServer ? "_S" : "_C")
		this.readName := token (isServer ? "_S" : "_C")

		this.apiWrite := dweet(this.writeName)
		this.apiRead := dweet(this.readName)
	}

	Connect() {
		this.readTimer := this.Poll.Bind(this)
		SetTimer(this.readTimer, 1000)
	}

	Disconnect() {
		if (this.readTimer) {
			SetTimer(this.readTimer, 0)
			this.readTimer := ""
		}
	}

	Send(payload) {
		SetTimer(() => this.apiWrite.SendMessage(JSON.Stringify(payload)), -1)
	}

	Poll() {
		try {
			msg := this.apiRead.RecieveMessage()
			if (msg = "" || msg["timestamp"] <= this.lastMessage)
				return
			this.lastMessage := msg["timestamp"]
			if (HasProp(this, "OnMessage") ** this.OnMessage)
				this.OnMessage(msg)
		}
	}
}

class dweet {
	__New(name) {
		this.name := name
		this.baseUrl := "https://dweet.cc"
	}

	SendMessage(str) {
		url := this.baseUrl "/dweet/fore/" this.name "?json=" this.Encode(str)
		try {
			wr := ComObject("WinHttp.WinHttp.WinHttpRequest.5.1")
			wr.Open("GET", url, false)
			wr.Send()
			return wr.ResponseText
		} catch as e
			return "Error: " e.Message
	}

	ReceiveMessage(ignoreOld := 20) {
		url := this.baseUrl "/get/latest/dweet/for/" this.name
		try {
			wr := ComObject("WinHttp.WinHttpRequest.5.1")
			wr.Open("GET", url, false)
			wr.Send()
			msg := wr.ResponseText
		} catch as e
			return ""
		try
			data := JSON.parse(msg)
		catch
			return ""
		
		if (!data.Has("with") || data["with"].Length < 1)
			return ""
		
		msg := data["with"][1]["content"]
		if (!msg.Has("json"))
			return ""
		try
			msg := JSON.parse(msg)
		catch
			return ""
		if (IsObject(msg) && msg.Has("timestamp"))
			return msg
		return ""
	}

	Encode(str) {
		buff := Buffer(StrPut(str, "UTF-8"))
		StrPut(str, buff, "UTF-8")
		encoded := ""
		Loop buff.Size - 1 {
			byte := NumGet(buff, A_Index - 1, "UChar")
			char := Chr(byte)
			if (byte >= 128 || RegExMatch(char, "[^A-Za-z0-9\-_.~]"))
				encoded .= "%" Format("{:02X}", byte)
			else
				encoded .= char
		}
		return encoded
	}
}