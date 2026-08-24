extends CanvasLayer

## 설정 화면.
## 배경음악·소리 볼륨 슬라이더 + 진동 토글.
## 각 줄의 이름 버튼(로고 자리)을 누르면 그 값이 바로 0이 된다 — 스케치 기획 그대로.
## 인터페이스(레이아웃) 조정 기능은 이번 범위에서 뺐다.

const TOP_DEAD_ZONE_RATIO := 1.0 / 3.0  # 설정에서도 상단 1/3은 비워둔다 (PIP 영상에 가려지는 영역)
const ROW_HEIGHT := 150
const NAME_BUTTON_SIZE := Vector2(240.0, 96.0)
const SLIDER_MAX := 100.0
const DEFAULT_RESTORE := 50.0  # 0인 상태에서 끔을 풀면 돌아가는 위치 (50%)

const BGM_ICON := preload("res://assets/스프라이/배경음악로고_ui.png")
const SFX_ICON := preload("res://assets/스프라이/소리로고_ui.png")
const OFF_ICON := preload("res://assets/스프라이/끔로고-Photoroom.png")  # 음소거 때 로고 위에 겹치는 빨간 금지 표시
const VIBRATION_CONFIRM_MS := 30  # 진동을 다시 켰을 때 손끝으로 바로 확인시켜주는 진동

const TITLE_FONT_SIZE := 44
const NAME_FONT_SIZE := 34
const CLOSE_FONT_SIZE := 32

const TEXT_COLOR := Color("EDEAE1")
const DIM_TEXT_COLOR := Color("8A877E")
const ROW_BORDER_COLOR := Color("3A3A36")
const NAME_BUTTON_COLOR := Color("2A2A28")  # 로고 자리 버튼의 바탕
const ON_COLOR := Color("2FA35E")  # 진동 켬 — 상점의 "살 수 있음"과 같은 초록
const OFF_COLOR := Color("323230")  # 진동 끔 — 상점의 잠금 회색

@onready var _top_spacer: Control = $Layout/TopSpacer
@onready var _title: Label = $Layout/Title
@onready var _rows: VBoxContainer = $Layout/Rows
@onready var _close_button: Button = $Layout/CloseButton

var _vibration_button: Button = null


func _ready() -> void:
	visible = false
	KoreanFont.apply(_title, TITLE_FONT_SIZE, TEXT_COLOR)
	KoreanFont.apply(_close_button, CLOSE_FONT_SIZE, TEXT_COLOR)
	_close_button.pressed.connect(close)
	get_viewport().size_changed.connect(_layout_top_gap)
	_layout_top_gap()
	_build_rows()


func open() -> void:
	visible = true


func close() -> void:
	visible = false


## 상단 1/3을 빈 칸으로 밀어낸다. 화면 높이가 달라도 비율을 지킨다
func _layout_top_gap() -> void:
	_top_spacer.custom_minimum_size.y = get_viewport().get_visible_rect().size.y * TOP_DEAD_ZONE_RATIO


func _build_rows() -> void:
	_add_volume_row(BGM_ICON, GameSettings.bgm_volume, GameSettings.set_bgm_volume)
	_add_volume_row(SFX_ICON, GameSettings.sfx_volume, GameSettings.set_sfx_volume)
	_add_vibration_row()


## 로고 버튼 + 슬라이더 한 줄.
## 로고를 누르면 0(음소거)이 되고 위에 끔 표시가 뜬다.
## 다시 누르면 끄기 전 위치로 돌아오고, 0인 상태에서 껐던 거라면 50%로 돌아온다
func _add_volume_row(icon: Texture2D, initial: float, setter: Callable) -> void:
	var line := _new_row_line()

	var slider := HSlider.new()
	slider.max_value = SLIDER_MAX
	slider.step = 1.0
	slider.value = initial * SLIDER_MAX
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	slider.custom_minimum_size.y = 64.0

	var button := _new_icon_button(icon)

	# 음소거 상태일 때 로고 위에 겹쳐 뜨는 끔 표시
	var off_mark := TextureRect.new()
	off_mark.texture = OFF_ICON
	off_mark.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	off_mark.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	off_mark.set_anchors_preset(Control.PRESET_FULL_RECT)
	off_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	off_mark.visible = initial <= 0.0
	button.add_child(off_mark)

	# 끄기 직전 위치를 기억해뒀다가 다시 누르면 거기로 돌아간다
	var memory := {"last": DEFAULT_RESTORE}
	button.pressed.connect(func() -> void:
		if slider.value > 0.0:
			memory["last"] = slider.value
			slider.value = 0.0
		else:
			slider.value = memory["last"]
	)

	# 슬라이더가 바뀌면 즉시 적용된다. 손으로 0까지 내려도 끔 표시가 뜬다
	slider.value_changed.connect(func(value: float) -> void:
		setter.call(value / SLIDER_MAX)
		off_mark.visible = value <= 0.0
	)

	line.add_child(button)
	line.add_child(slider)


## 로고만 있는 버튼 (볼륨 줄의 음소거 토글용)
func _new_icon_button(icon: Texture2D) -> Button:
	var button := Button.new()
	button.icon = icon
	button.expand_icon = true
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.custom_minimum_size = NAME_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_paint_button(button, NAME_BUTTON_COLOR, TEXT_COLOR)
	return button


func _add_vibration_row() -> void:
	var line := _new_row_line()
	_vibration_button = _new_name_button("진동")
	_vibration_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vibration_button.pressed.connect(_toggle_vibration)
	line.add_child(_vibration_button)
	_paint_vibration()


func _toggle_vibration() -> void:
	GameSettings.set_vibration(not GameSettings.vibration_on)
	if GameSettings.vibration_on:
		GameSettings.vibrate(VIBRATION_CONFIRM_MS)
	_paint_vibration()


func _paint_vibration() -> void:
	if GameSettings.vibration_on:
		_vibration_button.text = "진동 켬"
		_paint_button(_vibration_button, ON_COLOR, TEXT_COLOR)
	else:
		_vibration_button.text = "진동 끔"
		_paint_button(_vibration_button, OFF_COLOR, DIM_TEXT_COLOR)


## 테두리만 있는 한 줄 틀 (상점의 줄과 같은 모양)
func _new_row_line() -> HBoxContainer:
	var row := PanelContainer.new()
	row.custom_minimum_size.y = ROW_HEIGHT
	row.add_theme_stylebox_override("panel", _row_style())

	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 24)
	row.add_child(line)
	_rows.add_child(row)
	return line


## 로고 자리 버튼. 아이콘 그림이 준비되면 text 대신 icon으로 바꾼다
func _new_name_button(label: String) -> Button:
	var button := Button.new()
	button.text = label
	button.custom_minimum_size = NAME_BUTTON_SIZE
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	KoreanFont.apply(button, NAME_FONT_SIZE, TEXT_COLOR)
	_paint_button(button, NAME_BUTTON_COLOR, TEXT_COLOR)
	return button


func _row_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.0, 0.0)
	style.border_color = ROW_BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(10)
	style.content_margin_left = 20.0
	style.content_margin_right = 20.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	return style


## 버튼은 상태별 색이 모두 같아야 눌렀을 때 색이 튀지 않는다 (상점과 같은 방식)
func _paint_button(button: Button, background: Color, text_color: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_corner_radius_all(8)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, style)
	button.add_theme_color_override("font_color", text_color)
	button.add_theme_color_override("font_hover_color", text_color)
	button.add_theme_color_override("font_pressed_color", text_color)
