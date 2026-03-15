# 🍜 Gourmet GO — Prototype Plan
**Flutter iOS Hackathon | Game Producer Draft | March 2026**

> *"Build your ramen empire from a tiny eatery to a bustling restaurant!*
> *Snap every bowl you eat across Japan to unlock authentic regional styles,*
> *level up your chefs, and serve hungry customers in this dreamy pixel art sim."*

---

## Table of Contents

1. [Game Concept](#1-game-concept)
2. [Design Philosophy & Social Mission](#2-design-philosophy--social-mission)
3. [Story Synopsis](#3-story-synopsis)
4. [First-Time User Experience (FTUE)](#4-first-time-user-experience-ftue)
5. [Core Game Loop](#5-core-game-loop)
6. [Progression & Upgrade System](#6-progression--upgrade-system)
7. [Daily Rating System](#7-daily-rating-system)
8. [Menu System — Photo-Driven](#8-menu-system--photo-driven)
9. [Character System](#9-character-system)
10. [Japan Travel System](#10-japan-travel-system)
11. [AI & Media Integration](#11-ai--media-integration)
12. [Technical Architecture](#12-technical-architecture)
13. [Hackathon Build Priority](#13-hackathon-build-priority)
14. [Scope Boundaries](#14-scope-boundaries)
15. [Open Design Questions](#15-open-design-questions)

---

## 1. Game Concept

**Gourmet GO** is a ramen restaurant simulator where the menu is built entirely from bowls the player discovers and photographs while traveling Japan. The player has inherited their ailing grandfather's ramen shop — a place with quiet history and deep roots — and has made a promise: not only to keep it alive, but to make it more beloved than ever.

The restaurant starts as a single run-down counter with one chef of basic skill. Over time, as the player earns cash and builds their menu through real-world discovery, they upgrade their chef, hire additional cooks, expand daily capacity, and transform the shop from a quiet neighbourhood spot into a destination restaurant.

The restaurant sits in an **undefined city**, deliberately unanchored from any specific country, so that players from anywhere in the world can step into the role naturally. The player photographs ramen anywhere, anytime — not just between service periods.

### The Loop in One Sentence

> Inherit the shop → photograph ramen bowls you actually eat across Japan → unlock regional styles → serve customers → earn cash → upgrade the shop and team → attract more curious customers → travel further into places most tourists never find.

### Prototype Definition of Done

| # | Criterion |
|---|-----------|
| ✅ | Player completes FTUE: photographs a bowl, it joins the menu |
| ✅ | Single chef completes orders one at a time with a visible progress bar |
| ✅ | Cash earned per bowl served; upgrade screen accessible end of day |
| ✅ | Daily star rating delivered by the sous chef at close of service |
| ✅ | At least 4 Japan regions unlockable via ramen photography |
| ✅ | Rarity tier visibly reflected in dish card and customer reactions |
| ✅ | Camera accessible at any point during play, not only between rounds |
| ✅ | Runs on a physical iOS device without crashing |

---

## 2. Design Philosophy & Social Mission

### The Problem

Japan's most iconic destinations — Tokyo, Kyoto, Osaka, Nara — are at or beyond sustainable tourist capacity. Meanwhile, many of Japan's most authentic, beautiful, and culturally rich regions receive a fraction of the visitors they could meaningfully host. The infrastructure exists. The hospitality exists. The food, history, and character exist. The tourists are simply not finding their way there.

This is not a failure of interest. It is a failure of imagination and incentive. Most first-time visitors follow the same well-worn route because it's the one they've seen photographed, recommended, and packaged. There is no compelling reason presented to them to go further.

### The Opportunity

Gourmet GO is designed to create that reason — and to make it feel like discovery, not duty.

The game's core mechanic — photograph the ramen you're actually eating to unlock it in your restaurant — is inherently tied to where the player physically travels. The game then does something deliberate: **the rarer the region, the more exceptional the bowl.** Dishes from lesser-visited areas of Japan carry higher rarity ratings, unlock more impressive customer reactions, and earn greater cash. The game never lectures the player about overtourism. It simply makes the road less traveled the more rewarding one.

### The Design Principle

> **Discovery is the reward. Curiosity is the mechanic.**

Every design decision in Gourmet GO should reinforce the feeling that Japan contains more than any single trip can hold — and that the best version of the player's restaurant, and the best version of their journey, lies just beyond the obvious itinerary.

### How This Manifests in the Game

| Layer | How the philosophy shows up |
|-------|---------------------------|
| **Region rarity tiers** | Off-the-beaten-path regions yield rarer dish cards with higher star ceilings and cash multipliers |
| **Sous chef voice** | Actively expresses curiosity and wonder about lesser-known places; nudges gently toward unexplored regions |
| **Customer reactions** | A bowl from Kitakata or Tottori triggers a more astonished, story-rich reaction than one from central Tokyo |
| **Japan map design** | Famous regions start bright and accessible; lesser-known regions are deliberately intriguing — hinted at, glowing faintly, waiting |
| **Ramen lore** | Each dish card includes a one-line regional note written to spark genuine interest in the place it came from |

---

## 3. Story Synopsis

### Background

The player's grandfather ran a small ramen shop for decades — nothing flashy, just honest broth and handmade noodles, and a loyal crowd of regulars who came from near and far. As he aged, the shop grew quieter. Fewer travelers found it. The recipes started to feel like relics.

Now the shop is the player's. They've come from far away, carrying their own memories and a single promise: they'll make this place more beloved than ever before. Not a museum to what it was — something alive, evolving, surprising.

### The Core Motivation

The grandfather's shop serves one foundational style of ramen. But the player quickly learns that Japan's ramen world is vast and quietly astonishing — every region has its own broth philosophy, noodle cut, topping traditions, and history. The most legendary bowls aren't the famous ones. They belong to places that haven't been written up in travel guides, served in tourist districts, or recreated abroad.

That means traveling. Straying from the itinerary. Eating in places that don't have English menus. Photographing.

### The Emotional Core

> **The best bowl you've ever had is probably somewhere you haven't been yet.**

This is the game's emotional north star. It frames every regional discovery not as a task to complete but as a genuine invitation — a pull toward curiosity, toward the unfamiliar, toward the quieter corners of Japan that are waiting to be found. The grandfather understood this. His shop was always full of people who had traveled far and found something they didn't expect. That's what the player is rebuilding: not just a restaurant, but a reason to keep exploring.

---

## 4. First-Time User Experience (FTUE)

The FTUE is the tutorial. There is no separate onboarding screen, instruction popup, or feature walkthrough. The entire premise of Gourmet GO is established through the sous chef's voice in the first 90 seconds of play.

### FTUE Flow

```
App loads → ByteDance intro clip (2–3s) → Dark kitchen screen →
Sous chef speaks opening story → Motivation to travel →
Camera opens → Player photographs or uploads ramen →
Vision AI identifies bowl → Dish card created → Menu updated →
Japan map pulses → First customer arrives → Service begins
```

### FTUE Dialogue (Full Script)

---

#### Opening Story

> *"Welcome, traveler.*
>
> *This little ramen shop may look ordinary, but it carries a long, quiet history.*
> *Generations have stood behind this counter, tasting broth, perfecting noodles, and warming the souls of strangers far from home.*
>
> *Now the shop is yours.*
> *You've come from far away, carrying your own memories and flavors… and a promise to yourself:*
> *you'll not only keep this place alive, you'll make it more beloved than ever.*
>
> *People from all over the world should feel at home here — no matter where they started their journey."*

---

#### Motivation to Travel and Discover

> *"To do that, you can't stay in one place.*
> *Japan's ramen isn't just one bowl — it changes from town to town, coast to coast.*
>
> *If we want this shop to become a legend, we'll have to travel.*
> *From snowy northern ports to neon-lined streets, from quiet countryside stations to busy market alleys —*
> *every region has its own secrets in the broth."*

---

#### Tutorial: First Recipe (Onboarding Step)

> *"Every great journey starts with a single bowl.*
>
> *First, let's add your very first ramen to the menu.*
> *Take a photo of a bowl you're eating right now — or upload one of your favorites.*
>
> *I'll bring that photo into the kitchen, and we'll study it together."*

*→ Camera / upload picker opens. Player takes a photo or selects one.*

---

#### After Photo / Recognition — Base Case

> *"Nice shot, chef.*
> *Let's see… this looks like [ramen variety].*
>
> *We'll taste it with our eyes, imagine the steam, the smell, the texture of the noodles —*
> *and try to capture its spirit here in our tiny shop."*

---

#### Recognition Incorrect — Retry Branch

> *"Hmm… that doesn't feel quite right.*
> *I don't want to misrepresent this bowl — or the place it came from.*
>
> *Let's try again, chef.*
> *These regional flavors deserve to be honored properly."*

*→ Camera / upload picker reopens. Alternatively, offer 3 pre-seeded starter dishes to choose from.*

---

#### Recognition Correct → Confirm and Prepare

> *"Yes, this looks just right.*
> *Okay, we'll get right on that!*
>
> *We'll break it into its key ingredients and steps so the whole kitchen can learn it —*
> *a little piece of that region's soul, now living in our menu."*

*→ Dish card animates onto the menu board. Japan map pulses on the identified region.*

---

#### Dish Added to Menu + Travel Loop Hint

> *"We did it, chef — your first dish is ready, and it's now on the menu.*
> *Soon, customers from all over the world will taste this bowl and feel the place it came from.*
>
> *When you're ready, we'll head out again.*
> *There are whole regions of Japan waiting for you —*
> *and every new bowl you discover can find a home in this shop."*

*→ First AI-generated customer arrives. Day one service begins.*

---

### Graceful Failure Handling

If the vision AI cannot confidently identify the image (confidence < 0.6, not food, or blurry), the sous chef uses the **Recognition Incorrect** branch — never a raw error state. The retry branch and the pre-seeded fallback picker ensure the FTUE always completes successfully.

---

## 5. Core Game Loop

The active gameplay is a single service **day**. The restaurant opens, customers arrive, and the player manages their kitchen to fulfil as many orders as possible before the day ends. The fundamental constraint is time and capacity: one chef can only make one bowl at a time, and the day has a fixed number of customer slots.

### The Day Structure

```
Open for the day
      ↓
Customers arrive one at a time (or small groups)
      ↓
Player assigns each order to an available chef
      ↓
Chef works through the queue: one bowl at a time, progress bar fills
      ↓
Completed bowls served → cash earned per bowl
      ↓
Some orders may go unfulfilled (capacity limit, chef too slow)
      ↓
Day ends → Daily Star Rating delivered by sous chef
      ↓
Upgrade screen: spend cash on chef skill / new chefs / capacity / ambience
      ↓
New day begins with improved shop
```

### What the Player Does

| Action | When | Decision |
|--------|------|----------|
| **Assign order to chef** | Customer arrives with a request | Which chef (if more than one)? What queue position? |
| **Prioritise the queue** | Chef finishes a bowl | Which order to start next? |
| **Photograph a new bowl** | Any time — mid-service, between customers, or outside the restaurant | Adds to menu immediately; new customer types may be attracted |
| **Spend cash on upgrades** | End of day upgrade screen | Chef skill vs. hire a new chef vs. expand capacity vs. restaurant ambience |
| **Check the Japan map** | Any time via the map icon in the HUD | See which regions are researchable; plan next discovery trip |

### Key Constraints That Create the Fun

- **One chef, one bowl at a time** at game start — the queue backs up fast if orders come in faster than the chef can cook
- **Daily bowl limit** — the shop can only serve a fixed number of bowls per day before supplies run out (expanded via upgrades)
- **Not all orders will be filled** — this is expected, especially early game; the rating system accounts for it
- **Chef cook time decreases with skill** — upgrading the chef is the fastest way to serve more customers per day

### Cook Time by Chef Skill Level

| Skill Level | Time per bowl | Unlock cost |
|-------------|--------------|-------------|
| ⬜ Novice *(start)* | 60 seconds | — |
| 🔵 Trained | 45 seconds | TBD |
| 🟡 Skilled | 30 seconds | TBD |
| 🟠 Expert | 20 seconds | TBD |
| 🌟 Master | 12 seconds | TBD |

*Cook time applies per bowl regardless of ramen type. Rarity affects cash earned, not cook time.*

---

## 6. Progression & Upgrade System

At the end of each day, the player spends earned cash to grow the restaurant. Upgrades are permanent — each purchase persists across all future days.

### Upgrade Categories

#### 🧑‍🍳 Chef Upgrades

| Upgrade | Effect | Cost |
|---------|--------|------|
| **Skill level** (Novice → Master, 4 steps) | Reduces cook time per bowl | See table in Section 5 |
| **Hire second chef** | Two bowls cooking simultaneously | TBD |
| **Hire third chef** | Three bowls simultaneously | TBD |

*Maximum 3 chefs for the hackathon prototype.*

#### 🏠 Restaurant Upgrades

Restaurant tier affects the **Ambience** component of the daily star rating. It also changes the visual appearance of the pixel art shop.

| Tier | Name | Ambience score | Unlock cost |
|------|------|---------------|-------------|
| 1 | Run-down family shop *(start)* | ★☆☆☆☆ | — |
| 2 | Clean neighbourhood spot | ★★☆☆☆ | TBD |
| 3 | Popular local eatery | ★★★☆☆ | TBD |
| 4 | Destination ramen bar | ★★★★☆ | TBD |
| 5 | Legendary ramen institution | ★★★★★ | TBD |

#### 📦 Capacity Upgrades

| Upgrade | Effect | Cost |
|---------|--------|------|
| **Expand daily bowls** (×3 steps) | +10 bowls per day per upgrade | ¥1,000 each |
| **Add counter seats** | Increases simultaneous customer queue | ¥2,000 |

### Upgrade Screen UI

The upgrade screen appears at the end of every day, before the new day begins. It shows:
- Cash earned today and total cash balance
- Daily star rating with factor breakdown
- Available upgrades with costs, greyed out if unaffordable
- A "Next Day" CTA once the player is done spending

The sous chef narrates the transition: *"Good day, chef. Here's what we earned — and here's what we could do with it."*

---

## 7. Daily Rating System

At the close of each service day, the sous chef delivers a star rating out of 5. This is not a pass/fail — it is a reflection of how the shop performed today, giving the player a clear sense of what to prioritise tomorrow.

### Rating Factors

| Factor | What it measures | Weight |
|--------|-----------------|--------|
| ⚡ **Speed of service** | Average time from order placed to bowl served | 25% |
| 🏠 **Restaurant ambience** | Current restaurant tier (see Section 6) | 20% |
| 🧑‍🍳 **Chef skill** | Current skill level of the highest-rated chef | 25% |
| ✅ **Order fulfilment rate** | % of customer orders successfully completed | 30% |

### Star Thresholds

| Stars | Score range | Sous chef tone |
|-------|-------------|---------------|
| ⭐☆☆☆☆ | 0–20% | Gentle encouragement — *"It was a hard start. But we're still standing."* |
| ⭐⭐☆☆☆ | 21–40% | Honest — *"We got through it. There's room to grow."* |
| ⭐⭐⭐☆☆ | 41–60% | Warm — *"Solid service. Customers felt looked after."* |
| ⭐⭐⭐⭐☆ | 61–80% | Proud — *"The shop is finding its rhythm. Your grandfather would nod at this."* |
| ⭐⭐⭐⭐⭐ | 81–100% | Quietly moved — *"A day like this is why the shop is still standing. Remember this one."* |

### Design Note: Unfilled Orders Are Expected

In the early game with one Novice chef and a small daily capacity, the player will regularly fail to serve every customer. This is by design — not a punishment, but a signal. The rating system communicates that 40% fulfilment today is worth 2 stars, and shows the player exactly what upgrade would help most tomorrow. The game never makes the player feel they've failed; it makes them want to build.

---

## 8. Menu System — Photo-Driven

The menu is built entirely from ramen bowls the player photographs or uploads at any time. The camera is always accessible — there is no waiting for a service round to end. A player eating ramen at a small counter in Kitakata at noon can add that bowl to their menu in real time, mid-session.

### Photographing Anytime

The camera/upload button lives permanently in the bottom navigation bar of the kitchen HUD. Tapping it:

1. Pauses the service timer briefly (a few seconds of grace, covered by sous chef: *"One moment, chef."*)
2. Opens camera or photo picker
3. Submits to vision AI
4. Dish card created, menu updated immediately
5. Service timer resumes — no round boundary required

New dishes can attract new customer types in the same day's service if added early enough.

### Dish Card Data Model

| Field | Source |
|-------|--------|
| **Ramen name** | Returned by vision AI. Player can rename after creation. |
| **Regional style** | Vision AI infers regional origin. Drives Japan map and rarity tier. |
| **Broth base** | Classified by AI: miso / shoyu / shio / tonkotsu / gyukotsu / tori. |
| **Rarity tier** | Derived from region tourism footprint: Common / Uncommon / Rare / Legendary. |
| **Regional lore ** | 1-2 evocative sentences about the place the bowl comes from. Written to spark curiosity. |
| **Illustrated icon** | Stylised pixel art dish icon, auto-selected from a regional icon library. |
| **Player photo thumbnail** | Small rounded version of the actual photo. Personal food journal feel. |
| **Price** | **Returned from backend.** Not stored locally. Fetched when the dish card is created and refreshed on each session start. |
| **Available ramen varieties** | **Returned from backend.** The canonical list of recognisable ramen types, regional mappings, and their base prices is backend-managed, not hardcoded in the client. |
| **Times served / avg stars** | Tracked per dish. Feeds sous chef commentary and signature bowl logic. |

### Backend API Contract

Two backend calls drive the menu system. Both are read-only from the client's perspective.

| Call | When | Returns |
|------|------|---------|
| `GET /ramen/varieties` | Session start, and after each successful dish card creation | Canonical list of recognised ramen types with `{ variety_id, name, regional_style, broth_base, rarity_tier }` |
| `GET /ramen/{variety_id}/price` | Immediately after vision AI identifies a dish | `{ price, currency }` — displayed on the dish card and used in cash calculation when the bowl is served |

**Client behaviour:**
- Cache the variety catalogue for the session; re-fetch on next app launch
- If the price endpoint is unavailable, display a placeholder ("—") and retry silently; never block the dish card creation flow
- Price is treated as display-only on the client; the backend is the source of truth for all cash calculations

---

### Ongoing Discovery

| Trigger | Behaviour |
|---------|-----------|
| **Photo / upload a new ramen** | Dish card created with rarity tier; Japan region pulses on map. |
| **Photo a ramen already on menu** | Sous chef: *"We serve something like this — but this version looks richer. Upgrade?"* |
| **Photo a locked region's specialty** | Region marked researchable on map — unlocks when enough cash is spent. |
| **Photo from a Rare / Legendary region** | Sous chef reacts with genuine surprise. Card gets a special border treatment. |
| **Unrecognisable or low-confidence photo** | Retry branch fires. Fallback: offer 3 pre-seeded starter bowls to choose from. |

---

## 9. Character System

### 9.1 The Sous Chef

The sous chef is the player's constant companion — voice of the grandfather's kitchen, end-of-day narrator, and the most enthusiastic advocate for going somewhere unexpected. Their tone is warm, poetic, and quietly wise. They never lecture; they guide and encourage.

**Voice rule:** Maximum 12 words per line during active service. Longer, reflective lines reserved for FTUE, end-of-day ratings, and between-session moments.

| Behaviour Type | Trigger | Example Line |
|----------------|---------|-------------|
| FTUE storytelling | First launch | *"This little ramen shop may look ordinary, but it carries a long, quiet history."* |
| Dish recognition — common region | Vision AI identifies a well-known style | *"Tokyo shoyu. A classic. Solid start for the menu."* |
| Dish recognition — rare region | Vision AI identifies a lesser-known style | *"Kitakata-style? Chef, most people never make it there. This is something."* |
| Mid-service photo pause | Player taps camera during service | *"One moment, chef."* *(timer brief grace period)* |
| Queue backing up | Chef has 3+ orders queued | *"The queue's getting long. Stay focused."* |
| Rare bowl served well | 3-star on a Rare / Legendary dish | *"That's exactly why we went off the map."* |
| End of day — debrief | Daily rating delivered | *(See Section 7 star threshold lines)* |
| Upgrade suggestion | After poor speed score | *"A faster chef would change everything. Worth considering."* |
| Discovery nudge | Player hasn't photographed recently | *"The menu's good — but Tohoku is calling. Have you been north yet?"* |
| Grandfather reference | Between days | *"Your grandfather always came back from Tohoku with something no one had tried before."* |

---

### 9.2 Chefs

The kitchen starts with a single chef of Novice skill. Additional chefs are hired via the upgrade screen. Each chef operates independently with their own order queue and progress bar. LLM generates new chef profiles for hire.

| Cook | Starting skill | Region specialty | Personality |
|------|---------------|-----------------|-------------|
| **Ken 🍜** *(starter chef)* | Trained | Kanto shoyu | Methodical, quality-focused. Brings immediate Kanto competency. |


**Cook interaction rules:**
- Chefs never speak — they communicate via animation states and emoji reactions only
- Cook states: **Available → Cooking (progress bar) → Plating (brief flash) → Rest**

---

### 9.3 AI-Generated Customers

Customers are generated fresh each day by the LLM, using the player's current menu as input. Rare regional dishes attract more curious, story-rich customer types — rewarding the player for venturing beyond the tourist trail.

| Attribute | Detail |
|-----------|--------|
| **Name & personality tag** | Generated by LLM from menu rarity profile. Examples: *"First-time visitor on the standard tourist route"* (Common menu) → *"Ramen researcher quietly amazed you have Kitakata"* (Rare menu). |
| **Order logic** | Requests a dish from the player's unlocked menu. Rare dishes draw more interesting customer types. |
| **Patience** | Derived from arrival mood: Hungry (short wait tolerance), Relaxed (standard), Celebrating (tips double). |
| **Reaction on serve** | LLM generates a short reaction. Legendary-tier bowls at 3 stars earn multi-sentence, region-specific responses. |

**Pre-generation:** Generate 6–10 customer personas at day start, not live during service.

```json
// Customer generation payload
{
  "available_menu": [
    { "name": "Sapporo miso", "rarity": "uncommon" },
    { "name": "Kitakata shoyu", "rarity": "rare" }
  ],
  "day_number": 3,
  "restaurant_tier": 1,
  "chef_skill": "novice"
}

// Response
{
  "customer_name": "Emre",
  "personality_tag": "Ramen researcher quietly amazed you have Kitakata on the menu",
  "order": "Kitakata shoyu",
  "patience": "relaxed"
}
```

---

## 10. Japan Travel System

The Japan map is the world layer that gives the player's journey shape and direction. It is accessible at any time via the map icon in the HUD — during service or between days. Each region corresponds to a ramen tradition, and photographing a bowl from that region while traveling is what activates it.

### 10.1 Region Rarity Tiers

| Tier | Description | Cash multiplier | Customer reaction |
|------|-------------|----------------|-------------------|
| ⬜ **Common** | Major tourist hubs | 1× | Standard |
| 🔵 **Uncommon** | Well-known regionally, undervisited by inbound tourists | 1.3× | Pleasantly surprised |
| 🟡 **Rare** | Genuinely off the beaten path | 1.7× | Story-rich, enthusiastic |
| 🌟 **Legendary** | Remote, deeply authentic, almost unknown to tourists | 2.5× | Multi-sentence, emotionally resonant |

### 10.2 Full Region Map

| Region | Ramen Tradition | Rarity |
|--------|----------------|--------|
| 🏙 **Kanto** *(Tokyo / Yokohama)* | Tokyo shoyu, ie-kei, tsukemen | ⬜ Common |
| 🏯 **Kansai** *(Osaka / Kyoto)* | Lighter chicken-based shoyu | ⬜ Common |
| 🌾 **Hokkaido** *(Sapporo / Hakodate / Asahikawa)* | Miso, shio, shoyu — three distinct styles | 🔵 Uncommon |
| 🐖 **Kyushu** *(Fukuoka / Kumamoto / Kagoshima)* | Tonkotsu variants, black garlic | 🔵 Uncommon |
| 🏔 **Tohoku** *(Kitakata / Yamagata / Sendai)* | Wavy noodles, tori, miso | 🟡 Rare |
| 🌊 **San'in Coast** *(Tottori / Shimane)* | Tottori gyukotsu (beef bone broth) | 🟡 Rare |
| 🌀 **Shikoku** | Local underdocumented styles | 🟡 Rare |
| 🏝 **Okinawa** | Okinawa soba (pork + bonito, flat noodles) | 🌟 Legendary |
| 🌿 **Noto Peninsula** | Hyper-local seafood broths, almost undocumented | 🌟 Legendary |

**Hackathon scope:** 3 regions — Kanto (Common), Hokkaido (Uncommon), Tohoku (Rare). Demonstrates the rarity reward system within the demo.

### 10.3 The Reinforcing Cycle

```
Venture off the tourist trail
         ↓
Photograph a Rare / Legendary bowl
         ↓
Higher cash per bowl served
         ↓
Faster upgrades (chef skill, new hires, capacity, ambience)
         ↓
Higher daily star rating
         ↓
More diverse, story-rich customers
         ↓
Unlock the next distant region sooner
         ↓
(repeat)
```

### 10.4 Map UI Specification

| Element | Implementation Note |
|---------|-------------------|
| **Map artwork** | Single illustrated SVG of Japan. Warm, hand-drawn aesthetic. Lesser-known regions given equal visual care. |
| **Region states** | Greyed + faint lore hint (locked) → pulsing glow with rarity colour (photo detected) → full colour + rarity border (unlocked) |
| **Region tap** | Bottom sheet: region name, one-line lore, 2–3 signature bowl thumbnails, rarity badge, unlock cost in cash, Unlock CTA |
| **Entry point** | Map icon always visible in HUD bottom bar. Tapping during service pauses the timer briefly. |
| **Travel animation** | ByteDance clip (1–2s) on unlock. Remote regions get slower, more atmospheric clips. |

---

## 11. AI & Media Integration

### 11.1 Vision AI — Ramen Recognition

| Aspect | Detail |
|--------|--------|
| **Model** | Claude Vision (claude-3-5-sonnet) or equivalent multimodal model |
| **Prompt** | `"Identify the ramen in this image. Return JSON: { ramen_name, regional_style, broth_base, regional_lore, confidence_0_to_1 }"` |
| **Rarity assignment** | Derived from `regional_style` mapped against the rarity tier table |
| **Confidence threshold** | < 0.6 → Recognition Incorrect branch; offer retry or pre-seeded starter selection |
| **Available anytime** | API call triggered whenever the player photographs or uploads — no session boundary |
| **Latency target** | < 3s on LTE. Show scanning animation. Never a raw spinner. |

### 11.2 LLM — Sous Chef & Customer Generation

| Usage | Detail |
|-------|--------|
| **Sous chef commentary** | Game-state JSON → short reactive line. Max 1 call / 4s during service. 30+ pre-written fallback lines per category. |
| **End-of-day debrief** | Daily rating payload → sous chef summary line (tone matches star level, see Section 7). |
| **Customer generation** | Pre-generate 6–10 customer personas at day start using current menu + restaurant state. |
| **Customer reaction** | Quality score + ramen name + rarity tier → reaction line. Non-blocking post-serve call. |

### 11.3 Seedoms — Wow Moments

Pre-generate and cache 8–10 clips. Do **not** call live during gameplay. Maximum 1 clip per day.

| Trigger | Clip Content |
|---------|-------------|
| 3-star bowl served (Common) | Happy customer reaction. Warm, upbeat. |
| 3-star bowl served (Rare / Legendary) | Visibly emotional customer reaction. |
| Signature bowl unlocked | Montage of multiple customers enjoying the same bowl. |
| Perfect day (5-star rating) | Restaurant exterior, full queue forming outside. |
| Region unlocked (Common) | Busy, recognisable street scene. |
| Region unlocked (Rare / Legendary) | Quiet, atmospheric footage — fog over a coastline, a lantern in a market alley. |

### 11.4 ByteDance — Polish Moments

Used only at session bookends. Never mid-service.

- **App load:** 2–3s branded intro on first launch
- **Day start:** "Kitchen doors open" transition
- **Region unlock:** 1–2s travel flavour clip feeding into Seedoms regional reveal

---

## 12. Technical Architecture

### 12.1 Flutter / iOS Stack

| Layer | Package / Approach |
|-------|-------------------|
| **Framework** | Flutter 3.x, iOS primary target |
| **State management** | Riverpod — reactive streams for orders, chef states, customer queue, menu, cash balance, upgrade state |
| **Camera / upload** | `camera` package + `image_picker` for photo library access |
| **Vision AI** | `dio` + multipart POST to Claude Vision API; decode JSON dish card response |
| **LLM calls** | `http` + Anthropic REST API; `dio` for retry/timeout; 800ms timeout before fallback |
| **Backend API** | `dio` — REST calls for (1) ramen variety catalogue, (2) per-dish pricing; called on dish card creation and session start; responses cached locally until next session |
| **Game loop / timers** | Dart Isolate for non-blocking tick; `StreamProvider` to push cook progress and service timer to UI |
| **Animations** | Lottie for chef state animations; `AnimationController` for map glow states and rarity shimmer |
| **Video playback** | `video_player` for pre-cached Seedoms / ByteDance clips |
| **Local storage** | `shared_preferences` for dish cards (JSON, excluding price), unlocked regions, cash balance, upgrade state, day count |
| **Map** | `flutter_svg` for Japan map; `GestureDetector` overlays for region tap targets |

### 12.2 Screen Inventory (Minimum Viable)

| Screen | Key Contents |
|--------|-------------|
| **Intro / load** | ByteDance clip → Play button. No sign-up. |
| **FTUE — kitchen (dark)** | Sous chef opening monologue. |
| **FTUE — camera / upload** | Full-screen camera or picker → scanning overlay → dish card reveal → map pulse |
| **Kitchen HUD** | Customer arrival area (top) \| Order ticket rail \| Chef station cards with progress bars \| Sous chef bubble (bottom-left) \| Day timer (top-right) \| Camera + Menu + Map icons (bottom bar) |
| **Menu board** | Scrollable dish card grid, grouped by region, rarity borders. Camera FAB. |
| **Japan map** | SVG map + tappable region overlays with rarity glow + unlock bottom sheet |
| **End-of-day summary** | Star rating with factor breakdown, sous chef debrief line, cash earned |
| **Upgrade screen** | Chef upgrades / hire / capacity / restaurant tier — costs shown, greyed if unaffordable |

---

## 13. Hackathon Build Priority

See [todo.md](todo.md) for the full task breakdown, split into BE (Backend) and FE (Frontend) categories.

---

## 14. Scope Boundaries

### In Scope

- Grandfather's ramen shop narrative and full FTUE dialogue
- Discovery philosophy: rarer regions yield higher cash and richer customer reactions
- Camera / upload accessible at any point during play
- Single starting chef (Novice); hire up to 2 additional chefs via upgrades
- Cash economy: earned per bowl, spent on chef skill / hires / capacity / restaurant tier
- End-of-day star rating (speed, ambience, chef skill, fulfilment rate)
- Restaurant visual progression: 5 tiers from run-down shop to legendary institution
- AI-generated customers with rarity-aware personality tags
- 3-region Japan map (Common, Uncommon, Rare) with rarity glow states
- Pre-cached Seedoms clips differentiated by rarity
- ByteDance app load + day-start animation
- 2–3 playable days, persistent state across sessions

### Out of Scope

- User accounts, sign-up, or authentication
- Real GPS / location verification
- Live Seedoms generation during gameplay
- More than 3 Japan regions for the hackathon build
- Non-ramen food items
- Multiplayer, social sharing, or leaderboards
- Ingredient management or shopping mechanics
- Tutorial overlays (the sous chef IS the tutorial)
- Monetisation, IAP, ads
- In-app tourism recommendations or external links

---

## 15. Open Design Questions

| Question | Suggested Default — Confirm or Override |
|----------|----------------------------------------|
| How long is one service day? | 4 minutes real-time. Represents a dinner service. Adjust after first playtest. |
| How many customer slots per day at game start? | 8 customers, only 5 bowls can be completed by a Novice chef in 4 minutes. Forces queue management immediately. |
| Does the service timer pause fully when the player opens the camera? | Yes — brief pause with sous chef grace line. Prevents frustration during discovery moments. |
| Does the map also pause the service timer? | Yes, same grace period. Keeps exploration feel-good rather than stressful. |
| Is the grandfather a character the player interacts with? | Not for hackathon. Referenced in FTUE backstory only. A photo on the kitchen wall is a nice visual touch. |
| How does the restaurant tier change visually? | Pixel art swap of the background kitchen art. 5 art states. Achievable for hackathon if designer has capacity; otherwise defer to post-launch. |
| Should Common-region bowls feel noticeably less exciting than Rare ones? | Yes — intentional and core to the design philosophy. Common dishes work fine; Rare dishes feel like discoveries. |
| When does a new chef unlock? | Hire option appears in the upgrade screen once <TBD amount> is accumulated. No region gating for hackathon. |
| Should the sous chef reference the grandfather during play? | Occasionally, between days only. *"Your grandfather always came back from Tohoku with something no one had tried before."* |
| How explicit should the anti-overtourism message be? | Never explicit. The design carries it. The game should feel like an adventure, not a public service announcement. |

---

*Gourmet GO — Prototype Plan*
*The best bowl you've ever had is probably somewhere you haven't been yet.*