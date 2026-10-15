extends Node
## One bounded request, no tools, retries, redirect following or credential persistence.
signal completed(ticket: int, result: Dictionary)
const ENDPOINT="https://api.deepseek.com/chat/completions"
const DEFAULT_MODEL="deepseek-flash"
var endpoint: String=ENDPOINT
var model: String=DEFAULT_MODEL
var api_key: String=""
var enabled: bool=false
var busy: bool=false
var serial: int=0
var request_node: HTTPRequest
var timeout_seconds: float=35.0
var mock_allowed: bool=false

func settings_error() -> String:
 if endpoint!=ENDPOINT and endpoint!="https://api.deepseek.com/v1/chat/completions":
  if not (mock_allowed and endpoint.begins_with("http://127.0.0.1:")): return "此版本仅连接 DeepSeek 官方接口。"
 if model.strip_edges().is_empty() or model.length()>100 or model.contains("\n"): return "请填写模型名。"
 if api_key.strip_edges().is_empty(): return "请在 AI 设置中输入 DeepSeek API Key。"
 if api_key.contains("\n") or api_key.contains("\r"): return "密钥格式不正确。"
 return ""

func body_for(system_prompt: String, context: Dictionary) -> Dictionary:
 return {"model":model,"messages":[{"role":"system","content":system_prompt},{"role":"user","content":JSON.stringify(context)}],"response_format":{"type":"json_object"},"thinking":{"type":"disabled"},"max_tokens":700,"temperature":0.7,"stream":false}

func send(system_prompt: String, context: Dictionary) -> int:
 if busy or not settings_error().is_empty(): return -1
 serial+=1
 var ticket=serial
 busy=true
 request_node=HTTPRequest.new()
 request_node.timeout=timeout_seconds
 request_node.max_redirects=0
 request_node.body_size_limit=131072
 request_node.use_threads=true
 add_child(request_node)
 request_node.request_completed.connect(func(result,code,_headers,body): _finished(ticket,result,code,body))
 var error=request_node.request(endpoint,PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+api_key]),HTTPClient.METHOD_POST,JSON.stringify(body_for(system_prompt,context)))
 if error!=OK: call_deferred("_finished",ticket,HTTPRequest.RESULT_CANT_CONNECT,0,PackedByteArray())
 return ticket

func cancel() -> void:
 serial+=1; busy=false
 if is_instance_valid(request_node):
  request_node.cancel_request(); request_node.queue_free()
 request_node=null

func _finished(ticket: int, result: int, code: int, body: PackedByteArray) -> void:
 if ticket!=serial or not busy: return
 busy=false
 if is_instance_valid(request_node): request_node.queue_free()
 request_node=null
 completed.emit(ticket,decode(result,code,body))

static func decode(result: int, code: int, body: PackedByteArray) -> Dictionary:
 if result==HTTPRequest.RESULT_TIMEOUT: return {"ok":false,"error":"等待超时；这句未扣游戏 T。可以继续剧情或稍后再问。"}
 if result!=HTTPRequest.RESULT_SUCCESS: return {"ok":false,"error":"连接中断；这句未扣游戏 T，剧情仍可继续。"}
 if code!=200:
  var messages={401:"密钥未通过验证，请检查 AI 设置。",402:"DeepSeek 账户余额不足。",403:"服务拒绝了请求，请检查账户权限。",404:"模型或接口不可用，请检查模型名。",429:"服务限流；请稍后再发，不会自动重试。",400:"服务不接受当前配置，请检查模型名。"}
  return {"ok":false,"error":messages.get(code,"服务暂时不可用（HTTP %d）。"%code)+" 未扣游戏 T。"}
 if body.size()>131072: return {"ok":false,"error":"回复过大，已忽略。未扣游戏 T。"}
 var json=JSON.new()
 if json.parse(body.get_string_from_utf8())!=OK: return {"ok":false,"error":"服务回复格式异常。未扣游戏 T。"}
 var data=json.data
 if not data is Dictionary or not data.get("choices") is Array or data.choices.is_empty(): return {"ok":false,"error":"服务返回了空回复。未扣游戏 T。"}
 var choice=data.choices[0]
 if not choice is Dictionary or choice.get("finish_reason","")!="stop" or not choice.get("message") is Dictionary: return {"ok":false,"error":"回复未完整生成。未扣游戏 T。"}
 var message=choice.message
 if message.has("tool_calls") and message.tool_calls!=null and message.tool_calls!=[]: return {"ok":false,"error":"回复含有未允许的操作。未扣游戏 T。"}
 if not message.get("content") is String or message.content.length()>4096: return {"ok":false,"error":"服务返回了无效回复。未扣游戏 T。"}
 var parsed=JSON.new()
 if parsed.parse(message.content)!=OK: return {"ok":false,"error":"回复格式不符合约定。未扣游戏 T。"}
 return {"ok":true,"value":parsed.data}
