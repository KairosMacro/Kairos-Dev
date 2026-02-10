class dweet {
   __New(name) {
      this.name := name
      this.baseUrl := "https://dweet.cc"
      this.lastMessage := 0
      ; maybe add encryption later ? "this.salt := [string]"
   }

   SendMessage(str) {
      url := this.baseUrl "/dweet/for/" this.name "?json=" this.Encode(str)

      try {
         wr := ComObject("WinHttp.WinHttpRequest.5.1")
         wr.Open("GET", url, false)
         wr.Send()
         return wr.ResponseText
      } catch as e
         return "Error: " e.Message
   }

   RecieveMessage(ignoreOld := 20) {
      url := this.baseUrl "/get/latest/dweet/for/" this.name

      try {
         wr := ComObject("WinHttp.WinHttpRequest.5.1")
         wr.Open("GET", url, false)
         wr.Send()
         msg := wr.ResponseText
      } catch as e
         return ""

      if (RegExMatch(msg, '"json"\s*:\s*"((\\.|[^"\\])*)"', &match)) {
         clean := match[1]
         clean := StrReplace(clean, '\"', '"')
         clean := StrReplace(clean, '\\', '\')
         clean := StrReplace(clean, "\/", "/")
         
         if (RegExMatch(clean, '"unix"\s*:\s*(\d+)', &unix)) {
            unixTime := unix[1]
            if (unixTime <= this.lastMessage)
               return ""
            ; since computers might have a time offset, SYNC YOUR TIME WITH NIST.GOV TIME SERVERS
            now := nowUnix()
            if (now - unixTime > ignoreOld) {
               this.lastMessage := unixTime
               return ""
            }
            this.lastMessage := unixTime
         }
         return clean
      }
      return ""
   }

   Encode(str) {
      buff := Buffer(StrPut(str, "UTF-8"))
      StrPut(str, buff, "UTF-8")
      encoded := ""
      Loop buff.Size - 1 {
         byte := NumGet(buff, A_Index - 1, "UChar")
         char := Chr(byte)

         if (byte >= 128 || RegExMatch(char, "[^A-Za-z0-9\-_.~]")) {
            encoded .= "%" Format("{:02X}", byte)
         } else {
            encoded .= char
         }
      }
      return encoded
   }
}
