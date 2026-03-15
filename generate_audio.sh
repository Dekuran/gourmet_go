#!/usr/bin/env bash
# Generate all game audio assets using ElevenLabs.
# Run from the gourmet_go/ directory: bash generate_audio.sh

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

  [ -f "$outfile" ] && { echo "  skip $filename"; return; }

  echo "  gen  $filename..."
  HTTP_STATUS=$(curl -s -X POST "https://api.elevenlabs.io/v1/sound-generation" \
    -H "xi-api-key: $ELEVENLABS_API_KEY" \
    -H "Content-Type: application/json" \
    -d "{\"text\":\"$prompt\",\"duration_seconds\":$duration,\"prompt_influence\":0.4}" \
    --output "$outfile" \
    -w "%{http_code}")

  if [ "$HTTP_STATUS" = "200" ]; then
    echo "  ✓ $outfile"
  else
    echo "  ✗ HTTP $HTTP_STATUS for $filename"
    rm -f "$outfile"
  fi
  sleep 0.5
}

echo ""
echo "=== Generating SFX ==="
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
        "assets/audio/music_map.mp3",
        "Upbeat adventurous game map exploration theme, warm brass stabs and light mallet percussion, "
        "100 BPM, loopable, curious and fun feeling, no vocals, mobile indie game soundtrack",
    ),
    (
        "assets/audio/music_shop.mp3",
        "Warm cosy ramen restaurant ambiance background music, gentle fingerpicked acoustic guitar "
        "and soft piano, 72 BPM, loopable, inviting and calm, no vocals, slight modern jazz fusion feel",
    ),
]

for outfile, prompt in tracks:
    if os.path.exists(outfile):
        print(f"  skip {outfile}")
        continue
    print(f"  gen  {outfile}...")
    try:
        track = client.music.compose(
            prompt=prompt,
            music_length_ms=20000,
            force_instrumental=True,
        )
        with open(outfile, "wb") as f:
            for chunk in track:
                f.write(chunk)
        print(f"  ✓ {outfile}")
    except Exception as e:
        print(f"  ✗ Error: {e}")
PYEOF

echo ""
echo "=== Done ==="
echo "Generated audio saved to $ASSETS_DIR/"
echo "Run 'flutter pub get && flutter run' to test."
