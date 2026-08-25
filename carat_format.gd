class_name CaratFormat

## 화면의 숫자는 항상 4자리 이하로 유지한다.
## 곁눈질로도 읽혀야 하는 게임이라 자릿수가 늘어나면 읽는 데 시선이 더 든다.

const UNIT_STEP := 10000  # 한국식 4자리 단위
const UNIT_NAMES := ["", "만", "억", "조", "경"]
const SWAP_START := 100  # 룰렛 교체가 시작되는 캐럿


static func to_text(amount: int) -> String:
	return "%s 캐럿" % to_number_text(amount)


## 지금 몇 번째 단위로 표시되는지 (0=원, 1=만, 2=억...). 룰렛 교체 시점을 여기서 잡는다
static func unit_index(amount: int) -> int:
	var index := 0
	var value := float(amount)
	# 가장 큰 단위로 나눠서 1 이상 10000 미만이 되게 한다
	while value >= UNIT_STEP and index < UNIT_NAMES.size() - 1:
		value /= UNIT_STEP
		index += 1
	return index


## 룰렛 교체 단계. 만/억은 10,000배씩 벌어져 있어서 그 주기로는 교체가 너무 드물다.
## 자릿수가 하나 늘 때마다(10배) 한 칸 올린다 — 숫자가 자라는 게 눈에 보이는 주기다
static func swap_step(amount: int) -> int:
	if amount < SWAP_START:
		return 0  # 첫 몇 판이 연출로 도배되지 않게 바닥을 둔다
	return str(amount).length() - str(SWAP_START).length() + 1


## "1,234" / "1.2만" / "5,678만" 처럼 단위까지 붙인 숫자 부분.
## 소수는 한 자리만, 단위는 붙여 써서 상점 버튼같이 좁은 곳에서도 안 넘친다
static func to_number_text(amount: int) -> String:
	var index := unit_index(amount)
	if index == 0:
		return _with_commas(amount)

	var mantissa := float(amount) / pow(float(UNIT_STEP), index)

	# 반올림하면 가진 것보다 많아 보이고 9999.9가 10,000으로 튀어 자릿수가 넘친다. 그래서 버린다
	var number := ""
	if mantissa < 100.0:
		number = "%.1f" % _floor_to(mantissa, 1)  # 1.2 / 12.3
	else:
		number = _with_commas(int(mantissa))  # 5,678

	return "%s%s" % [number, UNIT_NAMES[index]]


## 소수점 아래 digits자리까지 남기고 버림
static func _floor_to(value: float, digits: int) -> float:
	var scale := pow(10.0, digits)
	return floorf(value * scale) / scale


static func _with_commas(value: int) -> String:
	var digits := str(value)
	var text := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		text = digits[i] + text
		count += 1
		if count % 3 == 0 and i > 0:
			text = "," + text
	return text
