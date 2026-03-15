# Gourmet GO — Hackathon Build TODO

Build in strict tier order. **Tier 3 is cuttable without breaking the demo.**

See [flame_implementation.md](flame_implementation.md) for full architecture and phased build plan.

---

## Tier 0 — Flame Migration *(Do First)*

| Task | Notes | Est. |
|------|-------|------|
| Replace `main.dart` with Flame entry point | `ProviderScope` → `MaterialApp` (theme only) → `RiverpodAwareGameWidget`. Remove all Navigator routes. | 2h |
| Create `GourmetGame` with `RiverpodGameMixin` | Register all Flutter overlays. World-swapping for scene transitions (FtueWorld, MapWorld, ShopWorld). | 3h |
| Migrate state management to `flame_riverpod` | Create Riverpod providers: `cashProvider`, `chefProvider` (single chef — Ken), `gameStateProvider`, `menuProvider`, `ftueProvider`, `regionProvider`. All Flame components use `RiverpodComponentMixin`. | 4h |
| Remove old Flutter screens and widgets | Delete `lib/screens/`, `lib/widgets/`, `lib/deprecated/`. Preserve service and model files. | 1h |
| Remove unused Flame packages | Remove `flame_tiled`, `flame_forge2d`, `flame_rive` from `pubspec.yaml`. Run `flutter pub get`. | 0.5h |
| Implement `Dish` model per API contract | Fields: `varietyId`, `name`, `regionalStyle`, `brothBase`, `rarityTier`, `price`, `playerPhotoPath`, `regionalLore`. Must match `GET /ramen/varieties` response structure from prototype Section 8. | 1h |
| Update `GuideService.identifyDish()` to return structured JSON | Currently returns free-text string. Must return JSON matching Dish model fields: `{ ramen_name, regional_style, broth_base, regional_lore, confidence_0_to_1 }` per prototype Section 11.1. | 2h |

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
