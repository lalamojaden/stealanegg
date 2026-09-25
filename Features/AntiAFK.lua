-- ==================================================
-- Jaden HUB | FEATURE | Anti AFK (Integrated & Cleaned)
-- ==================================================

local Players = game:GetService("Players")

local Player = Players.LocalPlayer

-- ==================================================
-- SETTINGS
-- ==================================================

local MOUSE_INTERVAL_MIN = 45
local MOUSE_INTERVAL_MAX = 120

local CAMERA_INTERVAL_MIN = 60
local CAMERA_INTERVAL_MAX = 180

local ZOOM_INTERVAL_MIN = 90
local ZOOM_INTERVAL_MAX = 240

-- ==================================================
-- STATE
-- ==================================================

local AntiAFKEnabled = false
local MouseThread = nil
local CameraThread = nil
local ZoomThread = nil

-- ==================================================
-- METHOD 1: MOUSE MOVE
-- ==================================================

local function DoMouseMove()
    pcall(function()
        if mousemoverel then
            mousemoverel(math.random(-15, 15), math.random(-15, 15))
        end
    end)
end

-- ==================================================
-- METHOD 2: CAMERA ROTATION
-- ==================================================

local function DoCameraRotation()
    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            Camera.CFrame = Camera.CFrame * CFrame.Angles(
                math.rad(math.random(-2, 2)),
                math.rad(math.random(-3, 3)),
                0
            )
        end
    end)
end

-- ==================================================
-- METHOD 3: CAMERA ZOOM
-- ==================================================

local function DoCameraZoom()
    pcall(function()
        local Camera = workspace.CurrentCamera
        if Camera then
            local Original = Camera.FieldOfView
            Camera.FieldOfView = Original + math.random(-5, 5)
            task.wait(0.3)
            Camera.FieldOfView = Original
        end
    end)
end

-- ==================================================
-- ENABLE / DISABLE
-- ==================================================

local function EnableAntiAFK()
    if AntiAFKEnabled then return end
    AntiAFKEnabled = true

    -- ✅ Method 1: Mouse Move
    MouseThread = task.spawn(function()
        while AntiAFKEnabled do
            local WaitTime = math.random(MOUSE_INTERVAL_MIN, MOUSE_INTERVAL_MAX)
            task.wait(WaitTime)
            if not AntiAFKEnabled then break end
            DoMouseMove()
            print("[Jaden] Anti AFK: Mouse Move")
        end
    end)

    -- ✅ Method 2: Camera Rotation
    CameraThread = task.spawn(function()
        while AntiAFKEnabled do
            local WaitTime = math.random(CAMERA_INTERVAL_MIN, CAMERA_INTERVAL_MAX)
            task.wait(WaitTime)
            if not AntiAFKEnabled then break end
            DoCameraRotation()
            print("[Jaden] Anti AFK: Camera Rotation")
        end
    end)

    -- ✅ Method 3: Camera Zoom
    ZoomThread = task.spawn(function()
        while AntiAFKEnabled do
            local WaitTime = math.random(ZOOM_INTERVAL_MIN, ZOOM_INTERVAL_MAX)
            task.wait(WaitTime)
            if not AntiAFKEnabled then break end
            DoCameraZoom()
            print("[Jaden] Anti AFK: Camera Zoom")
        end
    end)

    print("[Jaden] Anti AFK: ON (3 Methods)")
end

local function DisableAntiAFK()
    if not AntiAFKEnabled then return end
    AntiAFKEnabled = false

    if MouseThread then
        pcall(function() task.cancel(MouseThread) end)
        MouseThread = nil
    end
    if CameraThread then
        pcall(function() task.cancel(CameraThread) end)
        CameraThread = nil
    end
    if ZoomThread then
        pcall(function() task.cancel(ZoomThread) end)
        ZoomThread = nil
    end

    print("[Jaden] Anti AFK: OFF")
end

local function ToggleAntiAFK()
    if AntiAFKEnabled then
        DisableAntiAFK()
    else
        EnableAntiAFK()
    end
end

-- ==================================================
-- EXPORT
-- ==================================================

_G.Jaden_AntiAFK = {
    Enable = EnableAntiAFK,
    Disable = DisableAntiAFK,
    Toggle = ToggleAntiAFK,
    IsEnabled = function() return AntiAFKEnabled end,

    -- ✅ Settings
    MOUSE_INTERVAL_MIN = MOUSE_INTERVAL_MIN,
    MOUSE_INTERVAL_MAX = MOUSE_INTERVAL_MAX,
    CAMERA_INTERVAL_MIN = CAMERA_INTERVAL_MIN,
    CAMERA_INTERVAL_MAX = CAMERA_INTERVAL_MAX,
    ZOOM_INTERVAL_MIN = ZOOM_INTERVAL_MIN,
    ZOOM_INTERVAL_MAX = ZOOM_INTERVAL_MAX
}

print("✅ AntiAFK Feature Loaded & Synced with Jaden Hub")
