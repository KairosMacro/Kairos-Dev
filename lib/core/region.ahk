class region {
	static debug_box := ""

	; --- TOP HUD ---
	; 0 = exact, 1 = compensated (buff collected)
	static buff_region(win, mode := 0) {
		coords := [[36, 37], [30, 50]]
		return win.x "|" win.y + win.y_offset + coords[mode + 1][1] "|" win.w "|" coords[mode + 1][2]
	}

	; text for y-offset.
	static honey_region(win) => (win.x + (win.w // 2) - 241 "|" win.y + win.y_offset + 4 "|" 221 "|" 28)

	static pollen_region(win) => (win.x + (win.w // 2) + 59 "|" win.y + win.y_offset + 3 "|" 221 "|" 29)

	; inv, quests, etc...
	static bss_tabs_region(win, tab := 0) {
		coords := [ ; OFFSETS
			[0, 3, 46, 51], ; inv
			[53, 5, 48, 48], ; quests
			[110, 5, 48, 48], ; bees
			[168, 2, 45, 53], ; badges
			[218, 0, 56, 56], ; settings
			[275, 3, 54, 49] ; shop
		]
		if tab = 0 {
			return win.x + 6 "|" win.y + win.y_offset + 76 "|" 329 "|" 56
		} else { ; SELECTED
			return win.x + 6 + coords[tab][1] "|" win.y + win.y_offset + 76 + coords[tab][2] "|" coords[tab][3] "|" coords[tab][4]
		}
	}

	; ALL DEPENDS ON FIRST LAUNCH, so defaults to finding down to bottom window
	static bss_menu_region(win) => (win.x "|" win.y + win.y_offset + 146 "|" 322 "|" win.h - win.y_offset - 146)

	; --- BOTTOM HUD ---

	static passive_region(win, slot := 0) {
		if slot = 0 {
			return win.x + (win.w // 2) - 257 "|" win.y + win.h - 142 "|" 509 "|" 36
		} else {
			slot -= 1
			return win.x + (win.w // 2) - 257 + (slot * 40) "|" win.y + win.h - 142 "|" 36 "|" 36
		}
	}

	static hotbar_region(win, slot := 0) {
		if slot = 0 {
			return win.x + (win.w // 2) - 261 "|" win.y + win.h - 102 "|" 517 "|" 68
		} else {
			slot -= 1
			return win.x + (win.w // 2) - (261 + (slot >= 3 ? 1 : 0)) + (slot * 75) "|" win.y + win.h - 102 "|" 68 "|" 68
		}
	}

	static npc_name_region(win) => (win.x + (win.w // 2) - 255 "|" win.y + win.h - 208 - Round((win.h * 0.2679) - 120.48) "|" 236 "|" 50)

	; including name
	static npc_dialog_region(win) => (win.x + (win.w // 2) - 255 "|" win.y + win.h - 208 - Round((win.h * 0.2679) - 120.48) "|" 511 "|" 208)

	; --- MIDDLE HUD ---

	; "E button" + message
	static prompt_region(win, e_button := 0) => (win.x + (win.w // 2) - 180 + (e_button ? 0 : 4) "|" win.y + win.y_offset + 36 "|" 356 - (e_button ? 0 : 4) "|" 66)

	; plant/harvest
	static planter_prompt_region(win) => (win.x + (win.w // 2) - 218 "|" win.y + (win.h // 2) - 106 "|" 437 "|" 191)

	; --- MISC ---

	static chat_region(win) {

	}

	static gameplay_region(win) {

	}

	static show_region(input, is_visible := true) {
		if (!is_visible) {
			if (this.debug_box) {
				this.debug_box.Destroy()
				this.debug_box := ""
			}
			return
		}

		if this.debug_box {
			return
		}

		this.debug_box := Gui("+AlwaysOnTop -Caption +ToolWindow -DPIScale +E0x20")
		this.debug_box.BackColor := "Red"
		WinSetTransparent(100, this.debug_box.Hwnd)
		a := StrSplit(input, "|")
		this.debug_box.Show("x" a[1] " y" a[2] " w" a[3] " h" a[4] " NoActivate")
	}
}