# One Night Ultimate Werewolf — Spec Index

Comprehensive game specifications for the One Night series by Bezier Games. These specs serve as the authoritative reference for implementing the Midnight Village digital companion app.

## Base Game (v1 Scope)

These specs cover the 12 roles targeted for initial implementation.

| Document | Contents |
|----------|----------|
| [overview.md](overview.md) | Setup, game flow, phases, teams, information architecture |
| [roles.md](roles.md) | All 12 v1 roles — team, wave, action, special rules |
| [night-phase.md](night-phase.md) | Wake order, wave system, narrator scripts, action types, timer model, optionality |
| [voting-and-resolution.md](voting-and-resolution.md) | Discussion, voting mechanics, death threshold, win conditions, algorithm |
| [doppelganger.md](doppelganger.md) | Complete Doppelganger interaction matrix for all 12 copied roles |
| [reference-games.md](reference-games.md) | 23 complete games and 6 short Doppelganger games, traced from deal to result and checked against the rules, with a table of what each covers |

## Daybreak Expansion (Future Scope)

| Document | Contents |
|----------|----------|
| [daybreak-overview.md](daybreak-overview.md) | Expansion summary, 11 new roles, new mechanics |
| [daybreak-roles.md](daybreak-roles.md) | All 11 Daybreak roles — team, wave, action, special rules, base game interactions |
| [daybreak-mechanics.md](daybreak-mechanics.md) | Artifacts, shield tokens, Center Werewolf card, combined wake order |

## Series Reference

| Document | Contents |
|----------|----------|
| [series-catalog.md](series-catalog.md) | Complete catalog of all One Night games (Werewolf, Daybreak, Vampire, Alien, Super Villains, Bonus Roles, Epic Battle) |
| [recommended-setups.md](recommended-setups.md) | Curated role combinations by player count |

## Implementation Status

| Spec Area | Status | Notes |
|-----------|--------|-------|
| Base game rules | Complete | 2 research passes, challenger-reviewed |
| Base game roles (12) | Complete | All interactions documented |
| Night phase engine | Complete | Official wake order, Doppelganger timing clarified |
| Voting & resolution | Complete | Win conditions, Hunter chain, Tanner override |
| Doppelganger matrix | Complete | All 12 copied role scenarios |
| Daybreak expansion | Documented | Not in v1 scope |
| Series catalog | Documented | Reference only — no implementation planned |
| Recommended setups | Documented | UX reference for lobby configuration |
