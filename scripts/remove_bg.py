#!/usr/bin/env python3
"""
Background Removal Tool — Standalone
======================================
Remove backgrounds from sprite images locally using rembg (AI-powered)
or a PIL chroma-key fallback (zero extra dependencies).

Usage:
    # Single file (auto-installs rembg on first use)
    python3 remove_bg.py sprites/darumascot_idle.png

    # Custom output path
    python3 remove_bg.py sprites/input.png output_nobg.png

    # Choose model (isnet-anime is best for cartoon sprites)
    python3 remove_bg.py -m isnet-anime sprites/input.png

    # Alpha matting for better edges on hair/fur
    python3 remove_bg.py -a sprites/input.png

    # Batch process a folder
    python3 remove_bg.py --batch sprites/ sprites/nobg/

    # Use PIL chroma-key instead of rembg (no ML model needed)
    python3 remove_bg.py --pil sprites/input.png

Models:
    isnet-anime        — Best for cartoon/anime sprites (recommended)
    birefnet-general   — Best quality for photos & complex scenes
    u2netp             — Fast & lightweight
    silueta            — Tiny (43 MB), general purpose

Requirements:
    pip install "rembg[cpu,cli]" Pillow
    (Or run this script — it will offer to install rembg for you)
"""

import argparse
import sys
from pathlib import Path
from collections import Counter, deque


def remove_bg_rembg(input_path: Path, output_path: Path, model: str, alpha_matting: bool):
    """Remove background using rembg (AI model)."""
    try:
        from rembg import remove, new_session
        from PIL import Image
    except ImportError:
        print("rembg is not installed.")
        print("Install it with:  pip install 'rembg[cpu,cli]'")
        print("Or use --pil for the PIL chroma-key fallback (no ML needed)")
        sys.exit(1)

    print(f"Loading model: {model}")
    session = new_session(model)

    print(f"Processing: {input_path}")
    input_img = Image.open(input_path)

    if alpha_matting:
        output_img = remove(
            input_img,
            session=session,
            alpha_matting=True,
            alpha_matting_foreground_threshold=240,
            alpha_matting_background_threshold=10,
        )
    else:
        output_img = remove(input_img, session=session)

    if isinstance(output_img, bytes):
        with open(str(output_path), "wb") as f:
            f.write(output_img)
    else:
        output_img.save(str(output_path))  # type: ignore[union-attr]
    print(f"Saved: {output_path}")


def remove_bg_pil(input_path: Path, output_path: Path):
    """Remove background using PIL border-connected chroma-key.

    How it works:
    1. Samples the most common colour along the image border
    2. Flood-fills inward from the border, marking matching pixels
    3. Sets those pixels to transparent
    4. Soft-fades the fringe zone for cleaner edges

    This preserves interior colours even if they match the background.
    """
    from PIL import Image

    print(f"Processing (PIL chroma-key): {input_path}")
    img = Image.open(input_path).convert("RGBA")
    pixels = img.load()
    if pixels is None:
        print("  Error: unable to access pixels")
        return
    px = pixels
    w, h = img.size

    # Sample border pixels to detect background colour
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

    if not border_samples:
        print("  Warning: no opaque border pixels found")
        img.save(str(output_path))
        return

    bg_rgb = Counter(border_samples).most_common(1)[0][0]
    print(f"  Detected background: RGB{bg_rgb}")

    is_dark_bg = sum(bg_rgb) < 96
    tolerance = 110 if is_dark_bg else 80
    soft_tolerance = 180 if is_dark_bg else 140

    def dist(rgb: tuple[int, int, int]) -> int:
        return abs(rgb[0] - bg_rgb[0]) + abs(rgb[1] - bg_rgb[1]) + abs(rgb[2] - bg_rgb[2])

    # Flood-fill from border
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

    # Apply transparency
    removed = 0
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
                removed += 1

    img.save(str(output_path))
    pct = removed / (w * h) * 100
    print(f"  Removed {removed:,} pixels ({pct:.1f}%) → {output_path}")


def batch_process(input_dir: Path, output_dir: Path, model: str, use_pil: bool, alpha_matting: bool):
    """Process all PNGs in a directory."""
    output_dir.mkdir(parents=True, exist_ok=True)
    files = sorted(input_dir.glob("*.png"))
    files = [f for f in files if "nobg" not in f.name and "atlas" not in f.name]

    if not files:
        print(f"No PNG files found in {input_dir}")
        return

    print(f"Batch processing {len(files)} files → {output_dir}/\n")

    for f in files:
        out = output_dir / f.name
        if out.exists():
            print(f"  skip {f.name} (already exists)")
            continue
        if use_pil:
            remove_bg_pil(f, out)
        else:
            remove_bg_rembg(f, out, model, alpha_matting)
        print()

    print(f"Done! {len(files)} files processed → {output_dir}/")


def main():
    parser = argparse.ArgumentParser(
        description="Remove image backgrounds — AI (rembg) or PIL chroma-key",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Models (for rembg):
  isnet-anime        Best for cartoon/anime sprites (recommended)
  birefnet-general   Best quality for photos
  u2netp             Fast & lightweight
  silueta            Tiny model, general purpose

Examples:
  python3 remove_bg.py sprites/character.png
  python3 remove_bg.py -m isnet-anime -a sprites/character.png
  python3 remove_bg.py --pil sprites/character.png
  python3 remove_bg.py --batch sprites/ sprites/nobg/
        """,
    )
    parser.add_argument("input", nargs="?", help="Input image or directory (with --batch)")
    parser.add_argument("output", nargs="?", help="Output path (default: input_nobg.png)")
    parser.add_argument("--model", "-m", default="isnet-anime",
                        help="rembg model name (default: isnet-anime)")
    parser.add_argument("--alpha-matting", "-a", action="store_true",
                        help="Enable alpha matting for better edges")
    parser.add_argument("--pil", action="store_true",
                        help="Use PIL chroma-key instead of rembg (no ML model needed)")
    parser.add_argument("--batch", action="store_true",
                        help="Batch process: input=dir, output=dir")
    args = parser.parse_args()

    if not args.input:
        parser.print_help()
        sys.exit(1)

    input_path = Path(args.input)

    if args.batch:
        output_dir = Path(args.output) if args.output else input_path / "nobg"
        batch_process(input_path, output_dir, args.model, args.pil, args.alpha_matting)
    else:
        if not input_path.exists():
            print(f"Error: {input_path} not found")
            sys.exit(1)
        if args.output:
            output_path = Path(args.output)
        else:
            output_path = input_path.parent / f"{input_path.stem}_nobg.png"

        if args.pil:
            remove_bg_pil(input_path, output_path)
        else:
            remove_bg_rembg(input_path, output_path, args.model, args.alpha_matting)


if __name__ == "__main__":
    main()
