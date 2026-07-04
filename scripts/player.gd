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

var frozen := false
var _dash_dir := Vector2.ZERO  ## 记录最后一次冲刺方向，用于过渡区域检测

@onready var _sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var _death_sprite: AnimatedSprite2D = $AnimatedSprite2D2
@onready var _camera: Camera2D = $Camera2D
@onready var _sfx_jump01: AudioStreamPlayer = $SFX_Jump01
@onready var _sfx_jump02: AudioStreamPlayer = $SFX_Jump02
@onready var _sfx_run01: AudioStreamPlayer = $SFX_Run01
@onready var _sfx_run02: AudioStreamPlayer = $SFX_Run02
@onready var _sfx_rush01: AudioStreamPlayer = $SFX_Rush01
@onready var _sfx_rush02: AudioStreamPlayer = $SFX_Rush02
@onready var _sfx_break: AudioStreamPlayer = $SFX_Break
@onready var _sfx_charge: AudioStreamPlayer = $SFX_Charge
@onready var _anchor_marker: AnimatedSprite2D = $AnchorMarker
@onready var _sfx_anchor: AudioStreamPlayer = $SFX_Anchor
@onready var _sfx_anchor_back: AudioStreamPlayer = $SFX_AnchorBack
@onready var _death_timer: Timer = $DeathTimer

var _run_step := 0
var _running := false
var _heavy_state := 0  ## 0=正常, 1=蓄力中, 2=重坠中
var _charge_timer := 0.0
var _heavy_fall_time := 0.0  ## 重坠已持续时长
var _heavy_cd := 0.0  ## 重坠冷却，退出后1s内不可再触发
var _fragile_tilemap: TileMapLayer = null
var _anchor_position := Vector2.ZERO
var _has_anchor := false
var _anchor_instance: AnimatedSprite2D = null
var _respawn_position := Vector2.ZERO


func _physics_process(delta: float) -> void:
	# 重坠蓄力即使在 frozen 时也要处理，否则卡死
	_update_heavy_fall(delta)
	if frozen:
		return
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

	# Q 键传送锚
	if Input.is_action_just_pressed("place"):
		_handle_recall()

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
	_update_animation(on_floor, input_x)
	_update_visual()
	_update_run_sfx(delta, input_x, on_floor)


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
	if _heavy_state == 2 and velocity.y > 0.0:
		g *= 5.0
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


func _wall_jump_side(_cfg: PlayerMovementConfig) -> int:
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
	_sfx_jump01.play()


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
	_sfx_jump02.play()
	return true


func _can_dash() -> bool:
	return _dashes_left > 0


func _start_dash(cfg: PlayerMovementConfig) -> void:
	var dir := _dash_direction()
	_dash_dir = dir  ## 记录冲刺方向，供过渡区域检测（纯向下= 仅 y>0 且 x≈0）
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
	# 交替冲刺音效
	if randi() % 2 == 0:
		_sfx_rush01.play()
	else:
		_sfx_rush02.play()


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
	## idle/dash 朝右。冲刺用 _dash_dir 判断方向，跑步不用翻转。
	if _sprite.animation == &"run_left" or _sprite.animation == &"run_right":
		_sprite.flip_h = false
	elif _sprite.animation == &"dash":
		_sprite.flip_h = _dash_dir.x < 0.0
	elif _sprite.animation == &"jump":
		_sprite.flip_h = _facing < 0
	elif _facing != 0:
		_sprite.flip_h = _facing > 0


func _update_run_sfx(_delta: float, input_x: float, on_floor: bool) -> void:
	## 按住移动键在地面 → 循环播放跑步音效；松键 → 停止。
	var moving := on_floor and absf(input_x) > 0.1 and not frozen and _dash_active_timer <= 0.0
	if moving:
		if not _running:
			_running = true
			_run_step += 1
		var s := _sfx_run01 if _run_step % 2 == 1 else _sfx_run02
		if not s.playing:
			s.play()
	elif not moving and _running:
		_running = false
		_sfx_run01.stop()
		_sfx_run02.stop()


func _update_animation(on_floor: bool, input_x: float) -> void:
	## 根据玩家状态切换动画。跳跃动画按竖直速度分帧。
	if frozen and _heavy_state != 1:
		return
	var target := &"idle"
	if _dash_active_timer > 0.0:
		target = &"dash"
	elif on_floor:
		if input_x > 0.1:
			target = &"run_right"
		elif input_x < -0.1:
			target = &"run_left"
	elif not on_floor:
		if _heavy_state == 2:
			target = &"down"
		else:
			var wd := _wall_contact_dir()
			if wd != 0 and velocity.y > 0.0:
				target = &"wall_slide"
			else:
				target = &"jump"
	if _sprite.sprite_frames.has_animation(target) and _sprite.animation != target:
		_sprite.play(target)
	elif not _sprite.sprite_frames.has_animation(target) and _sprite.animation != &"idle":
		_sprite.play(&"idle")

	# 跳跃动画按速度分帧：上升→顶点→下落
	if _sprite.animation == &"jump" and _sprite.sprite_frames.get_frame_count(&"jump") >= 5:
		_sprite.speed_scale = 0.0  # 手动控帧
		var vy := velocity.y
		if vy < -250:
			_sprite.frame = 0
		elif vy < -80:
			_sprite.frame = 1
		elif vy < 80:
			_sprite.frame = 2
		elif vy < 250:
			_sprite.frame = 3
		else:
			_sprite.frame = 4
	elif _sprite.animation != &"jump":
		_sprite.speed_scale = 1.0  # 其他动画恢复正常播放

func set_respawn(pos: Vector2) -> void:
	_respawn_position = pos


func respawn() -> void:
	global_position = _respawn_position
	_death_sprite.visible = true
	velocity = Vector2.ZERO
	_dash_active_timer = 0.0
	_dash_grav_lock_timer = 0.0
	_dash_ctrl_lock_timer = 0.0
	_heavy_state = 0
	frozen = false


func die() -> void:
	_heavy_state = 0
	frozen = true
	velocity = Vector2.ZERO
	_death_sprite.visible = false
	if _sprite.sprite_frames.has_animation(&"death"):
		_sprite.speed_scale = 1.0
		_sprite.stop()
		_sprite.play(&"death")
		var n := _sprite.sprite_frames.get_frame_count(&"death")
		var sp := _sprite.sprite_frames.get_animation_speed(&"death")
		var dur := n / maxf(sp, 0.01) + 0.1
		$DeathTimer.start(dur)
	else:
		$DeathTimer.start(1.0)


func freeze_for(duration: float) -> void:
	## 冻结玩家输入与物理，持续 duration 秒。
	frozen = true
	velocity = Vector2.ZERO
	await get_tree().create_timer(duration, false).timeout
	frozen = false


func is_dashing_downward() -> bool:
	## 供过渡区域检测：重坠状态中（C 键下砸）。
	return _heavy_state == 2


func _update_heavy_fall(delta: float) -> void:
	## 重坠蓄力+破瓦。frozen 时也要处理，所以独立于 _physics_process 主体。

	if _heavy_cd > 0.0:
		_heavy_cd -= delta

	if Input.is_action_pressed("heavy_fall"):
		match _heavy_state:
			0:  # 开始蓄力
				if _heavy_cd > 0.0:
					return
				_heavy_state = 1
				_charge_timer = 0.0
				frozen = true
				_sfx_charge.play()
				velocity = Vector2.ZERO
				# 播放蓄力动画
				if _sprite.sprite_frames.has_animation(&"down"):
					_sprite.play(&"down")
			1:  # 蓄力中
				_charge_timer += delta
				if _charge_timer >= 0.5:
					_heavy_state = 2
					_heavy_fall_time = 0.0
					frozen = false
					_set_break_collision(false)
			2:  # 重坠中
				_heavy_fall_time += delta
				_destroy_floor()
	else:
		if _heavy_state == 1:
			# 蓄力未满松手 → 取消
			_heavy_state = 0
			frozen = false
			_sfx_charge.stop()

	# 重坠中退出条件：按跳跃，或落地（需持续0.15s以上防误触发）
	if _heavy_state == 2:
		if Input.is_action_just_pressed("jump"):
			_heavy_state = 0
			_set_break_collision(true)
			_heavy_cd = 1.0
		elif is_on_floor() and _heavy_fall_time > 0.15:
			_heavy_state = 0
			_set_break_collision(true)
			_heavy_cd = 1.0


func _handle_recall() -> void:
	if not _has_anchor:
		_anchor_position = global_position
		_has_anchor = true
		_sfx_anchor.play()
		_anchor_instance = _anchor_marker.duplicate() as AnimatedSprite2D
		_anchor_instance.global_position = global_position
		_anchor_instance.visible = true
		_anchor_instance.z_index = 10
		get_tree().current_scene.add_child(_anchor_instance)
	else:
		global_position = _anchor_position
		velocity = Vector2.ZERO
		_has_anchor = false
		_sfx_anchor_back.play()
		if _anchor_instance:
			_anchor_instance.queue_free()
			_anchor_instance = null
		_dash_active_timer = 0.0
		_dash_grav_lock_timer = 0.0
		_dash_ctrl_lock_timer = 0.0


func _ready() -> void:
	_anchor_marker.visible = false
	_respawn_position = global_position
	_death_timer.timeout.connect(respawn)
	if SaveManager.continue_game:
		SaveManager.continue_game = false
		var data := SaveManager.load_save()
		if not data.is_empty():
			_respawn_position = Vector2(data.position.x, data.position.y)
			respawn()
		if data.has("collectibles"):
			SaveManager.collectible_count = data.collectibles
			SaveManager._update_ui()
	var tilemap = get_tree().current_scene.get_node("TileMap")
	if tilemap:
		_fragile_tilemap = tilemap.get_node_or_null("break") as TileMapLayer


func _destroy_floor() -> void:
	if not _fragile_tilemap:
		return
	var broke := false
	var foot_y := global_position.y + 20
	for offset_x in [-8, 0, 8]:
		var pos := Vector2(global_position.x + offset_x, foot_y)
		var tile_pos := _fragile_tilemap.local_to_map(_fragile_tilemap.to_local(pos))
		var source_id := _fragile_tilemap.get_cell_source_id(tile_pos)
		if source_id != -1:
			_fragile_tilemap.set_cell(tile_pos, -1, Vector2i.ZERO, -1)
			broke = true
	if broke:
		_sfx_break.play()


func _set_break_collision(enabled: bool) -> void:
	if _fragile_tilemap:
		_fragile_tilemap.collision_enabled = enabled
