#!/usr/bin/env bash
# Generate pre-baked TTS audio for all FTUE dialogue lines.
# Uses the exact script from restaurant_sim_prototype.md §4.
#
# Run from the gourmet_go/ directory: bash generate_ftue_dialogue_audio.sh
#
# Requires: ELEVENLABS_API_KEY in .env
# Voice: Roger (CwhRBWXzGAHq8TQ4Fs17) — warm, authoritative male
# Model: eleven_turbo_v2_5 (fast, high-quality)
#
# Output: assets/audio/ftue_line_01.mp3 … ftue_line_09.mp3
# Idempotent — skips existing files. Delete a file to regenerate.

set -euo pipefail

[ -f .env ] && { set -a; source .env; set +a; }
: "${ELEVENLABS_API_KEY:?ERROR: ELEVENLABS_API_KEY not set in .env}"

python3 - "$ELEVENLABS_API_KEY" <<'PYEOF'
import json, os, sys, urllib.request

API_KEY = sys.argv[1]
VOICE_ID = "CwhRBWXzGAHq8TQ4Fs17"
MODEL = "eleven_turbo_v2_5"
ASSETS_DIR = "assets/audio"
os.makedirs(ASSETS_DIR, exist_ok=True)

LINES = [
    ("ftue_line_01.mp3", "Welcome, traveler."),
    ("ftue_line_02.mp3",
     "This little ramen shop may look ordinary, but it carries a long, quiet history. "
     "Generations have stood behind this counter, tasting broth, perfecting noodles, "
     "and warming the souls of strangers far from home."),
    ("ftue_line_03.mp3",
     "Now the shop is yours. You've come from far away, carrying your own memories "
     "and flavors, and a promise to yourself: you'll not only keep this place alive, "
     "you'll make it more beloved than ever."),
    ("ftue_line_04.mp3",
     "People from all over the world should feel at home here, "
     "no matter where they started their journey."),
    ("ftue_line_05.mp3",
     "To do that, you can't stay in one place. Japan's ramen isn't just one bowl, "
     "it changes from town to town, coast to coast."),
    ("ftue_line_06.mp3",
     "If we want this shop to become a legend, we'll have to travel. "
     "From snowy northern ports to neon-lined streets, from quiet countryside stations "
     "to busy market alleys, every region has its own secrets in the broth."),
    ("ftue_line_07.mp3",
     "Every great journey starts with a single bowl."),
    ("ftue_line_08.mp3",
     "First, let's add your very first ramen to the menu. "
     "Take a photo of a bowl you're eating right now, or upload one of your favorites."),
    ("ftue_line_09.mp3",
     "I'll bring that photo into the kitchen, and we'll study it together."),
]

print(f"\n=== Generating FTUE Dialogue TTS ===")
print(f"Voice: Roger ({VOICE_ID}) | Model: {MODEL}\n")

for filename, text in LINES:
    outfile = os.path.join(ASSETS_DIR, filename)
    if os.path.exists(outfile):
        print(f"  skip {filename} (exists)")
        continue

    print(f"  gen  {filename}...")
    body = json.dumps({
        "text": text,
        "model_id": MODEL,
        "voice_settings": {
            "stability": 0.5,
            "similarity_boost": 0.75,
            "style": 0.3,
        },
    }).encode()

    req = urllib.request.Request(
        f"https://api.elevenlabs.io/v1/text-to-speech/{VOICE_ID}",
        data=body,
        headers={
            "Content-Type": "application/json",
            "xi-api-key": API_KEY,
        },
    )
    try:
        resp = urllib.request.urlopen(req)
        data = resp.read()
        with open(outfile, "wb") as f:
            f.write(data)
        print(f"  ✓ {outfile} ({len(data)} bytes)")
    except Exception as e:
        print(f"  ✗ Error: {e}")

    import time
    time.sleep(1)

print("\n=== Done ===")
for f in sorted(os.listdir(ASSETS_DIR)):
    if f.startswith("ftue_line_"):
        path = os.path.join(ASSETS_DIR, f)
        print(f"  {f} ({os.path.getsize(path)} bytes)")
print()
PYEOF
