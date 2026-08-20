class_name Roulette
extends Node2D

## 멈춘 결과를 알린다. 캐럿 누적·연출은 모두 이 시그널을 받아서 처리한다
signal spun(index: int, mineral: String, multiplier: int)

const WEDGE_COUNT := Minerals.COUNT
const WEDGE_ANGLE := TAU / WEDGE_COUNT  # 한 칸이 차지하는 각도(30도)
const ARC_SEGMENTS := 8  # 부채꼴 호를 나누는 조각 수. 클수록 원이 매끄럽다
const WEDGE_RIM_RATIO := 0.95  # 파편이 튀어나오는 지점. 안쪽에서 튀면 같은 색 룰렛에 묻혀 안 보인다
const SPIN_SPEED := TAU / 2.0  # 상시 회전 속도(초당 180도)
const UP_ANGLE := -PI / 2.0  # 12시 방향. Godot는 y축이 아래로 향해서 위쪽이 -90도다

const SLOW_DOWN_TIME := 3.0  # 첫 탭 후 멈추기까지 걸리는 시간
const SKIP_SPEED_SCALE := 6.0  # 두 번째 탭의 빨리감기 배속 (3초 → 0.5초)
const MIN_EXTRA_TURNS := 2  # 목표 칸에 도달하기 전 최소로 더 도는 바퀴 수

# 칸에 적히는 배수 숫자
const NUMBER_SIZE_RATIO := 0.11  # 반지름 대비 글자 크기
const NUMBER_RADIUS_RATIO := 0.63  # 숫자를 놓을 위치 (중심에서 얼마나 바깥인지)
const NUMBER_COLOR := Color("14140F")

# 강화할 수 있는 칸은 천천히 맥동한다. 빠르게 깜빡이면 영상 시청에 방해된다
const PULSE_PERIOD := 2.0
const PULSE_PEAK := Color(1.35, 1.35, 1.35)

# 룰렛 교체 연출. 흰색 플래시는 쓰지 않는다 — 어두운 방에서 보는 유저가 대부분이다
const DOMINO_STEP_DELAY := 0.03  # 12칸 × 0.03 = 0.36초
const FLIP_TIME := 0.5

enum State {
	SPINNING,  # 상시 회전 중
	SLOWING,  # 결과가 정해졌고 그 칸으로 감속하는 중
	STOPPED,  # 멈춰서 다음 탭을 기다리는 중
}

## 룰렛 반지름. 화면 크기에 맞춰 밖에서 넣어주면 칸을 다시 만든다
@export var radius: float = 100.0:
	set(value):
		radius = value
		if is_node_ready():
			_build_wedges()

## 상점에 띄우는 룰렛은 돌지 않는다 (게임용 룰렛과 같은 노드를 그대로 쓰기 위한 스위치)
@export var idle_spin: bool = true

var _wedges: Array[Polygon2D] = []  # 인덱스 0~11로 칸에 바로 접근하려고 배열로 들고 있는다
var _numbers: Array[Label] = []
var _state := State.SPINNING
var _result_index := -1  # 첫 탭에서 확정된 결과. 연출이 끝날 때까지 이 값은 변하지 않는다
var _slow_down_tween: Tween = null
var _skipped := false  # 빨리감기는 한 번만 먹힌다
var _upgrades: Upgrades = null
var _pulsing: Array = []  # 지금 강화할 수 있어서 맥동시킬 광물들
var _pulse_time := 0.0
var _palette_step := 0
var _transition_tween: Tween = null
var _transition_count := 0
var _flip_target := 1.0  # 뒤집힘 연출이 끝나야 할 scale.x. 스킵할 때 여기로 맞춘다


func _ready() -> void:
	_build_wedges()


func _process(delta: float) -> void:
	# 연출 중에는 회전을 멈춘다. 그 정적 자체가 "뭔가 온다"는 신호다
	if idle_spin and _state == State.SPINNING and not is_transitioning():
		rotation += SPIN_SPEED * delta

	# 숫자는 룰렛과 같이 돌지 않고 항상 똑바로 선다. 바퀴처럼 눕히면 아래쪽 칸이 거꾸로 읽힌다.
	# 뒤집힘 연출 뒤에는 룰렛이 거울반전 상태로 남는데, 그러면 회전도 반대로 보여서
	# 상쇄하려면 부호를 같이 뒤집어야 한다. 안 그러면 글자가 두 배로 돌아간다
	var mirrored := scale.x < 0.0
	for number in _numbers:
		number.rotation = rotation if mirrored else -rotation
		number.scale.x = -1.0 if mirrored else 1.0

	_animate_pulse(delta)


## 강화 상태를 물려준다. 룰렛이 두 개라 배수는 바깥에서 공유한다
func bind_upgrades(upgrades: Upgrades) -> void:
	_upgrades = upgrades
	_upgrades.changed.connect(_refresh_numbers)
	_refresh_numbers()


## 화면 어디를 눌렀든 이 함수 하나로 들어온다. 조준이 없는 게임이라 위치를 받지 않는다
func tap() -> void:
	# 연출 중 탭은 스킵이다 (감속 스킵과 같은 문법)
	if is_transitioning():
		_skip_transition()
		return

	match _state:
		State.SPINNING:
			_start_slow_down()
		State.SLOWING:
			_skip_slow_down()
		State.STOPPED:
			_start_spin()


## ★결과는 여기서 확정된다★
## 감속은 이미 정해진 칸으로 가는 연출일 뿐이라, 이후 어떤 탭도 결과를 바꾸지 못한다
func _start_slow_down() -> void:
	_result_index = randi() % WEDGE_COUNT
	_state = State.SLOWING
	_skipped = false

	_slow_down_tween = create_tween()
	_slow_down_tween.tween_property(self, "rotation", _target_rotation(_result_index), SLOW_DOWN_TIME) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_slow_down_tween.finished.connect(_on_slow_down_finished)


## 즉시 정지가 아니라 남은 연출을 빨리 감는다. 도착지가 그대로라 결과도 그대로다
func _skip_slow_down() -> void:
	if _skipped or _slow_down_tween == null:
		return
	_skipped = true
	_slow_down_tween.set_speed_scale(SKIP_SPEED_SCALE)


func _on_slow_down_finished() -> void:
	_state = State.STOPPED
	_slow_down_tween = null
	rotation = fposmod(rotation, TAU)  # 각도가 무한정 커지면 정밀도가 떨어져서 한 바퀴 안으로 접는다

	# 결과 없이 이 함수가 불릴 일은 없어야 한다. 그래도 들어오면 조용히 나간다 —
	# GDScript는 음수 인덱스를 뒤에서부터 세기 때문에 엉뚱한 광물이 나가버린다
	if _result_index < 0:
		push_warning("결과 없이 감속이 끝났다")
		return

	var mineral: String = Minerals.ORDER[_result_index]
	spun.emit(_result_index, mineral, multiplier_of(mineral))


func _start_spin() -> void:
	# 감속 트윈이 남아 있는 채로 다시 돌기 시작하면, 그 트윈이 나중에 끝나면서
	# 결과 없는 상태로 결과를 쏘게 된다. 먼저 끊는다
	if _slow_down_tween != null and _slow_down_tween.is_valid():
		_slow_down_tween.kill()
	_slow_down_tween = null
	_state = State.SPINNING
	_result_index = -1


## index번 칸의 중심이 12시 포인터에 오는 회전각.
## 그 조건을 만족하는 각도는 2π 간격으로 무한히 많아서, 최소 2바퀴 뒤의 것을 고른다
func _target_rotation(index: int) -> float:
	var aligned := -index * WEDGE_ANGLE
	var earliest := rotation + TAU * MIN_EXTRA_TURNS
	return aligned + ceil((earliest - aligned) / TAU) * TAU


func multiplier_of(mineral: String) -> int:
	if _upgrades == null:
		return Minerals.BASE_MULTIPLIERS[mineral]
	return _upgrades.multiplier(mineral)


## 12칸을 각각 독립 노드로 만든다. 칸마다 색을 따로 바꿔야 해서 통짜 이미지를 쓰지 않는다
func _build_wedges() -> void:
	for wedge in _wedges:
		wedge.queue_free()
	for number in _numbers:
		number.queue_free()
	_wedges.clear()
	_numbers.clear()

	for index in WEDGE_COUNT:
		var mineral: String = Minerals.ORDER[index]
		var wedge := Polygon2D.new()
		wedge.name = "Wedge%02d" % index
		wedge.polygon = _wedge_points(index)
		wedge.color = Minerals.color(mineral, _palette_step)
		add_child(wedge)
		_wedges.append(wedge)
		_numbers.append(_make_number(index))

	_refresh_numbers()


## index번 칸의 부채꼴 꼭짓점. 0번 칸의 중심이 12시를 향하도록 배치한다
func _wedge_points(index: int) -> PackedVector2Array:
	var start_angle := UP_ANGLE + index * WEDGE_ANGLE - WEDGE_ANGLE / 2.0
	var points := PackedVector2Array([Vector2.ZERO])
	for step in ARC_SEGMENTS + 1:
		var angle := start_angle + WEDGE_ANGLE * (float(step) / ARC_SEGMENTS)
		points.append(Vector2.from_angle(angle) * radius)
	return points


## 칸에 적히는 배수 숫자. 위치만 룰렛을 따라 돌고 글자는 항상 똑바로 선다
func _make_number(index: int) -> Label:
	var font_size := maxf(radius * NUMBER_SIZE_RATIO, 8.0)
	var label := Label.new()
	KoreanFont.apply(label, int(font_size), NUMBER_COLOR)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 칸 판정은 각도로 하므로 라벨은 입력을 안 먹는다

	var angle := UP_ANGLE + index * WEDGE_ANGLE
	label.size = Vector2(font_size * 3.4, font_size * 1.5)
	label.pivot_offset = label.size / 2.0
	label.position = Vector2.from_angle(angle) * radius * NUMBER_RADIUS_RATIO - label.size / 2.0
	label.rotation = -rotation
	add_child(label)
	return label


func _refresh_numbers() -> void:
	for index in _numbers.size():
		_numbers[index].text = "×%d" % multiplier_of(Minerals.ORDER[index])


## 강화할 수 있게 된 광물들. 여기 담긴 칸만 맥동한다 (뱃지·팝업 대신 쓰는 유일한 신호)
func set_pulsing(minerals: Array) -> void:
	_pulsing = minerals
	if _pulsing.is_empty():
		_pulse_time = 0.0
		for wedge in _wedges:
			wedge.self_modulate = Color.WHITE


func _animate_pulse(delta: float) -> void:
	if _pulsing.is_empty():
		return
	_pulse_time = fmod(_pulse_time + delta, PULSE_PERIOD)
	var wave := 0.5 - 0.5 * cos(TAU * _pulse_time / PULSE_PERIOD)
	for index in _wedges.size():
		var lit: bool = Minerals.ORDER[index] in _pulsing
		_wedges[index].self_modulate = Color.WHITE.lerp(PULSE_PEAK, wave) if lit else Color.WHITE


func is_transitioning() -> bool:
	return _transition_tween != null and _transition_tween.is_valid()


## 표시 단위가 바뀔 때 룰렛을 통째로 교체한다. 연출 2종을 번갈아 재생한다
func play_transition(step: int) -> void:
	if is_transitioning():
		_skip_transition()
	_palette_step = step
	_transition_count += 1
	if _transition_count % 2 == 1:
		_play_domino()
	else:
		_play_flip()


## 연출 없이 바로 새 색으로. 상점에 띄운 룰렛이 쓴다
func set_palette(step: int) -> void:
	_palette_step = step
	_paint_all()


## 도미노 — 12칸이 한 칸씩 물든다. 회전 방향(인덱스가 커지는 쪽)과 같은 순서다
func _play_domino() -> void:
	_flip_target = scale.x
	_transition_tween = create_tween()
	for index in WEDGE_COUNT:
		_transition_tween.tween_callback(_paint_wedge.bind(index))
		_transition_tween.tween_interval(DOMINO_STEP_DELAY)


## 뒤집힘 — Y축으로 180도. 폭이 0이 되는 가운데에서 색을 바꿔야 교체 순간이 안 보인다
func _play_flip() -> void:
	_flip_target = -1.0 if scale.x > 0.0 else 1.0
	_transition_tween = create_tween()
	_transition_tween.tween_property(self, "scale:x", 0.0, FLIP_TIME / 2.0)
	_transition_tween.tween_callback(_paint_all)
	_transition_tween.tween_property(self, "scale:x", _flip_target, FLIP_TIME / 2.0)


func _skip_transition() -> void:
	_transition_tween.kill()
	_transition_tween = null
	_paint_all()
	scale.x = _flip_target


func _paint_wedge(index: int) -> void:
	_wedges[index].color = Minerals.color(Minerals.ORDER[index], _palette_step)


func _paint_all() -> void:
	for index in _wedges.size():
		_paint_wedge(index)


## 밖에서 칸 색을 바꾸기 위한 창구
func set_wedge_color(index: int, color: Color) -> void:
	if index < 0 or index >= _wedges.size():
		push_warning("칸 인덱스가 범위를 벗어났다: %d" % index)
		return
	_wedges[index].color = color


## 칸 노드 자체가 필요할 때 쓴다
func get_wedge(index: int) -> Polygon2D:
	if index < 0 or index >= _wedges.size():
		return null
	return _wedges[index]


## index번 칸의 바깥 테두리 좌표. 회전까지 반영되므로 멈춘 칸이면 포인터 아래가 나온다
func get_wedge_rim_global(index: int) -> Vector2:
	var angle := UP_ANGLE + index * WEDGE_ANGLE
	return to_global(Vector2.from_angle(angle) * radius * WEDGE_RIM_RATIO)


## 화면 좌표가 몇 번 칸인지. 룰렛 바깥이면 -1.
## to_local이 회전을 이미 반영해서 돌아가는 중에도 맞는다
func wedge_at_global(point: Vector2) -> int:
	var local := to_local(point)
	if local.length() > radius:
		return -1
	var angle := fposmod(local.angle() - UP_ANGLE + WEDGE_ANGLE / 2.0, TAU)
	return int(angle / WEDGE_ANGLE) % WEDGE_COUNT
