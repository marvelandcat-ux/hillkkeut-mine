class_name CaratOdometer
extends HBoxContainer

## 캐럿 숫자를 오도미터(주행계) 방식으로 보여준다.
## 유튜브 구독자수 카운터처럼 자릿수마다 숫자가 세로로 굴러가며 바뀐다.
## 앞자리 0은 표시하지 않고 자릿수가 차오르면 칸이 하나씩 나타난다.
## 억을 넘으면 "1000억"처럼 단위로 줄이고, 조·경 순서로 올라간다.
## 숫자를 감싸는 틀 스프라이트는 나중에 뒤에 따로 얹는다 — 여기는 숫자 애니메이션만.

const MAX_DIGITS := 8  # 단위 없이 보여주는 최대 자릿수 (1억 직전 = 99,999,999)
const FONT_SIZE := 52
const SUFFIX_FONT_SIZE := 30
const SUFFIX := "ct"
const TEXT_COLOR := Color("F2F0EA")
const ROLL_TIME := 0.4  # 한 자릿수가 목표 숫자까지 굴러가는 시간
const DIGIT_GAP := 2  # 자릿수 사이 간격(픽셀)
const LINE_RATIO := 1.25  # 숫자 한 칸의 높이 = 글자 크기 × 이 값. 틀 스프라이트에 맞춰 조절

const EOK := 100_000_000  # 억
const JO := 1_000_000_000_000  # 조
const GYEONG := 10_000_000_000_000_000  # 경

var _value := 0
var _digit_height := 0.0
var _windows: Array[Control] = []  # 자릿수별 창. 안 쓰는 앞자리는 숨긴다
var _strips: Array[Control] = []
var _positions: Array[float] = []  # 자릿수별 롤 위치. 0.0~10.0이고 10은 다시 0이다
var _tweens: Array = []  # 자릿수별 진행 중인 Tween (없으면 null)
var _unit_label: Label = null  # 억/조/경


func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", DIGIT_GAP)
	_digit_height = FONT_SIZE * LINE_RATIO
	_build_columns()
	_build_unit_label()
	_build_suffix()


## 바깥에서 부르는 유일한 함수. animate=false면 굴리지 않고 즉시 맞춘다
func set_value(value: int, animate := true) -> void:
	var forward := value >= _value  # 늘면 앞으로(위로), 줄면 뒤로 굴린다
	_value = value

	var parts := _split(value)
	var text: String = parts[0]
	var unit: String = parts[1]
	_unit_label.text = unit
	_unit_label.visible = not unit.is_empty()

	# 숫자는 오른쪽 끝에 붙이고, 남는 앞 칸은 숨긴다
	var hidden := MAX_DIGITS - text.length()
	for i in MAX_DIGITS:
		if i < hidden:
			_kill_tween(i)
			_windows[i].visible = false
			continue
		_windows[i].visible = true
		var target := text.unicode_at(i - hidden) - 48  # 48 = "0"
		if animate:
			_roll_to(i, target, forward)
		else:
			_kill_tween(i)
			_apply_roll(i, float(target))


## 값을 [표시할 숫자 문자열, 단위 글자]로 쪼갠다. 단위 아래 나머지는 버린다
func _split(value: int) -> Array:
	if value < EOK:
		return [str(value), ""]
	if value < JO:
		return [str(value / EOK), "억"]
	if value < GYEONG:
		return [str(value / JO), "조"]
	return [str(value / GYEONG), "경"]


## 한 자릿수를 목표 숫자까지 굴린다. 진행 중이던 롤은 그 위치에서 이어받는다
func _roll_to(index: int, target: int, forward: bool) -> void:
	var current := _positions[index]
	var distance: float
	if forward:
		distance = fposmod(float(target) - current, 10.0)  # 9→0도 위로 이어서 넘어간다
	else:
		distance = -fposmod(current - float(target), 10.0)
	if is_zero_approx(distance):
		return

	_kill_tween(index)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tween.tween_method(
		func(pos: float) -> void: _apply_roll(index, pos),
		current, current + distance, ROLL_TIME
	)
	_tweens[index] = tween


## Control의 내부 함수 _set_position과 이름이 겹치면 안 되어서 _apply_roll이라는 이름을 쓴다
func _apply_roll(index: int, pos: float) -> void:
	var wrapped := fposmod(pos, 10.0)
	_positions[index] = wrapped
	_strips[index].position.y = -wrapped * _digit_height


func _kill_tween(index: int) -> void:
	if _tweens[index] != null and _tweens[index].is_valid():
		_tweens[index].kill()
	_tweens[index] = null


func _build_columns() -> void:
	var font := KoreanFont.make()
	var digit_width := font.get_string_size("0", HORIZONTAL_ALIGNMENT_LEFT, -1, FONT_SIZE).x
	for i in MAX_DIGITS:
		# 창(window)은 한 글자 크기만 보여주고 나머지는 잘라낸다
		var window := Control.new()
		window.clip_contents = true
		window.custom_minimum_size = Vector2(digit_width, _digit_height)
		# 컨테이너가 세로로 늘려버리면 창이 한 칸보다 커져서 다음 숫자가 삐져나온다
		window.size_flags_vertical = Control.SIZE_SHRINK_CENTER

		# 띠(strip)에 0~9를 세로로 쌓고, 맨 끝에 0을 하나 더 둔다 (9→0이 이어져 보이게)
		var strip := Control.new()
		for d in 11:
			var label := Label.new()
			label.text = str(d % 10)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			label.position = Vector2(0.0, d * _digit_height)
			label.size = Vector2(digit_width, _digit_height)
			KoreanFont.apply(label, FONT_SIZE, TEXT_COLOR)
			strip.add_child(label)

		window.add_child(strip)
		add_child(window)
		_windows.append(window)
		_strips.append(strip)
		_positions.append(0.0)
		_tweens.append(null)


func _build_unit_label() -> void:
	_unit_label = Label.new()
	_unit_label.visible = false
	_unit_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_unit_label.custom_minimum_size = Vector2(0.0, _digit_height)
	KoreanFont.apply(_unit_label, FONT_SIZE, TEXT_COLOR)
	add_child(_unit_label)


func _build_suffix() -> void:
	var label := Label.new()
	label.text = SUFFIX
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.custom_minimum_size = Vector2(0.0, _digit_height)
	KoreanFont.apply(label, SUFFIX_FONT_SIZE, TEXT_COLOR)
	add_child(label)
