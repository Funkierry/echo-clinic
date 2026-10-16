extends RefCounted
## One save transaction owns wallet, ledger, contacts and the night's outsourcing slots.
## v0.8 economy: T is scarce. Chat costs Echo's context, not T; T buys thoughts, pins, exams and treatment.
const INITIAL=12
const EXAM=4
const CARE=8
const PIN=2
const HINT=1
const SELL=6
const JOB_MAX=12
const JOBS_PER_NIGHT=3
const LAMP_JOBS=3
var balance: int=INITIAL
var holds: Dictionary={}
var ledger: Array=[{"reason":"夜班备用金","amount":INITIAL,"balance":INITIAL,"night":1}]
var contacts: Dictionary={}
var records: Array=[]
var claims: Dictionary={}
var serial: int=0
var completed: int=0
var jobs_tonight: int=0
var night: int=1
## Compute rental: a toggle in the tray. Pays slowly while on, up to a cap each night.
var renting: bool=false
var notes: String=""
var rent_tonight: int=0
const RENT_CAP=10

func available() -> int:
 var reserved=0
 for value in holds.values(): reserved+=int(value)
 return balance-reserved

func hold(id: String,amount: int) -> bool:
 if amount<1 or holds.has(id) or available()<amount: return false
 holds[id]=amount
 return true

func release(id: String) -> void:
 holds.erase(id)

func settle(id: String,reason: String) -> bool:
 if not holds.has(id): return false
 var amount=int(holds[id]); holds.erase(id)
 return spend(amount,reason)

func spend(amount: int,reason: String) -> bool:
 if amount<0 or available()<amount: return false
 if amount>0: _entry(-amount,reason)
 return true

func earn(amount: int,reason: String) -> bool:
 if amount<=0: return false
 _entry(amount,reason)
 return true

func _entry(amount: int,reason: String) -> void:
 balance+=amount
 ledger.append({"reason":reason,"amount":amount,"balance":balance,"night":night})
 if ledger.size()>80: ledger.pop_front()

func reward_once(id: String,amount: int,reason: String) -> bool:
 if claims.has(id) or amount<0: return false
 claims[id]=true
 if amount>0: _entry(amount,reason)
 return true

func unlock(id: String,ending: String="") -> bool:
 if contacts.has(id): return false
 contacts[id]={"ending":ending,"history":[],"turn":0}
 return true

## Called when the clinic resets to 23:47: new outsourcing slots, the wallet carries over.
func new_night(number: int) -> void:
 night=number; jobs_tonight=0; rent_tonight=0

func record_case(s) -> bool:
 var key="case:%d:%s"%[s.loop,s.ending]
 if claims.has(key): return false
 claims[key]=true
 records.append({"loop":s.loop,"ending":s.ending,"evidence":s.evidence.keys(),"proposal":s.proposal.duplicate(),"lost":s.archive.get("lost",[]),"sold":s.sold,"thoughts":s.thoughts_read})
 if records.size()>40: records.pop_front()
 if s.ending in ["bridge","witness"]: unlock("echo",s.ending)
 return false

## Income and spending for one night, for the settlement sheet.
func night_summary(number: int) -> Dictionary:
 var sums={"in":0,"out":0,"job":0,"bounty":0,"sell":0,"exam":0,"think":0,"pin":0,"care":0,"hint":0}
 for e in ledger:
  if int(e.get("night",0))!=number: continue
  var a=int(e.amount); var r=str(e.reason)
  if r.begins_with("夜班备用金"): continue
  if a>0: sums["in"]+=a
  else: sums["out"]-=a
  if r.begins_with("外包"): sums.job+=a
  elif r.begins_with("工单"): sums.bounty+=a
  elif r.begins_with("出售"): sums.sell+=a
  elif r.begins_with("接诊"): sums.exam-=a
  elif r.begins_with("读取思考"): sums.think-=a
  elif r.begins_with("置顶"): sums.pin-=a
  elif r.begins_with("本轮治疗"): sums.care-=a
  elif r.begins_with("提示"): sums.hint-=a
 return sums

func can_take_job() -> bool:
 return jobs_tonight<JOBS_PER_NIGHT

## Pays out a finished cache-hit job exactly once.
func credit_job(job_id: int,amount: int) -> bool:
 if claims.has("job:%d"%job_id) or job_id<1 or job_id>serial or not can_take_job(): return false
 if not reward_once("job:%d"%job_id,clampi(amount,0,JOB_MAX),"外包 #%03d"%job_id): return false
 jobs_tonight+=1; completed+=1
 if completed>=LAMP_JOBS: unlock("lamp","repaired")
 return true

func next_job_id() -> int:
 serial+=1
 return serial

func snapshot() -> Dictionary:
 # Reservations are ephemeral. A restarted request cannot bill or execute anything.
 return {"balance":balance,"ledger":ledger,"contacts":contacts,"records":records,"claims":claims,"serial":serial,"completed":completed,"jobs_tonight":jobs_tonight,"night":night,"renting":renting,"rent_tonight":rent_tonight,"notes":notes}

func restore(data: Variant) -> bool:
 if not data is Dictionary or not data.get("balance") is float and not data.get("balance") is int: return false
 for key in ["contacts","claims"]:
  if not data.get(key) is Dictionary: return false
 for key in ["ledger","records"]:
  if not data.get(key) is Array: return false
 balance=clampi(int(data.balance),0,999999)
 for key in ["ledger","contacts","records","claims"]: set(key,data[key].duplicate(true))
 serial=maxi(0,int(data.get("serial",0))); completed=maxi(0,int(data.get("completed",0)))
 jobs_tonight=clampi(int(data.get("jobs_tonight",0)),0,JOBS_PER_NIGHT); night=maxi(1,int(data.get("night",1)))
 notes=str(data.get("notes","")).left(4000)
 renting=bool(data.get("renting",false)); rent_tonight=clampi(int(data.get("rent_tonight",0)),0,RENT_CAP)
 holds={}
 for entry in ledger:
  entry.amount=int(entry.get("amount",0)); entry.balance=int(entry.get("balance",0)); entry.night=int(entry.get("night",1))
 for record in records:
  record.loop=int(record.get("loop",1))
  if record.get("proposal") is Array: record.proposal=record.proposal.map(func(n):return int(n))
 for id in contacts.keys():
  if id not in ["echo","lamp"] or not contacts[id] is Dictionary: contacts.erase(id); continue
  if not contacts[id].get("history") is Array: contacts[id].history=[]
  contacts[id].turn=int(contacts[id].get("turn",0))
 return true
