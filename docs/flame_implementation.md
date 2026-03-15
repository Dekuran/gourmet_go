# Ramen Restaurant Simulator -- Flame Implementation Plan

## Context

Gourmet GO is an iOS-only Flutter/Flame ramen restaurant simulator. The project currently runs as a Flutter screen-based app (MaterialApp + Navigator routes) with fully implemented screens for map navigation, ramen shop, visual novel dialogue, camera/photo capture, and an API test dashboard. All AI services (Claude vision, Gemini image gen, ElevenLabs TTS, Seedance video, Tripo 3D) are integrated and working.

**This plan converts the app from a Flutter screen-based architecture into a full Flame game.** The existing `main.dart`, screens, and widget-based navigation will be replaced by a `FlameGame` with Flame components and Flutter overlays. Existing services and models are preserved and integrated.

**Scope for this iteration:**
- FTUE: sous chef opening monologue + first photo onboarding
- Camera/upload flow to add dishes to the menu (reusing existing `CameraScreen` behavior + `GuideService`)
- Japan map as the menu (4 regions: Hokkaido, Kanto, Kansai, Kyushu — matching existing `Region` model)
- Ramen shop service loop: chef cooking, customer queue, order assignment
- 1 starter chef (Ken, Trained skill) cooking orders with a progress timer, upgradeable speed
- Mechanical customers: dish order + patience timer only (no personality, names, or LLM generation)
- Money earned per order (prices from API)
- Register till balance
- Chef speed upgrades up to Master
- Ramen varieties/prices fetched from API

**Out of scope for this iteration:**
- Hiring additional chefs (max 3 in prototype, deferred)
- Chef personality, backstory, or regional specialties
- Customer personality, names, types, desires, or budget
- LLM-generated customer personas
- Rarity-tier cash multipliers (all dishes earn base price)
- Restaurant tier / ambience upgrades (5-tier visual progression)
- Daily bowl limit / capacity upgrades
- LLM-generated sous chef lines
- Seedoms / ByteDance video clips

---

## User Journey

```
FTUE (sous chef monologue, dark kitchen)
  → Camera (first photo, part of FTUE)
  → Map (Japan map = the menu, 4 regions)
  → Shop (service day: chef cooks, customers order, cash earned)
  → End-of-day summary + upgrades
  → Map (next day)
```

The entire app is a single `FlameGame`. Scene transitions (FTUE → Map → Shop) are handled by swapping Flame `World` instances and toggling Flutter overlays.

---

## Architecture Overview

### Flame + Flutter Split

| Layer | Technology | Handles |
|-------|-----------|---------|
| **Game canvas** | Flame components | Kitchen scene, chef sprites, customer sprites, progress bars, speech bubbles, map, animations |
| **HUD & menus** | Flutter widget overlays | Cash balance, day timer, upgrade screen, day summary, sous chef bubble, camera |
| **State** | Riverpod providers via `flame_riverpod` | Cash, chef roster, menu, upgrades, game phase — bridged to Flame via `RiverpodComponentMixin` |

### Component Tree

```
GourmetGame (FlameGame + RiverpodGameMixin)
  │
  ├── [World: FtueWorld] (first launch only)
  │     +-- DarkKitchenBackground (SpriteComponent)
  │
  ├── [World: MapWorld] (Japan map = menu)
  │     +-- MapBackground (SpriteComponent — isometric Japan map)
  │     +-- RegionNode x4 (PositionComponent + TapCallbacks)
  │     |     +-- RamenBowlIcon (SpriteComponent — floats above region)
  │     |     +-- RegionGlow (ShapeComponent — unlock state indicator)
  │     +-- ChefWalkerEntity (PositionComponent — animated chef on map)
  │
  ├── [World: ShopWorld] (service day)
  │     +-- KitchenBackground (SpriteComponent)
  │     +-- ChefEntity (PositionComponent + EntityMixin) — single chef (Ken)
  │     |     +-- CookBehavior — cook timer state machine
  │     |     +-- ProgressBarComponent
  │     +-- CustomerQueueComponent (Component)
  │     |     +-- CustomerEntity x0..8 — mechanical: dish order + patience only
  │     |           +-- WaitBehavior — patience countdown
  │     |           +-- SpeechBubbleComponent — dish icon + name
  │     |           +-- PatienceBarComponent
  │     +-- ServiceTimerComponent — 4-min day clock
  │     +-- OrderDispatcher — routes tapped orders to chef
```

**Flutter Overlays** (on top of canvas):
- `ftue` — sous chef monologue text (tap to advance), shown over FtueWorld
- `hud` — cash balance, day timer, bottom bar icons (camera, map)
- `camera` — reuses existing camera/upload + scanning + dish identification behavior via `GuideService`
- `map_info` — region detail bottom sheet (name, ramen type, description, enter shop CTA)
- `day_summary` — star rating + factor breakdown
- `upgrade_screen` — spend cash on chef skill / hire
- `sous_chef_bubble` — contextual commentary

---

## Existing Code to Preserve & Integrate

### Services (keep as-is, used from overlays and providers)

| Service | File | Usage in Flame Game |
|---------|------|---------------------|
| **GuideService** | `services/guide_service.dart` | Camera overlay calls `identifyDish()` for dish recognition; `generateRecipe()` for structured dish data |
| **GameAudioService** | `services/game_audio_service.dart` | SFX on order complete, customer arrive, photo snap; music per scene (map, shop) |
| **GameAssetService** | `services/game_asset_service.dart` | Generate chef sprites, customer sprites, ramen bowl icons, kitchen backgrounds via Gemini |
| **ElevenLabsService** | `services/elevenlabs_service.dart` | Sous chef voice lines during FTUE and end-of-day |
| **SeedanceService** | `services/seedance_service.dart` | Out of scope for this iteration but preserved |
| **TripoService** | `services/tripo_service.dart` | Out of scope for this iteration but preserved |
| **DebugLogger** | `services/debug_logger.dart` | Logging throughout |

### Models (keep and extend)

| Model | File | Status |
|-------|------|--------|
| **Region** | `models/region.dart` | **Keep as-is.** 4 regions (Hokkaido, Kanto, Kansai, Kyushu) with `id`, `name`, `prefecture`, `ramenType`, `ramenEmoji`, `ramenDescription`, `mapPosition`, `primaryColor`, `secondaryColor`, `connectedTo`, `arrivalQuote`. Add `unlocked` field for runtime state (tracked in provider, not on model). |
| **Recipe** | `models/recipe.dart` | **Keep as-is.** JSON-serializable recipe model with ingredients and steps. |
| **PrepStep** | `models/prep_step.dart` | **Keep as-is.** Used by recipe model. |
| **Dish** | `models/dish.dart` | **Replace stub.** New model per API contract (see Data Models below). |

### Fixtures (keep)

- `lib/fixtures/ramen.json`, `masuzushi.json`, `takoyaki.json` — fixture data for offline/fallback

### Assets (keep)

- `assets/audio/` — 8 audio files (map music, shop music, SFX)
- `assets/images/tonkotsu_ramen_basic.png` — test photo
- `assets/models/`, `assets/videos/` — preserved for future use

### Code to Remove

- `lib/main.dart` — replaced entirely with Flame game entry point
- `lib/screens/` — all screens replaced by Flame worlds + overlays
- `lib/widgets/` — all stubs, replaced by Flame components
- `lib/deprecated/` — removed (models superseded by new Flame data models)

---

## Project Structure

```
lib/
  main.dart                             # ProviderScope + RiverpodAwareGameWidget

  game/
    gourmet_game.dart                   # FlameGame + RiverpodGameMixin, overlay registration
    worlds/
      ftue_world.dart                   # FTUE scene: dark kitchen background
      map_world.dart                    # Japan map with 4 region nodes + chef walker
      shop_world.dart                   # Service day: kitchen, chefs, customers
    components/
      chef/
        chef_entity.dart                # Positioned chef with EntityMixin
        cook_behavior.dart              # Behavior: cook timer state machine
        chef_state.dart                 # Enum: available, cooking, plating, resting
        chef_walker_entity.dart         # Map chef that walks between regions
      customer/
        customer_entity.dart            # Positioned customer sprite
        wait_behavior.dart              # Behavior: patience countdown
        customer_state.dart             # Enum: arriving, waiting, served, left_unhappy
        speech_bubble_component.dart    # Dish icon + name bubble
      map/
        region_node.dart                # Tappable region on Japan map
        ramen_bowl_icon.dart            # Floating bowl icon above region
        region_glow.dart                # Unlock state glow effect
      kitchen/
        order_dispatcher.dart           # Assigns tapped orders to chefs
        service_timer_component.dart    # 4-min day countdown, supports pause/resume
        progress_bar_component.dart     # Reusable progress bar

  models/
    region.dart                         # EXISTING: 4 regions with map data (from master)
    recipe.dart                         # EXISTING: JSON-serializable recipe model
    prep_step.dart                      # EXISTING: prep step model
    dish.dart                           # NEW: variety_id, name, regional_style, broth_base, rarity_tier, price (per API contract)
    chef_profile.dart                   # Single chef (Ken): name, skill_level, cook_time
    skill_level.dart                    # Enum: novice(60s)..master(12s). Ken starts at Trained.
    customer_order.dart                 # Mechanical: dish, patience_seconds, arrival_time, status
    ramen_variety.dart                  # Mirrors API: variety_id, name, regional_style, broth_base, rarity_tier
    day_summary.dart                    # Computed end-of-day rating

  providers/
    game_state_provider.dart            # Game phase (ftue/map/shop/post_day), day number
    cash_provider.dart                  # Till balance: earn(), spend()
    chef_provider.dart                  # Single chef (Ken): skill level, upgrade
    menu_provider.dart                  # List<Dish> on the menu
    customer_queue_provider.dart        # Mechanical customer queue for current day (dish + patience)
    ramen_api_provider.dart             # FutureProvider for API variety/price data
    upgrade_provider.dart               # Tracks purchased upgrades
    region_provider.dart                # Region unlock state (wraps existing Region.all)
    ftue_provider.dart                  # FTUE completion flag

  services/
    guide_service.dart                  # EXISTING: Claude API — dish identification + recipe generation
    game_audio_service.dart             # EXISTING: FlameAudio + ElevenLabs TTS/SFX
    game_asset_service.dart             # EXISTING: Gemini image generation (sprites, bowls, BGs)
    elevenlabs_service.dart             # EXISTING: ElevenLabs TTS wrapper
    seedance_service.dart               # EXISTING: BytePlus Seedance video generation
    tripo_service.dart                  # EXISTING: Tripo3D image-to-3D model
    debug_logger.dart                   # EXISTING: logging utility
    ramen_api_service.dart              # NEW: HTTP GET /ramen/varieties, GET /ramen/{id}/price
    local_storage_service.dart          # NEW: SharedPreferences persistence

  overlays/
    ftue_overlay.dart                   # Sous chef monologue (tap to advance) + camera CTA
    hud_overlay.dart                    # Cash, timer, bottom bar (camera + map icons)
    camera_overlay.dart                 # Reuses CameraScreen behavior: image_picker + GuideService + scanning animation
    map_info_overlay.dart               # Region detail bottom sheet on tap
    day_summary_overlay.dart            # Star rating + breakdown
    upgrade_overlay.dart                # End-of-day upgrade screen
    sous_chef_bubble.dart               # Contextual commentary widget

  theme/
    app_theme.dart                      # ThemeData for overlays (dark theme from existing main.dart)
    game_colors.dart                    # Game palette constants

  fixtures/
    ramen.json                          # EXISTING
    masuzushi.json                      # EXISTING
    takoyaki.json                       # EXISTING
    fallback_varieties.json             # NEW: offline API fallback
```

---

## Data Models

| Model | Key Fields |
|-------|-----------|
| **Region** | EXISTING: `id`, `name`, `prefecture`, `ramenType`, `ramenEmoji`, `ramenDescription`, `mapPosition`, `primaryColor`, `secondaryColor`, `connectedTo`, `arrivalQuote` |
| **Dish** | `varietyId`, `name`, `regionalStyle`, `brothBase`, `rarityTier`, `price`, `playerPhotoPath`, `regionalLore` — per API contract in prototype Section 8 |
| **RamenVariety** | Mirrors API: `varietyId`, `name`, `regionalStyle`, `brothBase`, `rarityTier` |
| **Recipe** | EXISTING: full JSON-serializable model with ingredients + steps |
| **ChefProfile** | Single starter chef: Ken, Trained skill. Fields: `name`, `skillLevel`, `cookTimeSeconds` (derived from skill) |
| **SkillLevel** | Enum with `cookTimeSeconds` getter: novice=60, trained=45, skilled=30, expert=20, master=12. Ken starts at Trained. |
| **CustomerOrder** | Mechanical only: `dish`, `patienceSeconds`, `arrivalTime`, `status`. No customer name, personality, or type. |
| **DaySummary** | `ordersServed`, `ordersMissed`, `avgServiceTime`, 3 factor scores (speed, skill, fulfilment), `stars` (1-5) |

---

## Core Mechanics

### Chef Cooking State Machine (Single Chef — Ken)
```
Available -> [order assigned] -> Cooking (progress 0.0->1.0) -> Plating (1s) -> Available
```
- `CookBehavior.update(dt)` increments progress by `dt / cookTimeSeconds`
- On completion: earn cash via `cashProvider`, mark order served, auto-start next queued order
- Single chef maintains one `Queue<CustomerOrder>`
- Ken starts at Trained skill (45s per bowl); upgradeable to Master (12s)

### Customer Patience
- Customers are purely mechanical: a dish order + patience timer
- `WaitBehavior.update(dt)` decrements patience counter
- Visual patience bar shrinks over time
- At zero: customer leaves, increments missed-orders counter

### Order Assignment
- Player taps a customer's speech bubble → order added to Ken's queue
- Uses `TapCallbacks` mixin on `CustomerEntity`/`SpeechBubbleComponent`

### Scene Transitions
- `GourmetGame` manages scene flow by swapping `World` instances
- FTUE → `FtueWorld` with `ftue` overlay
- Camera opens as overlay (pauses current world)
- Map → `MapWorld`, tap region → `map_info` overlay with "Enter Shop" CTA
- Shop → `ShopWorld` with `hud` overlay, service timer runs
- Post-day → `day_summary` overlay → `upgrade_screen` overlay → back to `MapWorld`

### Day Lifecycle
1. **Pre-Day** — generate customers, populate ShopWorld with chef entities
2. **Service** — 240s timer, customers spawn at intervals (~30s apart), player assigns orders
3. **Post-Day** — compute summary (3-factor weighted: speed 30%, skill 30%, fulfilment 40%), show overlays, upgrades, persist state

### Camera Flow (Reusing Existing Behavior)
- Camera overlay wraps existing `image_picker` + `GuideService.identifyDish()` flow
- Scanning animation with cyan scan line (from existing `CameraScreen`)
- On success: create `Dish` model from response, add to `menuProvider`
- On failure: retry branch or 3 pre-seeded starter bowls
- During service: `ServiceTimerComponent.pause()` on open, `resume()` on close
- SFX via `GameAudioService.playSfx(GameSfx.photo)`

### API Integration
- `RamenApiService` uses `http` package (already a dependency), base URL from `.env` (via `flutter_dotenv`, already configured)
- `ramenVarietiesProvider` = `FutureProvider`, called on session start, cached
- `ramenPriceProvider(varietyId)` = `FutureProvider.family` for per-dish price
- Fallback to `fallback_varieties.json` if API unavailable
- Never block gameplay on API — show placeholder price and retry silently

---

## State Management

All state management uses **Riverpod** via the `flame_riverpod` package.

**Riverpod owns persistent state** (cash, chef skill level, menu, day number, region unlocks, FTUE flag) — accessible from both Flutter overlays (`ConsumerWidget`) and Flame components (`RiverpodComponentMixin`).

**Flame components own ephemeral state** (cook progress, patience remaining, animation frame, service timer seconds).

**Data flow example — serving a bowl:**
1. Player taps speech bubble → `OrderDispatcher` assigns to chef
2. `CookBehavior.update()` ticks timer based on skill level
3. Timer completes → `ref.read(cashProvider.notifier).earn(dish.price)`
4. HUD overlay watches `cashProvider` → balance updates reactively

**Data flow example — photographing a dish:**
1. Player taps camera icon in HUD → camera overlay opens, world pauses
2. `image_picker` returns photo → `GuideService.identifyDish()` called
3. On success → `ref.read(menuProvider.notifier).addDish(dish)`
4. Camera overlay closes, world resumes
5. Map region nodes react to new dish (glow state updates)

---

## Phased Build Order

### Phase 1: Foundation
- Replace `main.dart`: `ProviderScope` → `MaterialApp` (for theme) → `RiverpodAwareGameWidget`
- `GourmetGame` with `RiverpodGameMixin`, overlay registration for all overlays
- Keep existing `Region` model as-is; implement new `Dish` model per API contract
- Data models: `ChefProfile`, `SkillLevel`, `CustomerOrder`, `RamenVariety`, `DaySummary`
- Core providers: `cashProvider`, `chefProvider`, `gameStateProvider`, `menuProvider`, `ftueProvider`, `regionProvider`
- Remove `lib/screens/`, `lib/widgets/`, `lib/deprecated/`
- Remove `flame_tiled`, `flame_forge2d`, `flame_rive` from `pubspec.yaml`

### Phase 2: FTUE
- `FtueWorld`: dark kitchen background sprite
- `ftue_overlay.dart`: sous chef monologue (static text screens from prototype Section 4, tap to advance)
- At end of monologue → opens camera overlay for first photo
- `ftueProvider` persists completion flag via `SharedPreferences` so FTUE only plays once
- On FTUE complete → transition to `MapWorld`

### Phase 3: Camera & Dish Creation
- `camera_overlay.dart`: reuses existing `CameraScreen` behavior (image_picker + GuideService + scanning animation)
- Modify `GuideService.identifyDish()` response to return structured JSON matching `Dish` model fields (variety_id, name, regional_style, broth_base)
- Dish card created and added to `menuProvider`
- Fallback to 3 pre-seeded starter bowls on recognition failure
- Camera accessible any time via HUD bottom bar; pauses current world on open

### Phase 4: Japan Map (Menu)
- `MapWorld`: isometric Japan map background, 4 `RegionNode` components (Hokkaido, Kanto, Kansai, Kyushu)
- `ChefWalkerEntity`: animated chef that walks between regions (behavior from existing `MapScreen`)
- `RamenBowlIcon`: floating bowl icon above each region
- `RegionGlow`: visual state per region (locked / discovered / unlocked)
- `regionProvider`: tracks unlock state; regions unlock when a dish from that region is photographed
- Tap region → `map_info_overlay` bottom sheet with region detail + "Enter Shop" CTA
- Audio: map music via `GameAudioService`

### Phase 5: Chef Mechanics
- Single `ChefEntity` (Ken, Trained skill) with `CookBehavior` state machine
- Visual progress bar (`ProgressBarComponent`)
- Cash earned on bowl completion via `cashProvider`
- Placeholder chef visuals (colored rectangles); sprites from `GameAssetService` later

### Phase 6: Customer System
- Mechanical `CustomerEntity` with `WaitBehavior` and patience bar (no personality or names)
- `CustomerQueueComponent` with timed spawning (~30s intervals)
- `SpeechBubbleComponent` showing dish name
- Tap customer speech bubble → order added to Ken's queue
- Customer leaves when patience expires

### Phase 7: Day Lifecycle
- `ServiceTimerComponent`: 4-min countdown with HUD display, supports pause/resume
- Day-end detection and world pause
- `DaySummary` computation (3-factor: speed 30%, skill 30%, fulfilment 40%)
- `day_summary_overlay` with star rating and sous chef debrief line
- Phase transitions: MapWorld → ShopWorld (service) → post-day overlays → MapWorld

### Phase 8: API Integration
- `RamenApiService` with two endpoints (`GET /ramen/varieties`, `GET /ramen/{id}/price`)
- `ramenVarietiesProvider` and `ramenPriceProvider` (Riverpod `FutureProvider`)
- Dish prices flow from API into cash earned on serve
- `fallback_varieties.json` for offline play
- Never block gameplay on API

### Phase 9: Upgrades
- `upgrade_overlay` with chef skill upgrade (Ken: Trained → Skilled → Expert → Master)
- Cost deduction and balance validation via `cashProvider`
- Persistence via `SharedPreferences`

### Phase 10: Polish
- `sous_chef_bubble` overlay with hardcoded contextual lines (no LLM yet)
- Customer arrival pacing tuning
- Visual polish: sprites from `GameAssetService` (Gemini) for kitchen BG, chefs, customers, bowls
- Audio: shop music, SFX for order complete / customer arrive / photo snap via `GameAudioService`
- Sous chef voice via `ElevenLabsService` for FTUE and end-of-day (if time permits)

---

## Key Decisions

| Decision | Rationale |
|----------|-----------|
| **Full Flame game, not Flutter screens** | The app is being rebuilt as a game. Flame handles scene management, entity rendering, and game loop. Flutter overlays handle text-heavy UI only. |
| **Riverpod via `flame_riverpod`** | Upgrade screen and day summary are Flutter overlays that need direct access to cash/roster. Flame components access the same state via `RiverpodComponentMixin`. |
| **Reuse existing services** | `GuideService`, `GameAudioService`, `GameAssetService`, `ElevenLabsService` are production-ready. Overlays call these directly; no need to rewrite. |
| **Keep existing `Region` model** | 4 regions already defined with map positions, colors, quotes, and connectivity. Unlock state tracked separately in `regionProvider`. |
| **World-swapping for scenes** | `GourmetGame` swaps between `FtueWorld`, `MapWorld`, and `ShopWorld`. Cleaner than a single monolithic world with visibility toggles. |
| **`flame_behaviors` for entity logic** | Keeps cooking/waiting concerns in separate testable `Behavior` classes, avoids monolithic entities. |
| **No `flame_tiled`** | Restaurant is a single-screen view, not a scrollable tile map. `SpriteComponent` background is simpler. |
| **No `flame_forge2d`** | No physics needed for a restaurant management sim. |
| **No `flame_rive`** | Not using Rive animations for this prototype. |

---

## Verification

1. **Unit tests**: Test `CookBehavior` state transitions, `WaitBehavior` patience countdown, `DaySummary` computation (3-factor), cash provider earn/spend, region unlock logic, menu provider add/remove
2. **Widget tests**: Test overlay widgets (HUD displays correct balance, upgrade screen disables unaffordable items, FTUE advances through monologue screens, map info shows correct region data)
3. **Integration**: Run `flutter run` on iOS simulator, verify full journey: FTUE → camera adds first dish → map shows regions → enter shop → customers arrive → tap to assign → chef cooks → cash earned → day ends → upgrade → back to map
4. **Camera flow**: Verify image_picker opens from overlay, GuideService returns dish identification, dish appears in menu provider, service timer pauses/resumes
5. **API**: Mock API responses in tests via provider overrides; verify fallback to fixture data
6. **Linting**: `flutter analyze` + `dcm analyze lib`
