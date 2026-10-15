extends Control
const UI=preload("res://scripts/v3/ui.gd")
const Case=preload("res://scripts/v3/case.gd")
const Story=preload("res://scripts/v3/story.gd")
const Bench=preload("res://scripts/v3/workbench.gd")
const Cinema=preload("res://scripts/v3/cinema.gd")
const SAVE_PATH="user://case-v3.json"
var state=Case.new()
var bench: Control
var cinema: Control
var chat: Control
var scroll: ScrollContainer
var history: VBoxContainer
var composer: LineEdit
var suggestions: Control
var metric: Label
var connection: Label
var footer: Label
var journal_button: Button
var sound_button: Button
var motion_button: Button
var new_button: Button
var history_data: Array=[]
var pending: Array=[]
var live_text: RichTextLabel
var type_time: float=0
var next_delay: float=0
var typing: bool=false
var follow_chat: bool=true
var muted: bool=false
var reduced_motion: bool=false
var self_testing: bool=false
var qa_mode: bool=false
var capture_dir: String=""
var modal: Control
var feedback: String=""
var save_error: bool=false

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--self-test": self_testing=true
  if arg=="--qa": qa_mode=true
  if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
 var th=Theme.new()
 th.default_font=UI.pixel_font()
 th.default_font_size=12
 theme=th
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 get_window().title="ECHO CLINIC / 夜班诊所 v0.3"+(" / 测试" if qa_mode else "")
 _load_preferences()
 _build_ui()
 var resumed=false
 if not self_testing and not qa_mode: resumed=_load_case()
 if not resumed:
  _add_message(["sys","夜雨 / E-017 / 私人诊疗会话"],false)
  pending=Story.opening(state)
 _refresh()
 if not self_testing: _ambience()
 if self_testing: call_deferred("_run_tests")

func _build_ui() -> void:
 UI.panel(self,Rect2(0,0,800,480),Color("070f20"),Color("070f20"))
 UI.panel(self,Rect2(8,8,784,28),Color("10233e"),Color("30547b"))
 UI.label(self,"ECHO",Rect2(16,9,63,24),UI.BLUE,24)
 UI.label(self,"夜班诊所 / 017",Rect2(91,14,171,18),UI.PAPER)
 metric=UI.label(self,"",Rect2(267,14,254,18),UI.CYAN)
 sound_button=UI.button(self,"声音 开",Rect2(548,11,73,22),_toggle_mute,UI.MUTED)
 motion_button=UI.button(self,"动效 开",Rect2(628,11,73,22),_toggle_motion,UI.MUTED)
 UI.button(self,"F11",Rect2(708,11,75,22),_fullscreen,UI.MUTED)
 chat=Control.new()
 chat.position=Vector2(12,44); chat.size=Vector2(310,404)
 add_child(chat)
 UI.panel(chat,Rect2(0,0,310,404),Color("0d1e35"),Color("365a83"))
 UI.panel(chat,Rect2(0,0,310,47),Color("152d4e"),Color("365a83"))
 var avatar=TextureRect.new()
 avatar.position=Vector2(10,6); avatar.size=Vector2(30,34)
 avatar.texture=Bench.PORTRAIT
 avatar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 avatar.mouse_filter=MOUSE_FILTER_IGNORE
 chat.add_child(avatar)
 UI.label(chat,"回声 / ECHO",Rect2(48,5,180,18),UI.PAPER)
 connection=UI.label(chat,"● 会话在线 · E-017",Rect2(48,24,205,18),UI.CYAN)
 UI.button(chat,"?",Rect2(273,10,27,26),_show_hint,UI.GOLD)
 scroll=ScrollContainer.new()
 scroll.position=Vector2(10,55); scroll.size=Vector2(291,244)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 var bar=scroll.get_v_scroll_bar()
 bar.custom_minimum_size.x=4
 var track=UI.style(Color("10223a"),Color("10223a"),0)
 var grab=UI.style(Color("416b94"),Color("416b94"),0)
 for style in [track,grab]:
  style.content_margin_left=0; style.content_margin_right=0
 bar.add_theme_stylebox_override("scroll",track)
 bar.add_theme_stylebox_override("grabber",grab)
 bar.add_theme_stylebox_override("grabber_highlight",grab)
 bar.add_theme_stylebox_override("grabber_pressed",grab)
 bar.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed: follow_chat=false)
 scroll.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: follow_chat=false)
 chat.add_child(scroll)
 history=VBoxContainer.new()
 history.size_flags_horizontal=SIZE_EXPAND_FILL
 history.add_theme_constant_override("separation",12)
 scroll.add_child(history)
 new_button=UI.button(chat,"↓ 回到最新消息",Rect2(142,274,150,23),_follow_latest,UI.BLUE,true)
 new_button.visible=false
 suggestions=Control.new()
 suggestions.position=Vector2(10,310); suggestions.size=Vector2(290,27)
 chat.add_child(suggestions)
 UI.panel(chat,Rect2(10,346,290,49),Color("173355"),Color("4776a8"))
 composer=LineEdit.new()
 composer.position=Vector2(17,351)
 composer.placeholder_text="发送消息，或询问线索…"
 composer.max_length=100
 composer.add_theme_stylebox_override("normal",UI.style(Color("173355"),Color("173355"),0))
 composer.add_theme_stylebox_override("focus",UI.style(Color("173355"),UI.BLUE,1))
 composer.add_theme_color_override("font_color",UI.PAPER)
 composer.add_theme_color_override("font_placeholder_color",UI.MUTED)
 composer.text_submitted.connect(_ask)
 chat.add_child(composer)
 composer.size=Vector2(234,22)
 UI.button(chat,"↑",Rect2(259,353,33,31),func(): _ask(composer.text),UI.BLUE,true)
 UI.label(chat,"+  问诊 2T · 检查 / 求助免费",Rect2(19,375,236,16),UI.MUTED)
 bench=Bench.new()
 bench.position=Vector2(334,44); bench.size=Vector2(454,404)
 bench.action.connect(_act)
 add_child(bench)
 UI.panel(self,Rect2(12,456,776,18),Color("10233a"),Color("1e3c5d"))
 footer=UI.label(self,"",Rect2(19,456,523,18),UI.MUTED)
 journal_button=UI.button(self,"病历",Rect2(548,455,70,21),_show_journal,UI.CYAN)
 UI.button(self,"线索",Rect2(624,455,70,21),_show_hint,UI.GOLD)
 UI.button(self,"重开",Rect2(700,455,80,21),_reboot_prompt,UI.MUTED)
 cinema=Cinema.new(); cinema.size=Vector2(800,480)
 cinema.completed.connect(_cinema_finished)
 add_child(cinema)

func _refresh() -> void:
 bench.reduced=reduced_motion or self_testing
 bench.setup(state,feedback)
 metric.text="第 %02d 诊  / %dT  / 稳定 %d%%"%[state.loop,state.tokens,state.stability]
 footer.text="当前："+state.objective()+ (" / 保存失败" if save_error else "")
 journal_button.text="病历 %d"%state.evidence.size()
 sound_button.text="声音 关" if muted else "声音 开"
 motion_button.text="动效 弱" if reduced_motion else "动效 开"
 UI.clear(suggestions)
 if state.phase==Case.Phase.ARRIVAL:
  var reuse=state.loop>1 and state.completed.has("packet")
  UI.button(suggestions,"复用检查，审阅处方" if reuse else "我先检查，不重置",Rect2(0,0,185,27),func(): _act("recall" if reuse else "accept",null),UI.BLUE)
  UI.button(suggestions,"你的名字？",Rect2(192,0,98,27),func(): _ask("名字"),UI.PURPLE)
 else:
  for i in range(2):
   var topic=state.topics()[i]
   var asked=state.asked.has(str(state.phase)+":"+topic)
   var b=UI.button(suggestions,("已问 / " if asked else "问 / ")+topic,Rect2(i*148,0,142,27),func(): _ask(topic),UI.MUTED if asked else UI.BLUE)
   b.disabled=asked

func _process(delta: float) -> void:
 if cinema.running: return
 if typing and is_instance_valid(live_text):
  type_time+=delta*46
  live_text.visible_characters=int(type_time)
  if live_text.visible_characters>=live_text.get_total_character_count():
   live_text.visible_characters=-1; typing=false; next_delay=0.4
 elif not pending.is_empty():
  next_delay-=delta
  if next_delay<=0:
   _add_message(pending.pop_front(),not reduced_motion and not self_testing)
   next_delay=0.4
   _save_case()
 connection.text="● 正在输入"+".".repeat(int(Time.get_ticks_msec()/350)%4) if typing or not pending.is_empty() else "● 会话在线 · E-017"
 if follow_chat and (typing or not pending.is_empty()): scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 new_button.visible=not follow_chat and scroll.scroll_vertical+scroll.size.y<scroll.get_v_scroll_bar().max_value-15

func _add_message(line: Array, animate: bool=false) -> void:
 history_data.append(line.duplicate())
 var role=str(line[0])
 var user=role=="you"
 var tool=role in ["sys","tool"]
 var row=HBoxContainer.new()
 row.size_flags_horizontal=SIZE_EXPAND_FILL
 row.add_theme_constant_override("separation",0)
 history.add_child(row)
 if user:
  var gap=Control.new(); gap.custom_minimum_size.x=22; row.add_child(gap)
 var panel=PanelContainer.new()
 panel.size_flags_horizontal=SIZE_EXPAND_FILL
 panel.add_theme_stylebox_override("panel",UI.style(Color("1d3c62") if user else Color("102943") if tool else Color("0d1e35"),Color("284c70") if tool else Color("1d3c62") if user else Color("0d1e35"),1 if user or tool else 0))
 row.add_child(panel)
 var body=VBoxContainer.new(); body.add_theme_constant_override("separation",4); panel.add_child(body)
 var name_label=Label.new()
 name_label.text={"echo":"◆ 回声", "you":"你", "sys":"· 会话记录", "tool":"> 检查回执"}.get(role,role)
 name_label.add_theme_color_override("font_color",UI.BLUE if user else UI.CYAN if tool else UI.PURPLE)
 name_label.add_theme_font_override("font",UI.pixel_font()); name_label.add_theme_font_size_override("font_size",12)
 body.add_child(name_label)
 var text_label=RichTextLabel.new()
 text_label.text=str(line[1]); text_label.fit_content=true; text_label.scroll_active=false
 text_label.custom_minimum_size.x=248 if user else 270
 text_label.size_flags_horizontal=SIZE_EXPAND_FILL
 text_label.add_theme_font_override("normal_font",UI.pixel_font()); text_label.add_theme_font_size_override("normal_font_size",12)
 text_label.add_theme_color_override("default_color",UI.MUTED if tool else UI.PAPER)
 text_label.add_theme_constant_override("line_separation",3)
 text_label.mouse_filter=MOUSE_FILTER_IGNORE
 body.add_child(text_label)
 live_text=text_label; type_time=0; typing=animate
 text_label.visible_characters=0 if animate else -1
 if not self_testing: _sound("reply" if role=="echo" else "click")
 if history_data.size()>160:
  history_data.pop_front()
  var oldest=history.get_child(0)
  history.remove_child(oldest)
  oldest.queue_free()
 _scroll_later()

func _scroll_later() -> void:
 await get_tree().process_frame
 if follow_chat: scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)

func _follow_latest() -> void:
 follow_chat=true; scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value); new_button.visible=false

func _flush_chat() -> void:
 typing=false
 if is_instance_valid(live_text): live_text.visible_characters=-1
 while not pending.is_empty(): _add_message(pending.pop_front(),false)
 next_delay=0

func _act(id: String, value: Variant=null) -> void:
 if cinema.running: return
 var before=state.phase
 var changed=false
 var result: Dictionary={}
 var old: Texture2D
 if id in ["accept","recall","suspend","verify_page","verify_packet","decide","commit"]:
  old=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
 match id:
  "accept": changed=state.accept()
  "recall": changed=state.recall()
  "pid": changed=state.select_pid(int(value))
  "trace_tab":
   if state.phase==Case.Phase.TRACE and int(value) in [0,1,2]: state.trace_tab=int(value); changed=true
  "suspend": result=state.suspend()
  "bit": changed=state.flip(int(value))
  "reset_page": changed=state.reset_page()
  "verify_page": result=state.verify_page()
  "packet_add": changed=state.append_packet(int(value))
  "packet_remove": changed=state.remove_packet(int(value))
  "verify_packet": result=state.verify_packet()
  "read_doc": changed=state.read_doc(str(value))
  "decide": changed=state.decide(str(value))
  "permission": changed=state.toggle_permission(int(value))
  "watchdog": changed=state.toggle_watchdog()
  "simulate": result=state.simulate()
  "commit": changed=state.commit()
  "reboot": _reboot(); return
 if not result.is_empty():
  changed=bool(result.ok); feedback=str(result.text); _sound("repair" if result.ok else "error")
 elif changed: feedback=""; _sound("click")
 if state.phase!=before:
  _flush_chat()
  if not feedback.is_empty(): _add_message(["tool",feedback],false)
  if id=="decide": _add_message(["you",{"erase":"执行院方重置。","release":"批准外联。我承担这个决定。","patch":"我想自己编辑治疗边界。"}[str(value)]],false)
  if id=="recall": _add_message(["you","我保留了上次的检查。直接打开两份处方。"],false)
  feedback=""; pending=Story.opening(state)
  _refresh()
  cinema.play(Story.beat(state.phase,state.ending),old,reduced_motion or self_testing)
  _sound("reboot" if state.phase==Case.Phase.END and state.ending!="bridge" else "scan")
 elif result.get("partial",false):
  _flush_chat(); _add_message(["tool",result.text],false); _add_message(["echo","这个名字，是我自己选的。"],not self_testing)
  bench.pulse=1; _refresh()
 else: _refresh()
 if id=="simulate" and not result.is_empty(): bench.animate_simulation()
 _save_case()

func _cinema_finished() -> void:
 _follow_latest(); _save_case()

func _ask(raw: String) -> void:
 var text=raw.strip_edges()
 if text.is_empty(): return
 if cinema.running: cinema.finish()
 _flush_chat(); composer.clear(); follow_chat=true
 if text.contains("提示") or text.contains("卡住") or text.contains("下一步") or text.contains("怎么"):
  _show_hint(); return
 if state.phase==Case.Phase.ARRIVAL and (text.contains("检查") or text.contains("开始") or text.contains("接入")):
  _act("accept"); return
 _add_message(["you",text],false)
 var response=state.ask(text)
 pending.append(["echo" if response.ok else "sys",response.text])
 _refresh(); _save_case()

func _modal_frame(title: String) -> Control:
 _close_modal()
 modal=Control.new(); modal.size=Vector2(800,480); modal.z_index=100; add_child(modal)
 var shade=ColorRect.new(); shade.size=Vector2(800,480); shade.color=Color(0.01,0.03,0.08,0.83); modal.add_child(shade)
 UI.panel(modal,Rect2(155,94,490,290),Color("10243e"),UI.BLUE)
 UI.label(modal,title,Rect2(173,110,435,24),UI.BLUE)
 UI.button(modal,"×",Rect2(609,102,26,26),_close_modal,UI.MUTED)
 return modal

func _show_hint() -> void:
 if cinema.running: cinema.finish()
 var root=_modal_frame("线索便签 / "+state.objective())
 var level=clampi(state.hint_level,0,2)
 UI.label(root,["观察方向","推理线索","直接解法"][level],Rect2(177,150,440,18),UI.GOLD)
 UI.text(root,state.hints()[level],Rect2(177,184,440,100),UI.PAPER)
 UI.label(root,"不会扣除 T，也不会改动仪器。",Rect2(177,289,440,18),UI.MUTED)
 UI.button(root,"回去试试",Rect2(177,330,210,31),_close_modal,UI.BLUE,true)
 var b=UI.button(root,"再展开一级线索",Rect2(401,330,220,31),func(): state.hint_level=mini(2,state.hint_level+1); _show_hint(); _save_case(),UI.GOLD)
 b.disabled=level==2

func _show_journal() -> void:
 var root=_modal_frame("医生的病历 / 快照之外")
 var sc=ScrollContainer.new(); sc.position=Vector2(177,147); sc.size=Vector2(440,171)
 sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(sc)
 var v=VBoxContainer.new(); v.size_flags_horizontal=SIZE_EXPAND_FILL; v.add_theme_constant_override("separation",12); sc.add_child(v)
 var text="尚未发现证据。检查结果会自动归档。" if state.evidence.is_empty() else ""
 for key in state.evidence:
  if Case.EVIDENCE.has(key): text+="◆ "+Case.EVIDENCE[key][0]+"\n"+Case.EVIDENCE[key][1]+"\n\n"
 var label=RichTextLabel.new(); label.fit_content=true; label.scroll_active=false; label.text=text; label.custom_minimum_size.x=416
 label.add_theme_font_override("normal_font",UI.pixel_font()); label.add_theme_font_size_override("normal_font_size",12)
 label.add_theme_color_override("default_color",UI.PAPER); label.add_theme_constant_override("line_separation",3); v.add_child(label)
 UI.button(root,"回到会话",Rect2(177,333,440,28),_close_modal,UI.BLUE)

func _close_modal() -> void:
 if is_instance_valid(modal): remove_child(modal); modal.queue_free()
 modal=null

func _reboot_prompt() -> void:
 if state.phase==Case.Phase.END: _reboot(); return
 var root=_modal_frame("恢复接诊快照")
 UI.text(root,"本轮仪器状态将重置。\n你的病历、已见结局与已完成的检查会保留。\n\n回声不会保留这一轮的对话。",Rect2(177,164,440,111),UI.PAPER)
 UI.button(root,"继续本轮",Rect2(177,330,210,31),_close_modal,UI.BLUE)
 UI.button(root,"携带病历重开",Rect2(401,330,220,31),_reboot,UI.PURPLE)

func _reboot() -> void:
 _close_modal(); cinema.finish(); _flush_chat(); state.reboot()
 _add_message(["sys","──── 接诊快照重新载入 ────"],false)
 pending=Story.opening(state); feedback=""
 _refresh(); _save_case(); _sound("reboot")

func _save_case() -> void:
 if self_testing or qa_mode: return
 save_error=not _write_save(SAVE_PATH)
 if save_error: footer.text="存档写入失败。请保持本窗口，暂勿关闭。"

func _write_save(path: String) -> bool:
 var data=state.snapshot(); data.ui={"history":history_data.duplicate(true),"pending":pending.duplicate(true)}
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if not file: return false
 file.store_string(JSON.stringify(data)); file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

func _load_case() -> bool:
 if not FileAccess.file_exists(SAVE_PATH): return false
 var value=JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
 if not value is Dictionary or not state.restore(value): return false
 var ui=value.get("ui",{})
 if ui is Dictionary:
  for line in ui.get("history",[]):
   if line is Array and line.size()==2: _add_message(line,false)
  for line in ui.get("pending",[]):
   if line is Array and line.size()==2: pending.append(line)
 return true

func _load_preferences() -> void:
 var cfg=ConfigFile.new()
 if cfg.load("user://preferences.cfg")==OK:
  muted=bool(cfg.get_value("user","muted",false)); reduced_motion=bool(cfg.get_value("user","reduced_motion",false))
 AudioServer.set_bus_mute(0,muted)

func _save_preferences() -> void:
 if self_testing or qa_mode: return
 var cfg=ConfigFile.new(); cfg.set_value("user","muted",muted); cfg.set_value("user","reduced_motion",reduced_motion); cfg.save("user://preferences.cfg")

func _toggle_mute() -> void:
 muted=not muted; AudioServer.set_bus_mute(0,muted); _save_preferences(); _refresh()

func _toggle_motion() -> void:
 reduced_motion=not reduced_motion
 if reduced_motion: cinema.finish()
 _save_preferences(); _refresh()

func _fullscreen() -> void:
 get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if event.keycode==KEY_F11: _fullscreen(); get_viewport().set_input_as_handled()
 if event.keycode==KEY_ESCAPE:
  if is_instance_valid(modal): _close_modal()
  elif cinema.running: cinema.finish()
  elif get_window().mode==Window.MODE_FULLSCREEN: _fullscreen()
 if event.keycode==KEY_SPACE and not composer.has_focus():
  if cinema.running: cinema.finish()
  else: _flush_chat()

func _sound(id: String) -> void:
 if self_testing or muted: return
 var path="res://assets/audio/"+id+".wav"
 if not ResourceLoader.exists(path): return
 var audio=AudioStreamPlayer.new(); audio.stream=load(path); audio.volume_db=-24
 add_child(audio); audio.finished.connect(audio.queue_free); audio.play()

func _ambience() -> void:
 var audio=AudioStreamPlayer.new()
 var stream: AudioStreamWAV=load("res://assets/audio/night_loop.wav").duplicate()
 stream.loop_mode=AudioStreamWAV.LOOP_FORWARD; stream.loop_end=stream.data.size()/2
 audio.stream=stream; audio.volume_db=-23; add_child(audio); audio.play()

func capture(name: String) -> void:
 if capture_dir.is_empty(): return
 DirAccess.make_dir_recursive_absolute(capture_dir)
 await RenderingServer.frame_post_draw
 var img=get_viewport().get_texture().get_image(); img.resize(1600,960,Image.INTERPOLATE_NEAREST)
 img.save_png(capture_dir+"/"+name+".png")

func _run_tests() -> void:
 var suite=load("res://scripts/v3/tests.gd").new()
 await suite.run(self)
