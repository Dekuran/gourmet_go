# 🍜 Gourmet Go

**SF GenAI GameJam 2026** — An AI-native Japanese ramen discovery game built with Flutter.

*Every journey starts with a single bowl.*

Build your ramen empire from a tiny eatery to a bustling restaurant! Snap every bowl you eat across Japan to unlock authentic regional styles, level up your chefs, and serve hungry customers in this dreamy isometric sim.

Snap a photo of ramen and AI identifies the dish, narrates its story, generates ingredient images, creates a cooking video, and builds a 3D model — all in real-time.

---

## Details

| | |
|---|---|
| **Platform** | iOS |
| **Stack/Engine** | Flutter / Flame |
| **Game Type** | Simulation |
| **Age Rating** | 3+ |
| **Art Style** | Dreamy anime-inspired isometric pixel art — flat pastel colours, bold outlines, modern indie aesthetic |

---

## Quick Start

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.41.4 (Dart ≥ 3.11.1)
- Xcode (for iOS simulator or device)
- API keys (see below)

### 2. Set Up API Keys

```bash
cd gourmet_go
cp .env.example .env
```

Edit `.env` and fill in your keys:

```env
CLAUDE_API_KEY=sk-ant-...        # Anthropic Claude (dish identification, recipes, reviews)
TRIPO_API_KEY=tsk_...            # Tripo3D (image-to-3D model)
ARK_API_KEY=...                  # BytePlus ModelArk (Seedance video generation)
ELEVENLABS_API_KEY=sk_...        # ElevenLabs (TTS narration + game audio)
GEMINI_API_KEY=AIza...           # Google Gemini (game asset + ingredient image generation)
```

### 3. Install Dependencies

```bash
cd gourmet_go
flutter pub get
```

### 4. Generate Audio Assets

Run once to generate all SFX and music via ElevenLabs:

```bash
bash generate_audio.sh
```

### 5. Run the App

```bash
flutter run
```

The app launches into the **Japan Map** screen (`/map` route).

---

## Chrome (Development/Testing Only)

Chrome is used purely as a fast iteration target during development — it is **not** the intended platform and has no camera access or full native feature support. To run on Chrome locally you need to disable CORS since the APIs don't allow browser origins:

```bash
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

> ⚠️ `--disable-web-security` is safe for local development only. Never deploy a web build with this flag.

For API testing without a connected device, use the **API Test Screen** (see below) on Chrome.

---

## Screens

### Game Screens

The app launches into the **Japan Map** screen. The full game flow is:

```
Map → (tap region) → Ramen Shop → (enter) → Visual Novel → (take photo) → Camera
```

| Screen | Route | Description |
|--------|-------|-------------|
| **Japan Map** | `/map` | Isometric Japan map with 4 tappable regions. Chef sprite walks between them. Ramen bowl icons float above each region. |
| **Ramen Shop** | *(pushed)* | Regional shop exterior. Chef shuffles in from the side. Transitions into the shop. |
| **Visual Novel** | *(pushed)* | Chef portrait + typewriter dialogue + ElevenLabs TTS voice. Ends with "Take Photo" CTA. |
| **Camera** | *(pushed)* | Full-screen camera with scanning overlay. Claude Vision identifies the ramen dish. |

### API Test Screen (`/test`)

A development dashboard for testing all AI services independently. Switch to it by editing [`lib/main.dart`](lib/main.dart):

```dart
initialRoute: '/test',
```

| Section | Service | What It Tests |
|---------|---------|---------------|
| **§1** | GuideService (Claude) | Load test ramen photo → Identify dish → Chat follow-up → Generate recipe JSON |
| **§7** | ElevenLabs TTS | Generate speech from guide narration → Play/stop audio |
| **§8** | Gemini Images | Generate ingredient images (top 3) → Horizontal scroll gallery |
| **§6** | SeedanceService (BytePlus) | Generate cooking video → Poll for completion → Play video |
| **§2** | TripoService (Tripo3D) | Upload image → Generate 3D GLB model → View with ModelViewer |
| **§3** | LineCookService (Claude) | Generate a ramen chef character |
| **§4** | CustomerService (Claude) | Generate a queue of customers |
| **§5** | ReviewService (Claude) | Generate high/low score reviews |

#### Recommended Test Flow

1. Tap **"Load Test Ramen"** to load `tonkotsu_ramen_basic.png`
2. Tap **"Identify Dish"** — Claude identifies it as Hakata Tonkotsu Ramen
3. Tap **"Generate Recipe"** — Claude produces full recipe JSON
4. Scroll to §7, tap **"Generate Speech"** — ElevenLabs speaks the narration
5. Scroll to §8, tap **"Generate Ingredient Images"** — Gemini creates ingredient photos
6. Scroll to §6, tap **"Start (live)"** — Seedance generates a cooking video (~60s)
7. Scroll to §2, tap **"Start (live)"** — Tripo generates a 3D ramen model (~50s)

---

## Project Structure

```
gourmet_go/
├── lib/
│   ├── main.dart                    # App entry point, routes
│   ├── models/
│   │   ├── recipe.dart              # Recipe + Ingredient models
│   │   ├── prep_step.dart           # Prep step model
│   │   ├── line_cook.dart           # LineCook character model
│   │   ├── customer.dart            # Customer model
│   │   ├── region.dart              # Region data (4 Japan regions)
│   │   └── dish.dart                # Dish model
│   ├── services/
│   │   ├── guide_service.dart       # Claude API — dish ID, chat, recipes
│   │   ├── game_asset_service.dart  # Gemini — generates all game sprites/BGs
│   │   ├── game_audio_service.dart  # ElevenLabs — SFX, music, runtime TTS
│   │   ├── elevenlabs_service.dart  # ElevenLabs TTS — narration audio
│   │   ├── gemini_image_service.dart# Gemini — ingredient image generation
│   │   ├── seedance_service.dart    # BytePlus Seedance — video generation
│   │   ├── tripo_service.dart       # Tripo3D — image-to-3D model
│   │   ├── line_cook_service.dart   # Claude API — chef generation
│   │   ├── customer_service.dart    # Claude API — customer queue
│   │   ├── review_service.dart      # Claude API — reviews
│   │   └── debug_logger.dart        # Debug logging utility
│   ├── screens/
│   │   ├── map_screen.dart          # Japan map — isometric, animated chef
│   │   ├── ramen_shop_screen.dart   # Regional shop arrival screen
│   │   ├── visual_novel_screen.dart # Chef dialogue + TTS + camera CTA
│   │   ├── camera_screen.dart       # Ramen photo capture + AI analysis
│   │   ├── api_test_screen.dart     # 8-section API test dashboard
│   │   ├── prep_loop_screen.dart    # Cooking prep loop
│   │   ├── restaurant_screen.dart   # Restaurant sim
│   │   └── reveal_screen.dart       # Dish reveal
│   └── widgets/
│       ├── chef_reaction.dart       # Chef reaction widget
│       ├── dish_card.dart           # Dish display card
│       ├── item_table.dart          # Item table widget
│       └── timing_bar.dart          # Timing bar widget
├── assets/
│   ├── images/                      # Game images
│   │   └── tonkotsu_ramen_basic.png # Test ramen photo
│   ├── models/                      # 3D GLB models
│   ├── videos/                      # Pre-baked video assets
│   └── audio/                       # SFX + music (generated by generate_audio.sh)
├── docs/
│   ├── restaurant_sim_prototype.md  # Full game design document
│   └── todo.md                      # Hackathon build task breakdown (BE/FE)
├── lib/fixtures/                    # JSON fixture data
│   ├── ramen.json
│   ├── masuzushi.json
│   └── takoyaki.json
├── generate_audio.sh                # Generates SFX + music via ElevenLabs
├── .env                             # API keys (gitignored)
├── .env.example                     # Template for API keys
└── pubspec.yaml                     # Dependencies
```

---

## API Services Summary

| Service | API | Model | Auth |
|---------|-----|-------|------|
| GuideService | Anthropic Claude | `claude-sonnet-4-20250514` | `x-api-key` header |
| GameAssetService | Google Gemini | `gemini-2.0-flash-preview-image-generation` | API key in URL |
| GameAudioService | ElevenLabs | `eleven_turbo_v2_5` (TTS) + sound-generation + music.compose | `xi-api-key` header |
| ElevenLabsService | ElevenLabs | `eleven_multilingual_v2` | `xi-api-key` header |
| GeminiImageService | Google Gemini | `gemini-2.0-flash-exp` | API key in URL |
| SeedanceService | BytePlus ModelArk | `seedance-1-5-pro-251215` | `Bearer` token |
| TripoService | Tripo3D | `v2.5-20250123` (auto) | `Bearer` token |

---

## Troubleshooting

**"No .env file found"** — Run `cp .env.example .env` and add your API keys.

**Image picker not working on iOS simulator** — Use the "Load Test Ramen" button on the API Test Screen instead.

**ModelViewer blank on iOS** — GLB rendering requires WebView. Try running on Chrome (`flutter run -d chrome`) for best 3D support during development.

**Seedance returns 404** — Make sure you're using `ARK_API_KEY` (not `SEEDANCE_API_KEY`) and the endpoint is `/api/v3/contents/generations/tasks`.

**`generate_audio.sh` music generation fails** — Install the ElevenLabs Python SDK: `pip install elevenlabs`.

**flutter analyze shows warnings** — All current issues are info-level `avoid_print` hints, safe to ignore during development.

**SDK version mismatch** — This project requires Dart ≥ 3.11.1 (Flutter ≥ 3.41.4). Run `flutter upgrade` if needed.
