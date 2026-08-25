extends Node2D

# 기획서는 지름 82% / 중심 65%였는데, 실제 폰에서는 하단 UI가 룰렛 위로 겹치고
# 제스처 바에도 물렸다. 룰렛을 조금 줄이고 위로 올려 아래쪽에 자리를 만든다
const DIAMETER_RATIO := 0.70  # 룰렛 지름 = 화면 폭 대비 비율
const CENTER_Y_RATIO := 0.59  # 상단 1/3은 그대로 비운 채, 아래에 UI 자리를 남긴다
const POINTER_HEIGHT := 64.0  # 포인터 스프라이트의 화면 표시 높이
const POINTER_GAP := 6.0  # 링 바깥과 포인터 끝 사이 간격

const MAX_CARAT := 9_000_000_000_000_000_000  # 64비트 정수가 넘치기 전에 멈춘다

const TOP_DEAD_ZONE_RATIO := 1.0 / 3.0  # 상단 1/3은 PIP 영상에 가려지는 영역이라 탭 판정에서 뺀다

# 룰렛 가운데를 꾹 누르고 있으면 자동으로 돈다. 반복 탭이 손가락에 부담이라서 넣었다
const AUTO_HOLD_TIME := 0.35  # 이만큼 누르고 있으면 자동 모드로 들어간다
const AUTO_ZONE_RATIO := 1.12  # 룰렛 반지름 대비 꾹 누르기가 먹는 범위 (링 포함 룰렛 전체)

# 결과가 나올 때 주는 진동. 등급이 높을수록 길다 —
# 화면을 안 봐도 알 수 있어야 하는 게임이라 진동도 같은 정보를 나른다.
# 50ms 밑으로는 폰 진동 모터가 예열되기 전에 끝나서 아무것도 안 느껴진다
const HAPTIC_MS := {
	"돌": 30,
	"철": 70,
	"금": 130,
	"다이아": 260,
}
const AUTO_START_HAPTIC_MS := 50  # 자동 모드가 켜졌다는 신호

const CARAT_FONT_COLOR := Color("F2F0EA")
const SHOP_BUTTON_FONT_SIZE := 32

# 화면 전체를 덮는 어둠막. 이 값은 절대 움직이지 않는다 —
# 화면이 통째로 깜빡이면 영상 시청에 방해가 되고, 뭐가 걸렸는지도 안 읽힌다
const REST_DIM_ALPHA := 0.15

# 룰렛은 평소 어둡게 눌러두고, 좋은 게 걸린 순간에만 밝아진다.
# 밝아지는 건 결과와 붙어야 하니 빠르게, 어둠으로 돌아오는 건 느리게
const ROULETTE_REST_TINT := 0.72
const FLASH_IN_TIME := 0.06
const FLASH_RECOVER_TIME := 0.30
# 등급이 올라갈수록 더 밝고 더 오래 간다. 이게 안 보고도 읽는 첫 번째 단서다.
# tint 0은 "변화 없음" — 돌은 절반이나 나와서 반짝이면 신호가 아니라 소음이 된다
const FLASH_LEVELS := {
	"돌": {"tint": 0.0, "hold": 0.0},
	"철": {"tint": 1.15, "hold": 0.3},
	"금": {"tint": 1.55, "hold": 0.3},
	"다이아": {"tint": 2.00, "hold": 1.0},
}

@onready var _roulette: Roulette = $Roulette
@onready var _pointer: Sprite2D = $Pointer
@onready var _carat_odometer: CaratOdometer = $UI/CaratOdometer
@onready var _shop_button: Button = $UI/ShopButton
@onready var _settings_button: Button = $UI/SettingsButton
@onready var _shards: Node2D = $Shards
@onready var _dim: ColorRect = $Dim/DimRect
@onready var _shop: CanvasLayer = $Shop
@onready var _settings: CanvasLayer = $Settings

var _carat := 0
var _holding_center := false
var _hold_time := 0.0
var _auto_spinning := false
var _palette_step := 0  # 지금까지 도달한 교체 단계. 여기서 올라갈 때만 룰렛을 교체한다
var _upgrades := Upgrades.new()
var _flash_tween: Tween = null


func _ready() -> void:
	_setup_labels()
	_layout()
	_pointer.modulate = Roulette.material_tint(_palette_step)
	_dim.color.a = REST_DIM_ALPHA  # 여기서 한 번 정해두고 이후로 건드리지 않는다
	_roulette.modulate = _gray(ROULETTE_REST_TINT)
	get_viewport().size_changed.connect(_layout)  # 기기 해상도가 달라도 같은 비율을 유지한다

	_roulette.bind_upgrades(_upgrades)
	_roulette.spun.connect(_on_spun)

	_shop.setup(_upgrades)
	_shop.upgrade_requested.connect(_on_upgrade_requested)
	_shop_button.pressed.connect(_open_shop)
	_settings_button.pressed.connect(_open_settings)
	_refresh_pulse()


## 터치는 project.godot에서 마우스 이벤트로 바꿔서 받는다.
## Godot의 Button은 터치 이벤트를 안 받기 때문에, 그걸 꺼두면 상점 버튼이 폰에서 죽는다.
## 그래서 여기서는 마우스 쪽만 본다 — 두 종류를 다 받으면 한 번 누른 게 두 번 먹힌다
func _unhandled_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click == null or click.button_index != MOUSE_BUTTON_LEFT:
		return

	if click.pressed:
		_on_press(click.position)
	else:
		_on_release()
	get_viewport().set_input_as_handled()


func _on_press(point: Vector2) -> void:
	if point.y < get_viewport_rect().size.y * TOP_DEAD_ZONE_RATIO:
		return  # 상단 1/3은 판정에서 뺀다

	# 룰렛 가운데는 "꾹 누르기"를 기다려야 해서 즉시 돌리지 않는다.
	# 그 밖은 조준이 없는 게임답게 누르는 즉시 한 판이다
	_holding_center = point.distance_to(_roulette.position) <= _roulette.radius * AUTO_ZONE_RATIO
	_hold_time = 0.0
	if not _holding_center:
		_roulette.tap()


func _on_release() -> void:
	if _auto_spinning:
		_stop_auto()
	elif _holding_center:
		_roulette.tap()  # 가운데를 짧게 눌렀다 뗐으면 그냥 한 판
	_holding_center = false


func _process(delta: float) -> void:
	if not _holding_center or _auto_spinning:
		return
	_hold_time += delta
	if _hold_time >= AUTO_HOLD_TIME:
		_start_auto()


func _start_auto() -> void:
	_auto_spinning = true
	_roulette.set_auto_spin(true)
	GameSettings.vibrate(AUTO_START_HAPTIC_MS)


func _stop_auto() -> void:
	_auto_spinning = false
	_roulette.set_auto_spin(false)


func _on_spun(index: int, mineral: String, multiplier: int) -> void:
	_carat = mini(_carat + multiplier, MAX_CARAT)
	_carat_odometer.set_value(_carat)
	_flash_roulette(mineral)
	GameSettings.vibrate(HAPTIC_MS[mineral])  # 설정에서 끌 수 있다. 폰이 아니면 아무 일도 일어나지 않는다

	var origin := _roulette.get_wedge_rim_global(index)
	_shards.burst(origin, mineral, _shard_reach(mineral, origin))

	_refresh_pulse()
	_advance_palette()


## 자릿수가 한 칸 올라가면 룰렛을 통째로 교체한다.
## 캐럿을 써서 자릿수가 내려가도 되돌리지 않는다 — 경계에서 연출이 반복되기 때문
func _advance_palette() -> void:
	var step := CaratFormat.swap_step(_carat)
	if step <= _palette_step:
		return
	_palette_step = step
	_roulette.play_transition(step)
	_pointer.modulate = Roulette.material_tint(step)  # 포인터도 몸체와 같은 재질을 따라간다
	_shop.set_palette(step)  # 상점 목록의 광물 이름 색도 새 팔레트를 따라간다


func _open_shop() -> void:
	if _auto_spinning:
		_stop_auto()  # 상점을 여는 동안까지 돌아갈 이유가 없다
	_holding_center = false
	_shop.open(_carat)


func _open_settings() -> void:
	if _auto_spinning:
		_stop_auto()  # 설정을 보는 동안까지 돌아갈 이유가 없다
	_holding_center = false
	_settings.open()


## 강화 판정. 돈과 순서 잠금은 여기서만 본다 (상점은 어느 항목을 눌렀는지만 알려준다)
func _on_upgrade_requested(mineral: String) -> void:
	# 살 수 없으면 버튼이 이미 비활성이다. 상태가 어긋났을 때를 대비한 방어선
	if not _upgrades.can_upgrade(mineral, _carat):
		return

	_carat -= _upgrades.price(mineral)
	_upgrades.upgrade(mineral)
	_carat_odometer.set_value(_carat)
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
## 그걸 건드리면 위에 떠 있는 유튜브 PIP 영상까지 같이 어두워진다.
## 화면 전체가 아니라 룰렛만 밝힌다 — 빛나는 자리가 곧 결과가 나온 자리다
func _flash_roulette(mineral: String) -> void:
	var level: Dictionary = FLASH_LEVELS[mineral]
	var peak: float = level["tint"]
	if peak <= 0.0:
		return  # 돌은 변화 없음

	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	_flash_tween = create_tween()
	_flash_tween.tween_property(_roulette, "modulate", _gray(peak), FLASH_IN_TIME)
	_flash_tween.tween_interval(level["hold"])
	_flash_tween.tween_property(_roulette, "modulate", _gray(ROULETTE_REST_TINT), FLASH_RECOVER_TIME)


## 색은 그대로 두고 밝기만 곱하는 회색. 1보다 크면 밝아지고 작으면 어두워진다
func _gray(value: float) -> Color:
	return Color(value, value, value)


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
	KoreanFont.apply(_shop_button, SHOP_BUTTON_FONT_SIZE, CARAT_FONT_COLOR)
	_carat_odometer.set_value(_carat, false)  # 시작값은 굴리지 않고 바로 표시


func _layout() -> void:
	var screen := get_viewport_rect().size
	var radius := screen.x * DIAMETER_RATIO / 2.0
	_roulette.radius = radius
	_roulette.position = Vector2(screen.x / 2.0, screen.y * CENTER_Y_RATIO)
	# 포인터는 룰렛의 형제 노드다. 자식으로 넣으면 룰렛과 같이 돌아서 의미가 없어진다.
	# 스프라이트 원점이 가운데라서, 뾰족한 끝이 링 바깥에 오도록 절반 높이만큼 올린다
	_pointer.scale = Vector2.ONE * (POINTER_HEIGHT / float(_pointer.texture.get_height()))
	_pointer.position = _roulette.position \
		+ Vector2(0.0, -radius * Roulette.RIM_OUTER_RATIO - POINTER_GAP - POINTER_HEIGHT / 2.0)
