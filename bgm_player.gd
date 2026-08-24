extends AudioStreamPlayer

## 배경음악 재생기.
## 시작할 때 3초에 걸쳐 서서히 커지고, 곡이 끝나기 3초 전부터 서서히 작아진 뒤
## 처음부터 다시 반복한다. 볼륨 조절은 BGM 버스(설정의 배경음악 슬라이더)가 맡는다.

const FADE_TIME := 3.0
const SILENT_DB := -40.0  # 사실상 무음으로 들리는 크기

var _fading_out := false
var _tween: Tween = null


func _ready() -> void:
	finished.connect(_start)
	_start()


func _start() -> void:
	_fading_out = false
	volume_db = SILENT_DB
	play()
	_fade_to(0.0)


func _process(_delta: float) -> void:
	if _fading_out or not playing:
		return
	# 끝나기 3초 전에 페이드아웃을 건다
	if get_playback_position() >= stream.get_length() - FADE_TIME:
		_fading_out = true
		_fade_to(SILENT_DB)


func _fade_to(target_db: float) -> void:
	if _tween != null and _tween.is_valid():
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(self, "volume_db", target_db, FADE_TIME)
