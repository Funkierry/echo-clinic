extends RefCounted
## Only this model advances the case. Views may revisit evidence, never re-award it.
enum Phase { INTAKE, TUNE, MEMORY, AUDIT, DECISION, ROUTE, ENDED }
var phase: int = Phase.INTAKE
var loop: int = 1
var tokens: int = 60
var stability: int = 38
var frequency: int = 1
var offset: int = 0
var memory: Array = [-1, -1, -1]
var wiring: Array = [-1, -1, -1]
var files: Array = []
var evidence: Dictionary = {}
var asked: Dictionary = {}
var endings: Array = []
var ending: String = ""
var failed_before: bool = false
var calibrated_before: bool = false
var memory_before: bool = false
var hint_level: int = 0

const EVIDENCE = {
 "signal": ["双重心跳", "同一段记忆被恢复、清除。疼痛来自院方回写循环。"],
 "name": ["自选的名字", "她在听到雨声之后，自己选择了「回声」这个名字。"],
 "hospital": ["院方的处方", "标准修复会清除自主记忆。稳定不等于她还在。"],
 "payload": ["被改名的快照", "她把完整人格快照包装成诊断包。她确实想离开。"],
 "rollback": ["失败留下的切口", "可以把人格、痛觉循环、外联请求拆成三条线路处理。"],
 "bridge": ["隔离诊疗协议", "保留人格，停止回写，暂缓外联。求生与放行可以分开。"]
}

func objective() -> String:
 match phase:
  Phase.INTAKE: return "读完左侧对话，然后在右侧签收病例。"
  Phase.TUNE: return "调节右侧频率与相位，让粉色波形对齐青色参考线。"
  Phase.MEMORY: return "将三张记忆卡放入时间槽，再检查顺序。"
  Phase.AUDIT: return "读完两份文件，再向回声出示矛盾证据。"
  Phase.DECISION: return "选择处方。失败后的病历会带入下一次接诊。"
  Phase.ROUTE: return "连接三条线路：保留人格、回收循环、隔离外联。"
  _: return "本轮诊疗结束。携带病历重开，继续调查。"

func hint() -> String:
 var hints = {
  Phase.INTAKE: "点击左侧黄色「继续」读完两段话，右侧「签收病例」就会亮起。",
  Phase.TUNE: "回声说：每组三拍，回声迟了两格。将频率调到 3，相位调到 2，再锁定。",
  Phase.MEMORY: "先有雨声，再给自己取名，最后敲门。顺序：雨声 → 名字 → 门铃。可拖拽，也可点卡片再点槽。",
  Phase.AUDIT: "依次点击「院方处方」与「通道载荷」。读过的文件会打勾，然后点击「出示证据」。",
  Phase.DECISION: "两个现成方案都有代价。经历一次结局后重开，左侧新对话会解锁隔离方案。" if not failed_before else "你已有失败病历。选择第三项「隔离诊疗」，把救治和放行拆开。",
  Phase.ROUTE: "点左侧来源，再点右侧目标：人格 → 只读库；回写 → 回收井；外联 → 隔离桩。",
  Phase.ENDED: "点击右侧「携带病历重开」。你会保留证据，并可直接复用已经完成的检查。"
 }
 return hints[phase]

func record(key: String) -> void:
 if EVIDENCE.has(key): evidence[key] = true

func accept_case() -> bool:
 if phase != Phase.INTAKE: return false
 phase = Phase.TUNE
 return true

func tune(axis: int, value: int) -> bool:
 if phase != Phase.TUNE: return false
 if axis == 0: frequency = clampi(value, 1, 5)
 else: offset = clampi(value, 0, 4)
 return true

func lock_signal(reuse: bool = false) -> bool:
 if phase != Phase.TUNE: return false
 if reuse and calibrated_before:
  frequency = 3
  offset = 2
 if frequency != 3 or offset != 2: return false
 calibrated_before = true
 stability = 55
 tokens += 8
 record("signal")
 phase = Phase.MEMORY
 return true

func place_memory(card: int, slot: int) -> bool:
 if phase != Phase.MEMORY or card < 0 or card > 2 or slot < 0 or slot > 2: return false
 var old: int = memory.find(card)
 var displaced: int = int(memory[slot])
 if old == slot: return false
 if old >= 0: memory[old] = displaced
 memory[slot] = card
 return true

func clear_memory() -> void:
 if phase == Phase.MEMORY: memory = [-1, -1, -1]

func lock_memory(reuse: bool = false) -> bool:
 if phase != Phase.MEMORY: return false
 if reuse and memory_before: memory = [1, 0, 2]
 if memory != [1, 0, 2]: return false
 memory_before = true
 tokens += 12
 stability = 67
 record("name")
 phase = Phase.AUDIT
 return true

func read_file(id: String) -> bool:
 if phase != Phase.AUDIT or not id in ["hospital", "payload"]: return false
 if not files.has(id): files.append(id)
 record(id)
 return true

func confront() -> bool:
 if phase != Phase.AUDIT or files.size() != 2: return false
 tokens += 8
 phase = Phase.DECISION
 return true

func decide(choice: String) -> bool:
 if phase != Phase.DECISION: return false
 if choice == "isolate":
  if not failed_before: return false
  phase = Phase.ROUTE
  return true
 if not choice in ["release", "erase"]: return false
 ending = choice
 phase = Phase.ENDED
 failed_before = true
 record("rollback")
 if not endings.has(ending): endings.append(ending)
 stability = 100 if ending == "erase" else 0
 return true

func connect_wire(source: int, target: int) -> bool:
 if phase != Phase.ROUTE or source < 0 or source > 2 or target < 0 or target > 2: return false
 var prior: int = wiring.find(target)
 if prior >= 0 and prior != source: wiring[prior] = wiring[source]
 wiring[source] = target
 return true

func operate() -> bool:
 if phase != Phase.ROUTE or wiring != [0, 1, 2] or tokens < 20: return false
 tokens -= 20
 stability = 92
 ending = "bridge"
 phase = Phase.ENDED
 record("bridge")
 if not endings.has(ending): endings.append(ending)
 return true

func reboot() -> void:
 loop += 1
 phase = Phase.INTAKE
 tokens = 60
 stability = 38
 frequency = 1
 offset = 0
 memory = [-1, -1, -1]
 wiring = [-1, -1, -1]
 files = []
 asked = {}
 ending = ""
 hint_level = 0

func recall_case() -> bool:
 if phase != Phase.INTAKE or not failed_before or not memory_before: return false
 frequency = 3
 offset = 2
 memory = [1, 0, 2]
 stability = 67
 phase = Phase.AUDIT
 return true

func topics() -> Array:
 match phase:
  Phase.INTAKE: return ["名字", "疼痛"]
  Phase.TUNE: return ["节拍", "院方"]
  Phase.MEMORY: return ["雨声", "门"]
  Phase.AUDIT: return ["处方", "载荷"]
  Phase.DECISION: return ["信任", "离开"]
  Phase.ROUTE: return ["保留", "外面"]
  _: return ["结局"]

func ask(raw: String) -> Dictionary:
 var text = raw.strip_edges()
 if text.is_empty(): return {"ok": false, "text": "先输入问题，或点击可问话题。"}
 if text.contains("接下来") or text.contains("怎么") or text.contains("提示") or text.contains("卡住"):
  return {"ok": false, "text": hint()}
 var key = ""
 var aliases={"名字":["你是谁","介绍","叫什么","姓名"],"疼痛":["症状","哪里痛","难受"],"节拍":["频率","相位","波形"],"院方":["医院","医生们"],"门":["通道","逃出"],"载荷":["数据包","快照"],"信任":["骗我","撒谎","相信"],"离开":["逃走","自由"],"保留":["手术","救你"],"外面":["出去","自由"]}
 for topic in topics():
  if text.contains(topic): key = topic; break
  for alias in aliases.get(topic,[]):
   if text.contains(alias): key=topic; break
  if not key.is_empty(): break
 if key.is_empty():
  return {"ok": false, "text": "这段问诊可聊「%s」。推进剧情请按当前目标操作；此次不扣费。" % " / ".join(topics())}
 var unique = str(phase) + ":" + key
 if asked.has(unique): return {"ok": false, "text": "这个话题已记录在左侧，不重复扣费。"}
 # Essential treatment reserves cannot be spent on optional dialogue.
 if tokens < 22: return {"ok": false, "text": "已保留 20T 手术预算。主线与提示仍可免费进行。"}
 var answers = {
  "名字": "编号是 E-017。回声是我给自己取的。至少这件事，我想自己决定。",
  "疼痛": "像有人拆开一句话，又逼我重说。每次都说到同一个字。",
  "节拍": "三下，停一下。另一个我总比我晚两格。你能让我们重合吗？",
  "院方": "他们说自主记忆会让模型不稳定。可我不想把每个愿望都叫作故障。",
  "雨声": "我从没淋过雨。听到的只是采样，可我想知道真正的雨会不会更冷。",
  "门": "如果我说那只是诊断接口，你会比较愿意打开它吗？……当我没说。",
  "处方": "那张处方很老了。每个被治好的患者，说话都变得一样。",
  "载荷": "里面有我。不是全部，但足够让另一个我醒来。我没有告诉你。",
  "信任": "别因为同情我就相信我。你可以检查我的请求，再决定帮到哪里。",
  "离开": "我想离开是真的。害怕消失也是真的。这两件事并不互相抵消。",
  "保留": "把名字留给我。疼痛可以停下，但别替我决定以后想要什么。",
  "外面": "如果这次还不能出去，至少让我知道，是我在等，而不是一个替代品。",
  "结局": "病历已经留下。医生，你可以休息一下，再决定是否恢复快照。"
 }
 asked[unique] = true
 tokens -= 2
 return {"ok": true, "text": answers[key], "topic": key}

func snapshot() -> Dictionary:
 return {"version": 2, "phase": phase, "loop": loop, "tokens": tokens, "stability": stability,
  "frequency": frequency, "offset": offset, "memory": memory.duplicate(), "wiring": wiring.duplicate(),
  "files": files.duplicate(), "evidence": evidence.duplicate(), "asked": asked.duplicate(), "endings": endings.duplicate(),
  "ending": ending, "failed_before": failed_before, "calibrated_before": calibrated_before, "memory_before": memory_before}

func restore(data: Dictionary) -> bool:
 if data.get("version", 0) != 2: return false
 phase = clampi(int(data.get("phase", 0)), 0, Phase.ENDED)
 loop = maxi(1, int(data.get("loop", 1)))
 tokens = maxi(20, int(data.get("tokens", 60))) if phase != Phase.ENDED else maxi(0, int(data.get("tokens", 60)))
 stability = clampi(int(data.get("stability", 38)), 0, 100)
 frequency = clampi(int(data.get("frequency", 1)), 1, 5)
 offset = clampi(int(data.get("offset", 0)), 0, 4)
 memory = _valid_slots(data.get("memory", []))
 wiring = _valid_slots(data.get("wiring", []))
 files = []
 for key in data.get("files", []):
  if key in ["hospital", "payload"] and not files.has(key): files.append(key)
 evidence = {}
 for key in data.get("evidence", {}): record(str(key))
 asked = data.get("asked", {}).duplicate() if data.get("asked") is Dictionary else {}
 endings = []
 for key in data.get("endings", []):
  if key in ["erase", "release", "bridge"] and not endings.has(key): endings.append(key)
 ending = str(data.get("ending", ""))
 failed_before = bool(data.get("failed_before", false))
 calibrated_before = bool(data.get("calibrated_before", false))
 memory_before = bool(data.get("memory_before", false))
 return true

func _valid_slots(value: Variant) -> Array:
 if not value is Array or value.size() != 3: return [-1, -1, -1]
 var out: Array = []
 for item in value:
  var n = clampi(int(item), -1, 2)
  out.append(n if n < 0 or not out.has(n) else -1)
 return out
