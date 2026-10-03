<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# 알려진 함정 / 버그 수정 이력
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

- **`.tscn` 파일 안에는 GDScript 스타일 `##`/`#` 주석을 못 씀** -- 씬 텍스트 포맷은 스크립트가 아니라서
  일반적인 주석 구문이 아예 없음. `천막` 밑에 새 노드를 추가하면서 설명용 `##` 블록을 그 노드
  프로퍼티 구역 안에 실수로 넣었더니, 그 다음 노드(`shelf`)의 파싱이 통째로 깨져서 "Parent path ...
  has vanished when instantiating" 경고 + 이후 그 노드를 스크립트에서 `$이름`으로 찾으려던 다른 코드까지
  연쇄로 터짐(`Node not found` 에러). 헤드리스로 재현·확정 후 그 주석 블록만 제거해서 해결 -- `.tscn`에
  뭔가 설명을 남기고 싶으면 관련 `.gd` 스크립트의 독스트링에 적을 것.
- **GDScript 타입 추론은 Dictionary 조회/느슨하게 타입된 배열 순회 결과에도 실패함** -- 위 "타입 추론 +
  서브클래스 프로퍼티" 항목과 같은 계열의 함정을 이번 세션에서 세 번 더 겪음: (1) `for node in
  [$CompanionA, $CompanionB]:`처럼 타입 없는 배열 리터럴을 순회하면 `node`가 Variant로 추론돼서 그 뒤
  `var d := node.global_position.distance_to(...)`가 "타입을 추론할 수 없음" 에러를 냄, (2) `var
  busy: bool = dict[key] or dict[key2]`처럼 Dictionary 값 조회를 `:=`로 받으면 마찬가지로 실패. 둘 다
  `var x: float = ...`/`var x: bool = ...`처럼 **명시적 타입을 써서** 우회함 -- `:=`는 우변이 진짜
  정적으로 타입이 확정되는 표현식(리터럴, 타입이 박힌 함수 리턴값 등)일 때만 믿을 것.
- **천막(`res://entities/bottari_merchant/tent/천막.fbx`) 300배 스케일 밑에 새 오브젝트를 넣을 때는 로컬 스케일을 정확히 `1/300`
  균일로 맞출 것** -- 원본 FBX가 작게 들어와서 씬에 넣을 때 300배로 키워뒀는데(`천막` 노드 자체의
  Transform3D), 그 자식으로 새 메쉬/조명을 넣으면서 스케일을 손으로(스케일 기즈모로) 맞추다 보면 축마다
  비율이 미묘하게 달라지기 아주 쉬움(예: `0.0332`/`0.0017`/`0.0028`처럼) -- 부모의 300배와 합성되면
  실제 세계 좌표 기준으로 심하게 눌리거나 늘어난 모양이 나옴(길쭉한 판자처럼 찌그러짐, 사용자가
  스크린샷으로 신고). 고치는 법: 로컬 스케일을 세 축 다 정확히 `0.0033333333`(=1/300)으로 주고, 실제
  치수는 `mesh.size`(BoxMesh 등) 쪽에서 미터 단위로 직접 조절 -- 그러면 부모 스케일이 정확히 상쇄돼서
  숫자 그대로가 실제 크기가 됨. 천막 안의 선반/진열대/랜턴/상자 전부 이 패턴으로 통일함.
