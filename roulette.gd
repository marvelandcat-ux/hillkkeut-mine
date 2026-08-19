class_name Roulette
extends Node2D

## 멈춘 결과를 알린다. 캐럿 누적·연출은 모두 이 시그널을 받아서 처리한다
signal spun(index: int, mineral: String, multiplier: int)

# 이웃 순서는 게임 규칙상 고정이다 — 순서가 바뀌면 유저가 눈에 익힌 판독이 깨진다
const MINERALS := [
	"다이아", "돌", "철", "돌", "철", "돌",
	"금", "돌", "철", "돌", "철", "돌",
]

# 임시 팔레트. 배수가 클수록 따뜻한 색이라는 온도 순서만 지키면 된다
const MINERAL_COLORS := {
	"돌": Color("888780"),
	"철": Color("1D9E75"),
	"금": Color("7F77DD"),
	"다이아": Color("EF9F27"),
}

const MULTIPLIERS := {
	"돌": 1,
	"철": 3,
	"금": 10,
	"다이아": 100,
}

const WEDGE_COUNT := 12
const WEDGE_ANGLE := TAU / WEDGE_COUNT  # 한 칸이 차지하는 각도(30도)
const ARC_SEGMENTS := 8  # 부채꼴 호를 나누는 조각 수. 클수록 원이 매끄럽다
const SPIN_SPEED := TAU / 2.0  # 상시 회전 속도(초당 180도)
const UP_ANGLE := -PI / 2.0  # 12시 방향. Godot는 y축이 아래로 향해서 위쪽이 -90도다

const SLOW_DOWN_TIME := 3.0  # 첫 탭 후 멈추기까지 걸리는 시간
const SKIP_SPEED_SCALE := 6.0  # 두 번째 탭의 빨리감기 배속 (3초 → 0.5초)
const MIN_EXTRA_TURNS := 2  # 목표 칸에 도달하기 전 최소로 더 도는 바퀴 수

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

var _wedges: Array[Polygon2D] = []  # 인덱스 0~11로 칸에 바로 접근하려고 배열로 들고 있는다
var _state := State.SPINNING
var _result_index := -1  # 첫 탭에서 확정된 결과. 연출이 끝날 때까지 이 값은 변하지 않는다
var _slow_down_tween: Tween = null
var _skipped := false  # 빨리감기는 한 번만 먹힌다


func _ready() -> void:
	_build_wedges()


func _process(delta: float) -> void:
	if _state == State.SPINNING:
		rotation += SPIN_SPEED * delta


## 화면 어디를 눌렀든 이 함수 하나로 들어온다. 조준이 없는 게임이라 위치를 받지 않는다
func tap() -> void:
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

	var mineral: String = MINERALS[_result_index]
	spun.emit(_result_index, mineral, MULTIPLIERS[mineral])


func _start_spin() -> void:
	_state = State.SPINNING
	_result_index = -1


## index번 칸의 중심이 12시 포인터에 오는 회전각.
## 그 조건을 만족하는 각도는 2π 간격으로 무한히 많아서, 최소 2바퀴 뒤의 것을 고른다
func _target_rotation(index: int) -> float:
	var aligned := -index * WEDGE_ANGLE
	var earliest := rotation + TAU * MIN_EXTRA_TURNS
	return aligned + ceil((earliest - aligned) / TAU) * TAU


## 12칸을 각각 독립 노드로 만든다. 칸마다 색을 따로 바꿔야 해서 통짜 이미지를 쓰지 않는다
func _build_wedges() -> void:
	for wedge in _wedges:
		wedge.queue_free()
	_wedges.clear()
	for index in WEDGE_COUNT:
		var wedge := Polygon2D.new()
		wedge.name = "Wedge%02d" % index
		wedge.polygon = _wedge_points(index)
		wedge.color = MINERAL_COLORS[MINERALS[index]]
		add_child(wedge)
		_wedges.append(wedge)


## index번 칸의 부채꼴 꼭짓점. 0번 칸의 중심이 12시를 향하도록 배치한다
func _wedge_points(index: int) -> PackedVector2Array:
	var start_angle := UP_ANGLE + index * WEDGE_ANGLE - WEDGE_ANGLE / 2.0
	var points := PackedVector2Array([Vector2.ZERO])
	for step in ARC_SEGMENTS + 1:
		var angle := start_angle + WEDGE_ANGLE * (float(step) / ARC_SEGMENTS)
		points.append(Vector2.from_angle(angle) * radius)
	return points


## 밖에서 칸 색을 바꾸기 위한 창구 (강화 표시·팔레트 교체에서 쓴다)
func set_wedge_color(index: int, color: Color) -> void:
	if index < 0 or index >= _wedges.size():
		push_warning("칸 인덱스가 범위를 벗어났다: %d" % index)
		return
	_wedges[index].color = color


## 칸 노드 자체가 필요할 때 쓴다 (맥동 연출 등)
func get_wedge(index: int) -> Polygon2D:
	if index < 0 or index >= _wedges.size():
		return null
	return _wedges[index]
