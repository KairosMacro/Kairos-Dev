Send "{" RotUp " 5}"
loop reps {
	Walk(5 * size + A_Index, TCFBKey, TCLRKey)
	Walk(10 * size + A_Index, AFCLRKey, "")
	Walk(5 * size + A_Index, TCFBKey, TCLRKey)
	Walk(10 * size + A_Index, AFCFBKey, "")
	Walk(5 * size + A_Index, TCFBKey, AFCLRKey)
	Walk(10 * size + A_Index, TCLRKey, "")
	Walk(5 * size + A_Index, TCFBKey, AFCLRKey)
	Walk(5 * size + A_Index, AFCFBKey, AFCLRKey)
	Walk(10 * size + A_Index, TCLRKey, "")
	Walk(5 * size + A_Index, AFCFBKey, AFCLRKey)
	Walk(10 * size + A_Index, TCFBKey, "")
	Walk(5 * size + A_Index, AFCFBKey, TCLRKey)
	Walk(10 * size + A_Index, AFCLRKey, "")
	Walk(5 * size + A_Index, AFCFBKey, TCLRKey)
}
Send "{" RotDown " 5}"
