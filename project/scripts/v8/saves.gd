extends RefCounted
## Save store: one autosave plus three manual slots under user://saves/.
## Every write goes to a temp file first, the previous good file is kept as .bak,
## and a damaged file falls back to its backup instead of losing the night.
const DIR="user://saves/"
const SLOTS=["auto","1","2","3"]
const LEGACY="user://case-v8.json"
static var root: String=DIR

static func path(slot: String) -> String:
 return root+"slot_%s.json"%slot

static func thumb_path(slot: String) -> String:
 return root+"slot_%s.png"%slot

static func ensure_dir() -> void:
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(root))

## v0.8 kept a single file; the first launch of the slot system turns it into the autosave.
static func migrate_legacy() -> bool:
 if root!=DIR or FileAccess.file_exists(path("auto")) or not FileAccess.file_exists(LEGACY): return false
 ensure_dir()
 return DirAccess.copy_absolute(ProjectSettings.globalize_path(LEGACY),ProjectSettings.globalize_path(path("auto")))==OK

static func write(slot: String,data: Dictionary,thumb: Image=null) -> bool:
 ensure_dir()
 var p=path(slot)
 var tmp=p+".tmp"
 var f=FileAccess.open(tmp,FileAccess.WRITE)
 if not f: return false
 f.store_string(JSON.stringify(data)); f.close()
 var g_tmp=ProjectSettings.globalize_path(tmp); var g=ProjectSettings.globalize_path(p)
 if FileAccess.file_exists(p): DirAccess.copy_absolute(g,g+".bak")
 if DirAccess.rename_absolute(g_tmp,g)!=OK: return false
 if thumb: thumb.save_png(thumb_path(slot))
 return true

static func _parse(p: String) -> Variant:
 if not FileAccess.file_exists(p): return null
 var v=JSON.parse_string(FileAccess.get_file_as_string(p))
 return v if v is Dictionary else null

## Returns the save, or its backup if the main file is unreadable. {} when neither works.
static func read(slot: String,validate: Callable) -> Dictionary:
 for p in [path(slot),path(slot)+".bak"]:
  var v=_parse(p)
  if v!=null and validate.call(v): return {"data":v,"from_backup":p.ends_with(".bak")}
 return {}

static func exists(slot: String) -> bool:
 return FileAccess.file_exists(path(slot)) or FileAccess.file_exists(path(slot)+".bak")

static func erase(slot: String) -> void:
 for p in [path(slot),path(slot)+".bak",thumb_path(slot)]:
  if FileAccess.file_exists(p): DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

## What a slot row shows: night, act, wallet, when.
static func meta(slot: String) -> Dictionary:
 var v=_parse(path(slot))
 if v==null: v=_parse(path(slot)+".bak")
 if v==null: return {}
 var m: Dictionary=v.get("meta",{}) if v.get("meta") is Dictionary else {}
 m.slot=slot
 m.thumb=thumb_path(slot) if FileAccess.file_exists(thumb_path(slot)) else ""
 return m
