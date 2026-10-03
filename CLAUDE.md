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
구조는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) 참고.

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
  │       (john, ping_pong_bottle, brain_in_vat, scissor_scarf)
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

## 핵심 아키텍처 (상세는 `docs/systems/`)

의존 구조 개요는 [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). 시스템별 상세 문서 — **해당 시스템을 건드리기 전에 읽을 것**:

| 문서 | 내용 |
|---|---|
| [interactable.md](docs/systems/interactable.md) | 공용 `[E]` 상호작용 컴포넌트 (대화형 오브젝트는 이걸 인스턴스, 로직 복붙 금지) |
| [story-flags.md](docs/systems/story-flags.md) | `StoryFlags`(플래그/방문횟수/외형상태/선택지), 선택지 조건 숨기기, `DialogueVisibility` |
| [dialogue-ui.md](docs/systems/dialogue-ui.md) | 대화창 연출(`unskippable`/`tremble_level`/`reveal_chars_per_second`), `MutterLabel` |
| [inventory-stats.md](docs/systems/inventory-stats.md) | `Inventory`, `Stats`, 스탯 소모 피드백 UI |
| [shop.md](docs/systems/shop.md) | `Currency`("너"), `ShopUI`/`ShopWatcher` |
| [binder-ui.md](docs/systems/binder-ui.md) | Tab/Esc 통합 모달(아이템·세이브/로드·설정 탭) |
| [save-system.md](docs/systems/save-system.md) | `SaveSystem`, 기록지, 세이브 슬롯 |
| [npcs.md](docs/systems/npcs.md) | NPC/오브젝트별 구현 메모 (존, 물병, 축음기, 엘리콘티, 상인 등) |
| [pitfalls.md](docs/systems/pitfalls.md) | 알려진 함정 / 버그 수정 이력 (GDScript 타입 추론, Container scale, .tscn 주석 등) |

**핵심 규칙 요약** (이유와 사례는 위 문서):
- 대화 가능한 오브젝트는 `entities/shared/interactable.tscn`을 자식으로 인스턴스, 로직 복붙 금지
- 외형/상태 변화는 `StoryFlags`(`set_visual_state` 등) 재사용, **새 오토로드 만들지 말 것**
- 대화에서 씬 전환 등 `get_tree()`가 필요하면 플래그만 세우고 옆의 Watcher 노드가 처리
- `Interactable`을 계속 회전/스케일 변하는 노드 밑에 두지 말 것 (Jolt 에러 스팸)
- 새 NPC마다 `hint_offset`은 "플레이어가 실제로 쳐다볼 지점"으로

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
- **새 에셋(사진/FBX/텍스처 등)을 드래그해서 넣을 때 프로젝트 루트에 그냥 떨어뜨리지 말 것** —
  Godot 에디터에 파일을 드롭하면 기본적으로 열려있는 폴더(대개 루트)에 그대로 들어가는데, 방치하면
  루트가 지저분해짐. 실제로 `천막.fbx`/`천막_0.png`/`천막2.fbx`/`천막2_0.png`(+`.tscn`)와
  `WoodFloor064*.png` 3종이 전부 루트에 쌓여있던 걸 나중에 발견해서, 천막 관련 파일은
  `entities/bottari_merchant/tent/`로(전용 리소스라 엔티티 폴더 규칙), WoodFloor 텍스처는 `materials/`로
  (여러 오브젝트가 공유할 수 있는 셰어드 텍스처라 공용 폴더 규칙) 옮김 — 파일을 옮긴 뒤에는 그 파일을
  참조하는 모든 `.tscn`의 `path=`와 `.import`의 `source_file=`을 새 경로로 고치고,
  `--headless --editor --path . --quit`을 한 번 더 돌려서 재임포트/uid 재연결까지 확인해야 함
  (텍스트만 고치고 헤드리스 재임포트를 안 돌리면 캐시가 예전 경로 기준으로 남아있을 수 있음).
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

## 알려진 함정

전체 목록은 [docs/systems/pitfalls.md](docs/systems/pitfalls.md). 자주 걸리는 것만:
- `:=` 타입 추론은 서브클래스 프로퍼티/Dictionary 조회/타입 없는 배열 순회에서 실패 → 명시적 타입 사용
- `Container` 직계 자식의 `scale`은 정렬 때마다 초기화됨 → 빈 슬롯 `Control` 밑 손자로 내릴 것
- `Control.size`는 최소 크기 미만이면 조용히 늘어남 → 대입 직후 다시 읽을 것
- `.tscn`엔 주석 문법이 없음 (파싱 깨짐)
- 오토로드 참조 스크립트는 `--script` 진입점으로 못 돌림 → 더미 `.tscn`으로 실행

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
- [ ] 천막 안 소품들(상인/선반/진열대/랜턴/상자류)의 정확한 위치/크기를 에디터에서 직접 보고 조정
      (전부 감으로 배치함, 실제 천막 내부 형태를 못 보고 작업해서)
- [ ] `bottari_merchant.dialogue`/`bottari_merchant_chat.dialogue`의 대사 화자 이름이 "보따리장수"가 아니라
      "판매하겠습니다"로 되어있음 -- 사용자가 직접 편집하면서 바뀐 것인데 의도적인건지(새 캐릭터 이름/콘셉)
      실수인지("판매하겠습니다:" 가 대사로 써내려다 화자 이름으로 파싱된 것일 수도) 아직 확인 안 됨
- [ ] 화폐 "너"의 실제 획득 경로 추가 -- 지금은 SaveSystem._ready()가 시작할 때 10을 임시로 지급함
      (기록지/발광체와 같은 임시 상태)
- [ ] 스탯 소모 피드백 팝업(`ui/stat_loss_toast.*`)과 상점 UI(`ui/shop/shop_ui.*`)를 실제 에디터로
      열어서 레이아웃/애니메이션 타이밍이 의도대로 보이는지 확인 (헤드리스 검증은 로직만 확인함)

## 새 오브젝트 추가할 때
1. `entities/<새이름>/` 폴더 생성
2. **대화 가능한 오브젝트면** `entities/shared/interactable.tscn`을 자식으로 인스턴스하고
   `dialogue_resource`만 연결 — 상호작용 로직을 직접 짜지 말 것
3. 사진 기반이면 `floating_photo.tscn`을 상속/복제, 텍스처만 갈아끼움
4. 배경 제거: 기본은 "고정 밝기 + 무채색 기준 flood fill"(존 참고), 배경과 피사체 밝기가 비슷하면
   `rembg` AI 세그멘테이션(물병/통속의뇌 참고)
5. "대화 진행에 따라 외형이 바뀌어야" 하면 `StoryFlags.set_visual_state`/`get_visual_state` 재사용
   (쓰레기천사 참고), 새 오토로드 만들지 말 것
6. "선택지를 다 골라보면 그 다음부터 다른 대화가 나오게" 하고 싶으면 `StoryFlags.mark_choice_seen`/
   `has_seen_all_choices` 재사용(가위(목도리) 참고) — 선택지 분기마다 `mark_choice_seen` 한 줄, `~ start`
   라우팅에 `has_seen_all_choices` 조건 한 줄이면 끝
7. "같은 메뉴 안에서 이미 골라본 선택지 하나만 빼고 나머지는 계속 같이 보이게" 하고 싶으면
   선택지 줄 끝에 `[if not StoryFlags.has_seen_choice("<id>", "<choice_id>") /]`(엘리콘티 `wings_menu`
   참고) — **절대 조건을 별도 `if` 블록으로 감싸지 말 것**(한 메뉴로 안 합쳐지고 하나씩 튀어나옴)

## 레퍼런스
- Midsommar (2019) — 낮 공포의 정서
- LSD Dream Emulator — 세계의 규칙
- Yume Nikki — 탐험형 구조
