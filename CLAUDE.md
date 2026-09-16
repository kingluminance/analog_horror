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
  ├─ main.tscn               공간(레벨) 씬 — 나무 고정 배치, WorldBoundary로 이탈 방지,
  │                           Objects/ 밑에 NPC·오브젝트 전부 인스턴스 (나무집도 여기 포함)
  └─ log_cabin_interior.tscn 나무집 문으로 들어가면 나오는 별도 씬 — 겉보다 훨씬 큰 방 하나
entities/
  ├─ player/player.gd, player.tscn        1인칭 이동 + 마우스룩 (CharacterBody3D) — main.tscn과
  │                                       log_cabin_interior.tscn이 같은 player.tscn을 인스턴스해서 씀
  ├─ shared/interactable.gd/.tscn        공용 E-상호작용 컴포넌트 (아래 참고) — 모든 대화형
  │                                       오브젝트가 이걸 자식 노드로 인스턴스해서 씀
  ├─ floating_photo/                     실사진 빌보드 베이스
  │   ├─ floating_photo.gd/.tscn         Sprite3D, billboard, sine bob (+ Interactable 자식)
  │   └─ photos/                         사진(.png, 배경 제거됨) + 대화(.dialogue) 에셋
  │       (john, ping_pong_bottle, brain_in_vat)
  ├─ orbiting_paddle/          물병 주위를 기울어진 원으로 빠르게 도는 탁구채
  ├─ spinning_trinket/         통속의 뇌 옆에서 제자리 자전하는 오브젝트 (상호작용 없음)
  ├─ red_bouncy_ball/          빨간 통통볼 NPC — 스크립트 기반 바운스+찌부 애니메이션
  ├─ speaker/                 축음기 — 상자+펌핑하는 나팔 오브젝트, 노래 재생
  ├─ trash_angel/              쓰레기 천사 — 대화로 몸통 형태가 바뀜
  ├─ trash_angel_wing_animation/  위 캐릭터의 원본 에셋(2D 스프라이트+날개 애니메이션 리소스)
  └─ dialogue_ui/analog_dialogue_balloon.gd/.tscn   세피아/모노스페이스 커스텀 대화창
data/
  ├─ story_flags.gd    방문 횟수 + "대화가 외형을 바꾸는" 범용 메커니즘 (아래 참고)
  ├─ inventory.gd       인벤토리 (아래 참고)
  ├─ stats.gd            RPG식 스탯 (아래 참고)
  └─ save_system.gd      세이브/로드 (아래 참고)
ui/
  ├─ post_process.tscn         레트로 포스트프로세싱 셰이더, 타이틀/메인 씬이 공유
  ├─ inventory_polaroid.gd/.tscn, stat_gauge.gd/.tscn   아이템 카드 한 장 / 스탯 게이지 하나
  │                             (둘 다 binder/items_page.gd가 재사용하는 부품)
  └─ binder/                   Tab·Esc로 여는 단일 모달 UI (아래 참고) -- 예전에 따로였던
                                inventory_ui.gd/pause_menu.gd를 탭 3개로 통합
      ├─ binder_ui.gd/.tscn         탭(아이템/세이브·로드/설정)을 관리하는 루트, Tab/Esc 처리
      ├─ items_page.gd/.tscn        [아이템] 탭 -- 옛 inventory_ui.gd 내용을 그대로 이전
      ├─ save_load_page.gd/.tscn    [세이브/로드] 탭
      ├─ save_slot_card.gd/.tscn    세이브 슬롯 한 칸(빈 슬롯 / 기록된 슬롯)
      └─ settings_page.gd/.tscn     [설정] 탭 -- 옛 pause_menu.gd 내용을 그대로 이전
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

### 대화창 연출 확장 — `unskippable`/`tremble_level`/`reveal_chars_per_second` + `MutterLabel`
대화 한 줄 단위로 "이 줄은 스킵 안 됨" / "이 줄은 떨린다" / "이 줄은 더 빠르게/느리게 타이핑된다" 같은
연출을 걸고 싶을 때 쓰는 확장. 애드온을 건드리지 않고 이 프로젝트가 이미 감싸둔
`AnalogDialogueBalloon`/`AnalogDialogueLabel` 두 스크립트에 얇게 얹었다.

**`[wait=초]`/`[speed=배율]...[/speed]`는 애드온에 이미 내장된 인라인 태그** — 새로 만들지 말고
그대로 쓸 것. `[wait=0.4]`는 타이핑 도중 그 지점에서 0.4초 멈췄다 계속, `[speed=2.0]...[/speed]`는
그 구간만 타이핑 속도를 배율로 바꾼다. 둘 다 `DialogueLabel._mutate_inline_mutations()`가 처리하고,
이번에 추가한 어떤 코드도 이 경로를 건드리지 않았다(아래 `AnalogDialogueLabel`은 `_update_text()`만
오버라이드함) — 헤드리스 테스트로 `[wait=]`가 그대로 동작함을 직접 확인함(아래 함정 참고).

**`AnalogDialogueBalloon`(`entities/dialogue_ui/analog_dialogue_balloon.gd`)에 추가한 3개 `@export`**,
전부 기본값이 오늘까지의 동작과 동일(0/false)이라 기존 NPC 대화는 손대지 않아도 그대로 동작함:
- `unskippable: bool = false` — true면 그 줄이 타이핑 중일 때 클릭/`skip_action`이 완전히 무시됨(끝까지
  다 타이핑될 때까지 기다려야 함). `_on_balloon_gui_input()`의 스킵 분기 전체를 `and not unskippable`로
  감쌈 — 그 블록을 안 타면 `is_waiting_for_input`도 아직 false라 아래로 흘러도 아무 일도 안 일어남.
- `tremble_level: float = 0.0` — 0보다 크면 그 줄이 떨림. `AnalogDialogueLabel.tremble_level`로 그대로
  전달됨(아래 참고). 0 = 꺼짐.
- `reveal_chars_per_second: float = 0.0` — `DialogueLabel.seconds_per_step`(초/글자)을 글자/초 단위로
  덮어씀. 0이면 손대지 않고 `_ready()`에서 미리 캡처해둔 라벨의 원래 `seconds_per_step`(씬에 설정된
  값)으로 계속 감. 셋 다 `apply_dialogue_line()` 안, `dialogue_label.dialogue_line = dialogue_line`을
  대입하기 **직전**에 라벨로 밀어줌 — 그 대입이 `DialogueLabel._update_text()`를 곧바로 트리거하는데
  `AnalogDialogueLabel._update_text()`가 그 순간의 `tremble_level`을 읽어서 `[shake]`로 감싸기 때문에
  순서가 바뀌면 한 프레임 묵은 값으로 감싸게 됨.

**`.dialogue` 파일에서 `using` 없이 바로 `$> tremble_level = 4.0`처럼 설정 가능** — `locals.x`가 이미
쓰는 것과 완전히 같은 메커니즘(`DialogueManager`의 `_set_state_value`가 unqualified 식별자를
`extra_game_states`에서 찾음)이다. **단, 이게 성립하려면 실제로 대화를 여는 balloon이 그
`extra_game_states`에 들어있어야 함** — `AnalogDialogueBalloon.start()`가 `temporary_game_states = [self]
+ extra_game_states`로 자기 자신을 항상 첫 번째로 넣어주니 `Interactable`/`DialogueManager.
show_dialogue_balloon()`을 거쳐 실제 게임에서 여는 대화는 항상 이 조건을 만족한다. 하지만 헤드리스
테스트에서 `DialogueResource.get_next_dialogue_line()`을 balloon 없이 맨몸으로 부르면(`locals.x`
문서화된 것과 같은 함정) `"tremble_level" not found` 에러가 나고 그 뒤로도 조용히 계속 진행됨 —
balloon을 실제로 인스턴스해서 `.start()`로 열어야 이 경로가 성립한다(이번 검증도 그렇게 했음, 아래
참고).

**`AnalogDialogueLabel`(`entities/dialogue_ui/analog_dialogue_label.gd`, `extends DialogueLabel`)** —
`tremble_level`을 들고 있다가 `_update_text()`(베이스 클래스가 명시적으로 서브클래스 오버라이드
지점으로 문서화해둔 함수)에서 `super._update_text()` 호출 뒤 0보다 크면 텍스트 전체를 Godot
`RichTextLabel` 내장 `[shake rate=.. level=..]...[/shake]` BBCode 이펙트로 감싼다 — 커스텀
`RichTextEffect` 리소스 필요 없음. `analog_dialogue_balloon.tscn`이 애드온 기본 `DialogueLabel` 대신
이 스크립트를 쓰도록 인스턴스의 `script` 프로퍼티를 오버라이드해뒀다 — 이건 인스턴스된 씬의 **루트
노드 자체**에 대한 프로퍼티 오버라이드라서(중첩된 자식이 아님) 위 "인스턴스된 씬의 중첩 자식
노드" 항목과 달리 `[editable path=...]` 없이도 에디터 재저장에도 안전함(헤드리스 로드 테스트로
스크립트 오버라이드가 살아있는 것까지 확인함).

**가장 까다로웠던 부분 — `[shake]`로 감싸도 타자 애니메이션 인덱싱이 안 깨지는 이유**: `DialogueLabel`은
`visible_characters`/`get_total_character_count()`로 타자 진행을 추적하는데, 베이스 씬이
`bbcode_enabled = true`라 이 카운트는 **파싱된(렌더링되는) 글자 수**만 센다 — `[shake]`/`[/shake]`
같은 BBCode 태그 문자 자체는 안 셈. 그래서 감싸도 실제 대사 글자 쪽 인덱싱은 안 밀림 — 이걸 가정만
하지 말고 헤드리스 테스트로 직접 확인함(대사 앞뒤로 캐릭터 수를 세서 비교).

**주의 — `[wait=...]` 태그는 라벨에 표시되는 `text`/`DialogueLine.text`에 남아있지 않음**: 컴파일
단계에서 `inline_mutations` 배열로 빠지고 소스에서는 사라짐(그래서 `label.text`에서 `"[wait="`를
찾는 식으로 검증하려 하면 항상 실패함 — 대신 `dialogue_line.inline_mutations.size() > 0`으로 확인해야
함). **더 헷갈리는 함정**: `[wait=]`로 멈춰있는 동안 `DialogueLabel.is_typing`(공개 getter)이 **false를
반환함** — 내부적으로 `_is_typing and not _is_awaiting_mutation`이라 대기 중(`_is_awaiting_mutation
== true`)엔 아직 다 안 끝났어도 `is_typing`이 false로 보임. 헤드리스 테스트에서 "아직 타이핑
중이면 계속 기다린다"는 루프를 `while label.is_typing: ...`으로 짰다가 `[wait=]` 구간에서 즉시
빠져나와버리는 거짓 통과를 겪음 — `label.is_typing` 대신 `label.visible_characters`(또는
`visible_ratio`)가 목표치에 도달했는지로 기다려야 함.

**검증**: `entities/dialogue_ui/`에 임시 `.dialogue`/`.tscn`/`.gd`(지금은 삭제됨, `_tmp_test_*` 관례대로)를
만들어 balloon을 직접 `.start()`로 띄우고 `$> tremble_level = 6.0`/`$> unskippable = true`/
`$> reveal_chars_per_second = 100.0`이 각각 라벨에 반영되는지, 가짜 `InputEventAction`(`.action =
balloon.skip_action`, `.pressed = true`)을 `_on_balloon_gui_input()`에 직접 흘려서 unskippable일 때
스킵이 실제로 막히는지, `[wait=0.3]`이 여전히 정확히 그 글자 수에서 멈췄다 이어지는지까지 전부
확인함(`scenes/main.tscn` 헤드리스 회귀 테스트도 새 스크립트 에러 없이 통과 — 기존 NPC 전부 이 세
프로퍼티를 안 건드리므로 기본값 그대로 조용히 무시됨).

### `MutterLabel` — 대화 없이도 뜨는 혼잣말
`entities/shared/mutter_label.gd`(`class_name MutterLabel extends Node3D`) +
`entities/shared/mutter_label.tscn`. `Interactable`의 `[E]` 힌트(`Label3D`, billboard + no_depth_test +
작은 아웃라인)와 같은 스타일이지만, 대화(`DialogueManager`) 진행과 완전히 무관하게 아무 오브젝트나
자기 스크립트에서 아무 때나 짧은 혼잣말을 띄우고 싶을 때 쓴다(예: 통통볼이 튈 때마다 가끔 한 마디,
플레이어가 가까이 왔을 때 반응 등 — 아직 실제로 연결한 오브젝트는 없음, 컴포넌트만 준비해둠).
`interactable.tscn`과 같은 인스턴싱 관례 — 아무 오브젝트나 자식으로 `mutter_label.tscn`을 인스턴스하고
스크립트에서 `.say("텍스트")`만 부르면 됨.

`func say(text: String, duration: float = -1.0) -> void` — 페이드인 → 유지 → 페이드아웃(기본
`fade_in_time`/`fade_out_time` 각 0.25초, `hold_time` 1.1초 = 총 ~1.6초). `duration`을 양수로 주면
유지 시간만 그 값에 맞춰 재계산(`duration - fade_in_time - fade_out_time`)하고 페이드 자체 느낌은
안 바꿈. **큐 없음 — 의도적으로 단순하게**: 이미 보여주는 중에 `say()`를 또 부르면 진행 중이던
`Tween`을 죽이고 그냥 새로 시작함(끊기는 느낌 정도는 감수). 여러 혼잣말을 순서대로 이어붙여야 하는
오브젝트가 있으면 그건 이 컴포넌트가 아니라 그 오브젝트 자신의 스크립트가 순서를 들고 있다가 하나씩
`say()`를 불러주는 식으로 구현할 것.

### `Inventory` (오토로드, `data/inventory.gd`) + `ui/binder/items_page.*`
`register_item(id, display_name, texture, description="", max_count=-1)` / `give_item(id, count=1)` /
`remove_item(id, count=1) -> bool` / `has_item(id, count=1)` / `get_count(id)` /
`get_owned_items() -> Array`, `item_added`/`item_removed` 시그널. `.dialogue` 파일에서
`using Inventory` + `$> Inventory.give_item("id")`로 아이템을 줄 수 있음 (`ping_pong_bottle.dialogue`에
스모크테스트용 예시 있음). **`max_count`**(기본 -1 = 무제한)는 한 번에 최대 몇 개까지 지닐 수 있는지
제한 — `give_item`이 그 이상은 조용히 잘라냄(에러 안 냄, 그냥 그 이상 안 늘어남). "기록지"(`record_paper`,
아래 `SaveSystem` 참고)가 `max_count=1`로 등록되는 실사용 예시. `get_all_counts()`/`set_all_counts()`는
세이브/로드 전용(전체 스냅샷을 통째로 교체해서, 로드할 때마다 아이템 하나하나에 대해
`item_added`/`item_removed` 토스트가 뜨지 않게 함).

UI는 [아이템] 탭 안에서 **흩뿌려진 폴라로이드 더미**(그리드 아님) + 위쪽에 스탯 게이지 한 줄(아래
`Stats` 참고) — `KEY_TAB`으로 바인더 전체를 토글(아래 `binder_ui.gd` 참고). **아이템 설명 표시**는
카드 클릭/호버/`←→` 포커스 이동 셋 다 결국 `InventoryPolaroid.show_description()`으로 모여서
트리거됨(각 경로에서 따로 구현 안 함, `items_page.gd`의 `_update_focus()`가 포커스된 카드에 대해
매번 불러줌).

### `Stats` (오토로드, `data/stats.gd`) + `ui/stat_gauge.*` — RPG식 스탯
HP/공격성/유연성/레벨 등, 나중에 이벤트(전투일지는 미정)에 쓰일 플레이어 스탯. `StoryFlags`/`Inventory`처럼
딕셔너리 기반이라 `stats.gd` 자체엔 특정 스탯 이름이 하나도 안 박혀있음 — `register_stat(id,
display_name, default=0.0, max_value=10.0, clamp_to_max=true, description="")`로 한 번 등록해두면
(현재 시작 세트는 `entities/player/player.gd`의 `_ready()`에서 등록) `get_stat(id)`/`set_stat(id,
value)`/`add_stat(id, delta)`/`get_max(id)`/`set_max(id, max)`/`add_max(id, delta)`로 어디서든
(`.dialogue` 포함) 읽고 쓸 수 있음. `using Stats` +
`$> Stats.add_stat("aggression", 1)`처럼. 실제로 전투/이벤트에서 어떻게 쓸지는 아직 안 정해짐.

**스탯 두 종류, `clamp_to_max`로 구분** (최댓값 넘으면 어떻게 되는지 논의 후 결정):
- **자원형**(HP/공격성/유연성, `clamp_to_max=true` 기본값) — 진짜 상한/하한이 있고 HP처럼 소모될 수
  있음. `set_stat`/`add_stat`을 부를 때마다(등록 시 기본값이 범위 밖이어도) 실제 값 자체를
  `[0, max]`로 잘라냄 — 그래서 게이지 바늘이 꽉 찬 것과 숫자가 항상 일치함(둘 다 진짜 최대치를 뜻함)
- **성장형**(레벨, `clamp_to_max=false`로 등록) — 상한 강제 없음, `max_value`는 그냥 게이지 바늘
  눈금 기준일 뿐이고 값 자체는 그 이상 계속 오름. 넘으면 바늘은 꽉 찬 자리에 고정되고 숫자만 계속
  올라가는 상태가 되는데, "그냥 어쩔 수 없고 평범한 레벨 시스템"이라 의도적으로 그대로 둠

**표시는 [아이템] 탭 안, 별도 HUD 아님** — 처음엔 화면 구석에 항상 떠있는 별도 HUD로 만들었었는데,
"Tab 눌러야 나오게" 피드백으로 인벤토리 패널의 `StatsRow`로 옮겼고, 지금은 그 인벤토리 패널 자체가
바인더의 [아이템] 탭이 되어 같은 열고/닫는 생명주기를 씀(탭이 앞으로 나올 때마다 다시 그림). 각
스탯은 **바 대신 아날로그 바늘 게이지**(`ui/stat_gauge.gd`, `_draw()`로 직접 그린 눈금+바늘, 이미지
에셋 없음 — 이 프로젝트 오디오처럼 "직접 합성"하는 관례를 UI에도 적용) — `Stats.stat_changed`가 뜨면
해당 게이지만 바늘을 트윈으로 부드럽게 움직임. 여기도 스탯 이름을 하나도 하드코딩 안 해서 새 스탯을
`register_stat()`으로 추가하면 다음에 탭 열 때 자동으로 같이 뜸.

### 바인더 UI (`ui/binder/binder_ui.gd` 등) — Tab·Esc 통합 모달
"상단에 라벨이 겹쳐 있는 L홀더 파일첩" 컨셉의 단일 모달 — 예전에 따로 떠 있던 인벤토리 패널
(`inventory_ui.gd`)과 일시정지 메뉴(`pause_menu.gd`)를 [아이템]/[세이브·로드]/[설정] 3탭으로
합침. `KEY_TAB`을 누르면 [아이템] 탭으로, `ui_cancel`(Esc)을 누르면 [설정] 탭으로 열리지만 **일단
열리고 나면 탭은 자유롭게 클릭해서 전환** 가능 — 이미 열려 있는 상태에서 Tab/Esc를 다시 누르면
탭과 무관하게 그냥 닫힘(기존 토글 관례 유지). 탭을 고르면 이전 페이지가 `scale.x`를 0으로 줄였다가
새 페이지가 0에서 1로 펼쳐지는 짧은 트윈으로 전환됨 — 이 프로젝트가 이미 스피너류에 쓰던 것과 같은
"빌보드 플립" 스케일 트릭을 페이지 전환에도 재사용한 것. 탭 버튼들은 `_tab_order`(최근 고른
탭이 맨 앞에 오는 MRU 배열) 순서대로 **앞에서 뒤로 계단식으로 쌓인 모양**으로 배치됨 -- rank 0(현재
탭)이 맨 왼쪽·가장 밝고 큼·가장 위에 그려지고, rank가 늘어날수록(뒤에 있을수록) 오른쪽으로/살짝
작게/더 아래에 그려짐(z_index도 rank만큼 낮아짐) -- "선택된 것만 튀어나오고 나머진 다 같은 높이"가
아니라 "겹쳐 쌓인 실제 파일 탭들 중 이게 맨 위" 느낌을 냄(처음엔 선택된 탭만 맨 뒤/맨 오른쪽으로
옮기는 이진 방식이었는데, "맨 왼쪽부터 차례대로 아래에 깔리게, 클릭하면 그게 맨 앞으로" 라는
피드백으로 지금의 랭크 기반 계단식으로 바꿈).

**버튼을 `HBoxContainer`에 직접 넣고 `scale`을 건드리면 컨테이너가 정렬할 때마다 조용히 1로
되돌려버림**(이번에 직접 겪은 버그 -- `move_child` 앞/뒤 어느 순서로 `scale`을 대입해도 안 먹혀서
한참 헤맴). 그래서 각 탭은 `HBoxContainer`의 자식인 평범한(Container 아닌) `Control` "슬롯" 하나에,
그 슬롯의 자식으로 실제 `Button`을 넣는 2단 구조로 만듦 -- 슬롯은 컨테이너가 가로 배치를 담당하고,
`Button`은 어떤 컨테이너에도 안 속해 있어서 그 위치/크기를 몇 번을 바꿔도 그대로 유지됨.

계단식 높이 자체는 (재시도 끝에) `scale`이 아니라 `Button`의 `position.y`/`size.y`를 랭크별로 직접
계산해서 줌 -- 각 버튼의 **아래쪽 끝은 랭크와 무관하게 항상 같은 자리(`SLOT_HEIGHT`)에 오도록**
`position.y = SLOT_HEIGHT - size.y`로 맞추고, 짧아지는 건 전부 위쪽 끝에서만 일어나게 함 -- 그래야
탭 줄이 몇 랭크든 상관없이 바인더 프레임의 위쪽 테두리 선과 항상 딱 맞물림(처음엔 여기서도 실수함:
`Button`은 폰트+스타일박스 여백이 만드는 자기만의 최소 크기 밑으로는 `size.y`를 아무리 작게 줘도
조용히 다시 늘어나는데, `position.y`는 내가 **요청한**(늘어나기 전) 높이로 계산해버려서 뒤쪽 랭크
탭들의 아래쪽 끝이 그 늘어난 만큼 테두리 선 밑으로 빗나가 있었음 -- 사용자가 스크린샷으로 신고.
`size.y`를 대입한 **뒤에** 그 값을 다시 읽어서(`btn.size.y`, 클램프된 실제 값) `position.y`를 계산하는
걸로 고침 + 여백/폰트 크기를 줄여서 실제로 줄어들 수 있는 폭 자체도 넓힘).

**각 탭 밑에 강조선("종이 조각") 하나씩 달아봤다가 도로 뺌** -- "인덱스에 맞춰서 줄도 3개" →
"짧은 밑줄 말고 길게, 종이 3장이 겹친 것처럼" 두 차례 피드백으로 각 슬롯에 `ColorRect` 밑줄을
추가하고 4px에서 16px까지 늘려봤는데, 그 다음 피드백은 "이 큰 줄 지우자 오히려 별로다" --
`_tab_underlines`와 관련 로직 전부 삭제함. "여러 장 겹쳐 보이게" 하는 역할은 아래 고스트
시트가 대신 함.

**탭 라벨뿐 아니라 페이지 전체를 종이 뭉치처럼**("아코디언 파일철을 앞에서 본 것처럼"
— 참고 사진까지 받음) -- rank 1/2 페이지의 "몸통" 전체도 `BinderFrame` 뒤에서 살짝(12/10px,
24/20px) 오른쪽 아래로 밀려 삐져나와 보이도록 `GhostSheet1`/`GhostSheet2`(`ColorRect`) 두 장을
추가함(`_update_ghost_sheets()`). `BookWrap`(중앙 정렬 `CenterContainer`) 형제로 둬서 `BookColumn`의
레이아웃과 무관하게 자유롭게 위치·크기를 줄 수 있게 하고, `BinderFrame`의 **실제 화면 좌표**
(`global_position`/`size`, `CenterContainer`가 매 프레임 다시 정렬하므로 고정값 아님)를 읽어서
매 탭 전환마다 `call_deferred`로 다시 계산함(레이아웃이 그 프레임에 이미 끝났다는 보장이 없어서 —
위 "숨겨져 있던 Control" 함정과 같은 이유).

**탭 라벨도 자기 고스트 시트랑 같은 오프셋으로 같이 밀림** -- "위에 인덱스도 그거 맞춰서
진짜 그 페이지에 인덱스 붙어 있는거처럼" 피드백으로, rank1/2 오프셋을 `RANK_OFFSETS` 상수
하나로 통일해서 `_update_tab_buttons()`(탭 버튼)와 `_update_ghost_sheets()`가 같은 값을 씀 --
따로 하드코딩해뒀으면 나중에 둘이 어긋날 수 있었음.

**단, 탭 자체는 세로(y) 오프셋까지 받으면 안 됨** -- 처음엔 `RANK_OFFSETS`의 x/y를 탭에도
그대로 다 줬더니 뒤쪽 탭들이 앞 탭의 아래쪽 선보다 더 밑으로 처져서 "뒤로 숨음"이 아니라
"떨어져 나감"처럼 보임(사용자가 스크린샷으로 신고: "뒤쪽으로 보내야지 좀 올리고"). 탭
버튼은 `RANK_OFFSETS`의 **x만** 쓰고 y는 예전처럼 `SLOT_HEIGHT` 기준으로 전부 같은
바닥선에 맞춤 -- 세로로 처지는 건 고스트 시트(페이지 몸통)만의 몫.

**뒤쪽 탭은 진짜로 프레임보다 z가 낮아야 함 + "뒷종이 꺼내서 넘기는" 애니메이션** --
"인덱스들이 뒷장 종이에 붙어 있는 거처럼 보일려면 당연히 맨 앞장보다 레이어가 뒤어야지"
피드백. 그동안 탭바 전체(`tab_bar.z_index`)에 한 값을 걸어서 **모든** 탭이 프레임보다
위에 그려졌음 -- 뒤쪽 탭도 앞장에 가려지는 부분 없이 통째로 다 보여서 "뒤에 숨음" 느낌이
전혀 안 났음. 뒤로 갈수록(z 낮음) 앞으로 올수록(z 높음) 순서로 명시적 상수 4단계로 재구성:
고스트 시트(0, 기본값) < 뒤쪽 탭(`Z_BACK_TAB`=1) < 프레임/현재 페이지(`Z_FRAME`=2) < 앞쪽
탭(`Z_FRONT_TAB`=3). 뒤쪽 탭은 이제 자기 고스트 시트보다는 위, 프레임보다는 아래라서
프레임 몸통에 실제로 가려짐. 앞쪽 탭만 프레임보다 위(원래 z를 올렸던 이유 자체 -- 안 그러면
탭이 프레임 테두리 밑에 깔림).

**애니메이션**: 뒤쪽 탭을 클릭하면 그 탭이 갖고 있던 고스트 시트가 자기 위치(뒤에 숨어있던
자리)에서 `BinderFrame`의 실제 자리까지 트윈으로 이동 + 색을 프레임 색으로 페이드(`_switch_tab`
안에서 `await`) -- "뒷종이를 꺼내서 앞으로 넘기는" 느낌을 낸 뒤에야 기존 페이지 내용 전환
(`scale.x` 플립)이 이어짐. 클릭 즉시(`animate=false`인 첫 오픈 경로 제외) 반응하는 탭
라벨/z 갱신과 달리 이 부분만 애니메이션 있음.

**앞 페이지가 가장 밝아야 하는데 거꾸로였음** -- "인덱스 맨 앞에만 밝잖아 그거에
맞춰서 탭도 맨 앞에거가 더 밝게" 피드백. 탭 라벨은 이미 앞(밝은 금색)/뒤(어두운 호박색)
구분이 있었는데, `BinderFrame`의 배경색(0.06/0.05/0.035)이 오히려 그 뒤에 있는 고스트
시트 둘(0.15/0.12/0.08, 0.1/0.08/0.055)보다 더 어두웠음 -- 지금 보고 있는 앞장이 스택에서
가장 어두운 걸로 보이는 거꾸로 상태. 프레임은 밝게(0.11/0.09/0.06), 고스트는 랭크가
뒤로 갈수록 어둡게(0.08/0.065/0.045, 0.05/0.04/0.028) 조정해서 밝기가 앞→뒤로 내려가게
고침(탭 라벨의 밝기 규칙과 통일). 뒷장을 앞으로 당기는 애니메이션의 색 페이드 목표값도
새 프레임 색으로 같이 맞춤.

**탭은 데이터, 하드코딩 아님** — `binder_ui.gd`의 `TAB_DEFS` 배열에 `{id, label}` 하나 추가하고
`%PagesRoot` 밑에 그 id와 이름이 같은 페이지 씬을 인스턴스해두면 새 탭이 그냥 생김(코드 수정 불필요).
각 페이지 스크립트는 선택사항으로 `refresh()`(탭이 맨 앞으로 올 때마다 호출됨)와 `set_binder(binder)`
(자기 자신을 닫거나 스크린샷을 찍어야 하는 페이지용)를 구현할 수 있음. [아이템] 탭은 `items_page.gd`
(옛 `inventory_ui.gd` 그대로), [설정] 탭은 `settings_page.gd`(옛 `pause_menu.gd` 그대로), [세이브/로드]
탭은 아래 `SaveSystem` 참고.

### `SaveSystem` (오토로드, `data/save_system.gd`) + `ui/binder/save_load_page.*` — 세이브/로드
[세이브/로드] 탭의 백엔드. **세이브는 "기록지"(`record_paper`) 아이템 1장을 소모해야만 실행됨** —
`Inventory`에 `max_count=1`로 등록돼 있어 한 번에 한 장만 지닐 수 있음(`SaveSystem.can_save()` ==
`Inventory.has_item("record_paper")`). **로드는 제한 없이 언제든 가능.** 아직 게임 어디에도 기록지를
실제로 주는 이벤트/NPC가 없어서 — 발광체와 같은 상황("게이트는 진짜, 획득 경로는 나중 콘텐츠") —
지금은 `SaveSystem._ready()`에서 시작할 때 1장을 임시로 지급해 둠(실제 배포 전에 진짜 획득 경로로
옮기거나 지울 것).

세이브를 누르면: ① `binder_ui.gd`의 `capture_world_screenshot()`이 바인더 패널을 한두 프레임 숨기고
`get_viewport().get_texture().get_image()`로 UI가 아니라 실제 게임 화면을 찍음 → ② 중앙의 `RecordFrame`
(사용자가 준 그린스크린 사진 두 장을 Pillow로 크로마키 + 크롭한 실제 아트 -- `ui/binder/record_paper.png`,
찢어진 줄노트 종이 = "기록지" 그 자체)에 그 스크린샷이 페이드인 + 위치/시간 텍스트가
`RichTextLabel.visible_ratio`로 타자 치듯 나타나며 `audio/record_save.wav`(Python stdlib로 합성한
종이 서걱임 + 낮은 정착음) 재생 → ③ 잠깐 멈췄다가 대상 슬롯 쪽으로 이동하며 카드 크기로 줄어들고,
마지막에 순수하게 오른쪽으로만 짧게 한 번 더 밀려 들어가면서(`insert` 트윈, 그 전 이동이 어느 방향이었든
무관하게 "끼워 넣는" 동작 자체는 항상 오른쪽) `audio/record_click.wav`(합성한 딸깍 소리) 재생 후 사라짐.
각 세이브 슬롯(`save_slot_card.gd/.tscn`)의 배경도 같은 방식으로 만든 `ui/binder/slot_frame.png`
(회색 플라스틱 틀 사진)이고, 점유된 슬롯은 그 틀 안쪽 칸에 스크린샷 썸네일이 앉아있는 모양. 실제 저장은
`user://saves/slot_<n>.json`(플래그/방문횟수/외형상태/인벤토리/스탯/현재 씬/플레이어 트랜스폼/메모/
시각) + `slot_<n>.png`(스크린샷) 두 파일로 이뤄짐 — `StoryFlags`/`Inventory`/`Stats`는 평소엔
세션 메모리에만 있다가 이 순간에만 실제로 디스크에 쓰여짐. 로드는 그 반대로 전부 복원하고, 저장된
씬이 지금 있는 씬과 다르면 `change_scene_to_file()`로 이동한 뒤 플레이어 위치를 복원함(`cabin_door_watcher.gd`가
`dialogue_ended`를 기다리는 것과 같은 이유로 프레임을 한두 번 기다렸다가 적용).

**세이브 슬롯 개수는 고정이 아니라 `SaveSystem.get_max_slots()`가 매번 계산** — 시작은 1개, `StoryFlags`
플래그("기록된 날개와의 계약" 같은 스토리 진행)에 따라 3개 → 4개까지 늘어나도록 만들어 둠(지금은
`wings_contract_stage1`/`wings_contract_stage2`라는 자리표시자 플래그 — 실제로 그 플래그를 세워주는
스토리 콘텐츠는 아직 없음, 나중에 그 이벤트가 생기면 `StoryFlags.set_flag(...)` 한 줄만 추가하면 됨).
`save_load_page.gd`는 탭이 맨 앞으로 올 때마다 이 값을 다시 물어서 슬롯 카드(`save_slot_card.gd/.tscn`)를
다시 그리므로, 슬롯이 늘어나도 UI 쪽은 따로 손댈 필요 없음.

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
  넣고 귀로 들으면서 다시 튜닝하면 됨. Horn은 `billboard=0`(항상 카메라를 보지 않음)이고 `_ready()`에서
  180도 뒤집힌 채로 고정. **Box도 같은 엔벨로프로 펌핑함 — 대신 `box_pump_scale_y`(기본 1.4배)로
  위아래로만**(가로는 안 건드림), Horn과 같은 타이밍이라 같이 맞춰서 펄떡거림. **재생 중일 때만
  펌핑**: `StoryFlags.get_flag("gramophone_playing")`가 false면 둘 다 `scale = Vector3.ONE`으로 고정 —
  노래 안 틀었으면 가만히 있음.
  대화는 `entities/speaker/gramophone.dialogue`(아직 대사 비어있는 스텁) — **`entities/floating_photo/
  photos/speaker.dialogue`("나는 왜 휴일인데 일하지...")를 쓰는 `BrainInVat/SpinningTrinket` 밑의 "스피커"
  NPC와는 완전히 다른 별개의 캐릭터**임에 주의. 폴더/노드 이름이 둘 다 "speaker" 계열이라 헷갈리기 쉬움 —
  처음에 실수로 둘을 같은 대화로 합쳐버린 적 있어서(바로 되돌림) 기록해둠. `GramophoneAudio`
  (`AudioStreamPlayer3D`, `gramophone_audio.gd`)가 `audio/gramophone_song.wav`를 이 오브젝트 근처에서
  계속 재생함(`audio/looping_player.gd`와 같은 종료 시 재생 트릭, 3D 버전). 이 트랙 자체도 외부 에셋
  없이 Python stdlib(wave/math/random)로 합성함 — Daisy Bell 피아노 하나만(처음엔 Twinkle Twinkle
  Little Star를 한 옥타브 내려서 언더레이로 겹쳤었는데, 오히려 데이지벨이 잘 안 들린다는 피드백으로
  뺌), 여기에 히스/럼블/크래클 비닐 노이즈 + wow 피치 LFO를 더함. 멜로디는 처음엔 기억만으로 옮겼다가
  음이 부정확해서 사용자가 실제 악보(Harry Dacre, F장조, 3/4 왈츠) 사진을 보내줬는데, 그것도 이미지를
  눈으로 읽다 보니 또 부정확할 수 있어서 — 결국 abcnotation.com에서 실제 ABC 악보 원본 데이터(John
  Chambers Vintage 컬렉션, G장조)를 웹 검색/페치로 찾아서 그대로 가져와 옮김(픽셀 추측이 아니라 실제
  음/길이 데이터). 사용자가 보내준 2페이지 전체 분량(버스 4줄, "Daisy Daisy..."부터 "...bicycle built
  for two!"까지)을 전부 담아서 트랙 길이가 13초 → 37초로 늘어남. **베이스+코드 반주 추가**: "피아노
  멜로디만 있지 말고 노래답게 해달라"는 피드백으로, 왈츠 특유의 "쿵-짝짝"(oom-pah) 좌수 반주를 추가함
  — 마디 1박은 베이스음 단독, 2~3박은 코드 3음을 겹쳐 침. 코드는 멜로디와 같은 ABC 소스에 있던 코드
  기호(G/D7/Em/B7/A7)를 마디별로 그대로 매핑해서 실제 화성 진행과 맞춤(`CHORDS`/`BARS` in the
  generator script — 스크립트 자체는 리포에는 안 넣고 스크래치패드에만 둠, 다른 이미지 배경제거
  스크립트들과 같은 관례). **자동재생 안 함** — `StoryFlags.get_flag("gramophone_playing")`이 true가
  될 때까지 `play()`를 안 부름, `gramophone.dialogue`의 "노래를 틀어볼게." 선택지가 그 플래그를 세워줌.
  **레코드 튀는(스킵) 연출은 오디오 파일에 안 구워져 있고 런타임에 구현**: `skip_loop_end_sec`(기본
  9.6초)를 넘으면 `skip_loop_start_sec`(기본 9.0초)로 계속 `seek()`해서 그 구간을 무한 반복하면서
  `"gramophone_stuck"` 플래그를 세움 — `gramophone.dialogue`는 이 플래그가 true일 때만(재생 중이면서
  튀고 있을 때만) "고쳐볼게" 선택지를 보여주고, 그걸 고르면 `"gramophone_loop_fixed"`를 세워서 멈춤(동시에
  `"gramophone_stuck"`도 다시 false로 정리됨). 트랙이 길어져서 스킵 기본값이 곡 초반부(1번째 줄 안)에
  해당하니, 중간쯤으로 옮기고 싶으면 이 두 값만 조정하면 됨. `GramophoneAudio`는 매 프레임
  `"gramophone_playing"` 플래그를 그대로 따라감(true면 재생 시작, false면 `stop()`) — 껐다가 다시
  선택지로 켤 수 있음. **방문 횟수 카운트는 고친 뒤부터만**: `gramophone.dialogue`의 `~playing`에서
  `StoryFlags.increment_visit_count("gramophone")`를 부르는데, `StoryFlags.get_flag(
  "gramophone_loop_fixed")`가 true일 때만 부르도록 가드해둠 — 안 그러면 한 번도 안 고쳤어도(스킵을
  만나기 전에) "재생 중" 방문이 쌓여서 6번 채워질 수 있음(실제로 사용자가 발견한 버그). 6번(고친 뒤부터)
  채우면 `~repeat`로 빠져서 "그만 듣는다."/"계속 듣는다." 선택지가 나오고, 그만 듣기를 고르면
  `"gramophone_playing"`을 다시 false로 돌려서 실제로 음악이 멈춤. **재생 중엔 플레이어를 쫓아감**:
  `chase_radius`(기본 8m) 안에서는 카메라 위치(이 프로젝트엔 "player" 그룹이 없어서 `interactable.gd`가
  쓰는 것과 같은 방식으로 카메라를 플레이어 위치 대용으로 씀)를 향해 걸어가고, 그 반경을 넘어서면
  `_returning_home`이 true가 되면서 원래 스폰 위치로 돌아가는 데 전념함(다시 집에 도착할 때까지는
  거리가 반경 안으로 들어와도 재추격 안 함) — 이 래치(latch)가 없으면 반경 경계에서 매 프레임
  추격↔귀환이 뒤바뀌면서 제자리에 멈춰버리는 버그가 남(실제로 겪음, 헤드리스 테스트로 재현·수정 확인).
  Box/Horn/Interactable/GramophoneAudio가 전부 `Speaker`의 자식이라 이동하면 E 범위랑 3D 오디오
  패닝도 같이 따라감. **`chase_stop_distance`(기본 2m)까지만 다가가고 거기서 멈춤** — 원래 플레이어
  바로 코앞(0.05m)까지 붙어서 `[E]` 힌트가 카메라에 거의 파묻히던 문제 수정. 이 거리 판정은
  `chase_radius`(집에서 얼마나 멀어질 수 있는지)랑 독립적인 별개 제약이라, 둘 다 걸리는 위치에서
  테스트하면 어느 쪽이 실제로 막고 있는지 헷갈릴 수 있음(실제로 헷갈렸음 — 플레이어를 `chase_radius`
  경계 근처에 둔 첫 테스트에서 애매한 값이 나와서, `chase_radius` 안쪽 깊숙한 곳으로 옮겨서 다시
  테스트해 확인함). **단, 처음 한 번은 예외** — `_has_closed_in_once`가 false인 동안(=한 번도 플레이어
  코앞까지 닿아본 적 없는 동안)은 옛날처럼 0.05m까지 바짝 붙음(한 번의 깜짝 연출 용도). 한 번이라도
  닿으면 그 뒤로는(노래를 껐다 다시 켜도) 계속 `chase_stop_distance`를 지킴.
- **엘리콘티** (`entities/ellikonti/`) — `scenes/main.tscn`의 `Objects/Ellikonti`에 배치됨(사용자가
  직접 에디터에서 위치 조정, 현재 `(-31.97, 0, -31.26)`). **아트 교체**: 처음엔 대포 장식이 달린
  귀여운 애니메 치비 캐릭터였는데, "너무 유아틱하고 애니메이션틱하다, 그냥 퍼리잖아" 피드백으로
  완전히 다시 감. 마도카 마기카 마녀(게키단 이누카레) 스타일의 종이공예/콜라주 질감, 비대칭
  비율, 줄무늬 눈동자로 방향을 바꾸고, 표정도 "수줍음"이 아니라 식은땀 줄줄 흐르는 완전한 패닉
  상태로 밀어붙임 — 여전히 이 프로젝트의 밝고 채도 높은 색감은 유지해서 "밝은 색인데 표정은
  공포"인 부조화를 의도적으로 냄(그린스크린으로 받아서 크로마키 처리, 원본은 리포에 안 넣음).
  항상 몸을 떠는(지면 고정, 대화 없이도 계속) NPC — `Visual`(Sprite3D, billboard)에만
  위치/z회전 저크(sum-of-incommensurate-sines, `speaker.gd`의 펌핑 엔벨로프와 같은 "여러 사인파를
  안 맞는 주파수로 겹쳐서 반복 안 느껴지게" 발상, 단 여긴 엔벨로프가 아니라 연속 흔들림)를 매 프레임
  적용하고, 루트 노드와 `Interactable`은 완전히 정지 상태로 둠(`interactable.gd`의 range/facing 판정이
  이 루트의 `global_position`을 기준으로 삼으므로 — "`Interactable`을 계속 회전/변형하는 노드 밑에
  자식으로 달지 말 것" 항목과 같은 이유로 `Visual`을 `Interactable`의 형제로 둠). 대화와 무관하게
  주기적으로(불규칙한 간격, 고정 `Timer.wait_time` 아님) 자식 `MutterLabel`로 짧은 혼잣말을 띄움.
  `.dialogue`가 대화창 연출 확장(`unskippable`/`tremble_level`/`reveal_chars_per_second` +
  인라인 `[wait=]`)을 실제로 쓰는 첫 사례 — `first_meet`/`repeat` 두 분기 모두 끝에서 셋 다 명시적으로
  0/0/false로 되돌림. 플레이어가 "기록된 날개"(다른 브랜치에서 만들어지는 별개의 존재 — 이 스크립트는
  그쪽 구현을 전혀 모르고 대사상으로만 언급)를 데려온 건 아닌지 두려워한다는 설정. 헤드리스 테스트로
  검증: 실제 `Interactable`을 통해 진짜 `AnalogDialogueBalloon`을 띄우고 `first_meet` 분기를 진행하며
  `tremble_level`/`unskippable`/`reveal_chars_per_second`가 라이브 balloon 인스턴스에서 실제로 비기본값에
  도달하는지, `Visual`의 position/rotation이 몇 프레임 사이에 실제로 바뀌는지(떨림이 살아있는지),
  `MutterLabel.say()`가 대화 없이도 자기 타이머로 최소 한 번 발화하는지 확인함. **에디터로 직접 열어서
  스케일/월드 배치/떨림 강도 기본값을 아직 눈으로 확인 못 함** — 위 TODO 항목 참고.
- **나무집(로그캐빈)** (`Objects/LogCabin`, `(20, 0, -20)`) — 지면에 지은 통나무집 스타일(사용자 요청:
  나무 위 트리하우스 아님). `Body`(StaticBody3D, 충돌 있음 — 벽을 그냥 뚫고 지나갈 수 없게)/`Roof`
  (`PrismMesh`, 뾰족지붕)/`Door` 전부 나무·땅 공용 `curved_world` 셰이더 + 단색 `albedo_color`로 만듦
  (사진 에셋 없음, 이 프로젝트가 나무/땅에 쓰는 것과 같은 저폴리 프리미티브 스타일). 자체 대화/NPC 없음
  — 순수 장식. `scenes/log_cabin_interior.tscn`으로 이어짐 — **겉보다 훨씬 큰 방 하나**(34x34, 벽 높이
  10m, 전부 충돌 있음), **일부러 거의 안 보일 정도로 어둡게** 만듦(조명 없음, `ambient_light_energy
  =0.05`, 짙은 안개 `fog_depth_begin=1.5`) — 이유는 바로 아래. 자체 `Player`(`entities/player/
  player.tscn` 재사용)/`PostProcess`/`PauseMenu`/`InventoryUI` 다 갖추고 있어서 ESC/Tab 그대로 동작함,
  `ExitDoor`가 `scene_to_load`로 `scenes/main.tscn`에 되돌려보냄(플레이어 위치는 저장 안 해서 나가면
  원래 스폰 지점에서 다시 시작). 아직 안이 텅 빈 분위기용 공간 — NPC/아이템/스토리는 다음 단계.

  **문 상호작용은 대화 기반**(`entities/log_cabin/cabin_door.dialogue`) — `DoorInteractable`은
  `scene_to_load` 대신 다시 `dialogue_resource`를 씀: `Inventory.has_item("발광체")`(빛나는 물건, 아직
  어디서도 안 주어짐 — 등록 안 된 아이템도 `has_item`은 안전하게 false라 게이트 자체는 문제없이 작동)가
  없으면 "너무 어두워서 못 들어간다" 하고 끝, 있으면 "이동하시겠습니까?" 선택지("그래."/"아니.")를 물어봄.
  **`.dialogue`의 `$>`는 `get_tree()`를 못 부름(오토로드/게임state 객체 메서드만 가능)이라 "그래."를
  골라도 씬 전환 자체는 대화 안에서 못 함** — 대신 `StoryFlags.set_flag("cabin_wants_enter", true)`만
  세워두고, 옆에 붙어있는 `CabinDoorWatcher`(`entities/log_cabin/cabin_door_watcher.gd`)가
  `DialogueManager.dialogue_ended`를 구독하고 있다가 그 플래그가 서 있으면 그때 실제로
  `get_tree().change_scene_to_file()`을 부르고 플래그를 다시 끔 — "대화로 시작해서 코드로 마무리"하는
  패턴, 비슷한 게 또 필요하면 재사용 가능.
- **기록된 날개** (`entities/recorded_wings/`) — `scenes/main.tscn`의 `Objects/RecordedWings`에 배치됨.
  가운데 눈(`Eye`) + 그 주위에 같은 찢어진 줄노트 날개 스프라이트 4장(`WingRight`/`WingTop`/`WingLeft`/
  `WingBottom` — 처음엔 아래를 일부러 비웠다가 나중에 `WingBottom` 추가로 사방이 다 채워짐) —
  SaveSystem의 "기록지"(`record_paper.png`) 모티프를 저장 카드가 아니라 날개 모양으로 재활용한 것.
  대화/`Interactable` 없음 — 순수 장식.
  **그룹 전체가 한 방향을 보는 트릭 (업데이트됨)**: 원래는 날개 3장이 서로 회전 없이(위치만 다르게)
  대칭 배치돼 있어서 네 스프라이트 전부 `billboard = 1`만 걸면 끝이었음 — `spinning_trinket.gd`가
  문서화했듯 billboard는 매 프레임 카메라 기준으로 노드의 회전을 통째로 재계산해서 자기 `rotation`을
  무시하는데, 네 스프라이트가 같은 카메라를 상대로 정확히 같은 계산을 독립적으로 돌리니 결과적으로
  넷 다 똑같은 방향을 보게 됨(실제로 궤도 카메라 도는 테스트 씬에서 확인함). **이후 날개들을 비대칭
  부채꼴로 손으로 재배치**하면서 이 트릭이 깨짐 — billboard를 켜두면 매 프레임 그 손으로 맞춘 회전을
  카메라 기준으로 지워버리기 때문. 그래서 지금은 **다섯 스프라이트(눈+날개 4장) 전부 billboard OFF**,
  대신 `recorded_wings.gd`의 루트가 `_process()`에서 카메라를 향해 `look_at()` 한 번만 해줌 — 부모의
  basis만 바뀌니까 자식들(눈+부채꼴 날개 4장)의 로컬 회전(=날개 모양)은 그대로 유지된 채 전체가
  한 덩어리로 카메라를 따라 돎. 몸 전체 bob은 루트 레벨 sine 하나로(`trash_angel.gd`와 같은 방식),
  개별 스프라이트는 자기 bob을 따로 안 가짐.
  **날개 4장은 각자 독립적으로 랜덤 간격(`wing_interval_min`~`wing_interval_max`, 기본 1.0~2.5초 —
  원래 2.5~6초였는데 더 자주 나오라고 줄임)마다 TREMBLE(짧은 떨림)/PUMP(스케일 펄스 5회)/STRETCH
  (세로로 늘어났다 복귀) 셋 중 하나를 무작위로 골라 실행**하고 끝나면 원래 위치/스케일로 정확히
  복귀한 뒤 다음 간격을 다시 뽑음 — `speaker.gd`의 pump 엔벨로프와 같은 정신이지만 스프라이트별·
  랜덤이라는 점이 다름. **날개끼리 "하나만 동시에" 같은 잠금이 전혀 없어서 여러 날개가 동시에
  behavior를 돌리는 것도 정상**(원래부터 그랬음, 4번째 날개 추가로 바뀐 건 없음). 테스트에서 관찰하기 쉽도록
  `wing_behavior_started`/`wing_behavior_finished(wing, behavior)` 시그널을 냄(헤드리스 테스트가
  내부 상태를 몰래 훔쳐보지 않고 이 시그널만으로 3가지 행동이 실제로 도는지 확인함 — 실제 카메라 있는
  더미 씬 + `--quit-after`로 18초 시뮬레이션해서 검증).

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
- **`Interactable`을 계속 회전/변형하는 노드(예: `spinning_trinket.gd`처럼 `scale.x`를 매 프레임
  오실레이션하는 빌보드 플립 트릭) 밑에 자식으로 달지 말 것.** 자식 노드는 부모의 스케일을 그대로
  상속받는데, 그게 매 프레임 -1~1 사이를 오가면 `CollisionShape3D`가 계속 음수/비균일 스케일이 되고,
  Jolt Physics가 그때마다 "Failed to correctly scale body..." ERROR를 로그에 계속 찍음(초당 거의
  프레임 수만큼, 게임 자체는 정상 동작하지만 디버그 콘솔이 스팸으로 도배됨). 실제로 겪음 — 사용자가
  에디터에서 `BrainInVat/SpinningTrinket` 밑에 "스피커" NPC용 `Interactable`을 자식으로 달아놨었는데,
  한참 뒤에야 이게 원인인 걸 발견함(그 전까진 "원인 불명의 사소한 pre-existing 경고"로만 취급하고
  넘어갔었음). 고칠 때는 그 `Interactable`을 트링켓의 형제 노드로 옮기고(`Objects/BrainInVat` 밑,
  `SpeakerInteractable`로 개명) 같은 월드 위치가 되도록 `transform`을 직접 지정해서 해결 —
  `BrainInVat`엔 이미 `[editable path="Objects/BrainInVat"]`가 있어서 마커 추가는 불필요했음.
  **그래도 이 시각 효과(힌트가 같이 도는 것) 자체는 사용자가 마음에 들어해서** — `Interactable`에
  `hint_spin_speed`(기본 0 = 꺼짐) export를 새로 추가함, 켜면 `_hint`(Label3D) 자기 자신의 `scale.x`만
  같은 빌보드 플립 트릭으로 오실레이션시킴(Area3D 루트나 `CollisionShape3D`는 절대 안 건드림 — 그래서
  Jolt는 계속 조용함). `SpeakerInteractable`엔 `hint_spin_speed = 6.0`(트링켓의 `spin_speed`와 동일)을
  걸어서 다시 같이 돌게 해둠.
- **`.dialogue`의 `locals.x`는 Dialogue Manager 내장 기능이 아니라, 대화창(`analog_dialogue_balloon.gd`
  등)이 자기 자신을 `extra_game_states`로 넘길 때 그 스크립트가 갖고 있는 평범한 `var locals: Dictionary`
  프로퍼티를 찾아서 읽고 쓰는 것뿐임**. 그래서 실제 게임(Interactable → `show_dialogue_balloon()`)에서는
  잘 되지만, 헤드리스 테스트에서 `DialogueManager.get_next_dialogue_line(res, key)`를 `extra_game_states`
  없이 맨몸으로 부르면 `"locals" not found` 에러가 나고(그런데도 조용히 계속 진행돼서 `if not locals.x`가
  **항상 true로 잘못 평가됨** — 침묵 실패라 알아채기 어려움). 헤드리스로 `locals` 쓰는 대화를 테스트할 땐
  `var locals: Dictionary = {}` 프로퍼티 하나만 가진 더미 객체를 만들어서 `extra_game_states` 배열에
  넣어 넘겨야 함(`gramophone.dialogue`의 재생/스킵 분기 테스트할 때 실제로 이 삽질을 함).
- **`.dialogue` 파일 내용만 고쳤다고 헤드리스(비에디터) 실행에 바로 반영 안 됨** — import 캐시가
  마지막 `--editor` 패스 시점 내용으로 고정돼있어서, 텍스트 파일을 바꿔도 새로 `--headless --editor
  --path . --quit`을 한 번 더 돌리기 전까진 구버전 컴파일 결과가 계속 로드됨(새 이미지/오디오 파일을
  처음 추가했을 때랑 똑같은 종류의 문제 — 여긴 "신규 파일"이 아니라 "기존 파일 내용 변경"이라 더
  헷갈리기 쉬움. 실제로 이것 때문에 방금 수정한 분기 로직이 헤드리스 테스트에서 계속 구버전처럼
  동작하는 걸 보고 한참 헤맴).
- **오토로드(`DialogueManager`/`StoryFlags`/`Stats` 등)를 이름으로 직접 참조하는 스크립트는, `--headless
  --script res://_tmp_test_X.gd`처럼 맨몸 `SceneTree` 진입점으로 띄우면 컴파일 자체가 안 됨**
  (`Identifier not found: DialogueManager` 같은 에러) — 그 스크립트 안에서 `res://scenes/main.tscn`을
  `load()`+`instantiate()`해서 오토로드를 미리 "띄워봐도" 소용없음(실제로 시도해봤는데도 안 됨). 오토로드가
  전역 식별자로 풀리는 건 Godot이 `.tscn`을 **정식 메인 씬으로 직접 부팅**할 때만 일어나는 것으로 보임 —
  즉 `--headless --path . res://아무씬.tscn --quit-after N`(지금까지 잘 써온 방식)은 되고, `--script`
  진입점 안에서 아무리 다른 씬을 로드해봐도 안 됨. 그런 스크립트(예: `interactable.gd`, 대화 관련 로직)의
  실제 동작을 테스트하려면, 맨몸 `SceneTree` 스크립트 대신 **작은 더미 `.tscn` + 그 안에서 도는 스크립트를
  따로 만들어서 그 씬 자체를 정식으로 실행**해야 함(`entities/shared/interactable.gd`의 `scene_to_load`
  기능 테스트할 때 실제로 이 방식으로 우회함).
- **`Container` 안에서 형제 노드의 draw 순서는 트리 순서(뒤에 오는 형제가 위에 그려짐)를 따름 --
  `VBoxContainer`에 음수 `separation`을 줘서 두 자식을 일부러 겹치게 만들면, 뒤에 오는 자식(배경이
  불투명한 패널 등)이 앞에 오는 자식(글자가 있는 라벨/버튼 등) 위를 그대로 덮어버릴 수 있음** --
  바인더 UI의 탭 라벨(`ui/binder/binder_ui.gd`)이 겹쳐 보이는 연출을 노리고 `BookColumn`(탭바+
  바인더 프레임)에 음수 separation을 줬다가, 탭 라벨이 뒤에 그려지는 불투명한 프레임 배경 밑에
  깔려서 거의 안 보이는 버그가 남(사용자가 스크린샷으로 신고). `z_index`는 레이아웃(위치/순서)과
  무관하게 그리기 순서만 따로 바꿀 수 있어서, 탭바에 `z_index = 5`를 줘서 프레임보다 항상 위에
  그려지도록 고침 -- 겹치는 시각 효과를 negative separation으로 낼 때는 항상 위에 그려져야 하는
  쪽에 z_index를 명시적으로 줄 것.
- **처음부터 숨겨져 있던 `Control`은 그 조상 컨테이너 체인이 레이아웃을 한 번도 안 돌렸을 수 있어서,
  그 시점에 자기 `size`를 읽으면 값이 틀릴 수 있음** -- 바인더를 맨 처음 여는 순간(`Panel.show()`
  직후) `items_page.gd`의 `refresh()`가 곧바로 `size`로 카드 위치를 계산했는데, 그 위의
  `BookWrap/BookColumn/BinderFrame/PagesRoot` 체인이 지금까지 한 번도 화면에 나온 적이 없어서 실제
  레이아웃이 아직 확정 안 된 상태였음 -- 카드가 화면 왼쪽 위(탭바와 겹치는 자리)에 뭉쳐서 나타나는
  버그로 나타남(사용자가 스크린샷으로 신고). `refresh()` 맨 앞에 `await get_tree().process_frame`
  하나만 넣어서 컨테이너들이 한 번 정렬될 시간을 준 뒤에 `size`를 읽도록 고침.
- **`Container`(예: `HBoxContainer`)의 직계 자식 `Control`의 `scale`을 코드로 바꿔도, 그 컨테이너가
  다시 정렬할 때(`move_child` 등으로) 조용히 `Vector2.ONE`로 되돌아갈 수 있음** -- 바인더 탭이 랭크별로
  계단식으로 작아지게 만들려고 각 `Button`(HBoxContainer의 직계 자식)에 `scale`을 줬는데, `move_child`
  전에 주든 후에 주든 다음 프레임엔 전부 1.0으로 돌아와 있었음(헤드리스 테스트로 재현·확정). `position`/
  `size`만 컨테이너가 관리하는 줄 알았는데 실제로는 `scale`까지 건드리는 것으로 보임. 고친 방법: 그 버튼을
  컨테이너의 직계 자식이 아니라, **컨테이너 자식인 평범한(Container 아닌) `Control` "슬롯" 밑의
  손자 노드**로 한 단계 내려서 넣음 -- 슬롯은 컨테이너가 가로 배치를 관리하고, 버튼은 어떤 컨테이너 관리도
  안 받으니 `scale`/`pivot_offset`을 몇 번을 바꿔도 그대로 유지됨. 컨테이너 자식에 스케일 효과를 주고
  싶으면 이 패턴(컨테이너 자식 = 빈 슬롯, 실제 비주얼 = 그 슬롯의 자식)을 재사용할 것.
- **`Control.size`에 폰트+스타일박스 여백이 요구하는 것보다 작은 값을 대입해도 조용히 그 최소
  크기로 다시 늘어남(에러도 경고도 없음)** -- 바인더 탭을 랭크별로 계단식 높이로 줄이면서, 줄어든
  높이만큼 `position.y`도 같이 보정해서 아래쪽 끝을 한 줄에 맞추려고 했는데, `position.y` 계산에
  **요청한**(대입하려던) 높이를 썼더니 실제로 적용된(더 큰) 높이와 안 맞아서 뒤쪽 랭크 탭들의 아래쪽
  끝이 몇 픽셀씩 삐져나옴(사용자가 스크린샷으로 신고, 헤드리스로 재현·확정: `size.y=34` 요청했는데
  실제로는 `39`가 적용됨). `size.y = 값` 대입 **직후 그 프로퍼티를 다시 읽어서** 실제 적용된 값으로
  이후 계산(위치 등)을 해야 함 -- 대입에 쓴 변수를 그대로 재사용하면 안 됨. 최소 크기 자체를 줄이고
  싶으면 폰트 크기/스타일박스 `content_margin_*`을 줄일 것(`custom_minimum_size`는 최솟값을 못 낮춤 --
  실제 최소 크기와 `max()`로 합쳐질 뿐).

## TODO
- [ ] 게임 에디터로 직접 열어서 존/물병/탁구채/통속의뇌/트링켓/쓰레기천사/통통볼/인벤토리 전부
      플레이 테스트 (헤드리스 검증은 파싱 에러만 잡아줌, 실제 배치/크기/느낌은 안 봄)
- [ ] 쓰레기 천사 대화문은 예시 수준 — 다듬기
- [ ] 세계 규칙 명문화
- [ ] 엔딩 / 구조 설계
- [ ] 바인더 UI(Tab/아이템, 세이브·로드, 설정)를 실제 에디터로 열어서 탭 전환 애니메이션/
      겹친 탭 라벨 레이아웃/세이브 카드 연출이 의도대로 보이는지 확인 (헤드리스 검증은 로직만 확인함)
- [ ] "기록지"(record_paper)를 실제로 주는 이벤트/NPC/줍기 추가 -- 지금은 SaveSystem._ready()가
      시작할 때 1장을 임시로 지급함 (발광체와 같은 임시 상태)
- [ ] "기록된 날개와의 계약" 스토리 이벤트 만들어서 wings_contract_stage1/stage2
      StoryFlags를 실제로 세워주기 (지금은 세이브 슬롯이 영원히 1개로 고정된 상태)
- [ ] 엘리콘티 새 아트(마도카 마녀 스타일)에 맞춰 `Visual`의 `pixel_size`/스케일/기존 위치가 여전히
      맞는지 에디터에서 확인 — 몸통 실루엣이 이전 치비 디자인이랑 많이 달라져서 재조정 필요할 수 있음

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
