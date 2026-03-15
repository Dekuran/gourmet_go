# Sprite Generation Pipeline — Example Package

> Self-contained reference for generating AI game sprites using
> **Gemini** (primary) and **DALL-E 3** (fallback), plus background removal.

---

## Quick Start

```bash
# 1. Set up environment
cd sprite_generation_example
cp .env.example .env        # ← add your GEMINI_API_KEY here

# 2. Run the generator (auto-creates a venv)
python3 generate_sprites.py

# 3. Remove backgrounds
python3 generate_sprites.py --remove-bg

# 4. Check results
open sprites/reference_atlas.png
ls sprites/nobg/
```

**No manual `pip install` needed** — the script auto-creates an isolated venv at `scripts_venv/` and installs dependencies on first run.

---

## What's in This Package

```
sprite_generation_example/
├── README.md                    ← You are here
├── .env.example                 ← API key template
├── requirements.txt             ← Python dependencies (auto-installed)
├── generate_sprites.py          ← Main generator script (Gemini + DALL-E 3)
├── remove_bg.py                 ← Standalone background removal tool
├── art_style_guide.md           ← Visual style rules & prompt patterns
├── reference_image.png          ← Character reference (passed to Gemini)
├── sample_sprites/              ← Example outputs (already generated)
│   ├── darumascot_idle.png
│   ├── darumascot_celebrating.png
│   ├── darumascot_excited.png
│   └── reference_atlas.png
└── sprites/                     ← Your generated output goes here
    └── nobg/                    ← Background-removed versions
```

---

## How It Works

### Pipeline Overview

```
┌──────────────────────────────────────────────────────────────┐
│ 1. GENERATE — AI creates sprites with solid-colour background│
│    Tool: Gemini (google-genai SDK) or DALL-E 3 (fallback)    │
│    Key:  Pass reference image for character consistency       │
│    BG:   Solid #00FF88 lime-green (easy to remove later)     │
└───────────────────────┬──────────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ 2. NORMALISE — Trim whitespace, pad to square, resize 512px  │
│    Tool: Pillow (PIL)                                        │
└───────────────────────┬──────────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ 3. REMOVE BACKGROUND — Strip the solid colour to transparent │
│    Tool: rembg (isnet-anime model) or PIL chroma-key fallback│
│    Output: sprites/nobg/*.png (transparent PNGs)             │
└───────────────────────┬──────────────────────────────────────┘
                        ▼
┌──────────────────────────────────────────────────────────────┐
│ 4. REVIEW — Check reference_atlas.png, then copy to game     │
└──────────────────────────────────────────────────────────────┘
```

### Why Solid-Colour Backgrounds?

**Never** request transparent backgrounds from AI generators. Both Gemini and DALL-E 3 produce checkerboard or white artefacts that are _harder_ to clean than a solid colour.

✅ Always request `#00FF88` (lime-green) or `#111111` (dark charcoal)  
✅ Post-process to remove the solid colour  
❌ Never request "transparent background" or "no background"

---

## Script Usage

### `generate_sprites.py`

```bash
# Generate all defined sprites
python3 generate_sprites.py

# Generate a single sprite
python3 generate_sprites.py --only enemy_typo_gremlin

# Use DALL-E 3 instead of Gemini
python3 generate_sprites.py --use-dalle

# Remove backgrounds after generation
python3 generate_sprites.py --remove-bg

# Just rebuild the atlas (no API calls)
python3 generate_sprites.py --atlas-only
```

### `remove_bg.py`

```bash
# Single file
python3 remove_bg.py sprites/darumascot_idle.png

# Specify output path
python3 remove_bg.py sprites/input.png sprites/output_nobg.png

# Choose model (isnet-anime is best for cartoon sprites)
python3 remove_bg.py -m isnet-anime sprites/input.png

# Alpha matting for better edges
python3 remove_bg.py -a sprites/input.png

# Batch process a folder
python3 remove_bg.py --batch sprites/ sprites/nobg/
```

---

## Adding New Sprites

Edit the `SPRITES` dictionary in `generate_sprites.py`:

```python
SPRITES["my_new_character"] = {
    "use_reference": False,    # True = pass reference_image.png to Gemini
    "prompt": f"""2D mobile game sprite. Single character, centred, isolated.
Chibi cute style, bold black outlines, flat colours.

ENEMY: MY NEW CHARACTER
[Describe the character here — be VERY specific about pose, colours,
expression, accessories, proportions]

{NO_BG_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
512×512, single character, cel-shaded, game sprite.""",
}
```

### Prompt Writing Tips

1. **Be extremely specific** — describe every detail (colour, pose, expression)
2. **State negatives explicitly** — "NO text, NO legs, NO transparent background"
3. **Include technical specs** — "512×512, cel-shaded, bold outlines"
4. **Reference existing style** — "Chibi proportions, flat bright colours"
5. **One character per image** — multi-character sheets are unreliable

---

## API Keys

| Provider | Env Var | Get One At | Used For |
|----------|---------|------------|----------|
| Google Gemini | `GEMINI_API_KEY` | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | Primary sprite generation |
| OpenAI | `OPENAI_API_KEY` | [platform.openai.com](https://platform.openai.com/api-keys) | DALL-E 3 fallback |

**Cost per sprite**: ~$0.02–0.04 (Gemini), ~$0.04–0.08 (DALL-E 3)

---

## Background Removal Models

| Model | Best For | Speed |
|-------|----------|-------|
| `isnet-anime` | **Cartoon/anime sprites** (recommended) | Fast |
| `birefnet-general` | Photos & complex scenes | Slow |
| `u2netp` | Quick & lightweight | Very fast |
| `silueta` | General purpose, tiny (43 MB) | Very fast |

The PIL chroma-key fallback (no ML model needed) works well when sprites have clean solid-colour backgrounds. It uses border-connected flood-fill to avoid removing interior colours that happen to match the background.

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `GEMINI_API_KEY not set` | Copy `.env.example` to `.env` and add your key |
| Sprite has limbs when it shouldn't | Add explicit negative prompts: "NO legs, NO arms" |
| Background removal leaves green fringe | Use `--remove-bg` with rembg, or adjust `TOLERANCE` in PIL fallback |
| Sprite style inconsistent | Always pass the reference image (`use_reference: True`) |
| Rate limit errors | Increase `RATE_LIMIT_DELAY` (default 4 seconds) |
| rembg install fails on Apple Silicon | Use ARM64 Python: `/opt/homebrew/bin/python3` |

---

## Adapting for Your Own Project

1. **Change the character**: Replace `reference_image.png` and update `CHARACTER_DESCRIPTION`
2. **Change the art style**: Edit the style keywords in each prompt (e.g., "pixel art" instead of "cel-shaded")
3. **Change sprite size**: Modify the `normalise()` function's `size` parameter
4. **Add sprite sheets**: See the `grammar_dash/generate_darumascot_sprites.py` pattern for sheet-based generation with grid slicing
