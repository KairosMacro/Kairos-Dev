; ===================
; TIME UTILITY
; ===================
/**
 * @description QueryPerformanceCounter
 * @author Thqby
 **/
QPC() {
	static _ := 0, f := (DllCall("QueryPerformanceFrequency", "int64*", &_), _ /= 1000)
	return (DllCall("QueryPerformanceCounter", "int64*", &_), _ / f)
}

/**
 * @description NowUnix
 * @author N/A
 **/
nowUnix() => DateDiff(A_NowUTC, "19700101000000", "Seconds")

/**
 * @description HyperSleep
 * @author N/A
 **/
HyperSleep(ms)
{
	static freq := (DllCall("QueryPerformanceFrequency", "Int64*", &f := 0), f)
	DllCall("QueryPerformanceCounter", "Int64*", &begin := 0)
	current := 0, finish := begin + ms * freq / 1000
	while (current < finish)
	{
		if ((finish - current) > 30000)
		{
			DllCall("Winmm.dll\timeBeginPeriod", "UInt", 1)
			DllCall("Sleep", "UInt", 1)
			DllCall("Winmm.dll\timeEndPeriod", "UInt", 1)
		}
		DllCall("QueryPerformanceCounter", "Int64*", &current)
	}
}

/**
* @description: Simple GetDurationFormatEx parser
* https://learn.microsoft.com/en-us/windows/win32/api/winnls/nf-winnls-getdurationformatex
* @author SP
**/
duration_from_secs(secs, format:="hh:mm:ss", capacity:=64)
{
	dur := Buffer(capacity), DllCall("GetDurationFormatEx"
		, "Ptr", 0
		, "UInt", 0
		, "Ptr", 0
		, "Int64", secs*10000000
		, "Str", format
		, "Ptr", dur.Ptr
		, "Int", 32)
	return StrGet(dur)
}
hms_from_secs(secs) => duration_from_secs(secs, ((secs >= 3600) ? "h'h' m" : "") ((secs >= 60) ? "m'm' s" : "") "s's'")

; ===================
; OBJECT/ARRAY UTILITY
; ===================
Array.Prototype.DefineProp("index_of", { Call: array_index_of })
Array.Prototype.DefineProp("join", { Call: array_join })
Array.Prototype.DefineProp("has_value", { Call: array_has_value })

array_index_of(arr, val) {
	for k, v in arr {
		if (v == val)
			return k
	}
	return 0
}

array_join(arr, delim) {
	out := ""
	try {
		for k, v in arr
			out .= (out == "" ? "" : delim) . v
		return out
	} catch
		return 0
}

array_has_value(arr, val) {
	for k, v in arr
		if (v == val)
			return 1
	return 0
}

ObjFullyClone(obj)
{
	nobj := obj.Clone()
	for k, v in nobj
		if IsObject(v)
			nobj[k] := ObjFullyClone(v)
	return nobj
}

ObjMinIndex(obj)
{
	for k, v in obj
		return k
	return 0
}
