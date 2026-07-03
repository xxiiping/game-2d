class_name PlayerMovementConfig
extends Resource

## 玩家移动数值配置：与 player.gd 逻辑分离，调手感只改 .tres 权威数据。
## 本脚本定义字段与出厂默认值；新建 Resource 时从此处填充。
## 单位：速度 px/s，加速度 px/s²，时间 秒，距离 px。

# --- 水平移动 ---
@export_group("Horizontal")
## 地面/空中同向加速的目标最大水平速度（px/s）。
@export var max_speed := 180.0
## 地面同向加速率（px/s²）。
@export var ground_accel := 1800.0
## 地面无输入时水平减速，拉向 0（px/s²）。
@export var ground_friction := 2448.0
## 地面反向输入时急刹到 0（px/s²）。
@export var turn_decel := 3960.0
## 空中同向加速率（px/s²）。
@export var air_accel := 756.0
## 空中无输入时水平减速，拉向 0（px/s²）。
@export var air_brake := 1440.0
## 空中反向输入时急刹到 0，非拉向反向目标（px/s²）。
@export var air_turn_decel := 1980.0

# --- 跳跃与重力（平地跳；与 Wall 组蹬墙跳参数独立）---
@export_group("Jump / Gravity")
## 平地跳/土狼跳起跳瞬时竖直速度；负值表示向上（px/s）。
@export var jump_velocity := -384.0
## 上升阶段重力加速度（px/s²）。
@export var rise_gravity := 1267.2
## 下落阶段重力加速度（px/s²）。
@export var fall_gravity := 1267.2
## 最大下落速度上限（px/s）。
@export var max_fall_speed := 720.0
## 松跳跃键时 velocity.y 除以该值，实现短跳。
@export var jump_cut_factor := 2.0

# --- 容错计时 ---
@export_group("Assist")
## 离地后仍可平地跳的窗口（秒）；@60fps 约 6 帧。
@export var coyote_time := 0.1
## 平地跳输入缓冲：提前按跳，落地或土狼窗内自动起跳（秒）。
@export var jump_buffer_time := 0.1
## 蹬墙跳专用输入缓冲（秒）；与 jump_buffer_time 独立。
@export var wall_jump_buffer_time := 0.1

# --- 墙体（蹬墙跳/墙滑；与 Jump / Gravity 组平地跳参数独立）---
@export_group("Wall")
## 墙滑时竖直下落速度上限（px/s）。
@export var wall_slide_max := 168.0
## 贴墙下滑时的下落加速度（px/s²）。
@export var wall_slide_gravity := 480.0
## 蹬墙跳竖直起跳速度，有水平输入时（px/s）。
@export var wall_jump_velocity := -370.0
## 蹬墙跳水平推力，有水平输入时；与竖直分量共同决定起跳角度（px/s）。
@export var wall_jump_push := 310.0
## 蹬墙跳竖直起跳速度，无水平输入时的小跳（px/s）。
@export var wall_jump_velocity_min := -250.0
## 蹬墙跳水平推力，无水平输入时（px/s）。
@export var wall_jump_push_min := 210.0
## 蹬墙跳后水平输入锁定时间，保护飞出动量（秒）。
@export var wall_jump_input_lock := 0.1
## 墙土狼：须先贴墙接触，离墙后仍可蹬墙跳（秒）；@60fps 约 12 帧。
@export var wall_coyote_time := 0.2

# --- 冲刺 ---
@export_group("Dash")
## 冲刺初速度模长，八向（px/s）。
@export var dash_speed := 456.0
## 向上冲刺时竖直分量缩放。
@export var dash_up_scale := 0.75
## 冲刺后跳过重力与墙滑的重力锁定期（秒）。
@export var dash_gravity_lock := 0.15
## 冲刺后水平速度冻结时长（秒）。
@export var dash_control_lock := 0.075
## 水平解锁后仍无视左右输入、走摩擦归零的静默窗（秒）。
@export var dash_input_silence := 0.15
## 冲刺手感窗：期内禁用跳跃截断，保留纵向动量（秒）。
@export var dash_active_time := 0.57
## 空中可用冲刺次数；落地补满。
@export var dash_count := 1
## 冲刺触发时全局 time_scale=0 的定格时长（秒）。
@export var hitstop_time := 0.03
## 冲刺相机震动幅度，沿冲刺方向（px）。
@export var dash_shake_amp := 2.0
## 相机震动衰减时长（秒）。
@export var dash_shake_time := 0.15

# --- 转角修正 ---
@export_group("Corner")
## 上升顶头被挡时，左右微移尝试滑过棱角的距离（px）。
@export var corner_correction_px := 8
## 水平移动被挡时，上下微移尝试滑过的距离（px）。
@export var corner_correction_v_px := 10
## 水平转角修正仅在 |vy| 低于此值时生效（px/s）。
@export var corner_h_max_vy := 12.0
