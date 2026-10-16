extends RefCounted
## TUI kit for v0.8: crisp text, 1px line frames with corner ticks, flat bracket buttons.
## Same call shape as the v4 kit so every screen can switch over by changing one preload.
const INK = Color("05080f")
const BG = Color("070b14")
const PAPER = Color("d7e2f2")
const MUTED = Color("7d8ea8")
const DIM = Color("47566e")
const LINE = Color("24324a")
const PINK = Color("ff7d92")
const CYAN = Color("5fe0c8")
const GOLD = Color("ffc56e")
const BLUE = Color("74a9ff")
const PURPLE = Color("b39dff")
const MONO_SRC = preload("res://assets/JetBrainsMono-Regular.ttf")
const SANS_SRC = preload("res://assets/NotoSansCJKsc-Regular.otf")
static var ready := false

static func _prepare() -> void:
 if ready: return
 ready = true
 for f in [MONO_SRC, SANS_SRC]:
  f.antialiasing = TextServer.FONT_ANTIALIASING_GRAY
  f.hinting = TextServer.HINTING_LIGHT
  f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_AUTO
  f.generate_mipmaps = false
 var m: FontFile = MONO_SRC
 m.fallbacks = [SANS_SRC]

## Breaks the mono→sans fallback link so both fonts can be freed at exit.
static func release() -> void:
 var m: FontFile = MONO_SRC
 m.fallbacks = []
 m.clear_cache(); SANS_SRC.clear_cache()
 ready = false

## Monospace Latin with CJK fallback: the look of the stage and status lines.
static func mono() -> FontFile:
 _prepare()
 return MONO_SRC

## Clean sans for chat bubbles and long prose.
static func sans() -> FontFile:
 _prepare()
 return SANS_SRC

## Kept for older call sites; every screen now gets the crisp mono face.
static func pixel_font() -> FontFile:
 return mono()

static func style(bg: Color, edge: Color, thick: int = 1, radius: int = 2) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = bg
 s.border_color = edge
 s.set_border_width_all(thick)
 s.set_corner_radius_all(radius)
 s.content_margin_left = 6
 s.content_margin_right = 6
 s.content_margin_top = 3
 s.content_margin_bottom = 3
 s.anti_aliasing = radius > 0
 return s

## Panels are hairline frames; the edge colour only tints the corner ticks so busy screens stay quiet.
static func panel(parent: Node, r: Rect2, bg: Color, edge: Color) -> Panel:
 var n = Panel.new()
 n.position = r.position
 n.size = r.size
 var fill = bg
 if fill.a > 0.0: fill = Color(fill.r * 0.55, fill.g * 0.55, fill.b * 0.62, minf(fill.a, 0.92))
 n.add_theme_stylebox_override("panel", style(fill, Color(edge, 0.38), 1, 0))
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 n.size = r.size
 corners(n, Color(edge.lightened(0.15), 0.9))
 return n

## Four L-shaped ticks, as in the PV's frames.
static func corners(n: Control, color: Color, arm: float = 6.0) -> void:
 n.draw.connect(func():
  var w = n.size.x; var h = n.size.y
  for p in [[Vector2(0,0),Vector2(1,1)],[Vector2(w,0),Vector2(-1,1)],[Vector2(0,h),Vector2(1,-1)],[Vector2(w,h),Vector2(-1,-1)]]:
   var o: Vector2 = p[0] + Vector2(-0.5 if p[1].x < 0 else 0.5, -0.5 if p[1].y < 0 else 0.5)
   n.draw_line(o, o + Vector2(arm * p[1].x, 0), color, 1.0)
   n.draw_line(o, o + Vector2(0, arm * p[1].y), color, 1.0))

## A "/ label" title cut into a frame's top edge.
static func tab(parent: Node, caption: String, pos: Vector2, color: Color = MUTED) -> Label:
 var n = label(parent, "/ " + caption, Rect2(pos, Vector2(caption.length() * 9 + 30, 14)), color, 10)
 n.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0))
 var back = StyleBoxFlat.new(); back.bg_color = BG; back.content_margin_left = 4; back.content_margin_right = 4
 n.add_theme_stylebox_override("normal", back)
 n.clip_text = false
 n.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
 n.size = Vector2(0, 14)
 return n

static func label(parent: Node, text: String, r: Rect2, color: Color = PAPER, px: int = 12) -> Label:
 var n = Label.new()
 n.position = r.position
 n.size = r.size
 n.text = text
 n.add_theme_font_override("font", mono())
 n.add_theme_font_size_override("font_size", px)
 n.add_theme_color_override("font_color", color)
 n.clip_text = true
 n.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 n.size = r.size
 return n

static func text(parent: Node, content: String, r: Rect2, color: Color = PAPER) -> RichTextLabel:
 var n = RichTextLabel.new()
 n.position = r.position
 n.size = r.size
 n.text = content
 n.add_theme_font_override("normal_font", mono())
 n.add_theme_font_size_override("normal_font_size", 12)
 n.add_theme_color_override("default_color", color)
 n.add_theme_constant_override("line_separation", 4)
 n.scroll_active = false
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 return n

## Flat bracket buttons. Solid ones are the single "main move" on a screen.
static func button(parent: Node, caption: String, r: Rect2, callback: Callable, accent: Color = CYAN, solid: bool = false) -> Button:
 var b = Button.new()
 b.text = caption
 b.position = r.position
 b.size = r.size
 b.add_theme_font_override("font", mono())
 b.add_theme_font_size_override("font_size", 12)
 b.add_theme_color_override("font_color", INK if solid else accent)
 b.add_theme_color_override("font_hover_color", INK if solid else accent.lightened(0.35))
 b.add_theme_color_override("font_pressed_color", INK)
 b.add_theme_color_override("font_focus_color", INK if solid else accent)
 b.add_theme_color_override("font_disabled_color", DIM)
 b.add_theme_stylebox_override("normal", style(Color(accent, 0.92) if solid else Color(accent, 0.05), Color(accent, 0.95 if solid else 0.55)))
 b.add_theme_stylebox_override("hover", style(accent.lightened(0.12) if solid else Color(accent, 0.16), accent.lightened(0.2)))
 b.add_theme_stylebox_override("pressed", style(accent.darkened(0.08), accent.lightened(0.3)))
 b.add_theme_stylebox_override("disabled", style(Color(LINE, 0.18), Color(LINE, 0.9)))
 b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.pressed.connect(callback)
 parent.add_child(b)
 b.size = r.size
 juicy(b)
 return b

## Hover lift, press squash, elastic release: every button gets the same tactile response.
static func juicy(b: Button) -> void:
 b.pivot_offset = b.size / 2
 b.resized.connect(func(): b.pivot_offset = b.size / 2)
 b.mouse_entered.connect(func():
  if b.disabled: return
  b.create_tween().tween_property(b, "scale", Vector2(1.04, 1.04), 0.08)
  Sfx.play("hover", 1.15))
 b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.12))
 b.button_down.connect(func():
  b.scale = Vector2(0.92, 0.92)
  Sfx.play("press"))
 b.button_up.connect(func():
  var tw = b.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
  tw.tween_property(b, "scale", Vector2.ONE, 0.45))

static func clear(node: Node) -> void:
 for child in node.get_children():
  node.remove_child(child)
  child.queue_free()
