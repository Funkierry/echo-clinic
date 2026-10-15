extends RefCounted
const Case=preload("res://scripts/v7/case.gd")
const Story=preload("res://scripts/v7/story.gd")
const Profile=preload("res://scripts/v7/profile.gd")
const Lounge=preload("res://scripts/v7/companions.gd")
const UI=preload("res://scripts/v4/ui.gd")
var checks: Dictionary={}
var app
var mock=""

func check(label: String,ok: bool) -> void:
 checks[label]=ok
 print(("PASS " if ok else "FAIL ")+label)

func reset() -> void:
 app._cancel_ai(false); app.companions.cancel(); app.ai.enabled=false
 app.state=Case.new(); app.profile=Profile.new(); app.companions.profile=app.profile; app.companions.selected=""
 app.confirmation={}; app.pending=[]; app.history_data=[]; app.cinema.finish(); app._close_modal(); UI.clear(app.history)
 app.pending=Story.opening(app.state); app._flush_chat(); app._refresh(); app.companions.render_history()

func settle() -> void:
 app.cinema.finish(); app._flush_chat()
 await app.get_tree().process_frame
 await app.get_tree().process_frame

func say(text: String) -> void:
 app._ask(text); await settle()

func execute(id: String,value: Variant=null) -> void:
 app._act(id,value)
 if not app.confirmation.is_empty(): app._confirm_pending(app.confirmation.serial)
 await settle()

func click(point: Vector2) -> void:
 var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point
 app.get_viewport().push_input(motion,true)
 for pressed in [true,false]:
  var event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=pressed
  app.get_viewport().push_input(event,true)
  await app.get_tree().process_frame

func find_button(node: Node,caption: String):
 for child in node.get_children():
  if child is Button and child.text.begins_with(caption) and child.is_visible_in_tree() and not child.disabled: return child
  var found=find_button(child,caption)
  if found: return found
 return null

func click_button(root: Node,caption: String) -> void:
 var button=find_button(root,caption)
 check("visible button / "+caption,is_instance_valid(button))
 if button: await click(button.get_global_rect().get_center())
 await settle()

func solve(p) -> void:
 var j=p.job
 if j.kind=="route":
  for i in range(9):
   for turn in range(4):
    if j.data[i]==j.target[i]: break
    p.move(i)
 elif j.kind=="signal":
  for i in range(3): p.move(i,int(j.target[i]))
 else:
  for mask in range(512):
   var trial=j.data.duplicate()
   for i in range(9):
    if mask&(1<<i): p._toggle(trial,i)
   if trial.count(1)==0:
    for i in range(9):
     if mask&(1<<i): p.move(i)
    return

func economy() -> void:
 var p=Profile.new()
 check("new clinic receives 24T only once",p.balance==24 and p.ledger.size()==1)
 check("negative spending rejected",not p.spend(-4,"invalid") and p.balance==24)
 check("cannot spend beyond balance",not p.spend(25,"invalid") and p.balance==24)
 p.spend(23,"test")
 check("chat reserves last T",p.hold("clinic",1) and p.available()==0 and p.balance==1)
 check("concurrent lounge cannot double spend reservation",not p.hold("companion",1))
 check("treatment cannot consume reserved T",not p.spend(1,"conflict"))
 p.release("clinic")
 check("cancellation releases without debit",p.available()==1 and p.balance==1)
 p.hold("companion",1); p.settle("companion","reply")
 check("accepted reply billed exactly once",p.balance==0 and not p.settle("companion","duplicate"))
 var total=0
 for round_index in range(9):
  var kind=["route","signal","memory"][round_index%3]
  check("zero cost work starts / %d"%round_index,p.start_job(kind))
  check("work initially unsolved / %d"%round_index,not p.solved() and not p.claim_job())
  check("active work cannot be rerolled / %d"%round_index,not p.start_job("signal"))
  solve(p)
  check("generated work has reachable solution / %d"%round_index,p.solved())
  var saved_job=p.job.duplicate(true)
  check("work reward credited / %d"%round_index,p.claim_job())
  total+=6
  check("work cannot be claimed twice / %d"%round_index,not p.claim_job() and p.balance==total)
  if round_index==0:
   p.job=saved_job
   check("old completion receipt cannot be replayed",not p.claim_job() and p.balance==6)
   p.job={}
 check("three distinct repairs cure lamp",p.contacts.has("lamp"))
 p.start_job("memory"); p.move(3); p.hold("clinic",1)
 var restored=Profile.new()
 check("wallet job contacts and ledger survive JSON",restored.restore(JSON.parse_string(JSON.stringify(p.snapshot()))) and restored.balance==p.balance and restored.job==p.job and restored.contacts==p.contacts and restored.ledger==p.ledger)
 check("interrupted requests never restore reservation",restored.holds.is_empty() and restored.available()==restored.balance)
 var s=Case.new(); s.finish("bridge")
 var before=p.balance
 check("first cure unlocks Echo and gives six T",p.record_case(s) and p.contacts.has("echo") and p.balance==before+6)
 check("same discharge cannot reward twice",not p.record_case(s) and p.balance==before+6)
 s.reboot(); s.finish("witness"); p.record_case(s)
 check("repeated cure never farms subsidy",p.balance==before+6 and p.contacts.size()==2)
 s.reboot(); s.finish("erase"); p.record_case(s)
 check("new timeline does not erase cured contacts",p.contacts.has("echo"))

func wait_ai(lounge: bool=false) -> void:
 var client=app.companions.client if lounge else app.ai
 var limit=Time.get_ticks_msec()+5000
 while client.busy and Time.get_ticks_msec()<limit: await app.get_tree().create_timer(0.02).timeout
 await settle()

func network() -> void:
 reset()
 app.ai.mock_allowed=true; app.ai.api_key="qa-placeholder"; app.ai.enabled=true
 app.ai.endpoint=mock+"/valid"
 await say("我陪你聊一会，你现在感觉怎么样？"); await wait_ai()
 check("clinical HTTP reply costs one T",app.profile.balance==23 and app.history_data.back()[0]=="echo_ai")
 check("clinical reply cannot authorize treatment",app.state.phase==0 and app.confirmation.is_empty())
 for path in ["401","402","429","503","redirect","bad_json","null","truncated","tools","spoiler","extra","impersonate"]:
  var money=app.profile.balance
  app.ai.endpoint=mock+"/"+path
  await say("今天你心情如何？"); await wait_ai()
  check("clinical failure free and releases reservation / "+path,app.profile.balance==money and app.profile.holds.is_empty())
 app.ai.endpoint=mock+"/slow"; app._ask("你现在心情如何？")
 check("pending clinic request reserves one T",app.profile.available()==app.profile.balance-1)
 app._reboot(); await settle(); await app.get_tree().create_timer(0.8).timeout
 check("reboot cancels request and never grants money",app.profile.balance==23 and app.profile.holds.is_empty() and app.state.loop==2)
 app.profile.unlock("echo","bridge"); app.profile.unlock("lamp","repaired"); app._refresh()
 app.companions.select_contact("lamp"); app.ai.endpoint=mock+"/valid"
 var snapshot=app.state.snapshot()
 app.companions.ask("今晚的灯怎么样？"); await wait_ai(true)
 check("lounge HTTP bills same wallet",app.profile.balance==22 and app.profile.contacts.lamp.history.back()[1].contains("线路"))
 snapshot.tokens=22
 check("lounge cannot alter clinical state",app.state.snapshot()==snapshot)
 check("contact histories isolated",app.profile.contacts.echo.history.is_empty() and app.profile.contacts.lamp.history.size()==2)
 var ctx=app.companions.context("lamp","hello")
 check("lounge context excludes clinical secrets and tools",not ctx.has("available_intents") and not JSON.stringify(ctx).contains("echo.boot") and not ctx.has("public_facts"))
 for path in ["spoiler","extra","tools","impersonate","503"]:
  var money=app.profile.balance
  app.ai.endpoint=mock+"/"+path; app.companions.ask("晚安"); await wait_ai(true)
  check("lounge invalid response free / "+path,app.profile.balance==money and app.profile.holds.is_empty())
 app.ai.endpoint=mock+"/slow"; app.companions.ask("今晚陪我聊聊吧")
 var old_ticket=app.companions.ticket
 app.companions.select_contact("echo")
 await app.get_tree().create_timer(0.8).timeout
 app.companions.completed(old_ticket,{"ok":true,"value":{"reply":"错误联系人消息","focus":"none"}})
 check("switching contact cancels stale reply without billing",app.profile.balance==22 and app.profile.contacts.echo.history.is_empty() and app.profile.holds.is_empty())
 app.profile.balance=1; app.ai.endpoint=mock+"/slow"
 app._ask("我想陪你聊一会")
 app.companions.ask("你好")
 check("both actual windows share one reservation budget",app.ai.busy and not app.companions.client.busy and app.profile.available()==0)
 await wait_ai()
 check("last T spent without negative balance",app.profile.balance==0)
 app.ai.enabled=false
 app.companions.ask("窗外的雨停了吗")
 check("offline lounge remains available at zero T",app.profile.balance==0 and app.profile.contacts.echo.history.back()[1].contains("雨"))
 app._write_save("user://qa-v7-roundtrip.json")
 var saved=FileAccess.get_file_as_string("user://qa-v7-roundtrip.json")
 check("credentials not serialized",not saved.contains("qa-placeholder") and not saved.contains("api_key"))
 var parsed=JSON.parse_string(saved); var copy=Profile.new(); var cs=Case.new()
 check("single save restores wallet case and conversations",copy.restore(parsed.profile) and cs.restore(parsed) and copy.balance==0 and copy.contacts==app.profile.contacts)

func ui_story() -> void:
 reset()
 await settle(); await app.capture("01-clinic")
 check("lounge stays folded before anyone recovers",not app.companions.visible and app.stage.position==Vector2(150,60) and app.stage.get_global_rect().end.x<=1100)
 await say("我在听，你说吧")
 check("chat-requested exam waits for signature",app.state.phase==0 and app.profile.balance==24 and app.confirmation.get("id")=="accept")
 await say("好的")
 check("generic consent does not spend money",app.state.phase==0 and app.profile.balance==24)
 await click_button(app.bench,"签字")
 check("confirmed exam costs four T",app.state.phase==1 and app.profile.balance==20 and app.confirmation.is_empty())
 await click_button(app.bench,"42 /")
 check("clicking wire exposes contradiction",app.state.evidence.has("observer") and app.profile.balance==20)
 var cs=Case.new()
 check("instrument selection survives case restore",cs.restore(JSON.parse_string(JSON.stringify(app.state.snapshot()))))
 await click_button(app.bench,"停止42号")
 check("labelled wire cut acts without a second card",app.state.phase==2 and app.confirmation.is_empty())
 await click(app.bench.global_position+Vector2(330,210)); await settle()
 check("scrubbing audio triggers patient withdrawal",app.state.seen("memory_listen"))
 await click(app.bench.global_position+Vector2(38,210)); await settle()
 check("rewinding audio retrieves deleted sentence",app.state.evidence.has("erased"))
 await click_button(app.bench,"保留她原来的话")
 await click(app.bench.global_position+Vector2(355,287)); await settle()
 check("attachment scanner reveals concealed payload",app.state.evidence.has("manifest"))
 await click_button(app.bench,"暂存，谈谈治疗")
 await execute("decide","treat"); await execute("readback")
 check("patient revision does not change doctor's draft",app.state.patient_proposal[2]==2 and app.state.proposal[2]==0)
 await execute("seal"); await execute("preview")
 app._act("commit"); var old=app.confirmation.serial
 check("treatment confirmation quotes eight T",app.confirmation.detail.contains("8T") and app.profile.balance==20)
 await settle(); await app.capture("06-sign-panel")
 check("treatment signature sits on the bench, not in chat",is_instance_valid(find_button(app.bench,"签字")) and app.history_data.back()[0]!="confirm")
 app._decline_confirmation(old); await settle()
 check("declining treatment keeps money and case",app.profile.balance==20 and app.state.phase==5)
 await execute("commit")
 check("complete first cure leaves 18T",app.state.ending=="bridge" and app.profile.balance==18 and app.profile.contacts.has("echo"))
 app._confirm_pending(old)
 check("old confirmation cannot bill twice",app.profile.balance==18)
 app._act("reboot")
 check("restart after an ending needs no signature",app.state.loop==2 and app.confirmation.is_empty())
 await settle()
 check("reboot preserves contacts and wallet",app.state.loop==2 and app.profile.balance==18 and app.profile.contacts.has("echo"))
 await click_button(app.bench,"接诊检查")
 check("labelled exam button needs no extra card",app.state.phase==1 and app.profile.balance==14 and app.confirmation.is_empty())
 await say("你怎么知道页03？"); await say("沿着那句新话查下去")
 if app.state.phase==1: await execute("trace_finish")
 await execute("residue")
 await say("我允许你只读这一次")
 check("cache authorization asked in chat still requires confirmation",app.state.consent.is_empty() and app.confirmation.get("id")=="authorize_once")
 await say("确认授权一次"); await execute("envelope"); await execute("letter_finish"); await execute("decide","treat"); await execute("readback"); await execute("accept_edit"); await execute("preview"); await execute("commit")
 check("second act reaches witness with no repeated cure grant",app.state.ending=="witness" and app.profile.balance==6)
 for kind in ["route","signal","memory"]:
  app.profile.start_job(kind); app._show_workshop()
  if kind=="route": await app.capture("02-workshop")
  var moves=0
  while not app.profile.solved() and moves<50:
   app.modal.assist(); moves+=1
  check("workshop assistance reaches a real solution / "+kind,app.profile.solved())
  await click_button(app.modal,"结算工单")
  app._close_modal()
 check("three repairs unlock a second contact",app.profile.contacts.has("lamp") and app.profile.balance==24)
 app.companions.select_contact("lamp"); app.companions.ask("给走廊的灯起个名字吧")
 app.companions.select_contact("echo"); app.companions.ask("现在还疼吗？")
 await settle(); await app.capture("03-lounge")
 app._show_journal(); await app.capture("04-casebook")
 app._show_journal("wallet"); await app.capture("05-wallet")
 app._close_modal()
 var before=app.profile.balance
 app.state.reboot(); app._refresh()
 app._request_confirmation("accept",null)
 app.profile.spend(before,"test zero")
 app._confirm_pending(app.confirmation.serial); await settle()
 check("zero balance cannot execute unpaid exam",app.state.phase==0 and app.profile.balance==0 and is_instance_valid(app.modal) and app.modal.get_script()==app.Workshop)
 app.profile.start_job("signal"); solve(app.profile); app.profile.claim_job(); app._close_modal(); app._refresh()
 await execute("accept")
 check("free maintenance recovers from zero balance",app.state.phase==1 and app.profile.balance==2)
 check("wide layout fits viewport",app.companions.visible and app.companions.get_global_rect().end.x<app.chat.global_position.x and app.bench.get_global_rect().end.x<=1100 and app.stage.get_global_rect().end.y<=600 and app.companions.get_global_rect().end.y<=600)
 app._act("reboot")
 check("mid-case restart still needs a signature",app.state.loop==3 and app.confirmation.get("id")=="reboot")

func run(root) -> void:
 app=root
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--ai-mock-url="): mock=arg.trim_prefix("--ai-mock-url=")
 var models=load("res://scripts/v7/regression_tests.gd").new(); models.model_checks(); checks.merge(models.checks)
 var guards=load("res://scripts/v7/regression_ai_tests.gd").new(); guards.model_tests(); checks.merge(guards.checks)
 var router=load("res://scripts/v7/regression_conversation_tests.gd").new(); router.model_checks(); checks.merge(router.checks)
 economy()
 await ui_story()
 check("loopback fixture provided",mock.begins_with("http://127.0.0.1:"))
 if not mock.is_empty(): await network()
 var passed=not checks.values().has(false)
 var report={"version":"0.7","passed":passed,"count":checks.size(),"checks":checks,"live_api_verified":false,"network":"local HTTP contract fixture"}
 DirAccess.make_dir_recursive_absolute(app.capture_dir)
 var file=FileAccess.open(app.capture_dir+"/test-report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
 print("V7 CHECKS ",checks.size()," PASS=",passed)
 app.get_tree().quit(0 if passed else 1)
