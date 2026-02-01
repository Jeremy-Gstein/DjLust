-- DjLust: Production version with music!
-- Detects Bloodlust (and similar spells) via haste changes and plays music

local addonName, addon = ...

-- Initialize saved variables with defaults
DjLustDB = DjLustDB or {}
DjLustDB.volume = DjLustDB.volume or 1.0
DjLustDB.theme = DjLustDB.theme or "chipi"

-- Theme configurations
local THEMES = {
    chipi = {
        name = "Chipi Chipi",
        music = "Interface\\AddOns\\DjLust\\Music.mp3",
        animation = "Interface\\AddOns\\DjLust\\chipi.tga",
    },
    pedro = {
        name = "Pedro",
        music = "Interface\\AddOns\\DjLust\\pedrolust.mp3",
        animation = "Interface\\AddOns\\DjLust\\pedrolust.tga",
    },
}

-- Track state
local isLusted = false
local baselineHaste = nil
local hasteCheckTimer = nil
local musicHandle = nil
local debugAddon = false

-- Configuration
local HASTE_THRESHOLD = 0.25 -- Detect increases of 25%+ (bloodlust is 30%)
local CHECK_INTERVAL = 0.3   -- Check every 0.3 seconds

-- Get current theme's music file
local function GetMusicFile()
    local theme = THEMES[DjLustDB.theme] or THEMES.chipi
    return theme.music
end

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

-- Track original volume for restoration
local originalDialogVolume = nil

-- Play bloodlust music
local function PlayDjLust()
    -- Stop any currently playing music
    StopMusic()
    
    -- Get volume from settings (default to 1.0 if not set)
    local volume = (DjLustDB and DjLustDB.volume) or 1.0
    
    -- Get music file from current theme
    local musicFile = GetMusicFile()
    
    -- Play the sound effect (or music file if you specify a path)
    if type(musicFile) == "number" then
        -- Using sound kit ID
        PlaySound(musicFile, "Dialog")
        printDebug("Playing default sound!")
    else
        -- Save original Dialog volume
        originalDialogVolume = tonumber(GetCVar("Sound_DialogVolume")) or 1.0
        
        -- Set Dialog volume to our desired level
        SetCVar("Sound_DialogVolume", tostring(volume))
        
        -- Play the music file on Dialog channel
        local willPlay, soundHandle = PlaySoundFile(musicFile, "Dialog")
        if willPlay then
            musicHandle = soundHandle
            local themeName = THEMES[DjLustDB.theme] and THEMES[DjLustDB.theme].name or "Unknown"
            printDebug("Now playing: ", themeName, " at volume ", math.floor(volume * 100), "% (Dialog channel)")
            
            -- Trigger animation update
            if addon.StartAnimation then
                addon:StartAnimation()
            end
        else
            printDebug("Failed to play music file: ", musicFile)
            -- Restore volume if playback failed
            if originalDialogVolume then
                SetCVar("Sound_DialogVolume", tostring(originalDialogVolume))
                originalDialogVolume = nil
            end
        end
    end
end

-- Stop bloodlust music
local function StopDjLust()
    if musicHandle then
        StopSound(musicHandle)
        musicHandle = nil
    end
    
    -- Restore original Dialog volume
    if originalDialogVolume then
        SetCVar("Sound_DialogVolume", tostring(originalDialogVolume))
        originalDialogVolume = nil
    end
    
    -- Stop animation
    if addon.StopAnimation then
        addon:StopAnimation()
    end
    
    printDebug("Music stopped - Bloodlust ended")
end

-- Update volume for currently playing music
function addon:UpdateVolume(volume)
    if musicHandle then
        -- Update the Dialog volume while music is playing
        SetCVar("Sound_DialogVolume", tostring(volume))
        printDebug("Volume updated to ", math.floor(volume * 100), "%")
    end
end

-- Update theme (will apply on next Bloodlust)
function addon:UpdateTheme(theme)
    if THEMES[theme] then
        DjLustDB.theme = theme
        printDebug("Theme updated to: ", THEMES[theme].name)
        
        -- If animation is currently playing, update it now
        if addon.UpdateAnimationTexture then
            addon:UpdateAnimationTexture()
        end
    end
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
        local themeName = THEMES[DjLustDB.theme] and THEMES[DjLustDB.theme].name or "Unknown"
        print("[DjLust] [TEST] Testing music playback with theme: " .. themeName)
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
        local currentTheme = THEMES[DjLustDB.theme] or THEMES.chipi
        print("  Current theme:", currentTheme.name)
        print("  Music file:", currentTheme.music)
        print("  Animation file:", currentTheme.animation)
        print("  Volume:", math.floor(DjLustDB.volume * 100) .. "%")
        print("  Haste threshold:", (HASTE_THRESHOLD * 100) .. "%")
        print("  Check interval:", CHECK_INTERVAL .. "s")
        print("\nAvailable themes:")
        for key, theme in pairs(THEMES) do
            local marker = (key == DjLustDB.theme) and " [ACTIVE]" or ""
            print("  " .. key .. ": " .. theme.name .. marker)
        end
        print("\nTo change theme, use /djlust settings")
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
    else
        print("|cff00bfff[DjLust] [HELP]\nAvailable Commands:|r")
        print("  |cffff8800/djlust status|r - Show current status")
        print("  |cffff8800/djlust test|r - Test music playback for .mp3 @ ", MUSIC_FILE)
        print("  |cffff8800/djlust stop|r - Stop music")
        print("  |cffff8800/djlust reset|r - Reset detection")
        print("  |cffff8800/djlust config|r - Show configuration")
        print("  |cffff8800/djlust volume <0-100>|r - Set music volume")
        print("  |cffff8800/djlust debug on|r  - Enable debug output")
        print("  |cffff8800/djlust debug off|r - Disable debug output")
        print("|cff00bfff[TIP]|r |cffff8800/djl|r can be used as shortcut/alias of |cffff8800/djlust|r")
    end
end

print("|cff00bfff[DjLust]|r Type |cffff8800/djlust|r for all available commands.")
