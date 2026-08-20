class_name Minerals

## 룰렛 12칸의 이웃 순서. 게임 규칙상 고정이다 — 순서가 바뀌면 눈에 익힌 판독이 깨진다
const ORDER := [
	"다이아", "돌", "철", "돌", "철", "돌",
	"금", "돌", "철", "돌", "철", "돌",
]

const COUNT := 12

## 돌은 언제나 무채색이라 팔레트가 바뀌어도 그대로다
const STONE_COLOR := Color("888780")

## 룰렛이 교체될 때마다 한 칸씩 이동하는 팔레트.
## 어느 단계에서든 철이 가장 차갑고 다이아가 가장 따뜻하다 — 이 온도 순서는 절대 안 뒤집힌다
const PALETTES := [
	{"철": Color("1D9E75"), "금": Color("7F77DD"), "다이아": Color("EF9F27")},
	{"철": Color("378ADD"), "금": Color("D4537E"), "다이아": Color("D85A30")},
	{"철": Color("7F77DD"), "금": Color("D85A30"), "다이아": Color("E24B4A")},
]

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


## step 단계에서 그 광물이 가지는 색. 단계가 팔레트 수를 넘으면 색상환처럼 처음으로 돈다
static func color(mineral: String, step: int) -> Color:
	if mineral == "돌":
		return STONE_COLOR
	var palette: Dictionary = PALETTES[step % PALETTES.size()]
	return palette[mineral]
