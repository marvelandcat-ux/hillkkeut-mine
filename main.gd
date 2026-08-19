extends Node2D

const DIAMETER_RATIO := 0.82  # 룰렛 지름 = 화면 폭의 82%
const CENTER_Y_RATIO := 0.65  # 상단 1/3을 비워두려고 중심을 아래쪽에 둔다
const POINTER_WIDTH := 34.0
const POINTER_HEIGHT := 40.0
const POINTER_GAP := 8.0  # 룰렛 테두리와 포인터 끝 사이 간격
const POINTER_COLOR := Color("F2F0EA")

const TOP_DEAD_ZONE_RATIO := 1.0 / 3.0  # 상단 1/3은 PIP 영상에 가려지는 영역이라 탭 판정에서 뺀다

# 기본 폰트에는 한글 글리프가 없어서 두부(□)로 나온다. OFL 폰트를 프로젝트에 넣어 쓴다
const CARAT_FONT := preload("res://fonts/noto_sans_kr.ttf")
const CARAT_FONT_SIZE := 62
const CARAT_FONT_WEIGHT := 600
const CARAT_FONT_COLOR := Color("F2F0EA")

# 평상시에도 화면을 살짝 덮어둔다. 이 여유분이 있어야 "밝아지는" 연출이 가능하다
const REST_DIM_ALPHA := 0.15
const DIM_IN_TIME := 0.06  # 밝아지는 건 빠르게 (결과가 나온 순간과 붙어야 한다)
const DIM_RECOVER_TIME := 0.30  # 되돌아오는 건 느리게
# 등급이 올라갈수록 더 밝아지고 더 오래 간다. 이게 안 보고도 읽는 첫 번째 단서다
const DIM_LEVELS := {
	"돌": {"alpha": 0.15, "hold": 0.0},
	"철": {"alpha": 0.10, "hold": 0.3},
	"금": {"alpha": 0.00, "hold": 0.3},
	"다이아": {"alpha": 0.00, "hold": 1.0},
}

@onready var _roulette: Roulette = $Roulette
@onready var _pointer: Polygon2D = $Pointer
@onready var _carat_label: Label = $UI/CaratLabel
@onready var _shards: Node2D = $Shards
@onready var _dim: ColorRect = $Dim/DimRect

var _carat := 0
var _dim_tween: Tween = null


func _ready() -> void:
	_setup_carat_label()
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
	_carat += multiplier
	_carat_label.text = CaratFormat.to_text(_carat)
	_flash_dim(mineral)

	var origin := _roulette.get_wedge_rim_global(index)
	# 색은 상수가 아니라 지금 칸에 칠해진 색을 쓴다 (팔레트가 바뀌어도 따라간다)
	var wedge := _roulette.get_wedge(index)
	_shards.burst(origin, mineral, _shard_reach(mineral, origin), wedge.color)


## ★시스템 밝기 API를 쓰지 않는다★
## 그걸 건드리면 위에 떠 있는 유튜브 PIP 영상까지 같이 어두워진다. 오버레이로만 한다
func _flash_dim(mineral: String) -> void:
	var level: Dictionary = DIM_LEVELS[mineral]
	var target: float = clampf(level["alpha"], 0.0, REST_DIM_ALPHA)  # 밝아지되 0 밑으로는 안 간다
	if is_equal_approx(target, REST_DIM_ALPHA):
		return  # 돌은 변화 없음

	if _dim_tween != null and _dim_tween.is_valid():
		_dim_tween.kill()
	_dim_tween = create_tween()
	_dim_tween.tween_property(_dim, "color:a", target, DIM_IN_TIME)
	_dim_tween.tween_interval(level["hold"])
	_dim_tween.tween_property(_dim, "color:a", REST_DIM_ALPHA, DIM_RECOVER_TIME)


## 파편이 위로 얼마나 도달하게 할지. 등급 차이는 개수가 아니라 이 범위에서 온다.
## 셋 다 "출발점에서 화면 위 끝까지"라는 하나의 자로 잰다 —
## 기준이 섞이면 화면 비율에 따라 철 < 금 < 다이아 순서가 뒤집힐 수 있다.
## 720x1280 기준: 철 100px(칸 주변) / 금 313px(룰렛 크기) / 다이아 625px(화면 끝)
func _shard_reach(mineral: String, origin: Vector2) -> float:
	match mineral:
		"철":
			return origin.y * 0.16
		"금":
			return origin.y * 0.50
		"다이아":
			return origin.y
		_:
			return 0.0


func _setup_carat_label() -> void:
	var text_server := TextServerManager.get_primary_interface()
	var font := FontVariation.new()
	font.base_font = CARAT_FONT
	font.variation_opentype = {text_server.name_to_tag("wght"): CARAT_FONT_WEIGHT}
	# tnum(고정폭 숫자). 숫자마다 폭이 달라지면 값이 오를 때 라벨이 떨려 보인다
	font.opentype_features = {text_server.name_to_tag("tnum"): 1}

	_carat_label.add_theme_font_override("font", font)
	_carat_label.add_theme_font_size_override("font_size", CARAT_FONT_SIZE)
	_carat_label.add_theme_color_override("font_color", CARAT_FONT_COLOR)
	_carat_label.text = CaratFormat.to_text(_carat)


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
