<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# `Currency`/상점 시스템 — 화폐 "너" + 재사용 가능한 상점 UI
새 오토로드를 또 만드는 대신("재사용... 새 오토로드 만들지 말 것" 관례를 그대로 따름), 화폐 "너"는
`data/currency.gd`(오토로드 아님, 그냥 `class_name Currency`)가 `Currency.ID`/`Currency.DISPLAY_NAME`
상수만 들고 있고, 실제 보유량은 그냥 `Inventory.get_count(Currency.ID)`임 — `Stats.register_stat()`으로
등록하지 않은 이유는, 그러면 [아이템] 탭 스탯 게이지 줄에 화폐가 RPG 바늘처럼 같이 떠버려서 "돈"
느낌과 안 맞기 때문. `Currency.register_and_seed(starting_amount=10)`을 `SaveSystem._ready()`에서
한 번 불러 테스트용으로 10을 임시 지급함(기록지/발광체와 같은 "게이트는 진짜, 획득 경로는 나중"
상태) — 부작용으로 [아이템] 탭 폴라로이드 더미에 "너"도 그냥 아이템처럼 같이 보이는데, 의도한 건
아니지만 잔액 확인용으로 나쁘지 않아서 그대로 둠.

상점 자체는 상인마다 다른 목록을 가질 수 있게 완전히 데이터 기반으로 설계됨:
- `data/shop/shop_item.gd` — `class_name ShopItem extends Resource`, `item_id`/`display_name`/
  `texture`/`description`/`price`. 상인 하나당 이 리소스 여러 개(`.tres` 파일 또는 씬 안에 인라인)로
  자기 판매 목록을 가짐.
- `entities/shared/shop_watcher.gd`/`.tscn` — `interactable.tscn`/`mutter_label.tscn`처럼 아무 NPC에나
  자식으로 드롭인하는 재사용 컴포넌트. `@export shop_items`/`shop_title`/`open_flag`만 채우면 끝 —
  `cabin_door_watcher.gd`와 완전히 같은 "대화가 플래그를 세우고, 옆의 감시 노드가 실제 동작(여기선
  상점 UI 열기)을 함" 패턴을 그대로 재사용(`Interactable`은 평범한 `dialogue_resource`만 쓰고 전혀
  안 건드림). **`open_flag`는 상인마다 반드시 서로 다른 고유 문자열이어야 함** — 여러 상인이 같은
  플래그를 공유하면 한 상인과의 대화가 끝나는 순간 다른 상인의 `ShopWatcher`도 동시에 반응해버릴 수
  있음(수동 유일성 관례, `StoryFlags`의 `visit_counts`/`visual_states` id들과 같은 종류의 규칙).
- `ui/shop/shop_ui.gd`/`.tscn` — `class_name ShopUI extends CanvasLayer`, 딱 하나만 씬에 존재
  (`scenes/main.tscn`의 `ShopUI` 노드, `layer=55`). `open_shop(items, title)`/`close_shop()`/
  `is_modal_open()` + `purchase_succeeded`/`purchase_failed` 시그널. `ShopWatcher`는
  `get_tree().get_first_node_in_group("shop_ui")`로 이 인스턴스를 찾음. 아이템 카드를 **플레이어
  앞쪽으로 펼쳐진 반원(부채꼴)** 모양으로 배치(2D 화면 좌표 오버레이, 3D 월드 배치 아님) — 클릭하면
  `Inventory.has_item(Currency.ID, price)`를 검사해서 살 수 있으면 차감+지급, 없으면 "돈 부족" 피드백만
  주고 끝. 바인더처럼 열려있는 동안 `get_tree().paused = true`이고, `binder_ui.gd`와 같은 `"modal_ui"`
  그룹에 자기도 등록해서 두 모달이 동시에 뜨는 걸 막음 — 다만 Esc 처리 우선순위가 바인더 쪽과 꼬일 수
  있어서(둘 다 `ui_cancel`을 씀) 안전하게 자체 "나가기" 카드를 항상 기본 닫기 수단으로 둠.
- `ui/shop/shop_item_card.gd`/`.tscn` — `ui/inventory_polaroid.tscn`을 상속한 씬(가격 라벨 + 구매
  가능 여부에 따른 어둡게 표시 추가), 카드 레이아웃을 처음부터 새로 만들지 않고 재사용.

**새 상인을 추가할 때 코드 수정이 전혀 필요 없음** — `entities/<새상인>/`에 `Interactable`(짧은 인사
대화, 마지막에 `$> StoryFlags.set_flag("<고유 플래그>", true)`) + `ShopWatcher`(자기만의
`shop_items`/`open_flag`) 두 컴포넌트만 인스턴스하면 끝, 아래 `보따리로 판매합니다`가 이 패턴의 첫
실사용 예시. **단, `보따리로 판매합니다`는 실제로는 이 경로를 안 씀** -- 처음엔 첫 실사용 예시로
붙여놨었는데, 나중에 "반원 카드 UI는 다른 상인용으로 아껴두고 싶다"는 요청으로 떼어냄(아래 NPC
항목 참고). `ShopWatcher`/`ShopUI` 자체는 코드베이스에 그대로 남아있어서 다음 상인이 이 경로의 첫
실사용 예시가 될 예정.
