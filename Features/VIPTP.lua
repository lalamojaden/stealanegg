-- ==================================================
-- Cruuzz HUB | FEATURE | VIPTP (AFK Farm Only)
-- ==================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Player = Players.LocalPlayer
local Container = workspace:WaitForChild("AreaEggSlotsClient")

-- ==================================================
-- REMOTES
-- ==================================================
local CollectEvent = nil
local ForestStrike = nil

pcall(function()
    CollectEvent = ReplicatedStorage.Packages.Networking["RF/EggWorld/AskFieldEggCarry"]
end)

pcall(function()
    ForestStrike = ReplicatedStorage.Packages.Networking["RE/GuardPatrol/ForestStrike"]
end)

if not CollectEvent then
    warn("[VIPTP] CollectEvent not found")
    return
end

print("[VIPTP] CollectEvent OK")

-- ==================================================
-- SETTINGS
-- ==================================================
local TARGET_UID = nil
local SAFE_ZONE = Vector3.new(533, 70, -366)

local FLY_SPEED = 1000
local RETURN_SPEED = 800
local FLY_OFFSET = 15

-- ✅ Distance Threshold
local DISTANCE_THRESHOLD = 3000

-- ✅ Intervals (លឿន)
local COLLECT_INTERVAL = 0.05
local COLLECT_INTERVAL_AUTO_FLY_BACK = 0.05
local DAY_CHECK_INTERVAL = 0.5
local NIGHT_CHECK_INTERVAL = 0.05

-- ✅ Thresholds
local SHOT_DISTANCE = 15
local LOCK_ABOVE = 1
local LOCK_ABOVE_AUTO_FLY_BACK = 2
local ARRIVE_DISTANCE = 2
local SAFE_LOCK_DISTANCE = 3
local TIMEOUT_SECONDS = 30

local AUTO_FLY_BACK_DISTANCE_THRESHOLD = 6
local STABLE_Y_REQUIRED = 3
local STABLE_Y_THRESHOLD = 0.1

local SEARCH_PREFIX = "FirstAreaEgg"
local POSITION_THRESHOLD = 1

local LOCK_POSITION = Vector3.new(
    607.6259155273438,
    70.57420349121094,
    -326.8830261230469
)

-- ==================================================
-- RAGDOLL BYPASS
-- ==================================================
local RagdollEnabled = false
local RagdollConnection = nil
local ForceUpConnection = nil

-- ==================================================
-- STATE
-- ==================================================
local Running = false
local CurrentStep = "idle"
local CurrentMode = "none"

local FlyConnection = nil
local BodyVelocity = nil
local BodyGyro = nil
local ActiveHeartbeat = nil
local LockConnection = nil

local FirstEggList = {}
local FirstEggUid = nil
local FirstEggSlotKey = nil

local CollectAttempts = 0
local CollectTime = 0

local FlyTargetStarted = false
local CollectDone = false
local TargetCollected = false

-- ✅ ForestStrike State
local ForestStrikeFired = false
local FirstEggCollected = false  -- ✅ ពេល First Egg ចូល Container វិញ

local SavedTargetPosition = nil
local TargetLockedCFrame = nil

local SavedWalkSpeed = nil
local SavedJumpPower = nil
local SavedJumpHeight = nil
local SavedUseJumpPower = nil

-- ✅ Auto Fly Back State
local AutoFlyBackActive = false
local AutoFlyBackAttempts = 0
local SavedEggY = nil
local AutoFlyBackTargetUid = nil
local AutoFlyBackCheckStarted = false
local FlyToSafeZoneActive = false
local FlyToSafeZoneRequested = false

-- ✅ Container Collect State
local ContainerCollectStartTime = nil
local ContainerCollectTimeout = 5

-- ==================================================
-- FORWARD DECLARATIONS
-- ==================================================
local FlyToSafeZone
local AutoStop
local StartAutoFlyBackTask

-- ==================================================
-- GET HUMANOID
-- ==================================================
local function GetHumanoid()
    local Char = Player.Character
    if not Char then return nil, nil end
    local Hum = Char:FindFirstChildOfClass("Humanoid")
    local Root = Char:FindFirstChild("HumanoidRootPart")
    return Hum, Root
end

-- ==================================================
-- RAGDOLL BYPASS
-- ==================================================
local function ForceUp()
    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end

    pcall(function()
        if Hum:GetState() == Enum.HumanoidStateType.Physics then
            Hum:ChangeState(Enum.HumanoidStateType.GettingUp)
        end

        Hum:SetStateEnabled(Enum.HumanoidStateType.Physics, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Ragdoll, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
        Hum:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

        Hum.PlatformStand = false
        Hum.Sit = false

        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero

        Root.CanCollide = true

        Hum.BreakJointsOnDeath = false
        Hum.RequiresNeck = false
    end)
end

local function CleanupRagdollConstraints()
    local Char = Player.Character
    if not Char then return end

    pcall(function()
        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant.Name:find("RagdollConstraint") then
                descendant:Destroy()
            end
            if descendant.Name:find("RagdollAttachment") then
                descendant:Destroy()
            end
        end

        for _, descendant in ipairs(Char:GetDescendants()) do
            if descendant:IsA("Motor6D") then
                descendant.Enabled = true
            end
        end
    end)
end

local function EnableRagdollBypass()
    if RagdollEnabled then return end
    RagdollEnabled = true

    RagdollConnection = RunService.Heartbeat:Connect(function()
        if not RagdollEnabled then return end
        ForceUp()
    end)

    ForceUpConnection = task.spawn(function()
        while RagdollEnabled do
            task.wait(0.1)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[VIPTP] Ragdoll Bypass: ON")
end

local function DisableRagdollBypass()
    if not RagdollEnabled then return end
    RagdollEnabled = false

    if RagdollConnection then
        RagdollConnection:Disconnect()
        RagdollConnection = nil
    end

    print("[VIPTP] Ragdoll Bypass: OFF")
end

-- ==================================================
-- SAVE / RESTORE STATS
-- ==================================================
local function SaveStats()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SavedWalkSpeed == nil then SavedWalkSpeed = Hum.WalkSpeed end
    if SavedJumpPower == nil then SavedJumpPower = Hum.JumpPower end
    if SavedJumpHeight == nil then SavedJumpHeight = Hum.JumpHeight end
    if SavedUseJumpPower == nil then SavedUseJumpPower = Hum.UseJumpPower end
end

local function RestoreStats()
    local Hum = GetHumanoid()
    if not Hum then return end

    if SavedWalkSpeed ~= nil then pcall(function() Hum.WalkSpeed = SavedWalkSpeed end) end
    if SavedJumpPower ~= nil then pcall(function() Hum.JumpPower = SavedJumpPower end) end
    if SavedJumpHeight ~= nil then pcall(function() Hum.JumpHeight = SavedJumpHeight end) end
    if SavedUseJumpPower ~= nil then pcall(function() Hum.UseJumpPower = SavedUseJumpPower end) end
end

-- ==================================================
-- CLEANUP
-- ==================================================
local function CleanupMovers()
    if FlyConnection then
        FlyConnection:Disconnect()
        FlyConnection = nil
    end
    if LockConnection then
        LockConnection:Disconnect()
        LockConnection = nil
    end
    if BodyVelocity then
        pcall(function()
            BodyVelocity.Velocity = Vector3.zero
            BodyVelocity.MaxForce = Vector3.zero
        end)
        BodyVelocity:Destroy()
        BodyVelocity = nil
    end
    if BodyGyro then
        pcall(function()
            BodyGyro.MaxTorque = Vector3.zero
        end)
        BodyGyro:Destroy()
        BodyGyro = nil
    end

    local Hum, Root = GetHumanoid()
    if Root then
        for _, Child in ipairs(Root:GetChildren()) do
            if Child.Name == "CruuzzBV" or Child.Name == "CruuzzBG" then
                pcall(function() Child:Destroy() end)
            end
        end
    end

    if Hum then
        pcall(function()
            Hum.PlatformStand = false
            Hum.Sit = false
        end)
    end

    if Root then
        pcall(function()
            Root.AssemblyLinearVelocity = Vector3.zero
            Root.AssemblyAngularVelocity = Vector3.zero
        end)
    end
end

-- ==================================================
-- LOCK AT TARGET
-- ==================================================
local function StartLock(TargetPosition, LockAbove)
    LockAbove = LockAbove or LOCK_ABOVE
    TargetLockedCFrame = CFrame.new(TargetPosition + Vector3.new(0, LockAbove, 0))

    if LockConnection then
        LockConnection:Disconnect()
    end

    LockConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            if LockConnection then LockConnection:Disconnect() LockConnection = nil end
            return
        end

        local Hum, Root = GetHumanoid()
        if not Root then return end

        Root.CFrame = TargetLockedCFrame
        Root.AssemblyLinearVelocity = Vector3.zero
        Root.AssemblyAngularVelocity = Vector3.zero
    end)
end

-- ==================================================
-- GET POSITION
-- ==================================================
local function GetPosition(Object)
    if not Object then return nil end
    if Object:IsA("Model") then
        if Object.PrimaryPart then return Object.PrimaryPart.Position end
        local Part = Object:FindFirstChildWhichIsA("BasePart")
        if Part then return Part.Position end
        for _, Desc in ipairs(Object:GetDescendants()) do
            if Desc:IsA("BasePart") then return Desc.Position end
        end
    elseif Object:IsA("BasePart") then
        return Object.Position
    end
    return nil
end

-- ==================================================
-- SEARCH FIRST EGGS
-- ==================================================
local function SearchFirstEggs()
    FirstEggList = {}
    if not Container then return end

    for _, Slot in ipairs(Container:GetChildren()) do
        if string.find(Slot.Name, SEARCH_PREFIX) then
            local SlotNum = string.match(Slot.Name, "Slot_(%d+)")
            if SlotNum then
                table.insert(FirstEggList, {
                    Slot = Slot,
                    Uid = Slot.Name,
                    SlotKey = "Forest:Slot_" .. SlotNum,
                    SlotNum = tonumber(SlotNum)
                })
            end
        end
    end
end

local function FindClosestEgg()
    local Hum, Root = GetHumanoid()
    if not Root then return nil end

    local Closest = nil
    local ClosestDistance = 9999

    for _, Egg in ipairs(FirstEggList) do
        local Pos = GetPosition(Egg.Slot)
        if Pos then
            local Dist = (Pos - Root.Position).Magnitude
            if Dist < ClosestDistance then
                ClosestDistance = Dist
                Closest = Egg
            end
        end
    end

    if Closest then
        FirstEggUid = Closest.Uid
        FirstEggSlotKey = Closest.SlotKey
    end

    return Closest
end

-- ==================================================
-- FLY TP
-- ==================================================
local function FlyTP(Destination, Speed, UseShotTP, IsSafeZone, Callback, LockAbove)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    LockAbove = LockAbove or LOCK_ABOVE
    local FlyPos = Vector3.new(Destination.X, Destination.Y + FLY_OFFSET, Destination.Z)
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, LockAbove, 0))

    Hum.PlatformStand = true

    BodyVelocity = Instance.new("BodyVelocity")
    BodyVelocity.Name = "CruuzzBV"
    BodyVelocity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    BodyVelocity.P = 1250
    BodyVelocity.Velocity = Vector3.zero
    BodyVelocity.Parent = Root

    BodyGyro = Instance.new("BodyGyro")
    BodyGyro.Name = "CruuzzBG"
    BodyGyro.MaxTorque = Vector3.new(math.huge, math.huge, math.huge)
    BodyGyro.P = 3000
    BodyGyro.D = 500
    BodyGyro.CFrame = Root.CFrame
    BodyGyro.Parent = Root

    local StartTime = tick()
    local ShotDone = false

    FlyConnection = RunService.Heartbeat:Connect(function()
        if not Running then
            CleanupMovers()
            return
        end

        local Hum2, Root2 = GetHumanoid()
        if not Hum2 or not Root2 then
            CleanupMovers()
            return
        end
        if Hum2.Health <= 0 then return end

        if not BodyVelocity or not BodyGyro then
            CleanupMovers()
            return
        end

        local CurrentPos = Root2.Position
        local Direction = (FlyPos - CurrentPos)
        local HorizDist = Vector3.new(Direction.X, 0, Direction.Z).Magnitude
        local VertDist = math.abs(Direction.Y)
        local TotalDist = Direction.Magnitude

        if IsSafeZone then
            if HorizDist <= SAFE_LOCK_DISTANCE then
                CleanupMovers()
                Root2.CFrame = LockCFrame
                Root2.AssemblyLinearVelocity = Vector3.zero
                Root2.AssemblyAngularVelocity = Vector3.zero
                StartLock(Destination, LockAbove)
                if Callback then Callback() end
                return
            end
        end

        if not IsSafeZone and UseShotTP and not ShotDone and HorizDist <= SHOT_DISTANCE then
            ShotDone = true
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination, LockAbove)
            if Callback then Callback() end
            return
        end

        if HorizDist <= ARRIVE_DISTANCE and VertDist <= 2 then
            CleanupMovers()
            Root2.CFrame = LockCFrame
            Root2.AssemblyLinearVelocity = Vector3.zero
            Root2.AssemblyAngularVelocity = Vector3.zero
            StartLock(Destination, LockAbove)
            if Callback then Callback() end
            return
        end

        if tick() - StartTime > TIMEOUT_SECONDS then
            CleanupMovers()
            if Callback then Callback() end
            return
        end

        if TotalDist > 1 then
            BodyVelocity.Velocity = Direction.Unit * Speed
        else
            BodyVelocity.Velocity = Vector3.zero
        end

        BodyGyro.CFrame = CFrame.new(CurrentPos, CurrentPos + Vector3.new(Direction.X, 0, Direction.Z))
    end)
end

-- ==================================================
-- INSTANT FLY TP
-- ==================================================
local function InstantFlyTP(Destination, Callback, LockAbove)
    CleanupMovers()

    local Hum, Root = GetHumanoid()
    if not Hum or not Root then return end
    if Hum.Health <= 0 then return end

    LockAbove = LockAbove or LOCK_ABOVE
    local LockCFrame = CFrame.new(Destination + Vector3.new(0, LockAbove, 0))

    Root.CFrame = LockCFrame
    Root.AssemblyLinearVelocity = Vector3.zero
    Root.AssemblyAngularVelocity = Vector3.zero

    StartLock(Destination, LockAbove)

    if Callback then Callback() end
end

-- ==================================================
-- ✅ TELEPORT TO TARGET WITH DISTANCE CHECK
-- ==================================================
local function TeleportToTargetWithDistanceCheck(TargetPos, Callback)
    local Hum, Root = GetHumanoid()
    if not Root then
        if Callback then Callback() end
        return
    end

    local Dist = (TargetPos - Root.Position).Magnitude
    print("[VIPTP] Target Distance: " .. math.floor(Dist))

    if Dist > DISTANCE_THRESHOLD then
        print("[VIPTP] Distance > 3000 → Instant TP")
        InstantFlyTP(TargetPos, Callback)
    else
        print("[VIPTP] Distance ≤ 3000 → FlyTP")
        FlyTP(TargetPos, FLY_SPEED, true, false, Callback)
    end
end

-- ==================================================
-- REMOTE COLLECT
-- ==================================================
local function RemoteCollectFirst()
    if not CollectEvent or not FirstEggSlotKey or not FirstEggUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            FirstAreaSlotKey = FirstEggSlotKey,
            Uid = FirstEggUid
        })
    end)
    return success
end

local function RemoteCollectTarget()
    if not CollectEvent or not TARGET_UID then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            Uid = TARGET_UID
        })
    end)
    return success
end

local function RemoteCollectAutoFlyBack()
    if not CollectEvent or not AutoFlyBackTargetUid then return false end
    local success = pcall(function()
        return CollectEvent:InvokeServer({
            Uid = AutoFlyBackTargetUid
        })
    end)
    return success
end

-- ==================================================
-- ✅ FIRE FOREST STRIKE (តែម្តងគត់)
-- ==================================================
local function FireForestStrike()
    if ForestStrikeFired then return end  -- ✅ ការពារ Fire ស្ទួន
    if not ForestStrike then return end

    ForestStrikeFired = true

    EnableRagdollBypass()

    pcall(function()
        ForestStrike:FireServer({
            EggUid = FirstEggUid,
            GuardCFrame = CFrame.new(LOCK_POSITION)
        })
    end)

    task.spawn(function()
        for i = 1, 10 do
            task.wait(0.05)
            ForceUp()
            CleanupRagdollConstraints()
        end
    end)

    print("[VIPTP] ForestStrike Fired (Once)")
end

-- ==================================================
-- CHECK EGG
-- ==================================================
local function IsFirstEggInWorkspace()
    if not FirstEggUid then return false end
    return workspace:FindFirstChild(FirstEggUid) ~= nil
end

local function IsFirstEggInContainer()
    if not FirstEggUid then return false end
    if not Container then return false end
    return Container:FindFirstChild(FirstEggUid) ~= nil
end

local function IsTargetInContainer()
    if not TARGET_UID or not Container then return false end
    return Container:FindFirstChild(TARGET_UID) ~= nil
end

local function IsTargetInWorkspace()
    if not TARGET_UID then return false end
    return workspace:FindFirstChild(TARGET_UID) ~= nil
end

-- ==================================================
-- ✅ GET PHASE (Day/Night)
-- ==================================================
local function GetPhase()
    local Success, Text = pcall(function()
        return Player.PlayerGui.HUD.GameHUD.BottomRight.NightTimer.Value.Text
    end)

    if Success and Text then
        local M = tonumber(string.match(Text, "(%d+)m")) or 0
        local S = tonumber(string.match(Text, "(%d+)s")) or 0
        local Sec = M * 60 + S
        if Sec > 10 then
            return "Day"
        else
            return "Night"
        end
    end

    return "UNKNOWN"
end

-- ==================================================
-- AUTO STOP
-- ==================================================
function AutoStop()
    if not Running then return end
    Running = false
    CurrentStep = "done"

    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    AutoFlyBackActive = false
    AutoFlyBackAttempts = 0
    SavedEggY = nil
    AutoFlyBackTargetUid = nil
    AutoFlyBackCheckStarted = false
    FlyToSafeZoneActive = false
    FlyToSafeZoneRequested = false
    ContainerCollectStartTime = nil

    print("[VIPTP] Auto Stop")

    if _G.Cruuzz_FarmingManager and _G.Cruuzz_FarmingManager.OnVIPTPComplete then
        task.spawn(function()
            task.wait(0.5)
            _G.Cruuzz_FarmingManager.OnVIPTPComplete()
        end)
    end
end

-- ==================================================
-- FLY TO SAFE
-- ==================================================
function FlyToSafeZone()
    if FlyToSafeZoneActive then return end
    if FlyToSafeZoneRequested then return end
    FlyToSafeZoneActive = true
    FlyToSafeZoneRequested = true

    CurrentStep = "to_safe"

    print("[VIPTP] FlyTP to Safe Zone")

    FlyTP(SAFE_ZONE, RETURN_SPEED, false, true, function()
        FlyToSafeZoneActive = false
        TargetCollected = true
        task.spawn(function()
            task.wait(0.5)
            AutoStop()
        end)
    end)
end

-- ==================================================
-- AUTO FLY BACK LOGIC
-- ==================================================
function StartAutoFlyBackTask()
    if AutoFlyBackActive then return end
    AutoFlyBackCheckStarted = false

    local EggInWS = workspace:FindFirstChild(TARGET_UID)
    if not EggInWS then
        print("[VIPTP] Auto Fly Back: Egg not in workspace!")
        return
    end

    local EggPos = GetPosition(EggInWS)
    if not EggPos then
        print("[VIPTP] Auto Fly Back: Cannot get Egg position!")
        return
    end

    print("[VIPTP] Auto Fly Back: Starting Task!")

    AutoFlyBackActive = true
    AutoFlyBackAttempts = AutoFlyBackAttempts + 1
    AutoFlyBackTargetUid = TARGET_UID

    FlyTP(EggPos, FLY_SPEED, true, false, function()
        print("[VIPTP] Auto Fly Back: Locked at Egg")

        task.spawn(function()
            local LastY = nil
            local StableCount = 0

            while AutoFlyBackActive and Running do
                task.wait(0.05)

                local EggInWS2 = workspace:FindFirstChild(TARGET_UID)
                if not EggInWS2 then
                    print("[VIPTP] Auto Fly Back: Egg gone → Done!")
                    AutoFlyBackActive = false
                    if Running then
                        FlyToSafeZone()
                    end
                    return
                end

                local EggPos2 = GetPosition(EggInWS2)
                if EggPos2 then
                    if LastY and math.abs(EggPos2.Y - LastY) < STABLE_Y_THRESHOLD then
                        StableCount = StableCount + 1
                        if StableCount >= STABLE_Y_REQUIRED then
                            SavedEggY = EggPos2.Y
                            print("[VIPTP] Auto Fly Back: Y Stable = " .. tostring(SavedEggY))
                            break
                        end
                    else
                        StableCount = 0
                    end
                    LastY = EggPos2.Y
                end
            end

            if not AutoFlyBackActive or not Running then return end

            print("[VIPTP] Auto Fly Back: Starting Auto Collect...")

            while AutoFlyBackActive and Running do
                task.wait(COLLECT_INTERVAL_AUTO_FLY_BACK)

                local EggInWS3 = workspace:FindFirstChild(TARGET_UID)
                if not EggInWS3 then
                    print("[VIPTP] Auto Fly Back: Egg gone → Done!")
                    AutoFlyBackActive = false
                    if Running then
                        FlyToSafeZone()
                    end
                    return
                end

                local EggPos3 = GetPosition(EggInWS3)
                if EggPos3 then
                    if SavedEggY and EggPos3.Y > SavedEggY + 0.1 then
                        print("[VIPTP] Auto Fly Back: Y Up! " .. tostring(SavedEggY) .. " → " .. tostring(EggPos3.Y) .. " → Done!")
                        AutoFlyBackActive = false
                        if Running then
                            FlyToSafeZone()
                        end
                        return
                    end

                    RemoteCollectAutoFlyBack()
                end
            end
        end)
    end, LOCK_ABOVE_AUTO_FLY_BACK)
end

-- ==================================================
-- FLY TO TARGET
-- ==================================================
local function StartFlyToTarget()
    if FlyTargetStarted then return end
    FlyTargetStarted = true

    CurrentStep = "to_target"

    local TargetPos = nil

    if CurrentMode == "spawn" then
        local TargetEgg = Container and Container:FindFirstChild(TARGET_UID)
        if TargetEgg then
            TargetPos = GetPosition(TargetEgg)
        end
    elseif CurrentMode == "workspace" then
        if SavedTargetPosition then
            TargetPos = SavedTargetPosition
        else
            local WSEgg = workspace:FindFirstChild(TARGET_UID)
            if WSEgg then
                TargetPos = GetPosition(WSEgg)
                SavedTargetPosition = TargetPos
            end
        end
    end

    if not TargetPos then
        AutoStop()
        return
    end

    -- ✅ ប្រើ Function ថ្មីដែល Check Distance
    TeleportToTargetWithDistanceCheck(TargetPos, function()
        CurrentStep = "collect_target"
    end)
end

-- ==================================================
-- HEARTBEAT
-- ==================================================
local function StartActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end

    ActiveHeartbeat = RunService.Heartbeat:Connect(function()
        if not Running then return end

        local Hum, Root = GetHumanoid()
        if not Hum or not Root then return end
        if Hum.Health <= 0 then return end

        -- ==================================================
        -- STEP: collect_first
        -- ==================================================
        if CurrentStep == "collect_first" and not CollectDone then
            -- ✅ ពេល First Egg ចូល workspace → Fire ForestStrike (តែម្តង)
            if IsFirstEggInWorkspace() then
                print("[VIPTP] First Egg in workspace → Fire ForestStrike (Once)")
                FireForestStrike()
                CurrentStep = "wait_spawn_back"
                return
            end

            -- ✅ Remote Collect First Egg
            if tick() - CollectTime > COLLECT_INTERVAL then
                CollectTime = tick()

                if IsFirstEggInContainer() then
                    RemoteCollectFirst()
                    CollectAttempts = CollectAttempts + 1
                else
                    -- ✅ First Egg ចូល Container វិញ → Stop ForestStrike
                    if FirstEggCollected then
                        print("[VIPTP] First Egg collected → Stop ForestStrike")
                        ForestStrikeFired = true  -- ✅ Stop ភ្លាម
                    end
                end
            end
        end

        -- ==================================================
        -- STEP: wait_spawn_back
        -- ==================================================
        if CurrentStep == "wait_spawn_back" and not FlyTargetStarted then
            -- ✅ ពេល First Egg ចូល Container វិញ → Stop ForestStrike → Fly to Target
            if IsFirstEggInContainer() then
                FirstEggCollected = true
                ForestStrikeFired = true  -- ✅ Stop ភ្លាម
                print("[VIPTP] First Egg back in Container → Stop ForestStrike → Fly to Target")
                task.spawn(function() StartFlyToTarget() end)
            end
        end

        -- ==================================================
        -- STEP: collect_target
        -- ==================================================
        if CurrentStep == "collect_target" and not TargetCollected then
            if CurrentMode == "spawn" then
                -- ✅ Step 1: Collect Target Egg ពី Container មុន
                local TargetInContainer = Container:FindFirstChild(TARGET_UID)
                if TargetInContainer then
                    if not ContainerCollectStartTime then
                        ContainerCollectStartTime = tick()
                    end

                    if tick() - CollectTime > COLLECT_INTERVAL then
                        CollectTime = tick()
                        RemoteCollectTarget()
                        CollectAttempts = CollectAttempts + 1
                    end

                    if tick() - ContainerCollectStartTime > ContainerCollectTimeout then
                        print("[VIPTP] Container Collect Timeout → Check workspace")
                        ContainerCollectStartTime = nil
                    end
                    return
                end

                -- ✅ Step 2: Egg ចូល workspace → Fly to Safe Zone ភ្លាម
                local EggInWS = workspace:FindFirstChild(TARGET_UID)
                if EggInWS and not AutoFlyBackCheckStarted and not AutoFlyBackActive then
                    AutoFlyBackCheckStarted = true
                    print("[VIPTP] Target Egg entered workspace → Fly to Safe Zone + Auto Check Distance")

                    -- ✅ Fly to Safe Zone ភ្លាម
                    task.spawn(function()
                        if Running then
                            FlyToSafeZone()
                        end
                    end)

                    -- ✅ Auto Check Distance
                    task.spawn(function()
                        while Running and not TargetCollected do
                            task.wait(COLLECT_INTERVAL_AUTO_FLY_BACK)

                            local EggNow = workspace:FindFirstChild(TARGET_UID)
                            if not EggNow then
                                print("[VIPTP] Egg gone from workspace → TargetCollected = true")
                                TargetCollected = true
                                AutoFlyBackCheckStarted = false
                                return
                            end

                            local EggPos = GetPosition(EggNow)
                            local Hum2, Root2 = GetHumanoid()
                            if EggPos and Root2 then
                                local Dist = (EggPos - Root2.Position).Magnitude

                                if Dist > AUTO_FLY_BACK_DISTANCE_THRESHOLD then
                                    print("[VIPTP] Distance > 6 (" .. math.floor(Dist) .. ") → Stop Fly + Auto Fly Back!")

                                    FlyToSafeZoneActive = false
                                    FlyToSafeZoneRequested = false
                                    CleanupMovers()

                                    StartAutoFlyBackTask()

                                    AutoFlyBackCheckStarted = false
                                    return
                                end
                            end
                        end
                        AutoFlyBackCheckStarted = false
                    end)
                end

                if AutoFlyBackActive then
                    return
                end

                if TargetCollected then
                    AutoStop()
                    return
                end

            elseif CurrentMode == "workspace" then
                if SavedTargetPosition then
                    local WSEgg = workspace:FindFirstChild(TARGET_UID)
                    if WSEgg then
                        local CurrentPos = GetPosition(WSEgg)
                        if CurrentPos then
                            local Dist = (CurrentPos - SavedTargetPosition).Magnitude
                            if Dist >= POSITION_THRESHOLD then
                                TargetCollected = true
                                task.spawn(function() FlyToSafeZone() end)
                                return
                            end
                        end
                    end
                end
            end
        end
    end)
end

local function StopActiveHeartbeat()
    if ActiveHeartbeat then
        ActiveHeartbeat:Disconnect()
        ActiveHeartbeat = nil
    end
end

-- ==================================================
-- MAIN PROCESS
-- ==================================================
local function StartProcess()
    Running = true
    CurrentStep = "search"

    CollectAttempts = 0
    CollectTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    ForestStrikeFired = false
    FirstEggCollected = false
    SavedTargetPosition = nil
    TargetLockedCFrame = nil

    AutoFlyBackActive = false
    AutoFlyBackAttempts = 0
    SavedEggY = nil
    AutoFlyBackTargetUid = nil
    AutoFlyBackCheckStarted = false
    FlyToSafeZoneActive = false
    FlyToSafeZoneRequested = false
    ContainerCollectStartTime = nil

    SaveStats()
    EnableRagdollBypass()

    -- ✅ Check Path Spawn (Container)
    if IsTargetInContainer() then
        CurrentMode = "spawn"
        print("[VIPTP] Target found in Container → spawn mode")
    elseif IsTargetInWorkspace() then
        CurrentMode = "workspace"
        local WSEgg = workspace:FindFirstChild(TARGET_UID)
        if WSEgg then
            SavedTargetPosition = GetPosition(WSEgg)
        end
        print("[VIPTP] Target found in Workspace → workspace mode")
    else
        local WaitTime = 0
        while Running and not IsTargetInContainer() and not IsTargetInWorkspace() do
            task.wait(0.5)
            WaitTime = WaitTime + 0.5
            if WaitTime > 60 then
                AutoStop()
                return
            end
        end

        if IsTargetInContainer() then
            CurrentMode = "spawn"
        elseif IsTargetInWorkspace() then
            CurrentMode = "workspace"
            local WSEgg = workspace:FindFirstChild(TARGET_UID)
            if WSEgg then
                SavedTargetPosition = GetPosition(WSEgg)
            end
        end
    end

    -- ✅ Check Day/Night
    local Phase = GetPhase()
    print("[VIPTP] Phase: " .. Phase)

    SearchFirstEggs()

    if #FirstEggList == 0 then
        AutoStop()
        return
    end

    local Closest = FindClosestEgg()

    if not Closest then
        AutoStop()
        return
    end

    local EggPos = GetPosition(Closest.Slot)
    if not EggPos then
        AutoStop()
        return
    end

    CurrentStep = "fly_first"

    StartActiveHeartbeat()

    -- ✅ Fly to First Egg
    print("[VIPTP] FlyTP to First Egg")
    FlyTP(EggPos, FLY_SPEED, true, false, function()
        CurrentStep = "collect_first"
    end)
end

-- ==================================================
-- FULL RESET
-- ==================================================
local function FullReset()
    Running = false
    CurrentStep = "idle"
    CurrentMode = "none"

    FirstEggList = {}
    FirstEggUid = nil
    FirstEggSlotKey = nil
    CollectAttempts = 0
    CollectTime = 0
    FlyTargetStarted = false
    CollectDone = false
    TargetCollected = false
    ForestStrikeFired = false
    FirstEggCollected = false
    SavedTargetPosition = nil
    TargetLockedCFrame = nil

    AutoFlyBackActive = false
    AutoFlyBackAttempts = 0
    SavedEggY = nil
    AutoFlyBackTargetUid = nil
    AutoFlyBackCheckStarted = false
    FlyToSafeZoneActive = false
    FlyToSafeZoneRequested = false
    ContainerCollectStartTime = nil

    CleanupMovers()
    DisableRagdollBypass()
    StopActiveHeartbeat()
    RestoreStats()

    print("[VIPTP] Full Reset")
end

-- ==================================================
-- ENABLE / DISABLE / SET
-- ==================================================
local function Enable()
    if Running then return end
    if not CollectEvent then warn("[VIPTP] CollectEvent not found") return end
    if not TARGET_UID then warn("[VIPTP] No Target ID") return end

    FullReset()
    StartProcess()

    print("[VIPTP] ON | Target: " .. tostring(TARGET_UID))
end

local function Disable()
    FullReset()
    print("[VIPTP] OFF")
end

local function SetTargetId(Id)
    TARGET_UID = Id
    print("[VIPTP] Target ID: " .. tostring(Id))
end

-- ==================================================
-- EXPORT
-- ==================================================
_G.Cruuzz_VIPTP = {
    Enable = Enable,
    Disable = Disable,
    SetTargetId = SetTargetId,
    IsEnabled = function() return Running end,
    GetTargetId = function() return TARGET_UID end,
    GetMode = function() return CurrentMode end,
    IsAutoFlyBackActive = function() return AutoFlyBackActive end,
    GetPhase = GetPhase,
    FLY_SPEED = FLY_SPEED,
    RETURN_SPEED = RETURN_SPEED,
    FLY_OFFSET = FLY_OFFSET,
    SAFE_ZONE = SAFE_ZONE,
    DISTANCE_THRESHOLD = DISTANCE_THRESHOLD,
}


print("✅ VIPTP Loaded (AFK Farm Only | Auto Method | ForestStrike Once | No Limit)")
