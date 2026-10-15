extends RefCounted
const Case=preload("res://scripts/v4/case.gd")
const Story=preload("res://scripts/v4/story.gd")
var checks: Dictionary={}
var app

func check(name: String,ok: bool) -> void:
 checks[name]=ok
 print(("PASS " if ok else "FAIL ")+name)

func to_decision(trust: bool=false,inspect: bool=true):
 var s=Case.new()
 s.dispatch("accept")
 if trust: s.dispatch("quiet")
 s.dispatch("receipt"); s.dispatch("trace_finish")
 if inspect:
  s.dispatch("memory_listen"); s.dispatch("memory_undo"); s.dispatch("memory_keep")
 else: s.dispatch("memory_accept")
 s.dispatch("letter_finish")
 return s

func to_second(s,proof: bool=true,authorize: bool=false) -> void:
 s.reboot(); s.dispatch("accept"); s.dispatch("compare"); s.dispatch("trace_finish")
 s.dispatch("residue"); s.dispatch("authorize_once" if authorize else "deny_forgery")
 if proof: s.dispatch("envelope")
 s.dispatch("letter_finish")

func model_checks() -> void:
 var s=Case.new()
 check("wrong-phase events rejected",not s.dispatch("commit").ok and not s.dispatch("memory_keep").ok and not s.dispatch("trace_finish").ok)
 s.dispatch("accept"); s.dispatch("quiet")
 check("patient misdirection does not heal or deadlock",s.stability==31 and s.phase==1 and s.allowed().has("receipt"))
 var snapshot=s.snapshot()
 check("misdirection only once",not s.dispatch("quiet").ok and s.snapshot()==snapshot)
 s.dispatch("receipt"); s.dispatch("trace_finish")
 var before=s.tokens
 check("repair reward cannot repeat",not s.dispatch("trace_finish").ok and s.tokens==before)
 var deletion=s.dispatch("memory_listen")
 check("patient withdrawal is an authored event",deletion.retract and s.allowed().has("memory_undo") and s.allowed().has("memory_accept"))
 var restored=Case.new()
 check("save during deletion resumes reversible state",restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and restored.allowed().has("memory_undo"))
 restored.dispatch("memory_undo"); check("restored original is evidence",restored.evidence.has("erased"))
 var all_first=true
 for trusting in [false,true]:
  for inspect in [false,true]:
   for route in ["erase","release","treat"]:
    var branch=to_decision(trusting,inspect)
    all_first=all_first and branch.phase==4
    branch.dispatch("decide",route)
    if route=="treat":
     branch.dispatch("readback"); branch.dispatch("seal"); branch.dispatch("preview"); branch.dispatch("commit")
    all_first=all_first and branch.phase==6
 check("12 first-act choice combinations reach an ending",all_first)
 var trusted=to_decision(true,false)
 var skeptical=to_decision(false,true)
 check("accepted false memory changes later confrontation",JSON.stringify(Story.opening(trusted)).contains("你刚才说不想离开") and not JSON.stringify(Story.opening(skeptical)).contains("你刚才说不想离开"))
 s=to_decision()
 s.dispatch("decide","treat")
 var original=s.proposal.duplicate()
 s.dispatch("readback")
 check("NPC cannot alter doctor proposal or consent",s.proposal==original and s.patient_proposal!=s.proposal and not s.sealed and not s.reviewed)
 check("unsigned proposal cannot execute",not s.dispatch("commit").ok)
 check("NPC interference is one-shot",not s.dispatch("readback").ok)
 s.dispatch("seal"); s.dispatch("preview")
 check("explicit signature and rehearsal enable execution",s.allowed().has("commit"))
 s.dispatch("clause",0)
 check("editing a signed draft invalidates consent",not s.sealed and not s.reviewed and not s.dispatch("commit").ok)
 s.dispatch("seal"); s.dispatch("preview"); s.dispatch("commit")
 check("freezing autonomy has distinct narrative outcome",s.ending=="frozen")
 s=to_decision(); s.dispatch("decide","treat"); s.dispatch("readback"); s.dispatch("accept_edit"); s.dispatch("preview")
 check("accepting broad migration shows consequence before commit",s.prediction().contains("离开沙箱") and s.phase==5)
 s.dispatch("commit"); check("accepting widened clause leads to migration",s.ending=="release")
 var all_clauses=true
 for identity in range(3):
  for treatment in range(2):
   for boundary in [0,2]:
    var branch=to_decision(); branch.dispatch("decide","treat")
    for i in range(identity): branch.dispatch("clause",0)
    for i in range(treatment): branch.dispatch("clause",1)
    if boundary==2: branch.dispatch("clause",2)
    branch.dispatch("readback"); branch.dispatch("seal"); branch.dispatch("preview"); branch.dispatch("commit")
    var expected="erase" if identity==2 or treatment==1 else "release" if boundary==2 else "frozen" if identity==1 else "bridge"
    all_clauses=all_clauses and branch.ending==expected
 check("all available first-act contracts have consistent outcomes",all_clauses)
 var saved_lines: Array=[]
 var loop_paths=true
 for ending in ["erase","release","bridge","frozen"]:
  var branch=to_decision(); branch.finish(ending)
  to_second(branch)
  saved_lines.append(Story.archive_line(branch))
  loop_paths=loop_paths and branch.phase==4 and branch.evidence.has("witness") and branch.events.has("compare") and not branch.events.has("quiet") and not branch.events.has("memory_listen")
 check("second act replaces old puzzles with new investigation",loop_paths)
 check("prior endings leave distinct cached replies",saved_lines[0]!=saved_lines[1] and saved_lines[1]!=saved_lines[2] and saved_lines[2]!=saved_lines[3])
 var partial=Case.new(); partial.dispatch("accept"); partial.reboot(); partial.dispatch("accept")
 check("mid-case reboot cannot create an unsolvable replay",partial.allowed()==["compare"] and partial.last_ending=="interrupted")
 var consent_paths=true
 for once in [false,true]:
  var branch=to_decision(); branch.finish("bridge"); to_second(branch,true,once)
  consent_paths=consent_paths and branch.phase==4 and branch.consent==("once" if once else "denied")
 check("accepting or denying forged authority preserves progress",consent_paths)
 s=to_decision(); s.finish("bridge"); to_second(s,false)
 s.dispatch("decide","treat"); s.dispatch("clause",2)
 check("unverified endpoint cannot unlock limited witness route",s.proposal[2]==2)
 s=to_decision(); s.finish("bridge"); to_second(s,true)
 s.dispatch("decide","treat"); s.dispatch("readback")
 check("second-act patient proposes limited contact",s.patient_proposal[2]==1 and s.proposal[2]==0)
 s.dispatch("accept_edit"); s.dispatch("preview"); s.tokens=20; s.dispatch("commit")
 check("new evidence enables distinct witness ending",s.ending=="witness" and s.tokens==0)
 check("new ending has two different speakers",JSON.stringify(Story.opening(s)).contains("other"))
 restored=Case.new()
 check("ending and archive survive JSON roundtrip",restored.restore(JSON.parse_string(JSON.stringify(s.snapshot()))) and restored.ending=="witness" and restored.archive.ending=="witness")
 var bad=s.snapshot(); bad.proposal=[0,0,9]
 check("malformed contract rejected",not restored.restore(bad))
 var talk=Case.new(); var money=talk.tokens
 check("unknown question free",not talk.ask("月球天气").ok and talk.tokens==money)
 check("optional questions charged once",talk.ask("你是谁").ok and not talk.ask("名字").ok and talk.tokens==money-2)
 talk.tokens=21
 check("story cannot be starved by optional conversation",not talk.ask("重置").ok and talk.tokens==21 and talk.dispatch("accept").ok)

func settle() -> void:
 app.cinema.finish(); app._flush_chat()
 await app.get_tree().process_frame
 await app.get_tree().process_frame

func click(point: Vector2) -> void:
 var move=InputEventMouseMotion.new(); move.position=point; move.global_position=point
 app.get_viewport().push_input(move,true)
 var e=InputEventMouseButton.new(); e.position=point; e.global_position=point; e.button_index=MOUSE_BUTTON_LEFT; e.button_mask=MOUSE_BUTTON_MASK_LEFT; e.pressed=true
 app.get_viewport().push_input(e,true)
 await app.get_tree().process_frame
 e=InputEventMouseButton.new(); e.position=point; e.global_position=point; e.button_index=MOUSE_BUTTON_LEFT; e.pressed=false
 app.get_viewport().push_input(e,true)
 await app.get_tree().process_frame

func right(x: float,y: float) -> void:
 await click(Vector2(x+334,y+44))

func attachment(node: Node,id: String):
 for child in node.get_children():
  if child is Button and child.get_meta("story_action","")==id and not child.disabled: return child
  var found=attachment(child,id)
  if found: return found
 return null

func bounds(tag: String) -> void:
 var ok=true
 var text_ok=true
 for node in app.bench.content.get_children():
  if node is Control: ok=ok and node.position.x>=0 and node.position.y>=0 and node.position.x+node.size.x<=455 and node.position.y+node.size.y<=405
  if node is RichTextLabel and not node.scroll_active:
   if node.get_content_height()>node.size.y+2:
    print("TEXT OVERFLOW "+tag+" "+str(node.get_content_height())+" / "+str(node.size.y)+" "+node.text)
    text_ok=false
 check("instrument bounds / "+tag,ok)
 check("narrative text fits / "+tag,text_ok)
 check("chat fits / "+tag,app.history.size.x<=app.scroll.size.x)

func save_roundtrip(name: String) -> void:
 check(name+" save",app._write_save("user://qa-v4.json"))
 var data=JSON.parse_string(FileAccess.get_file_as_string("user://qa-v4.json"))
 var clone=Case.new()
 check(name+" restore state",clone.restore(data) and clone.snapshot()==app.state.snapshot())
 check(name+" restore pending dialogue",data.ui.history.size()==app.history_data.size() and data.ui.pending.size()==app.pending.size())

func cinematic(kind: String,filename: String) -> void:
 var texture=ImageTexture.create_from_image(app.get_viewport().get_texture().get_image())
 app.cinema.play(Story.beat(kind,app.state),texture,false)
 app.cinema.tween.pause(); app.cinema.progress=0.46
 await app.get_tree().process_frame
 await app.capture(filename)
 check("cinematic renders / "+kind,app.cinema.running and not app.cinema.reduced and app.cinema.progress==0.46)
 app.cinema.finish()

func run(root) -> void:
 app=root
 model_checks()
 await settle()
 await app.capture("01-first-letter")
 bounds("arrival")
 await click(Vector2(160,366)); await settle()
 check("UI reply begins narrative",app.state.phase==1)
 await right(100,372); await settle()
 check("UI follows misleading suggestion",app.state.seen("quiet") and app.state.stability==31)
 await app.capture("02-silence")
 await right(310,372); await settle()
 check("UI reveals original receipt",app.state.evidence.has("observer"))
 bounds("receipt")
 await right(210,372); await settle()
 check("UI keeps patient while stopping writer",app.state.phase==2)
 var inline_file=attachment(app.history,"memory_listen")
 check("clue is embedded as a chat attachment",is_instance_valid(inline_file))
 if is_instance_valid(inline_file): await click(inline_file.get_global_rect().get_center())
 await settle()
 check("used chat attachment becomes archived",inline_file.disabled if is_instance_valid(inline_file) else true)
 check("UI withdrawal leaves forensic transcript",app.history_data.any(func(line):return line[0]=="withdrawn") and app.state.seen("memory_listen"))
 await app.capture("03-withdrawn")
 await cinematic("erase_line","03b-withdrawal-performance")
 bounds("withdrawal")
 await save_roundtrip("withdrawal checkpoint")
 await right(110,372); await settle()
 check("UI undo reveals original desire",app.state.evidence.has("erased"))
 await right(110,372); await settle()
 check("UI original testimony preserved",app.state.memory_version=="original" and app.state.phase==3)
 await right(220,58); await settle()
 check("UI file metadata exposes rename",app.state.evidence.has("manifest"))
 await app.capture("04-renamed-attachment")
 bounds("letter")
 var count=app.history_data.size(); var money=app.state.tokens
 await right(220,58); await settle()
 check("UI revisiting evidence does not repeat dialogue or rewards",app.history_data.size()==count and app.state.tokens==money)
 await right(210,371); await settle()
 check("UI transfer is held before commitment",app.state.phase==4 and app.state.ending.is_empty())
 bounds("decision")
 await right(210,371); await settle()
 await right(210,371); await settle()
 check("UI patient redline is distinct from signed draft",app.state.patient_proposal!=app.state.proposal and not app.state.sealed)
 await app.capture("05-patient-redline")
 await cinematic("redline","05b-redline-performance")
 bounds("contract")
 await right(110,371); await settle()
 await right(210,371); await settle()
 check("UI rehearsal precedes treatment",app.state.reviewed and app.state.phase==5)
 bounds("rehearsal")
 await right(310,371); await settle()
 check("UI first-act treatment completes",app.state.ending=="bridge")
 await app.capture("06-first-ending")
 bounds("first ending")
 await right(210,372); await settle()
 check("UI replay shows new opening",app.state.loop==2 and JSON.stringify(app.history_data.slice(-5)).contains("早一秒"))
 await cinematic("rewind","06b-rewind-performance")
 await click(Vector2(160,366)); await settle()
 await app.capture("07-second-loop-diff")
 bounds("second diff")
 await right(210,370); await settle()
 check("UI repeated puzzle replaced by textual contradiction",app.state.evidence.has("anticipation"))
 await right(210,370); await settle()
 await right(210,370); await settle()
 check("UI fake doctor message is visibly unsigned",app.history_data.any(func(line):return line[0]=="ghost") and app.state.consent.is_empty())
 await app.capture("08-unsigned-message")
 await cinematic("forgery","08b-forged-message-performance")
 bounds("forgery")
 await save_roundtrip("unsigned authorization checkpoint")
 await right(110,372); await settle()
 check("UI rejects forged consent without blocking story",app.state.phase==3 and app.state.consent=="denied")
 await right(110,372); await settle()
 check("UI envelope proves doctor-side cache",app.state.evidence.has("witness"))
 await app.capture("09-old-reply")
 bounds("return envelope")
 await right(310,372); await settle()
 await right(210,371); await settle()
 await right(210,371); await settle()
 check("UI second negotiation has new limited proposal",app.state.patient_proposal[2]==1)
 await right(310,371); await settle()
 await right(210,371); await settle()
 await save_roundtrip("signed agreement checkpoint")
 await right(310,371); await settle()
 check("UI second-act witness ending",app.state.ending=="witness")
 await app.capture("10-two-voices")
 bounds("two voices")
 await click(Vector2(655,465))
 check("UI hints begin without answer",is_instance_valid(app.modal) and app.state.hint_level==0)
 await click(Vector2(510,344)); await click(Vector2(510,344))
 check("UI hint escalation remains opt-in",app.state.hint_level==2)
 await click(Vector2(280,344))
 check("UI hint closes",not is_instance_valid(app.modal))
 app._ask("另一个你"); await settle()
 check("UI free input responds to story topic",app.history_data.back()[0]=="echo")
 app.get_window().size=Vector2i(800,480)
 await app.get_tree().process_frame
 await app.capture("11-minimum-window")
 check("minimum window is usable",app.get_viewport_rect().size==Vector2(800,480))
 var passed=not checks.values().has(false)
 var report={"version":"0.4","passed":passed,"count":checks.size(),"checks":checks,"scope":"branch invariants, actual mouse input, two acts, saved interference, five outcomes and layout"}
 if not app.capture_dir.is_empty():
  var file=FileAccess.open(app.capture_dir+"/test-report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
 print("V4_RESULT "+JSON.stringify({"passed":passed,"count":checks.size()}))
 app.get_tree().quit(0 if passed else 1)
