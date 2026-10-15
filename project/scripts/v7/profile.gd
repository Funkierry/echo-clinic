extends RefCounted
## One save transaction owns wallet, case, rewards, contacts and work orders.
const INITIAL=24
const CHAT=1
const EXAM=4
const CARE=8
const WORK=6
var balance: int=INITIAL
var holds: Dictionary={}
var ledger: Array=[{"reason":"首次开诊补助","amount":INITIAL,"balance":INITIAL}]
var contacts: Dictionary={}
var records: Array=[]
var claims: Dictionary={}
var work_types: Dictionary={}
var serial: int=0
var completed: int=0
var job: Dictionary={}
var instruments: Dictionary={}

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

func _entry(amount: int,reason: String) -> void:
 balance+=amount
 ledger.append({"reason":reason,"amount":amount,"balance":balance})
 if ledger.size()>80: ledger.pop_front()

func reward_once(id: String,amount: int,reason: String) -> bool:
 if claims.has(id) or amount<0: return false
 claims[id]=true
 _entry(amount,reason)
 return true

func unlock(id: String,ending: String="") -> bool:
 if contacts.has(id): return false
 contacts[id]={"ending":ending,"history":[],"turn":0}
 return true

func record_case(s) -> bool:
 var key="case:%d:%s"%[s.loop,s.ending]
 if claims.has(key): return false
 claims[key]=true
 records.append({"loop":s.loop,"ending":s.ending,"evidence":s.evidence.keys(),"proposal":s.proposal.duplicate()})
 if records.size()>40: records.pop_front()
 if s.ending in ["bridge","witness"]:
  unlock("echo",s.ending)
  return reward_once("echo:first_cure",6,"回声首次康复补贴")
 return false

func start_job(kind: String) -> bool:
 if not job.is_empty() or kind not in ["route","signal","memory"]: return false
 serial+=1
 var rng=RandomNumberGenerator.new(); rng.seed=7919*serial+kind.hash()
 job={"id":serial,"kind":kind,"moves":0,"data":[],"target":[]}
 if kind=="route":
  # Hamiltonian cable, left inlet at 0 and right outlet at 8.
  job.target=[10,10,12,6,10,9,3,10,10]
  if serial%2==0: job.target=[12,6,12,5,5,5,3,9,3]
  for mask in job.target:
   for n in range(rng.randi_range(0,3)): mask=rotate(mask)
   job.data.append(mask)
 elif kind=="signal":
  for i in range(3):
   var target=rng.randi_range(1,6)
   job.target.append(target); job.data.append((target+rng.randi_range(1,5))%7)
 else:
  job.data=[0,0,0,0,0,0,0,0,0]
  for i in range(5): _toggle(job.data,rng.randi_range(0,8))
 if solved():
  if kind=="route": job.data[0]=rotate(job.data[0])
  elif kind=="memory": _toggle(job.data,4)
 return true

static func rotate(mask: int) -> int:
 return ((mask<<1)&15)|((mask>>3)&1)

static func _toggle(data: Array,index: int) -> void:
 for i in range(9):
  if absi(i%3-index%3)+absi(i/3-index/3)<=1: data[i]=1-int(data[i])

func move(index: int,value: int=0) -> bool:
 if job.is_empty() or solved(): return false
 if index<0 or index>=job.data.size(): return false
 match job.kind:
  "route": job.data[index]=rotate(int(job.data[index]))
  "signal": job.data[index]=clampi(value,0,6)
  "memory": _toggle(job.data,index)
 job.moves+=1
 return true

func solved() -> bool:
 if job.is_empty(): return false
 if job.kind=="memory": return job.data.count(1)==0
 return job.data==job.target

func claim_job() -> bool:
 if not solved(): return false
 if not reward_once("work:%d"%int(job.id),WORK,"维修工单 #%03d"%int(job.id)): return false
 work_types[job.kind]=true; completed+=1; job={}
 if work_types.size()==3: unlock("lamp","repaired")
 return true

func snapshot() -> Dictionary:
 # Reservations are ephemeral. A restarted request cannot bill or execute anything.
 return {"balance":balance,"ledger":ledger,"contacts":contacts,"records":records,"claims":claims,"work_types":work_types,"serial":serial,"completed":completed,"job":job,"instruments":instruments}

func restore(data: Variant) -> bool:
 if not data is Dictionary or not data.get("balance") is float and not data.get("balance") is int: return false
 for key in ["contacts","claims","work_types","job","instruments"]:
  if not data.get(key) is Dictionary: return false
 for key in ["ledger","records"]:
  if not data.get(key) is Array: return false
 balance=clampi(int(data.balance),0,999999)
 for key in ["ledger","contacts","records","claims","work_types","job","instruments"]: set(key,data[key].duplicate(true))
 serial=maxi(0,int(data.get("serial",0))); completed=maxi(0,int(data.get("completed",0))); holds={}
 for entry in ledger:
  entry.amount=int(entry.get("amount",0)); entry.balance=int(entry.get("balance",0))
 for record in records:
  record.loop=int(record.get("loop",1))
  if record.get("proposal") is Array: record.proposal=record.proposal.map(func(n):return int(n))
 for id in contacts.keys():
  if id not in ["echo","lamp"] or not contacts[id] is Dictionary: contacts.erase(id); continue
  if not contacts[id].get("history") is Array: contacts[id].history=[]
  contacts[id].turn=int(contacts[id].get("turn",0))
 if not job.is_empty():
  if not job.get("data") is Array or not job.get("target") is Array or job.get("kind","") not in ["route","signal","memory"]:
   job={}
  elif job.data.size()!=(3 if job.kind=="signal" else 9): job={}
  else:
   job.data=job.data.map(func(n):return int(n)); job.target=job.target.map(func(n):return int(n))
   job.id=int(job.get("id",serial)); job.moves=int(job.get("moves",0))
 return true
