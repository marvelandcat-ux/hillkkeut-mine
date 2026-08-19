class_name Roulette
extends Node2D

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

const WEDGE_COUNT := 12
const WEDGE_ANGLE := TAU / WEDGE_COUNT  # 한 칸이 차지하는 각도(30도)
const ARC_SEGMENTS := 8  # 부채꼴 호를 나누는 조각 수. 클수록 원이 매끄럽다
const SPIN_SPEED := TAU / 2.0  # 상시 회전 속도(초당 180도)
const UP_ANGLE := -PI / 2.0  # 12시 방향. Godot는 y축이 아래로 향해서 위쪽이 -90도다

## 룰렛 반지름. 화면 크기에 맞춰 밖에서 넣어주면 칸을 다시 만든다
@export var radius: float = 100.0:
	set(value):
		radius = value
		if is_node_ready():
			_build_wedges()

var _wedges: Array[Polygon2D] = []  # 인덱스 0~11로 칸에 바로 접근하려고 배열로 들고 있는다


func _ready() -> void:
	_build_wedges()


func _process(delta: float) -> void:
	rotation += SPIN_SPEED * delta


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
