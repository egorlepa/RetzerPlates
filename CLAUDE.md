# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What This Is

RetzerPlates is a World of Warcraft nameplate addon for Midnight (Interface 120000). It replaces Blizzard's default nameplates with a custom, hook-based system that external addons can extend.

## Deploy

```bash
./deploy.sh    # rsync src/ → WoW AddOns/RetzerPlates/
./watch.sh     # auto-deploy on file changes (requires inotify-tools)
```

No build step. Edit files in `src/`, deploy, `/reload` in-game. Open settings in-game with `/rp`.

## Architecture

**Load order** (defined in `RetzerPlates.toc`):
1. `libs/` — LibStub, AceDB-3.0, LibDataBroker, LibDBIcon
2. `Core.lua` — Event dispatcher, hook system, module system. Creates `RP` namespace (globally accessible as `RetzerPlates`).
3. `Config.lua` — Declarative schema (single source of truth for defaults + options UI). Plugins extend it via `RP:RegisterSchema()`.
4. `Options.lua` — Settings UI, profile management, minimap button. Auto-generates widgets from schema.
5. `Utilities.lua` — Shared factories (`RP.CreateIconFrame` for aura/CC icon frames).
6. `Hooks.lua` — Core hook implementations: plate construction, suppression, classification, layout, lifecycle no-ops.
7. `plugins/*.lua` — Feature plugins. Each registers its own hooks (`RegisterHook`) and/or wraps existing ones (`WrapHook`). Some plugins (Healthbar, CastBar, Name) own "default" hooks like `ConstructHealth` or `UpdateCastBar`.
8. `Layout.lua` — Right-side slot system and left anchor system for positioning elements beside the health bar.
9. `Nameplates.lua` — Thin orchestrator. Listens to WoW nameplate events, dispatches to hooks via `RP:Call(...)`. Contains zero logic.

**Key principle**: Nameplates.lua only wires WoW events to hook calls. All behavior lives in Hooks.lua or plugins.

## Hook System

```lua
RP:RegisterHook(name, fn)    -- Register implementation (Hooks.lua AND plugins)
RP:Call(name, ...)            -- Dispatch to current implementation (pcall-wrapped)
RP:SetHook(name, fn)          -- Full replacement (external addons)
RP:WrapHook(name, wrapper)    -- Wrap current: function(original, ...) (plugins use this)
RP:ResetHook(name)             -- Restore default
```

Plugin wrapping pattern:
```lua
RP:WrapHook("GetHealthColor", function(original, plate)
    if myCondition then return r, g, b end
    return original(plate)
end)
```

## Key Hooks

- **Construction**: `ConstructPlate`, `ConstructHealth`, `ConstructName`, `ConstructCastBar`, `ConstructHighlight`
- **Updates**: `UpdatePlate` (orchestrator), `UpdateHealth`, `UpdateHealthColor`, `UpdateName`, `UpdateLayout`, `UpdateCastBar`, `UpdateCastBarColor`
- **Color logic**: `GetHealthColor(plate) → r,g,b`, `GetNameColor(plate) → r,g,b`
- **Classification**: `GetFrameType(unit) → PLAYER|FRIENDLY_PLAYER|ENEMY_PLAYER|FRIENDLY_NPC|ENEMY_NPC`
- **Lifecycle**: `OnPlateCreated`, `OnPlateAdded`, `OnPlateRemoved`
- **Cast bar**: `StartCastBarTicker`, `StopCastBar`, `UpdateDebugCastBar`
- **Layout**: `OnLayoutChanged`, `OnLeftLayoutChanged`, `GetRightAnchor`
- **Setup**: `SetCVars`, `SetClickSpace`, `SuppressBlizzardPlate`

## Schema-Driven Config

Config uses a declarative schema system. Each section defines entries with `key`, `default`, `label`, and optional constraints (`min`, `max`, `step`). Options.lua auto-generates the UI from this schema.

Plugins register their own config sections:
```lua
RP:RegisterSchema("threat", {
    _meta = { label = "Threat" },
    { key = "enabled", default = true, label = "Enable Threat Colors" },
    { key = "colorTankAggro", default = { r = 0.29, g = 0.69, b = 0.30 }, label = "Has Aggro" },
})
```

Saved to `RetzerPlatesDB` via AceDB. Access at runtime via `RP.db.<section>.<key>`.

## Layout System

`Layout.lua` provides two positioning systems for elements beside the health bar:

- **Right slots**: Ordered chain (raid marker, quest icon, CC, etc.). Plugins register with `RP:RegisterRightSlot(name)`, assign frames with `RP:SetSlotFrame()`, toggle with `RP:SetSlotActive()`. Registration order = TOC load order.
- **Left anchor**: Single element (cast bar icon). Set with `RP:SetLeftAnchor()`, clear with `RP:ClearLeftAnchor()`.

## Passive Units

`RP.IsPassive(plate)` — true when `not UnitCanAttack("player", unit)`. These get name-only plates (health bar hidden). Covers friendly NPCs and neutral non-attackable NPCs.

## Midnight / Secret Values

WoW Midnight taints health values and certain booleans. Key workarounds:
- Use `C_CurveUtil.EvaluateColorValueFromBoolean(secretBool, trueVal, falseVal)` for secret boolean branching
- Use `UnitCastingDuration`/`UnitChannelDuration` + `SetTimerDuration` for cast bar progress
- Pass `UnitHealth()`/`UnitHealthMax()` directly to C API (SetMinMaxValues/SetValue) — do not compare in Lua
- Use `issecretvalue(val)` to check if a value is tainted

## Plugin Pattern

Plugins live in `src/plugins/`. They load after Hooks.lua but before Nameplates.lua (per TOC order). A plugin typically:
1. Defines a `@class` annotation for its config
2. Calls `RP:RegisterSchema()` to declare config + UI
3. Calls `RP:RegisterHook()` for new hooks it owns, and/or `RP:WrapHook()` to extend existing hooks

## References

`references/` contains Plater source code for reference. Not part of the addon.
