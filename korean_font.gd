class_name KoreanFont

## 기본 폰트에는 한글 글리프가 없어서 "캐럿"이 두부(□)로 나온다.
## OFL 폰트를 프로젝트에 넣어 쓴다 (fonts/LICENSE.txt 참고)

const SOURCE := preload("res://fonts/noto_sans_kr.ttf")
const DEFAULT_WEIGHT := 600


## tnum(고정폭 숫자)을 켠 폰트. 숫자마다 폭이 달라지면 값이 오를 때 글자가 떨려 보인다
static func make(weight: int = DEFAULT_WEIGHT) -> FontVariation:
	var text_server := TextServerManager.get_primary_interface()
	var font := FontVariation.new()
	font.base_font = SOURCE
	font.variation_opentype = {text_server.name_to_tag("wght"): weight}
	font.opentype_features = {text_server.name_to_tag("tnum"): 1}
	return font


static func apply(control: Control, size: int, color: Color, weight: int = DEFAULT_WEIGHT) -> void:
	control.add_theme_font_override("font", make(weight))
	control.add_theme_font_size_override("font_size", size)
	control.add_theme_color_override("font_color", color)
