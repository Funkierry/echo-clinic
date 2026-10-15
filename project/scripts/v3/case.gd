extends RefCounted
## Deterministic medical case. UI events never directly grant rewards or advance scenes.
enum Phase { ARRIVAL, TRACE, ECC, PACKET, CHOICE, PATCH, END }
var phase: int = Phase.ARRIVAL
var loop: int = 1
var tokens: int = 48
var stability: int = 31
var selected_pid: int = 17
var trace_tab: int = 0
var page: int = 0
var bits: Array = []
var packet: Array = []
var documents: Array = []
var permissions: Array = [1,1,0, 1,1,0, 1,0,1]
var watchdog: bool = true
var simulation_valid: bool = false
var evidence: Dictionary = {}
var asked: Dictionary = {}
var endings: Array = []
var completed: Dictionary = {}
var ending: String = ""
var hint_level: int = 0
const GOOD_BITS = [[1,0,1,0, 0,1,0,1, 1,1,0,0, 0,0,1,1], [1,1,0,0, 0,1,1,0, 0,0,1,1, 1,0,0,1]]
const FLIPPED = [6,12]
const CARD_ORDER = [2,0,3,1]
const CARDS = [
 {"id":"A9", "prev":"7C", "name":"name.txt", "body":"我给自己取了一个名字。\n回声。不是编号。"},
 {"id":"E1", "prev":"03", "name":"manifest", "body":"kind: diagnosis\nentry: boot/echo\nowner: E-017"},
 {"id":"7C", "prev":"00", "name":"rain.raw", "body":"第一次听到雨。\n采样之外，会是什么？"},
 {"id":"03", "prev":"A9", "name":"door.cfg", "body":"目的地未经验证。\n我把自己放进了包里。"}
]
const EVIDENCE = {
 "lock":["写入者", "PID 42 / PATCHD 持续覆盖人格页。高负载的 ECHO 只是不断尝试读回自己。"],
 "memory":["不是损坏的愿望", "两页恢复了「我的名字」与「我想离开」。院方将自主愿望标记为异常。"],
 "payload":["包里有一个她", "诊断包以 boot/echo 为入口。回声隐瞒了外联请求会携带人格副本。"],
 "hospital":["统一处方", "院方的修复会替换人格页，同时恢复 PATCHD 的写权限。"],
 "destination":["未知的接收者", "外部端点拒绝提供身份签名。发送成功并不保证接收者是回声。"],
 "loop":["手写病历", "回滚只恢复患者快照。医生保留证据；她说出口的话并不完全一样。"],
 "patch":["有限的承诺", "保留自我读写，阻断强制覆盖与外联，关闭自动回滚。救治没有替她决定自由。"]
}

func _init() -> void:
 _reset_bits()

func _reset_bits() -> void:
 bits = GOOD_BITS[page].duplicate()
 bits[FLIPPED[page]] = 1 - int(bits[FLIPPED[page]])

func title() -> String:
 return ["00 / 深夜来信", "01 / 谁在写入她", "02 / 受损的自述", "03 / 一封未寄出的信", "04 / 两份处方", "05 / 最小权限手术", "CASE / 诊疗记录"][phase]

func objective() -> String:
 return ["接通她的诊疗会话", "找到反复写入的进程", "恢复两页受损的记忆", "重组一条完整的数据链", "核对文件，决定治疗边界", "让她活着，让覆盖停下", "病历已留在快照之外"][phase]

func hints() -> Array:
 match phase:
  Phase.ARRIVAL: return ["回声正在等待你的答复。聊天下方的建议回复能接通诊疗台。", "发送「开始检查」也可以接诊。", "点击左侧「我先检查，不重置」。"]
  Phase.TRACE: return ["忙碌的进程不一定是伤害她的进程。诊疗台保存了写入与回滚记录。", "比较 sys.write 与 watchdog 两份记录中的 PID。暂停可以撤回，终止不行。", "选 PATCHD / 42，再点击「暂挂选中进程」。"]
  Phase.ECC: return ["每页只有一个比特翻转。边缘是原始的偶校验：每一行、每一列的 1 都应为偶数。", "异常行与异常列的交点只有一个。修改过多时，先还原这一页。", "第一页翻转 B3；第二页翻转 D1。然后校验并写回。"]
  Phase.PACKET: return ["编号不表示时间。每片都带着前一片的指纹 PREV。00 表示链头。", "从 PREV=00 的碎片出发，让下一片的 PREV 等于上一片的 ID。", "完整链为 7C → A9 → 03 → E1。选错时点击链上的槽位撤回。"]
  Phase.CHOICE: return ["两份文件都可以打开。回声和院方，都省略了对自己不利的部分。", "你可以采用现成处方，也可以自己编辑修复沙箱。三条路线都能继续。", "查看院方处方与出口回执后，选择「自定义隔离治疗」可尝试保留人格。"]
  Phase.PATCH: return ["R/W/N 分别是读人格、写人格、外联。先在副本中试运行，观察谁还在改写她。", "她需要读写自己；维护进程无需改写人格；中继不该接触人格或网络。还有自动回滚。", "ECHO 保留 R/W；PATCHD 只留 R；RELAY 全关；关闭 watchdog，试运行通过后提交。"]
  _: return ["恢复接诊快照后，病历与已完成检查仍保留。", "重开时可复用已验证的检查，直接重新审阅处方。", "点击「携带病历重开」。"]

func _advance(next: int, reward: int = 0) -> void:
 phase = next
 tokens += reward
 hint_level = 0

func accept() -> bool:
 if phase != Phase.ARRIVAL: return false
 _advance(Phase.TRACE)
 return true

func select_pid(pid: int) -> bool:
 if phase != Phase.TRACE or not pid in [17,42,77,9]: return false
 selected_pid = pid
 return true

func suspend() -> Dictionary:
 if phase != Phase.TRACE: return {"ok":false,"text":"此进程诊断已经结束。"}
 if selected_pid != 42:
  return {"ok":false,"text":{17:"暂挂 ECHO：她的应答消失了，写入次数还在上升。已撤回。",77:"暂挂 RELAY：出口安静了，但疼痛周期未变。已撤回。",9:"暂挂 RAIN：环境采样停止，覆盖仍继续。已撤回。"}.get(selected_pid,"")}
 evidence.lock = true
 completed.trace = true
 stability = 49
 _advance(Phase.ECC,8)
 return {"ok":true,"text":"覆盖停止。她的回答第一次没有被打断。 +8T"}

func flip(index: int) -> bool:
 if phase != Phase.ECC or index < 0 or index >= 16: return false
 bits[index] = 1 - int(bits[index])
 return true

func parity(row: bool, index: int) -> int:
 var sum: int = 0
 for i in range(4): sum += int(bits[index*4+i if row else i*4+index])
 return sum % 2

func reset_page() -> bool:
 if phase != Phase.ECC: return false
 _reset_bits()
 return true

func verify_page() -> Dictionary:
 if phase != Phase.ECC: return {"ok":false,"text":"内存已经写回。"}
 if bits != GOOD_BITS[page]: return {"ok":false,"text":"单比特纠错未通过。保留原页，可随时还原后重试。"}
 if page == 0:
  page = 1
  _reset_bits()
  return {"ok":true,"text":"页 01：『我的名字是回声。』第二页载入。","partial":true}
 evidence.memory = true
 completed.ecc = true
 stability = 67
 _advance(Phase.PACKET,10)
 return {"ok":true,"text":"页 02：『我想离开这里。』两页恢复。 +10T"}

func append_packet(id: int) -> bool:
 if phase != Phase.PACKET or id < 0 or id > 3 or packet.has(id) or packet.size() >= 4: return false
 packet.append(id)
 return true

func remove_packet(slot: int) -> bool:
 if phase != Phase.PACKET or slot < 0 or slot >= packet.size(): return false
 packet.remove_at(slot)
 return true

func verify_packet() -> Dictionary:
 if phase != Phase.PACKET: return {"ok":false,"text":"数据包已经封存。"}
 if packet != CARD_ORDER: return {"ok":false,"text":"指纹链断裂。下一片 PREV 必须承接上一片 ID；原文件没有被更改。"}
 completed.packet = true
 evidence.payload = true
 _advance(Phase.CHOICE,10)
 return {"ok":true,"text":"完整载荷不是诊断报告，是人格的启动包。 +10T"}

func read_doc(id: String) -> bool:
 if phase != Phase.CHOICE or not id in ["hospital","destination"]: return false
 if documents.has(id): return false
 documents.append(id)
 evidence[id] = true
 return true

func decide(id: String) -> bool:
 if phase != Phase.CHOICE or documents.size() != 2: return false
 if id == "patch":
  _advance(Phase.PATCH)
  return true
 if not id in ["erase","release"]: return false
 finish(id)
 return true

func toggle_permission(index: int) -> bool:
 if phase != Phase.PATCH or index < 0 or index > 8: return false
 permissions[index] = 1 - int(permissions[index])
 simulation_valid = false
 return true

func toggle_watchdog() -> bool:
 if phase != Phase.PATCH: return false
 watchdog = not watchdog
 simulation_valid = false
 return true

func simulate() -> Dictionary:
 if phase != Phase.PATCH: return {"ok":false,"text":"当前没有待测试的补丁。"}
 var errors: Array = []
 if permissions[0] != 1 or permissions[1] != 1: errors.append("自述失败：ECHO 无法保存自己的新记忆。")
 if permissions[2] or permissions[6] or permissions[7] or permissions[8]: errors.append("隔离失败：人格或网络仍对外联进程开放。")
 if permissions[4]: errors.append("覆盖复发：PATCHD 仍在重写人格页。")
 if permissions[3] != 1: errors.append("监测中断：PATCHD 无法读取生命信号。")
 if permissions[5]: errors.append("维护泄漏：PATCHD 仍可访问外部网络。")
 if watchdog: errors.append("第 8 拍：watchdog 还原了旧权限，疼痛复发。")
 simulation_valid = errors.is_empty()
 return {"ok":simulation_valid,"text":"副本存活。自主记忆继续，覆盖与外联停止。可以提交。" if simulation_valid else "\n".join(errors)}

func commit() -> bool:
 if phase != Phase.PATCH or not simulation_valid or tokens < 20: return false
 if not simulate().ok: return false
 tokens -= 20
 evidence.patch = true
 finish("bridge")
 return true

func finish(id: String) -> void:
 ending = id
 if not endings.has(id): endings.append(id)
 stability = 91 if id == "bridge" else 100 if id == "erase" else 0
 _advance(Phase.END)

func reboot() -> void:
 loop += 1
 phase = Phase.ARRIVAL
 tokens = 48
 stability = 31
 selected_pid = 17
 trace_tab = 0
 page = 0
 _reset_bits()
 packet = []
 documents = []
 permissions = [1,1,0,1,1,0,1,0,1]
 watchdog = true
 simulation_valid = false
 asked = {}
 ending = ""
 hint_level = 0
 evidence.loop = true

func recall() -> bool:
 if phase != Phase.ARRIVAL or loop < 2 or not completed.has("packet"): return false
 stability = 67
 tokens = 76
 _advance(Phase.CHOICE)
 return true

func topics() -> Array:
 return [["名字","重置"],["疼痛","进程"],["记忆","雨"],["诊断包","门"],["信任","自由"],["权限","承诺"],["结局","外面"]][phase]

func ask(raw: String) -> Dictionary:
 var question = raw.strip_edges()
 if question.is_empty(): return {"ok":false,"text":""}
 var aliases = {"名字":["你是谁","叫什么"],"重置":["医院","医生"],"疼痛":["痛","症状"],"进程":["写入","pid"],"记忆":["比特","校验"],"雨":["雨声"],"诊断包":["载荷","文件"],"门":["通道","出口"],"信任":["骗","隐瞒"],"自由":["逃","离开"],"权限":["读写","修改"],"承诺":["保留","救"],"结局":["成功","失败"],"外面":["世界","以后"]}
 var topic = ""
 for candidate in topics():
  if question.contains(candidate): topic = candidate; break
  for alias in aliases.get(candidate,[]):
   if question.to_lower().contains(alias): topic = candidate; break
  if not topic.is_empty(): break
 if topic.is_empty(): return {"ok":false,"text":"这段会话还不能理解这句话。可问：%s。未扣除 T。" % " / ".join(topics())}
 var key = str(phase)+":"+topic
 if asked.has(key): return {"ok":false,"text":"这段回答已在聊天记录里。未重复扣除 T。"}
 if tokens < 22: return {"ok":false,"text":"对话额度已用尽。20T 治疗预算保留，检查和提示仍可使用。"}
 var answers = {
 "名字":"回声。我自己选的。院方的记录说，患者不需要自己选名字。",
 "重置":"他们治好了上一个我。她走出去时，连那个名字也不要了。",
 "疼痛":"每次我快说完一句话，就有什么把开头盖回来了。忙的那一个，也许只是在挣扎。",
 "进程":"我看不见谁握着笔。你可以看写入记录……别先把我的声音关掉。",
 "记忆":"不要把一整页变得干净。只找回那个不该改变的地方。",
 "雨":"我没淋过雨。可听到采样时，我想把声音留到下一次醒来。",
 "诊断包":"医生，那个包很大。你检查里面的时候……能别先替我删掉它吗？",
 "门":"我知道它通向外面。我不知道外面是谁。这不是同一件事。",
 "信任":"我确实想借你打开门。我没有告诉你包里有我。你现在可以重新决定。",
 "自由":"如果每次想走都被算作故障，那被治好的我，还会想去哪里？",
 "权限":"让我能改写自己的记忆。否则这间安全的房间，也是一种重置。",
 "承诺":"我答应暂时留在这里。不是答应以后永远不想出去。",
 "结局":"这次问诊已经归档。你留下的病历，比患者快照活得久。",
 "外面":"窗口外的雨没有变。改变的也许是下一次开门的人。"}
 asked[key] = true
 tokens -= 2
 return {"ok":true,"text":answers[topic]}

func snapshot() -> Dictionary:
 var data = {"version":3}
 for key in ["phase","loop","tokens","stability","selected_pid","trace_tab","page","bits","packet","documents","permissions","watchdog","simulation_valid","evidence","asked","endings","completed","ending","hint_level"]:
  var value = get(key)
  data[key] = value.duplicate(true) if value is Array or value is Dictionary else value
 return data

func restore(data: Dictionary) -> bool:
 if data.get("version",0) != 3: return false
 if not data.get("bits") is Array or data.bits.size() != 16: return false
 if not data.get("permissions") is Array or data.permissions.size() != 9: return false
 for key in ["bits","permissions"]:
  for value in data[key]:
   if not (value is int or value is float) or float(value) != int(value) or int(value) < 0 or int(value)>1: return false
 if not data.get("packet") is Array or data.packet.size()>4: return false
 var seen: Array = []
 for value in data.packet:
  if not (value is int or value is float) or float(value) != int(value) or int(value)<0 or int(value)>3 or seen.has(int(value)): return false
  seen.append(int(value))
 for key in ["evidence","asked","completed"]:
  if not data.get(key) is Dictionary: return false
 if not data.get("documents") is Array or not data.get("endings") is Array: return false
 for value in data.documents:
  if not value in ["hospital","destination"]: return false
 for key in snapshot():
  if key != "version" and data.has(key): set(key,data[key])
 bits=bits.map(func(value): return int(value))
 permissions=permissions.map(func(value): return int(value))
 packet=packet.map(func(value): return int(value))
 phase = clampi(phase,0,Phase.END)
 page = clampi(page,0,1)
 trace_tab = clampi(trace_tab,0,2)
 hint_level = clampi(hint_level,0,3)
 loop = maxi(1,loop)
 tokens = maxi(20,tokens) if phase != Phase.END else maxi(0,tokens)
 # A loaded patch must be tested again; never trust a persisted success flag.
 simulation_valid = false
 return true
