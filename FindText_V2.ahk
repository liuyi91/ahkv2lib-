#Requires AutoHotkey v2.0-
;  脚本作者 : FeiYue
;  最新版本 : 8.8
;  更新时间 : 2022-03-22
;  v2部分移植 : Tebayaki 2022-04-19

; ok:=FindText.Find(&X, &Y, 0, 0, 0, 0, 0, 0, Text)
class FindText {
	static bind := { id: 0, mode: 0, oldStyle: 0 }

	static bits := { hBM: 0, oldzw: 0, oldzh: 0 }

	static Cursor := 0

	static Find(&outputX := "", &outputY := "", x1 := 0, y1 := 0, x2 := 0, y2 := 0, err1 := 0, err0 := 0, text := "", ScreenShot := 1, FindAll := 1, JoinText := 0, offsetX := 20, offsetY := 10, dir := 1) {
			if outputX ~= "i)^\s*wait[10]?\s*$" {
				found := !InStr(outputX, "0"), time := outputY, timeout := A_TickCount + Round(time * 1000), outputX := outputY := ""
				loop {
					While (ok := this.Find(&outputX, &outputY, x1, y1, x2, y2, err1, err0, text, ScreenShot, FindAll, JoinText, offsetX, offsetY, dir)) && found {
						v := ok[1], x := v.1, y := v.2, w := v.3, h := v.4
						, hash := this.GetPicHash(x, y, x + w - 1, y + h - 1, 0), Sleep(10)
						if hash = this.GetPicHash(x, y, x + w - 1, y + h - 1, 1)
							return ok
					}
					if !found && !ok
						return 1
					if time >= 0 && A_TickCount >= timeout
						break
					Sleep(100)
				}
				return 0
			}
			centerX := Round(x1 + x2) // 2, centerY := Round(y1 + y2) // 2
			if (x1 * x1 + y1 * y1 + x2 * x2 + y2 * y2 <= 0)
				n := 150000, x := y := -n, w := h := 2 * n
			else
				x := Min(x1, x2), y := Min(y1, y2), w := Abs(x2 - x1) + 1, h := Abs(y2 - y1) + 1
			bits := this.GetBitsFromScreen(&x, &y, &w, &h, ScreenShot, &zx, &zy, &zw, &zh), x -= zx, y -= zy, info := [], this.ok := 0
			loop parse, text, "|"
				if IsObject(j := this.PicInfo(A_LoopField))
					info.Push(j)
			if w < 1 || h < 1 || !(num := info.Length) || !bits.Scan0
				return 0
			arr := [], info2 := [], k := 0, s := "", mode := (IsObject(JoinText) ? 2 : JoinText ? 1 : 0)
			for i, j in info
				k := Max(k, j[2] * j[3]), s .= "|" i, v := (mode = 1 ? i : j[11]), (mode && !info2[v] && info2[v] := []), (mode && info2[v].Push(j))
			JoinText := mode = 1 ? [s] : JoinText
			s1 := Buffer(k * 4), s0 := Buffer(k * 4), ss := Buffer(2 * (w + 2) * (h + 2))
			, FindAll := dir = 9 ? 1 : FindAll
			, allpos_max := FindAll || JoinText ? 10240 : 1
			, ini := { sx: x, sy: y, sw: w, sh: h, zx: zx, zy: zy, zw: zw, zh: zh, bits: bits, ss: ss.Ptr, s1: s1.Ptr, s0: s0.Ptr, allpos_max: allpos_max }
			loop 2 {
				if err1 = 0 && err0 = 0 && (num > 1 || A_Index > 1)
					err1 := 0.05, err0 := 0.05
				ini.err1 := err1, ini.err0 := err0
				if !JoinText {
					allpos := Buffer(allpos_max * 8)
					for i, j in info
						loop this.PicFind(ini, j, dir, &allpos, ini.sx, ini.sy, ini.sw, ini.sh) {
							x := NumGet(allpos, 8 * A_Index - 8, "uint") + zx
							, y := NumGet(allpos, 8 * A_Index - 4, "uint") + zy
							, w := j[2], h := j[3], comment := j[11]
							, arr.Push({ 1: x, 2: y, 3: w, 4: h, x: x + w // 2, y: y + h // 2, id: comment })
							if !FindAll
								break 2
						}
				} else {
					for k, v in JoinText {
						v := RegExReplace(v, "\s*\|[|\s]*", "|")
						, v := StrSplit(Trim(v, "|"), (InStr(v, "|") ? "|" : ""))
						, this.JoinText(ini, arr, info2, v, offsetX, offsetY, FindAll, 1, v.Length, dir, 0, 0, ini.sx, ini.sy, ini.sw, ini.sh)
						if !FindAll && arr.Length
							break 2
					}
					if err1 != 0 || err0 != 0 || arr.Length || info[1][12]
						break
				}
				if dir = 9
					arr := this.Sort2(arr, centerX, centerY)
				if arr.Length {
					OutputX := arr[1].x, OutputY := arr[1].y, this.ok := arr
					return arr
				}
				return 0
			}
		}

	; 按照从左到右、从上到下的顺序排序Find的结果, 忽略轻微的Y坐标差距，返回排序后的数组对象
	static Sort(ok, dy := 10) {
			if !IsObject(ok)
				return ok
			s := "", n := 150000, ypos := []
			For k, v in ok {
				x := v.x, y := v.y, add := 1
				For k1, v1 in ypos
					if Abs(y - v1) <= dy {
						y := v1, add := 0
						Break
					}
				if (add)
					ypos.Push(y)
				s .= (y * n + x) "." k "|"
			}
			s := Trim(s, "|")
			s := Sort(s, "N D|")
			ok2 := []
			Loop Parse, s, "|"
				ok2.Push(ok[StrSplit(A_LoopField, ".")[2]])
			return ok2
		}

	; 以指定点为中心，按从近到远排序Find的结果,返回排序后的数组对象
	static Sort2(ok, px, py) {
			if !IsObject(ok)
				return ok
			s := ""
			For k, v in ok
				s .= ((v.x - px) ** 2 + (v.y - py) ** 2) "." k "|"
			s := Trim(s, "|")
			s := Sort(s, "N D|")
			ok2 := []
			Loop Parse, s, "|"
				ok2.Push(ok[StrSplit(A_LoopField, ".")[2]])
			return ok2
		}

	; 按指定的查找方向，排序Find的结果，返回排序后的数组
	static Sort3(ok, dir := 1) {
			if !IsObject(ok)
				return ok
			s := "", n := 150000
			For k, v in ok
				x := v.1, y := v.2
			, s .= (dir = 1 ? y * n + x
				: dir = 2 ? y * n - x
					: dir = 3 ? -y * n + x
						: dir = 4 ? -y * n - x
							: dir = 5 ? x * n + y
								: dir = 6 ? x * n - y
									: dir = 7 ? -x * n + y
										: dir = 8 ? -x * n - y : y * n + x) "." k "|"
			s := Trim(s, "|")
			s := Sort(s, "N D|")
			ok2 := []
			Loop Parse, s, "|"
				ok2.Push(ok[StrSplit(A_LoopField, ".")[2]])
			return ok2
		}

	static GetPicHash(x1 := 0, y1 := 0, x2 := 0, y2 := 0, ScreenShot := 1) {
			static h := DllCall("LoadLibrary", "Str", "ntdll", "Ptr")
			if (x1 * x1 + y1 * y1 + x2 * x2 + y2 * y2 <= 0)
				n := 150000, x := y := -n, w := h := 2 * n
			else
				x := Min(x1, x2), y := Min(y1, y2), w := Abs(x2 - x1) + 1, h := Abs(y2 - y1) + 1
			bits := this.GetBitsFromScreen(&x, &y, &w, &h, ScreenShot, &zx, &zy), x -= zx, y -= zy
			if (w < 1 || h < 1 || !bits.Scan0)
				return 0
			hash := 0, Stride := bits.Stride, p := bits.Scan0 + (y - 1) * Stride + x * 4, w *= 4
			Loop h
				hash := (hash * 31 + DllCall("ntdll\RtlComputeCrc32", "uint", 0, "Ptr", p += Stride, "uint", w, "uint")) & 0xFFFFFFFF
			return hash
		}

	static GetBitsFromScreen(&x, &y, &w, &h, ScreenShot := 1, &zx := "", &zy := "", &zw := "", &zh := "") {
			(!IsObject(this.bits) && this.bits := []), bits := this.bits
			if !ScreenShot && bits.Scan0 {
				zx := bits.zx, zy := bits.zy, zw := bits.zw, zh := bits.zh
				w := Min(x + w, zx + zw), x := Max(x, zx), w -= x
				, h := Min(y + h, zy + zh), y := Max(y, zy), h -= y
				return bits
			}
			cri := A_IsCritical
			Critical
			if id := this.BindWindow(0, 0, 1)
				WinGetPos(&zx, &zy, &zw, &zh, id)
			else
				zx := SysGet(76), zy := SysGet(77), zw := SysGet(78), zh := SysGet(79)
			bits.zx := zx, bits.zy := zy, bits.zw := zw, bits.zh := zh
			, w := Min(x + w, zx + zw), x := Max(x, zx), w -= x
			, h := Min(y + h, zy + zh), y := Max(y, zy), h -= y
			if zw > bits.oldzw || zh > bits.oldzh || !bits.hBM {
				DllCall("DeleteObject", "Ptr", bits.hBM)
				, bits.hBM := this.CreateDIBSection(zw, zh, bpp := 32, &ppvBits)
				, bits.Scan0 := !bits.hBM ? 0 : ppvBits
				, bits.Stride := ((zw * bpp + 31) // 32) * 4
				, bits.oldzw := zw, bits.oldzh := zh
			}
			if !ScreenShot || w < 1 || h < 1 || !bits.hBM {
				Critical cri
				return bits
			}
			mDC := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
			oBM := DllCall("SelectObject", "Ptr", mDC, "Ptr", bits.hBM, "Ptr")
			if id {
				if 2 > mode := this.BindWindow(0, 0, 0, 1) {
					hDC2 := DllCall("GetDCEx", "Ptr", id, "Ptr", 0, "int", 3, "Ptr")
					DllCall("BitBlt", "Ptr", mDC, "int", x - zx, "int", y - zy, "int", w, "int", h, "Ptr", hDC2, "int", x - zx, "int", y - zy, "uint", 0xCC0020 | 0x40000000)
					DllCall("ReleaseDC", "Ptr", id, "Ptr", hDC2)
				} else {
					hBM2 := this.CreateDIBSection(zw, zh)
					mDC2 := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
					oBM2 := DllCall("SelectObject", "Ptr", mDC2, "Ptr", hBM2, "Ptr")
					DllCall("PrintWindow", "Ptr", id, "Ptr", mDC2, "uint", (mode > 3) * 3)
					DllCall("BitBlt", "Ptr", mDC, "int", x - zx, "int", y - zy, "int", w, "int", h, "Ptr", mDC2, "int", x - zx, "int", y - zy, "uint", 0xCC0020 | 0x40000000)
					DllCall("SelectObject", "Ptr", mDC2, "Ptr", oBM2)
					DllCall("DeleteDC", "Ptr", mDC2)
					DllCall("DeleteObject", "Ptr", hBM2)
				}
			} else {
				win := DllCall("GetDesktopWindow", "Ptr")
				, hDC := DllCall("GetWindowDC", "Ptr", win, "Ptr")
				, DllCall("BitBlt", "Ptr", mDC, "int", x - zx, "int", y - zy, "int", w, "int", h, "Ptr", hDC, "int", x, "int", y, "uint", 0xCC0020 | 0x40000000)
				, DllCall("ReleaseDC", "Ptr", win, "Ptr", hDC)
			}
			if this.CaptureCursor(0, 0, 0, 0, 0, 1)
				this.CaptureCursor(mDC, zx, zy, zw, zh)
			DllCall("SelectObject", "Ptr", mDC, "Ptr", oBM)
			, DllCall("DeleteDC", "Ptr", mDC)
			, Critical(cri)
			return bits
		}

	static CreateDIBSection(w, h, bpp := 32, &ppvBits := 0, &bi := "") {
			NumPut("int", 40, "int", w, "int", -h, "short", 1, "short", bpp, bi := Buffer(40, 0))
			return DllCall("CreateDIBSection", "Ptr", 0, "Ptr", bi, "int", 0, "Ptr*", &ppvBits := 0, "Ptr", 0, "int", 0, "Ptr")
		}

	static PicInfo(text) {
			static info := Map()
			if !InStr(text, "$")
				return
			key := (r := StrLen(text)) < 10000 ? text : DllCall("ntdll\RtlComputeCrc32", "uint", 0, "str", text, "uint", r * 2, "uint")
			if info.Has(key)
				return info[key]
			v := text, comment := "", seterr := e1 := e0 := 0
			if RegExMatch(v, "<([^>\n]*)>", &r)
				v := StrReplace(v, r[0]), comment := Trim(r[1])
			if RegExMatch(v, "\[([^\]\n]*)]", &r)
				v := StrReplace(v, r[0]), r := StrSplit(r[1], ","), seterr := 1, e1 := r[1], e0 := r[2]
			color := StrSplit(v, "$")[1], v := Trim(SubStr(v, InStr(v, "$") + 1))
			mode := InStr(color, "##") ? 5
				: InStr(color, "-") ? 4 : InStr(color, "#") ? 3
					: InStr(color, "**") ? 2 : InStr(color, "*") ? 1 : 0
			color := RegExReplace(color, "[*#\s]")
			if mode = 5 {
				if v ~= "[^\s\w/]" && FileExist(v) {
					if !(hBM := LoadPicture(v))
						return
					this.GetBitmapWH(hBM, &w, &h)
					if w < 1 || h < 1
						return
					hBM2 := this.CreateDIBSection(w, h, 32, &Scan0)
					this.CopyHBM(hBM2, 0, 0, hBM, 0, 0, w, h)
					DllCall("DeleteObject", "Ptr", hBM)
					if !Scan0
						return
					c1 := NumGet(Scan0 + 0, "uint") & 0xFFFFFF
					c2 := NumGet(Scan0 + (w - 1) * 4, "uint") & 0xFFFFFF
					c3 := NumGet(Scan0 + (w * h - w) * 4, "uint") & 0xFFFFFF
					c4 := NumGet(Scan0 + (w * h - 1) * 4, "uint") & 0xFFFFFF
					if c1 != c2 || c1 != c3 || c1 != c4
						c1 := 1
					v := Buffer(w * h * 18 * 2), i := -4, n := 0
					loop h {
						y := A_Index - 1
						loop w
							if (c := NumGet(Scan0 + (i += 4), "uint") & 0xFFFFFF) != c1
								v .= (A_Index - 1) | y << 16 | c << 32 . "/", n++
					}
					DllCall("DeleteObject", "Ptr", hBM2)
				} else {
					v := Trim(StrReplace(RegExReplace(v, "\s"), ",", "/"), "/")
					r := StrSplit(v, "/"), n := r.Length // 3
					if !n
						return
					; v := Buffer(n * 36)
					VarSetStrCapacity(&v, n * 36)
					x1 := x2 := r[1], y1 := y2 := r[2]
					loop n + (i := -2) * 0
						x := r[i += 3], y := r[i + 1]
					, (x < x1 && x1 := x), (x > x2 && x2 := x)
					, (y < y1 && y1 := y), (y > y2 && y2 := y)
					Loop n + (i := -2) * 0
						v .= (r[i += 3] - x1) | (r[i + 1] - y1) << 16 | (Floor("0x"
							. StrReplace(r[i + 2], "0x")) & 0xFFFFFF) << 32 . "/"
					w := x2 - x1 + 1, h := y2 - y1 + 1
				}
				len1 := n, len0 := 0
			} else {
				r := StrSplit(v, "."), w := r[1]
				, v := this.base64tobit(r[2]), h := StrLen(v) // w
				if (w < 1 || h < 1 || StrLen(v) != w * h)
					return
				if mode = 4
					r := StrSplit(StrReplace(color, "0x"), "-"), color := Round("0x" r[1]), n := r.Length > 1 ? Round("0x" r[2]) : 0
				else {
					r := StrSplit(color, "@"), color := r[1], n := r.Length > 1 ? Round(r[2], 2) + (!r[2]) : 1, n := Floor(512 * 9 * 255 * 255 * (1 - n) * (1 - n))
					if mode = 3
						color := (((color - 1) // w) << 16) | Mod(color - 1, w)
				}
				StrReplace(v, "1", , , &len1), len0 := StrLen(v) - len1
			}
			e1 := Floor(len1 * e1), e0 := Floor(len0 * e0)
			return info[key] := [v, w, h, len1, len0, e1, e0, mode, color, n, comment, seterr]
		}

	static GetBitmapWH(hBM, &w, &h) {
			bm := Buffer(A_PtrSize = 8 ? 32 : 24, 0)
			r := DllCall("GetObject", "Ptr", hBM, "int", bm.Size, "Ptr", bm)
			w := NumGet(bm, 4, "int"), h := Abs(NumGet(bm, 8, "int"))
			return r
		}

	static CopyHBM(hBM1, x1, y1, hBM2, x2, y2, w2, h2) {
			if w2 < 1 || h2 < 1 || !hBM1 || !hBM2
				return
			mDC1 := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
			oBM1 := DllCall("SelectObject", "Ptr", mDC1, "Ptr", hBM1, "Ptr")
			mDC2 := DllCall("CreateCompatibleDC", "Ptr", 0, "Ptr")
			oBM2 := DllCall("SelectObject", "Ptr", mDC2, "Ptr", hBM2, "Ptr")
			DllCall("BitBlt", "Ptr", mDC1, "int", x1, "int", y1, "int", w2, "int", h2, "Ptr", mDC2, "int", x2, "int", y2, "uint", 0xCC0020)
			DllCall("SelectObject", "Ptr", mDC2, "Ptr", oBM2)
			DllCall("DeleteDC", "Ptr", mDC2)
			DllCall("SelectObject", "Ptr", mDC1, "Ptr", oBM1)
			DllCall("DeleteDC", "Ptr", mDC1)
		}

	static BindWindow(bind_id := 0, bind_mode := 0, get_id := 0, get_mode := 0) {
			(!IsObject(this.bind) && this.bind := {}), bind := this.bind
			if get_id
				return bind.id
			if get_mode
				return bind.mode
			if bind_id {
				bind.id := bind_id, bind.mode := bind_mode, bind.oldStyle := 0
				if bind_mode & 1 {
					oldStyle := WinGetExStyle(bind_id)
					bind.oldStyle := oldStyle
					WinSetTransparent(255, bind_id)
					Loop 30 {
						Sleep(100)
						, i := WinGetTransparent(bind_id)
					} Until i = 255
				}
			} else {
				bind_id := bind.id
				if bind.mode & 1
					WinSetExStyle(bind.oldStyle, bind_id)
				bind.id := 0, bind.mode := 0, bind.oldStyle := 0
			}
		}

	static CaptureCursor(hDC := 0, zx := 0, zy := 0, zw := 0, zh := 0, get_cursor := 0) {
			if (get_cursor)
				return this.Cursor
			if (hDC = 1 || hDC = 0) && (zw = 0) {
				this.Cursor := hDC
				return
			}
			mi := Buffer(40, 0), NumPut("int", 16 + A_PtrSize, mi)
			DllCall("GetCursorInfo", "ptr", mi)
			bShow := NumGet(mi, 4, "int")
			hCursor := NumGet(mi, 8, "ptr")
			x := NumGet(mi, 8 + A_PtrSize, "int")
			y := NumGet(mi, 12 + A_PtrSize, "int")
			if (!bShow) || (x < zx || y < zy || x >= zx + zw || y >= zy + zh)
				return
			ni := Buffer(40, 0)
			DllCall("GetIconInfo", "ptr", hCursor, "ptr", ni)
			xCenter := NumGet(ni, 4, "int")
			yCenter := NumGet(ni, 8, "int")
			hBMMask := NumGet(ni, (A_PtrSize = 8 ? 16 : 12), "ptr")
			hBMColor := NumGet(ni, (A_PtrSize = 8 ? 24 : 16), "ptr")
			DllCall("DrawIconEx", "ptr", hDC, "int", x - xCenter - zx, "int", y - yCenter - zy, "ptr", hCursor, "int", 0, "int", 0, "int", 0, "int", 0, "int", 3)
			DllCall("DeleteObject", "ptr", hBMMask)
			DllCall("DeleteObject", "ptr", hBMColor)
		}

	static JoinText(ini, arr, info2, text, offsetX, offsetY, FindAll, index := "", Len := "", dir := "", minY := "", maxY := "", sx := "", sy := "", sw := "", sh := "") {
			allpos := Buffer(ini.allpos_max * 8)
			for i, j in info2[text[index]]
				loop this.PicFind(ini, j, dir, allpos, sx, sy, (index = 1 ? sw : Min(sx + offsetX + j[2], ini.sx + ini.sw) - sx), sh) {
					x := NumGet(allpos, 8 * A_Index - 8, "uint"), y := NumGet(allpos, 8 * A_Index - 4, "uint"), w := j[2], h := j[3]
					, (index = 1) && (ini.x := x, minY := y, maxY := y + h)
					if index < Len {
						if this.JoinText(ini, arr, info2, text, offsetX, offsetY, FindAll, index + 1, Len, 5, y1 := Min(y, minY), y2 := Max(y + h, maxY), x + w, y := Max(y1 - offsetY, ini.sy), 0, Min(y2 + offsetY, ini.sy + ini.sh) - y) && (index > 1 || !FindAll)
							return 1
					} else {
						comment := ""
						for k, v in text
							comment .= info2[v][1][11]
						w := x + w - ini.x, x := ini.x + ini.zx
						, h := Max(y + h, maxY) - Min(y, minY), y := Min(y, minY) + ini.zy
						, arr.Push({ 1: x, 2: y, 3: w, 4: h, x: x + w // 2, y: y + h // 2, id: comment })
						if index > 1 || !FindAll
							return 1
					}
				}
		}

	static base64tobit(s) {
			static Chars := "0123456789+/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
			Loop parse, Chars
				s := RegExReplace(s, "[" A_LoopField "]", ((i := A_Index - 1) >> 5 & 1) . (i >> 4 & 1) . (i >> 3 & 1) . (i >> 2 & 1) . (i >> 1 & 1) . (i & 1))
			return RegExReplace(RegExReplace(s, "[^01]+"), "10*$")
		}

	static bit2base64(s) {
			static Chars := "0123456789+/ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
			s := RegExReplace(s, "[^01]+")
			s .= SubStr("100000", 1, 6 - Mod(StrLen(s), 6))
			s := RegExReplace(s, ".{6}", "|$0")
			Loop parse Chars
				s := StrReplace(s, "|" . ((i := A_Index - 1) >> 5 & 1) . (i >> 4 & 1) . (i >> 3 & 1) . (i >> 2 & 1) . (i >> 1 & 1) . (i & 1), A_LoopField)
			return s
		}

	static PicFind(ini, j, dir, &allpos, sx, sy, sw, sh) {
		static MyFunc := ""
		if !MyFunc {
			hex := A_PtrSize = 4 ? ""
				. "5557565383EC6C8BAC248000000083FD050F84DB0800008B8424C4000000C744"
				. "24100000000085C00F8E6B0D000031FF31C089AC2480000000C744240C000000"
				. "0031C9C744241800000000897C241489C58B5C24148BBC24C00000008B742418"
				. "8B54241001DF89D829DE8B9C24C000000003B424BC00000085DB7E68897C2404"
				. "89EB89D7EB248D76008DBC27000000008BAC24B800000083C70483C00189548D"
				. "0083C10139442404742D83BC24800000000389FA0F45D0803C063175D38BAC24"
				. "B400000083C70483C00189549D0083C3013944240475D38BB424C00000000174"
				. "241889DD8344240C018BBC24A80000008B44240C017C24148B9C249400000001"
				. "5C2410398424C40000000F8541FFFFFF896C240C8BAC2480000000894C241031"
				. "C08B74240C39B424C80000008B7C24100F4DF039BC24CC0000008974240C0F4C"
				. "C739C6894424100F4DC683FD03894424040F84AF0800008B8424940000008BB4"
				. "24A00000000FAF8424A4000000C1E6028974243801F08BB42494000000894424"
				. "348B8424A8000000F7D885ED8D0486894424240F858B0300008B842484000000"
				. "C744242000000000C744242800000000C1E8100FB6E88B8424840000000FB6C4"
				. "894424140FB6842484000000894424188B8424A8000000C1E002894424308B84"
				. "24AC00000085C00F8EC70000008B7C24088B442434896C241C8BAC24A8000000"
				. "85ED0F8E8E0000008BB424900000008B6C242803AC24B000000001C603442430"
				. "8944242C0384249000000089442408900FB67E028B4C241C0FB6160FB646012B"
				. "5424182B44241489FB01CF29CB8D8F000400000FAFC00FAFCBC1E00B0FAFCBBB"
				. "FE05000029FB0FAFDA01C10FAFD301CA399424880000000F93450083C60483C5"
				. "013B74240875A98B9C24A8000000015C24288B44242C8344242001034424248B"
				. "74242039B424AC0000000F8549FFFFFF897C24088B8424A80000002B8424C000"
				. "0000C644244F00C644244E00C744245400000000C74424600000000089442458"
				. "8B8424AC0000002B8424C40000008944243C8B84248C00000083E80183F8070F"
				. "87D005000083F803894424440F8ECB0500008B4424608B742454894424548974"
				. "24608B742458397424540F8F760A00008B4424588B74240CC744243000000000"
				. "8944245C8B8424B40000008D04B08B7424448944245089F083E0018944244889"
				. "F08BB4249000000083E003894424648B4424608B7C243C39F80F8F7F01000083"
				. "7C2464018B5C24540F4F5C245C897C242C89442420895C24408DB42600000000"
				. "8B7C24488B44242C85FF0F44442420837C244403894424240F8FD2020000807C"
				. "244E008B442440894424288B4424280F85DA020000807C244F000F8580030000"
				. "0FAF8424A80000008B5424048B5C242485D28D2C180F8E840000008BBC24CC00"
				. "00008B9424B000000031C08B9C24C8000000896C24348B4C240C8974241C01EA"
				. "897C24188B6C24048B7C2410895C241439C17E1C8B9C24B40000008B348301D6"
				. "803E00750B836C2414010F886004000039C77E1C8B9C24B80000008B348301D6"
				. "803E00740B836C2418010F884004000083C00139E875B98B6C24348B74241C8B"
				. "44240C85C074278BBC24B00000008B8424B40000008B5C24508D0C2F8D742600"
				. "8B1083C00401CA39D8C6020075F28B442424038424A00000008B5C24308BBC24"
				. "D00000008904DF8B442428038424A40000008944DF0483C3013B9C24D4000000"
				. "895C24307D308344242001836C242C018B4424203944243C0F8DA2FEFFFF8344"
				. "245401836C245C018B442454394424580F8D59FEFFFF8B44243083C46C5B5E5F"
				. "5DC2580083FD010F849507000083FD020F84F90400008B8424840000000FB6BC"
				. "2484000000C744242C00000000C744243000000000C1E8100FB6D08B84248400"
				. "000089D50FB6DC8B842488000000C1E8100FB6C88B84248800000029CD01D189"
				. "6C243C89DD894C24140FB6F40FB684248800000029F501DE896C241889FD8974"
				. "241C29C501F8894424288B8424A8000000896C2420C1E002894424388B8424AC"
				. "00000085C00F8EE9FCFFFF8B4C24348B6C243C8B8424A800000085C00F8E8F00"
				. "00008B8424900000008B542430039424B000000001C8034C243889CF894C2434"
				. "03BC2490000000EB3B8DB42600000000395C24147C3D394C24187F37394C241C"
				. "7C3189F30FB6F3397424200F9EC3397424280F9DC183C00483C20121D9884AFF"
				. "39C7741E0FB658020FB648010FB63039DD7EBD31C983C00483C201884AFF39C7"
				. "75E28BB424A8000000017424308B4C24348344242C01034C24248B44242C3984"
				. "24AC0000000F8548FFFFFFE924FCFFFF8B442424807C244E00894424288B4424"
				. "40894424248B4424280F8426FDFFFF0FAF8424940000008B5C24048B4C242485"
				. "DB8D2C880F8EE4FDFFFF8BBC24C800000031C9896C241489F68DBC2700000000"
				. "8B8424B40000008B5C2414031C888B8424B80000008B2C880FB6441E0289EAC1"
				. "EA100FB6D229D00FB6541E010FB61C1E0FAFC03B4424087F2789E80FB6C429C2"
				. "0FAFD23B5424087F1789E80FB6C029C30FAFDB3B5C24087E108DB42600000000"
				. "83EF010F887701000083C1013B4C2404758E89AC2484000000E950FDFFFF6690"
				. "0FAF8424940000008B4C24248D048889442414038424840000000FB64C06010F"
				. "B67C06020FB60406894C24188B4C24048944241C85C90F8E12FDFFFF8B8424CC"
				. "00000031DB894424388B8424C8000000894424348B442408897C24088D742600"
				. "395C240C7E658B8424B40000008B4C24148B7C2408030C980FB6440E020FB654"
				. "0E010FB60C0E2B5424182B4C241C89C501F829FD8DB8000400000FAFD20FAFFD"
				. "C1E20B0FAFFDBDFE05000029C50FAFE901FA0FAFCD01D1398C2488000000730B"
				. "836C2434010F88A1000000395C24107E618B8424B80000008B4C24148B7C2408"
				. "030C980FB6440E020FB6540E010FB60C0E2B5424182B4C241C89C501F829FD8D"
				. "B8000400000FAFD20FAFFDC1E20B0FAFFDBDFE05000029C50FAFE901FA0FAFCD"
				. "01D1398C24880000007207836C243801783A83C3013B5C24040F8521FFFFFF89"
				. "442408E906FCFFFF908DB426000000008B74241CE92DFCFFFF8DB42600000000"
				. "89AC2484000000E91AFCFFFF89442408E911FCFFFFC7442444000000008B4424"
				. "3C8B742458894424588974243CE930FAFFFF8B84248800000031FF89AC248000"
				. "00008BB424BC00000031D289FD894424048B8424840000000FAFC08944240831"
				. "C0EB18B90A0000006BFA0AF7E189D9C1FB1F01FA01C811DA83C6010FBE0E85C9"
				. "744A8D59D083FB0976D983F92F75E989D389C10FB7C00FACD9108B9C24B40000"
				. "008D3CAD000000000FB7C90FAF8C24940000008D04818904AB8B9C24B8000000"
				. "83C50131C089143B31D2EBAC8BAC248000000083FD058B8424A80000000F9444"
				. "244E83FD030F9444244F038424A00000002B8424C0000000894424588B8424A4"
				. "000000038424AC0000002B8424C40000008944243C8B8424A4000000C78424A4"
				. "00000000000000894424548B8424A0000000C78424A000000000000000894424"
				. "60E9ECF8FFFF8B8424840000000FB7942484000000C1E8100FAF842494000000"
				. "8D049089842484000000E964FFFFFF8B8424A80000008BB424A40000000FAF84"
				. "24AC00000083EE01038424B0000000897424148944241C8B8424A80000000384"
				. "24A0000000894424208B8424A4000000038424AC00000039F00F8C0A0100008B"
				. "B424A000000083C0012BAC24A00000008944242C8B442420C744242800000000"
				. "83EE01897424308B74241401C50FAFB424940000008D7801896C243489742424"
				. "8B442430394424200F8C9D0000008B4C24148B5C24248B742428035C24382BB4"
				. "24A0000000039C2490000000C1E91F0374241C894C2418EB528DB42600000000"
				. "398424980000007E4B807C24180075448B4C2414398C249C0000007E370FB64B"
				. "FE0FB653FD83C3040FB66BF86BD24B6BC92601D189EAC1E20429EA01CAC1FA07"
				. "8854060183C00139F8741889C2C1EA1F84D274ACC64406010083C00183C30439"
				. "F875E88B7424340174242883442414018B9C24940000008B442414015C242439"
				. "44242C0F8537FFFFFF8B8424A80000008B8C24AC00000083C00285C989442420"
				. "0F8E0EF7FFFF8B8424AC0000008B6C241C036C2420C744241C01000000C74424"
				. "240000000083C001894424288B8424A8000000896C241883C0048944242C8B84"
				. "24880000008B9424A800000085D20F8EA70000008B4424188B5C24248B74242C"
				. "039C24B000000089C12B8C24A800000089C201C6894C2414908DB42600000000"
				. "0FB642010FB62ABF010000000384248400000039E8723D0FB66A0239E872358B"
				. "4C24140FB669FF39E872290FB66EFF39E872210FB669FE39E872190FB62939E8"
				. "72120FB66EFE39E8720A0FB63E39F80F92C189CF89F9834424140183C201880B"
				. "83C60183C3018B7C2414397C241875908BBC24A8000000017C24248344241C01"
				. "8B5C24208B74241C015C2418397424280F852FFFFFFF89842488000000E9F2F5"
				. "FFFF8B8424840000008BB424AC00000031EDC74424180000000083C001C1E007"
				. "898424840000008B8424A8000000C1E00285F68944241C0F8EB7F5FFFF896C24"
				. "148B4424348BAC24840000008B9C24A800000085DB7E638B8C24900000008B5C"
				. "2418039C24B000000001C10344241C894424200384249000000089C78D742600"
				. "0FB651020FB641010FB6316BC04B6BD22601C289F0C1E00429F001D039C50F97"
				. "0383C10483C30139F975D58BBC24A8000000017C24188B442420834424140103"
				. "4424248B74241439B424AC0000000F8578FFFFFFE91BF5FFFFC744240C000000"
				. "00E979F3FFFFC744243000000000E963F7FFFF90909090909090909090909090"
				: ""
				. "4157415641554154555756534881EC88000000488BBC24F0000000488BB42430"
				. "01000083F90589542468448944240844898C24E8000000488B9C243801000048"
				. "8BAC24400100000F84300900008B8424580100004531ED4531E485C00F8EDC00"
				. "000044897C240C448BBC245001000031D231C04889BC24F00000004889B42430"
				. "0100004531F64531ED4531E4C704240000000089D789C6660F1F840000000000"
				. "4585FF7E6548631424478D1C374489F048039424480100004189F8EB1F0F1F00"
				. "83C0014D63D54183C0044183C5014883C2014139C346894C9500742A83F90345"
				. "89C1440F45C8803A3175D583C0014D63D44183C0044183C4014883C2014139C3"
				. "46890C9375D644013C2483C6014403B4242001000003BC24F800000039B42458"
				. "0100000F8577FFFFFF448B7C240C488BBC24F0000000488BB4243001000031C0"
				. "4439A42460010000440F4DE04439AC2468010000440F4DE84539EC4589EE450F"
				. "4DF483F9030F848A0800008B8424F80000008B9424100100000FAF8424180100"
				. "008D04908B9424F8000000894424208B842420010000F7D885C98D0482890424"
				. "0F85C40300008B4C24684889C84189CB0FB6C441C1EB1089C20FB6C1450FB6DB"
				. "4189C28B84242801000085C00F8E370100008B842420010000448964242831C9"
				. "44896C24304889B42430010000448B6C2420448B6424088BB42420010000C1E0"
				. "0244897424184889BC24F00000004889AC24400100004189CEC744240C000000"
				. "008944241089D748899C24380100004489D585F60F8E8A000000488B9C24F000"
				. "00004963C54531D24C8D4C030248635C240C48039C2430010000660F1F440000"
				. "450FB639410FB651FE410FB641FF29EA4489F94501DF4189D0418D9700040000"
				. "4429D929F80FAFD10FAFC00FAFD1C1E00B8D0402BAFE0500004429FA410FAFD0"
				. "410FAFD001D04139C4420F9304134983C2014983C1044439D67FA544036C2410"
				. "0174240C4183C60144032C244439B424280100000F8558FFFFFF448B74241844"
				. "8B642428448B6C2430488BBC24F0000000488BB42430010000488B9C24380100"
				. "00488BAC24400100008B8424200100002B842450010000C644245700C644244C"
				. "00C744246C00000000C744247800000000894424708B8424280100002B842458"
				. "010000894424408B8424E800000083E80183F8070F870606000083F803894424"
				. "480F8E010600008B4424788B4C246C8944246C894C24788B4C2470394C246C0F"
				. "8F050B00008B4424708B4C244848899C24380100004889AC24400100004489ED"
				. "4589E5C74424300000000089442474418D4424FF4C8BA42440010000488D4483"
				. "044889F3488BB42438010000488944246089C883E0018944245089C883E00389"
				. "44247C4489F04589FE4189C78B4424788B4C244039C80F8F3E010000837C247C"
				. "018B54246C0F4F542474894C2428890424895424448B44245085C08B4424280F"
				. "440424837C2448038944240C0F8FCF020000807C244C008B442444894424100F"
				. "85D7020000807C2457000F85700300008B4C24100FAF8C2420010000034C240C"
				. "4585FF7E59448B942468010000448B8C246001000031C0660F1F840000000000"
				. "4139C589C27E184189C84403048642803C0300750A4183E9010F888500000039"
				. "D57E1289CA41031484803C130074064183EA01786F4883C0014139C77FC24585"
				. "ED741E4C8B4424604889F00F1F44000089CA03104883C0044C39C0C604130075"
				. "EF8B4C24308B54240C039424100100004C8B94247001000089C801C048984189"
				. "14828B54241003942418010000418954820489C883C0013B8424780100008944"
				. "24307D2E83042401836C2428018B0424394424400F8DDBFEFFFF8344246C0183"
				. "6C2474018B44246C394424700F8D9AFEFFFF8B4424304881C4880000005B5E5F"
				. "5D415C415D415E415FC383F9010F844108000083F9020F84070500008B542468"
				. "448B542408C744241000000000C74424180000000089D0440FB6C2C1E810440F"
				. "B6C84889D00FB6CC4489D04589CBC1E810894C240C0FB6D04C89D00FB6C44129"
				. "D34401CA89C18B44240C29C8034C240C89442430410FB6C24589C24129C24401"
				. "C0448B8424280100008944240C8B842420010000C1E0024585C0894424280F8E"
				. "05FDFFFF448974243C44896C244448899C2438010000448B742420448B6C2430"
				. "8B9C242001000044897C243844896424404189CF4889AC24400100004189D444"
				. "89D585DB7E784C635424184963C631D2488D4407024901F2EB37660F1F440000"
				. "4539C47C3E4139CD7F394139CF7C344439CD410F9EC044394C240C0F9DC14883"
				. "C0044421C141880C124883C20139D37E24440FB6000FB648FF440FB648FE4539"
				. "C37EBD31C94883C00441880C124883C20139D37FDC4403742428015C24188344"
				. "241001440334248B442410398424280100000F856AFFFFFF448B7C2438448B74"
				. "243C448B642440448B6C2444488B9C2438010000488BAC2440010000E908FCFF"
				. "FF8B44240C807C244C00894424108B4424448944240C0F8429FDFFFF8B442410"
				. "8B4C240C0FAF8424F80000004585FF448D14880F8EA8FDFFFF448B8C24600100"
				. "004531C04989DB660F1F840000000000428B1486438B1C844401D289D98D4202"
				. "C1E9100FB6C948980FB6040729C88D4A014863D20FAFC00FB614174863C90FB6"
				. "0C0F4439F07F1A0FB6C729C10FAFC94439F17F0D0FB6C329C20FAFD24439F27E"
				. "0A4183E9010F88950100004983C0014539C77F9C895C24684C89DBE921FDFFFF"
				. "8B4424108B4C240C0FAF8424F80000008D048889C1034424684585FF8D500248"
				. "63D2440FB614178D500148980FB604074863D20FB614170F8EE4FCFFFF448B9C"
				. "246801000048895C24584531C948897424184C8964242089CB89C64189D44489"
				. "5C243C448B9C246001000044895C24384539CD4589C87E6E488B442418428B14"
				. "8801DA8D42024898440FB634078D42014863D20FB6141748980FB604074589F3"
				. "4501D6418D8E000400004529D329F2410FAFCB4429E00FAFC0410FAFCB41BBFE"
				. "050000C1E00B4529F3440FAFDA01C8410FAFD301C239542408730B836C243801"
				. "0F88A60000004439C57E6A488B442420428B148801DA8D42024898440FB63407"
				. "8D42014863D20FB6141748980FB604074589F04501D6418D8E000400004529D0"
				. "29F2410FAFC84429E00FAFC0410FAFC841B8FE050000C1E00B4529F0440FAFC2"
				. "01C8410FAFD001C2395424087207836C243C0178374983C1014539CF0F8F0EFF"
				. "FFFF488B5C2458488B7424184C8B642420E9ABFBFFFF662E0F1F840000000000"
				. "895C24684C89DBE9D8FBFFFF488B5C2458488B7424184C8B642420E9C4FBFFFF"
				. "C7442448000000008B4424408B4C247089442470894C2440E9FAF9FFFF8B4424"
				. "68448B7424084531D24531DB4189C7440FAFF8488B842448010000EB0F4B8D14"
				. "924D63C04D8D14504883C0010FBE1085D2745D448D42D04183F80976E083FA2F"
				. "75E64C89D2450FB7CA4D63C348C1EA1049C1EA204183C3010FB7D20FAF9424F8"
				. "000000428D148A4289148346895485004531D2EBB38B54246889D00FB7D2C1E8"
				. "100FAF8424F80000008D04908944246883F9058B8424200100000F9444244C83"
				. "F9030F94442457038424100100002B842450010000894424708B842418010000"
				. "038424280100002B842458010000894424408B842418010000C7842418010000"
				. "000000008944246C8B842410010000C78424100100000000000089442478E9C4"
				. "F8FFFF8B8424200100008B9424180100000FAF842428010000448D5AFF489848"
				. "01F0488904248B842420010000038424100100008944240C8B84241801000003"
				. "8424280100004439D80F8C610100008B94241001000083C001448B9424F80000"
				. "00894424282B8C24100100004489642448448BA4240001000083EA01C7442418"
				. "0000000044897C24408D049500000000895424384489742444450FAFD344896C"
				. "244C48899C243801000089442420489848894424308B44240C448954241001C1"
				. "448D5001894C243C8B4424383944240C0F8CA40000008B4C24108B5424204589"
				. "DE488B5C24304C6344241841C1EE1F4C03042401CA4C63F94863D24C8D0C1748"
				. "29D3EB514139C47E554584F6755044399C24080100007E46410FB64902410FB6"
				. "510183C0014983C0016BD24B6BC92601D14A8D140B4983C104460FB62C3A4489"
				. "EAC1E2044429EA01D1C1F907418848FF4139C2741D89C2C1EA1F84D274A683C0"
				. "0141C600004983C1044983C0014139C275E38B5C243C015C24184183C3018B9C"
				. "24F8000000015C241044395C24280F8534FFFFFF448B7C2440448B742444448B"
				. "642448448B6C244C488B9C24380100008B842420010000448B94242801000083"
				. "C0024585D20F8EBEF6FFFF488B0C24489844897C24384889442410448B7C2468"
				. "48899C2438010000C7042401000000488D440101C744240C0000000044897424"
				. "3C4889C18B8424280100004889CB83C001894424184863842420010000488D50"
				. "0348F7D048894424288B84242001000048895424208B54240883E8014883C001"
				. "4889442430448B8C24200100004585C90F8EAD000000488B44242048634C240C"
				. "4C8D0C18488B4424284801F14C8D0418488B4424304C8D34184889D80F1F4000"
				. "0FB610440FB650FF41BB010000004401FA4439D2724A440FB650014439D27240"
				. "450FB650FF4439D27236450FB651FF4439D2722C450FB650FE4439D27222450F"
				. "B6104439D27219450FB651FE4439D2720F450FB6114439D2410F92C30F1F4000"
				. "4883C0014488194983C1014883C1014983C0014C39F075888B8C242001000001"
				. "4C240C8304240148035C24108B0424394424180F852CFFFFFF448B7C2438448B"
				. "74243C89542408488B9C2438010000E955F5FFFF8B8424200100008B54246845"
				. "31DBC744240C00000000C1E00283C201894424108B842428010000C1E2078954"
				. "246885C00F8E1FF5FFFF44897C241848899C2438010000448B7C2468448B9424"
				. "200100008B5C242044897424284585D27E504C6374240C4863C34531C0488D4C"
				. "07024901F60FB6110FB641FF440FB649FE6BC04B6BD22601C24489C8C1E00444"
				. "29C801D04139C7430F9704064983C0014883C1044539C27FCC035C2410440154"
				. "240C4183C301031C2444399C2428010000759A448B7C2418448B742428488B9C"
				. "2438010000E97FF4FFFFC744243000000000E9BBF6FFFF909090909090909090"
			DllCall("crypt32\CryptStringToBinary", "str", hex, "uint", 0, "uint", 4, "ptr", 0, "uint*", &bytes := 0, "ptr", 0, "ptr", 0)
			DllCall("crypt32\CryptStringToBinary", "str", hex, "uint", 0, "uint", 4, "ptr", MyFunc := Buffer(bytes), "uint*", &bytes, "ptr", 0, "ptr", 0)
			DllCall("VirtualProtect", "ptr", MyFunc, "uint", bytes, "uint", 0x40, "uint*", 0)
		}
		text := j[1], w := j[2], h := j[3]
		, e1 := j[12] ? j[6] : Floor(j[4] * ini.err1)
		, e0 := j[12] ? j[7] : Floor(j[5] * ini.err0)
		, mode := j[8], color := j[9], n := j[10]
		return !ini.bits.Scan0 ? 0 : DllCall(MyFunc
			, "int", mode, "uint", color, "uint", n, "int", dir, "Ptr", ini.bits.Scan0, "int", ini.bits.Stride
			, "int", ini.zw, "int", ini.zh, "int", sx, "int", sy, "int", sw, "int", sh
			, "Ptr", ini.ss, "Ptr", ini.s1, "Ptr", ini.s0, "AStr", text, "int", w, "int", h, "int", e1, "int", e0
			, "Ptr", allpos, "int", ini.allpos_max)
	}
}

FindTextGui(){

}