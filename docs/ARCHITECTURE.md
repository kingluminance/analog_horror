# ARCHITECTURE

코드베이스 지식 그래프(codebase-memory)의 `get_architecture` 결과를 정리한 문서다.
기획/세부 규칙은 `CLAUDE.md`, 이 문서는 **모듈 간 의존 구조**만 다룬다.

> 인덱싱 기준: 2026-10-04, 워크트리 `godot-github-obsidian-access-a89c6d` 스냅샷
> (노드 1,199 / 엣지 2,523). 이후 추가된 코드는 반영되지 않았을 수 있다.

## 패키지 구성

| 패키지 | 노드 수 | 역할 |
|---|---|---|
| `addons/` | 504 | Dialogue Manager v4.1.0 (외부 애드온, 수정 안 함) |
| `entities/` | 81 | 오브젝트/NPC 하나당 폴더 하나 (스크립트+씬+전용 리소스) |
| `ui/` | 78 | 바인더(Tab/Esc 모달), 상점, 토스트, 게이지 |
| `data/` | 43 | 오토로드 상태 저장소 (플래그/인벤토리/스탯/세이브/화폐) |
| `audio/` | 3 | 루프 재생기, 정적 글리치 |
| `scenes/` | 2 | 타이틀 화면 등 (`main.tscn` 등 씬 파일 위주) |

## 계층과 의존 방향

```
entities (entry, 바깥으로 호출만 함)
   ├──▶ data      (22 호출)
   ├──▶ addons    (13 호출)  ← Dialogue Manager
   └──▶ ui        (5 호출)
ui (internal)
   └──▶ data      (23 호출)
data (core, 45 in / 0 out)     ← 아무것도 호출하지 않는 최하층
addons (core, 13 in / 0 out)
```

- **`data`는 최하층**이다. 다른 패키지를 호출하지 않고, `ui`와 `entities`가 모두 여기에 의존한다.
  새 상태가 필요하면 새 오토로드를 만들지 말고 `StoryFlags`/`Inventory`/`Stats`를 재사용한다.
- **`ui`는 `data`만 본다.** `entities`에서 `ui`로 가는 호출(5)은 상점/판매 UI 열기 등 소수다.
- **`entities` 사이의 직접 의존은 없다.** 공용 로직은 `entities/shared/`로 뽑는다.

## 핵심 허브 (fan-in 상위)

프로젝트 코드 중에서 가장 많이 호출되는 것:

- `data/story_flags.gd` `get_flag` (8) — 대화/오브젝트가 플래그로 분기하는 중심점
- `data/inventory.gd` `give_item`/`has_item`/`remove_item`, `data/stats.gd` `get_stat` — 구매·UI·세이브가 함께 씀

애드온 쪽 상위(`translate` 31, `get_setting` 17 등)는 Dialogue Manager 내부 호출이라 우리 코드와 무관하다.

## 기능 클러스터

그래프의 응집도 높은 묶음(프로젝트 코드만):

| 클러스터 | 대표 심볼 | 설명 |
|---|---|---|
| 세이브/로드 | `save_to_slot`, `load_from_slot`, `save_load_page` | `SaveSystem` + 바인더 [세이브/로드] 탭 |
| 인벤토리·상점 | `get_flag`, `give_item`, `_attempt_purchase` | `StoryFlags`/`Inventory`/`ShopUI` |
| 스탯 | `get_stat`, `get_max`, `_rebuild_gauges` | `Stats` + 게이지 UI |
| 대화창 | `apply_dialogue_line`, `skip_typing` | `AnalogDialogueBalloon`/`AnalogDialogueLabel` |
| 상호작용 | `show_dialogue_balloon`, `_get_player` | `Interactable` (카메라 시선 + 근접 + 가장 가까운 것 1개) |

## 오토로드

`StoryFlags`, `Inventory`, `Stats`, `SaveSystem`, `DialogueManager`. `Currency`는 오토로드가 아니라
상수만 가진 `class_name`이다. 세부 API는 `CLAUDE.md`의 해당 항목 참고.

## 인덱스 한계 (이 문서를 읽을 때 주의)

- GDScript의 일부가 그래프에 안 잡힌다. 특히 `addons/dialogue_manager/dialogue_manager.gd` 576~1980줄,
  `components/code_edit.gd` 전체는 파싱 실패/부분 파싱이다 → 직접 소스를 읽을 것.
- `.tscn`/`.dialogue`/`.gdshader`는 그래프 대상이 아니라서, **씬 간 연결(인스턴스 관계)은 이 문서에 없다.**
  씬 구조는 `CLAUDE.md`의 "코드 구조"와 실제 `.tscn`을 볼 것.
- 파일 트리의 엔티티 목록은 인덱싱 시점 기준이며, 이후 추가된 엔티티(예: 가위)는 빠졌을 수 있다.
- 호출 그래프는 정적 분석이라 시그널 연결(`visual_state_changed` 등)과 `.dialogue`의 `$>` 호출은 엣지로 안 보인다.
