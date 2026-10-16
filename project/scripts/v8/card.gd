extends Control
## A draggable card with Balatro-style feel: spring-follow while dragged, sway from velocity,
## tilt toward the mouse with a moving shine on hover, idle breathing, elastic snap on drop.
const UI=preload("res://scripts/v8/ui.gd")
const Juice=preload("res://scripts/v8/juice.gd")
const Icons=preload("res://scripts/v8/icons.gd")
signal dropped(card: Control, slot: Control)
signal picked(card: Control)
var tag: String=""
var title: String=""
var body: String=""
var accent: Color=UI.CYAN
var home: Vector2=Vector2.ZERO
var draggable: bool=true
var dragging: bool=false
var hovered: bool=false
var reduced: bool=false
var vel: Vector2=Vector2.ZERO
var grab: Vector2=Vector2.ZERO
var phase: float=0.0
var time: float=0.0
var lift: float=0.0
var scale_vel: float=0.0
var cur_scale: float=1.0
var tilt: Vector2=Vector2.ZERO
var over_slot: Control
var visual: Node2D
var face: Control
var small: bool=false
## Optional vector icon drawn on the face; cards show a thing before they show words.
var icon: String=""
var wobble: float=0.0

func setup(card_tag: String, card_title: String, card_body: String, color: Color, rect: Rect2, compact: bool=false) -> void:
 tag=card_tag; title=card_title; body=card_body; accent=color; small=compact
 position=rect.position; size=rect.size; home=rect.position
 mouse_filter=MOUSE_FILTER_STOP
 mouse_default_cursor_shape=Control.CURSOR_DRAG if draggable else Control.CURSOR_ARROW
 phase=randf()*TAU
 visual=Node2D.new(); visual.position=size/2; add_child(visual)
 face=Control.new(); face.position=-size/2; face.size=size; face.mouse_filter=MOUSE_FILTER_IGNORE
 visual.add_child(face)
 face.draw.connect(_draw_face)
 mouse_entered.connect(func():
  hovered=true
  if draggable and not dragging and not reduced:
   scale_vel+=2.2
   Sfx.play("hover"))
 mouse_exited.connect(func(): hovered=false)

func _draw() -> void:
 # Shadow stays on the table while the card lifts, which sells the height.
 var off=Vector2(3,5)+Vector2(lift*6,lift*10)
 draw_rect(Rect2(off+Vector2(2,2),size-Vector2(4,4)),Color(0,0,0,0.35+lift*0.15))

func _draw_face() -> void:
 var r=Rect2(Vector2.ZERO,size)
 var fill=Color("101a2c").lerp(accent,0.08)
 face.draw_style_box(UI.style(fill,Color(accent,0.85),1,6),r)
 face.draw_rect(Rect2(4,4,size.x-8,3),Color(accent,0.75))
 var font=UI.sans()
 var fs=11 if small else 12
 if small and size.y<34:
  # Chips: title and body share one line.
  var tx=8.0
  if not icon.is_empty():
   Icons.draw(face,icon,Rect2(6,(size.y-16)/2,16,16),accent,1.3); tx=28.0
  face.draw_string(UI.mono(),Vector2(tx,size.y/2+5),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-tx-6,fs,UI.PAPER)
  var tw=UI.mono().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
  if not body.is_empty(): face.draw_string(font,Vector2(tx+6+tw,size.y/2+5),body,HORIZONTAL_ALIGNMENT_LEFT,size.x-tx-12-tw,10,Color(UI.PAPER,0.72))
  if hovered or dragging:
   var sx=(tilt.x*0.5+0.5)*size.x
   face.draw_line(Vector2(sx-12,0),Vector2(sx-24,size.y),Color(1,1,1,0.12),5)
  return
 var y=36.0 if not small else 32.0
 var big=not icon.is_empty() and size.y>=70
 if big:
  # Tall cards: a big icon on top, words underneath.
  var ih=minf(size.y*0.40,44.0)
  Icons.draw(face,icon,Rect2((size.x-ih)/2,12,ih,ih),accent,1.8)
  var ty=12+ih+16
  var tw2=UI.mono().get_string_size(title,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
  face.draw_string(UI.mono(),Vector2(maxf(6,(size.x-tw2)/2),ty),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-12,fs,UI.PAPER)
  y=ty+15
 elif not icon.is_empty():
  Icons.draw(face,icon,Rect2(size.x-26,8,18,18),accent,1.3)
  face.draw_string(UI.mono(),Vector2(8,20 if not small else 18),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-40,fs,UI.PAPER)
 else:
  face.draw_string(UI.mono(),Vector2(8,20 if not small else 18),title,HORIZONTAL_ALIGNMENT_LEFT,size.x-14,fs,UI.PAPER)
 if not body.is_empty():
  for line in body.split("\n"):
   var lw=font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
   var lx=maxf(6,(size.x-lw)/2) if big else 8.0
   face.draw_string(font,Vector2(lx,y),line,HORIZONTAL_ALIGNMENT_LEFT,size.x-14,10,Color(UI.PAPER,0.72))
   y+=14
 # Shine band slides with the tilt, like light catching a foil card.
 if hovered or dragging:
  var x=(tilt.x*0.5+0.5)*size.x
  for i in range(6):
   var w=6.0-i
   face.draw_line(Vector2(x-30+i*3,0),Vector2(x-60+i*3,size.y),Color(1,1,1,0.035*(6-i)),w)

func _gui_input(event: InputEvent) -> void:
 if not draggable: return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   dragging=true; grab=get_local_mouse_position(); z_index=60
   scale_vel+=3.0
   Sfx.play("pick")
   picked.emit(self)
   accept_event()
  elif dragging:
   _release()
   accept_event()

func _release() -> void:
 dragging=false; z_index=0
 var slot=_slot_under_mouse()
 if over_slot and is_instance_valid(over_slot): over_slot.hot=false
 over_slot=null
 dropped.emit(self,slot)

func _slot_under_mouse() -> Control:
 var m=get_global_mouse_position()
 for s in get_tree().get_nodes_in_group("drop_slot"):
  if s.is_visible_in_tree() and s.get_global_rect().grow(6).has_point(m) and s.can_accept(tag): return s
 return null

## Enter like a dealt card: from below, slightly turned, staggered by `delay`.
func deal(delay: float) -> void:
 if reduced:
  modulate.a=1.0; return
 position=home+Vector2(randf_range(-20,20),70)
 modulate.a=0.0
 if visual: visual.rotation=randf_range(-0.3,0.3)
 var tw=create_tween(); tw.tween_interval(delay)
 tw.tween_callback(func(): Sfx.play("pick",1.2,-6.0))
 tw.tween_property(self,"modulate:a",1.0,0.16)

## "I can move" — a short shake when the player has been idle, never pointing at a target.
func nudge() -> void:
 if reduced or dragging or not draggable: return
 wobble=0.55; scale_vel+=2.5

## Snap back to where it lives, with a small wobble so the miss still feels physical.
func bounce_home() -> void:
 vel+=Vector2(randf_range(-80,80),-60)
 Sfx.play("reject")

## Absorbed into a slot: shrink and flash into its centre, then call back.
func absorb(target_global: Vector2, then: Callable) -> void:
 draggable=false; mouse_filter=MOUSE_FILTER_IGNORE
 var target=target_global-get_parent().get_global_rect().position-size/2
 var tw=create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
 tw.tween_property(self,"position",target,0.16)
 tw.tween_property(visual,"scale",Vector2(0.55,0.55),0.16)
 tw.chain().tween_callback(func():
  Juice.burst(target_global,accent,16)
  then.call())

func _process(delta: float) -> void:
 time+=delta
 var target=home
 if dragging:
  target=get_parent().get_local_mouse_position()-grab
  var s=_slot_under_mouse()
  if s!=over_slot:
   if over_slot and is_instance_valid(over_slot): over_slot.hot=false
   over_slot=s
   if s: s.hot=true; Sfx.play("hover",1.3)
 # Spring toward the target: stiff while dragging so it tracks the hand, softer when settling home.
 var k=420.0 if dragging else 170.0
 var damp=pow(0.0006 if dragging else 0.004,delta)
 vel+=(target-position)*k*delta
 vel*=damp
 position+=vel*delta
 if reduced and not dragging: position=target; vel=Vector2.ZERO
 # Scale spring with overshoot.
 var want=1.12 if dragging else 1.06 if hovered and draggable else 1.0
 scale_vel+=(want-cur_scale)*260.0*delta
 scale_vel*=pow(0.002,delta)
 cur_scale+=scale_vel*delta
 lift=lerpf(lift,1.0 if dragging else 0.4 if hovered else 0.0,clampf(delta*10,0,1))
 # Tilt toward the mouse while hovering; sway against the motion while dragging.
 var m=(get_local_mouse_position()-size/2)/(size/2)
 tilt=tilt.lerp(m.clamp(Vector2(-1,-1),Vector2(1,1)) if (hovered or dragging) else Vector2.ZERO,clampf(delta*10,0,1))
 var rot_target=clampf(-vel.x*0.0011,-0.4,0.4) if dragging else (0.0 if reduced else sin(time*1.1+phase)*0.025)
 if wobble>0.0:
  wobble=maxf(0.0,wobble-delta)
  rot_target+=sin(wobble*38.0)*0.14*wobble/0.55
 if visual:
  visual.rotation=lerpf(visual.rotation,rot_target,clampf(delta*14,0,1))
  visual.skew=-tilt.x*0.10 if not reduced else 0.0
  visual.scale=Vector2(cur_scale*(1.0-absf(tilt.y)*0.03),cur_scale*(1.0-absf(tilt.x)*0.02))
  visual.position=size/2+Vector2(0,(0.0 if reduced or dragging else sin(time*1.6+phase)*1.4)-lift*4)
 queue_redraw()
 if face: face.queue_redraw()
