class ActivityLog {
	static Entries := []
	static MaxEntries := 500
	static LogGui := ""
	static LogList := ""

	static Add(msg) {
		timeStr := FormatTime(A_Now, "HH:mm:ss")
		entry := timeStr "  |  " msg
		this.Entries.Push(entry)
		if (this.Entries.Length > this.MaxEntries)
			this.Entries.RemoveAt(1)
		this.AppendToGui(entry)
	}

	static Toggle(*) {
		if (this.LogGui != "")
			this.Close()
		else
			this.Open()
	}

	static Open(*) {
		if (this.LogGui != "") {
			try WinActivate("ahk_id " this.LogGui.Hwnd)
			return
		}

		isDark := Config.Get("Main", "DarkMode", 1)
		this.LogGui := Gui("+AlwaysOnTop +Resize +MinSize400x200", "Kairos Activity Log")
		this.LogGui.OnEvent("Close", (*) => this.Close())
		this.LogGui.OnEvent("Size", this.OnResize.Bind(this))

		this.LogGui.SetFont("s10", "Consolas")
		this.LogGui.Add("Text", "x10 y8 w480 vHeader", "Time         |  Event")

		this.LogGui.SetFont("s9", "Consolas")
		this.LogList := this.LogGui.Add("ListBox", "x10 y30 w480 h310 vLogList ReadOnly")

		this.LogGui.SetFont("s9 cDefault Norm", "MS Sans Serif")
		this.LogGui.Add("Button", "x10 y348 w80 h25 vClearBtn", "Clear").OnEvent("Click", (*) => this.Clear())

		this.LogGui.Show("w500 h380")
		SetWindowTheme(this.LogGui, isDark)
		SetWindowAttribute(this.LogGui, isDark)

		for entry in this.Entries
			this.LogList.Add([entry])
		if (this.Entries.Length > 0)
			SendMessage(0x0197, this.Entries.Length - 1, 0, this.LogList)
	}

	static OnResize(thisGui, MinMax, W, H) {
		if (MinMax = -1)
			return
		try {
			this.LogGui["Header"].Move(, , W - 20)
			this.LogList.Move(, , W - 20, H - 70)
			this.LogGui["ClearBtn"].Move(, H - 32)
		}
	}

	static Close(*) {
		if (this.LogGui != "") {
			try this.LogGui.Destroy()
			this.LogGui := ""
			this.LogList := ""
		}
	}

	static AppendToGui(entry) {
		if (this.LogGui = "" || this.LogList = "")
			return
		try {
			this.LogList.Add([entry])
			count := SendMessage(0x018B, 0, 0, this.LogList)
			SendMessage(0x0197, count - 1, 0, this.LogList)
		}
	}

	static Clear(*) {
		this.Entries := []
		if (this.LogList != "")
			try SendMessage(0x0184, 0, 0, this.LogList)
	}
}
