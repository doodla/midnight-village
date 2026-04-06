# User Journeys

## Identity

| Field     | Value |
|-----------|-------|
| type      | journey |
| id        | J-all |
| phase     | all |

This document maps the complete experience of playing Midnight Village from two perspectives: the **Host** (creates and shepherds the game) and the **Player** (joins and plays). Each journey covers the full arc from app launch to post-game, including edge cases for first-time use, veteran shortcuts, disconnect/reconnect, and remote play divergences.

All journeys reference design tokens from `design-tokens.md`, motion sequences from `sound-and-motion.md`, and visual direction from `art-direction.md`. No raw values.

---

## Preconditions

- App is installed and launched
- Device has an active network connection
- No game is currently in progress (if resuming mid-game, see Reconnection Journey)

---

## Journey 1: Host Journey (J-host)

The host is the stage manager. They create the game, configure the experience, shepherd players through phases, and initiate rematches. The host has exclusive controls at every phase, but those controls are contextual -- they appear only when relevant and disappear when not.

### States

| State ID | Phase | What the Host Experiences | Emotional Beat | Audio/Haptic |
|----------|-------|--------------------------|----------------|-------------|
| J-host-01 | Welcome | Sees misty village illustration on `AppColors.phaseLobby` background. Name input field with `AppTextStyles.bodyLarge` placeholder "Your name". Single CTA: "Enter the Village" in `AppColors.bloodEmber` with `AppGlows.cta` pulse. Spends <10s here. | Invitation, anticipation | `Ambience.lobby` fades in on screen load |
| J-host-02 | Home | Greeting with player name in `AppTextStyles.heading1`. Two cards on `AppColors.surface`: "Create Game" and "Join Game". Online player count displayed in `AppTextStyles.label` with `AppColors.parchmentMuted`. | Choosing your table | -- |
| J-host-03 | Lobby (empty) | Lobby created. Hero lobby code in `AppTextStyles.codeDisplay` on `AppColors.surface`, tap-to-copy. Player list shows only the host (with `AppColors.tallowGold` 2dp host border ring on avatar). "Configure Roles" and "Start Game" (disabled) visible. | Preparing the table | `AppHaptics.tapLight` on lobby creation |
| J-host-04 | Lobby (configuring) | Role picker bottom sheet. Roles listed with count steppers (+/-). Current card count shown as `AppTextStyles.label`: "Cards: 8/8" (player_count + 3). Validation banners in `AppColors.bloodEmber` background tint for invalid configs (e.g., odd Mason count, wrong card total). | Building the experience | `AppHaptics.selectionClick` on each stepper tap |
| J-host-05 | Lobby (gathering) | Players arrive -- each triggers a player card entry animation (UI-13, 50ms stagger). Ready states shown per player (`AppColors.moonlitSage` text for ready, `AppColors.parchmentMuted` text for not ready). "Start Game" CTA enables when player_count >= 3 AND all players ready AND card count == player_count + 3. | Anticipation builds with each arrival | `AppHaptics.tapLight` per player join |
| J-host-06 | Night (role reveal) | Same as any player: receives face-down card, taps to reveal (M-01). The host is a player during the game. No host controls during role reveal. | Personal secret moment | M-01 full sequence |
| J-host-07 | Night (action/waiting) | If host's role has a night action: action UI per role type. If no action: night waiting screen with fidgets, trivia, wave progress dots. No host controls during night. | Mystery, mischief, or cozy waiting | Per role action + fidget haptics/sounds |
| J-host-08 | Discussion | Big countdown timer in `AppTextStyles.timerDisplay` with color ramp. Role reminder (tap-to-reveal, UI-21/22). Roles-in-play collapsible list. **Host exclusive:** "End Discussion" button on `AppColors.surface` card, styled with `AppColors.bloodEmber` text, appears only for host. | Social energy + shepherd control | `AppHaptics.tapMedium` on "End Discussion" |
| J-host-09 | Voting | Player grid for vote selection. Fluid selection -- tap to select, tap another to change. Timer with pressure indicators (UI-26, UI-27). Vote counter in `AppTextStyles.label`. **Host exclusive:** "End Voting" button, same styling as "End Discussion". Current selection hidden by default (tap-to-reveal). | Tension, commitment, control | `AppHaptics.selectionClick` on each vote change |
| J-host-10 | Vote reveal | Vote tally build (M-03). Host watches alongside everyone. No host controls. | Dramatic tension | M-03 full sequence |
| J-host-11 | Elimination | Elimination announcement (M-04) or no elimination (M-05). Host watches. No host controls. | Theatrical climax | M-04 or M-05 full sequence |
| J-host-12 | Results | Team headline + personal outcome (M-06). Player table with original -> final roles. Full autopsy expandable. **Host exclusive:** "Play Again" CTA in `AppColors.bloodEmber` with `AppGlows.cta`. "End Game" secondary action on `AppColors.surface` background. | Satisfaction, storytelling, rematch energy | M-06 full sequence |
| J-host-13 | Play again | Lobby returns (T-07) with same player group. Role configuration preserved from last game but editable. Players shown as "not ready". Host can reconfigure and start again. | Quick rematch energy | T-07 transition |

### Transitions

| From State | Condition | To State | Animation/Transition |
|------------|-----------|----------|---------------------|
| J-host-01 | Taps "Enter the Village" with valid name | J-host-02 | `AppDurations.standard` (300ms) crossfade, `AppCurves.enter` |
| J-host-02 | Taps "Create Game" | J-host-03 | `AppDurations.standard` (300ms), lobby code animates in with `AppCurves.enter` |
| J-host-03 | Taps "Configure Roles" | J-host-04 | Bottom sheet slide up (UI-08) |
| J-host-04 | Closes role picker (swipe down or tap scrim) | J-host-05 | Bottom sheet dismiss (UI-09) |
| J-host-05 | Taps "Start Game" (enabled) | J-host-06 | T-01 game start cinematic (2500ms) |
| J-host-06 | Role reveal complete (card flipped + settle) | J-host-07 | `AppDurations.crossfade` (400ms) into night action or waiting (UI-01) |
| J-host-07 | All night waves complete | J-host-08 | T-02 Night -> Discussion (2500ms) |
| J-host-08 | Timer expires OR host taps "End Discussion" | J-host-09 | T-03 Discussion -> Voting (2000ms) |
| J-host-09 | Timer expires OR host taps "End Voting" | J-host-10 | T-04 Voting -> Vote Reveal (1200ms) |
| J-host-10 | Vote tally complete (M-03) | J-host-11 | T-05 Vote Reveal -> Elimination (1500ms) |
| J-host-11 | Elimination sequence complete | J-host-12 | T-06 Elimination -> Results (1500ms) |
| J-host-12 | Taps "Play Again" | J-host-13 | T-07 Results -> Lobby (1000ms) |
| J-host-12 | Taps "End Game" | J-host-02 | `AppDurations.standard` crossfade to Home |

### Host-Exclusive Controls Summary

| Phase | Control | Appearance | Behavior |
|-------|---------|------------|----------|
| Lobby | "Configure Roles" | `AppColors.surface` card, `AppTextStyles.labelLarge` | Opens role picker bottom sheet |
| Lobby | "Start Game" | `AppColors.bloodEmber` CTA with `AppGlows.cta` pulse when enabled; disabled state at `AppOpacity.disabled` | Sends game start to server; triggers T-01 |
| Discussion | "End Discussion" | `AppColors.surface` card with `AppColors.bloodEmber` text, `AppTextStyles.labelLarge` | Sends early-end to server; triggers T-03 |
| Voting | "End Voting" | Same styling as "End Discussion" | Finalizes all current selections; triggers T-04 |
| Results | "Play Again" | `AppColors.bloodEmber` CTA with `AppGlows.cta` | Returns group to lobby with same players; triggers T-07 |
| Results | "End Game" | `AppColors.surface` background, `AppColors.parchment` text, `AppTextStyles.labelLarge` | Returns host to Home; players see "Host ended the game" |

---

## Journey 2: Player Journey (J-player)

The player joins an existing game and plays through it. Their experience differs from the host in two ways: (1) no phase-advancing controls, and (2) the join flow replaces the create flow. Once in-game, the player's experience varies dramatically based on role complexity.

### States

| State ID | Phase | What the Player Experiences | Emotional Beat | Audio/Haptic |
|----------|-------|----------------------------|----------------|-------------|
| J-player-01 | Welcome | Same as J-host-01. Identical screen. | Invitation | `Ambience.lobby` on load |
| J-player-02 | Home | Same as J-host-02. "Create Game" and "Join Game" cards. | Choosing | -- |
| J-player-03 | Join | Hero lobby code input: 6-character field in `AppTextStyles.codeDisplay` on `AppColors.surfaceInset`, uppercase. Large touch targets. "Join" CTA in `AppColors.bloodEmber`. | Entering the gathering | `AppHaptics.tapLight` per character input |
| J-player-04 | Lobby (waiting) | Player list visible. Own avatar appears with ready toggle. Lobby code visible (for sharing with others). Roles-in-play preview if host has configured. No "Start Game" button -- that's host-only. Ready/unready toggle (UI-14 bounce). | Anticipation, social warmth | `AppHaptics.selectionClick` on ready toggle |
| J-player-05 | Night (role reveal) | Face-down card arrives (M-01 Phase 1). "Tap to reveal your role" prompt in `AppTextStyles.body`, `AppColors.parchmentMuted`. Player taps: card flip (M-01 Phase 2), settle (M-01 Phase 3). Sees: role art, role name, team badge, brief description. | Delight, secrecy | M-01 full sequence |
| J-player-06a | Night (no-action role) | Villager, Hunter, or Tanner. Night waiting screen: wave progress dots (`AppColors.tallowGold` active pulse UI-24), engagement layer (medieval facts in `AppTextStyles.flavor`, trivia questions, fidget interactions F-01/F-02/F-03). Phone must be in hand and active to conceal who has a real action. | Cozy waiting, concealment | Fidget sounds/haptics, `Ambience.night` |
| J-player-06b | Night (simple action) | Robber or Drunk. Action prompt: role info strip at top (`AppTextStyles.heading3` role name, `AppTextStyles.bodySmall` action instruction). Player grid or center card slots in center. Timer at bottom in `AppTextStyles.timerCompact`. Player selects target, server confirms, result shown (card peek via M-02 for Robber; no reveal for Drunk). Falls through to waiting for remaining waves. | Deliberate, secret ritual | `AppHaptics.selectionClick` on target select, M-02 on peek result |
| J-player-06c | Night (choice action) | Seer. Choice UI: two option cards on `AppColors.surface` -- "Peek one player's card" and "Peek two center cards". Player taps choice, then selects target(s). Peek result via M-02. Optional: player may let timer expire to skip (action is optional). | Powerful decision | `AppHaptics.selectionClick` on choice, M-02 on result |
| J-player-06d | Night (multi-step action) | Doppelganger. Step 1: peek one player's card (M-02). Server reveals copied role. Step 2: if copied role has immediate action (Seer/Robber/Troublemaker/Drunk), action UI appears for the follow-up. If copied role is Wave 2 (Werewolf/Mason/Minion), player closes eyes and re-wakes in Wave 2. If copied role has no action, done. Step indicator: "Step 1 of 2" in `AppTextStyles.label`. | Complex ritual, discovery | M-02 for peek, then per-role action sequence |
| J-player-06e | Night (auto-resolve info) | Werewolf (see teammates), Mason (see partner), Minion (see Werewolves), Insomniac (see own card). Information display appears automatically -- no player selection needed. Teammate avatars highlighted with `AppGlows.selection`. Lone Werewolf: option to peek one center card (optional). Lone Mason: "No other Masons" message. | Recognition, alliance or isolation | `AppHaptics.tapMedium` on info reveal |
| J-player-07 | Discussion | Big countdown timer. Role reminder hidden behind tap-to-reveal (UI-21/22). Roles-in-play collapsible. No "End Discussion" button (host-only). Phone is a mood lamp and cheat sheet -- the real action is face-to-face. | Social energy, suspicion | Timer color ramp, `Ambience.discussion` |
| J-player-08 | Voting | Player grid. Fluid selection: tap player to select as vote target, tap another to change. Current selection hidden behind tap-to-reveal (in-person guardrail). Checkmarks show who has made a selection (blind -- no one sees anyone else's target). Timer with pressure effects. Vote counter: "4/6 have chosen." | Tension, commitment | `AppHaptics.selectionClick` per selection change |
| J-player-09 | Vote reveal | Vote tally build (M-03). Watch the bars fill. | Dramatic build | M-03 |
| J-player-10 | Elimination | M-04 (elimination) or M-05 (no elimination). See who died and what role they held. Hunter chain if applicable. | Theatrical beat | M-04 or M-05 |
| J-player-11 | Results | Team headline + personal outcome (M-06). Player table. Full autopsy on demand. Non-host players see "Stay for Rematch" CTA (`AppColors.bloodEmber`) and "Leave Game" secondary action (`AppColors.surface`). Tapping "Stay for Rematch" signals intent to the host; tapping "Leave Game" exits to Home. When host starts rematch, staying players return to lobby. | Satisfaction, storytelling, "I knew it!" | M-06 |

### Transitions

| From State | Condition | To State | Animation/Transition |
|------------|-----------|----------|---------------------|
| J-player-01 | Taps "Enter the Village" with valid name | J-player-02 | `AppDurations.standard` crossfade |
| J-player-02 | Taps "Join Game" | J-player-03 | `AppDurations.standard` crossfade |
| J-player-03 | Enters valid code, taps "Join" | J-player-04 | `AppDurations.standard` crossfade, player card entry (UI-13) |
| J-player-04 | Host starts game | J-player-05 | T-01 game start cinematic (2500ms) |
| J-player-05 | Role reveal complete | J-player-06a/b/c/d/e | `AppDurations.crossfade` (400ms) to role-appropriate night state (UI-01) |
| J-player-06* | All night waves complete | J-player-07 | T-02 Night -> Discussion (2500ms) |
| J-player-07 | Timer expires or host ends discussion | J-player-08 | T-03 Discussion -> Voting (2000ms) |
| J-player-08 | Timer expires or host ends voting | J-player-09 | T-04 Voting -> Vote Reveal (1200ms) |
| J-player-09 | Tally complete | J-player-10 | T-05 Vote Reveal -> Elimination (1500ms) |
| J-player-10 | Elimination sequence complete | J-player-11 | T-06 Elimination -> Results (1500ms) |
| J-player-11 | Player taps "Stay for Rematch" | J-player-11 (waiting) | `AppHaptics.tapLight`, button state changes to "Staying" |
| J-player-11 | Player taps "Leave Game" | J-player-02 | `AppDurations.standard` crossfade to Home |
| J-player-11 | Host starts rematch (player is staying) | J-player-04 | T-07 Results -> Lobby (1000ms) |
| J-player-11 | Host selects "End Game" | J-player-02 | `AppDurations.standard` crossfade + in-world message |

### Role-Specific Night Experience Variants

The night action UI framework handles all roles through composition. This table maps each role to its night experience pattern.

| Role | Night State | Action Steps | Player Input Required | Information Received | Timer Pressure |
|------|------------|-------------|----------------------|---------------------|---------------|
| Villager | J-player-06a | 0 | None | None | None (waiting) |
| Hunter | J-player-06a | 0 | None | None | None (waiting) |
| Tanner | J-player-06a | 0 | None | None | None (waiting) |
| Robber | J-player-06b | 1: select player | Tap one player avatar | Sees stolen card (M-02 flip) | Wave timer |
| Drunk | J-player-06b | 1: select center card | Tap one center slot | None (blind swap) | Wave timer |
| Troublemaker | J-player-06b | 1: select two players | Tap two player avatars | None (blind swap) | Wave timer |
| Seer | J-player-06c | 2: choose mode, then select target(s) | Tap choice card, then tap target(s) | Sees peeked card(s) (M-02 flip) | Wave timer |
| Werewolf (multi) | J-player-06e | 0 | None (auto-resolve) | Sees teammate identity | None |
| Werewolf (lone) | J-player-06e | 0-1: optional center peek | Optional tap on center slot | Optionally sees one center card | Wave timer if peeking |
| Minion | J-player-06e | 0 | None (auto-resolve) | Sees Werewolf identities | None |
| Mason | J-player-06e | 0 | None (auto-resolve) | Sees other Mason (or "lone Mason" message) | None |
| Insomniac | J-player-06e | 0 | None (auto-resolve) | Sees own current card | None |
| Doppelganger | J-player-06d | 1-3: peek + conditional follow-up | Tap player to peek, then per-copied-role | Sees copied role + follow-up result | Extended wave timer |

---

## Journey 3: First-Time Player Experience (J-first-time)

First-time use is a **state**, not a separate persona. Contextual hints appear once per interaction type and persist in local storage so they never reappear after first use. No tutorial game, no heavy onboarding.

### Hint Triggers

| Moment | Hint Content | Style | Dismissal | Appears When |
|--------|-------------|-------|-----------|-------------|
| Welcome screen | None. The CTA "Enter the Village" is self-explanatory. | -- | -- | -- |
| First lobby join | "Share this code with friends to invite them" | Tooltip (UI-06) anchored below lobby code | Tap anywhere (UI-07) | First time seeing lobby code |
| First role reveal (card face-down) | "Tap the card to reveal your secret role" | `AppTextStyles.body` below card in `AppColors.parchmentMuted`, fades in with card (M-01 Phase 1) | Auto-dismissed on card tap | First role reveal ever |
| First role reveal (card face-up) | "Keep your role secret! Others can't see your screen." | Tooltip (UI-06) above role name, appears 800ms after card flip settle | Tap anywhere, auto-dismiss after 4000ms | First role reveal ever |
| First night action (Seer choice) | "Choose how to use your power" | Tooltip (UI-06) anchored to choice cards | Tap anywhere | First time seeing Seer choice UI |
| First night action (player selection) | "Tap a player to select them" | Tooltip (UI-06) anchored to player grid | Auto-dismiss on first selection | First time seeing night action player grid |
| First night action (center cards) | "Tap a card to peek" | Tooltip (UI-06) anchored to center card slots | Auto-dismiss on first selection | First time seeing center card selection |
| First discussion phase | "Discuss with the other players! Your role reminder is hidden below." | Tooltip (UI-06) anchored to tap-to-reveal area | Tap anywhere, auto-dismiss after 4000ms | First discussion phase ever |
| First voting phase | "Tap a player to cast your vote. You can change your mind until time runs out." | Tooltip (UI-06) anchored to player grid | Auto-dismiss on first selection | First voting phase ever |
| First voting (fluid model) | "Your current pick is your vote when the timer ends. No need to confirm." | Tooltip (UI-06) appears 3s after first selection | Tap anywhere, auto-dismiss after 4000ms | First vote selection ever |
| First results screen | "Tap the player table to see what happened during the night" | Tooltip (UI-06) anchored to collapsed player table | Tap anywhere | First results screen ever |

### First-Time Principles

1. **Never block.** Hints are tooltips, not modals. The player can always ignore them and proceed.
2. **One hint at a time.** If multiple hints would trigger simultaneously, show only the most contextually important one. Priority order matches the table above (top = highest priority).
3. **Disappear forever.** Each hint ID is stored in local storage after first display. It never shows again on that device.
4. **Don't explain the game.** Hints explain the *interface*, not the *strategy*. "Tap a player to select them" is interface. "The Seer should peek at suspected Werewolves" is strategy and should never appear.
5. **Role description on reveal card is sufficient.** The role reveal card (M-01) includes a brief description of what the role does. No additional role tutorial is needed.

---

## Journey 4: Veteran Shortcuts (J-veteran)

Veterans who have played multiple games benefit from streamlined flows. No special mode -- these are natural consequences of hints being dismissed and familiarity with the UI.

### Veteran Flow Differences

| Area | First-Timer Experience | Veteran Experience | Implementation |
|------|----------------------|-------------------|----------------|
| Welcome | Full name entry | Name pre-filled from last session (local storage) | Name persists in local storage; welcome screen auto-fills |
| Home | Considers both options | Goes directly to Create or Join | No change needed -- the two-card layout is already fast |
| Lobby code entry | Types code character by character | Taps "Join" from a shared link or pastes code | Deep link support: `midnightvillage.app/join/{code}` bypasses Home and Join screens, goes directly to lobby |
| Role reveal | Reads all hints, takes time to understand | Quick tap to reveal, glances at role, ready for night | Hints already hidden. Card flip is still 600ms -- the theatrical moment serves everyone. |
| Night actions | Reads hint, considers carefully | Selects target immediately, familiar with timing | No change. Timer is the same. Faster input means more waiting time in the wave. |
| Discussion | Reads role reminder, checks roles-in-play | Discusses immediately, may not look at phone at all | Phone recedes naturally for veterans |
| Voting | Reads fluid-model hint | Selects and changes fluidly, watches vote counter | No change. The fluid model is intuitive once learned. |
| Results | Explores player table with hint guidance | Jumps straight to autopsy, calls out interesting moments | No change. Progressive disclosure serves both. |
| Play Again | Follows host | May suggest role changes to host verbally | No in-app feature needed -- social negotiation |

### Quick Rejoin

After the app is closed and reopened, if a game is in progress:

| Scenario | Behavior |
|----------|----------|
| Player was in a lobby | Auto-rejoin lobby if it still exists. Show lobby screen with current player list. |
| Player was in an active game | Reconnection journey (J-disconnect, see below) |
| Game ended while app was closed | Show Home screen. No stale game state. |
| Player has played before, no active game | Show Home screen with pre-filled name |

---

## Journey 5: Disconnect & Reconnect (J-disconnect)

Disconnections are handled dramatically and game-pausingly, per the vision brief. The disconnect overlay (T-09) fires for all players when any player disconnects.

### Disconnect States

| State ID | Perspective | What Happens | Visual | Audio/Haptic |
|----------|-------------|-------------|--------|-------------|
| J-disc-01 | Disconnected player | Connection drops. App shows reconnection attempt screen: "The spirits are restless..." in `AppTextStyles.flavor` on `AppColors.surface` card with `AppColors.parchmentMuted` subtitle "Reconnecting..." and a loading shimmer (UI-12). | Scrim over current game screen at `AppOpacity.scrim`. Reconnect card centered. | `SoundCues.disconnect`, `AppHaptics.tapMedium` |
| J-disc-02 | Other players | "A villager has wandered into the fog..." in `AppTextStyles.flavor` on overlay card, with `AppColors.parchmentMuted` subtitle "[Player Name] disconnected". Disconnected player's avatar fades to 50% opacity with fog particle overlay. All interactive elements disabled. Timers pause. | T-09 disconnect overlay (600ms in) | `SoundCues.disconnect`, `AppHaptics.tapMedium` |
| J-disc-03 | Disconnected player (reconnecting) | Connection restored. App catches up to current game state. Brief "Welcome back!" moment: `AppTextStyles.heading2`, `AppColors.tallowGold` accent, 800ms display then auto-dismiss. Player resumes at current phase. | T-09 reconnect out (600ms) | `SoundCues.reconnect`, `AppHaptics.confirmationPulse` |
| J-disc-04 | Other players (reconnect) | "They have returned!" in `AppTextStyles.flavor` on overlay card. Player avatar restores to full opacity. Interactive elements re-enable. Timers resume. | T-09 reconnect out (600ms) | `SoundCues.reconnect`, `AppHaptics.confirmationPulse` |
| J-disc-05 | All players (host disconnected) | Host connection drops. 5-minute candle countdown begins. Quiz/mini-game content appears. Players can interact with content while waiting. | Host-disconnect screen (see cross-cutting.md P-DISCONNECT). Candle burns down. Content rotates. | `SoundCues.disconnect`, `AppHaptics.tapMedium`, ambient ducks to 30% |
| J-disc-06 | All players (host reconnected) | Current mini-game round finishes (up to 15s). "The innkeeper has returned!" displays. Game resumes from paused state. | Toast message, candle screen dismisses, game UI restores | `SoundCues.reconnect`, `AppHaptics.confirmationPulse` |
| J-disc-07 | All players (host timeout) | 5-minute candle expires. "The candle has gone out..." Game ends. All return to home. | Candle extinguishes, message displays for 3s, then home screen | None |

### Reconnection State Recovery

When a player reconnects, the app must seamlessly restore them to the current game state. The server sends a full state snapshot scoped to that player's information access.

| Current Phase at Reconnect | What the Player Sees |
|---------------------------|---------------------|
| Lobby | Lobby screen with current player list and ready states |
| Night (their wave is active) | Their night action screen with remaining timer |
| Night (their wave has passed) | Night waiting screen with current wave indicator |
| Night (their wave hasn't come yet) | Night waiting screen with current wave indicator |
| Discussion | Discussion screen with remaining timer |
| Voting | Voting screen with remaining timer. Previous selection restored if any. |
| Vote reveal | Vote tally in progress or completed |
| Elimination/Results | Current screen |

### Disconnect Timing Edge Cases

| Scenario | Resolution |
|----------|-----------|
| Player disconnects during their night action wave | Wave timer pauses immediately. If player reconnects, they complete their action. If host ends game, game ends. |
| Player disconnects during voting with a selection | Selection is preserved. Timer pauses. On reconnect, player can still change selection. |
| Player disconnects during voting with no selection | Timer pauses. On reconnect, player can make selection. |
| Host disconnects | 5-minute candle countdown begins. Mini-game content engages remaining players. Host reconnect resumes game; timeout ends game. |
| Multiple players disconnect simultaneously | Overlay shows each disconnected player. Game pauses until all reconnect or host ends game. |
| Player disconnects during a phase transition | On reconnect, player receives the completed transition state. |
| Host disconnects during non-interactive phase | Same candle countdown. Mini-games provide engagement during what would otherwise be a frozen screen. |

---

## Journey 6: Remote Play (J-remote)

Remote play (players on a video call instead of in the same room) is explicitly in scope. The same app serves both contexts, but certain design decisions have different implications.

### Remote Play Divergences

| Game Aspect | In-Person Behavior | Remote Play Behavior | Design Implication |
|-------------|-------------------|---------------------|-------------------|
| Lobby code sharing | Host says code aloud; players type it | Host shares code via screen share, text message, or deep link | Deep link (`midnightvillage.app/join/{code}`) is critical for remote. Tap-to-copy on lobby code enables paste into chat. |
| "Close your eyes" | Players physically close eyes; phone enforces isolation | No physical eyes-closed -- app is the sole isolation mechanism | Night phase screen must not leak information. All players see either their action or the waiting screen. No ambient cues that differ based on role. |
| Night waiting engagement | Conceals who is tapping (all phones active) | Less critical -- players can't see each other's phones | Waiting engagement still valuable for entertainment. Less security-critical but still serves the experience. |
| Discussion phase | Phone recedes; players talk face-to-face | Phone IS the discussion interface (via video call). Phone cannot recede. | Discussion screen must not compete with the video call. Timer is the primary content. Role reminder available but not intrusive. No content that demands phone attention. |
| Voting | Players can see each other's body language | Players rely entirely on app indicators (checkmarks) for social reading | Vote counter ("4/6 have chosen") becomes more important. Checkmarks on player cards are the only signal of engagement. |
| Tap-to-reveal guardrails | Essential -- others can see your screen | Less essential -- no one can see your screen | Keep the guardrails active regardless. Consistent behavior reduces confusion. Players may still share screens on video calls. |
| Sound and ambience | Shared room means shared ambience (potential X-channel audio) | Each player hears their own audio independently | All audio must work as individual experience. No assumptions about shared acoustic space. Volume should be low enough not to bleed into video call mic. |
| Elimination theatrics | Shared room reaction is part of the fun | Reactions happen on video call | No change needed in app. The app delivers the dramatic moment; the video call carries the social reaction. |
| Post-game debrief | Players talk, laugh, replay moments in person | Players debrief on video call while viewing results screen | Full autopsy is more important in remote play -- it substitutes for the shared physical experience of flipping all cards. |

### Remote-Specific Recommendations

1. **No "remote mode" toggle.** The app works identically in both contexts. Design decisions that serve remote play also benefit in-person play (deep links, tap-to-copy, vote counter).
2. **Audio volume defaults.** Default volume settings should assume the player might be on a video call. Ambient soundscapes at 40% master volume (per `sound-and-motion.md`) is appropriate.
3. **Discussion timer visibility.** In remote play, the timer is more important (no shared room energy to feel "time is running out"). The timer color ramp (`AppColors.timerNormal` -> `timerWarning` -> `timerUrgent` -> `timerCritical`) and pressure effects (UI-19, UI-20) serve this well.
4. **Deep link flow.** When a player opens a `midnightvillage.app/join/{code}` link:
   - If app is installed: opens app directly to lobby (bypasses Welcome if name is cached, bypasses Home and Join screens)
   - If app is not installed: opens app store page, then on first launch handles the deferred deep link

---

## Errors

| Error | In-World Headline | Clear Subtitle | Recovery | Phase |
|-------|-------------------|----------------|----------|-------|
| Invalid lobby code | "The tavern door is barred..." | No lobby found with code [CODE] | Tap to re-enter code. Auto-focus input field. | Join |
| Lobby full | "The village is full..." | This lobby has reached its maximum capacity | Return to Home. Try a different code. | Join |
| Lobby closed | "The tavern has gone dark..." | This lobby no longer exists | Return to Home. | Join |
| Game already started | "The ritual has begun..." | This game is already in progress | Return to Home. Cannot late-join. | Join |
| Connection lost | "The spirits are restless..." | Connection lost. Reconnecting... | Auto-reconnect with exponential backoff. Manual "Try Again" after 10s. | Any |
| Reconnection failed | "The fog is too thick..." | Unable to reconnect to the game | "Return to Village" button -> Home screen | Any |
| Server error | "Dark forces are at work..." | Something went wrong. Please try again. | "Try Again" button retries last action. Error toast (UI-15/16) auto-dismisses after 4s. | Any |
| Invalid role config | "The village cannot be formed..." | [Specific validation message, e.g., "Need exactly 8 cards for 5 players"] | Validation banner on role picker. Host adjusts configuration. | Lobby (config) |
| Host ended game | "The tavern keeper has called last orders..." | [Host Name] ended the game | Auto-return to Home after 3s or tap to dismiss | Results |
| Host ended game | "The candle has gone out..." | The game has ended. | All players return to Home after 3s. | Any (in-game) |
| Name too short | "Every villager needs a name..." | Name must be at least 2 characters | Input field shows validation state (`AppColors.bloodEmber` border) | Welcome |
| Name already taken (in lobby) | "Another villager answers to that name..." | A player named [NAME] is already in this lobby | Input field clears. Player enters a different name. | Join -> Lobby |

---

## Information Architecture

### What the Player Knows at Each Phase

| Phase | Player Sees | Player Does NOT See | Host Additional Info |
|-------|------------|--------------------|--------------------|
| Welcome/Home | Own name, online player count | Nothing game-related | Same |
| Lobby | Player list, ready states, roles in play, lobby code | Other players' roles, center cards | Role configuration UI, start control |
| Role Reveal | Own original role, team, description | Any other player's role, center cards | Same (host is a player) |
| Night Action | Own action result (per role's information access) | Other players' actions, other roles, center cards not peeked | Same |
| Night Waiting | Wave progress indicator (dot position, not role labels), engagement content | Which role is currently acting, any action details | Same |
| Discussion | Timer, own role reminder (tap-to-reveal), roles in play | Any night action results except their own, current card positions | "End Discussion" control |
| Voting | Player grid, own selection (tap-to-reveal), who has voted (checkmarks), vote count, timer | Who anyone else voted for | "End Voting" control |
| Vote Reveal | Full vote tally (who voted for whom) | Roles (not yet revealed) | Same |
| Elimination | Eliminated player's identity and revealed role | Non-eliminated players' roles | Same |
| Results | Team outcome, personal outcome, all players' original -> final roles, complete night log | Nothing -- full transparency | "Play Again" and "End Game" controls |

### Tap-to-Reveal Guardrails

Information that is hidden behind a tap-to-reveal overlay (UI-21/22) to prevent casual over-the-shoulder exposure:

| Content | Screen | Reveal Duration | Auto-Hide |
|---------|--------|----------------|-----------|
| Own role reminder | Discussion, Voting | Tap to show | 3000ms auto-hide (UI-22) |
| Own vote selection | Voting | Tap to show | 3000ms auto-hide |
| Night action result summary | Discussion | Tap to show | 3000ms auto-hide |

---

## Accessibility

### Journey-Level Accessibility Requirements

| Requirement | Specification | Screen(s) Affected |
|-------------|--------------|-------------------|
| Screen reader: phase announcements | Each phase transition announces the new phase name and key information: "Night phase. Your role is [Role]. [Action instruction or 'You have no night action.']" | All phase transitions |
| Screen reader: role reveal | Card flip is announced: "Your role is [Role]. [Team] team. [Description]." No reliance on visual card flip. | Role Reveal |
| Screen reader: night action | Action choices announced with labels: "Option 1: Peek one player's card. Option 2: Peek two center cards." Target grid labels each player by name. | Night Action |
| Screen reader: voting | Player grid labels: "[Player Name], not selected" / "[Player Name], selected as your vote target". Vote counter announced on change. | Voting |
| Screen reader: vote tally | Each vote increment announced: "[Voter Name] voted for [Target Name]. [Target Name] now has [N] votes." Final result: "[Player Name] has the most votes with [N]." | Vote Reveal |
| Screen reader: results | Team outcome and personal outcome announced immediately. Player table navigable with role and status per row. | Results |
| Reduced motion: card flip | 3D Y-axis rotation replaced with 300ms crossfade between card back and card front. Team glow appears instantly. Per M-01 reduced motion spec. | Role Reveal |
| Reduced motion: phase transitions | Instant cuts with static narrator text for 1500ms (lobby->night) or 1000ms (other transitions). Per T-01 through T-07 reduced motion specs. | All transitions |
| Reduced motion: vote tally | All bars fill simultaneously over 1000ms. No stagger. Per M-03 reduced motion spec. | Vote Reveal |
| Reduced motion: particles | Static ember dots (8-12 fixed positions), skip dust motes, 2-3 static fog patches. Per `art-direction.md` reduced motion fallback. | Night, Discussion, Voting |
| Color independence | Team identity conveyed by team name label AND color (not color alone). Vote state conveyed by checkmark icon AND color. Timer urgency conveyed by pulse animation AND color change. | All screens |
| Touch targets | All interactive elements meet `AppDimensions.touchTargetMin` (48dp) minimum. Player grid cards, role picker steppers, vote targets, CTA buttons. | All screens |
| Dynamic text | All text respects system font size preferences up to 200% scale. Layouts accommodate larger text by allowing vertical scroll where needed. `AppTextStyles.timerDisplay` and `AppTextStyles.codeDisplay` exempt from dynamic scaling (fixed sizes for design intent). | All screens |
| Focus navigation | All interactive elements reachable via keyboard/switch navigation with visible focus ring (`AppGlows.focus`, `AppColors.outlineStrong` 2dp offset). Tab order follows visual layout top-to-bottom, left-to-right. | All screens |

### First-Time Hint Accessibility

| Hint | Accessible Alternative |
|------|----------------------|
| All tooltips (UI-06) | Announced by screen reader with content text. Dismissible via accessibility action (double-tap). |
| "Tap to reveal your role" prompt | Screen reader announces "Double-tap the card to reveal your role" |
| Contextual onboarding hints | Announced once, then silence. Do not repeat on screen reader re-focus. |

---

## Open Questions

(none)
