-- MinimapButton.lua: Minimap button for DjLust
-- Using proven LibDBIcon-style positioning

local addonName, addon = ...

local BUTTON_NAME = "DjLust_MinimapButton"

-- Initialize saved position
DjLustDB = DjLustDB or {}
DjLustDB.minimap = DjLustDB.minimap or {
    angle = 225,
    hide = false,
}

--------------------------------------------------
-- Positioning (based on LibDBIcon)
--------------------------------------------------
local function UpdateButtonPosition(button)
    local angle = math.rad(DjLustDB.minimap.angle or 225)
    local x, y, q = math.cos(angle), math.sin(angle), 1
    
    if x < 0 then q = q + 1 end
    if y > 0 then q = q + 2 end
    
    -- For round minimaps, always use 105 radius
    x, y = x * 105, y * 105
    
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--------------------------------------------------
-- Creation
--------------------------------------------------
local function CreateMinimapButton()
    if _G[BUTTON_NAME] then
        UpdateButtonPosition(_G[BUTTON_NAME])
        return
    end
    
    local btn = CreateFrame("Button", BUTTON_NAME, Minimap)
    btn:SetSize(31, 31)  -- LibDBIcon uses 31x31
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    btn:RegisterForDrag("LeftButton")
    btn:SetClampedToScreen(true)
    
    --------------------------------------------------
    -- Border (OVERLAY, positioned first)
    --------------------------------------------------
    btn.border = btn:CreateTexture(nil, "OVERLAY")
    btn.border:SetSize(53, 53)
    btn.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
    btn.border:SetPoint("TOPLEFT")
    
    --------------------------------------------------
    -- Icon (ARTWORK layer, smaller size)
    --------------------------------------------------
    btn.icon = btn:CreateTexture(nil, "ARTWORK")
    btn.icon:SetSize(17, 17)
    btn.icon:SetTexture("Interface\\Icons\\Spell_Nature_BloodLust")  -- Bloodlust icon!
    btn.icon:SetPoint("CENTER")
    btn.icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
    
    --------------------------------------------------
    -- Highlight
    --------------------------------------------------
    btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight", "ADD")
    
    --------------------------------------------------
    -- Tooltip
    --------------------------------------------------
    btn:SetScript("OnEnter", function(self)
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:AddLine("|cff00bfffDjLust|r", 1, 1, 1)
        GameTooltip:AddLine(" ")
        GameTooltip:AddLine("|cffff8800Left Click:|r Open Settings", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffff8800Right Click:|r Quick Menu", 0.8, 0.8, 0.8)
        GameTooltip:AddLine("|cffff8800Drag:|r Move Icon", 0.8, 0.8, 0.8)
        GameTooltip:Show()
    end)
    btn:SetScript("OnLeave", function()
        GameTooltip:Hide()
    end)
    
    --------------------------------------------------
    -- Click
    --------------------------------------------------
    btn:SetScript("OnClick", function(self, button)
        if button == "LeftButton" then
            -- Open settings
            if addon.ToggleSettings then
                addon:ToggleSettings()
            else
                SlashCmdList["DJLUST"]("settings")
            end
        elseif button == "RightButton" then
            -- Show quick menu
            ShowQuickMenu(self)
        end
    end)
    
    --------------------------------------------------
    -- Drag
    --------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self:SetScript("OnUpdate", function()
            local mx, my = Minimap:GetCenter()
            local cx, cy = GetCursorPosition()
            local scale = Minimap:GetEffectiveScale()
            cx, cy = cx / scale, cy / scale
            local angle = math.deg(math.atan2(cy - my, cx - mx)) % 360
            DjLustDB.minimap.angle = angle
            UpdateButtonPosition(self)
        end)
    end)
    btn:SetScript("OnDragStop", function(self)
        self:SetScript("OnUpdate", nil)
    end)
    
    UpdateButtonPosition(btn)
    
    -- Hide if configured
    if DjLustDB.minimap.hide then
        btn:Hide()
    end
end

--------------------------------------------------
-- Quick Menu (Right Click)
--------------------------------------------------
local menuFrame
function ShowQuickMenu(parent)
    if not menuFrame then
        menuFrame = CreateFrame("Frame", "DjLustQuickMenu", UIParent, "UIDropDownMenuTemplate")
    end
    
    local menuList = {
        {
            text = "|cff00bfffDjLust Quick Menu|r",
            isTitle = true,
            notCheckable = true,
        },
        {
            text = " ",
            notCheckable = true,
            disabled = true,
        },
        {
            text = "|cffff8800Test Music|r",
            notCheckable = true,
            func = function()
                SlashCmdList["DJLUST"]("test")
            end,
        },
        {
            text = "|cffff8800Stop Music|r",
            notCheckable = true,
            func = function()
                SlashCmdList["DJLUST"]("stop")
            end,
        },
        {
            text = "|cffff8800Toggle Animation|r",
            notCheckable = true,
            func = function()
                SlashCmdList["DJLANIM"]("toggle")
            end,
        },
        {
            text = " ",
            notCheckable = true,
            disabled = true,
        },
        {
            text = "|cffff8800Show Status|r",
            notCheckable = true,
            func = function()
                SlashCmdList["DJLUST"]("status")
            end,
        },
        {
            text = "|cffff8800Reset Detection|r",
            notCheckable = true,
            func = function()
                SlashCmdList["DJLUST"]("reset")
            end,
        },
        {
            text = " ",
            notCheckable = true,
            disabled = true,
        },
        {
            text = "Debug Mode",
            checked = function() return DjLustDB.debugMode end,
            func = function()
                DjLustDB.debugMode = not DjLustDB.debugMode
                SlashCmdList["DJLUST"]("debug " .. (DjLustDB.debugMode and "on" or "off"))
            end,
        },
        {
            text = " ",
            notCheckable = true,
            disabled = true,
        },
        {
            text = "|cffff8800Open Settings|r",
            notCheckable = true,
            func = function()
                if addon.ToggleSettings then
                    addon:ShowSettings()
                else
                    SlashCmdList["DJLUST"]("settings")
                end
            end,
        },
        {
            text = "Hide Minimap Button",
            notCheckable = true,
            func = function()
                DjLustDB.minimap.hide = true
                _G[BUTTON_NAME]:Hide()
                print("|cff00bfff[DjLust]|r Minimap button hidden. Use |cffff8800/djlust minimap|r to show it again.")
            end,
        },
        {
            text = "|cff808080Close|r",
            notCheckable = true,
            func = function() end,
        },
    }
    
    EasyMenu(menuList, menuFrame, "cursor", 0, 0, "MENU")
end

--------------------------------------------------
-- Slash Command to Toggle Minimap Button
--------------------------------------------------
local originalSlashHandler
local function HookSlashCommand()
    if not SlashCmdList["DJLUST"] then
        -- Not loaded yet, try again later
        C_Timer.After(0.5, HookSlashCommand)
        return
    end
    
    originalSlashHandler = SlashCmdList["DJLUST"]
    SlashCmdList["DJLUST"] = function(msg)
        if msg == "minimap" then
            DjLustDB.minimap.hide = not DjLustDB.minimap.hide
            local btn = _G[BUTTON_NAME]
            if btn then
                if DjLustDB.minimap.hide then
                    btn:Hide()
                    print("|cff00bfff[DjLust]|r Minimap button hidden")
                else
                    btn:Show()
                    print("|cff00bfff[DjLust]|r Minimap button shown")
                end
            end
        else
            originalSlashHandler(msg)
        end
    end
end

--------------------------------------------------
-- Init
--------------------------------------------------
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
    CreateMinimapButton()
    HookSlashCommand()
end)
