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

# --- 跳跃与重力 ---
@export_group("Jump / Gravity")
@export var jump_velocity := -192.0
@export var rise_gravity := 640.0
@export var fall_gravity := 640.0
@export var max_fall_speed := 360.0
@export var jump_cut_factor := 2.0

# --- 容错计时 ---
@export_group("Assist")
@export var coyote_time := 0.1
@export var jump_buffer_time := 0.1

# --- 墙体 ---
@export_group("Wall")
@export var wall_slide_max := 105.0
@export var wall_slide_gravity := 360.0
@export var wall_jump_velocity := -135.0
@export var wall_jump_push := 180.0
@export var wall_jump_velocity_min := -90.0
@export var wall_jump_push_min := 120.0
@export var wall_jump_input_lock := 0.1
@export var wall_check_dist := 2.0

# --- 冲刺 ---
@export_group("Dash")
@export var dash_speed := 228.0
@export var dash_up_scale := 0.75
@export var dash_lock_time := 0.15
@export var dash_cooldown := 0.15
@export var dash_count := 1

# --- 转角修正 ---
@export_group("Corner")
@export var corner_correction_px := 4

var _facing := 1
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _input_lock_timer := 0.0
var _dash_cooldown_timer := 0.0
var _dash_timer := 0.0
var _dashes_left := 1
var _is_dashing := false
var _dash_velocity := Vector2.ZERO

@onready var _sprite: Sprite2D = $Sprite


func _physics_process(delta: float) -> void:
	var on_floor := is_on_floor()
	_update_timers(delta, on_floor)

	var input_x := Input.get_axis("move_left", "move_right")
	if _input_lock_timer <= 0.0 and input_x != 0.0:
		_facing = int(sign(input_x))

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time

	if Input.is_action_just_pressed("dash") and _can_dash():
		_start_dash()

	if _is_dashing:
		_process_dash(delta)
	else:
		_process_gravity(delta, on_floor)
		_process_horizontal(delta, on_floor, input_x)
		_process_wall_slide(delta, input_x)
		if _jump_buffer_timer > 0.0:
			_try_jump(input_x)
		if Input.is_action_just_released("jump") and velocity.y < 0.0:
			velocity.y /= jump_cut_factor
		_corner_correct(delta)

	move_and_slide()
	_update_visual()


func _update_timers(delta: float, on_floor: bool) -> void:
	if on_floor:
		_coyote_timer = coyote_time
		if not _is_dashing:
			_dashes_left = dash_count
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
	_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)
	_input_lock_timer = maxf(_input_lock_timer - delta, 0.0)
	_dash_cooldown_timer = maxf(_dash_cooldown_timer - delta, 0.0)


func _process_gravity(delta: float, on_floor: bool) -> void:
	if on_floor:
		return
	var g := rise_gravity if velocity.y < 0.0 else fall_gravity
	velocity.y = move_toward(velocity.y, max_fall_speed, g * delta)


func _process_horizontal(delta: float, on_floor: bool, input_x: float) -> void:
	if _input_lock_timer > 0.0:
		return
	var target := input_x * max_speed
	var accel: float
	if on_floor:
		if input_x == 0.0:
			accel = ground_friction
		elif velocity.x != 0.0 and sign(input_x) != sign(velocity.x):
			accel = turn_decel
		else:
			accel = ground_accel
	else:
		accel = air_brake if input_x == 0.0 else air_accel
	velocity.x = move_toward(velocity.x, target, accel * delta)


func _process_wall_slide(delta: float, input_x: float) -> void:
	if is_on_floor() or velocity.y <= 0.0:
		return
	var wd := _wall_dir()
	if wd != 0 and int(sign(input_x)) == wd:
		velocity.y = move_toward(velocity.y, wall_slide_max, wall_slide_gravity * delta)


func _try_jump(input_x: float) -> bool:
	if _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_coyote_timer = 0.0
		_jump_buffer_timer = 0.0
		return true
	var wd := _wall_dir()
	if wd != 0:
		if absf(input_x) > 0.01:
			velocity.y = wall_jump_velocity
			velocity.x = -wd * wall_jump_push
		else:
			velocity.y = wall_jump_velocity_min
			velocity.x = -wd * wall_jump_push_min
		_input_lock_timer = wall_jump_input_lock
		_jump_buffer_timer = 0.0
		return true
	return false


func _can_dash() -> bool:
	return _dashes_left > 0 and not _is_dashing and _dash_cooldown_timer <= 0.0


func _start_dash() -> void:
	var dir := _dash_direction()
	var v := dir * dash_speed
	if dir.y < 0.0:
		v.y *= dash_up_scale
	_dash_velocity = v
	velocity = v
	_is_dashing = true
	_dash_timer = dash_lock_time
	_dash_cooldown_timer = dash_lock_time + dash_cooldown
	_dashes_left -= 1


func _process_dash(delta: float) -> void:
	velocity = _dash_velocity
	_dash_timer -= delta
	if _dash_timer <= 0.0:
		_is_dashing = false


func _dash_direction() -> Vector2:
	var d := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	)
	if d == Vector2.ZERO:
		d = Vector2(_facing, 0.0)
	return d.normalized()


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
