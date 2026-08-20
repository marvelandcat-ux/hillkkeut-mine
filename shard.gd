class_name Shard
extends Polygon2D

## 결과로 튀는 파편 한 조각.
## 광물마다 실루엣이 달라서 색을 못 봐도 뭐가 걸렸는지 형태로 구분된다.

const GRAVITY := 900.0  # 떨어지는 가속도. 도달 거리를 역산할 때도 이 값을 쓴다
const SPIN_RANGE := 5.0  # 조각이 도는 속도 범위(라디안/초)
const FADE_TAIL_RATIO := 0.35  # 수명의 마지막 35%만 페이드아웃에 쓴다
const SIZE_JITTER := Vector2(0.85, 1.15)  # 조각마다 크기를 조금씩 흩는다
const FACET_LIGHTEN := 0.32  # 윗면을 밝게 해서 덩어리로 보이게 한다

## 광물별 모양. -1~1 정규 좌표로 적어두고 크기만 곱해서 쓴다.
## body = 실루엣, facet = 빛 받는 윗면
const SHAPES := {
	"철": {
		"body": [
			Vector2(-0.80, -0.20), Vector2(-0.30, -0.75), Vector2(0.50, -0.60),
			Vector2(0.85, 0.10), Vector2(0.35, 0.80), Vector2(-0.50, 0.60),
		],
		"facet": [Vector2(-0.80, -0.20), Vector2(-0.30, -0.75), Vector2(0.10, -0.10)],
	},
	"금": {
		"body": [
			Vector2(-0.85, 0.45), Vector2(0.85, 0.45),
			Vector2(0.55, -0.45), Vector2(-0.55, -0.45),
		],
		"facet": [
			Vector2(-0.55, -0.45), Vector2(0.55, -0.45),
			Vector2(0.42, -0.10), Vector2(-0.42, -0.10),
		],
	},
	"다이아": {
		"body": [
			Vector2(-0.45, -0.50), Vector2(0.45, -0.50), Vector2(0.90, -0.15),
			Vector2(0.00, 0.90), Vector2(-0.90, -0.15),
		],
		"facet": [
			Vector2(-0.45, -0.50), Vector2(0.45, -0.50),
			Vector2(0.25, -0.05), Vector2(-0.25, -0.05),
		],
	},
}

var _velocity := Vector2.ZERO
var _spin := 0.0
var _life := 1.0
var _age := 0.0


func launch(start: Vector2, velocity: Vector2, shard_color: Color, life: float, size: float, mineral: String) -> void:
	position = start
	_velocity = velocity
	_life = life
	_spin = randf_range(-SPIN_RANGE, SPIN_RANGE)
	rotation = randf_range(0.0, TAU)  # 처음 각도가 제각각이어야 파편처럼 보인다

	var shape: Dictionary = SHAPES[mineral]
	var scaled_size := size * randf_range(SIZE_JITTER.x, SIZE_JITTER.y)
	color = shard_color
	polygon = _scaled(shape["body"], scaled_size)

	var facet := Polygon2D.new()
	facet.polygon = _scaled(shape["facet"], scaled_size)
	facet.color = shard_color.lightened(FACET_LIGHTEN)
	add_child(facet)


func _process(delta: float) -> void:
	_age += delta
	if _age >= _life:
		queue_free()
		return

	_velocity.y += GRAVITY * delta
	position += _velocity * delta
	rotation += _spin * delta

	# 끝에서만 흐려지게 한다. 처음부터 옅어지면 "어디까지 날아갔는지"가 안 남는다
	var tail := _life * FADE_TAIL_RATIO
	modulate.a = clampf((_life - _age) / tail, 0.0, 1.0)


func _scaled(points: Array, size: float) -> PackedVector2Array:
	var scaled := PackedVector2Array()
	for point in points:
		scaled.append(point * size)
	return scaled
