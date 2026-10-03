<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# 대화창 연출 확장 — `unskippable`/`tremble_level`/`reveal_chars_per_second` + `MutterLabel`
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
