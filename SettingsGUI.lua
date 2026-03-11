-- SettingsGUI.lua: Settings panel for DjLust
-- Sections: Animation | Music | Profiles | Detection | Minimap | Debug

local addonName, addon = ...

local settingsFrame

-- Tracks whether animation was manually toggled ON via the button in this panel.
local manualAnimActive = false

-- No popup needed: closing settings always stops any manual animation cleanly.


--------------------------------------------------
-- DB defaults + migration
--------------------------------------------------
local function EnsureDBDefaults()
    if not DjLustDB then DjLustDB = {} end

    -- Schema migration v1 (theme/customSong) to v2 (animationStyle/music)
    if DjLustDB.theme and not DjLustDB.animationStyle then
        local styleMap = { chipi="chipi", pedro="pedro", text="text", custom="chipi" }
        DjLustDB.animationStyle = styleMap[DjLustDB.theme] or "chipi"
        if DjLustDB.customSong and DjLustDB.customSong ~= "" then
            DjLustDB.music = DjLustDB.customSong
        end
        DjLustDB.theme      = nil
        DjLustDB.customSong = nil
    end
    if DjLustDB.animationEnabled ~= nil then DjLustDB.animationEnabled = nil end

    DjLustDB.animationStyle = DjLustDB.animationStyle or "chipi"
    DjLustDB.music          = DjLustDB.music          or ""
    DjLustDB.partyText      = DjLustDB.partyText      or "PARTY TIME!"
    DjLustDB.animationSize  = DjLustDB.animationSize  or 128
    DjLustDB.animationFPS   = DjLustDB.animationFPS   or 8
    DjLustDB.animationX     = DjLustDB.animationX     or 0
    DjLustDB.animationY     = DjLustDB.animationY     or 0
    DjLustDB.volume         = DjLustDB.volume         or 1.0
    DjLustDB.soundChannel   = DjLustDB.soundChannel   or "Dialog"
    DjLustDB.muteSound      = DjLustDB.muteSound      or false
    DjLustDB.hasteThreshold = DjLustDB.hasteThreshold or 25
    DjLustDB.debugMode      = DjLustDB.debugMode      or false
    if DjLustDB.animationLocked == nil then DjLustDB.animationLocked = false end
    if not DjLustDB.minimap      then DjLustDB.minimap = {} end
    if DjLustDB.minimap.hide == nil then DjLustDB.minimap.hide = false end
end

--------------------------------------------------
-- Sync UI from DB
--------------------------------------------------
local function UpdateUIValues(f)
    if not f or not f.uiElements then return end
    local ui = f.uiElements
    local s  = DjLustDB.animationStyle

    if ui.animChipi  then ui.animChipi:SetChecked(s == "chipi")  end
    if ui.animPedro  then ui.animPedro:SetChecked(s == "pedro")  end
    if ui.animText   then ui.animText:SetChecked(s == "text")    end
    if ui.animNone   then ui.animNone:SetChecked(s == "none")    end
    if ui.lockAnim   then ui.lockAnim:SetChecked(DjLustDB.animationLocked) end
    if ui.partyTextBox then ui.partyTextBox:SetText(DjLustDB.partyText or "PARTY TIME!") end

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
        ui.volumeLabel:SetText("Volume: " .. math.floor(DjLustDB.volume * 100) .. "%")
    end
    if ui.muteCheck then ui.muteCheck:SetChecked(DjLustDB.muteSound) end
    if ui.channelRadios then
        for ch, btn in pairs(ui.channelRadios) do
            btn:SetChecked(DjLustDB.soundChannel == ch)
        end
    end
    if ui.hasteSlider and ui.hasteLabel then
        ui.hasteSlider:SetValue(DjLustDB.hasteThreshold)
        ui.hasteLabel:SetText("Haste Threshold: " .. DjLustDB.hasteThreshold .. "%")
    end
    if ui.minimapCheck then ui.minimapCheck:SetChecked(not DjLustDB.minimap.hide) end
    if ui.debugCheck   then ui.debugCheck:SetChecked(DjLustDB.debugMode)          end
end

--------------------------------------------------
-- Create Settings Window
--------------------------------------------------
local function CreateSettingsWindow()
    if _G["DjLustSettingsFrame"] then return _G["DjLustSettingsFrame"] end

    EnsureDBDefaults()

    local WIDTH = 450

    local f = CreateFrame("Frame", "DjLustSettingsFrame", UIParent, "BackdropTemplate")
    f:SetSize(WIDTH, 600)
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
    f:SetBackdropColor(0, 0, 0, 0.88)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    f.title:SetPoint("TOP", 0, -15)
    f.title:SetText("|cff00bfffDjLust Settings|r")

    -- On close: stop any manually triggered music/animation
    f:SetScript("OnHide", function(self)
        if addon.StopMusic then addon:StopMusic() end
        if manualAnimActive then
            manualAnimActive = false
            if SlashCmdList["DJLANIM"] then SlashCmdList["DJLANIM"]("stop") end
        end
    end)

    local closeBtn = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    closeBtn:SetPoint("TOPRIGHT", -8, -8)
    closeBtn:SetScript("OnClick", function() f:Hide() end)

    -- ScrollFrame
    local scroll = CreateFrame("ScrollFrame", nil, f, "UIPanelScrollFrameTemplate")
    scroll:SetPoint("TOPLEFT",     10, -45)
    scroll:SetPoint("BOTTOMRIGHT", -30, 35)
    scroll:EnableMouseWheel(true)
    scroll:SetScript("OnMouseWheel", function(self, delta)
        local cur = self:GetVerticalScroll()
        self:SetVerticalScroll(math.max(0, math.min(self:GetVerticalScrollRange(), cur - delta * 20)))
    end)

    local content = CreateFrame("Frame", nil, scroll)
    content:SetSize(WIDTH - 50, 900)
    scroll:SetScrollChild(content)

    local y = -10         -- running yOffset
    f.uiElements = {}

    -- ── Layout helpers ─────────────────────────────────────────────────────

    local function Header(text)
        local fs = content:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
        fs:SetPoint("TOPLEFT", 20, y)
        fs:SetText("|cffff8800" .. text .. "|r")
        y = y - 28
    end

    local function Btn(x, w, text, fn)
        local b = CreateFrame("Button", nil, content, "UIPanelButtonTemplate")
        b:SetPoint("TOPLEFT", x, y)
        b:SetSize(w, 24)
        b:SetText(text)
        b:SetScript("OnClick", fn)
        return b
    end

    local function Sep()
        y = y - 8
        local line = content:CreateTexture(nil, "ARTWORK")
        line:SetSize(WIDTH - 60, 1)
        line:SetPoint("TOPLEFT", 10, y)
        line:SetColorTexture(0.3, 0.3, 0.3, 0.7)
        y = y - 12
    end

    local function Label(text, size)
        local fs = content:CreateFontString(nil, "OVERLAY",
                       size == "small" and "GameFontNormalSmall" or "GameFontNormal")
        fs:SetPoint("TOPLEFT", 25, y)
        fs:SetText(text)
        return fs
    end

    -- ── SECTION: ANIMATION ─────────────────────────────────────────────────
    Header("Animation")

    -- Radio row: Chipi | Pedro | Text | None  (all on one line)
    local animChipi = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    animChipi:SetPoint("TOPLEFT", 30, y)
    animChipi.text:SetText("Chipi Chipi")
    animChipi:SetChecked(DjLustDB.animationStyle == "chipi")

    local animPedro = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    animPedro:SetPoint("TOPLEFT", 145, y)
    animPedro.text:SetText("Pedro")
    animPedro:SetChecked(DjLustDB.animationStyle == "pedro")

    local animText = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    animText:SetPoint("TOPLEFT", 250, y)
    animText.text:SetText("Text")
    animText:SetChecked(DjLustDB.animationStyle == "text")

    local animNone = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
    animNone:SetPoint("TOPLEFT", 330, y)
    animNone.text:SetText("None")
    animNone:SetChecked(DjLustDB.animationStyle == "none")

    f.uiElements.animChipi = animChipi
    f.uiElements.animPedro = animPedro
    f.uiElements.animText  = animText
    f.uiElements.animNone  = animNone
    y = y - 30

    -- Party text row (visible only when Text is selected)
    local partyLabel = content:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    partyLabel:SetPoint("TOPLEFT", 30, y)
    partyLabel:SetText("Display Text:")

    local partyBox = CreateFrame("EditBox", "DjLustPartyTextBox", content, "InputBoxTemplate")
    partyBox:SetPoint("TOPLEFT", 125, y + 2)
    partyBox:SetWidth(245)
    partyBox:SetHeight(22)
    partyBox:SetAutoFocus(false)
    partyBox:SetMaxLetters(64)
    partyBox:SetText(DjLustDB.partyText or "PARTY TIME!")
    partyBox:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        local txt = self:GetText()
        if txt == "" then txt = "PARTY TIME!" end
        DjLustDB.partyText = txt
        self:SetText(txt)
        if addon.UpdatePartyText then addon:UpdatePartyText(txt) end
    end)
    partyBox:SetScript("OnEscapePressed", function(self)
        self:SetText(DjLustDB.partyText or "PARTY TIME!")
        self:ClearFocus()
    end)
    f.uiElements.partyTextBox = partyBox

    local partyHint = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    partyHint:SetPoint("TOPLEFT", 375, y)
    partyHint:SetText("|cff606060Enter|r")

    local function RefreshPartyText()
        local show = DjLustDB.animationStyle == "text"
        if show then partyLabel:Show() ; partyBox:Show() ; partyHint:Show()
        else         partyLabel:Hide() ; partyBox:Hide() ; partyHint:Hide() end
    end
    RefreshPartyText()
    y = y - 30

    -- Sync all four radios + side effects
    local function SetAnimStyle(style)
        DjLustDB.animationStyle = style
        animChipi:SetChecked(style == "chipi")
        animPedro:SetChecked(style == "pedro")
        animText:SetChecked(style == "text")
        animNone:SetChecked(style == "none")
        RefreshPartyText()
        if addon.UpdateTheme then addon:UpdateTheme(style) end
    end
    animChipi:SetScript("OnClick", function() SetAnimStyle("chipi") end)
    animPedro:SetScript("OnClick", function() SetAnimStyle("pedro") end)
    animText:SetScript("OnClick",  function() SetAnimStyle("text")  end)
    animNone:SetScript("OnClick",  function() SetAnimStyle("none")  end)

    -- Test / Stop animation buttons
    Btn(25,  185, "Test Animation", function()
        manualAnimActive = true
        SlashCmdList["DJLANIM"]("start")
    end)
    Btn(220, 185, "Stop Animation", function()
        manualAnimActive = false
        SlashCmdList["DJLANIM"]("stop")
    end)
    y = y - 32

    -- Lock Position
    local lockAnim = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    lockAnim:SetPoint("TOPLEFT", 25, y)
    lockAnim.text:SetText("Lock Position")
    lockAnim:SetChecked(DjLustDB.animationLocked)
    lockAnim:SetScript("OnClick", function(self)
        if addon.SetAnimationLocked then
            addon:SetAnimationLocked(self:GetChecked())
        else
            DjLustDB.animationLocked = self:GetChecked()
        end
    end)
    lockAnim:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine("|cff00bfffLock Animation Position|r")
        GameTooltip:AddLine("Prevents accidental dragging.", 1, 1, 1, true)
        GameTooltip:Show()
    end)
    lockAnim:SetScript("OnLeave", function() GameTooltip:Hide() end)
    f.uiElements.lockAnim = lockAnim
    y = y - 30

    -- Size slider
    local sizeLabel = Label("Animation Size: " .. DjLustDB.animationSize .. " px")
    y = y - 22
    local sizeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    sizeSlider:SetPoint("TOPLEFT", 25, y)
    sizeSlider:SetWidth(380) ; sizeSlider:SetMinMaxValues(32, 512)
    sizeSlider:SetValue(DjLustDB.animationSize) ; sizeSlider:SetValueStep(16)
    sizeSlider:SetObeyStepOnDrag(true)
    sizeSlider.Low:SetText("32") ; sizeSlider.High:SetText("512")
    sizeSlider:SetScript("OnValueChanged", function(self, v)
        v = math.floor(v / 16) * 16
        DjLustDB.animationSize = v
        sizeLabel:SetText("Animation Size: " .. v .. " px")
        if _G["DjLustAnimFrame"] then _G["DjLustAnimFrame"]:SetSize(v, v) end
    end)
    f.uiElements.sizeSlider = sizeSlider
    f.uiElements.sizeLabel  = sizeLabel
    y = y - 32

    -- FPS slider
    local fpsLabel = Label("Animation Speed: " .. DjLustDB.animationFPS .. " FPS")
    y = y - 22
    local fpsSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    fpsSlider:SetPoint("TOPLEFT", 25, y)
    fpsSlider:SetWidth(380) ; fpsSlider:SetMinMaxValues(1, 30)
    fpsSlider:SetValue(DjLustDB.animationFPS) ; fpsSlider:SetValueStep(1)
    fpsSlider:SetObeyStepOnDrag(true)
    fpsSlider.Low:SetText("1") ; fpsSlider.High:SetText("30")
    fpsSlider:SetScript("OnValueChanged", function(self, v)
        DjLustDB.animationFPS = v
        fpsLabel:SetText("Animation Speed: " .. v .. " FPS")
        if addon.UpdateAnimationFPS then addon:UpdateAnimationFPS(v) end
    end)
    f.uiElements.fpsSlider = fpsSlider
    f.uiElements.fpsLabel  = fpsLabel
    y = y - 36

    Sep()

    -- ── SECTION: MUSIC ─────────────────────────────────────────────────────
    Header("Music")

    -- Song dropdown
    local songNote = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    songNote:SetPoint("TOPLEFT", 25, y)
    songNote:SetText("Song:")
    y = y - 20

    local dropdown = CreateFrame("Frame", "DjLustSongDropdown", content, "UIDropDownMenuTemplate")
    dropdown:SetPoint("TOPLEFT", 25, y)

    local function GetAvailableSongs()
        local BUILTIN = {
            { label = "Chipi Chipi (built-in)", path = "Interface\\AddOns\\DjLust\\chipilust.mp3" },
            { label = "Pedro (built-in)",       path = "Interface\\AddOns\\DjLust\\pedrolust.mp3" },
        }
        local songs = { { label = "(None / Default)", path = "" } }
        for _, e in ipairs(BUILTIN) do
            local ok, h = PlaySoundFile(e.path, "Master")
            if ok and h then table.insert(songs, e) ; StopSound(h) end
        end
        if CUSTOM_SONGS and type(CUSTOM_SONGS) == "table" then
            for _, file in ipairs(CUSTOM_SONGS) do
                file = file:match("^%s*(.-)%s*$")
                if file ~= "" then
                    local path = "Interface\\AddOns\\Songs\\" .. file
                    local ok, h = PlaySoundFile(path, "Master")
                    if ok and h then
                        table.insert(songs, { label = file, path = path })
                        StopSound(h)
                    end
                end
            end
        end
        return songs
    end

    local function InitDropdown(self, level)
        local info  = UIDropDownMenu_CreateInfo()
        local songs = GetAvailableSongs()
        for _, e in ipairs(songs) do
            info.text    = e.label
            info.value   = e.path
            info.checked = (DjLustDB.music == e.path) or
                           (e.path == "" and DjLustDB.music == "")
            info.func = function()
                DjLustDB.music = e.path
                UIDropDownMenu_SetText(dropdown, e.label)
                if addon.UpdateMusic then addon:UpdateMusic(e.path) end
                print("|cff00bfff[DjLust]|r Music: " ..
                      (e.path == "" and "default (Chipi Chipi)" or e.label))
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end

    UIDropDownMenu_Initialize(dropdown, InitDropdown)
    UIDropDownMenu_SetWidth(dropdown, 280)
    do
        local songs = GetAvailableSongs()
        local display = "(None / Default)"
        for _, e in ipairs(songs) do
            if e.path == DjLustDB.music then display = e.label ; break end
        end
        UIDropDownMenu_SetText(dropdown, display)
    end
    y = y - 35

    -- Volume slider
    local volumeLabel = Label("Volume: " .. math.floor(DjLustDB.volume * 100) .. "%")
    y = y - 22
    local volumeSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    volumeSlider:SetPoint("TOPLEFT", 25, y)
    volumeSlider:SetWidth(380) ; volumeSlider:SetMinMaxValues(0, 1)
    volumeSlider:SetValue(DjLustDB.volume) ; volumeSlider:SetValueStep(0.05)
    volumeSlider:SetObeyStepOnDrag(true)
    volumeSlider.Low:SetText("0%") ; volumeSlider.High:SetText("100%")
    volumeSlider:SetScript("OnValueChanged", function(self, v)
        DjLustDB.volume = v
        volumeLabel:SetText("Volume: " .. math.floor(v * 100) .. "%")
        if addon.UpdateVolume then addon:UpdateVolume(v) end
    end)
    f.uiElements.volumeSlider = volumeSlider
    f.uiElements.volumeLabel  = volumeLabel
    y = y - 32

    -- Sound channel
    Label("Sound Channel:")
    y = y - 18
    local chHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    chHelp:SetPoint("TOPLEFT", 25, y)
    chHelp:SetText("|cff606060If music is silent, try a different channel (Dialog is recommended)|r")
    y = y - 22

    local CHANNELS      = { "Dialog", "SFX", "Music", "Master", "Ambience" }
    local channelRadios = {}
    local colW          = 90
    for i, ch in ipairs(CHANNELS) do
        local col   = (i - 1) % 3
        local row   = math.floor((i - 1) / 3)
        local radio = CreateFrame("CheckButton", nil, content, "UIRadioButtonTemplate")
        radio:SetPoint("TOPLEFT", 35 + col * colW, y - row * 22)
        radio.text:SetText(ch)
        radio:SetChecked(DjLustDB.soundChannel == ch)
        local cap = ch
        radio:SetScript("OnClick", function()
            DjLustDB.soundChannel = cap
            for _, r in pairs(channelRadios) do r:SetChecked(false) end
            radio:SetChecked(true)
            if addon.SetSoundChannel then addon:SetSoundChannel(cap) end
            print("|cff00bfff[DjLust]|r Sound channel: |cffff8800" .. cap .. "|r")
        end)
        channelRadios[ch] = radio
    end
    f.uiElements.channelRadios = channelRadios
    y = y - 50

    -- Mute
    local muteCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    muteCheck:SetPoint("TOPLEFT", 25, y)
    muteCheck.text:SetText("Mute Sound (animation still plays)")
    muteCheck:SetChecked(DjLustDB.muteSound)
    muteCheck:SetScript("OnClick", function(self)
        if addon.SetMuteSound then addon:SetMuteSound(self:GetChecked())
        else DjLustDB.muteSound = self:GetChecked() end
    end)
    f.uiElements.muteCheck = muteCheck
    y = y - 32

    -- Music action buttons
    Btn(25,  185, "Test Music", function()
        if addon.TestMusic then addon:TestMusic() end
    end)
    Btn(220, 185, "Stop Music", function()
        if addon.StopMusic then addon:StopMusic()
        else SlashCmdList["DJLUST"]("stop") end
    end)
    y = y - 32

    Sep()

    -- ── SECTION: DETECTION ─────────────────────────────────────────────────
    Header("Detection")

    local hasteLabel = Label("Haste Threshold: " .. DjLustDB.hasteThreshold .. "%")
    y = y - 18
    local hasteHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hasteHelp:SetPoint("TOPLEFT", 25, y)
    hasteHelp:SetText("|cff606060Minimum haste spike required to trigger (default 25%)|r")
    y = y - 24
    local hasteSlider = CreateFrame("Slider", nil, content, "OptionsSliderTemplate")
    hasteSlider:SetPoint("TOPLEFT", 25, y)
    hasteSlider:SetWidth(380) ; hasteSlider:SetMinMaxValues(10, 50)
    hasteSlider:SetValue(DjLustDB.hasteThreshold) ; hasteSlider:SetValueStep(1)
    hasteSlider:SetObeyStepOnDrag(true)
    hasteSlider.Low:SetText("10%") ; hasteSlider.High:SetText("50%")
    hasteSlider:SetScript("OnValueChanged", function(self, v)
        DjLustDB.hasteThreshold = v
        hasteLabel:SetText("Haste Threshold: " .. v .. "%")
    end)
    f.uiElements.hasteSlider = hasteSlider
    f.uiElements.hasteLabel  = hasteLabel
    y = y - 36

    Sep()

    -- ── SECTION: PROFILES ──────────────────────────────────────────────────
    Header("Profiles")

    local profHelp = content:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    profHelp:SetPoint("TOPLEFT", 25, y)
    profHelp:SetText("|cff808080Quick-set animation and music together|r")
    y = y - 26

    Btn(25, 185, "Chipi Chipi Profile", function()
        SetAnimStyle("chipi")
        DjLustDB.music = "Interface\\AddOns\\DjLust\\chipilust.mp3"
        if addon.UpdateMusic then addon:UpdateMusic(DjLustDB.music) end
        UIDropDownMenu_SetText(dropdown, "Chipi Chipi (built-in)")
        print("|cff00bfff[DjLust]|r Profile: |cffff1493Chipi Chipi|r")
    end)
    Btn(220, 185, "Pedro Profile", function()
        SetAnimStyle("pedro")
        DjLustDB.music = "Interface\\AddOns\\DjLust\\pedrolust.mp3"
        if addon.UpdateMusic then addon:UpdateMusic(DjLustDB.music) end
        UIDropDownMenu_SetText(dropdown, "Pedro (built-in)")
        print("|cff00bfff[DjLust]|r Profile: |cff00ff00Pedro|r")
    end)
    y = y - 36

    Sep()

    -- ── SECTION: MINIMAP ───────────────────────────────────────────────────
    Header("Minimap")

    local minimapCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    minimapCheck:SetPoint("TOPLEFT", 25, y)
    minimapCheck.text:SetText("Show Minimap Button")
    minimapCheck:SetChecked(not DjLustDB.minimap.hide)
    minimapCheck:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        DjLustDB.minimap.hide = not show
        local btn = _G["DjLust_MinimapButton"]
        if show then
            if btn then btn:Show() ; btn:SetAlpha(btn.snapped and 0.01 or 1)
            elseif addon.CreateMinimapButton then addon.CreateMinimapButton() end
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
    y = y - 36

    Sep()

    -- ── SECTION: DEBUG ─────────────────────────────────────────────────────
    Header("Debug")

    local debugCheck = CreateFrame("CheckButton", nil, content, "UICheckButtonTemplate")
    debugCheck:SetPoint("TOPLEFT", 25, y)
    debugCheck.text:SetText("Enable Debug Output")
    debugCheck:SetChecked(DjLustDB.debugMode)
    debugCheck:SetScript("OnClick", function(self)
        DjLustDB.debugMode = self:GetChecked()
        SlashCmdList["DJLUST"]("debug " .. (DjLustDB.debugMode and "on" or "off"))
    end)
    f.uiElements.debugCheck = debugCheck
    y = y - 32

    Btn(25, 190, "Reset Anim Position", function()
        local af = _G["DjLustAnimFrame"]
        if af then
            if DjLustDB.animationLocked then
                if addon.SetAnimationLocked then addon:SetAnimationLocked(false) end
                DjLustDB.animationLocked = false
                if f.uiElements.lockAnim then f.uiElements.lockAnim:SetChecked(false) end
            end
            af:ClearAllPoints()
            af:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
            DjLustDB.animationX, DjLustDB.animationY = 0, 0
            print("|cff00bfff[DjLust]|r Animation position reset to center")
        end
    end)
    Btn(225, 175, "Reset Detection", function()
        SlashCmdList["DJLUST"]("reset")
    end)
    y = y - 36

    -- Resize content to actual height used
    content:SetSize(WIDTH - 50, math.abs(y) + 20)

    local info = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    info:SetPoint("BOTTOM", 0, 12)
    info:SetText("|cff606060Drag animation to reposition (when unlocked) | /djlust for all commands|r")

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
        f:Hide()
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
    local py = 0

    local function Fs(tmpl, text, x)
        local fs = panel:CreateFontString(nil, "ARTWORK", tmpl)
        fs:SetPoint("TOPLEFT", panel, "TOPLEFT", x or LX, py)
        fs:SetJustifyH("LEFT") ; fs:SetText(text)
        return fs
    end
    local function Skip(n) py = py - n end
    local function Div()
        local d = panel:CreateTexture(nil, "ARTWORK")
        d:SetSize(W, 1) ; d:SetPoint("TOPLEFT", panel, "TOPLEFT", LX, py)
        d:SetColorTexture(0.35, 0.35, 0.35, 0.8)
    end

    Skip(16)
    Fs("GameFontNormalLarge", "|cff00bfffDjLust|r")
    Skip(22)
    Fs("GameFontHighlightSmall",
       "Plays music and animation when Bloodlust / Heroism is detected via haste spike.")
    Skip(14) ; Div() ; Skip(4) ; Skip(12)

    local check = CreateFrame("CheckButton", "DjLustOptionsMinimapCheck", panel,
                              "InterfaceOptionsCheckButtonTemplate")
    check:SetPoint("TOPLEFT", panel, "TOPLEFT", LX - 2, py + 2)
    check.Text:SetText("Show Minimap Button")
    check.tooltipText = "Show or hide the DjLust minimap icon."
    check:SetScript("OnClick", function(self)
        local show = self:GetChecked()
        DjLustDB.minimap.hide = not show
        local mb = _G["DjLust_MinimapButton"]
        if show then
            if mb then mb:Show() ; mb:SetAlpha(mb.snapped and 0.01 or 1)
            elseif addon.CreateMinimapButton then addon.CreateMinimapButton() end
        else
            if mb then mb:Hide() end
        end
        local sw = _G["DjLustSettingsFrame"]
        if sw and sw.uiElements and sw.uiElements.minimapCheck then
            sw.uiElements.minimapCheck:SetChecked(show)
        end
    end)

    local openBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
    openBtn:SetSize(190, 26)
    openBtn:SetPoint("TOPLEFT", panel, "TOPLEFT", RX, py)
    openBtn:SetText("Open DjLust Settings")
    openBtn:SetScript("OnClick", function()
        HideUIPanel(SettingsPanel or InterfaceOptionsFrame)
        addon:ShowSettings()
    end)
    Skip(34) ; Div() ; Skip(4) ; Skip(12)

    Fs("GameFontNormal", "|cffff8800Slash Commands|r")
    Skip(18)

    local COMMANDS = {
        { "/djlust",                "Show all available commands"             },
        { "/djlust settings",       "Open the settings window"                },
        { "/djlust test",           "Test music and animation"                },
        { "/djlust stop",           "Stop music and animation"                },
        { "/djlust status",         "Show detection status"                   },
        { "/djlust reset",          "Reset haste baseline"                    },
        { "/djlust volume <0-100>", "Set volume (e.g. /djlust volume 80)"     },
        { "/djlust minimap",        "Toggle minimap button"                   },
        { "/djlanim lock",          "Lock animation position"                 },
        { "/djlanim unlock",        "Unlock animation position"               },
    }
    for _, row in ipairs(COMMANDS) do
        local cmd = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        cmd:SetPoint("TOPLEFT", panel, "TOPLEFT", LX + 4, py)
        cmd:SetJustifyH("LEFT") ; cmd:SetWidth(CMDX - LX - 8)
        cmd:SetText("|cffffe066" .. row[1] .. "|r")
        local desc = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        desc:SetPoint("TOPLEFT", panel, "TOPLEFT", CMDX, py)
        desc:SetJustifyH("LEFT") ; desc:SetWidth(W - CMDX)
        desc:SetText("|cffaaaaaa" .. row[2] .. "|r")
        Skip(15)
    end

    Skip(4) ; Div() ; Skip(4) ; Skip(12)
    Fs("GameFontNormal", "|cffff8800Adding Custom Songs|r")
    Skip(18)

    local STEPX = 290
    local STEPS = {
        { "|cffffe0661.|r  Navigate to your WoW folder.",
          "|cffaaaaaa...\\World of Warcraft\\_retail_\\|r" },
        { "|cffffe0662.|r  Open  |cffffffff Interface\\AddOns\\|r", "" },
        { "|cffffe0663.|r  Create folder  |cff00ff00Songs|r",
          "|cffaaaaaa Interface\\AddOns\\Songs\\|r" },
        { "|cffffe0664.|r  Copy  |cffffffff .mp3|r  files into  |cff00ff00Songs|r", "" },
        { "|cffffe0665.|r  Edit  |cffffffff DjLust\\CustomSongs.lua|r",
          "Add filename to  |cff00ff00CUSTOM_SONGS|r" },
        { "|cffffe0666.|r  Type  |cffffffff /reload|r  in-game.", "" },
        { "|cffffe0667.|r  Settings -> Music -> dropdown", "Select song. Done!" },
    }
    for i, row in ipairs(STEPS) do
        local left = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
        left:SetPoint("TOPLEFT", panel, "TOPLEFT", LX + 4, py)
        left:SetJustifyH("LEFT") ; left:SetWidth(STEPX - LX - 8) ; left:SetText(row[1])
        if row[2] ~= "" then
            local right = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
            right:SetPoint("TOPLEFT", panel, "TOPLEFT", STEPX, py)
            right:SetJustifyH("LEFT") ; right:SetWidth(W - STEPX) ; right:SetText(row[2])
        end
        Skip(15)
        if i < #STEPS then
            local sep = panel:CreateTexture(nil, "ARTWORK")
            sep:SetSize(W - LX * 2, 1)
            sep:SetPoint("TOPLEFT", panel, "TOPLEFT", LX, py)
            sep:SetColorTexture(0.25, 0.25, 0.25, 0.6)
            Skip(5)
        end
    end

    Div() ; Skip(4) ; Skip(60)
    Fs("GameFontHighlightSmall", "|cffff8800 Issues | Bugs | Feedback -> Use GitHub:|r", LX)
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
-- Addon load
--------------------------------------------------
local loadFrame = CreateFrame("Frame")
loadFrame:RegisterEvent("ADDON_LOADED")
loadFrame:SetScript("OnEvent", function(self, event, loadedAddon)
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
