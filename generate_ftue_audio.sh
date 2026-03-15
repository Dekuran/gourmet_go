#!/usr/bin/env bash
# Generate all FTUE + game-loop audio assets using ElevenLabs.
# Run from the gourmet_go/ directory: bash generate_ftue_audio.sh
#
# Requires:
#   - ELEVENLABS_API_KEY in .env
#   - pip install elevenlabs  (for music generation)
#
# Idempotent — skips existing files. Delete a file to regenerate it.
# See plans/ftue_implementation_plan.md §1B for the full asset list.

set -euo pipefail

[ -f .env ] && { set -a; source .env; set +a; }
: "${ELEVENLABS_API_KEY:?ERROR: ELEVENLABS_API_KEY not set in .env}"

ASSETS_DIR="assets/audio"
mkdir -p "$ASSETS_DIR"

# ── SFX (sound-generation endpoint) ─────────────────────────────────────────

generate_sfx() {
  local filename="$1"
  local prompt="$2"
  local duration="${3:-1.0}"
  local outfile="$ASSETS_DIR/$filename"

  [ -f "$outfile" ] && { echo "  skip $filename (exists)"; return; }

  echo "  gen  $filename..."
  HTTP_STATUS=$(curl -s -X POST "https://api.elevenlabs.io/v1/sound-generation" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$prompt\",\"duration_seconds\":$duration,\"prompt_influence\":0.4}" \
    --output "$outfile" \
    -w "%{http_code}")

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "  ✓ $outfile ($(wc -c < "$outfile" | tr -d ' ') bytes)"
  else
    echo "  ✗ HTTP $HTTP_STATUS for $filename"
    rm -f "$outfile"
  fi
  sleep 0.5
}

echo ""
echo "=== Generating FTUE SFX ==="

generate_sfx "sfx_kitchen_ambience.mp3" \
  "Quiet empty kitchen ambience, distant simmering pot, gentle fan hum, peaceful and calm, subtle background" 3.0

generate_sfx "sfx_dish_card_reveal.mp3" \
  "Magical sparkling reveal sound, ascending chimes, achievement unlocked, warm and celebratory, short" 1.5

generate_sfx "sfx_map_pulse.mp3" \
  "Soft pulsing glow sound, map region lighting up, ethereal and gentle, subtle game UI" 1.0

generate_sfx "sfx_customer_arrive.mp3" \
  "Restaurant door bell, cheerful short jingle, customer entering, warm wooden door, brief" 1.2

generate_sfx "sfx_order_placed.mp3" \
  "Paper ticket stamp sound, quick crisp, order placed on rail, restaurant service kitchen, snappy" 0.5

generate_sfx "sfx_bowl_served.mp3" \
  "Ceramic bowl placed on counter with gentle clink, served dish, satisfying placement, warm" 0.8

generate_sfx "sfx_cash_ding.mp3" \
  "Cash register ding, money earned, cheerful coin sound, short positive notification" 0.4

generate_sfx "sfx_day_end.mp3" \
  "End of day wind-down, kitchen fans slowing, gentle closing chime, reflective and calm" 2.0

generate_sfx "sfx_upgrade_purchase.mp3" \
  "Upgrade purchased sparkle sound, level up, improvement jingle, positive ascending tones" 1.2

generate_sfx "sfx_star_rating.mp3" \
  "Star rating reveal, ascending bell tones per star, building anticipation, game achievement, magical" 2.5

echo ""
echo "=== Generating Game-Loop SFX (if missing) ==="

# These may already exist from generate_audio.sh — skip if present.
generate_sfx "sfx_map_tap.mp3" \
  "Soft satisfying map pin drop, clean UI tap, subtle game menu click, warm tone" 0.3

generate_sfx "sfx_chef_walk.mp3" \
  "Quick light shuffling footsteps on tile floor, cartoon chibi character walking, bouncy and playful, short loop" 1.0

generate_sfx "sfx_door_open.mp3" \
  "Wooden restaurant door sliding open smoothly, gentle bell chime as it opens, warm interior ambience hint" 1.2

generate_sfx "sfx_arrive.mp3" \
  "Cheerful bright arrival jingle, short ascending xylophone notes, destination reached, upbeat and positive, game notification" 1.5

generate_sfx "sfx_photo.mp3" \
  "Digital camera shutter click, crisp clean snap, single shot, phone camera" 0.4

generate_sfx "sfx_region_hover.mp3" \
  "Soft warm ping, UI element highlight hover, subtle and brief, gentle game tone" 0.25

# ── Music (Python SDK — music.compose endpoint) ──────────────────────────────

echo ""
echo "=== Generating Music ==="

python3 - <<'PYEOF'
import os, sys

try:
    from elevenlabs.client import ElevenLabs
except ImportError:
    print("  elevenlabs package not installed.")
    print("  Run: pip install elevenlabs")
    sys.exit(1)

api_key = os.environ.get("ELEVENLABS_API_KEY", "")
if not api_key:
    print("  No ELEVENLABS_API_KEY found in environment")
    sys.exit(1)

client = ElevenLabs(api_key=api_key)

tracks = [
    (
        "assets/audio/music_ftue_intro.mp3",
        "Gentle emotional piano and strings, slow build, nostalgic and warm, "
        "Japanese restaurant story opening, cinematic, dreamy, soft ambient, "
        "no vocals, mobile indie game soundtrack",
        15000,  # 15s — short intro
    ),
    (
        "assets/audio/music_kitchen.mp3",
        "Warm busy kitchen background music, gentle upbeat tempo, simmering pots "
        "and soft percussion, loopable, cozy Japanese restaurant service day feel, "
        "no vocals, light jazz fusion, 90 BPM",
        20000,  # 20s loop
    ),
    # Also regenerate existing music if missing
    (
        "assets/audio/music_map.mp3",
        "Upbeat adventurous game map exploration theme, warm brass stabs and light "
        "mallet percussion, 100 BPM, loopable, curious and fun feeling, no vocals, "
        "mobile indie game soundtrack",
        20000,
    ),
    (
        "assets/audio/music_shop.mp3",
        "Warm cosy ramen restaurant ambiance background music, gentle fingerpicked "
        "acoustic guitar and soft piano, 72 BPM, loopable, inviting and calm, "
        "no vocals, slight modern jazz fusion feel",
        20000,
    ),
]

for outfile, prompt, duration_ms in tracks:
    if os.path.exists(outfile):
        print(f"  skip {outfile} (exists)")
        continue
    print(f"  gen  {outfile}...")
    try:
        track = client.music.compose(
            prompt=prompt,
            music_length_ms=duration_ms,
            force_instrumental=True,
        )
        with open(outfile, "wb") as f:
            for chunk in track:
                f.write(chunk)
        size = os.path.getsize(outfile)
        print(f"  ✓ {outfile} ({size} bytes)")
    except Exception as e:
        print(f"  ✗ Error: {e}")
PYEOF

echo ""
echo "=== Done ==="
echo "Generated audio saved to $ASSETS_DIR/"
echo ""
echo "Files generated:"
ls -lh "$ASSETS_DIR/"
echo ""
echo "Run 'flutter pub get && flutter run' to test."
