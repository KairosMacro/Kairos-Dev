#Warn All, Off

Padding := 8

AlignWidth  := (FieldWidth  / 2) - Padding
AlignHeight := (FieldHeight / 2) - Padding

MicroStep := 2
MicroHold := 10

MoveBalanced(MicroStep, MicroHold, FwdKey, BackKey, LeftKey, RightKey)
{
    walk(MicroStep, LeftKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, FwdKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, RightKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, BackKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, RightKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, FwdKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, LeftKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }

    walk(MicroStep, BackKey)
    Sleep MicroHold
    if BitmapVisible("combo-start") {
        DoCocoCatch()
        return
    }
}

if (index = 1) {

    Switch AltNumber {

        Case 0: ; Center
            Sleep 50

        Case 1: ; Top Left
            walk(AlignHeight, FwdKey)
            walk(AlignWidth,  LeftKey)
            Send "{" RotRight " 3}"

        Case 2: ; Top Right
            walk(AlignHeight, FwdKey)
            walk(AlignWidth,  RightKey)
            Send "{" RotLeft " 3}"

        Case 3: ; Bottom Right
            walk(AlignHeight, BackKey)
            walk(AlignWidth,  RightKey)
            Send "{" RotLeft " 1}"

        Case 4: ; Bottom Left
            walk(AlignHeight, BackKey)
            walk(AlignWidth,  LeftKey)
            Send "{" RotRight " 1}"
    }

    Send "{" RotUp " 8}"
    Loop 5
        Send "{" ZoomIn "}"

    Sleep 100
}

BitmapVisible(bmName, var:=0) {
    Gdip_GetImageDimensions(bitmaps[bmName], &nWidth, &nHeight)
    Gdip_LockBits(bitmaps[bmName], 0, 0, nWidth, nHeight, &nStride, &nScan, &nBitmap)

    pBM := Gdip_BitmapFromScreen(windowX+windowWidth-400 "|" windowY+windowHeight-400 "|400|400")
    Gdip_GetImageDimensions(pBM, &hWidth, &hHeight)
    Gdip_LockBits(pBM, 0, 0, hWidth, hHeight, &hStride, &hScan, &hBitmap)

    sx2 := hWidth  - nWidth
    sy2 := hHeight - nHeight
    found := (0 = Gdip_LockedBitsSearch(hStride, hScan, hWidth, hHeight, nStride, nScan, nWidth, nHeight, &foundX, &foundY, 0, 0, sx2, sy2, var))

    Gdip_UnlockBits(pBM, &hBitmap)
    Gdip_DisposeImage(pBM)
    Gdip_UnlockBits(bitmaps[bmName], &nBitmap)

    return found
}

/**
0 = missed
1 = dropped
2 = finished or in progress
-1 = nothing
 */
GetComboState(var := 30) {
    if BitmapVisible("combo-miss", 30)
        return 0

    Gdip_GetImageDimensions(bitmaps["combo"], &nWidth, &nHeight)
    Gdip_LockBits(bitmaps["combo"], 0, 0, nWidth, nHeight, &nStride, &nScan, &nBitmap)

    pBM := Gdip_BitmapFromScreen(windowX+windowWidth-400 "|" windowY+windowHeight-400 "|400|400")
    Gdip_SetBitmapToClipboard(pBM)
    Gdip_GetImageDimensions(pBM, &hWidth, &hHeight)
    Gdip_LockBits(pBM, 0, 0, hWidth, hHeight, &hStride, &hScan, &hBitmap)

    sx2 := hWidth - nWidth
    sy2 := hHeight - nHeight
    found1 := found2 := 0
    found1 := (0 = Gdip_LockedBitsSearch(hStride, hScan, hWidth, hHeight, nStride, nScan, nWidth, nHeight, &foundX1, &foundY1, 0, 0, sx2, sy2, var, 1))

    if (found1)
        found2 := (0 = Gdip_LockedBitsSearch(hStride, hScan, hWidth, hHeight, nStride, nScan, nWidth, nHeight, &foundX2, &foundY2, 0, 0, sx2, sy2, var, 4))

    Gdip_UnlockBits(pBM, &hBitmap)
    Gdip_DisposeImage(pBM)
    Gdip_UnlockBits(bitmaps["combo"], &nBitmap)

    if (found1)
        if (found2 && (foundX2 - foundX1 > 30) && Abs(foundY2 - foundY1) < 15)
            return 1
        else
            return 2
    return -1
}


ReverseAlignRotation() {
    Switch AltNumber {
        Case 0: ; Center – nothing to undo
            Sleep 50
        Case 1: ; Top Left had RotRight 3  ->  undo with RotLeft 3
            Send "{" RotLeft " 3}"
        Case 2: ; Top Right had RotLeft 3  =>  undo with RotRight 3
            Send "{" RotRight " 3}"
        Case 3: ; Bottom Right had RotLeft 1  ->  undo with RotRight 1
            Send "{" RotRight " 1}"
        Case 4: ; Bottom Left had RotRight 1  ->  undo with RotLeft 1
            Send "{" RotLeft " 1}"
    }
}

ReApplyAlignRotation() {
    Switch AltNumber {
        Case 0:
            Sleep 50
        Case 1:
            Send "{" RotRight " 3}"
        Case 2:
            Send "{" RotLeft " 3}"
        Case 3:
            Send "{" RotLeft " 1}"
        Case 4:
            Send "{" RotRight " 1}"
    }
}

ReturnToPosition() {
    Switch AltNumber {
        Case 0:
            Sleep 50
        Case 1:
            walk(AlignHeight, FwdKey)
            walk(AlignWidth,  LeftKey)
        Case 2:
            walk(AlignHeight, FwdKey)
            walk(AlignWidth,  RightKey)
        Case 3:
            walk(AlignHeight, BackKey)
            walk(AlignWidth,  RightKey)
        Case 4:
            walk(AlignHeight, BackKey)
            walk(AlignWidth,  LeftKey)
    }
}

locateCoco() {
    static init := false
    static coco := ""
    static lastPos := ""
    static nWidth, nHeight, nStride, nScan, nBitmap
    if (!init) {
        coco := Gdip_CreateBitmap(7, 7)
        G := Gdip_GraphicsFromImage(coco)
        Gdip_GraphicsClear(G, 0xFF99AAB5)
        Gdip_DeleteGraphics(G)

        Gdip_GetImageDimensions(coco, &nWidth, &nHeight)
        Gdip_LockBits(coco, 0, 0, nWidth, nHeight, &nStride, &nScan, &nBitmap)
        init := true
    }
    if (lastPos) {
        scanW := Round(windowWidth * 0.2)
        scanH := Round(windowHeight * 0.2)
        screenX := (windowX + lastPos.x) - (scanW // 2)
        screenY := (windowY + lastPos.y) - (scanH // 2)

        scanX := (screenX < windowX) ? windowX : screenX
        scanY := (screenY < windowY) ? windowY : screenY

        pBM := Gdip_BitmapFromScreen(scanX "|" scanY "|" scanW "|" scanH)
        Gdip_GetImageDimensions(pBM, &hWidth, &hHeight)
        Gdip_LockBits(pBM, 0, 0, hWidth, hHeight, &hStride, &hScan, &hBitmap)
        sx2 := hWidth - nWidth
        sy2 := hHeight - nHeight
        if (0 = Gdip_LockedBitsSearch(hStride, hScan, hWidth, hHeight, nStride, nScan, nWidth, nHeight, &foundX, &foundY, 0, 0, sx2, sy2)) {
            Gdip_UnlockBits(pBM, &hBitmap)
            Gdip_DisposeImage(pBM)

            finalX := (scanX - windowX) + foundX
            finalY := (scanY - windowY) + foundY

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
    if (0 = Gdip_LockedBitsSearch(aStride, aScan, aWidth, aHeight, nStride, nScan, nWidth, nHeight, &foundX, &foundY, 0, 0, sx2, sy2)) {
        Gdip_UnlockBits(pBMAll, &aBitmap)
        Gdip_DisposeImage(pBMAll)

        lastPos := {x: foundX + windowX, y: foundY + windowY}
        return {x: foundX + windowX, y: foundY + windowY}
    }
    lastPos := ""
    Gdip_UnlockBits(pBMAll, &aBitmap)
    Gdip_DisposeImage(pBMAll)
    return 0
}


gotoCoco() {
    start := A_TickCount
    GetRobloxClientPos()
    if !(pos := locateCoco()) {
        rotate()
        return
    }
    rotate(true)

    centerX := windowWidth // 2, centerY := windowHeight // 2
    deadX := windowWidth * 0.035, deadY := windowHeight * 0.035

    heldX := ""
    heldY := ""
    miss := 0

    while (A_TickCount - start < 10000) {
        if !(pos := locateCoco()) {
            if (miss++ > 3)
                break
            continue
        }
        miss := 0
        vecX := pos.x - centerX
        vecY := pos.y - centerY
        targetX := targetY := ""
        if (Abs(vecX) > deadX)
            targetX := (vecX > 0) ? RightKey : LeftKey
        if (Abs(vecY) > deadY)
            targetY := (vecY > 0) ? BackKey : FwdKey

        if (heldX != targetX) {
            if heldX
                send "{" heldX " up}"
            if targetX
                send "{" targetX " down}"
            heldX := targetX
        }
        if (heldY != targetY) {
            if heldY
                send "{" heldY " up}"
            if targetY
                send "{" targetY " down}"
            heldY := targetY
        }

        if (heldX = "" && heldY = "")
            break
    }
    Send "{" FwdKey " up}{" BackKey " up}{" LeftKey " up}{" RightKey " up}"
}

rotate(reset := false) {
    static step := 0
    static count := 0
    static last := 0
    limit := 160

    if (reset) {
        last := A_TickCount + 275
        step := 0
        return
    }
    if (step >= limit)
        return
    if (A_TickCount - last < 40)
        return
    last := A_TickCount
    step++
    if (Mod(count, 4) < 2) {
        send "{" RotLeft "}"
        compensate(1)
    } else {
        send "{" RotRight "}"
        compensate(-1)
    }
    count++
}

compensate(dir) {
    static cycle := []
    if (cycle.Length = 0) {
        cycle := [
            [FwdKey],
            [FwdKey, RightKey],
            [RightKey],
            [RightKey, BackKey],
            [BackKey],
            [BackKey, LeftKey],
            [LeftKey],
            [LeftKey, FwdKey]
        ]
    }

    f := GetKeyState(FwdKey)
    b := GetKeyState(BackKey)
    l := GetKeyState(LeftKey)
    r := GetKeyState(RightKey)
    idx := (f && l ? 8 : f && r ? 2 : b && l ? 6 : b && r ? 4 : f ? 1 : b ? 5 : l ? 7 : r ? 3 : 0)

    if idx = 0
        return

    newIdx := idx + dir
    if newIdx > 8
        newIdx := 1
    else if newIdx < 1
        newIdx := 8
    old := cycle[idx]
    new := cycle[newIdx]
    for k in old {
        inNew := false
        for nk in new {
            if (k = nk) {
                inNew := true
                break
            }
        }
        if (!inNew) {
            send "{"  k " up}"
        }
    }
    for k in new {
        inOld := false
        for ok in old {
            if (k = ok) {
                inOld := true
                break
            }
        }
        if (!inOld)
            send "{"  k " down}"
    }
}


DoCocoCatch() {
    ReverseAlignRotation()
    Sleep 100

    SetTimer(spam, 1)

    loop {
        gotoCoco()
        if BitmapVisible("combo-miss")
            break
    }

    SetTimer(spam, 0)

    Send "{" FwdKey " up}{" BackKey " up}{" LeftKey " up}{" RightKey " up}"
    Sleep 100

    Send "{" RotDown " 4}"
    Sleep 150

    loop {
        GetRobloxClientPos()
        if BitmapVisible("sprinkler")
            break
        Sleep 50
    }

    ReturnToPosition()
    Sleep 100

    ReApplyAlignRotation()
    Sleep 100
}

spam() {
    send "{" ZoomOut "}{" RotUp "}"
}


loop {
    tooltip GetComboState(5)
    sleep 100
}
