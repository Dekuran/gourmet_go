#!/usr/bin/env python3
"""
Sprite Generator — Example
============================
Generates game sprites via Gemini (primary) with DALL-E 3 as fallback.

APPROACH — One image per sprite (not sprite sheets):
  Grid-slicing sprite sheets is unreliable because AI does not guarantee
  equal frame spacing. Each sprite is generated as a separate API call
  so every output is a single clean image, ready to use.

BACKGROUND REMOVAL STRATEGY:
  Neither Gemini nor DALL-E 3 can return pre-removed backgrounds reliably.
  Requesting transparency produces checkerboard artefacts that are HARDER
  to clean than a solid colour.
  ✅ ALWAYS request solid #00FF88 lime-green background.
  ✅ Post-process with rembg or PIL chroma-key to make transparent.

Usage:
    cd sprite_generation_example
    source .env                                  # needs GEMINI_API_KEY
    python3 generate_sprites.py                  # generate all sprites
    python3 generate_sprites.py --only darumascot_idle
    python3 generate_sprites.py --remove-bg      # + background removal
    python3 generate_sprites.py --use-dalle      # DALL-E 3 instead
    python3 generate_sprites.py --atlas-only     # just rebuild atlas

Output:
    sprites/
    ├── darumascot_idle.png
    ├── darumascot_celebrating.png
    ├── enemy_typo_gremlin.png
    ├── npc_tanuki.png
    ├── reference_atlas.png          ← visual overview of all sprites
    └── nobg/                        ← background-removed versions
        ├── darumascot_idle.png
        └── ...
"""

# ---------------------------------------------------------------------------
# Venv bootstrap — auto-creates an isolated venv, BEFORE any third-party imports
# ---------------------------------------------------------------------------
import os
import sys
import subprocess
from pathlib import Path

_SCRIPT_FILE  = Path(__file__).resolve()
_SCRIPT_DIR   = _SCRIPT_FILE.parent
_VENV_DIR     = _SCRIPT_DIR / "scripts_venv"
_VENV_PYTHON  = _VENV_DIR / "bin" / "python3"
_REQUIREMENTS = _SCRIPT_DIR / "requirements.txt"


def _in_venv() -> bool:
    return sys.prefix != sys.base_prefix


def _bootstrap_venv():
    """Create isolated venv, install requirements, re-exec inside it."""
    print(f"[bootstrap] Creating isolated venv at {_VENV_DIR} ...")
    subprocess.run([sys.executable, "-m", "venv", str(_VENV_DIR)], check=True)
    pip = _VENV_DIR / "bin" / "pip"
    print("[bootstrap] Installing dependencies (google-genai, Pillow, requests) ...")
    subprocess.run([str(pip), "install", "-r", str(_REQUIREMENTS), "-q"], check=True)
    print("[bootstrap] Re-launching inside venv ...\n")
    os.execv(str(_VENV_PYTHON), [str(_VENV_PYTHON)] + sys.argv)


if not _in_venv():
    if not _VENV_PYTHON.exists():
        _bootstrap_venv()
    else:
        os.execv(str(_VENV_PYTHON), [str(_VENV_PYTHON)] + sys.argv)

# ---------------------------------------------------------------------------
# Standard imports (running inside venv now)
# ---------------------------------------------------------------------------
import io
import time
import base64
import argparse
from typing import Optional

try:
    from PIL import Image as _PILImage
except ImportError:
    _PILImage = None  # type: ignore[assignment]

# ---------------------------------------------------------------------------
# Config — loaded from environment / .env file
# ---------------------------------------------------------------------------

# Auto-load .env if present
_ENV_FILE = _SCRIPT_DIR / ".env"
if _ENV_FILE.exists():
    with open(_ENV_FILE) as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                key, _, value = line.partition("=")
                os.environ.setdefault(key.strip(), value.strip())

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
GEMINI_MODEL   = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-image")

RATE_LIMIT_DELAY = 4.0   # seconds between API calls
MAX_RETRIES      = 2

OUTPUT_DIR = _SCRIPT_DIR / "sprites"
OUTPUT_DIR.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# Background colour strategy
# ---------------------------------------------------------------------------

# Lime-green works well for most sprites.
BG_COLOR = "#00FF88"
NO_BG_INSTRUCTION = (
    f"Place the character on a SOLID BRIGHT LIME-GREEN background (hex {BG_COLOR}). "
    "Do NOT use transparent, checkered, gradient, white, or any other background. "
    "Only this exact solid colour. It will be removed in post-processing."
)

# Dark charcoal works better for sprites with light/white/glowing details.
DARK_BG_COLOR = "#111111"
NO_BG_DARK_INSTRUCTION = (
    f"Place the character on a SOLID VERY DARK CHARCOAL background (hex {DARK_BG_COLOR}). "
    "Do NOT use transparent, checkered, gradient, vignette, spotlight, texture, or any other background. "
    "Use one flat uniform dark background only. It will be removed in post-processing."
)

NO_TEXT_INSTRUCTION = (
    "NO text, NO labels, NO captions, NO watermarks, NO speech bubbles, "
    "NO letters, NO numbers anywhere on the image."
)

# ---------------------------------------------------------------------------
# Reference image — passed to Gemini for character consistency
# ---------------------------------------------------------------------------

REFERENCE_PNG_PATH = _SCRIPT_DIR / "reference_image.png"

# ---------------------------------------------------------------------------
# Character description — edit this for your own character!
# ---------------------------------------------------------------------------

CHARACTER_DESCRIPTION = """\
Darumascot — a cute cartoon Japanese daruma doll character.
Design rules (STRICTLY follow all of these):
• Round glossy RED body shaped like a traditional daruma doll roly-poly toy.
• NO LEGS and NO FEET. The body ends in a smooth rounded base.
• NO ARMS in the default design. The character is arm-less by design.
  → For action poses that need to hold an object, use VERY SMALL
    minimalist floating nub-arms or let the object float magically near the body.
• Long BUNNY / RABBIT EARS on top (same red as body, pink inside).
• Cream / beige face area with cat-like WHISKERS on each cheek.
• Small pink NOSE. Closed happy curved EYES (cat-smile eyes).
• Gold Japanese kanji 「合格」 on a WHITE belly patch.
• Gold decorative scroll curves on the body.
• Movement is conveyed via body TILT, BOUNCE, or WOBBLE — never walking legs.
• Chibi proportions, cel-shaded, bold black outlines, flat bright colours.\
"""

# ---------------------------------------------------------------------------
# Sprite definitions — one image per sprite
# ---------------------------------------------------------------------------
# Edit this dictionary to add/remove sprites for your project.
# Each entry maps a filename stem to a prompt + config.

SPRITES: dict[str, dict] = {

    # ── Player character ─────────────────────────────────────────────────
    "darumascot_idle": {
        "use_reference": True,
        "prompt": f"""{CHARACTER_DESCRIPTION}

POSE: IDLE
The character faces forward, upright, resting. Bunny ears stand straight up.
Happy relaxed expression. Round base sits flat on the ground.
Centred in frame, roughly 70% of frame height.

{NO_BG_DARK_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
Single character, isolated, 512×512, cel-shaded game sprite.""",
    },

    "darumascot_celebrating": {
        "use_reference": True,
        "prompt": f"""{CHARACTER_DESCRIPTION}

POSE: CELEBRATING
The character bounces up with joy. Golden sparkle aura radiates from the body.
Very small floating nub-arms raised upward in triumph (or arms implied by sparkle
rays). Enormous excited expression, wide open eyes, big grin.
Stars and sparkles surround the character.

{NO_BG_DARK_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
Single character, isolated, 512×512, cel-shaded game sprite.""",
    },

    "darumascot_hurt": {
        "use_reference": True,
        "prompt": f"""{CHARACTER_DESCRIPTION}

POSE: HURT / TAKING DAMAGE
The body is knocked sharply sideways / tilted back as if hit. Sweat drops fly off.
Pained squinting expression, small stars above head indicating dizziness.
Body has a brief flash/tint (semi-transparent white overlay feel).
No legs — the rounded base just tilts in the air.

{NO_BG_DARK_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
Single character, isolated, 512×512, cel-shaded game sprite.""",
    },

    # ── Enemies ──────────────────────────────────────────────────────────
    "enemy_typo_gremlin": {
        "use_reference": False,
        "prompt": f"""2D top-down mobile game enemy sprite. Single enemy character, centred,
isolated, 70% of frame height. Chibi cute style, bold black outlines, flat colours.

ENEMY: TYPO GREMLIN
A small round PURPLE creature. Big round yellow glowing eyes. Sharp tiny teeth
in a wide mischievous grin. Small stubby horns on its head. Short nubby arms
reaching forward menacingly. Plump blob body with a scaly texture.
Energetic, slightly chaotic pose — leaning forward ready to pounce.

{NO_BG_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
512×512, single character, cel-shaded, game sprite, top-down perspective.""",
    },

    "enemy_grammar_goblin": {
        "use_reference": False,
        "prompt": f"""2D top-down mobile game enemy sprite. Single enemy character, centred,
isolated, 70% of frame height. Chibi cute style, bold black outlines, flat colours.

ENEMY: GRAMMAR GOBLIN
A chubby GREEN goblin. Smug confident expression, raised eyebrow.
Wearing a tiny blue graduation cap tilted sideways. Holding a broken pencil stub
(snapped in two) in one hand. Pudgy rounded body, big belly. Short stocky legs.
Arms crossed or one hand on hip — arrogant posture.

{NO_BG_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
512×512, single character, cel-shaded, game sprite, top-down perspective.""",
    },

    # ── NPCs ─────────────────────────────────────────────────────────────
    "npc_tanuki": {
        "use_reference": False,
        "prompt": f"""2D top-down mobile game NPC sprite. Single friendly character, centred,
isolated, 70% of frame height. Chibi cute style, bold black outlines, flat colours.

NPC: TANUKI (Japanese Raccoon Dog)
A round fluffy raccoon-dog with tan/brown fur and a striped tail.
Wearing a wide traditional straw hat (sugegasa). Holding a small sake bottle gourd.
Cheerful, welcoming expression — big round eyes, rosy cheeks, friendly smile.
Plump round body, short stubby legs.

{NO_BG_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
512×512, single character, cel-shaded, game sprite, top-down perspective.""",
    },

    # ── Power-up items ───────────────────────────────────────────────────
    "orb_magic_blue": {
        "use_reference": False,
        "prompt": f"""2D mobile game power-up orb icon. Single object, centred, isolated.
Chibi style, bold black outlines, flat cel-shaded colours.

ORB: MAGIC ORB (blue)
A glowing bright BLUE crystalline sphere / gem orb. Faceted like a jewel.
Inner glow radiates soft blue light. Small sparkle particles surround it.
Looks magical and inviting. No characters on or inside the orb.

{NO_BG_DARK_INSTRUCTION}
{NO_TEXT_INSTRUCTION}
256×256, single object, cel-shaded, game icon.""",
    },
}


# ---------------------------------------------------------------------------
# Gemini generation
# ---------------------------------------------------------------------------

def _load_gemini():
    try:
        from google import genai  # type: ignore[import-untyped]
        from google.genai import types  # type: ignore[import-untyped]
        return genai, types
    except ImportError:
        print("  Installing google-genai ...")
        subprocess.run([sys.executable, "-m", "pip", "install", "google-genai", "-q"], check=True)
        from google import genai  # type: ignore[import-untyped]
        from google.genai import types  # type: ignore[import-untyped]
        return genai, types


def generate_with_gemini(
    name: str,
    prompt: str,
    reference_image: Optional["_PILImage.Image"] = None,  # type: ignore[name-defined]
) -> Optional["_PILImage.Image"]:  # type: ignore[name-defined]
    """Call Gemini once for a single sprite. Returns PIL Image or None."""
    from PIL import Image
    genai, types = _load_gemini()
    client = genai.Client(api_key=GEMINI_API_KEY)

    # Build multimodal request: optional reference image + text prompt
    parts: list = []
    if reference_image is not None:
        buf = io.BytesIO()
        reference_image.save(buf, format="PNG")
        parts.append(types.Part.from_bytes(data=buf.getvalue(), mime_type="image/png"))
        parts.append(
            "Here is the reference character design. "
            "Match this character EXACTLY — same body shape, "
            "same colours, same proportions, same face style. "
            "Do NOT change the character design.\n\n"
        )
    parts.append(prompt)

    for attempt in range(MAX_RETRIES + 1):
        try:
            response = client.models.generate_content(
                model=GEMINI_MODEL,
                contents=parts,
                config=types.GenerateContentConfig(
                    response_modalities=["TEXT", "IMAGE"],
                ),
            )
            # Extract the image from the response
            for part in response.candidates[0].content.parts:
                if part.inline_data is not None:
                    img_bytes = part.inline_data.data
                    if isinstance(img_bytes, str):
                        img_bytes = base64.b64decode(img_bytes)
                    return Image.open(io.BytesIO(img_bytes)).convert("RGBA")

            if attempt < MAX_RETRIES:
                print(f"(no image, retry {attempt + 1}) ", end="", flush=True)
                time.sleep(RATE_LIMIT_DELAY)
        except Exception as e:
            if attempt < MAX_RETRIES:
                print(f"(error retry {attempt + 1}: {e}) ", end="", flush=True)
                time.sleep(RATE_LIMIT_DELAY * 2)
            else:
                print(f"\n    Gemini error: {e}")
                return None
    return None


# ---------------------------------------------------------------------------
# DALL-E 3 fallback
# ---------------------------------------------------------------------------

def generate_with_dalle(
    name: str,
    prompt: str,
) -> Optional["_PILImage.Image"]:  # type: ignore[name-defined]
    """Fallback: single sprite via DALL-E 3. Does not support reference images."""
    import requests
    from PIL import Image

    if not OPENAI_API_KEY:
        print("    SKIP DALL-E fallback (OPENAI_API_KEY not set)")
        return None
    try:
        resp = requests.post(
            "https://api.openai.com/v1/images/generations",
            headers={
                "Authorization": f"Bearer {OPENAI_API_KEY}",
                "Content-Type": "application/json",
            },
            json={
                "model": "dall-e-3",
                "prompt": prompt,
                "size": "1024x1024",
                "quality": "standard",
                "n": 1,
            },
            timeout=60,
        )
        resp.raise_for_status()
        url = resp.json()["data"][0]["url"]
        img_data = requests.get(url, timeout=60).content
        return Image.open(io.BytesIO(img_data)).convert("RGBA")
    except Exception as e:
        print(f"    DALL-E error: {e}")
        return None


# ---------------------------------------------------------------------------
# Post-resize / normalise
# ---------------------------------------------------------------------------

def normalise(img: "_PILImage.Image", size: int = 512) -> "_PILImage.Image":  # type: ignore[name-defined]
    """Trim transparent padding, then pad to square and resize to `size`."""
    from PIL import Image
    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    max_dim = max(img.width, img.height)
    canvas_size = int(max_dim * 1.1)  # 10% breathing room
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    ox = (canvas_size - img.width) // 2
    oy = (canvas_size - img.height) // 2
    canvas.paste(img, (ox, oy))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


# ---------------------------------------------------------------------------
# Background removal — PIL chroma-key (zero extra dependencies)
# ---------------------------------------------------------------------------

def remove_backgrounds():
    """Remove backgrounds using PIL border-connected chroma-key.

    This approach:
    1. Samples the dominant colour around the image border
    2. Flood-fills from the border, removing only connected matching pixels
    3. Preserves interior colours even if they match the background

    Output goes to sprites/nobg/ for manual review.
    """
    from PIL import Image
    from collections import Counter, deque

    NOBG_DIR = OUTPUT_DIR / "nobg"
    NOBG_DIR.mkdir(exist_ok=True)

    sprite_files = sorted(
        f for f in OUTPUT_DIR.glob("*.png")
        if "_nobg" not in f.name and "atlas" not in f.name and "nobg" not in str(f)
    )
    if not sprite_files:
        print("  No sprites found in sprites/")
        return

    print(f"\n[Background removal — PIL chroma-key]")

    for src in sprite_files:
        dst = NOBG_DIR / f"{src.stem}.png"
        if dst.exists():
            print(f"  skip {src.name} (already processed)")
            continue

        img = Image.open(src).convert("RGBA")
        pixels = img.load()
        if pixels is None:
            print(f"  skip {src.name} (unable to access pixels)")
            continue
        px = pixels

        w, h = img.size

        # Step 1: Sample border pixels to detect the background colour
        border_samples: list[tuple[int, int, int]] = []
        for x in range(w):
            for y in (0, h - 1):
                pixel = pixels[x, y]
                if isinstance(pixel, tuple) and len(pixel) >= 4:
                    r, g, b, a = pixel[:4]
                    if a > 0:
                        border_samples.append((r, g, b))
        for y in range(h):
            for x in (0, w - 1):
                pixel = pixels[x, y]
                if isinstance(pixel, tuple) and len(pixel) >= 4:
                    r, g, b, a = pixel[:4]
                    if a > 0:
                        border_samples.append((r, g, b))

        bg_rgb = Counter(border_samples).most_common(1)[0][0] if border_samples else (0x00, 0xFF, 0x88)

        # Adjust tolerance based on dark vs light background
        is_dark_bg = sum(bg_rgb) < 96
        tolerance = 110 if is_dark_bg else 80
        soft_tolerance = 180 if is_dark_bg else 140

        def dist(rgb: tuple[int, int, int]) -> int:
            return abs(rgb[0] - bg_rgb[0]) + abs(rgb[1] - bg_rgb[1]) + abs(rgb[2] - bg_rgb[2])

        # Step 2: Flood-fill from border edges
        visited = [[False] * h for _ in range(w)]
        queue: deque[tuple[int, int]] = deque()

        def add_seed(x: int, y: int):
            pixel = px[x, y]
            if not isinstance(pixel, tuple) or len(pixel) < 4:
                return
            r, g, b, a = pixel[:4]
            if not visited[x][y] and (a == 0 or dist((r, g, b)) <= tolerance):
                visited[x][y] = True
                queue.append((x, y))

        for x in range(w):
            add_seed(x, 0)
            add_seed(x, h - 1)
        for y in range(h):
            add_seed(0, y)
            add_seed(w - 1, y)

        while queue:
            x, y = queue.popleft()
            for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                if 0 <= nx < w and 0 <= ny < h and not visited[nx][ny]:
                    pixel = px[nx, ny]
                    if not isinstance(pixel, tuple) or len(pixel) < 4:
                        continue
                    r, g, b, a = pixel[:4]
                    if a == 0 or dist((r, g, b)) <= tolerance:
                        visited[nx][ny] = True
                        queue.append((nx, ny))

        # Step 3: Set visited border-connected pixels to transparent
        for y in range(h):
            for x in range(w):
                pixel = px[x, y]
                if not isinstance(pixel, tuple) or len(pixel) < 4:
                    continue
                r, g, b, a = pixel[:4]
                if visited[x][y]:
                    if a > 0 and dist((r, g, b)) <= soft_tolerance:
                        # Hard remove within tolerance, soft fade in the fringe
                        alpha = 0 if dist((r, g, b)) <= tolerance else int(
                            255 * (dist((r, g, b)) - tolerance) / max(1, soft_tolerance - tolerance)
                        )
                        pixels[x, y] = (r, g, b, min(a, alpha))

        img.save(str(dst))
        print(f"  ✓ {src.name} → nobg/{dst.name}")

    print(f"  Done. Results in sprites/nobg/")
    print(f"  TIP: For better quality, install rembg and use remove_bg.py")


# ---------------------------------------------------------------------------
# Reference atlas — visual overview of all generated sprites
# ---------------------------------------------------------------------------

def create_atlas():
    from PIL import Image, ImageDraw

    sprites = sorted(f for f in OUTPUT_DIR.glob("*.png")
                     if "_nobg" not in f.name and "atlas" not in f.name
                     and "nobg" not in str(f))
    if len(sprites) < 2:
        return

    cols = 4
    rows = (len(sprites) + cols - 1) // cols
    thumb = 160
    label_h = 22
    atlas = Image.new("RGBA", (cols * thumb, rows * (thumb + label_h)), (30, 30, 30, 255))
    draw = ImageDraw.Draw(atlas)

    for idx, path in enumerate(sprites):
        col = idx % cols
        row = idx // cols
        x = col * thumb
        y = row * (thumb + label_h)
        try:
            img = Image.open(path).convert("RGBA")
            img.thumbnail((thumb - 8, thumb - 8), Image.Resampling.LANCZOS)
            ox = x + (thumb - img.width) // 2
            oy = y + (thumb - img.height) // 2
            atlas.paste(img, (ox, oy), img)
        except Exception:
            pass
        draw.text((x + 4, y + thumb + 2), path.stem[:20], fill=(255, 255, 200, 255))

    out = OUTPUT_DIR / "reference_atlas.png"
    atlas.save(str(out))
    print(f"  atlas → reference_atlas.png  ({len(sprites)} sprites)")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Sprite generator (Gemini + DALL-E 3)")
    parser.add_argument("--only",       help="Only generate this sprite by name (e.g. darumascot_idle)")
    parser.add_argument("--use-dalle",  action="store_true", help="Use DALL-E 3 instead of Gemini")
    parser.add_argument("--remove-bg",  action="store_true", help="Run background removal after generation")
    parser.add_argument("--atlas-only", action="store_true", help="Just rebuild atlas, no generation")
    args = parser.parse_args()

    # Validate API keys
    if not args.atlas_only:
        if not GEMINI_API_KEY and not args.use_dalle:
            print("ERROR: GEMINI_API_KEY not set.")
            print("  Copy .env.example to .env and add your key")
            print("  Or use --use-dalle for DALL-E 3 fallback (needs OPENAI_API_KEY)")
            sys.exit(1)
        if args.use_dalle and not OPENAI_API_KEY:
            print("ERROR: OPENAI_API_KEY not set (required for --use-dalle)")
            sys.exit(1)

    # Load reference image (PNG — APIs don't accept SVG)
    reference = None
    if not args.use_dalle and not args.atlas_only:
        from PIL import Image
        if REFERENCE_PNG_PATH.exists():
            reference = Image.open(REFERENCE_PNG_PATH).convert("RGBA")
            print(f"Reference loaded: {REFERENCE_PNG_PATH}")
        else:
            print(f"⚠️  Reference PNG not found: {REFERENCE_PNG_PATH}")
            print("    Sprites with use_reference=True will use text-only prompts (less consistent)")

    # Filter sprites
    to_run: dict[str, dict] = SPRITES
    if args.only:
        if args.only not in SPRITES:
            print(f"Unknown sprite: '{args.only}'")
            print(f"Available: {', '.join(SPRITES)}")
            sys.exit(1)
        to_run = {args.only: SPRITES[args.only]}

    # Generate sprites
    if not args.atlas_only:
        print(f"\n{'=' * 50}")
        print(f"Sprite Generation")
        print(f"{'=' * 50}")
        print(f"Mode:    {'Gemini (' + GEMINI_MODEL + ')' if not args.use_dalle else 'DALL-E 3'}")
        print(f"Sprites: {len(to_run)}")
        print(f"Output:  {OUTPUT_DIR}/")
        print(f"⚠️  Sprites use solid-colour background → run --remove-bg to strip")
        print()

        generated = 0
        for name, sprite_def in to_run.items():
            out_path = OUTPUT_DIR / f"{name}.png"
            print(f"  [{name}]")

            if out_path.exists():
                print(f"    skip (exists — delete to regenerate)")
                print()
                continue

            print(f"    generating ...", end=" ", flush=True)

            ref = reference if sprite_def.get("use_reference") else None

            if args.use_dalle:
                img = generate_with_dalle(name, sprite_def["prompt"])
            else:
                img = generate_with_gemini(name, sprite_def["prompt"], reference_image=ref)
                # Auto-fallback to DALL-E 3 if Gemini fails and key is available
                if img is None and OPENAI_API_KEY:
                    print(f"    Gemini failed — trying DALL-E 3 fallback ...")
                    img = generate_with_dalle(name, sprite_def["prompt"])

            if img is not None:
                img = normalise(img)
                img.save(str(out_path))
                print(f"done ({img.width}×{img.height})")
                generated += 1
            else:
                print("FAILED")

            print()
            if not args.use_dalle:
                time.sleep(RATE_LIMIT_DELAY)

        print(f"Generated {generated}/{len(to_run)} sprites.\n")

    # Post-processing
    print("[Post-processing]")
    create_atlas()

    if args.remove_bg:
        remove_backgrounds()

    print()
    print("NEXT STEPS:")
    print("  1. Review sprites/reference_atlas.png")
    print("  2. Remove backgrounds:  python3 generate_sprites.py --atlas-only --remove-bg")
    print("     Review results in sprites/nobg/ before deployment")
    print("  3. Copy approved files into your game's assets/sprites/ folder")


if __name__ == "__main__":
    main()
