extends CharacterBody2D

## Celeste 风格平台移动控制器（核心阶段）。
## 机制为独立实现，仅以 Celeste / 参考 demo 作为手感与数值参考。
## 所有数值以 px/s、px/s^2、秒为单位，便于按手感调参。

# --- 水平移动 ---
@export_group("Horizontal")
@export var max_speed := 90.0
@export var ground_accel := 900.0
@export var ground_friction := 1224.0
@export var turn_decel := 1980.0
@export var air_accel := 378.0
@export var air_brake := 720.0
## 空中反向时的急刹减速（拉向 0），对齐参考的空中掉头手感。
@export var air_turn_decel := 990.0

# --- 跳跃与重力 ---
@export_group("Jump / Gravity")
@export var jump_velocity := -192.0
@export var rise_gravity := 633.6
@export var fall_gravity := 633.6
@export var max_fall_speed := 360.0
@export var jump_cut_factor := 2.0

# --- 容错计时 ---
@export_group("Assist")
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1
@export var wall_jump_buffer_time := 0.05

# --- 墙体 ---
@export_group("Wall")
@export var wall_slide_max := 105.0
@export var wall_slide_gravity := 288.0
@export var wall_jump_velocity := -135.0
@export var wall_jump_push := 180.0
@export var wall_jump_velocity_min := -90.0
@export var wall_jump_push_min := 120.0
@export var wall_jump_input_lock := 0.1
@export var wall_check_dist := 3.0

# --- 冲刺 ---
@export_group("Dash")
@export var dash_speed := 228.0
@export var dash_up_scale := 0.75
## 冲刺分段锁定：重力锁定窗口内跳过重力，水平锁定窗口内冻结水平速度。
@export var dash_gravity_lock := 0.15
@export var dash_control_lock := 0.075
## 水平解锁后到该时刻前输入仍被静默（按摩擦拉回 0），对齐参考 deactive_input。
@export var dash_input_silence := 0.15
## 冲刺手感窗：该窗口内禁用跳跃截断，保留冲刺纵向动量。
@export var dash_active_time := 0.57
@export var dash_count := 1
## 冲刺命中定格（hitstop）：触发瞬间冻结整个游戏时间。
@export var hitstop_time := 0.03
## 冲刺屏幕震动（沿冲刺方向施加）。
@export var dash_shake_amp := 1.0
@export var dash_shake_time := 0.15

# --- 转角修正 ---
@export_group("Corner")
@export var corner_correction_px := 4
@export var corner_correction_v_px := 5
## 水平转角修正仅在接近顶点（纵向速度很小）时介入。
@export var corner_h_max_vy := 6.0

var _facing := 1
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _wall_jump_buffer_timer := 0.0
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
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)
	_update_shake(delta)

	var input_x := Input.get_axis("move_left", "move_right")
	if _input_lock_timer <= 0.0 and _dash_input_silence_timer <= 0.0 and input_x != 0.0:
		_facing = int(sign(input_x))

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
		_wall_jump_buffer_timer = wall_jump_buffer_time

	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()

	var grav_locked := _dash_grav_lock_timer > 0.0
	var ctrl_locked := _dash_ctrl_lock_timer > 0.0

	# 重力（冲刺重力锁期间跳过，保留冲刺动量）
	if not grav_locked:
		_process_gravity(delta, on_floor)
	# 水平（冲刺水平锁期间冻结；输入静默窗内把输入视为 0 走摩擦）
	if not ctrl_locked:
		var effective_input_x := 0.0 if _dash_input_silence_timer > 0.0 else input_x
		_process_horizontal(delta, on_floor, effective_input_x)
	# 墙滑（冲刺重力锁期间跳过）
	if not grav_locked:
		_process_wall_slide(delta, input_x)

	# 缓冲跳跃：优先地面/土狼跳，其次蹬墙跳（更短的独立缓冲窗口）
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		_do_ground_jump()
	elif _wall_jump_buffer_timer > 0.0:
		_do_wall_jump(input_x)

	# 跳跃截断（冲刺手感窗内禁用，避免削减冲刺纵向速度）
	if _dash_active_timer <= 0.0 and Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y /= jump_cut_factor

	_corner_correct(delta)
	_corner_correct_horizontal(delta)

	move_and_slide()
	_update_visual()


func _update_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = coyote_time
		if _dash_grav_lock_timer <= 0.0:
			_dashes_left = dash_count
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_wall_jump_buffer_timer = maxf(_wall_jump_buffer_timer - delta, 0.0)
	_input_lock_timer = maxf(_input_lock_timer - delta, 0.0)
	_dash_grav_lock_timer = maxf(_dash_grav_lock_timer - delta, 0.0)
	_dash_ctrl_lock_timer = maxf(_dash_ctrl_lock_timer - delta, 0.0)
	_dash_input_silence_timer = maxf(_dash_input_silence_timer - delta, 0.0)
	_dash_active_timer = maxf(_dash_active_timer - delta, 0.0)


func _process_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
		return
	var g := rise_gravity if velocity.y < 0.0 else fall_gravity
	velocity.y = move_toward(velocity.y, max_fall_speed, g * delta)


## 水平运动：镜像参考分支——同向加速、反向急刹（拉向 0）、无输入摩擦（拉向 0）。
func _process_horizontal(delta: float, on_floor: bool, input_x: float) -> void:
	if _input_lock_timer > 0.0:
		return
	var target := 0.0
	var accel: float
	if input_x == 0.0:
		accel = ground_friction if on_floor else air_brake
	elif velocity.x != 0.0 and sign(input_x) != sign(velocity.x):
		accel = turn_decel if on_floor else air_turn_decel
	else:
		target = input_x * max_speed
		accel = ground_accel if on_floor else air_accel
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _process_wall_slide(delta: float, input_x: float) -> void:
	if is_on_floor() or velocity.y <= 0.0:
		return
	var wd := _wall_dir()
	if wd != 0 and int(sign(input_x)) == wd:
		velocity.y = move_toward(velocity.y, wall_slide_max, wall_slide_gravity * delta)


## 地面/土狼跳：消耗普通跳跃缓冲。
func _do_ground_jump() -> void:
	velocity.y = jump_velocity
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	_wall_jump_buffer_timer = 0.0


## 蹬墙跳：消耗独立的蹬墙缓冲，仅在贴墙时生效。
func _do_wall_jump(input_x: float) -> bool:
	var wd := _wall_dir()
	if wd == 0:
		return false
	if absf(input_x) > 0.01:
		velocity.y = wall_jump_velocity
		velocity.x = -wd * wall_jump_push
	else:
		velocity.y = wall_jump_velocity_min
		velocity.x = -wd * wall_jump_push_min
	_input_lock_timer = wall_jump_input_lock
	_jump_buffer_timer = 0.0
	_wall_jump_buffer_timer = 0.0
	return true


## 冲刺可用：仅按剩余次数（落地补充），与参考一致，无人为冷却。
func _can_dash() -> bool:
	return _dashes_left > 0


func _start_dash() -> void:
	var dir := _dash_direction()
	var v := dir * dash_speed
	if dir.y < 0.0:
		v.y *= dash_up_scale
	velocity = v
	_dash_grav_lock_timer = dash_gravity_lock
	_dash_ctrl_lock_timer = dash_control_lock
	_dash_input_silence_timer = dash_input_silence
	_dash_active_timer = dash_active_time
	_dashes_left -= 1
	_start_shake(dir.abs() * dash_shake_amp, dash_shake_time)
	_do_hitstop()


## 命中定格：忽略时间缩放的计时器，确保 time_scale=0 时仍能恢复。
func _do_hitstop() -> void:
	if hitstop_time <= 0.0:
		return
	Engine.time_scale = 0.0
	await get_tree().create_timer(hitstop_time, true, false, true).timeout
	Engine.time_scale = 1.0


## 冲刺方向：把输入向量吸附到最近的 45°（八向）；无输入则取面向水平方向。
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


## 屏幕震动：随时间线性衰减，按各轴幅度随机写入相机 offset。
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


## 顶头转角修正：上升中头部被挡时，尝试左右微移让玩家滑过棱角。
func _corner_correct(delta: float) -> void:
	if velocity.y >= 0.0:
		return
	var up_motion := Vector2(0.0, velocity.y * delta)
	if not test_move(global_transform, up_motion):
		return
	for i in range(1, corner_correction_px + 1):
		for s in [-1, 1]:
			var shifted := global_transform.translated(Vector2(s * i, 0.0))
			if not test_move(shifted, up_motion):
				position.x += s * i
				return


## 水平转角修正：接近顶点（纵向速度很小）时若水平被棱角挡住，尝试上下微移滑过。
func _corner_correct_horizontal(delta: float) -> void:
	if velocity.x == 0.0:
		return
	if absf(velocity.y) > corner_h_max_vy:
		return
	var h_motion := Vector2(velocity.x * delta, 0.0)
	if not test_move(global_transform, h_motion):
		return
	for i in range(1, corner_correction_v_px + 1):
		for s in [-1, 1]:
			var shifted := global_transform.translated(Vector2(0.0, s * i))
			if not test_move(shifted, h_motion):
				position.y += s * i
				return


## 检测紧贴的墙：返回 1（右侧有墙）/ -1（左侧有墙）/ 0（无）。
func _wall_dir() -> int:
	if test_move(global_transform, Vector2(wall_check_dist, 0.0)):
		return 1
	if test_move(global_transform, Vector2(-wall_check_dist, 0.0)):
		return -1
	return 0


func _update_visual() -> void:
	if _facing != 0:
		_sprite.flip_h = _facing < 0
