extends Node2D

## 광물별 파편 성격.
## 개수보다 "어디까지 날아가는가"가 등급을 알려준다 — 곁눈으로 보는 건 범위다.
## 그림은 shard.gd가 광물별로 따로 들고 있다. size는 화면에서 보일 긴 변 길이다.
const BURSTS := {
	"돌": {},  # 없음
	"철": {"count": 3, "spread": 0.45, "size": 34.0, "life": 0.6},
	"금": {"count": 12, "spread": 1.20, "size": 42.0, "life": 1.1},
	"다이아": {"count": 22, "spread": 0.60, "size": 42.0, "life": 2.0},
}

const SPEED_JITTER := 0.18  # 초기 속도를 조금씩 흩어 자연스럽게 만든다
const UP := -PI / 2.0


## reach = 위로 얼마나 도달했으면 하는가(픽셀). 그 높이에서 초기 속도를 역산한다
func burst(origin: Vector2, mineral: String, reach: float) -> void:
	var spec: Dictionary = BURSTS.get(mineral, {})
	if spec.is_empty() or reach <= 0.0:
		return

	var base_speed := sqrt(2.0 * Shard.GRAVITY * reach)
	for i in int(spec["count"]):
		var angle: float = UP + randf_range(-spec["spread"], spec["spread"])
		var speed := base_speed * randf_range(1.0 - SPEED_JITTER, 1.0 + SPEED_JITTER)
		var shard := Shard.new()
		add_child(shard)
		shard.launch(origin, Vector2.from_angle(angle) * speed, spec["life"], spec["size"], mineral)
