extends CharacterBody2D

## 平台移动控制器。
## 机制为独立实现；移动数值从 PlayerMovementConfig 资源读取，逻辑与数据分离。

@export var movement: PlayerMovementConfig = preload("res://resources/movement/player_default.tres")

var _facing := 1
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_jump_buffer_timer := 0.0  ## 蹬墙跳输入缓冲剩余时间。
var _wall_coyote_timer := 0.0  ## 墙土狼剩余时间：离墙后仍可蹬墙跳的窗口。
var _last_wall_dir := 0  ## 最近贴墙方向：1 为右侧有墙，-1 为左侧有墙。
var _input_lock_timer := 0.0
var _dash_grav_lock_timer := 0.0
var _dash_ctrl_lock_timer := 0.0
var _dash_input_silence_timer := 0.0
var _dash_active_timer := 0.0
var _dashes_left := 1

var _shake_amp := Vector2.ZERO
var _shake_dur := 0.0
var _shake_time := 0.0

@onready var _sprite: Sprite2D = $Sprite
@onready var _camera: Camera2D = $Camera2D


func _physics_process(delta: float) -> void:
	var cfg := movement
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor, cfg)
	_update_wall_contact(delta, on_floor, cfg)
	_update_shake(delta)

	var input_x := Input.get_axis("move_left", "move_right")
	if _input_lock_timer <= 0.0 and _dash_input_silence_timer <= 0.0 and input_x != 0.0:
		_facing = int(sign(input_x))

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = cfg.jump_buffer_time
		_wall_jump_buffer_timer = cfg.wall_jump_buffer_time

	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash(cfg)

	# R 键 / 右摇杆按下 → 重新载入场景
	if Input.is_action_just_pressed("restart"):
		get_tree().reload_current_scene()

	var grav_locked := _dash_grav_lock_timer > 0.0
	var ctrl_locked := _dash_ctrl_lock_timer > 0.0

	if not grav_locked:
		_process_gravity(delta, on_floor, cfg)
	if not ctrl_locked:
		var effective_input_x := 0.0 if _dash_input_silence_timer > 0.0 else input_x
		_process_horizontal(delta, on_floor, effective_input_x, cfg)
	if not grav_locked:
		_process_wall_slide(delta, input_x, cfg)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_do_ground_jump(cfg)
	elif _wall_jump_buffer_timer > 0.0:
		_do_wall_jump(input_x, cfg)

	if _dash_active_timer <= 0.0 and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y /= cfg.jump_cut_factor

	_corner_correct(delta, cfg)
	_corner_correct_horizontal(delta, cfg)

	move_and_slide()
	_update_visual()


func _update_timers(delta: float, on_floor: bool, cfg: PlayerMovementConfig) -> void:
	if on_floor:
		_coyote_timer = cfg.coyote_time
		_wall_coyote_timer = 0.0
		_last_wall_dir = 0
		if _dash_grav_lock_timer <= 0.0:
			_dashes_left = cfg.dash_count
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_wall_jump_buffer_timer = maxf(_wall_jump_buffer_timer - delta, 0.0)
	_input_lock_timer = maxf(_input_lock_timer - delta, 0.0)
	_dash_grav_lock_timer = maxf(_dash_grav_lock_timer - delta, 0.0)
	_dash_ctrl_lock_timer = maxf(_dash_ctrl_lock_timer - delta, 0.0)
	_dash_input_silence_timer = maxf(_dash_input_silence_timer - delta, 0.0)
	_dash_active_timer = maxf(_dash_active_timer - delta, 0.0)


func _update_wall_contact(delta: float, on_floor: bool, cfg: PlayerMovementConfig) -> void:
	## 跟踪贴墙状态：贴墙时刷新墙土狼；下落贴墙时续期蹬墙跳缓冲以支持链式连跳。
	if on_floor:
		return
	var wd := _wall_contact_dir()
	if wd != 0:
		_last_wall_dir = wd
		_wall_coyote_timer = cfg.wall_coyote_time
		if velocity.y > 0.0 and _wall_jump_buffer_timer > 0.0:
			_wall_jump_buffer_timer = cfg.wall_jump_buffer_time
	else:
		_wall_coyote_timer = maxf(_wall_coyote_timer - delta, 0.0)


func _process_gravity(delta: float, on_floor: bool, cfg: PlayerMovementConfig) -> void:
	if on_floor:
		return
	var g := cfg.rise_gravity if velocity.y < 0.0 else cfg.fall_gravity
	velocity.y = move_toward(velocity.y, cfg.max_fall_speed, g * delta)


func _process_horizontal(delta: float, on_floor: bool, input_x: float, cfg: PlayerMovementConfig) -> void:
	if _input_lock_timer > 0.0:
		return
	var target := 0.0
	var accel: float
	if input_x == 0.0:
		accel = cfg.ground_friction if on_floor else cfg.air_brake
	elif velocity.x != 0.0 and sign(input_x) != sign(velocity.x):
		accel = cfg.turn_decel if on_floor else cfg.air_turn_decel
	else:
		target = input_x * cfg.max_speed
		accel = cfg.ground_accel if on_floor else cfg.air_accel
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _process_wall_slide(delta: float, input_x: float, cfg: PlayerMovementConfig) -> void:
	if is_on_floor() or velocity.y <= 0.0:
		return
	var wd := _wall_contact_dir()
	if wd == 0:
		return
	if input_x != 0.0 and int(sign(input_x)) == wd:
		velocity.y = move_toward(velocity.y, cfg.wall_slide_max, cfg.wall_slide_gravity * delta)


func _wall_jump_side(cfg: PlayerMovementConfig) -> int:
	var wd := _wall_contact_dir()
	if wd != 0:
		return wd
	if _wall_coyote_timer > 0.0 and _last_wall_dir != 0:
		return _last_wall_dir
	return 0


func _wall_contact_dir() -> int:
	if not is_on_wall():
		return 0
	var nx := get_wall_normal().x
	if nx > 0.01:
		return -1
	if nx < -0.01:
		return 1
	return 0


func _do_ground_jump(cfg: PlayerMovementConfig) -> void:
	velocity.y = cfg.jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_buffer_timer = 0.0
	_wall_coyote_timer = 0.0


func _do_wall_jump(input_x: float, cfg: PlayerMovementConfig) -> bool:
	var wd := _wall_jump_side(cfg)
	if wd == 0:
		return false
	if absf(input_x) > 0.01:
		velocity.y = cfg.wall_jump_velocity
		velocity.x = -wd * cfg.wall_jump_push
	else:
		velocity.y = cfg.wall_jump_velocity_min
		velocity.x = -wd * cfg.wall_jump_push_min
	_input_lock_timer = cfg.wall_jump_input_lock
	_wall_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_buffer_timer = 0.0
	return true


func _can_dash() -> bool:
	return _dashes_left > 0


func _start_dash(cfg: PlayerMovementConfig) -> void:
	var dir := _dash_direction()
	var v := dir * cfg.dash_speed
	if dir.y < 0.0:
		v.y *= cfg.dash_up_scale
	velocity = v
	_dash_grav_lock_timer = cfg.dash_gravity_lock
	_dash_ctrl_lock_timer = cfg.dash_control_lock
	_dash_input_silence_timer = cfg.dash_input_silence
	_dash_active_timer = cfg.dash_active_time
	_dashes_left -= 1
	_start_shake(dir.abs() * cfg.dash_shake_amp, cfg.dash_shake_time)
	_do_hitstop(cfg)


func _do_hitstop(cfg: PlayerMovementConfig) -> void:
	if cfg.hitstop_time <= 0.0:
		return
	Engine.time_scale = 0.0
	await get_tree().create_timer(cfg.hitstop_time, true, false, true).timeout
	Engine.time_scale = 1.0


func _dash_direction() -> Vector2:
	var d := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if d == Vector2.ZERO:
		return Vector2(_facing, 0.0)
	var ang := snappedf(d.angle(), PI / 4.0)
	return Vector2.RIGHT.rotated(ang)


func _start_shake(amp: Vector2, dur: float) -> void:
	_shake_amp = amp
	_shake_dur = dur
	_shake_time = dur


func _update_shake(delta: float) -> void:
	if _shake_time > 0.0:
		_shake_time = maxf(_shake_time - delta, 0.0)
		var k := _shake_time / _shake_dur if _shake_dur > 0.0 else 0.0
		_camera.offset = Vector2(
			randf_range(-_shake_amp.x, _shake_amp.x) * k,
			randf_range(-_shake_amp.y, _shake_amp.y) * k
		)
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


func _corner_correct(delta: float, cfg: PlayerMovementConfig) -> void:
	if velocity.y >= 0.0:
		return
	var up_motion := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, up_motion):
		return
	for i in range(1, cfg.corner_correction_px + 1):
		for s in [-1, 1]:
			var shifted := global_transform.translated(Vector2(s * i, 0.0))
			if not test_move(shifted, up_motion):
				position.x += s * i
				return


func _corner_correct_horizontal(delta: float, cfg: PlayerMovementConfig) -> void:
	if velocity.x == 0.0:
		return
	if absf(velocity.y) > cfg.corner_h_max_vy:
		return
	var h_motion := Vector2(velocity.x * delta, 0.0)
	if not test_move(global_transform, h_motion):
		return
	for i in range(1, cfg.corner_correction_v_px + 1):
		for s in [-1, 1]:
			var shifted := global_transform.translated(Vector2(0.0, s * i))
			if not test_move(shifted, h_motion):
				position.y += s * i
				return


func _update_visual() -> void:
	if _facing != 0:
		_sprite.flip_h = _facing < 0
