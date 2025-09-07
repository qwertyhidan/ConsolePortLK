local UI, an, L = ConsolePortUI, ...
local db = ConsolePort:GetData()
local ICON = 'Interface\\Icons\\%s'
local Button = L.Button

-- Loot header specifics
local LootButton = L.LootButton
local lootButtonProbeScript = L.lootButtonProbeScript
local lootHeaderOnSetScript = L.lootHeaderOnSetScript

-- Check if game client is a custom client.
local IsCustomClient = CPAPI.IsCustomClient()

-- Dropdown button templates 
local maskTemplates = {'CPUIMenuButtonBaseTemplate', IsCustomClient and 'SecureUnitButtonTemplate' or 'SecureActionButtonTemplate'}
local baseTemplates = {'CPUIMenuButtonMaskTemplate', IsCustomClient and 'SecureUnitButtonTemplate' or 'SecureActionButtonTemplate'}


local Menu =  UI:CreateFrame('Frame', an, IsCustomClient and EscapeMenu or GameMenuFrame, 'SecureHandlerStateTemplate, CPUIMenuTemplate', {
	{
		Character = {
			Type 	= 'CheckButton',
			Setup 	= {
				'SecureHandlerBaseTemplate',
				'SecureHandlerClickTemplate',
				'CPUIListCategoryTemplate',
			},
			Text	= '|TInterface\\Store\\category-icon-armor:18:18:-4:0:64:64:14:50:14:50|t' .. CHARACTER,
			ID = 1,
			SetAttribute = {'_onclick', 'control:RunFor(self:GetParent(), self:GetParent():GetAttribute("ShowHeader"), self:GetID())'},
			{
				Info  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 1,
					Point 	= {'TOP', 'parent', 'BOTTOM', 0, -16},
					Desc	= CHARACTER_BUTTON,
					Attrib 	= {hidemenu = true},
					UpdateLevel = function(self, newLevel)
						local level = newLevel or UnitLevel('player')
						if ( level and level < MAX_PLAYER_LEVEL ) then
							self.Level:SetTextColor(1, 0.8, 0)
							self.Level:SetText(level)
						else
							self.Level:SetTextColor(CPAPI:GetItemLevelColor())
							self.Level:SetText(CPAPI:GetAverageItemLevel())
						end
					end,
					OnClick = function(self) ToggleCharacter('PaperDollFrame') end,
					OnEvent = function(self, event, ...)
						if event == 'UNIT_PORTRAIT_UPDATE' then
							SetPortraitTexture(self.Icon, 'player')
						elseif event == 'PLAYER_LEVEL_UP' then
							self:UpdateLevel(...)
						else
							SetPortraitTexture(self.Icon, 'player')
							self:UpdateLevel()
						end
					end,
					Events = {
						'UNIT_PORTRAIT_UPDATE',
						'PLAYER_ENTERING_WORLD',
						'PLAYER_LEVEL_UP',
					},
					{
						Level = {
							Type 	= 'FontString',
							Setup 	= {'OVERLAY'},
							Font 	= {GameFontNormal:GetFont()},
							AlignH 	= 'RIGHT',
							Point 	= {'RIGHT', -10, 0},
						},
					},
				},
				Inventory  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 2,
					Point 	= {'TOP', 'parent.Info', 'BOTTOM', 0, 0},
					Desc	= INVENTORY_TOOLTIP,
					Img 	= [[Interface\ICONS\INV_Misc_Bag_22]],
					Events 	= {'BAG_UPDATE'},
					Attrib 	= {hidemenu = true},
					OnClick = CPAPI.ToggleAllBags,
					OnEvent = function(self, event, ...)
						local totalFree, numSlots, freeSlots, bagFamily = 0, 0
						for i = BACKPACK_CONTAINER, NUM_BAG_SLOTS do
							freeSlots, bagFamily = GetContainerNumFreeSlots(i)
							if ( bagFamily == 0 ) then
								totalFree = totalFree + freeSlots
								numSlots = numSlots + GetContainerNumSlots(i)
							end
						end
						self.Count:SetFormattedText('%s\n|cFFAAAAAA%s|r', totalFree, numSlots)
					end,
					{
						Count = {
							Type 	= 'FontString',
							Setup 	= {'OVERLAY'},
							Font 	= {GameFontNormal:GetFont()},
							AlignH 	= 'RIGHT',
							Point 	= {'RIGHT', -10, 0},
						},
					},
				},
				Spec  = {
					Type 	= 'Button',
					Setup 	= maskTemplates,
					Mixin 	= Button,
					ID 		= 3,
					Point 	= {'TOP', 'parent.Inventory', 'BOTTOM', 0, 0},
					Desc	= TALENTS_BUTTON,
					RefTo 	= TalentMicroButton,
					Attrib 	= {hidemenu = true},
					EvaluateAlertVisibility = function(self)
						-- If we just unspecced, and we have unspent talent points, it's probably spec-specific talents that were just wiped.  Show the tutorial box.
					--	if not AreTalentsLocked() and GetNumUnspentTalents() > 0 and (not PlayerTalentFrame or not PlayerTalentFrame:IsShown()) then
					--		self.tooltipText = TALENT_MICRO_BUTTON_UNSPENT_TALENTS
					--		self:SetPulse(true)
					--		return
					--	end
					--	if GetNumUnspentPvpTalents() > 0 and (not PlayerTalentFrame or not PlayerTalentFrame:IsShown()) then
					--		self.tooltipText = TALENT_MICRO_BUTTON_UNSPENT_HONOR_TALENTS
					--		self:SetPulse(true)
					--		return
					--	end
					end,
					OnEnterScript = function(self)
						if self.tooltipText then
							GameTooltip:SetOwner(self, 'ANCHOR_RIGHT')
							GameTooltip:SetText(self.tooltipText)
							self.tooltipText = nil
							self.hideTooltipOnLeave = true
						end
					end,
					OnLeaveHook = function(self)
						if self.hideTooltipOnLeave then
							GameTooltip:Hide()
							self.hideTooltipOnLeave = nil
						end
					end,
					OnLoadHook = function(self)
						SetPortraitToTexture(self.Icon, [[Interface\Icons\Ability_Mage_StudentOfTheMind]])

						self:RegisterEvent('PLAYER_LEVEL_UP')
						self:RegisterEvent('UPDATE_BINDINGS')
						self:RegisterEvent('PLAYER_TALENT_UPDATE')
						self:RegisterEvent('PLAYER_SPECIALIZATION_CHANGED')
						self:RegisterEvent('HONOR_LEVEL_UPDATE')
						self:RegisterEvent('HONOR_PRESTIGE_UPDATE')
						self:RegisterEvent('PLAYER_PVP_TALENT_UPDATE')
						self:RegisterEvent('PLAYER_CHARACTER_UPGRADE_TALENT_COUNT_CHANGED') 
					end,
					OnEvent = function(self, event, ...)
						self.tooltipText = nil
						if ( event == 'PLAYER_LEVEL_UP' ) then
							local level = ...
							if (level == SHOW_SPEC_LEVEL) then
								self.tooltipText = TALENT_MICRO_BUTTON_SPEC_TUTORIAL
								self:SetPulse(true)
							elseif (level == SHOW_TALENT_LEVEL) then
								self.tooltipText = TALENT_MICRO_BUTTON_TALENT_TUTORIAL
								self:SetPulse(true)
							end
						elseif ( event == 'PLAYER_SPECIALIZATION_CHANGED' ) then
							self:EvaluateAlertVisibility()
						elseif ( event == 'PLAYER_TALENT_UPDATE' or event == 'NEUTRAL_FACTION_SELECT_RESULT' or
							event == 'HONOR_LEVEL_UPDATE' or event == 'HONOR_PRESTIGE_UPDATE' or event == 'PLAYER_PVP_TALENT_UPDATE' ) then
							self:EvaluateAlertVisibility()

							-- On the first update from the server, flash the button if there are unspent points
							-- Small hack: GetNumSpecializations should return 0 if talents haven't been initialized yet
							--if (not self.receivedUpdate and GetNumSpecializations(false) > 0) then
							--	self.receivedUpdate = true;
							--	local shouldPulseForTalents = GetNumUnspentTalents() > 0 or GetNumUnspentPvpTalents() > 0 and not AreTalentsLocked()
							--	if (UnitLevel('player') >= SHOW_SPEC_LEVEL and (not GetSpecialization() or shouldPulseForTalents)) then
							--		self:SetPulse(true)
							--	end
							--end
						elseif ( event == 'PLAYER_CHARACTER_UPGRADE_TALENT_COUNT_CHANGED' ) then
							local prev, current = ...
							if ( prev == 0 and current > 0 ) then
								self.tooltipText = TALENT_MICRO_BUTTON_TALENT_TUTORIAL
								self:SetPulse(true)
							elseif ( prev ~= current ) then
								self.tooltipText = TALENT_MICRO_BUTTON_UNSPENT_TALENTS
								self:SetPulse(true)
							end
						end
					end,
				},
				Spellbook  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 4,
					Point 	= {'TOP', 'parent.Spec', 'BOTTOM', 0, 0},
					Desc	= SPELLBOOK_BUTTON,
					Img 	= [[Interface\Spellbook\Spellbook-Icon]],
					RefTo 	= SpellbookMicroButton,
					Attrib 	= {hidemenu = true},
				},
				Collections  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 5,
					Point 	= {'TOP', 'parent.Spellbook', 'BOTTOM', 0, 0},
					Desc	= MOUNTS.." & "..PETS,
					Img 	= [[Interface\ICONS\Ability_Mount_BigBlizzardBear]], 
					Attrib 	= {hidemenu = true},	
					OnLoadHook = function(self)
						local mountIcon = [[Interface\ICONS\Ability_Mount_BigBlizzardBear]]
	
						local pAlliance = {["Human"]=1, ["NightElf"]=1, ["Dwarf"]=1, ["Gnome"]=1, ["Draenei"]=1}
						local pHorde = {["Orc"]=1, ["Troll"]=1, ["Scourge"]=1, ["Tauren"]=1, ["BloodElf"]=1}
						local punitRace, punitRaceEn = UnitRace("player");

						if(pHorde[punitRaceEn]) then
							mountIcon = [[Interface\ICONS\Ability_Mount_BlackDireWolf]]
						elseif(pAlliance[punitRaceEn]) then
							mountIcon = [[Interface\ICONS\Ability_Mount_RidingHorse]] 
						end

						SetPortraitToTexture(self.Icon, mountIcon)
					end,
					OnClick = function(self) ToggleCharacter('PetPaperDollFrame') end,
				},
			},
		},
		Gameplay = {
			Type 	= 'CheckButton',
			Setup 	= {
				'SecureHandlerBaseTemplate',
				'SecureHandlerClickTemplate',
				'CPUIListCategoryTemplate',
			},
			Text	= '|TInterface\\Store\\category-icon-weapons:18:18:-4:0:64:64:14:50:14:50|t' .. GAME,
			ID 	= 2,
			SetAttribute = {'_onclick', 'control:RunFor(self:GetParent(), self:GetParent():GetAttribute("ShowHeader"), self:GetID())'},
			{
				WorldMap  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 1,
					Point 	= {'TOP', 'parent', 'BOTTOM', 0, -16},
					Desc	= WORLD_MAP,
					Img 	= ICON:format('INV_Misc_Map02'), 
					Attrib 	= {hidemenu = true},
					OnClick = function(self) WorldMapFrame:Show() end,
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('INV_Misc_Map02')) end,
				}, 
				QuestLog  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 2,
					Point 	= {'TOP', 'parent.WorldMap', 'BOTTOM', 0, 0},
					Desc	= QUEST_LOG,
					Img 	= [[Interface\QUESTFRAME\UI-QuestLog-BookIcon]],
					RefTo 	= QuestLogMicroButton,
					Attrib 	= {hidemenu = true},
					{
						Notice = {
							Type = 'Frame',
							Size = {28, 28},
							Point = {'RIGHT', -10, 0},
							--Hide = not EJMicroButton.NewAdventureNotice:IsShown(),
							{
								Texture = {
									Type = 'Texture',
									Setup = {'OVERLAY'},
									Fill = true,
									Atlas = 'adventureguide-microbutton-alert',
								},
							},
							OnLoad = function(self)
								--hooksecurefunc('EJMicroButton_UpdateNewAdventureNotice', function()
								--	if EJMicroButton.NewAdventureNotice:IsShown() then
								--		self:Show()
								--	end
								--end)
								--hooksecurefunc('EJMicroButton_ClearNewAdventureNotice', function()
								--	self:Hide()
								--end)
							end,
						},
					},
				},
				Achievements  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 3,
					Point 	= {'TOP', 'parent.QuestLog', 'BOTTOM', 0, 0},
					Desc	= ACHIEVEMENTS,
					Img 	= ICON:format('ACHIEVEMENT_WIN_WINTERGRASP'),
					RefTo 	= AchievementMicroButton,
					Attrib 	= {hidemenu = true},
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('ACHIEVEMENT_WIN_WINTERGRASP')) end,
				},
				PVPFinder  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 4,
					Point 	= {'TOP', 'parent.Achievements', 'BOTTOM', 0, -16},
					Desc	= BUG_CATEGORY14,
					Img 	= [[Interface\ICONS\Ability_Parry]],
					OnClick = function(self) TogglePVPFrame() end,
					Attrib 	= {hidemenu = true},
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, [[Interface\ICONS\Ability_Parry]]) end,

				},
				PVEFinder  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 5,
					Point 	= {'TOP', 'parent.PVPFinder', 'BOTTOM', 0, 0},
					Desc	= DUNGEONS_BUTTON,
					Img 	= [[Interface\LFGFRAME\UI-LFG-PORTRAIT]],
					RefTo 	= LFDMicroButton,
					Attrib 	= {hidemenu = true},
				},
				
				-- Custom client specifics
				PathToAscension  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 6,
					Point 	= {'TOP', 'parent.PVEFinder', 'BOTTOM', 0, 0},
					Desc	= PATH_TO_ASCENSION,
					RefTo 	= PathToAscensionMicroButton,
					Img 	= [[Interface\ICONS\inv_azeriteexplosion]],
					Attrib 	= {
						hidemenu = true, 
						condition = string.format('return %s', tostring(IsCustomClient and IsCustomClient == "Ascension"))
					},
				},
				Trials  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 7,
					Point 	= {'TOP', 'parent.PathToAscension', 'BOTTOM', 0, 0},
					Desc	= TRIALS,
					RefTo 	= ChallengesMicroButton,
					Img 	= [[Interface\ICONS\_CallToArmsRed]],
					Attrib 	= {
						hidemenu = true,
						condition = string.format('return %s', tostring(IsCustomClient and IsCustomClient == "Ascension"))
					},
				},

				-----------

				Teleport  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 8,
					Point 	= {'TOP', IsCustomClient and 'parent.Trials' or 'parent.PVEFinder', 'BOTTOM', 0, 0},
					Img 	= ICON:format('Spell_Shadow_Teleport'),  Attrib 	= {
						hidemenu 	= true,
						condition 	= 'return PlayerInGroup()',
					},
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('Spell_Shadow_Teleport')) end,
					Hooks = {
						OnShow = function(self)
							local isLFG, inDungeon = IsPartyLFG(), IsInLFGDungeon()
							self:SetText(inDungeon and TELEPORT_OUT_OF_DUNGEON or isLFG and TELEPORT_TO_DUNGEON or '|cFF757575'..TELEPORT_TO_DUNGEON)
						end,
						OnClick = function(self)
							LFGTeleport(IsInLFGDungeon())
						end,
					},
				},
			},
		},
		Social = {
			Type 	= 'CheckButton',
			Setup 	= {
				'SecureHandlerBaseTemplate',
				'SecureHandlerClickTemplate',
				'CPUIListCategoryTemplate',
			},
			Text	= '|TInterface\\Store\\category-icon-featured:18:18:-4:0:64:64:14:50:14:50|t' .. SOCIAL_BUTTON,
			ID = 3,
			SetAttribute = {'_onclick', 'control:RunFor(self:GetParent(), self:GetParent():GetAttribute("ShowHeader"), self:GetID())'},
			{	 
				Friends  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 1,
					Point 	= {'TOP', 'parent', 'BOTTOM', 0, -16},
					Desc 	= FRIENDS_LIST,
					Img 	= [[Interface\FriendsFrame\BroadcastIcon]],
					RefTo 	= FriendsMicroButton,
					Attrib 	= {hidemenu = true},
					OnEvent = function(self)
						local _, numBNetOnline = BNGetNumFriends()
						local _, numWoWOnline = GetNumFriends()
						self.Count:SetText(numBNetOnline + numWoWOnline)
					end,
					Events = {
						'FRIENDLIST_UPDATE',
						'BN_FRIEND_INFO_CHANGED',
						'PLAYER_ENTERING_WORLD',
					},
					{
						Count = {
							Type 	= 'FontString',
							Setup 	= {'OVERLAY'},
							Font 	= {GameFontNormal:GetFont()},
							AlignH 	= 'RIGHT',
							Point 	= {'RIGHT', -10, 0},
						},
					},
				},
				Guild  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 2,
					Point 	= {'TOP', 'parent.Friends', 'BOTTOM', 0, 0},
					Desc 	= GUILD,
					Img 	= ICON:format('Achievement_Reputation_01'),
					OnClick = function(self) ToggleFriendsFrame(3) end,
					Attrib 	= {hidemenu = true},
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('Achievement_Reputation_01')) end,
				},
				Calendar  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 3,
					Point 	= {'TOP', 'parent.Guild', 'BOTTOM', 0, 0},
					Desc 	= EVENTS_LABEL,
					Img 	= [[Interface\Calendar\MeetingIcon]],
					Attrib 	= {hidemenu = true},
					RefTo 	= GameTimeFrame,
					
				},
				Raid  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 4,
					Point 	= {'TOP', 'parent.Calendar', 'BOTTOM', 0, 0},
					Desc 	= RAID,
					Img 	= [[Interface\LFGFRAME\UI-LFR-PORTRAIT]],
                    Attrib 	= {hidemenu = true},
					OnClick = function(self) ToggleFriendsFrame(5) end, 
				},
				Party  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 5,
					Point 	= {'TOP', 'parent.Raid', 'BOTTOM', 0, -16},
					Img 	= [[Interface\LFGFRAME\UI-LFG-PORTRAIT]],
                    Attrib 	= {
						condition = 'return PlayerInGroup()',
						hidemenu = true,
					},
					Hooks = {
						OnShow = function(self)
							self:SetText(IsPartyLFG() and INSTANCE_PARTY_LEAVE or PARTY_LEAVE)
						end,
						OnClick = function(self)
							if IsPartyLFG() or IsInLFGDungeon() then
								ConfirmOrLeaveLFGParty()
							else
								LeaveParty()
							end
						end,
					},
				}, 
			},
		},
		System = {
			Type 	= 'CheckButton',
			Setup 	= {
				'SecureHandlerBaseTemplate',
				'SecureHandlerClickTemplate',
				'CPUIListCategoryTemplate',
			},
			Text	= '|TInterface\\Store\\category-icon-wow:18:18:-4:0:64:64:14:50:14:50|t' .. CHAT_MSG_SYSTEM,
			ID = 4,
			SetAttribute = {'_onclick', 'control:RunFor(self:GetParent(), self:GetParent():GetAttribute("ShowHeader"), self:GetID())'},
			{
				Return  = {
					Type 	= 'Button',
					Setup 	= maskTemplates,
					Mixin 	= Button,
					ID 		= 1,
					Point 	= {'TOP', 'parent', 'BOTTOM', 0, -16},
					Desc	= RETURN_TO_GAME,
					RefTo 	= IsCustomClient and EscapeMenuButton1 or GameMenuButtonContinue,
					Img 	= [[Interface\FriendsFrame\Battlenet-WoWicon]], 
				}, 
				Logout  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 2,
					Point 	= {'TOP', 'parent.Return', 'BOTTOM', 0, 0},
					Desc	= LOGOUT,
					RefTo 	= IsCustomClient and EscapeMenuButton3 or GameMenuButtonLogout,
					Img 	= ICON:format('Ability_Paladin_BeaconOfLight'),
				--	OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('Ability_Paladin_BeaconOfLight')) end,
				},
				Exit  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 3,
					Point 	= {'TOP', 'parent.Logout', 'BOTTOM', 0, 0},
					Desc	= EXIT_GAME,
					RefTo 	= IsCustomClient and EscapeMenuButton2 or GameMenuButtonQuit,
					Img 	= [[Interface\RAIDFRAME\ReadyCheck-NotReady]],
				},
				Controller  = {
					Type 	= 'Button',
					Setup 	= maskTemplates,
					Mixin 	= Button,
					ID 		= 4,
					Point 	= {'TOP', 'parent.Exit', 'BOTTOM', 0, -16},
					Desc	= CONTROLS_LABEL,
					Img 	= db.TEXTURE.CP_X_CENTER,
                    Attrib 	= {hidemenu = true}, 
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, db.TEXTURE.CP_X_CENTER) end,
					OnClick = function() 
						if InCombatLockdown() then
							ConsolePortOldConfig:OnShow()
						else
							ConsolePortOldConfig:Show()
						end
					end,
				},
				Video  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 5,
					Point 	= {'TOP', 'parent.Controller', 'BOTTOM', 0, 0},
					Desc	= VIDEOOPTIONS_MENU, 
					RefTo 	= IsCustomClient and EscapeMenuButton4 or GameMenuButtonOptions,
					Img 	= [[Interface\Icons\Ability_TownWatch]], 
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('Ability_TownWatch')) end,
				},
				Audio  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 6,
					Point 	= {'TOP', 'parent.Video', 'BOTTOM', 0, 0},
					Desc	= VOICE_SOUND, 
					RefTo 	= IsCustomClient and EscapeMenuButton5 or GameMenuButtonSoundOptions,
					Img 	= [[Interface\FriendsFrame\PlusManz-BattleNet]],
				},
				Interface  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 7,
					Point 	= {'TOP', 'parent.Audio', 'BOTTOM', 0, 0},
					Desc	= UIOPTIONS_MENU, 
					RefTo 	= IsCustomClient and EscapeMenuButton8 or GameMenuButtonUIOptions,
					Img 	= [[Interface\TUTORIALFRAME\UI-TutorialFrame-GloveCursor]],
				},
				AddOns  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 8,
					Point 	= {'TOP', 'parent.Interface', 'BOTTOM', 0, 0},
					Desc	= ADDONS, 
                    Attrib 	= {hidemenu = true},
					OnClick = function(self)
						if (not IsCustomClient) then 
							InterfaceOptionsFrame:Show()
							PanelTemplates_SetTab(InterfaceOptionsFrame, 2);       
							InterfaceOptionsFrameAddOns:Show();
							InterfaceOptionsFrameCategories:Hide();
						else
							ShowAddonsPanel()
						end
					end,
					Img 	= ICON:format('inv_misc_wrench_01'),
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('inv_misc_wrench_01')) end,
				},
				Macros  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 9,
					Point 	= {'TOP', 'parent.AddOns', 'BOTTOM', 0, -16},
					Desc	= MACROS, 
					RefTo 	= IsCustomClient and EscapeMenuButton11 or GameMenuButtonMacros,
					Img 	= ICON:format('trade_engineering'),
					LoadScript = function(self) SetPortraitToTexture(self.Icon, ICON:format('trade_engineering')) end,
				},
				KeyBindings  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 10,
					Point 	= {'TOP', 'parent.Macros', 'BOTTOM', 0, 0},
					Desc	= KEY_BINDINGS, 
					RefTo 	= IsCustomClient and EscapeMenuButton9 or GameMenuButtonKeybindings,
					Img 	= [[Interface\MacroFrame\MacroFrame-Icon]],
				},
				Help  = {
					Type 	= 'Button',
					Setup 	= baseTemplates,
					Mixin 	= Button,
					ID 		= 11,
					Point 	= {'TOP', 'parent.KeyBindings', 'BOTTOM', 0, 0},
					Desc	= HELP_LABEL, 
					RefTo 	= HelpMicroButton,
                    Attrib 	= {hidemenu = true},
					Img 	= ICON:format('INV_Misc_QuestionMark'),
					OnLoadHook = function(self) SetPortraitToTexture(self.Icon, ICON:format('INV_Misc_QuestionMark')) end,
				}, 
			},
		},
	},
})

-- In case we're adding the loot dropdown
tinsert(maskTemplates, 'SecureHandlerBaseTemplate')
local lootWireFrame = {
	Loot = {
		Type 	= 'CheckButton',
		Setup 	= {
			'SecureHandlerBaseTemplate',
			'SecureHandlerShowHideTemplate',
			'SecureHandlerClickTemplate',
			'CPUIListCategoryTemplate',
		},
		Point 	= {'CENTER', 490, 0},
		Text	= [[|TInterface\Buttons\UI-GroupLoot-Dice-Up:24:24:0:-2|t]],
		Width 	= 50,
		ID = 5,
		OnLoad = function(self)
			CPAPI.SetShown(self,
				GroupLootFrame1:IsVisible() or
				GroupLootFrame2:IsVisible() or
				GroupLootFrame3:IsVisible() or
				GroupLootFrame4:IsVisible())-- or
				--BonusRollFrame:IsVisible())
		end,
		HideOtherHeader = function(self, headername)
			ret = {}
			for i = 1, select('#', _G[headername]:GetChildren()) do
				ret[i] = select(i, _G[headername]:GetChildren())
			end
		 
			local buttons = ret
			_G[headername]:SetAttribute('focused', false)
			for _, button in pairs(buttons) do
				button:Hide()
			end
		end,
		Multiple = {
			Probe = {
				{GroupLootFrame1, 'showhide'},
				{GroupLootFrame2, 'showhide'},
				{GroupLootFrame3, 'showhide'},
				{GroupLootFrame4, 'showhide'},
			--	{BonusRollFrame, 'showhide'},
			},
			SetAttribute = {
				{'_onclick', [[
				--control:RunFor(self:GetParent(), self:GetParent():GetAttribute("ShowHeader"), self:GetID()) 
				local currHeader = self:GetParent():GetAttribute("currentHeader")
				if(currHeader) then
					control:CallMethod('HideOtherHeader', currHeader)
				end
				local buttons = newtable(self:GetChildren())
				for _, button in pairs(buttons) do
					local condition = button:GetAttribute('condition')
					if condition then
						local show = control:Run(condition)
						if show then
							button:Show()
						else
							button:Hide()
						end
					else
						button:Show()
					end
				end
				self:GetParent():SetAttribute("currentHeader", self:GetName())
				]]},
				{'onheaderset', lootHeaderOnSetScript},
			},
		},
		{
			Loot1  = {
				Type 	= 'Button',
				Setup 	= maskTemplates,
				Mixin 	= LootButton,
				ID 		= 1,
				Img 	= ICON:format('INV_Misc_QuestionMark'),
				Obj 	= GroupLootFrame1,
				Probe 	= {GroupLootFrame1, 'probescript', nil, lootButtonProbeScript},
				RegisterForClicks = {'AnyUp', 'AnyDown'},
				Multiple = {
					SetAttribute = {
						{'circleclick', 'control:CallMethod("OnCircleClicked")'},
						{'squareclick', 'control:CallMethod("OnSquareClicked")'},
						{'triangleclick', 'control:CallMethod("OnTriangleClicked")'},
						{'pc', 0},
						{'condition', 'return false'},
					},
				},
			},
			Loot2  = {
				Type 	= 'Button',
				Setup 	= maskTemplates,
				Mixin 	= LootButton,
				ID 		= 2,
				Obj 	= GroupLootFrame2,
				Img 	= ICON:format('INV_Misc_QuestionMark'),
				Probe 	= {GroupLootFrame2, 'probescript', nil, lootButtonProbeScript},
				RegisterForClicks = {'AnyUp', 'AnyDown'},
				Multiple = {
					SetAttribute = {
						{'circleclick', 'control:CallMethod("OnCircleClicked")'},
						{'squareclick', 'control:CallMethod("OnSquareClicked")'},
						{'triangleclick', 'control:CallMethod("OnTriangleClicked")'},
						{'pc', 0},
						{'condition', 'return false'},
					},
				},
			},
			Loot3  = {
				Type 	= 'Button',
				Setup 	= maskTemplates,
				Mixin 	= LootButton,
				ID 		= 3,
				Obj 	= GroupLootFrame3,
				Img 	= ICON:format('INV_Misc_QuestionMark'),
				Probe 	= {GroupLootFrame3, 'probescript', nil, lootButtonProbeScript},
				RegisterForClicks = {'AnyUp', 'AnyDown'},
				Multiple = {
					SetAttribute = {
						{'circleclick', 'control:CallMethod("OnCircleClicked")'},
						{'squareclick', 'control:CallMethod("OnSquareClicked")'},
						{'triangleclick', 'control:CallMethod("OnTriangleClicked")'},
						{'pc', 0},
						{'condition', 'return false'},
					},
				},
			},
			Loot4  = {
				Type 	= 'Button',
				Setup 	= maskTemplates,
				Mixin 	= LootButton,
				ID 		= 4,
				Obj 	= GroupLootFrame4,
				Img 	= ICON:format('INV_Misc_QuestionMark'),
				Probe 	= {GroupLootFrame4, 'probescript', nil, lootButtonProbeScript},
				RegisterForClicks = {'AnyUp', 'AnyDown'},
				Multiple = {
					SetAttribute = {
						{'circleclick', 'control:CallMethod("OnCircleClicked")'},
						{'squareclick', 'control:CallMethod("OnSquareClicked")'},
						{'triangleclick', 'control:CallMethod("OnTriangleClicked")'},
						{'pc', 0},
						{'condition', 'return false'},
					},
				},
			},
			-- Bonus  = {
			-- 	Type 	= 'Button',
			-- 	Setup 	= maskTemplates,
			-- 	Mixin 	= LootButton,
			-- 	ID 		= 5,
			-- 	NoMask 	= true,
			-- 	Obj 	= BonusRollFrame,
			-- 	Img 	= ICON:format('INV_Misc_QuestionMark'),
			-- 	Probe 	= {BonusRollFrame, 'probescript', nil, lootButtonProbeScript},
			-- 	RegisterForClicks = {'AnyUp', 'AnyDown'},
			-- 	Multiple = {
			-- 		SetAttribute = {
			-- 			{'pc', 0},
			-- 			{'condition', 'return false'},
			-- 		},
			-- 	},
			-- },
		},
	},
}

do	
	ConsolePortUIConfig.Menu = ConsolePortUIConfig.Menu or {}

	local cfg = ConsolePortUIConfig.Menu

	cfg.lootprobe = cfg.lootprobe and true or false 
	cfg.scale = cfg.scale or 1

	if cfg.lootprobe then
		UI:BuildFrame(Menu, lootWireFrame)
	end

	lootWireFrame = nil
	maskTemplates = nil
	baseTemplates = nil

	CPAPI.Mixin(Menu, ConsolePortMenuSecureMixin, ConsolePortMenuArtMixin)

	Menu:StartEnvironment()
	Menu:Execute('hID, bID = 4, 1')
	Menu:DrawIndex(function(header)
		for i, button in ipairs({header:GetChildren()}) do

			

			if button:GetAttribute('hidemenu') then
				button:SetAttribute('type', 'macro')

				if(IsCustomClient) then
					button:SetAttribute('macrotext', '/click EscapeMenuButton1')
				else
					button:SetAttribute('macrotext', '/click GameMenuButtonContinue')
				end

			end
			if button.RefTo then
				local macrotext = button:GetAttribute('macrotext')
				local prefix = (macrotext and macrotext .. '\n') or ''  
				button:SetAttribute('macrotext', prefix .. '/click ' .. button.RefTo:GetName())
				button:SetAttribute('type', 'macro')  

			end
			button:Hide()
			header:SetFrameRef(tostring(button:GetID()), button)
		end
	end)


	UI:RegisterFrame(Menu, 'Menu', false, true)
	UI:HideFrame(IsCustomClient and EscapeMenu or GameMenuFrame, true)

	Menu:SetScale(cfg.scale)
	Menu:LoadArt()

	L.Menu = Menu
end

--[[

Character
	Character Info
	Backpack (inventory)
	Spec&Talents
	Spell book
	Collections
Gameplay
	Quest/Map
	Adventure Guide
	Group Finder
	Achievements
	What's New
	Shop
- 	Teleport
Social
	Friends List
	Guild (guild finder)
	Raid
	Events (Calendar)
-	Leave Group
System
	Return to game
	Logout
	Exit Game

	Controller
	System (settings)
	Interface

	AddOns
	Macros

	Key bindings
	Help
]]
