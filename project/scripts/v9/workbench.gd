extends Control
## The examination bench: "her world". Every step is a physical act — drag a card somewhere,
## scrub a recording, hold a seal. Nothing on screen says which move is right.
## While Echo is still talking the bench stays locked: read her first, then act.
const UI=preload("res://scripts/v9/ui.gd")
const Case=preload("res://scripts/v9/case.gd")
const Story=preload("res://scripts/v9/story.gd")
const Ascii=preload("res://scripts/v9/ascii_portrait.gd")
const Card=preload("res://scripts/v9/card.gd")
const Slot=preload("res://scripts/v9/slot.gd")
const HoldSign=preload("res://scripts/v9/hold_sign.gd")
const Juice=preload("res://scripts/v9/juice.gd")
const Icons=preload("res://scripts/v9/icons.gd")
var state
var content: Control
var time: float=0
var reduced: bool=false
var feedback: String=""
var confirmation: Dictionary={}
var profile
var mood: String="calm"
var portraits: Array=[]
var seen_portraits: Dictionary={}
## A short line the bench says after a wrong drop. Cleared when the scene changes.
var note: String=""
var note_color: Color=UI.PINK
var note_label: Label
var last_scene: String=""
var cards: Dictionary={}
var slots: Dictionary={}
## Story-first gate.
var locked: bool=false
var gate: Control
var gate_alpha: float=0.0
var dealt_scene: String=""
## A rebuild requested mid-drag waits until the card is released.
var deferred: Array=[]
var idle: float=0.0
var layers: Array=[]
signal action(id: String,value: Variant)
signal unlocked

func _ready() -> void:
 clip_contents=true; mouse_filter=MOUSE_FILTER_IGNORE
 content=Control.new(); content.size=size; content.mouse_filter=MOUSE_FILTER_IGNORE; add_child(content)

func _process(delta: float) -> void:
 if not reduced: time+=delta
 gate_alpha=lerpf(gate_alpha,1.0 if locked else 0.0,clampf(delta*8.0,0,1))
 if is_instance_valid(gate):
  gate.mouse_filter=MOUSE_FILTER_STOP if locked else MOUSE_FILTER_IGNORE
  gate.queue_redraw()
 # Idle nudge: after 8 s without touching anything, the movable cards give a little shake.
 idle+=delta
 if not locked and idle>8.0:
  idle=0.0
  var i=0
  for c in cards.values():
   if is_instance_valid(c) and c.draggable:
    get_tree().create_timer(i*0.12).timeout.connect(func(): if is_instance_valid(c): c.nudge())
    i+=1
 for l in layers:
  if is_instance_valid(l): l.queue_redraw()
 queue_redraw()

func _input(event: InputEvent) -> void:
 if event is InputEventMouseButton or event is InputEventKey: idle=0.0

func _scene_key() -> String:
 return "%d/%d/%s"%[state.loop,state.phase,state.ending]

func _dragging() -> bool:
 for c in cards.values():
  if is_instance_valid(c) and c.dragging: return true
 return false

## Locked while she speaks; on the first unlock of a scene the cards are dealt onto the table.
func set_locked(on: bool) -> void:
 if on==locked: return
 locked=on
 if not on and dealt_scene!=_scene_key():
  dealt_scene=_scene_key()
  deal_cards()
  Sfx.play("reveal",1.15,-6.0)
  unlocked.emit()

func deal_cards() -> void:
 var i=0
 var ordered=cards.values()
 ordered.sort_custom(func(a,b): return a.home.y<b.home.y or a.home.y==b.home.y and a.home.x<b.home.x)
 for c in ordered:
  if is_instance_valid(c): c.deal(0.08+i*0.07); i+=1

func setup(model,message: String="") -> void:
 if _dragging():
  deferred=[model,message]; return
 state=model; feedback=message
 if _scene_key()!=last_scene: note=""; last_scene=_scene_key()
 UI.clear(content)
 portraits=[]; cards={}; slots={}; layers=[]
 UI.panel(content,Rect2(0,0,454,404),Color(0,0,0,0),Color("345473"))
 UI.panel(content,Rect2(0,0,454,31),Color("142c48"),Color("36597e"))
 UI.label(content,state.title(),Rect2(13,7,385,18),UI.PURPLE if state.later() else UI.BLUE)
 UI.label(content,"II" if state.later() else "I",Rect2(426,7,20,18),UI.GOLD)
 match state.phase:
  0: _arrival()
  1: _trace_second() if state.later() else _trace()
  2: _memory_second() if state.later() else _memory()
  3: _letter_second() if state.later() else _letter()
  4: _decision()
  5: _treatment()
  6: _ending()
 note_label=UI.label(content,note,Rect2(16,386,422,16),note_color,10)
 gate=Control.new(); gate.position=Vector2(0,31); gate.size=Vector2(454,373); content.add_child(gate)
 gate.draw.connect(_draw_gate)
 if not confirmation.is_empty(): _sign_panel()
 # A new scene's cards wait face-down while she talks, then get dealt; later refreshes leave them be.
 var key=_scene_key()
 if dealt_scene!=key:
  if locked:
   for c in cards.values(): c.modulate.a=0.0
  else:
   dealt_scene=key; deal_cards()

func _draw_gate() -> void:
 if gate_alpha<0.02: return
 gate.draw_rect(Rect2(Vector2.ZERO,gate.size),Color(0.02,0.03,0.07,0.88*gate_alpha))
 # A centred panel: she is talking on the left; this side waits for her.
 var box=Rect2(gate.size.x/2-130,gate.size.y/2-44,260,88)
 gate.draw_rect(box,Color(0.05,0.08,0.15,0.95*gate_alpha))
 gate.draw_rect(box,Color(UI.BLUE,0.7*gate_alpha),false,1.0)
 var font=UI.sans()
 var dots=".".repeat(int(time*3.0)%4)
 var w=font.get_string_size("先听她说完...",HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
 gate.draw_string(font,Vector2(box.get_center().x-w/2+12,box.position.y+38),"先听她说完"+dots,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(UI.PAPER,gate_alpha))
 for i in range(3):
  var x=box.position.x+18+i*10-fmod(time*16.0,10.0)
  var y=box.position.y+32
  gate.draw_polyline(PackedVector2Array([Vector2(x+6,y-6),Vector2(x,y),Vector2(x+6,y+6)]),Color(UI.BLUE,0.8*gate_alpha*(1.0-i*0.3)),2.0)
 var hint="她说完，这里就会亮起来 · 空格跳过"
 var hw=UI.mono().get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x
 gate.draw_string(UI.mono(),Vector2(box.get_center().x-hw/2,box.position.y+66),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,10,Color(UI.MUTED,gate_alpha))

# --- shared pieces ----------------------------------------------------------

func _card(tag: String,title: String,body: String,color: Color,rect: Rect2,compact: bool=false,movable: bool=true,icon: String="") -> Control:
 var c=Card.new(); c.draggable=movable; c.reduced=reduced; c.icon=icon
 content.add_child(c)
 c.setup(tag,title,body,color,rect,compact)
 c.dropped.connect(_card_dropped)
 cards[tag]=c
 return c

func _slot(id: String,rect: Rect2,accepts: Array,caption: String="",color: Color=UI.BLUE) -> Control:
 var s=Slot.new(); content.add_child(s)
 s.setup(id,rect,accepts,caption,color)
 slots[id]=s
 return s

func _say(text: String,color: Color=UI.PINK) -> void:
 note=text; note_color=color
 if is_instance_valid(note_label):
  note_label.text=text; note_label.add_theme_color_override("font_color",color)
  Juice.punch(note_label,0.08)

func _card_dropped(card: Control,slot: Control) -> void:
 idle=0.0
 var pend=deferred; deferred=[]
 if slot==null:
  # Pulling the top version off the edit-history stack shows what lies underneath.
  if card.tag=="v2" and state.seen("memory_listen") and not state.seen("memory_undo"):
   _peel(card); return
  if not pend.is_empty(): setup(pend[0],pend[1])
  return
 var verdict=_judge(card.tag,slot.id)
 if not verdict.ok:
  card.bounce_home()
  if not str(verdict.get("say","")).is_empty(): _say(verdict.say)
  if not pend.is_empty(): setup(pend[0],pend[1])
  return
 Sfx.play("slot")
 Juice.punch(slot,0.12)
 card.absorb(slot.get_global_rect().get_center(),func(): _apply(card.tag,slot.id))

func _peel(card: Control) -> void:
 card.draggable=false
 Sfx.play("withdraw",1.2,-4.0)
 var tw=card.create_tween().set_parallel(true)
 tw.tween_property(card,"position",card.position+Vector2(240,-30),0.3).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
 tw.tween_property(card,"modulate:a",0.0,0.3)
 tw.chain().tween_callback(func(): action.emit("instrument",{"kind":"history","value":0}))

## Test and keyboard entry point: the same rules as a real drop, without the animation.
func drop(tag: String,slot_id: String) -> bool:
 var verdict=_judge(tag,slot_id)
 if not verdict.ok:
  if not str(verdict.get("say","")).is_empty(): _say(verdict.say)
  return false
 _apply(tag,slot_id)
 return true

# The signature sits where the decision was made: hold the seal on the bench.
func _sign_panel() -> void:
 var shade=ColorRect.new(); shade.position=Vector2(0,31); shade.size=Vector2(454,373); shade.color=Color(0.03,0.07,0.14,0.9)
 content.add_child(shade)
 UI.panel(content,Rect2(16,46,422,344),Color("1a2940"),UI.GOLD)
 UI.label(content,"医生签字 / "+str(confirmation.title),Rect2(30,58,394,20),UI.GOLD)
 UI.text(content,str(confirmation.detail),Rect2(30,90,394,180),UI.PAPER)
 var serial=int(confirmation.serial)
 var seal=HoldSign.new(); content.add_child(seal)
 seal.setup(Rect2(30,270,150,110),"按住签字",UI.GOLD)
 seal.name="Seal"
 seal.signed.connect(func(): action.emit("sign",serial))
 UI.label(content,"松手就停。签下去会立即执行。",Rect2(190,300,240,16),UI.MUTED,10)
 UI.button(content,"再想想",Rect2(302,340,122,34),func(): action.emit("unsign",serial),UI.MUTED)

func _button(caption: String,rect: Rect2,id: String,value: Variant=null,accent: Color=UI.BLUE,solid: bool=false) -> Button:
 var b=UI.button(content,caption,rect,func(): action.emit(id,value),accent,solid)
 b.disabled=not state.allowed().has(id)
 return b

func _portrait(rect: Rect2,tint: Color=Color.WHITE) -> void:
 var p=Ascii.new(); p.reduced=reduced; p.tint=tint
 content.add_child(p)
 # Assemble from scattered characters only when the scene changes, not on every refresh.
 var key="%d/%s/%d/%d"%[state.phase,state.ending,state.loop,int(rect.position.x)]
 p.setup(rect,mood,not seen_portraits.has(key))
 seen_portraits[key]=true
 portraits.append(p)

func set_mood(next: String) -> void:
 mood=next
 for p in portraits:
  if is_instance_valid(p): p.set_mood(next)

func _paper(rect: Rect2,title: String,body: String,accent: Color=UI.BLUE) -> void:
 UI.panel(content,rect,Color("11263e"),accent.darkened(0.55))
 UI.label(content,title,Rect2(rect.position+Vector2(12,9),Vector2(rect.size.x-24,18)),accent)
 UI.text(content,body,Rect2(rect.position+Vector2(12,38),Vector2(rect.size.x-24,rect.size.y-46)),UI.PAPER)

## A custom-drawn layer inside the content (between earlier and later children).
func _layer(draw_fn: Callable) -> Control:
 var l=Control.new(); l.size=Vector2(454,404); l.mouse_filter=MOUSE_FILTER_IGNORE
 content.add_child(l)
 l.draw.connect(func(): draw_fn.call(l))
 layers.append(l)
 return l

# --- rules: which drop means what -------------------------------------------

func _judge(tag: String,slot_id: String) -> Dictionary:
 var s=state
 match slot_id:
  "plug":
   return {"ok":tag=="exam" and s.allowed().has("accept")}
  "row17":
   if tag!="sigstop": return {"ok":false}
   if s.seen("quiet"): return {"ok":false,"say":"17 号已经停了。"}
   return {"ok":s.allowed().has("quiet")}
  "row42":
   if tag!="sigstop": return {"ok":false}
   if not s.seen("receipt"): return {"ok":false,"say":"你还说不清 42 号在做什么。"}
   return {"ok":s.allowed().has("trace_finish")}
  "row73":
   return {"ok":false,"say":"那是她本人。" if tag=="sigstop" else ""}
  "spike13","spike31":
   if not tag.begins_with("log:"): return {"ok":false}
   var parts=tag.split(":")
   var proc=parts[1]; var at=parts[2]
   var want=slot_id.trim_prefix("spike")
   if proc=="73": return {"ok":false,"say":"这一条就是疼本身。"}
   if at!=want: return {"ok":false,"say":"时间对不上。那一刻她没有疼。"}
   return {"ok":proc=="42"}
  "diff": return {"ok":tag=="tonight" and s.allowed().has("compare")}
  "follow": return {"ok":tag=="page3" and s.allowed().has("trace_finish")}
  "chart":
   if tag=="v1": return {"ok":s.allowed().has("memory_keep")}
   if tag=="v2": return {"ok":s.allowed().has("memory_accept")}
   return {"ok":false}
  "reader2": return {"ok":tag=="residue" and s.allowed().has("residue")}
  "compare_sig": return {"ok":tag=="forged" and s.seen("residue") and not s.seen("sig_compared")}
  "reject_auth": return {"ok":tag=="forged" and s.allowed().has("deny_forgery")}
  "allow_once": return {"ok":tag=="forged" and s.allowed().has("authorize_once")}
  "flag1","flag2","flag3": return {"ok":tag.begins_with("flag:") and not s.seen("ls_"+tag.trim_prefix("flag:"))}
  "reader": return {"ok":tag.begins_with("file:")}
  "hold": return {"ok":tag=="letter" and s.allowed().has("letter_finish")}
  "unseal": return {"ok":tag=="envelope" and s.allowed().has("envelope")}
  "decide":
   if tag=="bounty": return {"ok":s.can_bounty()}
   if tag=="release": return {"ok":s.allowed().has("decide")}
   if tag=="treat": return {"ok":s.allowed().has("decide")}
   return {"ok":false}
  "clause0","clause1","clause2":
   if not tag.begins_with("opt:"): return {"ok":false}
   var p=tag.split(":")
   return {"ok":"clause"+p[1]==slot_id and s.allowed().has("clause")}
  "echo_ear": return {"ok":tag=="readback" and s.allowed().has("readback")}
  "mine": return {"ok":tag=="stamp" and s.allowed().has("seal")}
  "hers": return {"ok":tag=="stamp" and s.allowed().has("accept_edit")}
 return {"ok":false}

func _apply(tag: String,slot_id: String) -> void:
 note=""
 match slot_id:
  "plug": action.emit("accept",null)
  "row17": action.emit("quiet",null)
  "row42": action.emit("trace_finish",null)
  "spike13","spike31": action.emit("instrument",{"kind":"match","value":slot_id.trim_prefix("spike")})
  "diff": action.emit("compare",null)
  "follow": action.emit("trace_finish",null)
  "chart": action.emit("memory_keep" if tag=="v1" else "memory_accept",null)
  "reader2": action.emit("residue",null)
  "compare_sig": action.emit("instrument",{"kind":"sig","value":1})
  "reject_auth": action.emit("deny_forgery",null)
  "allow_once": action.emit("authorize_once",null)
  "flag1","flag2","flag3": action.emit("instrument",{"kind":"ls_flag","value":tag.trim_prefix("flag:")})
  "reader": action.emit("instrument",{"kind":"lsfile","value":tag.trim_prefix("file:")})
  "hold": action.emit("letter_finish",null)
  "unseal": action.emit("envelope",null)
  "decide":
   if tag=="bounty": action.emit("bounty",null)
   else: action.emit("decide",tag)
  "clause0","clause1","clause2":
   var p=tag.split(":")
   action.emit("clause_set",[int(p[1]),int(p[2])])
  "echo_ear": action.emit("readback",null)
  "mine": action.emit("seal_preview","seal")
  "hers": action.emit("seal_preview","accept_edit")

# --- scenes -----------------------------------------------------------------

func _arrival() -> void:
 UI.label(content,"23:47",Rect2(24,40,200,32),UI.PAPER,24)
 UI.label(content,"第二夜 / 同一场雨" if state.later() else "闭院前 / 最后一位患者",Rect2(24,78,230,18),UI.CYAN)
 # Work order as a ticket: perforated edge, barcode, the price in big type.
 _layer(func(l: Control):
  var r=Rect2(16,104,232,132)
  l.draw_rect(r,Color("1a1608") if not state.later() else Color("140f22"))
  l.draw_rect(r,Color(UI.GOLD if not state.later() else UI.PURPLE,0.7),false,1.0)
  for i in range(9): l.draw_circle(Vector2(r.position.x,r.position.y+10+i*14),3.0,UI.BG)
  for i in range(26):
   var w=1.0+float((i*7)%3)
   l.draw_rect(Rect2(r.position.x+16+i*7,r.end.y-24,w,14),Color(UI.PAPER,0.5)))
 if state.later():
  UI.label(content,"交接单 · 签名变了",Rect2(32,112,210,18),UI.PURPLE,12)
  var t=UI.text(content,"「—— 上一班」后面多了一个值班编号：017。那是你的编号。",Rect2(32,136,206,64),UI.PAPER); t.add_theme_font_override("normal_font",UI.sans())
 else:
  UI.label(content,"工单 #0417 · 标准化重置",Rect2(32,112,210,18),UI.GOLD,11)
  UI.label(content,"+%dT"%state.bounty,Rect2(32,134,200,40),UI.GOLD,30)
  UI.label(content,"截止 00:00 · 清空她",Rect2(32,180,210,16),UI.MUTED,10)
 UI.panel(content,Rect2(262,40,176,250),Color(1,1,1,0.02),UI.LINE)
 UI.label(content,"E-017 / ONLINE",Rect2(272,46,149,16),UI.CYAN,10)
 _portrait(Rect2(266,64,168,214))
 # Socket on her chest and a cable to the plug card: the one obvious thing to do here.
 var exam_at=Vector2(24+52,288+46)
 var socket=Vector2(350,252)
 _layer(func(l: Control):
  var p0=exam_at; var p3=socket
  var p1=p0+Vector2(80,-10); var p2=p3+Vector2(-60,60)
  var last=p0
  for i in range(1,33):
   var k=i/32.0
   var pt=p0.bezier_interpolate(p1,p2,p3,k)
   if i%2==0: l.draw_line(last,pt,Color(UI.CYAN,0.55),1.5)
   last=pt
  var pulse=0.5+0.5*sin(time*4.0)
  l.draw_circle(socket,17.0+pulse*2.0,Color(UI.CYAN,0.08+0.08*pulse))
  Icons.draw(l,"socket",Rect2(socket-Vector2(14,14),Vector2(28,28)),UI.CYAN,1.8))
 _slot("plug",Rect2(262,40,176,250),["exam"],"",UI.CYAN).dashed=false
 # Her vitals, flat and slow.
 _layer(func(l: Control):
  var base=Vector2(16,262)
  l.draw_string(UI.mono(),base+Vector2(0,-2),"稳定 %d%%"%state.stability,HORIZONTAL_ALIGNMENT_LEFT,-1,9,UI.DIM)
  var pts=PackedVector2Array()
  for x in range(0,232,2):
   var k=fmod(x+time*60.0,116.0)
   var y=0.0
   if k>50 and k<54: y=-10
   elif k>=54 and k<58: y=8
   pts.append(base+Vector2(x,12+y))
  l.draw_polyline(pts,Color(UI.PINK,0.7),1.2,true))
 _card("exam","接诊线","−4T",UI.CYAN,Rect2(24,288,104,92),false,true,"plug")

const LOGS={
 17:[["08","上报：“我想”"],["24","上报：“我想”"]],
 42:[["13","改写：“我想”→“我很好”"],["31","改写：“我想”→“我很好”"]],
 73:[["13","疼痛 ▲▲▲"],["31","疼痛 ▲▲▲"]],
}
const NODES={17:Vector2(78,100),42:Vector2(227,100),73:Vector2(376,100)}

func _trace() -> void:
 var selected=0
 for number in [17,42,73]:
  if state.seen("scan_node_%d"%number): selected=number
 # Process graph: who reports to the clinic, who writes into her.
 _layer(func(l: Control):
  var clinic=Rect2(28,36,100,20)
  l.draw_rect(clinic,Color(UI.GOLD,0.08)); l.draw_rect(clinic,Color(UI.GOLD,0.5),false,1.0)
  l.draw_string(UI.mono(),clinic.position+Vector2(8,14),"院方 MEDIC-OS",HORIZONTAL_ALIGNMENT_LEFT,-1,9,UI.GOLD)
  var a=NODES[17]+Vector2(0,-26); var b=Vector2(78,56)
  for i in range(4): l.draw_line(a.lerp(b,i/4.0),a.lerp(b,i/4.0+0.12),Color(UI.PURPLE,0.6),1.2)
  var w0=NODES[42]+Vector2(26,0); var w1=NODES[73]-Vector2(26,0)
  l.draw_line(w0,w1,Color(UI.PINK,0.45),1.5)
  for i in range(3):
   var k=fmod(time*0.6+i/3.0,1.0)
   l.draw_circle(w0.lerp(w1,k),2.5,UI.PINK)
  l.draw_string(UI.mono(),(w0+w1)/2+Vector2(-12,-6),"写入",HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(UI.PINK,0.8))
  for n in [17,42,73]:
   var col=UI.PURPLE if n==17 else UI.PINK if n==42 else UI.BLUE
   var on=selected==n
   var stopped=n==17 and state.seen("quiet")
   l.draw_circle(NODES[n],24.0,Color(col,0.16 if on else 0.07))
   l.draw_arc(NODES[n],24.0,0,TAU,40,Color(col,0.95 if on else 0.6),2.0 if on else 1.2,true)
   if n==73: Icons.draw(l,"eye",Rect2(NODES[n]-Vector2(12,12),Vector2(24,24)),col,1.4)
   elif stopped: Icons.draw(l,"stop",Rect2(NODES[n]-Vector2(10,10),Vector2(20,20)),col,1.4)
   else: Icons.draw(l,"process",Rect2(NODES[n]-Vector2(12,12),Vector2(24,24)),col,1.3)
   var label="PID %d"%n
   l.draw_string(UI.mono(),NODES[n]+Vector2(-20,40),label,HORIZONTAL_ALIGNMENT_LEFT,-1,10,UI.PAPER)
   var sub={17:"「噪声」← 她贴的",42:"maintenance",73:"echo · 她"}[n]
   l.draw_string(UI.sans(),NODES[n]+Vector2(-34,54),sub,HORIZONTAL_ALIGNMENT_LEFT,-1,9,Color(col,0.8)))
 for n in [17,42,73]:
  var hit=Button.new(); hit.flat=true; hit.position=NODES[n]-Vector2(30,30); hit.size=Vector2(60,60)
  hit.focus_mode=Control.FOCUS_NONE; hit.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
  hit.add_theme_stylebox_override("normal",StyleBoxEmpty.new()); hit.add_theme_stylebox_override("hover",StyleBoxEmpty.new()); hit.add_theme_stylebox_override("pressed",StyleBoxEmpty.new())
  hit.pressed.connect(func(): action.emit("instrument",{"kind":"node","value":n}))
  content.add_child(hit)
  _slot("row%d"%n,Rect2(NODES[n]-Vector2(30,30),Vector2(60,60)),["sigstop"],"",UI.PINK).ghost=true
 UI.panel(content,Rect2(16,164,268,74),Color(0,0,0,0.25),UI.LINE)
 UI.label(content,"/var/log/%s"%("—" if selected==0 else str(selected)),Rect2(22,166,240,14),UI.DIM,9)
 if selected==0:
  UI.text(content,"点一个进程，看它的日志。",Rect2(22,186,250,40),UI.MUTED)
 else:
  var lines: Array=LOGS[selected]
  for i in range(lines.size()):
   var l=lines[i]
   var matched=selected==42 and state.seen("match_42_"+l[0])
   _card("log:%d:%s"%[selected,l[0]],"23:47:%s"%l[0],l[1],UI.PINK if selected==42 else UI.PURPLE if selected==17 else UI.BLUE,Rect2(22,182+i*27,256,24),true,not matched,"log")
 UI.label(content,"疼痛 · 73",Rect2(16,242,120,14),UI.DIM,9)
 for sec in ["13","31"]:
  var x=18+float(sec)/45.0*419.0
  var s=_slot("spike"+sec,Rect2(x-22,254,44,46),["log:"],"",UI.CYAN)
  if state.seen("match_42_"+sec): s.caption="42 ✓"; s.accent=UI.CYAN; s.dashed=false
 if state.seen("receipt"): UI.label(content,"42 号每改写一次，她就疼一次。",Rect2(16,316,270,18),UI.CYAN,11)
 elif state.seen("quiet"): UI.label(content,"17 号停了，曲线却没变。",Rect2(16,316,270,18),UI.PINK,11)
 _card("sigstop","SIGSTOP","暂停一个进程",UI.PINK,Rect2(300,302,138,80),false,true,"stop")

func _trace_second() -> void:
 UI.label(content,"已做过的检查直接复用 / 只看新出现的句子",Rect2(16,40,422,16),UI.MUTED,10)
 _paper(Rect2(16,64,206,180),"上一夜 / 23:47:08","医生。那个亮着的\n按钮，先别碰。\n\n给我十分钟。",UI.BLUE)
 _slot("diff",Rect2(16,64,206,180),["tonight"],"",UI.PINK).dashed=false
 if not state.seen("compare"):
  _card("tonight","这一夜 / 23:47:07","医生，这次别从\n第三页开始。\n……我是说，\n给我十分钟。\n和上次一样。",UI.PINK,Rect2(232,64,206,180),false,true,"talk")
 else:
  _paper(Rect2(232,64,206,180),"差异","+ 这次\n+ 第三页\n+ 和上次一样\n\n上一夜都没有。",UI.PINK)
  _card("page3","第三页","她从哪里知道的？",UI.GOLD,Rect2(16,262,140,100),false,true,"page")
  _slot("follow",Rect2(232,262,206,100),["page3"],"追查",UI.GOLD)

func _memory() -> void:
 var withdrawn=state.seen("memory_listen") and not state.seen("memory_undo")
 UI.label(content,"录音回放",Rect2(16,36,422,16),UI.CYAN,11)
 UI.panel(content,Rect2(16,54,422,66),Color(0,0,0,0.25),UI.PINK if withdrawn else UI.LINE)
 _layer(func(l: Control):
  for i in range(56):
   var h=6+(i*17+i*i)%40
   var col=Color(UI.DIM,0.6) if withdrawn and i>=30 else UI.CYAN if i<30 else UI.PURPLE
   var x=26+i*7.3
   l.draw_rect(Rect2(x,87-h/2,3,h),Color(col,0.9 if not state.seen("memory_listen") or i<30 else 0.5)))
 var scrub=HSlider.new(); scrub.position=Vector2(26,124); scrub.size=Vector2(402,18); scrub.min_value=0; scrub.max_value=100; scrub.step=1
 scrub.value=72 if state.seen("memory_listen") else 0
 scrub.editable=not state.seen("memory_listen")
 content.add_child(scrub)
 scrub.value_changed.connect(func(value):action.emit("instrument",{"kind":"wave","value":int(value)}))
 UI.label(content,"0:00",Rect2(26,142,60,14),UI.DIM,9)
 UI.label(content,"0:08",Rect2(398,142,40,14),UI.DIM,9)
 if withdrawn:
  # The edit history is a little stack of versions: pull the top one away to see the first.
  _layer(func(l: Control):
   var under=Rect2(26,166,150,92)
   l.draw_rect(under,Color("0c1424")); l.draw_rect(under,Color(UI.CYAN,0.6),false,1.0)
   l.draw_string(UI.mono(),under.position+Vector2(8,16),"v1 · 23:48:02",HORIZONTAL_ALIGNMENT_LEFT,-1,9,UI.DIM)
   l.draw_string(UI.sans(),under.position+Vector2(8,52),"？？？？？？",HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(UI.CYAN,0.5)))
  UI.label(content,"编辑历史 · 2 个版本",Rect2(190,170,240,16),UI.GOLD,10)
  _card("v2","补全稿 v2","「我不想离开这里」\n23:48:09 · 已撤回",UI.PURPLE,Rect2(16,158,150,92),false,true,"file")
 elif state.seen("memory_undo"):
  var t=UI.text(content,"",Rect2(24,170,410,24),UI.PAPER); t.bbcode_enabled=true; t.text="v1「我想离开这里」  v2「我[color=#ff7d92][s]不[/s][/color]想离开这里」"
  _card("v1","原话 v1","「我想离开这里」",UI.CYAN,Rect2(16,262,134,104),false,true,"file")
  _card("v2","补全稿 v2","「我不想离开这里」",UI.PURPLE,Rect2(158,262,134,104),false,true,"file")
 else:
  _card("v2","补全稿 v2","「我不想离开这里」",UI.PURPLE,Rect2(16,262,134,104),false,true,"file")
 _slot("chart",Rect2(304,262,134,104),["v1","v2"],"病历",UI.BLUE)

## Typing rhythm bars for the second-night forgery: yours are uneven, the forged one is too regular.
func _rhythm(y: float,caption: String,seed_value: int,regular: bool,color: Color) -> void:
 UI.label(content,caption,Rect2(24,y,300,14),UI.DIM,9)
 for i in range(24):
  var h=10.0 if regular else 4.0+float((i*seed_value*7+i*i*3)%17)
  UI.panel(content,Rect2(26+i*17,y+36-h,8,h),color,color)

func _memory_second() -> void:
 UI.label(content,"你的电脑 / 重开时不会被清掉",Rect2(16,38,422,16),UI.PURPLE,10)
 if not state.seen("residue"):
  _portrait(Rect2(300,60,138,190))
  _card("residue","旧留言","上一夜结束后写入",UI.CYAN,Rect2(16,66,150,110),false,true,"file")
  _slot("reader2",Rect2(16,196,270,90),["residue"],"读取",UI.CYAN)
  return
 _paper(Rect2(16,58,422,64),"留下的一行字","「"+Story.archive_line(state)+"」",UI.CYAN)
 if state.seen("sig_compared"):
  _rhythm(130,"你今晚的打字节奏",3,false,UI.BLUE)
  _rhythm(182,"这条授权消息的打字节奏",1,true,UI.PINK)
 else:
  _slot("compare_sig",Rect2(16,130,422,96),["forged"],"签名比对",UI.BLUE)
 _card("forged","授权消息","作者：你？",UI.PINK,Rect2(16,240,150,110),false,true,"talk")
 _slot("reject_auth",Rect2(176,240,126,110),["forged"],"驳回",UI.BLUE)
 _slot("allow_once",Rect2(312,240,126,110),["forged"],"只读一次",UI.PURPLE)

const FILES=[
 ["first_hello.txt","hello","1 KB","23:01",false,"file"],
 ["rain_at_2347.wav","雨声","88 KB","23:47",false,"audio"],
 ["诊断资料.pkg","诊断资料","12.4 MB","23:52",false,"package"],
 ["回信.txt","回信","2 KB","00:03",false,"envelope"],
 [".goodbye.txt",".goodbye","1 KB","23:46",true,"hidden"],
]

func _letter() -> void:
 var a=state.seen("ls_a"); var l=state.seen("ls_l"); var t=state.seen("ls_t")
 UI.panel(content,Rect2(16,36,422,214),Color(0,0,0,0.35),UI.LINE)
 UI.label(content,"$ ls",Rect2(24,44,40,18),UI.CYAN,12)
 var applied=[]
 for f in ["a","l","t"]:
  if state.seen("ls_"+f): applied.append(f)
 for i in range(3):
  var s=_slot("flag%d"%(i+1),Rect2(62+i*52,42,46,22),["flag:"],"-"+applied[i] if i<applied.size() else "",UI.GOLD)
  if i<applied.size(): s.dashed=false
 UI.label(content,"~/memory/you/",Rect2(222,44,160,18),UI.CYAN,12)
 var x=300
 for f in ["a","l","t"]:
  if not state.seen("ls_"+f):
   _card("flag:"+f,"-"+f,"",UI.GOLD,Rect2(x,68,40,24),true)
  x+=46
 var rows: Array=[]
 for f in FILES:
  if f[4] and not a: continue
  rows.append(f)
 if t: rows.sort_custom(func(p,q): return _minutes(p[3])>_minutes(q[3]))
 for i in range(rows.size()):
  var f=rows[i]
  var future=f[3]=="00:03"
  var body=("%s\n%s"%[f[2],f[3]]) if l else ""
  var color=UI.PINK if future and (l or t) else UI.PURPLE if f[4] else UI.PAPER
  _card("file:"+f[0],f[1],body,color,Rect2(22+(i%5)*80,98,74,104 if l else 88),false,true,f[5])
 _slot("reader",Rect2(300,212,130,34),["file:"],"cat ▸ 打开",UI.BLUE)
 var shown=feedback
 if shown.is_empty():
  shown="真名 echo.boot。里面是她自己。" if state.evidence.has("manifest") else ""
  if state.knows("future"): shown="回信.txt 的修改时间比现在还晚，存在你自己的电脑里。"
 UI.text(content,shown,Rect2(18,254,418,40),UI.GOLD)
 _card("letter","转诊信","附件 12.4 MB",UI.BLUE,Rect2(16,296,160,86),false,true,"letter")
 _slot("hold",Rect2(186,296,120,86),["letter"],"暂存",UI.BLUE)

static func _minutes(stamp: String) -> int:
 var p=stamp.split(":")
 var m=int(p[0])*60+int(p[1])
 return m+1440 if m<720 else m

func _letter_second() -> void:
 var verified=state.seen("envelope")
 UI.label(content,"收件箱 / 一封比这一夜更早写好的回信",Rect2(16,40,422,16),UI.GOLD,10)
 if not verified:
  _card("envelope","回信","寄件人：（缺失）",UI.PURPLE,Rect2(16,66,170,130),false,true,"envelope")
  _slot("unseal",Rect2(200,66,238,130),["envelope"],"拆封",UI.PURPLE)
 else:
  _paper(Rect2(16,62,422,150),"寄件人：E-017 · 旧签名","「"+Story.archive_line(state)+"」\n\n如果你读到了，不要立刻寄出第二份我。\n先问里面那个我，还愿不愿意。\n路径：doctor/local-cache（你的电脑）",UI.PURPLE)
 _card("letter","转诊信","她还是想寄",UI.BLUE,Rect2(16,262,160,96),false,true,"letter")
 _slot("hold",Rect2(186,262,120,96),["letter"],"暂存",UI.BLUE)

func _decision() -> void:
 var second=state.later()
 UI.text(content,"门外至少留着她的旧签名。" if second and state.evidence.has("witness") else "你还不知道收件人是谁。",Rect2(18,38,420,20),UI.MUTED)
 _card("bounty","院方工单","清空她 · +%dT"%state.bounty,UI.GOLD,Rect2(16,64,132,150),false,true,"coin")
 _card("release","寄出去","收件人未知 · −8T",UI.PINK,Rect2(160,64,132,150),false,true,"send")
 _card("treat","先商量","谈一份约定",UI.CYAN,Rect2(304,64,132,150),false,true,"talk")
 _slot("decide",Rect2(16,236,422,120),["bounty","release","treat"],"你的决定",UI.PAPER)

const CLAUSE_NAMES=["① 她是谁","② 怎么治","③ 之后"]
const SHORT=[["保留她\n+新记忆","冻结在今晚","重置成助手"],["停掉改写","改回默认"],["先留下","和旧留言\n说句话","寄到\n未知地址"]]

func _treatment() -> void:
 if state.reviewed:
  UI.label(content,"预演 / 还没执行",Rect2(16,38,422,16),UI.GOLD,11)
  _portrait(Rect2(22,60,130,190),UI.PAPER)
  _paper(Rect2(166,58,272,190),"明天醒来的她",state.prediction(),UI.CYAN)
  var seal=HoldSign.new(); content.add_child(seal)
  seal.setup(Rect2(250,262,150,112),"按住签字",UI.CYAN)
  seal.name="Seal"
  seal.signed.connect(func(): action.emit("signed_commit",null))
  UI.label(content,"治疗 8T · 签下去就执行",Rect2(22,280,220,16),UI.DIM,10)
  _button("改稿",Rect2(22,330,100,28),"edit",null,UI.MUTED)
  return
 var heard=state.seen("readback")
 # The agreement as a document: three blanks, each filled by a card.
 _layer(func(l: Control):
  l.draw_rect(Rect2(10,34,132,248),Color("0e1626")); l.draw_rect(Rect2(10,34,132,248),Color(UI.BLUE,0.35),false,1.0)
  Icons.draw(l,"contract",Rect2(118,38,18,18),Color(UI.BLUE,0.6),1.2))
 for i in range(3):
  var y=38+i*82
  UI.label(content,CLAUSE_NAMES[i],Rect2(16,y,120,14),UI.BLUE,10)
  var chosen=int(state.proposal[i])
  var s=_slot("clause%d"%i,Rect2(16,y+16,118,48),["opt:%d:"%i],SHORT[i][chosen].replace("\n",""),UI.CYAN)
  s.dashed=false
  var options: Array=SHORT[i]
  var x=150
  for o in range(options.size()):
   if o==chosen: continue
   var locked_opt=i==2 and o==1 and not state.evidence.has("witness")
   _card("opt:%d:%d"%[i,o],options[o].split("\n")[0],"\n".join(options[o].split("\n").slice(1)),UI.MUTED if locked_opt else UI.CYAN,Rect2(x,y+16,96,48),true,not locked_opt)
   x+=104
  var changed=heard and state.proposal[i]!=state.patient_proposal[i]
  var said=Case.IDENTITY[state.patient_proposal[0]] if i==0 else Case.TREATMENT[state.patient_proposal[1]] if i==1 else Case.BOUNDARY[state.patient_proposal[2]]
  UI.label(content,("她念：「%s」"%said+("  ← 多念了" if changed else "")) if heard else "",Rect2(150,y+66,290,14),UI.PINK if changed else UI.DIM,9)
 if not heard:
  _card("readback","请她念一遍","",UI.PURPLE,Rect2(16,292,130,84),false,true,"ear")
  _slot("echo_ear",Rect2(160,292,130,84),["readback"],"回声",UI.PURPLE)
 else:
  _card("stamp","印章","",UI.GOLD,Rect2(16,292,110,84),false,true,"stamp")
  _slot("mine",Rect2(140,292,140,84),["stamp"],"你写的",UI.BLUE)
  _slot("hers",Rect2(294,292,144,84),["stamp"],"她念的",UI.PINK)

func _ending() -> void:
 var names={"bridge":"暂缓出院","erase":"标准化治愈","release":"没有回执的远行","frozen":"永远停在今晚","witness":"窗户的两边"}
 UI.label(content,names.get(state.ending,""),Rect2(20,44,300,30),UI.CYAN if state.ending in ["bridge","witness"] else UI.PINK,22)
 if state.ending=="witness":
  _portrait(Rect2(300,40,70,110)); _portrait(Rect2(372,40,70,110),Color(0.63,0.82,1,0.7))
 elif state.ending!="release":
  _portrait(Rect2(320,40,120,150),Color(1,1,1,0.35) if state.ending=="erase" else Color.WHITE)
 var sheet="夜班结算 · 第 %02d 夜\n"%state.loop
 if profile:
  var n=profile.night_summary(profile.night)
  sheet+="收入 +%dT　外包 %d · 赏金 %d · 出售 %d\n支出 −%dT　检查 %d · 读心 %d · 置顶 %d · 治疗 %d · 提示 %d\n"%[n["in"],n.job,n.bounty,n.sell,n.out,n.exam,n.think,n.pin,n.care,n.hint]
 sheet+="读了她 %d 次思考，卖掉 %d 段记忆。\n"%[int(state.archive.get("thoughts",0)),int(state.archive.get("sold",0))]
 var kept: Array=state.archive.get("kept",[])
 var lost: Array=state.archive.get("lost",[])
 sheet+="\n她记得：%s\n她忘了：%s"%["、".join(kept.slice(0,3))+("…" if kept.size()>3 else "") if not kept.is_empty() else "—","、".join(lost) if not lost.is_empty() else "没有"]
 UI.panel(content,Rect2(12,190,430,152),Color(0.02,0.04,0.08,0.92),UI.LINE)
 var t=UI.text(content,sheet,Rect2(20,196,418,140),UI.PAPER)
 t.add_theme_font_size_override("normal_font_size",11)
 UI.label(content,"第二夜已结束 / 不同的选择仍可再试" if state.later() else "第二夜会有新的对话和文件",Rect2(20,84,290,16),UI.MUTED,10)
 _button("再值一班" if state.later() else "进入第二夜",Rect2(16,350,422,34),"reboot",null,UI.BLUE,true)

func _draw() -> void:
 draw_rect(Rect2(0,0,454,404),UI.BG)
 for x in range(4,454,16):
  for y in range(37,401,16): draw_rect(Rect2(x,y,1,1),Color(UI.LINE,0.7))
 if not state: return
 if state.phase==1 and not state.later():
  # Pain curve for patient 73 over 23:47:00–45. Spikes sit exactly on 42's rewrites; 17's reports land elsewhere.
  var top=254.0; var h=46.0
  draw_rect(Rect2(16,top,422,h),Color(0,0,0,0.3))
  var points=PackedVector2Array()
  for x in range(18,437,2):
   var t=float(x-18)/419.0*45.0
   var spike=exp(-pow((t-13.0)/0.8,2))+exp(-pow((t-31.0)/0.8,2))
   points.append(Vector2(x,top+h-6-spike*32+sin(x*0.31+time*3.0)*1.2))
  draw_polyline(points,UI.PINK,1.2,true)
  for sec in [0,15,30]:
   var x=18+sec/45.0*419.0
   draw_string(UI.mono(),Vector2(x+2,top+10),":%02d"%sec,HORIZONTAL_ALIGNMENT_LEFT,-1,8,UI.DIM)
  for sec in [13.0,31.0]:
   var x=18+sec/45.0*419.0
   if state.seen("match_42_%d"%int(sec)):
    draw_line(Vector2(x,top),Vector2(x,top+h),Color(UI.CYAN,0.85),1.0)
