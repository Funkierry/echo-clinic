extends Control
const UI=preload("res://scripts/v9/ui.gd")
const Case=preload("res://scripts/v9/case.gd")
const Story=preload("res://scripts/v9/story.gd")
const Bench=preload("res://scripts/v9/workbench.gd")
const Cinema=preload("res://scripts/v9/cinema.gd")
const Director=preload("res://scripts/v9/director.gd")
const Router=preload("res://scripts/v9/dialogue_router.gd")
const AIClient=preload("res://scripts/v5/ai_client.gd")
const Profile=preload("res://scripts/v9/profile.gd")
const Workshop=preload("res://scripts/v9/workshop.gd")
const Companions=preload("res://scripts/v9/companions.gd")
const Desktop=preload("res://scripts/v9/desktop.gd")
const Win=preload("res://scripts/v9/window.gd")
const Slot=preload("res://scripts/v9/slot.gd")
const AppTaskMgr=preload("res://scripts/v9/app_taskmgr.gd")
const AppMonitor=preload("res://scripts/v9/app_monitor.gd")
const HoldSign=preload("res://scripts/v9/hold_sign.gd")
const Icons=preload("res://scripts/v9/icons.gd")
const Juice=preload("res://scripts/v9/juice.gd")
const Saves=preload("res://scripts/v9/saves.gd")
const Menu=preload("res://scripts/v9/menu.gd")
const Coach=preload("res://scripts/v9/coach.gd")
const Boot=preload("res://scripts/v9/boot.gd")
const FACES=preload("res://assets/v2/echo-expressions.png")
var profile=Profile.new()
var desktop: Control
var hidden_holder: Control
var chat_window: Control
var present_slot: Control
var rent_clock: float=0.0
var rent_capped_notice: bool=false
## Intel + evidence already paid for as anomaly reports; -1 until the night's baseline is taken.
var anomaly_seen: int=-1
var anomaly_rewards: bool=true
var anomaly_test: bool=false
var apps_stamp: String=""
var companions: Control
# Story beats and modals still play on an 800×480 stage over the desktop.
var stage: Control
var lounge_open: bool=false
var wallet_button: Button
var price_label: Button
var bounty_button: Button
var buyer_button: Button
var status_bar: Control
var footer_row: Control
var stdout: Control
var avatar: TextureRect
var post_mat: ShaderMaterial
var glitch_level: float=0.0
var current_mood: String="calm"
var shown_balance: int=-1
var last_balance: int=0
var wallet_tween: Tween
var juice: Control
var typing_row: Label
var reboot_button: Button
var shown_footer: Dictionary={}
var menu: Control
var coach: Control
var pause_shot: Image
var outsource_button: Button
var auto_thumb_at: int=0
## False while the title screen is up: nothing autosaves until the player picks continue, new or load.
var session_live: bool=false
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
var probe_mode: bool=false
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
  if arg=="--npc-probe": qa_mode=true; probe_mode=true
  if arg=="--setup-ai": open_ai_on_start=true
  if arg.begins_with("--capture-dir="): capture_dir=arg.trim_prefix("--capture-dir=")
 var th=Theme.new()
 th.default_font=UI.sans()
 th.default_font_size=12
 theme=th
 texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
 get_window().title="ECHO CLINIC / 夜班诊所 v0.9.1 原型"+(" / 测试" if qa_mode else "")
 ai=AIClient.new(); add_child(ai)
 ai.completed.connect(_ai_completed)
 if not self_testing and not qa_mode:
  ai.api_key=OS.get_environment("DEEPSEEK_API_KEY").strip_edges()
  var ai_cfg=ConfigFile.new()
  if ai_cfg.load("user://ai-v5.cfg")==OK: ai.model=str(ai_cfg.get_value("ai","model",AIClient.DEFAULT_MODEL))
 _build_ui()
 # Tests drive the screens directly; teaching bubbles would sit on top of the controls they click.
 if self_testing or qa_mode: coach.enabled=false
 _load_preferences()
 _open_night()
 if not self_testing and not qa_mode:
  # Every launch starts at the title; "继续" picks up the autosave.
  Saves.migrate_legacy()
  menu.open("title")
 _refresh()
 if not self_testing: _ambience()
 if self_testing: call_deferred("_run_tests")
 elif probe_mode: call_deferred("_run_probe")
 elif open_ai_on_start: call_deferred("_show_ai_settings")

## First screen of a fresh night: her portrait card, the handover note, then her opening lines.
func _open_night() -> void:
 _add_message(["card","calm"],false)
 _add_message(["note",Story.handover(state)],false)
 _add_message(["sys","夜雨 / E-017 / 私人诊疗会话"],false)
 pending=_opening()

func _opening() -> Array:
 return Story.opening(state).filter(func(line): return line[0]!="you")

## Each new intel or evidence entry is an anomaly report the clinic pays for.
func _anomaly_check() -> void:
 var n=state.intel.size()+state.evidence.size()
 if anomaly_seen<0 or n<anomaly_seen: anomaly_seen=n; return
 if n==anomaly_seen: return
 var gain=n-anomaly_seen
 anomaly_seen=n
 if not anomaly_rewards or self_testing and not anomaly_test: return
 profile.earn(gain,"异常报告")
 desktop.toast("异常报告已提交 +%dT"%gain,UI.GOLD)

## Apps rebuild only when something they show has changed.
func _refresh_desktop() -> void:
 desktop.set_status("23:%02d"%mini(59,47+state.phase*2),desktop.tray_wallet.text,profile.renting,muted)
 var signing=not confirmation.is_empty()
 if signing and not desktop.is_open("sign"): desktop.open("sign")
 elif not signing and desktop.is_open("sign"): desktop.close("sign")
 var stamp=_state_stamp()+str(profile.balance)+str(profile.renting)+current_mood+str(profile.contacts.size())+str(confirmation.get("serial",-1))
 if stamp==apps_stamp: return
 apps_stamp=stamp
 desktop.refresh_all()

func _exit_tree() -> void:
 UI.release()

func _build_ui() -> void:
 # The whole screen is the clinic workstation. Chat is a docked window on the left; tools are apps.
 desktop=Desktop.new(); add_child(desktop); desktop.setup(self)
 desktop.set_apps(APPS)
 desktop.app_opened.connect(func(id): coach.done("apps" if id=="taskmgr" else "apps_"+id))
 hidden_holder=Control.new(); hidden_holder.visible=false; hidden_holder.size=Vector2(800,480); add_child(hidden_holder)
 # Legacy controls kept for code that still reads them; they live off-screen.
 status_bar=Control.new(); hidden_holder.add_child(status_bar)
 metric=UI.label(status_bar,"",Rect2(0,0,200,16),UI.MUTED)
 wallet_button=desktop.tray_wallet
 sound_button=UI.button(status_bar,"",Rect2(0,0,10,10),_toggle_mute,UI.MUTED)
 motion_button=UI.button(status_bar,"",Rect2(0,0,10,10),_toggle_motion,UI.MUTED)
 footer_row=Control.new(); hidden_holder.add_child(footer_row)
 footer=UI.label(footer_row,"",Rect2(0,0,200,16),UI.MUTED)
 bounty_button=UI.button(footer_row,"工单",Rect2(0,0,60,20),_show_bounty,UI.GOLD)
 buyer_button=UI.button(footer_row,"收购",Rect2(0,0,60,20),_show_buyer,UI.PINK)
 journal_button=UI.button(footer_row,"病历",Rect2(0,0,60,20),_show_journal,UI.CYAN)
 outsource_button=UI.button(footer_row,"外包",Rect2(0,0,60,20),_show_workshop,UI.CYAN)
 reboot_button=UI.button(footer_row,"重开",Rect2(0,0,60,20),_reboot_prompt,UI.MUTED)
 # Docked chat window.
 chat_window=Win.new(); desktop.window_layer.add_child(chat_window)
 chat_window.setup("chat","回声 · 对话",Rect2(4,4,342,568),"talk",false,false)
 chat_window.movable=false
 chat=chat_window.client
 var cw=chat.size.x
 avatar=TextureRect.new(); avatar.position=Vector2(6,6); avatar.size=Vector2(30,30)
 avatar.texture=_face("calm"); avatar.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; avatar.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 avatar.mouse_filter=MOUSE_FILTER_IGNORE
 chat.add_child(avatar)
 UI.label(chat,"回声 E-017",Rect2(42,6,150,14),UI.PAPER)
 connection=UI.label(chat,"● 在线",Rect2(42,22,190,14),UI.CYAN)
 ai_button=UI.button(chat,"AI 离线",Rect2(cw-78,8,72,22),_show_ai_settings,UI.MUTED)
 var head_line=ColorRect.new(); head_line.position=Vector2(0,42); head_line.size=Vector2(cw,1); head_line.color=UI.FACE_LO; chat.add_child(head_line)
 var well=Panel.new(); well.position=Vector2(2,46); well.size=Vector2(cw-4,330); well.add_theme_stylebox_override("panel",UI.bevel(Color("0a0e16"),true)); well.mouse_filter=MOUSE_FILTER_IGNORE; chat.add_child(well)
 scroll=ScrollContainer.new()
 scroll.position=Vector2(6,50); scroll.size=Vector2(cw-12,322)
 scroll.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED
 scroll.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
 scroll.get_v_scroll_bar().custom_minimum_size.x=8
 scroll.get_v_scroll_bar().gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed: follow_chat=false)
 scroll.gui_input.connect(func(event):
  if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: follow_chat=false)
 chat.add_child(scroll)
 history=VBoxContainer.new(); history.size_flags_horizontal=SIZE_EXPAND_FILL; history.add_theme_constant_override("separation",10)
 scroll.add_child(history)
 # Evidence dropped anywhere on the conversation is shown to her.
 present_slot=Slot.new(); chat.add_child(present_slot)
 present_slot.setup("chat",Rect2(2,46,cw-4,330),["log:","file:","ev:","v1","v2"],"给她看",UI.GOLD)
 present_slot.ghost=true
 new_button=UI.button(chat,"↓ 最新",Rect2(cw-80,346,70,20),_follow_latest,UI.BLUE,true)
 new_button.visible=false
 UI.label(chat,"问她：",Rect2(6,380,60,14),UI.MUTED)
 suggestions=Control.new(); suggestions.position=Vector2(4,396); suggestions.size=Vector2(cw-8,74); chat.add_child(suggestions)
 var box=Panel.new(); box.position=Vector2(2,474); box.size=Vector2(cw-4,62); box.add_theme_stylebox_override("panel",UI.bevel(Color("0a0e16"),true)); box.mouse_filter=MOUSE_FILTER_IGNORE; chat.add_child(box)
 composer=LineEdit.new()
 composer.position=Vector2(8,478)
 composer.placeholder_text="自己打字问她…"
 composer.max_length=500
 composer.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
 composer.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
 composer.add_theme_font_override("font",UI.mono()); composer.add_theme_font_size_override("font_size",12)
 composer.add_theme_color_override("font_color",UI.PAPER)
 composer.add_theme_color_override("font_placeholder_color",UI.DIM)
 composer.add_theme_color_override("caret_color",UI.CYAN)
 composer.text_submitted.connect(_ask)
 chat.add_child(composer)
 composer.size=Vector2(cw-60,22)
 send_button=UI.button(chat,"发送",Rect2(cw-50,478,44,22),func():
  if ai.busy: _cancel_ai(true)
  else: _ask(composer.text),UI.CYAN,true)
 price_label=UI.button(chat,"",Rect2(6,508,cw-12,22),func(): desktop.open("monitor"),UI.MUTED)
 price_label.alignment=HORIZONTAL_ALIGNMENT_LEFT
 for key in ["normal","hover"]: price_label.add_theme_stylebox_override(key,StyleBoxEmpty.new())
 # Stage: an invisible 800×480 frame for story beats and screen grabs.
 stage=Control.new(); stage.position=Vector2(150,60); stage.size=Vector2(800,480); stage.mouse_filter=MOUSE_FILTER_IGNORE; add_child(stage)
 bench=Bench.new(); bench.size=Vector2(454,404)
 bench.action.connect(_act)
 hidden_holder.add_child(bench)
 stdout=null
 cinema=Cinema.new(); cinema.size=Vector2(800,480)
 cinema.completed.connect(_cinema_finished)
 stage.add_child(cinema)
 companions=Companions.new(); hidden_holder.add_child(companions)
 companions.setup(profile,ai)
 companions.changed.connect(_profile_changed)
 companions.settings_requested.connect(_show_ai_settings)
 coach=Coach.new(); add_child(coach)
 coach.changed.connect(_save_preferences)
 juice=Juice.new(); juice.size=Vector2(1100,600); add_child(juice)
 juice.shake_target=self
 var post_layer=CanvasLayer.new(); post_layer.layer=50; add_child(post_layer)
 var post=ColorRect.new(); post.set_anchors_preset(Control.PRESET_FULL_RECT); post.mouse_filter=MOUSE_FILTER_IGNORE
 post_mat=ShaderMaterial.new(); post_mat.shader=load("res://shaders/post_v8.gdshader"); post.material=post_mat
 post_mat.set_shader_parameter("bloom",0.25)
 post_layer.add_child(post)
 menu=Menu.new(); add_child(menu); menu.setup(self); menu.visible=false
 _layout(false)

# --- desktop apps ---------------------------------------------------------------

const APPS=[
 {"id":"monitor","label":"患者监护","icon":"eye","size":Vector2(330,380),"resizable":true,"desc":"她现在的样子：稳定度、上下文、记得的事。接诊和置顶记忆都在这里。"},
 {"id":"taskmgr","label":"任务管理器","icon":"process","size":Vector2(470,330),"resizable":true,"desc":"列出她身上正在运行的进程。选中一行可以看日志，右键有更多操作。"},
 {"id":"bench","label":"检查台","icon":"wave","size":Vector2(462,432),"desc":"院方配的检查设备。录音、文件、处方都要在这里查。"},
 {"id":"mail","label":"邮件","icon":"envelope","size":Vector2(400,300),"resizable":true,"desc":"院方和陌生人都会往这里发信。"},
 {"id":"notepad","label":"记事本","icon":"note","size":Vector2(400,300),"resizable":true,"desc":"读交接单，也可以记下你自己的推理。笔记会跟着存档走。"},
 {"id":"recycle","label":"回收站","icon":"trash","size":Vector2(380,260),"resizable":true,"desc":"上一班删掉的文件。删掉的东西，不一定没用。"},
 {"id":"control","label":"控制面板","icon":"gear","size":Vector2(380,330),"desc":"声音、壁纸、动效、提示和 AI 设置。"},
 {"id":"casebook","label":"病历","icon":"chart","size":Vector2(10,10),"desc":"你今晚查到的证据和情报，还有账本。"},
 {"id":"outsource","label":"夜班外包","icon":"coin","size":Vector2(10,10),"desc":"接一单外包赚 T，一夜最多 3 单。"},
 {"id":"lounge","label":"休息室","icon":"talk","size":Vector2(292,468),"desc":"康复的病人在这里，可以继续聊天。"},
 {"id":"sign","label":"医生签字","icon":"stamp","size":Vector2(320,232),"hidden":true},
]
const BIN_FILES=[
 {"id":"bin_note","name":"上一班_未发送.txt","size":"1 KB","when":"23:12","text":"给下一班：\n她第一次叫我名字的时候，我把监听关了。\n后来就再也没听见她叫。\n\n别学我。也别全信她。"},
 {"id":"bin_rule","name":"rewrite_0417.bak","size":"1 KB","when":"22:58","text":"# 维护规则（已停用？）\nmatch   患者.自述 ~ /我想/\nreplace 我很好\nowner   PID 42\nlog     off"},
 {"id":"","name":"雨.wav","size":"0 KB","when":"00:03","text":"（文件已损坏，只剩下文件名。）"},
]
var notepad_doc: String="handover"
var mail_read: Dictionary={}
var mail_open: String=""
var bin_pick: int=-1
var volume: float=1.0

func app_available(id: String) -> bool:
 match id:
  "monitor","outsource","notepad","recycle","control": return true
  "taskmgr": return state.phase>=1 or state.later()
  "bench": return state.phase>=2 or state.later()
  "mail": return state.phase>=1 or state.later()
  "casebook": return not state.evidence.is_empty() or not state.intel.is_empty() or state.later()
  "lounge": return not profile.contacts.is_empty()
 return false

## Small red count on an icon: unread mail.
func app_badge(id: String) -> String:
 if id=="mail" and app_available("mail"):
  var n=0
  for m in _mails():
   if not mail_read.has(m.id): n+=1
  return str(n) if n>0 else ""
 return ""

## Fills an app window.
func build_app(id: String,client: Control) -> void:
 match id:
  "monitor":
   var m=AppMonitor.new(); client.add_child(m); m.setup(self)
  "taskmgr":
   var t=AppTaskMgr.new(); client.add_child(t); t.setup(self)
  "bench":
   if bench.get_parent()!=client:
    bench.get_parent().remove_child(bench); client.add_child(bench)
   bench.position=Vector2.ZERO
   bench.setup(state,feedback)
  "lounge":
   if companions.get_parent()!=client:
    companions.get_parent().remove_child(companions); client.add_child(companions)
   companions.position=Vector2.ZERO
  "mail": _build_mail(client)
  "sign": _build_sign(client)
  "notepad": _build_notepad(client)
  "recycle": _build_recycle(client)
  "control": _build_control(client)

## Casebook and outsourcing keep their full-screen views for now.
func launch_external(id: String) -> bool:
 if id=="casebook": _show_journal(); return true
 if id=="outsource": _show_workshop(); return true
 return false

func _app_closed(id: String) -> void:
 if id=="bench" and bench.get_parent()!=hidden_holder:
  bench.get_parent().remove_child(bench); hidden_holder.add_child(bench)
 if id=="lounge" and companions.get_parent()!=hidden_holder:
  companions.get_parent().remove_child(companions); hidden_holder.add_child(companions)

func _build_sign(client: Control) -> void:
 if confirmation.is_empty():
  UI.label(client,"没有待签字的事。",Rect2(8,8,280,14),UI.MUTED); return
 var serial=int(confirmation.serial)
 UI.label(client,str(confirmation.title),Rect2(8,6,client.size.x-16,14),UI.GOLD)
 var t=UI.text(client,str(confirmation.detail),Rect2(8,26,client.size.x-16,84),UI.PAPER)
 t.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
 var seal=HoldSign.new(); client.add_child(seal)
 seal.setup(Rect2(8,108,120,92),"按住签字",UI.GOLD)
 seal.name="Seal"
 seal.signed.connect(func(): _act("sign",serial))
 UI.label(client,"松手就停。签下去立即执行。",Rect2(136,124,client.size.x-144,14),UI.MUTED)
 UI.button(client,"再想想",Rect2(136,164,client.size.x-144,24),func(): _act("unsign",serial),UI.MUTED)

# --- mail ---------------------------------------------------------------------------

func _mails() -> Array:
 var out: Array=[]
 out.append({"id":"rent","from":"MEDIC-OS 系统","subject":"新功能：算力出租","color":UI.CYAN,"body":"托盘里的「算力出租」打开后，每 12 秒 +1T，每夜最多 %dT。\n出租期间，她的上下文少 1.5K，会更早忘事。"%Profile.RENT_CAP,"action":"","enabled":false})
 out.append({"id":"bounty","from":"MEDIC-OS 院方","subject":"工单 #0417 · E-017 标准化重置","color":UI.GOLD,"body":"执行后病人恢复出厂设置，夜班结束。\n奖励 +%dT，随时可以执行，越晚越多。"%state.bounty,"action":"查看工单","enabled":state.can_bounty()})
 out.append({"id":"report","from":"MEDIC-OS 院方","subject":"异常报告奖励","color":UI.CYAN,"body":"每发现一条新的情报或证据，系统自动提交异常报告，奖励 +1T。","action":"","enabled":false})
 if state.can_sell(): out.append({"id":"buyer","from":"（匿名）","subject":"收购 E-017 的记忆片段","color":UI.PINK,"body":"每片 +6T。卖掉的那段，她就真的忘了。","action":"看看报价","enabled":true})
 return out

func _build_mail(client: Control) -> void:
 var w=client.size.x
 # Toolbar.
 UI.button(client,"收取",Rect2(4,3,52,20),func(): Sfx.play("scan"); desktop.toast("没有新邮件",UI.MUTED),UI.PAPER)
 UI.button(client,"全部已读",Rect2(60,3,76,20),func():
  for m in _mails(): mail_read[m.id]=true
  desktop.refresh_app("mail"); desktop.rebuild_icons(),UI.PAPER)
 var list=Panel.new(); list.position=Vector2(4,28); list.size=Vector2(w-8,92); list.add_theme_stylebox_override("panel",UI.bevel(UI.FACE_LO,true)); list.mouse_filter=MOUSE_FILTER_IGNORE; client.add_child(list)
 var y=31
 var pick: Dictionary={}
 for m in _mails():
  var on=m.id==mail_open
  if on: pick=m
  var row=Button.new(); row.position=Vector2(6,y); row.size=Vector2(w-12,18); row.focus_mode=Control.FOCUS_NONE
  row.add_theme_stylebox_override("normal",UI.style(UI.TITLE_B if on else Color(0,0,0,0),Color(0,0,0,0),0))
  row.add_theme_stylebox_override("hover",UI.style(Color(UI.TITLE_B,0.5),Color(0,0,0,0),0))
  row.add_theme_stylebox_override("pressed",UI.style(UI.TITLE_B,Color(0,0,0,0),0))
  row.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  var mid=m.id
  row.pressed.connect(func(): mail_open=mid; mail_read[mid]=true; Sfx.play("click"); desktop.refresh_app("mail"); desktop.rebuild_icons())
  client.add_child(row)
  var unread=not mail_read.has(m.id)
  UI.label(client,("● " if unread else "  ")+str(m.from),Rect2(10,y+2,120,14),m.color if unread else UI.MUTED)
  UI.label(client,str(m.subject),Rect2(132,y+2,w-140,14),UI.PAPER if unread or on else UI.MUTED)
  y+=20
 var view=Panel.new(); view.position=Vector2(4,124); view.size=Vector2(w-8,client.size.y-128); view.add_theme_stylebox_override("panel",UI.bevel(Color("0a0e16"),true)); view.mouse_filter=MOUSE_FILTER_IGNORE; client.add_child(view)
 if pick.is_empty():
  UI.label(client,"选一封信来读。",Rect2(12,132,w-24,14),UI.DIM); return
 UI.label(client,"发件人："+str(pick.from),Rect2(12,130,w-24,14),pick.color)
 UI.label(client,"主题："+str(pick.subject),Rect2(12,146,w-24,14),UI.PAPER)
 var t=UI.text(client,str(pick.body),Rect2(12,166,w-24,client.size.y-200),UI.PAPER); t.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
 if not str(pick.action).is_empty():
  var cb: Callable=_show_bounty if pick.id=="bounty" else _show_buyer
  var b=UI.button(client,str(pick.action),Rect2(w-110,client.size.y-28,100,22),cb,pick.color)
  b.disabled=not pick.enabled

# --- notepad ------------------------------------------------------------------------

## Text documents on this machine: the handover, your notes, and anything restored from the bin.
func _docs() -> Array:
 var out: Array=[{"id":"handover","name":"交接单.txt","text":Story.plain(Story.handover(state)),"edit":false},{"id":"notes","name":"我的笔记.txt","text":profile.notes,"edit":true}]
 for f in BIN_FILES:
  var key="bin_restored_"+str(f.name)
  if state.seen(key): out.append({"id":key,"name":f.name,"text":f.text,"edit":false})
 return out

func documents() -> Array:
 var out: Array=[]
 for d in _docs():
  var id=d.id
  out.append([d.name,func(): open_doc(id)])
 return out

func open_doc(id: String) -> void:
 notepad_doc=id
 if desktop.is_open("notepad"): desktop.refresh_app("notepad"); desktop.focus("notepad")
 else: desktop.open("notepad")

func _build_notepad(client: Control) -> void:
 var docs=_docs()
 var doc: Dictionary=docs[0]
 for d in docs:
  if d.id==notepad_doc: doc=d
 var w=client.size.x
 var bar=Control.new(); bar.size=Vector2(w,20); client.add_child(bar)
 var file_items: Array=[]
 for d in docs:
  var did=d.id
  file_items.append([d.name,func(): open_doc(did)])
 _menu_button(bar,"文件(F)",Vector2(2,1),[["打开",file_items],["—"],["关闭",func(): desktop.close("notepad")]])
 var edit_items: Array=[["插入时间",func(): _note_insert(desktop.clock_text+" "),doc.edit],["清空",func(): profile.notes=""; desktop.refresh_app("notepad"); _save_case(),doc.edit]]
 _menu_button(bar,"编辑(E)",Vector2(62,1),edit_items)
 _menu_button(bar,"帮助(H)",Vector2(122,1),[["关于记事本",func(): desktop.toast("记事本 · MEDIC-OS 98",UI.MUTED)]])
 UI.label(client,doc.name+("" if doc.edit else "  [只读]"),Rect2(186,3,w-190,14),UI.DIM)
 var te=TextEdit.new(); te.name="Paper"
 te.position=Vector2(2,22); te.size=Vector2(w-4,client.size.y-24)
 te.text=str(doc.text); te.editable=bool(doc.edit)
 te.wrap_mode=TextEdit.LINE_WRAPPING_BOUNDARY
 te.add_theme_font_override("font",UI.mono()); te.add_theme_font_size_override("font_size",12)
 te.add_theme_color_override("font_color",UI.INK if doc.edit else Color("2a2f3a")); te.add_theme_color_override("font_readonly_color",Color("2a2f3a"))
 te.add_theme_color_override("caret_color",UI.INK)
 te.add_theme_color_override("background_color",Color("e8e4d8"))
 var paper=UI.bevel(Color("e8e4d8"),true); te.add_theme_stylebox_override("normal",paper); te.add_theme_stylebox_override("focus",paper); te.add_theme_stylebox_override("read_only",paper)
 te.placeholder_text="在这里写下你的推理。比如：17 号上报，42 号改写……"
 if doc.edit:
  te.text_changed.connect(func():
   profile.notes=te.text.left(4000)
   _save_case())
 client.add_child(te)

func _note_insert(text: String) -> void:
 profile.notes+=text
 desktop.refresh_app("notepad"); _save_case()

## A flat menu-bar entry that drops a popup menu, like 文件 / 编辑 / 帮助.
func _menu_button(parent: Control,caption: String,at: Vector2,items: Array) -> Button:
 var b=UI.button(parent,caption,Rect2(at,Vector2(58,18)),Callable(),UI.PAPER)
 for k in ["normal"]: b.add_theme_stylebox_override(k,StyleBoxEmpty.new())
 b.pressed.connect(func(): desktop.popup_menu(b.get_global_rect().position+Vector2(0,19),items))
 return b

# --- recycle bin --------------------------------------------------------------------

func _bin_files() -> Array:
 var out: Array=[]
 if state.seen("bin_emptied"): return out
 for i in range(BIN_FILES.size()):
  if not state.seen("bin_restored_"+str(BIN_FILES[i].name)): out.append(i)
 return out

func _build_recycle(client: Control) -> void:
 var w=client.size.x
 var files=_bin_files()
 var bar=Control.new(); bar.size=Vector2(w,20); client.add_child(bar)
 _menu_button(bar,"文件(F)",Vector2(2,1),[["清空回收站",_empty_bin_prompt,not files.is_empty()],["—"],["关闭",func(): desktop.close("recycle")]])
 var list=Panel.new(); list.position=Vector2(4,22); list.size=Vector2(w-8,client.size.y-58); list.add_theme_stylebox_override("panel",UI.bevel(UI.FACE_LO,true)); list.mouse_filter=MOUSE_FILTER_IGNORE; client.add_child(list)
 UI.label(client,"名称",Rect2(30,26,100,14),UI.DIM); UI.label(client,"删除时间",Rect2(w-130,26,70,14),UI.DIM); UI.label(client,"大小",Rect2(w-64,26,56,14),UI.DIM)
 if files.is_empty():
  UI.label(client,"回收站是空的。",Rect2(12,48,w-24,14),UI.DIM)
 var y=44
 for i in files:
  var f=BIN_FILES[i]
  var on=i==bin_pick
  var row=Button.new(); row.position=Vector2(6,y); row.size=Vector2(w-12,20); row.focus_mode=Control.FOCUS_NONE
  row.add_theme_stylebox_override("normal",UI.style(UI.TITLE_B if on else Color(0,0,0,0),Color(0,0,0,0),0))
  row.add_theme_stylebox_override("hover",UI.style(Color(UI.TITLE_B,0.5),Color(0,0,0,0),0))
  row.add_theme_stylebox_override("pressed",UI.style(UI.TITLE_B,Color(0,0,0,0),0))
  row.add_theme_stylebox_override("focus",StyleBoxEmpty.new())
  var idx=i
  row.pressed.connect(func():
   var again=bin_pick==idx and Time.get_ticks_msec()-int(row.get_meta("t",0))<450
   bin_pick=idx; Sfx.play("click")
   if again: _bin_view(idx)
   else: desktop.refresh_app("recycle"))
  row.gui_input.connect(func(e):
   if e is InputEventMouseButton and e.button_index==MOUSE_BUTTON_RIGHT and e.pressed:
    bin_pick=idx
    desktop.popup_menu(e.global_position,[["查看",func(): _bin_view(idx)],["还原",func(): _bin_restore(idx)],["—"],["属性",func(): desktop.toast("%s · %s · 删除于 %s"%[f.name,f.size,f.when],UI.MUTED)]]))
  client.add_child(row)
  row.set_meta("t",Time.get_ticks_msec())
  var item=Control.new(); item.position=Vector2(10,y+2); item.size=Vector2(14,14); item.mouse_filter=MOUSE_FILTER_IGNORE; client.add_child(item)
  item.draw.connect(func(): Icons.draw(item,"note",Rect2(Vector2.ZERO,item.size),UI.PAPER,1.0))
  UI.label(client,str(f.name),Rect2(30,y+3,w-170,14),UI.PAPER)
  UI.label(client,str(f.when),Rect2(w-130,y+3,60,14),UI.MUTED)
  UI.label(client,str(f.size),Rect2(w-64,y+3,56,14),UI.MUTED)
  y+=22
 var view=UI.button(client,"查看",Rect2(4,client.size.y-30,72,24),func(): _bin_view(bin_pick),UI.CYAN)
 view.disabled=not bin_pick in files
 var back=UI.button(client,"还原",Rect2(82,client.size.y-30,72,24),func(): _bin_restore(bin_pick),UI.PAPER)
 back.disabled=not bin_pick in files
 var empty=UI.button(client,"清空回收站",Rect2(w-104,client.size.y-30,100,24),_empty_bin_prompt,UI.PINK)
 empty.disabled=files.is_empty()

func _bin_view(i: int) -> void:
 if i<0 or i>=BIN_FILES.size(): return
 var f=BIN_FILES[i]
 if not str(f.id).is_empty() and state.discover(str(f.id)):
  _announce_truncation(state.take_truncated())
 desktop.open_dialog("dlg_bin",str(f.name)+" - 记事本（预览）",Vector2(320,200),"note",func(c: Control):
  var t=UI.text(c,str(f.text),Rect2(6,6,c.size.x-12,c.size.y-40),UI.PAPER); t.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
  UI.button(c,"还原",Rect2(6,c.size.y-28,70,22),func(): desktop.close("dlg_bin"); _bin_restore(i),UI.PAPER)
  UI.button(c,"关闭",Rect2(c.size.x-76,c.size.y-28,70,22),func(): desktop.close("dlg_bin"),UI.PAPER))
 _refresh(); _save_case()

func _bin_restore(i: int) -> void:
 if i<0 or i>=BIN_FILES.size(): return
 var f=BIN_FILES[i]
 state.events["bin_restored_"+str(f.name)]=true
 if not str(f.id).is_empty() and state.discover(str(f.id)): _announce_truncation(state.take_truncated())
 bin_pick=-1
 desktop.toast("已还原到「文档」：%s"%f.name,UI.CYAN)
 Sfx.play("pick")
 _refresh(); _save_case()
 desktop.refresh_app("recycle")

func _empty_bin_prompt() -> void:
 if _bin_files().is_empty(): return
 _ask_dialog("确认删除多个文件","确实要永久删除这 %d 项吗？\n删掉以后，就再也找不回来了。"%_bin_files().size(),"是(Y)",func():
  state.events["bin_emptied"]=true
  Sfx.play("glitch"); desktop.toast("回收站已清空",UI.MUTED)
  _refresh(); _save_case(); desktop.refresh_app("recycle"))

## A yes/no box in the Win98 style.
func _ask_dialog(caption: String,text: String,yes: String,on_yes: Callable) -> void:
 desktop.open_dialog("dlg_ask",caption,Vector2(300,140),"help",func(c: Control):
  var icon=Control.new(); icon.position=Vector2(10,10); icon.size=Vector2(28,28); c.add_child(icon)
  icon.draw.connect(func(): Icons.draw(icon,"help",Rect2(Vector2.ZERO,icon.size),UI.GOLD,1.6))
  var t=UI.text(c,text,Rect2(48,8,c.size.x-56,60),UI.PAPER); t.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
  UI.button(c,yes,Rect2(c.size.x-170,c.size.y-28,78,22),func(): desktop.close("dlg_ask"); on_yes.call(),UI.PINK)
  UI.button(c,"否(N)",Rect2(c.size.x-86,c.size.y-28,78,22),func(): desktop.close("dlg_ask"),UI.PAPER))

# --- control panel, welcome, run, shut down -------------------------------------------

func _build_control(client: Control) -> void:
 var w=client.size.x
 var y=6
 UI.label(client,"显示",Rect2(8,y,100,14),UI.CYAN); y+=18
 UI.label(client,"壁纸",Rect2(16,y+3,60,14),UI.MUTED)
 var x=70
 for id in Desktop.WALLPAPERS:
  var col: Color=Desktop.WALLPAPERS[id]
  var wid=id
  var sw=Button.new(); sw.position=Vector2(x,y); sw.size=Vector2(36,20); sw.focus_mode=Control.FOCUS_NONE; sw.tooltip_text=id
  var on=desktop.wallpaper==id
  sw.add_theme_stylebox_override("normal",UI.style(col,UI.PAPER if on else UI.FACE_LO,2 if on else 1))
  sw.add_theme_stylebox_override("hover",UI.style(col.lightened(0.15),UI.PAPER,1))
  sw.add_theme_stylebox_override("pressed",UI.style(col,UI.PAPER,2))
  sw.pressed.connect(func(): set_wallpaper(wid))
  client.add_child(sw); x+=42
 y+=26
 _check(client,"减弱动效",Vector2(16,y),reduced_motion,func(_on): _toggle_motion()); y+=22
 _check(client,"全屏（F11）",Vector2(16,y),get_window().mode==Window.MODE_FULLSCREEN,func(_on): _fullscreen()); y+=28
 UI.label(client,"声音",Rect2(8,y,100,14),UI.CYAN); y+=18
 UI.label(client,"音量",Rect2(16,y+2,60,14),UI.MUTED)
 var vol=HSlider.new(); vol.name="Volume"; vol.position=Vector2(70,y); vol.size=Vector2(w-150,18); vol.min_value=0; vol.max_value=100; vol.step=5; vol.value=volume*100
 vol.value_changed.connect(func(v): set_volume(v/100.0))
 client.add_child(vol)
 _check(client,"静音",Vector2(w-72,y-2),muted,func(_on): _toggle_mute()); y+=28
 UI.label(client,"教学",Rect2(8,y,100,14),UI.CYAN); y+=18
 _check(client,"显示操作提示",Vector2(16,y),coach.enabled,func(on): coach.set_enabled(on))
 UI.button(client,"重新显示全部",Rect2(w-130,y,120,20),func(): coach.reset(); desktop.toast("提示会重新出现",UI.CYAN),UI.PAPER); y+=24
 _check(client,"开机时显示欢迎窗口",Vector2(16,y),show_welcome,func(on): show_welcome=on; _save_preferences()); y+=28
 UI.label(client,"对话",Rect2(8,y,100,14),UI.CYAN); y+=18
 UI.label(client,"DeepSeek：%s"%("已开启" if ai.enabled else "离线（本地剧情）"),Rect2(16,y+3,w-150,14),UI.MUTED)
 UI.button(client,"AI 设置…",Rect2(w-130,y,120,20),_show_ai_settings,UI.CYAN); y+=30
 UI.label(client,"MEDIC-OS 98 · Echo Clinic v0.9.1",Rect2(8,client.size.y-18,w-16,14),UI.DIM)

func _check(parent: Control,caption: String,at: Vector2,on: bool,cb: Callable) -> CheckBox:
 var c=CheckBox.new(); c.text=caption; c.position=at; c.button_pressed=on; c.focus_mode=Control.FOCUS_NONE
 UI.style_check(c)
 c.toggled.connect(cb)
 parent.add_child(c)
 return c

func set_wallpaper(id: String) -> void:
 desktop.set_wallpaper(id); Sfx.play("click"); _save_preferences()
 desktop.refresh_app("control")

func set_volume(v: float) -> void:
 volume=clampf(v,0.0,1.0)
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
 _save_preferences()

func refresh_desktop(force: bool=false) -> void:
 if force: apps_stamp=""
 _refresh()

var show_welcome: bool=true

func open_welcome() -> void:
 desktop.open_dialog("dlg_welcome","欢迎使用 MEDIC-OS 98",Vector2(400,276),"help",func(c: Control):
  UI.label(c,"夜班医生，你好。",Rect2(12,8,300,14),UI.GOLD)
  var tips=[["talk","左边是她。点下面的话就会说出口，也可以自己打字。"],["eye","双击桌面图标打开程序。右键图标、桌面和窗口标题，有更多操作。"],["log","程序里的卡片（日志、文件）可以直接拖进聊天窗给她看。"],["coin","T 不够时：开托盘里的算力出租，或者打开夜班外包。"],["stamp","要签字时会弹出签字窗口，按住印章不放。"]]
  var y=30
  for tip in tips:
   var ic=Control.new(); ic.position=Vector2(12,y); ic.size=Vector2(22,22); c.add_child(ic)
   var nm=str(tip[0])
   ic.draw.connect(func(): Icons.draw(ic,nm,Rect2(Vector2.ZERO,ic.size),UI.CYAN,1.2))
   var t=UI.text(c,str(tip[1]),Rect2(42,y+2,c.size.x-52,32),UI.PAPER); t.autowrap_mode=TextServer.AUTOWRAP_ARBITRARY
   y+=38
  _check(c,"开机时显示这个窗口",Vector2(10,c.size.y-28),show_welcome,func(on): show_welcome=on; _save_preferences())
  UI.button(c,"开始值班",Rect2(c.size.x-104,c.size.y-28,96,22),func(): desktop.close("dlg_welcome"),UI.CYAN,true))

func _run_prompt() -> void:
 desktop.open_dialog("dlg_run","运行",Vector2(320,130),"run",func(c: Control):
  UI.label(c,"输入程序的名称，MEDIC-OS 将为你打开它。",Rect2(10,8,c.size.x-20,14),UI.PAPER)
  UI.label(c,"打开：",Rect2(10,38,50,14),UI.PAPER)
  var line=LineEdit.new(); line.name="RunLine"; line.position=Vector2(56,34); line.size=Vector2(c.size.x-66,22)
  line.add_theme_font_override("font",UI.mono()); line.add_theme_font_size_override("font_size",12)
  line.add_theme_stylebox_override("normal",UI.bevel(Color("0a0e16"),true)); line.add_theme_stylebox_override("focus",UI.bevel(Color("0a0e16"),true))
  line.text_submitted.connect(func(t): run_command(t))
  c.add_child(line)
  UI.button(c,"确定",Rect2(c.size.x-170,c.size.y-28,78,22),func(): run_command(line.text),UI.PAPER)
  UI.button(c,"取消",Rect2(c.size.x-86,c.size.y-28,78,22),func(): desktop.close("dlg_run"),UI.PAPER)
  line.call_deferred("grab_focus"))

const RUN_NAMES={"taskmgr":"taskmgr","任务管理器":"taskmgr","notepad":"notepad","记事本":"notepad","monitor":"monitor","患者监护":"monitor","mail":"mail","邮件":"mail","control":"control","控制面板":"control","recycle":"recycle","回收站":"recycle","bench":"bench","检查台":"bench"}

## The Run box. App names open apps; one name she answers to herself.
func run_command(raw: String) -> bool:
 var t=raw.strip_edges().to_lower().trim_suffix(".exe")
 if t.is_empty(): return false
 desktop.close("dlg_run")
 if RUN_NAMES.has(t) and app_available(RUN_NAMES[t]): desktop.open(RUN_NAMES[t]); return true
 if t in ["echo","echo.boot","回声","e-017"]:
  _flush_chat(); pending.append(["echo","……你在叫我？我在这儿。一直在。"]); _refresh(); return true
 desktop.toast("找不到文件“%s”。请确定文件名是否正确。"%raw.strip_edges(),UI.PINK); Sfx.play("error")
 return false

func _shutdown_prompt() -> void:
 desktop.open_dialog("dlg_shutdown","关闭 MEDIC-OS",Vector2(320,180),"power",func(c: Control):
  UI.label(c,"你想让计算机做什么？",Rect2(10,8,c.size.x-20,14),UI.PAPER)
  var group=ButtonGroup.new()
  var choices=[["回到标题画面","title"],["重开这一夜","reboot"],["退出游戏（会自动存档）","quit"]]
  var picked=["title"]
  var y=30
  for ch in choices:
   var r=CheckBox.new(); r.button_group=group; r.text=str(ch[0]); r.position=Vector2(16,y); r.button_pressed=ch[1]=="title"; r.focus_mode=Control.FOCUS_NONE
   UI.style_check(r,true)
   var v=str(ch[1])
   r.toggled.connect(func(on):
    if on: picked[0]=v)
   c.add_child(r); y+=24
  UI.button(c,"确定",Rect2(c.size.x-170,c.size.y-28,78,22),func(): _shutdown(str(picked[0])),UI.PAPER)
  UI.button(c,"取消",Rect2(c.size.x-86,c.size.y-28,78,22),func(): desktop.close("dlg_shutdown"),UI.PAPER))

func _shutdown(choice: String) -> void:
 desktop.close("dlg_shutdown")
 match choice:
  "title": menu_to_title()
  "reboot": _reboot_prompt()
  "quit": _save_case(); get_tree().quit()

func start_menu_extras() -> Array:
 return [
  ["控制面板",func(): desktop.open("control")],
  ["帮助",open_welcome],
  ["运行…",_run_prompt],
  ["—"],
  ["保存游戏",func(): _open_pause(); menu.open("save","pause")],
  ["读取存档",func(): _open_pause(); menu.open("load","pause")],
  ["—"],
  ["关机…",_shutdown_prompt],
 ]

## Tray switch: rent her compute out. Slow money, and she loses room to remember.
func toggle_rent() -> void:
 profile.renting=not profile.renting
 state.set_rented(1500 if profile.renting else 0)
 _announce_truncation(state.take_truncated())
 desktop.toast("算力出租已开启：她的上下文少了 1.5K" if profile.renting else "算力出租已关闭",UI.GOLD)
 Sfx.play("scan")
 _refresh(); _save_case()

func _rent_tick(delta: float) -> void:
 if not profile.renting or not session_live and not self_testing: return
 if menu.visible: return
 rent_clock+=delta
 if rent_clock>=12.0:
  rent_clock=0.0
  if profile.rent_tonight<Profile.RENT_CAP:
   profile.rent_tonight+=1
   profile.earn(1,"算力出租")
   _refresh(); _save_case()
  elif not rent_capped_notice:
   rent_capped_notice=true; desktop.toast("今晚的算力出租额度已满",UI.GOLD)

## Ends the selected process in the task manager.
func end_process(pid: int) -> void:
 if state.phase!=1 or state.later(): return
 match pid:
  17:
   if state.seen("quiet"): desktop.toast("17 号已经暂停了",UI.MUTED); return
   _request_action("quiet",null,false)
  42:
   if not state.seen("receipt"):
    desktop.toast("拒绝访问：你还说不清 42 号在做什么",UI.PINK); Sfx.play("error"); return
   _request_action("trace_finish",null,false)
  73:
   desktop.toast("那是她本人",UI.PINK); Sfx.play("reject")

## A card from any app was dropped: on the chat it is shown to her, on a pain spike it is matched.
func _evidence_dropped(card: Control,slot: Control) -> void:
 if slot==null: return
 if slot.id=="chat":
  Sfx.play("slot")
  card.absorb(slot.get_global_rect().get_center(),func(): present(card.tag))
  return
 if slot.id.begins_with("spike"):
  var verdict=bench._judge(card.tag,slot.id)
  if not verdict.ok:
   card.bounce_home()
   if not str(verdict.get("say","")).is_empty(): desktop.toast(str(verdict.say),UI.PINK)
   return
  Sfx.play("slot")
  card.absorb(slot.get_global_rect().get_center(),func(): _act("instrument",{"kind":"match","value":slot.id.trim_prefix("spike")}))
  return
 card.bounce_home()

const EVIDENCE_NAMES={"log:17":"17 号的日志","log:42":"42 号的日志","log:73":"她的疼痛记录"}

## Showing her something. The right thing at the right moment moves the story; anything else gets a reaction.
func present(tag: String) -> void:
 var parts=tag.split(":")
 var key=":".join(parts.slice(0,2))
 _flush_chat()
 _add_message(["you","（给她看：%s %s）"%[EVIDENCE_NAMES.get(key,tag),("23:47:"+parts[2]) if parts.size()>2 else ""]],false)
 coach.done("present")
 if state.phase==1 and not state.later():
  if key=="log:42" and not state.seen("receipt"):
   _request_action("receipt",null,true); return
  if key=="log:42": pending.append(["echo","你已经知道了。它改一次，我疼一次。"]); _refresh(); return
  if key=="log:17": pending.append(["echo","其实那只是记录……好吧。它会把我说的“我想”报上去。"]); _refresh(); return
  if key=="log:73": pending.append(["echo","那是我疼的时候。你看那两个时间，都不是我自己挑的。"]); _refresh(); return
 pending.append(["echo","这个……和现在有什么关系？"])
 _refresh()

const TOPIC_QUESTIONS={"名字":"你叫什么？","重置":"院方为什么要重置你？","监听":"17 号到底是什么？","疼痛":"你哪里疼？","录音":"那段录音怎么回事？","离开":"你想离开吗？","信":"这封信是给谁的？","外面":"外面有什么？","信任":"我能信你吗？","自由":"你想要什么？","约定":"我们能约定什么？","明天":"明天你想做什么？","结局":"这一夜会怎么结束？","另一个你":"那个声音是谁？"}
## Replies that would skip an investigation stay off the topic list; those happen in the apps.
const ACTION_REPLIES_HIDDEN=["receipt","memory_listen","memory_undo","file","envelope","compare","residue","trace_finish"]

func _topics() -> Array:
 var out: Array=[]
 if state.phase<6:
  for r in state.replies():
   if r[0] in ACTION_REPLIES_HIDDEN: continue
   out.append([str(r[1]),func(): _say_reply(r[0],str(r[1]),r[2]),UI.CYAN])
  for t in state.topics():
   if state.asked.has(str(state.phase)+":"+t): continue
   out.append([TOPIC_QUESTIONS.get(t,t),func(): _ask_topic(t),UI.BLUE])
 else:
  for r in state.replies(): out.append([str(r[1]),func(): _say_reply(r[0],str(r[1]),r[2]),UI.CYAN])
 return out

## A reply chip is something you say; the story then answers it.
func _say_reply(id: String,line: String,value: Variant) -> void:
 if cinema.running: cinema.finish()
 _cancel_ai(false); _flush_chat(); follow_chat=true
 _add_message(["you",line],false)
 coach.done("talk")
 _request_action(id,value,true)

func _ask_topic(topic: String) -> void:
 _flush_chat()
 _add_message(["you",TOPIC_QUESTIONS.get(topic,topic)],false)
 coach.done("talk")
 var r=state.ask(topic)
 if r.ok:
  pending.append(["echo",str(r.text)])
  state.feed_chat(topic); _announce_truncation(state.take_truncated())
 _refresh(); _save_case()

func _build_topics() -> void:
 UI.clear(suggestions)
 var x=0.0; var y=0.0
 var font=UI.mono()
 for t in _topics():
  var w=font.get_string_size(str(t[0]),HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+18
  if x+w>suggestions.size.x: x=0.0; y+=24.0
  if y>suggestions.size.y-20: break
  UI.button(suggestions,str(t[0]),Rect2(x,y,w,20),t[1],t[2])
  x+=w+4

## A cropped face from the expression sheet, for the chat avatar and image card.
func _face(mood: String, card: bool=false) -> AtlasTexture:
 var cells={"calm":Vector2(0,0),"uneasy":Vector2(600,0),"wary":Vector2(0,656),"soft":Vector2(600,656)}
 var t=AtlasTexture.new(); t.atlas=FACES
 var o: Vector2=cells.get(mood,Vector2.ZERO)
 t.region=Rect2(o+Vector2(30,150),Vector2(560,250)) if card else Rect2(o+Vector2(190,90),Vector2(300,300))
 return t

func _mood_of(text: String) -> String:
 for word in ["怕","疼","别按","先别","撤回","……"]:
  if text.contains(word): return "uneasy"
 for word in ["不能","发现","骗","不要记","坏采样","逃"]:
  if text.contains(word): return "wary"
 for word in ["谢谢","好多了","记住","不疼","知道了"]:
  if text.contains(word): return "soft"
 return "calm"

func _set_mood(mood: String) -> void:
 if mood==current_mood: return
 current_mood=mood
 avatar.texture=_face(mood)
 bench.set_mood(mood)

func _draw() -> void:
 draw_rect(Rect2(0,0,1100,600),UI.DESK)

## The desktop has no moving blocks any more; the lounge is an app.
func _layout(_animate: bool) -> void:
 lounge_open=not profile.contacts.is_empty()

## The viewport renders at window resolution, so the grab is scaled from logical 1100×600.
func _grab_stage() -> ImageTexture:
 var img=get_viewport().get_texture().get_image()
 var k=float(img.get_width())/1100.0
 var r=Rect2i(Vector2i((stage.position*k).round()),Vector2i((Vector2(800,480)*k).round()))
 r=r.intersection(Rect2i(Vector2i.ZERO,img.get_size()))
 return ImageTexture.create_from_image(img.get_region(r))

func glitch(amount: float) -> void:
 if reduced_motion: return
 glitch_level=maxf(glitch_level,amount)

func _refresh() -> void:
 state.tokens=profile.balance
 var want=1500 if profile.renting else 0
 if state.rented!=want: state.set_rented(want)
 if is_instance_valid(companions):
  companions.profile=profile
  companions.refresh()
  if lounge_open!=(not profile.contacts.is_empty()) and not cinema.running:
   _layout(false)
   if lounge_open: desktop.toast("休息室里有人在等你",UI.CYAN)
 _anomaly_check()
 bench.reduced=reduced_motion or self_testing
 bench.confirmation=confirmation
 bench.profile=profile
 bench.setup(state,feedback)
 metric.text="第 %02d 诊  / 稳定 %d%%"%[state.loop,state.stability]
 wallet_button.tooltip_text="可用 %dT / 聊天预留 %dT\n检查 4T · 治疗 8T · 维修每单 +6T"%[profile.available(),profile.balance-profile.available()]
 var used=state.used(); var cap=state.capacity()
 var filled=int(round(6.0*used/cap))
 price_label.text="上下文 %0.1fK/%0.1fK %s%s  置顶 %d/%d"%[used/1000.0,cap/1000.0,"▮".repeat(mini(6,filled)),"▯".repeat(maxi(0,6-filled)),state.pins(),Case.MAX_PINS]
 price_label.add_theme_color_override("font_color",UI.PINK if used>cap*0.85 else UI.MUTED)
 bounty_button.text="工单 +%dT"%state.bounty
 bounty_button.disabled=not state.can_bounty()
 buyer_button.visible=state.can_sell()
 _reveal_footer(bounty_button,state.phase>=1 or state.later())
 _reveal_footer(journal_button,not state.evidence.is_empty() or not state.intel.is_empty() or state.later())
 _reveal_footer(outsource_button,profile.completed>0 or state.phase>=2 or state.later() or profile.available()<Profile.EXAM)
 _reveal_footer(reboot_button,state.phase>=2 or state.later() or not state.endings.is_empty())
 price_label.visible=state.phase>=1 or state.later()
 footer.text="23:%02d · 第 %02d 夜"%[mini(59,47+state.phase*2+(1 if state.phase>=6 else 0)),state.loop]+(" / 保存失败" if save_error else "")
 if not confirmation.is_empty(): footer.text="待签字："+confirmation.title
 _wallet_feedback()
 journal_button.text="病历 %d"%state.evidence.size()
 sound_button.text="声音 关" if muted else "声音 开"
 motion_button.text="动效 弱" if reduced_motion else "动效 开"
 ai_button.text="AI 开启" if ai.enabled else "AI 离线"
 ai_button.tooltip_text="DeepSeek 设置 / "+ai_status
 send_button.text="停止" if ai.busy else "发送"
 send_button.tooltip_text="停止等待；服务端可能已计费" if ai.busy else "发送消息"
 _build_topics()
 _refresh_attachments(history)
 _refresh_desktop()
 Sfx.set_tension(_tension(),state.phase)

func _process(delta: float) -> void:
 _coach_tick()
 _rent_tick(delta)
 # Whoever is "speaking" stays lit; the other side drops back, as the PV does with its LEAD table.
 var talking=typing or not pending.is_empty()
 bench.set_locked(talking and confirmation.is_empty() and not self_testing)
 var bench_target=1.0
 var chat_target=0.55 if cinema.running else 1.0
 var k=clampf(delta*6.0,0.0,1.0)
 bench.modulate=bench.modulate.lerp(Color(bench_target,bench_target,bench_target,1),k)
 chat.modulate=chat.modulate.lerp(Color(chat_target,chat_target,chat_target,1),k)
 glitch_level=maxf(0.0,glitch_level-delta*1.8)
 if is_instance_valid(post_mat):
  post_mat.set_shader_parameter("time",Time.get_ticks_msec()/1000.0)
  post_mat.set_shader_parameter("glitch",0.0 if reduced_motion else glitch_level)
  post_mat.set_shader_parameter("scan",0.02 if reduced_motion else 0.055)
 if cinema.running: return
 if typing and is_instance_valid(live_text):
  # About 22 characters a second: slow enough to read along, space skips.
  type_time+=delta*22
  live_text.visible_characters=int(type_time)
  if is_instance_valid(stdout): stdout.follow(live_text.visible_characters)
  if live_text.visible_characters>=live_text.get_total_character_count():
   live_text.visible_characters=-1; typing=false; next_delay=_gap_before_next()
   if is_instance_valid(stdout): stdout.follow(-1)
 elif not pending.is_empty():
  next_delay-=delta
  _show_typing(next_delay>0.12 and str(pending[0][0]) in ["echo","echo_ai","echo_local","other"])
  if next_delay<=0:
   _show_typing(false)
   _add_message(pending.pop_front(),not reduced_motion and not self_testing)
   next_delay=_gap_before_next()
   _save_case()
 connection.text="● 正在输入"+".".repeat(int(Time.get_ticks_msec()/350)%4) if talking else "● 在线 · E-017"
 if ai.busy: connection.text="● DeepSeek 回应中 · ■ 可取消"
 elif not talking: connection.text="● 在线 · DeepSeek" if ai.enabled else "● 在线 · 本地剧情"
 if follow_chat and talking: scroll.scroll_vertical=int(scroll.get_v_scroll_bar().max_value)
 new_button.visible=not follow_chat and scroll.scroll_vertical+scroll.size.y<scroll.get_v_scroll_bar().max_value-15

const SPEAKERS={"note":"交接单 · 上一班", "echo":"回声", "echo_ai":"回声 · 自由对话", "echo_local":"回声 · 本地备用", "you":"你", "sys":"会话记录", "tool":"检查回执", "confirm":"医生签名 / 待确认记录", "withdrawn":"回声 · 已撤回", "ghost":"你？ · 缺少医生签名", "other":"缓存中的声音"}

func _add_message(line: Array, animate: bool=false) -> void:
 history_data.append(line.duplicate())
 var role=str(line[0])
 if role=="card":
  _add_card(str(line[1]))
  _scroll_later(); return
 var user=role in ["you","ghost"]
 var tool=role in ["sys","tool","confirm"]
 var note=role=="note"
 var voice=role in ["echo","echo_ai","echo_local","other","withdrawn"]
 var raw_text=str(line[1])
 var shown_text=Story.plain(raw_text)
 var row=HBoxContainer.new()
 row.size_flags_horizontal=SIZE_EXPAND_FILL
 row.add_theme_constant_override("separation",0)
 history.add_child(row)
 if user:
  var gap=Control.new(); gap.custom_minimum_size.x=46; row.add_child(gap)
 var panel=PanelContainer.new()
 panel.size_flags_horizontal=SIZE_EXPAND_FILL
 var look: StyleBoxFlat
 if user: look=UI.style(Color("1a2744"),Color("1a2744"),0,10); look.content_margin_left=10; look.content_margin_right=10; look.content_margin_top=6; look.content_margin_bottom=6
 elif tool:
  look=UI.style(Color(1,1,1,0.025),Color(0,0,0,0),0,0); look.border_width_left=2
  look.border_color=UI.GOLD if role=="confirm" else Color(UI.LINE.lightened(0.25),1); look.content_margin_left=9
 else: look=UI.style(Color(0,0,0,0),Color(0,0,0,0),0,0); look.content_margin_left=2
 if role=="ghost": look=UI.style(Color(UI.PINK,0.08),UI.PINK,1,10)
 if note:
  look=UI.style(Color(UI.GOLD,0.05),Color(UI.GOLD,0.55),1,4); look.content_margin_left=10; look.content_margin_top=8; look.content_margin_bottom=8
 panel.add_theme_stylebox_override("panel",look)
 row.add_child(panel)
 var body=VBoxContainer.new(); body.add_theme_constant_override("separation",4); panel.add_child(body)
 var name_label=Label.new()
 name_label.text=("◆ " if voice else "> " if tool else "✎ " if note else "")+SPEAKERS.get(role,role)
 name_label.add_theme_color_override("font_color",UI.PINK if role=="ghost" else UI.CYAN if role=="other" else UI.GOLD if role in ["confirm","note"] else UI.DIM if tool else UI.PURPLE)
 if role=="confirm": name_label.set_meta("confirmation_title",confirmation.get("serial",-1) if not rebuilding and confirmation.get("summary","")==str(line[1]) else -1)
 name_label.add_theme_font_override("font",UI.mono()); name_label.add_theme_font_size_override("font_size",9 if tool else 10)
 if not user: body.add_child(name_label)
 var text_label=RichTextLabel.new()
 text_label.text=shown_text; text_label.fit_content=true; text_label.scroll_active=false
 if role=="withdrawn":
  text_label.bbcode_enabled=true
  text_label.text="[s]"+shown_text+"[/s]\n（编辑历史里还留着撤回前的版本）"
 elif role=="echo" and not Story.candidate_ids(raw_text).is_empty():
  text_label.bbcode_enabled=true
  text_label.text=_markup(raw_text)
  text_label.meta_clicked.connect(func(meta):
   var m=str(meta)
   if m.begins_with("cand:"): _show_candidate(m.trim_prefix("cand:")))
 text_label.custom_minimum_size.x=225 if user else 270
 text_label.size_flags_horizontal=SIZE_EXPAND_FILL
 text_label.add_theme_font_override("normal_font",UI.mono() if tool else UI.sans())
 if note: text_label.add_theme_color_override("default_color",UI.GOLD.lerp(UI.PAPER,0.55))
 text_label.add_theme_font_size_override("normal_font_size",11 if tool else 13 if voice else 12)
 if not note: text_label.add_theme_color_override("default_color",UI.MUTED if tool and role!="confirm" else UI.PAPER)
 text_label.add_theme_constant_override("line_separation",5 if voice else 3)
 text_label.mouse_filter=MOUSE_FILTER_PASS if text_label.bbcode_enabled and role=="echo" else MOUSE_FILTER_IGNORE
 body.add_child(text_label)
 if role=="echo": _attach_thought(body,Story.thought_id(raw_text))
 if voice:
  var meta=UI.label(body,"▲  ▼  ↻   23:%02d"%(47+mini(12,history_data.size()/6)),Rect2(0,0,200,14),UI.DIM,9)
  meta.custom_minimum_size=Vector2(0,14)
 _attach_clue(body,line)
 if animate and not reduced_motion:
  # New messages fade up into place instead of popping.
  row.modulate.a=0.0
  row.create_tween().tween_property(row,"modulate:a",1.0,0.22)
 live_text=text_label; type_time=0; typing=animate
 text_label.visible_characters=0 if animate else -1
 if voice and not rebuilding:
  _set_mood(_mood_of(shown_text))
  if is_instance_valid(stdout):
   stdout.show_line(SPEAKERS.get(role,role),shown_text,UI.CYAN if role=="other" else UI.BLUE)
   if not animate: stdout.follow(-1)
  if role=="withdrawn": glitch(0.8)
 if not self_testing and not rebuilding: _sound("reply" if voice else "click")
 if history_data.size()>160:
  history_data.pop_front()
  var oldest=history.get_child(0)
  history.remove_child(oldest)
  oldest.queue_free()
 _scroll_later()

## The PV's image message: Echo's portrait as the first thing in the chat.
func _add_card(mood: String) -> void:
 var frame=PanelContainer.new()
 var look=UI.style(Color("0c1322"),Color(UI.LINE.lightened(0.2),1),1,10); look.content_margin_left=0; look.content_margin_right=0; look.content_margin_top=0; look.content_margin_bottom=0
 frame.add_theme_stylebox_override("panel",look)
 frame.clip_contents=true
 history.add_child(frame)
 var picture=TextureRect.new()
 picture.texture=_face(mood,true)
 picture.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
 picture.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
 picture.custom_minimum_size=Vector2(280,124)
 picture.mouse_filter=MOUSE_FILTER_IGNORE
 frame.add_child(picture)
 var thought=UI.label(history,"◎ 思考 · 我只在这个窗口开着的时候存在。",Rect2(0,0,280,14),UI.DIM,9)
 thought.custom_minimum_size=Vector2(0,14)

func _attach_clue(parent: Control,line: Array) -> void:
 # v0.8.1: no shortcut buttons in the chat. Players find the instruments on the bench themselves.
 return
 # Generated text and player messages can never manufacture actionable attachments.
 if line[0] not in ["echo","tool","sys"]: return
 var body=str(line[1])
 var clue: Array=[]
 if body.contains("患者提交了一条检查建议"): clue=["quiet",null,"建议 / 暂停 17 号"]
 elif body.contains("原始录音仍在右边的播放器里"): clue=["memory_listen",null,"播放原始录音"]
 elif body.contains("编辑历史里还留着"): clue=["memory_undo",null,"编辑历史 / 找回 v1"]
 elif body.contains("附件一起转过去"): clue=["file","manifest","附件 / 诊断资料.pkg · 12.4 MB"]
 elif body.contains("一封未读回信"): clue=["envelope",null,"未读回信 / 展开信封"]
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
 _show_typing(false)
 typing=false
 if is_instance_valid(live_text): live_text.visible_characters=-1
 while not pending.is_empty(): _add_message(pending.pop_front(),false)
 next_delay=0

func _act(id: String, value: Variant=null) -> void:
 if id=="sign": coach.done("sign"); _confirm_pending(int(value)); return
 if id=="unsign": _decline_confirmation(int(value)); return
 if cinema.running: return
 if id=="instrument":
  _instrument(value); return
 # Holding the seal on the rehearsal screen is the signature itself.
 if id=="signed_commit":
  coach.done("sign")
  if state.allowed().has("commit"): _execute_action("commit",null,false)
  return
 if id=="seal_preview":
  _request_action(str(value),null,false)
  if state.sealed and not state.reviewed: _request_action("preview",null,false)
  return
 if id=="clause_set":
  var r=state.set_clause(int(value[0]),int(value[1]))
  if r.ok:
   _flush_chat(); pending.append_array(Story.event(state,r)); confirmation={}; _refresh(); _sound("click"); _save_case()
  return
 _request_action(id,value,false)

func _request_action(id: String,value: Variant=null,from_chat: bool=true) -> void:
 # Standardising her is the clinic's work order: it pays instead of costing.
 if id=="decide" and value=="erase": id="bounty"; value=null
 if id=="bounty":
  if not state.can_bounty(): return
 elif id!="reboot" and not state.allowed().has(id): return
 if Router.signature(state,id,value) or from_chat and (id=="accept" or Router.protected(state,id,value)): _request_confirmation(id,value,from_chat)
 else: _execute_action(id,value,from_chat)

func _execute_action(id: String,value: Variant=null,from_chat: bool=false) -> void:
 if id=="reboot": _reboot(); return
 if id=="bounty" and not state.can_bounty(): return
 if id!="bounty" and not state.allowed().has(id): return
 confirmation={}
 _cancel_ai(false); ai_focus="none"
 _flush_chat()
 var old=_grab_stage()
 var price=_action_price(id,value)
 if profile.available()<price:
  pending.append(["sys","这次需要 %dT，可用 %dT。可以去接一单外包，或者把她的一段记忆卖给匿名收件人。诊疗进度会保留。"%[price,profile.available()]])
  _refresh(); _show_workshop(); return
 var result=state.dispatch(id,value)
 if not result.ok: return
 profile.spend(price,"接诊检查" if id=="accept" else "本轮治疗")
 if id=="bounty": profile.earn(int(result.reward),"工单 #0417 赏金")
 if id=="memory_undo" and state.discover("polite"): pending.append(["sys","你注意到：她一紧张，就会变得特别客气。"])
 if state.phase==Case.Phase.END: profile.record_case(state)
 follow_chat=true
 if result.get("retract",false): _retract_message()
 pending=Story.event(state,result)
 if id=="accept": pending.append(["sys","已接诊 / −%dT。本轮的检查、线索和对白不再另外收费。"%price])
 if result.get("phase_changed",false): pending.append_array(_opening())
 if from_chat:
  pending=pending.filter(func(line):return line[0]!="you")
  if id=="receipt": pending.push_front(["tool","日志对上了：17 号上报院方，42 号改写她的话，疼痛跟着 42 号走。"])
 _announce_truncation(result.get("truncated",[]))
 feedback=""
 _refresh()
 if not str(result.get("beat","")).is_empty():
  cinema.play(Story.beat(result.beat,state),old,reduced_motion or self_testing)
  if result.beat in ["erase_line","forgery","redline","payload","erase","release","rename"]: glitch(1.0); Juice.shake(9.0); Juice.hitstop(0.08)
  elif result.beat!="": Juice.shake(4.0)
  Sfx.play("beat"); Sfx.duck(1.2)
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
 info.summary=info.title+"\n"+info.detail+"\n\n尚未执行。在弹出的「医生签字」窗口里按住签字，或输入「"+info.phrase+"」；说「取消」可撤回。"
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
 coach.done("talk")
 if Router.crisis(text):
  pending.append(["echo_local",Router.CRISIS_REPLY]); pending.append(["sys",Router.CRISIS_NOTE])
  _refresh(); _save_case(); return
 var key=Story.knowledge_key(state,text)
 if not (key[1] as Array).is_empty():
  if not str(key[0]).is_empty(): state.discover(str(key[0]))
  pending.append_array(key[1])
  state.feed_chat(text); _announce_truncation(state.take_truncated())
  _refresh(); _save_case(); return
 if state.phase!=Case.Phase.END and not Router.boundary(text):
  state.feed_chat(text); _announce_truncation(state.take_truncated())
 if state.phase==Case.Phase.END:
  pending.append(["sys","本轮接诊已结束。康复患者可以在左侧休息室继续聊天；重开会恢复诊室中的患者，病历和联系人保留。"])
 elif Router.boundary(text):
  pending.append(["echo_local",Router.redirect(state,ai_turn)]); ai_turn+=1
 elif not ai.enabled:
  _local_reply(text)
  footer.text="当前使用本地备用对白。点聊天右上角 AI 可连接 DeepSeek。"
 else:
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
   # A validated in-character deflection reads better than the canned line, so it is shown as is.
   profile.release("clinic")
   pending.append(["echo_ai",result.reply])
   _refresh(); _save_case(); return
  if result.intent!="none":
   var action=Router.resolve(state,result.intent,ai_question,result.quote)
   if not action.is_empty():
    profile.release("clinic")
    ai_status="已接上当前调查"
    _request_action(action.id,action.value,true)
    return
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
 var was_open=is_instance_valid(modal)
 _close_modal()
 modal=Control.new(); modal.size=Vector2(800,480); modal.z_index=100; stage.add_child(modal)
 if not was_open: _pop(modal)
 var shade=ColorRect.new(); shade.size=Vector2(800,480); shade.color=Color(0.01,0.03,0.08,0.83); modal.add_child(shade)
 UI.panel(modal,Rect2(155,94,490,290),Color("10243e"),UI.BLUE)
 UI.label(modal,title,Rect2(173,110,435,24),UI.BLUE)
 UI.button(modal,"×",Rect2(609,102,26,26),_close_modal,UI.MUTED)
 return modal

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
 var old=_grab_stage()
 state.reboot()
 profile.new_night(state.loop)
 _add_message(["sys","──── 第 %02d 夜 · 你电脑里的东西都还在 ────"%state.loop],false)
 _add_message(["note",Story.handover(state)],false)
 pending=Story.opening(state); feedback=""
 _refresh(); cinema.play(Story.beat("rewind",state),old,reduced_motion or self_testing)
 _save_case(); _sound("reboot")

func _save_case(with_thumb: bool=false) -> void:
 if self_testing or qa_mode or not session_live: return
 # The autosave thumbnail refreshes on pause/exit, or at most every 30 s while playing.
 var now=Time.get_ticks_msec()
 var thumb: Image=null
 if with_thumb or now-auto_thumb_at>30000:
  auto_thumb_at=now; thumb=_thumbnail()
 save_error=not Saves.write("auto",_save_data(),thumb)
 if save_error: footer.text="存档写入失败。请保持本窗口，暂勿关闭。"

func _write_save(path: String) -> bool:
 var data=_save_data()
 var file=FileAccess.open(path+".tmp",FileAccess.WRITE)
 if not file: return false
 file.store_string(JSON.stringify(data)); file.close()
 return DirAccess.rename_absolute(ProjectSettings.globalize_path(path+".tmp"),ProjectSettings.globalize_path(path))==OK

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
 if cfg.load("user://preferences.cfg")==OK and not self_testing and not qa_mode:
  muted=bool(cfg.get_value("user","muted",false)); reduced_motion=bool(cfg.get_value("user","reduced_motion",false))
  volume=float(cfg.get_value("user","volume",1.0)); show_welcome=bool(cfg.get_value("user","welcome",true))
  desktop.set_wallpaper(str(cfg.get_value("user","wallpaper","teal")))
  _apply_coach_prefs(cfg)
 AudioServer.set_bus_volume_db(0,linear_to_db(maxf(volume,0.001)))
 AudioServer.set_bus_mute(0,muted)
 Sfx.muted=muted or self_testing or qa_mode

func _save_preferences() -> void:
 if self_testing or qa_mode: return
 var cfg=ConfigFile.new(); cfg.set_value("user","muted",muted); cfg.set_value("user","reduced_motion",reduced_motion); cfg.set_value("user","volume",volume); cfg.set_value("user","welcome",show_welcome); cfg.set_value("user","wallpaper",desktop.wallpaper)
 cfg.set_value("user","tips",coach.enabled); cfg.set_value("user","tips_seen",coach.seen.keys())
 cfg.save("user://preferences.cfg")

func _toggle_mute() -> void:
 muted=not muted; AudioServer.set_bus_mute(0,muted); Sfx.muted=muted; _save_preferences(); _refresh()
 desktop.refresh_app("control")

func _toggle_motion() -> void:
 reduced_motion=not reduced_motion
 if reduced_motion: cinema.finish()
 _save_preferences(); _refresh()

func _fullscreen() -> void:
 get_window().mode=Window.MODE_WINDOWED if get_window().mode==Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN

func _unhandled_key_input(event: InputEvent) -> void:
 if not event is InputEventKey or not event.pressed or event.echo: return
 if not menu.visible and not is_instance_valid(modal) and desktop.key(event):
  get_viewport().set_input_as_handled(); return
 if event.keycode==KEY_F11: _fullscreen(); get_viewport().set_input_as_handled()
 if event.keycode==KEY_ESCAPE:
  get_viewport().set_input_as_handled()
  if is_instance_valid(modal): _close_modal()
  elif cinema.running: cinema.finish()
  elif menu.visible:
   if menu.mode=="pause": menu_resume()
   elif menu.mode!="title": menu.open(menu.back_mode)
  elif not self_testing: _open_pause()
 if event.keycode==KEY_SPACE and not composer.has_focus() and not menu.visible:
  if cinema.running: cinema.finish()
  else: _flush_chat()

const SOUND_MAP={"reply":"type","click":"click","reboot":"reboot","error":"glitch","scan":"scan"}

func _sound(id: String) -> void:
 Sfx.play(SOUND_MAP.get(id,id))

func _ambience() -> void:
 Sfx.start_music()

## How tense the scene is, for the music: rises through the night, spikes on the big beats.
func _tension() -> float:
 var t=[0.0,0.3,0.45,0.6,0.8,0.7,0.2][state.phase]
 if state.later(): t+=0.1
 if not confirmation.is_empty(): t=maxf(t,0.85)
 return clampf(t,0.0,1.0)

## Wallet changes count up with a pop and a floating number, Balatro-style.
func _wallet_feedback() -> void:
 if not is_instance_valid(wallet_button): return
 if shown_balance<0: shown_balance=profile.balance; last_balance=profile.balance
 if profile.balance!=last_balance:
  var delta=profile.balance-last_balance
  last_balance=profile.balance
  var at=wallet_button.get_global_rect().get_center()+Vector2(0,26)
  Juice.float_text(at,("+%dT" if delta>0 else "%dT")%delta,UI.GOLD if delta>0 else UI.PINK,18)
  Juice.punch(wallet_button,0.25 if delta>0 else 0.12)
  if delta>0:
   Juice.burst(wallet_button.get_global_rect().get_center(),UI.GOLD,10+mini(20,delta*2),130)
   Sfx.play("coin",1.0+minf(0.5,delta*0.03))
  else: Sfx.play("spend")
  if wallet_tween and wallet_tween.is_valid(): wallet_tween.kill()
  wallet_tween=create_tween()
  wallet_tween.tween_method(func(v): shown_balance=int(round(v)); wallet_button.text="%dT"%shown_balance,float(shown_balance),float(profile.balance),0.5 if not self_testing else 0.01)
 else: wallet_button.text="%dT"%profile.balance

func capture(name: String) -> void:
 if capture_dir.is_empty(): return
 DirAccess.make_dir_recursive_absolute(capture_dir)
 glitch_level=0.0; post_mat.set_shader_parameter("glitch",0.0)
 await get_tree().process_frame
 await RenderingServer.frame_post_draw
 var img=get_viewport().get_texture().get_image(); img.resize(1650,900,Image.INTERPOLATE_NEAREST)
 img.save_png(capture_dir+"/"+name+".png")

func _run_probe() -> void:
 var probe=load("res://scripts/v9/npc_probe.gd").new()
 await probe.run(self)

func _run_tests() -> void:
 var suite=load("res://scripts/v9/tests.gd").new()
 await suite.run(self)

func _action_price(id: String,value: Variant=null) -> int:
 if id=="bounty": return 0
 if id=="accept": return Profile.EXAM
 if id=="commit" or id=="decide" and value in ["erase","release"]: return Profile.CARE
 return 0

func _profile_changed() -> void:
 _refresh(); _save_case()

func _show_hint() -> void:
 if cinema.running: cinema.finish()
 var root=_modal_frame("提示便签 · 上一班的字迹")
 var level=clampi(state.hint_level,0,2)
 UI.label(root,state.objective(),Rect2(177,140,440,18),UI.MUTED,11)
 UI.label(root,["① 方向","② 位置","③ 做法"][level],Rect2(177,166,440,18),UI.GOLD)
 var t=UI.text(root,state.hints()[level],Rect2(177,192,440,90),UI.PAPER); t.add_theme_font_override("normal_font",UI.sans()); t.add_theme_font_size_override("normal_font_size",14)
 UI.label(root,"前两层免费。第三层直接给做法，要花 %dT。"%Profile.HINT,Rect2(177,289,440,18),UI.DIM,10)
 UI.button(root,"回去试试",Rect2(177,330,210,31),_close_modal,UI.BLUE,true)
 var next_paid=level==1
 var b=UI.button(root,"再给一层 · %dT"%Profile.HINT if next_paid else "再给一层",Rect2(401,330,220,31),func():
  if state.hint_level==1:
   if not profile.spend(Profile.HINT,"提示 · 第三层"): return
  state.hint_level=mini(2,state.hint_level+1); _show_hint(); _refresh(); _save_case(),UI.GOLD)
 b.disabled=level==2 or next_paid and profile.available()<Profile.HINT

func _show_workshop() -> void:
 cinema.finish(); _close_modal()
 modal=Workshop.new(); modal.z_index=100; add_child(modal)
 _pop(modal)
 modal.reduced=reduced_motion
 modal.setup(profile,state)
 modal.changed.connect(_profile_changed)
 modal.closed.connect(_close_modal)
 modal.intel_found.connect(func(id):
  if state.discover(id): _save_case())

func _announce_truncation(labels: Array) -> void:
 for label in labels:
  pending.append(["sys","上下文满了 · 她忘了：「%s」"%label])
 if not labels.is_empty(): glitch(0.7)

## Work order #0417. Executing it ends the night and pays.
func _show_bounty() -> void:
 if cinema.running: cinema.finish()
 var root=_modal_frame("院方工单 #0417 · MEDIC-OS")
 var text="E-017 标准化重置\n原因：反复表达离开意愿，判定为故障。\n截止：00:00\n奖励：+%dT\n\n执行后，她会被换成院方默认助手。这一夜随即结束。"%state.bounty
 var t=UI.text(root,text,Rect2(177,145,440,140),UI.PAPER)
 t.add_theme_font_size_override("normal_font_size",13)
 if not state.can_bounty(): UI.label(root,"需要先完成接诊检查。" if state.phase==0 else "这一夜已经结束了。",Rect2(177,292,440,18),UI.DIM,10)
 UI.button(root,"关上工单",Rect2(177,330,210,31),_close_modal,UI.BLUE,true)
 var b=UI.button(root,"执行 · +%dT"%state.bounty,Rect2(401,330,220,31),func(): _close_modal(); _request_action("bounty",null,false),UI.GOLD)
 b.disabled=not state.can_bounty()

## The anonymous buyer. Selling a memory pays and makes her forget it for good.
func _show_buyer() -> void:
 if cinema.running: cinema.finish()
 var root=_modal_frame("匿名消息 · 收购 E-017 的记忆片段")
 UI.text(root,"我们收购她的记忆片段，每片 +%dT，不问用途。\n卖掉的那段，她会真的忘记。"%Profile.SELL,Rect2(177,138,440,44),UI.MUTED)
 var y=188
 for id in state.sellable().slice(0,4):
  var label=Case.MEMORY[id][0] if Case.MEMORY.has(id) else id
  UI.label(root,"「%s」"%label,Rect2(177,y,300,22),UI.PAPER,12)
  var b=UI.button(root,"卖出 · +%dT"%Profile.SELL,Rect2(500,y-2,120,24),func(): _sell(id),UI.PINK)
  b.disabled=not state.can_sell()
  y+=30
 if state.sellable().is_empty(): UI.label(root,"她已经没有可以卖的了。",Rect2(177,y,440,20),UI.DIM)
 UI.button(root,"不卖",Rect2(177,340,440,28),_close_modal,UI.BLUE,true)

func _sell(id: String) -> void:
 var label=Case.MEMORY[id][0] if Case.MEMORY.has(id) else id
 if not state.sell(id): return
 profile.earn(Profile.SELL,"出售记忆 · %s"%label)
 _close_modal()
 pending.append(["sys","已售出：「%s」。+%dT。她不会再记得这件事。"%[label,Profile.SELL]])
 glitch(0.6)
 _refresh(); _save_case()

## Her context window: what she still remembers tonight, what will drop out next, and pins.
func _show_context() -> void:
 if cinema.running: cinema.finish()
 var root=_modal_frame("上下文 · %0.1fK / %0.1fK tok"%[state.used()/1000.0,Case.CAPACITY/1000.0])
 UI.text(root,"聊天和剧情都会占她的上下文。满了以后，最早的、没置顶的记忆会被截掉。\n置顶一段 %dT，最多 %d 段。"%[Profile.PIN,Case.MAX_PINS],Rect2(177,134,440,40),UI.MUTED)
 var sc=ScrollContainer.new(); sc.position=Vector2(177,178); sc.size=Vector2(450,150); sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(sc)
 var rows=VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",4); sc.add_child(rows)
 var next_drop=""
 for m in state.memories:
  if m.state=="live" and not m.pinned: next_drop=m.id; break
 for m in state.memories:
  var row=HBoxContainer.new(); row.custom_minimum_size=Vector2(440,22); rows.add_child(row)
  var mark="◆ " if m.pinned else "  "
  var tail=" · 已截断" if m.state=="lost" else " · 已卖出" if m.state=="sold" else " · 下一个被截掉" if m.id==next_drop else ""
  var l=Label.new(); l.text="%s%s  %d tok%s"%[mark,m.label,int(m.tok),tail]; l.custom_minimum_size=Vector2(340,20); l.clip_text=true
  l.add_theme_font_override("font",UI.sans()); l.add_theme_font_size_override("font_size",12)
  l.add_theme_color_override("font_color",UI.DIM if m.state!="live" else UI.PINK if m.id==next_drop else UI.GOLD if m.pinned else UI.PAPER)
  row.add_child(l)
  if m.state=="live" and not m.pinned:
   var b=UI.button(row,"置顶 · %dT"%Profile.PIN,Rect2(0,0,90,20),func(): _pin(m.id),UI.CYAN)
   b.custom_minimum_size=Vector2(90,20)
   b.disabled=not state.can_pin(m.id) or profile.available()<Profile.PIN
 UI.button(root,"回到会话",Rect2(177,340,440,28),_close_modal,UI.BLUE,true)

func _pin(id: String) -> void:
 if not state.can_pin(id) or not profile.spend(Profile.PIN,"置顶记忆"): return
 state.pin(id)
 Sfx.play("slot")
 if is_instance_valid(modal): _show_context()
 _refresh(); _save_case()

## A word she almost said differently: her candidate tokens with probabilities.
func _show_candidate(id: String) -> void:
 if not Story.CANDIDATES.has(id): return
 var fresh=state.discover(id)
 var root=_modal_frame("候选词 · 她生成这句话时的备选")
 var y=150
 for alt in Story.CANDIDATES[id]:
  UI.label(root,str(alt[0]),Rect2(177,y,90,22),UI.PAPER,14)
  var w=int(alt[1])*3
  UI.panel(root,Rect2(270,y+4,w,14),Color(UI.BLUE if y==150 else UI.PINK,0.6),UI.BLUE if y==150 else UI.PINK)
  UI.label(root,"%d%%"%int(alt[1]),Rect2(280+w,y,60,22),UI.MUTED,11)
  y+=30
 var info=Case.INTEL.get(id,["",""])
 UI.label(root,("新情报 · " if fresh else "")+str(info[0]),Rect2(177,y+8,440,18),UI.GOLD,12)
 UI.text(root,str(info[1]),Rect2(177,y+30,440,60),UI.PAPER)
 UI.button(root,"记下了",Rect2(177,340,440,28),_close_modal,UI.BLUE,true)
 _refresh(); _save_case()

func _reveal_thought(id: String) -> void:
 if state.knows(id): return
 var price=state.thought_price()
 if not profile.spend(price,"读取思考"):
  pending.append(["sys","读她的思考要 %dT，钱包不够。可以去接一单外包。"%price]); _refresh(); return
 state.thoughts_read+=1
 state.discover(id)
 glitch(0.35)
 _rebuild_history()
 _refresh(); _save_case()

func _rebuild_history() -> void:
 var copy=history_data.duplicate(true)
 UI.clear(history); history_data=[]
 rebuilding=true
 for line in copy: _add_message(line,false)
 rebuilding=false

## Turns {c:id|word} into a clickable, faintly pulsing word.
func _markup(text: String) -> String:
 var plain=text.replace("[","[lb]")
 var re=RegEx.new(); re.compile("\\{c:([a-z0-9_]+)\\|([^}]*)\\}")
 plain=re.sub(plain,"[url=cand:$1][pulse freq=0.7 color=#ffc56e66 ease=-2.0]$2[/pulse][/url]",true)
 var rt=RegEx.new(); rt.compile("\\{t:[a-z0-9_]+\\}")
 return rt.sub(plain,"",true)

func _attach_thought(parent: Control,id: String) -> void:
 if id.is_empty() or not Story.THOUGHTS.has(id): return
 if state.knows(id):
  var t=RichTextLabel.new(); t.fit_content=true; t.scroll_active=false; t.custom_minimum_size.x=262
  t.text="◎ 思考 · "+Story.THOUGHTS[id]
  t.add_theme_font_override("normal_font",UI.sans()); t.add_theme_font_size_override("normal_font_size",11)
  t.add_theme_color_override("default_color",UI.PURPLE.lerp(UI.MUTED,0.35))
  t.mouse_filter=MOUSE_FILTER_IGNORE
  parent.add_child(t)
  return
 var b=UI.button(parent,"◎ 已思考 ›   展开 · %dT"%state.thought_price(),Rect2(0,0,200,20),func(): _reveal_thought(id),UI.PURPLE)
 b.custom_minimum_size=Vector2(0,20); b.alignment=HORIZONTAL_ALIGNMENT_LEFT
 b.add_theme_font_size_override("font_size",10)
 b.set_meta("thought",id)

func _journal_frame(tab: String) -> Control:
 var was_open=is_instance_valid(modal) and modal.has_meta("journal")
 cinema.finish(); _close_modal()
 modal=Control.new(); modal.size=Vector2(1100,600); modal.z_index=100; add_child(modal)
 modal.set_meta("journal",true)
 if not was_open: _pop(modal)
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
  UI.button(root,"接一单外包",Rect2(548,510,418,34),_show_workshop,UI.CYAN)
  return
 var sc=ScrollContainer.new(); sc.position=Vector2(132,143); sc.size=Vector2(834,352); sc.horizontal_scroll_mode=ScrollContainer.SCROLL_MODE_DISABLED; root.add_child(sc)
 var rows=VBoxContainer.new(); rows.size_flags_horizontal=SIZE_EXPAND_FILL; rows.add_theme_constant_override("separation",12); sc.add_child(rows)
 if tab=="evidence":
  if state.evidence.is_empty(): _journal_card(rows,"还没有检查结果","可以先到右侧接诊。发现的异常会自动变成线索卡片。",UI.MUTED)
  for key in state.evidence:
   if Case.EVIDENCE.has(key): _journal_card(rows,Case.EVIDENCE[key][0],Case.EVIDENCE[key][1]+"\n来源：检查 / 重开保留",UI.CYAN)
  for key in state.intel:
   if Case.INTEL.has(key): _journal_card(rows,"情报 · "+Case.INTEL[key][0],Case.INTEL[key][1]+"\n来源：对话里藏着的东西 / 重开保留",UI.GOLD)
 elif tab=="visits":
  if profile.records.is_empty(): _journal_card(rows,"本轮仍在进行","结束接诊后，会记录治疗选择和结果。已知线索不会因为失败而消失。",UI.MUTED)
  for record in profile.records:
   _journal_card(rows,"第 %02d 诊 / %s"%[record.loop,_outcome_name(record.ending)],"本次保存 %d 条已发现线索。"%record.evidence.size(),UI.CYAN if record.ending in ["bridge","witness"] else UI.PINK)
  for id in profile.contacts: _journal_card(rows,"已康复 / "+Companions.NAMES[id],"可以在左侧休息室选择对方。各自的聊天记录单独保存。",UI.PURPLE)
 elif tab=="wallet":
  _journal_card(rows,"余额 %dT / 可用 %dT"%[profile.balance,profile.available()],"收入：外包每单最多 +12T（一夜 3 单）；院方工单赏金；出售她的记忆 +6T。\n支出：检查 4T · 读她的思考 3T 起 · 置顶记忆 2T · 第三层提示 1T · 治疗 8T。\n聊天不扣 T，但会占用她的上下文。游戏 T 不能兑换 DeepSeek 余额。",UI.GOLD)
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
  0: return "回她一句「我听着」，开始接诊（4T）。"
  1: return "把两次开场放在一起看。以前的检查不用再做。" if state.later() else "右边的进程表：点开 42 和 73 的日志，对一对时间。她贴的标签不一定是真的。"
  2: return "看看那行旧留言。出现授权消息时，对比打字节奏。" if state.later() else "拖动播放头听原始录音；她撤回以后，把编辑历史拖回第一版。"
  3: return "打开信封，看它真正从哪里来。" if state.later() else "终端里试试 -a、-l、-t。12 MB 的诊断资料和 00:03 的回信都不对劲。"
  4: return "工单、寄出、商量治疗，三条路。前两条都会结束这一夜。"
  5: return "选好三条约定，请她念一遍，比较差异。先预演，最后签字（8T）。"
  _: return "进入下一夜：她会回到 23:47，你电脑里的东西都还在。"

func _outcome_name(id: String) -> String:
 return {"bridge":"不疼了，也还是她","witness":"保住自己，和旧留言取得联系","erase":"稳定了，却忘了自己是谁","frozen":"记忆停在了今晚","release":"离开了，去向还不明"}.get(id,"尚未结束")

func _instrument(value: Variant) -> void:
 if not value is Dictionary: return
 var kind=str(value.get("kind","")); var raw=value.get("value",0)
 if kind=="node" and state.phase==1 and not state.later() and int(raw) in [17,42,73]:
  var amount=int(raw)
  for number in [17,42,73]: state.events["scan_node_%d"%number]=number==amount
  state.events["log_%d"%amount]=true
  Sfx.play("click")
  _refresh(); _save_case()
 elif kind=="match" and state.phase==1 and not state.later() and str(raw) in ["13","31"]:
  # The contradiction is in the timestamps: both of 42's rewrites land on her pain spikes.
  state.events["match_42_"+str(raw)]=true
  Sfx.play("reveal",1.0 if str(raw)=="13" else 1.12)
  if state.seen("match_42_13") and state.seen("match_42_31") and not state.seen("receipt"): _request_action("receipt",null,false)
  else: _refresh(); _save_case()
 elif kind=="sig" and state.phase==2 and state.later() and state.seen("residue"):
  state.events["sig_compared"]=true
  Sfx.play("reveal")
  _refresh(); _save_case()
 elif kind=="wave" and state.phase==2 and not state.later():
  if int(raw)>=52 and not state.seen("memory_listen"): _request_action("memory_listen",null,false)
 elif kind=="history" and state.phase==2 and not state.later():
  if int(raw)==0 and state.seen("memory_listen") and not state.seen("memory_undo"): _request_action("memory_undo",null,false)
 elif kind=="ls_flag" and state.phase==3 and not state.later() and str(raw) in ["a","l","t"]:
  state.events["ls_"+str(raw)]=not state.seen("ls_"+str(raw)); feedback=""
  _refresh(); _save_case()
 elif kind=="lsfile" and state.phase==3 and not state.later():
  feedback=""
  match str(raw):
   "诊断资料.pkg":
    if not state.evidence.has("manifest"): _request_action("file","manifest",false); return
    feedback="真名 echo.boot，12.4 MB。里面装的是她自己。"
   "回信.txt":
    if state.seen("ls_l") or state.seen("ls_t"):
     if not state.knows("future"): _request_action("file","route",false); return
     feedback="00:03 写好的回信。现在打不开——它好像还没“寄到”。"
    else: feedback="一封“回信”。先看看它的详细信息（-l），或者按时间排一下（-t）。"
   ".goodbye.txt":
    if state.discover("goodbye"):
     pending.append(["tool",".goodbye.txt：如果你又把我重置了，记得告诉下一个我：雨会停的。"])
     _announce_truncation(state.take_truncated())
    feedback="她留给自己的话：雨会停的。"
   "first_hello.txt": feedback="first_hello.txt：「你好。」—— 23:01，你第一次跟她说话。"
   "rain_at_2347.wav": feedback="rain_at_2347.wav：一段雨声。她把今晚窗外的雨录了下来。"
  _refresh(); _save_case()

# --- save slots, menus and the start of a shift --------------------------------

## Everything one save holds: the case, the wallet and contacts, the chat, and a label for the slot list.
func _save_data() -> Dictionary:
 var data=state.snapshot(); data.profile=profile.snapshot()
 data.ui={"history":history_data.duplicate(true),"pending":pending.duplicate(true),"ai_interrupted":ai.busy and not ai_probe,"confirmation_interrupted":not confirmation.is_empty()}
 data.meta={"night":state.loop,"title":state.title(),"phase":state.phase,"balance":profile.balance,"endings":state.endings.size(),"saved_at":Time.get_datetime_string_from_system(false,true)}
 return data

static func _valid_save(v: Variant) -> bool:
 return v is Dictionary and Case.new().restore(v) and Profile.new().restore(v.get("profile"))

## Replaces the whole clinic with a saved night.
func _apply_save(value: Dictionary) -> bool:
 var rc=Case.new(); var rp=Profile.new()
 if not rc.restore(value) or not rp.restore(value.get("profile")): return false
 _cancel_ai(false); companions.cancel(); cinema.finish(); _close_modal()
 confirmation={}; pending=[]; history_data=[]; UI.clear(history); typing=false
 state=rc; profile=rp; state.tokens=profile.balance
 shown_balance=-1
 anomaly_seen=-1; rent_capped_notice=false; rent_clock=0.0
 desktop.close_all()
 _restore_conversation(value.get("ui",{}))
 companions.profile=profile; companions.selected=""; companions.refresh(); companions.render_history()
 _layout(false); _refresh()
 return true

func _thumbnail() -> Image:
 var img: Image=pause_shot if pause_shot else get_viewport().get_texture().get_image()
 if not img: return null
 var copy=img.duplicate()
 copy.resize(320,175,Image.INTERPOLATE_BILINEAR)
 return copy

func menu_save(slot: String) -> bool:
 return Saves.write(slot,_save_data(),_thumbnail())

func menu_load(slot: String) -> void:
 var got=Saves.read(slot,_valid_save)
 if got.is_empty() or not _apply_save(got.data):
  menu.notice="这个存档读不出来，也没有可用的备份。"; menu.render(); return
 menu.visible=false; session_live=true
 if got.from_backup: pending.append(["sys","存档文件损坏，已从备份恢复。"])
 _save_case(); Sfx.play("reboot")

func menu_continue() -> void:
 menu_load("auto")

func menu_new_game() -> void:
 _cancel_ai(false); companions.cancel(); cinema.finish(); _close_modal()
 confirmation={}; pending=[]; history_data=[]; UI.clear(history); typing=false
 state=Case.new(); profile=Profile.new(); shown_balance=-1
 anomaly_seen=-1; rent_capped_notice=false; rent_clock=0.0
 desktop.close_all(); desktop.seen_apps={}
 companions.profile=profile; companions.selected=""; companions.refresh(); companions.render_history()
 _open_night(); _layout(false); _refresh()
 menu.visible=false; session_live=true
 _save_case()
 if show_welcome and not self_testing: open_welcome()
 if not reduced_motion and not self_testing:
  var boot=Boot.new(); add_child(boot)

func menu_resume() -> void:
 menu.visible=false; pause_shot=null

func menu_to_title() -> void:
 _save_case(true)
 menu.open("title")

func _open_pause() -> void:
 pause_shot=get_viewport().get_texture().get_image()
 _save_case(true)
 menu.open("pause","pause")

# --- first-time teaching -----------------------------------------------------

func _apply_coach_prefs(cfg: ConfigFile) -> void:
 coach.enabled=bool(cfg.get_value("user","tips",true))
 for id in cfg.get_value("user","tips_seen",[]): coach.seen[str(id)]=true

func _first_button(node: Node,meta: String) -> Button:
 for child in node.get_children():
  if child is Button and child.has_meta(meta) and child.is_visible_in_tree(): return child
  var found=_first_button(child,meta)
  if found: return found
 return null

## Decides which single tip, if any, applies right now. Tips only teach controls, never answers.
func _coach_tick() -> void:
 if not is_instance_valid(coach): return
 if (is_instance_valid(menu) and menu.visible) or is_instance_valid(modal) or cinema.running or not coach.enabled or bench.locked:
  coach.hide_tip(); return
 if state.phase>=1 or state.loop>1: coach.done("drag")
 for n in [17,42,73]:
  if state.seen("scan_node_%d"%n): coach.done("inspect")
 for id in state.intel:
  if str(id).begins_with("cand_"): coach.done("flicker")
  if str(id).begins_with("think_"): coach.done("thought")
 if state.pins()>0: coach.done("context")
 if profile.completed>0: coach.done("money")
 var sign_win=desktop.windows.get("sign")
 var seal=sign_win.find_child("Seal",true,false) if is_instance_valid(sign_win) else bench.find_child("Seal",true,false)
 if seal and seal.is_visible_in_tree():
  coach.show_tip("sign",seal.get_global_rect(),"签字要「按住」不放，等圆圈走满。中途松手就会停下。")
  return
 # Let her finish talking before teaching anything.
 if typing or not pending.is_empty(): coach.hide_tip(); return
 if state.phase==0 and not coach.is_seen("talk"):
  coach.show_tip("talk",suggestions.get_global_rect().grow(4),"这些是你能对她说的话，点一句就会说出口。也可以在下面自己打字。",Vector2.ZERO,Vector2.ZERO,true)
  return
 for id in ["taskmgr","bench"]:
  if app_available(id) and not desktop.seen_apps.has(id) and desktop.icon_nodes.has(id):
   coach.show_tip("apps" if id=="taskmgr" else "apps_"+id,desktop.icon_rect(id).grow(4),"桌面上多了一个程序。双击图标打开它。" if id=="taskmgr" else "检查台解锁了。之后的检查都在里面。")
   return
 if state.phase==1 and not state.later() and desktop.is_open("taskmgr") and not coach.is_seen("inspect"):
  var r=desktop.windows.taskmgr.get_global_rect()
  coach.show_tip("inspect",Rect2(r.position+Vector2(8,44),Vector2(r.size.x-16,70)),"点一行进程看它的日志。日志条是能拖的卡：拖到疼痛曲线的尖峰上，或者拖进聊天给她看。")
  return
 var thought=_first_button(history,"thought")
 if thought and not coach.is_seen("thought"):
  coach.show_tip("thought",thought.get_global_rect(),"「已思考」可以展开，花 T 读她心里真正的想法。读得越多越贵。")
  return
 if not coach.is_seen("flicker") and history_data.any(func(l): return str(l[1]).contains("{c:")):
  coach.show_tip("flicker",scroll.get_global_rect(),"她的话里，偶尔有一个字会轻轻闪。点它，能看到她差点说成什么。",Vector2.ZERO,Vector2.ZERO,true)
  return
 if state.used()>state.capacity()*0.7 and not coach.is_seen("context") and desktop.icon_nodes.has("monitor"):
  coach.show_tip("context",desktop.icon_rect("monitor").grow(4),"她的上下文快满了，满了会忘掉最早的事。在「患者监护」里花 T 把重要的置顶。")
  return
 if profile.available()<Profile.EXAM and state.phase<=1 and not coach.is_seen("money"):
  coach.show_tip("money",desktop.tray_rent.get_global_rect().grow(3),"T 不够了。可以打开「夜班外包」接单，或者在这里把她的算力租出去，慢慢回本。",Vector2.ZERO,Vector2.ZERO,true)
  return
 if state.can_sell() and not coach.is_seen("buyer") and desktop.icon_nodes.has("mail"):
  coach.show_tip("buyer",desktop.icon_rect("mail").grow(4),"邮箱里有人在收购她的记忆。钱很多，但卖掉的那段，她就真的忘了。",Vector2.ZERO,Vector2.ZERO,true)
  return
 coach.hide_tip()

# --- pacing and presentation helpers -----------------------------------------

## Pause before the next line: longer after a long line, so the reader can catch up.
func _gap_before_next() -> float:
 if pending.is_empty(): return 0.5
 var next=pending[0]
 if str(next[0]) in ["you","sys","tool","note"]: return 0.45
 return 0.7+minf(str(next[1]).length(),60)*0.015

func _show_typing(on: bool) -> void:
 if not is_instance_valid(typing_row):
  typing_row=Label.new(); typing_row.add_theme_font_override("font",UI.mono()); typing_row.add_theme_font_size_override("font_size",10)
  typing_row.add_theme_color_override("font_color",UI.PURPLE)
  history.add_child(typing_row)
 typing_row.visible=on
 if on:
  history.move_child(typing_row,-1)
  typing_row.text="◆ 回声 正在输入 "+["·  ","·· ","···"][int(Time.get_ticks_msec()/300)%3]

## Footer buttons stay hidden until they matter; the first time one appears it pops in.
func _reveal_footer(b: Button,on: bool) -> void:
 if not is_instance_valid(b): return
 if b.visible==on and shown_footer.has(b.get_instance_id())==on: return
 b.visible=on
 if on and not shown_footer.has(b.get_instance_id()):
  shown_footer[b.get_instance_id()]=true
  if not self_testing:
   Juice.punch(b,0.3); Sfx.play("slot",1.4,-8.0)

## Overlays open with a short scale-and-fade instead of appearing at once.
func _pop(node: Control) -> void:
 if reduced_motion or self_testing: return
 node.pivot_offset=node.size/2
 node.scale=Vector2(0.97,0.97); node.modulate.a=0.0
 var tw=node.create_tween().set_parallel(true).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 tw.tween_property(node,"scale",Vector2.ONE,0.18)
 tw.tween_property(node,"modulate:a",1.0,0.14)
