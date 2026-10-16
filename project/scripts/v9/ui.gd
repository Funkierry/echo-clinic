extends RefCounted
## MEDIC-OS 98 kit: one pixel font, crisp 1px bevels generated at runtime, night-shift palette.
## Same call shape as the v8 kit so older screens keep working inside windows.
const INK = Color("05080f")
const BG = Color("0b1018")
const PAPER = Color("dfe8f5")
const MUTED = Color("8a9bb5")
const DIM = Color("56647c")
const LINE = Color("2a3550")
const PINK = Color("ff7d92")
const CYAN = Color("5fe0c8")
const GOLD = Color("ffc56e")
const BLUE = Color("74a9ff")
const PURPLE = Color("b39dff")
## Window chrome.
const FACE = Color("222a3b")
const FACE_HI = Color("43506c")
const FACE_LO = Color("0d1119")
const EDGE = Color("05070c")
const TITLE_A = Color("1b2f6e")
const TITLE_B = Color("3c64b8")
const TITLE_OFF = Color("2a3142")
const DESK = Color("0e3940")
const FONT_SRC = preload("res://assets/v2/pixel-12.ttf")
static var ready := false
static var bevels: Dictionary = {}
static var checks: Dictionary = {}

## Win98 check boxes: a sunken white-on-dark square, ticked in cyan. Radio = round dot.
static func check_icon(on: bool, radio: bool = false) -> ImageTexture:
 var key = str(on) + str(radio)
 if checks.has(key): return checks[key]
 var img = Image.create(13, 13, false, Image.FORMAT_RGBA8)
 img.fill(Color(0, 0, 0, 0))
 img.fill_rect(Rect2i(0, 0, 13, 13), FACE_LO)
 img.fill_rect(Rect2i(1, 1, 12, 12), FACE_HI)
 img.fill_rect(Rect2i(1, 1, 11, 11), Color("0a0e16"))
 if on:
  if radio:
   img.fill_rect(Rect2i(4, 4, 5, 5), CYAN)
  else:
   for p in [Vector2i(3, 6), Vector2i(4, 7), Vector2i(5, 8), Vector2i(6, 7), Vector2i(7, 6), Vector2i(8, 5), Vector2i(9, 4)]:
    img.fill_rect(Rect2i(p.x, p.y, 1, 2), CYAN)
 checks[key] = ImageTexture.create_from_image(img)
 return checks[key]

static func style_check(c: CheckBox, radio: bool = false) -> void:
 c.add_theme_icon_override("unchecked", check_icon(false, radio))
 c.add_theme_icon_override("checked", check_icon(true, radio))
 c.add_theme_icon_override("radio_unchecked", check_icon(false, true))
 c.add_theme_icon_override("radio_checked", check_icon(true, true))
 c.add_theme_font_override("font", mono()); c.add_theme_font_size_override("font_size", 12)
 for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
  c.add_theme_color_override(k, PAPER)
 c.add_theme_constant_override("h_separation", 6)

static func _prepare() -> void:
 if ready: return
 ready = true
 var f: FontFile = FONT_SRC
 f.antialiasing = TextServer.FONT_ANTIALIASING_NONE
 f.hinting = TextServer.HINTING_NONE
 f.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
 f.generate_mipmaps = false

static func release() -> void:
 FONT_SRC.clear_cache()
 bevels = {}
 checks = {}
 ready = false

static func mono() -> FontFile:
 _prepare()
 return FONT_SRC

static func sans() -> FontFile:
 _prepare()
 return FONT_SRC

static func pixel_font() -> FontFile:
 return mono()

## CJK pixel glyphs are drawn at 12px; anything smaller would be unreadable.
static func px(size: int) -> int:
 return 24 if size >= 20 else 12

## A 1px Win98 bevel as a 9-slice texture: light top-left, dark bottom-right (or inverted when sunken).
static func bevel(face: Color, sunken: bool = false) -> StyleBoxTexture:
 var key = "%s/%s" % [face.to_html(), sunken]
 if bevels.has(key): return bevels[key]
 var img = Image.create(8, 8, false, Image.FORMAT_RGBA8)
 img.fill(face)
 var hi = face.lightened(0.28); var lo = face.darkened(0.55)
 var outer_hi = face.lightened(0.45); var outer_lo = EDGE
 if sunken:
  var t = hi; hi = lo; lo = t
  t = outer_hi; outer_hi = outer_lo; outer_lo = t
 for i in range(8):
  img.set_pixel(i, 0, outer_hi); img.set_pixel(0, i, outer_hi)
  img.set_pixel(i, 7, outer_lo); img.set_pixel(7, i, outer_lo)
 for i in range(1, 7):
  img.set_pixel(i, 1, hi); img.set_pixel(1, i, hi)
  img.set_pixel(i, 6, lo); img.set_pixel(6, i, lo)
 var sb = StyleBoxTexture.new()
 sb.texture = ImageTexture.create_from_image(img)
 sb.texture_margin_left = 2; sb.texture_margin_right = 2; sb.texture_margin_top = 2; sb.texture_margin_bottom = 2
 sb.content_margin_left = 6; sb.content_margin_right = 6; sb.content_margin_top = 3; sb.content_margin_bottom = 3
 sb.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
 sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
 bevels[key] = sb
 return sb

static func style(bg: Color, edge: Color, thick: int = 1, _radius: int = 0) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = bg
 s.border_color = edge
 s.set_border_width_all(thick)
 s.content_margin_left = 6
 s.content_margin_right = 6
 s.content_margin_top = 3
 s.content_margin_bottom = 3
 s.anti_aliasing = false
 return s

## Panels are flat fills with a hard 1px edge; transparent panels become sunken wells.
static func panel(parent: Node, r: Rect2, bg: Color, edge: Color) -> Panel:
 var n = Panel.new()
 n.position = r.position
 n.size = r.size
 if bg.a <= 0.05:
  n.add_theme_stylebox_override("panel", style(Color(0, 0, 0, 0), Color(edge, 0.45), 1))
 else:
  n.add_theme_stylebox_override("panel", style(Color(bg.r * 0.7, bg.g * 0.7, bg.b * 0.75, minf(bg.a, 0.95)), Color(edge, 0.55), 1))
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 n.size = r.size
 return n

static func corners(_n: Control, _color: Color, _arm: float = 6.0) -> void:
 pass

static func tab(parent: Node, caption: String, pos: Vector2, color: Color = MUTED) -> Label:
 var n = label(parent, caption, Rect2(pos, Vector2(caption.length() * 12 + 16, 14)), color, 12)
 n.clip_text = false
 n.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
 return n

static func label(parent: Node, text: String, r: Rect2, color: Color = PAPER, size: int = 12) -> Label:
 var n = Label.new()
 n.position = r.position
 n.size = r.size
 n.text = text
 n.add_theme_font_override("font", mono())
 n.add_theme_font_size_override("font_size", px(size))
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
 n.add_theme_constant_override("line_separation", 3)
 n.scroll_active = false
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 return n

## Raised Win98 buttons; `accent` tints the label, `solid` marks the default action with a deeper face.
static func button(parent: Node, caption: String, r: Rect2, callback: Callable, accent: Color = CYAN, solid: bool = false) -> Button:
 var b = Button.new()
 b.text = caption
 b.position = r.position
 b.size = r.size
 b.add_theme_font_override("font", mono())
 b.add_theme_font_size_override("font_size", 12)
 var face = FACE.lerp(accent, 0.32) if solid else FACE
 var text_color = PAPER if solid else accent.lerp(PAPER, 0.35)
 b.add_theme_color_override("font_color", text_color)
 b.add_theme_color_override("font_hover_color", PAPER)
 b.add_theme_color_override("font_pressed_color", PAPER)
 b.add_theme_color_override("font_focus_color", text_color)
 b.add_theme_color_override("font_disabled_color", DIM)
 b.add_theme_stylebox_override("normal", bevel(face))
 b.add_theme_stylebox_override("hover", bevel(face.lightened(0.12)))
 b.add_theme_stylebox_override("pressed", bevel(face.darkened(0.1), true))
 b.add_theme_stylebox_override("disabled", bevel(FACE.darkened(0.25)))
 b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.pressed.connect(callback)
 parent.add_child(b)
 b.size = r.size
 juicy(b)
 return b

## Hover lift, press squash, elastic release.
static func juicy(b: Button) -> void:
 b.pivot_offset = b.size / 2
 b.resized.connect(func(): b.pivot_offset = b.size / 2)
 b.mouse_entered.connect(func():
  if b.disabled: return
  Sfx.play("hover", 1.15))
 b.button_down.connect(func():
  b.scale = Vector2(0.95, 0.95)
  Sfx.play("press"))
 b.button_up.connect(func():
  var tw = b.create_tween().set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
  tw.tween_property(b, "scale", Vector2.ONE, 0.4))

static func clear(node: Node) -> void:
 for child in node.get_children():
  node.remove_child(child)
  child.queue_free()
