# 힐끗 광산

영상을 보면서 화면을 거의 안 보고도 할 수 있는 룰렛 클리커. Godot 4.6, GDScript, 모바일 세로.

게임 규칙과 절대 원칙은 [CLAUDE.md](CLAUDE.md)에 있다. 코드를 고치기 전에 먼저 읽을 것.

## 실행

```
godot --path .
```

Windows 기준 실행 파일 경로 예시:

```
"D:\Godot_v4.6.3-stable_win64.exe\Godot_v4.6.3-stable_win64.exe" --path .
```

## 파일

| 파일 | 역할 |
|---|---|
| `main.gd` / `main.tscn` | 화면 배치, 탭 입력, 캐럿, 밝기 오버레이, 상점 연결 |
| `roulette.gd` / `roulette.tscn` | 12칸 룰렛. 회전·감속·스킵·칸 숫자·맥동·전환 연출 |
| `minerals.gd` | 칸 순서, 팔레트, 기본 배수, 등급 관계 (데이터 한 곳) |
| `upgrades.gd` | 강화된 배수, 가격, 순서 잠금 판정 |
| `shop.gd` / `shop.tscn` | 상점 화면. 룰렛 그림 자체가 상점이다 |
| `shard.gd` / `shards.gd` | 결과 파편 |
| `carat_format.gd` | 만/억/조/경 4자리 단위 표기 |
| `korean_font.gd` | 한글 폰트 + 고정폭 숫자 설정 |

`fonts/noto_sans_kr.ttf`는 OFL 폰트다. 기본 폰트에 한글 글리프가 없어서 넣었다.

## 검증

새 씬·스크립트를 만든 뒤에는 임포트를 돌린다.

```
godot --headless --import --path .
```

## 안드로이드 빌드

APK가 실제로 나오는 것까지 확인했다. 빌드에 필요한 것:

- Godot 내보내기 템플릿 (에디터 > 내보내기 템플릿 관리)
- JDK 17, Android SDK (platform-tools + build-tools)
- 디버그 키스토어

Godot 에디터 설정 > 내보내기 > Android 에 SDK·JDK·키스토어 경로를 넣고:

```
godot --headless --export-debug "Android" --path . build/hilkkeut_mine.apk
```

주의할 점 두 가지:

- `project.godot`의 `textures/vram_compression/import_etc2_astc`가 켜져 있어야 한다.
  꺼져 있으면 "설정 오류"만 뜨고 이유를 안 알려준다.
- Godot 프로세스가 떠 있는 상태에서 에디터 설정 파일을 손으로 고치면,
  그 프로세스가 종료되면서 예전 값으로 덮어쓴다.
