extends Control
const UI = preload("res://scripts/pixel_ui.gd")
signal selected(item: int)
signal placed(item: int, slot: int)
var item: int = -1
var slot: int = -1
var active: bool = true
var chosen: bool = false
var hovering: bool = false
var dragging: bool = false
var time: float = 0
var occupied: bool = false
var reduced_motion: bool = false
const TITLES = ["名字", "雨声", "门铃"]
const DETAILS = ["我选择了回声", "外面正在下雨", "请求打开出口"]
const COLORS = [UI.GOLD, UI.CYAN, UI.PINK]

func _ready() -> void:
 mouse_default_cursor_shape = CURSOR_POINTING_HAND
 mouse_entered.connect(func(): hovering = true; queue_redraw())
 mouse_exited.connect(func(): hovering = false; queue_redraw())

func _process(delta: float) -> void:
 time += delta
 if hovering: queue_redraw()

func _gui_input(event: InputEvent) -> void:
 if active and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed and not dragging:
  if slot >= 0: placed.emit(-1, slot)
  elif item >= 0: selected.emit(item)
  accept_event()

func _get_drag_data(_at: Vector2) -> Variant:
 if not active or slot >= 0 or occupied: return null
 dragging = true
 var preview = Control.new()
 preview.custom_minimum_size = size
 UI.panel(preview,Rect2(-size/2,size),Color("302542"),COLORS[item])
 UI.label(preview,TITLES[item],Rect2(-size/2+Vector2(8,8),size),COLORS[item])
 set_drag_preview(preview)
 return {"memory": item}

func _can_drop_data(_at: Vector2, data: Variant) -> bool:
 return active and slot >= 0 and data is Dictionary and data.has("memory") and int(data.memory) in [0,1,2]

func _drop_data(_at: Vector2, data: Variant) -> void:
 placed.emit(int(data.memory),slot)

func _notification(what: int) -> void:
 if what == NOTIFICATION_DRAG_END: dragging = false

func _draw() -> void:
 var c = COLORS[item] if item >= 0 else UI.PURPLE
 var shift = -2 if hovering and active and not reduced_motion else 0
 var r = Rect2(0,shift,size.x,size.y)
 draw_rect(Rect2(2,3+shift,size.x,size.y),UI.INK)
 draw_rect(r,Color("342943") if slot < 0 else Color("1c2335"))
 draw_rect(r,UI.PAPER if chosen else c.darkened(0.45) if occupied else c,false,2 if chosen else 1)
 if slot < 0:
  draw_rect(Rect2(1,shift+1,size.x-2,3),c)
  if hovering and active:
   var sweep = int(time*60) % int(size.x)
   draw_rect(Rect2(sweep,shift+4,2,size.y-5),Color(c,0.22))
  draw_string(UI.pixel_font(),Vector2(8,shift+20),TITLES[item],HORIZONTAL_ALIGNMENT_LEFT,-1,12,c)
  draw_string(UI.pixel_font(),Vector2(8,shift+37),"已放入" if occupied else DETAILS[item],HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.MUTED if occupied else UI.PAPER)
 else:
  draw_string(UI.pixel_font(),Vector2(7,shift+19),"%02d  %s" % [slot+1,TITLES[item] if item>=0 else "放入记忆"],HORIZONTAL_ALIGNMENT_LEFT,-1,12,c)

