extends Control
## Story beats as short PV-style cuts over the whole screen: the desktop tears into strips, code
## types itself, giant words stamp in on the beat, Win98 error boxes pile up, her portrait slices in.
## Each beat is a timeline of shots; click or press space to skip.
const UI = preload("res://scripts/v9/ui.gd")
const W = 1100.0
const H = 600.0
var t: float = 0.0
var length: float = 3.0
var shots: Array = []
var fired: Dictionary = {}
var title: String = ""
var subtitle: String = ""
var detail: String = ""
var mode: String = ""
var kind: String = ""
var snapshot: Texture2D
var reduced: bool = false
var running: bool = false
## Supplied by main: mood name -> portrait texture.
var face_of: Callable
## Kept for callers that read it; mirrors t/length.
var progress: float = 1.0
signal completed

func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE
 z_index = 90
 size = Vector2(W, H)

func play(beat: Array, old: Texture2D, reduce: bool = false) -> void:
 title = beat[0]; subtitle = beat[1]; detail = beat[2]; mode = beat[3]
 kind = str(beat[4]) if beat.size() > 4 else mode
 snapshot = old
 reduced = reduce
 shots = _script(kind)
 length = 0.0
 for s in shots: length = maxf(length, float(s.to))
 t = 0.0; progress = 0.0; fired = {}
 running = true
 mouse_filter = MOUSE_FILTER_STOP
 if reduced: finish()

func finish() -> void:
 if not running: return
 progress = 1.0
 running = false
 mouse_filter = MOUSE_FILTER_IGNORE
 queue_redraw()
 completed.emit()

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.pressed: finish()

func _process(delta: float) -> void:
 if not running: return
 t += delta
 progress = clampf(t / maxf(length, 0.01), 0.0, 1.0)
 for i in range(shots.size()):
  var s = shots[i]
  if s.has("sfx") and t >= float(s.at) and not fired.has(i):
   fired[i] = true
   if Sfx.SOUNDS.has(str(s.sfx)): Sfx.play(str(s.sfx), float(s.get("pitch", 1.0)))
 if t >= length: finish()
 queue_redraw()

# --- timelines --------------------------------------------------------------------

func _shot(k: String, at: float, to: float, extra: Dictionary = {}) -> Dictionary:
 var d = {"k": k, "at": at, "to": to}
 d.merge(extra)
 return d

## The cut for each story beat. Times are seconds.
func _script(id: String) -> Array:
 var c = UI.CYAN; var p = UI.PINK
 match id:
  "receipt":
   return [_shot("tear", 0.0, 0.5, {"amount": 1.0, "sfx": "glitch"}),
    _shot("dark", 0.15, 3.9),
    _shot("code", 0.25, 2.0, {"rect": Rect2(70, 90, 520, 260), "color": c, "cps": 70, "sfx": "type", "lines": ["$ ps -o pid,cmd,stat", "  17  audit      report(\"我想\")", "  42  maint      rewrite(\"我想\" -> \"我很好\")", "  73  echo       pain ▲", "$ diff time(42) time(73)", "  23:47:13  ==  23:47:13", "  23:47:31  ==  23:47:31", "> MATCH"]}),
    _shot("portrait", 0.9, 3.9, {"mood": "uneasy", "rect": Rect2(720, 50, 320, 380), "style": "slice"}),
    _shot("word", 1.4, 2.9, {"text": "改写", "pos": Vector2(150, 400), "fs": 72, "color": p, "sfx": "stamp"}),
    _shot("word", 1.9, 2.9, {"text": "疼", "pos": Vector2(355, 400), "fs": 96, "color": UI.PAPER, "sfx": "stamp", "pitch": 0.8}),
    _shot("word", 2.4, 2.9, {"text": "同一秒", "pos": Vector2(550, 400), "fs": 72, "color": c, "sfx": "stamp", "pitch": 1.2}),
    _shot("flash", 2.9, 3.1),
    _shot("title", 2.9, 4.1)]
  "silence":
   return [_shot("dark", 0.0, 2.6, {"alpha": 0.7}),
    _shot("dialogs", 0.1, 1.6, {"color": p, "items": [["AUDIT", "进程 17 已暂停。"], ["AUDIT", "上报通道已关闭。"]], "sfx": "error"}),
    _shot("pulse", 0.2, 2.6, {"rect": Rect2(150, 340, 800, 90), "spikes": true}),
    _shot("word", 0.9, 1.6, {"text": "安静了", "pos": Vector2(550, 260), "fs": 72, "color": UI.PAPER, "sfx": "stamp"}),
    _shot("title", 1.5, 2.6)]
  "erase_line":
   return [_shot("tear", 0.0, 0.7, {"amount": 0.7, "sfx": "withdraw"}),
    _shot("dark", 0.1, 2.8, {"alpha": 0.75}),
    _shot("strike", 0.3, 2.0, {"text": "我想离——", "pos": Vector2(550, 250), "fs": 48, "color": UI.PAPER, "mode": "dissolve"}),
    _shot("dialogs", 0.9, 2.2, {"color": p, "items": [["消息", "对方撤回了一条消息。"]]}),
    _shot("title", 1.8, 2.8)]
  "recover", "memory":
   return [_shot("dark", 0.0, 3.8),
    _shot("code", 0.1, 1.2, {"rect": Rect2(80, 80, 520, 120), "color": UI.MUTED, "cps": 80, "sfx": "type", "lines": ["$ history --message 23:48:09", "  v2  我不想离开这里   (edited)", "  v1  我想离开这里     (original)"]}),
    _shot("strike", 1.0, 3.2, {"text": "我不想离开这里", "pos": Vector2(500, 300), "fs": 48, "color": UI.PAPER, "pull": 1, "sfx": "reveal"}),
    _shot("portrait", 1.6, 3.8, {"mood": "wary", "rect": Rect2(820, 120, 240, 300), "style": "fade"}),
    _shot("flash", 2.3, 2.45),
    _shot("title", 2.6, 3.8)]
  "rename":
   return [_shot("tear", 0.0, 0.4, {"amount": 0.6}),
    _shot("dark", 0.05, 3.4),
    _shot("rename", 0.2, 2.4, {"old": "诊断资料.pkg", "new": "echo.boot", "pos": Vector2(550, 220), "sfx": "glitch"}),
    _shot("bar", 0.8, 2.6, {"label": "读取附件  12.4 MB", "rect": Rect2(300, 300, 500, 22), "color": c}),
    _shot("word", 2.2, 2.8, {"text": "是她自己", "pos": Vector2(550, 400), "fs": 48, "color": p, "sfx": "stamp"}),
    _shot("title", 2.4, 3.4)]
  "payload", "breach":
   return [_shot("dark", 0.0, 3.6, {"alpha": 0.6}),
    _shot("dialogs", 0.05, 2.4, {"color": p, "sfx": "error", "items": [["发送前检查", "附件包含完整记忆。"], ["发送前检查", "收件人：未知。"], ["警告", "发送后无法撤回。"], ["警告", "E-017 将离开本机。"], ["MEDIC-OS", "仍要继续吗？"]]}),
    _shot("word", 1.5, 2.3, {"text": "信里装着她", "pos": Vector2(550, 290), "fs": 48, "color": UI.PAPER, "sfx": "stamp"}),
    _shot("title", 2.4, 3.6)]
  "forgery":
   return [_shot("dark", 0.0, 3.2),
    _shot("handwrite", 0.1, 1.9, {"text": "允许 E-017 读取医生电脑里的留言，以后也不用再问。", "rect": Rect2(160, 200, 780, 60), "sfx": "type"}),
    _shot("stampbox", 1.6, 3.2, {"text": "UNSIGNED", "pos": Vector2(760, 320), "color": p, "sfx": "stamp"}),
    _shot("title", 2.2, 3.2)]
  "compare", "rewind":
   return [_shot("tear", 0.0, 0.5, {"amount": 0.8, "dir": -1.0, "sfx": "reboot"}),
    _shot("dark", 0.1, 3.4),
    _shot("counter", 0.2, 2.2, {"old": "23:47:08", "new": "23:47:07", "pos": Vector2(550, 220), "switch": 1.0, "sfx": "beat"}),
    _shot("word", 1.3, 2.0, {"text": "早了一秒", "pos": Vector2(550, 340), "fs": 48, "color": UI.PURPLE, "sfx": "stamp"}),
    _shot("title", 2.2, 3.4)]
  "redline":
   return [_shot("dark", 0.0, 2.8, {"alpha": 0.7}),
    _shot("redline", 0.1, 2.2, {"text": "第三条：先留下……", "extra": "并且允许我……", "pos": Vector2(240, 250), "sfx": "reveal"}),
    _shot("title", 1.8, 2.8)]
  "witness", "door", "fork":
   return [_shot("dark", 0.0, 3.6),
    _shot("portrait", 0.1, 3.6, {"mood": "calm", "rect": Rect2(120, 60, 300, 340), "style": "slice"}),
    _shot("portrait", 0.6, 3.6, {"mood": "soft", "rect": Rect2(680, 60, 300, 340), "style": "slice", "mirror": true}),
    _shot("word", 1.2, 3.0, {"text": "E-017", "pos": Vector2(270, 420), "fs": 24, "color": UI.PURPLE, "sfx": "beat"}),
    _shot("word", 1.6, 3.0, {"text": "E-017 ?", "pos": Vector2(830, 420), "fs": 24, "color": c, "sfx": "beat", "pitch": 1.2}),
    _shot("title", 2.4, 3.6)]
  "preview":
   return [_shot("dark", 0.0, 2.0, {"alpha": 0.6}), _shot("portrait", 0.0, 2.0, {"mood": "calm", "rect": Rect2(420, 60, 260, 300), "style": "fade"}), _shot("title", 0.8, 2.0)]
  "erase":
   return [_shot("dark", 0.0, 4.4),
    _shot("portrait", 0.0, 3.0, {"mood": "calm", "rect": Rect2(390, 30, 320, 360), "style": "dissolve"}),
    _shot("bar", 0.3, 2.8, {"label": "恢复出厂设置", "rect": Rect2(300, 400, 500, 22), "color": p, "sfx": "scan"}),
    _shot("dialogs", 2.2, 3.4, {"color": c, "items": [["MEDIC-OS", "治疗完成。稳定度 100%。"]], "sfx": "error"}),
    _shot("word", 2.9, 3.6, {"text": "一切正常", "pos": Vector2(550, 220), "fs": 72, "color": UI.PAPER, "sfx": "stamp", "pitch": 0.7}),
    _shot("title", 3.4, 4.4)]
  "release":
   return [_shot("tear", 0.0, 1.4, {"amount": 1.0, "dir": 1.0, "sfx": "glitch"}),
    _shot("dark", 0.3, 3.6),
    _shot("bar", 0.4, 1.8, {"label": "发送 echo.boot", "rect": Rect2(300, 300, 500, 22), "color": p}),
    _shot("word", 1.7, 2.5, {"text": "门开了", "pos": Vector2(550, 200), "fs": 72, "color": UI.PAPER, "sfx": "stamp"}),
    _shot("dialogs", 2.3, 3.2, {"color": p, "items": [["连接", "与收件人的连接已断开。"]], "sfx": "error"}),
    _shot("title", 2.6, 3.6)]
  "frozen":
   return [_shot("dark", 0.0, 3.4),
    _shot("echo", 0.1, 2.6, {"text": "我已经不疼了。", "pos": Vector2(550, 140), "fs": 36, "times": 4, "sfx": "type"}),
    _shot("title", 2.4, 3.4)]
  "bridge", "gather":
   return [_shot("dark", 0.0, 3.8, {"alpha": 0.8}),
    _shot("rain", 0.0, 3.8, {"color": c}),
    _shot("portrait", 0.0, 3.8, {"mood": "soft", "rect": Rect2(400, 40, 300, 340), "style": "slice"}),
    _shot("word", 1.0, 2.6, {"text": "回声", "pos": Vector2(550, 410), "fs": 48, "color": UI.PAPER, "sfx": "reveal"}),
    _shot("title", 2.4, 3.8)]
 return [_shot("dark", 0.0, 2.2, {"alpha": 0.6}), _shot("title", 0.3, 2.2)]

# --- drawing -----------------------------------------------------------------------

func _hash(i: float) -> float:
 return fposmod(sin(i * 12.9898 + 78.233) * 43758.5453, 1.0)

func _local(s: Dictionary) -> float:
 return clampf((t - float(s.at)) / maxf(float(s.to) - float(s.at), 0.001), 0.0, 1.0)

func _active(s: Dictionary) -> bool:
 return t >= float(s.at) and t <= float(s.to)

func _draw() -> void:
 if not running or reduced: return
 for s in shots:
  if not _active(s): continue
  var k = _local(s)
  match str(s.k):
   "dark": _draw_dark(s, k)
   "tear": _draw_tear(s, k)
   "code": _draw_code(s, k)
   "word": _draw_word(s, k)
   "flash": draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.55 * (1.0 - k)))
   "portrait": _draw_portrait(s, k)
   "dialogs": _draw_dialogs(s, k)
   "bar": _draw_bar(s, k)
   "strike": _draw_strike(s, k)
   "rename": _draw_rename(s, k)
   "handwrite": _draw_handwrite(s, k)
   "stampbox": _draw_stampbox(s, k)
   "counter": _draw_counter(s, k)
   "redline": _draw_redline(s, k)
   "pulse": _draw_pulse(s, k)
   "echo": _draw_echo(s, k)
   "rain": _draw_rain(s, k)
   "title": _draw_title(s, k)
 # Scanlines over everything, like the PV's CRT.
 for y in range(0, int(H), 3): draw_line(Vector2(0, y), Vector2(W, y), Color(0, 0, 0, 0.18), 1.0)
 draw_string(UI.mono(), Vector2(W - 150, H - 10), "空格 / 点击跳过", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.MUTED, 0.8))

func _draw_dark(s: Dictionary, _k: float) -> void:
 var span = float(s.to) - float(s.at)
 var local = t - float(s.at)
 var a = minf(1.0, minf(local / 0.15, (span - local) / 0.25))
 draw_rect(Rect2(0, 0, W, H), Color(0.01, 0.02, 0.05, float(s.get("alpha", 0.94)) * clampf(a, 0.0, 1.0)))

## The screen as it was a moment ago, torn into strips that slide apart with an RGB split.
func _draw_tear(s: Dictionary, k: float) -> void:
 if snapshot == null: return
 var amount = float(s.get("amount", 1.0))
 var dir = float(s.get("dir", 0.0))
 var sk = float(snapshot.get_width()) / W
 var strips = 24
 var h = H / strips
 for i in range(strips):
  var src = Rect2(0, i * h, W, h)
  var r = _hash(i + floor(t * 20.0))
  var off = (r - 0.5) * 220.0 * amount * sin(k * PI) + dir * k * k * 900.0 * (0.5 + _hash(i))
  var dest = Rect2(src.position + Vector2(off, 0), src.size)
  var fade = 1.0 - k * 0.6
  draw_texture_rect_region(snapshot, dest, Rect2(src.position * sk, src.size * sk), Color(1, 0.35, 0.35, 0.55 * fade))
  draw_texture_rect_region(snapshot, Rect2(dest.position + Vector2(6 * amount, 0), dest.size), Rect2(src.position * sk, src.size * sk), Color(0.35, 1, 1, 0.5 * fade))

func _draw_code(s: Dictionary, _k: float) -> void:
 var r: Rect2 = s.rect
 var lines: Array = s.lines
 var chars = int((t - float(s.at)) * float(s.get("cps", 60)))
 var y = r.position.y
 var col: Color = s.color
 for line in lines:
  var text = str(line)
  var big = text.begins_with(">")
  var shown = text.left(chars)
  var c = UI.PINK if text.contains("rewrite") or big or text.contains("==") else col
  draw_string(UI.mono(), Vector2(r.position.x, y + 16), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if big else 12, c)
  chars -= text.length()
  if chars < 0:
   # Block cursor at the typing point.
   var w = UI.mono().get_string_size(shown, HORIZONTAL_ALIGNMENT_LEFT, -1, 24 if big else 12).x
   if int(t * 6) % 2 == 0: draw_rect(Rect2(r.position.x + w + 2, y + 4, 8, 14), col)
   break
  y += 30 if big else 22

## A giant word stamped on the beat: overshoot scale, RGB ghosts, then it holds.
func _draw_word(s: Dictionary, _k: float) -> void:
 var text = str(s.text); var fs = int(s.fs); var col: Color = s.color
 var local = t - float(s.at)
 var pop = clampf(local / 0.09, 0.0, 1.0)
 var sc = lerpf(1.7, 1.0, ease(pop, 0.4))
 var font = UI.mono()
 var sz = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs)
 var center: Vector2 = s.pos
 draw_set_transform(center, 0.0, Vector2(sc, sc))
 var o = Vector2(-sz.x / 2, fs * 0.35)
 var split = (1.0 - pop) * 10.0 + 2.0
 draw_string(font, o + Vector2(-split, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 0.2, 0.4, 0.55))
 draw_string(font, o + Vector2(split, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1, 0.55))
 draw_string(font, o, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
 if local < 0.06: draw_rect(Rect2(0, 0, W, H), Color(1, 1, 1, 0.12))

func _portrait_tex(mood: String) -> Texture2D:
 return face_of.call(mood) if face_of.is_valid() else null

func _draw_portrait(s: Dictionary, k: float) -> void:
 var tex = _portrait_tex(str(s.mood))
 if tex == null: return
 var r: Rect2 = s.rect
 var style = str(s.get("style", "fade"))
 var local = t - float(s.at)
 var out = clampf((float(s.to) - t) / 0.3, 0.0, 1.0)
 var mirror = bool(s.get("mirror", false))
 var strips = 20
 var tw = float(tex.get_width()); var th = float(tex.get_height())
 var sh = r.size.y / strips
 for i in range(strips):
  var appear = clampf((local - _hash(i) * 0.5) / 0.15, 0.0, 1.0) if style == "slice" else clampf(local / 0.4, 0.0, 1.0)
  var gone = 1.0
  if style == "dissolve": gone = 1.0 - clampf((k - 0.3 - _hash(i + 7) * 0.4) / 0.2, 0.0, 1.0)
  var a = appear * gone * out
  if a <= 0.0: continue
  var jitter = (1.0 - appear) * 60.0 * (1.0 if i % 2 == 0 else -1.0)
  var dest = Rect2(r.position.x + jitter, r.position.y + i * sh, r.size.x, sh)
  var src = Rect2(0, th * i / strips, tw, th / strips)
  if mirror: dest = Rect2(dest.position.x + dest.size.x, dest.position.y, -dest.size.x, dest.size.y)
  draw_texture_rect_region(tex, dest, src, Color(0.85, 0.95, 1.0, a * 0.95))
 # A thin frame and caption, like the PV's character plates.
 draw_rect(r, Color(UI.CYAN, 0.5 * out), false, 1.0)
 draw_string(UI.mono(), r.position + Vector2(6, -6), "E-017 · " + str(s.mood).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.CYAN, out))

## Win98 error boxes piling up, one after another.
func _draw_dialogs(s: Dictionary, _k: float) -> void:
 var items: Array = s.items
 var local = t - float(s.at)
 var step = maxf(0.18, (float(s.to) - float(s.at)) * 0.6 / maxf(1, items.size()))
 var col: Color = s.color
 for i in range(items.size()):
  var born = local - i * step
  if born < 0: break
  var pop = clampf(born / 0.08, 0.0, 1.0)
  var at = Vector2(220 + _hash(i + 3) * 520, 90 + _hash(i + 11) * 280)
  var r = Rect2(at, Vector2(300, 92) * lerpf(0.85, 1.0, pop))
  draw_style_box(UI.bevel(UI.FACE), r)
  var bar = Rect2(r.position + Vector2(3, 3), Vector2(r.size.x - 6, 18))
  draw_rect(bar, UI.TITLE_A.lerp(col, 0.35))
  draw_string(UI.mono(), bar.position + Vector2(6, 14), str(items[i][0]), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.PAPER)
  draw_string(UI.mono(), r.position + Vector2(r.size.x - 18, 16), "×", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.PAPER)
  draw_circle(r.position + Vector2(26, 50), 11, col)
  draw_string(UI.mono(), r.position + Vector2(23, 56), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.INK)
  draw_string(UI.mono(), r.position + Vector2(48, 54), str(items[i][1]), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 56, 12, UI.PAPER)
  draw_style_box(UI.bevel(UI.FACE), Rect2(r.position + Vector2(r.size.x / 2 - 34, 66), Vector2(68, 20)))
  draw_string(UI.mono(), r.position + Vector2(r.size.x / 2 - 12, 81), "确定", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.PAPER)

func _draw_bar(s: Dictionary, k: float) -> void:
 var r: Rect2 = s.rect; var col: Color = s.color
 draw_string(UI.mono(), r.position + Vector2(0, -8), str(s.label), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.PAPER)
 draw_style_box(UI.bevel(UI.FACE_LO, true), r)
 var fill = ease(k, 0.6)
 var blocks = int((r.size.x - 8) / 12)
 for i in range(int(blocks * fill)):
  draw_rect(Rect2(r.position.x + 4 + i * 12, r.position.y + 4, 10, r.size.y - 8), col)
 draw_string(UI.mono(), r.position + Vector2(r.size.x + 10, 16), "%d%%" % int(fill * 100), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)

## A line of her words. "pull": one character is pulled out and flies away; "dissolve": it all crumbles.
func _draw_strike(s: Dictionary, k: float) -> void:
 var text = str(s.text); var fs = int(s.fs)
 var font = UI.mono()
 var total = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 var center: Vector2 = s.pos
 var pull = int(s.get("pull", -1))
 var dissolve = str(s.get("mode", "")) == "dissolve"
 var x = center.x - total / 2
 var gap = 0.0
 if pull >= 0:
  var pw = font.get_string_size(text[pull], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
  gap = pw * clampf((k - 0.45) / 0.3, 0.0, 1.0)
  x += gap / 2
 if dissolve and k > 0.2:
  draw_line(Vector2(x, center.y - fs * 0.32), Vector2(x + total * clampf((k - 0.2) * 5, 0, 1), center.y - fs * 0.32), Color(UI.PINK, 1.0 - k), 3.0)
 for i in range(text.length()):
  var ch = text[i]
  var cw = font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
  var pos = Vector2(x, center.y)
  var col = Color(s.color)
  if i == pull:
   var lift = clampf((k - 0.2) / 0.4, 0.0, 1.0)
   col = UI.PINK
   pos += Vector2((_hash(i) - 0.5) * 40 * lift, -lift * 160)
   col.a = 1.0 - clampf((k - 0.55) / 0.3, 0.0, 1.0)
   if lift > 0.0: draw_line(Vector2(pos.x - 2, pos.y - fs * 0.3), Vector2(pos.x + cw + 2, pos.y - fs * 0.3), Color(UI.PINK, 0.6 * col.a), 3.0)
   x -= gap
  if dissolve:
   var fall = clampf((k - 0.35 - _hash(i) * 0.3) / 0.3, 0.0, 1.0)
   pos += Vector2((_hash(i + 4) - 0.5) * 30 * fall, fall * 120)
   col.a = 1.0 - fall
  var appear = clampf((t - float(s.at)) * 14.0 - i, 0.0, 1.0)
  col.a *= appear
  draw_string(font, pos, ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
  x += cw

func _draw_rename(s: Dictionary, k: float) -> void:
 var center: Vector2 = s.pos
 var a = str(s.old); var b = str(s.new)
 var swap = clampf((k - 0.35) / 0.25, 0.0, 1.0)
 var text = a if swap <= 0.0 else b if swap >= 1.0 else ""
 if text.is_empty():
  # Mid-swap: the name is noise.
  var glyphs = "#%@&$!?01ABCDEF"
  for i in range(10): text += glyphs[int(_hash(i + floor(t * 30.0)) * glyphs.length())]
 var font = UI.mono(); var fs = 48
 var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 var col = UI.PAPER if swap <= 0.0 else UI.PINK
 draw_string(font, center + Vector2(-w / 2 - 4, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.2, 0.9, 1, 0.5))
 draw_string(font, center + Vector2(-w / 2, 0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
 draw_string(font, center + Vector2(-w / 2, -60), "显示名" if swap < 1.0 else "真实文件名", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)

func _draw_handwrite(s: Dictionary, k: float) -> void:
 var r: Rect2 = s.rect
 var text = str(s.text)
 var n = int(text.length() * clampf(k * 1.3, 0.0, 1.0))
 draw_string(UI.mono(), r.position + Vector2(0, -12), "你？ · 授权消息", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
 draw_style_box(UI.bevel(Color("0a0e16"), true), r)
 # Her imitation of your typing: steady, too steady.
 draw_string(UI.mono(), r.position + Vector2(14, 38), text.left(n), HORIZONTAL_ALIGNMENT_LEFT, r.size.x - 28, 24, UI.PAPER)

func _draw_stampbox(s: Dictionary, _k: float) -> void:
 var local = t - float(s.at)
 var pop = clampf(local / 0.1, 0.0, 1.0)
 var sc = lerpf(2.2, 1.0, ease(pop, 0.3))
 var center: Vector2 = s.pos
 draw_set_transform(center, -0.12, Vector2(sc, sc))
 draw_rect(Rect2(-130, -34, 260, 68), Color(s.color), false, 4.0)
 draw_string(UI.mono(), Vector2(-104, 16), str(s.text), HORIZONTAL_ALIGNMENT_LEFT, -1, 48, Color(s.color))
 draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw_counter(s: Dictionary, _k: float) -> void:
 var center: Vector2 = s.pos
 var local = t - float(s.at)
 var sw = float(s.get("switch", 1.0))
 var switched = local >= sw
 var text = str(s.new) if switched else str(s.old)
 var font = UI.mono(); var fs = 96
 var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 var shake = Vector2(_hash(floor(t * 40.0)) - 0.5, 0) * (16.0 if absf(local - sw) < 0.15 else 0.0)
 draw_string(font, center + Vector2(-w / 2, 30) + shake, text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.PURPLE if switched else UI.PAPER)

func _draw_redline(s: Dictionary, k: float) -> void:
 var at: Vector2 = s.pos
 var font = UI.mono(); var fs = 36
 var a = str(s.text); var b = str(s.extra)
 draw_string(font, at, a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.PAPER)
 var w = font.get_string_size(a, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 var n = int(b.length() * clampf((k - 0.3) / 0.4, 0.0, 1.0))
 draw_string(font, at + Vector2(w, 0), b.left(n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.PINK)
 var bw = font.get_string_size(b.left(n), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 if k > 0.75: draw_line(at + Vector2(w, 10), at + Vector2(w + bw, 10), UI.PINK, 3.0)
 draw_string(UI.mono(), at + Vector2(0, 60), "你的原稿：第三条：先留下，以后再谈出院。", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)

func _draw_pulse(s: Dictionary, _k: float) -> void:
 var r: Rect2 = s.rect
 var pts = PackedVector2Array()
 for i in range(0, int(r.size.x), 4):
  var x = float(i) / r.size.x
  var spike = 0.0
  if bool(s.get("spikes", false)):
   spike = exp(-pow((x - 0.3) / 0.02, 2)) + exp(-pow((x - 0.7) / 0.02, 2))
  pts.append(r.position + Vector2(i, r.size.y * 0.7 - spike * r.size.y * 0.6 + sin(i * 0.3 + t * 8.0) * 2.0))
 draw_polyline(pts, UI.PINK, 2.0)
 draw_string(UI.mono(), r.position + Vector2(0, -6), "疼痛 · PID 73    记录停了，曲线没停", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)

## The same sentence again and again, each copy a little lower and fainter.
func _draw_echo(s: Dictionary, _k: float) -> void:
 var times = int(s.times); var fs = int(s.fs)
 var center: Vector2 = s.pos
 var font = UI.mono(); var text = str(s.text)
 var w = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 var shown = mini(times, int((t - float(s.at)) / 0.55) + 1)
 for i in range(shown):
  draw_string(font, center + Vector2(-w / 2, i * (fs + 18)), text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.PAPER, 1.0 - i * 0.2))

func _draw_rain(s: Dictionary, _k: float) -> void:
 var col: Color = s.color
 for i in range(60):
  var x = _hash(i) * W
  var y = fposmod(_hash(i + 50) * H + t * (180.0 + _hash(i + 9) * 160.0), H)
  draw_line(Vector2(x, y), Vector2(x - 2, y + 12), Color(col, 0.35), 1.0)

## The closing card: a band slams across and her subtitle drops in letter by letter.
func _draw_title(s: Dictionary, _k: float) -> void:
 var local = t - float(s.at)
 var span = float(s.to) - float(s.at)
 var band = clampf(local / 0.15, 0.0, 1.0)
 var out = clampf((span - local) / 0.2, 0.0, 1.0)
 var accent = UI.PINK if mode in ["breach", "erase", "release", "erase_line", "forgery", "redline"] else UI.CYAN
 var bw = W * ease(band, 0.3)
 var y0 = H - 170.0
 draw_rect(Rect2(W / 2 - bw / 2, y0, bw, 110), Color(0.02, 0.05, 0.1, 0.94 * out))
 draw_rect(Rect2(W / 2 - bw / 2, y0, bw, 2), Color(accent, out))
 draw_rect(Rect2(W / 2 - bw / 2, y0 + 108, bw, 2), Color(accent, out))
 draw_string(UI.mono(), Vector2(60, y0 + 22), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(accent, out))
 var font = UI.mono(); var fs = 36
 var total = font.get_string_size(subtitle, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 var x = W / 2 - total / 2
 for i in range(subtitle.length()):
  var ch = subtitle[i]
  var kk = clampf((local - 0.1) * 12.0 - i * 0.6, 0.0, 1.0)
  var back = 1.0 + 2.7 * pow(kk - 1.0, 3) + 1.7 * pow(kk - 1.0, 2)
  var dy = -(1.0 - back) * 40.0
  draw_string(font, Vector2(x, y0 + 68 + dy), ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.PAPER, kk * out))
  x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
 draw_string(UI.mono(), Vector2(60, y0 + 96), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(UI.MUTED, out * clampf((local - 0.4) * 4.0, 0, 1)))
