# Gourmet GO — Hackathon Build TODO

Build in strict tier order. **Tier 3 is cuttable without breaking the demo.**

See [flame_implementation.md](flame_implementation.md) for full architecture and phased build plan.

---

## Implementation Progress (feature/flame-game branch)

### COMPLETED — Foundation Layer

| What | Files Created | Notes |
|------|--------------|-------|
| Data models | `lib/models/dish.dart`, `skill_level.dart`, `chef_profile.dart`, `customer_order.dart`, `day_summary.dart`, `ramen_variety.dart` | All models per flame_implementation.md spec. `Dish` has `starterBowls` fallback, `DaySummary` has 3-factor compute factory, `SkillLevel` enum has `next` getter + `upgradeCost`. |
| Theme | `lib/theme/app_theme.dart`, `game_colors.dart` | Dark theme + game palette constants. |
| Riverpod providers | `lib/providers/cash_provider.dart`, `chef_provider.dart`, `game_state_provider.dart`, `menu_provider.dart`, `customer_queue_provider.dart`, `region_provider.dart`, `upgrade_provider.dart` | All use Riverpod 3.x `Notifier` API (not deprecated `StateNotifier`). |
| Dependencies | `shared_preferences`, `flutter_riverpod` added to pubspec.yaml | `flame_riverpod` v5.5.3 already present. |

### NEXT — Pick Up Here

Build these in order. Each task references the architecture in `flame_implementation.md`.

**1. GourmetGame + main.dart** (`lib/game/gourmet_game.dart`, update `lib/main.dart`)
- Replace current `main.dart` with `ProviderScope` → `MaterialApp` (theme only) → `RiverpodAwareGameWidget`
- `GourmetGame extends FlameGame with RiverpodGameMixin` — register all overlay builders
- Check `flame_riverpod` v5 API: use `RiverpodAwareGameWidget`, `RiverpodGameMixin`, `RiverpodComponentMixin`
- Overlay keys: `'hud'`, `'camera'`, `'map_info'`, `'day_summary'`, `'upgrade'`, `'sous_chef_bubble'`
- Game starts by loading `MapWorld` (assume FTUE complete)

**2. ShopWorld** (`lib/game/worlds/shop_world.dart`)
- Extends `World` — colored rectangle kitchen background (placeholder)
- On mount: show `'hud'` overlay, create `ChefEntity`, `CustomerQueueComponent`, `ServiceTimerComponent`, `OrderDispatcher`
- On remove: hide `'hud'` overlay

**3. Chef mechanics** (`lib/game/components/chef/`)
- `chef_entity.dart` — `PositionComponent` with `RiverpodComponentMixin`, holds cook queue
- `cook_behavior.dart` — `Behavior<ChefEntity>` state machine: Available → Cooking → Plating → Available
- `progress_bar_component.dart` — `PositionComponent` using `RectangleComponent` + Paint (not sprites)
- On cook complete: `ref.read(cashProvider.notifier).earn(dish.price)`

**4. Customer system** (`lib/game/components/customer/`)
- `customer_entity.dart` — `PositionComponent` with `TapCallbacks`, holds `CustomerOrder`
- `wait_behavior.dart` — `Behavior<CustomerEntity>` patience countdown
- `speech_bubble_component.dart` — `PositionComponent` with dish name text
- Tap speech bubble → assign order to chef queue via `OrderDispatcher`

**5. Kitchen infrastructure** (`lib/game/components/kitchen/`)
- `order_dispatcher.dart` — routes tapped orders to chef queue
- `service_timer_component.dart` — 240s countdown, pause/resume support

**6. MapWorld** (`lib/game/worlds/map_world.dart`, `lib/game/components/map/`)
- 4 `RegionNode` components with `TapCallbacks`, positioned using `Region.mapPosition`
- Tap region → show `'map_info'` overlay
- "Enter Shop" CTA → swap to `ShopWorld`

**7. Overlays** (`lib/overlays/`)
- `hud_overlay.dart` — `ConsumerWidget`: cash balance, day timer, bottom bar (camera + map icons)
- `camera_overlay.dart` — reuses `CameraScreen` behavior (image_picker + GuideService + scanning animation), adds dish to `menuProvider`
- `map_info_overlay.dart` — region detail bottom sheet with "Enter Shop" CTA
- `day_summary_overlay.dart` — star rating display from `DaySummary`
- `upgrade_overlay.dart` — chef skill upgrade with cash gating

**8. API + persistence** (`lib/services/`)
- `ramen_api_service.dart` — GET /ramen/varieties, GET /ramen/{id}/price
- `local_storage_service.dart` — SharedPreferences for cash, chef skill, day number
- `lib/fixtures/fallback_varieties.json` — offline API fallback

**9. Day lifecycle wiring**
- Pre-day: seed customers from menu, populate ShopWorld
- Service: 240s timer, spawn customers ~30s apart
- Post-day: compute DaySummary, show overlays, upgrades, transition to MapWorld

**10. Cleanup**
- Delete `lib/screens/`, `lib/widgets/`, `lib/deprecated/`
- Remove `flame_tiled`, `flame_forge2d`, `flame_rive` from pubspec (they're not in pubspec currently — verify)
- Run `flutter analyze` and fix all issues

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
| ~~Replace `main.dart` with Flame entry point~~ | — | **Next up** |
| ~~Create `GourmetGame` with `RiverpodGameMixin`~~ | — | **Next up** |
| ~~Migrate state management to `flame_riverpod`~~ | Providers created, need to wire into Flame components | **Partial** |
| Remove old Flutter screens and widgets | Delete `lib/screens/`, `lib/widgets/`, `lib/deprecated/`. Preserve service and model files. | Pending |
| Remove unused Flame packages | Verify which are still in pubspec. | Pending |
| ~~Implement `Dish` model per API contract~~ | — | **Done** |
| Update `GuideService.identifyDish()` to return structured JSON | Currently returns free-text string. Must return JSON matching Dish model fields. | Pending |

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
| `camera_overlay.dart` — reuse `CameraScreen` behavior | `image_picker` + `GuideService.identifyDish()` + scanning animation. Opens as Flame overlay, pauses current world. Dish added to `menuProvider` on success. | 3h |
| Single chef (Ken) cook queue + progress bar + state machine | `ChefEntity` + `CookBehavior`: Available → Cooking → Plating → Rest. Ken starts at Trained (45s). `ProgressBarComponent` renders on canvas. | 4h |
| Mechanical `CustomerEntity` + `WaitBehavior` + `SpeechBubbleComponent` | Customer arrives with random dish from menu + patience timer. Speech bubble shows dish name. Patience bar counts down. Leaves if expired. No personality/names. | 4h |
| Tap-to-assign orders to Ken | Tap speech bubble → order added to Ken's queue. `TapCallbacks` mixin on customer entity. | 2h |
| Cash earned on serve via `cashProvider` | `CookBehavior` completion → `ref.read(cashProvider.notifier).earn(dish.price)`. HUD overlay watches provider reactively. | 1h |
| `hud_overlay.dart` — cash balance + day timer + bottom bar | Bottom bar has camera icon and map icon. Day timer counts down from 240s. | 2h |

---

## Tier 2 — Progression & World Layer (~22h)

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| FTUE: `FtueWorld` + `ftue_overlay.dart` | Dark kitchen background. Sous chef monologue from prototype Section 4 (tap to advance). Opens camera at end. `ftueProvider` persists completion. | 3h |
| Japan map: `MapWorld` + `RegionNode` x4 + `ChefWalkerEntity` | Isometric map BG, 4 tappable regions (Hokkaido, Kanto, Kansai, Kyushu) using existing `Region` model. Chef walks between regions. `RamenBowlIcon` floats above each. | 5h |
| `map_info_overlay.dart` — region detail bottom sheet | Shows region name, ramen type, description, arrivalQuote. "Enter Shop" CTA transitions to `ShopWorld`. | 2h |
| `day_summary_overlay.dart` + star rating calculation | 3-factor weighted score (speed 30%, skill 30%, fulfilment 40%) → 1–5 stars. Sous chef debrief line per star level. | 4h |
| `upgrade_overlay.dart` — chef skill upgrade | Ken: Trained → Skilled → Expert → Master. Persistent via SharedPreferences. Cash gating. No hiring — single chef only. | 3h |
| `sous_chef_bubble.dart` — contextual commentary | Hardcoded lines: queue backing up, rare bowl served, end of day, discovery nudge. Max 12 words during service. | 2h |
| Day lifecycle: `ServiceTimerComponent` + phase transitions | 240s countdown, pause/resume on camera/map open. Day-end → summary → upgrades → back to MapWorld. Persist state between days. | 3h |

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
