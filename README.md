# MANNEQUIN — Full Roblox Horror Game (v1.0.0)

A complete, production-ready Roblox horror/social deduction game where one player disguises as a mannequin in a department store. The mannequin can only move when no one is looking.

**22 scripts. 4,500+ lines of Luau. Server-authoritative. Anti-cheat. Full UI. Ready to publish.**

---

## Development Setup (Rojo + GitHub)

This project uses [Rojo](https://rojo.space) to sync code from your filesystem into Roblox Studio, so you can use VS Code (or any editor) + Git for version control.

### Prerequisites

1. **[Aftman](https://github.com/LPGhatguy/aftman)** — Toolchain manager (installs Rojo, Selene, StyLua, Wally)
2. **[Roblox Studio](https://www.roblox.com/create)** — For map building and playtesting
3. **[VS Code](https://code.visualstudio.com/)** + [Rojo extension](https://marketplace.visualstudio.com/items?itemName=evaera.vscode-rojo) (recommended)

### Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/groupsmix/mannequin.git
cd mannequin

# 2. Install tools (Rojo, Selene, StyLua, Wally)
aftman install

# 3. Install packages (if any are added later)
wally install

# 4. Start Rojo dev server
rojo serve
```

Then in **Roblox Studio**:
1. Install the [Rojo plugin](https://www.roblox.com/library/13916111004) from the Roblox Marketplace
2. Open a new or existing place
3. Click **Rojo > Connect** in the plugin toolbar
4. Your code syncs live — edit in VS Code, see changes in Studio instantly

### Build a .rbxl File

```bash
rojo build -o Mannequin.rbxl
```

This creates a complete place file you can open directly in Roblox Studio.

### Linting & Formatting

```bash
# Check formatting
stylua --check src/

# Auto-format
stylua src/

# Lint for errors
selene src/
```

### CI Pipeline

Every push and pull request to `main` runs GitHub Actions that:
1. Checks formatting with **StyLua**
2. Lints with **Selene**
3. Builds with **Rojo** (validates project structure)

---

## Project Structure

```
mannequin/
├── default.project.json          # Rojo project — maps files to Roblox services
├── aftman.toml                   # Toolchain (Rojo, Selene, StyLua, Wally)
├── selene.toml                   # Linter config
├── stylua.toml                   # Formatter config
├── wally.toml                    # Package manager
├── .github/workflows/ci.yml     # GitHub Actions CI
├── docs/
│   └── GAME_DESIGN_DOCUMENT.md
└── src/
    ├── ServerScriptService/      # Server-side code
    │   ├── Main.server.luau      # Bootstrap (Script)
    │   ├── GameManager.luau      # Round lifecycle (ModuleScript)
    │   ├── PlayerManager.luau    # Spawning, death, spectating
    │   ├── GazeSystem.luau       # CORE — line-of-sight detection
    │   ├── TaskManager.luau      # Shopping task system
    │   ├── VoteManager.luau      # Emergency meetings + voting
    │   ├── DataManager.luau      # DataStore persistence
    │   ├── AtmosphereManager.luau # 6-phase tension escalation
    │   ├── MonetizationManager.luau
    │   ├── MonsterController.luau
    │   ├── MannequinSetup.luau   # Procedural mannequin spawning
    │   ├── SoundManager.luau     # 40+ sounds
    │   ├── AntiExploit.luau      # Rate limiting, teleport detection
    │   └── ProximityPromptSetup.luau
    ├── ReplicatedStorage/        # Shared between server + client
    │   ├── Modules/
    │   │   ├── Config.luau       # All tuning values
    │   │   └── Utils.luau        # Math, shuffle, helpers
    │   └── Remotes/
    │       └── RemoteSetup.luau  # 50+ RemoteEvents/Functions
    ├── StarterPlayerScripts/     # Client-side scripts
    │   ├── ClientController.client.luau   # Input, camera, flashlight
    │   └── SpectatorCamera.client.luau    # Dead player camera
    └── StarterGui/               # GUI scripts
        ├── HUDController.client.luau      # HUD, tasks, voting, notifications
        ├── LoadingScreen.client.luau      # Animated loading screen
        ├── SettingsMenu.client.luau       # Volume, graphics, sensitivity
        ├── ShopUI.client.luau             # Cosmetics shop
        └── TutorialUI.client.luau         # 9-step onboarding
```

### Rojo File Naming Convention

| Suffix | Roblox Type | Used For |
|--------|-------------|----------|
| `.server.luau` | Script | Server entry points |
| `.client.luau` | LocalScript | Client-side scripts |
| `.luau` | ModuleScript | Shared modules (default) |

---

## Map Setup in Roblox Studio

### Step 1: Build the Map

Use Roblox Studio AI Assistant (View > Assistant):

**Prompt:** "Create a 2-floor department store interior with clothing section, mannequin display areas, electronics section, 3 checkout registers, storage room, furniture section, toy section, security room, break room, restrooms, 2 escalators, 1 elevator, 1 stairwell, entrance lobby with glass doors, fluorescent ceiling lights, tile flooring"

**Then:** "Add 30 mannequin figures throughout the store in display poses"

### Step 2: Tag Map Objects

Install the **Tag Editor** plugin, then apply these CollectionService tags:

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

### Step 3: Configure Game Settings

1. Game Settings > Security: Enable **Studio Access to API Services**
2. These are auto-set by Rojo via `default.project.json`:
   - Workspace > StreamingEnabled: `true`
   - Players > CharacterAutoLoads: `false`

### Step 4: Set Up Game Passes (Optional)

| Game Pass | Price |
|-----------|-------|
| VIP (2x XP) | R$199 |
| Monster Radio | R$99 |
| Flashlight Pro | R$149 |
| Extra Inspect | R$99 |

Create these on the [Creator Dashboard](https://create.roblox.com), then paste Asset IDs into `src/ReplicatedStorage/Modules/Config.luau > Config.GamePasses`.

### Step 5: Test!

1. **F5** for solo test
2. **Test > Start** with 4+ players for multiplayer test

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

## Tuning (Config.luau)

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

See [docs/GAME_DESIGN_DOCUMENT.md](docs/GAME_DESIGN_DOCUMENT.md) for full specification.
