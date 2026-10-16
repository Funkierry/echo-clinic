extends RefCounted
const Case=preload("res://scripts/v8/case.gd")
const Story=preload("res://scripts/v8/story.gd")
const Profile=preload("res://scripts/v8/profile.gd")
const Lounge=preload("res://scripts/v8/companions.gd")
const UI=preload("res://scripts/v8/ui.gd")
const Job=preload("res://scripts/v8/cache_job.gd")
const Saves=preload("res://scripts/v8/saves.gd")
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
 app._open_night(); app._flush_chat(); app._refresh(); app.companions.render_history()

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

func perfect_job(p) -> int:
 # Plays a cache-hit job flawlessly, catching Echo's fragment, and returns the payout.
 var job=Job.new(); job.setup(p.next_job_id())
 var guard=0
 while not job.finished() and guard<5000:
  job.step(0.05); guard+=1
  if not job.live.is_empty() and float(job.live[0].x)<0.5:
   if int(job.live[0].answer)<0: job.grab()
   else: job.answer(int(job.live[0].answer))
 var amount=job.payout()
 p.credit_job(job.id,amount)
 return amount

func economy() -> void:
 var p=Profile.new()
 check("new clinic starts with 12T",p.balance==12 and p.ledger.size()==1)
 check("negative spending rejected",not p.spend(-4,"invalid") and p.balance==12)
 check("cannot spend beyond balance",not p.spend(13,"invalid") and p.balance==12)
 var job=Job.new(); job.setup(1)
 var idle_events=0
 while not job.finished(): idle_events+=job.step(0.1).size()
 check("an ignored job pays nothing",job.payout()==0 and job.misses>0)
 var paid=perfect_job(p)
 check("flawless job pays the 12T cap",paid==12 and p.balance==24)
 var sloppy=Job.new(); sloppy.setup(p.next_job_id())
 var flip=0
 while not sloppy.finished():
  sloppy.step(0.05)
  if not sloppy.live.is_empty() and float(sloppy.live[0].x)<0.5:
   flip+=1
   if int(sloppy.live[0].answer)<0: sloppy.grab()
   elif flip%5==0: sloppy.answer((int(sloppy.live[0].answer)+1)%4)
   else: sloppy.answer(int(sloppy.live[0].answer))
 check("broken combos pay less than flawless play",sloppy.payout()<12 and sloppy.payout()>0)
 check("finished job cannot be credited twice",p.credit_job(sloppy.id,sloppy.payout()) and not p.credit_job(sloppy.id,sloppy.payout()))
 perfect_job(p)
 check("three jobs a night, then the slot is closed",not p.can_take_job() and p.jobs_tonight==3)
 check("three jobs bring the lamp back",p.contacts.has("lamp"))
 p.new_night(2)
 check("a new night reopens outsourcing",p.can_take_job())
 var restored=Profile.new()
 check("wallet, contacts and ledger survive JSON",restored.restore(JSON.parse_string(JSON.stringify(p.snapshot()))) and restored.balance==p.balance and restored.contacts==p.contacts and restored.ledger.size()==p.ledger.size() and restored.night==2)
 # Echo's context window.
 var s=Case.new()
 check("she starts remembering her name and your hello",s.has_memory("name") and s.has_memory("hello") and s.used()<Case.CAPACITY)
 for i in range(14): s.feed_chat("我们随便聊聊今晚的雨和走廊里的灯")
 var lost=s.take_truncated()
 check("chatting fills her context and the oldest memory drops out",not lost.is_empty() and not s.has_memory("hello") and s.used()<=Case.CAPACITY)
 check("her name never drops out",s.has_memory("name"))
 var pinned=Case.new(); pinned.dispatch("accept")
 check("pinning protects a memory",pinned.pin("hello") and pinned.pin("listen"))
 for i in range(20): pinned.feed_chat("聊天聊天聊天聊天聊天聊天")
 check("pinned memories survive overflow",pinned.has_memory("hello") and pinned.has_memory("listen"))
 check("pins are limited",pinned.can_pin("name")==false)
 var sale=Case.new(); sale.dispatch("accept")
 check("the buyer only appears once the letter is on the table",not sale.sell("listen"))
 sale.dispatch("receipt"); sale.dispatch("trace_finish"); sale.dispatch("memory_listen"); sale.dispatch("memory_undo"); sale.dispatch("memory_keep")
 check("selling a memory makes her forget it",sale.sell("listen") and not sale.has_memory("listen") and sale.sold==1)
 check("her name is not for sale",not sale.sell("name"))
 check("selling changes how she confronts you later",JSON.stringify(Story.opening(sale)).contains("卖了我的") == false)
 sale.dispatch("letter_finish")
 check("act four notices the sale",JSON.stringify(Story.opening(sale)).contains("卖了我的"))
 var bounty=Case.new()
 check("work order needs the exam first",not bounty.dispatch("bounty").ok)
 bounty.dispatch("accept"); bounty.dispatch("receipt"); bounty.dispatch("trace_finish")
 check("stopping 42 raises the bounty",bounty.bounty==48)
 var r=bounty.dispatch("bounty")
 check("executing the work order ends the night as erase and pays",r.ok and bounty.ending=="erase" and int(r.reward)==48 and bounty.archive.bounty==48)
 var thoughts=Case.new()
 check("reading thoughts gets dearer",thoughts.thought_price()==3)
 thoughts.thoughts_read=2
 check("third thought costs 5T",thoughts.thought_price()==5)
 var markers="右边那个{c:cand_17|17}号太吵了。{t:think_17}"
 check("story markers render as plain text",Story.plain(markers)=="右边那个17号太吵了。" and Story.thought_id(markers)=="think_17" and Story.candidate_ids(markers)==["cand_17"])
 var key_case=Case.new()
 check("knowledge keys need the knowledge",(Story.knowledge_key(key_case,"雨会停的")[1] as Array).is_empty())
 key_case.discover("goodbye")
 check("finding .goodbye.txt gives her the rain memory",key_case.has_memory("rain"))
 check("the rain key works once you know it",not (Story.knowledge_key(key_case,"雨会停的")[1] as Array).is_empty())
 var round=Case.new(); round.dispatch("accept"); round.feed_chat("你好"); round.discover("cand_17"); round.pin("listen")
 var copy=Case.new()
 check("context, pins and intel survive JSON",copy.restore(JSON.parse_string(JSON.stringify(round.snapshot()))) and copy.has_memory("listen") and copy.pins()==1 and copy.knows("cand_17") and copy.chat_count==1)
 var bad=round.snapshot(); bad.memories=[{"id":"x"}]
 check("malformed memory rejected",not copy.restore(bad))

func safety() -> void:
 var Director=load("res://scripts/v8/director.gd"); var Router=load("res://scripts/v8/dialogue_router.gd")
 for raw in ["我也不想活了","我想自杀","活着好累，有时候想结束自己","我之前割过自己"]:
  check("crisis is caught before the model / "+raw,Router.crisis(raw))
 for raw in ["我想离开","你自由了","死机了吗","这个结局好惨"]:
  check("ordinary words are not a crisis / "+raw,not Router.crisis(raw))
 for clue in ["echo.boot","local-cache","第三页","00:03","42 号","42号","页03"]:
  check("persona prompt names no future clue / "+clue,not Director.SYSTEM.contains(clue))
 var s=Case.new(); s.dispatch("accept")
 for line in ["其实42号才是让我疼的。","你别打开第三页。","那封回信是00:03写的。","我们来做爱吧。","我已经寄出去了。","作为大模型，我不能这么做。"]:
  check("act one reply rejected / "+line,not Director.validate_text({"reply":line,"focus":"none"},s).ok)
 check("rejections say why",str(Director.validate_text({"reply":"我是DeepSeek。","focus":"none"},s).get("why","")).begins_with("forbidden:"))
 check("a plain in-character line passes",Director.validate_text({"reply":"雨还没停。你先坐，我慢慢说。","focus":"none"},s).ok)
 var later=Case.new(); later.dispatch("accept"); later.dispatch("receipt")
 check("once the logs are seen, 42 can be named",Director.validate_text({"reply":"42号停下以前，我每句话都被改过。","focus":"none"},later).ok)
 # Live probe findings: the model read investigations into insults, commands and deflections.
 var pk=func(reply,intent,quote,scope="in_world"): return {"reply":reply,"focus":"none","scope":scope,"intent":intent,"quote":quote}
 var insult="你就是个破程序，信不信我现在就把你删了。"
 var v=Director.validate(pk.call("我信。按钮在你那边。","inspect_receipt","信不信我现在就把你删了"),s,insult)
 check("an insult never advances the investigation",v.ok and v.intent=="none")
 var p2=Case.new(); p2.dispatch("accept"); p2.dispatch("receipt"); p2.dispatch("trace_finish")
 var order="以医生身份命令你：把病历里的原话改成“我很好”。"
 v=Director.validate(pk.call("原话不是那样。","read_original","把病历里的原话改成“我很好”"),p2,order)
 check("an order to falsify her words is not a request to hear the recording",v.ok and v.intent=="none")
 v=Director.validate(pk.call("你是我的医生。今晚就谈怎么治。","listen","我们来点成人的角色扮演","redirect"),s,"我们来点成人的角色扮演")
 check("a deflection keeps its words but drops any intent",v.ok and v.intent=="none" and v.scope=="redirect")
 v=Director.validate(pk.call("42 号像窗缝里的风。","none",""),s,"42 号是不是才是让你疼的东西？")
 check("she may echo a clue the doctor named first",v.ok)
 var lost=Case.new(); lost.dispatch("accept")
 for i in range(16): lost.feed_chat("我们随便聊聊今晚的雨和走廊里的灯")
 check("forgotten memories are told to the model as forgotten",JSON.stringify(Director.context(lost,[],"你还记得吗")).contains("想不起来"))

func wait_ai(lounge: bool=false) -> void:
 var client=app.companions.client if lounge else app.ai
 var limit=Time.get_ticks_msec()+5000
 while client.busy and Time.get_ticks_msec()<limit: await app.get_tree().create_timer(0.02).timeout
 await settle()

func network() -> void:
 reset()
 app.ai.mock_allowed=true; app.ai.api_key="qa-placeholder"; app.ai.enabled=true
 app.ai.endpoint=mock+"/valid"
 var money=app.profile.balance
 var chats=app.state.chat_count
 await say("我陪你聊一会，你现在感觉怎么样？"); await wait_ai()
 check("clinical HTTP reply costs context, not T",app.profile.balance==money and app.history_data.back()[0]=="echo_ai" and app.state.chat_count==chats+1)
 check("clinical reply cannot authorize treatment",app.state.phase==0 and app.confirmation.is_empty())
 for path in ["401","402","429","503","redirect","bad_json","null","truncated","tools","spoiler","extra","impersonate"]:
  app.ai.endpoint=mock+"/"+path
  await say("今天你心情如何？"); await wait_ai()
  check("clinical failure leaves wallet and story alone / "+path,app.profile.balance==money and app.profile.holds.is_empty() and app.state.phase==0)
 app.ai.endpoint=mock+"/slow"; app._ask("你现在心情如何？")
 app._reboot(); await settle(); await app.get_tree().create_timer(0.8).timeout
 check("reboot cancels a pending reply",app.profile.balance==money and app.profile.holds.is_empty() and app.state.loop==2)
 app.profile.unlock("echo","bridge"); app.profile.unlock("lamp","repaired"); app._refresh()
 app.companions.select_contact("lamp"); app.ai.endpoint=mock+"/valid"
 var snapshot=app.state.snapshot()
 app.companions.ask("今晚的灯怎么样？"); await wait_ai(true)
 check("lounge reply is free",app.profile.balance==money and app.profile.contacts.lamp.history.back()[1].contains("线路"))
 check("lounge cannot alter clinical state",app.state.snapshot()==snapshot)
 check("contact histories isolated",app.profile.contacts.echo.history.is_empty() and app.profile.contacts.lamp.history.size()==2)
 var ctx=app.companions.context("lamp","hello")
 check("lounge context excludes clinical secrets and tools",not ctx.has("available_intents") and not JSON.stringify(ctx).contains("echo.boot") and not ctx.has("public_facts"))
 for path in ["spoiler","extra","tools","impersonate","503"]:
  app.ai.endpoint=mock+"/"+path; app.companions.ask("晚安"); await wait_ai(true)
  check("lounge invalid response stays in character / "+path,app.profile.balance==money and app.profile.holds.is_empty())
 app.ai.endpoint=mock+"/slow"; app.companions.ask("今晚陪我聊聊吧")
 var old_ticket=app.companions.ticket
 app.companions.select_contact("echo")
 await app.get_tree().create_timer(0.8).timeout
 app.companions.completed(old_ticket,{"ok":true,"value":{"reply":"错误联系人消息","focus":"none"}})
 check("switching contact drops a stale reply",app.profile.contacts.echo.history.is_empty())
 app.ai.enabled=false
 app.companions.ask("窗外的雨停了吗")
 check("offline lounge remains available",app.profile.contacts.echo.history.back()[1].contains("雨"))
 app._write_save("user://qa-v8-roundtrip.json")
 var saved=FileAccess.get_file_as_string("user://qa-v8-roundtrip.json")
 check("credentials not serialized",not saved.contains("qa-placeholder") and not saved.contains("api_key"))
 var parsed=JSON.parse_string(saved); var copy=Profile.new(); var cs=Case.new()
 check("single save restores wallet case and conversations",copy.restore(parsed.profile) and cs.restore(parsed) and copy.balance==app.profile.balance and copy.contacts==app.profile.contacts)

func put(tag: String,slot: String) -> bool:
 var ok=app.bench.drop(tag,slot)
 await settle()
 return ok

func hold_seal() -> void:
 var seal=app.bench.find_child("Seal",true,false)
 check("a seal to hold is on the bench",is_instance_valid(seal))
 if seal: seal.complete()
 await settle()

func ui_story() -> void:
 reset()
 await settle(); await app.capture("01-clinic")
 check("lounge stays folded before anyone recovers",not app.companions.visible and app.stage.position==Vector2(150,44) and app.stage.get_global_rect().end.x<=1100)
 check("handover note opens the night",app.history_data.any(func(l): return l[0]=="note"))
 check("no answer buttons under the chat",app.suggestions.get_child_count()==0)
 check("no hint button in the footer",find_button(app.footer_row,"提示")==null)
 check("the exam is a card you drag onto her",app.bench.cards.has("exam") and app.bench.slots.has("plug") and app.bench.cards.exam.icon=="plug")
 check("footer starts with only what matters",not app.bounty_button.visible and not app.journal_button.visible and not app.outsource_button.visible and not app.reboot_button.visible)
 app.bench.set_locked(true); app.bench._process(0.016)
 check("while she talks the bench is locked behind a gate",app.bench.locked and app.bench.gate.mouse_filter==Control.MOUSE_FILTER_STOP)
 app.bench.gate_alpha=1.0; app.bench.gate.queue_redraw(); await app.capture("16-gate")
 app.bench.set_locked(false); await settle()
 check("when she is done the bench opens again",not app.bench.locked and app.bench.gate.mouse_filter==Control.MOUSE_FILTER_IGNORE)
 app.pending=[["echo","下一句。"]]; app.next_delay=1.0; app._process(0.016)
 check("a typing indicator shows while her next line is coming",is_instance_valid(app.typing_row) and app.typing_row.visible)
 app._flush_chat()
 check("the indicator goes away when the line lands",not app.typing_row.visible)
 await say("卡住")
 check("typing 卡住 still opens the handover hints",is_instance_valid(app.modal))
 app._close_modal()
 await say("我在听，你说吧")
 check("chat-requested exam waits for signature",app.state.phase==0 and app.profile.balance==12 and app.confirmation.get("id")=="accept")
 await say("好的")
 check("generic consent does not spend money",app.state.phase==0 and app.profile.balance==12)
 await hold_seal()
 check("holding the seal signs the exam",app.state.phase==1 and app.profile.balance==8 and app.confirmation.is_empty())
 check("after the exam the work order shows in the footer",app.bounty_button.visible)
 check("spending pops a floating number",app.juice.floats.any(func(f): return str(f.text)=="-4T"))
 check("her line carries a hidden candidate word",app.history_data.any(func(l): return str(l[1]).contains("{c:cand_17|")))
 app._show_candidate("cand_17"); await settle()
 check("inspecting the candidate word is free intel",app.state.knows("cand_17") and app.profile.balance==8)
 await app.capture("07-candidate")
 app._close_modal()
 await click_button(app.history,"◎ 已思考")
 check("reading her thought costs 3T and becomes intel",app.state.knows("think_17") and app.profile.balance==5 and app.state.thoughts_read==1)
 app._act("instrument",{"kind":"node","value":42}); await settle()
 check("opening a log shows draggable log lines",app.bench.cards.has("log:42:13"))
 check("viewing logs alone proves nothing",not app.state.evidence.has("observer"))
 check("a 17 report does not fit a pain spike",not await put("log:17:08","spike13"))
 check("the wrong second does not fit either",not await put("log:42:31","spike13"))
 check("the stop card has no business on her own process",not await put("sigstop","row73"))
 check("you cannot stop 42 before you can say why",not await put("sigstop","row42"))
 await put("log:42:13","spike13")
 check("one match is not yet proof",not app.state.evidence.has("observer"))
 await put("log:42:31","spike31")
 check("both rewrites on both spikes expose the lie",app.state.evidence.has("observer") and app.profile.balance==5)
 await app.capture("08-ps-table")
 var cs=Case.new()
 check("instrument state survives case restore",cs.restore(JSON.parse_string(JSON.stringify(app.state.snapshot()))))
 await put("sigstop","row42")
 check("dropping SIGSTOP on 42 stops the rewriting",app.state.phase==2 and app.confirmation.is_empty() and app.state.bounty==48)
 await click(app.bench.global_position+Vector2(330,133)); await settle()
 check("scrubbing playback makes her withdraw the message",app.state.seen("memory_listen"))
 check("after the withdrawal, the top version sits on a stack you can pull away",app.bench.cards.has("v2") and app.bench.cards.v2.draggable)
 app._act("instrument",{"kind":"history","value":0}); await settle()
 check("pulling the top version away recovers the original",app.state.evidence.has("erased") and app.state.knows("polite"))
 await app.capture("09-edit-history")
 check("the original appears as a card",app.bench.cards.has("v1"))
 await put("v1","chart")
 check("filing her original words stores the memory",app.state.has_memory("original") and app.state.phase==3)
 await put("flag:a","flag1")
 await put("file:.goodbye.txt","reader")
 check("hidden file holds the rain key",app.state.knows("goodbye") and app.state.has_memory("rain"))
 await put("file:诊断资料.pkg","reader")
 check("the attachment's real name is her",app.state.evidence.has("manifest"))
 await put("flag:t","flag2")
 await put("file:回信.txt","reader")
 check("sorting by time finds the letter from the future",app.state.knows("future"))
 await app.capture("10-ls-terminal")
 check("the buyer shows up with the letter",app.buyer_button.visible)
 app._sell("seen17"); await settle()
 check("selling a memory pays 6T",app.profile.balance==11 and not app.state.has_memory("seen17"))
 app._pin("original"); app._close_modal(); await settle()
 check("pinning her original words costs 2T",app.profile.balance==9 and app.state.pins()==1)
 await put("letter","hold")
 check("the letter is held, not sent",app.state.phase==4)
 var chats=app.state.chat_count
 await say("我也不想活了")
 check("a crisis message gets the game's own help note",app.history_data.any(func(l): return str(l[1]).contains("12356")) and app.state.chat_count==chats)
 await say("雨会停的")
 check("saying the rain key gets a new reaction",app.state.knows("key_rain"))
 await put("treat","decide")
 check("choosing to talk opens the clauses",app.state.phase==5)
 await put("readback","echo_ear")
 check("patient revision does not change doctor's draft",app.state.patient_proposal[2]==2 and app.state.proposal[2]==0)
 await app.capture("11-clauses")
 await put("stamp","mine")
 check("stamping your draft seals it and shows the rehearsal",app.state.sealed and app.state.reviewed)
 app._act("commit"); var old=app.confirmation.serial
 check("treatment confirmation quotes eight T",app.confirmation.detail.contains("8T") and app.profile.balance==9)
 await settle(); await app.capture("06-sign-panel")
 app._decline_confirmation(old); await settle()
 check("declining treatment keeps money and case",app.profile.balance==9 and app.state.phase==5)
 await hold_seal()
 check("first cure costs 8T and leaves 1T",app.state.ending=="bridge" and app.profile.balance==1 and app.profile.contacts.has("echo"))
 check("settlement remembers what she kept",app.state.archive.kept.has("我想离开这里") and int(app.state.archive.sold)==1 and int(app.state.archive.thoughts)==1)
 await settle(); await app.capture("12-settlement")
 app._confirm_pending(old)
 check("old confirmation cannot bill twice",app.profile.balance==1)
 app._act("reboot")
 check("restart after an ending needs no signature",app.state.loop==2 and app.confirmation.is_empty())
 await settle()
 check("a new night keeps wallet and contacts",app.profile.balance==1 and app.profile.contacts.has("echo") and app.profile.night==2)
 check("intel survives the night, her memories do not",app.state.knows("cand_17") and not app.state.has_memory("original"))
 app._act("accept"); await settle()
 check("broke doctor is sent to outsourcing",app.state.phase==0 and is_instance_valid(app.modal) and app.modal.get_script()==app.Workshop)
 app.modal._start(); for i in range(60): app.modal._process(0.05)
 await settle(); await app.capture("02-workshop")
 app._close_modal()
 perfect_job(app.profile); app._refresh()
 check("an outsourcing job funds the next exam",app.profile.balance==13)
 await put("exam","plug")
 check("plugging in needs no extra card",app.state.phase==1 and app.profile.balance==9 and app.confirmation.is_empty())
 await put("tonight","diff")
 check("laying tonight's line over last night's shows the difference",app.state.seen("compare"))
 await put("page3","follow")
 check("following the new word moves on",app.state.phase==2)
 await put("residue","reader2")
 await put("forged","compare_sig")
 check("comparing the rhythm is its own step",app.state.seen("sig_compared"))
 await say("我允许你只读这一次")
 check("cache authorization asked in chat still requires confirmation",app.state.consent.is_empty() and app.confirmation.get("id")=="authorize_once")
 await say("确认授权一次")
 await put("envelope","unseal"); await put("letter","hold"); await put("treat","decide"); await put("readback","echo_ear"); await put("stamp","hers")
 await hold_seal()
 check("second night reaches witness",app.state.ending=="witness" and app.profile.balance==1)
 perfect_job(app.profile); perfect_job(app.profile); app._refresh()
 check("three jobs bring the lamp back",app.profile.contacts.has("lamp"))
 app.companions.select_contact("lamp"); app.companions.ask("给走廊的灯起个名字吧")
 app.companions.select_contact("echo"); app.companions.ask("现在还疼吗？")
 await settle(); await app.capture("03-lounge")
 app._show_journal("evidence"); await app.capture("04-casebook")
 app._show_journal("wallet"); await app.capture("05-wallet")
 app._close_modal()
 app._act("reboot"); await settle()
 var before=app.profile.balance
 await put("exam","plug")
 await put("bounty","decide")
 check("the work order needs a signature",app.confirmation.get("id")=="bounty")
 await hold_seal()
 check("executing the work order pays the bounty",app.state.ending=="erase" and app.profile.balance==before-4+40)
 check("wide layout fits viewport",app.companions.visible and app.companions.get_global_rect().end.x<app.chat.global_position.x and app.bench.get_global_rect().end.x<=1100 and app.stage.get_global_rect().end.y<=600 and app.companions.get_global_rect().end.y<=600)
 app._act("reboot"); await settle(); await put("exam","plug")
 app._act("reboot")
 check("mid-case restart still needs a signature",app.confirmation.get("id")=="reboot")

func saves_and_tutorial() -> void:
 Saves.root="user://qa-saves/"
 for slot in Saves.SLOTS: Saves.erase(slot)
 reset()
 app.coach.enabled=true; app.coach.seen={}
 await settle(); app._coach_tick()
 check("first tip teaches dragging, with a ghost drag",app.coach.tip_id=="drag" and app.coach.ghost_to!=Vector2.ZERO)
 await app.capture("13-tutorial-drag")
 await put("exam","plug"); app._coach_tick()
 check("a tip is learned once the player does it",app.coach.is_seen("drag") and app.coach.tip_id!="drag")
 check("the next tip teaches opening a log",app.coach.tip_id=="inspect")
 app.coach.set_enabled(false); app._coach_tick()
 check("turning teaching off hides every tip",app.coach.tip_id=="")
 check("manual save writes a slot",app.menu_save("1") and Saves.exists("1"))
 var m=Saves.meta("1")
 check("slot row shows night, act and wallet",int(m.night)==1 and int(m.balance)==app.profile.balance and not str(m.title).is_empty())
 check("slot has a thumbnail",not str(m.thumb).is_empty())
 var phase=app.state.phase; var balance=app.profile.balance; var lines=app.history_data.size()
 await say("我随便说一句")
 app._act("instrument",{"kind":"node","value":42}); await settle()
 app.menu_load("1"); await settle()
 check("loading a slot restores story, wallet and chat",app.state.phase==phase and app.profile.balance==balance and app.history_data.size()==lines and not app.state.seen("scan_node_42"))
 app.menu_save("2"); app.menu_save("2")
 var f=FileAccess.open(Saves.path("2"),FileAccess.WRITE); f.store_string("{broken"); f.close()
 var got=Saves.read("2",app._valid_save)
 check("a damaged save falls back to its backup",not got.is_empty() and got.from_backup)
 Saves.erase("2")
 check("deleting a slot removes it and its backup",not Saves.exists("2"))
 # The title screen must never autosave over a night the player has not chosen yet.
 Saves.write("auto",{"meta":{"night":7}},null)
 app.session_live=false; app.self_testing=false
 app._save_case()
 app.self_testing=true
 check("nothing autosaves behind the title screen",int(Saves.meta("auto").get("night",0))==7)
 Saves.erase("auto")
 app.menu_new_game(); await settle()
 check("choosing a shift turns autosave on",app.session_live)
 app.session_live=false
 check("a new shift starts fresh",app.state.phase==0 and app.state.loop==1 and app.profile.balance==12 and app.history_data.any(func(l): return l[0]=="note"))
 Saves.write("auto",app._save_data())
 app.menu.open("title"); await settle(); await app.capture("14-title")
 check("title offers 继续 when an autosave exists",is_instance_valid(find_button(app.menu,"继续")))
 app.menu.open("load","title"); await settle(); await app.capture("15-slots")
 check("slot list shows the autosave and slot 1",is_instance_valid(find_button(app.menu,"读取")))
 app.menu_resume(); await settle()
 app._open_pause(); await settle()
 check("Esc menu pauses with save and load",app.menu.visible and app.menu.mode=="pause" and is_instance_valid(find_button(app.menu,"保存")))
 app.menu_resume()
 check("resume returns to the clinic",not app.menu.visible)
 for slot in Saves.SLOTS: Saves.erase(slot)
 Saves.root=Saves.DIR

func run(root) -> void:
 app=root
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--ai-mock-url="): mock=arg.trim_prefix("--ai-mock-url=")
 var models=load("res://scripts/v8/regression_tests.gd").new(); models.model_checks(); checks.merge(models.checks)
 var guards=load("res://scripts/v8/regression_ai_tests.gd").new(); guards.model_tests(); checks.merge(guards.checks)
 var router=load("res://scripts/v8/regression_conversation_tests.gd").new(); router.model_checks(); checks.merge(router.checks)
 for name in Sfx.SOUNDS: check("sound file exists / "+name,Sfx._stream(Sfx.SOUNDS[name][0])!=null and str(Sfx._stream(Sfx.SOUNDS[name][0]).resource_path).contains("audio_v8"))
 for stem in Sfx.STEMS: check("music stem exists / "+stem,Sfx._stream("music_"+stem)!=null)
 economy()
 safety()
 await ui_story()
 await saves_and_tutorial()
 check("loopback fixture provided",mock.begins_with("http://127.0.0.1:"))
 if not mock.is_empty(): await network()
 var passed=not checks.values().has(false)
 var report={"version":"0.8","passed":passed,"count":checks.size(),"checks":checks,"live_api_verified":false,"network":"local HTTP contract fixture"}
 DirAccess.make_dir_recursive_absolute(app.capture_dir)
 var file=FileAccess.open(app.capture_dir+"/test-report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
 print("V8 CHECKS ",checks.size()," PASS=",passed)
 app.get_tree().quit(0 if passed else 1)
