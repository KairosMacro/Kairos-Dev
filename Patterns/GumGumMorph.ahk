loops := 2
longWalk := 6.25
shortWalk := longWalk / 4
halfWalk := longWalk / 2

walk(halfWalk, LeftKey)
walk(shortWalk, FwdKey)
walk(longWalk, RightKey)
walk(shortWalk, FwdKey)
walk(longWalk, LeftKey)

walk(longWalk, BackKey)
walk(shortWalk, RightKey)
walk(longWalk, FwdKey)
walk(shortWalk, RightKey)
walk(longWalk, BackKey)
walk(shortWalk, RightKey)
walk(longWalk, FwdKey)
walk(shortWalk, RightKey)
walk(longWalk, BackKey)

walk(longWalk, LeftKey)
walk(shortWalk, FwdKey)
walk(longWalk, RightKey)
walk(shortWalk, FwdKey)
walk(halfWalk, LeftKey)


walk(halfWalk, FwdKey, LeftKey)
walk(shortWalk, FwdKey, RightKey)
walk(longWalk, BackKey, RightKey)
walk(shortWalk, FwdKey, RightKey)
walk(longWalk, FwdKey, LeftKey)

walk(longWalk, BackKey, LeftKey)
walk(shortWalk, BackKey, RightKey)
walk(longWalk, FwdKey, RightKey)
walk(shortWalk, BackKey, RightKey)
walk(longWalk, BackKey, LeftKey)

walk(shortWalk, BackKey, RightKey)
walk(longWalk, FwdKey, RightKey)
walk(shortWalk, BackKey, RightKey)
walk(longWalk, BackKey, LeftKey)

walk(longWalk, FwdKey, LeftKey)
walk(shortWalk, FwdKey, RightKey)
walk(longWalk, BackKey, RightKey)
walk(shortWalk, FwdKey, RightKey)
walk(halfWalk, FwdKey, LeftKey)

