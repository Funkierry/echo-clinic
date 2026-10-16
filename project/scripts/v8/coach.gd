extends Control
## First-time teaching marks. Each tip explains how to *operate* something (drag, hold, type),
## never what the right answer is. A tip shows once, disappears when you do the thing, and can be
## turned off from its own bubble or from Settings.
const UI=preload("res://scripts/v8/ui.gd")
signal changed
var enabled: bool=true
var seen: Dictionary={}
var tip_id: String=""
var target: Rect2=Rect2()
var ghost_from: Vector2=Vector2.ZERO
var ghost_to: Vector2=Vector2.ZERO
var time: float=0.0
var bubble: PanelContainer
var body: RichTextLabel
var dismiss_only: bool=false

func _ready() -> void:
 mouse_filter=MOUSE_FILTER_IGNORE
 z_index=110
 size=Vector2(1100,600)

func set_enabled(on: bool) -> void:
 enabled=on
 if not on: hide_tip()
 changed.emit()

func reset() -> void:
 seen={}; enabled=true; changed.emit()

func is_seen(id: String) -> bool:
 return seen.has(id)

## Marks a tip as learned. Called when the player has actually done the thing it teaches.
func done(id: String) -> void:
 if seen.has(id): return
 seen[id]=true
 if tip_id==id: hide_tip()
 changed.emit()

func show_tip(id: String,rect: Rect2,text: String,from: Vector2=Vector2.ZERO,to: Vector2=Vector2.ZERO,only_dismiss: bool=false) -> void:
 if not enabled or seen.has(id): return
 var origin=get_global_rect().position
 target=Rect2(rect.position-origin,rect.size)
 ghost_from=from-origin if from!=Vector2.ZERO else Vector2.ZERO
 ghost_to=to-origin if to!=Vector2.ZERO else Vector2.ZERO
 if id!=tip_id:
  tip_id=id; dismiss_only=only_dismiss; time=0.0
  _build(text)
  Sfx.play("reveal",1.3,-8.0)
 _place()

func hide_tip() -> void:
 tip_id=""
 if is_instance_valid(bubble): bubble.queue_free()
 bubble=null
 queue_redraw()

func _build(text: String) -> void:
 if is_instance_valid(bubble): bubble.queue_free()
 bubble=PanelContainer.new()
 var look=UI.style(Color("101a2c"),UI.GOLD,1,6); look.content_margin_left=12; look.content_margin_right=12; look.content_margin_top=10; look.content_margin_bottom=10
 bubble.add_theme_stylebox_override("panel",look)
 bubble.mouse_filter=MOUSE_FILTER_STOP
 add_child(bubble)
 var box=VBoxContainer.new(); box.add_theme_constant_override("separation",8); bubble.add_child(box)
 var head=Label.new(); head.text="✎ 上一班的便签"; head.add_theme_color_override("font_color",UI.GOLD); head.add_theme_font_override("font",UI.mono()); head.add_theme_font_size_override("font_size",10); box.add_child(head)
 body=RichTextLabel.new(); body.fit_content=true; body.scroll_active=false; body.custom_minimum_size=Vector2(260,0); body.text=text
 body.add_theme_font_override("normal_font",UI.sans()); body.add_theme_font_size_override("normal_font_size",13); body.add_theme_color_override("default_color",UI.PAPER)
 body.mouse_filter=MOUSE_FILTER_IGNORE
 box.add_child(body)
 var row=HBoxContainer.new(); row.add_theme_constant_override("separation",8); box.add_child(row)
 var ok=UI.button(row,"知道了",Rect2(0,0,90,24),func(): done(tip_id),UI.GOLD,true); ok.custom_minimum_size=Vector2(90,24)
 var off=UI.button(row,"关闭教学",Rect2(0,0,90,24),func(): set_enabled(false),UI.MUTED); off.custom_minimum_size=Vector2(90,24)
 bubble.modulate.a=0.0
 bubble.create_tween().tween_property(bubble,"modulate:a",1.0,0.2)

func _place() -> void:
 if not is_instance_valid(bubble): return
 var s=bubble.get_combined_minimum_size()
 var area=Rect2(8,36,1084,420)
 var cy=clampf(target.get_center().y-s.y/2,area.position.y,area.end.y-s.y)
 var cx=clampf(target.get_center().x-s.x/2,area.position.x,area.end.x-s.x)
 var options=[Vector2(target.position.x-16-s.x,cy),Vector2(target.end.x+16,cy),Vector2(cx,target.position.y-14-s.y),Vector2(cx,target.end.y+14)]
 var pos=options[0]
 for o in options:
  if Rect2(o,s).grow(-1).intersection(target).has_area(): continue
  if area.encloses(Rect2(o,s)): pos=o; break
 bubble.position=pos

func _process(delta: float) -> void:
 time+=delta
 if not tip_id.is_empty(): queue_redraw()

func _draw() -> void:
 if tip_id.is_empty(): return
 var pulse=0.5+0.5*sin(time*5.0)
 var r=target.grow(4+pulse*3)
 draw_rect(r,Color(UI.GOLD,0.10+0.08*pulse))
 draw_rect(r,Color(UI.GOLD,0.55+0.4*pulse),false,2.0)
 if is_instance_valid(bubble):
  var a=bubble.position+Vector2(bubble.size.x/2,0 if bubble.position.y>target.position.y else bubble.size.y)
  var b=Vector2(clampf(a.x,r.position.x,r.end.x),r.end.y if bubble.position.y>target.position.y else r.position.y)
  draw_line(a,b,Color(UI.GOLD,0.7),1.5)
 # Ghost drag: a faint card glides from where it is to where it could go, then fades.
 if ghost_from!=Vector2.ZERO and ghost_to!=Vector2.ZERO:
  var k=fmod(time,1.8)/1.8
  var e=ease(clampf(k*1.4,0.0,1.0),-2.2)
  var at=ghost_from.lerp(ghost_to,e)
  var alpha=sin(clampf(k*1.25,0,1)*PI)*0.7
  draw_rect(Rect2(at-Vector2(30,20),Vector2(60,40)),Color(UI.CYAN,0.18*alpha))
  draw_rect(Rect2(at-Vector2(30,20),Vector2(60,40)),Color(UI.CYAN,alpha),false,1.5)
  draw_string(UI.mono(),at+Vector2(-6,30),"☝",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(UI.PAPER,alpha))
