# MANNEQUIN — Game Design Document

## 1. Overview

**Title:** Mannequin
**Genre:** Horror / Social Deduction
**Platform:** Roblox (PC, Mobile, Console, VR)
**Players:** 6-12 per server
**Round Duration:** 5 minutes per round
**Target Audience:** Ages 10+ (Roblox horror community)

### Elevator Pitch
One player is the Monster — disguised as a store mannequin in a creepy department store. Other players must shop, complete tasks, and survive without realizing which mannequin is alive. The Monster can only move when no one is looking at it. Pure psychological horror. No jumpscares. Just paranoia.

---

## 2. Core Gameplay Loop

```
LOBBY (15-30s wait) 
  → ROLE ASSIGNMENT (Monster chosen secretly)
  → SHOPPING PHASE (players complete tasks in the store)
  → TENSION ESCALATES (lights flicker, mannequins "shift")
  → CONFRONTATION (Monster strikes / players identify & vote)
  → ROUND END (win/lose, XP awarded)
  → REPEAT
```

### Player Roles

#### Shoppers (Survivors)
- **Objective:** Complete 5 shopping tasks and escape OR identify & vote out the Monster.
- **Actions:** Walk around the store, pick up items, interact with shelves, use flashlight, call emergency vote.
- **Lose condition:** Get "captured" by the Monster (touched from behind when Monster is in kill range).

#### Monster (1 player)
- **Objective:** Eliminate 3 shoppers before time runs out OR avoid being voted out.
- **Actions:** Disguise as a mannequin (freeze in place), move ONLY when no player's camera is pointed at you, perform "kill" when close enough and unseen.
- **Movement rule:** If ANY player's camera frustum includes the Monster, the Monster is FROZEN and cannot move. Period.
- **Lose condition:** Gets voted out by shoppers in an emergency meeting.

#### Shopkeeper (Optional Role — unlockable)
- **Objective:** Help shoppers survive. Has access to security cameras.
- **Actions:** View security camera feeds (4 angles), announce warnings to shoppers, lock/unlock doors.
- **Cannot:** Move from the security room. Cannot be killed.

---

## 3. Core Mechanics

### 3.1 Line-of-Sight / Gaze System
This is the CORE mechanic that makes the game work.

**How it works:**
1. Every frame, the server checks each shopper's camera `CFrame` (position + look direction).
2. A frustum (cone of vision) is calculated for each shopper.
3. The Monster's position is tested against ALL shopper frustums.
4. If the Monster is inside ANY frustum AND not fully occluded by walls/objects → Monster is FROZEN.
5. If no shopper can see the Monster → Monster can move freely.

**Visual feedback:**
- Monster sees a red vignette when frozen ("You are being watched").
- Monster sees green vignette when free to move.
- Shoppers see nothing — they don't know if they're looking at the Monster or a real mannequin.

**Occlusion:**
- Raycasts from each shopper's camera to the Monster check for walls/objects in between.
- If all rays are blocked → Monster is NOT considered "seen" even if in frustum.

### 3.2 Mannequin Disguise System
- The store has 20-40 mannequins placed throughout.
- When the Monster freezes (is being watched), they become visually IDENTICAL to nearby mannequins — same pose, same material.
- The Monster player can choose from 3 preset freeze poses (standing, arms out, looking down).
- Shoppers can "inspect" mannequins (hold E for 2 seconds) — this checks: is this the Monster? If yes, the Monster is briefly stunned and revealed for 3 seconds.
- Inspecting has a 15-second cooldown to prevent spam.

### 3.3 Shopping Tasks
Players must complete tasks to "win by escape." Tasks are simple interactions:

| Task | Description |
|------|------------|
| Find Item | Go to a marked shelf, press E to pick up a specific item |
| Checkout | Bring items to a register and interact |
| Restock Shelf | Carry items from backroom to a marked shelf |
| Fix Lights | Find a fuse box and complete a short minigame (press buttons in order) |
| Clean Spill | Stand on a marked spot for 5 seconds |

Each player gets 5 random tasks. Completing all 5 opens the exit doors.

### 3.4 Emergency Vote System
- Any shopper can call an emergency meeting (1 per player per round, button in UI).
- All players teleport to the store entrance.
- 30-second discussion phase (chat only).
- 15-second voting phase — vote for who you think is the Monster, or skip.
- Majority vote eliminates that player. If they were the Monster → Shoppers win. If innocent → game continues with fewer shoppers.

### 3.5 Kill Mechanic
- Monster must be within 8 studs of a shopper AND unseen by any other shopper.
- Kill animation plays (mannequin hand reaches out, screen goes black for victim).
- Victim becomes a spectator (ghost cam).
- Body disappears after 10 seconds — other shoppers only see an empty space where the player was.

### 3.6 Atmosphere & Tension Escalation
Time-based events that increase tension:

| Time | Event |
|------|-------|
| 0:00 | Round starts. Store is well-lit, calm music. |
| 1:00 | Lights flicker briefly. Some mannequins subtly change pose (cosmetic — not the Monster). |
| 2:00 | One section of the store goes dark. Footstep sounds echo. |
| 3:00 | Half the lights are off. Ambient whispering sounds. Real mannequins occasionally "twitch." |
| 4:00 | Emergency lighting only (red). Heartbeat audio intensifies. Monster moves 20% faster. |
| 4:30 | Final warning — exit doors begin closing. Monster moves 40% faster. |
| 5:00 | Time's up. If Monster hasn't killed 3, shoppers win. |

---

## 4. Map: The Department Store

### Layout
A 2-floor department store with these sections:

**Floor 1 (Ground):**
- Entrance / Lobby (spawn point + emergency meeting spot)
- Clothing Section (racks, mannequins wearing outfits)
- Electronics Section (TVs, displays)
- Checkout Registers (3 lanes)
- Storage Room (dim lighting, boxes, narrow aisles)

**Floor 2 (Upper):**
- Home & Furniture Section (beds, couches, mannequins posed in "living rooms")
- Toy Section (creepy dolls, shelves)
- Security Room (Shopkeeper's location, camera monitors)
- Employee Break Room (lockers, table)
- Restrooms (tight spaces, mirrors)

**Connectors:**
- 2 escalators (moving)
- 1 elevator (can be disabled by Monster)
- 1 stairwell (tight, dark)

### Mannequin Placement
- 30+ mannequins throughout the store
- Clustered in groups of 3-5
- Some in natural poses, some in slightly "off" poses
- Every round, mannequin positions are slightly shuffled (so memorization doesn't work)

---

## 5. Progression System

### XP & Levels
| Action | XP Earned |
|--------|----------|
| Complete a shopping task | +25 XP |
| Survive the round (shopper) | +100 XP |
| Correctly vote out Monster | +150 XP |
| Kill a shopper (monster) | +50 XP |
| Win as Monster | +200 XP |
| Inspect and find the Monster | +100 XP |

Level thresholds: 0, 500, 1500, 3000, 5000, 8000, 12000, 17000, 23000, 30000...

### Unlockables (by Level)
| Level | Unlock |
|-------|--------|
| 1 | Default mannequin skin |
| 3 | "Wooden" mannequin skin |
| 5 | Shopkeeper role unlocked |
| 7 | "Chrome" mannequin skin |
| 10 | Custom freeze pose #1 |
| 15 | "Cracked Porcelain" mannequin skin |
| 20 | Custom freeze pose #2 |
| 25 | "Shadow" mannequin skin (semi-transparent) |
| 30 | "Gold" mannequin skin |
| 50 | "Void" mannequin skin (legendary) |

---

## 6. Monetization

### Game Passes (One-Time Purchase)
| Pass | Price (Robux) | Effect |
|------|--------------|--------|
| VIP | 199 | 2x XP, VIP nameplate, access to VIP lounge in lobby |
| Radio | 99 | Play music in lobby |
| Flashlight Pro | 149 | Wider, brighter flashlight beam |
| Extra Inspect | 99 | Inspect cooldown reduced from 15s to 8s |

### Developer Products (Consumable)
| Product | Price (Robux) | Effect |
|---------|--------------|--------|
| 2x XP Boost (1 hour) | 49 | Double XP for 1 hour |
| Skip Task | 29 | Auto-complete one shopping task |
| Extra Vote | 19 | Get a second emergency meeting call |

### Cosmetic Shop (In-Game Currency: Store Credits)
- Shopper outfits (hats, shirts, accessories)
- Mannequin skins (for Monster role)
- Kill effect animations
- Lobby emotes

---

## 7. Technical Architecture

### Server Authority
ALL game logic runs on the server:
- Role assignment
- Line-of-sight calculations
- Kill validation
- Vote counting
- Task completion
- XP/data saving

The client only sends:
- Camera CFrame (for gaze detection)
- Input actions (move, interact, vote)

### Anti-Cheat
- Server validates all kills (distance + visibility check)
- Camera CFrame is validated against movement speed
- Inspect results are server-calculated
- Vote manipulation is impossible (server counts)

### Performance Targets
- 60 FPS on mid-range PC
- 30 FPS on mobile
- Max 12 players per server
- Streaming enabled for map loading

---

## 8. Sound Design

| Sound | When |
|-------|------|
| Calm store music | Round start (0:00 - 1:00) |
| Music distortion | 1:00+ (gradually increases) |
| Footsteps (wood/tile) | Player movement |
| Heartbeat | When near a mannequin / tension phase |
| Static burst | When a light flickers |
| Whispers | 3:00+ ambient |
| Kill sound | Low bass drone + cut to silence |
| Vote bell | Emergency meeting called |
| Victory fanfare | Round win |
| Defeat drone | Round loss |

---

## 9. Mobile Controls

| Action | PC | Mobile |
|--------|-----|--------|
| Move | WASD | Virtual joystick |
| Look | Mouse | Touch drag |
| Interact | E key | Interact button (bottom right) |
| Flashlight | F key | Flashlight button (bottom right) |
| Inspect mannequin | Hold E | Hold Interact button |
| Call meeting | M key | Meeting button (top right) |
| Vote | Click player | Tap player icon |

---

## 10. Post-Launch Roadmap

### Month 1: "Grand Opening"
- Launch with base game
- Monitor balance (Monster win rate should be ~40-45%)
- Bug fixes

### Month 2: "After Hours" Update
- New map: Mall at Night (bigger, darker, more mannequins)
- New role: Security Guard (can lock doors, has taser to stun Monster for 3s)
- Halloween event skins

### Month 3: "Black Friday" Update
- Chaos mode: 2 Monsters, 10 shoppers
- New tasks: Carry fragile items (drop = fail), timed discounts
- Seasonal cosmetics

### Month 4: "Returns Department" Update
- New map: IKEA-style furniture warehouse
- Revenge mode: Eliminated players become mini-ghosts that can slow the Monster
- Community-submitted mannequin skins
