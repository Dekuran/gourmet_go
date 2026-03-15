# Sprite Generation Plan — Gourmet GO

> Plan for generating all sprite sheets needed for the Flame game UI defined
> in [flame_implementation.md](flame_implementation.md), using the pipeline
> from [sprite_generation_example/](sprite_generation_example/).

---

## Pipeline Summary

The existing example pipeline (`docs/sprite_generation_example/`) provides:

1. **`generate_sprites.py`** — Generates one sprite per API call via Gemini
   (primary) or DALL-E 3 (fallback), using a reference image for character
   consistency.
2. **Background removal** — Solid `#00FF88` lime-green (or `#111111` charcoal
   for light sprites) backgrounds, removed via PIL chroma-key or rembg.
3. **Normalisation** — Trim, pad to square, resize to 512x512.
4. **Atlas** — Reference atlas for visual review.
5. **Sprite sheet assembly** — PIL horizontal strip stitching for animation
   frames, loaded in Flame via `SpriteSheet`.

We will create a new script (`scripts/generate_game_sprites.py`) that follows
this same structure, with its own `SPRITES` dictionary, reference images, and
output directory (`assets/sprites/`).

---

## Art Style

Per the README: **"Dreamy anime-inspired isometric pixel art — flat pastel
colours, bold outlines, modern indie aesthetic."**

Master style keywords for every prompt:

```
Dreamy anime-inspired, flat pastel colours, bold black outlines,
cel-shaded, modern indie game aesthetic. Single character/object,
centred, isolated. 512x512, game sprite.
```

Use `#111111` charcoal background for all sprites (pastel colours would blend
with lime-green).

---

## Sprite Inventory

### 1. Chef Sprites

The game supports 1-3 chefs. Each chef needs sprites for the `CookBehavior`
state machine: `available → cooking → plating → available`.

| Sprite Name | Pose / State | Reference Image | Notes |
|---|---|---|---|
| `chef_idle` | Standing at station, arms relaxed, smiling | Yes (create ref first) | Default "available" state |
| `chef_cooking_01` | Stirring pot, focused expression | Yes | Cooking animation frame 1 |
| `chef_cooking_02` | Lifting noodles with chopsticks | Yes | Cooking animation frame 2 |
| `chef_cooking_03` | Adding toppings / garnish | Yes | Cooking animation frame 3 |
| `chef_plating` | Presenting finished bowl, proud smile | Yes | Brief "plating" state (1s) |

**Sprite sheet:** Assemble `chef_cooking_01..03` into `spritesheet_chef_cooking.png` (3-frame horizontal strip, 512x512 each → 1536x512).

**Chef variants:** Generate 3 colour variants (different apron/bandana colours) for the 3 hirable chefs. Use the same prompts but specify different accent colours:
- Chef 1: Red apron/bandana (default)
- Chef 2: Blue apron/bandana
- Chef 3: Green apron/bandana

**Total: 5 poses x 3 colour variants = 15 sprites + 3 cooking sprite sheets**

---

### 2. Customer Sprites

Customers appear in a queue (up to 8). They need sprites for the
`WaitBehavior` states: `arriving → waiting → served → left_unhappy`.

| Sprite Name | Pose / State | Reference Image | Notes |
|---|---|---|---|
| `customer_01_waiting` | Standing, looking expectant | No (unique designs) | Casual diner |
| `customer_01_served` | Happy, hands clasped, sparkle eyes | No | Satisfied reaction |
| `customer_01_unhappy` | Frowning, arms crossed, anger symbol | No | Patience expired |
| `customer_02_waiting` | ... | No | Different character design |
| `customer_02_served` | ... | No | |
| `customer_02_unhappy` | ... | No | |
| ... | | | |

**Variety:** Generate 6 unique customer character designs (enough visual
variety for a queue of 8 — Flame can randomly assign). Each needs 3 poses
(waiting, served, unhappy).

**Total: 6 characters x 3 poses = 18 sprites**

---

### 3. Kitchen Background

Single static background for the `KitchenBackground` `SpriteComponent`.

| Sprite Name | Description | Size | Notes |
|---|---|---|---|
| `kitchen_bg` | Isometric ramen kitchen interior — countertops, stove with pots, noren curtain, warm lighting | 1024x768 | Wider than standard; no solid-BG removal needed (full scene) |

**Prompt approach:** Generate as a full scene (no background removal). Use a
specific prompt for isometric perspective matching the game's art style.

**Total: 1 sprite**

---

### 4. Speech Bubble & UI Components

In-game UI elements rendered as Flame `SpriteComponent`s.

| Sprite Name | Description | Size | Notes |
|---|---|---|---|
| `speech_bubble` | Rounded speech bubble with tail pointing down | 256x256 | White fill, bold outline; dish icon overlaid programmatically |
| `progress_bar_bg` | Horizontal bar background (dark, rounded ends) | 256x32 | Sliced in code; or use Flame `RectangleComponent` |
| `progress_bar_fill` | Horizontal bar fill (gradient green→orange→red) | 256x32 | Tinted programmatically |
| `patience_bar_bg` | Same style as progress bar | 256x32 | Reuse `progress_bar_bg` |
| `patience_bar_fill` | Yellow→red gradient fill | 256x32 | Tinted programmatically |

**Decision:** Progress/patience bars are simple enough to render with Flame
`RectangleComponent` + paint. Only generate `speech_bubble` as a sprite.
The bars should be built programmatically.

**Total: 1 sprite (speech bubble)**

---

### 5. Ramen Bowl Sprites

Dish icons shown inside speech bubbles and on the menu. These represent the
ramen varieties from the API.

| Sprite Name | Description | Reference Image | Notes |
|---|---|---|---|
| `bowl_tonkotsu` | Tonkotsu ramen bowl (creamy white broth, chashu, egg) | No | Top-down view |
| `bowl_shoyu` | Shoyu ramen bowl (clear brown broth, nori, menma) | No | Top-down view |
| `bowl_miso` | Miso ramen bowl (orange broth, corn, butter) | No | Top-down view |
| `bowl_shio` | Shio ramen bowl (clear pale broth, seafood) | No | Top-down view |

**Total: 4 sprites**

---

### 6. Sous Chef (FTUE Character)

The sous chef appears in the FTUE monologue overlay and the contextual
commentary bubble. This is a Flutter overlay (not a Flame component), but a
character portrait sprite is still needed.

| Sprite Name | Description | Reference Image | Notes |
|---|---|---|---|
| `sous_chef_neutral` | Friendly sous chef portrait, neutral expression | Yes (create ref first) | Half-body portrait, facing forward |
| `sous_chef_excited` | Same character, excited/encouraging expression | Yes | For positive commentary |
| `sous_chef_thinking` | Same character, hand on chin, pondering | Yes | For hints/tips |

**Total: 3 sprites**

---

### 7. Map & Region Icons

The Japan map overlay is Flutter SVG-based, but region markers and
decorative elements could use sprites.

| Sprite Name | Description | Size | Notes |
|---|---|---|---|
| `region_marker_locked` | Grey ramen bowl icon (locked region) | 128x128 | Greyed out |
| `region_marker_unlocked` | Full-colour ramen bowl icon (unlocked) | 128x128 | Glowing/vibrant |
| `region_marker_discovered` | Pulsing glow ramen bowl (photo detected) | 128x128 | Intermediate state |

**Decision:** These can likely be handled with Flutter widgets (SVG + colour
filters). Skip sprite generation unless Flutter widgets prove insufficient.

**Total: 0 sprites (deferred)**

---

## Summary — Full Sprite List

| Category | Count | Priority |
|---|---|---|
| Chef sprites (3 variants x 5 poses) | 15 | Phase 4 (Chef Mechanics) |
| Chef cooking sprite sheets (3) | 3 sheets | Phase 4 |
| Customer sprites (6 characters x 3 poses) | 18 | Phase 5 (Customer System) |
| Kitchen background | 1 | Phase 4 |
| Speech bubble | 1 | Phase 5 |
| Ramen bowl icons | 4 | Phase 3 (Camera & Menu) |
| Sous chef portraits | 3 | Phase 2 (FTUE) |
| **Total individual sprites** | **42** | |
| **Total sprite sheets** | **3** | |

---

## Generation Order (by build phase)

### Batch 1 — Phase 2: FTUE (3 sprites)

Generate sous chef reference image first, then 3 portrait variants.

```
sous_chef_neutral, sous_chef_excited, sous_chef_thinking
```

### Batch 2 — Phase 3: Camera & Menu (4 sprites)

Ramen bowl icons for dish cards and speech bubbles.

```
bowl_tonkotsu, bowl_shoyu, bowl_miso, bowl_shio
```

### Batch 3 — Phase 4: Chef Mechanics (16 sprites + 3 sheets)

Generate chef reference image first, then all poses x3 colour variants.

```
chef_idle (x3 variants)
chef_cooking_01, _02, _03 (x3 variants) → assemble into spritesheet_chef_cooking_[1-3].png
chef_plating (x3 variants)
kitchen_bg
```

### Batch 4 — Phase 5: Customer System (19 sprites)

6 unique customer designs, each with 3 poses, plus the speech bubble.

```
customer_[01-06]_waiting, _served, _unhappy
speech_bubble
```

---

## Script Structure

Create `scripts/generate_game_sprites.py` by adapting the example pipeline:

```
scripts/
├── generate_game_sprites.py    # Main script (adapted from example)
├── remove_bg.py                # Copy from example (or symlink)
├── requirements.txt            # Same deps as example
├── .env.example                # Same keys
├── reference_images/
│   ├── chef_ref.png            # Generated first, used for chef variants
│   └── sous_chef_ref.png       # Generated first, used for sous chef variants
└── sprites/                    # Raw output (review here)
    └── nobg/                   # Background-removed
```

Final approved sprites get copied into `assets/sprites/` and declared in
`pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/sprites/
```

---

## Script Modifications from Example

1. **New `SPRITES` dictionary** — All 42 entries defined with Gourmet GO
   prompts and the dreamy-pastel art style keywords.
2. **`--batch` flag** — Accept a batch name (`ftue`, `menu`, `chef`,
   `customer`) to generate only that batch, enabling incremental generation
   aligned with the phased build.
3. **`--variant` flag** — For chef sprites, generate colour variants by
   swapping accent colour keywords in the prompt template.
4. **Sprite sheet assembly step** — After generating `chef_cooking_01..03`,
   auto-assemble into horizontal strip PNG using the PIL pattern from the
   art style guide.
5. **Output to `assets/sprites/`** — Final `--deploy` flag copies
   background-removed sprites from `sprites/nobg/` into the game's asset
   directory and prints a `pubspec.yaml` snippet.
6. **Charcoal background default** — Use `#111111` instead of `#00FF88`
   since pastels blend with lime-green.

---

## Prompt Templates

### Chef (with reference)

```
Dreamy anime-inspired Japanese ramen chef character.
Flat pastel colours, bold black outlines, cel-shaded, modern indie aesthetic.

CHEF CHARACTER:
A friendly young ramen chef wearing a white chef coat and a [RED] bandana.
Rolled-up sleeves. Confident but warm expression.
Standing behind a ramen counter.

POSE: [IDLE / COOKING / PLATING]
[Pose-specific description here]

Place on SOLID DARK CHARCOAL background (#111111).
Do NOT use transparent, checkered, or gradient backgrounds.
NO text, NO labels, NO captions, NO watermarks.
512x512, single character, centred, isolated, cel-shaded game sprite.
```

### Customer (unique, no reference)

```
Dreamy anime-inspired Japanese restaurant customer.
Flat pastel colours, bold black outlines, cel-shaded, modern indie aesthetic.

CUSTOMER CHARACTER [N]:
[Unique character description — age, clothing, personality]
Chibi proportions, cute and friendly design.

POSE: [WAITING / SERVED / UNHAPPY]
[Pose-specific description]

Place on SOLID DARK CHARCOAL background (#111111).
NO text, NO labels, NO captions, NO watermarks.
512x512, single character, centred, isolated, cel-shaded game sprite.
```

### Ramen Bowl (no reference)

```
Dreamy anime-inspired ramen bowl illustration, top-down view.
Flat pastel colours, bold black outlines, cel-shaded, modern indie aesthetic.

DISH: [TONKOTSU / SHOYU / MISO / SHIO] RAMEN
[Specific broth colour, toppings, garnish description]
Beautiful presentation in a traditional ceramic bowl.

Place on SOLID DARK CHARCOAL background (#111111).
NO text, NO labels, NO captions, NO watermarks.
512x512, single object, centred, isolated, game icon.
```

---

## Estimated Cost

| Batch | Sprites | Cost (Gemini) | Cost (DALL-E 3) |
|---|---|---|---|
| FTUE (sous chef) | 3 + 1 ref | ~$0.12 | ~$0.24 |
| Menu (bowls) | 4 | ~$0.12 | ~$0.24 |
| Chef | 15 + 1 ref | ~$0.48 | ~$0.96 |
| Customer | 18 | ~$0.54 | ~$1.08 |
| Kitchen BG | 1 | ~$0.04 | ~$0.08 |
| Speech bubble | 1 | ~$0.04 | ~$0.08 |
| **Total** | **44** | **~$1.34** | **~$2.68** |

---

## Pre-Requisites

- [ ] Gemini API key configured in `.env` (or `scripts/.env`)
- [ ] Python 3.10+ available (script bootstraps its own venv)
- [ ] Review and finalise art style keywords with the team before first batch
- [ ] Create chef and sous chef reference images (generate one "hero" sprite
      first, review, then use as reference for consistency)

---

## Flame Integration

Once sprites are in `assets/sprites/`, load them in Flame:

```dart
// Single sprite
final chefIdle = await Sprite.load('sprites/chef_idle_red.png');

// Animation from sprite sheet
final sheet = SpriteSheet(
  image: await images.load('sprites/spritesheet_chef_cooking_red.png'),
  srcSize: Vector2(512, 512),
);
final cookingAnim = sheet.createAnimation(row: 0, stepTime: 0.4, to: 3);
```

Progress bars and patience bars should be built with Flame's
`RectangleComponent` + custom `Paint` rather than sprites for easy
colour/size manipulation.
