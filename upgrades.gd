class_name Upgrades
extends RefCounted

## 강화된 배수를 들고 있는 곳. 룰렛이 두 개(게임용·상점용)라 상태는 바깥에 둔다

signal changed

const PRICE_UNIT := 3

## 배수 상한. 이걸 넘기면 캐럿이 64비트 정수 범위를 벗어나 값이 망가진다
const MAX_MULTIPLIER := 1 << 50

var _multipliers := Minerals.BASE_MULTIPLIERS.duplicate()


func multiplier(mineral: String) -> int:
	return _multipliers[mineral]


## 가격 = 계수 × 칸 수 × 현재 배수.
## 배수가 2배가 되면 가격도 2배가 되어서, 무엇을 몇 번 강화하든 캐럿당 이득이 같다. 의도된 설계다
func price(mineral: String) -> int:
	return PRICE_UNIT * Minerals.wedge_count(mineral) * multiplier(mineral)


## 강화했을 때 바로 위 등급을 추월하면 그 등급 이름을 돌려준다 (막아야 한다는 뜻).
## 추월을 허용하면 "배수가 클수록 따뜻한 색"이라는 규칙이 뒤집혀 판독이 통째로 깨진다
func blocked_by(mineral: String) -> String:
	var next: String = Minerals.NEXT_TIER.get(mineral, "")
	if next.is_empty():
		return ""  # 다이아는 위가 없어서 항상 강화할 수 있다
	if multiplier(mineral) * 2 > multiplier(next):
		return next
	return ""


func is_maxed(mineral: String) -> bool:
	return multiplier(mineral) >= MAX_MULTIPLIER


func can_upgrade(mineral: String, carat: int) -> bool:
	if is_maxed(mineral):
		return false
	return blocked_by(mineral).is_empty() and carat >= price(mineral)


func upgrade(mineral: String) -> void:
	_multipliers[mineral] *= 2
	changed.emit()
