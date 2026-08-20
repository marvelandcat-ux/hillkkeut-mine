class_name Minerals

## 룰렛 12칸의 이웃 순서. 게임 규칙상 고정이다 — 순서가 바뀌면 눈에 익힌 판독이 깨진다
const ORDER := [
	"다이아", "돌", "철", "돌", "철", "돌",
	"금", "돌", "철", "돌", "철", "돌",
]

const COUNT := 12

## 돌은 언제나 무채색이라 팔레트가 바뀌어도 그대로다
const STONE_COLOR := Color("888780")

## 룰렛이 교체될 때마다 색상환을 한 칸 돈다.
## 역할마다 안전한 색상 구간이 정해져 있어서, 어느 단계에서든
## "철이 가장 차갑고 다이아가 가장 따뜻하다"는 온도 순서가 구조적으로 안 깨진다.
## 0단계는 기획서에 적힌 색(철 1D9E75 / 금 7F77DD / 다이아 EF9F27)과 같다.
const PALETTE_CYCLE := 8  # 여덟 번 교체하면 처음 색으로 돌아온다
const PALETTE_STRIDE := 3  # 한 번에 건너뛰는 칸 수. 인접한 단계가 확실히 달라 보이게

const HUE_BANDS := {
	"철": {"hue": 160.0, "sweep": 60.0, "saturation": 0.82, "value": 0.62},
	"금": {"hue": 244.0, "sweep": 60.0, "saturation": 0.46, "value": 0.87},
	"다이아": {"hue": 36.0, "sweep": -60.0, "saturation": 0.84, "value": 0.94},
}

const BASE_MULTIPLIERS := {
	"돌": 1,
	"철": 3,
	"금": 10,
	"다이아": 100,
}

## 등급 순서. 상점 목록도 이 순서로 나열한다
const TIERS := ["돌", "철", "금", "다이아"]

## 낮은 등급 -> 바로 위 등급. 배수 순서(돌 < 철 < 금 < 다이아)를 잠그는 데 쓴다
const NEXT_TIER := {
	"돌": "철",
	"철": "금",
	"금": "다이아",
}


static func wedge_count(mineral: String) -> int:
	return ORDER.count(mineral)


## step 단계에서 그 광물이 가지는 색.
## 색상만 구간 안에서 돌고 채도·명도는 고정이라 어느 단계든 화면 인상이 비슷하게 유지된다
static func color(mineral: String, step: int) -> Color:
	if mineral == "돌":
		return STONE_COLOR
	var band: Dictionary = HUE_BANDS[mineral]
	var phase := float((step * PALETTE_STRIDE) % PALETTE_CYCLE) / float(PALETTE_CYCLE)
	var hue: float = fposmod(band["hue"] + band["sweep"] * phase, 360.0)
	return Color.from_hsv(hue / 360.0, band["saturation"], band["value"])
