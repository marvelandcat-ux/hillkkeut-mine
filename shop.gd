extends CanvasLayer

## 별도 목록 UI가 아니라 룰렛 그림 자체가 상점이다.
## 칸을 누르면 그 광물의 배수가 2배가 된다.

signal wedge_pressed(mineral: String)

const DIAMETER_RATIO := 0.72  # 상점 룰렛은 게임 화면보다 조금 작게
const CENTER_Y_RATIO := 0.56
const MESSAGE_SIZE := 38
const MESSAGE_COLOR := Color("D8D5CC")
const BUTTON_SIZE := 34

@onready var _backdrop: ColorRect = $Backdrop
@onready var _roulette: Roulette = $Roulette
@onready var _message: Label = $Message
@onready var _close_button: Button = $CloseButton


func _ready() -> void:
	visible = false
	_backdrop.gui_input.connect(_on_backdrop_input)
	_close_button.pressed.connect(close)
	KoreanFont.apply(_message, MESSAGE_SIZE, MESSAGE_COLOR)
	KoreanFont.apply(_close_button, BUTTON_SIZE, MESSAGE_COLOR)
	get_viewport().size_changed.connect(_layout)
	_layout()


func setup(upgrades: Upgrades) -> void:
	_roulette.bind_upgrades(upgrades)


func open(message: String) -> void:
	visible = true
	show_message(message)


func close() -> void:
	visible = false


func show_message(text: String) -> void:
	_message.text = text


func set_pulsing(minerals: Array) -> void:
	_roulette.set_pulsing(minerals)


func set_palette(step: int) -> void:
	_roulette.set_palette(step)


## 칸 판정은 각도로 한다. 부채꼴 하나하나에 버튼을 붙이지 않아도 되고 회전 중에도 맞는다
func _on_backdrop_input(event: InputEvent) -> void:
	var pressed := false
	if event is InputEventScreenTouch:
		pressed = event.pressed
	elif event is InputEventMouseButton:
		pressed = event.pressed and event.button_index == MOUSE_BUTTON_LEFT
	if not pressed:
		return

	var index := _roulette.wedge_at_global(event.position)
	if index < 0:
		return  # 룰렛 밖을 누르면 아무 일도 안 일어난다
	wedge_pressed.emit(Minerals.ORDER[index])


func _layout() -> void:
	var screen := get_viewport().get_visible_rect().size
	_roulette.radius = screen.x * DIAMETER_RATIO / 2.0
	_roulette.position = Vector2(screen.x / 2.0, screen.y * CENTER_Y_RATIO)
