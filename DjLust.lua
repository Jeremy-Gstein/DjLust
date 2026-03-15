-- DjLust: Production version with music!
-- Detects Bloodlust (and similar spells) via haste changes and plays music

local addonName, addon = ...

-- Initialize saved variables with defaults
DjLustDB = DjLustDB or {}

-- Schema migration from v1 (theme/customSong) to v2 (animationStyle/music)
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

DjLustDB.animationStyle = DjLustDB.animationStyle or "chipi"
DjLustDB.music          = DjLustDB.music          or ""
DjLustDB.partyText      = DjLustDB.partyText      or "PARTY TIME!"
DjLustDB.volume         = DjLustDB.volume         or 1.0
DjLustDB.soundChannel   = DjLustDB.soundChannel   or "Dialog"
DjLustDB.muteSound      = DjLustDB.muteSound      or false
DjLustDB.savedSongs     = DjLustDB.savedSongs     or {}
DjLustDB.hasteThreshold = DjLustDB.hasteThreshold or 25
if DjLustDB.animationLocked == nil then DjLustDB.animationLocked = false end

-- Built-in music file paths
local BUILTIN_MUSIC = {
    chipi = "Interface\\AddOns\\DjLust\\chipilust.mp3",
    pedro = "Interface\\AddOns\\DjLust\\pedrolust.mp3",
}

-- Track state
local isLusted = false
local baselineHaste = nil
local hasteCheckTimer = nil
local debugAddon = false
local bloodlustCooldown = 0

-- Sound handle management 
local soundHandlePool = {}
local lastPlayTime = 0
local PLAY_COOLDOWN = 0.5  -- Prevent rapid-fire plays

-- CVar caching 
local originalChannelVolume = nil
local cvarDirty = false

-- Sound channel -> CVar mapping
local CHANNEL_CVARS = {
    Master   = "Sound_MasterVolume",
    SFX      = "Sound_SFXVolume",
    Dialog   = "Sound_DialogVolume",
    Music    = "Sound_MusicVolume",
    Ambience = "Sound_AmbienceVolume",
}

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

-- Configuration
local CHECK_INTERVAL = 0.5
local BLOODLUST_COOLDOWN = 30

-- Get current music file path
local function GetMusicFile()
    -- User-selected song takes priority (full path already stored)
    if DjLustDB.music and DjLustDB.music ~= "" then
        return DjLustDB.music
    end
    -- Default: chipi song
    return BUILTIN_MUSIC.chipi
end

-- Debug print helper
function printDebug(...)
    if not debugAddon then return end
    local prefix = "|cff00bfff[DjLust]|r |cffff8800[DEBUG]|r"
    print(prefix, ...)
end

local function SetDebug(enabled)
    debugAddon = enabled
    print(string.format(
        "|cff00bfff[DjLust]|r Debug mode %s",
        enabled and "|cff00ff00ENABLED|r" or "|cffff0000DISABLED|r"
    ))
end

-- Event frame
local frame = CreateFrame("Frame")

-- Get current haste percentage
local function GetCurrentHaste()
    return GetHaste() or 0
end

-- Cleanup all sound handles
local function CleanupSoundHandles()
    for i = #soundHandlePool, 1, -1 do
        local handle = soundHandlePool[i]
        if handle then
            StopSound(handle)
        end
        soundHandlePool[i] = nil
    end
    
    -- Force table cleanup
    wipe(soundHandlePool)
end

-- Restore CVar only when needed
local function RestoreChannelVolume()
    if cvarDirty and originalChannelVolume then
        local channel = DjLustDB.soundChannel or "Dialog"
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

    local volume  = DjLustDB.volume or 1.0
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
local function PlayDjLust()
    -- DEBOUNCE: Prevent rapid-fire calls
    local now = GetTime()
    if now - lastPlayTime < PLAY_COOLDOWN then
        printDebug("Music play blocked - cooldown active (", string.format("%.1f", PLAY_COOLDOWN - (now - lastPlayTime)), "s remaining)")
        return
    end
    lastPlayTime = now

    -- Stop any currently playing music and cleanup handles
    StopMusic()
    CleanupSoundHandles()

    -- ── ANIMATION ────────────────────────────────────────────────────────────
    -- Always start animation first, regardless of sound outcome.
    if DjLustDB.animationStyle ~= "none" then
        if addon.StartAnimation then
            addon:StartAnimation()
        end
    end

    -- ── SOUND ────────────────────────────────────────────────────────────────
    -- Respect the addon-level mute flag
    if DjLustDB.muteSound then
        printDebug("Sound muted by user preference - animation only")
        return
    end

    local channel = DjLustDB.soundChannel or "Dialog"
    local musicFile = GetMusicFile()

    -- Check whether the WoW sound channel is actually audible
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

        -- Cache original volume for restoration
        if not originalChannelVolume then
            originalChannelVolume = tonumber(GetCVar(cvarName)) or 1.0
        end

        -- Only set CVar if actually different
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
            -- Music failed but animation is already running – just warn.
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

-- Stop bloodlust music (internal: stops both music and animation when lust ends)
local function StopDjLust()
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
        local channel = DjLustDB.soundChannel or "Dialog"
        local cvarName = CHANNEL_CVARS[channel] or "Sound_DialogVolume"
        SetCVar(cvarName, tostring(volume))
        cvarDirty = true
        printDebug("Volume updated to", math.floor(volume * 100), "%")
    end
end

-- Change which WoW sound channel music plays on
function addon:SetSoundChannel(channel)
    if CHANNEL_CVARS[channel] then
        -- Restore old channel before switching
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
    if addon.UpdateAnimationTexture then
        addon:UpdateAnimationTexture()
    end
end

-- Update selected music
function addon:UpdateMusic(path)
    DjLustDB.music = path
end

-- Check for sudden haste increase
local function CheckHasteForBloodlust()
    if bloodlustCooldown > 0 then
        bloodlustCooldown = bloodlustCooldown - CHECK_INTERVAL
        return isLusted
    end
    
    local currentHaste = GetCurrentHaste()
    
    if not baselineHaste then
        baselineHaste = currentHaste
        return false
    end
    
    -- Use configured threshold (convert from % to decimal)
    local hasteThreshold = (DjLustDB.hasteThreshold or 25) / 100
    local hasteIncrease = (currentHaste - baselineHaste) / 100
    
    if hasteIncrease >= hasteThreshold and not isLusted then
        isLusted = true
        bloodlustCooldown = BLOODLUST_COOLDOWN
        PlayDjLust()
        return true
    end
    
    if hasteIncrease < (hasteThreshold / 2) and isLusted then
        isLusted = false
        baselineHaste = currentHaste
        bloodlustCooldown = 0
        StopDjLust()
        return false
    end
    
    return isLusted
end

-- Start haste monitoring (combat only)
local function StartHasteMonitoring()
    if hasteCheckTimer then
        hasteCheckTimer:Cancel()
        hasteCheckTimer = nil
    end

    hasteCheckTimer = C_Timer.NewTicker(CHECK_INTERVAL, CheckHasteForBloodlust)
end

-- Stop haste monitoring
local function StopHasteMonitoring()
    if hasteCheckTimer then
        hasteCheckTimer:Cancel()
        hasteCheckTimer = nil
    end
end

-- COMPREHENSIVE CLEANUP 
local function Cleanup()
    printDebug("Running comprehensive cleanup...")
    
    -- Stop monitoring
    StopHasteMonitoring()
    
    -- Stop music and sounds
    StopDjLust()
    
    -- Reset state
    isLusted = false
    baselineHaste = nil
    bloodlustCooldown = 0
    lastPlayTime = 0
    
    -- Force garbage collection (aggressive)
    collectgarbage("collect")
    
    -- Second pass after short delay
    C_Timer.After(0.1, function()
        collectgarbage("collect")
        printDebug("Garbage collection complete")
    end)
end

-- Event handler
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED")
frame:RegisterEvent("PLAYER_REGEN_ENABLED")
frame:RegisterEvent("PLAYER_LOGOUT")
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        printDebug("DjLust loaded - Style:", DjLustDB.animationStyle or "chipi")
        baselineHaste = GetCurrentHaste()
        -- No ticker on load - will start when combat begins
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat: snapshot baseline and start polling
        baselineHaste = GetCurrentHaste()
        StartHasteMonitoring()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Leaving combat: stop polling immediately (0 CPU while idle)
        StopHasteMonitoring()
        if isLusted then
            isLusted = false
            StopDjLust()
        end
        baselineHaste = GetCurrentHaste()
        bloodlustCooldown = 0
    elseif event == "PLAYER_LOGOUT" then
        Cleanup()
    end
end)

-- Slash commands
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
        isLusted = false
        bloodlustCooldown = 0
    elseif msg == "status" then
        print("[DjLust] [STATUS]:")
        print("  Bloodlusted:", isLusted and "YES" or "NO")
        print("  In combat:", InCombatLockdown() and "YES" or "NO")
        print(string.format("  Baseline haste: %.1f%%", baselineHaste or 0))
        print(string.format("  Current haste: %.1f%%", GetCurrentHaste()))
        local diff = baselineHaste and (GetCurrentHaste() - baselineHaste) or 0
        print(string.format("  Haste difference: %.1f%%", diff))
        print(string.format("  Cooldown remaining: %.1fs", bloodlustCooldown))
        print("  Ticker active:", hasteCheckTimer and "YES" or "NO")
        print("  Sound handles active:", #soundHandlePool)
        print("  Last play:", string.format("%.1fs ago", GetTime() - lastPlayTime))
    elseif msg == "reset" then
        print("[DjLust] [RESET] Resetting detection...")
        baselineHaste = GetCurrentHaste()
        isLusted = false
        bloodlustCooldown = 0
        StopDjLust()
    elseif msg == "config" then
        print("[DjLust] [CONFIG]\nConfiguration:")
        print("  Animation style:", DjLustDB.animationStyle or "chipi")
        print("  Music:", (DjLustDB.music ~= "") and DjLustDB.music or "(default: chipilust.mp3)")
        print("  Volume:", math.floor(DjLustDB.volume * 100) .. "%")
        print("  Haste threshold:", (DjLustDB.hasteThreshold or 25) .. "%")
        print("  Check interval:", CHECK_INTERVAL .. "s")
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
            if addon.UpdateVolume then
                addon:UpdateVolume(DjLustDB.volume)
            end
            print(string.format("|cff00bfff[DjLust]|r Volume set to %d%%", vol))
        else
            print("|cff00bfff[DjLust]|r Usage: /djlust volume <0-100>")
            print(string.format("  Current volume: %d%%", math.floor((DjLustDB.volume or 1.0) * 100)))
        end
    elseif msg == "cleanup" then
        Cleanup()
        print("|cff00bfff[DjLust]|r Cleanup complete - all resources freed")
    elseif msg == "mem" then
        -- Memory diagnostic
        UpdateAddOnMemoryUsage()
        local mem = GetAddOnMemoryUsage("DjLust")
        print(string.format("|cff00bfff[DjLust]|r Memory usage: %.2f KB", mem))
        print("  Sound handles:", #soundHandlePool)
        print("  Ticker active:", hasteCheckTimer and "YES" or "NO")
    else
        print("|cff00bfff[DjLust] [HELP]\nAvailable Commands:|r")
        print("  |cffff8800/djlust status|r - Show current status")
        print("  |cffff8800/djlust test|r - Test music playback")
        print("  |cffff8800/djlust stop|r - Stop music")
        print("  |cffff8800/djlust reset|r - Reset detection")
        print("  |cffff8800/djlust config|r - Show configuration")
        print("  |cffff8800/djlust volume <0-100>|r - Set music volume")
        print("  |cffff8800/djlust debug on/off|r - Toggle debug output")
        print("  |cffff8800/djlust cleanup|r - Force cleanup and garbage collection")
        print("  |cffff8800/djlust mem|r - Show memory usage")
        print("|cff00bfff[TIP]|r |cffff8800/djl|r can be used as shortcut/alias of |cffff8800/djlust|r")
    end
end

print("|cff00bfff[DjLust]|r Type |cffff8800/djlust|r for all available commands.")
