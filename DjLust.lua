-- DjLust: Production version with music!
-- Detects Bloodlust (and similar spells) via haste changes and plays music
-- MEMORY LEAK FIXED VERSION - Aggressive cleanup

local addonName, addon = ...

-- Initialize saved variables with defaults
DjLustDB = DjLustDB or {}
DjLustDB.volume = DjLustDB.volume or 1.0
DjLustDB.theme = DjLustDB.theme or "chipi"
DjLustDB.customSong = DjLustDB.customSong or ""

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
    custom = {
        name = "Custom Song",
        music = nil,  -- Set dynamically from DjLustDB.customSong
        animation = "Interface\\AddOns\\DjLust\\pedrolust.tga", 
    },
}

-- Track state
local isLusted = false
local baselineHaste = nil
local hasteCheckTimer = nil
local debugAddon = false
local bloodlustCooldown = 0

-- Sound handle management (MEMORY LEAK FIX)
local soundHandlePool = {}
local lastPlayTime = 0
local PLAY_COOLDOWN = 0.5  -- Prevent rapid-fire plays

-- CVar caching (MEMORY LEAK FIX)
local originalDialogVolume = nil
local cvarDirty = false

-- Configuration
local HASTE_THRESHOLD = 0.25
local CHECK_INTERVAL = 0.5
local BLOODLUST_COOLDOWN = 30

-- Get current theme's music file
local function GetMusicFile()
    local theme = THEMES[DjLustDB.theme] or THEMES.chipi
    
    -- For custom theme, use the selected custom song
    if DjLustDB.theme == "custom" then
        if DjLustDB.customSong and DjLustDB.customSong ~= "" then
            return "Interface\\AddOns\\Songs\\" .. DjLustDB.customSong
        else
            printDebug("Custom theme selected but no song chosen, using default")
            return THEMES.chipi.music
        end
    end
    
    return theme.music
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

-- MEMORY LEAK FIX: Cleanup all sound handles
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

-- MEMORY LEAK FIX: Restore CVar only when needed
local function RestoreDialogVolume()
    if cvarDirty and originalDialogVolume then
        SetCVar("Sound_DialogVolume", tostring(originalDialogVolume))
        cvarDirty = false
        originalDialogVolume = nil
        printDebug("Dialog volume restored")
    end
end

-- Play bloodlust music (WITH MEMORY LEAK FIXES)
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
    
    -- Get volume from settings
    local volume = (DjLustDB and DjLustDB.volume) or 1.0
    
    -- Get music file from current theme
    local musicFile = GetMusicFile()
    
    -- Play the sound
    if type(musicFile) == "number" then
        PlaySound(musicFile, "Dialog")
        printDebug("Playing default sound!")
    else
        -- Cache original volume only once
        if not originalDialogVolume then
            originalDialogVolume = tonumber(GetCVar("Sound_DialogVolume")) or 1.0
        end
        
        -- Only set CVar if it's actually different (reduce CVar spam)
        local targetVolume = tostring(volume)
        local currentVolume = GetCVar("Sound_DialogVolume")
        if currentVolume ~= targetVolume then
            SetCVar("Sound_DialogVolume", targetVolume)
            cvarDirty = true
        end
        
        -- Play the music file
        local willPlay, soundHandle = PlaySoundFile(musicFile, "Dialog")
        if willPlay then
            -- Store in pool (max 1 handle)
            soundHandlePool[1] = soundHandle
            
            local themeName = THEMES[DjLustDB.theme] and THEMES[DjLustDB.theme].name or "Unknown"
            printDebug("Now playing: ", themeName, " at volume ", math.floor(volume * 100), "%")
            
            -- Trigger animation
            if addon.StartAnimation then
                addon:StartAnimation()
            end
        else
            printDebug("Failed to play music file: ", musicFile)
            RestoreDialogVolume()
        end
    end
end

-- Stop bloodlust music (WITH MEMORY LEAK FIXES)
local function StopDjLust()
    -- Stop and cleanup all sound handles
    CleanupSoundHandles()
    
    -- Restore volume
    RestoreDialogVolume()
    
    -- Stop animation
    if addon.StopAnimation then
        addon:StopAnimation()
    end
    
    printDebug("Music stopped - Bloodlust ended")
end

-- Update volume for currently playing music
function addon:UpdateVolume(volume)
    if soundHandlePool[1] and originalDialogVolume then
        SetCVar("Sound_DialogVolume", tostring(volume))
        cvarDirty = true
        printDebug("Volume updated to ", math.floor(volume * 100), "%")
    end
end

-- Update theme
function addon:UpdateTheme(theme)
    if THEMES[theme] then
        DjLustDB.theme = theme
        printDebug("Theme updated to: ", THEMES[theme].name)
        
        if addon.UpdateAnimationTexture then
            addon:UpdateAnimationTexture()
        end
    end
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
    
    local hasteIncrease = (currentHaste - baselineHaste) / 100
    
    if hasteIncrease >= HASTE_THRESHOLD and not isLusted then
        isLusted = true
        bloodlustCooldown = BLOODLUST_COOLDOWN
        PlayDjLust()
        return true
    end
    
    if hasteIncrease < (HASTE_THRESHOLD / 2) and isLusted then
        isLusted = false
        baselineHaste = currentHaste
        bloodlustCooldown = 0
        StopDjLust()
        return false
    end
    
    return isLusted
end

-- Start haste monitoring
local function StartHasteMonitoring()
    if hasteCheckTimer then
        hasteCheckTimer:Cancel()
        hasteCheckTimer = nil
    end
    
    hasteCheckTimer = C_Timer.NewTicker(CHECK_INTERVAL, function()
        if InCombatLockdown() then
            CheckHasteForBloodlust()
        else
            if not isLusted then
                baselineHaste = GetCurrentHaste()
            end
        end
    end)
end

-- Stop haste monitoring
local function StopHasteMonitoring()
    if hasteCheckTimer then
        hasteCheckTimer:Cancel()
        hasteCheckTimer = nil
    end
end

-- COMPREHENSIVE CLEANUP (MEMORY LEAK FIX)
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
        printDebug("DjLust loaded - Theme: ", DjLustDB.theme or "chipi")
        baselineHaste = GetCurrentHaste()
        StartHasteMonitoring()
    elseif event == "PLAYER_REGEN_DISABLED" then
        baselineHaste = GetCurrentHaste()
    elseif event == "PLAYER_REGEN_ENABLED" then
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
        local themeName = THEMES[DjLustDB.theme] and THEMES[DjLustDB.theme].name or "Unknown"
        print("[DjLust] [TEST] Testing music playback with theme: " .. themeName)
        PlayDjLust()
    elseif msg == "stop" then
        print("[DjLust] [STOP] Stopping music...")
        StopDjLust()
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
