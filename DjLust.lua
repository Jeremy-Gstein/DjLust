-- DjLust: Production version with music!
-- Detects Bloodlust (and similar spells) via aura detection and plays music
-- v1.2.0: Detection via issecretvalue() guard on UNIT_AURA addedAuras (ported from BudgetPedro)
-- v1.3.0: 12.1.0 fix — UNIT_AURA payload is now fully secret while auras are
--         secret, so detection moved to spell-ID polling via
--         C_UnitAuras.GetPlayerAuraBySpellID (spell-ID lookups are explicitly
--         still allowed in 12.1; non-secret spells return non-secrets).

local addonName, addon = ...

-- Sated-type debuff IDs. In 12.1 the UNIT_AURA payload is fully secret, but
-- these debuffs are non-secret auras and remain directly queryable by spell
-- ID. They are applied at the exact same instant as the lust buff itself.
local SATED_DEBUFF_IDS = {
    [57723]  = true, -- Exhaustion           (Heroism / Fury of the Aspects / Primal Rage)
    [57724]  = true, -- Sated                (Bloodlust)
    [80354]  = true, -- Temporal Displacement (Time Warp)
    [95809]  = true, -- Insanity             (Ancient Hysteria - Core Hound pet)
    [160455] = true, -- Fatigued             (Drums of the Maelstrom)
    [264689] = true, -- Fatigued             (Hunter pet variant)
    [390435] = true, -- Exhaustion           (additional variant)
}

-- Track state
local isLusted      = false
local activeDebufID = nil  -- Sated-type debuff ID that triggered detection
local lustEndTimer  = nil  -- C_Timer handle; stops music after lust duration
local debugAddon    = false

-- Sound handle management
local soundHandlePool = {}
local lastPlayTime    = 0
local PLAY_COOLDOWN   = 0.5

-- CVar caching
local originalChannelVolume = nil
local cvarDirty             = false

-- Sound channel -> CVar mapping
local CHANNEL_CVARS = {
    Master   = "Sound_MasterVolume",
    SFX      = "Sound_SFXVolume",
    Dialog   = "Sound_DialogVolume",
    Music    = "Sound_MusicVolume",
    Ambience = "Sound_AmbienceVolume",
}

-- Built-in music file paths (defined early, no DB dependency)
local BUILTIN_MUSIC = {
    chipi = "Interface\\AddOns\\DjLust\\chipilust.mp3",
    pedro = "Interface\\AddOns\\DjLust\\pedrolust.mp3",
}

-- Forward declarations so OnPlayerAuraUpdate (defined before the sound
-- functions) can reference them without resolving to nil globals.
local PlayDjLust, StopDjLust

-- Event frame
local frame = CreateFrame("Frame")

-- ─── DB INIT (deferred until SavedVariables are loaded) ──────────────────────
-- Mirrors BudgetPedro's EventUtil.ContinueOnAddOnLoaded pattern: all code that
-- touches DjLustDB runs after ADDON_LOADED, when SavedVariables are guaranteed
-- to be available. Without this, DjLustDB reads always return defaults.
EventUtil.ContinueOnAddOnLoaded(addonName, function()
    DjLustDB = DjLustDB or {}

    -- Schema migration v1 (theme/customSong) → v2 (animationStyle/music)
    if DjLustDB.theme and not DjLustDB.animationStyle then
        local styleMap = { chipi = "chipi", pedro = "pedro", text = "text", custom = "chipi" }
        DjLustDB.animationStyle = styleMap[DjLustDB.theme] or "chipi"
        if DjLustDB.customSong and DjLustDB.customSong ~= "" then
            DjLustDB.music = DjLustDB.customSong
        end
        DjLustDB.theme      = nil
        DjLustDB.customSong = nil
    end
    if DjLustDB.animationEnabled ~= nil then DjLustDB.animationEnabled = nil end
    -- Schema migration v2 (hasteThreshold) → v3 (aura-based, threshold unused)
    if DjLustDB.hasteThreshold ~= nil then DjLustDB.hasteThreshold = nil end

    DjLustDB.animationStyle = DjLustDB.animationStyle or "chipi"
    DjLustDB.music          = DjLustDB.music          or ""
    DjLustDB.partyText      = DjLustDB.partyText      or "PARTY TIME!"
    DjLustDB.volume         = DjLustDB.volume         or 1.0
    DjLustDB.soundChannel   = DjLustDB.soundChannel   or "Dialog"
    DjLustDB.muteSound      = DjLustDB.muteSound      or false
    DjLustDB.savedSongs     = DjLustDB.savedSongs     or {}
    if DjLustDB.animationLocked == nil then DjLustDB.animationLocked = false end
end)

-- Returns true + reason string if the given channel (or master) is muted/zero
local function IsChannelEffectivelyMuted(channel)
    if GetCVar("Sound_EnableAllSound") == "0" then
        return true, "all sound is globally disabled"
    end
    local masterVol = tonumber(GetCVar("Sound_MasterVolume")) or 0
    if masterVol <= 0 then
        return true, "master volume is 0"
    end
    local cvarName = CHANNEL_CVARS[channel]
    if cvarName then
        local vol = tonumber(GetCVar(cvarName)) or 0
        if vol <= 0 then
            return true, (channel .. " channel volume is 0")
        end
    end
    return false, nil
end

-- Get current music file path
local function GetMusicFile()
    if DjLustDB and DjLustDB.music and DjLustDB.music ~= "" then
        return DjLustDB.music
    end
    return BUILTIN_MUSIC.chipi
end

-- Debug print helper
function printDebug(...)
    if not debugAddon then return end
    print("|cff00bfff[DjLust]|r |cffff8800[DEBUG]|r", ...)
end

local function SetDebug(enabled)
    debugAddon = enabled
    print(string.format("|cff00bfff[DjLust]|r Debug mode %s",
        enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"))
end

-- ─── LUST DETECTION (12.1.0) ─────────────────────────────────────────────────
-- 12.1.0 broke payload-based detection: UNIT_AURA now delivers a fully secret
-- payload while auras are secret (combat, encounters, M+, PvP), and AuraData
-- structs in the payload are always fully secret. Reading updateInfo fields,
-- taking #updateInfo.addedAuras, or iterating it now errors — the old
-- issecretvalue()-per-spellId guard is useless because the WHOLE struct is
-- secret, not individual fields.
--
-- What still works: C_UnitAuras lookups by spell ID or spell name. Per the
-- 12.1 notes these "can still be called by addons as before (non-secret
-- spells still return non-secrets)". The Sated-type debuffs are non-secret
-- (their classification is unchanged from 12.0.5 — the only auras
-- re-classified in 12.1 were healer HoTs), so we use UNIT_AURA purely as a
-- "something changed on the player" signal and poll our known IDs directly.
--
-- Freshness check: the Sated debuff outlives the lust itself (minutes vs
-- 40s), so presence alone would retrigger on every aura update for the whole
-- debuff duration. Instead we compute the debuff's age from its own
-- duration/expirationTime and only fire when it was applied within the last
-- FRESH_WINDOW seconds. This replaces both the old addedAuras delta logic
-- and the isFullUpdate skip: zoning in or /reload mid-debuff yields an old
-- debuff, which is correctly ignored. Music still stops on a 42s timer since
-- the debuff can't tell us when the lust buff itself falls off.
local LUST_DURATION = 42  -- seconds; all lust variants last 40s base
local FRESH_WINDOW  = 2   -- seconds; max debuff age to count as a fresh lust

-- Secret-value guard. issecretvalue covers scalar secrets; issecrettable and
-- canaccessvalue exist in some builds for tables/access checks. All are
-- guarded so this is safe on any client version.
local function IsSecret(value)
    if issecretvalue and issecretvalue(value) then return true end
    if issecrettable and issecrettable(value) then return true end
    if canaccessvalue and not canaccessvalue(value) then return true end
    return false
end

-- Returns the spellId of a freshly-applied Sated-type debuff, or nil.
local function GetFreshSatedDebuff()
    for spellId in pairs(SATED_DEBUFF_IDS) do
        -- pcall: spell-ID lookups are explicitly still allowed in 12.1, but if
        -- Blizzard ever re-flags these debuffs the call must degrade silently
        -- instead of erroring on every UNIT_AURA.
        local ok, aura = pcall(C_UnitAuras.GetPlayerAuraBySpellID, spellId)
        -- IsSecret first: never compare a possibly-secret value to nil.
        if ok and not IsSecret(aura) and aura ~= nil
           and not IsSecret(aura.expirationTime) and not IsSecret(aura.duration) then
            local appliedAt = aura.expirationTime - aura.duration
            -- appliedAt > 0 filters out durationless auras (expirationTime == 0)
            if appliedAt > 0 and (GetTime() - appliedAt) <= FRESH_WINDOW then
                return spellId
            end
        end
    end
    return nil
end

-- UNIT_AURA handler. The updateInfo payload is fully secret in 12.1 — it is
-- not even passed in here. The event is only a trigger to re-poll.
local function OnPlayerAuraUpdate()
    if isLusted then return end

    local spellId = GetFreshSatedDebuff()
    if not spellId then return end

    isLusted      = true
    activeDebufID = spellId
    printDebug("Lust detected via spellId:", spellId)
    PlayDjLust()

    if lustEndTimer then lustEndTimer:Cancel() end
    lustEndTimer = C_Timer.NewTimer(LUST_DURATION, function()
        lustEndTimer  = nil
        isLusted      = false
        activeDebufID = nil
        StopDjLust()
        printDebug("Lust timer expired - stopping")
    end)
end

-- ─── SOUND / ANIMATION ───────────────────────────────────────────────────────

local function CleanupSoundHandles()
    for i = #soundHandlePool, 1, -1 do
        local handle = soundHandlePool[i]
        if handle then StopSound(handle) end
        soundHandlePool[i] = nil
    end
    wipe(soundHandlePool)
end

local function RestoreChannelVolume()
    if cvarDirty and originalChannelVolume then
        local channel  = DjLustDB.soundChannel or "Dialog"
        local cvarName = CHANNEL_CVARS[channel] or "Sound_DialogVolume"
        SetCVar(cvarName, tostring(originalChannelVolume))
        cvarDirty = false
        originalChannelVolume = nil
        printDebug("Channel volume restored for", channel)
    end
end

-- Play music only (no animation) — used by the Test Music button
function addon:TestMusic()
    local now = GetTime()
    if now - lastPlayTime < PLAY_COOLDOWN then return end
    lastPlayTime = now

    StopMusic()
    CleanupSoundHandles()

    if DjLustDB.muteSound then
        print("|cff00bfff[DjLust]|r Sound is muted.")
        return
    end

    local channel   = DjLustDB.soundChannel or "Dialog"
    local musicFile = GetMusicFile()

    local isMuted, muteReason = IsChannelEffectivelyMuted(channel)
    if isMuted then
        print("|cff00bfff[DjLust]|r |cffff8800[!] Cannot play music:|r " .. muteReason)
        return
    end

    local volume   = DjLustDB.volume or 1.0
    local cvarName = CHANNEL_CVARS[channel] or "Sound_DialogVolume"
    if not originalChannelVolume then
        originalChannelVolume = tonumber(GetCVar(cvarName)) or 1.0
    end
    local targetVolume = tostring(volume)
    if GetCVar(cvarName) ~= targetVolume then
        SetCVar(cvarName, targetVolume)
        cvarDirty = true
    end

    local willPlay, soundHandle = PlaySoundFile(musicFile, channel)
    if willPlay then
        soundHandlePool[1] = soundHandle
        print("|cff00bfff[DjLust]|r Testing music: " .. musicFile)
    else
        print("|cff00bfff[DjLust]|r |cffff8800[!] Failed to play:|r " .. musicFile)
        RestoreChannelVolume()
    end
end

-- Play bloodlust music and animation
PlayDjLust = function()
    local now = GetTime()
    if now - lastPlayTime < PLAY_COOLDOWN then
        printDebug("Music play blocked - cooldown active (", string.format("%.1f", PLAY_COOLDOWN - (now - lastPlayTime)), "s remaining)")
        return
    end
    lastPlayTime = now

    StopMusic()
    CleanupSoundHandles()

    if DjLustDB.animationStyle ~= "none" then
        if addon.StartAnimation then addon:StartAnimation() end
    end

    if DjLustDB.muteSound then
        printDebug("Sound muted by user preference - animation only")
        return
    end

    local channel   = DjLustDB.soundChannel or "Dialog"
    local musicFile = GetMusicFile()

    local isMuted, muteReason = IsChannelEffectivelyMuted(channel)
    if isMuted then
        print(string.format(
            "|cff00bfff[DjLust]|r |cffff8800[!] Cannot play music:|r %s.\n"
            .. "  Open |cffff8800/djlust settings|r to pick a different channel or mute sound intentionally.",
            muteReason
        ))
        return
    end

    local volume = (DjLustDB and DjLustDB.volume) or 1.0

    if type(musicFile) == "number" then
        PlaySound(musicFile, channel)
        printDebug("Playing default sound on channel:", channel)
    else
        local cvarName = CHANNEL_CVARS[channel] or "Sound_DialogVolume"

        if not originalChannelVolume then
            originalChannelVolume = tonumber(GetCVar(cvarName)) or 1.0
        end

        local targetVolume = tostring(volume)
        if GetCVar(cvarName) ~= targetVolume then
            SetCVar(cvarName, targetVolume)
            cvarDirty = true
        end

        local willPlay, soundHandle = PlaySoundFile(musicFile, channel)
        if willPlay then
            soundHandlePool[1] = soundHandle
            printDebug("Now playing:", musicFile, "on channel:", channel, "at volume", math.floor(volume * 100), "%")
        else
            print(string.format(
                "|cff00bfff[DjLust]|r |cffff8800[!] Failed to load music file.|r "
                .. "Check the file exists and the |cffff8800%s|r channel isn't muted. "
                .. "Use |cffff8800/djlust settings|r to change channel.",
                channel
            ))
            RestoreChannelVolume()
        end
    end
end

-- Stop bloodlust music (stops both music and animation when lust ends)
StopDjLust = function()
    CleanupSoundHandles()
    RestoreChannelVolume()
    if addon.StopAnimation then addon:StopAnimation() end
    printDebug("Music stopped - Bloodlust ended")
end

-- Stop music only (used by the Stop Music button — leaves animation running)
function addon:StopMusic()
    CleanupSoundHandles()
    RestoreChannelVolume()
    printDebug("Music stopped by user")
end

-- Update volume for currently playing music
function addon:UpdateVolume(volume)
    if soundHandlePool[1] and originalChannelVolume then
        local channel  = DjLustDB.soundChannel or "Dialog"
        local cvarName = CHANNEL_CVARS[channel] or "Sound_DialogVolume"
        SetCVar(cvarName, tostring(volume))
        cvarDirty = true
        printDebug("Volume updated to", math.floor(volume * 100), "%")
    end
end

-- Change which WoW sound channel music plays on
function addon:SetSoundChannel(channel)
    if CHANNEL_CVARS[channel] then
        RestoreChannelVolume()
        DjLustDB.soundChannel = channel
        printDebug("Sound channel set to:", channel)
    else
        print("|cff00bfff[DjLust]|r Invalid channel. Valid options: Master, SFX, Dialog, Music, Ambience")
    end
end

-- Toggle addon-level sound mute (animation still plays)
function addon:SetMuteSound(muted)
    DjLustDB.muteSound = muted
    if muted then
        CleanupSoundHandles()
        RestoreChannelVolume()
        print("|cff00bfff[DjLust]|r Sound |cffff0000muted|r - animation will still play.")
    else
        print("|cff00bfff[DjLust]|r Sound |cff00ff00enabled|r.")
    end
end

-- Update animation style
function addon:UpdateTheme(style)
    DjLustDB.animationStyle = style
    if addon.UpdateAnimationTexture then addon:UpdateAnimationTexture() end
end

-- Update selected music
function addon:UpdateMusic(path)
    DjLustDB.music = path
end

-- ─── COMPREHENSIVE CLEANUP ───────────────────────────────────────────────────
local function Cleanup()
    printDebug("Running comprehensive cleanup...")
    if lustEndTimer then lustEndTimer:Cancel() ; lustEndTimer = nil end
    StopDjLust()
    isLusted      = false
    activeDebufID = nil
    lastPlayTime  = 0
    collectgarbage("collect")
    C_Timer.After(0.1, function()
        collectgarbage("collect")
        printDebug("Garbage collection complete")
    end)
end

-- ─── EVENT REGISTRATION ──────────────────────────────────────────────────────
frame:RegisterEvent("LOADING_SCREEN_DISABLED")
frame:RegisterEvent("PLAYER_DEAD")
frame:RegisterEvent("PLAYER_LOGOUT")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "LOADING_SCREEN_DISABLED" then
        printDebug("DjLust loaded - Style:", DjLustDB.animationStyle or "chipi")
        -- Only register UNIT_AURA in raid/party instances.
        -- This avoids unnecessary aura processing in the open world.
        local _, instanceType = GetInstanceInfo()
        if instanceType == "raid" or instanceType == "party" then
            self:RegisterUnitEvent("UNIT_AURA", "player")
            printDebug("UNIT_AURA registered (instanceType:", instanceType, ")")
        else
            self:UnregisterEvent("UNIT_AURA")
            printDebug("UNIT_AURA not registered (instanceType:", instanceType, ")")
        end

    elseif event == "UNIT_AURA" then
        -- 12.1.0: the updateInfo payload is fully secret while auras are
        -- secret. Do NOT read it — the event is only a re-poll trigger.
        OnPlayerAuraUpdate()

    elseif event == "PLAYER_DEAD" then
        -- Stop music if the player dies mid-lust
        if lustEndTimer then lustEndTimer:Cancel() ; lustEndTimer = nil end
        isLusted      = false
        activeDebufID = nil
        StopDjLust()

    elseif event == "PLAYER_LOGOUT" then
        Cleanup()
    end
end)

-- ─── SLASH COMMANDS ──────────────────────────────────────────────────────────
SLASH_DJLUST1 = "/djl"
SLASH_DJLUST2 = "/djlust"
SlashCmdList["DJLUST"] = function(msg)
    if msg == "test" then
        local style = DjLustDB.animationStyle or "chipi"
        print("[DjLust] [TEST] Testing playback (style: " .. style .. ")")
        PlayDjLust()

    elseif msg == "stop" then
        print("[DjLust] [STOP] Stopping music...")
        addon:StopMusic()
        if lustEndTimer then lustEndTimer:Cancel() ; lustEndTimer = nil end
        isLusted      = false
        activeDebufID = nil

    elseif msg == "status" then
        print("|cff00bfff[DjLust]|r [STATUS]:")
        print("  Bloodlusted:", isLusted and "|cff00ff00YES|r" or "|cffff0000NO|r")
        if activeDebufID then
            print("  Triggered by:", SATED_DEBUFF_IDS[activeDebufID] or "Unknown", "(ID: " .. activeDebufID .. ")")
        end
        print("  In combat:", InCombatLockdown() and "YES" or "NO")
        print("  Music timer active:", lustEndTimer and "|cff00ff00YES|r" or "NO")
        print("  Sound handles active:", #soundHandlePool)
        print("  Last play:", string.format("%.1fs ago", GetTime() - lastPlayTime))
        print("  Detection method: spell-ID polling of Sated debuffs on UNIT_AURA (12.1)")
        print("  Tracking", (function() local n=0 for _ in pairs(SATED_DEBUFF_IDS) do n=n+1 end return n end)(), "debuff IDs")

    elseif msg == "reset" then
        print("[DjLust] [RESET] Resetting detection state...")
        if lustEndTimer then lustEndTimer:Cancel() ; lustEndTimer = nil end
        isLusted      = false
        activeDebufID = nil
        StopDjLust()
        print("|cff00bfff[DjLust]|r Detection reset. Watching for Sated-type debuffs.")

    elseif msg == "config" then
        print("|cff00bfff[DjLust]|r [CONFIG]\nConfiguration:")
        print("  Animation style:", DjLustDB.animationStyle or "chipi")
        print("  Music:", (DjLustDB.music ~= "") and DjLustDB.music or "(default: chipilust.mp3)")
        print("  Volume:", math.floor(DjLustDB.volume * 100) .. "%")
        print("  Detection: C_UnitAuras.GetPlayerAuraBySpellID polling on UNIT_AURA (12.1 secret-payload safe)")
        print("  Animation locked:", DjLustDB.animationLocked and "YES" or "NO")
        print("\nTo change settings, use /djlust settings")

    elseif msg:match("^debug") then
        local arg = msg:match("^debug%s*(%S*)")
        if arg == "on" then
            SetDebug(true)
        elseif arg == "off" then
            SetDebug(false)
        else
            print("|cff00bfff[DjLust]|r Usage:")
            print("  /djlust debug on  - Enable debug output")
            print("  /djlust debug off - Disable debug output")
        end

    elseif msg:match("^volume") then
        local vol = tonumber(msg:match("^volume%s+(%d+)"))
        if vol and vol >= 0 and vol <= 100 then
            DjLustDB.volume = vol / 100
            if addon.UpdateVolume then addon:UpdateVolume(DjLustDB.volume) end
            print(string.format("|cff00bfff[DjLust]|r Volume set to %d%%", vol))
        else
            print("|cff00bfff[DjLust]|r Usage: /djlust volume <0-100>")
            print(string.format("  Current volume: %d%%", math.floor((DjLustDB.volume or 1.0) * 100)))
        end

    elseif msg == "cleanup" then
        Cleanup()
        print("|cff00bfff[DjLust]|r Cleanup complete - all resources freed")

    elseif msg == "mem" then
        UpdateAddOnMemoryUsage()
        local mem = GetAddOnMemoryUsage("DjLust")
        print(string.format("|cff00bfff[DjLust]|r Memory usage: %.2f KB", mem))
        print("  Sound handles:", #soundHandlePool)

    else
        print("|cff00bfff[DjLust] [HELP]\nAvailable Commands:|r")
        print("  |cffff8800/djlust status|r - Show current status and active auras")
        print("  |cffff8800/djlust test|r - Test music playback")
        print("  |cffff8800/djlust stop|r - Stop music")
        print("  |cffff8800/djlust reset|r - Reset detection state")
        print("  |cffff8800/djlust config|r - Show configuration")
        print("  |cffff8800/djlust volume <0-100>|r - Set music volume")
        print("  |cffff8800/djlust debug on/off|r - Toggle debug output")
        print("  |cffff8800/djlust cleanup|r - Force cleanup and garbage collection")
        print("  |cffff8800/djlust mem|r - Show memory usage")
        print("|cff00bfff[TIP]|r |cffff8800/djl|r can be used as shortcut/alias of |cffff8800/djlust|r")
    end
end

print("|cff00bfff[DjLust]|r Type |cffff8800/djlust|r for all available commands.")
