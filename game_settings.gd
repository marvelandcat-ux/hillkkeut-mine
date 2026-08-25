extends Node

## 게임 설정 저장소 (autoload).
## 볼륨은 오디오 버스(BGM/SFX)에 바로 적용된다 — 나중에 소리를 넣을 때
## AudioStreamPlayer의 bus를 "BGM"/"SFX"로 지정하기만 하면 슬라이더가 그대로 먹는다.
## 진동 설정만 user://settings.cfg에 저장된다.
## 볼륨은 저장하지 않는다 — 게임을 켤 때마다 배경음악·소리 모두 50%에서 시작한다.

const SAVE_PATH := "user://settings.cfg"
const MUTE_THRESHOLD := 0.001  # 이 밑이면 사실상 0으로 보고 버스를 뮤트한다
const MIN_VOLUME_DB := -40.0  # 슬라이더 맨 아래(0 직전)에서의 크기. 여기서 더 내리면 뮤트다
const START_VOLUME := 0.5  # 시작 볼륨 50%

var bgm_volume := START_VOLUME  # 0.0 ~ 1.0
var sfx_volume := START_VOLUME  # 0.0 ~ 1.0
var vibration_on := true


func _ready() -> void:
	_ensure_bus("BGM")
	_ensure_bus("SFX")
	_load()
	_apply_bus("BGM", bgm_volume)
	_apply_bus("SFX", sfx_volume)


func set_bgm_volume(value: float) -> void:
	bgm_volume = clampf(value, 0.0, 1.0)
	_apply_bus("BGM", bgm_volume)
	_save()


func set_sfx_volume(value: float) -> void:
	sfx_volume = clampf(value, 0.0, 1.0)
	_apply_bus("SFX", sfx_volume)
	_save()


func set_vibration(on: bool) -> void:
	vibration_on = on
	_save()


## 진동은 전부 이 함수를 거친다. 설정이 꺼져 있으면 조용히 무시한다.
## 세기를 지정하지 않으면 폰 기본값(대개 약하다)을 써서 짧은 진동이 묻힌다 — 최대로 준다
func vibrate(ms: int) -> void:
	if vibration_on:
		Input.vibrate_handheld(ms, 1.0)


func _ensure_bus(bus_name: String) -> void:
	if AudioServer.get_bus_index(bus_name) != -1:
		return
	var index := AudioServer.bus_count
	AudioServer.add_bus(index)
	AudioServer.set_bus_name(index, bus_name)
	AudioServer.set_bus_send(index, "Master")


## 슬라이더 위치를 데시벨에 그대로 대응시킨다.
## linear_to_db를 쓰면 50%가 -6dB밖에 안 되어서, 위쪽 절반을 움직여도
## 귀에는 그대로 들린다 — "조절이 아예 안 된다"고 느껴지는 이유다
func _apply_bus(bus_name: String, volume: float) -> void:
	var index := AudioServer.get_bus_index(bus_name)
	if index == -1:
		return  # 버스가 없으면 조용히 넘어간다. 여기서 -1을 넘기면 엔진이 오류를 뱉는다
	AudioServer.set_bus_mute(index, volume <= MUTE_THRESHOLD)
	AudioServer.set_bus_volume_db(index, lerpf(MIN_VOLUME_DB, 0.0, volume))


func _save() -> void:
	var config := ConfigFile.new()
	config.set_value("haptic", "vibration", vibration_on)
	config.save(SAVE_PATH)


func _load() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return  # 저장 파일이 없으면 기본값 그대로
	vibration_on = config.get_value("haptic", "vibration", true)
