extends Control
## Press and hold to sign. The seal fills, trembles harder as it nears the end, then stamps down.
const UI=preload("res://scripts/v8/ui.gd")
const Juice=preload("res://scripts/v8/juice.gd")
signal signed
var progress: float=0.0
var holding: bool=false
var done: bool=false
var duration: float=1.1
var caption: String="按住签字"
var accent: Color=UI.GOLD
var time: float=0.0
var tone_clock: float=0.0

func setup(rect: Rect2, text: String="按住签字", color: Color=UI.GOLD) -> void:
 position=rect.position; size=rect.size; caption=text; accent=color
 mouse_filter=MOUSE_FILTER_STOP
 mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND

func _gui_input(event: InputEvent) -> void:
 if done: return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  holding=event.pressed
  accept_event()

func _notification(what: int) -> void:
 if what==NOTIFICATION_MOUSE_EXIT: holding=false

## Used by tests and the keyboard path: completes the signature at once.
func complete() -> void:
 if done: return
 progress=1.0; _finish()

func _finish() -> void:
 done=true; holding=false
 Sfx.play("stamp")
 Juice.burst(get_global_rect().get_center(),accent,30,220)
 Juice.shake(7.0)
 Juice.hitstop(0.07)
 Juice.punch(self,0.22)
 signed.emit()

func _process(delta: float) -> void:
 time+=delta
 if not done:
  progress=clampf(progress+(delta/duration if holding else -delta*2.2),0.0,1.0)
  if holding:
   tone_clock-=delta
   if tone_clock<=0.0:
    # A rising tick while the seal fills.
    Sfx.play("sign_hold",0.8+progress*0.9); tone_clock=0.09
  if progress>=1.0: _finish()
 queue_redraw()

func _draw() -> void:
 var c=size/2
 var jitter=Vector2(randf_range(-1,1),randf_range(-1,1))*progress*progress*3.0 if holding else Vector2.ZERO
 c+=jitter
 var radius=minf(size.x,size.y)*0.42
 draw_circle(c,radius,Color(accent,0.06+progress*0.12))
 draw_arc(c,radius,0,TAU,64,Color(accent,0.35),1.5,true)
 if progress>0.0:
  draw_arc(c,radius,-PI/2,-PI/2+TAU*progress,64,accent,4.0,true)
 var font=UI.sans()
 var text="已签字" if done else caption
 var fs=14
 var w=font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
 draw_string(font,c+Vector2(-w/2,5),text,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,UI.PAPER if not done else accent)
