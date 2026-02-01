-- Animation.lua: Animated sprite display for DjLust
-- MEMORY LEAK FIXED VERSION - Aggressive cleanup

local addonName, addon = ...

-- Theme configurations
local THEMES = {
    chipi = {
        texture = "Interface\\AddOns\\DjLust\\chipi.tga",
        frameCount = 4,
        columns = 2,
        rows = 2,
    },
    pedro = {
        texture = "Interface\\AddOns\\DjLust\\pedrolust.tga",
        frameCount = 32,
        columns = 4,
        rows = 8,
    },
}

-- Animation state
local animState = {
    isPlaying = false,
    currentFrame = 0,
    frameCount = 4,
    fps = 8,
    ticker = nil,
    columns = 2,
    rows = 2,
}

-- MEMORY LEAK FIX: Debouncing
local lastAnimStart = 0
local lastAnimStop = 0
local ANIM_COOLDOWN = 0.3  -- Minimum time between start/stop calls

-- MEMORY LEAK FIX: Track pending timers
local pendingTimers = {}

-- Create animation frame
local animFrame = CreateFrame("Frame", "DjLustAnimFrame", UIParent)
animFrame:SetSize(128, 128)
animFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
animFrame:Hide()

-- Create texture
local animTexture = animFrame:CreateTexture(nil, "ARTWORK")
animTexture:SetAllPoints(animFrame)

-- Helper to get current theme safely
local function GetCurrentTheme()
    if not DjLustDB then
        return "chipi"
    end
    local theme = DjLustDB.theme or "chipi"
    if not THEMES[theme] then
        return "chipi"
    end
    return theme
end

-- Update texture based on theme
local function UpdateTexture()
    local theme = GetCurrentTheme()
    local themeConfig = THEMES[theme]
    
    if not themeConfig then
        print("|cff00bfff[DjLust]|r |cffff0000ERROR:|r Invalid theme configuration")
        return false
    end
    
    animTexture:SetTexture(themeConfig.texture)
    animState.frameCount = themeConfig.frameCount or 4
    animState.columns = themeConfig.columns or 2
    animState.rows = themeConfig.rows or 2
    
    return true
end

-- Calculate texture coordinates
local function GetFrameCoords(frameIndex)
    if frameIndex >= animState.frameCount then
        frameIndex = 0
    end
    
    local col = frameIndex % animState.columns
    local row = math.floor(frameIndex / animState.columns)
    
    local frameWidth = 1.0 / animState.columns
    local frameHeight = 1.0 / animState.rows
    
    local left = col * frameWidth
    local right = left + frameWidth
    local top = row * frameHeight
    local bottom = top + frameHeight
    
    return left, right, top, bottom
end

-- Update animation frame
local function UpdateAnimationFrame()
    if not animState.isPlaying then
        return
    end
    
    local left, right, top, bottom = GetFrameCoords(animState.currentFrame)
    animTexture:SetTexCoord(left, right, top, bottom)
    animState.currentFrame = (animState.currentFrame + 1) % animState.frameCount
end

-- MEMORY LEAK FIX: Cancel all pending timers
local function CancelPendingTimers()
    for i = #pendingTimers, 1, -1 do
        local timer = pendingTimers[i]
        if timer then
            timer:Cancel()
        end
        pendingTimers[i] = nil
    end
    wipe(pendingTimers)
end

-- Stop ticker safely
local function StopTicker()
    if animState.ticker then
        animState.ticker:Cancel()
        animState.ticker = nil
    end
end

-- Start ticker
local function StartTicker()
    StopTicker()
    
    local interval = 1.0 / animState.fps
    animState.ticker = C_Timer.NewTicker(interval, function()
        if not animState.isPlaying then
            StopTicker()
            return
        end
        UpdateAnimationFrame()
    end)
end

-- MEMORY LEAK FIX: Remove all animation groups
local function CleanupAnimationGroups()
    -- Stop any fade animations
    UIFrameFadeRemoveFrame(animFrame)
end

-- Start animation (WITH MEMORY LEAK FIXES)
function addon:StartAnimation()
    -- DEBOUNCE: Prevent rapid restarts
    local now = GetTime()
    if now - lastAnimStart < ANIM_COOLDOWN then
        if DjLustDB and DjLustDB.debugMode then
            print("|cff00bfff[DjLust]|r Animation start blocked - cooldown active")
        end
        return
    end
    lastAnimStart = now
    
    -- If already playing, don't restart
    if animState.isPlaying then
        return
    end
    
    -- Cleanup any existing animations first
    CleanupAnimationGroups()
    CancelPendingTimers()
    
    -- Update texture
    if not UpdateTexture() then
        print("|cff00bfff[DjLust]|r |cffff0000ERROR:|r Failed to load animation texture")
        return
    end
    
    -- Apply saved settings
    if DjLustDB then
        if DjLustDB.animationSize then
            animFrame:SetSize(DjLustDB.animationSize, DjLustDB.animationSize)
        end
        if DjLustDB.animationFPS then
            animState.fps = DjLustDB.animationFPS
        end
        if DjLustDB.animationX and DjLustDB.animationY then
            animFrame:ClearAllPoints()
            animFrame:SetPoint("CENTER", UIParent, "CENTER", DjLustDB.animationX, DjLustDB.animationY)
        end
    end
    
    animState.isPlaying = true
    animState.currentFrame = 0
    animFrame:Show()
    
    UpdateAnimationFrame()
    StartTicker()
    
    -- Fade in
    animFrame:SetAlpha(0)
    UIFrameFadeIn(animFrame, 0.3, 0, 1)
    
    if DjLustDB and DjLustDB.debugMode then
        local theme = GetCurrentTheme()
        print("|cff00bfff[DjLust]|r |cffff1493Animation started!|r (Theme: " .. theme .. ")")
    end
end

-- Stop animation (WITH MEMORY LEAK FIXES)
function addon:StopAnimation()
    -- DEBOUNCE: Prevent rapid stops
    local now = GetTime()
    if now - lastAnimStop < ANIM_COOLDOWN then
        return
    end
    lastAnimStop = now
    
    if not animState.isPlaying then
        return
    end
    
    animState.isPlaying = false
    StopTicker()
    
    -- Cleanup animation groups before creating new one
    CleanupAnimationGroups()
    
    -- Fade out
    UIFrameFadeOut(animFrame, 0.3, 1, 0)
    
    -- Store timer reference for cleanup
    local hideTimer = C_Timer.NewTimer(0.3, function()
        animFrame:Hide()
        CleanupAnimationGroups()
    end)
    table.insert(pendingTimers, hideTimer)
    
    if DjLustDB and DjLustDB.debugMode then
        print("|cff00bfff[DjLust]|r |cffff1493Animation stopped!|r")
    end
end

-- Make frame draggable
animFrame:SetMovable(true)
animFrame:EnableMouse(true)
animFrame:RegisterForDrag("LeftButton")
animFrame:SetScript("OnDragStart", function(self)
    self:StartMoving()
end)
animFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if DjLustDB then
        DjLustDB.animationX = xOfs
        DjLustDB.animationY = yOfs
    end
end)

-- Update FPS
function addon:UpdateAnimationFPS(fps)
    animState.fps = fps
    if animState.isPlaying then
        StartTicker()
    end
end

-- Update texture when theme changes
function addon:UpdateAnimationTexture()
    local wasPlaying = animState.isPlaying
    
    if wasPlaying then
        self:StopAnimation()
    end
    
    UpdateTexture()
    
    if wasPlaying then
        -- Use timer to avoid rapid restart
        local restartTimer = C_Timer.NewTimer(0.2, function()
            self:StartAnimation()
        end)
        table.insert(pendingTimers, restartTimer)
    end
end

-- MEMORY LEAK FIX: Comprehensive cleanup
local function CleanupAnimation()
    animState.isPlaying = false
    StopTicker()
    CancelPendingTimers()
    CleanupAnimationGroups()
    animFrame:Hide()
    animFrame:SetAlpha(1)
end

-- Slash commands
SLASH_DJLANIM1 = "/djlanim"
SLASH_DJLANIM2 = "/djla"
SlashCmdList["DJLANIM"] = function(msg)
    if msg == "start" or msg == "play" then
        addon:StartAnimation()
    elseif msg == "stop" then
        addon:StopAnimation()
    elseif msg == "toggle" then
        if animState.isPlaying then
            addon:StopAnimation()
        else
            addon:StartAnimation()
        end
    elseif msg == "info" then
        print("|cff00bfff[DjLust Animation] Info:|r")
        print("  Theme:", GetCurrentTheme())
        print("  Frame count:", animState.frameCount)
        print("  Grid:", animState.columns .. "x" .. animState.rows)
        print("  Current frame:", animState.currentFrame)
        print("  FPS:", animState.fps)
        print("  Playing:", animState.isPlaying and "Yes" or "No")
        local theme = THEMES[GetCurrentTheme()]
        print("  Texture:", theme.texture)
        print("  Ticker active:", animState.ticker and "Yes" or "No")
        print("  Pending timers:", #pendingTimers)
    elseif msg == "reset" then
        animFrame:ClearAllPoints()
        animFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if DjLustDB then
            DjLustDB.animationX = 0
            DjLustDB.animationY = 0
        end
        print("|cff00bfff[DjLust]|r Animation position reset to center")
    elseif msg == "cleanup" then
        CleanupAnimation()
        collectgarbage("collect")
        print("|cff00bfff[DjLust]|r Animation cleanup complete")
    elseif msg:match("^size") then
        local size = tonumber(msg:match("^size%s+(%d+)"))
        if size and size >= 32 and size <= 512 then
            animFrame:SetSize(size, size)
            if DjLustDB then
                DjLustDB.animationSize = size
            end
            print("|cff00bfff[DjLust]|r Animation size set to " .. size .. "x" .. size)
        else
            print("|cff00bfff[DjLust]|r Usage: /djlanim size <32-512>")
        end
    elseif msg:match("^fps") then
        local fps = tonumber(msg:match("^fps%s+(%d+)"))
        if fps and fps >= 1 and fps <= 60 then
            addon:UpdateAnimationFPS(fps)
            if DjLustDB then
                DjLustDB.animationFPS = fps
            end
            print("|cff00bfff[DjLust]|r Animation FPS set to " .. fps)
        else
            print("|cff00bfff[DjLust]|r Usage: /djlanim fps <1-60>")
        end
    else
        print("|cff00bfff[DjLust Animation] [HELP]\nAvailable Commands:|r")
        print("  |cffff1493/djlanim start|r - Start animation")
        print("  |cffff1493/djlanim stop|r - Stop animation")
        print("  |cffff1493/djlanim toggle|r - Toggle animation on/off")
        print("  |cffff1493/djlanim info|r - Show animation info")
        print("  |cffff1493/djlanim reset|r - Reset position to center")
        print("  |cffff1493/djlanim cleanup|r - Force cleanup")
        print("  |cffff1493/djlanim size <number>|r - Set animation size (32-512)")
        print("  |cffff1493/djlanim fps <number>|r - Set animation speed (1-60)")
        print("|cff00bfff[TIP]|r Drag the animation with left mouse button to reposition")
    end
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:RegisterEvent("PLAYER_LOGOUT")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if event == "ADDON_LOADED" and loadedAddon == addonName then
        UpdateTexture()
        
        if DjLustDB then
            if DjLustDB.animationSize then
                animFrame:SetSize(DjLustDB.animationSize, DjLustDB.animationSize)
            end
            if DjLustDB.animationFPS then
                animState.fps = DjLustDB.animationFPS
            end
            if DjLustDB.animationX and DjLustDB.animationY then
                animFrame:ClearAllPoints()
                animFrame:SetPoint("CENTER", UIParent, "CENTER", DjLustDB.animationX, DjLustDB.animationY)
            end
        end
    elseif event == "PLAYER_LOGOUT" then
        CleanupAnimation()
    end
end)
