local playerGUID = UnitGUID("player")
local lastCritTime = time()

CritWow = {

}

local defaults = {
    playsSound = true,
    debounce = 1,
}

function CritWow:PlaySound()
    PlaySoundFile("Interface\\AddOns\\CritWow\\sounds\\" .. tostring(math.random(1, 17)) .. ".mp3", "master")
end

function CritWow:SetDebounceSliderText()
    local debounceTitle = "Unlimited"
    if CritWowDB.debounce > 0 then
        debounceTitle = "Once per " .. CritWowDB.debounce .. "s"
    end

    getglobal("CritWowDebounceSpeedSlider").Text:SetText("Wows: " .. debounceTitle);
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function(self, event, addOnName)
    if event == "ADDON_LOADED" and addOnName == "CritWow" then
        self:SetDefaults()
        self:InitializeOptions()
    end
    self:COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
end)

function f:SetDefaults()
    CritWowDB = CritWowDB or CopyTable(defaults)
end

function f:InitializeOptions()
    self.panel = CreateFrame("Frame")
    self.panel.name = "Crit Wow"

    local title = self.panel:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
    title:SetPoint("TOP")
    title:SetText("Crit Wow")

    local cb = CreateFrame("CheckButton", nil, self.panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, -20)
    cb.Text:SetText("Play sounds")
    cb:HookScript("OnClick", function(_, btn, down)
        CritWowDB.playsSound = cb:GetChecked()
    end)
    cb:SetChecked(CritWowDB.playsSound)

    local debounceSlider = CreateFrame("Slider", "CritWowDebounceSpeedSlider", self.panel, "OptionsSliderTemplate")
    debounceSlider:SetPoint("TOPLEFT", 20, -70)
    debounceSlider:SetMinMaxValues(0, 30)
    debounceSlider:SetValueStep(2)
    debounceSlider:SetObeyStepOnDrag(true)
    debounceSlider:SetValue(CritWowDB.debounce * 10)
    getglobal(debounceSlider:GetName() .. "Low"):SetText("Unl");
    getglobal(debounceSlider:GetName() .. "High"):SetText("Every 3");

    CritWow:SetDebounceSliderText()
    debounceSlider.tooltipText = "Speed of Wows"
    debounceSlider:HookScript("OnValueChanged", function(_)
        CritWowDB.debounce = _:GetValue() / 10

        CritWow:SetDebounceSliderText()
    end)

    local btn = CreateFrame("Button", nil, self.panel, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", cb, 200, -10)
    btn:SetText("Play test sound")
    btn:SetWidth(100)
    btn.tooltipText = "Volume controlled by master sound level"
    btn:SetScript("OnClick", function()
        CritWow:PlaySound()
    end)

    InterfaceOptions_AddCategory(self.panel)
end

function f:COMBAT_LOG_EVENT_UNFILTERED(...)
    local timestamp, subevent, _, sourceGUID, sourceName, sourceFlags, sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags = ...
    local spellId, spellName, spellSchool
    local amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand

    if subevent == "SWING_DAMAGE" then
        amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = select(12, ...)
    elseif subevent == "SPELL_DAMAGE" then
        spellId, spellName, spellSchool, amount, overkill, school, resisted, blocked, absorbed, critical, glancing, crushing, isOffHand = select(12, ...)
    elseif subevent == "SPELL_HEAL" then
        spellId, spellName, spellSchool, amount, overhealing, absorbed, critical = select(12, ...)
    end

    if critical and sourceGUID == playerGUID then
        local currentTime = time()
        if (lastCritTime + CritWowDB.debounce <= currentTime and CritWowDB.playsSound) then
            CritWow:PlaySound()
            lastCritTime = currentTime
        end
    end
end

SLASH_CRITWOW1 = "/critwow"

SlashCmdList.CRITWOW = function(msg, editBox)
    InterfaceOptionsFrame_OpenToCategory(f.panel)
    InterfaceOptionsFrame_OpenToCategory(f.panel)
end