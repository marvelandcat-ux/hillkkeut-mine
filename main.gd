extends Node2D

const DIAMETER_RATIO := 0.82  # 룰렛 지름 = 화면 폭의 82%
const CENTER_Y_RATIO := 0.65  # 상단 1/3을 비워두려고 중심을 아래쪽에 둔다
const POINTER_WIDTH := 34.0
const POINTER_HEIGHT := 40.0
const POINTER_GAP := 8.0  # 룰렛 테두리와 포인터 끝 사이 간격
const POINTER_COLOR := Color("F2F0EA")

const MAX_CARAT := 9_000_000_000_000_000_000  # 64비트 정수가 넘치기 전에 멈춘다

const TOP_DEAD_ZONE_RATIO := 1.0 / 3.0  # 상단 1/3은 PIP 영상에 가려지는 영역이라 탭 판정에서 뺀다

const CARAT_FONT_SIZE := 62
const CARAT_FONT_COLOR := Color("F2F0EA")
const SHOP_BUTTON_FONT_SIZE := 32

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
@onready var _shop_button: Button = $UI/ShopButton
@onready var _shards: Node2D = $Shards
@onready var _dim: ColorRect = $Dim/DimRect
@onready var _shop: CanvasLayer = $Shop

var _carat := 0
var _unit_index := 0  # 지금까지 도달한 표시 단위. 여기서 올라갈 때만 룰렛을 교체한다
var _upgrades := Upgrades.new()
var _dim_tween: Tween = null


func _ready() -> void:
	_setup_labels()
	_layout()
	get_viewport().size_changed.connect(_layout)  # 기기 해상도가 달라도 같은 비율을 유지한다

	_roulette.bind_upgrades(_upgrades)
	_roulette.spun.connect(_on_spun)

	_shop.setup(_upgrades)
	_shop.upgrade_requested.connect(_on_upgrade_requested)
	_shop_button.pressed.connect(_open_shop)
	_refresh_pulse()


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
	_carat = mini(_carat + multiplier, MAX_CARAT)
	_carat_label.text = CaratFormat.to_text(_carat)
	_flash_dim(mineral)

	var origin := _roulette.get_wedge_rim_global(index)
	# 색은 상수가 아니라 지금 칸에 칠해진 색을 쓴다 (팔레트가 바뀌어도 따라간다)
	var wedge := _roulette.get_wedge(index)
	_shards.burst(origin, mineral, _shard_reach(mineral, origin), wedge.color)

	_refresh_pulse()
	_advance_palette()


## 표시 단위가 한 칸 올라가면 룰렛을 통째로 교체한다.
## 상점에서 캐럿을 써서 단위가 내려가도 되돌리지 않는다 — 경계에서 연출이 반복되기 때문
func _advance_palette() -> void:
	var unit := CaratFormat.unit_index(_carat)
	if unit <= _unit_index:
		return
	_unit_index = unit
	_roulette.play_transition(unit)
	_shop.set_palette(unit)  # 상점 목록의 광물 이름 색도 새 팔레트를 따라간다


func _open_shop() -> void:
	_shop.open(_carat)


## 강화 판정. 돈과 순서 잠금은 여기서만 본다 (상점은 어느 항목을 눌렀는지만 알려준다)
func _on_upgrade_requested(mineral: String) -> void:
	# 살 수 없으면 버튼이 이미 비활성이다. 상태가 어긋났을 때를 대비한 방어선
	if not _upgrades.can_upgrade(mineral, _carat):
		return

	_carat -= _upgrades.price(mineral)
	_upgrades.upgrade(mineral)
	_carat_label.text = CaratFormat.to_text(_carat)
	_shop.refresh(_carat)
	_refresh_pulse()


## 살 수 있게 된 칸만 맥동시킨다. 뱃지도 팝업도 쓰지 않으므로 이게 유일한 신호다
func _refresh_pulse() -> void:
	var affordable := []
	for mineral in Minerals.BASE_MULTIPLIERS:
		if _upgrades.can_upgrade(mineral, _carat):
			affordable.append(mineral)
	_roulette.set_pulsing(affordable)


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


func _setup_labels() -> void:
	KoreanFont.apply(_carat_label, CARAT_FONT_SIZE, CARAT_FONT_COLOR)
	KoreanFont.apply(_shop_button, SHOP_BUTTON_FONT_SIZE, CARAT_FONT_COLOR)
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
