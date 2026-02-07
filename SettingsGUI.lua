-- SettingsGUI.lua: Custom settings panel for DjLust

local addonName, addon = ...

local settingsFrame

--------------------------------------------------
-- Ensure all DB fields exist with defaults
--------------------------------------------------
local function EnsureDBDefaults()
    if not DjLustDB then
        DjLustDB = {}
    end
    
    -- Set defaults for any missing fields
    if DjLustDB.animationEnabled == nil then
        DjLustDB.animationEnabled = true
    end
    if DjLustDB.debugMode == nil then
        DjLustDB.debugMode = false
    end
    DjLustDB.animationSize = DjLustDB.animationSize or 128
    DjLustDB.animationFPS = DjLustDB.animationFPS or 8
    DjLustDB.volume = DjLustDB.volume or 1.0
    DjLustDB.theme = DjLustDB.theme or "chipi"
    DjLustDB.customSong = DjLustDB.customSong or ""
    DjLustDB.animationX = DjLustDB.animationX or 0
    DjLustDB.animationY = DjLustDB.animationY or 0
    DjLustDB.hasteThreshold = DjLustDB.hasteThreshold or 25  -- Default 25%
end

--------------------------------------------------
-- Update UI values from database
--------------------------------------------------
local function UpdateUIValues(f)
    if not f or not f.uiElements then return end
    
    local ui = f.uiElements
    
    -- Update checkboxes
    if ui.enableAnim then
        ui.enableAnim:SetChecked(DjLustDB.animationEnabled)
    end
    if ui.debugCheck then
        ui.debugCheck:SetChecked(DjLustDB.debugMode)
    end
    
    -- Update radio buttons
    if ui.chipiRadio and ui.pedroRadio and ui.customRadio then
        ui.chipiRadio:SetChecked(DjLustDB.theme == "chipi")
        ui.pedroRadio:SetChecked(DjLustDB.theme == "pedro")
        ui.customRadio:SetChecked(DjLustDB.theme == "custom")
    end
    
    -- Update sliders
    if ui.sizeSlider and ui.sizeLabel then
        ui.sizeSlider:SetValue(DjLustDB.animationSize)
        ui.sizeLabel:SetText("Animation Size: " .. DjLustDB.animationSize .. " px")
    end
    if ui.fpsSlider and ui.fpsLabel then
        ui.fpsSlider:SetValue(DjLustDB.animationFPS)
        ui.fpsLabel:SetText("Animation Speed: " .. DjLustDB.animationFPS .. " FPS")
    end
    if ui.volumeSlider and ui.volumeLabel then
        ui.volumeSlider:SetValue(DjLustDB.volume)
        ui.volumeLabel:SetText("Music Volume: " .. math.floor(DjLustDB.volume * 100) .. "%")
    end
    if ui.hasteSlider and ui.hasteLabel then
        ui.hasteSlider:SetValue(DjLustDB.hasteThreshold)
        ui.hasteLabel:SetText("Haste Threshold: " .. DjLustDB.hasteThreshold .. "%")
    end
end

--------------------------------------------------
-- Create Settings Window
--------------------------------------------------
local function CreateSettingsWindow()
    -- CRITICAL FIX: Check if window already exists globally
    if _G["DjLustSettingsFrame"] then
        return _G["DjLustSettingsFrame"]
    end
    
    -- CRITICAL FIX: Ensure database is initialized
    EnsureDBDefaults()
    
    local WIDTH, HEIGHT = 450, 550
    
    -- Main frame (container)
    local f = CreateFrame("Frame", "DjLustSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)  -- Ensure it's on top
    
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
    close:SetScript("OnClick", function()
        f:Hide()
    end)
    
    -- Create ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", 10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30, 50)
    
    -- Enable mouse wheel scrolling
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local current = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        local newScroll = math.max(0, math.min(maxScroll, current - (delta * 20)))
        self:SetVerticalScroll(newScroll)
    end)
    
    -- Create content frame (child of scroll frame)
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(WIDTH - 50, 500) -- Reduced height to fit actual content
    scrollFrame:SetScrollChild(content)
    
    local yOffset = -10
    
    -- Store references to UI elements for updating
    f.uiElements = {}
    
    --------------------------------------------------
    -- Animation Section Header
    --------------------------------------------------
    local animHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    animHeader:SetPoint("TOPLEFT", 20, yOffset)
    animHeader:SetText("|cffff8800Animation Settings|r")
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Enable Animation Checkbox
    --------------------------------------------------
    local enableAnim = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableAnim:SetPoint("TOPLEFT", 25, yOffset)
    enableAnim.text:SetText("Enable Animation")
    enableAnim:SetChecked(DjLustDB.animationEnabled)
    enableAnim:SetScript("OnClick", function(self)
        DjLustDB.animationEnabled = self:GetChecked()
        print("|cff00bfff[DjLust]|r Animation " .. (DjLustDB.animationEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    end)
    f.uiElements.enableAnim = enableAnim
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Animation Size Slider
    --------------------------------------------------
    local sizeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    sizeLabel:SetPoint("TOPLEFT", 25, yOffset)
    sizeLabel:SetText("Animation Size: " .. DjLustDB.animationSize .. " px")
    yOffset = yOffset - 25
    
    local sizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
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
    f.uiElements.sizeSlider = sizeSlider
    f.uiElements.sizeLabel = sizeLabel
    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Animation FPS Slider
    --------------------------------------------------
    local fpsLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    fpsLabel:SetPoint("TOPLEFT", 25, yOffset)
    fpsLabel:SetText("Animation Speed: " .. DjLustDB.animationFPS .. " FPS")
    yOffset = yOffset - 25
    
    local fpsSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
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
    f.uiElements.fpsSlider = fpsSlider
    f.uiElements.fpsLabel = fpsLabel
    yOffset = yOffset - 40
    
    --------------------------------------------------
    -- Audio Section Header
    --------------------------------------------------
    local audioHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    audioHeader:SetPoint("TOPLEFT", 20, yOffset)
    audioHeader:SetText("|cffff8800Audio Settings|r")
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Theme Selection
    --------------------------------------------------
    local themeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLabel:SetPoint("TOPLEFT", 25, yOffset)
    themeLabel:SetText("Theme Selection:")
    yOffset = yOffset - 25
    
    -- Chipi Theme Radio Button
    local chipiRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    chipiRadio:SetPoint("TOPLEFT", 35, yOffset)
    chipiRadio.text:SetText("Chipi Chipi (Default)")
    chipiRadio:SetChecked(DjLustDB.theme == "chipi")
    
    -- Pedro Theme Radio Button
    local pedroRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    pedroRadio:SetPoint("TOPLEFT", 225, yOffset)
    pedroRadio.text:SetText("Pedro Theme")
    pedroRadio:SetChecked(DjLustDB.theme == "pedro")
    
    yOffset = yOffset - 25
    
    -- Custom Theme Radio Button
    local customRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    customRadio:SetPoint("TOPLEFT", 35, yOffset)
    customRadio.text:SetText("Custom Song")
    customRadio:SetChecked(DjLustDB.theme == "custom")
    
    f.uiElements.chipiRadio = chipiRadio
    f.uiElements.pedroRadio = pedroRadio
    f.uiElements.customRadio = customRadio
    
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Custom Song Dropdown
    --------------------------------------------------
    local dropdownLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdownLabel:SetPoint("TOPLEFT", 55, yOffset)
    dropdownLabel:SetText("Select song from Interface\\AddOns\\Songs folder:")
    yOffset = yOffset - 20
    
    -- Create dropdown frame
    local dropdown = CreateFrame("Frame", "DjLustSongDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 45, yOffset)
    
    -- Function to get available songs from CustomSongs.lua
    local function GetAvailableSongs()
        local songs = {"(None)"}
        
        -- Check if CUSTOM_SONGS exists
        if not CUSTOM_SONGS or type(CUSTOM_SONGS) ~= "table" then
            return songs
        end
        
        -- Verify each song file exists before adding to list
        for _, songFile in ipairs(CUSTOM_SONGS) do
            -- Clean up the filename (remove extra spaces)
            songFile = songFile:match("^%s*(.-)%s*$")
            
            if songFile ~= "" then
                local path = "Interface\\AddOns\\Songs\\" .. songFile
                
                -- Test if file exists by attempting to play it
                local willPlay, handle = PlaySoundFile(path, "Master")
                
                if willPlay and handle then
                    -- File exists and is playable
                    table.insert(songs, songFile)
                    -- Stop the test playback immediately
                    StopSound(handle)
                end
            end
        end
        
        return songs
    end
    
    -- Dropdown initialization
    local function InitDropdown(self, level)
        local info = UIDropDownMenu_CreateInfo()
        local songs = GetAvailableSongs()
        
        for _, song in ipairs(songs) do
            info.text = song
            info.value = song
            info.func = function(self)
                if song == "(None)" then
                    DjLustDB.customSong = ""
                    UIDropDownMenu_SetText(dropdown, "(None)")
                else
                    DjLustDB.customSong = song
                    UIDropDownMenu_SetText(dropdown, song)
                end
                
                -- Update theme if custom is selected
                if DjLustDB.theme == "custom" then
                    if addon.UpdateTheme then
                        addon:UpdateTheme("custom")
                    end
                    print("|cff00bfff[DjLust]|r Custom song changed to: " .. (song == "(None)" and "None" or song))
                end
            end
            info.checked = (DjLustDB.customSong == song) or (song == "(None)" and DjLustDB.customSong == "")
            UIDropDownMenu_AddButton(info, level)
        end
    end
    
    UIDropDownMenu_Initialize(dropdown, InitDropdown)
    UIDropDownMenu_SetWidth(dropdown, 250)
    
    -- Set initial text
    if DjLustDB.customSong and DjLustDB.customSong ~= "" then
        UIDropDownMenu_SetText(dropdown, DjLustDB.customSong)
    else
        UIDropDownMenu_SetText(dropdown, "(None)")
    end
    
    -- Function to enable/disable dropdown based on theme
    local function UpdateDropdownState()
        if DjLustDB.theme == "custom" then
            UIDropDownMenu_EnableDropDown(dropdown)
            dropdownLabel:SetTextColor(1, 1, 1)
        else
            UIDropDownMenu_DisableDropDown(dropdown)
            dropdownLabel:SetTextColor(0.5, 0.5, 0.5)
        end
    end
    
    UpdateDropdownState()
    
    yOffset = yOffset - 35
    
    -- Set OnClick handlers
    chipiRadio:SetScript("OnClick", function(self)
        DjLustDB.theme = "chipi"
        chipiRadio:SetChecked(true)
        pedroRadio:SetChecked(false)
        customRadio:SetChecked(false)
        UpdateDropdownState()
        if addon.UpdateTheme then
            addon:UpdateTheme("chipi")
        end
        print("|cff00bfff[DjLust]|r Theme changed to: |cffff1493Chipi Chipi|r")
    end)
    
    pedroRadio:SetScript("OnClick", function(self)
        DjLustDB.theme = "pedro"
        chipiRadio:SetChecked(false)
        pedroRadio:SetChecked(true)
        customRadio:SetChecked(false)
        UpdateDropdownState()
        if addon.UpdateTheme then
            addon:UpdateTheme("pedro")
        end
        print("|cff00bfff[DjLust]|r Theme changed to: |cff00ff00Pedro|r")
    end)
    
    customRadio:SetScript("OnClick", function(self)
        DjLustDB.theme = "custom"
        chipiRadio:SetChecked(false)
        pedroRadio:SetChecked(false)
        customRadio:SetChecked(true)
        UpdateDropdownState()
        if addon.UpdateTheme then
            addon:UpdateTheme("custom")
        end
        
        if DjLustDB.customSong and DjLustDB.customSong ~= "" then
            print("|cff00bfff[DjLust]|r Theme changed to: |cff9370dbCustom|r (" .. DjLustDB.customSong .. ")")
        else
            print("|cff00bfff[DjLust]|r Theme changed to: |cff9370dbCustom|r (No song selected)")
        end
    end)
    
    
    --------------------------------------------------
    -- Volume Slider
    --------------------------------------------------
    local volumeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    volumeLabel:SetPoint("TOPLEFT", 25, yOffset)
    volumeLabel:SetText("Music Volume: " .. math.floor(DjLustDB.volume * 100) .. "%")
    yOffset = yOffset - 25
    
    local volumeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    volumeSlider:SetPoint("TOPLEFT", 25, yOffset)
    volumeSlider:SetWidth(380)
    volumeSlider:SetMinMaxValues(0, 1)
    volumeSlider:SetValue(DjLustDB.volume)
    volumeSlider:SetValueStep(0.05)
    volumeSlider:SetObeyStepOnDrag(true)
    volumeSlider.Low:SetText("0%")
    volumeSlider.High:SetText("100%")
    volumeSlider:SetScript("OnValueChanged", function(self, value)
        DjLustDB.volume = value
        volumeLabel:SetText("Music Volume: " .. math.floor(value * 100) .. "%")
        if addon.UpdateVolume then
            addon:UpdateVolume(value)
        end
    end)
    f.uiElements.volumeSlider = volumeSlider
    f.uiElements.volumeLabel = volumeLabel
    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Quick Actions Section
    --------------------------------------------------
    local actionHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
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
    CreateActionButton(content, 25, yOffset, 120, "Test Music", function()
        SlashCmdList["DJLUST"]("test")
    end)
    
    -- Stop Music Button
    CreateActionButton(content, 155, yOffset, 120, "Stop Music", function()
        SlashCmdList["DJLUST"]("stop")
    end)
    
    -- Toggle Animation Button
    CreateActionButton(content, 285, yOffset, 120, "Toggle Animation", function()
        SlashCmdList["DJLANIM"]("toggle")
    end)
    
    yOffset = yOffset - 35
    
    -- Reset Position Button
    CreateActionButton(content, 25, yOffset, 190, "Reset Animation Position", function()
        if _G["DjLustAnimFrame"] then
            _G["DjLustAnimFrame"]:ClearAllPoints()
            _G["DjLustAnimFrame"]:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            DjLustDB.animationX = 0
            DjLustDB.animationY = 0
            print("|cff00bfff[DjLust]|r Animation position reset to center")
        end
    end)
    
    -- Reset Detection Button
    CreateActionButton(content, 225, yOffset, 180, "Reset Detection", function()
        SlashCmdList["DJLUST"]("reset")
    end)

    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Detection Settings Section Header
    --------------------------------------------------
    local detectSettingsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectSettingsHeader:SetPoint("TOPLEFT", 20, yOffset)
    detectSettingsHeader:SetText("|cffff8800Detection Settings|r")
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Haste Threshold Slider
    --------------------------------------------------
    local hasteLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    hasteLabel:SetPoint("TOPLEFT", 25, yOffset)
    hasteLabel:SetText("Haste Threshold: " .. DjLustDB.hasteThreshold .. "%")
    yOffset = yOffset - 20
    
    local hasteHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hasteHelp:SetPoint("TOPLEFT", 25, yOffset)
    hasteHelp:SetText("|cff808080Minimum haste increase to trigger music (Default: 25%)|r")
    yOffset = yOffset - 25
    
    local hasteSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    hasteSlider:SetPoint("TOPLEFT", 25, yOffset)
    hasteSlider:SetWidth(380)
    hasteSlider:SetMinMaxValues(10, 50)
    hasteSlider:SetValue(DjLustDB.hasteThreshold)
    hasteSlider:SetValueStep(1)
    hasteSlider:SetObeyStepOnDrag(true)
    hasteSlider.Low:SetText("10%")
    hasteSlider.High:SetText("50%")
    hasteSlider:SetScript("OnValueChanged", function(self, value)
        DjLustDB.hasteThreshold = value
        hasteLabel:SetText("Haste Threshold: " .. value .. "%")
    end)
    f.uiElements.hasteSlider = hasteSlider
    f.uiElements.hasteLabel = hasteLabel
    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Debug Mode Section Header
    --------------------------------------------------
    local detectHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectHeader:SetPoint("TOPLEFT", 20, yOffset)
    detectHeader:SetText("|cffff8800Debug Mode|r")
    yOffset = yOffset - 30
    
    --------------------------------------------------
    -- Debug Mode Checkbox
    --------------------------------------------------
    local debugCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 25, yOffset)
    debugCheck.text:SetText("Enable Debug Output")
    debugCheck:SetChecked(DjLustDB.debugMode)
    debugCheck:SetScript("OnClick", function(self)
        DjLustDB.debugMode = self:GetChecked()
        SlashCmdList["DJLUST"]("debug " .. (DjLustDB.debugMode and "on" or "off"))
    end)
    f.uiElements.debugCheck = debugCheck
    yOffset = yOffset - 30

    -- Calculate actual content height needed
    local contentHeight = math.abs(yOffset) + 20  -- Add small padding at bottom
    content:SetSize(WIDTH - 50, contentHeight)
    
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
    -- CRITICAL FIX: Always get the frame reference, create if needed
    local f = _G["DjLustSettingsFrame"] or CreateSettingsWindow()
    
    if f:IsShown() then
        f:Hide()
    else
        -- Ensure DB is current before showing
        EnsureDBDefaults()
        -- Update all UI values from saved data
        UpdateUIValues(f)
        f:Show()
    end
end

function addon:ShowSettings()
    local f = _G["DjLustSettingsFrame"] or CreateSettingsWindow()
    EnsureDBDefaults()
    -- Update all UI values from saved data
    UpdateUIValues(f)
    f:Show()
end

function addon:HideSettings()
    local f = _G["DjLustSettingsFrame"]
    if f then
        f:Hide()
    end
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
        -- CRITICAL FIX: Wait for DjLust.lua to initialize DjLustDB first
        C_Timer.After(0.1, function()
            EnsureDBDefaults()
            
            -- Apply saved settings
            if DjLustDB.debugMode then
                C_Timer.After(0.2, function()
                    if SlashCmdList["DJLUST"] then
                        SlashCmdList["DJLUST"]("debug on")
                    end
                end)
            end
        end)
        
        -- Hook the main slash command
        C_Timer.After(0.2, function()
            if SlashCmdList["DJLUST"] then
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
    end
end)
