extends RefCounted
const Case=preload("res://scripts/v3/case.gd")
var checks: Dictionary={}
var app

func check(name: String, ok: bool) -> void:
 checks[name]=ok
 print(("PASS " if ok else "FAIL ")+name)

func _model_to_choice():
 var s=Case.new()
 s.accept(); s.select_pid(42); s.suspend()
 s.flip(6); s.verify_page(); s.flip(12); s.verify_page()
 for id in Case.CARD_ORDER: s.append_packet(id)
 s.verify_packet()
 return s

func model_checks() -> void:
 var s=Case.new()
 check("out-of-stage actions rejected",not s.commit() and not s.flip(6) and not s.decide("erase") and not s.suspend().ok and not s.verify_packet().ok)
 check("initial clues do not reveal solutions",not s.hints()[0].contains("42"))
 s.accept()
 var safe=true
 for pid in [17,77,9]:
  s.select_pid(pid); var t=s.tokens; safe=safe and not s.suspend().ok and s.tokens==t and s.phase==Case.Phase.TRACE
 check("wrong processes reversible and free",safe)
 s.select_pid(42); s.suspend(); var reward=s.tokens
 check("process reward once",not s.suspend().ok and reward==s.tokens)
 var ecc_valid=true
 for p in range(2):
  for index in range(16):
   var sample=Case.new(); sample.phase=Case.Phase.ECC; sample.page=p; sample._reset_bits(); sample.flip(index)
   ecc_valid=ecc_valid and (bool(sample.verify_page().ok)==(index==Case.FLIPPED[p]))
 check("both ECC pages reject every incorrect single-bit candidate",ecc_valid)
 s.flip(0); check("incorrect ECC changes preserve stage",not s.verify_page().ok and s.phase==Case.Phase.ECC)
 s.reset_page(); s.flip(6); s.verify_page(); s.flip(12); s.verify_page()
 reward=s.tokens
 check("memory reward once",not s.verify_page().ok and s.tokens==reward)
 check("packet cannot duplicate fragment",s.append_packet(0) and not s.append_packet(0))
 check("packet withdrawal works",s.remove_packet(0) and s.packet.is_empty())
 var permutations_ok=true
 for a in range(4):
  for b in range(4):
   for c in range(4):
    for d in range(4):
     if a==b or a==c or a==d or b==c or b==d or c==d: continue
     var sample=Case.new(); sample.phase=Case.Phase.PACKET; sample.packet=[a,b,c,d]
     permutations_ok=permutations_ok and (bool(sample.verify_packet().ok)==([a,b,c,d]==Case.CARD_ORDER))
 check("all 24 packet permutations validated",permutations_ok)
 s=_model_to_choice()
 check("choice requires both documents",not s.decide("patch"))
 s.read_doc("hospital"); check("document read idempotent",not s.read_doc("hospital") and s.documents.size()==1)
 s.read_doc("destination"); check("custom treatment available on first loop",s.decide("patch"))
 check("untested patch cannot be committed",not s.commit())
 var valid_count=0
 for mask in range(512):
  var sample=Case.new(); sample.phase=Case.Phase.PATCH; sample.watchdog=false
  for index in range(9): sample.permissions[index]=(mask>>index)&1
  if sample.simulate().ok: valid_count+=1
 check("ACL accepts only medically valid permission set",valid_count==1)
 s.permissions=[1,1,0,1,0,0,0,0,0]
 check("watchdog recurrence detected",not s.simulate().ok)
 s.toggle_watchdog(); check("safe sandbox passes",s.simulate().ok)
 s.toggle_permission(8); check("editing after simulation invalidates commit",not s.commit())
 s.toggle_permission(8); s.simulate(); s.tokens=20
 check("reserved budget supports treatment",s.commit() and s.tokens==0 and s.ending=="bridge")
 check("commit reward cannot repeat",not s.commit())
 for outcome in ["erase","release"]:
  var sample=_model_to_choice(); sample.read_doc("hospital"); sample.read_doc("destination"); sample.decide(outcome)
  check("ending "+outcome,sample.phase==Case.Phase.END and sample.ending==outcome)
  sample.reboot()
  check("loop remembers "+outcome,sample.evidence.has("payload") and sample.endings.has(outcome) and sample.loop==2 and sample.recall())
 var talk=Case.new()
 check("unknown question free",not talk.ask("火星天气").ok and talk.tokens==48)
 check("contextual alias accepted",talk.ask("你是谁").ok and talk.tokens==46)
 check("repeated question not charged",not talk.ask("名字").ok and talk.tokens==46)
 talk.tokens=21
 check("conversation cannot spend treatment reserve",not talk.ask("重置").ok and talk.tokens==21)
 var saved=_model_to_choice().snapshot()
 var restored=Case.new()
 check("JSON save round-trip",restored.restore(JSON.parse_string(JSON.stringify(saved))) and restored.phase==Case.Phase.CHOICE and restored.evidence.has("payload"))
 saved.bits=[]; check("malformed save rejected",not restored.restore(saved))

func settle() -> void:
 app.cinema.finish()
 app._flush_chat()
 await app.get_tree().process_frame
 await app.get_tree().process_frame

func click(point: Vector2) -> void:
 var move=InputEventMouseMotion.new(); move.position=point; move.global_position=point
 app.get_viewport().push_input(move,true)
 var event=InputEventMouseButton.new(); event.position=point; event.global_position=point
 event.button_index=MOUSE_BUTTON_LEFT; event.pressed=true; event.button_mask=MOUSE_BUTTON_MASK_LEFT
 app.get_viewport().push_input(event,true)
 await app.get_tree().process_frame
 event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=MOUSE_BUTTON_LEFT; event.pressed=false
 app.get_viewport().push_input(event,true)
 await app.get_tree().process_frame

func right(x: float,y: float) -> void:
 await click(Vector2(334+x,44+y))

func layout_checks(tag: String) -> void:
 var valid=true
 for node in app.bench.content.get_children():
  if node is Control:
   valid=valid and node.position.x>=0 and node.position.y>=0 and node.position.x+node.size.x<=455 and node.position.y+node.size.y<=405
 check("instrument bounds / "+tag,valid)
 check("chat fits viewport / "+tag,app.history.size.x<=app.scroll.size.x)

func run(root) -> void:
 app=root
 model_checks()
 await settle()
 await app.capture("01-chat")
 layout_checks("arrival")
 await click(Vector2(110,367))
 await settle()
 check("UI chat reply starts examination",app.state.phase==Case.Phase.TRACE)
 await right(300,377)
 check("UI wrong suspend feedback",app.state.phase==Case.Phase.TRACE and app.feedback.contains("已撤回"))
 await right(315,54)
 check("UI watchdog log tab",app.state.trace_tab==1)
 await right(100,122)
 check("UI process selection",app.state.selected_pid==42)
 await app.capture("02-process")
 layout_checks("trace")
 await right(300,377)
 await settle()
 check("UI trace advances",app.state.phase==Case.Phase.ECC)
 await app.capture("03-memory")
 layout_checks("ecc")
 await right(139,154)
 await right(320,377)
 check("UI first ECC page",app.state.page==1)
 await right(61,232)
 await right(320,377)
 await settle()
 check("UI second ECC page",app.state.phase==Case.Phase.PACKET)
 await right(100,175)
 await right(100,100)
 await right(320,175)
 await right(320,100)
 check("UI packet chain",app.state.packet==Case.CARD_ORDER)
 await app.capture("04-packet")
 layout_checks("packet")
 await right(320,377)
 await settle()
 check("UI packet reveals hidden purpose",app.state.phase==Case.Phase.CHOICE)
 var snapshot=ImageTexture.create_from_image(app.get_viewport().get_texture().get_image())
 app.cinema.play(app.Story.beat(4),snapshot,false)
 app.cinema.tween.pause(); app.cinema.progress=0.5
 await app.capture("05-breach-performance")
 app.cinema.finish()
 await right(100,95)
 await right(320,95)
 check("UI documents readable",app.state.documents.size()==2)
 await app.capture("06-audit")
 layout_checks("choice")
 await right(210,371)
 await settle()
 check("UI chooses custom treatment",app.state.phase==Case.Phase.PATCH)
 await right(100,374)
 check("UI simulation explains failure",not app.state.simulation_valid and app.feedback.contains("覆盖"))
 await right(284,158)
 await right(188,198)
 await right(380,198)
 await right(230,247)
 await right(100,374)
 check("UI ACL and watchdog repair",app.state.simulation_valid)
 await app.capture("07-permissions")
 layout_checks("patch")
 check("atomic save initial write",app._write_save("user://qa-v3.json"))
 check("atomic save replacement",app._write_save("user://qa-v3.json"))
 var disk=JSON.parse_string(FileAccess.get_file_as_string("user://qa-v3.json"))
 check("chat and pending restored data",disk.ui.history.size()==app.history_data.size() and disk.ui.pending.size()==app.pending.size())
 var restored=Case.new()
 check("save cannot bypass patch simulation",restored.restore(disk) and not restored.simulation_valid)
 await right(320,374)
 await settle()
 check("UI final commit",app.state.ending=="bridge")
 await app.capture("08-ending")
 layout_checks("ending")
 await right(200,370)
 await settle()
 check("UI restart retains evidence",app.state.loop==2 and app.state.evidence.has("patch"))
 await click(Vector2(110,367))
 await settle()
 check("UI recall avoids repeated puzzles",app.state.phase==Case.Phase.CHOICE)
 for ending in ["erase","release"]:
  await right(100,95); await right(320,95)
  await right(100 if ending=="erase" else 320,325)
  await settle()
  check("UI alternate ending "+ending,app.state.ending==ending)
  await app.capture("09-"+ending)
  await right(200,370); await settle()
  await click(Vector2(110,367)); await settle()
 await click(Vector2(655,465))
 check("UI first hint opens",is_instance_valid(app.modal) and app.state.hint_level==0)
 await click(Vector2(510,344))
 check("UI hint is opt-in tier two",app.state.hint_level==1)
 await click(Vector2(510,344))
 check("UI explicit answer is opt-in tier three",app.state.hint_level==2)
 await click(Vector2(280,344))
 check("UI hint closes",not is_instance_valid(app.modal))
 app._ask("信任"); await settle()
 check("chat free input responds",app.history_data.back()[0]=="echo")
 var money=app.state.tokens
 app._ask("信任"); await settle()
 check("UI repeated query no duplicate spend",app.state.tokens==money)
 # Restore the opening for a clean screenshot at the minimum supported viewport.
 app.state=Case.new(); app.history_data=[]; app.UI.clear(app.history); app.pending=app.Story.opening(app.state); app._refresh(); await settle()
 app.get_window().size=Vector2i(800,480)
 await app.get_tree().process_frame
 await app.capture("10-minimum-window")
 check("minimum window logical size",app.get_viewport_rect().size==Vector2(800,480))
 var passed=not checks.values().has(false)
 var report={"version":"0.3","passed":passed,"checks":checks,"count":checks.size(),"test_type":"model invariants + actual Godot viewport mouse input + rendered captures"}
 if not app.capture_dir.is_empty():
  var file=FileAccess.open(app.capture_dir+"/test-report.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"  ")); file.close()
 print("V3_RESULT "+JSON.stringify({"passed":passed,"count":checks.size()}))
 app.get_tree().quit(0 if passed else 1)
