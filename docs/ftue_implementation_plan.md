# FTUE Implementation Plan — Gourmet GO

## Overview

Build the First-Time User Experience from the [restaurant_sim_prototype.md](../gourmet_go/docs/restaurant_sim_prototype.md) Section 4, plus the supporting screens and API integrations needed for the full FTUE-to-service flow. The FTUE is the tutorial — no separate onboarding, no popups. The entire premise is established through the sous chef's voice in ~90 seconds.

### Architecture Decision: Flame Game Engine

The project has the full Flame ecosystem in [`pubspec.yaml`](../gourmet_go/pubspec.yaml) — `flame`, `flame_audio`, `flame_riverpod`, `flame_tiled`, `flame_rive`, `flame_svg`, `flame_behaviors`, `flame_forge2d`, `flame_jenny`, `flame_splash_screen`.

**The existing Flutter widget screens were prototypes. They will be replaced with a Flame-based game.**

**KEEP** — the API services, test dashboard, models, and fixtures are all battle-tested and valuable:
- All services in `lib/services/` — these are pure Dart HTTP clients, engine-agnostic
- [`ApiTestScreen`](../gourmet_go/lib/screens/api_test_screen.dart) — stays as a plain Flutter route for dev/testing
- Models: `Recipe`, `PrepStep`, `Region`, plus new `Dish`
- Fixtures and generated assets

**REPLACE** — rebuild as Flame game components with Flutter overlays:
- `map_screen.dart` → `FlameGame` world with isometric map components
- `ramen_shop_screen.dart` → Flame scene/component
- `visual_novel_screen.dart` → Flame dialogue overlay system
- `camera_screen.dart` → Flutter overlay on the Flame game (camera requires native widgets)
- Stubs: `restaurant_screen.dart`, `reveal_screen.dart`, `prep_loop_screen.dart`

### Flame Architecture Overview

```mermaid
flowchart TD
    subgraph FlutterLayer[Flutter Layer]
        Main[main.dart + GameWidget]
        Overlays[Flutter Overlays]
        Camera[Camera Overlay - native widget]
        Dialogue[Dialogue Overlay - typewriter + TTS]
        Menu[Menu Board Overlay - 3D viewer]
        HUD[HUD Overlay - cash, day timer, buttons]
    end
    
    subgraph FlameLayer[Flame Game Engine]
        GG[GourmetGoGame extends FlameGame]
        World[Game World]
        Map[MapScene - isometric Japan]
        Shop[ShopScene - regional restaurant]
        Kitchen[KitchenScene - service day]
        FTUE[FtueScene - dark kitchen intro]
    end
    
    subgraph Services[Services Layer - kept as-is]
        Guide[GuideService - Claude]
        Asset[GameAssetService - Gemini]
        Audio[GameAudioService - ElevenLabs]
        Seed[SeedanceService - BytePlus]
        Tripo[TripoService - Tripo3D]
        API[RamenApiService - backend]
    end
    
    Main --> GG
    GG --> World
    World --> Map
    World --> Shop
    World --> Kitchen
    World --> FTUE
    GG --> Overlays
    Overlays --> Camera
    Overlays --> Dialogue
    Overlays --> Menu
    Overlays --> HUD
    GG --> Services
```

### Target Flow

```
App loads → Seedance intro clip 2-3s → Dark kitchen screen →
Sous chef speaks opening story → Motivation to travel →
Camera opens → Player photographs or uploads ramen →
Vision AI identifies bowl → Dish card created → Menu updated →
Japan map pulses → First customer arrives → Service begins
```

---

## Current State Analysis

### What Exists

| Component | Status | File |
|-----------|--------|------|
| Map screen | ✅ Working | `screens/map_screen.dart` |
| Ramen shop screen | ✅ Working | `screens/ramen_shop_screen.dart` |
| Visual novel dialogue screen | ✅ Working | `screens/visual_novel_screen.dart` |
| Camera screen | ✅ Working | `screens/camera_screen.dart` |
| GuideService - Claude dish ID | ✅ Working | `services/guide_service.dart` |
| GameAssetService - Gemini sprites | ✅ Working | `services/game_asset_service.dart` |
| GameAudioService - SFX + TTS | ✅ Working | `services/game_audio_service.dart` |
| SeedanceService - video gen | ✅ Working | `services/seedance_service.dart` |
| ElevenLabsService - narration TTS | ✅ Working | `services/elevenlabs_service.dart` |
| Region model | ✅ Working | `models/region.dart` |
| Recipe model | ✅ Working | `models/recipe.dart` |
| Sprite generation pipeline | ✅ Reference exists | `docs/sprite_generation_example/` |
| Dish model | ❌ Stub only | `models/dish.dart` |
| Reveal screen | ❌ Stub only | `screens/reveal_screen.dart` |
| FTUE screen | ❌ Does not exist | — |
| FTUE state tracking | ❌ Does not exist | — |
| Sous chef character assets | ❌ Generated at runtime only | — |
| Dark kitchen background | ❌ Does not exist | — |
| FTUE-specific audio | ❌ Does not exist | — |
| Intro video clip | ❌ Does not exist | — |

### What Needs to Change

| Component | Change |
|-----------|--------|
| `main.dart` | Route to FTUE on first launch instead of `/map` |
| `dish.dart` | Full Dish model with rarity, region, lore, price, photo thumbnail, GLB URL |
| `region.dart` | Add `rarityTier` field matching design doc tiers |
| `guide_service.dart` | Add `identifyDishStructured()` returning JSON with confidence score |
| `game_asset_service.dart` | Add sous chef portrait, dark kitchen BG, dish card icon prompts |
| `game_audio_service.dart` | Add FTUE-specific SFX entries and intro music track |
| `generate_audio.sh` | Add FTUE audio generation commands |
| `camera_screen.dart` | Full rework: structured recognition, confidence branching, dish card creation, Tripo 3D kickoff |
| NEW `menu_board_screen.dart` | Scrollable dish card grid with 3D model viewer per dish |
| NEW `ramen_api_service.dart` | Backend API client for `GET /ramen/varieties` and `GET /ramen/{variety_id}/price` |
| `dish_card.dart` | Full widget with rarity borders, photo thumb, 3D model tap, region lore |

---

## Phase 1 — Asset Generation (Pre-Build)

These run offline via scripts before Flutter code changes.

### 1A. Sprite Generation Script

Create `gourmet_go/scripts/generate_ftue_sprites.py` modelled on the existing [`generate_sprites.py`](../gourmet_go/docs/sprite_generation_example/generate_sprites.py) pipeline.

**Sprites to generate:**

| Sprite | Description | Use Reference | Art Style |
|--------|-------------|---------------|-----------|
| `sous_chef_portrait` | Bust portrait for visual novel dialogue — warm, wise, older character | No - new character | Dreamy anime-inspired, bold outlines, flat pastel colours |
| `sous_chef_sprite` | Full body sprite for map/shop walking | Yes - from portrait | Same style |
| `dark_kitchen_bg` | Dimly lit ramen kitchen interior, moody, atmospheric | No | Isometric, warm shadows, modern indie |
| `dish_card_frame` | Card frame/border with rarity colour variants | No | UI element, clean, flat |
| `ramen_bowl_icon_generic` | Generic steaming ramen bowl icon for first dish card | No | Icon style, warm colours |

**Art style override** per README: *"Dreamy anime-inspired isometric pixel art — flat pastel colours, bold outlines, modern indie aesthetic"*

The script will:
1. Use Gemini `gemini-2.5-flash-image` as primary generator
2. Request solid `#00FF88` lime-green backgrounds
3. Post-process with PIL chroma-key removal
4. Output to `gourmet_go/assets/images/ftue/`
5. Also generate a reference atlas for review

### 1B. FTUE Audio Generation

Add to `generate_audio.sh` or create `generate_ftue_audio.sh`:

| Asset | Type | Prompt |
|-------|------|--------|
| `music_ftue_intro.mp3` | Music | Gentle emotional piano and strings, slow build, nostalgic and warm, Japanese restaurant story opening |
| `sfx_kitchen_ambience.mp3` | SFX | Quiet empty kitchen ambience, distant simmering pot, gentle fan hum, peaceful |
| `sfx_dish_card_reveal.mp3` | SFX | Magical sparkling reveal sound, ascending chimes, achievement unlocked, warm |
| `sfx_map_pulse.mp3` | SFX | Soft pulsing glow sound, map region lighting up, ethereal |
| `sfx_customer_arrive.mp3` | SFX | Restaurant door bell, cheerful short jingle, customer entering |

### 1C. Seedance Intro Video

Use [`SeedanceService`](../gourmet_go/lib/services/seedance_service.dart) to pre-generate a 2-3s intro clip:

**Prompt**: *"A dimly lit Japanese ramen kitchen slowly illuminating, warm golden light spreading across wooden counters and hanging lanterns, steam rising gently, cinematic, dreamy anime aesthetic"*

Store at `assets/videos/ftue_intro.mp4` — pre-baked, not generated at runtime.

---

## Phase 2 — Service & Model Updates

### 2A. Dish Model

Replace the stub [`dish.dart`](../gourmet_go/lib/models/dish.dart) with a full model:

```dart
class Dish {
  final String id;
  final String name;
  final String regionalStyle;
  final String brothBase;
  final RarityTier rarityTier;
  final String regionalLore;
  final String? photoPath;       // Player photo thumbnail
  final Uint8List? photoBytes;
  final double? price;           // From backend, display-only
  final int timesServed;
  final double avgStars;
  final DateTime discoveredAt;
  
  // ... factory fromGuideResponse, toJson, fromJson for persistence
}

enum RarityTier { common, uncommon, rare, legendary }
```

Persist via `shared_preferences` as JSON array, excluding `photoBytes` and `price`.

### 2B. FTUE State Service

New file `lib/services/ftue_service.dart`:

```dart
class FtueService {
  // Checks shared_preferences for 'ftue_completed' flag
  Future<bool> isFirstLaunch();
  // Sets flag after FTUE completes
  Future<void> markFtueComplete();
  // Stores the first dish created during FTUE
  Future<void> saveFirstDish(Dish dish);
}
```

### 2C. GuideService Updates

Add a new method to [`GuideService`](../gourmet_go/lib/services/guide_service.dart):

```dart
/// Returns structured JSON: { ramen_name, regional_style, broth_base,
///   regional_lore, confidence_0_to_1 }
Future<Map<String, dynamic>> identifyDishStructured(Uint8List imageBytes);
```

This is needed because the FTUE has branching logic based on `confidence < 0.6` — the current [`identifyDish()`](../gourmet_go/lib/services/guide_service.dart:86) returns a prose string, not structured data.

The structured prompt should ask Claude to return:
```json
{
  "ramen_name": "Hakata Tonkotsu Ramen",
  "regional_style": "Fukuoka",
  "broth_base": "tonkotsu",
  "regional_lore": "Born in the bustling yatai stalls of Fukuoka...",
  "confidence_0_to_1": 0.92,
  "variety_id": "hakata_tonkotsu"
}
```

The `variety_id` maps to the ramen varieties catalogue from the backend API.

### 2F. Ramen API Service (Backend Contract)

New file: `lib/services/ramen_api_service.dart`

Implements the two API endpoints from [design doc Section 8](../gourmet_go/docs/restaurant_sim_prototype.md:386):

```dart
class RamenApiService {
  /// GET /ramen/varieties
  /// Called at session start and after each dish card creation.
  /// Returns canonical list of recognised ramen types.
  /// Cached for the session; re-fetched on next app launch.
  Future<List<RamenVariety>> getVarieties();
  
  /// GET /ramen/{variety_id}/price
  /// Called immediately after vision AI identifies a dish.
  /// Returns price displayed on dish card and used in cash calc.
  Future<DishPrice?> getPrice(String varietyId);
}

class RamenVariety {
  final String varietyId;
  final String name;
  final String regionalStyle;
  final String brothBase;
  final RarityTier rarityTier;
}

class DishPrice {
  final int price;
  final String currency;  // Always '¥' for hackathon
}
```

**Client behaviour per design doc:**
- Cache the variety catalogue for the session; re-fetch on next app launch
- If the price endpoint is unavailable, display "—" and retry silently
- Price is display-only on client; backend is source of truth
- Never block dish card creation if price fetch fails

**Hackathon implementation:** Since there is no real backend server yet, the service will use a local JSON fixture with variety data and prices, structured so it can be swapped for real HTTP calls later. The fixtures already exist in a compatible format at [`lib/fixtures/ramen.json`](../gourmet_go/lib/fixtures/ramen.json).

### 2D. GameAssetService Updates

Add to [`GameAssetService`](../gourmet_go/lib/services/game_asset_service.dart):

```dart
Future<Uint8List?> getSousChefPortrait();   // Warm, wise older character
Future<Uint8List?> getDarkKitchenBg();       // Moody dimly-lit kitchen
Future<Uint8List?> getDishCardIcon(String regionalStyle);  // Per-region icon
```

Update the `_styleGuide` constant to match the new README art direction:
*"Dreamy anime-inspired isometric pixel art — flat pastel colours, bold outlines, modern indie aesthetic"*

### 2E. GameAudioService Updates

Add new SFX entries to [`GameSfx`](../gourmet_go/lib/services/game_audio_service.dart:108) enum:

```dart
enum GameSfx {
  // ... existing entries
  kitchenAmbience('sfx_kitchen_ambience.mp3'),
  dishCardReveal('sfx_dish_card_reveal.mp3'),
  mapPulse('sfx_map_pulse.mp3'),
  customerArrive('sfx_customer_arrive.mp3'),
}
```

Add `playFtueMusic()` method for the intro track.

---

## Phase 3 — Screen Implementation

### FTUE Screen Flow Diagram

```mermaid
flowchart TD
    A[App Launch] --> B{First launch?}
    B -- Yes --> C[FtueIntroScreen]
    B -- No --> M[MapScreen]
    
    C --> D[Seedance intro video 2-3s]
    D --> E[Dark kitchen BG fades in]
    E --> F[Sous chef portrait slides in]
    F --> G[Opening Story dialogue - typewriter + TTS]
    G --> H[Motivation to Travel dialogue]
    H --> I[Tutorial: First Recipe dialogue]
    I --> J[FtueCameraScreen opens]
    
    J --> K{Photo taken or uploaded}
    K --> L[Claude Vision identifies dish]
    L --> N{Confidence >= 0.6?}
    
    N -- Yes --> O[After Photo dialogue]
    O --> P[Confirm and Prepare dialogue]
    P --> Q[DishCardRevealScreen]
    
    N -- No --> R[Recognition Incorrect dialogue]
    R --> S{Retry or pick starter?}
    S -- Retry --> J
    S -- Pick starter --> T[Show 3 pre-seeded bowls]
    T --> Q
    
    Q --> U[Dish card animates onto menu]
    U --> V[Japan map pulses on region]
    V --> W[Dish Added + Travel Loop Hint dialogue]
    W --> X[First customer arrives]
    X --> Y[Service day begins]
```

### 3A. FtueIntroScreen

New file: `lib/screens/ftue_intro_screen.dart`

**Behaviour:**
1. Play `ftue_intro.mp4` video clip (2-3s) — if asset missing, show dark fade-in
2. Crossfade to dark kitchen background
3. Sous chef portrait slides in from left (reuse animation pattern from [`visual_novel_screen.dart`](../gourmet_go/lib/screens/visual_novel_screen.dart:59))
4. Typewriter text delivers Opening Story + Motivation to Travel + Tutorial prompt
5. ElevenLabs TTS speaks each dialogue section in sequence
6. After "Tutorial: First Recipe" dialogue completes → transition to camera

**Key differences from existing VisualNovelScreen:**
- Multiple sequential dialogue sections, not a single quote
- Plays a video first
- Dark/moody tone instead of region-coloured
- Transitions to camera, not pushed from existing stack
- Sous chef character, not "Chef Guide"

**Dialogue sections** (from the design doc):
1. Opening Story — 4 paragraphs
2. Motivation to Travel — 2 paragraphs  
3. Tutorial: First Recipe — 2 paragraphs

### 3B. Camera Screen Rework

**Rework** the existing [`camera_screen.dart`](../gourmet_go/lib/screens/camera_screen.dart) to serve both FTUE and normal gameplay.

The current camera screen is basic — it takes a photo, sends to `identifyDish()` for a prose string, and shows results. The reworked version needs:

#### Core Changes
1. **Structured recognition**: Call `identifyDishStructured()` instead of `identifyDish()` — returns JSON with `ramen_name`, `regional_style`, `broth_base`, `regional_lore`, `confidence_0_to_1`, `variety_id`
2. **Price fetch**: After successful identification, call `RamenApiService.getPrice(varietyId)` — non-blocking, show "—" as placeholder
3. **Confidence branching**:
   - `>= 0.6` → sous chef "After Photo" line → "Confirm and Prepare" line → proceed to reveal
   - `< 0.6` → sous chef "Recognition Incorrect" line → retry or pick starter
4. **3D model kickoff**: On successful identification, fire `TripoService.startGeneration()` in background — the GLB URL arrives later and gets stored on the Dish object
5. **Dish object creation**: Build a `Dish` model from the structured response + price + photo bytes
6. **Sous chef overlay**: Mini visual novel dialogue overlay at the bottom with portrait thumbnail and typewriter text
7. **Mode parameter**: Accept `isFtue: bool` to control whether to show FTUE-specific dialogue or normal gameplay dialogue

#### FTUE Mode vs Normal Mode

| Aspect | FTUE Mode | Normal Mode |
|--------|-----------|-------------|
| Dialogue after photo | Full sous chef speech from design doc Section 4 | Short one-liner |
| Dialogue on confirm | Full speeches from design doc | Brief confirmation |
| Retry dialogue | Full speech from design doc | Short retry prompt |
| Starter picker | Shows 3 pre-seeded bowls as fallback | Not shown, just retry |
| Next screen | DishCardRevealScreen then MapScreen | DishCardRevealScreen then back to kitchen |
| Service timer pause | N/A - no service running | Brief pause with sous chef grace line |

#### Starter Picker Widget

Bottom sheet with 3 pre-seeded dishes from fixtures:
- [`ramen.json`](../gourmet_go/lib/fixtures/ramen.json) — Hakata Tonkotsu
- [`masuzushi.json`](../gourmet_go/lib/fixtures/masuzushi.json) — Masuzushi
- [`takoyaki.json`](../gourmet_go/lib/fixtures/takoyaki.json) — Takoyaki

Each shows a thumbnail, name, region, and rarity badge. Tapping one skips the photo and creates a Dish directly from fixture data.

#### Camera → Dish Pipeline Sequence

```mermaid
sequenceDiagram
    participant Player
    participant Camera as CameraScreen
    participant Claude as GuideService
    participant API as RamenApiService
    participant Tripo as TripoService
    participant Reveal as DishCardRevealScreen

    Player->>Camera: Take photo / upload
    Camera->>Claude: identifyDishStructured - image bytes
    Claude-->>Camera: JSON with name, region, confidence, variety_id
    
    alt confidence >= 0.6
        Camera->>API: getPrice - variety_id - non-blocking
        Camera->>Tripo: startGeneration - image bytes - background
        Camera->>Camera: Show sous chef After Photo dialogue
        Camera->>Camera: Show Confirm and Prepare dialogue
        API-->>Camera: price or placeholder
        Camera->>Reveal: Navigate with Dish object
        Tripo-->>Reveal: GLB URL arrives later via polling
    else confidence < 0.6
        Camera->>Camera: Show Recognition Incorrect dialogue
        Camera->>Camera: Offer retry or starter picker
    end
```

### 3C. DishCardRevealScreen

New file: `lib/screens/dish_card_reveal_screen.dart`  
(This replaces the empty [`reveal_screen.dart`](../gourmet_go/lib/screens/reveal_screen.dart))

**Animations:**
1. Dish card builds from photo: flip/scale entrance with glow
2. Rarity tier badge stamps on with particle effect
3. Regional lore text fades in
4. Small Japan map widget shows the identified region pulsing
5. Sous chef delivers "Dish Added to Menu" + "Travel Loop Hint" dialogue
6. "Start Service" CTA button appears

**Dish card visual:**
- Player photo thumbnail (rounded)
- Ramen name + regional style
- Broth base tag
- Rarity border colour (Common=grey, Uncommon=blue, Rare=gold, Legendary=purple/shimmer)
- Regional lore 1-2 sentences
- Price display (from backend or placeholder "—")

### 3D. Transition to Service

After the reveal screen CTA:
1. Fade transition to MapScreen
2. Map shows the identified region pulsing
3. First AI-generated customer arrives (calls existing customer generation)
4. Service day begins

For the hackathon prototype, this means transitioning to the existing map → shop → visual novel flow, but now with a dish on the menu.

### 3E. Menu Board Screen

New file: `lib/screens/menu_board_screen.dart`

The Menu Board is the player's dish collection — every ramen they have discovered. Each entry shows the dish card with its 3D model viewable via tap.

**Layout:**
- Scrollable grid of dish cards, grouped by region
- Each card shows: player photo thumbnail, ramen name, regional style, rarity border, price
- Camera FAB at bottom-right to add new bowls at any time
- Accessible from the bottom nav bar during gameplay

**3D Model Viewer:**
- Uses `flutter_3d_controller` package already in [`pubspec.yaml`](../gourmet_go/pubspec.yaml:16)
- Tapping a dish card opens a detail bottom sheet or full-screen overlay
- The detail view shows:
  - Interactive 3D GLB model rendered via `Flutter3DViewer` — user can rotate/zoom
  - If GLB still generating via Tripo, show spinning placeholder with progress
  - If GLB generation failed, show the player photo as fallback
  - Full recipe data: dish name, region, broth base, rarity tier, regional lore
  - Ingredient list from the `Recipe` model
  - Prep steps with descriptions
  - Stats: times served, avg stars, discovery date
  - Price from backend API

**3D Model Data Flow:**
```mermaid
flowchart LR
    A[Player takes photo] --> B[Camera screen]
    B --> C[TripoService.startGeneration - background]
    C --> D[Poll for GLB URL]
    D --> E[Store GLB URL on Dish object]
    E --> F[Menu Board shows 3D model]
    F --> G[Flutter3DViewer loads GLB from URL]
```

**Integration with dish creation:**
- When a dish is created in the camera screen, `TripoService.startGeneration()` fires in background
- The `Dish` object stores `glbUrl` as nullable — initially null, filled when Tripo completes
- Menu Board checks `dish.glbUrl` to decide whether to show 3D viewer or loading state
- Uses `cached_network_image` pattern for lazy-loading the GLB URL

**Widget: DishCard** (replace existing stub at `lib/widgets/dish_card.dart`):

```dart
class DishCard extends StatelessWidget {
  final Dish dish;
  final VoidCallback? onTap;
  
  // Shows:
  // - Rounded player photo thumbnail
  // - Ramen name
  // - Regional style + broth base tags
  // - Rarity border colour: Common=Color 0xFF9E9E9E, Uncommon=Color 0xFF42A5F5, Rare=Color 0xFFFFD700, Legendary=Color 0xFF9C27B0
  // - Price display or "—" placeholder
  // - 3D model icon if GLB is available
}
```

---

## Phase 4 — Wiring & Polish

### 4A. Main.dart Routing

Update [`main.dart`](../gourmet_go/lib/main.dart):

```dart
// In build:
initialRoute: '/',  // Changed from '/map'

// Add routes:
'/': (context) => const FtueGate(),
'/ftue': (context) => const FtueIntroScreen(),
'/map': (context) => const MapScreen(),
'/menu': (context) => const MenuBoardScreen(),
'/test': (context) => const ApiTestScreen(),
```

`FtueGate` widget:
```dart
class FtueGate extends StatelessWidget {
  @override
  Widget build(context) {
    return FutureBuilder<bool>(
      future: FtueService().isFirstLaunch(),
      builder: (context, snapshot) {
        if (snapshot.data == true) return FtueIntroScreen();
        return MapScreen();
      },
    );
  }
}
```

### 4B. Region Model Updates

Add rarity tier to [`Region`](../gourmet_go/lib/models/region.dart):

```dart
class Region {
  // ... existing fields
  final RarityTier rarityTier;
  final String loreHint;  // One-line hint shown when locked
}
```

Update `Region.all` to match the design doc's 9 regions (hackathon scope: 3-4):

| Region | Rarity |
|--------|--------|
| Kanto | Common |
| Kansai | Common |
| Hokkaido | Uncommon |
| Kyushu | Uncommon |

### 4C. State Management — Riverpod

The design doc specifies Riverpod for reactive state. The key providers needed:

```dart
// Menu state — list of discovered dishes
final menuProvider = StateNotifierProvider<MenuNotifier, List<Dish>>();

// Cash balance
final cashProvider = StateProvider<int>();

// Current day number
final dayProvider = StateProvider<int>();

// FTUE completion state
final ftueCompleteProvider = FutureProvider<bool>();

// Ramen variety catalogue — cached from backend API
final varietiesProvider = FutureProvider<List<RamenVariety>>();
```

These providers allow screens to reactively update when dishes are added, cash changes, etc. The `flame_riverpod` package is already in `pubspec.yaml` for integration with the game engine.

### 4D. Integration Testing

- Test first-launch → FTUE complete flow end-to-end
- Test returning user → goes straight to map
- Test camera retry branch with confidence < 0.6
- Test pre-seeded starter picker fallback
- Test TTS plays correctly during FTUE dialogue
- Test 3D model loads in Menu Board after Tripo completes
- Test price fetch and fallback to "—"
- Test menu board shows all discovered dishes
- Verify on iOS device

---

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/generate_ftue_sprites.py` | Offline sprite generation for sous chef + FTUE backgrounds |
| `scripts/generate_ftue_audio.sh` | FTUE-specific audio generation via ElevenLabs |
| `lib/models/dish.dart` | Full Dish model replacing stub with GLB URL, rarity, region, price |
| `lib/services/ftue_service.dart` | First-launch state tracking via shared_preferences |
| `lib/services/ramen_api_service.dart` | Backend API client: GET /ramen/varieties and GET /ramen/variety_id/price |
| `lib/screens/ftue_intro_screen.dart` | Dark kitchen → sous chef dialogue → camera |
| `lib/screens/menu_board_screen.dart` | Dish collection grid with 3D model viewer per dish |
| `lib/screens/dish_card_reveal_screen.dart` | Animated dish card reveal + map pulse — replaces reveal_screen.dart |
| `lib/widgets/sous_chef_dialogue.dart` | Reusable sous chef dialogue widget with portrait + typewriter |
| `lib/widgets/dish_card.dart` | Full dish card widget with rarity borders, photo, 3D icon — replaces stub |
| `lib/widgets/starter_picker.dart` | Bottom sheet with 3 pre-seeded starter bowls |
| `lib/widgets/dish_detail_sheet.dart` | Full-screen dish detail with 3D model viewer, recipe, stats |
| `lib/providers/game_providers.dart` | Riverpod providers for menu, cash, day, FTUE state |

## Files to Modify

| File | Changes |
|------|---------|
| `lib/main.dart` | Add FTUE gate routing, menu route, wrap with ProviderScope |
| `lib/models/region.dart` | Add rarityTier field, loreHint field |
| `lib/services/guide_service.dart` | Add identifyDishStructured method returning JSON with confidence |
| `lib/services/game_asset_service.dart` | Add sous chef + dark kitchen prompts, update style guide string |
| `lib/services/game_audio_service.dart` | Add FTUE SFX entries + intro music method |
| `lib/screens/camera_screen.dart` | Full rework: structured recognition, confidence branching, Tripo kickoff, price fetch, FTUE/normal mode |
| `generate_audio.sh` | Add FTUE audio generation commands |
| `pubspec.yaml` | Add shared_preferences dep, FTUE asset paths, flutter_riverpod |

---

## Execution Order

The work is ordered to minimize blocking dependencies:

1. **Phase 1** (Asset gen) — can run in parallel, no code dependencies
   - 1A sprites, 1B audio, 1C video can all run simultaneously
2. **Phase 2** (Services + Models) — foundational, unlocks Phase 3
   - 2A Dish model first (everything depends on it)
   - 2B FTUE service, 2C GuideService, 2D GameAssetService, 2E GameAudioService, 2F RamenApiService — can be done in any order
3. **Phase 3** (Screens) — depends on Phase 2
   - 3A intro screen → 3B camera rework → 3C reveal screen → 3D service wiring → 3E menu board
4. **Phase 4** (Integration + Polish) — final wiring
   - 4A routing, 4B region updates, 4C Riverpod providers, 4D testing

---

## Risk Mitigations

| Risk | Mitigation |
|------|------------|
| Gemini sprite gen produces inconsistent art | Pre-generate + review before integrating; use reference image for consistency |
| Seedance intro video too slow | Pre-bake to assets/videos; fallback to animated dark fade-in |
| Claude confidence scoring unreliable | Keep retry path + starter picker as guaranteed fallback |
| TTS latency during FTUE dialogue | Pre-generate all FTUE TTS at app startup; cache locally |
| FTUE too long for hackathon demo | Typewriter text is tappable to skip; video skippable; total <90s |
| Tripo 3D model generation slow | Fire in background, show loading state in menu board, fallback to photo |
| No real backend server | RamenApiService uses local fixtures initially, structured for HTTP swap later |
| GLB model rendering issues on iOS | flutter_3d_controller tested; fallback to static image if WebView fails |
