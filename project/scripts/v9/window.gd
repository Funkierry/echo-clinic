extends Control
## A MEDIC-OS 98 window: bevelled frame, gradient title bar, minimise/maximise/close, drag by the
## title, double-click the title to maximise, drag the bottom-right grip to resize.
const UI=preload("res://scripts/v9/ui.gd")
const Icons=preload("res://scripts/v9/icons.gd")
const TITLE_H=20
const GRIP=12
signal closed(app_id: String)
signal minimized(app_id: String)
signal focused(app_id: String)
signal user_resized(app_id: String)
signal title_menu(app_id: String,at: Vector2)
var app_id: String=""
var title: String=""
var icon: String=""
var client: Control
var active: bool=true
var closable: bool=true
var movable: bool=true
var resizable: bool=false
var min_size: Vector2=Vector2(220,140)
var maximized: bool=false
var restore_rect: Rect2=Rect2()
## Where a maximised window goes: the desktop area right of the chat.
var max_rect: Rect2=Rect2(350,4,746,568)
var dragging: bool=false
var sizing: bool=false
var drag_off: Vector2=Vector2.ZERO
var last_title_click: int=0
var bounds: Rect2=Rect2(0,0,1100,576)
var reduced: bool=false
var buttons: Dictionary={}

func setup(id: String,caption: String,rect: Rect2,icon_name: String="",can_close: bool=true,can_min: bool=true,can_resize: bool=false) -> void:
 app_id=id; title=caption; icon=icon_name; closable=can_close; resizable=can_resize
 position=rect.position; size=rect.size
 mouse_filter=MOUSE_FILTER_STOP
 client=Control.new(); client.clip_contents=true
 add_child(client)
 if closable: buttons.close=_title_button("×",func(): close(),"关闭")
 if resizable: buttons.max=_title_button("□",func(): toggle_maximize(),"最大化")
 if can_min: buttons.min=_title_button("_",func(): minimize(),"最小化")
 _place()

func _title_button(caption: String,cb: Callable,tip: String) -> Button:
 var b=Button.new(); b.text=caption; b.size=Vector2(16,14); b.tooltip_text=tip
 b.add_theme_font_override("font",UI.mono()); b.add_theme_font_size_override("font_size",12)
 b.add_theme_color_override("font_color",UI.PAPER)
 b.add_theme_stylebox_override("normal",UI.bevel(UI.FACE)); b.add_theme_stylebox_override("hover",UI.bevel(UI.FACE.lightened(0.15)))
 b.add_theme_stylebox_override("pressed",UI.bevel(UI.FACE,true)); b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 for k in ["normal","hover","pressed"]:
  var sb: StyleBoxTexture=b.get_theme_stylebox(k).duplicate(); sb.content_margin_left=0; sb.content_margin_right=0; sb.content_margin_top=0; sb.content_margin_bottom=0; b.add_theme_stylebox_override(k,sb)
 b.focus_mode=Control.FOCUS_NONE
 b.pressed.connect(cb)
 add_child(b)
 return b

## Lays out the client well and the title buttons for the current size.
func _place() -> void:
 client.position=Vector2(4,TITLE_H+4); client.size=size-Vector2(8,TITLE_H+8)
 var x=size.x-22
 for k in ["close","max","min"]:
  if buttons.has(k):
   buttons[k].position=Vector2(x,4); x-=18 if k!="close" else 20
 if buttons.has("max"): buttons.max.text="❐" if maximized else "□"; buttons.max.tooltip_text="还原" if maximized else "最大化"
 queue_redraw()

func close() -> void:
 Sfx.play("click",0.8)
 closed.emit(app_id)

func minimize() -> void:
 Sfx.play("click",1.2)
 minimized.emit(app_id)

func toggle_maximize() -> void:
 if not resizable: return
 if maximized:
  maximized=false; _snap_to(restore_rect)
 else:
  restore_rect=Rect2(position,size); maximized=true; _snap_to(max_rect)
 Sfx.play("pick",1.1)

func _snap_to(r: Rect2) -> void:
 # The frame snaps; contents are rebuilt once at the new size.
 position=r.position; size=r.size; _place()
 user_resized.emit(app_id)

## Grows out of the icon it was opened from, the way old desktops did.
func open_from(origin: Vector2) -> void:
 pivot_offset=size/2
 var target=position
 scale=Vector2(0.2,0.2); modulate.a=0.0
 position=origin-size/2
 var tw=create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 tw.tween_property(self,"position",target,0.22)
 tw.tween_property(self,"scale",Vector2.ONE,0.22)
 tw.tween_property(self,"modulate:a",1.0,0.12)

## Shrinks toward a point (its taskbar button) and then hides; `done` runs at the end.
func shrink_to(point: Vector2,done: Callable) -> void:
 if reduced: done.call(); return
 pivot_offset=size/2
 var home=position
 var tw=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 tw.tween_property(self,"position",point-size/2,0.16)
 tw.tween_property(self,"scale",Vector2(0.1,0.1),0.16)
 tw.tween_property(self,"modulate:a",0.0,0.16)
 tw.chain().tween_callback(func():
  position=home; scale=Vector2.ONE; modulate.a=1.0
  done.call())

func _grip_rect() -> Rect2:
 return Rect2(size-Vector2(GRIP,GRIP),Vector2(GRIP,GRIP))

func _gui_input(event: InputEvent) -> void:
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   focused.emit(app_id)
   if resizable and not maximized and _grip_rect().has_point(event.position):
    sizing=true; drag_off=size-event.position; return
   if event.position.y<TITLE_H+3:
    var now=Time.get_ticks_msec()
    if now-last_title_click<400 and resizable:
     last_title_click=0; toggle_maximize(); return
    last_title_click=now
    if movable and not maximized:
     dragging=true; drag_off=event.position
  else:
   if sizing: sizing=false; user_resized.emit(app_id)
   dragging=false
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed and event.position.y<TITLE_H+3:
  focused.emit(app_id)
  title_menu.emit(app_id,event.global_position)
 elif event is InputEventMouseMotion:
  if dragging:
   var p=get_parent().get_local_mouse_position()-drag_off
   position=Vector2(clampf(p.x,bounds.position.x-size.x+60,bounds.end.x-60),clampf(p.y,bounds.position.y,bounds.end.y-TITLE_H))
  elif sizing:
   var want=event.position+drag_off
   size=Vector2(clampf(want.x,min_size.x,bounds.end.x-position.x),clampf(want.y,min_size.y,bounds.end.y-position.y))
   _place()
  mouse_default_cursor_shape=CURSOR_FDIAGSIZE if resizable and not maximized and _grip_rect().has_point(event.position) else CURSOR_ARROW

func _draw() -> void:
 var r=Rect2(Vector2.ZERO,size)
 draw_style_box(UI.bevel(UI.FACE),r)
 # Title bar: horizontal gradient when active, flat grey when not.
 var bar=Rect2(3,3,size.x-6,TITLE_H-2)
 if active:
  var steps=24
  for i in range(steps):
   var x0=bar.position.x+bar.size.x*i/steps
   draw_rect(Rect2(x0,bar.position.y,bar.size.x/steps+1,bar.size.y),UI.TITLE_A.lerp(UI.TITLE_B,float(i)/steps))
 else:
  draw_rect(bar,UI.TITLE_OFF)
 var tx=8.0
 if not icon.is_empty():
  Icons.draw(self,icon,Rect2(6,5,14,14),UI.PAPER,1.0); tx=24.0
 draw_string(UI.mono(),Vector2(tx,16),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-tx-70,12,UI.PAPER if active else UI.MUTED)
 # Client well.
 draw_rect(Rect2(client.position-Vector2(1,1),client.size+Vector2(2,2)),UI.FACE_LO,false,1.0)
 # Size grip: three diagonal ridges.
 if resizable and not maximized:
  for i in range(3):
   var o=4+i*3
   draw_line(Vector2(size.x-o,size.y-2),Vector2(size.x-2,size.y-o),UI.FACE_HI,1.0)
