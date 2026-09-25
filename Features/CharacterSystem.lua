-- ==================================================
-- Jaden HUB | CORE | Character System (Integrated & Cleaned)
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Player = Players.LocalPlayer

-- ==================================================
-- CHARACTER SYSTEM
-- ==================================================
local CharacterSystem = {}
CharacterSystem.Features = {}
CharacterSystem.CurrentCharacter = nil
CharacterSystem.CurrentHumanoid = nil
CharacterSystem.CurrentRoot = nil
CharacterSystem.Initialized = false
CharacterSystem.Restarting = false

-- ==================================================
-- GET HUMANOID
-- ==================================================
function CharacterSystem:GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

-- ==================================================
-- REGISTER FEATURE
-- ==================================================
-- Feature should provide:
--   Name = "AntiAFK"
--   Enable = function() end
--   Disable = function() end
--   IsEnabled = function() return bool end
--   OnCharacterAdded = function(Char, Hum, Root) end (optional)
--   OnCharacterRemoving = function(Char, Hum, Root) end (optional)
-- ==================================================
function CharacterSystem:RegisterFeature(Feature)
    if not Feature or not Feature.Name then
        warn("[CharacterSystem] Invalid Feature")
        return
    end

    self.Features[Feature.Name] = Feature
    print("[CharacterSystem] Registered: " .. Feature.Name)

    -- If character exists and feature is active, re-apply
    if self.CurrentCharacter and Feature.IsEnabled and Feature.IsEnabled() then
        if Feature.OnCharacterAdded then
            task.spawn(function()
                pcall(function()
                    Feature.OnCharacterAdded(self.CurrentCharacter, self.CurrentHumanoid, self.CurrentRoot)
                end)
            end)
        end
    end
end

-- ==================================================
-- UNREGISTER FEATURE
-- ==================================================
function CharacterSystem:UnregisterFeature(Name)
    if self.Features[Name] then
        self.Features[Name] = nil
        print("[CharacterSystem] Unregistered: " .. Name)
    end
end

-- ==================================================
-- RESTART ALL FEATURES
-- ==================================================
function CharacterSystem:RestartAllFeatures()
    if self.Restarting then return end
    self.Restarting = true

    print("[CharacterSystem] ========================================")
    print("[CharacterSystem] Restarting All Features...")
    print("[CharacterSystem] ========================================")

    for name, Feature in pairs(self.Features) do
        local IsEnabled = false
        if Feature.IsEnabled then
            pcall(function()
                IsEnabled = Feature.IsEnabled()
            end)
        end

        if IsEnabled then
            task.spawn(function()
                print("[CharacterSystem] Restarting: " .. name)

                -- Disable old state
                if Feature.Disable then
                    pcall(function()
                        Feature.Disable()
                    end)
                end

                task.wait(0.3)

                -- Enable new state
                if Feature.Enable then
                    pcall(function()
                        Feature.Enable()
                    end)
                end

                task.wait(0.2)

                -- OnCharacterAdded custom logic
                if Feature.OnCharacterAdded and self.CurrentCharacter then
                    pcall(function()
                        Feature.OnCharacterAdded(self.CurrentCharacter, self.CurrentHumanoid, self.CurrentRoot)
                    end)
                end

                print("[CharacterSystem] ✅ Restarted: " .. name)
            end)

            task.wait(0.2)
        end
    end

    task.wait(1)
    self.Restarting = false
    print("[CharacterSystem] All Features Restarted")
end

-- ==================================================
-- ON CHARACTER ADDED
-- ==================================================
function CharacterSystem:OnCharacterAdded(Char)
    print("[CharacterSystem] ========================================")
    print("[CharacterSystem] Character Added")
    print("[CharacterSystem] ========================================")

    self.CurrentCharacter = Char

    -- Wait for Humanoid
    local Hum = Char:WaitForChild("Humanoid", 10)
    local Root = Char:WaitForChild("HumanoidRootPart", 10)

    self.CurrentHumanoid = Hum
    self.CurrentRoot = Root

    if not Hum or not Root then
        warn("[CharacterSystem] Humanoid/Root not found")
        return
    end

    -- Wait for BypassAntiCheat to replace Humanoid
    task.wait(2)

    -- Update with the new Humanoid/Root
    Hum = Char:FindFirstChildOfClass("Humanoid")
    Root = Char:FindFirstChild("HumanoidRootPart")
    self.CurrentHumanoid = Hum
    self.CurrentRoot = Root

    if not Hum then
        warn("[CharacterSystem] Humanoid not found after wait")
        return
    end

    -- Restart all features
    self:RestartAllFeatures()
end

-- ==================================================
-- ON CHARACTER REMOVING
-- ==================================================
function CharacterSystem:OnCharacterRemoving(Char)
    print("[CharacterSystem] Character Removing")

    for name, Feature in pairs(self.Features) do
        if Feature.OnCharacterRemoving then
            pcall(function()
                Feature.OnCharacterRemoving(Char, self.CurrentHumanoid, self.CurrentRoot)
            end)
        end
    end

    self.CurrentCharacter = nil
    self.CurrentHumanoid = nil
    self.CurrentRoot = nil
end

-- ==================================================
-- INIT
-- ==================================================
function CharacterSystem:Init()
    if self.Initialized then return end
    self.Initialized = true

    -- Handle current character if already loaded
    if Player.Character then
        task.spawn(function()
            self:OnCharacterAdded(Player.Character)
        end)
    end

    -- Listen for future characters
    Player.CharacterAdded:Connect(function(Char)
        self:OnCharacterAdded(Char)
    end)

    Player.CharacterRemoving:Connect(function(Char)
        self:OnCharacterRemoving(Char)
    end)

    print("[CharacterSystem] Initialized")
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.Jaden_CharacterSystem = CharacterSystem

print("✅ CharacterSystem Loaded & Synced with Jaden Hub")
