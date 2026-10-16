extends Control
## The PV's bottom "stdout · tokens" strip: Echo's current line, token by token, with the live token boxed.
const UI = preload("res://scripts/v8/ui.gd")
var tokens: PackedStringArray = []
var shown := 0
var speaker := ""
var accent := UI.BLUE
var time := 0.0
var reduced := false

func _ready() -> void:
 mouse_filter = MOUSE_FILTER_IGNORE

## Chinese splits into short runs (2 chars, punctuation stays attached); Latin splits by word.
static func tokenize(text: String) -> PackedStringArray:
 var out: PackedStringArray = []
 var buf := ""
 var latin := ""
 for ch in text.replace("\n", " "):
  var code = ch.unicode_at(0)
  if code < 0x2E80:
   if ch == " ":
    if not latin.is_empty(): out.append(latin); latin = ""
    if not buf.is_empty(): out.append(buf); buf = ""
    continue
   if not buf.is_empty(): out.append(buf); buf = ""
   latin += ch
   continue
  if not latin.is_empty(): out.append(latin); latin = ""
  if ch in "，。？！、；：…—」』）":
   buf += ch; out.append(buf); buf = ""; continue
  buf += ch
  if buf.length() >= 2: out.append(buf); buf = ""
 if not latin.is_empty(): out.append(latin)
 if not buf.is_empty(): out.append(buf)
 return out

func show_line(who: String, text: String, color: Color) -> void:
 speaker = who; accent = color
 tokens = tokenize(text)
 shown = 0
 queue_redraw()

## Called with how many characters of the chat line are visible, so subtitles stay in step with the typing.
func follow(chars: int) -> void:
 var count := 0
 var n := 0
 for t in tokens:
  count += t.length()
  if count <= chars: n += 1
 if chars < 0: n = tokens.size()
 if n != shown: shown = n; queue_redraw()

func _process(delta: float) -> void:
 time += delta
 if int(time * 2.0) != int((time - delta) * 2.0): queue_redraw()

func _draw() -> void:
 var w = size.x
 draw_line(Vector2(0, 0.5), Vector2(w, 0.5), Color(UI.LINE, 0.9), 1.0)
 draw_string(UI.mono(), Vector2(10, 14), "stdout · tokens", HORIZONTAL_ALIGNMENT_LEFT, -1, 9, UI.DIM)
 if not speaker.is_empty(): draw_string(UI.mono(), Vector2(w - 160, 14), speaker, HORIZONTAL_ALIGNMENT_RIGHT, 150, 9, UI.DIM)
 var font = UI.sans()
 var fs = 15
 var x = 14.0
 var y = 40.0
 draw_string(UI.mono(), Vector2(x, y), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.MUTED)
 x += 16
 var limit = w - 24
 # Keep the live token on screen: drop leading tokens once the line overflows.
 var start = 0
 var total = 0.0
 for i in range(mini(shown + 1, tokens.size())): total += font.get_string_size(tokens[i], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3
 var i0 = 0
 while total > limit - x and i0 < shown:
  total -= font.get_string_size(tokens[i0], HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 3; i0 += 1
 start = i0
 for i in range(start, tokens.size()):
  var t = tokens[i]
  var tw = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
  if x + tw > limit: break
  if i < shown - 1 or (i == shown - 1 and shown == tokens.size()):
   draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.PAPER)
  elif i == shown - 1:
   draw_rect(Rect2(x - 3, y - fs - 1, tw + 6, fs + 7), Color(accent, 0.9))
   draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UI.INK)
  else:
   draw_string(font, Vector2(x, y), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(UI.DIM, 0.35))
  x += tw + 3
 if shown >= tokens.size() and int(time * 2.0) % 2 == 0:
  draw_rect(Rect2(x - 2, y - fs + 1, 8, fs + 2), Color(accent, 0.85))
