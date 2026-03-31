# Specification Quality Checklist: Completeness, Clarity & Measurability

**Purpose**: Validate that requirements in the Frontend Game Integration Layer spec are complete, unambiguous, and measurable
**Created**: 2026-03-31
**Feature**: [spec.md](../spec.md)
**Focus**: Requirements completeness, clarity, measurability
**Depth**: Standard
**Audience**: Reviewer (PR)

## Requirement Completeness

- [ ] CHK001 - Are loading/skeleton state requirements defined for initial data fetches (lobby load, game state load on reconnect, results fetch)? [Gap]
- [ ] CHK002 - Are requirements specified for what happens when a player enters an invalid or expired lobby code? [Gap]
- [ ] CHK003 - Are requirements defined for what happens when a player tries to join a lobby for a game that has already started? [Gap]
- [ ] CHK004 - Is the Villager's complete night phase experience specified beyond "sees waiting view"? (e.g., what text, what happens when all waves pass) [Completeness, Spec §US4]
- [ ] CHK005 - Are requirements defined for handling concurrent/conflicting HTTP response and WebSocket event updates to the same state (e.g., lobby player list)? [Gap]
- [ ] CHK006 - Is there a dedicated FR for the Insomniac auto-submit behavior described in US4 AS6a? [Completeness, Spec §FR list vs US4 AS6a]
- [ ] CHK007 - Are requirements defined for what the home screen displays and its navigation entry points (create lobby, join lobby, resume game)? [Gap]
- [ ] CHK008 - Is the polling fallback for game start mentioned in US3 AS4 (`GET /api/onuw/me/current-game/`) covered by a dedicated FR? [Completeness, Spec §US3 AS4 vs FR list]
- [ ] CHK009 - Are requirements specified for what happens when a player tries to create a lobby while already in one? [Gap]
- [x] CHK010 - Are all 12 v1 roles' night phase interactions specified in acceptance scenarios? [Completeness, Spec §US4]
- [x] CHK011 - Are all WebSocket event types from both consumers (LobbyConsumer and GameConsumer) mapped to specific frontend handling requirements? [Completeness, Spec §FR-003, Reference Documents]
- [x] CHK012 - Are backend changes (FR-030 through FR-033) each traceable to a specific user story acceptance scenario? [Completeness]
- [x] CHK013 - Are all edge cases in the Edge Cases section covered by corresponding FRs or acceptance scenarios? [Completeness, Spec §Edge Cases]
- [ ] CHK014 - Are requirements defined for disposing/cleaning up WebSocket connections and Riverpod providers when navigating away from game screens? [Gap]
- [x] CHK015 - Are requirements for the `VoteResult` and `PlayerResult` model changes (nullable fields, new fields) explicitly specified? [Completeness, Spec §FR-028]

## Requirement Clarity

- [ ] CHK016 - Is "prominently displayed" for the lobby code quantified with specific sizing, positioning, or visual hierarchy rules? [Clarity, Spec §US1 AS2, FR-008]
- [ ] CHK017 - Is the role reveal duration specified precisely (the spec says "3–5 seconds" — which value, or is it configurable)? [Clarity, Spec §Role reveal view, Assumptions]
- [ ] CHK018 - Are the exponential backoff parameters for WebSocket reconnection specified (initial delay, multiplier, max delay, max retries)? [Clarity, Spec §FR-004, Edge Cases]
- [ ] CHK019 - Is "atmospheric text" for the night waiting view defined with specific copy or content guidelines? [Clarity, Spec §Night waiting view]
- [ ] CHK020 - Is "breathing animation" for the night waiting view specified with animation parameters (duration, easing, amplitude)? [Clarity, Spec §Night waiting view]
- [x] CHK021 - Is the timer computation method unambiguous (`deadline - DateTime.now()`)? [Clarity, Spec §FR-017]
- [x] CHK022 - Are the Doppelganger follow-up action rules clearly specified for each possible copied role? [Clarity, Spec §US4 AS6, FR-023]
- [ ] CHK023 - Is "shortly after" in US5 AS6 (time between `vote_reveal` and `game_results` events) quantified? The 5-second fallback timeout is specified but the expected normal delay is not. [Clarity, Spec §US5 AS6]
- [x] CHK024 - Is the lone Werewolf compound interaction flow (empty teammate display → optional center peek → single action submission) unambiguously specified? [Clarity, Spec §FR-026]
- [ ] CHK025 - Is "warm, anticipatory" lobby aesthetic defined with reference to specific design tokens or existing component styles rather than subjective description? [Clarity, Spec §Lobby screen]

## Requirement Consistency

- [x] CHK026 - Are the API endpoint paths consistent between user stories, FRs, and reference documents? (e.g., FR-016 vs FR-030 both reference `/api/lobbies/<code>/`) [Consistency]
- [x] CHK027 - Is the `VoteReveal` widget usage consistent between the component inventory (takes `List<VoteResult>` with required fields) and FR-028 (nullable `targetId`/`targetName`)? [Consistency, Spec §Existing Components vs FR-028]
- [x] CHK028 - Are the Doppelganger-as-Insomniac requirements consistent between US4 AS6 ("may differ from the copied role if swapped") and US4 AS6a (Insomniac's own flow)? [Consistency, Spec §US4]
- [x] CHK029 - Are host vs non-host player capabilities consistently defined across lobby (US1, US2, US3) and discussion (US5) requirements? [Consistency]
- [x] CHK030 - Is the game results data flow consistent — US6 AS1 says fetch from GET endpoint, FR-024 says the same, and the WebSocket event contains only summary data? [Consistency]

## Acceptance Criteria Quality (Measurability)

- [ ] CHK031 - Is SC-002 ("within 2 seconds") specified as a percentile target (p50, p95, p99) or absolute guarantee? [Measurability, Spec §SC-002]
- [ ] CHK032 - Is SC-003 ("within 5 seconds") specified as a percentile or absolute, and does it include time for both WebSocket reconnection and HTTP state fetch? [Measurability, Spec §SC-003]
- [ ] CHK033 - Is SC-007 ("no hardcoded colors, spacing, or typography") defined with a measurable verification method (lint rule, code review checklist, automated check)? [Measurability, Spec §SC-007]
- [x] CHK034 - Is SC-001 (end-to-end playable game) defined with a specific test scenario that can be executed? [Measurability, Spec §SC-001]
- [x] CHK035 - Is SC-006 (new integration tests) specific about which flows must be covered? [Measurability, Spec §SC-006]

## Scenario Coverage

- [ ] CHK036 - Are requirements specified for screen orientation constraints (portrait-only, landscape support)? [Coverage, Gap]
- [ ] CHK037 - Are accessibility requirements defined for the new screens (screen reader labels, contrast ratios, touch target sizes, keyboard navigation)? [Coverage, Gap]
- [ ] CHK038 - Are requirements defined for what happens when a player backgrounds the app during non-reveal phases (night action prompt, voting)? The spec covers role reveal backgrounding but not other phases. [Coverage, Spec §Edge Cases]
- [x] CHK039 - Are disconnection indicator requirements defined for how other players see a disconnected player across all phases? [Coverage, Spec §Edge Cases]
- [x] CHK040 - Are requirements defined for the case where all players disconnect? [Coverage, Spec §Edge Cases]

## Edge Case & Exception Flow Coverage

- [x] CHK041 - Are HTTP error response handling requirements specified for all API calls (409 already acted, 400 validation, 403 non-host, auth failures)? [Coverage, Spec §Edge Cases]
- [ ] CHK042 - Are requirements specified for clock skew between client and server affecting deadline-based timers? [Edge Case, Gap]
- [x] CHK043 - Is the race condition between host ending discussion and timer expiring addressed? [Edge Case, Spec §Edge Cases]
- [x] CHK044 - Are requirements defined for what happens when the host leaves the lobby (lobby deletion, player notification)? [Edge Case, Spec §Edge Cases]
- [ ] CHK045 - Are requirements specified for network timeout thresholds on HTTP requests (how long before showing an error vs. retrying)? [Edge Case, Gap]

## Dependencies & Assumptions

- [x] CHK046 - Are all 4 backend changes (FR-030–FR-033) documented with clear scope and relationship to frontend requirements? [Dependencies, Spec §FR-030–FR-033]
- [x] CHK047 - Is the assumption about single WebSocket connection at a time explicitly documented? [Assumptions, Spec §Assumptions]
- [x] CHK048 - Is the assumption about one active game per user explicitly documented? [Assumptions, Spec §Assumptions]
- [x] CHK049 - Are out-of-scope items (timer config UI, role descriptions, saved configurations) explicitly listed? [Assumptions, Spec §Assumptions]
- [x] CHK050 - Are the existing frontend models that need modification (PlayerResult, VoteResult, GameResult) identified with specific field changes? [Dependencies, Spec §FR-028]
