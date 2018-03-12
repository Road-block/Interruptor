Interruptor = AceLibrary("AceAddon-2.0"):new("AceConsole-2.0", "AceDB-2.0", "AceEvent-2.0", "AceHook-2.1", "FuBarPlugin-2.0")
local DF = AceLibrary("Deformat-2.0")
local T  = AceLibrary("Tablet-2.0")
local BS = AceLibrary("Babble-Spell-2.2")
local SC = AceLibrary("SpellCache-1.0")
local SS = AceLibrary("SpellStatus-1.0")
local parser = ParserLib:GetInstance("1.1")
local gratuity = AceLibrary("Gratuity-2.0")
local L = AceLibrary("AceLocale-2.2"):new("Interruptor")

Interruptor._class, Interruptor._eClass = UnitClass("player")
Interruptor._pName = (UnitName("player"))

local groupTypeDesc = {
  [1] = L["Party Only"],
  [2] = L["Raid Only"],
  [3] = L["Party/Raid"],
}
local party,raid = {},{}
do
  for i=1,MAX_RAID_MEMBERS do
    party[i] = string.format("party%d",i)
  end
  for i=1,MAX_PARTY_MEMBERS do
    raid[i] = string.format("raid%d",i)
  end
end

local interrupts = {
  ["ROGUE"] = {
    ["Kick"] = BS["Kick"];
  },
  ["WARRIOR"] = {
    ["Shield Bash"] = BS["Shield Bash"];
    ["Pummel"] = BS["Pummel"];
  },
  ["SHAMAN"] = {
    ["Earth Shock"] = BS["Earth Shock"];
  },
  ["MAGE"] = {
    ["Counterspell"] = BS["Counterspell"];
  },
  ["PRIEST"] = {
    ["Silence"] = BS["Silence"];
  },
  ["WARLOCK"] = {
    ["Spell Lock"] = BS["Spell Lock"];
  },
}

local defaults = {
  Active = true,
  GroupType = 3,
  Channel = "SAY",
  Announce = L[">>Interrupt Used!<<"],
  Whisper = NONE
}

local options  = {
  type = "group",
  handler = Interruptor,
  args =
  {
    Active =
    {
      name = L["Active"],
      desc = L["Activate/Suspend 'Interruptor'"],
      type = "toggle",
      get  = "GetActiveStatusOption",
      set  = "SetActiveStatusOption",
      order = 1,
    },
    GroupType =
    {
      name = L["Group Type"],
      desc = L["1 = Party only, 2 = Raid only, 3 = Both"],
      type = "range",
      get  = "GetGroupTypeOption",
      set  = "SetGroupTypeOption",
      disabled = function() return not Interruptor.db.profile.Active end,
      min = 1,
      max = 3,
      step = 1,
      order = 2
    },
    Channel = 
    {
      name = L["Channel"],
      desc = L["Interrupt Announce Channel"],
      type = "text",
      get  = "GetChannelOption",
      set  = "SetChannelOption",
      usage = "<channel>",
      disabled = function() return not Interruptor.db.profile.Active end,
      order = 3,
      validate = {["SAY"]=SAY,["PARTY"]=PARTY,["RAID"]=RAID},
    },
    Announce = {
      name = L["Announce"],
      desc = L["Announce Text"],
      type = "text",
      get  = "GetAnnounceText",
      set  = "SetAnnounceText",
      usage = string.format("%s to reset or <any>",DEFAULTS),
      disabled = function() return not Interruptor.db.profile.Active end,
      order = 4,
      validate = function(text) return text == DEFAULTS or string.find(text,"[%a%s%c]+") end,
    },
    Whisper = {
      name = L["Whisper"],
      desc = L["Whisper a player"],
      type = "text",
      get  = "GetWhisperTarget",
      set  = "SetWhisperTarget",
      usage = string.format("%s to disable, or <name>",NONE),
      disabled = function() return not Interruptor.db.profile.Active end,
      order = 5,
      validate = function(name) return name == NONE or string.find(name,"^%w+$") end,
    },
  },
}

---------
-- FuBar
---------
Interruptor.hasIcon = [[Interface\AddOns\Interruptor\img\icon]]
Interruptor.title = L["Interruptor"]
Interruptor.defaultMinimapPosition = 260
Interruptor.defaultPosition = "CENTER"
Interruptor.cannotDetachTooltip = true
Interruptor.tooltipHiddenWhenEmpty = false
Interruptor.hideWithoutStandby = true
Interruptor.independentProfile = true

function Interruptor:OnTooltipUpdate()
  local groupType = self.db.profile.GroupType
  local hint = string.format(L["%s\n|cffFFA500Click:|r Cycle Group Mode|r\n|cffFFA500Right-Click:|r Options"],groupTypeDesc[groupType])
  T:SetHint(hint)
end

function Interruptor:OnTextUpdate()
  local groupType = self.db.profile.GroupType
  local active = self.db.profile.Active
  if (not active) then
    self:SetText(L["Suspended"])
  else
    self:SetText(groupTypeDesc[groupType] or L["Interruptor"])
  end
end

function Interruptor:OnClick()
  local active = self.db.profile.Active
  if not active then return end
  local groupType = self.db.profile.GroupType
  if tonumber(groupType) == nil then
    return self:SetGroupTypeOption(2)
  end
  local newType = groupType + 1
  if newType > 3 then
    newType = 1
  end
  self:Print(groupTypeDesc[newType])
  return self:SetGroupTypeOption(newType)
end

function Interruptor:OnInitialize() -- ADDON_LOADED (1)
  self:RegisterDB("InterruptorDB")
  self:RegisterDefaults("profile", defaults )
  self:RegisterChatCommand( { "/itr", "/interruptor" }, options )
  self.OnMenuRequest = options
  if not FuBar then
    self.OnMenuRequest.args.hide.guiName = L["Hide minimap icon"]
    self.OnMenuRequest.args.hide.desc = L["Hide minimap icon"]
  end
  if not (interrupts[self._eClass]) then
    self.db.profile.Active = false
    self:OnDisable()
    DisableAddOn("Interruptor")
  end
end

function Interruptor:IconUpdate()
  if self.db.profile.Active then
    self:SetIcon([[Interface\AddOns\Interruptor\img\icon]])
  else
    self:SetIcon([[Interface\AddOns\Interruptor\img\icon_disable]])
  end
end

function Interruptor:OnEnable() -- PLAYER_LOGIN (2)
  self:RegisterEvent("PLAYER_ENTERING_WORLD")
  self:IconUpdate()
  self:UpdateTooltip()
end

function Interruptor:OnDisable()
  self:UnregisterAllEvents()
  self:UnhookAll()
  self:IconUpdate()
  self:Print(L["Disabling"])
end

function Interruptor:PLAYER_ENTERING_WORLD()
  self:RegisterEvent("SpellCache_Updated")
  self:Interrupts()
end

function Interruptor:UI_ERROR_MESSAGE(msg)
  if self:IsEventScheduled("Interruptor_SpellLock") then
    self:CancelScheduledEvent("Interruptor_SpellLock")
  end
  self:UnregisterEvent("UI_ERROR_MESSAGE")
end

function Interruptor:SpellCache_Updated()
  self:Interrupts()
end

function Interruptor:Interrupts()
  for spell, locSpell in pairs(interrupts[self._eClass]) do
    local spellName = SC:GetSpellData(locSpell)
    if (spellName) then
      self._interrupts = self._interrupts or {}
      self._interrupts[locSpell] = spell
    end
  end
  if not (self.db.profile.Active) then return end
  if (self._interrupts) and (next(self._interrupts)) then
    if self._eClass == "WARLOCK" then
      if not self:IsHooked("CastPetAction") then
        self:Hook("CastPetAction")
      end
    else
      if not self:IsEventRegistered("SpellStatus_SpellCastInstant") then
        self:RegisterEvent("SpellStatus_SpellCastInstant","Casted")
      end
      if not self:IsEventRegistered("SpellStatus_SpellCastCastingFinish") then
        self:RegisterEvent("SpellStatus_SpellCastCastingFinish","Casted")
      end      
    end
  end
end

function Interruptor:CastPetAction(slotId, onUnit)
  local sId, sName, sRank, sFullName = self:GetSpellInfo(slotId, "SetPetAction")
  if (sName) and self._interrupts[sName] and (GetPetActionsUsable()) then
    if not self:IsEventRegistered("UI_ERROR_MESSAGE") then
      self:RegisterEvent("UI_ERROR_MESSAGE")
    end
    self:ScheduleEvent("Interruptor_SpellLock",self.Announce,0.5,self)
  end
  self.hooks["CastPetAction"](slotId, onUnit)
end

function Interruptor:Casted(sId, sName, sRank, sFullName, sCastTime)
  if not self._interrupts[sName] then return end
  self:Announce()
end

function Interruptor:GetSpellInfo(slotId, methodName)
  gratuity[methodName](gratuity,slotId)
  local spellName = gratuity:GetLine(1)
  local spellRank = gratuity:GetLine(1, true)
  --empty slot?
  if (not spellName) then
    return
  end
  local sName, sRank, sId, sFullName = SC:GetSpellData(spellName, spellRank)
  if (sName) then
    return sId, sName, sRank, sFullName
  else
    return nil, spellName, nil, nil
  end  
end

function Interruptor:GetGroupType()
  -- 1 = Party only, 2 = Raid only, 3 = Both
  if UnitExists("party1") and not UnitInRaid("player") then
    return 1
  elseif UnitInRaid("player") then
    return 2
  else
    return 0 -- solo
  end
end

function Interruptor:GetGroupTypeOption()
  return self.db.profile.GroupType
end

function Interruptor:SetGroupTypeOption(newType)
  self.db.profile.GroupType = newType
  self:UpdateText()
  self:UpdateTooltip()
end

function Interruptor:GetActiveStatusOption()
  return self.db.profile.Active
end

function Interruptor:SetActiveStatusOption(newStatus)
  self.db.profile.Active = newStatus
  if (self.db.profile.Active) then
    self:PLAYER_ENTERING_WORLD()
  end
  self:IconUpdate()
  self:UpdateText()
end

function Interruptor:GetChannelOption()
  return self.db.profile.Channel
end

function Interruptor:SetChannelOption(newChannel)
  self.db.profile.Channel = newChannel
end

function Interruptor:GetAnnounceText()
  return self.db.profile.Announce
end

function Interruptor:SetAnnounceText(newText)
  if newText == DEFAULTS then
    newText = defaults.Announce
  end
  self.db.profile.Announce = newText
end

function Interruptor:GetWhisperTarget()
  return self.db.profile.Whisper
end

function Interruptor:SetWhisperTarget(newTarget)
  if newTarget == NONE then
    if UnitExists("target") and UnitIsPlayer("target") and UnitIsFriend("player","target") then
      newTarget = (UnitName("target"))
    end
  end
  self.db.profile.Whisper = newTarget
end

function Interruptor:inGroup(name)
  local lowname = string.lower(name)
  if lowname == string.lower(self._pName) then
    return true
  end
  local numRaid, numParty = GetNumRaidMembers(), GetNumPartyMembers()
  if numRaid > 0 then
    for i=1,numRaid do
      if lowname == string.lower(UnitName(raid[i])) then
        return true
      end
    end
  elseif numParty > 0 then
    for i=1,numParty do
      if lowname == string.lower(UnitName(party[i])) then
        return true
      end
    end
  end
  return false
end

function Interruptor:Announce(msg)
  if not self.db.profile.Active then return end
  local optGroup = self.db.profile.GroupType
  local getGroup = self:GetGroupType()
  if getGroup == 0 then return end
  local optChannel, channel = self.db.profile.Channel
  if optChannel == "RAID" and getGroup == 1 then
    channel = "PARTY"
  else
    channel = optChannel
  end
  if (channel) then
    SendChatMessage(self.db.profile.Announce,channel)
  end
  local whispertarget = self.db.profile.Whisper
  if string.lower(whispertarget) ~= string.lower(NONE) and self:inGroup(whispertarget) then
    SendChatMessage(self.db.profile.Announce, "WHISPER", nil, whispertarget)
  end
  if (msg) then
    self:Print(msg) -- for debug
  end
end
