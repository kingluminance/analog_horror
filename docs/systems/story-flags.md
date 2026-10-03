<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# `StoryFlags` (오토로드, `data/story_flags.gd`)
- `get_flag`/`set_flag`, `get_visit_count`/`increment_visit_count` — 방문 횟수 기반 첫만남/재방문
  대사 분기 (존, 물병, 탁구채가 씀)
- `set_visual_state(id, key, value)` / `get_visual_state(id, key, default)` /
  `signal visual_state_changed` — **대화가 오브젝트의 외형을 바꾸는 범용 메커니즘**. `.dialogue`
  파일에서 `using StoryFlags` + `$> StoryFlags.set_visual_state("trash_angel", "body", "...")`처럼
  호출하면, 해당 id를 구독하는 엔티티 스크립트가 반응해서 텍스처 등을 바꾼다 (쓰레기천사가 이 방식으로
  몸통 3종을 전환함). 새 오브젝트도 이 패턴을 재사용하면 됨 — 새 오토로드 만들지 말 것.
- `mark_choice_seen(id, choice_id)` / `has_seen_choice(id, choice_id)` /
  `has_seen_all_choices(id, choice_ids: Array)` — **"이 NPC의 선택지를 다 골라봤는지" 범용 메커니즘**.
  `.dialogue`에서 대화 선택지 하나를 고를 때마다 그 분기 안에서
  `$> StoryFlags.mark_choice_seen("<entity_id>", "<choice_id>")`를 부르고, 보통 `~ start`의 라우팅에서
  `if StoryFlags.has_seen_all_choices("<entity_id>", ["choice_a", "choice_b", ...])`로 전부 골랐는지
  검사해서 다 골랐으면 새 대화 타이틀(에필로그 등)로, 아니면 평소 `repeat`로 보낸다. `id`/`choice_id`는
  `flags`/`visit_counts`와 같은 호출자 임의 문자열 네임스페이스라 캐릭터별 사전 등록이 필요 없다.
  가위(목도리) NPC(`entities/floating_photo/photos/scissor_scarf.dialogue`)가 첫 실사용 예시 —
  "목도리는 뭐야?"/"여기서 사는거야?" 두 선택지를 각각 한 번씩 골라본 뒤부터는 다음 방문에 `~ beyond`
  (에필로그) 타이틀로 자동 전환된다. 새 NPC에 같은 "다 물어보면 그다음부터" 연출을 넣고 싶으면 이
  세 함수만 재사용하면 됨 — 새 오토로드나 컴포넌트 불필요.
  **단, "메뉴 전체를 다음 단계로 넘기는" 것만 됨 — 같은 메뉴 안에서 이미 고른 선택지 하나만 쏙 빼고
  나머지는 계속 같이 보이게 하려면 아래 `[if ... /]` 인라인 조건과 같이 쓸 것.**

### 선택지 하나만 조건부로 숨기기 — `[if ... /]` + `hide_failed_responses`
"같은 메뉴의 선택지 여러 개 중 이미 골라본 것만 빼고 나머지는 계속 같이 보이게" 하고 싶을 때.
**Dialogue Manager 애드온에 이미 내장된 기능**이라 새로 만들 필요 없었다 — 선택지 줄 끝에
`[if <조건> /]`(공백 + `/]`로 정확히 끝나야 함, `DMCompilerRegEx.GOTO_REGEX`와 같은 계열의
`WRAPPED_CONDITION_REGEX`가 파싱)를 붙이면 조건이 거짓인 그 선택지 하나만 메뉴에서 빠진다:
```
using StoryFlags

~ wings_menu
if StoryFlags.has_seen_all_choices("ellikonti", ["wings_what", "wings_why"])
	=> contract_menu
- 날개 [if not StoryFlags.has_seen_choice("ellikonti", "wings_what") /]
	엘리콘티: 4대 날개들.. 몰라?
	$> StoryFlags.mark_choice_seen("ellikonti", "wings_what")
	=> wings_menu
- 날개들은 왜? [if not StoryFlags.has_seen_choice("ellikonti", "wings_why") /]
	엘리콘티: 저것들을 피해서 여기까지 왔어.
	$> StoryFlags.mark_choice_seen("ellikonti", "wings_why")
	=> wings_menu
- 대화를 그만한다
	=> END
```
**단, 이것만으론 부족함** — `DialogueManager._get_responses()`는 조건이 거짓인 응답도 `is_allowed=false`
플래그만 붙여서 여전히 목록에 포함시키고, 실제로 화면에서 숨기는 건 응답 메뉴 노드
(`DialogueResponsesMenu`)의 `hide_failed_responses`(기본값 `false`) 몫이다 — 그래서 우리 커스텀
대화창 `entities/dialogue_ui/analog_dialogue_balloon.tscn`의 `ResponsesMenu` 노드에
`hide_failed_responses = true`를 켜뒀다(딱 한 번, 씬 프로퍼티 한 줄 — 애드온 소스는 전혀 안 건드림,
새 대화에서 또 켤 필요 없음).

**함정 — 조건부 선택지 여러 개를 한 메뉴로 합치려고 각자 다른 `if` 블록으로 감싸면 안 됨**: 엘리콘티
`wings_menu`에서 실제로 겪음 —
```
if not locals.seen_what
	- 날개
		...
if not locals.seen_why
	- 날개들은 왜?
		...
```
처럼 짰더니 두 선택지가 한 메뉴로 안 합쳐지고 **하나씩 따로 튀어나옴**("날개" 선택지 처리가 끝나야
"날개들은 왜?"가 떴음). 원인은 `compilation.gd`의 `parse_response_line()` — 응답 그룹은 물리적으로
연속된 `TYPE_RESPONSE` 형제 줄끼리만 하나로 묶이는데(`sibling_index`를 거슬러 올라가며 `TYPE_UNKNOWN`이
아닌 첫 줄을 "원본 응답"으로 찾는 로직), 그 사이에 `if`(`TYPE_CONDITION`) 같은 다른 타입 줄이 끼면
거기서 그룹이 끊긴다. 위 `[if ... /]` 인라인 문법을 쓰면 선택지 줄 자체는 여전히 서로 물리적으로
연속돼 있어서 한 메뉴로 묶이면서 조건만 개별 적용됨 — 이게 정석 우회법. 헤드리스로 실제
`AnalogDialogueBalloon`을 띄워서 세 상태(둘 다 안 물어봄/하나만 물어봄/둘 다 물어봄)에서
`responses_menu`에 실제로 보이는 버튼 텍스트를 직접 확인함.

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
