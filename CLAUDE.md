# analog_horror

> 아날로그 호러 + 낮 공포(Daylight Horror) + 탐험형 3D 게임
> 엔진: **Godot 4.7** (Forward Plus, Jolt Physics, Windows에서 D3D12 렌더러)

## 컨셉
- **장르**: 낮 공포 — Midsommar, LSD Dream Emulator, Yume Nikki 계열의 정서
- **세계관**: 현실과 다른 가상의 세계. 이 세계만의 물리 법칙이 있고, 이상한 것들이 "원래 거기 있던 것처럼" 존재함 (예: 탁구 치는 물병)
- **분위기**: 밝고 채도 높은 잔디, 듬성듬성한 나무, 광각(FOV 90) 시점의 불안감
- **구조**: 탐험형 — 목표 없이 세계를 걸어다니며 규칙을 발견함. 엔딩 미정

이 저장소는 실제 Godot 프로젝트 루트다. 더 자세한 기획/진행 기록은 Obsidian 볼트
`obsidian-brain/projects/analog-horror/overview.md`에 있다 (이 저장소 밖, 별도 경로).

## 코드 구조

`entities/<이름>/` = 오브젝트 하나당 폴더 하나(스크립트 + 씬 + 전용 리소스를 같이 둠).
`shaders/`, `audio/`, `data/`는 여러 오브젝트가 공유하는 것만 놓는다.

```
project.godot
scenes/
  ├─ title_screen.tscn      아무 키나 눌러 시작하는 타이틀 화면
  └─ main.tscn               공간(레벨) 씬 — 나무 고정 배치, WorldBoundary로 이탈 방지,
                              Objects/ 밑에 NPC·오브젝트 전부 인스턴스
entities/
  ├─ player/player.gd                    1인칭 이동 + 마우스룩 (CharacterBody3D)
  ├─ shared/interactable.gd/.tscn        공용 E-상호작용 컴포넌트 (아래 참고) — 모든 대화형
  │                                       오브젝트가 이걸 자식 노드로 인스턴스해서 씀
  ├─ floating_photo/                     실사진 빌보드 베이스
  │   ├─ floating_photo.gd/.tscn         Sprite3D, billboard, sine bob (+ Interactable 자식)
  │   └─ photos/                         사진(.png, 배경 제거됨) + 대화(.dialogue) 에셋
  │       (john, ping_pong_bottle, brain_in_vat)
  ├─ orbiting_paddle/          물병 주위를 기울어진 원으로 빠르게 도는 탁구채
  ├─ spinning_trinket/         통속의 뇌 옆에서 제자리 자전하는 오브젝트 (상호작용 없음)
  ├─ red_bouncy_ball/          빨간 통통볼 NPC — 스크립트 기반 바운스+찌부 애니메이션
  ├─ speaker/                 스피커 — 상자+회전하는 나팔 오브젝트
  ├─ trash_angel/              쓰레기 천사 — 대화로 몸통 형태가 바뀜
  ├─ trash_angel_wing_animation/  위 캐릭터의 원본 에셋(2D 스프라이트+날개 애니메이션 리소스)
  └─ dialogue_ui/analog_dialogue_balloon.gd/.tscn   세피아/모노스페이스 커스텀 대화창
data/
  ├─ story_flags.gd    방문 횟수 + "대화가 외형을 바꾸는" 범용 메커니즘 (아래 참고)
  └─ inventory.gd       인벤토리 (아래 참고)
ui/
  ├─ post_process.tscn         레트로 포스트프로세싱 셰이더, 타이틀/메인 씬이 공유
  ├─ pause_menu.gd/.tscn       ESC 일시정지 메뉴
  └─ inventory_ui.gd/.tscn, inventory_polaroid.gd/.tscn   인벤토리 UI (아래 참고)
shaders/
  ├─ curved_world.gdshader     땅+나무+오브젝트 공용, 세계가 살짝 구형으로 휘어 보임
  └─ dither_overlay.gdshader   화면 전체 포스트프로세싱(디더링/비네트/스캔라인/그레인/CA)
audio/                          외부 에셋 없이 Python stdlib(wave/math/random)로 합성한 SFX
addons/dialogue_manager/        Dialogue Manager v4.1.0 (doda 프로젝트에서 그대로 가져온 애드온)
```

## 핵심 아키텍처

### 공용 E-상호작용 컴포넌트 — `entities/shared/interactable.gd`
`class_name Interactable extends Area3D`. Area3D 근접 감지 + **카메라가 바라보고 있어야 함**
(`facing_angle_degrees` 반각 콘) + `[E]` 힌트 표시 + `DialogueManager.show_dialogue_balloon()` 호출까지
전부 이 노드 하나가 처리한다. 대화 가능한 오브젝트를 새로 만들 땐 `entities/shared/interactable.tscn`을
자식 노드로 인스턴스하고 `dialogue_resource`만 갈아끼우면 된다 (필요하면 `facing_angle_degrees`/
`range_radius`/`hint_offset`도 오버라이드). `main.tscn`에서 인스턴스별 대사 연결은 이 자식 노드
경로에 건다:
```
[node name="Interactable" parent="Objects/<노드명>"]
dialogue_resource = ExtResource("...")
```
원래는 `floating_photo.gd`가 이 로직을 직접 갖고 있었고 `orbiting_paddle.gd`가 통째로 복붙했었는데,
세 번째·네 번째 복붙(쓰레기천사, 통통볼)이 생기려던 시점에 여기로 뽑아냄 — **새 대화형 오브젝트에
이 로직을 다시 복붙하지 말 것.**

**한 번에 하나만 활성화됨(가장 가까운 것)**: NPC들이 일렬로 서 있으면 여러 Interactable이
동시에 범위+시선 조건을 만족할 수 있는데, 각자 독립적으로 판단하면 `[E]` 힌트가 둘 다 뜨고
E를 누르면 두 대화가 동시에 열리는 버그가 났었다. 그래서 모든 인스턴스가 공유하는 `static var`
tally(`_best`/`_next_best`/`_next_best_dist`/`_tally_frame`)를 둬서, 매 프레임 각 인스턴스가
자기 자격(범위 안 + 시선 안)과 카메라까지 거리를 신고하고, 그중 **카메라에서 제일 가까운 것 하나만**
힌트를 보여주고 E에 반응한다(1프레임 지연되지만 60fps에서 체감 안 됨 — 별도 매니저 노드 없이 이
방식으로 처리). 헤드리스 테스트로 검증: 두 Interactable을 나란히 놓고 둘 다 조건 만족시켰을 때
힌트는 가까운 쪽만 `visible=true`, 같은 E 입력을 양쪽에 흘려도 `show_dialogue_balloon()`은 한 번만
호출됨을 확인함.

**시선 판정(`_is_player_facing()`)은 이 노드의 `global_position`이 아니라
`global_position + hint_offset`을 기준으로 계산한다.** 존/물병처럼 Interactable이 시각적
몸통과 거의 같은 위치에 있으면 둘 다 별 차이 없지만, **통통볼처럼 Interactable을 흔들림 방지
때문에 시각적 오브젝트(공)와 다른 위치(지면 y=0 고정)에 앵커링한 경우엔 이게 핵심**이다 —
플레이어는 자연스럽게 공중에 떠서 튀는 공(=`[E]` 힌트가 떠 있는 위치)을 보는데, 판정 기준이
지면의 고정 앵커점이면 아무리 공을 똑바로 쳐다봐도 시선 판정이 계속 실패한다(실제로 겪은 버그 —
"범위 문제인 줄 알았는데 사실 시선 판정 문제였음", 헤드리스 자동 테스트 스크립트로
`_player_in_range`/`_is_player_facing()`/힌트 가시성을 직접 찍어봐서 재현·확정함). 그래서
새 오브젝트의 `hint_offset`은 "플레이어가 실제로 쳐다볼 만한 지점"으로 잡아야 함 — 시각 오브젝트가
Interactable과 같은 위치에서 안 움직이면 기본값 `(0, 0.4, 0)` 근방으로 충분하지만, 움직이거나
Interactable과 떨어져 배치된 경우 그 시각적 위치(또는 평균 위치)에 맞춰 `hint_offset`을 조정할 것.

- 움직이지 않는 대상(존, 물병, 통속의뇌): `facing_angle_degrees` 기본값 35도
- 빠르게 움직이는 대상(탁구채, 궤도 3.5 rad/s): 10도로 좁혀서 "정확히 조준"해야 열림
- 제자리에서 위아래로만 움직이는 대상(통통볼): 20도 — 힌트/Area3D는 **바운스하는 메쉬가 아니라
  고정된 루트 노드**에 붙여서 안 떨리게 함

### `StoryFlags` (오토로드, `data/story_flags.gd`)
- `get_flag`/`set_flag`, `get_visit_count`/`increment_visit_count` — 방문 횟수 기반 첫만남/재방문
  대사 분기 (존, 물병, 탁구채가 씀)
- `set_visual_state(id, key, value)` / `get_visual_state(id, key, default)` /
  `signal visual_state_changed` — **대화가 오브젝트의 외형을 바꾸는 범용 메커니즘**. `.dialogue`
  파일에서 `using StoryFlags` + `$> StoryFlags.set_visual_state("trash_angel", "body", "...")`처럼
  호출하면, 해당 id를 구독하는 엔티티 스크립트가 반응해서 텍스처 등을 바꾼다 (쓰레기천사가 이 방식으로
  몸통 3종을 전환함). 새 오브젝트도 이 패턴을 재사용하면 됨 — 새 오토로드 만들지 말 것.

### `DialogueVisibility` — 대화로 오브젝트 통째로 보이기/숨기기
`entities/shared/dialogue_visibility.gd` (`class_name DialogueVisibility extends Node`).
`StoryFlags.visual_state` 메커니즘 위에 얹은 컴포넌트 — 아무 오브젝트에나 플레인 `Node`
자식으로 추가하고 `entity_id`만 지정하면 됨. 대화 파일에서:
```
using StoryFlags
$> StoryFlags.set_visual_state("<entity_id>", "visible", false)  # 숨김
$> StoryFlags.set_visual_state("<entity_id>", "visible", true)   # 다시 보임
```
숨겨지면 그 오브젝트의 `Interactable` 자식도 같이 꺼짐(숨겨진 걸 대화로 다시 못 걸게).
통통볼에 데모로 연결돼 있음("이제 그만 튀어도 돼." 선택지). 세이브 없음 — 재시작하면 초기화.
- 세이브/로드 없음, 게임 재시작하면 초기화됨 (doda 프로젝트도 동일 상태)

### `Inventory` (오토로드, `data/inventory.gd`) + `ui/inventory_ui.*`
`register_item(id, display_name, texture, description)` / `give_item(id, count=1)` /
`remove_item(id, count=1) -> bool` / `has_item(id, count=1)` / `get_count(id)` /
`get_owned_items() -> Array`, `item_added`/`item_removed` 시그널. `.dialogue` 파일에서
`using Inventory` + `$> Inventory.give_item("id")`로 아이템을 줄 수 있음 (`ping_pong_bottle.dialogue`에
스모크테스트용 예시 있음). UI는 **흩뿌려진 폴라로이드 더미**(그리드 아님) — `KEY_I`로 토글, `←→`로
넘기기. `"modal_ui"` 그룹으로 일시정지 메뉴와 상호 배타적(동시에 못 열림). 이 프로젝트엔
`project.godot`에 `[input]` 섹션이 없다 — 모든 키는 `event.keycode == KEY_X` 식으로 하드코딩되어
있음(E, I 등), InputMap 액션을 새로 추가하지 말고 이 관례를 따를 것.

## NPC / 오브젝트 목록
- **존** (`Objects/John`) — 첫 실사진 NPC, 얼굴 크롭. 예전 이름 "몽클가이"
- **물병** (`Objects/PingPongBottle`) — 탁구 치는 물병. `rembg` AI 배경 제거로 누끼(투명 재질이라
  "고정 밝기+무채색 flood fill"은 안 먹힘). 다리가 지면(y=0)에 고정, 여러 차례 확대 요청으로 현재
  높이 약 3.2m. `bob_height=0`
- **탁구채** (`Objects/PingPongBottle/OrbitingPaddle`) — 물병 자식 노드, 기울어진(`tilt_degrees=30`)
  원 궤도로 빠르게(`orbit_speed=3.5`) 돎
- **통속의 뇌** (`Objects/BrainInVat`) — floating_photo 베이스, `bob_height=0` (무거운 상자라 안 뜸)
- **트링켓** (`Objects/BrainInVat/SpinningTrinket`) — 통속의 뇌 옆에서 제자리 자전. `billboard=1`은
  노드의 `rotation`을 무시하므로 `scale.x = cos(time*spin_speed)`로 회전을 흉내냄(고전적인 빌보드
  플립 트릭). 상호작용 없음
- **쓰레기 천사** (`Objects/TrashAngel`) — `Body`(Sprite3D) + `WingLeft`/`WingRight`(AnimatedSprite3D,
  `wing_flap_frames.tres` 재사용) 조합. `StoryFlags.visual_state_changed`(id `"trash_angel"`, key
  `"body"`, 값 `open_lid_eyes`/`closed_lid_eyes`/`closed_lid_noeyes`)로 몸통 전환
- **빨간 통통볼** (`Objects/RedBouncyBall`) — 첫 실사진이 아닌 실제 3D 메쉬(SphereMesh) NPC. 물리
  아님, 스크립트 포물선(`y = 4h(t/T)(1-t/T)`)으로 바운스 + 접지 시 찌부(squash) 스케일
- **축음기(박스+나팔)** (`Objects/Speaker`, `entities/speaker/`) — 상자(Box, billboard) 위에 축음기
  나팔(Horn)이 얹혀있는 오브젝트. 처음엔 계속 회전시켰었는데, 사용자 피드백으로 회전은 빼고 대신
  **근처에서 재생될 노래에 맞춰 말하는/펌핑하는 느낌**으로 바꿈 — 정확한 박자 동기화는 필요 없다고
  해서(`speaker.gd`) 실제 오디오 분석 없이 그냥 빠르게 반복되는 엔벨로프로 구현: `pump_attack`
  (기본 0.05초) 동안 좌우로(`pump_scale_x`, 기본 1.7배) 확 찢어지듯 늘어나면서 동시에 위아래는
  살짝 눌리고(`pump_scale_y`, 기본 0.8배 — 스퀴시&스트레치 반대 방향 움직임), 남은 `pump_interval`
  (기본 0.28초) 동안 `smoothstep`으로 부드럽게 원래 비율로 돌아옴 — 넷 다 `@export`라 실제 노래
  넣고 귀로 들으면서 다시 튜닝하면 됨. Horn은 `billboard=0`(항상 카메라를 보지 않음)이고 `_ready()`에서 180도 뒤집힌 채로 고정.
  대화는 `entities/speaker/gramophone.dialogue`(아직 대사 비어있는 스텁) — **`entities/floating_photo/
  photos/speaker.dialogue`("나는 왜 휴일인데 일하지...")를 쓰는 `BrainInVat/SpinningTrinket` 밑의 "스피커"
  NPC와는 완전히 다른 별개의 캐릭터**임에 주의. 폴더/노드 이름이 둘 다 "speaker" 계열이라 헷갈리기 쉬움 —
  처음에 실수로 둘을 같은 대화로 합쳐버린 적 있어서(바로 되돌림) 기록해둠

## 개발 환경 메모
- **Godot 4.7 헤드리스 바이너리**: `C:\Users\my\Downloads\Godot_v4.7-stable_win64.exe\
  Godot_v4.7-stable_win64_console.exe` — `--headless --path <프로젝트> --quit`으로 파싱 에러 체크
  가능. **한 번도 안 열어본 체크아웃/워크트리는 먼저 `--headless --editor --path <경로> --quit`을
  한 번 돌려서 `.godot/` import 캐시부터 만들어야 함** (안 그러면 DialogueManager 애드온 자체가
  "DMConstants not declared" 파싱 에러를 냄, 텍스처/다이얼로그 preload도 전부 실패함)
- **`project.godot`의 `translations_pot_files` 오염 버그**: 에디터를 열면(`--editor` 포함) 이 프로젝트
  폴더 안의 `.claude/worktrees/...` 하위 워크트리들에 있는 `.dialogue` 파일까지 스캔해서 POT 배열에
  같이 집어넣는 현상이 반복적으로 발생함. `.claude/.gdignore` 빈 파일을 넣어놨는데도 이 특정 스캔
  기능(번역 추출)에는 안 먹힘 — 에디터를 한 번이라도 돌렸으면 `translations_pot_files` 배열에서
  `res://.claude/worktrees/...`로 시작하는 항목들을 수동으로 지워야 함
- Git worktree 여러 개를 병렬로 쓸 때, 각 워크트리는 자기만의 `.godot/` 캐시를 가짐 — 한 워크트리에서
  임포트해도 다른 워크트리/메인 체크아웃에는 반영 안 됨
- **임시 헤드리스 테스트(`--headless --script res://_tmp_test_*.gd`)는 반드시 셸 레벨 `timeout`으로 감쌀 것**
  (예: `timeout 60 "$GODOT" --headless --script res://_tmp_test_x.gd`), 스크립트 자체가 금방 끝날 것 같아
  보여도 예외 없이. 실제로 겪은 사고: 진단용 테스트 스크립트가 마지막 출력 줄에서 `%` 포맷 문자열 인자
  개수를 잘못 넣어 `SCRIPT ERROR`로 죽었는데, 그 에러 경로에서 `get_tree().quit()`을 안 불러서 프로세스가
  안 죽고 30분 넘게 실제 CPU를 계속 태우며 백그라운드에 방치됨(사용자가 먼저 의문의 백그라운드 작업을
  발견하고 직접 강제종료해야 했음). 그래서: (1) 테스트 GDScript의 **모든** 종료 경로(정상 종료뿐 아니라
  에러 핸들러 안에서도)에서 명시적으로 `get_tree().quit()`/`quit(1)`을 부를 것, (2) 그래도 이중 안전장치로
  호출 자체를 `timeout`으로 감쌀 것, (3) 백그라운드로 돌린 테스트는 예상 시간이 지나면 방치하지 말고
  상태를 확인할 것, (4) `_tmp_test_*.gd`는 결과 확인 즉시 삭제할 것
- **인스턴스된 씬의 중첩 자식 노드에 오버라이드를 걸 때는 `[editable path="..."]`가 반드시 필요함**
  (예: `main.tscn`에서 `Objects/John`처럼 인스턴스한 노드 밑의 `Interactable` 자식에
  `dialogue_resource`를 걸 때). 이 마커 없이 텍스트로만 `[node name="Interactable"
  parent="Objects/John"] dialogue_resource = ...` 블록을 추가하면 **헤드리스 로딩은 멀쩡히
  되지만, GUI 에디터가 씬을 다시 저장하는 순간 그 오버라이드가 통째로 사라짐**(에디터가 그 노드를
  "편집 가능한 자식"으로 인식 못 해서). 실제로 이것 때문에 한 번 모든 NPC의 대화(`[E]` 상호작용)가
  전부 끊긴 적 있음 — `main.tscn`에 `[editable path="Objects/John"]` 등을 추가해서 해결.
  **대안**: 인스턴스가 하나뿐인 오브젝트(탁구채, 통통볼, 쓰레기천사처럼)는 아예 `dialogue_resource`를
  `main.tscn` 오버라이드로 걸지 말고 **그 오브젝트 자신의 베이스 `.tscn` 안에 직접 박아넣는 게
  이 버그에 완전히 안전함**(쓰레기천사가 처음부터 이 방식이었음). `floating_photo.tscn`처럼 여러
  인스턴스(존/물병/통속의뇌)가 서로 다른 대화를 쓰는 경우만 어쩔 수 없이 오버라이드 + `[editable
  path=...]` 조합을 써야 함

## 알려진 함정 / 버그 수정 이력
- **GDScript 타입 추론 + 서브클래스 프로퍼티 조합 금지**: `title_screen.gd`에서
  `InputEventKey`의 `.pressed`/`.echo` 같은 서브클래스 전용 프로퍼티를 `:=` 타입 추론
  변수에 대입하면 컴파일 에러 발생. 베이스 클래스 메서드인 `event.is_pressed()` /
  `event.is_echo()`로 우회해야 한다.
- Ground에는 `StaticBody3D` + `WorldBoundaryShape3D`가 있어야 함 (없으면 땅 뚫림 버그).
- `WorldBoundary` 다각형 펜스는 실제 플레이 테스트로 가장자리 차단을 확인한 상태.
- 투명/유리 재질처럼 배경과 명암·채도가 거의 같은 사진은 "고정 밝기+무채색 flood fill" 방식이 안 먹힘
  (배경 제거가 피사체 내부까지 먹고 들어감) — `rembg`(AI 세그멘테이션) 같은 의미 기반 배경 제거를
  써야 함
- ~~VHS/라디오 정적 글리치~~ — `main.tscn`에서 `StaticGlitch` 노드 제거해서 비활성화됨 (거슬린다는
  피드백). 스크립트(`audio/static_glitch.gd`)와 사운드는 남아있어서 나중에 필요하면 노드만 다시
  추가하면 됨

## TODO
- [ ] 게임 에디터로 직접 열어서 존/물병/탁구채/통속의뇌/트링켓/쓰레기천사/통통볼/인벤토리 전부
      플레이 테스트 (헤드리스 검증은 파싱 에러만 잡아줌, 실제 배치/크기/느낌은 안 봄)
- [ ] 쓰레기 천사 대화문은 예시 수준 — 다듬기
- [ ] 세계 규칙 명문화
- [ ] 엔딩 / 구조 설계

## 새 오브젝트 추가할 때
1. `entities/<새이름>/` 폴더 생성
2. **대화 가능한 오브젝트면** `entities/shared/interactable.tscn`을 자식으로 인스턴스하고
   `dialogue_resource`만 연결 — 상호작용 로직을 직접 짜지 말 것
3. 사진 기반이면 `floating_photo.tscn`을 상속/복제, 텍스처만 갈아끼움
4. 배경 제거: 기본은 "고정 밝기 + 무채색 기준 flood fill"(존 참고), 배경과 피사체 밝기가 비슷하면
   `rembg` AI 세그멘테이션(물병/통속의뇌 참고)
5. "대화 진행에 따라 외형이 바뀌어야" 하면 `StoryFlags.set_visual_state`/`get_visual_state` 재사용
   (쓰레기천사 참고), 새 오토로드 만들지 말 것

## 레퍼런스
- Midsommar (2019) — 낮 공포의 정서
- LSD Dream Emulator — 세계의 규칙
- Yume Nikki — 탐험형 구조
