# MANNEQUIN — Full Roblox Horror Game (v1.0.0)

A complete, production-ready Roblox horror/social deduction game where one player disguises as a mannequin in a department store. The mannequin can only move when no one is looking.

**22 scripts. 2,800+ lines of Luau. Server-authoritative. Anti-cheat. Full UI. Ready to publish.**

---

## How to Install in Roblox Studio

### Step 1: Create a New Place
1. Open **Roblox Studio**
2. Create a new place (Baseplate or empty)
3. Save it to Roblox (File > Save to Roblox)

### Step 2: Set Up the Folder Structure

Create the following structure in the Explorer panel. The game has **22 scripts** organized across 4 services:

**ServerScriptService (14 ModuleScripts + 1 Script):**
- Main (Script — NOT ModuleScript)
- GameManager, PlayerManager, GazeSystem, TaskManager, VoteManager
- DataManager, AtmosphereManager, MonetizationManager, MonsterController
- MannequinSetup, SoundManager, AntiExploit, ProximityPromptSetup

**ReplicatedStorage:**
- Modules (Folder) > Config, Utils (ModuleScripts)
- Remotes (Folder) > RemoteSetup (ModuleScript)

**StarterPlayerScripts (2 LocalScripts):**
- ClientController, SpectatorCamera

**StarterGui (5 LocalScripts):**
- HUDController, LoadingScreen, SettingsMenu, ShopUI, TutorialUI

### Step 3: Copy the Code
For each file in the src/ folder:
1. Right-click the correct parent in Explorer
2. Insert Object > choose the correct type (Script, ModuleScript, or LocalScript)
3. Paste the contents from the corresponding .lua file
4. Rename each script to match the file name (without .lua)

### Step 4: Build the Map
Use Roblox Studio AI Assistant (View > Assistant):

Prompt: "Create a 2-floor department store interior with clothing section, mannequin display areas, electronics section, 3 checkout registers, storage room, furniture section, toy section, security room, break room, restrooms, 2 escalators, 1 elevator, 1 stairwell, entrance lobby with glass doors, fluorescent ceiling lights, tile flooring"

Then: "Add 30 mannequin figures throughout the store in display poses"

### Step 5: Tag Map Objects

**Required CollectionService Tags (use Tag Editor plugin):**

| Tag | What To Tag | Min Count |
|-----|------------|-----------|
| ShelfInteract | Shelves for item pickup | 10+ |
| Register | Checkout counters | 3+ |
| FuseBox | Electrical panels | 3+ |
| SpillZone | Floor spill areas | 3+ |
| ExitDoor | Exit door parts | 2+ |
| LightFixture | All PointLight/SpotLight instances | All |
| SecurityCamera | Camera models | 4+ |
| Mannequin | Mannequin models (auto-tagged by code) | 25-40 |

**Required Spawn Points (Attributes on SpawnLocation parts):**

| Attribute | Where |
|-----------|-------|
| SpawnTag = "ShopperSpawn" | Lobby area (4+ spots) |
| SpawnTag = "MonsterSpawn" | Storage room (hidden) |
| SpawnTag = "MeetingPoint" | Center of lobby |
| MannequinSpawn = true | Where mannequins appear (25+ parts) |

### Step 6: Configure Game Settings
1. Game Settings > Security: Enable Studio Access to API Services
2. Workspace > StreamingEnabled: true
3. Players > CharacterAutoLoads: false

### Step 7: Set Up Game Passes (Optional)

| Game Pass | Price |
|-----------|-------|
| VIP (2x XP) | R\99 |
| Monster Radio | R\9 |
| Flashlight Pro | R9 |
| Extra Inspect | R\9 |

Copy Asset IDs into Config.lua > Config.GamePasses

### Step 8: Test!
1. F5 for solo test
2. Test > Start with 4+ players for multiplayer test

---

## Complete File Reference (22 scripts)

### Server (14 files)
| File | Purpose |
|------|---------|
| Main.lua | Bootstrap — initializes all systems |
| GameManager.lua | Round lifecycle, state machine, win conditions |
| PlayerManager.lua | Spawning, death, spectating |
| GazeSystem.lua | **CORE** — frustum + raycast line-of-sight |
| TaskManager.lua | Shopping task assignment and tracking |
| VoteManager.lua | Emergency meetings, voting, elimination |
| DataManager.lua | DataStore persistence, XP, levels |
| AtmosphereManager.lua | 6-phase tension escalation |
| MonetizationManager.lua | Game Passes, Dev Products |
| MonsterController.lua | Kill validation, inspect, stun |
| MannequinSetup.lua | Procedural mannequin spawning |
| SoundManager.lua | 40+ sounds, music, SFX, ambient |
| AntiExploit.lua | Rate limiting, teleport/speed detection |
| ProximityPromptSetup.lua | Modern E-press interactions |

### Client (2 files)
| File | Purpose |
|------|---------|
| ClientController.lua | Input, camera stream, flashlight, mobile |
| SpectatorCamera.lua | Dead player camera cycling |

### GUI (5 files)
| File | Purpose |
|------|---------|
| HUDController.lua | HUD, tasks, voting, notifications |
| LoadingScreen.lua | Animated loading with asset preload |
| SettingsMenu.lua | Volume, graphics, sensitivity |
| ShopUI.lua | Cosmetics shop (skins, effects, emotes) |
| TutorialUI.lua | 9-step interactive onboarding |

### Shared (3 files)
| File | Purpose |
|------|---------|
| Config.lua | All tuning values |
| Utils.lua | Math, shuffle, debounce helpers |
| RemoteSetup.lua | 50+ RemoteEvents/Functions |

---

## Key Controls

| Key | Action |
|-----|--------|
| E | Interact / Inspect mannequin |
| F | Toggle flashlight |
| Q | Kill (Monster only) |
| M | Call emergency meeting |
| Tab | Toggle task list |
| B | Open shop |
| P/Esc | Open settings |
| Arrows | Cycle spectator targets |

---

## Anti-Exploit Protection
- Rate limiting on all RemoteEvents
- Teleport detection (max 80 studs/s)
- Speed hack detection
- WalkSpeed/JumpPower monitoring
- Camera validation (detects freecam)
- Auto-kick after 10 violations
- Server-authoritative kills, votes, tasks

---

## Tuning (Config.lua)

| Value | Default | Effect |
|-------|---------|--------|
| Monster.KillRange | 8 studs | Kill distance |
| Monster.KillCooldown | 5s | Between kills |
| Gaze.FieldOfView | 70 deg | Camera detection cone |
| Gaze.MaxViewDistance | 120 studs | Max see distance |
| Round.RoundDuration | 300s | Round length |
| Shopper.InspectCooldown | 15s | Between inspections |

Target Monster win rate: 40-45%.

---

## Game Design Document
See docs/GAME_DESIGN_DOCUMENT.md for full specification.
