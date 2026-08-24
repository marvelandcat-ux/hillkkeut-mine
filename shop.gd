extends CanvasLayer

## 강화 목록 상점.
## 룰렛 그림을 누르는 방식은 어디를 눌러야 하는지가 안 보여서 세로 목록으로 바꿨다.

signal upgrade_requested(mineral: String)

const TOP_DEAD_ZONE_RATIO := 1.0 / 3.0  # 상점에서도 상단 1/3은 비워둔다 (PIP 영상에 가려지는 영역)
const ROW_HEIGHT := 150
const BUY_BUTTON_SIZE := Vector2(300.0, 96.0)
const ICON_SIZE := Vector2(90.0, 90.0)  # 줄 맨 앞의 광물 그림 크기

# 줄 맨 앞에 보여줄 광물 그림 (파편과 같은 그림을 쓴다). 돌은 그림이 없어 빈 칸으로 자리만 맞춘다
const ICON_TEXTURES := {
	"철": preload("res://assets/스프라이/광물/shard_철.png"),
	"금": preload("res://assets/스프라이/광물/shard_금.png"),
	"다이아": preload("res://assets/스프라이/광물/shard_다이아.png"),
}

const TITLE_FONT_SIZE := 44
const CARAT_FONT_SIZE := 30
const NAME_FONT_SIZE := 46
const PRICE_FONT_SIZE := 30
const CLOSE_FONT_SIZE := 32

const TEXT_COLOR := Color("EDEAE1")
const DIM_TEXT_COLOR := Color("8A877E")
const WAITING_TEXT_COLOR := Color("B4B0A5")  # 어두운 초록 위라 조금 더 밝아야 읽힌다
const ROW_BORDER_COLOR := Color("3A3A36")
const BUY_READY_COLOR := Color("2FA35E")  # 지금 살 수 있다
const BUY_WAITING_COLOR := Color("1D4F33")  # 열려는 있는데 캐럿이 모자란다
const BUY_LOCKED_COLOR := Color("323230")  # 순서 잠금 — 회색

@onready var _layout: VBoxContainer = $Layout
@onready var _top_spacer: Control = $Layout/TopSpacer
@onready var _title: Label = $Layout/Title
@onready var _carat_label: Label = $Layout/CaratLabel
@onready var _row_list: VBoxContainer = $Layout/Scroll/Rows
@onready var _close_button: Button = $Layout/CloseButton

var _upgrades: Upgrades = null
var _palette_step := 0
var _carat := 0
var _rows := {}  # 광물 -> {"name": Label, "button": Button}


func _ready() -> void:
	visible = false
	KoreanFont.apply(_title, TITLE_FONT_SIZE, TEXT_COLOR)
	KoreanFont.apply(_carat_label, CARAT_FONT_SIZE, DIM_TEXT_COLOR)
	KoreanFont.apply(_close_button, CLOSE_FONT_SIZE, TEXT_COLOR)
	get_viewport().size_changed.connect(_layout_top_gap)
	_layout_top_gap()
	_build_rows()


func setup(upgrades: Upgrades) -> void:
	_upgrades = upgrades


func open(carat: int) -> void:
	visible = true
	refresh(carat)


func close() -> void:
	visible = false


func set_palette(step: int) -> void:
	_palette_step = step
	refresh(_carat)


## 목록의 상태(배수·가격·잠금)를 다시 칠한다
func refresh(carat: int) -> void:
	_carat = carat
	_carat_label.text = "보유 %s" % CaratFormat.to_text(carat)
	if _upgrades == null:
		return

	for mineral in Minerals.TIERS:
		var name_label: Label = _rows[mineral]["name"]
		var buy_button: Button = _rows[mineral]["button"]

		name_label.text = "×%d %s" % [_upgrades.multiplier(mineral), mineral]
		# 이름 색은 그 광물의 현재 색이다. 목록에서도 색 온도 순서가 그대로 보인다
		name_label.add_theme_color_override("font_color", Minerals.color(mineral, _palette_step))

		if _upgrades.is_maxed(mineral):
			buy_button.text = "최대"
			buy_button.disabled = true
			_paint_button(buy_button, BUY_LOCKED_COLOR, DIM_TEXT_COLOR)
			continue

		var blocker: String = _upgrades.blocked_by(mineral)
		if not blocker.is_empty():
			buy_button.text = "먼저 %s" % blocker
			buy_button.disabled = true
			_paint_button(buy_button, BUY_LOCKED_COLOR, DIM_TEXT_COLOR)
			continue

		var price: int = _upgrades.price(mineral)
		var affordable: bool = carat >= price
		buy_button.text = CaratFormat.to_text(price)
		buy_button.disabled = not affordable
		if affordable:
			_paint_button(buy_button, BUY_READY_COLOR, TEXT_COLOR)
		else:
			_paint_button(buy_button, BUY_WAITING_COLOR, WAITING_TEXT_COLOR)


## 상단 1/3을 빈 칸으로 밀어낸다. 화면 높이가 달라도 비율을 지킨다
func _layout_top_gap() -> void:
	_top_spacer.custom_minimum_size.y = get_viewport().get_visible_rect().size.y * TOP_DEAD_ZONE_RATIO


func _build_rows() -> void:
	_close_button.pressed.connect(close)
	for mineral in Minerals.TIERS:
		var row := PanelContainer.new()
		row.custom_minimum_size.y = ROW_HEIGHT
		row.add_theme_stylebox_override("panel", _row_style())

		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 20)
		row.add_child(line)

		# 그림이 글보다 앞에 온다. 곁눈으로도 어느 광물 줄인지 보이게
		var icon := TextureRect.new()
		icon.custom_minimum_size = ICON_SIZE
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		if ICON_TEXTURES.has(mineral):
			icon.texture = ICON_TEXTURES[mineral]
		line.add_child(icon)

		var name_label := Label.new()
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		KoreanFont.apply(name_label, NAME_FONT_SIZE, TEXT_COLOR)
		line.add_child(name_label)

		var buy_button := Button.new()
		buy_button.custom_minimum_size = BUY_BUTTON_SIZE
		buy_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		KoreanFont.apply(buy_button, PRICE_FONT_SIZE, TEXT_COLOR)
		buy_button.pressed.connect(upgrade_requested.emit.bind(mineral))
		line.add_child(buy_button)

		_rows[mineral] = {"name": name_label, "button": buy_button}
		_row_list.add_child(row)


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = ROW_BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 28.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


## 버튼은 상태 4가지가 모두 같은 색이어야 눌렀을 때 색이 튀지 않는다
func _paint_button(button: Button, background: Color, text_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_disabled_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
