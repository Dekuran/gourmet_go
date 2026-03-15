#!/usr/bin/env python3
"""
Sprite Generator — Gourmet GO
================================
Generates all game sprites for Gourmet GO via Gemini (primary) or
DALL-E 3 (fallback), following the pipeline from
docs/sprite_generation_example/.

Art style: Dreamy anime-inspired, flat pastel colours, bold black outlines,
cel-shaded, modern indie game aesthetic. Charcoal (#111111) background.

Usage:
    cd scripts
    python3 generate_game_sprites.py                       # all sprites
    python3 generate_game_sprites.py --batch ftue          # FTUE sous chef
    python3 generate_game_sprites.py --batch menu          # ramen bowl icons
    python3 generate_game_sprites.py --batch chef          # all chef variants
    python3 generate_game_sprites.py --batch customer      # customers + bubble
    python3 generate_game_sprites.py --batch chef --variant red   # one variant
    python3 generate_game_sprites.py --only bowl_tonkotsu
    python3 generate_game_sprites.py --generate-refs       # chef/sous_chef refs
    python3 generate_game_sprites.py --remove-bg           # strip backgrounds
    python3 generate_game_sprites.py --atlas-only          # rebuild atlas only
    python3 generate_game_sprites.py --deploy              # copy nobg → assets/

Output:
    scripts/sprites/              raw generated sprites
    scripts/sprites/nobg/         background-removed (review before deploying)
    assets/sprites/               final game assets (after --deploy)

Chef colour variants: red | blue | green
    Use --variant <colour> to generate one variant. Default: all three.
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


def _bootstrap_venv() -> None:
    """Create isolated venv, install requirements, re-exec inside it."""
    print(f"[bootstrap] Creating isolated venv at {_VENV_DIR} ...")
    subprocess.run([sys.executable, "-m", "venv", str(_VENV_DIR)], check=True)
    pip = _VENV_DIR / "bin" / "pip"
    print("[bootstrap] Installing dependencies ...")
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
# Config — loaded from .env (checked in scripts/ then parent gourmet_go/)
# ---------------------------------------------------------------------------

def _load_env() -> None:
    for candidate in (_SCRIPT_DIR / ".env", _SCRIPT_DIR.parent / ".env"):
        if candidate.exists():
            with open(candidate) as f:
                for raw in f:
                    line = raw.strip()
                    if line and not line.startswith("#") and "=" in line:
                        key, _, value = line.partition("=")
                        os.environ.setdefault(key.strip(), value.strip())
            return


_load_env()

GEMINI_API_KEY = os.environ.get("GEMINI_API_KEY")
OPENAI_API_KEY = os.environ.get("OPENAI_API_KEY")
GEMINI_MODEL   = os.environ.get("GEMINI_MODEL", "gemini-2.5-flash-image")

RATE_LIMIT_DELAY = 4.0
MAX_RETRIES      = 2

OUTPUT_DIR = _SCRIPT_DIR / "sprites"
OUTPUT_DIR.mkdir(exist_ok=True)
(OUTPUT_DIR / "nobg").mkdir(exist_ok=True)

ASSETS_DIR  = _SCRIPT_DIR.parent / "assets" / "sprites"
REF_DIR     = _SCRIPT_DIR / "reference_images"
REF_DIR.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# Style constants
# ---------------------------------------------------------------------------

_DARK_BG = "#111111"

_NO_BG = (
    f"Place on a SOLID VERY DARK CHARCOAL background (hex {_DARK_BG}). "
    "Do NOT use transparent, checkered, gradient, vignette, spotlight, "
    "texture, or any other background. One flat uniform dark background only. "
    "It will be removed in post-processing."
)

_NO_TEXT = (
    "NO text, NO labels, NO captions, NO watermarks, NO speech bubbles, "
    "NO letters, NO numbers anywhere on the image."
)

_STYLE = (
    "Dreamy anime-inspired, flat pastel colours, bold black outlines, "
    "cel-shaded, modern indie game aesthetic."
)

# ---------------------------------------------------------------------------
# Prompt builders
# ---------------------------------------------------------------------------

# ── Chef ──────────────────────────────────────────────────────────────────

CHEF_VARIANTS: dict[str, str] = {
    "red":   "red apron and red bandana",
    "blue":  "ocean-blue apron and blue bandana",
    "green": "forest-green apron and green bandana",
}

_CHEF_BASE = """\
A friendly young Japanese ramen chef wearing a white chef coat with {ACCENT}.
Rolled-up sleeves, confident but warm expression.
Standing behind a ramen counter. Chibi proportions. {STYLE}"""

_CHEF_POSES: dict[str, str] = {
    "idle": (
        "POSE: IDLE (available state)\n"
        "Standing at the counter, arms relaxed at sides. Smiling warmly.\n"
        "Welcoming posture, weight balanced. Ready for the next order.\n"
        "Centred in frame, roughly 70% of frame height."
    ),
    "cooking_01": (
        "POSE: COOKING — Animation Frame 1 of 3\n"
        "Stirring a large pot of ramen broth with a ladle.\n"
        "Focused, attentive expression. One hand on pot rim, other stirring.\n"
        "Steam visible rising from the pot."
    ),
    "cooking_02": (
        "POSE: COOKING — Animation Frame 2 of 3\n"
        "Lifting a nest of noodles from the pot with long cooking chopsticks.\n"
        "Arms raised slightly, noodles dangling. Concentrated expression."
    ),
    "cooking_03": (
        "POSE: COOKING — Animation Frame 3 of 3\n"
        "Adding toppings and garnish to a bowl — sprinkling sesame seeds,\n"
        "placing chashu. Artistic careful motion. Slight smile of satisfaction."
    ),
    "plating": (
        "POSE: PLATING (order complete, 1-second state)\n"
        "Presenting a finished ramen bowl with both hands extended forward.\n"
        "Proud delighted smile. Bowl is complete and beautiful."
    ),
}


def _chef_prompt(pose_key: str, variant: str) -> str:
    base = _CHEF_BASE.format(ACCENT=CHEF_VARIANTS[variant], STYLE=_STYLE)
    return (
        f"{base}\n\n"
        f"{_CHEF_POSES[pose_key]}\n\n"
        f"{_NO_BG}\n{_NO_TEXT}\n"
        "512x512, single character, centred, isolated, cel-shaded game sprite."
    )


_CHEF_REF_PROMPT = (
    f"{_CHEF_BASE.format(ACCENT=CHEF_VARIANTS['red'], STYLE=_STYLE)}\n\n"
    "POSE: NEUTRAL STANDING — CHARACTER REFERENCE SHEET\n"
    "Front-facing, arms slightly out, neutral expression. Clean design view.\n"
    "This will be used as the consistency reference for all chef sprite variants.\n\n"
    f"{_NO_BG}\n{_NO_TEXT}\n"
    "512x512, single character, centred, isolated, cel-shaded game sprite."
)

# ── Sous Chef ────────────────────────────────────────────────────────────

_SOUS_CHEF_BASE = """\
A friendly sous chef character, half-body portrait, facing forward.
Young and cheerful. Wearing a clean white chef uniform with a small neckerchief.
{STYLE} Chibi proportions, cute and approachable."""

_SOUS_CHEF_POSES: dict[str, str] = {
    "neutral": (
        "EXPRESSION: NEUTRAL — friendly, professional.\n"
        "Slight warm smile, relaxed posture. Default guide/narrator state."
    ),
    "excited": (
        "EXPRESSION: EXCITED / ENCOURAGING — big bright smile, sparkling eyes.\n"
        "Leaning forward enthusiastically, one hand raised in encouragement."
    ),
    "thinking": (
        "EXPRESSION: THINKING / PONDERING — hand on chin, thoughtful gaze\n"
        "upward and to one side. Gentle furrowed brow, calm curious expression."
    ),
}


def _sous_chef_prompt(pose_key: str) -> str:
    base = _SOUS_CHEF_BASE.format(STYLE=_STYLE)
    return (
        f"{base}\n\n"
        f"{_SOUS_CHEF_POSES[pose_key]}\n\n"
        f"{_NO_BG}\n{_NO_TEXT}\n"
        "512x512, half-body portrait, centred, cel-shaded game character portrait."
    )


_SOUS_CHEF_REF_PROMPT = (
    f"{_SOUS_CHEF_BASE.format(STYLE=_STYLE)}\n\n"
    "EXPRESSION: NEUTRAL — CHARACTER REFERENCE SHEET\n"
    "Front-facing, clear design view for consistency reference.\n\n"
    f"{_NO_BG}\n{_NO_TEXT}\n"
    "512x512, half-body portrait, centred, cel-shaded game character portrait."
)

# ── Customers ────────────────────────────────────────────────────────────

_CUSTOMER_DESIGNS: dict[str, str] = {
    "01": (
        "A young woman in casual street fashion. Pastel pink oversized hoodie, "
        "short hair with two small buns on top. Rosy cheeks, bright eager eyes."
    ),
    "02": (
        "A middle-aged businessman in a neat suit and tie. Round wire-frame glasses. "
        "Slightly impatient but polite expression. Holding a small briefcase."
    ),
    "03": (
        "A teenage boy with spiky dyed blue hair. Bright yellow bomber jacket, "
        "high-top sneakers. Excited, energetic expression."
    ),
    "04": (
        "An elderly grandmother with silver hair in a neat bun. Cozy floral-print "
        "cardigan. Warm grandmotherly smile, rosy cheeks. Patient and gentle."
    ),
    "05": (
        "A university student in an oversized college-logo hoodie, large backpack. "
        "Messy brown hair, slightly tired eyes. Relaxed hungry student expression."
    ),
    "06": (
        "A small child with two high pigtails. Pastel blue polka-dot dress. "
        "Huge wide curious eyes. Standing on tiptoes to see over the counter."
    ),
}

_CUSTOMER_POSES: dict[str, str] = {
    "waiting": (
        "POSE: WAITING — standing in queue, looking expectant.\n"
        "Slightly craning neck toward the kitchen. Hopeful expression."
    ),
    "served": (
        "POSE: SERVED — hands clasped in delight, sparkle eyes, wide happy smile.\n"
        "Overjoyed reaction upon receiving their order."
    ),
    "unhappy": (
        "POSE: UNHAPPY — arms crossed, frowning, small anger symbol above head.\n"
        "Patience expired. Disappointed but not aggressive."
    ),
}


def _customer_prompt(cid: str, pose_key: str) -> str:
    return (
        f"{_STYLE}\n\n"
        "Dreamy anime-inspired Japanese restaurant customer.\n"
        f"CUSTOMER CHARACTER {cid}:\n"
        f"{_CUSTOMER_DESIGNS[cid]}\n"
        "Chibi proportions, cute and friendly design.\n\n"
        f"{_CUSTOMER_POSES[pose_key]}\n\n"
        f"{_NO_BG}\n{_NO_TEXT}\n"
        "512x512, single character, centred, isolated, cel-shaded game sprite."
    )

# ── Ramen Bowls ──────────────────────────────────────────────────────────

_RAMEN_BOWLS: dict[str, tuple[str, str]] = {
    "tonkotsu": (
        "TONKOTSU RAMEN",
        "Rich creamy white-beige pork broth. Toppings: thick chashu pork slices, "
        "soft-boiled ramen egg (halved, orange yolk), green onion, nori sheet, "
        "bamboo shoots. Traditional white ceramic bowl with blue decorative ring.",
    ),
    "shoyu": (
        "SHOYU RAMEN",
        "Clear amber-brown soy sauce broth. Toppings: rolled chashu, menma bamboo "
        "shoots, nori, narutomaki fish cake slice, thin green onion. Elegant "
        "light-coloured ceramic bowl.",
    ),
    "miso": (
        "MISO RAMEN",
        "Cloudy orange-yellow miso broth. Toppings: corn kernels, melting pat of "
        "butter, ground pork, green onion, bean sprouts. Hearty rustic brown bowl.",
    ),
    "shio": (
        "SHIO RAMEN",
        "Delicate clear pale-golden salt broth. Toppings: white fish cake, shrimp, "
        "clam, thin yuzu peel slices, light green garnish. Refined white porcelain.",
    ),
}


def _bowl_prompt(ramen_key: str) -> str:
    name, desc = _RAMEN_BOWLS[ramen_key]
    return (
        "Dreamy anime-inspired ramen bowl illustration, top-down overhead view.\n"
        f"{_STYLE}\n\n"
        f"DISH: {name}\n"
        f"{desc}\n"
        "Beautiful presentation in a traditional ceramic bowl.\n"
        "Top-down view showing bowl contents clearly.\n\n"
        f"{_NO_BG}\n{_NO_TEXT}\n"
        "512x512, single object, centred, isolated, game icon."
    )

# ---------------------------------------------------------------------------
# SPRITES dictionary — built dynamically from prompt builders
# ---------------------------------------------------------------------------

CHEF_REF_PATH      = REF_DIR / "chef_ref.png"
SOUS_CHEF_REF_PATH = REF_DIR / "sous_chef_ref.png"

SPRITES: dict[str, dict] = {}

# Sous chef portraits (Batch: ftue)
for _pose in ("neutral", "excited", "thinking"):
    SPRITES[f"sous_chef_{_pose}"] = {
        "batch": "ftue",
        "reference_path": SOUS_CHEF_REF_PATH,
        "prompt": _sous_chef_prompt(_pose),
    }

# Ramen bowl icons (Batch: menu)
for _ramen in ("tonkotsu", "shoyu", "miso", "shio"):
    SPRITES[f"bowl_{_ramen}"] = {
        "batch": "menu",
        "reference_path": None,
        "prompt": _bowl_prompt(_ramen),
    }

# Chef sprites — 5 poses × 3 colour variants (Batch: chef)
for _variant in CHEF_VARIANTS:
    for _pose in ("idle", "cooking_01", "cooking_02", "cooking_03", "plating"):
        SPRITES[f"chef_{_pose}_{_variant}"] = {
            "batch": "chef",
            "variant": _variant,
            "reference_path": CHEF_REF_PATH,
            "prompt": _chef_prompt(_pose, _variant),
        }

# Kitchen background (Batch: chef — generated alongside chef sprites)
SPRITES["kitchen_bg"] = {
    "batch": "chef",
    "reference_path": None,
    "raw_output": True,   # Full scene — skip square-pad normalise + bg removal
    "size": (1024, 768),
    "prompt": (
        "Dreamy anime-inspired isometric Japanese ramen kitchen interior scene.\n"
        f"{_STYLE}\n\n"
        "SCENE: RAMEN KITCHEN INTERIOR (isometric view, upper-left angle)\n"
        "- Long wooden ramen counter / pass-through\n"
        "- Large stainless pots on a gas stove, gentle steam rising\n"
        "- Hanging noren curtain with Japanese pattern at the top\n"
        "- Shelves with bowls, condiment jars, and kitchen tools\n"
        "- Warm ambient lighting with soft shadows\n"
        "- Clean, organised, slightly magical kitchen atmosphere\n"
        "No characters in the scene. No text or labels.\n\n"
        "1024x768, full kitchen interior scene, isometric perspective."
    ),
}

# Customer sprites — 6 characters × 3 poses (Batch: customer)
for _cid in ("01", "02", "03", "04", "05", "06"):
    for _pose in ("waiting", "served", "unhappy"):
        SPRITES[f"customer_{_cid}_{_pose}"] = {
            "batch": "customer",
            "reference_path": None,
            "prompt": _customer_prompt(_cid, _pose),
        }

# Speech bubble (Batch: customer)
SPRITES["speech_bubble"] = {
    "batch": "customer",
    "reference_path": None,
    "prompt": (
        "Dreamy anime-inspired UI speech bubble.\n"
        f"{_STYLE}\n\n"
        "OBJECT: SPEECH BUBBLE\n"
        "Rounded rectangular speech bubble with a downward-pointing tail "
        "at the bottom-left corner.\n"
        "Clean white fill, bold dark outline. Simple and clear.\n"
        "Interior is empty white space (a dish icon will be overlaid in code).\n\n"
        f"{_NO_BG}\n{_NO_TEXT}\n"
        "256x256, single object, centred, isolated, game UI element."
    ),
}

# Cooking sprite sheets to assemble after generation
CHEF_COOKING_SHEETS: dict[str, list[str]] = {
    f"spritesheet_chef_cooking_{v}": [
        f"chef_cooking_01_{v}",
        f"chef_cooking_02_{v}",
        f"chef_cooking_03_{v}",
    ]
    for v in CHEF_VARIANTS
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
        subprocess.run(
            [sys.executable, "-m", "pip", "install", "google-genai", "-q"],
            check=True,
        )
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

    parts: list = []
    if reference_image is not None:
        buf = io.BytesIO()
        reference_image.save(buf, format="PNG")
        parts.append(types.Part.from_bytes(data=buf.getvalue(), mime_type="image/png"))
        parts.append(
            "Here is the reference character design. "
            "Match this character EXACTLY — same body shape, same colours, "
            "same proportions, same face style. Do NOT change the design.\n\n"
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
            for part in response.candidates[0].content.parts:
                if part.inline_data is not None:
                    img_bytes = part.inline_data.data
                    if isinstance(img_bytes, str):
                        img_bytes = base64.b64decode(img_bytes)
                    return Image.open(io.BytesIO(img_bytes)).convert("RGBA")

            if attempt < MAX_RETRIES:
                print(f"(no image in response, retry {attempt + 1}) ", end="", flush=True)
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
    """Fallback: DALL-E 3. Does not support reference images."""
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
                "prompt": prompt[:4000],
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
# Post-processing
# ---------------------------------------------------------------------------

def normalise(
    img: "_PILImage.Image",  # type: ignore[name-defined]
    size: int = 512,
) -> "_PILImage.Image":  # type: ignore[name-defined]
    """Trim transparent padding, pad to square, resize to `size`."""
    from PIL import Image

    bbox = img.getbbox()
    if bbox:
        img = img.crop(bbox)
    max_dim = max(img.width, img.height)
    canvas_size = int(max_dim * 1.1)
    canvas = Image.new("RGBA", (canvas_size, canvas_size), (0, 0, 0, 0))
    canvas.paste(img, ((canvas_size - img.width) // 2, (canvas_size - img.height) // 2))
    return canvas.resize((size, size), Image.Resampling.LANCZOS)


def resize_raw(
    img: "_PILImage.Image",  # type: ignore[name-defined]
    size: tuple[int, int],
) -> "_PILImage.Image":  # type: ignore[name-defined]
    """Simple resize for full-scene images (no padding)."""
    from PIL import Image
    return img.resize(size, Image.Resampling.LANCZOS)


def remove_backgrounds(target_files: Optional[list[Path]] = None) -> None:
    """Remove backgrounds using PIL border-connected chroma-key.

    Samples the dominant border colour and flood-fills from the border,
    removing only connected matching pixels. Preserves interior colours
    even if they match the background.
    """
    from PIL import Image
    from collections import Counter, deque

    NOBG_DIR = OUTPUT_DIR / "nobg"
    NOBG_DIR.mkdir(exist_ok=True)

    if target_files is None:
        sprite_files = sorted(
            f for f in OUTPUT_DIR.glob("*.png")
            if "atlas" not in f.name and "spritesheet" not in f.name
        )
    else:
        sprite_files = sorted(target_files)

    # Exclude raw-output sprites from bg removal
    raw_names = {name for name, d in SPRITES.items() if d.get("raw_output")}
    sprite_files = [f for f in sprite_files if f.stem not in raw_names]

    if not sprite_files:
        print("  No sprites found for background removal.")
        return

    print(f"\n[Background removal — PIL chroma-key]")

    for src in sprite_files:
        dst = NOBG_DIR / src.name
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

        # Step 1: Sample border pixels to detect background colour
        border_samples: list[tuple[int, int, int]] = []
        for x in range(w):
            for y in (0, h - 1):
                pixel = pixels[x, y]
                if isinstance(pixel, tuple) and len(pixel) >= 4 and pixel[3] > 0:
                    border_samples.append((pixel[0], pixel[1], pixel[2]))
        for y in range(h):
            for x in (0, w - 1):
                pixel = pixels[x, y]
                if isinstance(pixel, tuple) and len(pixel) >= 4 and pixel[3] > 0:
                    border_samples.append((pixel[0], pixel[1], pixel[2]))

        bg_rgb = Counter(border_samples).most_common(1)[0][0] if border_samples else (17, 17, 17)

        is_dark_bg = sum(bg_rgb) < 96
        tolerance      = 110 if is_dark_bg else 80
        soft_tolerance = 180 if is_dark_bg else 140

        def dist(rgb: tuple[int, int, int]) -> int:
            return abs(rgb[0] - bg_rgb[0]) + abs(rgb[1] - bg_rgb[1]) + abs(rgb[2] - bg_rgb[2])

        # Step 2: Flood-fill from border edges
        visited = [[False] * h for _ in range(w)]
        queue: deque[tuple[int, int]] = deque()

        def add_seed(x: int, y: int) -> None:
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
                if visited[x][y] and a > 0 and dist((r, g, b)) <= soft_tolerance:
                    alpha = 0 if dist((r, g, b)) <= tolerance else int(
                        255 * (dist((r, g, b)) - tolerance) / max(1, soft_tolerance - tolerance)
                    )
                    pixels[x, y] = (r, g, b, min(a, alpha))

        img.save(str(dst))
        print(f"  ✓ {src.name} → nobg/{dst.name}")

    print("  Done. Results in sprites/nobg/")
    print("  TIP: For better quality, install rembg and use remove_bg.py")


def assemble_chef_sheets() -> None:
    """Assemble cooking frames into horizontal sprite sheets (1536×512)."""
    from PIL import Image

    print("\n[Sprite sheet assembly]")
    for sheet_name, frame_names in CHEF_COOKING_SHEETS.items():
        out_path = OUTPUT_DIR / f"{sheet_name}.png"
        frames: list = []
        missing = False
        for fname in frame_names:
            src = OUTPUT_DIR / f"{fname}.png"
            if not src.exists():
                print(f"  skip {sheet_name} (missing {fname}.png)")
                missing = True
                break
            frames.append(Image.open(src).convert("RGBA"))
        if missing:
            continue
        w = sum(f.width for f in frames)
        h = max(f.height for f in frames)
        sheet = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        x = 0
        for frame in frames:
            sheet.paste(frame, (x, (h - frame.height) // 2))
            x += frame.width
        sheet.save(str(out_path))
        print(f"  ✓ {sheet_name}.png  ({w}×{h})")


def create_atlas() -> None:
    """Build a reference atlas PNG for visual review of all sprites."""
    from PIL import Image, ImageDraw

    sprites = sorted(
        f for f in OUTPUT_DIR.glob("*.png")
        if "atlas" not in f.name and "nobg" not in str(f)
    )
    if len(sprites) < 2:
        return

    cols  = 4
    rows  = (len(sprites) + cols - 1) // cols
    thumb = 160
    label = 24
    atlas = Image.new("RGBA", (cols * thumb, rows * (thumb + label)), (30, 30, 30, 255))
    draw  = ImageDraw.Draw(atlas)

    for idx, path in enumerate(sprites):
        col = idx % cols
        row = idx // cols
        x   = col * thumb
        y   = row * (thumb + label)
        try:
            img = Image.open(path).convert("RGBA")
            img.thumbnail((thumb - 8, thumb - 8), Image.Resampling.LANCZOS)
            atlas.paste(img, (x + (thumb - img.width) // 2, y + (thumb - img.height) // 2), img)
        except Exception:
            pass
        draw.text((x + 4, y + thumb + 2), path.stem[:22], fill=(255, 255, 200, 255))

    out = OUTPUT_DIR / "reference_atlas.png"
    atlas.save(str(out))
    print(f"  atlas → reference_atlas.png  ({len(sprites)} sprites)")


def deploy_to_assets(dry_run: bool = False) -> None:
    """Copy background-removed sprites from sprites/nobg/ into assets/sprites/."""
    import shutil

    NOBG_DIR = OUTPUT_DIR / "nobg"
    if not NOBG_DIR.exists():
        print("  No sprites/nobg/ directory found. Run --remove-bg first.")
        return

    ASSETS_DIR.mkdir(parents=True, exist_ok=True)
    files = sorted(NOBG_DIR.glob("*.png"))

    # Also copy raw-output sprites (kitchen_bg etc.) directly
    raw_names = {name for name, d in SPRITES.items() if d.get("raw_output")}
    for rn in raw_names:
        raw_src = OUTPUT_DIR / f"{rn}.png"
        if raw_src.exists():
            files = [*files, raw_src]

    # Also copy assembled sprite sheets
    for sheet_name in CHEF_COOKING_SHEETS:
        sheet_src = OUTPUT_DIR / f"{sheet_name}.png"
        if sheet_src.exists():
            files = [*files, sheet_src]

    if not files:
        print("  No files to deploy.")
        return

    print(f"\n[Deploy → {ASSETS_DIR}/]")
    for src in files:
        dst = ASSETS_DIR / src.name
        if dry_run:
            print(f"  (dry-run) {src.name}")
        else:
            shutil.copy2(src, dst)
            print(f"  ✓ {src.name}")

    print(f"\n  {len(files)} sprites deployed to {ASSETS_DIR}/")
    print("\n  Add to pubspec.yaml:")
    print("    flutter:")
    print("      assets:")
    print("        - assets/sprites/")

# ---------------------------------------------------------------------------
# Generate reference images
# ---------------------------------------------------------------------------

def generate_refs(use_dalle: bool) -> None:
    """Generate chef and sous chef reference images to reference_images/."""
    refs = [
        ("chef_ref", _CHEF_REF_PROMPT, CHEF_REF_PATH),
        ("sous_chef_ref", _SOUS_CHEF_REF_PROMPT, SOUS_CHEF_REF_PATH),
    ]
    print(f"\n[Generating reference images → {REF_DIR}/]\n")
    for name, prompt, out_path in refs:
        if out_path.exists():
            print(f"  skip {name} (already exists at {out_path})")
            continue
        print(f"  [{name}] generating ...", end=" ", flush=True)
        if use_dalle:
            img = generate_with_dalle(name, prompt)
        else:
            img = generate_with_gemini(name, prompt)
        if img is not None:
            img = normalise(img)
            img.save(str(out_path))
            print(f"done → {out_path}")
        else:
            print("FAILED")
        if not use_dalle:
            time.sleep(RATE_LIMIT_DELAY)

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

BATCHES = ("ftue", "menu", "chef", "customer")


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Gourmet GO sprite generator (Gemini + DALL-E 3 fallback)",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--batch",
        choices=BATCHES,
        help="Generate only this batch of sprites",
    )
    parser.add_argument(
        "--variant",
        choices=list(CHEF_VARIANTS),
        help="Chef colour variant to generate (default: all three)",
    )
    parser.add_argument("--only",      help="Generate a single sprite by name")
    parser.add_argument("--use-dalle", action="store_true", help="Use DALL-E 3 instead of Gemini")
    parser.add_argument("--remove-bg", action="store_true", help="Run background removal after generation")
    parser.add_argument("--atlas-only", action="store_true", help="Rebuild atlas only, no generation")
    parser.add_argument("--generate-refs", action="store_true", help="Generate chef/sous_chef reference images")
    parser.add_argument("--deploy",    action="store_true", help="Copy nobg sprites to assets/sprites/")
    parser.add_argument("--dry-run",   action="store_true", help="Show deploy plan without copying files")
    args = parser.parse_args()

    # Validate API keys
    if not args.atlas_only and not args.deploy:
        if not GEMINI_API_KEY and not args.use_dalle:
            print("ERROR: GEMINI_API_KEY not set.")
            print("  Copy .env.example to .env and add your key, or use --use-dalle")
            sys.exit(1)
        if args.use_dalle and not OPENAI_API_KEY:
            print("ERROR: OPENAI_API_KEY not set (required for --use-dalle)")
            sys.exit(1)

    # Reference image generation
    if args.generate_refs:
        generate_refs(args.use_dalle)
        return

    # Deploy only
    if args.deploy:
        assemble_chef_sheets()
        deploy_to_assets(dry_run=args.dry_run)
        return

    # Load reference images (Gemini only)
    chef_ref      = None
    sous_chef_ref = None
    if not args.use_dalle and not args.atlas_only:
        from PIL import Image
        if CHEF_REF_PATH.exists():
            chef_ref = Image.open(CHEF_REF_PATH).convert("RGBA")
            print(f"Chef reference loaded: {CHEF_REF_PATH}")
        else:
            print(f"⚠️  Chef reference not found: {CHEF_REF_PATH}")
            print("    Run --generate-refs first for better consistency")
        if SOUS_CHEF_REF_PATH.exists():
            sous_chef_ref = Image.open(SOUS_CHEF_REF_PATH).convert("RGBA")
            print(f"Sous chef reference loaded: {SOUS_CHEF_REF_PATH}")
        else:
            print(f"⚠️  Sous chef reference not found: {SOUS_CHEF_REF_PATH}")

    # Filter sprites to run
    to_run: dict[str, dict] = dict(SPRITES)
    if args.batch:
        to_run = {k: v for k, v in to_run.items() if v.get("batch") == args.batch}
    if args.variant:
        to_run = {
            k: v for k, v in to_run.items()
            if v.get("variant") is None or v.get("variant") == args.variant
        }
    if args.only:
        if args.only not in SPRITES:
            print(f"Unknown sprite: '{args.only}'")
            print(f"Available: {', '.join(SPRITES)}")
            sys.exit(1)
        to_run = {args.only: SPRITES[args.only]}

    # Generation
    if not args.atlas_only:
        print(f"\n{'=' * 55}")
        print("Gourmet GO — Sprite Generation")
        print(f"{'=' * 55}")
        print(f"Mode:    {'DALL-E 3' if args.use_dalle else 'Gemini (' + GEMINI_MODEL + ')'}")
        print(f"Sprites: {len(to_run)}")
        print(f"Output:  {OUTPUT_DIR}/")
        if args.batch:
            print(f"Batch:   {args.batch}")
        if args.variant:
            print(f"Variant: {args.variant}")
        print(f"⚠️  Raw sprites use charcoal background → run --remove-bg to strip\n")

        generated = 0
        for name, sprite_def in to_run.items():
            out_path = OUTPUT_DIR / f"{name}.png"
            print(f"  [{name}]")
            if out_path.exists():
                print("    skip (exists — delete to regenerate)\n")
                continue

            print("    generating ...", end=" ", flush=True)

            # Select reference image
            ref_path: Optional[Path] = sprite_def.get("reference_path")
            reference = None
            if ref_path is not None and not args.use_dalle:
                if ref_path == CHEF_REF_PATH:
                    reference = chef_ref
                elif ref_path == SOUS_CHEF_REF_PATH:
                    reference = sous_chef_ref

            if args.use_dalle:
                img = generate_with_dalle(name, sprite_def["prompt"])
            else:
                img = generate_with_gemini(name, sprite_def["prompt"], reference_image=reference)
                if img is None and OPENAI_API_KEY:
                    print("Gemini failed — trying DALL-E 3 fallback ...", end=" ", flush=True)
                    img = generate_with_dalle(name, sprite_def["prompt"])

            if img is not None:
                if sprite_def.get("raw_output"):
                    size: tuple[int, int] = sprite_def.get("size", (1024, 768))
                    img = resize_raw(img, size)
                else:
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
    assemble_chef_sheets()

    if args.remove_bg:
        remove_backgrounds()

    print()
    print("NEXT STEPS:")
    print("  1. Review sprites/reference_atlas.png")
    print("  2. Strip backgrounds:  python3 generate_game_sprites.py --remove-bg --atlas-only")
    print("     Then review sprites/nobg/ before deploying")
    print("  3. Deploy:             python3 generate_game_sprites.py --deploy")


if __name__ == "__main__":
    main()
