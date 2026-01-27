-- Animation.lua: Animated sprite display for DjLust
-- Shows a dancing animation when Bloodlust is active

local addonName, addon = ...

-- Create animation frame
local animFrame = CreateFrame("Frame", "DjLustAnimFrame", UIParent)
animFrame:SetSize(128, 128)  -- Animation display size
animFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
animFrame:Hide()

-- Create texture for the sprite
local animTexture = animFrame:CreateTexture(nil, "ARTWORK")
animTexture:SetAllPoints(animFrame)
animTexture:SetTexture("Interface\\AddOns\\DjLust\\chipi.tga")

-- Animation state
local animState = {
    isPlaying = false,
    currentFrame = 0,
    frameCount = 4,      -- Number of animation frames (2x2 grid)
    fps = 8,             -- Frames per second
    ticker = nil,
    frameWidth = 0.5,    -- Texture coordinates (2 columns = 0.5 width each)
    frameHeight = 0.5    -- Texture coordinates (2 rows = 0.5 height each)
}

-- Calculate texture coordinates for sprite sheet
-- Assuming 2x2 grid layout in the TGA file
local function GetFrameCoords(frameIndex)
    local col = frameIndex % 2           -- Column (0 or 1)
    local row = math.floor(frameIndex / 2)  -- Row (0 or 1)
    
    local left = col * animState.frameWidth
    local right = left + animState.frameWidth
    local top = row * animState.frameHeight
    local bottom = top + animState.frameHeight
    
    return left, right, top, bottom
end

-- Update the displayed frame
local function UpdateAnimationFrame()
    local left, right, top, bottom = GetFrameCoords(animState.currentFrame)
    animTexture:SetTexCoord(left, right, top, bottom)
    
    -- Advance to next frame
    animState.currentFrame = (animState.currentFrame + 1) % animState.frameCount
end

-- Start the animation
function addon:StartAnimation()
    if animState.isPlaying then
        return
    end
    
    animState.isPlaying = true
    animState.currentFrame = 0
    animFrame:Show()
    
    -- Set initial frame
    UpdateAnimationFrame()
    
    -- Create ticker for frame updates
    local interval = 1.0 / animState.fps
    animState.ticker = C_Timer.NewTicker(interval, function()
        if not animState.isPlaying then
            return
        end
        UpdateAnimationFrame()
    end)
    
    -- Add some visual flair with a pulse animation
    animFrame:SetAlpha(0)
    UIFrameFadeIn(animFrame, 0.3, 0, 1)
    
    -- Only show message in debug mode
    if DjLustDB and DjLustDB.debugMode then
        print("|cff00bfff[DjLust]|r |cffff1493Animation started!|r")
    end
end

-- Stop the animation
function addon:StopAnimation()
    if not animState.isPlaying then
        return
    end
    
    animState.isPlaying = false
    
    -- Cancel the ticker
    if animState.ticker then
        animState.ticker:Cancel()
        animState.ticker = nil
    end
    
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
    if animState.isPlaying and animState.ticker then
        animState.ticker:Cancel()
        local interval = 1.0 / animState.fps
        animState.ticker = C_Timer.NewTicker(interval, function()
            if not animState.isPlaying then
                return
            end
            UpdateAnimationFrame()
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
    elseif msg == "reset" then
        animFrame:ClearAllPoints()
        animFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
        print("|cff00bfff[DjLust]|r Animation position reset to center")
    elseif msg:match("^size") then
        local size = tonumber(msg:match("^size%s+(%d+)"))
        if size and size >= 32 and size <= 512 then
            animFrame:SetSize(size, size)
            print("|cff00bfff[DjLust]|r Animation size set to " .. size .. "x" .. size)
        else
            print("|cff00bfff[DjLust]|r Usage: /djlanim size <32-512>")
        end
    elseif msg:match("^fps") then
        local fps = tonumber(msg:match("^fps%s+(%d+)"))
        if fps and fps >= 1 and fps <= 60 then
            animState.fps = fps
            print("|cff00bfff[DjLust]|r Animation FPS set to " .. fps)
            -- Restart ticker if playing
            if animState.isPlaying and animState.ticker then
                animState.ticker:Cancel()
                local interval = 1.0 / animState.fps
                animState.ticker = C_Timer.NewTicker(interval, UpdateAnimationFrame)
            end
        else
            print("|cff00bfff[DjLust]|r Usage: /djlanim fps <1-60>")
        end
    else
        print("|cff00bfff[DjLust Animation] [HELP]\nAvailable Commands:|r")
        print("  |cffff1493/djlanim start|r - Start animation")
        print("  |cffff1493/djlanim stop|r - Stop animation")
        print("  |cffff1493/djlanim toggle|r - Toggle animation on/off")
        print("  |cffff1493/djlanim reset|r - Reset position to center")
        print("  |cffff1493/djlanim size <number>|r - Set animation size (32-512)")
        print("  |cffff1493/djlanim fps <number>|r - Set animation speed (1-60)")
        print("|cff00bfff[TIP]|r Drag the animation with left mouse button to reposition")
    end
end
