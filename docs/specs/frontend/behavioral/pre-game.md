# Pre-Game

## Identity

| Field     | Value |
|-----------|-------|
| type      | screen |
| id        | S01, S02 |
| phase     | all (pre-game, outside game sessions) |
| route     | S01: `/welcome`, S02: `/home` |

This spec covers the Welcome/Auth screen (S01) and the Home screen (S02). These are the simplest screens in the app but set the first impression. The emotional arc begins here: approaching a candlelit tavern door at midnight, then stepping inside to choose your table.

Most players spend less than 10 seconds on Welcome. The Home screen is the persistent hub between games. Both prioritize atmosphere and speed — large touch targets, minimal friction, immediate sense of the Firelit Gothic world.

---

## Layout

### S01: Welcome / Auth

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseLobby]   │
│  [background illustration:          │
│   misty village silhouette at 12%]  │
│  [AppParticles.dust]                │
│  [noise grain overlay]              │
│                                     │
│                                     │
│         MIDNIGHT                    │  <- AppTextStyles.displayXl
│         VILLAGE                     │     (40dp, Epilogue bold)
│                                     │     AppColors.parchment
│                                     │
│     "Night falls. Secrets stir."    │  <- AppTextStyles.flavor
│                                     │     (16dp, Libre Baskerville
│                                     │      italic)
│                                     │     AppColors.parchmentMuted
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Your name                  │    │  <- Name input field
│  │  ░░░░░░░░░░░░░░░░░░░░░░░░ │    │     AppColors.surfaceInset bg
│  └─────────────────────────────┘    │     AppRadius.md (8dp)
│                                     │     AppColors.outlineStrong
│                                     │     border on focus
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Enter the Village          │    │  <- Primary CTA
│  └─────────────────────────────┘    │     AppColors.bloodEmber bg
│                                     │     AppColors.parchment text
│                                     │     AppGlows.cta pulse (UI-17)
│                                     │     AppRadius.md (8dp)
│                                     │     Min height: 56dp
│                                     │
└─────────────────────────────────────┘
```

**Tablet:** Content centered within `AppDimensions.maxContentWidth` (480dp). Title and illustration have `AppSpacing.xxxxxxl` (80dp) top margin. More breathing room overall.

**Landscape:** Title and tagline shift to left half. Name input and CTA on right half.

---

### S02: Home

```
┌─────────────────────────────────────┐
│  [phase bg: AppColors.phaseLobby]   │
│  [background illustration:          │
│   tavern interior at 10%]           │
│  [AppParticles.dust]                │
│                                     │
│  Welcome back, Alice                │  <- AppTextStyles.heading1
│                                     │     AppColors.parchment
│                                     │
│  12 villagers online                │  <- AppTextStyles.bodySmall
│                                     │     AppColors.parchmentMuted
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │  [tavern door icon]         │    │  <- Create Game card
│  │  Create Game                │    │     AppColors.surface
│  │  Start a new game session   │    │     AppRadius.lg (12dp)
│  │                             │    │     AppShadows.card
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │                             │    │
│  │  [key icon]                 │    │  <- Join Game card
│  │  Join Game                  │    │     Same treatment
│  │                             │    │
│  │  ┌───────────────────────┐  │    │
│  │  │ Enter lobby code      │  │    │  <- Code input field
│  │  │ ░░░░░░░░░░░░░░░░░░░░ │  │    │     AppColors.surfaceInset
│  │  └───────────────────────┘  │    │     6-char max, uppercase
│  │                             │    │
│  │  ┌───────────────────────┐  │    │
│  │  │  Join                 │  │    │  <- Join button
│  │  └───────────────────────┘  │    │     AppColors.bloodEmber bg
│  │                             │    │     Disabled until 6 chars
│  └─────────────────────────────┘    │
│                                     │
│  ┌─────────────────────────────┐    │
│  │  Recent Games               │    │  <- Game history
│  │                             │    │     AppTextStyles.heading3
│  │  Today  Seer  Village  Won  │    │
│  │  Yesterday Werewolf WW Lost │    │  <- History rows
│  │  Apr 1  Robber Village Won  │    │     AppTextStyles.bodySmall
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

**Tablet:** Content centered within `AppDimensions.maxContentWidth` (480dp). Create and Join cards can sit side-by-side on wide screens.

**Landscape:** Create/Join cards in left column. Game history in right column.

---

## Preconditions

### S01: Welcome

- App is launched for the first time, OR player has no stored name
- No active game session exists

### S02: Home

- Player has entered a name (stored locally)
- No active game session exists
- Phase background is `AppColors.phaseLobby`
- `AppParticles.dust` is active
- `Ambience.lobby` is playing (or fades in on arrival)

---

## States

### S01: Welcome / Auth

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| WELCOME-IDLE | App launched, no stored name | Title "MIDNIGHT VILLAGE", tagline, name input (empty, focused), "Enter the Village" CTA (disabled). Background illustration: misty village. Dust particles. | `Ambience.lobby` begins playing |
| WELCOME-TYPING | Player begins typing name | Input field shows typed characters. CTA remains disabled until ≥2 characters. Keyboard visible. | None |
| WELCOME-VALID | Name field has ≥2 characters | CTA enables: `AppColors.bloodEmber` bg, `AppGlows.cta` pulse (UI-17). | None |
| WELCOME-SUBMIT | Player taps CTA or presses keyboard enter | Name saved to local storage. Navigate to Home (S02). | `AppHaptics.tapMedium` (H-02) |
| WELCOME-RETURN | App launched, name exists in storage | Skip S01 entirely. Navigate directly to S02. | None |
| WELCOME-LOADING | App initializing | Shimmer on input field and CTA (P-LOADING). Title visible. | None |

### S02: Home

| State ID | Trigger | What the user sees | Audio/Haptic |
|----------|---------|-------------------|--------------|
| HOME-IDLE | Player arrives at home | Greeting "Welcome back, {name}." Online count. Create Game card. Join Game card (code input empty). Game history (if any). | `Ambience.lobby` playing |
| HOME-CREATE | Player taps Create Game | Server creates lobby. Navigate to Lobby (S03) as host. | `AppHaptics.tapMedium` (H-02) |
| HOME-JOIN-TYPING | Player types in code input | Characters appear uppercase, max 6. Join button disabled until 6 characters entered. | None |
| HOME-JOIN-VALID | Code field has 6 characters | Join button enables: `AppColors.bloodEmber` bg. | None |
| HOME-JOIN-SUBMIT | Player taps Join or keyboard enter | Server validates code. If valid: navigate to Lobby (S03) as player. If invalid: P-ERR inline banner on Join card. | `AppHaptics.tapMedium` (H-02) |
| HOME-JOIN-ERROR | Server rejects code | Inline banner on Join card: "The tavern door is barred..." / "No lobby found with code {code}." Input field retains value. Player corrects and retries. | None |
| HOME-JOIN-FULL | Server: lobby full | Inline banner: "The village is full..." / "This lobby has reached its maximum of {N} players." | None |
| HOME-JOIN-STARTED | Server: game in progress | Inline banner: "The night has already fallen..." / "This game is in progress. You cannot join mid-game." | None |
| HOME-HISTORY-EMPTY | No past games | History section: empty state. "No tales yet told..." / "Play your first game to see your history here." (P-EMPTY). | None |
| HOME-HISTORY-LOADED | Past games exist | History list showing recent games, newest first. | None |
| HOME-ONLINE-COUNT | Server provides count | "{count} villagers online" below greeting. Updates in real time via WebSocket. | None |
| HOME-LOADING | Data loading | Shimmer on online count and history (P-LOADING). Cards visible. | None |
| HOME-CREATE-ERROR | Server fails to create lobby | Toast: "Something stirs in the darkness..." / "Failed to create game. Try again." | None |
| HOME-DISCONNECT | Connection lost | Local reconnection indicator (P-RECONNECTING). Online count shows "—". Join is disabled. Create shows loading state. | None |

---

## Transitions

| From State | Condition | To (screen/state) | Animation |
|------------|-----------|-------------------|-----------|
| S01 WELCOME-SUBMIT | Name saved | S02 HOME-IDLE | Screen crossfade (400ms, `AppCurves.standard`). Background illustration crossfades from village exterior to tavern interior. |
| S02 HOME-CREATE | Server confirms lobby | S03 Lobby (lobby.md) | Screen slide right (300ms, `AppCurves.enter`) |
| S02 HOME-JOIN-SUBMIT | Server confirms join | S03 Lobby (lobby.md) | Screen slide right (300ms, `AppCurves.enter`) |
| S03 Lobby (host leaves or kicked) | Return to home | S02 HOME-IDLE | Screen slide left (300ms, `AppCurves.exit`) |
| S15 Results (leave game) | Player exits session | S02 HOME-IDLE | Screen crossfade (400ms, `AppCurves.standard`) |
| App cold start (name exists) | App launched | S02 HOME-IDLE | Splash -> Home crossfade (400ms) |
| App cold start (no name) | App launched | S01 WELCOME-IDLE | Splash -> Welcome crossfade (400ms) |

---

## Interactions

### S01: Welcome

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Name input field | Tap | Keyboard opens. Field gains focus ring (`AppColors.outlineStrong`, 2dp). | None | None |
| Name input field | Type | Characters appear. CTA enables at ≥2 characters. | None | None |
| Name input field | Clear (x button) | Input cleared. CTA disables. | None | None |
| "Enter the Village" (enabled) | Tap | Name saved. Navigate to Home. | `AppHaptics.tapMedium` (H-02) | None |
| "Enter the Village" (disabled) | Tap | No action. Button at `AppOpacity.disabled` (0.38). | None | None |
| Keyboard "Done" / Enter | Press | Same as tapping CTA (if name ≥2 chars). | `AppHaptics.tapMedium` (H-02) | None |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Name submit | Name empty | CTA disabled. Cannot submit. |
| Name submit | Name too long (>30 chars) | Input field enforces 30-char max. Characters beyond 30 are not accepted. |
| Name submit | Local storage failure | Retry silently. If persistent, toast: P-ERR. |

### S02: Home

| Element | Event | Result | Haptic | Sound |
|---------|-------|--------|--------|-------|
| Create Game card | Tap | Server creates lobby. Loading indicator on card. Navigate to S03 on success. | `AppHaptics.tapMedium` (H-02) | None |
| Join Game code input | Tap | Keyboard opens. Input gains focus ring. | None | None |
| Join Game code input | Type | Characters uppercased automatically. Max 6. Join button enables at 6. | None | None |
| Join Game code input | Paste | Pasted text uppercased, truncated to 6 chars. | None | None |
| Join button (enabled) | Tap | Server validates code. Loading indicator on button. Navigate to S03 on success. On error: inline banner within Join card. | `AppHaptics.tapMedium` (H-02) | None |
| Join button (disabled) | Tap | No action. Button at `AppOpacity.disabled`. | None | None |
| Keyboard "Done" / Enter | Press | Same as tapping Join (if code is 6 chars). | `AppHaptics.tapMedium` (H-02) | None |
| Join error banner | (auto-dismiss) | Dismisses when player modifies code input. | None | None |
| Game history row | Tap | No action (v1). Display only. Future: navigate to game detail. | None | None |
| Online count | — | Not interactive. Display only. | — | — |

**Failure paths:**

| Interaction | Failure | Result |
|-------------|---------|--------|
| Create Game | Server timeout | Toast: P-ERR network timeout. Card returns to idle. |
| Create Game | Server error | Toast: "Something stirs in the darkness..." / "Failed to create game. Try again." |
| Join Game | Invalid code | Inline banner on Join card (see HOME-JOIN-ERROR). Input retains value. |
| Join Game | Lobby full | Inline banner (see HOME-JOIN-FULL). |
| Join Game | Game started | Inline banner (see HOME-JOIN-STARTED). |
| Join Game | Network timeout | Toast: P-ERR. Join button re-enables. |

---

## Name Input

| Property | Value |
|----------|-------|
| Max length | 30 characters |
| Min length | 2 characters (for CTA to enable) |
| Validation | No special character restrictions. Emoji allowed. Whitespace-only rejected (trimmed). |
| Persistence | Stored in local device storage. Persists across app restarts. |
| Change | No in-app "change name" flow in v1. Player clears local storage to reset (or future settings screen). |
| Display | Name used throughout the game: lobby, player grids, results, narrator cues (dynamic content). |

### Local Device Storage Summary

The following data persists in local device storage across app restarts:

| Data | Persistence | Notes |
|------|-------------|-------|
| Player name | Until cleared | Set on S01, used throughout |
| Game history | Last 20 entries, pruned | Date, role, team, outcome per game |
| Timer configuration | Until overwritten | Selected preset + per-phase timer values from S04b. Loaded when host opens Game Settings. Overwritten each time host changes a preset or slider. |

### Input Field Visual Treatment

| State | Border | Background | Text Color |
|-------|--------|------------|------------|
| Default (unfocused) | 1dp `AppColors.outline` | `AppColors.surfaceInset` | `AppColors.parchment` |
| Focused | 2dp `AppColors.outlineStrong` | `AppColors.surfaceInset` | `AppColors.parchment` |
| Placeholder | 1dp `AppColors.outline` | `AppColors.surfaceInset` | `AppColors.parchmentMuted` |
| Error | 2dp `AppColors.bloodEmber` | `AppColors.surfaceInset` | `AppColors.parchment` |

Input padding: `AppSpacing.md` (12dp) horizontal, `AppSpacing.sm` (8dp) vertical.
Input typography: `AppTextStyles.body` (DM Sans, 14dp).
Placeholder text: "Your name" (S01), "Enter lobby code" (S02).
Corner radius: `AppRadius.md` (8dp).

---

## Lobby Code Input (S02)

| Property | Value |
|----------|-------|
| Max length | 6 characters |
| Character set | Alphanumeric, auto-uppercased on input |
| Typography | `AppTextStyles.labelLarge` (Space Grotesk, 14dp, medium, letter-spacing 0.5dp) |
| Placeholder | "Enter lobby code" in `AppColors.parchmentMuted` |
| Keyboard type | Text input with autocapitalize enabled. No numeric-only (codes contain letters). |
| Paste support | Pasted content trimmed and uppercased. First 6 valid alphanumeric chars extracted. |

---

## Online Player Count

| Property | Value |
|----------|-------|
| Source | Server WebSocket, global count of connected players |
| Display | "{count} villagers online" |
| Typography | `AppTextStyles.bodySmall`, `AppColors.parchmentMuted` |
| Update frequency | Real-time via WebSocket. Debounce visual updates to every 5s max to prevent flicker. |
| Fallback | If WebSocket disconnected: show "—" instead of count. Reconnect indicator (P-RECONNECTING) if applicable. |
| Position | Below greeting, before game cards |

---

## Game History

### Layout

```
┌─────────────────────────────────────┐
│  Recent Games                       │  <- AppTextStyles.heading3
│                                     │
│  ┌─────────────────────────────┐    │
│  │ Today    [Seer icon] Seer   │    │  <- History row
│  │          Village    Won     │    │     AppColors.surface
│  └─────────────────────────────┘    │     AppRadius.lg (12dp)
│  ┌─────────────────────────────┐    │
│  │ Yesterday [WW icon] Werewolf│    │
│  │          Werewolf   Lost    │    │
│  └─────────────────────────────┘    │
│  ┌─────────────────────────────┐    │
│  │ Apr 1    [Robber] Robber    │    │
│  │          Village    Won     │    │
│  └─────────────────────────────┘    │
│                                     │
└─────────────────────────────────────┘
```

### Row Content

| Column | Content | Style |
|--------|---------|-------|
| Date | Relative: "Today", "Yesterday", or date (e.g., "Apr 1") | `AppTextStyles.bodySmall`, `AppColors.parchmentMuted` |
| Role icon | Small role icon at `AppDimensions.iconSm` (16dp), team accent color | Per art-direction.md |
| Role name | Player's original role | `AppTextStyles.body`, `AppColors.parchment` |
| Team | Team name | `AppTextStyles.label`, team accent color |
| Outcome | "Won" or "Lost" | `AppTextStyles.label`. Won: `AppColors.moonlitSage`. Lost: `AppColors.bloodEmber`. |

### History Data

| Property | Value |
|----------|-------|
| Source | Local device storage. Not synced across devices. |
| Max entries | 20 most recent games. Older entries pruned. |
| Stored per entry | Date, original role name, team name, win/loss boolean |
| Empty state | "No tales yet told..." / "Play your first game to see your history here." (P-EMPTY) with closed-book icon. |
| Interaction | Not interactive in v1. Display only. Future: tap to view game detail. |

---

## Background Illustrations

Per `art-direction.md`:

| Screen | Base Color | Illustration | Opacity | Mood |
|--------|-----------|-------------|---------|------|
| S01 Welcome | `AppColors.phaseLobby` | Misty village silhouette — clustered buildings, church steeple, bare trees against moonlit sky | 12% | Approaching the village at night. Mystery. Invitation. |
| S02 Home | `AppColors.phaseLobby` | Tavern interior suggestion — timber beams, hanging lantern shapes, fireplace glow | 10% | Inside the tavern. Warm, social, anticipation. |

Illustrations render as SVG, bottom-anchored, bleeding off bottom and sides. Layer order: phase background → illustration → noise grain → particles → content.

---

## Narrator Cues

No narrator cues fire on pre-game screens. The first narrator cue is NC-OPEN during T-01 (Lobby -> Night).

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery |
|-------|-------------------|----------------|----------|
| Lobby not found | "The tavern door is barred..." | No lobby found with code {code}. | Inline banner on Join card. Player re-enters code. |
| Lobby full | "The village is full..." | This lobby has reached its maximum of {N} players. | Inline banner on Join card. Player waits or finds another. |
| Game in progress | "The night has already fallen..." | This game is in progress. You cannot join mid-game. | Inline banner. Player returns to other action. |
| Create failed | "Something stirs in the darkness..." | Failed to create game. Try again. | Toast (P-ERR). Player retries. |
| Network timeout | "The fog grows thick..." | Request timed out. Check your connection and try again. | Toast. Player retries. |
| Local storage failure | (silent) | (retry) | Name save retried silently. If persistent, app continues without persistence (name lost on restart). |

---

## Animation

| Moment | Reference | Duration | Easing | What moves |
|--------|-----------|----------|--------|------------|
| Welcome -> Home transition | — | 400ms | `AppCurves.standard` | Full-screen crossfade. Background illustration crossfades (village exterior -> tavern interior). |
| Home -> Lobby transition | — | 300ms | `AppCurves.enter` | Screen slides right |
| CTA glow pulse (Welcome) | UI-17 | 3000ms loop | Sinusoidal | `AppGlows.cta` on "Enter the Village" |
| CTA glow pulse (Join, when valid) | UI-17 | 3000ms loop | Sinusoidal | `AppGlows.cta` on Join button |
| Create Game card press | UI-02/03 | 100ms/200ms | `AppCurves.standard` | Darken 15% on press, restore on release |
| Join error banner appear | — | 400ms | `AppCurves.enter` | Banner fades in within Join card, pushes content down |
| Join error banner dismiss | — | 400ms | `AppCurves.exit` | Banner fades out, content collapses |
| History row appear (stagger) | UI-13 | 300ms + 50ms/row | `AppCurves.enter` | Rows stagger in on initial load |
| Online count update | — | 200ms | `AppCurves.standard` | Number crossfades to new value |
| Input focus ring | — | 200ms | `AppCurves.standard` | Border transitions from `AppColors.outline` to `AppColors.outlineStrong` |

**Reduced motion:**

| Element | Alternative |
|---------|------------|
| Screen transitions | Instant swap (no slide or crossfade) |
| CTA glow pulse | Static glow at mid-opacity (0.20) |
| History stagger | All rows appear simultaneously |
| Card press | Instant darken/restore |

---

## Strings

### S01: Welcome

| Key | Default Text | Notes |
|-----|-------------|-------|
| `welcome.title` | MIDNIGHT VILLAGE | App title |
| `welcome.tagline` | Night falls. Secrets stir. | Flavor tagline |
| `welcome.name_placeholder` | Your name | Input placeholder |
| `welcome.cta` | Enter the Village | Primary CTA |
| `welcome.name_required` | Enter a name to continue | Shown if CTA tapped with empty input (edge case with keyboard submit) |

### S02: Home

| Key | Default Text | Notes |
|-----|-------------|-------|
| `home.greeting` | Welcome back, {name} | Personalized greeting |
| `home.online_count` | {count} villagers online | Global player count |
| `home.online_unavailable` | — | When WebSocket disconnected |
| `home.create_title` | Create Game | Card title |
| `home.create_subtitle` | Start a new game session | Card subtitle |
| `home.join_title` | Join Game | Card title |
| `home.join_code_placeholder` | Enter lobby code | Input placeholder |
| `home.join_button` | Join | Join button |
| `home.history_title` | Recent Games | Section header |
| `home.history_empty_headline` | "No tales yet told..." | Empty state (P-EMPTY) |
| `home.history_empty_subtitle` | Play your first game to see your history here. | Empty state |
| `home.history_won` | Won | Outcome label |
| `home.history_lost` | Lost | Outcome label |
| `home.history_today` | Today | Relative date |
| `home.history_yesterday` | Yesterday | Relative date |

---

## Information Architecture

### S01: Welcome

| Information | Source | Display |
|-------------|--------|---------|
| Player name (input) | Player typing | Name input field. No server involvement. Local only. |

No game data exists at this point. The Welcome screen is a pure entry point.

### S02: Home

| Information | Source | Visible | Display |
|-------------|--------|---------|---------|
| Player name | Local storage | Always | Greeting |
| Online player count | Server WebSocket (global) | Always (when connected) | Below greeting |
| Game history | Local storage | If games exist | History list |
| Lobby code (for joining) | Player input | During join flow | Join card input |

No Tier 2 or Tier 3 information exists on pre-game screens. There is no active game session.

---

## Accessibility

### S01: Welcome

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: page | `Semantics(label: "Midnight Village. Enter your name to begin.")` on page load. |
| Screen reader: input | `Semantics(label: "Your name. Text field. Required.")`. On focus: keyboard opens. |
| Screen reader: CTA (enabled) | `Semantics(label: "Enter the Village. Double-tap to continue.")` |
| Screen reader: CTA (disabled) | `Semantics(label: "Enter the Village. Disabled. Enter a name first.")` |
| Touch targets | CTA: full width, 56dp height. Input: full width, 48dp height. Both exceed minimums. |
| Keyboard navigation | Tab order: input → CTA. Enter key submits if name is valid. |
| Auto-focus | Input field receives focus on page load (keyboard opens automatically on mobile). |
| Reduced motion | Background illustration static. Dust particles replaced with static dots. CTA glow static. |
| Color-blind | No color-dependent information on this screen. CTA enabled/disabled distinguished by opacity (0.38 vs 1.0) + glow presence. |

### S02: Home

| Requirement | Implementation |
|-------------|---------------|
| Screen reader: page | `Semantics(label: "Home. Welcome back, {name}. {count} villagers online.")` |
| Screen reader: Create Game | `Semantics(label: "Create Game. Start a new game session. Double-tap to create.")` |
| Screen reader: Join Game section | `Semantics(label: "Join Game. Enter a 6-character lobby code.")` |
| Screen reader: code input | `Semantics(label: "Lobby code. Text field. {current length} of 6 characters entered.")` |
| Screen reader: Join button (enabled) | `Semantics(label: "Join lobby {code}. Double-tap to join.")` |
| Screen reader: Join button (disabled) | `Semantics(label: "Join. Disabled. Enter a complete lobby code.")` |
| Screen reader: join error | Error banner announced via `liveRegion: assertive`. "[Error subtitle text]." |
| Screen reader: history | Section: "Recent Games. {count} games." Each row: "[Date]. Played as [Role]. [Team]. [Won/Lost]." |
| Screen reader: empty history | "No tales yet told. Play your first game to see your history here." |
| Screen reader: online count | `Semantics(liveRegion: polite)`. Updated when count changes (debounced to 5s). |
| Touch targets | Cards: full width, minimum 64dp height. Join button: full width, 48dp. Code input: full width, 48dp. |
| Keyboard navigation | Tab order: Create Game → code input → Join button → history rows (non-interactive in v1). |
| Color-blind: history outcome | "Won" / "Lost" text labels. Green/red is reinforcement. |
| Dynamic text sizing | Greeting wraps at 200%. Cards expand vertically. History rows expand vertically. |

---

## Open Questions

(none)
