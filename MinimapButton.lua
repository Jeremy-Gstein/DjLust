-- MinimapButton.lua: Minimap button for DjLust
-- Hybrid snap/free-form positioning system:
--   - Snaps to minimap edge when close (works with round minimap)
--   - Breaks free for arbitrary positioning (works with square minimap / ElvUI)
--   - Saves x,y offset relative to Minimap center between sessions
-- HUGE shoutout to Amadeus!! - https://github.com/Amadeus-

local addonName, addon = ...

local BUTTON_NAME = "DjLust_MinimapButton"

-- Migrate from old angle-only format or initialize defaults
local function InitDB()
    if not DjLustDB then
        DjLustDB = {}
    end
    
    if not DjLustDB.minimap then
        DjLustDB.minimap = {}
    end
    
    -- Migrate: if old angle-based data exists, convert to x,y
    if DjLustDB.minimap.angle and not DjLustDB.minimap.x then
        local angle = math.rad(DjLustDB.minimap.angle)
        local radius = 105
        DjLustDB.minimap.x = math.cos(angle) * radius
        DjLustDB.minimap.y = math.sin(angle) * radius
        DjLustDB.minimap.angle = nil
    end
    
    -- Default position: bottom-left of minimap (equivalent to old 225 degrees)
    if not DjLustDB.minimap.x then
        local angle = math.rad(225)
        local radius = 105
        DjLustDB.minimap.x = math.cos(angle) * radius
        DjLustDB.minimap.y = math.sin(angle) * radius
    end
    
    -- Initialize hide flag
    if DjLustDB.minimap.hide == nil then
        DjLustDB.minimap.hide = false
    end
end

-----------------------------------------------------
-- Positioning
-----------------------------------------------------
local function UpdateButtonPosition(button)
    local x = DjLustDB.minimap.x or 0
    local y = DjLustDB.minimap.y or 0
    button:ClearAllPoints()
    button:SetPoint("CENTER", Minimap, "CENTER", x, y)
end

--------------------------------------------------
-- Creation
--------------------------------------------------
local function CreateMinimapButton()
    -- Don't create if hidden
    if DjLustDB.minimap.hide then
        return
    end
    
    -- CRITICAL FIX: If button already exists, just return it
    if _G[BUTTON_NAME] then
        UpdateButtonPosition(_G[BUTTON_NAME])
        return _G[BUTTON_NAME]
    end
    
    local btn = CreateFrame("Button", BUTTON_NAME, Minimap)
    btn:SetSize(31, 31)  
    btn:SetFrameStrata("MEDIUM")
    btn:SetFrameLevel(8)
    btn:SetMovable(true)
    btn:EnableMouse(true)
    btn:RegisterForClicks("LeftButtonUp")
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
            -- CRITICAL FIX: Use addon:ToggleSettings() for proper window management
            if addon and addon.ToggleSettings then
                addon:ToggleSettings()
            else
                -- Fallback if addon table not ready
                if SlashCmdList["DJLUST"] then
                    SlashCmdList["DJLUST"]("settings")
                end
            end
        end
    end)
    
    --------------------------------------------------
    -- Drag Handlers (Hybrid Snap/Free-form System)
    --------------------------------------------------
    btn:SetScript("OnDragStart", function(self)
        self.isDragging = true
        self:SetScript("OnUpdate", function(self)
            local minimap = Minimap
            local mx, my = minimap:GetCenter()
            local scale = minimap:GetEffectiveScale()
            local cx, cy = GetCursorPosition()
            cx, cy = cx / scale, cy / scale
            local dx, dy = cx - mx, cy - my
            local dist = (dx * dx + dy * dy) ^ 0.5

            -- Define the RADIUS_ADJUST constant (negative makes snap zone tighter)
            local RADIUS_ADJUST = -5

            -- Determine snap behavior
            local edgeRadius = (minimap:GetWidth() + self:GetWidth()) / 2
            local radSnap = edgeRadius + RADIUS_ADJUST
            local radPull = edgeRadius + self:GetWidth() * 0.2
            local radFree = edgeRadius + self:GetWidth() * 0.7
            local radClamp

            -- Snapping logic
            if dist <= radSnap then
                self.snapped = true
                radClamp = radSnap
            elseif dist < radPull and self.snapped then
                radClamp = radSnap
            elseif dist < radFree and self.snapped then
                radClamp = radSnap + (dist - radPull) / 2
            else
                self.snapped = false
            end

            -- Apply final position
            if radClamp and dist > 0 then
                local factor = radClamp / dist
                dx = dx * factor
                dy = dy * factor
            end

            DjLustDB.minimap.x = dx
            DjLustDB.minimap.y = dy
            self:ClearAllPoints()
            self:SetPoint("CENTER", minimap, "CENTER", dx, dy)
        end)
    end)
    
    btn:SetScript("OnDragStop", function(self)
        self.isDragging = false
        self:SetScript("OnUpdate", nil)
    end)
    
    -- Determine initial snap state
    local edgeRadius = (Minimap:GetWidth() + btn:GetWidth()) / 2
    local savedDist = (DjLustDB.minimap.x ^ 2 + DjLustDB.minimap.y ^ 2) ^ 0.5
    btn.snapped = (savedDist <= edgeRadius + btn:GetWidth() * 0.3)
    
    UpdateButtonPosition(btn)
    
    -- Hide if configured
    if DjLustDB.minimap.hide then
        btn:Hide()
    end
    
    return btn
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
    InitDB()
    CreateMinimapButton()
    HookSlashCommand()
end)
