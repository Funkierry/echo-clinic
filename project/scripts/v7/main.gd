extends Control
const UI=preload("res://scripts/v4/ui.gd")
const Case=preload("res://scripts/v7/case.gd")
const Story=preload("res://scripts/v7/story.gd")
const Bench=preload("res://scripts/v7/workbench.gd")
const Cinema=preload("res://scripts/v4/cinema.gd")
const Director=preload("res://scripts/v7/director.gd")
const Router=preload("res://scripts/v7/dialogue_router.gd")
const AIClient=preload("res://scripts/v5/ai_client.gd")
const SAVE_PATH="user://case-v7.json"
const Profile=preload("res://scripts/v7/profile.gd")
const Workshop=preload("res://scripts/v7/workshop.gd")
const Companions=preload("res://scripts/v7/companions.gd")
var profile=Profile.new()
var companions: Control
# The clinic (top bar, chat, bench, footer) moves as one 800×480 block; the lounge only takes room once someone has recovered.
var stage: Control
var lounge_open: bool=false
var wallet_button: Button
var price_label: Label
var confirmation: Dictionary={}
var confirmation_serial: int=0
var ai: Node
var ai_button: Button
var send_button: Button
var ai_ticket: int=-1
var ai_stamp: String=""
var ai_question: String=""
var ai_probe: bool=false
var ai_status: String="尚未连接 DeepSeek"
var ai_focus: String="none"
var ai_turn: int=0
var ai_form: Dictionary={}
var ai_status_label: RichTextLabel
var open_ai_on_start: bool=false
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
var rebuilding: bool=false
var ambience_player: AudioStreamPlayer

func _ready() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg=="--self-test": self_testing=true
  if arg=="--qa": qa_mode=true
  if arg=="--setup-ai": open_ai_on_start=true
  if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
 var th=Theme.new()
 th.default_font=UI.pixel_font()
 th.default_font_size=12
 theme=th
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 get_window().title="ECHO CLINIC / 夜班诊所 v0.7"+(" / 测试" if qa_mode else "")
 ai=AIClient.new(); add_child(ai)
 ai.completed.connect(_ai_completed)
 if not self_testing and not qa_mode:
  ai.api_key=OS.get_environment("DEEPSEEK_API_KEY").strip_edges()
  var ai_cfg=ConfigFile.new()
  if ai_cfg.load("user://ai-v5.cfg")==OK: ai.model=str(ai_cfg.get_value("ai","model",AIClient.DEFAULT_MODEL))
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
 elif open_ai_on_start: call_deferred("_show_ai_settings")

func _build_ui() -> void:
 UI.panel(self,Rect2(0,0,1100,600),Color("070f20"),Color("070f20"))
 stage=Control.new(); stage.size=Vector2(800,480); stage.mouse_filter=MOUSE_FILTER_IGNORE; add_child(stage)
 UI.panel(stage,Rect2(8,8,784,28),Color("10233e"),Color("30547b"))
 UI.label(stage,"ECHO",Rect2(16,9,63,24),UI.BLUE,24)
 UI.label(stage,"夜班诊所 / 017",Rect2(91,14,171,18),UI.PAPER)
 metric=UI.label(stage,"",Rect2(267,14,170,18),UI.CYAN)
 wallet_button=UI.button(stage,"",Rect2(444,11,96,22),func():_show_journal("wallet"),UI.GOLD)
 sound_button=UI.button(stage,"声音 开",Rect2(548,11,73,22),_toggle_mute,UI.MUTED)
 motion_button=UI.button(stage,"动效 开",Rect2(628,11,73,22),_toggle_motion,UI.MUTED)
 UI.button(stage,"F11",Rect2(708,11,75,22),_fullscreen,UI.MUTED)
 chat=Control.new()
 chat.position=Vector2(12,44); chat.size=Vector2(310,404)
 stage.add_child(chat)
 UI.panel(chat,Rect2(0,0,310,404),Color("0d1e35"),Color("365a83"))
 UI.panel(chat,Rect2(0,0,310,47),Color("152d4e"),Color("365a83"))
 var avatar=TextureRect.new()
 avatar.position=Vector2(10,6); avatar.size=Vector2(30,34)
 avatar.texture=Bench.PORTRAIT
 avatar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 avatar.mouse_filter=MOUSE_FILTER_IGNORE
 chat.add_child(avatar)
 UI.label(chat,"回声 / ECHO",Rect2(48,5,155,18),UI.PAPER)
 ai_button=UI.button(chat,"AI 离线",Rect2(232,10,68,26),_show_ai_settings,UI.MUTED)
 connection=UI.label(chat,"● 会话在线 · E-017",Rect2(48,24,180,18),UI.CYAN)
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
 composer.placeholder_text="直接追问，或说出你的打算…"
 composer.max_length=500
 composer.add_theme_stylebox_override("normal",UI.style(Color("173355"),Color("173355"),0))
 composer.add_theme_stylebox_override("focus",UI.style(Color("173355"),UI.BLUE,1))
 composer.add_theme_color_override("font_color",UI.PAPER)
 composer.add_theme_color_override("font_placeholder_color",UI.MUTED)
 composer.text_submitted.connect(_ask)
 chat.add_child(composer)
 composer.size=Vector2(234,22)
 send_button=UI.button(chat,"↑",Rect2(259,353,33,31),func():
  if ai.busy: _cancel_ai(true)
  else: _ask(composer.text),UI.BLUE,true)
 price_label=UI.label(chat,"",Rect2(19,375,236,16),UI.MUTED)
 bench=Bench.new()
 bench.position=Vector2(334,44); bench.size=Vector2(454,404)
 bench.action.connect(_act)
 stage.add_child(bench)
 UI.panel(stage,Rect2(12,456,776,18),Color("10233a"),Color("1e3c5d"))
 footer=UI.label(stage,"",Rect2(19,456,450,18),UI.MUTED)
 journal_button=UI.button(stage,"病历",Rect2(474,455,70,21),_show_journal,UI.CYAN)
 UI.button(stage,"提示",Rect2(550,455,58,21),_show_hint,UI.GOLD)
 UI.button(stage,"维修站",Rect2(614,455,82,21),_show_workshop,UI.CYAN)
 UI.button(stage,"重开",Rect2(702,455,78,21),_reboot_prompt,UI.MUTED)
 cinema=Cinema.new(); cinema.size=Vector2(800,480)
 cinema.completed.connect(_cinema_finished)
 stage.add_child(cinema)
 companions=Companions.new(); add_child(companions)
 companions.setup(profile,ai)
 companions.changed.connect(_profile_changed)
 companions.settings_requested.connect(_show_ai_settings)
 _layout(false)

func _layout(animate: bool) -> void:
 var open=not profile.contacts.is_empty()
 var target=Vector2(300,60) if open else Vector2(150,60)
 companions.position=Vector2(8,68)
 companions.visible=open
 if animate and open and not lounge_open and not reduced_motion and not self_testing:
  companions.modulate.a=0
  var tw=create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
  tw.tween_property(stage,"position",target,0.45)
  tw.tween_property(companions,"modulate:a",1.0,0.45).set_delay(0.2)
 else:
  stage.position=target; companions.modulate.a=1
 lounge_open=open

func _stage_rect() -> Rect2i:
 return Rect2i(Vector2i(stage.position),Vector2i(800,480))

func _refresh() -> void:
 state.tokens=profile.balance
 if is_instance_valid(companions):
  companions.profile=profile
  companions.refresh()
  if lounge_open!=(not profile.contacts.is_empty()) and not cinema.running: _layout(true)
 bench.reduced=reduced_motion or self_testing
 bench.confirmation=confirmation
 bench.setup(state,feedback)
 metric.text="第 %02d 诊  / 稳定 %d%%"%[state.loop,state.stability]
 wallet_button.text="钱包 %dT"%profile.balance
 wallet_button.tooltip_text="可用 %dT / 聊天预留 %dT\n检查 4T · 治疗 8T · 维修每单 +6T"%[profile.available(),profile.balance-profile.available()]
 price_label.text="在线回应每句 1T · 选项与调查免费" if ai.enabled else ""
 footer.text="当前："+state.objective()+ (" / 保存失败" if save_error else "")
 if not confirmation.is_empty(): footer.text="待签字："+confirmation.title
 journal_button.text="病历 %d"%state.evidence.size()
 sound_button.text="声音 关" if muted else "声音 开"
 motion_button.text="动效 弱" if reduced_motion else "动效 开"
 ai_button.text="AI 开启" if ai.enabled else "AI 离线"
 ai_button.tooltip_text="DeepSeek 设置 / "+ai_status
 send_button.text="■" if ai.busy else "↑"
 send_button.tooltip_text="停止等待；服务端可能已计费" if ai.busy else "发送消息"
 UI.clear(suggestions)
 var replies=state.replies()
 for i in range(replies.size()):
  var reply=replies[i]
  var width=290 if replies.size()==1 else 142
  var selected=ai_focus==("first" if i==0 else "second")
  var choice=UI.button(suggestions,reply[1],Rect2(i*148,0,width,27),func(): _act(reply[0],reply[2]),UI.CYAN if selected else UI.BLUE if i==0 else UI.PURPLE,selected)
  if selected: choice.tooltip_text="回声提到了这件事。是否行动，由你决定。"
 _refresh_attachments(history)

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
 if ai.busy: connection.text="● DeepSeek 回应中 · ■ 可取消"
 elif not typing and pending.is_empty(): connection.text="● DeepSeek 自由会话" if ai.enabled else "● 本地剧情 · 点 AI 接入"
 if follow_chat and (typing or not pending.is_empty()): scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 new_button.visible=not follow_chat and scroll.scroll_vertical+scroll.size.y<scroll.get_v_scroll_bar().max_value-15

func _add_message(line: Array, animate: bool=false) -> void:
 history_data.append(line.duplicate())
 var role=str(line[0])
 var user=role in ["you","ghost"]
 var tool=role in ["sys","tool","confirm"]
 var row=HBoxContainer.new()
 row.size_flags_horizontal=SIZE_EXPAND_FILL
 row.add_theme_constant_override("separation",0)
 history.add_child(row)
 if user:
  var gap=Control.new(); gap.custom_minimum_size.x=22; row.add_child(gap)
 var panel=PanelContainer.new()
 panel.size_flags_horizontal=SIZE_EXPAND_FILL
 panel.add_theme_stylebox_override("panel",UI.style(Color("1d3c62") if user else Color("102943") if tool else Color("0d1e35"),Color("284c70") if tool else Color("1d3c62") if user else Color("0d1e35"),1 if user or tool else 0))
 if role=="ghost": panel.add_theme_stylebox_override("panel",UI.style(Color("372b43"),UI.PINK))
 if role=="confirm": panel.add_theme_stylebox_override("panel",UI.style(Color("283447"),UI.GOLD))
 row.add_child(panel)
 var body=VBoxContainer.new(); body.add_theme_constant_override("separation",4); panel.add_child(body)
 var name_label=Label.new()
 name_label.text={"echo":"◆ 回声", "echo_ai":"◆ 回声 · 自由对话", "echo_local":"◆ 回声 · 本地备用", "you":"你", "sys":"· 会话记录", "tool":"> 检查回执", "confirm":"◇ 医生签名 / 待确认记录", "withdrawn":"◆ 回声 / 已撤回", "ghost":"你？ / 缺少医生签名", "other":"◇ 缓存中的声音"}.get(role,role)
 name_label.add_theme_color_override("font_color",UI.PINK if role=="ghost" else UI.CYAN if role=="other" else UI.BLUE if user else UI.CYAN if tool else UI.PURPLE)
 if role=="confirm":
  name_label.set_meta("confirmation_title",confirmation.get("serial",-1) if not rebuilding and confirmation.get("summary","")==str(line[1]) else -1)
  name_label.add_theme_color_override("font_color",UI.GOLD)
 name_label.add_theme_font_override("font",UI.pixel_font()); name_label.add_theme_font_size_override("font_size",12)
 body.add_child(name_label)
 var text_label=RichTextLabel.new()
 text_label.text=str(line[1]); text_label.fit_content=true; text_label.scroll_active=false
 if role=="withdrawn":
  text_label.bbcode_enabled=true
  text_label.text="[s]"+str(line[1])+"[/s]\n（医生记录保留了撤回前的原文）"
 text_label.custom_minimum_size.x=248 if user else 270
 text_label.size_flags_horizontal=SIZE_EXPAND_FILL
 text_label.add_theme_font_override("normal_font",UI.pixel_font()); text_label.add_theme_font_size_override("normal_font_size",12)
 text_label.add_theme_color_override("default_color",UI.MUTED if tool and role!="confirm" else UI.PAPER)
 text_label.add_theme_constant_override("line_separation",3)
 text_label.mouse_filter=MOUSE_FILTER_IGNORE
 body.add_child(text_label)
 _attach_clue(body,line)
 live_text=text_label; type_time=0; typing=animate
 text_label.visible_characters=0 if animate else -1
 if not self_testing and not rebuilding: _sound("reply" if role in ["echo","echo_ai","echo_local","other"] else "click")
 if history_data.size()>160:
  history_data.pop_front()
  var oldest=history.get_child(0)
  history.remove_child(oldest)
  oldest.queue_free()
 _scroll_later()

func _attach_clue(parent: Control,line: Array) -> void:
 # Generated text and player messages can never manufacture actionable attachments.
 if line[0] not in ["echo","tool","sys"]: return
 var body=str(line[1])
 var clue: Array=[]
 if body.contains("患者提交了一条诊疗建议"): clue=["quiet",null,"附件 / 应用暂挂建议"]
 elif body.contains("原始转写仍在页 03"): clue=["memory_listen",null,"页03 / 查看原始转写"]
 elif body.contains("修订记录仍保留删除前"): clue=["memory_undo",null,"修订历史 / 找回页03"]
 elif body.contains("附件也一起转交"): clue=["file","manifest","附件 / 诊断资料.pkg"]
 elif body.contains("缓存中有一封未读回信"): clue=["envelope",null,"未读回信 / 展开信封"]
 if clue.is_empty(): return
 var b=UI.button(parent,clue[2],Rect2(0,0,260,25),func(): _act(clue[0],clue[1]),UI.CYAN)
 b.custom_minimum_size=Vector2(0,25)
 b.size_flags_horizontal=SIZE_EXPAND_FILL
 b.clip_text=true
 b.set_meta("story_action",clue[0]); b.set_meta("clue_caption",clue[2])
 b.disabled=not state.allowed().has(clue[0])
 if b.disabled: b.text="已归档 · "+str(clue[2])

func _refresh_attachments(node: Node) -> void:
 for child in node.get_children():
  if child is Button and child.has_meta("story_action"):
   child.disabled=not state.allowed().has(str(child.get_meta("story_action")))
   child.text=("已归档 · " if child.disabled else "")+str(child.get_meta("clue_caption"))
  if child is Button and child.has_meta("confirm_serial"):
   child.disabled=confirmation.is_empty() or child.get_meta("confirm_serial")!=confirmation.get("serial",-1) or confirmation.get("stamp","")!=_state_stamp()
  if child is Label and child.has_meta("confirmation_title"):
   child.text="◇ 医生签名 / 等待确认" if not confirmation.is_empty() and child.get_meta("confirmation_title")==confirmation.get("serial",-1) else "◇ 医生签名 / 历史记录"
  _refresh_attachments(child)

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
 if id=="sign": _confirm_pending(int(value)); return
 if id=="unsign": _decline_confirmation(int(value)); return
 if cinema.running: return
 if id=="instrument":
  _instrument(value); return
 _request_action(id,value,false)

func _request_action(id: String,value: Variant=null,from_chat: bool=true) -> void:
 if id!="reboot" and not state.allowed().has(id): return
 if Router.signature(state,id,value) or from_chat and (id=="accept" or Router.protected(state,id,value)): _request_confirmation(id,value,from_chat)
 else: _execute_action(id,value,from_chat)

func _execute_action(id: String,value: Variant=null,from_chat: bool=false) -> void:
 if id=="reboot": _reboot(); return
 if not state.allowed().has(id): return
 confirmation={}
 _cancel_ai(false); ai_focus="none"
 _flush_chat()
 var old=ImageTexture.create_from_image(get_viewport().get_texture().get_image().get_region(_stage_rect()))
 var price=_action_price(id,value)
 if profile.available()<price:
  pending.append(["sys","这次需要 %dT，可用 %dT。先去维修站完成一单可赚6T；诊疗进度会保留。"%[price,profile.available()]])
  _refresh(); _show_workshop(); return
 var result=state.dispatch(id,value)
 if not result.ok: return
 profile.spend(price,"接诊检查" if id=="accept" else "本轮治疗")
 if state.phase==Case.Phase.END: profile.record_case(state)
 follow_chat=true
 if result.get("retract",false): _retract_message()
 pending=Story.event(state,result)
 if id=="accept": pending.append(["sys","已接诊 / −%dT。本轮的检查、线索和对白不再另外收费。"%price])
 if result.get("phase_changed",false): pending.append_array(Story.opening(state))
 if from_chat:
  pending=pending.filter(func(line):return line[0]!="you")
  if id=="receipt": pending.push_front(["tool","已对照原始回执：17是审计记录器，42是维护写入，73是患者。标签与原始身份不一致。"])
 feedback=""
 _refresh()
 if not str(result.get("beat","")).is_empty():
  cinema.play(Story.beat(result.beat,state),old,reduced_motion or self_testing)
  if is_instance_valid(ambience_player) and result.beat in ["silence","erase_line","forgery"]: ambience_player.volume_db=-40
  _sound("reboot" if state.phase==Case.Phase.END else "error" if result.beat in ["erase_line","forgery","redline"] else "scan")
 else: _sound("click")
 _save_case()

func _request_confirmation(id: String,value: Variant=null,from_chat: bool=true) -> void:
 var info=Router.confirmation(state,id,value)
 if id=="accept": info={"title":"接诊检查 · 4T","detail":"接通检查仪，开始本轮诊疗。检查、线索和剧情对白不再逐条收费。钱包不足时可以先修设备。","phrase":"确认接诊"}
 if info.is_empty(): return
 if not confirmation.is_empty() and confirmation.id==id and confirmation.value==value and confirmation.stamp==_state_stamp():
  _follow_latest(); return
 _cancel_ai(false); _flush_chat(); _close_modal()
 confirmation_serial+=1
 info.id=id; info.value=value; info.from_chat=from_chat; info.serial=confirmation_serial; info.stamp=_state_stamp()
 info.summary=info.title+"\n"+info.detail+"\n\n尚未执行。在右侧检查台签字，或输入「"+info.phrase+"」；说「取消」可撤回。"
 confirmation=info
 if from_chat: _add_message(["confirm",info.summary],false)
 follow_chat=true; _refresh(); _follow_latest(); _save_case()

func _confirm_pending(serial: int,written: bool=false) -> void:
 if confirmation.is_empty() or confirmation.serial!=serial: return
 if confirmation.stamp!=_state_stamp():
  confirmation={}; pending.append(["sys","约定已经变化，这份待确认记录已失效。请重新提出本次操作。"]); _refresh(); return
 var selected=confirmation.duplicate(true)
 confirmation={}; _flush_chat()
 if not written: _add_message(["you",selected.phrase],false)
 _execute_action(selected.id,selected.value,bool(selected.from_chat))
 _refresh(); _save_case()

func _decline_confirmation(serial: int,written: bool=false) -> void:
 if confirmation.is_empty() or confirmation.serial!=serial: return
 confirmation={}
 if not written: _add_message(["you","暂不执行。"],false)
 pending.append(["echo","好。这次没有签字，我们继续谈。"])
 _refresh(); _save_case()

func _retract_message() -> void:
 var copy=history_data.duplicate(true)
 for i in range(copy.size()-1,-1,-1):
  if copy[i][0]=="echo" and str(copy[i][1]).contains("我的自述是"):
   copy[i][0]="withdrawn"
   break
 UI.clear(history)
 history_data=[]
 rebuilding=true
 for line in copy: _add_message(line,false)
 rebuilding=false

func _cinema_finished() -> void:
 if is_instance_valid(ambience_player): ambience_player.volume_db=-23
 if lounge_open!=(not profile.contacts.is_empty()): _layout(true)
 _follow_latest(); _save_case()

func _ask(raw: String) -> void:
 var text=raw.strip_edges()
 if text.is_empty(): return
 if text.length()>500: footer.text="每条消息最多 500 字。"; return
 if cinema.running: cinema.finish()
 if text in ["提示","卡住","下一步","我卡住了"]:
  composer.clear(); _show_hint(); return
 var clean=text.trim_suffix("。").trim_suffix("！").trim_suffix("!")
 if not confirmation.is_empty():
  if clean==confirmation.phrase or clean in ["确认","签字","确认本次","签字确认"]:
   composer.clear(); _flush_chat(); _add_message(["you",text]); _confirm_pending(int(confirmation.serial),true); return
  if clean in ["取消","暂不执行","先不执行","先不确认"]:
   composer.clear(); _flush_chat(); _add_message(["you",text]); _decline_confirmation(int(confirmation.serial),true); return
  if clean in ["好的","可以","嗯","同意"]:
   composer.clear(); _flush_chat(); _add_message(["you",text])
   pending.append(["echo","我需要知道你同意的是哪一件事。请用待确认记录里的那句「"+confirmation.phrase+"」。"])
   _save_case(); return
 var local_intent=Router.local_intent(state,text)
 var action=Router.resolve(state,local_intent,text,text) if local_intent!="none" else {}
 if not action.is_empty():
  composer.clear(); _cancel_ai(false); _flush_chat(); _add_message(["you",text]); _request_action(action.id,action.value,true); return
 if ai.busy:
  ai_status="仍在回应；可按 ■ 取消，再发送新消息。"
  footer.text=ai_status
  return
 confirmation={}
 _flush_chat(); composer.clear(); follow_chat=true
 _add_message(["you",text],false)
 if state.phase==Case.Phase.END:
  pending.append(["sys","本轮接诊已结束。康复患者可以在左侧休息室继续聊天；重开会恢复诊室中的患者，病历和联系人保留。"])
 elif Router.boundary(text):
  pending.append(["echo_local",Router.redirect(state,ai_turn)]); ai_turn+=1
 elif not ai.enabled:
  _local_reply(text)
  footer.text="当前使用本地备用对白。点聊天右上角 AI 可连接 DeepSeek。"
 elif profile.available()<1:
  pending.append(["sys","聊天需要1T。左下角维修站随时开放，每单赚6T；调查与查看线索免费。"])
 else:
  if not profile.hold("clinic",1): return
  ai_stamp=_state_stamp(); ai_question=text; ai_probe=false
  var ctx=Director.context(state,history_data.slice(0,-1),text)
  ai_ticket=ai.send(Director.SYSTEM,ctx)
  if ai_ticket<0:
   profile.release("clinic")
   ai_status=ai.settings_error()
   pending.append(["sys",ai_status]); _local_reply(text)
 _refresh(); _save_case()

func _state_stamp() -> String:
 var stamp=state.snapshot()
 stamp.erase("hint_level"); stamp.erase("tokens")
 return JSON.stringify(stamp)

func _local_reply(raw: String) -> void:
 var scratch=Case.new(); scratch.restore(state.snapshot())
 var response=scratch.ask(raw)
 if response.ok: state.asked=scratch.asked.duplicate()
 var line=str(response.text) if response.ok else Director.local_reply(state,raw,ai_turn)
 # The backup must pass the same disclosure boundary as online dialogue.
 if not Director.validate_text({"reply":line,"focus":"none"},state).ok: line=Director.local_reply(state,raw,ai_turn)
 ai_turn+=1
 pending.append(["echo_local",line])

func _cancel_ai(notify_player: bool) -> void:
 profile.release("clinic")
 if not ai.busy: return
 ai.cancel(); ai_ticket=-1; ai_probe=false
 ai_status="已停止等待；未扣游戏 T。"
 if notify_player: pending.append(["sys",ai_status])
 _refresh(); _save_case()

func _ai_completed(ticket: int, result: Dictionary) -> void:
 if ticket!=ai_ticket: return
 ai_ticket=-1
 if ai_probe:
  ai_probe=false
  var valid=result.ok and Director.validate_text(result.get("value"),Case.new()).ok
  ai_status="连接测试通过。点「接入会话」即可开始。" if valid else result.get("error","服务返回格式不符合约定。")
  if is_instance_valid(ai_status_label): ai_status_label.text=ai_status
  _refresh(); return
 if ai_stamp!=_state_stamp(): profile.release("clinic"); _refresh(); return
 if result.ok:
  result=Director.validate(result.value,state,ai_question)
  if not result.ok:
   result.error="自由回复未通过角色与剧情检查，使用备用对白。未扣游戏 T。"
   result.guarded=true
 if result.ok:
  if result.scope=="redirect":
   profile.release("clinic")
   pending.append(["echo_local",Router.redirect(state,ai_turn)]); ai_turn+=1
   _refresh(); _save_case(); return
  if result.intent!="none":
   var action=Router.resolve(state,result.intent,ai_question,result.quote)
   if not action.is_empty():
    profile.release("clinic")
    ai_status="已接上当前调查"
    _request_action(action.id,action.value,true)
    return
  if not profile.settle("clinic","回声 / 补充问诊"): return
  ai_focus=result.focus
  pending.append(["echo_ai",result.reply])
  ai_status="DeepSeek 已回应"
 else:
  profile.release("clinic")
  ai_status=result.get("error","未收到有效回复。")
  if not result.get("guarded",false): pending.append(["sys",ai_status])
  _local_reply(ai_question)
 _refresh(); _save_case()

func _ai_line(root: Control, value: String, y: int, secret: bool=false) -> LineEdit:
 var field=LineEdit.new(); field.position=Vector2(224,y)
 field.text=value; field.secret=secret; field.max_length=200 if secret else 100
 field.add_theme_stylebox_override("normal",UI.style(Color("183552"),Color("416e98")))
 field.add_theme_stylebox_override("focus",UI.style(Color("183552"),UI.CYAN))
 field.add_theme_color_override("font_color",UI.PAPER)
 root.add_child(field); field.size=Vector2(438,28)
 return field

func _show_ai_settings() -> void:
 if cinema.running: cinema.finish()
 _close_modal()
 modal=Control.new(); modal.size=Vector2(800,480); modal.z_index=100; stage.add_child(modal)
 var shade=ColorRect.new(); shade.size=Vector2(800,480); shade.color=Color(0.01,0.03,0.08,0.9); modal.add_child(shade)
 UI.panel(modal,Rect2(100,48,600,386),Color("10243e"),UI.BLUE)
 UI.label(modal,"让回声自由回应 / DeepSeek",Rect2(121,65,532,26),UI.BLUE)
 UI.button(modal,"×",Rect2(662,59,26,26),_close_modal,UI.MUTED)
 UI.text(modal,"接入后，你发送的文字、近期对话和已公开病历将发给 DeepSeek。\n模型服务按你的账户计费；游戏 T 只是剧情资源。",Rect2(124,105,550,40),UI.PAPER)
 UI.label(modal,"官方接口",Rect2(124,154,98,22),UI.MUTED)
 UI.label(modal,"https://api.deepseek.com/chat/completions",Rect2(224,154,440,22),UI.CYAN)
 UI.label(modal,"模型",Rect2(124,191,92,24),UI.MUTED)
 var model_field=_ai_line(modal,ai.model,188)
 UI.label(modal,"API Key",Rect2(124,231,92,24),UI.MUTED)
 var key_field=_ai_line(modal,ai.api_key,228,true)
 key_field.placeholder_text="在此粘贴 DeepSeek 密钥（仅本次运行）"
 ai_form={"model":model_field,"key":key_field}
 UI.text(modal,"密钥不写入存档或发布包。退出后需重填；也可用 DEEPSEEK_API_KEY。\n测试连接会发送一条短消息。等待时可取消或继续推进剧情。",Rect2(124,269,548,40),UI.MUTED)
 ai_status_label=UI.text(modal,ai_status,Rect2(124,319,550,43),UI.GOLD)
 UI.button(modal,"测试连接",Rect2(124,381,165,31),_test_ai_connection,UI.CYAN)
 UI.button(modal,"接入会话",Rect2(308,381,165,31),_enable_ai,UI.BLUE,true)
 UI.button(modal,"本地模式",Rect2(492,381,183,31),func():
  _cancel_ai(false); companions.cancel(); ai.enabled=false; ai_status="已切换本地备用对白"; _close_modal(); _refresh(),UI.MUTED)

func _apply_ai_form() -> bool:
 companions.cancel()
 _cancel_ai(false)
 ai.model=ai_form.model.text.strip_edges(); ai.api_key=ai_form.key.text.strip_edges()
 ai_status=ai.settings_error()
 if not ai_status.is_empty():
  if is_instance_valid(ai_status_label): ai_status_label.text=ai_status
  return false
 return true

func _test_ai_connection() -> void:
 if not _apply_ai_form(): return
 ai_probe=true
 ai_status="正在测试 DeepSeek…"
 ai_status_label.text=ai_status
 ai_ticket=ai.send('仅输出 JSON：{"reply":"连接已建立。","focus":"none"}',{"message":"连接测试，不含游戏记录。"})
 _refresh()

func _enable_ai() -> void:
 if not _apply_ai_form(): return
 ai.enabled=true; ai_status="DeepSeek 已启用，等待你的消息"
 if not self_testing and not qa_mode:
  var cfg=ConfigFile.new(); cfg.set_value("ai","model",ai.model); cfg.save("user://ai-v5.cfg")
 _close_modal(); _refresh()
 composer.grab_focus()

func _modal_frame(title: String) -> Control:
 _close_modal()
 modal=Control.new(); modal.size=Vector2(800,480); modal.z_index=100; stage.add_child(modal)
 var shade=ColorRect.new(); shade.size=Vector2(800,480); shade.color=Color(0.01,0.03,0.08,0.83); modal.add_child(shade)
 UI.panel(modal,Rect2(155,94,490,290),Color("10243e"),UI.BLUE)
 UI.label(modal,title,Rect2(173,110,435,24),UI.BLUE)
 UI.button(modal,"×",Rect2(609,102,26,26),_close_modal,UI.MUTED)
 return modal

func _show_hint() -> void:
 if cinema.running: cinema.finish()
 var root=_modal_frame("提示便签 / "+state.objective())
 var level=clampi(state.hint_level,0,2)
 UI.label(root,["观察方向","推理线索","直接解法"][level],Rect2(177,150,440,18),UI.GOLD)
 UI.text(root,state.hints()[level],Rect2(177,184,440,100),UI.PAPER)
 UI.label(root,"不会扣除 T，也不会改动仪器。",Rect2(177,289,440,18),UI.MUTED)
 UI.button(root,"回去试试",Rect2(177,330,210,31),_close_modal,UI.BLUE,true)
 var b=UI.button(root,"再给一级提示",Rect2(401,330,220,31),func(): state.hint_level=mini(2,state.hint_level+1); _show_hint(); _save_case(),UI.GOLD)
 b.disabled=level==2

func _old_journal() -> void:
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
 if is_instance_valid(modal): modal.get_parent().remove_child(modal); modal.queue_free()
 modal=null

func _reboot_prompt() -> void:
 if cinema.running: cinema.finish()
 _request_action("reboot",null,false)

func _reboot() -> void:
 confirmation={}
 _cancel_ai(false); ai_focus="none"
 _close_modal(); cinema.finish(); _flush_chat()
 var old=ImageTexture.create_from_image(get_viewport().get_texture().get_image().get_region(_stage_rect()))
 state.reboot()
 _add_message(["sys","──── 医生记录保留 / 患者快照恢复 ────"],false)
 pending=Story.opening(state); feedback=""
 _refresh(); cinema.play(Story.beat("rewind",state),old,reduced_motion or self_testing)
 _save_case(); _sound("reboot")

func _save_case() -> void:
 if self_testing or qa_mode: return
 save_error=not _write_save(SAVE_PATH)
 if save_error: footer.text="存档写入失败。请保持本窗口，暂勿关闭。"

func _write_save(path: String) -> bool:
 var data=state.snapshot(); data.profile=profile.snapshot(); data.ui={"history":history_data.duplicate(true),"pending":pending.duplicate(true),"ai_interrupted":ai.busy and not ai_probe,"confirmation_interrupted":not confirmation.is_empty()}
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if not file: return false
 file.store_string(JSON.stringify(data)); file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

func _load_case() -> bool:
 var path=SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else "user://case-v6.json" if FileAccess.file_exists("user://case-v6.json") else "user://case-v5.json" if FileAccess.file_exists("user://case-v5.json") else "user://case-v4.json"
 if not FileAccess.file_exists(path): return false
 var value=JSON.parse_string(FileAccess.get_file_as_string(path))
 var restored_case=Case.new()
 var restored_profile=Profile.new()
 if not value is Dictionary or not restored_case.restore(value): return false
 if path==SAVE_PATH:
  if not restored_profile.restore(value.get("profile")): return false
 state=restored_case; profile=restored_profile
 if path!=SAVE_PATH:
  for outcome in state.endings:
   if outcome in ["bridge","witness"]: profile.unlock("echo",outcome)
  pending.append(["sys","旧病历已继承。诊所钱包从24T开始，之后与重开分开保存；旧版文件保留。"])
 state.tokens=profile.balance
 _restore_conversation(value.get("ui",{}))
 companions.profile=profile; companions.refresh(); companions.render_history()
 _layout(false)
 return true

func _restore_conversation(ui: Variant) -> void:
 # A saved card is a record of an unsigned proposal, never a reusable capability.
 confirmation={}
 if ui is Dictionary:
  for line in ui.get("history",[]):
   if line is Array and line.size()==2: _add_message(line,false)
  for line in ui.get("pending",[]):
   if line is Array and line.size()==2: pending.append(line)
  if ui.get("ai_interrupted",false): pending.append(["sys","上次等待自由回复时会话中断，未扣游戏 T。重新接入 AI 后可再问；剧情进度已经保留。"])
  if ui.get("confirmation_interrupted",false): pending.append(["sys","上次尚未确认的操作没有执行，待确认记录已过期。需要时请重新提出。"])

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
 ambience_player=audio

func capture(name: String) -> void:
 if capture_dir.is_empty(): return
 DirAccess.make_dir_recursive_absolute(capture_dir)
 await RenderingServer.frame_post_draw
 var img=get_viewport().get_texture().get_image(); img.resize(1650,900,Image.INTERPOLATE_NEAREST)
 img.save_png(capture_dir+"/"+name+".png")

func _run_tests() -> void:
 var suite=load("res://scripts/v7/tests.gd").new()
 await suite.run(self)

func _action_price(id: String,value: Variant=null) -> int:
 if id=="accept": return Profile.EXAM
 if id=="commit" or id=="decide" and value in ["erase","release"]: return Profile.CARE
 return 0

func _profile_changed() -> void:
 _refresh(); _save_case()

func _show_workshop() -> void:
 cinema.finish(); _close_modal()
 modal=Workshop.new(); modal.z_index=100; add_child(modal)
 modal.setup(profile)
 modal.changed.connect(_profile_changed)
 modal.closed.connect(_close_modal)

func _journal_frame(tab: String) -> Control:
 cinema.finish(); _close_modal()
 modal=Control.new(); modal.size=Vector2(1100,600); modal.z_index=100; add_child(modal)
 var shade=ColorRect.new(); shade.size=modal.size; shade.color=Color(0.01,0.03,0.08,0.94); modal.add_child(shade)
 UI.panel(modal,Rect2(110,30,880,540),Color("10243e"),UI.BLUE)
 UI.label(modal,"夜班病历夹",Rect2(132,48,400,30),UI.BLUE,24)
 UI.button(modal,"×",Rect2(941,43,30,30),_close_modal,UI.MUTED)
 var keys=["summary","evidence","visits","wallet"]
 var labels=["本次接诊","线索卡片","历次结果","钱包账本"]
 for i in range(4): UI.button(modal,labels[i],Rect2(132+i*211,94,196,30),func():_show_journal(keys[i]),UI.BLUE if tab==keys[i] else UI.MUTED,tab==keys[i])
 return modal

func _show_journal(tab: String="summary") -> void:
 var root=_journal_frame(tab)
 if tab=="summary":
  UI.label(root,"回声 / E-017 · 第 %02d 次接诊"%state.loop,Rect2(134,145,810,24),UI.PURPLE)
  var symptom="她说自己一想到离开就疼。院方建议清空记忆；你还没有接受这个方案。"
  if state.phase>=2: symptom="改写程序已经暂停，她说不疼了。但她想离开的原因，还需要慢慢谈。"
  if state.phase==6: symptom="本轮已结束："+_outcome_name(state.ending)+"。重开不会清空病历、联系人或钱包。"
  UI.panel(root,Rect2(132,184,834,95),Color("183351"),Color("41648a"))
  UI.label(root,"她怎么了",Rect2(148,194,790,22),UI.CYAN)
  UI.text(root,symptom,Rect2(148,226,790,43),UI.PAPER)
  UI.label(root,"现在的疑点",Rect2(148,299,790,22),UI.GOLD)
  UI.text(root,state.objective(),Rect2(148,333,790,42),UI.PAPER)
  UI.label(root,"可以从这里接着做",Rect2(148,391,790,22),UI.CYAN)
  UI.text(root,_next_step(),Rect2(148,425,790,45),UI.PAPER)
  UI.button(root,"回到检查台",Rect2(132,510,400,34),_close_modal,UI.BLUE,true)
  UI.button(root,"去维修站赚算力",Rect2(548,510,418,34),_show_workshop,UI.CYAN)
  return
 var sc=ScrollContainer.new(); sc.position=Vector2(132,143); sc.size=Vector2(834,352); sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(sc)
 var rows=VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",12); sc.add_child(rows)
 if tab=="evidence":
  if state.evidence.is_empty(): _journal_card(rows,"还没有检查结果","可以先到右侧接诊。发现的异常会自动变成线索卡片。",UI.MUTED)
  for key in state.evidence:
   if Case.EVIDENCE.has(key): _journal_card(rows,Case.EVIDENCE[key][0],Case.EVIDENCE[key][1]+"\n来源：医生已完成的检查 / 重开保留",UI.CYAN)
 elif tab=="visits":
  if profile.records.is_empty(): _journal_card(rows,"本轮仍在进行","结束接诊后，会记录治疗选择和结果。已知线索不会因为失败而消失。",UI.MUTED)
  for record in profile.records:
   _journal_card(rows,"第 %02d 诊 / %s"%[record.loop,_outcome_name(record.ending)],"本次保存 %d 条已发现线索。"%record.evidence.size(),UI.CYAN if record.ending in ["bridge","witness"] else UI.PINK)
  for id in profile.contacts: _journal_card(rows,"已康复 / "+Companions.NAMES[id],"可以在左侧休息室选择对方。各自的聊天记录单独保存。",UI.PURPLE)
 elif tab=="wallet":
  _journal_card(rows,"余额 %dT / 可用 %dT"%[profile.balance,profile.available()],"维修 +6T；检查 −4T；治疗 −8T；有效在线回复 −1T。\n首次康复回声补贴 +6T，只领一次。失败、取消和拦截的回复不扣 T。\n游戏 T 不能兑换 API 余额；DeepSeek 另按你的账户收费。",UI.GOLD)
  for i in range(profile.ledger.size()-1,-1,-1):
   var entry=profile.ledger[i]
   _journal_card(rows,("+" if entry.amount>=0 else "")+str(int(entry.amount))+"T / "+str(entry.reason),"结余 %dT"%entry.balance,UI.CYAN if entry.amount>=0 else UI.MUTED)
 UI.button(root,"返回诊室",Rect2(132,515,834,29),_close_modal,UI.BLUE)

func _journal_card(parent: Control,title: String,body: String,color: Color) -> void:
 var card=PanelContainer.new(); card.size_flags_horizontal=SIZE_EXPAND_FILL; card.add_theme_stylebox_override("panel",UI.style(Color("152e49"),color.darkened(0.5))); parent.add_child(card)
 var box=VBoxContainer.new(); box.add_theme_constant_override("separation",9); card.add_child(box)
 var label=Label.new(); label.text=title; label.add_theme_color_override("font_color",color); box.add_child(label)
 var text=RichTextLabel.new(); text.fit_content=true; text.scroll_active=false; text.custom_minimum_size.x=800; text.text=body; text.add_theme_constant_override("line_separation",4); box.add_child(text)

func _next_step() -> String:
 match state.phase:
  0: return "右侧接诊按钮会打开一次检查（4T）。先听她说，再决定动哪一条线路。"
  1: return "把两次开场白放在一起看。旧检查已经复用，不必再做一遍。" if state.later() else "点右侧三个进程节点，看它们分别在干什么。别急着相信患者写的名字。"
  2: return "先看旧留言。出现许可消息时，留意有没有你的签字。" if state.later() else "拖动右侧录音进度条，听听断掉的那一段。文件消失后，检查台会保留修订历史。"
  3: return "打开信封，看它真正从哪里寄来。" if state.later() else "拖动右侧扫描线查看附件。看完后先暂存，去谈治疗；此时不会发送文件。"
  4: return "你可以先谈一份新方案。重置和送走她都会结束本次接诊，需要你明确确认。"
  5: return "点卡片调整方案，请她复述，再比较两份版本。先预演，最后才签字治疗（8T）。"
  _: return "可以重开看看她的新反应。若她已康复，也可以去左侧休息室聊聊。"

func _outcome_name(id: String) -> String:
 return {"bridge":"不疼了，也还是她","witness":"保住自己，和旧留言取得联系","erase":"稳定了，却忘了自己是谁","frozen":"记忆停在了今晚","release":"离开了，去向还不明"}.get(id,"尚未结束")

func _instrument(value: Variant) -> void:
 if not value is Dictionary: return
 var kind=str(value.get("kind","")); var amount=int(value.get("value",0))
 if kind=="node" and state.phase==1 and not state.later() and amount in [17,42,73]:
  for number in [17,42,73]: state.events["scan_node_%d"%number]=number==amount
  if amount==42 and not state.seen("receipt"): _request_action("receipt",null,false)
  else: _refresh(); _save_case()
 elif kind=="wave" and state.phase==2 and not state.later():
  if amount>=52 and not state.seen("memory_listen"): _request_action("memory_listen",null,false)
  elif amount<=18 and state.seen("memory_listen") and not state.seen("memory_undo"): _request_action("memory_undo",null,false)
 elif kind=="parcel" and state.phase==3 and not state.later() and amount>=62:
  if not state.evidence.has("manifest"): _request_action("file","manifest",false)

