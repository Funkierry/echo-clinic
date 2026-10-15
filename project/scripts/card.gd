extends Control

signal selected(card_id: String)
signal released(card_id: String, center: Vector2)
signal hover_sound

var card_id: String = ""
var caption: String = ""
var detail: String = ""
var code: String = ""
var accent: Color = Color("8ce5cb")
var home: Vector2
var dragging: bool = false
var hovered: bool = false
var locked: bool = false
var reduced_motion: bool = false
var held_offset: Vector2
var press_point: Vector2
var tilt_velocity: float = 0.0
var target_rotation: float = 0.0
var glow: float = 0.0
var clock: float = 0.0
var font: Font
var mono: Font
var foil: ColorRect

func _ready() -> void:
	font = load("res://assets/font-ui.tres")
	mono = load("res://assets/font-mono.tres")
	size = Vector2(152, 164)
	pivot_offset = size / 2.0
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	tooltip_text = "拖拽到右侧记忆插槽" if card_id == "anchor" else "点击查阅；可拖动查看卡面"
	foil = ColorRect.new()
	foil.size = size
	foil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var material_instance = ShaderMaterial.new()
	material_instance.shader = load("res://shaders/foil.gdshader")
	material_instance.set_shader_parameter("accent", accent)
	material_instance.set_shader_parameter("phase", float(card_id.hash() % 100) / 100.0)
	foil.material = material_instance
	add_child(foil)
	mouse_entered.connect(func():
		hovered = true
		if not locked: hover_sound.emit())
	mouse_exited.connect(func(): hovered = false)
	gui_input.connect(_on_input)

func _process(delta: float) -> void:
	clock += delta
	if locked:
		return
	var target_scale = Vector2.ONE * (1.055 if hovered or dragging else 1.0)
	if reduced_motion: target_scale = Vector2.ONE
	scale = scale.lerp(target_scale, 1.0 - exp(-delta * 16.0))
	glow = lerpf(glow, 1.0 if hovered or dragging else 0.0, 1.0-exp(-delta*12.0))
	if dragging:
		var desired = get_global_mouse_position() - held_offset
		var dx = desired.x - position.x
		position = position.lerp(desired, 1.0-exp(-delta*24.0))
		target_rotation = clampf(dx * 0.004, -0.14, 0.14)
	else:
		position = position.lerp(home + Vector2(0, -7 if hovered and not reduced_motion else 0), 1.0-exp(-delta*16.0))
		var local_pointer = get_local_mouse_position()
		target_rotation = clampf((local_pointer.x-size.x/2.0)*0.0011, -0.08, 0.08) if hovered else 0.0
	if reduced_motion: target_rotation = 0.0
	tilt_velocity += (target_rotation-rotation)*120.0*delta
	tilt_velocity *= exp(-delta*14.0)
	rotation += tilt_velocity*delta
	foil.material.set_shader_parameter("hover", glow)
	queue_redraw()

func _on_input(event: InputEvent) -> void:
	if locked: return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		dragging = true
		press_point = get_global_mouse_position()
		held_offset = press_point - position
		z_index = 20
		accept_event()

func _input(event: InputEvent) -> void:
	if dragging and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		dragging = false
		z_index = 1
		if get_global_mouse_position().distance_to(press_point) < 9:
			selected.emit(card_id)
		else:
			released.emit(card_id, get_global_mouse_position())

func _draw() -> void:
	draw_rect(Rect2(5, 7, size.x, size.y), Color(0,0,0,0.3))
	draw_rect(Rect2(Vector2.ZERO, size), Color("12252c"))
	draw_rect(Rect2(Vector2.ZERO, size), accent * Color(1,1,1,0.3+glow*0.6), false, 1.0)
	draw_line(Vector2(0,0), Vector2(40,0), accent, 3.0)
	draw_string(mono, Vector2(12,23), code, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, accent)
	var c = Vector2(size.x/2.0, 67)
	if card_id == "anchor":
		for i in range(5):
			var r = 27.0-float(i)*4.5
			var points = PackedVector2Array([c+Vector2(0,-r),c+Vector2(r,0),c+Vector2(0,r),c+Vector2(-r,0),c+Vector2(0,-r)])
			draw_polyline(points, accent * Color(1,1,1,0.3+float(i)*0.13), 1.0)
		draw_rect(Rect2(c-Vector2(4,4),Vector2(8,8)), Color("efffee"))
	elif card_id == "log":
		for i in range(5):
			draw_line(c+Vector2(-28,-20+i*10),c+Vector2(25 if i%2==0 else 8,-20+i*10),accent*Color(1,1,1,0.4+0.12*i),2)
		draw_rect(Rect2(c+Vector2(16,-4),Vector2(12,12)),accent,false,1)
	else:
		draw_rect(Rect2(c-Vector2(26,25),Vector2(52,48)),accent,false,2)
		draw_line(c+Vector2(-15,0),c+Vector2(18,0),accent,2)
		draw_polyline(PackedVector2Array([c+Vector2(7,-10),c+Vector2(18,0),c+Vector2(7,10)]),accent,2)
	draw_string(font, Vector2(12,120), caption, HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color("dce8df"))
	draw_string(font, Vector2(12,145), detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("77958f"))
