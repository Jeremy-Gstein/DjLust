-- Animation.lua: Animated sprite display for DjLust
-- Shows a dancing animation when Bloodlust is active

local addonName, addon = ...

-- Theme configurations (must match DjLust.lua)
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

-- Animation state (initialize with safe defaults)
local animState = {
    isPlaying = false,
    currentFrame = 0,
    frameCount = 4,
    fps = 8,
    ticker = nil,
    columns = 2,
    rows = 2,
}

-- Create animation frame
local animFrame = CreateFrame("Frame", "DjLustAnimFrame", UIParent)
animFrame:SetSize(128, 128)
animFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
animFrame:Hide()

-- Create texture for the sprite
local animTexture = animFrame:CreateTexture(nil, "ARTWORK")
animTexture:SetAllPoints(animFrame)

-- Helper to get current theme safely
local function GetCurrentTheme()
    -- Ensure DjLustDB exists
    if not DjLustDB then
        return "chipi"
    end
    
    local theme = DjLustDB.theme or "chipi"
    
    -- Validate theme exists
    if not THEMES[theme] then
        return "chipi"
    end
    
    return theme
end

-- Function to update texture based on current theme
local function UpdateTexture()
    local theme = GetCurrentTheme()
    local themeConfig = THEMES[theme]
    
    -- Safety check
    if not themeConfig then
        print("|cff00bfff[DjLust]|r |cffff0000ERROR:|r Invalid theme configuration")
        return false
    end
    
    -- Update texture
    animTexture:SetTexture(themeConfig.texture)
    
    -- Update animation state with theme-specific settings
    animState.frameCount = themeConfig.frameCount or 4
    animState.columns = themeConfig.columns or 2
    animState.rows = themeConfig.rows or 2
    
    return true
end

-- Calculate texture coordinates for sprite sheet
local function GetFrameCoords(frameIndex)
    -- Bounds check
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

-- Update the displayed frame
local function UpdateAnimationFrame()
    if not animState.isPlaying then
        return
    end
    
    local left, right, top, bottom = GetFrameCoords(animState.currentFrame)
    animTexture:SetTexCoord(left, right, top, bottom)
    
    -- Advance to next frame
    animState.currentFrame = (animState.currentFrame + 1) % animState.frameCount
end

-- Stop the ticker safely
local function StopTicker()
    if animState.ticker then
        animState.ticker:Cancel()
        animState.ticker = nil
    end
end

-- Start the ticker
local function StartTicker()
    -- Stop any existing ticker first
    StopTicker()
    
    -- Create new ticker
    local interval = 1.0 / animState.fps
    animState.ticker = C_Timer.NewTicker(interval, function()
        if not animState.isPlaying then
            StopTicker()
            return
        end
        UpdateAnimationFrame()
    end)
end

-- Start the animation
function addon:StartAnimation()
    if animState.isPlaying then
        return
    end
    
    -- Update texture to current theme
    if not UpdateTexture() then
        print("|cff00bfff[DjLust]|r |cffff0000ERROR:|r Failed to load animation texture")
        return
    end
    
    -- Apply saved size if available
    if DjLustDB and DjLustDB.animationSize then
        animFrame:SetSize(DjLustDB.animationSize, DjLustDB.animationSize)
    end
    
    -- Apply saved FPS if available
    if DjLustDB and DjLustDB.animationFPS then
        animState.fps = DjLustDB.animationFPS
    end
    
    -- Apply saved position if available
    if DjLustDB and DjLustDB.animationX and DjLustDB.animationY then
        animFrame:ClearAllPoints()
        animFrame:SetPoint("CENTER", UIParent, "CENTER", DjLustDB.animationX, DjLustDB.animationY)
    end
    
    animState.isPlaying = true
    animState.currentFrame = 0
    animFrame:Show()
    
    -- Set initial frame
    UpdateAnimationFrame()
    
    -- Start the ticker
    StartTicker()
    
    -- Add some visual flair with a pulse animation
    animFrame:SetAlpha(0)
    UIFrameFadeIn(animFrame, 0.3, 0, 1)
    
    -- Only show message in debug mode
    if DjLustDB and DjLustDB.debugMode then
        local theme = GetCurrentTheme()
        print("|cff00bfff[DjLust]|r |cffff1493Animation started!|r (Theme: " .. theme .. ")")
    end
end

-- Stop the animation
function addon:StopAnimation()
    if not animState.isPlaying then
        return
    end
    
    animState.isPlaying = false
    
    -- Stop the ticker
    StopTicker()
    
    -- Fade out and hide
    UIFrameFadeOut(animFrame, 0.3, 1, 0)
    C_Timer.After(0.3, function()
        animFrame:Hide()
    end)
    
    -- Only show message in debug mode
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
    -- Save position to settings
    local point, _, relativePoint, xOfs, yOfs = self:GetPoint()
    if DjLustDB then
        DjLustDB.animationX = xOfs
        DjLustDB.animationY = yOfs
    end
end)

-- Function to update FPS (called from settings panel)
function addon:UpdateAnimationFPS(fps)
    animState.fps = fps
    
    -- If animation is playing, restart the ticker with new FPS
    if animState.isPlaying then
        StartTicker()
    end
end

-- Function to update animation texture when theme changes
function addon:UpdateAnimationTexture()
    local wasPlaying = animState.isPlaying
    
    -- Stop animation if playing
    if wasPlaying then
        self:StopAnimation()
    end
    
    -- Update texture
    UpdateTexture()
    
    -- Restart animation if it was playing
    if wasPlaying then
        C_Timer.After(0.1, function()
            self:StartAnimation()
        end)
    end
end

-- Add slash commands for animation
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
    elseif msg == "reset" then
        animFrame:ClearAllPoints()
        animFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        if DjLustDB then
            DjLustDB.animationX = 0
            DjLustDB.animationY = 0
        end
        print("|cff00bfff[DjLust]|r Animation position reset to center")
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
        print("  |cffff1493/djlanim info|r - Show animation info (useful for debugging)")
        print("  |cffff1493/djlanim reset|r - Reset position to center")
        print("  |cffff1493/djlanim size <number>|r - Set animation size (32-512)")
        print("  |cffff1493/djlanim fps <number>|r - Set animation speed (1-60)")
        print("|cff00bfff[TIP]|r Drag the animation with left mouse button to reposition")
    end
end

-- Initialize on load
local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("ADDON_LOADED")
initFrame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        -- Initialize texture with current theme
        UpdateTexture()
        
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
    end
end)
