# Gourmet GO — Hackathon Build TODO

Build in strict tier order. **Tier 3 is cuttable without breaking the demo.**

See [flame_implementation.md](flame_implementation.md) for full architecture and phased build plan.

---

## Implementation Progress (feature/flame-game branch)

### COMPLETED — Foundation Layer

| What | Files | Notes |
|------|-------|-------|
| Data models | `lib/models/dish.dart`, `skill_level.dart`, `chef_profile.dart`, `customer_order.dart`, `day_summary.dart`, `ramen_variety.dart` | All models per spec. `Dish` resolved merge conflict: int `rarityTier`, `effectivePrice`, `rarityLabel`, `fromJson`/`toJson`, `starterBowls`. |
| Theme | `lib/theme/app_theme.dart`, `game_colors.dart` | Dark theme + game palette constants. |
| Consolidated providers | `lib/providers/game_providers.dart` | Single file: `cashProvider`, `chefProvider`, `menuProvider`, `gamePhaseProvider`, `dayProvider`, `regionUnlockProvider`, `ftueCompleteProvider`, `chefCookTimeProvider`. Merged from `feat/ftue`. |
| Supporting providers | `lib/providers/customer_queue_provider.dart`, `upgrade_provider.dart` | Kept separate (not in `game_providers.dart`). |
| Dependencies | `shared_preferences`, `flutter_riverpod`, `flame_riverpod` v5.5.3 in pubspec.yaml | — |
| Flame entry point | `lib/main.dart`, `lib/game/gourmet_go_game.dart` | `ProviderScope` → `MaterialApp` → `RiverpodAwareGameWidget`. `GourmetGoGame` has `GameOverlay` enum, scene helpers (`showHud`, `openCamera`, `showMapInfo`, `showDaySummary`), and `pendingRegionId`. Merged from `feat/ftue`. |
| Worlds | `lib/game/worlds/shop_world.dart`, `map_world.dart` | `ShopWorld` mounts chef + queue + timer, shows/hides HUD. `MapWorld` renders 4 `RegionNode`s. |
| Chef mechanics | `lib/game/components/chef/chef_entity.dart`, `cook_behavior.dart`, `chef_state.dart` | `ChefEntity` holds cook queue + wires `OrderDispatcher`. `CookBehavior`: Available → Cooking → Plating state machine. Earns cash via `cashProvider` on serve. |
| Progress bar | `lib/game/components/kitchen/progress_bar_component.dart` | Canvas-rendered fill bar; used for cook progress and patience. |
| Customer system | `lib/game/components/customer/customer_entity.dart`, `wait_behavior.dart`, `speech_bubble_component.dart`, `customer_state.dart` | Mechanical only. Tap bubble → `OrderDispatcher.assign()`. Patience countdown via `WaitBehavior`. |
| Customer spawning | `lib/game/components/customer/customer_queue_component.dart` | Spawns up to 8 customers per day, ~30s apart. |
| Kitchen infrastructure | `lib/game/components/kitchen/order_dispatcher.dart`, `service_timer_component.dart` | `OrderDispatcher` routes orders to chef. `ServiceTimerComponent` 240s countdown → triggers `showDaySummary()`. |
| Map region nodes | `lib/game/components/map/region_node.dart` | Tappable circle per region; dimmed when locked. Tap → `showMapInfo(regionId)`. |

### NEXT — Pick Up Here

Build these in order. Each task references the architecture in `flame_implementation.md`.

**1. Overlays** (`lib/overlays/`)
- `hud_overlay.dart` — `ConsumerWidget`: cash balance (watches `cashProvider`), day timer (reads `ServiceTimerComponent.remainingSeconds` via game ref), bottom bar with camera icon + map icon
- `camera_overlay.dart` — `image_picker` + `GuideService.identifyAsDish()` + scanning animation (reuse pattern from deprecated `CameraScreen`). On success: `ref.read(menuProvider.notifier).addDish(dish)` + `ref.read(regionUnlockProvider.notifier).unlock(...)`. On failure (confidence < 0.6): show starter bowl picker. Pauses `ServiceTimerComponent` while open.
- `map_info_overlay.dart` — bottom sheet for `game.pendingRegionId`: region name, ramen type, `arrivalQuote`, "Enter Shop" CTA → `game.switchScene(ShopWorld, 'shop')`
- `day_summary_overlay.dart` — reads `customerQueueProvider` for served/missed counts, computes `DaySummary` (speed 30%, skill 30%, fulfilment 40%), displays 1–5 stars + sous chef debrief line. "Continue" → show `upgrade` overlay.
- `upgrade_overlay.dart` — shows Ken's current skill + next tier cost. "Upgrade" → `ref.read(chefProvider.notifier).upgrade()` + `ref.read(cashProvider.notifier).spend(cost)`. Cash-gates button. "Next Day" → `game.switchScene(MapWorld, 'map')`.

**2. API + persistence** (`lib/services/`)
- `ramen_api_service.dart` — `GET /ramen/varieties` (cache for session, fallback to `fallback_varieties.json`); `GET /ramen/{variety_id}/price` (non-blocking, updates `menuProvider` via `updateDish`)
- `local_storage_service.dart` — SharedPreferences: persist/restore cash balance, chef skill level, day number, menu (JSON list), region unlock state
- `lib/fixtures/fallback_varieties.json` — offline fallback: array of `{ variety_id, name, regional_style, broth_base, rarity_tier }` for the 3 starter regions

**3. Cleanup**
- Delete `lib/screens/`, `lib/widgets/`, `lib/deprecated/` (screens were moved to `deprecated/` in the merge; now remove entirely)
- Consolidate or delete superseded provider files: `cash_provider.dart`, `chef_provider.dart`, `menu_provider.dart`, `game_state_provider.dart`, `region_provider.dart` (all superseded by `game_providers.dart`)
- Run `flutter analyze` and fix all issues
- Run `dcm analyze lib`

### Key Implementation Notes

- **Riverpod version**: Project uses `flutter_riverpod: ^3.3.1` — use `Notifier`/`NotifierProvider`, NOT deprecated `StateNotifier`
- **flame_riverpod v5**: Use `RiverpodAwareGameWidget`, `RiverpodGameMixin`, `RiverpodComponentMixin`
- **No sprites yet**: Use colored rectangles as placeholders for all entities (chef, customers, kitchen BG)
- **FTUE skipped**: Another developer handles FTUE. Game starts at MapWorld.
- **Single chef**: Ken only, no hiring. `ChefProfile.ken` starts at `SkillLevel.trained` (45s)
- **Mechanical customers**: Random dish + patience timer. No names/personality/LLM.

---

## Tier 0 — Flame Migration *(Do First)*

| Task | Notes | Status |
|------|-------|--------|
| ~~Replace `main.dart` with Flame entry point~~ | `ProviderScope` → `MaterialApp` → `RiverpodAwareGameWidget`. Merged from `feat/ftue`. | **Done** |
| ~~Create `GourmetGoGame` with `RiverpodGameMixin`~~ | `GameOverlay` enum, scene helpers, `pendingRegionId`. | **Done** |
| ~~Migrate state management to `flame_riverpod`~~ | All providers in `game_providers.dart`; components use `RiverpodComponentMixin`. | **Done** |
| Remove old Flutter screens and widgets | Delete `lib/screens/`, `lib/widgets/`, `lib/deprecated/`. Consolidate superseded provider files. | **Pending** |
| Remove unused Flame packages | Verify which are still in pubspec. | **Pending** |
| ~~Implement `Dish` model per API contract~~ | int `rarityTier`, `effectivePrice`, `rarityLabel`, `fromIdentification`, `fromJson`/`toJson`. | **Done** |
| ~~Update `GuideService.identifyDish()` to return structured JSON~~ | `identifyDishStructured()` + `identifyAsDish()` already added in `feat/ftue` merge. | **Done** |

---

## Tier 1 — Core Loop (~22h) *(Non-Negotiable)*

### BE (Backend)

| Task | Notes | Est. |
|------|-------|------|
| `RamenApiService`: GET /ramen/varieties | Fetch canonical variety list on session start; cache locally; fallback to `fallback_varieties.json` | 2h |
| `RamenApiService`: GET /ramen/{variety_id}/price | Fetch per-dish price after vision AI identifies dish; never block dish card creation | 1h |
| ~~Customer generation (LLM)~~ | Out of scope. Customers are purely mechanical: random dish from menu + patience timer. No names, personality, or LLM generation. | — |

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| `camera_overlay.dart` — reuse `CameraScreen` behavior | `image_picker` + `GuideService.identifyAsDish()` + scanning animation. Opens as Flame overlay, pauses current world. Dish added to `menuProvider` on success. | 3h |
| ~~Single chef (Ken) cook queue + progress bar + state machine~~ | `ChefEntity` + `CookBehavior` + `ProgressBarComponent` built. | **Done** |
| ~~Mechanical `CustomerEntity` + `WaitBehavior` + `SpeechBubbleComponent`~~ | Built with patience bar, spawning via `CustomerQueueComponent`. | **Done** |
| ~~Tap-to-assign orders to Ken~~ | `SpeechBubbleComponent` TapCallbacks → `OrderDispatcher.assign()`. | **Done** |
| ~~Cash earned on serve via `cashProvider`~~ | `ChefEntity.onOrderServed()` → `cashProvider.earn(dish.effectivePrice)`. | **Done** |
| `hud_overlay.dart` — cash balance + day timer + bottom bar | Bottom bar has camera icon and map icon. Day timer counts down from 240s. | Pending |

---

## Tier 2 — Progression & World Layer (~22h)

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| FTUE: `FtueWorld` + `ftue_overlay.dart` | Dark kitchen background. Sous chef monologue from prototype Section 4 (tap to advance). Opens camera at end. `ftueProvider` persists completion. | 3h |
| ~~Japan map: `MapWorld` + `RegionNode` x4~~ | 4 tappable `RegionNode`s positioned from `Region.mapPosition`. Tap → `showMapInfo`. ChefWalkerEntity + RamenBowlIcon deferred. | **Done** |
| `map_info_overlay.dart` — region detail bottom sheet | Shows region name, ramen type, description, arrivalQuote. "Enter Shop" CTA transitions to `ShopWorld`. | Pending |
| `day_summary_overlay.dart` + star rating calculation | 3-factor weighted score (speed 30%, skill 30%, fulfilment 40%) → 1–5 stars. Sous chef debrief line per star level. | Pending |
| `upgrade_overlay.dart` — chef skill upgrade | Ken: Trained → Skilled → Expert → Master. Persistent via SharedPreferences. Cash gating. No hiring — single chef only. | Pending |
| `sous_chef_bubble.dart` — contextual commentary | Hardcoded lines: queue backing up, rare bowl served, end of day, discovery nudge. Max 12 words during service. | Pending |
| ~~`ServiceTimerComponent` + phase transitions~~ | 240s countdown with pause/resume built. Day-end triggers `showDaySummary()`. Full lifecycle wiring (persist state, transitions) still pending. | **Partial** |

---

## Tier 3 — Wow Layer (~12h) *(Cut If Needed)*

### BE (Backend)

| Task | Notes | Est. |
|------|-------|------|
| Seedoms clip pre-generation + caching | Separate clip sets for common vs rare | 2h |

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| Seedoms contextual playback | Trigger on 3-star and region unlock; max 1 clip per day | 2h |
| ByteDance load + day-start clips | Bookend moments only | 3h |
| Chef sprite generation via `GameAssetService` | Gemini-generated sprites per chef state (available, cooking, plating, rest) | 3h |
| Map region glow + unlock animations | `RegionGlow` component: greyed (locked) → pulsing (discovered) → full color (unlocked) | 2h |
