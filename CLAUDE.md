# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

RetzerPlates is a World of Warcraft nameplate addon for Midnight (Interface 120000). It replaces Blizzard's default nameplates with a custom, hook-based system that external addons can extend.

## Deploy

```bash
./deploy.sh  # rsync src/ → WoW AddOns/RetzerPlates/
```

No build step. Edit files in `src/`, deploy, `/reload` in-game.

## Architecture

**Load order** (defined in `RetzerPlates.toc`):
1. `Core.lua` — Event dispatcher, hook system, module system. Creates `RP` namespace.
2. `Config.lua` — Default config table. Registers `ApplyDefaults` hook. Settings live in `RP.db.<section>.<key>`.
3. `Hooks.lua` — All default hook implementations (construction, updates, coloring, CVars).
4. `plugins/*.lua` — Feature plugins that wrap hooks.
5. `Nameplates.lua` — Thin orchestrator. Listens to WoW nameplate events, dispatches to hooks via `RP:Call(...)`. Manages `NP.plates[frame]` registry.

**Key principle**: Nameplates.lua contains zero logic — it only wires WoW events to hook calls. All behavior lives in Hooks.lua (defaults) or plugins (extensions).

## Hook System

```lua
RP:RegisterHook(name, fn)    -- Register default implementation (used in Hooks.lua)
RP:Call(name, ...)            -- Dispatch to current implementation
RP:SetHook(name, fn)          -- Full replacement (external addons)
RP:WrapHook(name, wrapper)    -- Wrap current: function(original, ...) (plugins use this)
RP:ResetHook(name)             -- Restore default
```

Plugins extend behavior by wrapping hooks. Example pattern:
```lua
RP:WrapHook("GetHealthColor", function(original, plate)
    if myCondition then return r, g, b end
    return original(plate)
end)
```

## Key Hooks

- **Construction**: `ConstructPlate`, `ConstructHealth`, `ConstructName`, `ConstructCastBar`, `ConstructHighlight`
- **Updates**: `UpdatePlate` (orchestrator), `UpdateHealth`, `UpdateHealthColor`, `UpdateName`, `UpdateLayout`, `UpdateCastBar`
- **Color logic**: `GetHealthColor(plate) → r,g,b`, `GetNameColor(plate) → r,g,b`
- **Classification**: `GetFrameType(unit) → PLAYER|FRIENDLY_PLAYER|ENEMY_PLAYER|FRIENDLY_NPC|ENEMY_NPC`
- **Lifecycle**: `OnPlateCreated`, `OnPlateAdded`, `OnPlateRemoved`, `OnPlateEnter`, `OnPlateLeave`
- **Setup**: `SetCVars`, `SetClickSpace`, `ApplyDefaults`, `SuppressBlizzardPlate`

## Passive Units

`IsPassive(plate)` — true when `not UnitCanAttack("player", unit)`. These get name-only plates (health bar hidden). Covers friendly NPCs and neutral non-attackable NPCs.

## Midnight / Secret Values

WoW Midnight taints health values. Use `C_CurveUtil` for threshold comparisons and `SetTimerDuration` for castbar progress. Do not compare `UnitHealth()` return values directly in Lua.

## Plugin Pattern

Plugins live in `src/plugins/`. They wrap hooks — no registration API needed. They load after Hooks.lua but before Nameplates.lua (per TOC order). Current plugins:
- `ThreatColoring.lua` — wraps `GetHealthColor` for threat colors
- `QuestIndicator.lua` — wraps construction/update hooks, adds quest icon + progress
- `ExecuteIndicator.lua` — wraps health hooks, adds execute threshold marks

## Config

Defaults in `Config.lua`, saved to `RetzerPlatesDB`. Access via `RP.db.healthbar.colorByClass`, `RP.db.quest.enabled`, etc. Sections: `general`, `healthbar`, `execute`, `castbar`, `name`, `quest`, `debug`.

## References

`references/` contains Plater source code for reference. Not part of the addon.
