<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# `SaveSystem` (오토로드, `data/save_system.gd`) + `ui/binder/save_load_page.*` — 세이브/로드
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
