class_name Shard
extends Sprite2D

## 결과로 튀는 파편 한 조각.
## 광물 그림을 그대로 쓴다 (shard_*.png는 원본 사진의 흰 배경을 지운 것).

const GRAVITY := 900.0  # 떨어지는 가속도. 도달 거리를 역산할 때도 이 값을 쓴다
const SPIN_RANGE := 3.0  # 조각이 도는 속도 범위. 그림이 세밀해서 너무 빨리 돌면 지저분하다
const FADE_TAIL_RATIO := 0.35  # 수명의 마지막 35%만 페이드아웃에 쓴다
const SIZE_JITTER := Vector2(0.82, 1.18)  # 조각마다 크기를 조금씩 흩는다

const TEXTURES := {
	"철": preload("res://assets/스프라이/광물/shard_철.png"),
	"금": preload("res://assets/스프라이/광물/shard_금.png"),
	"다이아": preload("res://assets/스프라이/광물/shard_다이아.png"),
}

var _velocity := Vector2.ZERO
var _spin := 0.0
var _life := 1.0
var _age := 0.0


## size = 화면에서 보일 긴 변의 길이(픽셀)
func launch(start: Vector2, velocity: Vector2, life: float, size: float, mineral: String) -> void:
	texture = TEXTURES[mineral]
	position = start
	_velocity = velocity
	_life = life
	_spin = randf_range(-SPIN_RANGE, SPIN_RANGE)
	rotation = randf_range(0.0, TAU)  # 처음 각도가 제각각이어야 파편처럼 보인다

	var longest := maxf(texture.get_width(), texture.get_height())
	var wanted := size * randf_range(SIZE_JITTER.x, SIZE_JITTER.y)
	scale = Vector2.ONE * (wanted / longest)


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
