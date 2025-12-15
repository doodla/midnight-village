# ONUW Game Design

High-level design for Midnight Village's first game implementation: One Night Ultimate Werewolf (ONUW) companion app.

## Overview

**What:** A digital companion app for playing One Night Ultimate Werewolf in person. Players sit together and talk face-to-face, but use their phones for role assignment, night actions, and voting.

**Why:** Eliminates awkward reaching across the table with 8-10 players, ensures truly secret/simultaneous votes, and handles night phase timing automatically.

**Platform:** Flutter (web, iOS, Android) + Django backend with WebSockets

## Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Midnight Village                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌─────────────┐     ┌─────────────────────────────────────────┐    │
│  │   Flutter   │     │              Django Backend              │    │
│  │   Client    │     ├─────────────────────────────────────────┤    │
│  │             │     │                                         │    │
│  │  • Web      │ WS  │  apps.core                              │    │
│  │  • iOS      │◄───►│    • User accounts & auth               │    │
│  │  • Android  │     │    • Generic lobby shell                │    │
│  │             │     │      (rooms, codes, join, ready, host)  │    │
│  │             │ HTTP│    • WebSocket connection management    │    │
│  │             │◄───►│                                         │    │
│  └─────────────┘     │  apps.onuw                              │    │
│                      │    • ONUW lobby config (role selection) │    │
│                      │    • Game state machine                 │    │
│                      │    • Role definitions & behaviors       │    │
│                      │    • Night phase orchestration          │    │
│                      │    • Voting & resolution                │    │
│                      │                                         │    │
│                      └──────────────┬──────────────────────────┘    │
│                                     │                                │
│                      ┌──────────────┴──────────────┐                │
│                      │      Redis       PostgreSQL │                │
│                      │  (channels/cache)   (data)  │                │
│                      └─────────────────────────────┘                │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions

1. **Separate game implementations** - Each game type (ONUW, future Mafia, etc.) is its own Django app. Shared infrastructure lives in `apps.core`. This avoids premature abstraction; common patterns will be extracted after building multiple games.

2. **Generic lobby + game-specific config** - `apps.core` provides the lobby shell (room codes, join/leave, ready status, host controls). Each game app extends this with its own configuration (ONUW adds role selection).

3. **WebSockets for real-time** - Django Channels with Redis-backed channel layer. Enables instant phase transitions, synchronized timers, and simultaneous reveals.

4. **Server-authoritative** - All game logic runs on the server. Clients send actions, server validates and broadcasts results.

## Core Components

### `apps.core` Responsibilities

- User accounts and authentication
- Generic lobby system (create, join via code/QR, ready up, host controls)
- WebSocket connection management and routing to game-specific handlers
- Base classes/interfaces that game apps can extend

### `apps.onuw` Responsibilities

- ONUW-specific lobby configuration (role selection, player count validation)
- Game state machine (night → discussion → voting → resolution)
- Role definitions with behaviors and night action ordering
- Night phase orchestration (waves, timers, action resolution)
- Voting collection and win condition evaluation

### Future Game Apps

Future games (e.g., `apps.mafia`) would follow the same pattern:
- Depend on `apps.core` for shared infrastructure
- Own their lobby configuration and game logic
- Remain independent of other game apps

## Game Flow

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│    LOBBY     │───►│    NIGHT     │───►│  DISCUSSION  │
│              │    │              │    │              │
│ • Join room  │    │ • Waves run  │    │ • Timer      │
│ • Pick roles │    │ • Actions    │    │ • In-person  │
│ • Ready up   │    │   resolve    │    │   talking    │
└──────────────┘    └──────────────┘    └──────┬───────┘
                                               │
                    ┌──────────────┐    ┌──────▼───────┐
                    │   RESULTS    │◄───│    VOTING    │
                    │              │    │              │
                    │ • Reveal     │    │ • Submit     │
                    │   votes      │    │   votes      │
                    │ • Reveal     │    │ • Simultaneous│
                    │   roles      │    │   reveal     │
                    │ • Winner     │    └──────────────┘
                    └──────────────┘
```

### Phase Details

1. **Lobby** - Host configures roles, players join via room code or QR, everyone readies up, host starts game
2. **Night** - Roles act in waves (Doppelganger → Werewolves → Others → Insomniac), each wave is timed
3. **Discussion** - Countdown timer displayed, players talk in person
4. **Voting** - Everyone submits vote through app, simultaneous lock-in when timer expires
5. **Results** - Votes revealed, roles revealed, winner announced

## Night Phase Design

### Wave-Based Execution

```
Wave 1: Doppelganger
  └─► Copies a player's role, may act again in later wave

Wave 2: Werewolves, Minion, Masons
  └─► See each other (no actions that change game state)

Wave 3: Seer, Robber, Troublemaker, Drunk
  └─► Independent actions, resolve simultaneously

Wave 4: Insomniac, Doppelganger-as-Insomniac
  └─► See own final role after all swaps
```

### Role Behavior Model

- Each role defines: team, wave number, action type, action logic
- Action types: `peek_player`, `peek_center`, `swap_with_player`, `swap_with_center`, `swap_others`, `see_team`, `none`
- Server resolves all actions in wave after timer expires, then broadcasts "wave complete"

### Doppelganger Handling

- Acts in Wave 1: picks a player, copies their role
- If copied role has a night action, Doppelganger acts again in that role's wave (or Wave 4 for Insomniac)
- Server tracks copied role separately

### Timer Model

- Each wave has a configurable duration (e.g., 10 seconds)
- Players without actions see a "waiting" screen
- If a player doesn't submit in time, their action is skipped

## Roles (v1)

12 roles for initial release:

**Core (7):**
- Werewolf, Villager, Seer, Robber, Troublemaker, Drunk, Insomniac

**Extended (4):**
- Minion, Tanner, Hunter, Mason

**Complex (1):**
- Doppelganger

Including Doppelganger from day one ensures the architecture handles dynamic role behavior and multi-phase actions.

## Client-Server Communication

### HTTP Endpoints (REST)

- Auth (login, register, token refresh)
- Lobby CRUD (create, join by code, leave, get state)
- User profile

### WebSocket Events

- Player joins/leaves lobby
- Ready state changes
- Game start
- Phase transitions
- Night action prompts and submissions
- Vote submissions
- Results broadcast

### Principle

- HTTP for request/response operations (auth, creating lobby)
- WebSocket for anything where multiple clients need updates (game state changes)

## Future Considerations

### Shared Screen / TV Mode

- API already sends phase state, timers, vote counts
- Future "spectator" client connects to same game, receives same events
- Renders a "table center" view instead of player view (big timer, dramatic reveals)

### Additional Games

- New `apps.<game>` follows same pattern
- Registers with core, provides its own lobby config and game logic
- Core routes WebSocket messages to appropriate game handler

### Expansion Roles

- Role system designed for extension
- New roles = new behavior definitions, add to wave ordering
- No core changes needed

## Implementation Sections

This design can be implemented in the following chunks:

1. **Core infrastructure** - `apps.core` with user auth, generic lobby system, WebSocket setup
2. **ONUW lobby** - Role selection, game creation, join flow
3. **Night phase engine** - Wave system, role behaviors, action resolution
4. **Discussion & voting** - Timer management, vote collection, simultaneous reveal
5. **Results & win conditions** - Vote counting, role reveals, winner determination
6. **Flutter client** - Screens for each phase, WebSocket integration

Each section can be tackled independently once the previous dependencies are in place.
