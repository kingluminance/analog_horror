# analog_horror

> 아날로그 호러 + 낮 공포(Daylight Horror) + 탐험형 3D 게임
> 엔진: **Godot 4.7** (Forward Plus, Jolt Physics, Windows에서 D3D12 렌더러)

## 컨셉
- **장르**: 낮 공포 — Midsommar, LSD Dream Emulator, Yume Nikki 계열의 정서
- **세계관**: 현실과 다른 가상의 세계. 이 세계만의 물리 법칙이 있고, 이상한 것들이 "원래 거기 있던 것처럼" 존재함 (예: 탁구 치는 물병)
- **분위기**: 밝고 채도 높은 잔디, 듬성듬성한 나무, 광각(FOV 90) 시점의 불안감
- **구조**: 탐표형 — 목표 없이 세계를 걸어다니며 규칙을 발견함. 엔딩 미정

이 저장소는 실제 Godot 프로젝트 루트다. 더 자세한 기획/진행 기록은 Obsidian 볼트
`obsidian-brain/projects/analog-horror/overview.md`에 있다 (이 저장소 밖, 별도 경로).

## 코드 구조

`entities/<이름>/` = 오브젝트 하나당 폴더 하나(스크립트 + 씬 + 전용 리소스를 같이 둠).
`shaders/`, `audio/`는 여러 오브젝트가 공유하는 것만 놓는다. 새 "기괴한 오브젝트"를
추가할 때는 `entities/` 밑에 폴더만 하나 늘리면 된다.

```
project.godot
scenes/
  ├─ title_screen.tscn      아무 키나 눌러 시작하는 타이틀 화면
  └─ main.tscn               공간(레벨) 씬 — 나무 18그루 + 숲 가장자리 26그루 고정 배치,
                              WorldBoundary(다각형 펜스 콜리전)로 플레이어 이탈 방지
entities/
  ├─ player/player.gd                    1인칭 이동 + 마우스룩 (CharacterBody3D)
  ├─ floating_photo/                     실사진 빌보드 + 대화 트리거 공용 베이스
  │   ├─ floating_photo.gd/.tscn         Sprite3D, billboard, sine bob, Area3D 근접 감지
  │   └─ photos/                         사진(.png, 배경 제거됨) + 대화(.dialogue) 에셋
  └─ dialogue_ui/analog_dialogue_balloon.gd/.tscn   세피아/모노스페이스 커스텀 대화창
  └─ orbiting_paddle/orbiting_paddle.gd/.tscn        물병 주위를 원형 궤도로 도는 탁구채
shaders/
  ├─ curved_world.gdshader     땅+나무+오브젝트 공용, 세계가 살짝 구형으로 휘어 보임
  └─ dither_overlay.gdshader   화면 전체 포스트프로세싱(디더링/비네트/스캔라인/그레인/CA)
ui/
  ├─ post_process.tscn         위 셰이더를 타이틀/메인 씬이 공유
  └─ pause_menu.gd/.tscn       ESC 일시정지 메뉴 (get_tree().paused 사용)
audio/                          외부 에셋 없이 Python stdlib(wave/math/random)로 합성한 SFX
addons/dialogue_manager/        Dialogue Manager v4.1.0 (doda 프로젝트에서 그대로 가져온 애드온)
```

## 구현된 것
- Curved World Shader (curve_strength 0.0008)
- 밝은 ProceduralSky + 약한 Fog + 글로우
- 나무 배치는 **런타임 랜덤이 아니라 `main.tscn`에 구워진 정적 노드**다.
  (`tree_spawner.gd`는 "탐험형 게임에서 구조가 매 실행마다 바뀌면 안 된다"는 이유로 삭제됨 —
  나무를 다시 랜덤화하는 방향으로 되돌리지 말 것)
- 숲 가장자리 링(반지름 42~52) + `WorldBoundary`(반지름 50, 32개 박스 콜리전을 다각형으로
  이어붙인 빈 펜스). 통짜 CylinderShape3D를 쓰면 스폰 지점이 콜리전 내부라 플레이어가
  즉시 밖으로 튕겨나가므로, 반드시 "속은 비어있는 다각형 펜스" 방식을 유지해야 함
- WASD 이동(SPEED 5.0) + 마우스 시점(FOV 90, 감도 0.003), 발소리는 이동 거리 1.7m마다 재생
- 분기 대화 시스템: Area3D 근접 감지 + **카메라가 오브젝트를 바라보고 있어야 함**
  (`facing_angle_degrees`, 기본 35도 반각 콘 안에 있어야 판정) → 둘 다 만족해야 `[E]` 힌트가
  뜨고 E/Enter로 대화 시작. 근접만으로는 상호작용 안 됨 — 등지고 있으면 E가 안 먹힘
  (`floating_photo.gd`의 `_is_player_facing()`).
  대화 중엔 `Input.mouse_mode`가 VISIBLE로 풀리고 플레이어 이동/마우스룩이 멈춤
  (`player.gd`가 `DialogueManager.dialogue_started/ended` 시그널을 구독)
- 첫 NPC **존**(`entities/floating_photo/photos/john*.png`, `john.dialogue`,
  `main.tscn`의 `Objects/John` 노드) — 예전 이름 "몽클가이"에서 개명, 관련 파일/노드/대화문
  전부 `john`/`존`으로 통일됨
- 두 번째 오브젝트 **탁구 치는 물병**(`entities/floating_photo/photos/ping_pong_bottle*.png`,
  `main.tscn`의 `Objects/PingPongBottle` 노드) — AI 배경 제거(`rembg`, isnet-general-use 모델)로
  누끼 딴 실물 사진. 존과 달리 **공중에 안 뜨고 다리가 바닥에 닿아야 하는 오브젝트**라
  `bob_height = 0.0`으로 사인파 bob을 끄고, `pixel_size`/`position.y`를 계산해서 **다리 끝은 항상
  y=0 지면에 고정한 채로 키움**. 플레이어 얼굴 높이(카메라 y=1.6) 맞춤 → 한 번 더 "2배 키워달라"는
  요청으로 최종 `pixel_size = 0.004396`, `position.y = 1.6` (원본 고해상도 `ping_pong_bottle.png`
  사용 — `_180` 축소본은 이 크기에선 화질이 아쉬워서 안 씀). 다리는 y=0 고정, `position.y = 목표높이/2`,
  `pixel_size = 목표높이/텍스처세로픽셀`로 계산하는 패턴 — 더 키우려면 이 두 값만 비례로 조정하면 됨.
  대화는 `ping_pong_bottle.dialogue`로 연결됨 (존과 같은 StoryFlags 방문 횟수 분기 패턴, speaker "물병")
- **`entities/orbiting_paddle/`** — 물병 주위를 원형 궤도로 도는 탁구채. `orbiting_paddle.gd`가
  `_process()`에서 매 프레임 `position = (cos(각도)*반지름, 높이, sin(각도)*반지름)`으로 로컬 좌표를
  계산 (`main.tscn`에서 `Objects/PingPongBottle`의 자식으로 붙어있어서 물병이 움직이면 궤도 중심도
  같이 따라감). `orbit_radius`(1.3) / `orbit_speed`(0.7 rad/s) / `orbit_height`(0, 부모 기준 로컬
  오프셋) 전부 export라 에디터에서 바로 조절 가능. Sprite3D billboard라 궤도 각도와 무관하게 항상
  카메라를 바라봄. 처음엔 수평 원(XZ 평면)이었는데 "더 빠르게 + 기울어진 원으로" 요청으로
  `tilt_degrees`(30도, `Vector3.RIGHT` 축 기준 회전) 추가하고 `orbit_speed`를 0.7 → 3.5로 올림
- **탁구채도 대화 가능** — `orbiting_paddle.gd`에 `floating_photo.gd`와 같은 E-상호작용(Area3D 근접
  + 시선 체크 + `[E]` 힌트)을 그대로 복제해서 추가. 다만 **계속 움직이는 대상이라 시선 판정을 훨씬
  좁게**(`facing_angle_degrees = 10도`, 존/물병은 35도) 잡아서 "정확히 조준"해야만 대화가 열림.
  대사는 `entities/orbiting_paddle/paddle.dialogue`(speaker "라켓")
- **투명/유리 재질처럼 배경과 명암·채도가 거의 같은 사진은 존 때 쓴 "고정 밝기+무채색 flood fill"
  방식이 안 먹힘** (배경과 피사체가 같은 밝기라 배경 제거가 피사체 내부까지 먹고 들어감) — 이런
  경우엔 `rembg`(AI 세그멘테이션) 같은 의미 기반 배경 제거를 써야 함. 물병 사진에서 실제로 겪은 문제
- ~~VHS/라디오 정적 글리치~~ — `main.tscn`에서 `StaticGlitch` 노드 제거해서 비활성화됨 (거슬린다는 피드백). 스크립트(`audio/static_glitch.gd`)와 사운드(`audio/static_burst.wav`)는 남아있어서 나중에 필요하면 노드만 다시 추가하면 됨

## 알려진 함정 / 버그 수정 이력
- **GDScript 타입 추론 + 서브클래스 프로퍼티 조합 금지**: `title_screen.gd`에서
  `InputEventKey`의 `.pressed`/`.echo` 같은 서브클래스 전용 프로퍼티를 `:=` 타입 추론
  변수에 대입하면 컴파일 에러 발생. 베이스 클래스 메서드인 `event.is_pressed()` /
  `event.is_echo()`로 우회해야 한다.
- Ground에는 `StaticBody3D` + `WorldBoundaryShape3D`가 있어야 함 (없으면 땅 뚫림 버그).
- `WorldBoundary` 다각형 펜스는 실제 플레이 테스트로 가장자리 차단을 확인한 상태.

## TODO
- [x] ~~물병(`PingPongBottle`)에 대화(dialogue_resource) 달기~~ — `ping_pong_bottle.dialogue` 추가, 존과 동일한 StoryFlags 방문 횟수 분기 패턴 적용됨 (speaker "물병")
- [ ] 실제 사진 더 확보 — `entities/floating_photo/photos/`에 넣으면 바로 새 오브젝트로 사용 가능
- [ ] 세계 규칙 명문화
- [ ] 엔딩 / 구조 설계

## 새 오브젝트 추가할 때
1. `entities/<새이름>/` 폴더 생성
2. 사진 기반 오브젝트면 `floating_photo.tscn`을 상속/복제하고 `photo` 텍스처와
   `dialogue_resource`만 갈아끼우면 대부분 끝남
3. 배경 제거는 "고정 밝기 + 무채색 기준 flood fill" 방식을 따름 (기존 존 사진 참고)

## 레퍼런스
- Midsommar (2019) — 낮 공포의 정서
- LSD Dream Emulator — 세계의 규칙
- Yume Nikki — 탐험형 구조
