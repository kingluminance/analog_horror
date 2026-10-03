<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# `Inventory` (오토로드, `data/inventory.gd`) + `ui/binder/items_page.*`
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

### 스탯 소모 피드백 UI (`ui/stat_loss_toast.*` + `ui/stat_loss_gauge.gd`)
`Stats.set_stat`/`add_stat`이 아무 스탯이든 실제로 "줄이면"(늘어날 땐 안 뜸) 화면 정중앙 상단에 잠깐
떴다 사라지는 팝업 — `ui/item_toast.gd`와 같은 생명주기(페이드인→유지→페이드아웃, 큐 없음, 표시
도중 또 뜨면 그냥 끊고 새로 시작)를 따르되 위치만 상단 중앙. `data/stats.gd`에 새로 추가한
`stat_delta_changed(stat_id, old_value, new_value)` 시그널(기존 `stat_changed(stat_id, value)`는
그대로 — `items_page.gd`가 그걸 계속 씀, 순수 추가) 하나만 듣고 동작함. 이번에 줄어든 스탯 개수만큼만
(1개일 수도 여러 개일 수도) `ui/stat_loss_gauge.gd`(`ui/stat_gauge.gd`를 상속한 서브클래스 —
`ui/shop/shop_item_card.gd`가 `inventory_polaroid.tscn`을 상속한 것과 같은 패턴) 게이지가 나란히
뜨고, 각 게이지 밑에 `"유연성 -4"`처럼 부호 있는 숫자가 붙음. 바늘은 부드러운 트윈이 아니라 **정수
1칸당 한 번씩 딸깍 끊어지는 스텝 애니메이션**으로 옛 값에서 새 값까지 움직이고, 매 스텝마다 새로
합성한 `audio/stat_tick.wav`가 남(2개 이상 동시에 줄면 완전히 같은 타이밍이 아니라 살짝 엇갈리게
스태거해서 더 또렷하게 들림). 같은 프레임에 스탯이 여러 개 줄면(대화 한 블록에서 `$>`를 여러 번
부르는 경우 등) `await get_tree().process_frame`으로 한 번에 묶어서 팝업 하나로 합침. `layer=110`으로
대화창(`layer=100`)보다 위에 그려서, 대화 중 `$> Stats.add_stat(...)`로 생긴 감소도 balloon에 가려지지
않고 바로 보임. 스탯 이름을 하나도 하드코딩 안 해서 `register_stat()`으로 새 스탯이 생기면 자동으로
이 팝업 대상에도 포함됨(레벨처럼 `clamp_to_max=false`인 성장형 스탯이 줄어도 예외 없이 뜸 — 스탯
이름을 어디도 하드코딩 안 하는 이 프로젝트 전체 철학을 그대로 따름).
