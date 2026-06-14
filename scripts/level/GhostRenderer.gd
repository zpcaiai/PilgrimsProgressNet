extends Node3D
## GhostRenderer
## Renders other pilgrims' async "ghosts" in the world: a faint translucent
## stand-in that walks along each fetched trail, plus glowing motes at written
## markers. Drop one into a chapter scene and point it at the player.
##
## Setup (in a chapter's _ready, after the pilgrim exists):
##     var gr := preload("res://scripts/level/GhostRenderer.gd").new()
##     add_child(gr)
##     gr.bind_player(pilgrim_node)   # Node3D
##
## It registers the player with GhostService (for trail sampling) and listens
## for GhostService.ghosts_received to spawn ghosts for the current chapter.
## Fully inert when networking is disabled.

const GHOST_COLOR := Color(0.6, 0.8, 1.0, 0.28)
const MARKER_COLOR := Color(1.0, 0.92, 0.55, 0.9)
const LIVE_COLOR := Color(0.55, 1.0, 0.7, 0.85)   # live companions read brighter
const WALK_SPEED := 2.2   # m/s along the trail

var _ghost_root: Node3D
var _peer_root: Node3D
var _peers: Dictionary = {}      # peer_id -> Node3D avatar
var _buffers: Dictionary = {}    # peer_id -> Array of {t:int(ms), pos:Vector3, yaw:float}

# Entity interpolation: render peers in the past and interpolate between the two
# snapshots bracketing that time, using local receive timestamps. This absorbs
# network jitter. The delay ADAPTS to connection quality (more delay = smoother
# under poor networks, at the cost of more lag).
const DELAY_GOOD := 90.0
const DELAY_FAIR := 160.0
const DELAY_POOR := 260.0
const BUFFER_KEEP_MS := 1200

var _interp_delay: float = DELAY_GOOD
var _target_delay: float = DELAY_GOOD


func _ready() -> void:
	_ghost_root = Node3D.new()
	add_child(_ghost_root)
	_peer_root = Node3D.new()
	add_child(_peer_root)
	if NetConfig.enabled:
		GhostService.ghosts_received.connect(_on_ghosts)
		if NetConfig.realtime:
			RealtimeService.peer_updated.connect(_on_peer_updated)
			RealtimeService.peer_left.connect(_on_peer_left)
			RealtimeService.net_stats.connect(_on_net_stats)


func _on_net_stats(_latency_ms: int, quality: String) -> void:
	match quality:
		"good": _target_delay = DELAY_GOOD
		"fair": _target_delay = DELAY_FAIR
		_: _target_delay = DELAY_POOR


func bind_player(player: Node3D) -> void:
	if NetConfig.enabled:
		GhostService.set_player(player)
		if NetConfig.realtime:
			RealtimeService.set_player(player)


# --- Live (real-time) companions ---
func _on_peer_updated(peer_id: String, peer_name: String, pos: Vector3, yaw: float) -> void:
	var avatar: Node3D = _peers.get(peer_id)
	if avatar == null:
		avatar = _make_capsule(LIVE_COLOR)
		var tag := Label3D.new()
		tag.text = peer_name
		tag.modulate = Color(0.7, 1.0, 0.8, 0.9)
		tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		tag.no_depth_test = true
		tag.position = Vector3(0, 2.2, 0)
		tag.pixel_size = 0.012
		avatar.add_child(tag)
		avatar.position = pos      # snap on first sighting
		avatar.rotation.y = yaw
		_peer_root.add_child(avatar)
		_peers[peer_id] = avatar
		_buffers[peer_id] = []
	# Append a timestamped snapshot to the peer's interpolation buffer.
	var buf: Array = _buffers[peer_id]
	buf.append({"t": Time.get_ticks_msec(), "pos": pos, "yaw": yaw})


func _on_peer_left(peer_id: String) -> void:
	var avatar: Node3D = _peers.get(peer_id)
	if avatar != null:
		avatar.queue_free()
		_peers.erase(peer_id)
	_buffers.erase(peer_id)


func _process(delta: float) -> void:
	# Ease the interpolation delay toward the quality-driven target.
	_interp_delay = lerp(_interp_delay, _target_delay, clampf(delta * 2.0, 0.0, 1.0))
	# Render each peer at (now - delay), interpolating between the two buffered
	# snapshots that bracket that render time.
	var render_t := Time.get_ticks_msec() - int(_interp_delay)
	for peer_id in _peers.keys():
		var avatar: Node3D = _peers[peer_id]
		var buf: Array = _buffers.get(peer_id, [])
		if not is_instance_valid(avatar) or buf.is_empty():
			continue
		_prune(buf, render_t)
		_apply_interpolated(avatar, buf, render_t)


func _prune(buf: Array, render_t: int) -> void:
	# Drop snapshots older than what we still need to interpolate from.
	while buf.size() > 2 and int(buf[1]["t"]) < render_t - BUFFER_KEEP_MS:
		buf.remove_at(0)


func _apply_interpolated(avatar: Node3D, buf: Array, render_t: int) -> void:
	# Before the buffer starts: hold the oldest sample.
	if render_t <= int(buf[0]["t"]):
		avatar.position = buf[0]["pos"]
		avatar.rotation.y = float(buf[0]["yaw"])
		return
	# Find the pair [a,b] with a.t <= render_t <= b.t.
	for i in range(buf.size() - 1):
		var a: Dictionary = buf[i]
		var b: Dictionary = buf[i + 1]
		if int(a["t"]) <= render_t and render_t <= int(b["t"]):
			var span := float(int(b["t"]) - int(a["t"]))
			var f := 0.0 if span <= 0.0 else clampf((render_t - int(a["t"])) / span, 0.0, 1.0)
			avatar.position = (a["pos"] as Vector3).lerp(b["pos"], f)
			avatar.rotation.y = lerp_angle(float(a["yaw"]), float(b["yaw"]), f)
			return
	# Past the newest sample (starved buffer): hold the latest.
	var last: Dictionary = buf[buf.size() - 1]
	avatar.position = last["pos"]
	avatar.rotation.y = float(last["yaw"])


func _on_ghosts(_chapter_id: String, ghosts: Array) -> void:
	for c in _ghost_root.get_children():
		c.queue_free()
	for g in ghosts:
		var kind := String(g.get("kind", "trail"))
		if kind == "marker":
			_spawn_marker(g)
		else:
			_spawn_trail_walker(g)


func _spawn_trail_walker(g: Dictionary) -> void:
	var points: Array = g.get("points", [])
	if points.size() < 2:
		return
	var path: Array[Vector3] = []
	for p in points:
		if p is Array and p.size() >= 3:
			path.append(Vector3(float(p[0]), float(p[1]), float(p[2])))
	if path.size() < 2:
		return

	var body := _make_capsule(GHOST_COLOR)
	body.position = path[0]
	_ghost_root.add_child(body)

	# Floating name tag.
	var tag := Label3D.new()
	tag.text = String(g.get("display_name", "朝圣者"))
	tag.modulate = Color(0.8, 0.9, 1.0, 0.7)
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.2, 0)
	tag.pixel_size = 0.012
	body.add_child(tag)

	# Walk the path on a looping tween so the ghost retraces the route.
	var tw := create_tween()
	tw.set_loops()
	for i in range(1, path.size()):
		var dist := path[i - 1].distance_to(path[i])
		var dur: float = maxf(0.05, dist / WALK_SPEED)
		tw.tween_property(body, "position", path[i], dur)
	tw.tween_interval(1.5)
	tw.tween_property(body, "position", path[0], 0.01)


func _spawn_marker(g: Dictionary) -> void:
	var pts: Array = g.get("points", [])
	if pts.is_empty() or not (pts[0] is Array) or pts[0].size() < 3:
		return
	var pos := Vector3(float(pts[0][0]), float(pts[0][1]), float(pts[0][2]))
	var mote := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.25
	sphere.height = 0.5
	mote.mesh = sphere
	mote.material_override = _emissive(MARKER_COLOR)
	mote.position = pos + Vector3(0, 1.0, 0)
	_ghost_root.add_child(mote)

	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.9, 0.6)
	light.light_energy = 1.2
	light.omni_range = 4.0
	mote.add_child(light)

	# Gentle bob.
	var tw := create_tween()
	tw.set_loops()
	tw.tween_property(mote, "position:y", pos.y + 1.3, 1.4).set_trans(Tween.TRANS_SINE)
	tw.tween_property(mote, "position:y", pos.y + 0.9, 1.4).set_trans(Tween.TRANS_SINE)


func _make_capsule(color: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.35
	mesh.height = 1.7
	mi.mesh = mesh
	mi.material_override = _transparent(color)
	return mi


func _transparent(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 0.4
	return m


func _emissive(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = Color(color.r, color.g, color.b)
	m.emission_energy_multiplier = 2.0
	return m
