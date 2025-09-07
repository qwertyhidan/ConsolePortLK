-- Custom client workarounds goes here... for now only Ascension client workarounds
local _, db = ...

ConsolePort:AddPlugin('Custom', function(self)  

    local function IsAscensionSpellNode(node) 
        if ((node and node:GetParent()):GetName() and (node and node:GetParent()):GetName():match("AscensionSpellbookFrame")
					and node:GetName():match("SpellButton")) then
            return true
        end
        return false
    end

    for _, frame in pairs({
        'AddonPanel',
        'AscensionCharacterFrame',
        'AscensionSpellbookFrame',
        'AscensionLFGFrame',
        'Collections',
        'EscapeMenu',
        'PathToAscensionFrame', 
        'SkillCardsFrame',
    }) do self:AddFrame(frame) end
    
    self:UpdateFrames() 

    -- Register custom check function with the main addon's plugin system.
    if db.PLUGINCHECKS and db.PLUGINCHECKS.IsSpellNode then
        tinsert(db.PLUGINCHECKS.IsSpellNode, IsAscensionSpellNode)
    end

end, CPAPI.IsCustomClient())