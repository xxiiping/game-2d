extends AudioStreamPlayer

## 循环播放两个 BGM 曲目。

@export var track_1: AudioStream
@export var track_2: AudioStream

var _playing_first := true


func _ready() -> void:
	stream = track_1
	play()
	finished.connect(_next)


func _next() -> void:
	_playing_first = not _playing_first
	stream = track_1 if _playing_first else track_2
	play()
