#!/usr/bin/env bash
# Generate all pre-baked video assets using Seedance (BytePlus ModelArk).
# Run from the gourmet_go/ directory: bash generate_videos.sh
#
# Requires:
#   - ARK_API_KEY in .env
#
# Videos are async: submit task → poll → download MP4.
# Each clip takes ~30-120s to generate. Total: ~5-10 min for all clips.
#
# Idempotent — skips existing files. Delete a file to regenerate it.
# See plans/ftue_implementation_plan.md §1C for the full clip list.
#
# Art style: "Dreamy anime-inspired, soft pastel colours, warm golden light,
#             cinematic, Studio Ghibli influence, gentle atmosphere"

set -uo pipefail

[ -f .env ] && { set -a; source .env; set +a; }
: "${ARK_API_KEY:?ERROR: ARK_API_KEY not set in .env}"

ASSETS_DIR="assets/videos"
mkdir -p "$ASSETS_DIR"

BASE_URL="https://ark.ap-southeast.bytepluses.com/api/v3"
TASKS_URL="$BASE_URL/contents/generations/tasks"
MODEL="seedance-1-5-pro-251215"

# Dreamy anime style suffix appended to all prompts
STYLE_SUFFIX="Dreamy anime-inspired aesthetic, soft pastel colour palette, warm golden lighting, gentle atmosphere, Studio Ghibli influence, cinematic composition, ethereal glow, hand-painted feel. No text, no subtitles, no watermarks."

# ── Helper functions ─────────────────────────────────────────────────────────

submit_task() {
  local prompt="$1"
  local full_prompt="$prompt $STYLE_SUFFIX --resolution 720p --duration 5 --ratio 16:9"

  local response
  response=$(curl -s -X POST "$TASKS_URL" \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $ARK_API_KEY" \
    -d "$(jq -n --arg model "$MODEL" --arg text "$full_prompt" \
      '{model: $model, content: [{type: "text", text: $text}]}')")

  local task_id
  task_id=$(echo "$response" | jq -r '.id // empty')

  if [ -z "$task_id" ]; then
    echo "  ✗ Failed to submit task: $response"
    return 1
  fi

  echo "$task_id"
}

poll_task() {
  local task_id="$1"
  local max_attempts=60  # 5 minutes max
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    sleep 5
    attempt=$((attempt + 1))

    local response
    response=$(curl -s "$TASKS_URL/$task_id" \
      -H "Authorization: Bearer $ARK_API_KEY")

    local status
    status=$(echo "$response" | jq -r '.status // "unknown"' | tr '[:upper:]' '[:lower:]')

    case "$status" in
      succeeded)
        # Extract video URL — confirmed response shape: { content: { video_url: "..." } }
        local video_url
        video_url=$(echo "$response" | jq -r '.content.video_url // empty' 2>/dev/null || true)

        if [ -n "$video_url" ] && [ "$video_url" != "null" ]; then
          echo "$video_url"
          return 0
        else
          echo "  ✗ Task succeeded but no video URL found in response"
          echo "  Response: $response" >&2
          return 1
        fi
        ;;
      failed|cancelled)
        local error
        error=$(echo "$response" | jq -r '.error // .last_error // "Unknown error"')
        echo "  ✗ Task $status: $error" >&2
        return 1
        ;;
      *)
        # Still processing — show progress (stderr so stdout stays clean for URL)
        printf "\r    Polling %s (%ds)..." "$task_id" "$((attempt * 5))" >&2
        ;;
    esac
  done

  echo "  ✗ Timed out after $((max_attempts * 5))s" >&2
  return 1
}

generate_video() {
  local filename="$1"
  local prompt="$2"
  local outfile="$ASSETS_DIR/$filename"

  # Skip if file exists and is non-empty (failed downloads leave 0-byte files)
  if [ -f "$outfile" ] && [ -s "$outfile" ]; then
    echo "  skip $filename (exists)"
    return 0
  fi
  rm -f "$outfile"  # clean up any 0-byte leftovers

  echo "  submit $filename..."
  local task_id
  task_id=$(submit_task "$prompt") || { echo "  ✗ Submit failed for $filename"; return 1; }
  echo "    task_id: $task_id"

  echo "    polling..."
  local video_url
  video_url=$(poll_task "$task_id") || { echo ""; echo "  ✗ Poll failed for $filename"; return 1; }
  echo ""

  echo "    downloading..."
  curl -s -L "$video_url" -o "$outfile"
  local size
  size=$(wc -c < "$outfile" | tr -d ' ')
  echo "  ✓ $outfile ($size bytes)"
}

# ── Video clips ──────────────────────────────────────────────────────────────

echo ""
echo "=== Generating FTUE + Game Videos (Seedance) ==="
echo "Style: Dreamy anime-inspired"
echo ""

# FTUE intro — the first thing the player sees
FAIL_COUNT=0

generate_video "ftue_intro.mp4" \
  "A dimly lit Japanese ramen kitchen slowly illuminating, warm golden light spreading across wooden counters and hanging lanterns, steam rising gently from a simmering pot, traditional Japanese kitchen interior, intimate and cozy atmosphere, slow cinematic reveal." \
  || ((FAIL_COUNT++))

# Day start — transition between days
generate_video "day_start_doors.mp4" \
  "Japanese ramen restaurant wooden sliding doors swinging open to reveal warm morning light flooding into a cozy kitchen interior, wooden counter and bar stools visible, steam gently rising, inviting atmosphere, sunrise glow." \
  || ((FAIL_COUNT++))

# Happy customer — common bowl served well
generate_video "seedoms_happy_common.mp4" \
  "Happy customer smiling warmly while lifting chopsticks from a beautiful bowl of ramen, warm restaurant interior lighting, steam rising from the bowl, cozy wooden counter, upbeat cheerful mood, close-up." \
  || ((FAIL_COUNT++))

# Emotional rare — rare bowl moment
generate_video "seedoms_emotional_rare.mp4" \
  "Customer visibly moved and emotional while tasting a rare artisan ramen bowl, soft candlelight, intimate restaurant moment, single tear of joy, close-up of the beautiful bowl with intricate toppings, profound connection to food." \
  || ((FAIL_COUNT++))

# Signature bowl — achievement moment
generate_video "seedoms_signature.mp4" \
  "Montage of multiple happy customers enjoying the same signature ramen bowl at a busy Japanese restaurant counter, warm bustling atmosphere, bowls being served one after another, steaming noodles, satisfied expressions, celebration of craft." \
  || ((FAIL_COUNT++))

# Perfect day — 5-star achievement
generate_video "seedoms_perfect_day.mp4" \
  "Japanese ramen restaurant exterior at golden hour, long queue of eager customers forming outside, warm sunset light, bustling neighbourhood with cherry blossom petals drifting, glowing lanterns, sense of achievement and pride." \
  || ((FAIL_COUNT++))

# Region unlock — common region
generate_video "seedoms_region_common.mp4" \
  "Busy recognisable Japanese city street scene, neon signs reflecting in puddles, bustling crowds walking past food stalls, urban energy and excitement, night market atmosphere, discovering a new neighbourhood." \
  || ((FAIL_COUNT++))

# Region unlock — rare/legendary region
generate_video "seedoms_region_rare.mp4" \
  "Quiet atmospheric Japanese countryside, morning fog rolling over a coastal village, a single red lantern glowing in a hidden market alley, mountains in the distance, peaceful and mysterious, sense of discovery and wonder." \
  || ((FAIL_COUNT++))

echo ""
if [ "$FAIL_COUNT" -gt 0 ]; then
  echo "=== Done (${FAIL_COUNT} failed — re-run to retry) ==="
else
  echo "=== Done (all succeeded) ==="
fi
echo "Generated videos saved to $ASSETS_DIR/"
echo ""
echo "Files:"
ls -lh "$ASSETS_DIR/" 2>/dev/null || echo "  (no files yet)"
exit "$FAIL_COUNT"
