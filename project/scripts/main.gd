extends Control
const UI = preload("res://scripts/pixel_ui.gd")
const Case = preload("res://scripts/case_state.gd")
const Story = preload("res://scripts/case_story.gd")
const Stage = preload("res://scripts/clinic_stage.gd")
const Board = preload("res://scripts/puzzle_board.gd")
const SAVE_PATH = "user://case-v2.json"
var state = Case.new()
var stage: Control
var board: Control
var objective: Label
var metrics: Label
var session_label: Label
var current_name: Label
var current_body: RichTextLabel
var next_button: Button
var input: LineEdit
var send_button: Button
var topics_label: Button
var history: VBoxContainer
var scroll: ScrollContainer
var status: Label
var journal_button: Button
var mute_button: Button
var motion_button: Button
var route_bar: Control
var modal: Control
var flash: ColorRect
var dialogue: Array = []
var dialogue_index: int = 0
var dialogue_active: bool = true
var current_line: Array = []
var history_data: Array = []
var type_time: float = 0
var typing: bool = false
var busy: bool = false
var muted: bool = false
var reduced_motion: bool = false
var self_testing: bool = false
var qa_memory: bool = false
var capture_dir: String = ""
var phase_tween: Tween
var checks: Dictionary = {}
var resume_ui: Dictionary = {}

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg == "--self-test": self_testing = true
  if arg == "--qa-memory": qa_memory = true
  if arg.begins_with("--capture-dir="): capture_dir = arg.trim_prefix("--capture-dir=")
 var th = Theme.new()
 th.default_font = UI.pixel_font()
 th.default_font_size = 12
 theme = th
 texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
 _load_preferences()
 get_window().title = "ECHO CLINIC / 夜班诊所 v0.2" + (" / 操作测试" if qa_memory else "")
 if not self_testing and not qa_memory: _load_case()
 if qa_memory:
  state.accept_case()
  state.tune(0,3); state.tune(1,2); state.lock_signal()
 _build_ui()
 if not self_testing: _start_ambience()
 if resume_ui.get("history") is Array:
  for line in resume_ui.history:
   if line is Array and line.size()==2: _history_add(line)
 else:
  _history_add(["system","23:47，离闭院还剩十三分钟。值夜医生接入了最后一个患者。"])
  _history_add(["doctor","病例 E-017。重复回写、记忆缺损。院方已经开好重置处方。"])
  _history_add(["system","接诊快照已锁定。每次重开，只有你的病历会留下。"])
 _begin_phase(not resume_ui.is_empty())
 if qa_memory: _read_all()
 if self_testing: call_deferred("_self_test")

func _build_ui() -> void:
 UI.panel(self,Rect2(0,0,800,480),Color("141323"),Color("141323"))
 UI.panel(self,Rect2(10,8,780,29),Color("29213f"),Color("655180"))
 UI.label(self,"ECHO",Rect2(18,9,70,25),UI.PINK,24)
 UI.label(self,"/ 夜班诊所",Rect2(89,14,126,18),UI.PAPER)
 session_label = UI.label(self,"",Rect2(226,14,212,18),UI.PURPLE)
 metrics = UI.label(self,"",Rect2(428,14,161,18),UI.GOLD)
 mute_button = UI.button(self,"声音 开",Rect2(599,11,62,22),_toggle_mute,UI.PURPLE)
 motion_button = UI.button(self,"动效 开",Rect2(666,11,62,22),_toggle_motion,UI.PURPLE)
 UI.button(self,"F11",Rect2(734,11,48,22),_fullscreen,UI.PURPLE)
 UI.panel(self,Rect2(10,44,780,33),Color("303044"),UI.GOLD)
 UI.label(self,"当前目标",Rect2(19,52,78,18),UI.GOLD)
 objective = UI.label(self,"",Rect2(103,52,597,18),UI.PAPER)
 UI.button(self,"提示 ?",Rect2(712,49,70,23),_show_hint,UI.GOLD)
 UI.panel(self,Rect2(10,84,278,334),Color("201d31"),UI.PINK.darkened(0.3))
 UI.panel(self,Rect2(10,84,278,23),Color("512c4c"),Color("512c4c"))
 UI.label(self,"01 / 问诊通信",Rect2(18,87,170,18),UI.PINK)
 UI.label(self,"E-017 在线",Rect2(207,87,77,18),UI.PAPER)
 scroll = ScrollContainer.new()
 scroll.position = Vector2(18,114)
 scroll.size = Vector2(262,140)
 scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
 scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 add_child(scroll)
 history = VBoxContainer.new()
 history.size_flags_horizontal = SIZE_EXPAND_FILL
 history.add_theme_constant_override("separation",6)
 scroll.add_child(history)
 UI.panel(self,Rect2(18,261,262,75),Color("31243e"),Color("87516d"))
 current_name = UI.label(self,"",Rect2(25,265,248,16),UI.PINK)
 current_body = UI.text(self,"",Rect2(25,285,248,47),UI.PAPER)
 next_button = UI.button(self,"继续  >",Rect2(18,342,262,25),_next,UI.GOLD,true)
 topics_label = UI.button(self,"",Rect2(18,372,262,18),_show_topics,UI.MUTED)
 input = LineEdit.new()
 input.position = Vector2(18,394)
 input.size = Vector2(208,20)
 input.placeholder_text = "输入话题 / 问诊 2T"
 input.max_length = 90
 input.add_theme_stylebox_override("normal",UI.style(Color("15172b"),Color("6f567e")))
 input.add_theme_stylebox_override("focus",UI.style(Color("15172b"),UI.GOLD))
 input.add_theme_color_override("font_color",UI.PAPER)
 input.add_theme_color_override("font_placeholder_color",UI.MUTED)
 input.add_theme_color_override("caret_color",UI.GOLD)
 input.text_submitted.connect(_ask)
 add_child(input)
 input.size = Vector2(208,20)
 send_button = UI.button(self,"发送",Rect2(232,394,48,20),func(): _ask(input.text),UI.PINK)
 stage = Stage.new()
 stage.position = Vector2(298,84)
 stage.size = Vector2(492,166)
 stage.reduced_motion = reduced_motion
 add_child(stage)
 board = Board.new()
 board.position = Vector2(298,258)
 board.size = Vector2(492,160)
 board.reduced_motion = reduced_motion
 board.action.connect(_act)
 add_child(board)
 UI.panel(self,Rect2(10,426,780,44),Color("24253c"),Color("565176"))
 route_bar = Control.new()
 route_bar.position = Vector2(18,431)
 route_bar.size = Vector2(480,18)
 route_bar.mouse_filter = MOUSE_FILTER_IGNORE
 add_child(route_bar)
 status = UI.label(self,"",Rect2(18,451,568,16),UI.MUTED)
 journal_button = UI.button(self,"病历 0",Rect2(592,435,86,26),_show_journal,UI.CYAN)
 UI.button(self,"快照重开",Rect2(686,435,96,26),_request_reboot,UI.PURPLE)
 flash = ColorRect.new()
 flash.size = Vector2(800,480)
 flash.mouse_filter = MOUSE_FILTER_IGNORE
 flash.color = UI.PINK
 flash.modulate.a = 0
 flash.z_index = 80
 add_child(flash)
 _update_preferences()

func _begin_phase(resume: bool=false) -> void:
 board.selected_memory = -1
 board.selected_wire = -1
 board.active_file = ""
 dialogue = Story.opening(state.phase,state.loop,state.ending)
 dialogue_index = 0
 dialogue_active = not dialogue.is_empty()
 stage.change(state.phase,state.ending,state.stability)
 if resume:
  dialogue_index=clampi(int(resume_ui.get("index",0)),0,dialogue.size()-1)
  dialogue_active=bool(resume_ui.get("active",true))
  var saved_line=resume_ui.get("line",[])
  _show_line(saved_line if saved_line is Array and saved_line.size()==2 else dialogue[dialogue_index])
  typing=false
  current_body.visible_characters=-1
  stage.talking=false
 else:
  if dialogue_active: _show_line(dialogue[0])
 _refresh()
 _save_case()
 if phase_tween and phase_tween.is_valid(): phase_tween.kill()
 board.position.x = 298 if reduced_motion else 312
 phase_tween = create_tween()
 phase_tween.tween_property(board,"position:x",298.0,0.12 if reduced_motion else 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
 if state.phase == Case.Phase.ENDED:
  _sound("repair" if state.ending=="bridge" else "reboot")
  _flash(UI.CYAN if state.ending=="bridge" else UI.PINK)

func _refresh() -> void:
 objective.text = "先读完左侧对话；黄色按钮会解锁右侧操作。" if dialogue_active else state.objective()
 metrics.text = "%dT / 稳定 %d%%" % [state.tokens,state.stability]
 session_label.text = "CASE 017 / 第 %02d 次接诊" % state.loop
 journal_button.text = "病历 %d" % state.evidence.size()
 topics_label.text = "可问：%s  /  2T" % "·".join(state.topics())
 input.editable = not dialogue_active and not busy
 send_button.disabled = dialogue_active or busy
 topics_label.disabled = dialogue_active or busy
 board.setup(state,dialogue_active or busy)
 _update_next()
 UI.clear(route_bar)
 var labels = ["接诊", "调谐", "记忆", "审计", "决策", "手术"]
 for i in range(6):
  var col = UI.GOLD if i == state.phase else UI.CYAN if i < state.phase else UI.MUTED.darkened(0.3)
  UI.label(route_bar,"%s%s%s" % ["[" if i==state.phase else "",labels[i],"]" if i==state.phase else ""],Rect2(i*77,0,75,18),col)
 status.text = "左侧读完对话，右侧仪器会解锁。空格可继续。" if dialogue_active else "关键操作免费 / 病历自动保存 / ? 查看具体提示"

func _show_line(line: Array) -> void:
 if not current_line.is_empty(): _history_add(current_line)
 current_line = line.duplicate()
 current_name.text = {"echo":"回声 / ECHO", "doctor":"你 / 值夜医生", "system":"诊疗台 / SYSTEM"}.get(line[0],"问诊")
 current_name.add_theme_color_override("font_color",UI.PINK if line[0]=="echo" else UI.GOLD if line[0]=="doctor" else UI.BLUE)
 current_body.text = str(line[1])
 typing = not reduced_motion and not self_testing
 current_body.visible_characters = 0 if typing else -1
 type_time = 0
 stage.talking = line[0] == "echo" and typing
 _sound("reply")
 _update_next()

func _history_add(line: Array) -> void:
 history_data.append(line.duplicate())
 if history_data.size()>80: history_data.pop_front()
 var p = PanelContainer.new()
 p.size_flags_horizontal = SIZE_EXPAND_FILL
 p.add_theme_stylebox_override("panel",UI.style(Color("252339"),Color("39314c")))
 history.add_child(p)
 var v = VBoxContainer.new()
 v.add_theme_constant_override("separation",3)
 p.add_child(v)
 var name_label = Label.new()
 name_label.text = {"echo":"回声", "doctor":"你", "system":"诊疗台"}.get(line[0],"记录")
 name_label.add_theme_color_override("font_color",UI.PINK if line[0]=="echo" else UI.GOLD if line[0]=="doctor" else UI.BLUE)
 v.add_child(name_label)
 var body = RichTextLabel.new()
 body.text = str(line[1])
 body.fit_content = true
 body.scroll_active = false
 body.custom_minimum_size.x = 238
 body.size_flags_horizontal = SIZE_EXPAND_FILL
 body.add_theme_font_override("normal_font",UI.pixel_font())
 body.add_theme_font_size_override("normal_font_size",12)
 body.add_theme_color_override("default_color",UI.MUTED)
 body.add_theme_constant_override("line_separation",2)
 v.add_child(body)
 if history.get_child_count()>50: history.get_child(0).queue_free()
 call_deferred("_scroll_end")

func _scroll_end() -> void:
 await get_tree().process_frame
 scroll.scroll_vertical = int(scroll.get_v_scroll_bar().max_value)

func _next() -> void:
 if busy: return
 if typing:
  typing=false
  current_body.visible_characters=-1
  stage.talking=false
  _update_next()
  return
 if not dialogue_active: _show_hint(); return
 dialogue_index += 1
 if dialogue_index < dialogue.size(): _show_line(dialogue[dialogue_index])
 else:
  dialogue_active = false
  stage.talking = false
  _sound("attach")
  stage.burst(UI.GOLD)
  _refresh()
  _toast("右侧已解锁："+state.objective())
 _update_next()
 _save_case()

func _update_next() -> void:
 if not is_instance_valid(next_button): return
 next_button.disabled = busy
 if typing: next_button.text = "显示全文  [空格]"
 elif dialogue_active: next_button.text = "解锁右侧操作  >" if dialogue_index==dialogue.size()-1 else "继续  [%d/%d]  >" % [dialogue_index+1,dialogue.size()]
 else: next_button.text = "我接下来该做什么？"

func _act(id: String, data: Variant = null) -> void:
 if busy: return
 if id=="journal": _show_journal(); return
 if dialogue_active: _toast("先点击左侧「继续」，读完本段对话。右侧随后解锁。"); return
 _sound("click")
 var advanced = false
 var before_tokens = state.tokens
 match id:
  "accept": advanced = state.accept_case()
  "recall": advanced = state.recall_case()
  "freq": state.tune(0,state.frequency+int(data))
  "offset": state.tune(1,state.offset+int(data))
  "lock_signal", "reuse_signal":
   advanced = state.lock_signal(id=="reuse_signal")
   if not advanced: _toast("还没有对齐。参考线每组三拍，延迟两格；不扣除 Token。")
  "select_memory":
   board.selected_memory = int(data)
   _toast("已选「%s」，点击下方时间槽放入。" % ["名字","雨声","门铃"][int(data)])
  "place_memory":
   var item: int = int(data[0]) if int(data[0])>=0 else board.selected_memory
   var slot: int = int(data[1])
   if item<0:
    if state.memory[slot]>=0:
     board.selected_memory = state.memory[slot]
     _toast("已选槽内记忆。再点另一个时间槽可交换。")
    else: _toast("先选上方记忆卡，再点这个时间槽；也可以直接拖入。")
   elif state.place_memory(item,slot):
    board.selected_memory=-1
    _sound("drop")
  "clear_memory": state.clear_memory(); board.selected_memory=-1
  "lock_memory", "reuse_memory":
   advanced = state.lock_memory(id=="reuse_memory")
   if not advanced: _toast("顺序还不完整：先听见雨，再取名字，最后敲门。可随时重排，不扣费。")
  "read_file":
   if state.read_file(str(data)): board.active_file=str(data)
  "confront": advanced=state.confront()
  "decide": advanced=state.decide(str(data))
  "source":
   board.selected_wire=int(data)
   _toast("来源已选中。点击右侧目标接线，可随时改接。")
  "target":
   if board.selected_wire<0: _toast("先点击左侧的来源，再选择右侧目标。")
   else:
    state.connect_wire(board.selected_wire,int(data))
    board.selected_wire=-1
    _sound("attach")
  "operate":
   advanced=state.operate()
   if not advanced: _toast("检查线路：人格去只读库，回写去回收井，外联去隔离桩。不扣费。")
  "reboot": _reboot(); return
 if advanced:
  _begin_phase()
  if state.tokens>before_tokens:
   _sound("attach")
   _toast("检查完成  +%dT / 新证据已写入病历。" % (state.tokens-before_tokens))
 else:
  var feedback = state.objective() if id in ["freq","offset"] else status.text
  _refresh()
  status.text=feedback
 _save_case()

func _ask(raw: String) -> void:
 if dialogue_active or busy: _toast("先完成当前对话。可问的话题会随剧情更新。"); return
 var answer = state.ask(raw)
 if not answer.ok:
  _toast(str(answer.text))
  if str(answer.text).length()>46: _info("问诊提示",str(answer.text))
  return
 input.clear()
 if not current_line.is_empty(): _history_add(current_line); current_line=[]
 _history_add(["doctor",raw.strip_edges()])
 _show_line(["echo",answer.text])
 _refresh()
 _save_case()

func _show_topics() -> void:
 _close_modal()
 var root = _modal_frame("补充问诊 / 每题 2T")
 UI.text(root,"补充问诊不影响主线。已问过的主题不会再次扣费。\n关键线索都由剧情和检查提供。",Rect2(205,177,390,42),UI.MUTED)
 for i in range(state.topics().size()):
  var topic: String = state.topics()[i]
  var asked=state.asked.has(str(state.phase)+":"+topic)
  var topic_button=UI.button(root,("已问 / " if asked else "问 / ")+topic,Rect2(205+i*193,236,182,30),func(): _close_modal(); _ask(topic),UI.PINK)
  topic_button.disabled=asked
 UI.button(root,"返回诊疗",Rect2(205,296,390,26),_close_modal,UI.PURPLE)

func _show_hint() -> void:
 _info("当前目标 / 免费提示",("先读完左侧当前对话，点击「解锁右侧操作」。\n\n" if dialogue_active else "")+state.hint())

func _show_journal() -> void:
 _close_modal()
 var root = _modal_frame("医生病历 / 跨轮保留",true)
 var journal_scroll = ScrollContainer.new()
 journal_scroll.position=Vector2(165,113)
 journal_scroll.size=Vector2(470,246)
 journal_scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 root.add_child(journal_scroll)
 var list=VBoxContainer.new()
 list.size_flags_horizontal=SIZE_EXPAND_FILL
 list.add_theme_constant_override("separation",9)
 journal_scroll.add_child(list)
 if state.evidence.is_empty():
  var label=Label.new()
  label.text="还没有记录。完成检查后，证据会自动出现在这里。"
  list.add_child(label)
 for key in state.evidence:
  var label=RichTextLabel.new()
  label.text="[%s]\n%s" % Case.EVIDENCE[key]
  label.fit_content=true
  label.scroll_active=false
  label.custom_minimum_size.x=444
  label.add_theme_font_override("normal_font",UI.pixel_font())
  label.add_theme_font_size_override("normal_font_size",12)
  label.add_theme_color_override("default_color",UI.PAPER)
  list.add_child(label)
 UI.label(root,"自动保存 / 已见结局 %d / 3"%state.endings.size(),Rect2(165,365,320,20),UI.MUTED)
 UI.button(root,"返回诊疗",Rect2(485,365,150,26),_close_modal,UI.CYAN)

func _modal_frame(title: String, large: bool=false) -> Control:
 modal=Control.new()
 modal.size=Vector2(800,480)
 modal.z_index=90
 add_child(modal)
 var shade=ColorRect.new()
 shade.size=Vector2(800,480)
 shade.color=Color(0.03,0.02,0.08,0.92)
 modal.add_child(shade)
 var r=Rect2(150,78,500,328) if large else Rect2(190,136,420,204)
 UI.panel(modal,r,Color("272139"),UI.PURPLE)
 UI.label(modal,title,Rect2(r.position+Vector2(15,12),Vector2(r.size.x-30,22)),UI.GOLD)
 return modal

func _info(title: String, body: String) -> void:
 _close_modal()
 var root=_modal_frame(title)
 UI.text(root,body,Rect2(205,179,390,104),UI.PAPER)
 UI.button(root,"知道了 / 返回诊疗",Rect2(205,299,390,26),_close_modal,UI.CYAN)

func _request_reboot() -> void:
 if busy: return
 if state.phase==Case.Phase.ENDED: _reboot(); return
 _close_modal()
 var root=_modal_frame("恢复接诊快照")
 UI.text(root,"本轮的仪器操作会重置。\n已经发现的证据、完成过的检查和结局会保留。\n若只是卡住，可先查看免费提示。",Rect2(205,181,390,76),UI.PAPER)
 UI.button(root,"继续当前诊疗",Rect2(205,293,182,28),_close_modal,UI.CYAN)
 UI.button(root,"携带病历重开",Rect2(403,293,192,28),_reboot,UI.PURPLE)

func _reboot() -> void:
 if busy: return
 _close_modal()
 busy=true
 typing=false
 _sound("reboot")
 _flash(UI.PURPLE)
 state.reboot()
 UI.clear(history)
 history_data=[]
 current_line=[]
 _history_add(["system","接诊快照已恢复。你的 %d 条病历被保留，患者将从第一次问诊醒来。" % state.evidence.size()])
 input.clear()
 busy=false
 _begin_phase()

func _close_modal() -> void:
 if is_instance_valid(modal):
  remove_child(modal)
  modal.queue_free()
 modal=null

func _toast(text: String) -> void:
 status.text=text

func _flash(color: Color) -> void:
 if reduced_motion: return
 flash.color=color
 flash.modulate.a=0.16
 var tw=create_tween()
 tw.tween_property(flash,"modulate:a",0.0,0.45)

func _process(delta: float) -> void:
 if typing:
  type_time+=delta*36
  current_body.visible_characters=int(type_time)
  if current_body.visible_characters>=current_body.text.length():
   typing=false
   current_body.visible_characters=-1
   stage.talking=false
   _update_next()

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode==KEY_F11: _fullscreen()
 elif event.keycode==KEY_ESCAPE: _close_modal()
 elif input.has_focus(): return
 elif event.keycode==KEY_SPACE and not is_instance_valid(modal): _next()
 elif event.keycode==KEY_F1: _show_hint()
 elif event.keycode==KEY_F8: _capture("manual")

func _fullscreen() -> void:
 var full=DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
 DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if full else DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN)

func _toggle_mute() -> void:
 muted=not muted
 _update_preferences()
 _save_preferences()

func _toggle_motion() -> void:
 reduced_motion=not reduced_motion
 stage.reduced_motion=reduced_motion
 board.reduced_motion=reduced_motion
 if reduced_motion:
  typing=false
  current_body.visible_characters=-1
  stage.talking=false
 _update_preferences()
 _update_next()
 _refresh()
 _save_preferences()

func _update_preferences() -> void:
 mute_button.text="声音 关" if muted else "声音 开"
 motion_button.text="动效 静" if reduced_motion else "动效 开"
 AudioServer.set_bus_mute(0,muted)

func _load_preferences() -> void:
 var config=ConfigFile.new()
 if config.load("user://preferences.cfg")==OK:
  muted=config.get_value("accessibility","muted",false)
  reduced_motion=config.get_value("accessibility","reduced_motion",false)

func _save_preferences() -> void:
 var config=ConfigFile.new()
 config.set_value("accessibility","muted",muted)
 config.set_value("accessibility","reduced_motion",reduced_motion)
 config.save("user://preferences.cfg")

func _save_case() -> void:
 if self_testing or qa_memory: return
 if not _write_case(SAVE_PATH): _toast("自动保存未完成，请暂时保留窗口。")

func _write_case(path: String) -> bool:
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if file:
  var payload=state.snapshot()
  payload["ui"]={"history":history_data,"line":current_line,"index":dialogue_index,"active":dialogue_active}
  file.store_string(JSON.stringify(payload,"  "))
  file.close()
  return DirAccess.rename_absolute(path+".tmp",path)==OK
 return false

func _load_case() -> void:
 if not FileAccess.file_exists(SAVE_PATH): return
 var data=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if data is Dictionary and state.restore(data):
  if data.get("ui") is Dictionary: resume_ui=data.ui

func _start_ambience() -> void:
 var p=AudioStreamPlayer.new()
 var sound: AudioStreamWAV=load("res://assets/audio/night_loop.wav").duplicate()
 sound.loop_mode=AudioStreamWAV.LOOP_FORWARD
 sound.loop_begin=0
 sound.loop_end=sound.data.size()/2
 p.stream=sound
 p.volume_db=-20
 add_child(p)
 p.play()

func _sound(id: String) -> void:
 if muted or self_testing: return
 var path="res://assets/audio/"+id+".wav"
 if not ResourceLoader.exists(path): return
 var p=AudioStreamPlayer.new()
 p.stream=load(path)
 p.volume_db=-23
 add_child(p)
 p.finished.connect(p.queue_free)
 p.play()

func _capture(name: String) -> void:
 await RenderingServer.frame_post_draw
 var dir=capture_dir if not capture_dir.is_empty() else OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP)
 DirAccess.make_dir_recursive_absolute(dir)
 var screenshot=get_viewport().get_texture().get_image()
 screenshot.resize(1600,960,Image.INTERPOLATE_NEAREST)
 screenshot.save_png(dir.path_join("echo-clinic-"+name+".png"))

func _check(key: String, passed: bool) -> void:
 checks[key]=passed
 if not passed: push_error("CHECK FAILED: "+key)

func _read_all() -> void:
 typing=false
 current_body.visible_characters=-1
 var guard=0
 while dialogue_active and guard<20:
  _next()
  guard+=1

func _self_test() -> void:
 await get_tree().create_timer(1.0).timeout
 await _capture("initial")
 var runner=load("res://scripts/case_tests.gd").new()
 checks=runner.run()
 _check("ui_initial_actions_locked",board.buttons.accept.disabled)
 _act("accept")
 _check("ui_locked_action_cannot_skip_story",state.phase==Case.Phase.INTAKE)
 _read_all()
 _check("ui_reading_unlocks_action",not board.buttons.accept.disabled)
 board.buttons.accept.pressed.emit()
 _read_all()
 _act("lock_signal")
 _check("ui_wrong_tuning_stays_playable",state.phase==Case.Phase.TUNE)
 _act("freq",1); _act("freq",1)
 _act("offset",1); _act("offset",1)
 await get_tree().create_timer(0.6).timeout
 await _capture("signal")
 _act("lock_signal")
 _read_all()
 await get_tree().create_timer(0.5).timeout
 await _test_drag(Vector2(490,308),Vector2(365,362))
 _check("mouse_drag_memory_card_into_slot",state.memory[0]==1)
 await _test_click(Vector2(365,308))
 await _test_click(Vector2(489,362))
 _check("mouse_click_memory_then_slot",state.memory[1]==0)
 await _test_drag(Vector2(610,308),Vector2(610,362))
 _check("mouse_drag_third_memory",state.memory[2]==2)
 await get_tree().create_timer(0.5).timeout
 await _capture("memory")
 _act("lock_memory")
 _read_all()
 _act("read_file","hospital")
 _check("ui_one_file_not_enough",board.buttons.confront.disabled)
 _act("read_file","payload")
 _check("ui_both_files_unlock_confront",not board.buttons.confront.disabled)
 await _capture("audit")
 _act("confront")
 _read_all()
 _check("ui_third_choice_explained_and_locked",board.buttons.decide_isolate.disabled)
 _act("decide","release")
 _read_all()
 _check("ui_failed_ending_has_restart",not board.buttons.reboot.disabled and state.failed_before)
 _act("reboot")
 _read_all()
 _act("recall")
 _read_all()
 _act("read_file","hospital"); _act("read_file","payload")
 _act("confront")
 _read_all()
 _act("decide","isolate")
 _read_all()
 for i in range(3): _act("source",i); _act("target",i)
 await get_tree().create_timer(0.6).timeout
 await _capture("operation")
 _act("operate")
 _read_all()
 _check("ui_true_ending_reached",state.ending=="bridge" and state.evidence.has("bridge"))
 await get_tree().create_timer(0.6).timeout
 await _capture("ending")
 _check("ui_dialogue_fits",current_body.get_content_height()<=current_body.size.y)
 _check("ui_viewport_800x480",get_viewport_rect().size==Vector2(800,480))
 _check("ui_chinese_pixel_font_loaded",UI.pixel_font().has_char(0x56de))
 var probe="user://case-v2-ui-test.json"
 var written=_write_case(probe)
 written=written and _write_case(probe)
 var payload=JSON.parse_string(FileAccess.get_file_as_string(probe))
 _check("atomic_save_replaces_existing_file",written and payload.phase==state.phase)
 _check("save_keeps_dialogue_and_history",payload.ui.line==current_line and payload.ui.history==history_data and payload.ui.active==false)
 DirAccess.remove_absolute(probe)
 var all_text_fits=true
 var last_text=current_body.text
 for p in range(7):
  for e in ["erase","release","bridge"] if p==6 else [""]:
   for line in Story.opening(p,1,e):
    current_body.text=line[1]
    await get_tree().process_frame
    all_text_fits=all_text_fits and current_body.get_content_height()<=current_body.size.y
 current_body.text=last_text
 _check("all_story_lines_fit_current_dialogue_panel",all_text_fits)
 var passed=not checks.values().has(false)
 var file=FileAccess.open(capture_dir.path_join("test-report.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify({"passed":passed,"version":"0.2.0","engine":Engine.get_version_info().string,"checks":checks},"  "))
 file.close()
 print("V2 TEST RESULT: ",passed," / ",checks.size()," checks")
 get_tree().quit(0 if passed else 1)

func _test_click(point: Vector2) -> void:
 var move=InputEventMouseMotion.new()
 move.position=point
 move.global_position=point
 get_viewport().push_input(move,true)
 var down=InputEventMouseButton.new()
 down.position=point
 down.global_position=point
 down.button_index=MOUSE_BUTTON_LEFT
 down.button_mask=MOUSE_BUTTON_MASK_LEFT
 down.pressed=true
 get_viewport().push_input(down,true)
 await get_tree().process_frame
 var up=InputEventMouseButton.new()
 up.position=point
 up.global_position=point
 up.button_index=MOUSE_BUTTON_LEFT
 up.pressed=false
 get_viewport().push_input(up,true)
 await get_tree().process_frame

func _test_drag(from: Vector2, to: Vector2) -> void:
 var down=InputEventMouseButton.new()
 down.position=from
 down.global_position=from
 down.button_index=MOUSE_BUTTON_LEFT
 down.button_mask=MOUSE_BUTTON_MASK_LEFT
 down.pressed=true
 get_viewport().push_input(down,true)
 await get_tree().process_frame
 var previous=from
 for step in range(1,11):
  var move=InputEventMouseMotion.new()
  move.position=from.lerp(to,step/10.0)
  move.global_position=move.position
  move.relative=move.position-previous
  move.button_mask=MOUSE_BUTTON_MASK_LEFT
  get_viewport().push_input(move,true)
  previous=move.position
  await get_tree().process_frame
 var up=InputEventMouseButton.new()
 up.position=to
 up.global_position=to
 up.button_index=MOUSE_BUTTON_LEFT
 up.pressed=false
 get_viewport().push_input(up,true)
 await get_tree().process_frame
