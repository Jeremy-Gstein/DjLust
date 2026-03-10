-- SettingsGUI.lua: Custom settings panel for DjLust

local addonName, addon = ...

local settingsFrame

-- Tracks whether the animation was started via the "Toggle Animation" button
-- in this settings panel. Only set by that button; NOT set by bloodlust triggers.
local manualAnimActive = false

--------------------------------------------------
-- Popup: ask user whether to hide animation on settings close
-- Defined at module level so it's registered once at load time.
--------------------------------------------------
StaticPopupDialogs["DJLUST_HIDE_ANIM_ON_CLOSE"] = {
    text           = "|cff00bfffDjLust|r\nThe animation is still running.\nWould you like to hide it?",
    button1        = "Yes",
    button2        = "No",
    OnAccept = function()
        -- Stop the animation, then do a clean close
        if SlashCmdList["DJLANIM"] then
            SlashCmdList["DJLANIM"]("stop")
        end
        manualAnimActive = false
        local f = _G["DjLustSettingsFrame"]
        if f and f.allowClose then
            f.allowClose()
            f:Hide()
        end
    end,
    OnCancel = function()
        -- Leave animation running, just close settings
        local f = _G["DjLustSettingsFrame"]
        if f and f.allowClose then
            f.allowClose()
            f:Hide()
        end
    end,
    OnHide = function()
        -- Catches ESC on the popup (hideOnEscape skips OnAccept/OnCancel).
        -- OnAccept/OnCancel already called allowClose+Hide before this fires,
        -- so f:IsShown() will be false for those paths -- this becomes a no-op.
        local f = _G["DjLustSettingsFrame"]
        if f and f:IsShown() and f.allowClose then
            f.allowClose()
            f:Hide()
        end
    end,
    timeout        = 0,
    whileDead      = true,
    hideOnEscape   = true,
    preferredIndex = 3,
}

--------------------------------------------------
-- Ensure all DB fields exist with defaults
--------------------------------------------------
local function EnsureDBDefaults()
    if not DjLustDB then DjLustDB = {} end

    if DjLustDB.animationEnabled == nil then DjLustDB.animationEnabled = true  end
    if DjLustDB.debugMode        == nil then DjLustDB.debugMode        = false end
    if DjLustDB.animationLocked  == nil then DjLustDB.animationLocked  = false end

    DjLustDB.animationSize  = DjLustDB.animationSize  or 128
    DjLustDB.animationFPS   = DjLustDB.animationFPS   or 8
    DjLustDB.volume         = DjLustDB.volume         or 1.0
    DjLustDB.theme          = DjLustDB.theme          or "chipi"
    DjLustDB.customSong     = DjLustDB.customSong     or ""
    DjLustDB.animationX     = DjLustDB.animationX     or 0
    DjLustDB.animationY     = DjLustDB.animationY     or 0
    DjLustDB.hasteThreshold = DjLustDB.hasteThreshold or 25
    DjLustDB.soundChannel   = DjLustDB.soundChannel   or "Dialog"
    DjLustDB.muteSound      = DjLustDB.muteSound      or false

    if not DjLustDB.minimap then DjLustDB.minimap = {} end
    if DjLustDB.minimap.hide == nil then DjLustDB.minimap.hide = false end
end

--------------------------------------------------
-- Update UI values from database
--------------------------------------------------
local function UpdateUIValues(f)
    if not f or not f.uiElements then return end
    local ui = f.uiElements

    if ui.enableAnim   then ui.enableAnim:SetChecked(DjLustDB.animationEnabled)    end
    if ui.lockAnim     then ui.lockAnim:SetChecked(DjLustDB.animationLocked)       end
    if ui.debugCheck   then ui.debugCheck:SetChecked(DjLustDB.debugMode)           end
    if ui.muteCheck    then ui.muteCheck:SetChecked(DjLustDB.muteSound)            end
    if ui.minimapCheck then ui.minimapCheck:SetChecked(not DjLustDB.minimap.hide)  end

    if ui.chipiRadio   then ui.chipiRadio:SetChecked(DjLustDB.theme == "chipi")    end
    if ui.pedroRadio   then ui.pedroRadio:SetChecked(DjLustDB.theme == "pedro")    end
    if ui.customRadio  then ui.customRadio:SetChecked(DjLustDB.theme == "custom")  end

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
    if ui.channelRadios then
        for ch, btn in pairs(ui.channelRadios) do
            btn:SetChecked(DjLustDB.soundChannel == ch)
        end
    end
end

--------------------------------------------------
-- Create Settings Window
--------------------------------------------------
local function CreateSettingsWindow()
    if _G["DjLustSettingsFrame"] then
        return _G["DjLustSettingsFrame"]
    end

    EnsureDBDefaults()

    local WIDTH, HEIGHT = 450, 550

    local f = CreateFrame("Frame", "DjLustSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, HEIGHT)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetFrameLevel(100)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop",  f.StopMovingOrSizing)
    f:SetClampedToScreen(true)

    tinsert(UISpecialFrames, "DjLustSettingsFrame")

    f:SetBackdrop({
        bgFile   = "Interface\\ChatFrame\\ChatFrameBackground",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 11, right = 12, top = 12, bottom = 11 },
    })
    f:SetBackdropColor(0, 0, 0, 0.85)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", 0, -15)
    f.title:SetText("|cff00bfffDjLust Settings|r")

    -- ----------------------------------------------------------------
    -- allowClose guard: set by popup callbacks and HideSettings so that
    -- OnHide knows the close is intentional and shouldn't intercept.
    -- ----------------------------------------------------------------
    local allowClose = false
    f.allowClose = function() allowClose = true end

    -- OnHide is the single chokepoint for every close path:
    -- X button, ESC via UISpecialFrames, and programmatic f:Hide().
    f:SetScript("OnHide", function(self)
        if allowClose then
            allowClose = false  -- reset for next open/close cycle
            return
        end
        local af         = _G["DjLustAnimFrame"]
        local animRunning = af and af:IsShown()
        if manualAnimActive and animRunning then
            -- Abort the hide, re-show the frame, then ask the user
            self:Show()
            StaticPopup_Show("DJLUST_HIDE_ANIM_ON_CLOSE")
        else
            manualAnimActive = false  -- ensure flag is clean on normal close
        end
    end)

    -- X button: just call Hide(); OnHide handles the rest
    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ScrollFrame
    local scrollFrame = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT",     10, -45)
    scrollFrame:SetPoint("BOTTOMRIGHT", -30,  50)
    scrollFrame:EnableMouseWheel(true)
    scrollFrame:SetScript("OnMouseWheel", function(self, delta)
        local cur      = self:GetVerticalScroll()
        local maxScroll = self:GetVerticalScrollRange()
        self:SetVerticalScroll(math.max(0, math.min(maxScroll, cur - delta * 20)))
    end)

    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(WIDTH - 50, 500)
    scrollFrame:SetScrollChild(content)

    local yOffset = -10
    f.uiElements  = {}

    -- Button helper used throughout this function
    local function CreateActionButton(parent, x, y, width, text, onClick)
        local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
        btn:SetPoint("TOPLEFT", x, y)
        btn:SetSize(width, 25)
        btn:SetText(text)
        btn:SetScript("OnClick", onClick)
        return btn
    end

    --------------------------------------------------
    -- ANIMATION SETTINGS
    --------------------------------------------------
    local animHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    animHeader:SetPoint("TOPLEFT", 20, yOffset)
    animHeader:SetText("|cffff8800Animation Settings|r")
    yOffset = yOffset - 30

    -- Enable Animation | Lock Position  (same row)
    local enableAnim = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    enableAnim:SetPoint("TOPLEFT", 25, yOffset)
    enableAnim.text:SetText("Enable Animation")
    enableAnim:SetChecked(DjLustDB.animationEnabled)
    enableAnim:SetScript("OnClick", function(self)
        DjLustDB.animationEnabled = self:GetChecked()
        print("|cff00bfff[DjLust]|r Animation " ..
              (DjLustDB.animationEnabled and "|cff00ff00enabled|r" or "|cffff0000disabled|r"))
    end)
    f.uiElements.enableAnim = enableAnim

    local lockAnim = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    lockAnim:SetPoint("TOPLEFT", 220, yOffset)
    lockAnim.text:SetText("Lock Position")
    lockAnim:SetChecked(DjLustDB.animationLocked)
    lockAnim:SetScript("OnClick", function(self)
        local locked = self:GetChecked()
        if addon.SetAnimationLocked then
            addon:SetAnimationLocked(locked)
        else
            DjLustDB.animationLocked = locked
        end
    end)
    lockAnim:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff00bfffLock Animation Position|r")
        GameTooltip:AddLine("Prevents the animation from being dragged.", 1, 1, 1, true)
        GameTooltip:AddLine("Unlock to drag it to a new spot, then re-lock.", 0.8, 0.8, 0.8, true)
        GameTooltip:AddLine("|cff808080Also: /djlanim lock / unlock|r", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lockAnim:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.uiElements.lockAnim = lockAnim

    yOffset = yOffset - 30  -- one advance covers both checkboxes

    -- Quick-action Row 1: Test Music | Stop Music | Toggle Animation
    CreateActionButton(content, 25,  yOffset, 120, "Test Music", function()
        SlashCmdList["DJLUST"]("test")
    end)
    CreateActionButton(content, 155, yOffset, 120, "Stop Music", function()
        manualAnimActive = false
        SlashCmdList["DJLUST"]("stop")
    end)
    CreateActionButton(content, 285, yOffset, 120, "Toggle Animation", function()
        local af = _G["DjLustAnimFrame"]
        if af and af:IsShown() then
            manualAnimActive = false   -- turning OFF
        else
            manualAnimActive = true    -- turning ON -- prompt on close
        end
        SlashCmdList["DJLANIM"]("toggle")
    end)
    yOffset = yOffset - 35

    -- Quick-action Row 2: Reset Position | Reset Detection
    CreateActionButton(content, 25, yOffset, 190, "Reset Animation Position", function()
        local af = _G["DjLustAnimFrame"]
        if af then
            if DjLustDB.animationLocked then
                if addon.SetAnimationLocked then
                    addon:SetAnimationLocked(false)
                else
                    DjLustDB.animationLocked = false
                end
                if f.uiElements.lockAnim then
                    f.uiElements.lockAnim:SetChecked(false)
                end
            end
            af:ClearAllPoints()
            af:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            DjLustDB.animationX = 0
            DjLustDB.animationY = 0
            print("|cff00bfff[DjLust]|r Animation position reset to center")
        end
    end)
    CreateActionButton(content, 225, yOffset, 180, "Reset Detection", function()
        SlashCmdList["DJLUST"]("reset")
    end)
    yOffset = yOffset - 40

    -- Animation Size Slider
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
        value = math.floor(value / 16) * 16
        DjLustDB.animationSize = value
        sizeLabel:SetText("Animation Size: " .. value .. " px")
        if _G["DjLustAnimFrame"] then _G["DjLustAnimFrame"]:SetSize(value, value) end
    end)
    f.uiElements.sizeSlider = sizeSlider
    f.uiElements.sizeLabel  = sizeLabel
    yOffset = yOffset - 35

    -- Animation FPS Slider
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
        if addon.UpdateAnimationFPS then addon:UpdateAnimationFPS(value) end
    end)
    f.uiElements.fpsSlider = fpsSlider
    f.uiElements.fpsLabel  = fpsLabel
    yOffset = yOffset - 40

    --------------------------------------------------
    -- AUDIO SETTINGS
    --------------------------------------------------
    local audioHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    audioHeader:SetPoint("TOPLEFT", 20, yOffset)
    audioHeader:SetText("|cffff8800Audio Settings|r")
    yOffset = yOffset - 30

    local themeLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    themeLabel:SetPoint("TOPLEFT", 25, yOffset)
    themeLabel:SetText("Theme Selection:")
    yOffset = yOffset - 25

    local chipiRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    chipiRadio:SetPoint("TOPLEFT", 35, yOffset)
    chipiRadio.text:SetText("Chipi Chipi (Default)")
    chipiRadio:SetChecked(DjLustDB.theme == "chipi")

    local pedroRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    pedroRadio:SetPoint("TOPLEFT", 225, yOffset)
    pedroRadio.text:SetText("Pedro Theme")
    pedroRadio:SetChecked(DjLustDB.theme == "pedro")
    yOffset = yOffset - 25

    local customRadio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    customRadio:SetPoint("TOPLEFT", 35, yOffset)
    customRadio.text:SetText("Custom Song")
    customRadio:SetChecked(DjLustDB.theme == "custom")

    f.uiElements.chipiRadio  = chipiRadio
    f.uiElements.pedroRadio  = pedroRadio
    f.uiElements.customRadio = customRadio
    yOffset = yOffset - 30

    -- Custom Song Dropdown
    local dropdownLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    dropdownLabel:SetPoint("TOPLEFT", 55, yOffset)
    dropdownLabel:SetText("Select song from Interface\\AddOns\\Songs folder:")
    yOffset = yOffset - 20

    local dropdown = CreateFrame("Frame", "DjLustSongDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 45, yOffset)

    local function GetAvailableSongs()
        local songs = {"(None)"}
        if not CUSTOM_SONGS or type(CUSTOM_SONGS) ~= "table" then return songs end
        for _, songFile in ipairs(CUSTOM_SONGS) do
            songFile = songFile:match("^%s*(.-)%s*$")
            if songFile ~= "" then
                local path = "Interface\\AddOns\\Songs\\" .. songFile
                local willPlay, handle = PlaySoundFile(path, "Master")
                if willPlay and handle then
                    table.insert(songs, songFile)
                    StopSound(handle)
                end
            end
        end
        return songs
    end

    local function UpdateDropdownState()
        if DjLustDB.theme == "custom" then
            UIDropDownMenu_EnableDropDown(dropdown)
            dropdownLabel:SetTextColor(1, 1, 1)
        else
            UIDropDownMenu_DisableDropDown(dropdown)
            dropdownLabel:SetTextColor(0.5, 0.5, 0.5)
        end
    end

    local function InitDropdown(self, level)
        local info  = UIDropDownMenu_CreateInfo()
        local songs = GetAvailableSongs()
        for _, song in ipairs(songs) do
            info.text    = song
            info.value   = song
            info.checked = (DjLustDB.customSong == song) or
                           (song == "(None)" and DjLustDB.customSong == "")
            info.func = function()
                DjLustDB.customSong = (song == "(None)") and "" or song
                UIDropDownMenu_SetText(dropdown, song)
                if DjLustDB.theme == "custom" and addon.UpdateTheme then
                    addon:UpdateTheme("custom")
                    print("|cff00bfff[DjLust]|r Custom song changed to: " ..
                          (song == "(None)" and "None" or song))
                end
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, InitDropdown)
    UIDropDownMenu_SetWidth(dropdown, 250)
    UIDropDownMenu_SetText(dropdown,
        (DjLustDB.customSong and DjLustDB.customSong ~= "") and DjLustDB.customSong or "(None)")
    UpdateDropdownState()
    yOffset = yOffset - 35

    chipiRadio:SetScript("OnClick", function()
        DjLustDB.theme = "chipi"
        chipiRadio:SetChecked(true) ; pedroRadio:SetChecked(false) ; customRadio:SetChecked(false)
        UpdateDropdownState()
        if addon.UpdateTheme then addon:UpdateTheme("chipi") end
        print("|cff00bfff[DjLust]|r Theme changed to: |cffff1493Chipi Chipi|r")
    end)
    pedroRadio:SetScript("OnClick", function()
        DjLustDB.theme = "pedro"
        chipiRadio:SetChecked(false) ; pedroRadio:SetChecked(true) ; customRadio:SetChecked(false)
        UpdateDropdownState()
        if addon.UpdateTheme then addon:UpdateTheme("pedro") end
        print("|cff00bfff[DjLust]|r Theme changed to: |cff00ff00Pedro|r")
    end)
    customRadio:SetScript("OnClick", function()
        DjLustDB.theme = "custom"
        chipiRadio:SetChecked(false) ; pedroRadio:SetChecked(false) ; customRadio:SetChecked(true)
        UpdateDropdownState()
        if addon.UpdateTheme then addon:UpdateTheme("custom") end
        local songName = (DjLustDB.customSong ~= "") and DjLustDB.customSong or "No song selected"
        print("|cff00bfff[DjLust]|r Theme changed to: |cff9370dbCustom|r (" .. songName .. ")")
    end)

    -- Volume Slider
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
        if addon.UpdateVolume then addon:UpdateVolume(value) end
    end)
    f.uiElements.volumeSlider = volumeSlider
    f.uiElements.volumeLabel  = volumeLabel
    yOffset = yOffset - 35

    -- Sound Channel
    local channelHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    channelHeader:SetPoint("TOPLEFT", 25, yOffset)
    channelHeader:SetText("Sound Channel:")
    yOffset = yOffset - 20

    local channelHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    channelHelp:SetPoint("TOPLEFT", 25, yOffset)
    channelHelp:SetText("|cff808080If music is silent, try a different channel (Dialog is default)|r")
    yOffset = yOffset - 22

    local CHANNELS      = { "Dialog", "SFX", "Music", "Master", "Ambience" }
    local channelRadios = {}
    local colWidth      = 90
    for i, ch in ipairs(CHANNELS) do
        local col   = (i - 1) % 3
        local row   = math.floor((i - 1) / 3)
        local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 35 + col * colWidth, yOffset - row * 22)
        radio.text:SetText(ch)
        radio:SetChecked(DjLustDB.soundChannel == ch)
        local capturedCh = ch
        radio:SetScript("OnClick", function()
            DjLustDB.soundChannel = capturedCh
            for _, r in pairs(channelRadios) do r:SetChecked(false) end
            radio:SetChecked(true)
            if addon.SetSoundChannel then addon:SetSoundChannel(capturedCh) end
            print("|cff00bfff[DjLust]|r Sound channel set to: |cffff8800" .. capturedCh .. "|r")
        end)
        channelRadios[ch] = radio
    end
    f.uiElements.channelRadios = channelRadios
    yOffset = yOffset - 50

    -- Mute Checkbox
    local muteCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    muteCheck:SetPoint("TOPLEFT", 25, yOffset)
    muteCheck.text:SetText("Mute Sound (animation still plays)")
    muteCheck:SetChecked(DjLustDB.muteSound)
    muteCheck:SetScript("OnClick", function(self)
        if addon.SetMuteSound then
            addon:SetMuteSound(self:GetChecked())
        else
            DjLustDB.muteSound = self:GetChecked()
        end
    end)
    f.uiElements.muteCheck = muteCheck
    yOffset = yOffset - 35

    --------------------------------------------------
    -- MINIMAP
    --------------------------------------------------
    local minimapHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    minimapHeader:SetPoint("TOPLEFT", 20, yOffset)
    minimapHeader:SetText("|cffff8800Minimap|r")
    yOffset = yOffset - 30

    local minimapCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", 25, yOffset)
    minimapCheck.text:SetText("Show Minimap Button")
    minimapCheck:SetChecked(not DjLustDB.minimap.hide)
    minimapCheck:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        DjLustDB.minimap.hide = not show
        local btn = _G["DjLust_MinimapButton"]
        if show then
            if btn then
                btn:Show()
                btn:SetAlpha(btn.snapped and 0.01 or 1)
            elseif addon.CreateMinimapButton then
                addon.CreateMinimapButton()
            end
            print("|cff00bfff[DjLust]|r Minimap button |cff00ff00shown|r.")
        else
            if btn then btn:Hide() end
            print("|cff00bfff[DjLust]|r Minimap button |cffff0000hidden|r.")
        end
        if _G["DjLustOptionsMinimapCheck"] then
            _G["DjLustOptionsMinimapCheck"]:SetChecked(show)
        end
    end)
    f.uiElements.minimapCheck = minimapCheck
    yOffset = yOffset - 35

    --------------------------------------------------
    -- DETECTION SETTINGS
    --------------------------------------------------
    local detectSettingsHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectSettingsHeader:SetPoint("TOPLEFT", 20, yOffset)
    detectSettingsHeader:SetText("|cffff8800Detection Settings|r")
    yOffset = yOffset - 30

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
    f.uiElements.hasteLabel  = hasteLabel
    yOffset = yOffset - 35

    --------------------------------------------------
    -- DEBUG MODE
    --------------------------------------------------
    local detectHeader = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    detectHeader:SetPoint("TOPLEFT", 20, yOffset)
    detectHeader:SetText("|cffff8800Debug Mode|r")
    yOffset = yOffset - 30

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

    content:SetSize(WIDTH - 50, math.abs(yOffset) + 20)

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("BOTTOM", 0, 15)
    info:SetText("|cff808080Drag animation to reposition (when unlocked) | Use /djlust for all commands|r")

    f:Hide()
    settingsFrame = f
    return f
end

--------------------------------------------------
-- Public API
--------------------------------------------------
function addon:ToggleSettings()
    local f = _G["DjLustSettingsFrame"] or CreateSettingsWindow()
    if f:IsShown() then
        f:Hide()  -- OnHide intercepts and prompts if needed
    else
        EnsureDBDefaults()
        UpdateUIValues(f)
        f:Show()
    end
end

function addon:ShowSettings()
    local f = _G["DjLustSettingsFrame"] or CreateSettingsWindow()
    EnsureDBDefaults()
    UpdateUIValues(f)
    f:Show()
end

function addon:HideSettings()
    local f = _G["DjLustSettingsFrame"]
    if f then
        manualAnimActive = false
        if f.allowClose then f.allowClose() end
        f:Hide()
    end
end

--------------------------------------------------
-- WoW Options > AddOns Panel
--------------------------------------------------
local function RegisterOptionsPanel()
    local panel = CreateFrame("Frame")
    panel.name  = "DjLust"

    local LX, RX, CMDX, W = 16, 300, 220, 550
    local y = 0

    local function Fs(template, text, x, yExtra)
        local fs = panel:CreateFontString(nil, "ARTWORK", template)
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x or LX, y + (yExtra or 0))
        fs:SetJustifyH("LEFT")
        fs:SetText(text)
        return fs
    end
    local function Skip(px) y = y - px end
    local function Div()
        local d = panel:CreateTexture(nil, "ARTWORK")
        d:SetSize(W, 1)
        d:SetPoint("TOPLEFT", panel, "TOPLEFT", LX, y)
        d:SetColorTexture(0.35, 0.35, 0.35, 0.8)
    end

    Skip(16)
    Fs("GameFontNormalLarge", "|cff00bfffDjLust|r")
    Skip(22)
    Fs("GameFontHighlightSmall",
       "Plays music and animation when Bloodlust / Heroism is detected via haste spike.")
    Skip(14) ; Div() ; Skip(4)

    Skip(12)
    local check = CreateFrame("CheckButton", "DjLustOptionsMinimapCheck", panel,
                              "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", LX - 2, y + 2)
    check.Text:SetText("Show Minimap Button")
    check.tooltipText = "Show or hide the DjLust minimap icon. Saved across sessions."
    check:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        DjLustDB.minimap.hide = not show
        local mapBtn = _G["DjLust_MinimapButton"]
        if show then
            if mapBtn then
                mapBtn:Show()
                mapBtn:SetAlpha(mapBtn.snapped and 0.01 or 1)
            elseif addon.CreateMinimapButton then
                addon.CreateMinimapButton()
            end
            print("|cff00bfff[DjLust]|r Minimap button |cff00ff00shown|r.")
        else
            if mapBtn then mapBtn:Hide() end
            print("|cff00bfff[DjLust]|r Minimap button |cffff0000hidden|r.")
        end
        local sw = _G["DjLustSettingsFrame"]
        if sw and sw.uiElements and sw.uiElements.minimapCheck then
            sw.uiElements.minimapCheck:SetChecked(show)
        end
    end)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(190, 26)
    openBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", RX, y)
    openBtn:SetText("Open DjLust Settings")
    openBtn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel or InterfaceOptionsFrame)
        addon:ShowSettings()
    end)
    Skip(34) ; Div() ; Skip(4)

    Skip(12)
    Fs("GameFontNormal", "|cffff8800Slash Commands|r")
    Skip(18)

    local COMMANDS = {
        { "/djlust",                "Show all available commands"              },
        { "/djlust settings",       "Open the settings window"                 },
        { "/djlust test",           "Test music and animation playback"        },
        { "/djlust stop",           "Stop music and animation"                 },
        { "/djlust status",         "Show current detection status"            },
        { "/djlust reset",          "Reset haste baseline"                     },
        { "/djlust volume <0-100>", "Set volume  (e.g. /djlust volume 80)"     },
        { "/djlust minimap",        "Toggle minimap button on/off"             },
        { "/djlust minimap lock",   "Lock minimap button  (prevent dragging)"  },
        { "/djlust minimap reset",  "Reset minimap to default position"        },
        { "/djlanim lock",          "Lock animation position"                  },
        { "/djlanim unlock",        "Unlock animation position"                },
    }
    for _, row in ipairs(COMMANDS) do
        local cmd = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cmd:SetPoint("TOPLEFT", panel, "TOPLEFT", LX + 4, y)
        cmd:SetJustifyH("LEFT") ; cmd:SetWidth(CMDX - LX - 8)
        cmd:SetText("|cffffe066" .. row[1] .. "|r")
        local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", panel, "TOPLEFT", CMDX, y)
        desc:SetJustifyH("LEFT") ; desc:SetWidth(W - CMDX)
        desc:SetText("|cffaaaaaa" .. row[2] .. "|r")
        Skip(15)
    end

    Skip(4) ; Div() ; Skip(4)
    Skip(12)
    Fs("GameFontNormal", "|cffff8800Adding Custom Songs|r")
    Skip(18)

    local STEPX = 290
    local STEPS = {
        { "|cffffe0661.|r  Navigate to your WoW folder.",
          "|cffaaaaaaExample: ...\\World of Warcraft\\_retail_\\|r" },
        { "|cffffe0662.|r  Open  |cffffffff Interface\\AddOns\\|r",    "" },
        { "|cffffe0663.|r  Create a folder named  |cff00ff00Songs|r",
          "|cffaaaaaaInterface\\AddOns\\Songs\\|r" },
        { "|cffffe0664.|r  Copy your  |cffffffff .mp3|r  files into  |cff00ff00Songs|r", "" },
        { "|cffffe0665.|r  Edit  |cffffffff DjLust\\CustomSongs.lua|r",
          "Add to  |cff00ff00CUSTOM_SONGS|r:  |cffaaaaaa{ \"mysong.mp3\" }|r" },
        { "|cffffe0666.|r  Type  |cffffffff /reload|r  in-game.", "" },
        { "|cffffe0667.|r  In Settings pick  |cff00ff00Custom Song|r",
          "Select your song from the dropdown.  Done!" },
    }
    for i, row in ipairs(STEPS) do
        local left = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        left:SetPoint("TOPLEFT", panel, "TOPLEFT", LX + 4, y)
        left:SetJustifyH("LEFT") ; left:SetWidth(STEPX - LX - 8) ; left:SetText(row[1])
        if row[2] ~= "" then
            local right = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            right:SetPoint("TOPLEFT", panel, "TOPLEFT", STEPX, y)
            right:SetJustifyH("LEFT") ; right:SetWidth(W - STEPX) ; right:SetText(row[2])
        end
        Skip(15)
        if i < #STEPS then
            local sep = panel:CreateTexture(nil, "ARTWORK")
            sep:SetSize(W - LX * 2, 1)
            sep:SetPoint("TOPLEFT", panel, "TOPLEFT", LX, y)
            sep:SetColorTexture(0.25, 0.25, 0.25, 0.6)
            Skip(5)
        end
    end

    Div() ; Skip(4) ; Skip(90)
    Fs("GameFontHighlightSmall", "|cffff8800 GitHub  (issues, bugs, and feature requests):|r", LX)
    Fs("GameFontHighlightSmall", "|cffff8800 Seems Good Community:|r", RX)
    Skip(16)
    Fs("GameFontHighlightSmall", "|cff00bfffhttps://github.com/Jeremy-Gstein/DjLust|r", LX + 4)
    Fs("GameFontHighlightSmall", "|cff00bfffhttps://seemsgood.org|r", RX + 4)

    panel:SetScript("OnShow", function()
        EnsureDBDefaults()
        check:SetChecked(not DjLustDB.minimap.hide)
    end)

    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
        Settings.RegisterAddOnCategory(category)
    else
        InterfaceOptions_AddCategory(panel)
    end
end

--------------------------------------------------
-- Slash shortcut
--------------------------------------------------
SLASH_DJLSETTINGS1 = "/djlsettings"
SlashCmdList["DJLSETTINGS"] = function() addon:ToggleSettings() end

--------------------------------------------------
-- Addon load / slash hook
--------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, loadedAddon)
    if loadedAddon ~= addonName then return end

    C_Timer.After(0.1, function()
        EnsureDBDefaults()
        RegisterOptionsPanel()
        if DjLustDB.debugMode then
            C_Timer.After(0.2, function()
                if SlashCmdList["DJLUST"] then
                    SlashCmdList["DJLUST"]("debug on")
                end
            end)
        end
    end)

    -- Wrap the main slash handler to intercept "settings/config/options"
    C_Timer.After(0.2, function()
        if SlashCmdList["DJLUST"] then
            local orig = SlashCmdList["DJLUST"]
            SlashCmdList["DJLUST"] = function(msg)
                if msg == "settings" or msg == "config" or msg == "options" then
                    addon:ToggleSettings()
                else
                    orig(msg)
                end
            end
        end
    end)
end)
