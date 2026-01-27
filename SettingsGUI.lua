-- SettingsGUI.lua: Custom settings panel for DjLust
-- Based on proven popup window approach

local addonName, addon = ...

-- Saved variables
DjLustDB = DjLustDB or {
    animationEnabled = true,
    animationSize = 128,
    animationFPS = 8,
    debugMode = false,
}

local settingsFrame

--------------------------------------------------
-- Create Settings Window
--------------------------------------------------
local function CreateSettingsWindow()
    if settingsFrame then return settingsFrame end
    
    local WIDTH, HEIGHT = 450, 450
    
    local f = CreateFrame("Frame", "DjLustSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    
    -- Dragging
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetClampedToScreen(true)
    
    -- Backdrop
    f:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true,
        tileSize = 32,
        edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 }
    })
    f:SetBackdropColor(0, 0, 0, 0.85)
    
    -- Title
    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", 0, -15)
    f.title:SetText("|cff00bfffDjLust Settings|r")
    
    -- Close button
    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", -8, -8)
    
    local yOffset = -50
    
    --------------------------------------------------
    -- Animation Section Header
    --------------------------------------------------
    local animHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    animHeader:SetPoint("TOPLEFT", 20, yOffset)
    animHeader:SetText("|cffff8800Animation Settings|r")
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Enable Animation Checkbox
    --------------------------------------------------
    local enableAnim = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    enableAnim:SetPoint("TOPLEFT", 25, yOffset)
    enableAnim.text:SetText("Enable Animation")
    enableAnim:SetChecked(DjLustDB.animationEnabled)
    enableAnim:SetScript("OnClick", function(self)
        DjLustDB.animationEnabled = self:GetChecked()
        print("|cff00bfff[DjLust]|r Animation " .. (DjLustDB.animationEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    end)
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Animation Size Slider
    --------------------------------------------------
    local sizeLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 25, yOffset)
    sizeLabel:SetText("Animation Size: " .. DjLustDB.animationSize .. " px")
    yOffset = yOffset - 25
    
    local sizeSlider = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 25, yOffset)
    sizeSlider:SetWidth(380)
    sizeSlider:SetMinMaxValues(32, 512)
    sizeSlider:SetValue(DjLustDB.animationSize)
    sizeSlider:SetValueStep(16)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider.Low:SetText("32")
    sizeSlider.High:SetText("512")
    sizeSlider:SetScript("OnValueChanged", function(self, value)
        value = math.floor(value / 16) * 16 -- Snap to 16px increments
        DjLustDB.animationSize = value
        sizeLabel:SetText("Animation Size: " .. value .. " px")
        if _G["DjLustAnimFrame"] then
            _G["DjLustAnimFrame"]:SetSize(value, value)
        end
    end)
    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Animation FPS Slider
    --------------------------------------------------
    local fpsLabel = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fpsLabel:SetPoint("TOPLEFT", 25, yOffset)
    fpsLabel:SetText("Animation Speed: " .. DjLustDB.animationFPS .. " FPS")
    yOffset = yOffset - 25
    
    local fpsSlider = CreateFrame("Slider", nil, f, "OptionsSliderTemplate")
    fpsSlider:SetPoint("TOPLEFT", 25, yOffset)
    fpsSlider:SetWidth(380)
    fpsSlider:SetMinMaxValues(1, 30)
    fpsSlider:SetValue(DjLustDB.animationFPS)
    fpsSlider:SetValueStep(1)
    fpsSlider:SetObeyStepOnDrag(true)
    fpsSlider.Low:SetText("1")
    fpsSlider.High:SetText("30")
    fpsSlider:SetScript("OnValueChanged", function(self, value)
        DjLustDB.animationFPS = value
        fpsLabel:SetText("Animation Speed: " .. value .. " FPS")
        if addon.UpdateAnimationFPS then
            addon:UpdateAnimationFPS(value)
        end
    end)
    yOffset = yOffset - 40
    
    --------------------------------------------------
    -- Detection Section Header
    --------------------------------------------------
    local detectHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectHeader:SetPoint("TOPLEFT", 20, yOffset)
    detectHeader:SetText("|cffff8800Detection Settings|r")
    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Debug Mode Checkbox
    --------------------------------------------------
    local debugCheck = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 25, yOffset)
    debugCheck.text:SetText("Debug Mode")
    debugCheck:SetChecked(DjLustDB.debugMode)
    debugCheck:SetScript("OnClick", function(self)
        DjLustDB.debugMode = self:GetChecked()
        SlashCmdList["DJLUST"]("debug " .. (DjLustDB.debugMode and "on" or "off"))
    end)
    yOffset = yOffset - 40
    
    --------------------------------------------------
    -- Quick Actions Section
    --------------------------------------------------
    local actionHeader = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    actionHeader:SetPoint("TOPLEFT", 20, yOffset)
    actionHeader:SetText("|cffff8800Quick Actions|r")
    yOffset = yOffset - 30
    
    -- Button helper
    local function CreateActionButton(parent, x, y, width, text, onClick)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", x, y)
        btn:SetSize(width, 25)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end
    
    -- Test Music Button
    CreateActionButton(f, 25, yOffset, 120, "Test Music", function()
        SlashCmdList["DJLUST"]("test")
    end)
    
    -- Stop Music Button
    CreateActionButton(f, 155, yOffset, 120, "Stop Music", function()
        SlashCmdList["DJLUST"]("stop")
    end)
    
    -- Toggle Animation Button
    CreateActionButton(f, 285, yOffset, 120, "Toggle Animation", function()
        SlashCmdList["DJLANIM"]("toggle")
    end)
    
    yOffset = yOffset - 35
    
    -- Reset Position Button
    CreateActionButton(f, 25, yOffset, 190, "Reset Animation Position", function()
        if _G["DjLustAnimFrame"] then
            _G["DjLustAnimFrame"]:ClearAllPoints()
            _G["DjLustAnimFrame"]:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            print("|cff00bfff[DjLust]|r Animation position reset to center")
        end
    end)
    
    -- Reset Detection Button
    CreateActionButton(f, 225, yOffset, 180, "Reset Detection", function()
        SlashCmdList["DJLUST"]("reset")
    end)
    
    --------------------------------------------------
    -- Info Footer
    --------------------------------------------------
    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("BOTTOM", 0, 15)
    info:SetText("|cff808080Drag animation to reposition • Use /djlust for all commands|r")
    
    f:Hide()
    settingsFrame = f
    return f
end

--------------------------------------------------
-- Show/Hide Settings
--------------------------------------------------
function addon:ToggleSettings()
    local f = CreateSettingsWindow()
    if f:IsShown() then
        f:Hide()
    else
        f:Show()
    end
end

function addon:ShowSettings()
    local f = CreateSettingsWindow()
    f:Show()
end

--------------------------------------------------
-- Slash Command
--------------------------------------------------
SLASH_DJLSETTINGS1 = "/djlsettings"
SlashCmdList["DJLSETTINGS"] = function()
    addon:ToggleSettings()
end

-- Hook into main slash command
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon == addonName then
        -- Apply saved settings
        if DjLustDB.debugMode then
            C_Timer.After(0.1, function()
                SlashCmdList["DJLUST"]("debug on")
            end)
        end
        
        -- Hook the main slash command
        local originalHandler = SlashCmdList["DJLUST"]
        SlashCmdList["DJLUST"] = function(msg)
            if msg == "settings" or msg == "config" or msg == "options" then
                addon:ToggleSettings()
            else
                originalHandler(msg)
            end
        end
    end
end)
