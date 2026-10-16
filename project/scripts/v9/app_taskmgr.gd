extends Control
## 任务管理器: act one's instrument. Select a process to read its log; log lines are cards you can
## drop on the pain curve to line up the timestamps, or drag into the chat to show her.
const UI=preload("res://scripts/v9/ui.gd")
const Card=preload("res://scripts/v9/card.gd")
const Slot=preload("res://scripts/v9/slot.gd")
const Icons=preload("res://scripts/v9/icons.gd")
const LOGS={
 17:[["08","上报：患者说“我想”"],["24","上报：患者说“我想”"]],
 42:[["13","改写：“我想”→“我很好”"],["31","改写：“我想”→“我很好”"]],
 73:[["13","疼痛 ▲▲▲"],["31","疼痛 ▲▲▲"]],
}
const ROWS=[[17,"noise","噪声（她贴的标签）",UI.PURPLE],[42,"maintenance","维护",UI.PINK],[73,"echo","患者 E-017",UI.BLUE]]
var host
var state
var time: float=0.0
var cards: Array=[]
var graph: Control

func setup(main) -> void:
 host=main; state=main.state
 size=get_parent().size
 var sel=selected()
 UI.label(self,"进程",Rect2(6,4,120,14),UI.MUTED)
 # Table header and rows, sunken like an old list view.
 var well=Panel.new(); well.position=Vector2(4,20); well.size=Vector2(size.x-8,88); well.add_theme_stylebox_override("panel",UI.bevel(UI.FACE_LO,true)); well.mouse_filter=MOUSE_FILTER_IGNORE; add_child(well)
 UI.label(self,"PID   名称          描述                CPU",Rect2(10,24,size.x-20,14),UI.DIM)
 for i in range(3):
  var r=ROWS[i]
  var b=Button.new(); b.position=Vector2(8,40+i*22); b.size=Vector2(size.x-16,20); b.focus_mode=Control.FOCUS_NONE
  b.add_theme_stylebox_override("normal",UI.style(UI.TITLE_B if sel==r[0] else Color(0,0,0,0),Color(0,0,0,0),0))
  b.add_theme_stylebox_override("hover",UI.style(Color(UI.TITLE_B,0.5),Color(0,0,0,0),0))
  b.add_theme_stylebox_override("pressed",UI.style(UI.TITLE_B,Color(0,0,0,0),0))
  b.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  var n=int(r[0])
  b.pressed.connect(func(): host._act("instrument",{"kind":"node","value":n}))
  b.tooltip_text="右键：更多操作"
  var desc=str(r[2])
  b.gui_input.connect(func(e):
   if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_RIGHT and e.pressed:
    # Menu actions are bound to main: this window is rebuilt when the selection changes.
    host.desktop.popup_menu(e.global_position,[
     ["查看日志",host._act.bind("instrument",{"kind":"node","value":n})],
     ["结束进程",host.end_process.bind(n),state.phase==1 and not state.later()],
     ["—"],
     ["属性",host.desktop.toast.bind("PID %d · %s"%[n,desc],UI.MUTED)],
    ]))
  add_child(b)
  var stopped=n==17 and state.seen("quiet") or n==42 and state.seen("trace_finish")
  var row=UI.label(self,"%-5d %-13s %s"%[n,r[1],r[2]+("  [已暂停]" if stopped else "")],Rect2(12,43+i*22,size.x-80,14),r[3] if sel!=n else UI.PAPER)
  row.name="Row%d"%n
  var cpu=UI.label(self,"",Rect2(size.x-52,43+i*22,44,14),UI.PAPER)
  cpu.set_meta("pid",n)
 # Log pane.
 var logs=Panel.new(); logs.position=Vector2(4,112); logs.size=Vector2(size.x-8,74); logs.add_theme_stylebox_override("panel",UI.bevel(UI.FACE_LO,true)); logs.mouse_filter=MOUSE_FILTER_IGNORE; add_child(logs)
 if sel==0:
  UI.label(self,"选中一个进程，查看它的日志。",Rect2(12,140,size.x-24,14),UI.DIM)
 else:
  UI.label(self,"/var/log/%d"%sel,Rect2(10,114,200,14),UI.DIM)
  var lines: Array=LOGS[sel]
  for i in range(lines.size()):
   var l=lines[i]
   var c=Card.new(); c.reduced=host.reduced_motion or host.self_testing; c.icon="log"
   add_child(c)
   c.setup("log:%d:%s"%[sel,l[0]],"23:47:%s"%l[0],l[1],r_color(sel),Rect2(10,130+i*27,size.x-20,24),true)
   c.dropped.connect(host._evidence_dropped)
   cards.append(c)
 # Pain curve of patient 73, with the two spikes as drop targets.
 UI.label(self,"疼痛 · PID 73",Rect2(6,190,200,14),UI.MUTED)
 graph=Control.new(); graph.position=Vector2(4,206); graph.size=Vector2(size.x-8,58); graph.mouse_filter=MOUSE_FILTER_IGNORE; add_child(graph)
 graph.draw.connect(_draw_graph)
 for sec in [13,31]:
  var x=4+_x_of(sec)
  var s=Slot.new(); add_child(s)
  s.setup("spike%d"%sec,Rect2(x-20,206,40,58),["log:"],"42 ✓" if state.seen("match_42_%d"%sec) else "",UI.CYAN)
  s.ghost=not state.seen("match_42_%d"%sec)
 var verdict=""
 if state.seen("receipt"): verdict="42 号每改写一次，她就疼一次。"
 elif state.seen("quiet"): verdict="17 号停了，疼痛曲线没有变化。"
 UI.label(self,verdict,Rect2(6,270,size.x-120,14),UI.CYAN if state.seen("receipt") else UI.PINK)
 var end=UI.button(self,"结束进程",Rect2(size.x-110,268,104,22),func(): host.end_process(selected()),UI.PINK)
 end.disabled=sel==0 or state.phase!=1 or state.later()

static func r_color(pid: int) -> Color:
 return UI.PURPLE if pid==17 else UI.PINK if pid==42 else UI.BLUE

func selected() -> int:
 for n in [17,42,73]:
  if state.seen("scan_node_%d"%n): return n
 return 0

func _x_of(sec: float) -> float:
 return 6+sec/45.0*(size.x-20)

func _process(delta: float) -> void:
 time+=delta
 # Live CPU: 42 jumps exactly when her pain spikes.
 var t=fmod(time*3.0,45.0)
 for c in get_children():
  if c is Label and c.has_meta("pid"):
   var pid=int(c.get_meta("pid"))
   var v=2+int(sin(time*3.0+pid)*2+2)
   if pid==42 and not state.seen("trace_finish") and (absf(t-13)<1.2 or absf(t-31)<1.2): v=97
   if pid==73 and (absf(t-13)<1.2 or absf(t-31)<1.2) and not state.seen("trace_finish"): v=64
   if pid==17 and state.seen("quiet"): v=0
   c.text="%3d%%"%v
 if is_instance_valid(graph): graph.queue_redraw()

func _draw_graph() -> void:
 var w=graph.size.x; var h=graph.size.y
 graph.draw_style_box(UI.bevel(UI.FACE_LO,true),Rect2(Vector2.ZERO,graph.size))
 for gx in range(0,int(w),16): graph.draw_line(Vector2(gx,2),Vector2(gx,h-2),Color(UI.LINE,0.5),1.0)
 var pts=PackedVector2Array()
 for x in range(2,int(w)-2,2):
  var sec=float(x-2)/(w-20)*45.0
  var spike=0.0 if state.seen("trace_finish") else exp(-pow((sec-13.0)/0.8,2))+exp(-pow((sec-31.0)/0.8,2))
  pts.append(Vector2(x,h-8-spike*(h-18)+sin(x*0.4+time*4.0)))
 graph.draw_polyline(pts,UI.PINK,1.0)
 for sec in [0,15,30,45]:
  graph.draw_string(UI.mono(),Vector2(_x_of(sec)-6,12),":%02d"%sec,HORIZONTAL_ALIGNMENT_LEFT,-1,12,UI.DIM)
 for sec in [13,31]:
  if state.seen("match_42_%d"%sec): graph.draw_line(Vector2(_x_of(sec),2),Vector2(_x_of(sec),h-2),UI.CYAN,1.0)
