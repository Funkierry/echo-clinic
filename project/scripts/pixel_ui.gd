extends RefCounted
const INK = Color("131224")
const PAPER = Color("fff1d6")
const MUTED = Color("a7a0c4")
const PINK = Color("ff7899")
const CYAN = Color("6ee4d3")
const GOLD = Color("ffd176")
const BLUE = Color("85a5ff")
const PURPLE = Color("b39bff")
static var font: FontFile

static func pixel_font() -> FontFile:
 if not font:
  font = load("res://assets/v2/pixel-12.ttf")
  font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
  font.subpixel_positioning = 0
  font.generate_mipmaps = false
 return font

static func style(bg: Color, edge: Color, thick: int = 1) -> StyleBoxFlat:
 var s = StyleBoxFlat.new()
 s.bg_color = bg
 s.border_color = edge
 s.set_border_width_all(thick)
 s.content_margin_left = 6
 s.content_margin_right = 6
 s.content_margin_top = 3
 s.content_margin_bottom = 3
 s.shadow_color = Color("080a16")
 s.shadow_size = 0
 return s

static func panel(parent: Node, r: Rect2, bg: Color, edge: Color) -> Panel:
 var n = Panel.new()
 n.position = r.position
 n.size = r.size
 n.add_theme_stylebox_override("panel", style(bg, edge))
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 return n

static func label(parent: Node, text: String, r: Rect2, color: Color = PAPER, px: int = 12) -> Label:
 var n = Label.new()
 n.position = r.position
 n.size = r.size
 n.text = text
 n.add_theme_font_override("font", pixel_font())
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
 n.add_theme_font_override("normal_font", pixel_font())
 n.add_theme_font_size_override("normal_font_size", 12)
 n.add_theme_color_override("default_color", color)
 n.add_theme_constant_override("line_separation", 3)
 n.scroll_active = false
 n.mouse_filter = Control.MOUSE_FILTER_IGNORE
 parent.add_child(n)
 return n

static func button(parent: Node, caption: String, r: Rect2, callback: Callable, accent: Color = CYAN, solid: bool = false) -> Button:
 var b = Button.new()
 b.text = caption
 b.position = r.position
 b.size = r.size
 b.add_theme_font_override("font", pixel_font())
 b.add_theme_font_size_override("font_size", 12)
 b.add_theme_color_override("font_color", INK if solid else accent)
 b.add_theme_color_override("font_hover_color", INK)
 b.add_theme_color_override("font_pressed_color", INK)
 b.add_theme_color_override("font_disabled_color", Color("77738e"))
 b.add_theme_stylebox_override("normal", style(accent if solid else Color("26223b"), accent))
 b.add_theme_stylebox_override("hover", style(accent.lightened(0.12), PAPER))
 b.add_theme_stylebox_override("pressed", style(accent.darkened(0.1), PAPER, 2))
 b.add_theme_stylebox_override("disabled", style(Color("201e31"), Color("45405b")))
 b.add_theme_stylebox_override("focus", style(Color(0,0,0,0), PAPER))
 b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
 b.pressed.connect(callback)
 parent.add_child(b)
 b.size = r.size
 return b

static func clear(node: Node) -> void:
 for child in node.get_children():
  node.remove_child(child)
  child.queue_free()
