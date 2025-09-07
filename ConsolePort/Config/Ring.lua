---------------------------------------------------------------------
-- RingManager.lua: Utility ring presets settings
---------------------------------------------------------------------
-- Provides a configuration panel to setup utility ring presets. 

local addOn, db = ...
local FadeIn, FadeOut = db.GetFaders()  
local Popup, TUTORIAL, Mixin = ConsolePortPopup, db.TUTORIAL, db.table.mixin
local LOCALE = db.TUTORIAL.RING

local WindowMixin, Core, Catcher = {}, {}, {}

function Core:Init()
    if next(ConsolePortUtility) == nil then
        ConsolePortUtility[1] = {
            Name   = "Utility Ring",
            Icon   = "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\Ring",
			Autoassign = false,
            Binding = nil,
            Data   = {},
        }
    end
    self:NormalizeIds()
end

local function _sortedKeys(t)
    local keys = {}
    for k in pairs(t) do if type(k)=="number" then table.insert(keys, k) end end
    table.sort(keys)
    return keys
end

function Core:NextFreeId()
    local keys = _sortedKeys(ConsolePortUtility)
    local expect = 1
    for _, k in ipairs(keys) do
        if k ~= expect then return expect end
        expect = expect + 1
    end
    return expect
end

function Core:NormalizeIds()
    local keys = _sortedKeys(ConsolePortUtility)
    local i = 1
    local new = {}
    for _, k in ipairs(keys) do
        new[i] = ConsolePortUtility[k]
        i = i + 1
    end
    ConsolePortUtility = new
    _G.ConsolePortUtility = new
end

function Core:CreateRing(name)
    local id = self:NextFreeId()
    ConsolePortUtility[id] = {
        Name = name or (LOCALE.NEW_RING.." "..id),
        Icon = "Interface\\Icons\\INV_Misc_QuestionMark",
        Binding = nil,
        Data = {},
    }
    return id
end

function Core:DeleteRing(id)
    if not ConsolePortUtility[id] then return end

    --[==[
    if(ConsolePortUtility[id].Binding) then
        if(ConsolePortUtility[id].Binding.Button) then
            local default = ConsolePort:GetDefaultBindingSet()
            db.Bindings[ConsolePortUtility[id].Binding.Button][ConsolePortUtility[id].Binding.Modifier or ''] = default[ConsolePortUtility[id].Binding.Button][ConsolePortUtility[id].Binding.Modifier or '']  
            ConsolePort:LoadBindingSet(db.Bindings, true)
        end
    end
    --]==]

    ConsolePortUtility[id] = nil
    self:NormalizeIds()
end

function Core:GetRing(id)
    return ConsolePortUtility[id]
end

function Core:UpdateRingMeta(id, name, iconTexture, autoAssign)
    local r = ConsolePortUtility[id]; if not r then return end
    if name and name ~= "" then r.Name = name end
    if iconTexture and iconTexture ~= "" then r.Icon = iconTexture end
    r.Autoassign = autoAssign
end

function Core:UpdateRingBinding(id, bindingTable)
    local r = ConsolePortUtility[id]; if not r then return end 
    r.Binding = bindingTable
end

---------------------------------------------------------------
-- Helpers
---------------------------------------------------------------
local function DeepCopy(orig)
    local copy
    if type(orig) == "table" then
        copy = {}
        for k, v in pairs(orig) do
            copy[k] = DeepCopy(v)
        end
    else
        copy = orig
    end
    return copy
end

local function SelectRing(listFrame, button)
    if listFrame.selected and listFrame.selected ~= button and listFrame.selected.SelectedTexture then
        listFrame.selected.SelectedTexture:Hide()
    end
    listFrame.selected = button
    if button.SelectedTexture then
        button.SelectedTexture:Show()
    end

    local panel = listFrame.parent or listFrame:GetParent()
    panel.SelectedRingID = button.ringID

    local ringManager = listFrame:GetParent():GetParent()
    ringManager.ContentFrame:Show()
    ringManager.NoContentFrame:Hide()

    local r = Core:GetRing(button.ringID)
    if r then
        ringManager.WorkingCopy = DeepCopy(r)

        ringManager.ContentFrame.RingNameValue:SetText(r.Name or "")
        SetPortraitToTexture(ringManager.ContentFrame.RingIcon, r.Icon or "Interface\\Icons\\INV_Misc_QuestionMark")

		ringManager.ContentFrame.AutoAssignSetting:SetChecked(r.Autoassign)

        local catcher = ringManager.ContentFrame.BindCatcher
        catcher.PresetBinding = r.Binding
        catcher.CurrentBinding = nil
        catcher:OnShow()
    end
end




local function MakeListRow(parent, i, width)
	local btn = parent.Buttons and parent.Buttons[i]
	if not btn then
		btn = db.Atlas.GetBindingMetaButton(("$parentButton%d"):format(i), parent, {
			width = width or 240,
			height = 40,
			useButton = true,
			textWidth = (width or 240) - 40,
			iconPoint = {"LEFT", "LEFT", 8, 0},
			textPoint = {"LEFT", "LEFT", 36, 0},
			buttonPoint = {"CENTER", 0, 0},
		})
		db.Atlas.SetFutureButtonStyle(btn)
		btn.Label:SetJustifyH("LEFT")
		parent:AddButton(btn) 
	end
	return btn
end

local function RefreshRingList(self)
    local count = 0
    for id, ring in ipairs(ConsolePortUtility) do
        count = count + 1
        local btn = MakeListRow(self, count, 240)
        btn:SetText(ring.Name or (LOCALE.RING.." "..id))
        btn.ringID = id
        btn.binding = (ring.Binding and (ring.Binding.Modifier or "")..(ring.Binding.Button or "")) or nil

        if not btn.hotKey then
            btn.hotKey = btn:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
            btn.hotKey:SetPoint("TOPRIGHT", btn, "TOPRIGHT", -6, -4)
        end
        btn.hotKey:SetText(btn.binding and ("|cFFAAAAAA"..btn.binding.."|r") or "")

        btn:SetScript("OnClick", function(b) SelectRing(self, b) end)
        btn:Show()
    end
    self:Refresh(count)
end


local function OnAddRing(self)
    local newID = Core:CreateRing()
    RefreshRingList(self.RingList)
end

local function OnRemoveRing(self)
    if not self.SelectedRingID then return end
    if self.SelectedRingID == 1 then 
        return
    end
    Core:DeleteRing(self.SelectedRingID)
    self.SelectedRingID = nil
    RefreshRingList(self.RingList)
    self.ContentFrame:Hide()
    self.NoContentFrame:Show()
end


---------------------------------------------------------------
-- save/default (stubs)
---------------------------------------------------------------
function WindowMixin:Default()
	-- no-op
end
function WindowMixin:Save()
	-- no-op
end

---------------------------------------------------------------
-- Bind Catcher
---------------------------------------------------------------
function Catcher:Catch(key)
    FadeIn(ConsolePortCursor, 0.2, ConsolePortCursor:GetAlpha(), 1)
    ConsolePortOldConfig:ToggleShortcuts(true)
    self:SetScript('OnKeyUp', nil)
    self:EnableKeyboard(false)

	local action = key and GetBindingAction(key)

    if action and action:match('^CP_') then
        -- detect modifiers
        local mod = ''
        if IsShiftKeyDown() and IsControlKeyDown() then
            mod = 'CTRL-SHIFT-'
        elseif IsShiftKeyDown() then
            mod = 'SHIFT-'
        elseif IsControlKeyDown() then
            mod = 'CTRL-'
        end

        self.CurrentBinding = { Button = action, Modifier = mod }

        local ringManager = self:GetParent():GetParent():GetParent()
        if ringManager and ringManager.WorkingCopy and self.CurrentBinding then
            ringManager.WorkingCopy.Binding = self.CurrentBinding
        end

        local formatted = ConsolePort:GetFormattedButtonCombination(action, mod, 50, true)
        self:SetText(formatted or TUTORIAL.CONFIG.INTERACTCATCHER)
    else
        self:SetText(TUTORIAL.CONFIG.INTERACTCATCHER)
    end
end


function Catcher:OnClick()
	self:EnableKeyboard(true)
	self:SetScript('OnKeyUp', self.Catch)
	FadeOut(ConsolePortCursor, 0.2, ConsolePortCursor:GetAlpha(), 0)
	ConsolePortOldConfig:ToggleShortcuts(false)
	self:SetText(TUTORIAL.BIND.CATCHER)
end

function Catcher:OnHide()
    self:Catch()
    FadeOut(self, 0.2, self:GetAlpha(), 0) 
end



function Catcher:OnShow()
    local panel = self:GetParent():GetParent():GetParent()
    local binding
    if panel and panel.SelectedRingID then
        local r = Core:GetRing(panel.SelectedRingID)
        binding = r and r.Binding
    end
    if binding then
        local formatted = ConsolePort:GetFormattedButtonCombination(binding.Button, binding.Modifier, 50, true)
        self:SetText(formatted or TUTORIAL.CONFIG.INTERACTCATCHER)
    else
        self:SetText(TUTORIAL.CONFIG.INTERACTCATCHER)
    end
    FadeIn(self, 0.2, self:GetAlpha(), 1)
end


-------------------------------------------------------
-- Icon Picker Dialog
-------------------------------------------------------

local CUSTOM_ICONS = {
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\Ring",
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\combat-ring",
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\emote-ring",
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\mount-ring",
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\pot-ring",
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\prof-ring",
    "Interface\\AddOns\\ConsolePort\\Textures\\Icons\\quest-ring",
}

local function CreateIconPickerFrame()
    local frame = CreateFrame("Frame", "ConsolePortIconPicker", UIParent)
    frame:SetSize(460, 420)

    frame.customIcons = CUSTOM_ICONS

    frame.iconsPerRow  = 8
    frame.cellSize     = 36
    frame.cellSpacing  = 6
    frame.rowSpacing   = 8
    local rowHeight    = frame.cellSize + frame.rowSpacing

    frame.Scroll = db.Atlas.GetScrollFrame("$parentIconScroll", frame, {
        childKey  = "List",
        childWidth = (frame.iconsPerRow * (frame.cellSize + frame.cellSpacing)),
        stepSize   = rowHeight,
        noMeta     = true,
    })
    frame.Scroll:SetPoint("TOPLEFT", 10, -40)
    frame.Scroll:SetPoint("BOTTOMRIGHT", -10, 10)
    local scroll, child = frame.Scroll, frame.Scroll.Child

    frame.pool = {}
    frame.poolSize = 0

    local function CreatePoolButton(i)
        local btn = CreateFrame("Button", frame:GetName() .. "IconBtn" .. i, child, "UIPanelButtonTemplate")
        btn:SetSize(frame.cellSize, frame.cellSize)
        btn:SetNormalTexture("")
        btn:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
        btn.Icon = btn:CreateTexture(nil, "ARTWORK")
        btn.Icon:SetAllPoints(btn)
        btn:Hide()
        return btn
    end

    local function EnsurePoolSize(poolSize)
        if poolSize == frame.poolSize then return end
        for i = frame.poolSize + 1, poolSize do
            frame.pool[i] = CreatePoolButton(i)
        end
        for i = poolSize + 1, frame.poolSize do
            if frame.pool[i] then frame.pool[i]:Hide() end
        end
        frame.poolSize = poolSize
    end

    local function GetTotalIcons()
        return #frame.customIcons + GetNumMacroIcons()
    end

    local function GetIconTexture(globalIndex)
        if globalIndex <= #frame.customIcons then
            return frame.customIcons[globalIndex]
        else
            local macroIndex = globalIndex - #frame.customIcons
            return GetMacroIconInfo(macroIndex)
        end
    end

    local function UpdateVisible()
        frame.numIcons  = GetTotalIcons()
        frame.totalRows = math.ceil(frame.numIcons / frame.iconsPerRow)
        child:SetHeight(frame.totalRows * rowHeight)

        local offset     = scroll:GetVerticalScroll() or 0
        local firstRow   = math.floor(offset / rowHeight)
        local scrollH    = scroll:GetHeight() or 0
        local visibleRows = math.ceil(scrollH / rowHeight) + 1
        if visibleRows < 1 then visibleRows = 1 end

        local poolSize   = visibleRows * frame.iconsPerRow
        EnsurePoolSize(poolSize)

        local startIndex = firstRow * frame.iconsPerRow + 1
        local endIndex   = math.min(frame.numIcons, startIndex + poolSize - 1)

        local poolIndex = 1
        for globalIndex = startIndex, endIndex do
            local texture = GetIconTexture(globalIndex)
            local btn = frame.pool[poolIndex]
            if btn then
                btn.Icon:SetTexture(texture)
                local row = math.floor((globalIndex - 1) / frame.iconsPerRow)
                local col = (globalIndex - 1) % frame.iconsPerRow
                btn:ClearAllPoints()
                btn:SetPoint("TOPLEFT", child, "TOPLEFT", col * (frame.cellSize + frame.cellSpacing), -row * rowHeight)
                btn:Show()

                btn:SetScript("OnClick", function()
                    if frame.callback then
                        frame.callback(texture, globalIndex)
                    end
                    Popup:Hide()
                end)
            end
            poolIndex = poolIndex + 1
        end
        for i = poolIndex, frame.poolSize do
            if frame.pool[i] then frame.pool[i]:Hide() end
        end
    end

    function frame:Refresh(callback)
        self.callback = callback
        self.numIcons = GetTotalIcons()
        self.totalRows = math.ceil(self.numIcons / self.iconsPerRow)
        child:SetHeight(self.totalRows * rowHeight)
        UpdateVisible()
    end

    scroll:SetScript("OnVerticalScroll", function(_, offset) UpdateVisible() end)
    scroll:HookScript("OnSizeChanged", function() UpdateVisible() end)
    frame:HookScript("OnShow", function() UpdateVisible() end)

    return frame
end


---------------------------------------------------------------
-- Rename Ring Frame
---------------------------------------------------------------

local function CreateRenameFrame()
    local frame = CreateFrame("Frame", "ConsolePortRenameDialog", UIParent)
    frame:SetSize(300, 120)

    frame.EditBox = CreateFrame("EditBox", "$parentEditBox", frame, "InputBoxTemplate")
    frame.EditBox:SetSize(240, 30)
    frame.EditBox:SetPoint("TOP", 0, -5)
    frame.EditBox:SetAutoFocus(true)
    frame.EditBox:SetMaxLetters(32)
    frame.EditBox:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)

    local function CommitRename()
    	local newName = frame.EditBox:GetText()
    	if newName and newName ~= "" and frame.ringID then
        	if frame.parent and frame.parent.WorkingCopy then
            	frame.parent.WorkingCopy.Name = newName
        	end
        	frame.parent.ContentFrame.RingNameValue:SetText(newName)
    	end
    	Popup:Hide()
	end


    frame.OK = db.Atlas.GetFutureButton("$parentOK", frame, nil, nil, 120, 36)
    frame.OK:SetPoint("BOTTOMLEFT", 10, 10)
    frame.OK:SetText(LOCALE.OK)
    frame.OK:SetScript("OnClick", CommitRename)
	frame.OK:Hide()

    frame.Cancel = db.Atlas.GetFutureButton("$parentCancel", frame, nil, nil, 120, 36)
    frame.Cancel:SetPoint("BOTTOMRIGHT", -10, 10)
    frame.Cancel:SetText(TUTORIAL.UICTRL.CANCEL)
    frame.Cancel:SetScript("OnClick", function() Popup:Hide() end)
	frame.Cancel:Hide()

    frame:Hide()

    function frame:Open(ringID, parentPanel, currentName)
        self.ringID = ringID
        self.parent = parentPanel
        self.EditBox:SetText(currentName or "")
        self.EditBox:SetFocus()
        Popup:SetPopup(LOCALE.RENAMERING, self, self.OK, self.Cancel, 160, 400)
    end

    return frame
end

---------------------------------------------------------------
-- Register Panel
---------------------------------------------------------------
db.PANELS[#db.PANELS + 1] = {
	name = "RingManager",
	header = LOCALE.RING,
	mixin = WindowMixin,
	onLoad = function(RingManager, self)

		-------------------------------------------------------
		-- Initialize Core
		-------------------------------------------------------
		Core:Init()

		-------------------------------------------------------
		-- Tutorial / Help frame
		-------------------------------------------------------
		RingManager.TutorialFrame = db.Atlas.GetGlassWindow("$parentTutorialFrame", RingManager, nil, true)
		RingManager.TutorialFrame:SetBackdrop(db.Atlas.Backdrops.Border)
		RingManager.TutorialFrame:SetSize(600, 180)
		RingManager.TutorialFrame:SetPoint("CENTER", 150, 200)
		RingManager.TutorialFrame.Close:Hide()
		RingManager.TutorialFrame.BG:SetAlpha(0.1)
		RingManager.TutorialFrame.Title = RingManager.TutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		RingManager.TutorialFrame.Title:SetPoint("CENTER", 0, 40)
		RingManager.TutorialFrame.Title:SetText(LOCALE.RINGINTRO)
		RingManager.TutorialFrame.Text = RingManager.TutorialFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		RingManager.TutorialFrame.Text:SetPoint("CENTER", 0, -20)
		RingManager.TutorialFrame.Text:SetText(LOCALE.RINGDESC)

		-------------------------------------------------------
		-- Ring List
		-------------------------------------------------------
		RingManager.RingScroll = db.Atlas.GetScrollFrame("$parentRingScrollFrame", RingManager, {
			childKey = "List",
			childWidth = 260,
			stepSize = 50,
		})
		RingManager.RingScroll:SetPoint("TOPLEFT", RingManager, "TOPLEFT", 24, -41)
		RingManager.RingScroll:SetPoint("BOTTOMLEFT", RingManager, "BOTTOMLEFT", 24, 91)
		RingManager.RingScroll:SetWidth(260)

		RingManager.RingList = RingManager.RingScroll.Child
		RingManager.RingList.parent = RingManager
		RingManager.RingList.Buttons = RingManager.RingScroll.Buttons
		RingManager.RingList:SetScript("OnShow", RefreshRingList)

		-------------------------------------------------------
		-- Buttons: Add, Remove
		-------------------------------------------------------
		RingManager.AddRingButton = db.Atlas.GetFutureButton("$parentAddRingButton", RingManager, nil, nil, 137, 46)
		RingManager.AddRingButton:SetPoint("BOTTOMLEFT", 24, 24)
		RingManager.AddRingButton:SetText(LOCALE.ADD)
		RingManager.AddRingButton:SetScript("OnClick", function() OnAddRing(RingManager) end)

		RingManager.RemoveRingButton = db.Atlas.GetFutureButton("$parentRemoveRingButton", RingManager, nil, nil, 137, 46)
		RingManager.RemoveRingButton:SetPoint("BOTTOMLEFT", 167, 24)
		RingManager.RemoveRingButton:SetText(LOCALE.REMOVE)
		RingManager.RemoveRingButton:SetScript("OnClick", function() OnRemoveRing(RingManager) end)
		
		-------------------------------------------------------
		-- Content Frame
		-------------------------------------------------------
		RingManager.ContentFrame = db.Atlas.GetGlassWindow("$parentContentFrame", RingManager, nil, true)
		RingManager.ContentFrame:SetBackdrop(db.Atlas.Backdrops.Border)
		RingManager.ContentFrame:SetSize(600, 455)
		RingManager.ContentFrame:SetPoint("CENTER", 150, -95)
		RingManager.ContentFrame.Close:Hide()
		RingManager.ContentFrame.BG:SetAlpha(0.1)

		RingManager.ContentFrame.IconPicker = CreateIconPickerFrame()
		RingManager.ContentFrame.RenameFrame = CreateRenameFrame()

        -------------------------------------------------------
		-- Ring Name
        -------------------------------------------------------
		RingManager.ContentFrame.RingNameLabel = RingManager.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		RingManager.ContentFrame.RingNameLabel:SetPoint("TOPLEFT", 50, -50)
		RingManager.ContentFrame.RingNameLabel:SetText(LOCALE.NAME)

		RingManager.ContentFrame.RingNameValue = RingManager.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		RingManager.ContentFrame.RingNameValue:SetPoint("TOPLEFT", RingManager.ContentFrame.RingNameLabel, "TOPRIGHT", 15, 0)
		RingManager.ContentFrame.RingNameValue:SetText("")

		RingManager.ContentFrame.RingNameButton = db.Atlas.GetFutureButton("$parentRingNameButton", RingManager.ContentFrame, nil, nil, 100, 30)
		RingManager.ContentFrame.RingNameButton:SetPoint("TOPLEFT", 250, -41)
		RingManager.ContentFrame.RingNameButton:SetText(LOCALE.RENAME)
		RingManager.ContentFrame.RingNameButton:SetScript("OnClick", function()
    		if RingManager.SelectedRingID then
        		local r = Core:GetRing(RingManager.SelectedRingID)
        		if r then
            		RingManager.ContentFrame.RenameFrame:Open(
                		RingManager.SelectedRingID,
                		RingManager,
                		r.Name or ""
            		)
        		end
    		end
		end)

        -------------------------------------------------------
		-- Ring Icon
        -------------------------------------------------------
		RingManager.ContentFrame.RingIconLabel = RingManager.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		RingManager.ContentFrame.RingIconLabel:SetPoint("TOPLEFT", 50, -100)
		RingManager.ContentFrame.RingIconLabel:SetText(LOCALE.ICON) 

		RingManager.ContentFrame.RingIcon = RingManager.ContentFrame:CreateTexture(nil, "ARTWORK")  
		RingManager.ContentFrame.RingIcon:SetPoint("RIGHT", RingManager.ContentFrame.RingIconLabel, "RIGHT", 50, 0)
		SetPortraitToTexture(RingManager.ContentFrame.RingIcon, "Interface\\Icons\\INV_Misc_QuestionMark")
		RingManager.ContentFrame.RingIcon:SetSize(28, 28)
		RingManager.ContentFrame.RingIcon:SetAlpha(1)

		
		RingManager.ContentFrame.RingIconButton = db.Atlas.GetFutureButton("$parentRingIconButton", RingManager.ContentFrame, nil, nil, 100, 30)
		RingManager.ContentFrame.RingIconButton:SetPoint("CENTER", RingManager.ContentFrame.RingNameButton, "CENTER", 0, -50)
		RingManager.ContentFrame.RingIconButton:SetText(LOCALE.SETICON)
		RingManager.ContentFrame.RingIconButton:SetScript("OnClick", function()
    		local picker = RingManager.ContentFrame.IconPicker
    		picker:Refresh(function(selectedTexture, iconIndex)
    			SetPortraitToTexture(RingManager.ContentFrame.RingIcon, selectedTexture)
    			if RingManager.WorkingCopy then
        			RingManager.WorkingCopy.Icon = selectedTexture
    			end
			end)



    		Popup:SetPopup(LOCALE.CHOOSEICON, picker, nil, nil, 500, 420)
		end)

        -------------------------------------------------------
		-- Auto assign
        -------------------------------------------------------
		RingManager.ContentFrame.AutoAssignSetting = CreateFrame('CheckButton', '$parentAutoAssignSetting', RingManager.ContentFrame, 'ChatConfigCheckButtonTemplate')
		local check = RingManager.ContentFrame.AutoAssignSetting
		local text = check:CreateFontString(nil, 'OVERLAY', 'GameFontHighlight')
		text:SetText(TUTORIAL.CONFIG.AUTOEXTRA) 
		text:SetPoint('LEFT', check, 30, 0)
		check.Description = text
		check:SetPoint("TOPLEFT", 47, -150)
		check:SetScript('OnClick', function(self)
    		if RingManager.WorkingCopy then
        		RingManager.WorkingCopy.Autoassign = self:GetChecked()
    		end
		end)
        
        -------------------------------------------------------
		-- Binding
        -------------------------------------------------------		
		RingManager.ContentFrame.RingIconLabel = RingManager.ContentFrame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		RingManager.ContentFrame.RingIconLabel:SetPoint("TOPLEFT", 50, -250)
		RingManager.ContentFrame.RingIconLabel:SetText(LOCALE.BINDING) 


		RingManager.ContentFrame.BindWrapper = db.Atlas.GetGlassWindow('$parentBindWrapper', RingManager.ContentFrame, nil, true)
		RingManager.ContentFrame.BindWrapper:SetBackdrop(db.Atlas.Backdrops.Border)
		RingManager.ContentFrame.BindWrapper:SetPoint('CENTER', 0, -50)
		RingManager.ContentFrame.BindWrapper:SetSize(292, 100)
		RingManager.ContentFrame.BindWrapper.Close:Hide()
		RingManager.ContentFrame.BindWrapper:Show()

		RingManager.ContentFrame.BindCatcher = db.Atlas.GetFutureButton('$parentBindCatcher', RingManager.ContentFrame.BindWrapper, nil, nil, 260)
		RingManager.ContentFrame.BindCatcher.HighlightTexture:ClearAllPoints()
		RingManager.ContentFrame.BindCatcher.HighlightTexture:SetAllPoints(RingManager.ContentFrame.BindCatcher)
		RingManager.ContentFrame.BindCatcher:SetHeight(70)
		RingManager.ContentFrame.BindCatcher:SetPoint('CENTER', 0, 0)
		RingManager.ContentFrame.BindCatcher.Cover:Hide()

		-------------------------------------------------------
		-- Save Preset
        -------------------------------------------------------
		RingManager.ContentFrame.SavePresetButton = db.Atlas.GetFutureButton("$parentSavePresetButton", RingManager.ContentFrame, nil, nil, 137, 46)
		RingManager.ContentFrame.SavePresetButton:SetPoint("CENTER", 0, -170)
		RingManager.ContentFrame.SavePresetButton:SetText(LOCALE.SAVE)
		RingManager.ContentFrame.SavePresetButton:SetScript("OnClick", function()
    		if RingManager.SelectedRingID and RingManager.WorkingCopy then
        		local copy = RingManager.WorkingCopy
        		Core:UpdateRingMeta(RingManager.SelectedRingID, copy.Name, copy.Icon, copy.Autoassign)
        		Core:UpdateRingBinding(RingManager.SelectedRingID, copy.Binding)
       			RefreshRingList(RingManager.RingList)
                ConsolePort:RunOOC(ConsolePort.SetupUtilityBindings)
    		end
		end)

        -------------------------------------------------------
		-- No Ring Selected Content Frame
        -------------------------------------------------------
		RingManager.ContentFrame:Hide()		
		RingManager.NoContentFrame = db.Atlas.GetGlassWindow("$parentNoContentFrame", RingManager, nil, true)
		RingManager.NoContentFrame:SetBackdrop(db.Atlas.Backdrops.Border)
		RingManager.NoContentFrame:SetSize(600, 455)
		RingManager.NoContentFrame:SetPoint("CENTER", 150, -95)
		RingManager.NoContentFrame.Close:Hide()
		RingManager.NoContentFrame.BG:SetAlpha(0.1)
		RingManager.NoContentFrame.Title = RingManager.NoContentFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		RingManager.NoContentFrame.Title:SetPoint("CENTER", 0, 0)
		RingManager.NoContentFrame.Title:SetText(LOCALE.RINGSEL)
		


		Mixin(RingManager.ContentFrame.BindCatcher, Catcher)
		RingManager.ContentFrame.BindCatcher:OnShow()
		

		RefreshRingList(RingManager.RingList)
	end
}
