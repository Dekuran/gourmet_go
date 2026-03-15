# Gourmet GO — Hackathon Build TODO

Build in strict tier order. **Tier 3 is cuttable without breaking the demo.**

---

## Tier 1 — Core Loop (~22h) *(Non-Negotiable)*

### BE (Backend)

| Task | Notes | Est. |
|------|-------|------|
| Vision AI call for ramen recognition | Claude Vision API; return JSON dish card with rarity tier from regional_style | 3h |
| Customer generation (LLM) with rarity-aware payload | 6–10 pre-generated per day at day start | 4h |
| Cash value per bowl served | Backend returns price per dish via `GET /ramen/{variety_id}/price` | 1h |

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| Camera / upload + dish card creation UI | Anytime access. Scanning overlay → dish card reveal → map pulse. | 3h |
| Dish card model + rarity + local persistence | `shared_preferences` JSON store (price is display-only from backend) | 2h |
| Single chef cook queue + progress bar + state machine | Idle → Cooking → Plating → Rest. Cook time by skill level. | 4h |
| Order ticket rail + chef assignment (tap) | Rarity indicator on ticket. Must feel snappy. | 4h |
| Cash display on serve | Value returned from backend; display only on client | 1h |

---

## Tier 2 — Progression & World Layer (~22h)

### BE (Backend)

| Task | Notes | Est. |
|------|-------|------|
| FTUE sous chef dialogue — LLM integration | LLM calls for sous chef lines; 30+ pre-written fallback lines per category | 2h |

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| End-of-day summary screen + star rating calculation | 4-factor weighted score → 1–5 stars | 4h |
| Upgrade screen — chef skill / hire / capacity / restaurant tier | Persistent upgrades; cash gating | 5h |
| FTUE dialogue flow + sous chef bubble widget | Full script; fallback bank; mid-service camera pause line | 3h |
| Japan map screen (SVG + 3 regions with rarity glow) | Region state machine + rarity border + unlock bottom sheet with lore | 5h |
| Menu board screen with camera FAB | Dish card grid, region grouping, rarity borders, add-bowl flow | 3h |

---

## Tier 3 — Wow Layer (~12h) *(Cut If Needed)*

### BE (Backend)

| Task | Notes | Est. |
|------|-------|------|
| Seedoms clip pre-generation + caching | Separate clip sets for common vs rare | 2h |

### FE (Frontend)

| Task | Notes | Est. |
|------|-------|------|
| Seedoms contextual playback | Trigger on 3-star and region unlock; max 1 clip per day | 2h |
| ByteDance load + day-start clips | Bookend moments only | 3h |
| Lottie chef animations per state | Per-state per chef | 3h |
| Map region glow + Legendary shimmer animation | `AnimationController` states | 2h |
