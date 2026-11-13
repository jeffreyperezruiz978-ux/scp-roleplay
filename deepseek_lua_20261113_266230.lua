--[[═══════════════════════════════════════════════════════════════
      SCP ROLEPLAY HUB v8.5  |  CUSTOM UI (PlayerGui - 100% Safe)
      · Sin CoreGui (evita el error de Locales de tu executor)
      · Aimbot anti-vibración (deadzone, head filter, maxrot)
      · Key System propio (20112026)
   ═══════════════════════════════════════════════════════════════]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TweenService     = game:GetService("TweenService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
if game.PlaceId ~= 5041144419 then
    LocalPlayer:Kick("Este hub es exclusivo de SCP Roleplay.")
    return
end

-- Usar PlayerGui para evitar errores de CoreGui en ejecutores restrictivos
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

--═══════════════════════════════════════════════════════════════
-- KEY SYSTEM
--═══════════════════════════════════════════════════════════════
local VALID_KEY = "20112026"

local function checkKey()
    if isfile and isfile("SCPHub_Key.txt") then
        return readfile("SCPHub_Key.txt") == VALID_KEY
    end
    return false
end

local function showKeyGui()
    local keyGui = Instance.new("ScreenGui")
    keyGui.Name = "HubKeyGui"
    keyGui.Parent = PlayerGui
    keyGui.IgnoreGuiInset = true

    local bg = Instance.new("Frame")
    bg.Size = UDim2.new(0, 300, 0, 180)
    bg.Position = UDim2.new(0.5, -150, 0.5, -90)
    bg.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    bg.Parent = keyGui
    Instance.new("UICorner", bg).CornerRadius = UDim.new(0, 8)

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
    Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)

    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -40, 0, 35)
    btn.Position = UDim2.new(0, 20, 0, 100)
    btn.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
    btn.Text = "Acceder"
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 14
    btn.Parent = bg
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

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
end

--═══════════════════════════════════════════════════════════════
-- HUB MAIN
--═══════════════════════════════════════════════════════════════
function loadHub()
    -- Evitar duplicados
    local old = PlayerGui:FindFirstChild("SCPHubUI")
    if old then old:Destroy() end

    local State = {
        Aimbot = false, AimbotRMB = false, LockMode = "CFrame", LockPart = "Head",
        AimSmooth = 30, AimDeadzone = 0.5, AimMaxRotPerFrame = 8,
        AimMaxDist = 5000, RequireWeapon = false, ForceScriptable = false,
        FOV = 600, FOVVisible = true, FOVFollowMouse = false,
        FOVColor = Color3.fromRGB(255, 255, 255),
        TargetPriority = "Cercano al crosshair", TargetIndicator = true,
        WallDetect = false, IgnoreTeam = false, ShieldMode = "Ignorar",
        ESP = false, ESPName = true, ESPDist = true, ESPHealth = true,
        Fullbright = false,
    }

    local parentGui = Instance.new("ScreenGui")
    parentGui.Name = "SCPHubUI"
    parentGui.Parent = PlayerGui
    parentGui.IgnoreGuiInset = true
    parentGui.ResetOnSpawn = false

    -- ─────────────────────────────────────────────────────────────
    -- UI ENGINE
    -- ─────────────────────────────────────────────────────────────
    local Main = Instance.new("Frame")
    Main.Size = UDim2.new(0, 500, 0, 350)
    Main.Position = UDim2.new(0.5, -250, 0.5, -175)
    Main.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    Main.Parent = parentGui
    Instance.new("UICorner", Main).CornerRadius = UDim.new(0, 8)

    local dragBar = Instance.new("Frame")
    dragBar.Size = UDim2.new(1, 0, 0, 30)
    dragBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    dragBar.Parent = Main
    Instance.new("UICorner", dragBar).CornerRadius = UDim.new(0, 8)

    local title = Instance.new("TextLabel")
    title.Size = UDim2.new(1, -60, 1, 0)
    title.Position = UDim2.new(0, 10, 0, 0)
    title.BackgroundTransparency = 1
    title.Text = "SCP Hub v8.5"
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

    -- Dragging
    local dragging, dragInput, dragStart, startPos
    dragBar.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = true; dragStart = input.Position; startPos = Main.Position
        end
    end)
    dragBar.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement then dragInput = input end
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

    local function addToggle(parent, text, default, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.Text = "  [ " .. (default and "X" or " ") .. " ]  " .. text
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local state = default
        btn.MouseButton1Click:Connect(function()
            state = not state
            btn.Text = "  [ " .. (state and "X" or " ") .. " ]  " .. text
            callback(state)
        end)
    end

    local function addSlider(parent, text, min, max, default, callback)
        local frame = Instance.new("Frame")
        frame.Size = UDim2.new(1, 0, 0, 40)
        frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        frame.Parent = parent
        Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 4)

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
        Instance.new("UICorner", bar).CornerRadius = UDim.new(1, 0)

        local fill = Instance.new("Frame")
        fill.Size = UDim2.new((default - min) / (max - min), 0, 1, 0)
        fill.BackgroundColor3 = Color3.fromRGB(0, 170, 255)
        fill.Parent = bar
        Instance.new("UICorner", fill).CornerRadius = UDim.new(1, 0)

        local dragging, val = false, default
        local function update(input)
            local pos = math.clamp((input.Position.X - bar.AbsolutePosition.X) / bar.AbsoluteSize.X, 0, 1)
            val = math.floor(min + (max - min) * pos)
            fill.Size = UDim2.new(pos, 0, 1, 0)
            label.Text = "  " .. text .. ": " .. val
            callback(val)
        end
        bar.InputBegan:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = true; update(i) end end)
        UserInputService.InputChanged:Connect(function(i) if dragging and i.UserInputType == Enum.UserInputType.MouseMovement then update(i) end end)
        UserInputService.InputEnded:Connect(function(i) if i.UserInputType == Enum.UserInputType.MouseButton1 then dragging = false end end)
    end

    local function addCycle(parent, text, options, defaultIdx, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
        btn.Text = "  " .. text .. ": " .. options[defaultIdx]
        btn.TextColor3 = Color3.fromRGB(220, 220, 220)
        btn.Font = Enum.Font.Gotham
        btn.TextSize = 13
        btn.TextXAlignment = Enum.TextXAlignment.Left
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        local idx = defaultIdx
        btn.MouseButton1Click:Connect(function()
            idx = idx + 1; if idx > #options then idx = 1 end
            btn.Text = "  " .. text .. ": " .. options[idx]
            callback(options[idx])
        end)
    end

    local function addButton(parent, text, callback)
        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(1, 0, 0, 30)
        btn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
        btn.Text = "  " .. text
        btn.TextColor3 = Color3.fromRGB(255, 255, 255)
        btn.Font = Enum.Font.GothamBold
        btn.TextSize = 13
        btn.Parent = parent
        Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
        btn.MouseButton1Click:Connect(callback)
    end

    local Combat, btnCombat = createTab("Combat")
    local Visual, btnVisual = createTab("Visual")
    local Config, btnConfig = createTab("Config")
    btnCombat:Fire("MouseButton1Click")

    -- ─────────────────────────────────────────────────────────────
    -- GAME LOGIC
    -- ─────────────────────────────────────────────────────────────
    local aimState = { target = nil, locked = false, coasting = false, stableHeadPos = nil }
    
    local function isLocalAlive()
        local char = LocalPlayer.Character
        if not char then return false end
        local hum = char:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead
    end

    local function isTargetAlive(plr)
        if not plr or not plr.Character then return false end
        local hum = plr.Character:FindFirstChildOfClass("Humanoid")
        return hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead
    end

    local function findClosestPlayer(cam)
        local fovCenter = State.FOVFollowMouse and UserInputService:GetMouseLocation() or Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        local camPos = cam.CFrame.Position
        local best, bestScore = nil, math.huge
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr ~= LocalPlayer and isTargetAlive(plr) then
                if not (State.IgnoreTeam and LocalPlayer.Team == plr.Team) then
                    local part = plr.Character:FindFirstChild(State.LockPart) or plr.Character:FindFirstChild("Head")
                    if part then
                        local wd = (part.Position - camPos).Magnitude
                        if wd <= State.AimMaxDist then
                            local pos = cam:WorldToViewportPoint(part.Position)
                            if pos.Z > 0 then
                                local sd = (Vector2.new(pos.X, pos.Y) - fovCenter).Magnitude
                                if sd <= State.FOV then
                                    local score = (State.TargetPriority == "Menos HP" and plr.Character.Humanoid.Health)
                                        or (State.TargetPriority == "Más cercano en studs" and wd) or sd
                                    if score < bestScore then
                                        best = { plr = plr, head = part, score = score }
                                        bestScore = score
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
        if not State.Aimbot or not isLocalAlive() then return end
        if State.AimbotRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then return end
        
        local cam = workspace.CurrentCamera
        local target = findClosestPlayer(cam)
        if not target then aimState.locked = false; return end

        if aimState.target ~= target.plr then
            aimState.target = target.plr
            aimState.stableHeadPos = nil
        end
        aimState.locked = true

        local aimPos = target.head.Position
        local camPos = cam.CFrame.Position
        local delta = aimPos - camPos
        if delta.Magnitude < 0.3 then return end

        local dot = math.clamp(cam.CFrame.LookVector:Dot(delta.Unit), -1, 1)
        local angleDeg = math.deg(math.acos(dot))
        
        if aimState.coasting then
            if angleDeg > State.AimDeadzone * 4 then aimState.coasting = false end
        else
            if angleDeg < State.AimDeadzone then aimState.coasting = true end
        end
        if aimState.coasting then return end

        local baseAlpha = math.clamp(0.9 - (State.AimSmooth / 100) * 0.8, 0.1, 0.9)
        local angleFactor = angleDeg < 5 and math.max(0.15, angleDeg / 5) or (angleDeg < 15 and 0.5 + (angleDeg - 5) / 20 or 1.0)
        local finalAlpha = math.clamp(baseAlpha * angleFactor, 0.02, 0.9)
        
        local maxRot = math.rad(State.AimMaxRotPerFrame)
        if math.acos(dot) > maxRot then finalAlpha = math.min(finalAlpha, maxRot / math.acos(dot)) end

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
    end

    local function setAimbotBinding()
        pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)
        aimState.locked = false; aimState.target = nil
        if State.Aimbot then
            local okBind = pcall(function() RunService:BindToRenderStep("HubAimbotStep", Enum.RenderPriority.Last.Value - 1, aimStep) end)
            if not okBind then RunService.RenderStepped:Connect(aimStep) end
        end
    end

    -- FOV Circle
    local fovGui = Instance.new("ScreenGui"); fovGui.Parent = PlayerGui; fovGui.IgnoreGuiInset = true
    local fovRing = Instance.new("Frame"); fovRing.AnchorPoint = Vector2.new(0.5, 0.5); fovRing.BackgroundTransparency = 1; fovRing.Parent = fovGui
    local fovStroke = Instance.new("UIStroke", fovRing); fovStroke.Thickness = 1.5; fovStroke.Color = State.FOVColor
    Instance.new("UICorner", fovRing).CornerRadius = UDim.new(1, 0)

    RunService.RenderStepped:Connect(function()
        if not State.Aimbot or not State.FOVVisible then fovGui.Enabled = false; return end
        fovGui.Enabled = true
        local cam = workspace.CurrentCamera
        local center = State.FOVFollowMouse and UserInputService:GetMouseLocation() or Vector2.new(cam.ViewportSize.X/2, cam.ViewportSize.Y/2)
        fovRing.Position = UDim2.fromOffset(center.X, center.Y)
        fovRing.Size = UDim2.fromOffset(State.FOV * 2, State.FOV * 2)
        fovStroke.Color = aimState.coasting and Color3.fromRGB(100, 255, 100) or (aimState.locked and Color3.fromRGB(255, 150, 150) or State.FOVColor)
    end)

    -- ─────────────────────────────────────────────────────────────
    -- UI POPULATION
    -- ─────────────────────────────────────────────────────────────
    addToggle(Combat, "Aimbot", State.Aimbot, function(v) State.Aimbot = v; setAimbotBinding() end)
    addToggle(Combat, "Solo con clic derecho", State.AimbotRMB, function(v) State.AimbotRMB = v end)
    addCycle(Combat, "Modo de lock", {"CFrame", "mousemoverel", "mousemoveabs"}, 1, function(v) State.LockMode = v end)
    addCycle(Combat, "LockPart", {"Head", "UpperTorso", "HumanoidRootPart"}, 1, function(v) State.LockPart = v end)
    addSlider(Combat, "Suavidad", 0, 100, State.AimSmooth, function(v) State.AimSmooth = v end)
    addSlider(Combat, "Tolerancia (°)", 0.1, 5, State.AimDeadzone, function(v) State.AimDeadzone = v end)
    addSlider(Combat, "Velocidad máx (°/frame)", 2, 30, State.AimMaxRotPerFrame, function(v) State.AimMaxRotPerFrame = v end)
    addSlider(Combat, "FOV (radio px)", 10, 800, State.FOV, function(v) State.FOV = v end)
    addToggle(Combat, "Mostrar FOV", State.FOVVisible, function(v) State.FOVVisible = v end)
    addToggle(Combat, "Ignorar aliados", State.IgnoreTeam, function(v) State.IgnoreTeam = v end)

    addToggle(Visual, "ESP", State.ESP, function(v) State.ESP = v end)
    addToggle(Visual, "ESP Nombre", State.ESPName, function(v) State.ESPName = v end)
    addToggle(Visual, "Fullbright", State.Fullbright, function(v)
        State.Fullbright = v
        if v then Lighting.Ambient = Color3.fromRGB(200,200,200); Lighting.Brightness = 3; Lighting.FogEnd = 100000
        else Lighting.Ambient = Color3.fromRGB(0,0,0); Lighting.Brightness = 2; Lighting.FogEnd = 1000 end
    end)

    addButton(Config, "Descargar Hub", function()
        pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)
        parentGui:Destroy(); fovGui:Destroy()
    end)
    addButton(Config, "Borrar Key Guardada", function()
        pcall(function() if delfile then delfile("SCPHub_Key.txt") end end)
    end)

    -- Keybind
    UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == Enum.KeyCode.X then
            State.Aimbot = not State.Aimbot
            setAimbotBinding()
        end
    end)
end

if checkKey() then
    loadHub()
else
    showKeyGui()
end