extends Control
const UI=preload("res://scripts/v4/ui.gd")
const Case=preload("res://scripts/v4/case.gd")
const Story=preload("res://scripts/v4/story.gd")
const Bench=preload("res://scripts/v4/workbench.gd")
const Cinema=preload("res://scripts/v4/cinema.gd")
const Director=preload("res://scripts/v5/director.gd")
const AIClient=preload("res://scripts/v5/ai_client.gd")
const SAVE_PATH="user://case-v5.json"
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
 get_window().title="ECHO CLINIC / 夜班诊所 v0.5"+(" / 测试" if qa_mode else "")
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
 UI.label(chat,"回声 / ECHO",Rect2(48,5,155,18),UI.PAPER)
 ai_button=UI.button(chat,"AI 离线",Rect2(209,5,59,21),_show_ai_settings,UI.MUTED)
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
 UI.label(chat,"剧情免费 / AI 有效回复 2T",Rect2(19,375,236,16),UI.MUTED)
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
 if role=="ghost": panel.add_theme_stylebox_override("panel",UI.style(Color("372b43"),UI.PINK))
 row.add_child(panel)
 var body=VBoxContainer.new(); body.add_theme_constant_override("separation",4); panel.add_child(body)
 var name_label=Label.new()
 name_label.text={"echo":"◆ 回声", "echo_ai":"◆ 回声 · 自由对话", "echo_local":"◆ 回声 · 本地备用", "you":"你", "sys":"· 会话记录", "tool":"> 检查回执", "withdrawn":"◆ 回声 / 已撤回", "ghost":"你？ / 缺少医生签名", "other":"◇ 缓存中的声音"}.get(role,role)
 name_label.add_theme_color_override("font_color",UI.PINK if role=="ghost" else UI.CYAN if role=="other" else UI.BLUE if user else UI.CYAN if tool else UI.PURPLE)
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
 text_label.add_theme_color_override("default_color",UI.MUTED if tool else UI.PAPER)
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
 if cinema.running: return
 if id=="reboot": _reboot(); return
 if not state.allowed().has(id): return
 _cancel_ai(false); ai_focus="none"
 _flush_chat()
 var old=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
 var result=state.dispatch(id,value)
 if not result.ok: return
 follow_chat=true
 if result.get("retract",false): _retract_message()
 pending=Story.event(state,result)
 if result.get("phase_changed",false): pending.append_array(Story.opening(state))
 feedback=""
 _refresh()
 if not str(result.get("beat","")).is_empty():
  cinema.play(Story.beat(result.beat,state),old,reduced_motion or self_testing)
  if is_instance_valid(ambience_player) and result.beat in ["silence","erase_line","forgery"]: ambience_player.volume_db=-40
  _sound("reboot" if state.phase==Case.Phase.END else "error" if result.beat in ["erase_line","forgery","redline"] else "scan")
 else: _sound("click")
 _save_case()

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
 _follow_latest(); _save_case()

func _ask(raw: String) -> void:
 var text=raw.strip_edges()
 if text.is_empty(): return
 if text in ["提示","卡住","下一步","我卡住了"]:
  composer.clear(); _show_hint(); return
 for reply in state.replies():
  if text==str(reply[1]):
   if cinema.running: cinema.finish()
   composer.clear(); _act(reply[0],reply[2]); return
 if state.phase==Case.Phase.ARRIVAL and text in ["开始","开始检查","接入","我听你说","先听你说"]:
  if cinema.running: cinema.finish()
  composer.clear(); _act("accept"); return
 if ai.busy:
  ai_status="仍在回应；可按 ■ 取消，再发送新消息。"
  footer.text=ai_status
  return
 if text.length()>500: footer.text="每条消息最多 500 字。"; return
 if cinema.running: cinema.finish()
 _flush_chat(); composer.clear(); follow_chat=true
 _add_message(["you",text],false)
 if state.phase==Case.Phase.END:
  pending.append(["sys","本轮患者会话已结束。病历保留；查看下一次接诊后，可以继续问她。"])
 elif not ai.enabled:
  _local_reply(text)
  footer.text="当前使用本地备用对白。点聊天右上角 AI 可连接 DeepSeek。"
 elif state.tokens<22:
  pending.append(["sys","20T 治疗额度已保留，补充问诊暂停。关键回复和线索仍然免费。"])
 else:
  ai_stamp=_state_stamp(); ai_question=text; ai_probe=false
  var ctx=Director.context(state,history_data.slice(0,-1),text)
  ai_ticket=ai.send(Director.SYSTEM,ctx)
  if ai_ticket<0:
   ai_status=ai.settings_error()
   pending.append(["sys",ai_status]); _local_reply(text)
 _refresh(); _save_case()

func _state_stamp() -> String:
 var stamp=state.snapshot()
 stamp.erase("hint_level")
 return JSON.stringify(stamp)

func _local_reply(raw: String) -> void:
 var scratch=Case.new(); scratch.restore(state.snapshot())
 var response=scratch.ask(raw)
 var line=str(response.text) if response.ok else Director.local_reply(state,raw,ai_turn)
 # The backup must pass the same disclosure boundary as online dialogue.
 if not Director.validate({"reply":line,"focus":"none"},state).ok: line=Director.local_reply(state,raw,ai_turn)
 ai_turn+=1
 pending.append(["echo_local",line])

func _cancel_ai(notify_player: bool) -> void:
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
  var valid=result.ok and Director.validate(result.get("value"),Case.new()).ok
  ai_status="连接测试通过。点「接入会话」即可开始。" if valid else result.get("error","服务返回格式不符合约定。")
  if is_instance_valid(ai_status_label): ai_status_label.text=ai_status
  _refresh(); return
 if ai_stamp!=_state_stamp(): _refresh(); return
 if result.ok:
  result=Director.validate(result.value,state)
  if not result.ok: result.error="这条自由回复未通过剧情边界检查，已使用备用对白。未扣游戏 T。"
 if result.ok:
  state.tokens-=2
  ai_focus=result.focus
  pending.append(["echo_ai",result.reply])
  ai_status="DeepSeek 已回应"
 else:
  ai_status=result.get("error","未收到有效回复。")
  pending.append(["sys",ai_status])
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
 modal=Control.new(); modal.size=Vector2(800,480); modal.z_index=100; add_child(modal)
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
  _cancel_ai(false); ai.enabled=false; ai_status="已切换本地备用对白"; _close_modal(); _refresh(),UI.MUTED)

func _apply_ai_form() -> bool:
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
 UI.text(root,"患者快照将恢复。\n医生病历、旧句子与已见结局会保留。\n\n下一轮会进入差异调查，不需要重复旧检查。",Rect2(177,164,440,111),UI.PAPER)
 UI.button(root,"继续本轮",Rect2(177,330,210,31),_close_modal,UI.BLUE)
 UI.button(root,"携带病历重开",Rect2(401,330,220,31),_reboot,UI.PURPLE)

func _reboot() -> void:
 _cancel_ai(false); ai_focus="none"
 _close_modal(); cinema.finish(); _flush_chat()
 var old=ImageTexture.create_from_image(get_viewport().get_texture().get_image())
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
 var data=state.snapshot(); data.ui={"history":history_data.duplicate(true),"pending":pending.duplicate(true),"ai_interrupted":ai.busy and not ai_probe}
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if not file: return false
 file.store_string(JSON.stringify(data)); file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

func _load_case() -> bool:
 var path=SAVE_PATH if FileAccess.file_exists(SAVE_PATH) else "user://case-v4.json"
 if not FileAccess.file_exists(path): return false
 var value=JSON.parse_string(FileAccess.get_file_as_string(path))
 if not value is Dictionary or not state.restore(value): return false
 var ui=value.get("ui",{})
 if ui is Dictionary:
  for line in ui.get("history",[]):
   if line is Array and line.size()==2: _add_message(line,false)
  for line in ui.get("pending",[]):
   if line is Array and line.size()==2: pending.append(line)
  if ui.get("ai_interrupted",false): pending.append(["sys","上次等待自由回复时会话中断，未扣游戏 T。重新接入 AI 后可再问；剧情进度已经保留。"])
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
 ambience_player=audio

func capture(name: String) -> void:
 if capture_dir.is_empty(): return
 DirAccess.make_dir_recursive_absolute(capture_dir)
 await RenderingServer.frame_post_draw
 var img=get_viewport().get_texture().get_image(); img.resize(1600,960,Image.INTERPOLATE_NEAREST)
 img.save_png(capture_dir+"/"+name+".png")

func _run_tests() -> void:
 var suite=load("res://scripts/v5/tests.gd").new()
 await suite.run(self)

