extends Control
## 患者监护: who she is right now. Her face, stability, and the context window (what she still
## remembers, what drops out next, and pins). The night's exam starts here.
const UI=preload("res://scripts/v9/ui.gd")
const Ascii=preload("res://scripts/v9/ascii_portrait.gd")
const Case=preload("res://scripts/v9/case.gd")
const Profile=preload("res://scripts/v9/profile.gd")
var host
var state
var time: float=0.0

func setup(main) -> void:
 host=main; state=main.state
 size=get_parent().size
 var face=Panel.new(); face.position=Vector2(4,4); face.size=Vector2(130,170); face.add_theme_stylebox_override("panel",UI.bevel(Color("05080f"),true)); face.mouse_filter=MOUSE_FILTER_IGNORE; add_child(face)
 var p=Ascii.new(); p.reduced=host.reduced_motion or host.self_testing; add_child(p)
 p.setup(Rect2(7,7,124,164),host.current_mood,false)
 # Her face can be clicked; she does not like being stared at.
 var poke=Control.new(); poke.position=Vector2(4,4); poke.size=Vector2(130,170); poke.mouse_filter=MOUSE_FILTER_STOP
 poke.tooltip_text="E-017"; poke.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
 poke.gui_input.connect(func(e):
  if e is InputEventMouseButton and e.pressed and e.button_index==MOUSE_BUTTON_LEFT: host.poke_portrait())
 add_child(poke)
 UI.label(self,"E-017 · 回声",Rect2(142,6,160,14),UI.CYAN)
 var stab=state.stability-(15 if host.profile.renting else 0)
 UI.label(self,"稳定度  %d%%"%maxi(0,stab),Rect2(142,26,160,14),UI.PAPER)
 var bar=Panel.new(); bar.position=Vector2(142,44); bar.size=Vector2(size.x-150,12); bar.add_theme_stylebox_override("panel",UI.bevel(UI.FACE_LO,true)); bar.mouse_filter=MOUSE_FILTER_IGNORE; add_child(bar)
 var fill=ColorRect.new(); fill.position=Vector2(144,46); fill.size=Vector2((size.x-154)*clampf(stab/100.0,0,1),8); fill.color=UI.PINK if stab<40 else UI.GOLD if stab<70 else UI.CYAN; add_child(fill)
 var used=state.used(); var cap=state.capacity()
 UI.label(self,"上下文  %0.1fK / %0.1fK"%[used/1000.0,cap/1000.0],Rect2(142,64,size.x-150,14),UI.PINK if used>cap*0.85 else UI.PAPER)
 UI.label(self,"置顶 %d / %d · 每段 %dT"%[state.pins(),Case.MAX_PINS,Profile.PIN],Rect2(142,82,size.x-150,14),UI.MUTED)
 if host.profile.renting: UI.label(self,"算力出租中：她变慢了",Rect2(142,100,size.x-150,14),UI.GOLD)
 if state.allowed().has("accept"):
  UI.button(self,"开始接诊 · %dT"%Profile.EXAM,Rect2(142,140,size.x-150,28),func(): host._act("accept",null),UI.CYAN,true)
 # Memory list.
 var well=Panel.new(); well.position=Vector2(4,180); well.size=Vector2(size.x-8,size.y-184); well.add_theme_stylebox_override("panel",UI.bevel(UI.FACE_LO,true)); well.mouse_filter=MOUSE_FILTER_IGNORE; add_child(well)
 var next_drop=""
 for m in state.memories:
  if m.state=="live" and not m.pinned: next_drop=m.id; break
 var y=184
 for m in state.memories:
  if y>size.y-22: break
  var mark="◆" if m.pinned else "·"
  var tail="  已截断" if m.state=="lost" else "  已卖出" if m.state=="sold" else "  ← 下一个忘掉" if m.id==next_drop else ""
  var col=UI.DIM if m.state!="live" else UI.PINK if m.id==next_drop else UI.GOLD if m.pinned else UI.PAPER
  UI.label(self,"%s %s%s"%[mark,m.label,tail],Rect2(10,y,size.x-80,14),col)
  if m.state=="live" and not m.pinned:
   var id=m.id
   var b=UI.button(self,"置顶",Rect2(size.x-62,y-2,54,18),func(): host._pin(id),UI.CYAN)
   b.disabled=not state.can_pin(m.id) or host.profile.available()<Profile.PIN
  y+=20
