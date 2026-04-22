# DjLust
A Simple WoW Addon to play music and display an animation during Bloodlust and other similar spells.

**Detection method: `issecretvalue()` guard on `UNIT_AURA` `addedAuras` — compatible with WoW 12.0.5+.**

## Usage
- Click the bloodlust icon on your minimap to open the settings menu, or use the slash commands below.

## Features
- Choose between 2 default music clips or provide a custom file path
- Choose between 2 animations, or configure custom text to display
- Don't like sound? Select `none` under Music to show the animation only
- Don't like seeing anything on screen? Disable the animation and hear only the soundtrack

## Commands
| Command | Description |
|---|---|
| `/djlust` | Show all available commands |
| `/djlust settings` | Open settings window |
| `/djlust test` | Test music & animation |
| `/djlust stop` | Stop music & animation |
| `/djlust status` | Show current detection state |
| `/djlust reset` | Reset detection state |
| `/djlust volume <0-100>` | Set volume (e.g. `/djlust volume 80`) |
| `/djlust minimap` | Toggle minimap button |
| `/djlust lock` / `/djlust unlock` | Lock/unlock animation position |
| `/djlust debug on/off` | Toggle debug output |

> `/djl` is available as an alias for `/djlust`

---

## How Detection Works (12.0.5+)

WoW 12.0.5 made `GetHaste()` return a secret (unreadable) value when called from addon code.
Earlier attempts to read `aura.spellId` from `C_UnitAuras` also hit secret-value protection.

1. Listen to `UNIT_AURA` via `RegisterUnitEvent("UNIT_AURA", "player")` (registered only in raid/party)
2. On each event, iterate `updateInfo.addedAuras`
3. For each aura, call `issecretvalue(aura.spellId)` — if true, skip it safely
4. If the spellId is a known Sated-type debuff, trigger music + animation

**Tracked debuff IDs:**
| Debuff | ID | Source |
|---|---|---|
| Sated | 57724 | Bloodlust (Shaman) |
| Exhaustion | 57723 | Heroism / Fury of the Aspects / Primal Rage |
| Temporal Displacement | 80354 | Time Warp (Mage) |
| Insanity | 95809 | Ancient Hysteria (Hunter Core Hound pet) |
| Fatigued | 160455 | Drums of the Maelstrom |
| Fatigued | 264689 | Hunter pet variant |
| Exhaustion | 390435 | Additional variant |

Music stops automatically after 42 seconds (lust duration is 40s across all variants).

---

## Known Limitations
- Only active in raid and party instances (not open world)
- Zoning in while already lusted will not trigger the animation (the `isFullUpdate` path is intentionally skipped as the buff is already mid-duration)
- No localization framework (planned for v1.5.0)

<sub>Inspired by Pedro Lust Weakaura ❤️</sub>
