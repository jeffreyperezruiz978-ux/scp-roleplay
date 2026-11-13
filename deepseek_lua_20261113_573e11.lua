--[[═══════════════════════════════════════════════════════════════
      SCP ROLEPLAY HUB v8.4  |  CUSTOM UI (No Rayfield)
      · Sin dependencias de Rayfield (funciona en Xeno/Solara/Wave)
      · Aimbot anti-vibración (deadzone, head filter, maxrot)
      · Key System propio
   ═══════════════════════════════════════════════════════════════]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local VirtualUser      = game:GetService("VirtualUser")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if game.PlaceId ~= 5041144419 then
    LocalPlayer:Kick("Este hub es exclusivo de SCP Roleplay.")
    return
end

local CoreGui = game:GetService("CoreGui")
local ParentGui = (typeof(gethui) == "function" and gethui()) or CoreGui

--═══════════════════════════════════════════════════════════════
-- KEY SYSTEM (Propio)
--═══════════════════════════════════════════════════════════════
local CONFIG_FILE = "SCPHub_Config.json"
local VALID_KEY = "20112026"

local function isKeySaved()
    if isfile and isfile("SCPHub_Key.txt") then
        local saved = readfile("SCPHub_Key.txt")
        return saved == VALID_KEY
    end
    return false
end

if not isKeySaved() then
    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "HubKeyGui"
    keyGui.Parent = ParentGui
    keyGui.IgnoreGuiInset = true

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 300, 0, 180)
    bg.Position = UDim2.new(0.5, -150, 0.5, -90)
    bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    bg.BorderSizePixel = 0
    bg.Parent = keyGui
    
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 8)
    corner.Parent = bg

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, 0, 0, 40)
    title.BackgroundTransparency = 1
    title.Text = "SCP Hub · Key System"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 16
    title.Parent = bg

    local box = Instance.new("TextBox")
    box.Size = UDim2.new(1, -40, 0, 35)
    box.Position = UDim2.new(0, 20, 0, 50)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.PlaceholderText = "Introduce la clave..."
    box.Font = Enum.Font.Gotham
    box.TextSize = 14
    box.Parent = bg
    
    local boxCorner = Instance.new("UICorner")
    boxCorner.CornerRadius = UDim.new(0, 6)
    boxCorner.Parent = box

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -40, 0, 35)
    btn.Position = UDim2.new(0, 20, 0, 100)
    btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    btn.Text = "Acceder"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = bg
    
    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(0, 6)
    btnCorner.Parent = btn

    box.FocusLost:Connect(function()
        if box.Text == VALID_KEY then
            pcall(function() writefile("SCPHub_Key.txt", VALID_KEY) end)
            keyGui:Destroy()
            loadHub()
        else
            box.Text = ""
            box.PlaceholderText = "Clave incorrecta"
            box.PlaceholderColor3 = Color3.fromRGB(255, 50, 50)
        end
    end)
    return
end

--═══════════════════════════════════════════════════════════════
-- HUB PRINCIPAL
--═══════════════════════════════════════════════════════════════
function loadHub()
    local State = {
        -- Aimbot
        Aimbot = false,
        AimbotRMB = false,
        LockMode = "CFrame",
        LockPart = "Head",
        AimSmooth = 30,
        AimDeadzone = 0.5,
        AimMaxRotPerFrame = 8,
        AimMaxDist = 5000,
        RequireWeapon = false,
        ForceScriptable = false,
        FOV = 600,
        FOVVisible = true,
        FOVFollowMouse = false,
        FOVColor = Color3.fromRGB(255, 255, 255),
        TargetPriority = "Cercano al crosshair",
        TargetIndicator = true,
        WallDetect = false,
        IgnoreTeam = false,
        SCPFriendly = false,
        ShieldMode = "Ignorar",
        -- Visual
        ESP = false,
        ESPColorMode = "Equipo del juego",
        ESPColor = Color3.fromRGB(255, 255, 255),
        ESPName = true,
        ESPDist = true,
        ESPHealth = true,
        ESPTracers = false,
        ESPMaxDist = 2000,
        Fullbright = false,
    }

    local parentGui = Instance.new("ScreenGui")
    parentGui.Name = "SCPHubUI"
    parentGui.Parent = ParentGui
    parentGui.IgnoreGuiInset = true

    -- ─────────────────────────────────────────────────────────────
    -- UI ENGINE (Pure Roblox GUI)
    -- ─────────────────────────────────────────────────────────────
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 500, 0, 350)
    Main.Position = UDim2.new(0.5, -250, 0.5, -175)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.BorderSizePixel = 0
    Main.Active = true
    Main.Parent = parentGui
    local mc = Instance.new("UICorner"); mc.CornerRadius = UDim.new(0, 8); mc.Parent = Main

    -- Draggable
    local dragBar = Instance.new("Frame")
    dragBar.Size = UDim2.new(1, 0, 0, 30)
    dragBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    dragBar.Parent = Main
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(0, 8); dc.Parent = dragBar
    
    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SCP Hub v8.4 (Custom)"
    title.TextColor3 = Color3.fromRGB(255, 255, 255)
    title.Font = Enum.Font.GothamBold
    title.TextSize = 14
    title.TextXAlignment = Enum.TextXAlignment.Left
    title.Parent = dragBar

    local close = Instance.new("TextButton")
    close.Size = UDim2.new(0, 30, 0, 30)
    close.Position = UDim2.new(1, -30, 0, 0)
    close.BackgroundTransparency = 1
    close.Text = "X"
    close.TextColor3 = Color3.fromRGB(255, 100, 100)
    close.Font = Enum.Font.GothamBold
    close.Parent = dragBar
    close.MouseButton1Click:Connect(function() parentGui:Destroy() end)

    -- Dragging logic
    local dragging, dragInput, dragStart, startPos
    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = Main.Position
            input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragging = false end end)
        end
    end)
    dragBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then dragInput = input end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            Main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    -- Tabs
    local tabBar = Instance.new("Frame")
    tabBar.Size = UDim2.new(0, 120, 1, -30)
    tabBar.Position = UDim2.new(0, 0, 0, 30)
    tabBar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    tabBar.Parent = Main

    local content = Instance.new("Frame")
    content.Size = UDim2.new(1, -120, 1, -30)
    content.Position = UDim2.new(0, 120, 0, 30)
    content.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    content.Parent = Main

    local function createTab(name)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 35)
        btn.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
        btn.Text = "  " .. name
        btn.TextColor3 = Color3.fromRGB(200, 200, 200)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = tabBar
        
        local page = Instance.new("ScrollingFrame")
        page.Size = UDim2.new(1, 0, 1, 0)
        page.BackgroundTransparency = 1
        page.BorderSizePixel = 0
        page.ScrollBarThickness = 2
        page.Visible = false
        page.Parent = content

        local layout = Instance.new("UIListLayout")
        layout.Padding = UDim.new(0, 6)
        layout.SortOrder = Enum.SortOrder.LayoutOrder
        layout.Parent = page
        
        local pad = Instance.new("UIPadding")
        pad.PaddingTop = UDim.new(0, 10); pad.PaddingLeft = UDim.new(0, 10); pad.PaddingRight = UDim.new(0, 10)
        pad.Parent = page

        btn.MouseButton1Click:Connect(function()
            for _, c in ipairs(tabBar:GetChildren()) do
                if c:IsA("TextButton") then c.TextColor3 = Color3.fromRGB(200, 200, 200) end
            end
            for _, c in ipairs(content:GetChildren()) do
                if c:IsA("ScrollingFrame") then c.Visible = false end
            end
            btn.TextColor3 = Color3.fromRGB(0, 170, 255)
            page.Visible = true
        end)
        return page, btn
    end

    local function toggle(parent, text, default, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.Text = "  [ " .. (default and "X" or " ") .. " ]  " .. text
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = "  [ " .. (state and "X" or " ") .. " ]  " .. text
            callback(state)
        end)
        return { Set = function(_, val) state = val; btn.Text = "  [ " .. (state and "X" or " ") .. " ]  " .. text end }
    end

    local function slider(parent, text, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        frame.Parent = parent
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = frame

        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(1, -10, 0, 20)
        label.Position = UDim2.new(0, 5, 0, 2)
        label.BackgroundTransparency = 1
        label.Text = "  " .. text .. ": " .. default
        label.TextColor3 = Color3.fromRGB(220, 220, 220)
        label.Font = Enum.Font.Gotham
        label.TextSize = 13
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.Parent = frame

        local bar = Instance.new("Frame")
        bar.Size = UDim2.new(1, -20, 0, 6)
        bar.Position = UDim2.new(0, 10, 0, 25)
        bar.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        bar.Parent = frame
        local bc = Instance.new("UICorner"); bc.CornerRadius = UDim.new(1, 0); bc.Parent = bar

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        fill.Parent = bar
        local fc = Instance.new("UICorner"); fc.CornerRadius = UDim.new(1, 0); fc.Parent = fill

        local dragging, val = false, default
        local function update(input)
            local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            val = math.floor(min + (max - min) * pos)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            label.Text = "  " .. text .. ": " .. val
            callback(val)
        end
        bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; update(i) end end)
        UserInputService.InputChanged:Connect(function(i) if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then update(i) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end end)
        return { Set = function(_, v) val = v; local pos = (v - min) / (max - min); fill.Size = UDim2.new(pos, 0, 1, 0); label.Text = "  " .. text .. ": " .. v end }
    end

    local function cycle(parent, text, options, defaultIdx, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.Text = "  " .. text .. ": " .. options[defaultIdx]
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
        local idx = defaultIdx
        btn.MouseButton1Click:Connect(function()
            idx = idx + 1; if idx > #options then idx = 1 end
            btn.Text = "  " .. text .. ": " .. options[idx]
            callback(options[idx])
        end)
        return { Set = function(_, v) for i, o in ipairs(options) do if o == v then idx = i; btn.Text = "  " .. text .. ": " .. o; break end end } }
    end

    -- Tabs creation
    local Combat, btnCombat = createTab("Combat")
    local Visual, btnVisual = createTab("Visual")
    local Config, btnConfig = createTab("Config")
    btnCombat:Fire("MouseButton1Click") -- Open first tab

    -- Notify system
    local function notify(t, c)
        local n = Instance.new("Frame")
        n.Size = UDim2.new(0, 250, 0, 50)
        n.Position = UDim2.new(1, -260, 1, -60)
        n.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
        n.Parent = parentGui
        local nc = Instance.new("UICorner"); nc.CornerRadius = UDim.new(0, 6); nc.Parent = n
        
        local title = Instance.new("TextLabel")
        title.Size = UDim2.new(1, -10, 0, 20); title.Position = UDim2.new(0, 5, 0, 5)
        title.BackgroundTransparency = 1; title.Text = t
        title.TextColor3 = Color3.fromRGB(0, 170, 255); title.Font = Enum.Font.GothamBold
        title.TextSize = 13; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = n

        local desc = Instance.new("TextLabel")
        desc.Size = UDim2.new(1, -10, 0, 20); desc.Position = UDim2.new(0, 5, 0, 25)
        desc.BackgroundTransparency = 1; desc.Text = c
        desc.TextColor3 = Color3.fromRGB(200, 200, 200); desc.Font = Enum.Font.Gotham
        desc.TextSize = 11; desc.TextXAlignment = Enum.TextXAlignment.Left; desc.Parent = n

        task.spawn(function()
            task.wait(3)
            TweenService:Create(n, TweenInfo.new(0.5), {BackgroundTransparency = 1}):Play()
            title:Destroy(); desc:Destroy()
            task.wait(0.5); n:Destroy()
        end)
    end

    -- ─────────────────────────────────────────────────────────────
    -- AIMBOT & GAME LOGIC (Copiado de v8.3)
    -- ─────────────────────────────────────────────────────────────
    local aimState = {
        target = nil, locked = false, frameCount = 0, noTargetPrint = 0,
        coasting = false, lastAngle = 999,
        stableHeadPos = nil, stableHeadAt = 0, lastTargetName = nil,
        originalCameraType = nil,
    }
    local STABILITY = { headFilterRate = 15, headMoveSnap = 1.0, headNoiseIgnore = 0.3, deadzoneEnter = 0.5, deadzoneExit = 2.0, maxRotPerFrame = 8 }

    local function isLocalAlive()
        local char = LocalPlayer.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
        return true
    end
    local function isTargetAlive(plr)
        if not plr or plr.Parent == nil then return false end
        local char = plr.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        if not hum or hum.Health <= 0 then return false end
        if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
        return true
    end
    local function isAlly(plr)
        if not plr or plr == LocalPlayer then return true end
        if LocalPlayer.Team ~= nil and plr.Team ~= nil then return LocalPlayer.Team == plr.Team end
        return false
    end
    local NON_WEAPON = { "shield","riot","ballistic","escutcheon","escudo","barrier","radio","keycard","key card","medkit","bandage","handcuff" }
    local function hasWeaponEquipped()
        local char = LocalPlayer.Character
        if not char then return false end
        for _, tool in ipairs(char:GetChildren()) do
            if tool:IsA("Tool") then
                local l = string.lower(tool.Name)
                local isWeap = true
                for _, pat in ipairs(NON_WEAPON) do if l:find(pat, 1, true) then isWeap = false break end end
                if isWeap and tool:FindFirstChild("Handle") then return true end
            end
        end
        return false
    end

    local function getStableHeadPos(target, dt)
        if not target or not target.head then return nil end
        local rawPos = target.head.Position
        local now = os.clock()
        local targetName = target.plr.Name
        if aimState.lastTargetName ~= targetName then
            aimState.lastTargetName = targetName; aimState.stableHeadPos = rawPos; aimState.stableHeadAt = now
            aimState.coasting = false; aimState.lastAngle = 999; return rawPos
        end
        if not aimState.stableHeadPos then aimState.stableHeadPos = rawPos; aimState.stableHeadAt = now; return rawPos end
        local delta = (rawPos - aimState.stableHeadPos).Magnitude
        if delta > STABILITY.headMoveSnap then aimState.stableHeadPos = rawPos; aimState.stableHeadAt = now; return rawPos end
        if delta < STABILITY.headNoiseIgnore and (now - aimState.stableHeadAt) < 0.5 then return aimState.stableHeadPos end
        local alpha = math.clamp(dt * STABILITY.headFilterRate, 0.08, 0.5)
        aimState.stableHeadPos = aimState.stableHeadPos:Lerp(rawPos, alpha)
        aimState.stableHeadAt = now
        return aimState.stableHeadPos
    end

    local function getLockPosition(plr)
        local char = plr.Character; if not char then return nil end
        local part = char:FindFirstChild(State.LockPart) or char:FindFirstChild("Head")
        return part and part.Position or nil
    end

    local function findClosestPlayer(cam)
        local fovCenter = State.FOVFollowMouse and UserInputService:GetMouseLocation() or Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local camPos = cam.CFrame.Position
        local best, bestScore = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and plr.Character then
                local head = plr.Character:FindFirstChild("Head")
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                    if not (State.IgnoreTeam and isAlly(plr)) then
                        local lockPos = getLockPosition(plr)
                        if lockPos then
                            local wd = (lockPos - camPos).Magnitude
                            if wd <= State.AimMaxDist then
                                local pos = cam:WorldToViewportPoint(lockPos)
                                if pos.Z > 0 then
                                    local sd = (Vector2.new(pos.X, pos.Y) - fovCenter).Magnitude
                                    if sd <= State.FOV then
                                        local score = (State.TargetPriority == "Menos HP" and hum.Health)
                                            or (State.TargetPriority == "Más cercano en studs" and wd)
                                            or sd
                                        if score < bestScore then
                                            best = { plr = plr, head = head, hum = hum, lockPos = lockPos, score = score }
                                            bestScore = score
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
        return best
    end

    local function aimStep(dt)
        dt = dt or 0.016
        aimState.frameCount = aimState.frameCount + 1
        if not State.Aimbot then return end
        if not isLocalAlive() then if aimState.locked then aimState.locked = false end; return end
        if State.RequireWeapon and not hasWeaponEquipped() then if aimState.locked then aimState.locked = false end; return end
        if State.AimbotRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            if aimState.locked then aimState.locked = false end; return
        end

        local cam = workspace.CurrentCamera; if not cam then return end
        if not aimState.originalCameraType then aimState.originalCameraType = cam.CameraType end
        if State.ForceScriptable and cam.CameraType ~= Enum.CameraType.Scriptable then
            pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
        end

        local target = findClosestPlayer(cam)
        if not target then
            aimState.locked = false
            return
        end

        if aimState.target ~= target.plr then
            aimState.target = target.plr
            aimState.stableHeadPos = nil; aimState.lastTargetName = nil; aimState.lastAngle = 999
            notify("Aimbot", "Target: " .. target.plr.Name)
        end
        aimState.locked = true

        local aimPos = getStableHeadPos(target, dt); if not aimPos then return end
        local camPos = cam.CFrame.Position
        local delta = aimPos - camPos
        if delta.Magnitude < 0.3 then return end

        local dot = math.clamp(cam.CFrame.LookVector:Dot(delta.Unit), -1, 1)
        local angleRad = math.acos(dot); local angleDeg = math.deg(angleRad)
        local dzEnter = State.AimDeadzone or 0.5
        local dzExit = dzEnter * 4

        if aimState.coasting then if angleDeg > dzExit then aimState.coasting = false end
        else if angleDeg < dzEnter then aimState.coasting = true end end
        if aimState.coasting then return end

        local smooth = State.AimSmooth or 30
        local baseAlpha = math.clamp(0.9 - (smooth / 100) * 0.8, 0.1, 0.9)
        local angleFactor = angleDeg < 5 and math.max(0.15, angleDeg / 5) or (angleDeg < 15 and 0.5 + (angleDeg - 5) / 20 or 1.0)
        local finalAlpha = math.clamp(baseAlpha * angleFactor, 0.02, 0.9)
        
        local maxRot = math.rad(State.AimMaxRotPerFrame or 8)
        if angleRad > maxRot then finalAlpha = math.min(finalAlpha, maxRot / angleRad) end

        if State.LockMode == "mousemoverel" then
            local screenPos = cam:WorldToViewportPoint(aimPos)
            if screenPos.Z > 0 then
                local mouse = UserInputService:GetMouseLocation()
                pcall(function() mousemoverel((screenPos.X - mouse.X) * finalAlpha, (screenPos.Y - mouse.Y) * finalAlpha) end)
            end
        elseif State.LockMode == "mousemoveabs" then
            local screenPos = cam:WorldToViewportPoint(aimPos)
            if screenPos.Z > 0 and mousemoveabs then pcall(function() mousemoveabs(screenPos.X, screenPos.Y) end) end
        else
            pcall(function() cam.CFrame = cam.CFrame:Lerp(CFrame.new(camPos, aimPos), finalAlpha) end)
        end
        aimState.lastAngle = angleDeg
    end

    local function setAimbotBinding()
        pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)
        aimState.locked = false; aimState.target = nil; aimState.stableHeadPos = nil
        if State.Aimbot then
            local okBind = pcall(function() RunService:BindToRenderStep("HubAimbotStep", Enum.RenderPriority.Last.Value - 1, aimStep) end)
            if not okBind then addConn("AimbotStep", RunService.RenderStepped:Connect(aimStep)) end
        end
    end

    -- FOV Circle
    local fovGui = Instance.new("ScreenGui")
    fovGui.Name = "HubFOVCircle"; fovGui.IgnoreGuiInset = true; fovGui.ResetOnSpawn = false; fovGui.Parent = ParentGui
    local fovRing = Instance.new("Frame"); fovRing.AnchorPoint = Vector2.new(0.5, 0.5); fovRing.BackgroundTransparency = 1; fovRing.BorderSizePixel = 0; fovRing.Parent = fovGui
    local fovStroke = Instance.new("UIStroke"); fovStroke.Thickness = 1.5; fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border; fovStroke.Color = State.FOVColor; fovStroke.Parent = fovRing
    local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1, 0); cr.Parent = fovRing

    RunService.RenderStepped:Connect(function()
        if not State.Aimbot or not State.FOVVisible then fovGui.Enabled = false; return end
        fovGui.Enabled = true
        local cam = workspace.CurrentCamera
        if not cam then return end
        local center = State.FOVFollowMouse and UserInputService:GetMouseLocation() or Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        fovRing.Position = UDim2.fromOffset(center.X, center.Y)
        fovRing.Size = UDim2.fromOffset(State.FOV * 2, State.FOV * 2)
        fovStroke.Color = aimState.coasting and Color3.fromRGB(100, 255, 100) or (aimState.locked and Color3.fromRGB(255, 150, 150) or State.FOVColor)
    end)

    -- ─────────────────────────────────────────────────────────────
    -- UI POPULATION
    -- ─────────────────────────────────────────────────────────────
    toggle(Combat, "Aimbot", State.Aimbot, function(v) State.Aimbot = v; setAimbotBinding() end)
    toggle(Combat, "Solo con clic derecho", State.AimbotRMB, function(v) State.AimbotRMB = v end)
    toggle(Combat, "Gun check (solo con arma)", State.RequireWeapon, function(v) State.RequireWeapon = v end)
    toggle(Combat, "Forzar Scriptable", State.ForceScriptable, function(v) State.ForceScriptable = v end)
    cycle(Combat, "Modo de lock", {"CFrame", "mousemoverel", "mousemoveabs"}, 1, function(v) State.LockMode = v end)
    cycle(Combat, "LockPart", {"Head", "UpperTorso", "HumanoidRootPart"}, 1, function(v) State.LockPart = v end)
    slider(Combat, "Suavidad", 0, 100, State.AimSmooth, function(v) State.AimSmooth = v end)
    slider(Combat, "Tolerancia (°)", 0.1, 5, State.AimDeadzone, function(v) State.AimDeadzone = v end)
    slider(Combat, "Velocidad máx (°/frame)", 2, 30, State.AimMaxRotPerFrame, function(v) State.AimMaxRotPerFrame = v end)
    slider(Combat, "Distancia máx", 50, 5000, State.AimMaxDist, function(v) State.AimMaxDist = v end)
    slider(Combat, "FOV (radio px)", 10, 800, State.FOV, function(v) State.FOV = v end)
    toggle(Combat, "Mostrar FOV", State.FOVVisible, function(v) State.FOVVisible = v end)
    toggle(Combat, "FOV sigue al mouse", State.FOVFollowMouse, function(v) State.FOVFollowMouse = v end)
    cycle(Combat, "Prioridad", {"Cercano al crosshair", "Menos HP", "Más cercano en studs"}, 1, function(v) State.TargetPriority = v end)
    toggle(Combat, "Ignorar aliados", State.IgnoreTeam, function(v) State.IgnoreTeam = v end)

    toggle(Visual, "ESP", State.ESP, function(v) State.ESP = v end)
    toggle(Visual, "ESP Nombre", State.ESPName, function(v) State.ESPName = v end)
    toggle(Visual, "ESP Distancia", State.ESPDist, function(v) State.ESPDist = v end)
    toggle(Visual, "ESP Salud", State.ESPHealth, function(v) State.ESPHealth = v end)
    toggle(Visual, "ESP Tracers", State.ESPTracers, function(v) State.ESPTracers = v end)
    slider(Visual, "ESP Dist máx", 200, 5000, State.ESPMaxDist, function(v) State.ESPMaxDist = v end)
    toggle(Visual, "Fullbright", State.Fullbright, function(v) State.Fullbright = v end)

    local function clearHub()
        pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)
        parentGui:Destroy()
        fovGui:Destroy()
        notify("Hub", "Hub descargado correctamente.")
    end
    Config:CreateButton ... -- Wait, custom UI needs button creation

    local function button(parent, text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        btn.Text = "  " .. text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.Parent = parent
        local c = Instance.new("UICorner"); c.CornerRadius = UDim.new(0, 4); c.Parent = btn
        btn.MouseButton1Click:Connect(callback)
        return btn
    end

    button(Config, "Descargar Hub", clearHub)
    button(Config, "Borrar Key Guardada", function()
        pcall(function() if delfile then delfile("SCPHub_Key.txt") end end)
        notify("Config", "Key borrada. Reinicia el juego para volver a pedirla.")
    end)

    -- Keybind Aimbot
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.X then
            State.Aimbot = not State.Aimbot
            setAimbotBinding()
            notify("Keybind", "Aimbot: " .. (State.Aimbot and "ON" or "OFF"))
        end
    end)
end

-- Call load if key is saved
if isKeySaved() then
    loadHub()
end