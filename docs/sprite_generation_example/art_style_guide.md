# Art Style Guide — Sprite Generation

> Visual style rules, prompt patterns, and conventions for generating
> consistent game sprites using AI (Gemini / DALL-E 3).

---

## 1. Master Style Keywords

Always include these in every sprite prompt:

```
Chibi proportions, cel-shaded, bold black outlines, flat bright colours.
512×512, single character, isolated, game sprite.
```

---

## 2. Colour Palette

| Role | Hex | Usage |
|------|-----|-------|
| Background dark | `#0D1B0A` / `#1A1A2E` | Game backgrounds |
| Primary green | `#4CAF50` | Nature, health |
| Gold | `#FFD700` | Rewards, XP, accents |
| Red (player) | `#E53935` | Player character |
| Purple (enemy) | `#7B1FA2` | Enemy characters |
| Health bar | `#4CAF50` → `#FF9800` → `#F44336` | Green/orange/red gradient |
| XP bar | `#FFD700` | Gold |
| Text primary | `#FFFFFF` | White |
| Text secondary | `rgba(255,255,255,0.7)` | Semi-transparent white |

---

## 3. Sprite Resolution Standards

| Asset Type | Resolution | Notes |
|------------|-----------|-------|
| Character sprites | 512×512 | Trimmed and padded to square |
| Enemy sprites | 512×512 | Same as characters |
| Icons / orbs | 256×256 | Smaller for UI elements |
| Tiles / blocks | 512×512 | May be scaled down in-game |
| Animation frames | 512×512 each | Assembled into strip/sheet |
| Transparency | PNG-24 with alpha | Never JPEG for sprites |

---

## 4. Background Strategy

### What to Request

| BG Type | When to Use | Hex |
|---------|-------------|-----|
| Lime green | Most sprites (default) | `#00FF88` |
| Dark charcoal | Sprites with white/light/glowing details | `#111111` |

### What NEVER to Request

❌ "transparent background" — produces checkerboard artefacts  
❌ "no background" — AI interprets inconsistently  
❌ "white background" — hard to distinguish from white character details  
❌ gradients, vignettes, spotlights

### Background Prompt Template

```python
# Lime green (default)
BG_INSTRUCTION = (
    "Place the character on a SOLID BRIGHT LIME-GREEN background (hex #00FF88). "
    "Do NOT use transparent, checkered, gradient, white, or any other background. "
    "Only this exact solid colour. It will be removed in post-processing."
)

# Dark charcoal (for light-coloured sprites)
DARK_BG_INSTRUCTION = (
    "Place the character on a SOLID VERY DARK CHARCOAL background (hex #111111). "
    "Do NOT use transparent, checkered, gradient, vignette, spotlight, texture. "
    "Use one flat uniform dark background only."
)
```

---

## 5. Prompt Structure

### Anatomy of a Good Sprite Prompt

```
[1. Character description — physical traits, colours, proportions]

[2. Pose description — specific action, expression, body position]

[3. Background instruction — solid colour, no transparency]

[4. Negative instructions — no text, no labels, etc.]

[5. Technical specs — size, style, format]
```

### Example: Player Character

```
A cute cartoon Japanese daruma doll character.
Round glossy RED body shaped like a traditional daruma doll.
Long BUNNY / RABBIT EARS on top (same red as body, pink inside).
Cream face area with cat-like WHISKERS. Small pink NOSE.
Closed happy curved EYES (cat-smile eyes).
Chibi proportions, cel-shaded, bold black outlines, flat bright colours.

POSE: IDLE
The character faces forward, upright, resting. Bunny ears stand straight up.
Happy relaxed expression. Round base sits flat on the ground.
Centred in frame, roughly 70% of frame height.

Place on a SOLID BRIGHT LIME-GREEN background (hex #00FF88).
Do NOT use transparent or checkered backgrounds.

NO text, NO labels, NO captions, NO watermarks.
512×512, single character, isolated, cel-shaded game sprite.
```

### Example: Enemy Character

```
2D top-down mobile game enemy sprite. Single enemy character, centred,
isolated, 70% of frame height. Chibi cute style, bold black outlines.

ENEMY: GRAMMAR GOBLIN
A chubby GREEN goblin. Smug expression, raised eyebrow.
Wearing a tiny blue graduation cap. Holding a broken pencil.
Pudgy rounded body, big belly. Short stocky legs.
Arms crossed — arrogant posture.

Place on SOLID BRIGHT LIME-GREEN background (#00FF88).
NO text, NO labels, NO captions.
512×512, single character, cel-shaded, game sprite.
```

---

## 6. Reference Image Usage

### Why Pass a Reference Image?

When generating multiple sprites of the **same character**, passing a reference image to Gemini anchors the visual style. Without it, each API call may produce a different interpretation.

### How to Use References

```python
# Load reference
reference = Image.open("reference_image.png").convert("RGBA")

# Convert to bytes for Gemini
buf = io.BytesIO()
reference.save(buf, format="PNG")
ref_bytes = buf.getvalue()

# Include in the API call
parts = [
    types.Part.from_bytes(data=ref_bytes, mime_type="image/png"),
    "Match this character EXACTLY — same body, colours, proportions.\n\n",
    prompt_text,
]
```

### When to Use References

| Scenario | Use Reference? |
|----------|---------------|
| Multiple poses of same character | ✅ Yes |
| Enemy characters (unique designs) | ❌ No |
| NPCs (unique designs) | ❌ No |
| Items / orbs / tiles | ❌ No |

---

## 7. Common Prompt Pitfalls

| Problem | Solution |
|---------|----------|
| Character has unwanted arms/legs | Add explicit: "NO ARMS, NO LEGS" |
| Text appears on sprite | Add: "NO text, NO labels, NO captions, NO watermarks" |
| Multiple characters in one image | Add: "Single character, isolated" |
| Inconsistent style across sprites | Always pass reference image |
| Background not solid enough | Be very specific: "SOLID BRIGHT LIME-GREEN hex #00FF88" |
| Sprite too small in frame | Add: "fills 70% of frame height, centred" |
| Wrong perspective | Specify: "front view" or "top-down" or "3/4 view" |

---

## 8. Tool Comparison

| Feature | Gemini | DALL-E 3 |
|---------|--------|----------|
| Reference image support | ✅ Yes (multimodal) | ❌ No |
| Cost per sprite | ~$0.02–0.04 | ~$0.04–0.08 |
| Style consistency | Good (with ref) | Variable |
| Resolution | Up to 1024×1024 | 1024×1024 |
| Speed | ~3–5 seconds | ~5–10 seconds |
| Best for | Characters (with ref) | Backgrounds, unique art |

**Recommendation**: Use Gemini as primary (supports reference images), DALL-E 3 as fallback.

---

## 9. Sprite Sheet Assembly (Optional)

If you need animation frames as a single strip:

```python
from PIL import Image

frames = [
    Image.open("character_run_01.png"),
    Image.open("character_run_02.png"),
    Image.open("character_run_03.png"),
    Image.open("character_run_04.png"),
]

# Horizontal strip
w, h = frames[0].size
strip = Image.new("RGBA", (w * len(frames), h), (0, 0, 0, 0))
for i, frame in enumerate(frames):
    strip.paste(frame, (i * w, 0))
strip.save("spritesheet_running.png")
```

### Using Sprite Sheets in Flutter/Flame

```dart
final spriteSheet = SpriteSheet(
  image: await images.load('spritesheet_running.png'),
  srcSize: Vector2(128, 128),  // size of one frame
);

final runAnim = spriteSheet.createAnimation(
  row: 0,
  stepTime: 0.12,   // seconds per frame
  to: 4,            // number of frames
);
```
