-- SettingsGUI.lua: Custom settings panel for DjLust

local addonName, addon = ...

-- Saved variables
DjLustDB = DjLustDB or {
    animationEnabled = true,
    animationSize = 128,
    animationFPS = 8,
    debugMode = false,
    volume = 1.0, -- Volume level (0.0 to 1.0)
    theme = "chipi", -- Selected theme: "chipi", "pedro", or "custom"
    customSong = "", -- Custom song filename from AddOns\\Songs\\ folder
}

local settingsFrame

--------------------------------------------------
-- Create Settings Window
--------------------------------------------------
local function CreateSettingsWindow()
    if settingsFrame then return settingsFrame end
    
    local WIDTH, HEIGHT = 450, 550
    
    -- Main frame (container)
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
    content:SetSize(WIDTH - 50, 700) -- Tall enough for all content
    scrollFrame:SetScrollChild(content)
    
    local yOffset = -10
    
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
            print("|cff00bfff[DjLust]|r |cffff8800No custom songs defined.|r")
            print("  Edit CustomSongs.lua to add your song filenames")
            return songs
        end
        
        -- Verify each song exists by trying to play it
        local foundSongs = {}
        local testedCount = 0
        
        for _, songFile in ipairs(CUSTOM_SONGS) do
            testedCount = testedCount + 1
            
            -- Clean up the filename (in case user added extra spaces)
            songFile = songFile:match("^%s*(.-)%s*$")
            
            if songFile ~= "" then
                local path = "Interface\\AddOns\\Songs\\" .. songFile
                local willPlay, handle = PlaySoundFile(path, "Master")
                if willPlay and handle then
                    table.insert(foundSongs, songFile)
                    StopSound(handle)
                else
                    print("|cff00bfff[DjLust]|r |cffff8800Warning:|r Could not find: " .. songFile)
                end
            end
        end
        
        -- Sort the found songs
        table.sort(foundSongs)
        
        -- Add all found songs to the list
        for _, song in ipairs(foundSongs) do
            table.insert(songs, song)
        end
        
        -- Feedback
        if #foundSongs == 0 then
            print("|cff00bfff[DjLust]|r |cffff8800No custom songs found.|r")
            print("  1. Put .mp3 files in: Interface\\AddOns\\Songs\\")
            print("  2. Add filenames to CustomSongs.lua")
            print("  3. Reload UI with /reload")
        else
            print("|cff00bfff[DjLust]|r Found |cff00ff00" .. #foundSongs .. "|r custom song(s)")
            if #foundSongs < testedCount then
                print("  |cffff8800(" .. (testedCount - #foundSongs) .. " song(s) not found - check filenames)|r")
            end
        end
        
        return songs
    end
    
    -- Refresh song list and update dropdown
    local function RefreshSongDropdown()
        local songs = GetAvailableSongs()
        
        UIDropDownMenu_Initialize(dropdown, function(self, level)
            local info = UIDropDownMenu_CreateInfo()
            
            for _, songFile in ipairs(songs) do
                info.text = songFile
                info.value = songFile
                info.func = function(self)
                    if songFile == "(None)" then
                        DjLustDB.customSong = ""
                    else
                        DjLustDB.customSong = songFile
                    end
                    UIDropDownMenu_SetText(dropdown, songFile)
                    CloseDropDownMenus()
                    
                    -- Auto-select custom theme when a song is picked
                    if songFile ~= "(None)" then
                        DjLustDB.theme = "custom"
                        chipiRadio:SetChecked(false)
                        pedroRadio:SetChecked(false)
                        customRadio:SetChecked(true)
                        if addon.UpdateTheme then
                            addon:UpdateTheme("custom")
                        end
                        print("|cff00bfff[DjLust]|r Custom song set to: |cff00ff00" .. songFile .. "|r")
                    end
                end
                info.checked = (DjLustDB.customSong == songFile) or (songFile == "(None)" and DjLustDB.customSong == "")
                UIDropDownMenu_AddButton(info)
            end
        end)
        
        -- Set initial text
        if DjLustDB.customSong and DjLustDB.customSong ~= "" then
            UIDropDownMenu_SetText(dropdown, DjLustDB.customSong)
        else
            UIDropDownMenu_SetText(dropdown, "(None)")
        end
    end
    
    RefreshSongDropdown()
    
    -- Refresh button (create after RefreshSongDropdown is defined)
    local refreshBtn = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
    refreshBtn:SetPoint("LEFT", dropdown, "RIGHT", -15, 2)
    refreshBtn:SetSize(31, 31)
    refreshBtn:SetText("scan") -- fix for refresh button to scan Songs\.
    refreshBtn:SetScript("OnClick", function()
        RefreshSongDropdown()
        print("|cff00bfff[DjLust]|r Rescanning Songs folder...")
    end)
    
    -- Enable/disable dropdown based on custom radio selection
    local function UpdateDropdownState()
        if DjLustDB.theme == "custom" then
            UIDropDownMenu_EnableDropDown(dropdown)
            refreshBtn:Enable()
        else
            UIDropDownMenu_DisableDropDown(dropdown)
            refreshBtn:Disable()
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
    -- Ensure volume is initialized
    DjLustDB.volume = DjLustDB.volume or 1.0
    
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
            print("|cff00bfff[DjLust]|r Animation position reset to center")
        end
    end)
    
    -- Reset Detection Button
    CreateActionButton(content, 225, yOffset, 180, "Reset Detection", function()
        SlashCmdList["DJLUST"]("reset")
    end)

    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Detection Section Header
    --------------------------------------------------
    local detectHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectHeader:SetPoint("TOPLEFT", 20, yOffset)
    detectHeader:SetText("|cffff8800Enable Debug Mode|r")
    yOffset = yOffset - 35
    
    --------------------------------------------------
    -- Debug Mode Checkbox
    --------------------------------------------------
    local debugCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 25, yOffset)
    debugCheck.text:SetText("Debug Mode")
    debugCheck:SetChecked(DjLustDB.debugMode)
    debugCheck:SetScript("OnClick", function(self)
        DjLustDB.debugMode = self:GetChecked()
        SlashCmdList["DJLUST"]("debug " .. (DjLustDB.debugMode and "on" or "off"))
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
        -- Ensure all settings have default values
        DjLustDB.volume = DjLustDB.volume or 1.0
        DjLustDB.theme = DjLustDB.theme or "chipi"
        DjLustDB.customSong = DjLustDB.customSong or ""
        
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
