-- DjLust: Production version with music!
-- Detects Bloodlust (and similar spells) via haste changes and plays music

local addonName, addon = ...

-- Track state
local isLusted = false
local baselineHaste = nil
local hasteCheckTimer = nil
local musicHandle = nil
local debugAddon = false

-- Configuration
local HASTE_THRESHOLD = 0.25 -- Detect increases of 25%+ (bloodlust is 30%)
local CHECK_INTERVAL = 0.3   -- Check every 0.3 seconds

-- Music file path 
-- You can add your own mp3 here just rename the file to Music.mp3 (see below)
-- Put your song here: "Interface\\AddOns\\DjLust\\Music.mp3" 
-- (NOTE: you must rename the file to Music.mp3 OR change the MUSIC_FILE var)
-- local MUSIC_FILE = 8959 -- Sound kit ID for epic war horn (no mp3? uncomment to use builtin)
local MUSIC_FILE = "Interface\\AddOns\\DjLust\\Music.mp3"

-- DEBUGGING PRINT (disabled in prod)
-- Debug print helper (orange color)
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

-- Play bloodlust music
local function PlayDjLust()
    -- Stop any currently playing music
    StopMusic()
    
    -- Play the sound effect (or music file if you specify a path)
    if type(MUSIC_FILE) == "number" then
        -- Using sound kit ID
        PlaySound(MUSIC_FILE, "Master")
        printDebug("Playing default sound!")
    else
        -- Using file path
        local willPlay, soundHandle = PlaySoundFile(MUSIC_FILE, "Master")
        if willPlay then
            musicHandle = soundHandle
            printDebug("Now playing: ", MUSIC_FILE)
        else
            printDebug("Failed to play music file: ", MUSIC_FILE)
        end
    end
end

-- Stop bloodlust music
local function StopDjLust()
    if musicHandle then
        StopSound(musicHandle)
        musicHandle = nil
    end
    printDebug("Music stopped - Bloodlust ended")
end

-- Check for sudden haste increase
local function CheckHasteForBloodlust()
    local currentHaste = GetCurrentHaste()
    
    -- Initialize baseline haste state if needed
    if not baselineHaste then
        baselineHaste = currentHaste
        return false
    end
    
    -- Calculate the increase (as decimal, e.g. 0.30 for 30%)
    local hasteIncrease = (currentHaste - baselineHaste) / 100
    
    -- Bloodlust state detected
    if hasteIncrease >= HASTE_THRESHOLD and not isLusted then
        isLusted = true
        PlayDjLust()
        return true
    end
    
    -- Bloodlust state ended
    if hasteIncrease < (HASTE_THRESHOLD / 2) and isLusted then
        isLusted = false
        baselineHaste = currentHaste
        StopDjLust()
        return false
    end
    
    return isLusted
end

-- Periodic haste checker
local function StartHasteMonitoring()
    if hasteCheckTimer then
        hasteCheckTimer:Cancel()
    end
    
    hasteCheckTimer = C_Timer.NewTicker(CHECK_INTERVAL, function()
        if InCombatLockdown() then
            CheckHasteForBloodlust()
        else
            -- Out of combat, update baseline (no spam)
            if not isLusted then
                baselineHaste = GetCurrentHaste()
            end
        end
    end)
end

-- Event handler
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("PLAYER_REGEN_DISABLED") -- Entered combat
frame:RegisterEvent("PLAYER_REGEN_ENABLED")  -- Left combat
frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" then
        printDebug("Loaded with Track: ", MUSIC_FILE)
        baselineHaste = GetCurrentHaste()
        StartHasteMonitoring()
    elseif event == "PLAYER_REGEN_DISABLED" then
        -- Entering combat - set base haste sample
        baselineHaste = GetCurrentHaste()
    elseif event == "PLAYER_REGEN_ENABLED" then
        -- Left combat
        if isLusted then
            isLusted = false
            StopDjLust()
        end
        baselineHaste = GetCurrentHaste()
    end
end)

-- Slash commands
SLASH_DJLUST1 = "/djl"
SLASH_DJLUST2 = "/djlust"
SlashCmdList["DJLUST"] = function(msg)
    if msg == "test" then
        print("[DjLust] [TEST] Testing music playback...")
        PlayDjLust()
    elseif msg == "stop" then
        print("[DjLust] [STOP] Stopping music...")
        StopDjLust()
        isLusted = false
    elseif msg == "status" then
        print("[DjLust] [STATUS]:")
        print("  Bloodlusted:", isLusted and "YES" or "NO")
        print("  In combat:", InCombatLockdown() and "YES" or "NO")
        print(string.format("  Baseline haste: %.1f%%", baselineHaste or 0))
        print(string.format("  Current haste: %.1f%%", GetCurrentHaste()))
        local diff = baselineHaste and (GetCurrentHaste() - baselineHaste) or 0
        print(string.format("  Haste difference: %.1f%%", diff))
    elseif msg == "reset" then
        print("[DjLust] [RESET] Resetting detection...")
        baselineHaste = GetCurrentHaste()
        isLusted = false
        StopDjLust()
    elseif msg == "config" then
        print("[DjLust] [CONFIG]\nConfiguration:")
        print("  Music file:", type(MUSIC_FILE) == "number" and ("Sound ID: " .. MUSIC_FILE) or MUSIC_FILE)
        print("  Haste threshold:", (HASTE_THRESHOLD * 100) .. "%")
        print("  Check interval:", CHECK_INTERVAL .. "s")
        print("\nTo use custom music:")
        print("1. Put your MP3 in: Interface/AddOns/DjLust/")
        print("2. Edit DjLust.lua and change MUSIC_FILE to:")
        print('   "Interface\\\\AddOns\\\\DjLust\\\\Music.mp3"')
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

    else
        print("|cff00bfff[DjLust] [HELP]\nAvailable Commands:|r")
        print("  |cffff8800/djlust status|r - Show current status")
        print("  |cffff8800/djlust test|r - Test music playback for .mp3 @ ", MUSIC_FILE)
        print("  |cffff8800/djlust stop|r - Stop music")
        print("  |cffff8800/djlust reset|r - Reset detection")
        print("  |cffff8800/djlust config|r - Show configuration")
        print("  |cffff8800/djlust debug on|r  - Enable debug output")
        print("  |cffff8800/djlust debug off|r - Disable debug output")
        print("|cff00bfff[TIP]|r |cffff8800/djl|r can be used as shortcut/alias of |cffff8800/djlust|r")
    end
end

print("|cff00bfff[DjLust]|r Type |cffff8800/djlust|r for all available commands.")
