<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# NPC / 오브젝트 목록
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
  **대화 자체는 그 뒤로 사용자가 직접 훨씬 크게 다시 씀** — `first_meet` → `wings_menu`(날개
  얘기 선택지) → `contract_menu` → `contract_story`(계약 사연 독백, `repeat`은 계약 체결 이후의
  완전히 다른 분위기) 구조로 확장됨. `wings_menu`는 "날개"/"날개들은 왜?" 두 선택지를 각자 골라본
  뒤부터는 다음 방문에 `contract_menu`로 자동 전환되는 걸 `StoryFlags.has_seen_all_choices`로
  구현(위 참고) — 처음엔 그 두 선택지를 각각 다른 `if` 블록으로 감싸서 조건부로 숨기려다가 "위
  선택지 하나만 조건부로 숨기기" 항목의 함정을 그대로 겪음(한 메뉴로 안 합쳐지고 하나씩 튀어나옴)
  → `[if ... /]` 인라인 조건 + `hide_failed_responses`로 해결.
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
- **보따리로 판매합니다** (`entities/bottari_merchant/`) — `scenes/main.tscn`의 `Objects/BottariMerchant`에
  배치, 사용자가 직접 에디터에서 천막(`천막`, `res://entities/bottari_merchant/tent/천막.fbx` 임포트,
  300배 스케일 보정) 안쪽에
  자리잡음. 자물쇠 얼굴(`Face`, 그린스크린 사진을 flood-fill 크로마키)이 중심에서 `floating_photo.gd`와
  같은 sine bob으로 가볍게 떠 있고, 눈알 달린 열쇠꾸러미 사진(베이지색 배경이라 `rembg`로 배경 제거)
  두 장(`CompanionA`/`CompanionB`)이 각자 독립적으로 랜덤한 위상/속도로 느리게 둥둥 떠다님(단순
  `billboard=1` 독립 적용, `recorded_wings.gd`의 `look_at()` 트릭은 안 씀 — 고정된 상대 각도를 유지할
  필요가 없는 케이스라서). 천막 안에는 이 상인 말고도 사용자가 직접 만든 선반(`ShelfUnit`, 판자 4단 +
  기둥 2개)/진열대(`DisplayStand`)/랜턴(`Lantern`, 케이지 프레임 + 발광 코어 + `OmniLight3D`, 오렌지~노랑
  계열 따뜻한 빛)/상자류(`Crates`, Kenney Pirate Kit CC0 에셋 crate/crate-bottles/barrel/chest, glTF로
  받음 — FBX보다 스케일이 안정적)가 같이 있음. 이 오브젝트들은 전부 천막의 300배 스케일 밑에서 로컬
  스케일을 정확히 `1/300`으로 맞춰서 붙임(아래 "천막 300배 스케일" 함정 참고) — 그래야 `mesh.size`에
  적은 숫자가 그대로 실제 미터 단위로 나옴.

  **상호작용은 네 갈래**(예전엔 `ShopWatcher`로 반원 UI를 열었었는데, "그건 다른 상인용으로 아껴두고
  싶다"는 요청으로 전부 떼어내고 새로 짬):
  1. **입장 자동 인사** — Area3D `body_entered`가 아니라 매 프레임 거리 체크 + **두 겹 반경(히스테리시스)**로
     구현(`entrance_trigger_radius`=4.5m 안쪽이면 발동, `entrance_reset_radius`=7m 밖으로 완전히 나가야
     재발동) — 처음엔 Area3D 한 겹으로 만들었다가, 좁은 천막 안에서 왔다갔다 하면 경계선을 계속
     넘나들면서 인사가 반복 발동하는 버그가 남(사용자가 직접 발견해서 리포트). 발동하면 대화
     (`bottari_merchant.dialogue`)가 열리면서 동시에 플레이어 카메라가 상인 얼굴로 돌아감.
  2. **상인한테 직접 E** — `Interactable`(기본 대화형 컴포넌트) 재사용, `bottari_merchant_chat.dialogue`로
     잡담(입장 인사와는 다른 대사, 카메라 강제 전환도 없음).
  3. **카운터 위 아이템에 E** — `CounterItems` 밑 아이템 3개(안 맞는 열쇠 2너/눈이 달린 열쇠고리 4너/이미
     잠긴 자물쇠 7너, 전부 placeholder), 각자 독립 `Interactable` + `*_confirm.dialogue`("가져가시겠소?"
     예/아니요). 예를 고르면 플래그가 서고, 대화가 끝나는 순간 **배달 미니 컷씬**이 돎: 가장 가까운(안
     바쁜) 열쇠꾸러미 동반자가 그 아이템 위치로 날아가서 아이템을 자기 자식으로 재부모화(같이 들고
     움직이는 것처럼 보이게)한 뒤 플레이어 쪽으로 날아가 `Inventory.give_item()`으로 전달하고 원래
     자리로 복귀. 이 전체 과정 동안 플레이어 입력은 완전히 잠기고(`player.set_cutscene_lock()`), 카메라는
     매 프레임 `player.force_look_at()`을 다시 불러서 날아다니는 열쇠꾸러미를 계속 트래킹함.
  4. **잡담 대화의 "아이템을 판매한다" 선택지** — 플레이어가 갖고 있는 아이템을 거꾸로 상인한테
     파는 흐름. `entities/shared/sell_watcher.gd`/`.tscn`(새 재사용 컴포넌트, `shop_watcher.gd`의 판매 버전)를
     `SellWatcher` 자식으로 드롭인하고 `default_sell_price`/`default_sell_line`/`sell_overrides`/
     `open_flag`만 채우면 끝 — `.dialogue`는 정적 텍스트라 "지금 갖고 있는 아이템 목록"처럼 매번
     개수가 달라지는 걸 대화 선택지로 나열할 수 없어서, `ui/shop/sell_list_ui.gd`/`.tscn`(재사용 가능한
     고정 크기 스크롤 리스트 모달, `shop_ui.gd`와 같은 "단일 모달/일시정지/명시적 닫기 버튼" 규칙)로
     따로 뺌. 목록은 `Inventory.get_owned_items()`에서 "너"(화폐) 자기 자신만 빼고 그대로 가져오고,
     `sell_overrides`(`data/shop/sell_override.gd`, `item_id`/`price`/`line`/`sellable` 4필드 리소스)에 있는
     아이템만 개별 가격+반응 대사, 나머지 전부는 `default_sell_price`/`default_sell_line` 하나로 통일.
     **`sellable = false`로 고정해둔 특정 아이템은 상인이 아예 안 사** — 목록에선 사라지지 않고 계속
     보임("판매 불가"로 표시), 클릭하면 판매가 아니라 `line`을 거절 대사로 보여줌 — 아이템 자체를
     목록에서 아예 빼는 게 아니라 "왜 못 파는지" 보여주는 식을 취함. 리스트 맨 아래엔 "안 팔아요." 항목도
     항상 있음(패널의 닫기 버튼과 별개로, 구매 쪽 "아니요" 선택지와 같은 급의 명시적 취소 수단).

- **가위(목도리)** (`Objects/ScissorScarf`) — floating_photo 베이스 재사용. 가위 날에 자주색
  목도리가 감긴 사진 — 다른 floating_photo NPC들과 같은 "이상한 게 원래 거기 있던 것처럼" 톤.
  원본 이미지가 이미 알파 채널로 배경 제거되어 있어서 별도 flood-fill/rembg 작업 없이 바로 씀
  (`entities/floating_photo/photos/scissor_scarf.png` + `.dialogue`), `pixel_size=0.000977`로
  약 1.5m 높이. 대화 speaker 이름은 "가위"
