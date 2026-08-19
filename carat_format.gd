class_name CaratFormat

## 화면의 숫자는 항상 4자리 이하로 유지한다.
## 곁눈질로도 읽혀야 하는 게임이라 자릿수가 늘어나면 읽는 데 시선이 더 든다.

const UNIT_STEP := 10000  # 한국식 4자리 단위
const UNIT_NAMES := ["", "만", "억", "조", "경"]


static func to_text(amount: int) -> String:
	return "%s 캐럿" % to_number_text(amount)


## "1,234" / "1.23 만" / "5,678 만" 처럼 단위까지 붙인 숫자 부분
static func to_number_text(amount: int) -> String:
	var unit_index := 0
	var mantissa := float(amount)
	# 가장 큰 단위로 나눠서 1 이상 10000 미만이 되게 한다
	while mantissa >= UNIT_STEP and unit_index < UNIT_NAMES.size() - 1:
		mantissa /= UNIT_STEP
		unit_index += 1

	if unit_index == 0:
		return _with_commas(amount)

	# 반올림하면 가진 것보다 많아 보이고 9999.9가 10,000으로 튀어 자릿수가 넘친다. 그래서 버린다
	var number := ""
	if mantissa < 10.0:
		number = "%.2f" % _floor_to(mantissa, 2)  # 1.23
	elif mantissa < 100.0:
		number = "%.1f" % _floor_to(mantissa, 1)  # 12.3
	else:
		number = _with_commas(int(mantissa))  # 5,678

	return "%s %s" % [number, UNIT_NAMES[unit_index]]


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
