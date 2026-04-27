#SingleInstance Off
#NoTrayIcon
#Warn All, Off

#Include "..\..\Lib\Utils\Gdip_All.ahk"
#Include "..\..\Lib\Utils\Gdip_ImageSearch.ahk"
#iNCLUDE "..\..\Lib\Utils\Utility.ahk"

if (A_Args.Length < 1)
	ExitApp

TargetPID := A_Args[1]
pToken := Gdip_Startup()
OnExit((*) => Gdip_Shutdown(pToken))
DetectHiddenWindows true

saw_coconut := false

loop {
	start_time := QPC()
	if !WinExist("ahk_pid " TargetPID) {
		ExitApp
	}

	hwnd := WinExist("ahk_exe RobloxPlayerBeta.exe")
	if (!hwnd) {
		sleep 1000
		continue
	}

	pos := locateCoco(hwnd)
	try {
		if (pos) {
			SendMessage(0x5001, Round(pos.x), Round(pos.y), , "ahk_class AutoHotkey ahk_pid " TargetPID)
		} else {
			SendMessage(0x5002, 0, 0, , "ahk_class AutoHotkey ahk_pid " TargetPID)
		}
	} catch
		ExitApp
}

locateCoco(hwnd) {
	WinGetClientPos(&windowX, &windowY, &windowWidth, &windowHeight, hwnd)
	static init := false
	static coco := ""
	static lastPos := ""
	static nWidth, nHeight, nStride, nScan, nBitmap

	if (!init) {
		coco := Gdip_BitmapFromBase64("iVBORw0KGgoAAAANSUhEUgAAAAcAAAAHCAYAAADEUlfTAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsMAAA7DAcdvqGQAAABmZVhJZklJKgAIAAAAAQBphwQAAQAAABoAAAAAAAAAAwAAkAcABAAAADAyMzABoAMAAQAAAAEAAAAFoAQAAQAAAEQAAAAAAAAAAgABAAIABAAAAFI5OAACAAcABAAAADAxMDAAAAAAIvvHMbnUA7gAAAATSURBVBhXY5i5aut/BnxgyCgAADdzFMLU+WDwAAAAAElFTkSuQmCC")
		Gdip_GetImageDimensions(coco, &nWidth, &nHeight)
		Gdip_LockBits(coco, 0, 0, nWidth, nHeight, &nStride, &nScan, &nBitmap)
		init := true
	}

	if (lastPos) {
		scanW := Round(windowWidth * 0.2)
		scanH := Round(windowHeight * 0.2)
		
		relX := lastPos.x - (scanW // 2)
		relY := lastPos.y - (scanH // 2)

		relX := Max(0, relX)
		relY := Max(0, relY)
		scanW := Min(scanW, windowWidth - relX)
		scanH := Min(scanH, windowHeight - relY)

		absX := windowX + relX
		absY := windowY + relY

		pBM := Gdip_BitmapFromScreen(absX "|" absY "|" scanW "|" scanH)
		Gdip_GetImageDimensions(pBM, &hWidth, &hHeight)
		Gdip_LockBits(pBM, 0, 0, hWidth, hHeight, &hStride, &hScan, &hBitmap)
		
		sx2 := hWidth - nWidth
		sy2 := hHeight - nHeight
		
		if (sx2 > 0 && sy2 > 0 && 0 = Gdip_LockedBitsSearch(hStride, hScan, hWidth, hHeight, nStride, nScan, nWidth, nHeight, &foundX, &foundY, 0, 0, sx2, sy2)) {
			Gdip_UnlockBits(pBM, &hBitmap)
			Gdip_DisposeImage(pBM)

			finalX := relX + foundX
			finalY := relY + foundY
			lastPos := {x: finalX, y: finalY}
			return {x: finalX, y: finalY}
		}
		
		Gdip_UnlockBits(pBM, &hBitmap)
		Gdip_DisposeImage(pBM)
	}

	pBMAll := Gdip_BitmapFromScreen(windowX "|" windowY "|" windowWidth "|" windowHeight)
	Gdip_GetImageDimensions(pBMAll, &aWidth, &aHeight)
	Gdip_LockBits(pBMAll, 0, 0, aWidth, aHeight, &aStride, &aScan, &aBitmap)
	
	sx2 := aWidth - nWidth
	sy2 := aHeight - nHeight
	
	if (sx2 > 0 && sy2 > 0 && 0 = Gdip_LockedBitsSearch(aStride, aScan, aWidth, aHeight, nStride, nScan, nWidth, nHeight, &foundX, &foundY, 0, 0, sx2, sy2)) {
		Gdip_UnlockBits(pBMAll, &aBitmap)
		Gdip_DisposeImage(pBMAll)
		lastPos := {x: foundX, y: foundY}
		return {x: foundX, y: foundY}
	}
	
	lastPos := ""
	Gdip_UnlockBits(pBMAll, &aBitmap)
	Gdip_DisposeImage(pBMAll)
	return 0
}
