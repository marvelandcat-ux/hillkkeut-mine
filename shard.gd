class_name Shard
extends Polygon2D

## 이미지 없이 단색 다각형으로만 만든 파편 조각.

const GRAVITY := 900.0  # 떨어지는 가속도. 도달 거리를 역산할 때도 이 값을 쓴다
const SPIN_RANGE := 6.0  # 조각이 도는 속도 범위(라디안/초)
const FADE_TAIL_RATIO := 0.35  # 수명의 마지막 35%만 페이드아웃에 쓴다

var _velocity := Vector2.ZERO
var _spin := 0.0
var _life := 1.0
var _age := 0.0


func launch(start: Vector2, velocity: Vector2, shard_color: Color, life: float, size: float) -> void:
	position = start
	_velocity = velocity
	_life = life
	_spin = randf_range(-SPIN_RANGE, SPIN_RANGE)
	color = shard_color
	polygon = _chip_shape(size)


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


## 삼각~오각의 불규칙한 조각. 매번 모양이 달라야 파편처럼 보인다
func _chip_shape(size: float) -> PackedVector2Array:
	var corners := randi_range(3, 5)
	var points := PackedVector2Array()
	for i in corners:
		var angle := TAU * i / corners + randf_range(-0.2, 0.2)
		points.append(Vector2.from_angle(angle) * size * randf_range(0.6, 1.0))
	return points
