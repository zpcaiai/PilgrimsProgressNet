extends Node
## Global game-feel ("juice"), autoloaded as `Juice`. Three primitives any
## system can call to make impacts read:
##   Juice.shake(0.6)                       # screen shake (trauma-based)
##   Juice.hitstop(0.08)                    # brief, real-time time-scale dip
##   Juice.flash(Color(1, 0.3, 0.3, 0.25))  # full-screen impact flash
##
## Shake is applied through the active Camera3D's h/v_offset (frustum shift), so
## it never fights the camera rig's own position. Hit-stop uses an
## ignore-time-scale timer so it always restores after real time.

const TRAUMA_DECAY := 1.7
const MAX_OFFSET := 0.16

var _trauma: float = 0.0
var _t: float = 0.0
var _hitstop_active := false
var _flash_rect: ColorRect


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS


func shake(amount: float = 0.5) -> void:
	if Settings.reduce_motion:
		return
	_trauma = clampf(_trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	_t += delta
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	if _trauma > 0.0:
		var s := _trauma * _trauma
		cam.h_offset = MAX_OFFSET * s * sin(_t * 47.0)
		cam.v_offset = MAX_OFFSET * s * sin(_t * 41.0 + 1.3)
		_trauma = maxf(0.0, _trauma - TRAUMA_DECAY * delta)
		if _trauma <= 0.001:
			cam.h_offset = 0.0
			cam.v_offset = 0.0


func hitstop(duration: float = 0.08, scale: float = 0.05) -> void:
	if _hitstop_active or Settings.reduce_motion:
		return
	_hitstop_active = true
	Engine.time_scale = scale
	# 4th arg (ignore_time_scale=true) -> fires after REAL `duration`.
	await get_tree().create_timer(duration, true, false, true).timeout
	Engine.time_scale = 1.0
	_hitstop_active = false


func flash(color: Color = Color(1, 1, 1, 0.25), duration: float = 0.25) -> void:
	if _flash_rect == null or not is_instance_valid(_flash_rect):
		var layer := CanvasLayer.new()
		layer.layer = 80
		add_child(layer)
		_flash_rect = ColorRect.new()
		_flash_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
		_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		layer.add_child(_flash_rect)
	_flash_rect.color = color
	var tw := create_tween()
	tw.tween_property(_flash_rect, "color:a", 0.0, duration).from(color.a)
