extends RefCounted
const Case = preload("res://scripts/case_state.gd")
var checks: Dictionary = {}

func check(name: String, value: bool) -> void:
 checks[name]=value
 if not value: push_error("MODEL TEST FAILED: "+name)

func to_decision(c: RefCounted) -> void:
 c.accept_case()
 c.tune(0,3); c.tune(1,2)
 c.lock_signal()
 c.place_memory(1,0); c.place_memory(0,1); c.place_memory(2,2)
 c.lock_memory()
 c.read_file("hospital"); c.read_file("payload")
 c.confront()

func run() -> Dictionary:
 var c=Case.new()
 check("initial_stage_and_budget",c.phase==0 and c.tokens==60)
 check("out_of_order_actions_rejected",not c.lock_signal() and not c.lock_memory() and not c.confront() and not c.decide("erase") and not c.operate())
 var before=c.tokens
 check("unknown_input_does_not_charge",not c.ask("今天天气怎么样").ok and c.tokens==before)
 check("hint_input_does_not_charge",not c.ask("接下来怎么做").ok and c.tokens==before)
 check("first_optional_topic_charged",c.ask("名字").ok and c.tokens==before-2)
 check("duplicate_topic_no_charge",not c.ask("名字").ok and c.tokens==before-2)
 c.tokens=20
 check("treatment_budget_reserved",not c.ask("疼痛").ok and c.tokens==20)
 c.tokens=60
 c.accept_case()
 check("cannot_accept_twice",not c.accept_case())
 check("wrong_tuning_has_no_penalty",not c.lock_signal() and c.tokens==60)
 c.tune(0,99); c.tune(1,-99)
 check("tuning_clamped",c.frequency==5 and c.offset==0)
 c.tune(0,3); c.tune(1,2)
 check("tuning_advances",c.lock_signal() and c.phase==2 and c.evidence.has("signal"))
 before=c.tokens
 check("signal_reward_once",not c.lock_signal() and c.tokens==before)
 c.place_memory(0,0); c.place_memory(1,1)
 c.place_memory(0,1)
 check("memory_swap_preserves_both",c.memory==[1,0,-1])
 check("invalid_memory_rejected",not c.place_memory(9,0) and not c.place_memory(0,9))
 check("incomplete_memory_does_not_advance",not c.lock_memory())
 c.place_memory(2,2)
 check("memory_advances",c.lock_memory() and c.evidence.has("name"))
 before=c.tokens
 check("memory_reward_once",not c.lock_memory() and c.tokens==before)
 check("invalid_document_rejected",not c.read_file("unknown"))
 c.read_file("hospital")
 check("both_documents_required",not c.confront())
 c.read_file("hospital")
 check("reread_idempotent",c.files.size()==1 and c.tokens==before)
 c.read_file("payload")
 check("audit_advances",c.confront() and c.phase==4)
 before=c.tokens
 check("confront_reward_once",not c.confront() and c.tokens==before)
 check("isolation_requires_learning",not c.decide("isolate"))
 check("unknown_decision_rejected",not c.decide("unknown"))
 check("release_ending_reachable",c.decide("release") and c.ending=="release")
 check("ending_cannot_be_changed_by_double_click",not c.decide("erase") and c.ending=="release")
 var evidence_count=c.evidence.size()
 c.reboot()
 check("reboot_retains_evidence_and_unlock",c.phase==0 and c.evidence.size()==evidence_count and c.failed_before and c.loop==2)
 check("reboot_resets_run_only",c.tokens==60 and c.files.is_empty() and c.memory==[-1,-1,-1] and c.asked.is_empty())
 check("repeat_checks_can_be_skipped",c.recall_case() and c.phase==3)
 c.read_file("hospital"); c.read_file("payload"); c.confront()
 check("isolation_unlocks_on_second_loop",c.decide("isolate") and c.phase==5)
 check("incomplete_wires_do_not_charge",not c.operate() and c.tokens==68)
 c.connect_wire(0,1); c.connect_wire(1,0)
 c.connect_wire(0,0)
 check("wire_swap_preserves_connections",c.wiring==[0,1,-1])
 c.connect_wire(2,2)
 check("isolated_treatment_ending",c.operate() and c.ending=="bridge" and c.tokens==48 and c.evidence.has("bridge"))
 before=c.tokens
 check("operation_charged_once",not c.operate() and c.tokens==before)
 var saved=c.snapshot()
 var restored=Case.new()
 check("save_restore_round_trip",restored.restore(JSON.parse_string(JSON.stringify(saved))) and restored.ending=="bridge" and restored.endings.size()==2 and restored.evidence==c.evidence)
 var save_file=FileAccess.open("user://case-v2-test.json",FileAccess.WRITE)
 save_file.store_string(JSON.stringify(saved)); save_file.close()
 var disk=Case.new()
 check("save_file_readback",disk.restore(JSON.parse_string(FileAccess.get_file_as_string("user://case-v2-test.json"))) and disk.failed_before and disk.endings.size()==2)
 DirAccess.remove_absolute("user://case-v2-test.json")
 var erase=Case.new()
 to_decision(erase)
 check("erase_ending_reachable",erase.decide("erase") and erase.stability==100 and erase.ending=="erase")
 erase.reboot(); to_decision(erase)
 check("erase_also_unlocks_new_treatment",erase.decide("isolate"))
 var all_permutations=[[0,1,2],[0,2,1],[1,0,2],[1,2,0],[2,0,1],[2,1,0]]
 var memory_correct=true
 var wiring_correct=true
 for permutation in all_permutations:
  var test=Case.new()
  test.phase=Case.Phase.MEMORY
  test.memory=permutation.duplicate()
  var expected=permutation==[1,0,2]
  memory_correct=memory_correct and test.lock_memory()==expected
  test.phase=Case.Phase.ROUTE
  test.wiring=permutation.duplicate()
  expected=permutation==[0,1,2]
  wiring_correct=wiring_correct and test.operate()==expected
 check("all_memory_orders_have_one_solution",memory_correct)
 check("all_wiring_orders_have_one_solution",wiring_correct)
 var lowest=Case.new()
 lowest.failed_before=true
 lowest.phase=Case.Phase.ROUTE
 lowest.tokens=22
 lowest.ask("保留")
 lowest.wiring=[0,1,2]
 check("minimum_budget_still_finishes",lowest.operate() and lowest.tokens==0)
 var unknown=Case.new()
 check("old_save_version_rejected",not unknown.restore({"version":1}))
 var bad=Case.new()
 bad.restore({"version":2,"memory":[0,0,8],"wiring":[],"frequency":99,"offset":-1})
 check("malformed_slots_repaired",bad.memory==[0,-1,2] and bad.wiring==[-1,-1,-1] and bad.frequency==5 and bad.offset==0)
 return checks
