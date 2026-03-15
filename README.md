# 🍜 Gourmet Go — AI Ramen Discovery Game

**SF GenAI GameJam 2026** — An AI-native Japanese ramen discovery game built with Flutter.

Snap a photo of ramen, and AI identifies the dish, narrates its story, generates ingredient images, creates a cooking video, and builds a 3D model — all in real-time.

---

## Quick Start

### 1. Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) ≥ 3.10.4
- Xcode (for iOS) or Chrome (for web)
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
ELEVENLABS_API_KEY=sk_...        # ElevenLabs (text-to-speech narration)
GEMINI_API_KEY=AIza...           # Google Gemini (ingredient image generation)
```

### 3. Install Dependencies

```bash
cd gourmet_go
flutter pub get
```

### 4. Run the App

**iOS Simulator:**
```bash
flutter run
```

**Chrome (web) — requires CORS bypass for API calls:**
```bash
flutter run -d chrome --web-browser-flag="--disable-web-security"
```

> ⚠️ The `--disable-web-security` flag is required because browser CORS policies block direct calls to Anthropic, ElevenLabs, Tripo, and BytePlus APIs. This is safe for local development only. On native platforms (iOS/macOS/Android) this is not needed.

**macOS Desktop:**
```bash
flutter run -d macos
```

**Specific device:**
```bash
flutter devices          # List available devices
flutter run -d <device>  # Run on a specific device
```

---

## Screens

The app currently defaults to the **API Test Screen** (`/test` route). This is configured in [`lib/main.dart`](lib/main.dart:33).

### API Test Screen (`/test`)

The main development/testing screen with 8 sections. Run the app and it opens automatically.

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

### Home Screen (`/`)

Placeholder screen. To switch the default screen, edit [`lib/main.dart`](lib/main.dart:33):

```dart
// Change this:
initialRoute: '/test',
// To this:
initialRoute: '/',
```

---

## Project Structure

```
gourmet_go/
├── lib/
│   ├── main.dart                    # App entry point, routes
│   ├── models/
│   │   ├── recipe.dart              # Recipe + Ingredient models
│   │   ├── line_cook.dart           # LineCook character model
│   │   └── customer.dart            # Customer model
│   ├── services/
│   │   ├── guide_service.dart       # Claude API — dish ID, chat, recipes
│   │   ├── elevenlabs_service.dart  # ElevenLabs TTS — narration audio
│   │   ├── gemini_image_service.dart# Gemini — ingredient image generation
│   │   ├── seedance_service.dart    # BytePlus Seedance — video generation
│   │   ├── tripo_service.dart       # Tripo3D — image-to-3D model
│   │   ├── line_cook_service.dart   # Claude API — chef generation
│   │   ├── customer_service.dart    # Claude API — customer queue
│   │   └── review_service.dart      # Claude API — reviews
│   ├── screens/
│   │   ├── api_test_screen.dart     # 8-section API test dashboard
│   │   ├── camera_screen.dart       # Camera (stub)
│   │   ├── map_screen.dart          # Japan map (stub)
│   │   ├── prep_loop_screen.dart    # Cooking prep (stub)
│   │   ├── restaurant_screen.dart   # Restaurant (stub)
│   │   └── reveal_screen.dart       # Dish reveal (stub)
│   └── widgets/                     # UI components (stubs)
├── assets/
│   ├── images/
│   │   └── tonkotsu_ramen_basic.png # Test ramen photo
│   ├── models/
│   │   ├── tonkotsu_ramen.glb       # 3D model (generated from test photo)
│   │   ├── ramen.glb                # Placeholder GLB
│   │   ├── masuzushi.glb            # Placeholder GLB
│   │   └── takoyaki.glb             # Placeholder GLB
│   ├── videos/                      # Pre-baked video assets
│   └── audio/                       # Sound effects
├── .env                             # API keys (gitignored)
├── .env.example                     # Template for API keys
└── pubspec.yaml                     # Dependencies
```

---

## API Services Summary

| Service | API | Model | Auth |
|---------|-----|-------|------|
| GuideService | Anthropic Claude | `claude-sonnet-4-20250514` | `x-api-key` header |
| ElevenLabsService | ElevenLabs | `eleven_multilingual_v2` | `xi-api-key` header |
| GeminiImageService | Google Gemini | `gemini-2.0-flash-exp` | API key in URL |
| SeedanceService | BytePlus ModelArk | `seedance-1-5-pro-251215` | `Bearer` token |
| TripoService | Tripo3D | `v2.5-20250123` (auto) | `Bearer` token |
| LineCookService | Anthropic Claude | `claude-sonnet-4-20250514` | `x-api-key` header |
| CustomerService | Anthropic Claude | `claude-sonnet-4-20250514` | `x-api-key` header |
| ReviewService | Anthropic Claude | `claude-sonnet-4-20250514` | `x-api-key` header |

---

## Troubleshooting

**"No .env file found"** — Run `cp .env.example .env` and add your API keys.

**Image picker not working on iOS simulator** — Use the "Load Test Ramen" button instead.

**ModelViewer blank on iOS** — GLB rendering requires WebView. Try running on Chrome (`flutter run -d chrome`) for best 3D support.

**Seedance returns 404** — Make sure you're using `ARK_API_KEY` (not `SEEDANCE_API_KEY`) and the endpoint is `/api/v3/contents/generations/tasks`.

**flutter analyze shows warnings** — All current issues are info-level `avoid_print` hints, safe to ignore during development.
