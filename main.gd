extends Node2D

const DIAMETER_RATIO := 0.82  # 룰렛 지름 = 화면 폭의 82%
const CENTER_Y_RATIO := 0.65  # 상단 1/3을 비워두려고 중심을 아래쪽에 둔다
const POINTER_WIDTH := 34.0
const POINTER_HEIGHT := 40.0
const POINTER_GAP := 8.0  # 룰렛 테두리와 포인터 끝 사이 간격
const POINTER_COLOR := Color("F2F0EA")

const TOP_DEAD_ZONE_RATIO := 1.0 / 3.0  # 상단 1/3은 PIP 영상에 가려지는 영역이라 탭 판정에서 뺀다

@onready var _roulette: Roulette = $Roulette
@onready var _pointer: Polygon2D = $Pointer


func _ready() -> void:
	_layout()
	get_viewport().size_changed.connect(_layout)  # 기기 해상도가 달라도 같은 비율을 유지한다
	_roulette.spun.connect(_on_spun)


## 조준이 없는 게임이라 위치는 "상단 1/3인가 아닌가"만 보고 버린다
func _unhandled_input(event: InputEvent) -> void:
	var tap_position := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return
		tap_position = event.position
	elif event is InputEventMouseButton:
		if not event.pressed or event.button_index != MOUSE_BUTTON_LEFT:
			return
		tap_position = event.position
	else:
		return

	if tap_position.y < get_viewport_rect().size.y * TOP_DEAD_ZONE_RATIO:
		return

	_roulette.tap()
	get_viewport().set_input_as_handled()


func _on_spun(index: int, mineral: String, multiplier: int) -> void:
	# 3단계에서 캐럿 누적으로 바뀔 자리. 지금은 결과가 맞게 나오는지 눈으로 확인하는 용도다
	print("%d번 칸 · %s · x%d" % [index, mineral, multiplier])


func _layout() -> void:
	var screen := get_viewport_rect().size
	var radius := screen.x * DIAMETER_RATIO / 2.0
	_roulette.radius = radius
	_roulette.position = Vector2(screen.x / 2.0, screen.y * CENTER_Y_RATIO)
	# 포인터는 룰렛의 형제 노드다. 자식으로 넣으면 룰렛과 같이 돌아서 의미가 없어진다
	_pointer.position = _roulette.position + Vector2(0.0, -radius - POINTER_GAP)
	_pointer.polygon = PackedVector2Array([
		Vector2(-POINTER_WIDTH / 2.0, -POINTER_HEIGHT),
		Vector2(POINTER_WIDTH / 2.0, -POINTER_HEIGHT),
		Vector2(0.0, 0.0),
	])
	_pointer.color = POINTER_COLOR
