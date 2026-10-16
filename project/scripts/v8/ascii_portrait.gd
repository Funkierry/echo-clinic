extends Control
## Echo drawn as coloured characters, the way the PV turns its dancer into text.
## Sampled once per mood from the hi-res art; animated per frame (assemble, breathe, flicker, glitch).
const UI = preload("res://scripts/v8/ui.gd")
const PATIENT = preload("res://assets/v2/echo-patient.png")
const SHEET = preload("res://assets/v2/echo-expressions.png")
const RAMP = " .:-=+*#%@"
const DATA = "0123456789ABCDEF<>/\\{}[]=+*#"
## calm / uneasy / wary / soft: the four cells of the expression sheet, plus the full portrait.
const MOODS = {"calm": Rect2i(0, 0, 600, 656), "uneasy": Rect2i(600, 0, 599, 656), "wary": Rect2i(0, 656, 600, 656), "soft": Rect2i(600, 656, 599, 656)}
static var cache: Dictionary = {}

var cell := Vector2(3, 4)
var cols := 44
var rows := 40
var mood := "calm"
var tint := Color.WHITE
var glitch := 0.0
var assemble := 1.0
var reduced := false
var time := 0.0
var frame_clock := 0.0
var seed_shift := 0

func setup(rect: Rect2, start_mood: String = "calm", fly_in: bool = true) -> void:
 position = rect.position; size = rect.size
 mouse_filter = MOUSE_FILTER_IGNORE
 cols = int(rect.size.x / cell.x); rows = int(rect.size.y / cell.y)
 mood = start_mood
 assemble = 0.0 if fly_in and not reduced else 1.0
 if fly_in and not reduced: create_tween().tween_property(self, "assemble", 1.0, 1.1).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 queue_redraw()

func set_mood(next: String, flash: bool = true) -> void:
 if next == mood or not MOODS.has(next) and next != "portrait": return
 mood = next
 if flash and not reduced: pulse(0.55)
 queue_redraw()

func pulse(amount: float) -> void:
 glitch = maxf(glitch, amount)

func _process(delta: float) -> void:
 if reduced: return
 time += delta; frame_clock += delta
 glitch = maxf(0.0, glitch - delta * 1.6)
 # Characters re-roll at ~16 fps; that rate reads as "live text" without strobing.
 if frame_clock >= 0.06:
  frame_clock = 0.0; seed_shift += 1
  queue_redraw()

func _grid() -> Array:
 var key = "%s/%d/%d" % [mood, cols, rows]
 if cache.has(key): return cache[key]
 var src: Image = (PATIENT if mood == "portrait" else SHEET).get_image()
 if src.is_compressed(): src.decompress()
 var region = Rect2i(0, 0, src.get_width(), src.get_height()) if mood == "portrait" else MOODS[mood]
 var img = src.get_region(region)
 img.resize(cols, rows, Image.INTERPOLATE_LANCZOS)
 var grid: Array = []
 for y in range(rows):
  var row: Array = []
  for x in range(cols):
   var c = img.get_pixel(x, y)
   row.append(c)
  grid.append(row)
 cache[key] = grid
 return grid

func _draw() -> void:
 var grid = _grid()
 var font = UI.mono()
 var fs = int(cell.y + 2)
 var center = size / 2
 for y in range(rows):
  var sway = 0.0 if reduced else sin(time * 1.4 + y * 0.09) * 0.6
  var slice = 0.0
  if glitch > 0.05 and (y * 7 + seed_shift) % 9 == 0: slice = (float((y * 13 + seed_shift * 5) % 21) - 10.0) * glitch * 2.2
  for x in range(cols):
   var c: Color = grid[y][x]
   if c.a < 0.35: continue
   var lum = c.get_luminance()
   var h = (x * 73856093 ^ y * 19349663 ^ (seed_shift if (x + y + seed_shift) % 23 == 0 else 0)) & 0x7fffffff
   var ch = RAMP[clampi(int(lum * (RAMP.length() - 1) + 0.5), 1, RAMP.length() - 1)]
   # Mid-tones carry hex/data glyphs so the face reads as "made of code" up close.
   if lum > 0.28 and lum < 0.8 and h % 5 == 0: ch = DATA[h % DATA.length()]
   # Lift the dark jacket tones toward paper so the silhouette reads on a near-black stage.
   var col = Color(c.r, c.g, c.b, 1.0).lerp(UI.PAPER, 0.18 + lum * 0.25) * tint
   col = Color(minf(col.r * 1.25, 1.0), minf(col.g * 1.25, 1.0), minf(col.b * 1.3, 1.0), col.a)
   if glitch > 0.05 and h % 11 == 0:
    ch = ["#", "/", "\\", "_", "%"][h % 5]; col = UI.PINK
   var at = Vector2(x * cell.x + sway + slice, y * cell.y)
   if assemble < 1.0:
    var k = clampf(assemble * 1.4 - float(h % 40) / 100.0, 0.0, 1.0)
    var from = center + Vector2(float(h % 700) - 350.0, float((h / 700) % 500) - 250.0)
    at = from.lerp(at, k * k * (3.0 - 2.0 * k))
    col.a *= k
   draw_char(font, at + Vector2(0, cell.y), ch, fs, col)
