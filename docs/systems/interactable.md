<!-- CLAUDE.md에서 분리됨. 내용은 원문 그대로. 개요: ../ARCHITECTURE.md -->

# 공용 E-상호작용 컴포넌트 — `entities/shared/interactable.gd`
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

## 시선 가림 판정 (2026-10-14)

물체에 가려진 NPC에게는 말을 걸 수 없다. `_process`에서 범위·시선 각도 다음에 `_has_line_of_sight()`로
카메라 → 힌트 지점(`global_position + hint_offset`)에 레이를 쏴서, **시선 차단 레이어(physics layer 2,
`Interactable.SIGHT_BLOCKER_LAYER`)**에 맞으면 그 프레임 후보에서 빠진다(힌트 안 뜸, E 무시). `_best`가 이미
이 검사를 통과한 인스턴스만 되므로 `_unhandled_input`은 따로 레이를 안 쏜다.

- **계기**: 엘리콘티에게 나무 뒤에서 말을 걸면 계약 연출 카메라가 나무 줄기에 가려짐. "연출 위치 조정" 대신
  "가려지면 아예 대화 못 걸게"를 사용자가 선택.
- **막는 것**: 레이어 2에 있는 것만. 나무 줄기는 `main.tscn`의 `Trees`에 붙은 `entities/shared/sight_blockers.gd`가
  시작할 때 `Trunk` 메시마다 볼록 충돌체(레이어 2, mask 0 -- 플레이어는 여전히 나무를 통과)를 붙여줌.
  통나무집 `Body`는 `collision_layer = 3`(1 + 2).
- **막지 않는 것**: 일반 충돌(레이어 1)은 시선을 막지 않음 -- 보이지 않는 `WorldBoundary` 벽이 보따리상인
  천막과 겹쳐 있어서 상인에게 말을 못 걸게 됐었음. 나뭇잎도 제외 -- 나무 밑에 서면 카메라가 잎 원뿔 안에
  들어가서 모든 레이가 막혔음.
- 자기 엔티티의 충돌체(Interactable 부모 밑 전부)와 플레이어 몸은 항상 제외.
- 일부러 벽 너머로도 말 걸 수 있어야 하는 건 `require_line_of_sight = false`.
- 새 가림 물체를 추가하면: 레이어 2를 켜거나(`collision_layer`에 2 더하기), 장식 메시 묶음이면 부모에
  `sight_blockers.gd`를 붙이고 `mesh_name_filter` 지정.
