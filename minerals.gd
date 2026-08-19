class_name Minerals

## 룰렛 12칸의 이웃 순서. 게임 규칙상 고정이다 — 순서가 바뀌면 눈에 익힌 판독이 깨진다
const ORDER := [
	"다이아", "돌", "철", "돌", "철", "돌",
	"금", "돌", "철", "돌", "철", "돌",
]

const COUNT := 12

# 임시 팔레트. 배수가 클수록 따뜻한 색이라는 온도 순서만 지키면 된다
const COLORS := {
	"돌": Color("888780"),
	"철": Color("1D9E75"),
	"금": Color("7F77DD"),
	"다이아": Color("EF9F27"),
}

const BASE_MULTIPLIERS := {
	"돌": 1,
	"철": 3,
	"금": 10,
	"다이아": 100,
}

## 낮은 등급 -> 바로 위 등급. 배수 순서(돌 < 철 < 금 < 다이아)를 잠그는 데 쓴다
const NEXT_TIER := {
	"돌": "철",
	"철": "금",
	"금": "다이아",
}


## 순서 잠금에 걸렸을 때 띄우는 문구. 을/를이 광물마다 달라서 문장째로 적어둔다
const UPGRADE_FIRST_MESSAGE := {
	"철": "먼저 철을 강화해야 합니다",
	"금": "먼저 금을 강화해야 합니다",
	"다이아": "먼저 다이아를 강화해야 합니다",
}


static func wedge_count(mineral: String) -> int:
	return ORDER.count(mineral)
