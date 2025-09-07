---------------------------------------------------------------
-- Init.lua: Main frame creation, version checking, slash cmd
---------------------------------------------------------------
-- 1. Create the main frame and check all loaded settings.
-- 2. Validate compatibility with older versions.
-- 3. Create the slash handler function.

local addOn, db = ...
---------------------------------------------------------------
local NEWCALIBRATION, BINDINGSLOADED
---------------------------------------------------------------
-- Initialize addon tables
---------------------------------------------------------------
db.ICONS 	= {}
db.TEXTURE 	= {}
db.SECURE 	= {}
db.PANELS 	= {}
db.PLUGINS 	= {}

db.PLUGINCHECKS = {}
db.PLUGINCHECKS.IsBagNode = {}
db.PLUGINCHECKS.IsSpellNode = {} 
db.PLUGINCHECKS.IsMerchantNode = {}

---------------------------------------------------------------
-- Popup functions 
---------------------------------------------------------------
local function LoadDefaultBindings()
	ConsolePortOldConfig:OpenCategory('Binds')
	ConsolePortOldConfigContainerBinds:Default()
	ConsolePort:CheckLoadedSettings()
end

local function LoadWoWmapper()
	db('calibration', db.table.copy(WoWmapper.Keys))
	for k, v in pairs(WoWmapper.Settings) do
		db(k, v)
	end
	db('type', db('forceController') or db('type'))
end

local function CancelPopup()
	ConsolePort:ClearPopup()
end

---------------------------------------------------------------

---------------------------------------------------------------
-- Custom client workarounds
---------------------------------------------------------------

local function FixSecureHandler(object)
    function object:SetFrameRef(label, ref)
        SecureHandlerSetFrameRef(object, label, ref)
    end

    function object:Execute(func)
        SecureHandlerExecute(object, func)
    end

    function object:WrapScript(frame, name, script)
        SecureHandlerWrapScript(frame, name, object, script)
    end
end

if CPAPI.IsCustomClient() then  
	-- for some weird reason, in some custom clients, the SecureHandler methods are not merged with these frames.
	FixSecureHandler(ConsolePortRaidCursor)
	FixSecureHandler(ConsolePortEasyMotionButton)
	FixSecureHandler(ConsolePortPager)
	FixSecureHandler(ConsolePortRadialHandler)
	FixSecureHandler(ConsolePortUIHandle)
	FixSecureHandler(ConsolePortUtilityToggle)
end
---------------------------------------------------------------

function ConsolePort:LoadSettings()
	local selectController --, newUser

	-----------------------------------------------------------
	-- Set/load addon settings
	-----------------------------------------------------------
	if not ConsolePortSettings then
		selectController = true
		ConsolePortSettings = self:GetDefaultAddonSettings()
	end

	db.Settings = ConsolePortSettings
	db('calibration', db('calibration') or {})

	-----------------------------------------------------------
	-- Load exported WoWmapper settings
	-----------------------------------------------------------
	if WoWmapper then
		if ( not WoWmapper.Keys ) or ( not WoWmapper.Settings ) then
			print('Calibration or settings table missing in WoWmapper export data.')
		else
			if db('wmupdate') or ( not db('calibration') ) then
				db('wmupdate', nil)
				LoadWoWmapper()
			else
				local cs, ws = db.Settings, WoWmapper.Settings
				local cb, wk = cs.calibration, WoWmapper.Keys
				for k, v in pairs(cb) do
					if wk[k] ~= v then
						NEWCALIBRATION = true
						break
					end
				end
				for k, v in pairs(ws) do
					if k ~= 'type' and cs[k] ~= v then
						NEWCALIBRATION = true
						break
					end
				end
			end
			selectController = false
		end
	end

	-----------------------------------------------------------
	-- Load controller splash if no preference exists
	-----------------------------------------------------------
	if selectController then
		self:SelectController()
	end

	self:LoadLookup()

	-----------------------------------------------------------
	-- Set/load mouse settings
	-----------------------------------------------------------
	ConsolePortMouse = ConsolePortMouse or {
		Events = self:GetDefaultMouseEvents();
		Cursor = self:GetDefaultMouseCursor();
	}
	
	-----------------------------------------------------------
	-- Add empty bindings popup for later use
	-----------------------------------------------------------

	StaticPopupDialogs['CONSOLEPORT_IMPORTBINDINGS'] = {
		button1 = db.TUTORIAL.SLASH.ACCEPT,
		button2 = db.TUTORIAL.SLASH.CANCEL,
		showAlert = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		enterClicksFirstButton = true,
		exclusive = true,
		OnAccept = LoadDefaultBindings,
		OnCancel = CancelPopup,
		OnShow = function(self)
			-- don't show the popup when selecting controller layout or calibrating.
			if 	( ConsolePortSplashFrame and ConsolePortSplashFrame:IsVisible() ) or
				( ConsolePortCalibrationFrame and ConsolePortCalibrationFrame:IsVisible() ) then
				self:Hide()
			end
		end,
	}

	-----------------------------------------------------------
	-- Extra features
	-----------------------------------------------------------

	-- Use these frames in the virtual cursor stack
	ConsolePortUIFrames = ConsolePortUIFrames or self:GetDefaultUIFrames()
	-- Use this table to populate main radial action bar
	ConsolePortUtility = ConsolePortUtility or {}
	-- Use this table to store UI module settings
	ConsolePortUIConfig = ConsolePortUIConfig or {}

	----------------------------------------------------------

	db.UIStack 	= ConsolePortUIFrames
	db.UIConfig = ConsolePortUIConfig
	db.Mouse 	= ConsolePortMouse

	----------------------------------------------------------
	-- Load the calibration wizard if a button does not have a registered mock binding
	----------------------------------------------------------
	if 	self:CheckCalibration() then
		self:CalibrateController()
	end

	----------------------------------------------------------
	-- Load UI handle fade frames
	----------------------------------------------------------
	ConsolePortUIHandle:LoadFadeFrames()

	----------------------------------------------------------
	-- Create slash handler
	----------------------------------------------------------
	self:CreateSlashHandler()

	----------------------------------------------------------
	-- Dispatch a cvar refresh for reguistered callbacks
	----------------------------------------------------------
	self:RefreshCVars()

	----------------------------------------------------------
	self.LoadSettings = nil
end

function ConsolePort:WMupdate()
	StaticPopupDialogs['CONSOLEPORT_WMUPDATE'] = {
		text = db.TUTORIAL.SLASH.WMUPDATE,
		button1 = db.TUTORIAL.SLASH.ACCEPT,
		button2 = db.TUTORIAL.SLASH.CANCEL,
		showAlert = true,
		timeout = 0,
		whileDead = true,
		hideOnEscape = true,
		preferredIndex = 3,
		enterClicksFirstButton = true,
		exclusive = true,
		OnAccept = function()
			db('wmupdate', true)
			ReloadUI()
		end,
		OnCancel = CancelPopup,
	}
	self:ShowPopup('CONSOLEPORT_WMUPDATE')
end

function ConsolePort:GetBindingSet(specID)
	-----------------------------------------------------------
	-- Set/load binding table
	-----------------------------------------------------------
	local specID = specID or CPAPI.GetSpecialization() 

	-- Flag bindings loaded so the settings checkup doesn't run this part.
	BINDINGSLOADED = true

	-- Assert the SV binding set container exists before proceeding
	ConsolePortBindingSet = ConsolePortBindingSet or {}

	-- BC: Convert old binding set paradigm to spec-specific
	-- Check if set contains a string key, in which case it's using the
	-- outdated binding format. 
	if type(next(ConsolePortBindingSet)) == 'string' then
		ConsolePortBindingSet = {[specID] = ConsolePortBindingSet}
	end

	-- Assert the current specID is included in the set and that bindings exist,
	-- else create the subset (and flag no bindings for the popup).
	local set = ConsolePortBindingSet
	set[specID] = set[specID] or db.table.copy(db.Bindings) or {}

	-- return the current binding set and the specID
	return set[specID], specID
end

function ConsolePort:CheckLoadedSettings()
	local settings = ConsolePortSettings
	if settings then
		if settings.newController then
			local popupData = StaticPopupDialogs['CONSOLEPORT_IMPORTBINDINGS']
			popupData.text = db.TUTORIAL.SLASH.NEWCONTROLLER
			self:ShowPopup('CONSOLEPORT_IMPORTBINDINGS')
			settings.newController = nil
		elseif NEWCALIBRATION and ( not settings.id or (WoWmapper and WoWmapper.Settings and (settings.id ~= WoWmapper.Settings.id)) ) then
			NEWCALIBRATION = nil
			settings.id = WoWmapper.Settings.id
			StaticPopupDialogs['CONSOLEPORT_CALIBRATIONUPDATE'] = {
				text = db.TUTORIAL.SLASH.CALIBRATIONUPDATE,
				button1 = db.TUTORIAL.SLASH.ACCEPT,
				button2 = db.TUTORIAL.SLASH.CANCEL,
				showAlert = true,
				timeout = 0,
				whileDead = true,
				hideOnEscape = true,
				preferredIndex = 3,
				enterClicksFirstButton = true,
				exclusive = true,
				OnAccept = function()
					LoadWoWmapper()
					ReloadUI()
				end,
				OnCancel = CancelPopup,
			}
			self:ShowPopup('CONSOLEPORT_CALIBRATIONUPDATE')
		elseif BINDINGSLOADED and ( not db.Bindings or not next(db.Bindings) ) then
			local popupData = StaticPopupDialogs['CONSOLEPORT_IMPORTBINDINGS']
			popupData.text = db.TUTORIAL.SLASH.NOBINDINGS
			self:ShowPopup('CONSOLEPORT_IMPORTBINDINGS')
		end
	end
end

function ConsolePort:CheckLoadedAddons()
	local loaded = {}
	for name, frames in pairs(db.UIStack) do
		if IsAddOnLoaded(name) then
			for i, frame in pairs(frames) do
				self:AddFrame(frame)
			end
		end
	end
	for name, pluginData in pairs(db.PLUGINS) do
		if pluginData.condition then
			pluginData.loader(self)
			loaded[name] = true
		elseif IsAddOnLoaded(name) then
			pluginData.loader(self)
			loaded[name] = true
		end
	end
	for name in pairs(loaded) do
		db.PLUGINS[name] = nil
	end
end

function ConsolePort:RunPluginNodeChecks(checkType, node)
    if db.PLUGINCHECKS[checkType] then
        for i, checkFunc in ipairs(db.PLUGINCHECKS[checkType]) do 
            local success, result = pcall(checkFunc, node)
            if success and result then
                return true
            end
        end
    end
    return false
end

function ConsolePort:CreateSecureButtons()
	for name in self:GetBindings() do
		for modifier in self:GetModifiers() do
			self:SetSecureButton(name, modifier, self:GetUIControlKey(name))
		end
	end
	self.CreateSecureButtons = nil
end