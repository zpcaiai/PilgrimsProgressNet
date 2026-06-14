extends Node
## NetConfig
## Network layer configuration. Autoload as "NetConfig".
## Toggle `enabled` off to run the game purely offline (default-safe).

# Set to your deployed backend. For local docker-compose use http://localhost:8080
var base_url: String = "http://localhost:8080/api/v1"

# Master switch. If false, every NetService becomes a no-op and the game
# behaves exactly like the single-player build.
var enabled: bool = true

# How often (seconds) to sample the player position into a ghost trail.
var ghost_sample_interval: float = 1.0

# Request timeout (seconds).
var timeout_sec: float = 10.0

# Real-time companionship (WebSocket). When true and the backend is reachable,
# you see other pilgrims move live; otherwise the async-ghost layer still works.
var realtime: bool = true


func is_web() -> bool:
	return OS.has_feature("web")


## Server origin + path for static media (strips the API prefix), e.g.
## base_url "http://host:8080/api/v1" -> "http://host:8080/media/x.png".
func media_url(path: String) -> String:
	var b := base_url
	if b.ends_with("/api/v1"):
		b = b.substr(0, b.length() - 7)
	return b + path


## Derive a ws:// or wss:// URL for the given API path from base_url.
func ws_url(path: String) -> String:
	var b := base_url
	if b.begins_with("https"):
		b = "wss" + b.substr(5)
	elif b.begins_with("http"):
		b = "ws" + b.substr(4)
	return b + path
