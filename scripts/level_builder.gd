@tool
extends TileMapLayer

## 用占位 TileSet 在运行/编辑时拼出一个测试关卡。
## 仅用于验证移动手感（地面、边界墙、平台、蹬墙跳用的立柱）。

const SOURCE_ID := 0
const ATLAS := Vector2i(0, 0)

func _ready() -> void:
	_build()

func _build() -> void:
	clear()
	# 地面（两行厚）
	for x in range(-4, 34):
		set_cell(Vector2i(x, 10), SOURCE_ID, ATLAS)
		set_cell(Vector2i(x, 11), SOURCE_ID, ATLAS)
	# 左右边界墙
	for y in range(0, 10):
		set_cell(Vector2i(-4, y), SOURCE_ID, ATLAS)
		set_cell(Vector2i(33, y), SOURCE_ID, ATLAS)
	# 低平台
	for x in range(6, 11):
		set_cell(Vector2i(x, 7), SOURCE_ID, ATLAS)
	# 高平台
	for x in range(14, 18):
		set_cell(Vector2i(x, 4), SOURCE_ID, ATLAS)
	# 蹬墙跳立柱
	for y in range(4, 10):
		set_cell(Vector2i(22, y), SOURCE_ID, ATLAS)
	for y in range(2, 8):
		set_cell(Vector2i(27, y), SOURCE_ID, ATLAS)
