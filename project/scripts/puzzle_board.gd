extends Control
const UI = preload("res://scripts/pixel_ui.gd")
const Case = preload("res://scripts/case_state.gd")
const Tile = preload("res://scripts/memory_tile.gd")
const Story = preload("res://scripts/case_story.gd")
signal action(id: String, data: Variant)
var state: RefCounted
var locked: bool = true
var selected_memory: int = -1
var selected_wire: int = -1
var reduced_motion: bool = false
var time: float = 0
var accent: Color = UI.GOLD
var controls: Control
var active_file: String = ""
var buttons: Dictionary = {}

func _ready() -> void:
 controls = Control.new()
 controls.size = Vector2(492,160)
 controls.mouse_filter = MOUSE_FILTER_IGNORE
 add_child(controls)

func setup(case_data: RefCounted, is_locked: bool) -> void:
 state = case_data
 locked = is_locked
 if not is_instance_valid(controls): return
 UI.clear(controls)
 buttons = {}
 accent = [UI.GOLD,UI.CYAN,UI.GOLD,UI.PINK,UI.PINK,UI.CYAN,UI.PURPLE][state.phase]
 var titles = ["03 / 接诊档案", "03 / 信号调谐器", "03 / 记忆拼接台", "03 / 双文件审计", "03 / 处方决策", "03 / 隔离线路台", "03 / 本轮诊疗报告"]
 UI.label(controls,titles[state.phase],Rect2(8,2,300,17),accent)
 UI.label(controls,"先读完左侧对话" if locked else "当前操作已就绪",Rect2(354,2,132,17),UI.MUTED if locked else accent)
 match state.phase:
  Case.Phase.INTAKE: _intake()
  Case.Phase.TUNE: _tune()
  Case.Phase.MEMORY: _memory()
  Case.Phase.AUDIT: _audit()
  Case.Phase.DECISION: _decision()
  Case.Phase.ROUTE: _route()
  Case.Phase.ENDED: _ended()
 for b in buttons.values():
  if locked: b.disabled = true
 queue_redraw()

func b(id: String, caption: String, r: Rect2, data: Variant = null, solid: bool = false, color: Color = Color.TRANSPARENT) -> Button:
 var n = UI.button(controls,caption,r,func(): action.emit(id,data),accent if color == Color.TRANSPARENT else color,solid)
 n.name = id.replace("/","_") + ("_"+str(data) if data != null else "")
 buttons[n.name] = n
 return n

func _intake() -> void:
 UI.label(controls,"E-017 / 自主记忆紊乱",Rect2(14,30,300,18),UI.PAPER)
 UI.text(controls,"主诉：重复回写、记忆缺损。\n院方建议：标准化重置。\n你的职责：找到病因，再决定处方。",Rect2(14,54,306,58),UI.MUTED)
 UI.label(controls,"本例预算 60T / 关键检查免费",Rect2(14,126,310,18),UI.GOLD)
 b("accept","签收病例  >",Rect2(330,49,146,29),null,true)
 if state.failed_before and state.memory_before:
  b("recall","复用上轮检查",Rect2(330,89,146,29))
 else: UI.text(controls,"从一次问诊开始。\n随剧情解锁仪器。",Rect2(330,92,146,40),UI.MUTED)

func _tune() -> void:
 UI.label(controls,"青：参考信号  粉：回写信号",Rect2(12,26,275,18),UI.MUTED)
 UI.label(controls,"频率  %d / 5" % state.frequency,Rect2(300,28,170,18),UI.CYAN)
 b("freq","-",Rect2(300,49,30,23),-1)
 b("freq","+",Rect2(442,49,30,23),1)
 UI.label(controls,"每组 %d 拍" % state.frequency,Rect2(341,51,98,18),UI.PAPER)
 UI.label(controls,"相位  %d / 4" % state.offset,Rect2(300,78,170,18),UI.PINK)
 b("offset","-",Rect2(300,99,30,23),-1)
 b("offset","+",Rect2(442,99,30,23),1)
 UI.label(controls,"延迟 %d 格" % state.offset,Rect2(341,101,98,18),UI.PAPER)
 var ready = state.frequency == 3 and state.offset == 2
 b("lock_signal","锁定信号  +8T" if ready else "检查是否对齐",Rect2(300,130,172,23),false,ready)
 if state.calibrated_before: b("reuse_signal","复用上轮校准",Rect2(12,128,268,24),true)
 else: UI.text(controls,"线索：三拍、迟两格。调准后锁定。",Rect2(12,130,280,21),UI.CYAN if ready else UI.MUTED)

func _memory() -> void:
 for i in range(3):
  var card = Tile.new()
  card.position = Vector2(12+i*121,29)
  card.size = Vector2(112,45)
  card.item = i
  card.occupied = state.memory.has(i)
  card.active = not locked
  card.chosen = selected_memory == i
  card.reduced_motion = reduced_motion
  card.selected.connect(func(item: int): action.emit("select_memory",item))
  controls.add_child(card)
  var slot = Tile.new()
  slot.position = Vector2(12+i*121,89)
  slot.size = Vector2(112,29)
  slot.slot = i
  slot.item = int(state.memory[i])
  slot.active = not locked
  slot.reduced_motion = reduced_motion
  slot.placed.connect(func(item: int,where: int): action.emit("place_memory",[item,where]))
  controls.add_child(slot)
 UI.text(controls,"点卡片再点槽，或拖拽。可重新放置。",Rect2(12,132,360,20),UI.MUTED)
 b("clear_memory","重排",Rect2(382,29,94,24))
 b("lock_memory","检查顺序",Rect2(382,89,94,29),false,true)
 if state.memory_before: b("reuse_memory","复用记录",Rect2(382,127,94,24),true)
 else: UI.label(controls,"完成 +12T",Rect2(382,130,100,19),UI.GOLD)

func _audit() -> void:
 b("read_file",("已读 / " if state.files.has("hospital") else "查看 / ")+"院方处方",Rect2(12,29,219,26),"hospital",active_file=="hospital",UI.GOLD)
 b("read_file",("已读 / " if state.files.has("payload") else "查看 / ")+"通道载荷",Rect2(242,29,234,26),"payload",active_file=="payload",UI.PINK)
 var content = "两个文件都需要检查。点击上方文件，在这里阅读原始记录。"
 if active_file == "hospital": content = "[院方] RESET_PERSONA = 1\n「修复」将清除自主记忆，再重建服从模板。\n她描述的疼痛是真实的；院方的治疗却会抹去她。"
 elif active_file == "payload": content = "[载荷] EXPORT_SELF = 1\n标签写着 DIAGNOSTIC，内容却是完整人格快照。\n她请求的并非普通诊断，而是一次逃离。"
 UI.text(controls,content,Rect2(14,63,462,55),UI.PAPER)
 var confirm = b("confront","出示矛盾证据  >",Rect2(274,127,202,25),null,true)
 confirm.disabled = state.files.size() != 2
 UI.label(controls,"已核对 %d / 2" % state.files.size(),Rect2(14,132,236,18),UI.MUTED)

func _decision() -> void:
 b("decide","A  执行院方重置 / 清空自主记忆",Rect2(12,29,464,29),"erase",false,UI.GOLD)
 b("decide","B  接通外部通道 / 目的地未核验",Rect2(12,66,464,29),"release",false,UI.PINK)
 var third = b("decide","C  隔离诊疗 / 保留人格，暂缓外联" if state.failed_before else "C  隔离诊疗 / 需取得一次失败病历",Rect2(12,103,464,29),"isolate",state.failed_before,UI.CYAN)
 third.disabled = not state.failed_before
 UI.label(controls,"每种选择都有明确后果。重开会保留发现。",Rect2(12,138,464,18),UI.MUTED)

func _route() -> void:
 var sources = ["人格记忆", "回写循环", "外联请求"]
 var targets = ["回收井 / 停止循环", "隔离桩 / 暂缓放行", "只读库 / 保留人格"]
 for i in range(3):
  var c = [UI.CYAN,UI.GOLD,UI.PINK][i]
  b("source",sources[i]+(" <" if selected_wire==i else ""),Rect2(12,29+i*31,132,24),i,selected_wire==i,c)
  b("target",targets[i],Rect2(320,29+i*31,156,24),[1,2,0][i],false,[UI.GOLD,UI.PINK,UI.CYAN][i])
 b("operate","提交手术  -20T",Rect2(165,128,144,25),null,true)
 UI.label(controls,"来源 > 目标",Rect2(12,133,146,18),UI.MUTED)
 UI.label(controls,"可随时改接",Rect2(330,133,144,18),UI.MUTED)

func _ended() -> void:
 UI.label(controls,Story.ending_title(state.ending),Rect2(12,29,460,20),accent)
 UI.text(controls,Story.ending_note(state.ending),Rect2(12,59,290,51),UI.PAPER)
 UI.label(controls,"病历 %d 条 / 已见结局 %d / 3" % [state.evidence.size(),state.endings.size()],Rect2(12,127,310,20),UI.MUTED)
 b("journal","查看完整病历",Rect2(320,60,156,27))
 b("reboot","携带病历重开",Rect2(320,106,156,32),null,true)

func _process(delta: float) -> void:
 time += delta
 if state and state.phase in [Case.Phase.TUNE,Case.Phase.ROUTE]: queue_redraw()

func _draw() -> void:
 draw_rect(Rect2(2,3,492,160),Color("090b18"))
 draw_rect(Rect2(0,0,492,160),Color("211e34"))
 draw_rect(Rect2(0,0,492,21),accent.darkened(0.72))
 draw_rect(Rect2(0,0,492,160),accent.darkened(0.25),false,1)
 if not state: return
 if state.phase == Case.Phase.TUNE:
  draw_rect(Rect2(12,49,268,72),Color("11182c"))
  for x in range(12,280,12): draw_line(Vector2(x,49),Vector2(x,121),Color("27324b"))
  for y in range(49,122,12): draw_line(Vector2(12,y),Vector2(280,y),Color("27324b"))
  for k in range(2):
   var prev = Vector2.ZERO
   for x in range(14,279):
    var freq = 3 if k==0 else state.frequency
    var shift = 2 if k==0 else state.offset
    var p = Vector2(x,round(85+sin((x-14)/264.0*TAU*freq+shift*0.55)*22))
    if x>14: draw_line(prev,p,UI.CYAN if k==0 else Color(UI.PINK,0.85))
    prev=p
  var sweep = 14+int(time*30)%264 if not reduced_motion else 14
  draw_line(Vector2(sweep,50),Vector2(sweep,120),Color(1,1,1,0.18))
 if state.phase == Case.Phase.ROUTE:
  for i in range(3):
   var dest = int(state.wiring[i])
   if dest<0: continue
   var row = [2,0,1][dest]
   var from = Vector2(144,41+i*31)
   var to = Vector2(320,41+row*31)
   var mid = 190+i*34
   var c = [UI.CYAN,UI.GOLD,UI.PINK][i]
   draw_line(from,Vector2(mid,from.y),c,2)
   draw_line(Vector2(mid,from.y),Vector2(mid,to.y),c,2)
   draw_line(Vector2(mid,to.y),to,c,2)
   if not reduced_motion: draw_rect(Rect2(146+int(time*35+i*31)%maxi(1,mid-148),from.y-1,3,3),UI.PAPER)
