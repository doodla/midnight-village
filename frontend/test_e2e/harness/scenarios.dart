import 'scenario_dsl.dart';

/// The nine in-scope reference scenarios (contract §3), authored as data from
/// `docs/specs/frontend/validation/scenarios.md`.
///
/// In scope: 1, 2, 3, 4, 5, 6, 8, 10, plus Scenario 7 Sub-Case A only.
/// Scenario 9 (Disconnect Nightmare) is deferred per the contract.
///
/// Center-index convention: the forced `centerCards` list is index 0..2, so a
/// scenario's "peeks center card 0 → Werewolf" pins `centerCards[0] = Werewolf`.
/// Team tokens: {werewolf, village, neutral}; Minion/Werewolf = werewolf,
/// Tanner = neutral.
final List<HarnessScenario> allScenarios = [
  _scenario1,
  _scenario2,
  _scenario3,
  _scenario4,
  _scenario5,
  _scenario6,
  _scenario7SubCaseA,
  _scenario8,
  _scenario10,
];

// ---------------------------------------------------------------------------
// Scenario 1: Clean Village Win (Baseline) — uiCritical
// ---------------------------------------------------------------------------

final _scenario1 = HarnessScenario(
  name: 'scenario-1-clean-village-win',
  tags: {ScenarioTag.uiCritical},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
  playerRoles: {
    'Alice': 'Werewolf',
    'Bob': 'Seer',
    'Carol': 'Robber',
    'Dave': 'Villager',
    'Eve': 'Villager',
  },
  // Alice peeks center card 0 → Werewolf.
  centerCards: ['Werewolf', 'Troublemaker', 'Minion'],
  nightScript: [
    // W2: Alice (lone Werewolf) peeks center card 0 → Werewolf.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Alice', centerIndex: 0),
    // W3: Bob (Seer) peeks Alice → Werewolf.
    NightAction.peekPlayer(wave: 3, actor: 'Bob', targetName: 'Alice'),
    // W3: Carol (Robber) swaps with Dave → Carol=Villager, Dave=Robber.
    NightAction.swapWithPlayer(wave: 3, actor: 'Carol', targetName: 'Dave'),
  ],
  // Bob accuses Alice; village trusts Seer. Alice = 4 votes.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
    VoteEntry(voterName: 'Bob', targetName: 'Alice'),
    VoteEntry(voterName: 'Carol', targetName: 'Alice'),
    VoteEntry(voterName: 'Dave', targetName: 'Alice'),
    VoteEntry(voterName: 'Eve', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Werewolf',
      'Bob': 'Seer',
      'Carol': 'Villager',
      'Dave': 'Robber',
      'Eve': 'Villager',
    },
    teamsByName: {
      'Alice': 'werewolf',
      'Bob': 'village',
      'Carol': 'village',
      'Dave': 'village',
      'Eve': 'village',
    },
    winningTeams: {'village'},
    eliminatedNames: {'Alice'},
    eliminationReasons: {'Alice': 'vote'},
    nightResultChecks: [
      // Bob's Seer peek of Alice returns Werewolf (pre-swap, no swap of Alice).
      NightResultCheck(
        actorName: 'Bob',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Werewolf'},
      ),
    ],
  ),
  uiChecks: [
    UiCheck(
      perspectiveName: 'Alice',
      frameName: '01-alice-role-reveal',
      assertRenderedOriginalRole: true,
    ),
    UiCheck(
      perspectiveName: 'Bob',
      frameName: '02-bob-role-reveal',
      assertRenderedOriginalRole: true,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Scenario 2: No One Dies — Werewolf Survives — uiCritical (lone-WW peek)
// ---------------------------------------------------------------------------

final _scenario2 = HarnessScenario(
  name: 'scenario-2-no-one-dies',
  tags: {ScenarioTag.uiCritical},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave'],
  playerRoles: {
    'Alice': 'Werewolf',
    'Bob': 'Villager',
    'Carol': 'Villager',
    'Dave': 'Seer',
  },
  // Dave peeks center cards 0 and 1 → Werewolf, Minion.
  centerCards: ['Werewolf', 'Minion', 'Insomniac'],
  nightScript: [
    // W2: Alice (lone Werewolf) DECLINES the optional center peek (skip).
    NightAction.decline(wave: 2, actor: 'Alice', actionType: 'see_team'),
    // W3: Dave (Seer) peeks center cards 0 and 1 → Werewolf, Minion.
    NightAction.peekCenter(wave: 3, actor: 'Dave', centerIndices: [0, 1]),
  ],
  // Everyone gets exactly 1 vote — no one reaches the >=2 threshold.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
    VoteEntry(voterName: 'Bob', targetName: 'Carol'),
    VoteEntry(voterName: 'Carol', targetName: 'Dave'),
    VoteEntry(voterName: 'Dave', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Werewolf',
      'Bob': 'Villager',
      'Carol': 'Villager',
      'Dave': 'Seer',
    },
    teamsByName: {
      'Alice': 'werewolf',
      'Bob': 'village',
      'Carol': 'village',
      'Dave': 'village',
    },
    // No Werewolf died → Werewolf team wins by survival.
    winningTeams: {'werewolf'},
    eliminatedNames: {},
  ),
  uiChecks: [
    UiCheck(
      perspectiveName: 'Alice',
      frameName: '01-alice-lone-werewolf',
      assertRenderedOriginalRole: true,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Scenario 3: The Seer Trap — Stale Information — uiCritical (Seer peek)
// ---------------------------------------------------------------------------

final _scenario3 = HarnessScenario(
  name: 'scenario-3-seer-trap',
  tags: {ScenarioTag.uiCritical},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
  playerRoles: {
    'Alice': 'Werewolf',
    'Bob': 'Seer',
    'Carol': 'Robber',
    'Dave': 'Villager',
    'Eve': 'Troublemaker',
  },
  // Alice peeks center → Minion (index 0).
  centerCards: ['Minion', 'Werewolf', 'Drunk'],
  nightScript: [
    // W2: Alice (lone Werewolf) peeks center card 0 → Minion.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Alice', centerIndex: 0),
    // W3 order is Seer → Robber → Troublemaker.
    // Bob (Seer) peeks Alice → Werewolf (pre-swap).
    NightAction.peekPlayer(wave: 3, actor: 'Bob', targetName: 'Alice'),
    // Carol (Robber) swaps with Alice → Carol=Werewolf, Alice=Robber.
    NightAction.swapWithPlayer(wave: 3, actor: 'Carol', targetName: 'Alice'),
    // Eve (Troublemaker) swaps Bob and Dave → Bob=Villager, Dave=Seer.
    NightAction.swapOthers(
      wave: 3,
      actor: 'Eve',
      targetName1: 'Bob',
      targetName2: 'Dave',
    ),
  ],
  // Bob accuses Alice on stale Seer info; village votes Alice. Alice = 4 votes.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
    VoteEntry(voterName: 'Bob', targetName: 'Alice'),
    VoteEntry(voterName: 'Carol', targetName: 'Alice'),
    VoteEntry(voterName: 'Dave', targetName: 'Alice'),
    VoteEntry(voterName: 'Eve', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Robber',
      'Bob': 'Villager',
      'Carol': 'Werewolf',
      'Dave': 'Seer',
      'Eve': 'Troublemaker',
    },
    teamsByName: {
      'Alice': 'village',
      'Bob': 'village',
      'Carol': 'werewolf',
      'Dave': 'village',
      'Eve': 'village',
    },
    // Alice (Village) dies, Carol (Werewolf) survives → Werewolf team wins.
    winningTeams: {'werewolf'},
    eliminatedNames: {'Alice'},
    eliminationReasons: {'Alice': 'vote'},
    nightResultChecks: [
      // Bob's Seer peek saw Alice as Werewolf (correct at peek time, pre-swap).
      NightResultCheck(
        actorName: 'Bob',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Werewolf'},
      ),
      // Carol's Robber swap revealed Werewolf (the card she stole from Alice).
      NightResultCheck(
        actorName: 'Carol',
        roleActingAs: 'Robber',
        actionType: 'swap_with_player',
        expectedResultContains: {'new_role': 'Werewolf'},
      ),
    ],
  ),
  uiChecks: [
    UiCheck(
      perspectiveName: 'Bob',
      frameName: '01-bob-seer-role-reveal',
      assertRenderedOriginalRole: true,
    ),
    UiCheck(
      perspectiveName: 'Carol',
      frameName: '02-carol-robber-role-reveal',
      assertRenderedOriginalRole: true,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Scenario 4: Doppelganger Chaos — Multi-Swap Chain — uiCritical (multi-wave)
// ---------------------------------------------------------------------------

final _scenario4 = HarnessScenario(
  name: 'scenario-4-doppelganger-chaos',
  tags: {ScenarioTag.uiCritical},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
  playerRoles: {
    'Alice': 'Doppelganger',
    'Bob': 'Robber',
    'Carol': 'Werewolf',
    'Dave': 'Seer',
    'Eve': 'Villager',
  },
  // Carol peeks center → Werewolf (index 0).
  centerCards: ['Werewolf', 'Troublemaker', 'Drunk'],
  nightScript: [
    // W1: Alice (Doppelganger) peeks Bob → Robber (becomes Dopp-as-Robber).
    NightAction.peekPlayer(wave: 1, actor: 'Alice', targetName: 'Bob'),
    // W1 follow-up: Alice (as Robber) swaps with Carol → Alice=Werewolf,
    // Carol=Doppelganger. After this swap ALICE physically holds the Werewolf
    // card, so SHE is the lone Werewolf who wakes in wave 2 (the backend keys
    // wave-2 wake on current_role; Carol now holds Doppelganger and does not
    // wake — verified: Carol's see_team 400s, Alice's succeeds).
    NightAction.swapWithPlayer(wave: 1, actor: 'Alice', targetName: 'Carol'),
    // W2: Alice (now lone Werewolf) peeks center card 0 → Werewolf.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Alice', centerIndex: 0),
    // W3: Dave (Seer) peeks Eve → Villager.
    NightAction.peekPlayer(wave: 3, actor: 'Dave', targetName: 'Eve'),
    // W3: Bob (Robber) swaps with Dave → Bob=Seer, Dave=Robber.
    NightAction.swapWithPlayer(wave: 3, actor: 'Bob', targetName: 'Dave'),
  ],
  // Village votes Carol (3 votes); eliminated.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Carol'),
    VoteEntry(voterName: 'Bob', targetName: 'Carol'),
    VoteEntry(voterName: 'Dave', targetName: 'Carol'),
    VoteEntry(voterName: 'Carol', targetName: 'Alice'),
    VoteEntry(voterName: 'Eve', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Werewolf',
      'Bob': 'Seer',
      // Carol holds the Doppelganger card (copied Robber).
      'Carol': 'Doppelganger',
      'Dave': 'Robber',
      'Eve': 'Villager',
    },
    teamsByName: {
      'Alice': 'werewolf',
      'Bob': 'village',
      'Carol': 'village',
      'Dave': 'village',
      'Eve': 'village',
    },
    // Carol (Village) dies, no Werewolf died → Werewolf team wins.
    winningTeams: {'werewolf'},
    eliminatedNames: {'Carol'},
    eliminationReasons: {'Carol': 'vote'},
    // `doppelganger_copied_role` is reported on the player DEALT the
    // Doppelganger who acted (Alice) — the copy lives in her night_action_data —
    // NOT on whoever physically holds the Doppelganger card at the end (Carol).
    doppelgangerCopiedByName: {'Alice': 'Robber'},
    nightResultChecks: [
      // Alice's Doppelganger peek of Bob saw Robber. The peek result is keyed
      // `copied_role`; Alice's first log entry is the peek (the swap follow-up
      // is a separate `swap_with_player` entry).
      NightResultCheck(
        actorName: 'Alice',
        roleActingAs: 'Doppelganger',
        actionType: 'peek_player',
        expectedResultContains: {'copied_role': 'Robber'},
      ),
    ],
  ),
  uiChecks: [
    UiCheck(
      perspectiveName: 'Alice',
      frameName: '01-alice-doppelganger-reveal',
      assertRenderedOriginalRole: true,
    ),
    UiCheck(
      perspectiveName: 'Carol',
      frameName: '02-carol-werewolf-reveal',
      assertRenderedOriginalRole: true,
    ),
  ],
);

// ---------------------------------------------------------------------------
// Scenario 5: Hunter Chain + Tanner Block — uiCritical (Hunter-chain results)
// ---------------------------------------------------------------------------

final _scenario5 = HarnessScenario(
  name: 'scenario-5-hunter-chain-tanner-block',
  tags: {ScenarioTag.uiCritical},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank'],
  playerRoles: {
    'Alice': 'Werewolf',
    'Bob': 'Hunter',
    'Carol': 'Seer',
    'Dave': 'Villager',
    'Eve': 'Tanner',
    'Frank': 'Villager',
  },
  // Alice peeks center → Minion (index 0).
  centerCards: ['Minion', 'Werewolf', 'Robber'],
  nightScript: [
    // W2: Alice (lone Werewolf) peeks center card 0 → Minion.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Alice', centerIndex: 0),
    // W3: Carol (Seer) peeks Alice → Werewolf.
    NightAction.peekPlayer(wave: 3, actor: 'Carol', targetName: 'Alice'),
  ],
  // Bob=3 (Alice,Dave,Eve), Alice=2 (Carol,Frank), Eve=1 (Bob).
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
    VoteEntry(voterName: 'Bob', targetName: 'Eve'),
    VoteEntry(voterName: 'Carol', targetName: 'Alice'),
    VoteEntry(voterName: 'Dave', targetName: 'Bob'),
    VoteEntry(voterName: 'Eve', targetName: 'Bob'),
    VoteEntry(voterName: 'Frank', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Werewolf',
      'Bob': 'Hunter',
      'Carol': 'Seer',
      'Dave': 'Villager',
      'Eve': 'Tanner',
      'Frank': 'Villager',
    },
    teamsByName: {
      'Alice': 'werewolf',
      'Bob': 'village',
      'Carol': 'village',
      'Dave': 'village',
      'Eve': 'neutral',
      'Frank': 'village',
    },
    // Bob dies (3 votes). Hunter chain: Bob voted Eve → Eve also dies.
    // Tanner (Eve) died + no Werewolf died → Tanner wins ONLY (blocks WW win).
    winningTeams: {'tanner'},
    eliminatedNames: {'Bob', 'Eve'},
    eliminationReasons: {'Bob': 'vote', 'Eve': 'hunter_chain'},
    nightResultChecks: [
      NightResultCheck(
        actorName: 'Carol',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Werewolf'},
      ),
    ],
  ),
  uiChecks: [
    UiCheck(
      perspectiveName: 'Bob',
      frameName: '01-bob-hunter-reveal',
      assertRenderedOriginalRole: true,
    ),
    UiCheck(perspectiveName: 'Bob', frameName: '02-results-tanner-wins'),
  ],
);

// ---------------------------------------------------------------------------
// Scenario 6: No-Werewolf Minion — Unwitting Winner
// ---------------------------------------------------------------------------

final _scenario6 = HarnessScenario(
  name: 'scenario-6-no-werewolf-minion',
  tags: {},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
  playerRoles: {
    'Alice': 'Minion',
    'Bob': 'Seer',
    'Carol': 'Villager',
    'Dave': 'Troublemaker',
    'Eve': 'Mason',
  },
  // Both Werewolves in center; Mason in center makes Eve the lone Mason.
  centerCards: ['Werewolf', 'Werewolf', 'Mason'],
  nightScript: [
    // W2: Alice (Minion) wakes — zero thumbs (both WW in center).
    //     The Minion has no target action; encoded as a decline.
    NightAction.decline(wave: 2, actor: 'Alice', actionType: 'see_team'),
    // W2: Eve (lone Mason) ALSO wakes in wave 2 (Mason is a wave-2 role). Every
    //     required actor in a wave must submit for it to auto-advance, so Eve's
    //     see_team must be present too — lone Mason sees no one (empty targets).
    NightAction.decline(wave: 2, actor: 'Eve', actionType: 'see_team'),
    // W3: Bob (Seer) peeks Carol → Villager.
    NightAction.peekPlayer(wave: 3, actor: 'Bob', targetName: 'Carol'),
    // W3: Dave (Troublemaker) swaps Alice and Carol → Alice=Villager,
    //     Carol=Minion.
    NightAction.swapOthers(
      wave: 3,
      actor: 'Dave',
      targetName1: 'Alice',
      targetName2: 'Carol',
    ),
  ],
  // Alice frames Bob; everyone votes Bob. Bob = 4 votes.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
    VoteEntry(voterName: 'Carol', targetName: 'Bob'),
    VoteEntry(voterName: 'Dave', targetName: 'Bob'),
    VoteEntry(voterName: 'Eve', targetName: 'Bob'),
    VoteEntry(voterName: 'Bob', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Villager',
      'Bob': 'Seer',
      'Carol': 'Minion',
      'Dave': 'Troublemaker',
      'Eve': 'Mason',
    },
    teamsByName: {
      'Alice': 'village',
      'Bob': 'village',
      'Carol': 'werewolf',
      'Dave': 'village',
      'Eve': 'village',
    },
    // No WW among players + a non-Minion (Bob) died → Werewolf team wins
    // (Minion special rule). Carol holds the Minion card unknowingly.
    winningTeams: {'werewolf'},
    eliminatedNames: {'Bob'},
    eliminationReasons: {'Bob': 'vote'},
    nightResultChecks: [
      NightResultCheck(
        actorName: 'Bob',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Villager'},
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Scenario 7 Sub-Case A: Doppelganger-as-Minion (Minion also in play)
// Single entry, NOT uiCritical; asserted via the oracle only.
// ---------------------------------------------------------------------------

final _scenario7SubCaseA = HarnessScenario(
  name: 'scenario-7a-doppelganger-as-minion',
  tags: {},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
  playerRoles: {
    'Alice': 'Doppelganger',
    'Bob': 'Minion',
    'Carol': 'Werewolf',
    'Dave': 'Seer',
    'Eve': 'Villager',
  },
  // Carol peeks center → Werewolf (index 0).
  centerCards: ['Werewolf', 'Mason', 'Mason'],
  nightScript: [
    // W1: Alice (Doppelganger) peeks Bob → Minion (becomes Dopp-as-Minion,
    //     team → werewolf).
    NightAction.peekPlayer(wave: 1, actor: 'Alice', targetName: 'Bob'),
    // W1 follow-up: copied Minion's Doppelganger follow-up wave IS 1 (backend
    //   _DOPPELGANGER_FOLLOWUP_WAVES['Minion'] == 1), so the Dopp-as-Minion must
    //   take its see_team in wave 1 or the wave never auto-advances. The Minion
    //   sees thumbs (no target) → declined see_team with empty targets.
    NightAction.decline(wave: 1, actor: 'Alice', actionType: 'see_team'),
    // W2: Carol (Werewolf) wakes lone, peeks center card 0 → Werewolf.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Carol', centerIndex: 0),
    // W2: Bob (the REAL Minion) also wakes in wave 2 (Minion is a wave-2 role)
    //   and sees the Werewolf thumbs — every wave-2 actor must submit for the
    //   wave to auto-advance, so Bob's see_team is required (no target).
    NightAction.decline(wave: 2, actor: 'Bob', actionType: 'see_team'),
    // W3: Dave (Seer) peeks Alice → Doppelganger (physical card unchanged).
    NightAction.peekPlayer(wave: 3, actor: 'Dave', targetName: 'Alice'),
  ],
  // No elimination needed to assert the sub-case-A truth; everyone abstains so
  // the game still resolves to results for win-condition assertion.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: null),
    VoteEntry(voterName: 'Bob', targetName: null),
    VoteEntry(voterName: 'Carol', targetName: null),
    VoteEntry(voterName: 'Dave', targetName: null),
    VoteEntry(voterName: 'Eve', targetName: null),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Doppelganger',
      'Bob': 'Minion',
      'Carol': 'Werewolf',
      'Dave': 'Seer',
      'Eve': 'Villager',
    },
    // Alice/Bob/Carol on the Werewolf team (Alice = Dopp-as-Minion).
    teamsByName: {
      'Alice': 'werewolf',
      'Bob': 'werewolf',
      'Carol': 'werewolf',
      'Dave': 'village',
      'Eve': 'village',
    },
    // No one died, no Werewolf died → Werewolf team wins by survival.
    winningTeams: {'werewolf'},
    eliminatedNames: {},
    doppelgangerCopiedByName: {'Alice': 'Minion'},
    nightResultChecks: [
      // Dave's Seer peek of Alice saw Doppelganger (physical card, not Minion).
      NightResultCheck(
        actorName: 'Dave',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Doppelganger'},
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Scenario 8: The Drunk Into Werewolf — Unknowing Team Change
// ---------------------------------------------------------------------------

final _scenario8 = HarnessScenario(
  name: 'scenario-8-drunk-into-werewolf',
  tags: {},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve'],
  playerRoles: {
    'Alice': 'Werewolf',
    'Bob': 'Seer',
    'Carol': 'Drunk',
    'Dave': 'Villager',
    'Eve': 'Insomniac',
  },
  // Alice peeks center card 0 → Werewolf; Carol swaps with center card 0.
  centerCards: ['Werewolf', 'Villager', 'Troublemaker'],
  nightScript: [
    // W2: Alice (lone Werewolf) peeks center card 0 → Werewolf.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Alice', centerIndex: 0),
    // W3: Bob (Seer) peeks Carol → Drunk (pre-swap; Seer acts before Drunk).
    NightAction.peekPlayer(wave: 3, actor: 'Bob', targetName: 'Carol'),
    // W3: Carol (Drunk) MUST swap with center card 0 → Carol=Werewolf (blind).
    NightAction.swapWithCenter(wave: 3, actor: 'Carol', centerIndex: 0),
    // W4: Eve (Insomniac) checks own card → still Insomniac.
    NightAction.insomniacSelfCheck(wave: 4, actor: 'Eve'),
  ],
  // Village votes Alice. Alice = 4 votes.
  voteScript: [
    VoteEntry(voterName: 'Bob', targetName: 'Alice'),
    VoteEntry(voterName: 'Carol', targetName: 'Alice'),
    VoteEntry(voterName: 'Dave', targetName: 'Alice'),
    VoteEntry(voterName: 'Eve', targetName: 'Alice'),
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Werewolf',
      'Bob': 'Seer',
      'Carol': 'Werewolf',
      'Dave': 'Villager',
      'Eve': 'Insomniac',
    },
    teamsByName: {
      'Alice': 'werewolf',
      'Bob': 'village',
      'Carol': 'werewolf',
      'Dave': 'village',
      'Eve': 'village',
    },
    // Alice (Werewolf) dies → at least one WW died → Village wins. Carol is also
    // Werewolf but survived (Village wins by killing >=1 WW).
    winningTeams: {'village'},
    eliminatedNames: {'Alice'},
    eliminationReasons: {'Alice': 'vote'},
    nightResultChecks: [
      // Bob's pre-swap Seer peek of Carol saw Drunk (stale by resolution).
      NightResultCheck(
        actorName: 'Bob',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Drunk'},
      ),
      // Eve's Insomniac self-check saw Insomniac (auto-revealed `none` action;
      // result keyed `current_role`).
      NightResultCheck(
        actorName: 'Eve',
        roleActingAs: 'Insomniac',
        actionType: 'none',
        expectedResultContains: {'current_role': 'Insomniac'},
      ),
    ],
  ),
);

// ---------------------------------------------------------------------------
// Scenario 10: The Kitchen Sink — uiCritical (three-way tie)
// ---------------------------------------------------------------------------

final _scenario10 = HarnessScenario(
  name: 'scenario-10-kitchen-sink',
  tags: {ScenarioTag.uiCritical},
  playerNames: ['Alice', 'Bob', 'Carol', 'Dave', 'Eve', 'Frank', 'Grace'],
  playerRoles: {
    'Alice': 'Doppelganger',
    'Bob': 'Werewolf',
    'Carol': 'Minion',
    'Dave': 'Seer',
    'Eve': 'Robber',
    'Frank': 'Hunter',
    'Grace': 'Tanner',
  },
  // Bob peeks center → Troublemaker (index 0).
  centerCards: ['Troublemaker', 'Werewolf', 'Drunk'],
  nightScript: [
    // W1: Alice (Doppelganger) peeks Eve → Robber (becomes Dopp-as-Robber).
    NightAction.peekPlayer(wave: 1, actor: 'Alice', targetName: 'Eve'),
    // W1 follow-up: Alice (as Robber) robs Frank → Alice=Hunter, Frank=Dopp.
    NightAction.swapWithPlayer(wave: 1, actor: 'Alice', targetName: 'Frank'),
    // W2: Bob (Werewolf) wakes lone, peeks center card 0 → Troublemaker.
    NightAction.loneWerewolfPeek(wave: 2, actor: 'Bob', centerIndex: 0),
    // W2: Carol (Minion) wakes — sees Bob's thumb (no target action).
    NightAction.decline(wave: 2, actor: 'Carol', actionType: 'see_team'),
    // W3: Dave (Seer) peeks Bob → Werewolf.
    NightAction.peekPlayer(wave: 3, actor: 'Dave', targetName: 'Bob'),
    // W3: Eve (Robber) swaps with Alice → Eve=Hunter, Alice=Robber.
    NightAction.swapWithPlayer(wave: 3, actor: 'Eve', targetName: 'Alice'),
  ],
  // Three-way tie at 2 votes: Bob (Alice,Eve), Grace (Bob,Dave), Dave (Carol,
  // Frank); Alice = 1 (Grace). All three of Bob/Grace/Dave die.
  voteScript: [
    VoteEntry(voterName: 'Alice', targetName: 'Bob'),
    VoteEntry(voterName: 'Bob', targetName: 'Grace'),
    VoteEntry(voterName: 'Carol', targetName: 'Dave'),
    VoteEntry(voterName: 'Dave', targetName: 'Grace'),
    VoteEntry(voterName: 'Eve', targetName: 'Bob'),
    VoteEntry(voterName: 'Frank', targetName: 'Dave'),
    VoteEntry(voterName: 'Grace', targetName: 'Alice'),
  ],
  expected: ScenarioExpectation(
    finalRolesByName: {
      'Alice': 'Robber',
      'Bob': 'Werewolf',
      'Carol': 'Minion',
      'Dave': 'Seer',
      'Eve': 'Hunter',
      'Frank': 'Doppelganger',
      'Grace': 'Tanner',
    },
    teamsByName: {
      'Alice': 'village',
      'Bob': 'werewolf',
      'Carol': 'werewolf',
      'Dave': 'village',
      'Eve': 'village',
      'Frank': 'village',
      'Grace': 'neutral',
    },
    // Bob (WW) died → Village wins; Grace (Tanner) died → Tanner wins.
    // Eve holds Hunter but is alive → no Hunter chain. Winners: village + tanner.
    winningTeams: {'village', 'tanner'},
    eliminatedNames: {'Bob', 'Grace', 'Dave'},
    eliminationReasons: {'Bob': 'vote', 'Grace': 'vote', 'Dave': 'vote'},
    // Reported on Alice (dealt Doppelganger, copied Robber by peeking Eve), not
    // on Frank who ends up holding the Doppelganger card after the swaps.
    doppelgangerCopiedByName: {'Alice': 'Robber'},
    nightResultChecks: [
      // Dave's Seer peek of Bob saw Werewolf (Bob never swapped).
      NightResultCheck(
        actorName: 'Dave',
        roleActingAs: 'Seer',
        actionType: 'peek_player',
        expectedResultContains: {'peeked_role': 'Werewolf'},
      ),
      // Eve's Robber swap of Alice revealed Hunter (the card Alice held then).
      NightResultCheck(
        actorName: 'Eve',
        roleActingAs: 'Robber',
        actionType: 'swap_with_player',
        expectedResultContains: {'new_role': 'Hunter'},
      ),
    ],
  ),
  uiChecks: [
    UiCheck(
      perspectiveName: 'Dave',
      frameName: '01-dave-seer-reveal',
      assertRenderedOriginalRole: true,
    ),
    UiCheck(perspectiveName: 'Dave', frameName: '02-results-three-way-tie'),
  ],
);
