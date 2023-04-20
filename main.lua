local playerGUID = UnitGUID("player")
local lastCritTime = time()

CritWow = {
    modes = {
        wowenWilson = {
            id = "wowenWilson",
            name = "Wowen Wilson",
            count = 19,
            soundPath = "Interface\\AddOns\\CritWow\\sounds\\wowen_wilson\\"
        },
        dnc = {
            id = "dnc",
            name = "DNC",
            dncChance = 92,
            soundPath = "Interface\\AddOns\\CritWow\\sounds\\dnc\\"
        }
    },
    defaults = {
        playsSound = true,
        debounce = 1,
        mode = "wowenWilson",
    }
}

function CritWow:PlaySound()
    local path = self.modes.wowenWilson.soundPath
    local fileName = ""

    if CritWowDB.mode == "dnc" then
        path = self.modes.dnc.soundPath

        if math.random(1, 100) <= self.modes.dnc.dncChance then
            fileName = "dnc.mp3"
        else
            fileName = "igc.mp3"
        end
    else
        fileName = tostring(math.random(1, self.modes.wowenWilson.count)) .. ".mp3"
    end

    PlaySoundFile(path .. fileName, "master")
end

function CritWow:SetDebounceSliderText()
    local debounceTitle = "Unlimited"
    if self.db.debounce > 0 then
        debounceTitle = "Once per " .. self.db.debounce .. "s"
    end

    getglobal("CritWowDebounceSpeedSlider").Text:SetText("Wows: " .. debounceTitle);
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
f:SetScript("OnEvent", function(self, event, addOnName)
    if event == "ADDON_LOADED" and addOnName == "CritWow" then
        self:InitializeOptions()
    end
    self:COMBAT_LOG_EVENT_UNFILTERED(CombatLogGetCurrentEventInfo())
end)

function CritWow:SetDefaults()
    CritWowDB = CritWowDB or CopyTable(self.defaults)

    -- Set any missing config options
    for idx, val in pairs(self.defaults) do
        if not CritWowDB[idx] then
            CritWowDB[idx] = self.defaults[idx]
        end
    end

    self.db = CritWowDB
end

function f:InitializeOptions()
    CritWow:SetDefaults()

    self.panel = CreateFrame("Frame")
    self.panel.name = "Crit Wow"
    self.db = CritWowDB

    local title = self.panel:CreateFontString("ARTWORK", nil, "GameFontNormalLarge")
    title:SetPoint("TOP")
    title:SetText("Crit Wow")

    -- Play sounds check
    local cb = CreateFrame("CheckButton", nil, self.panel, "InterfaceOptionsCheckButtonTemplate")
    cb:SetPoint("TOPLEFT", 20, -20)
    cb.Text:SetText("Play sounds")
    cb:HookScript("OnClick", function(_, btn, down)
        CritWowDB.playsSound = cb:GetChecked()
    end)
    cb:SetChecked(CritWowDB.playsSound)

    -- Debounce slider
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

    -- Play test sound button
    local btn = CreateFrame("Button", nil, self.panel, "UIPanelButtonTemplate")
    btn:SetPoint("TOPLEFT", cb, 200, -10)
    btn:SetText("Play test sound")
    btn:SetWidth(100)
    btn.tooltipText = "Volume controlled by master sound level"
    btn:SetScript("OnClick", function()
        CritWow:PlaySound()
    end)

    -- Sound mode dropdown
    local dropDown = CreateFrame("FRAME", nil, self.panel, "UIDropDownMenuTemplate")
    dropDown:SetPoint("TOPLEFT", btn, -20, -30)
    UIDropDownMenu_SetWidth(dropDown, 200)
    UIDropDownMenu_SetText(dropDown, "Sound mode: " .. CritWow.modes[self.db.mode].name)

    UIDropDownMenu_Initialize(dropDown, function(self, level, menuList)
        local selectOption = UIDropDownMenu_CreateInfo()
        selectOption.text = CritWow.modes.wowenWilson.name
        selectOption.arg1 = CritWow.modes.wowenWilson.id
        selectOption.checked = CritWowDB.mode == CritWow.modes.wowenWilson.id
        selectOption.func = self.SetValue
        UIDropDownMenu_AddButton(selectOption)

        selectOption.text = CritWow.modes.dnc.name
        selectOption.arg1 = CritWow.modes.dnc.id
        selectOption.checked = CritWowDB.mode == CritWow.modes.dnc.id
        UIDropDownMenu_AddButton(selectOption)

    end)

    function dropDown:SetValue(newValue)
        CritWowDB.mode = newValue
        UIDropDownMenu_SetText(dropDown, "Sound mode: " .. CritWow.modes[CritWowDB.mode].name)
        CloseDropDownMenus()
    end

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