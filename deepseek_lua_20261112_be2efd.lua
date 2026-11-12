--[[═══════════════════════════════════════════════════════════════
          SCP ROLEPLAY HUB v6.5  |  Rayfield Gen2
          · Fixes de auditoría v6.4 (20 bugs corregidos)
          · Silent Aim con 3 capas + fallback Mouse
          · FOV FIJO en el centro · Aimbot POST-CÁMARA
          · ESP cajas + tracers · Hitbox sin Massless en HRP
   ═══════════════════════════════════════════════════════════════]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
local GuiService       = game:GetService("GuiService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

if game.PlaceId ~= 5041144419 then
    LocalPlayer:Kick("Este hub es exclusivo de SCP Roleplay (PlaceId 5041144419).")
    return
end

local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not ok or not Rayfield then
    LocalPlayer:Kick("No se pudo cargar Rayfield. Revisa tu conexión o tu ejecutor.")
    return
end

local Window = Rayfield:CreateWindow({
    name = "SCP Roleplay Hub",
    subtitle = "Rayfield Gen2 · v6.5",
    sidebarLayout = true,
    keySystem = true,
    keySettings = {
        title = "SCP Roleplay Hub",
        subtitle = "Key System",
        note = "Introduce la clave para acceder al hub",
        fileName = "SCPHubKey",
        saveKey = true,
        grabKeyFromSite = false,
        key = { "20112026" },
    },
})

local TabMain    = Window:CreateTab({ name = "Principal", icon = 93364949241311 })
local TabCombat  = Window:CreateTab({ name = "Combate",   icon = 93364949241311 })
local TabVisual  = Window:CreateTab({ name = "Visual",    icon = 93364949241311 })
local TabExtra   = Window:CreateTab({ name = "Varios",    icon = 93364949241311 })
local TabConfig  = Window:CreateTab({ name = "Config",    icon = 93364949241311 })

local State = {
    -- [FIX v6.5 #5] AutoSave real
    AutoSave        = true,
    ESP             = false,
    ESPName         = true,
    ESPDist         = true,
    ESPHealth       = true,
    ESPTracers      = false,
    ESPMaxDist      = 2000,
    ESPEnemiesOnly  = false,
    UseESPColor     = false,
    ESPColor        = Color3.fromRGB(255, 255, 255),
    InstantUse      = false,
    Fullbright      = false,
    SilentAim       = false,
    FOV             = 120,
    FOVVisible      = true,
    FOVColor        = Color3.fromRGB(0, 255, 255),
    WallDetect      = true,
    IgnoreTeam      = true,
    Hitbox          = false,
    HitboxMode      = "Cabeza",
    HitboxOnlyEnemy = true,
    HeadSize        = 6,
    AutoReload      = false,
    Aimbot          = false,
    AimbotRMB       = true,
    AimSmooth       = 35,
    MouseAim        = false,
    LOSBusy         = false,
    ShotsSeen       = 0,
    ShotsHit        = 0,
}

local DEFAULTS = {
    AutoSave = true,
    ESP = false, ESPName = true, ESPDist = true, ESPHealth = true,
    ESPTracers = false,
    ESPMaxDist = 2000, ESPEnemiesOnly = false, UseESPColor = false,
    ESPColor = Color3.fromRGB(255, 255, 255),
    InstantUse = false, Fullbright = false,
    SilentAim = false, FOV = 120, FOVVisible = true,
    FOVColor = Color3.fromRGB(0, 255, 255),
    WallDetect = true, IgnoreTeam = true,
    Hitbox = false, HitboxMode = "Cabeza",
    HitboxOnlyEnemy = true, HeadSize = 6,
    AutoReload = false,
    Aimbot = false, AimbotRMB = true, AimSmooth = 35,
    MouseAim = false,
}

local Highlights = {}
local ESPDraw    = {}
local ESPConns   = {}
local ESPRender  = nil
local antiAFKConn = nil
local UIRefs     = {}

local Conns = {}
local function addConn(name, conn)
    if Conns[name] then
        pcall(function() Conns[name]:Disconnect() end)
    end
    Conns[name] = conn
    return conn
end

local function notify(title, content)
    pcall(function() Window:Notify({ title = title, content = content }) end)
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

--─────────────────────── CONFIG (FIX #5, #19) ──────────────────
local CONFIG_FILE = "SCPHub_Config.json"

local SAVE_KEYS = {
    "AutoSave",
    "ESP", "ESPName", "ESPDist", "ESPHealth", "ESPTracers", "ESPMaxDist", "ESPEnemiesOnly",
    "UseESPColor", "ESPColor",
    "InstantUse", "Fullbright",
    "SilentAim", "FOV", "FOVVisible", "FOVColor",
    "WallDetect", "IgnoreTeam",
    "Hitbox", "HitboxMode", "HitboxOnlyEnemy", "HeadSize",
    "AutoReload",
    "Aimbot", "AimbotRMB", "AimSmooth", "MouseAim",
}

local function saveConfig()
    pcall(function()
        local data = {}
        for _, key in ipairs(SAVE_KEYS) do
            local v = State[key]
            if typeof(v) == "Color3" then
                data[key] = { r = v.R, g = v.G, b = v.B }
            else
                data[key] = v
            end
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end

-- [FIX v6.5 #5] guard para autoguardado
local function maybeSave()
    if State.AutoSave then saveConfig() end
end

local function loadConfig()
    local loaded = false
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(data) == "table" then
                for _, key in ipairs(SAVE_KEYS) do
                    local v = data[key]
                    if v ~= nil then
                        if type(v) == "table" and typeof(State[key]) == "Color3" then
                            State[key] = Color3.new(v.r or 1, v.g or 1, v.b or 1)
                        elseif typeof(v) == typeof(State[key]) then
                            State[key] = v
                        end
                    end
                end
                loaded = true
            end
        end
    end)
    return loaded
end

local configLoaded = loadConfig()

--──────────────────────────── ESP ───────────────────────────────
local DrawingSupported = false
pcall(function()
    local test = Drawing.new("Square")
    test:Remove()
    DrawingSupported = true
end)

local function clearPlayerVisual(plr)
    local objs = ESPDraw[plr]
    if objs then
        for _, obj in pairs(objs) do
            pcall(function() obj:Remove() end)
        end
        ESPDraw[plr] = nil
    end
    local hl = Highlights[plr]
    if hl then
        pcall(function() hl:Destroy() end)
        Highlights[plr] = nil
    end
    -- [FIX v6.5 #17] desconectar ESPConns del fallback
    local conn = ESPConns[plr]
    if conn then
        pcall(function() conn:Disconnect() end)
        ESPConns[plr] = nil
    end
end

local function createDrawings(plr)
    if ESPDraw[plr] then return end
    local box = Drawing.new("Square")
    box.Thickness = 1.5
    box.Filled = false
    box.Transparency = 1
    box.Visible = false

    local name = Drawing.new("Text")
    name.Size = 13
    name.Center = true
    name.Outline = true
    name.Visible = false

    local distTxt = Drawing.new("Text")
    distTxt.Size = 12
    distTxt.Center = true
    distTxt.Outline = true
    distTxt.Visible = false

    local healthbg = Drawing.new("Square")
    healthbg.Thickness = 0
    healthbg.Filled = true
    healthbg.Color = Color3.fromRGB(0, 0, 0)
    healthbg.Transparency = 0.6
    healthbg.Visible = false

    local health = Drawing.new("Square")
    health.Thickness = 0
    health.Filled = true
    health.Visible = false

    local tracer = Drawing.new("Line")
    tracer.Thickness = 1.5
    tracer.Transparency = 1
    tracer.Visible = false

    ESPDraw[plr] = {
        box      = box,
        name     = name,
        dist     = distTxt,
        health   = health,
        healthbg = healthbg,
        tracer   = tracer,
    }
end

local function espColorFor(plr)
    if State.UseESPColor then
        return State.ESPColor
    end
    return (plr.Team and plr.Team.Color) or Color3.fromRGB(255, 255, 255)
end

local function startRenderLoop()
    if ESPRender then return end
    ESPRender = RunService.RenderStepped:Connect(function()
        if not State.ESP or not DrawingSupported then return end
        local cam = workspace.CurrentCamera
        if not cam then return end

        for plr, objs in pairs(ESPDraw) do
            local char = plr.Character
            local root = char and char:FindFirstChild("HumanoidRootPart")
            local hum  = char and char:FindFirstChildOfClass("Humanoid")

            local visible = false
            local dist = 0
            local centerX, topY, boxW, boxH = 0, 0, 0, 0

            local sameTeam = plr.Team ~= nil and plr.Team == LocalPlayer.Team
            if State.ESPEnemiesOnly and sameTeam then
                char = nil
            end

            if char and root and hum and hum.Health > 0 then
                dist = (cam.CFrame.Position - root.Position).Magnitude
                if dist <= State.ESPMaxDist then
                    local topS = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3.4, 0))
                    local botS = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.0, 0))
                    local ctrS = cam:WorldToViewportPoint(root.Position)
                    if ctrS.Z > 0 then
                        boxH = math.abs(botS.Y - topS.Y)
                        if boxH > 4 then
                            boxW = boxH * 0.55
                            centerX = ctrS.X
                            topY = math.min(topS.Y, botS.Y)
                            visible = true
                        end
                    end
                end
            end

            if visible then
                local teamColor = espColorFor(plr)

                objs.box.Position = Vector2.new(centerX - boxW / 2, topY)
                objs.box.Size = Vector2.new(boxW, boxH)
                objs.box.Color = teamColor
                objs.box.Visible = true

                if State.ESPName then
                    objs.name.Text = plr.Name
                    objs.name.Position = Vector2.new(centerX, topY - 14)
                    objs.name.Color = teamColor
                    objs.name.Visible = true
                else
                    objs.name.Visible = false
                end

                if State.ESPDist then
                    objs.dist.Text = tostring(math.floor(dist)) .. " m"
                    objs.dist.Position = Vector2.new(centerX, topY + boxH + 4)
                    objs.dist.Color = Color3.fromRGB(255, 255, 255)
                    objs.dist.Visible = true
                else
                    objs.dist.Visible = false
                end

                if State.ESPHealth then
                    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local barH = boxH * pct
                    objs.healthbg.Position = Vector2.new(centerX - boxW / 2 - 6, topY)
                    objs.healthbg.Size = Vector2.new(3, boxH)
                    objs.healthbg.Visible = true
                    objs.health.Position = Vector2.new(centerX - boxW / 2 - 6, topY + (boxH - barH))
                    objs.health.Size = Vector2.new(3, barH)
                    objs.health.Color = Color3.fromRGB(
                        math.floor(255 * (1 - pct)),
                        math.floor(200 * pct),
                        0
                    )
                    objs.health.Visible = true
                else
                    objs.healthbg.Visible = false
                    objs.health.Visible = false
                end

                if objs.tracer then
                    if State.ESPTracers then
                        local vp = cam.ViewportSize
                        objs.tracer.From = Vector2.new(vp.X / 2, vp.Y - 2)
                        objs.tracer.To = Vector2.new(centerX, topY + boxH)
                        objs.tracer.Color = teamColor
                        objs.tracer.Visible = true
                    else
                        objs.tracer.Visible = false
                    end
                end
            else
                objs.box.Visible = false
                objs.name.Visible = false
                objs.dist.Visible = false
                objs.health.Visible = false
                objs.healthbg.Visible = false
                if objs.tracer then
                    objs.tracer.Visible = false
                end
            end
        end
    end)
end

local function attachHL(plr)
    if plr == LocalPlayer then return end
    if ESPConns[plr] then
        ESPConns[plr]:Disconnect()
        ESPConns[plr] = nil
    end
    local function attach(char)
        local old = Highlights[plr]
        if old then
            old:Destroy()
            Highlights[plr] = nil
        end
        if not State.ESP then return end
        local hl = Instance.new("Highlight")
        hl.Name = "HubESP"
        hl.FillTransparency = 0.65
        hl.FillColor = espColorFor(plr)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        Highlights[plr] = hl
    end
    if plr.Character then
        attach(plr.Character)
    end
    ESPConns[plr] = plr.CharacterAdded:Connect(attach)
end

local function setESP(on)
    State.ESP = on
    if DrawingSupported then
        if on then
            startRenderLoop()
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LocalPlayer then
                    createDrawings(plr)
                end
            end
        else
            for plr in pairs(ESPDraw) do
                clearPlayerVisual(plr)
            end
            if ESPRender then
                ESPRender:Disconnect()
                ESPRender = nil
            end
        end
    else
        if on then
            for _, plr in ipairs(Players:GetPlayers()) do
                attachHL(plr)
            end
        else
            for plr in pairs(Highlights) do
                clearPlayerVisual(plr)
            end
            for plr, conn in pairs(ESPConns) do
                pcall(function() conn:Disconnect() end)
            end
            ESPConns = {}
        end
    end
end

--────────────────────── CÍRCULO FOV ────────────────────────────
local fovGui, fovRing, fovDot, fovStroke = nil, nil, nil, nil
pcall(function()
    local parent = nil
    if typeof(gethui) == "function" then
        pcall(function() parent = gethui() end)
    end
    if not parent then
        local okCore, core = pcall(function() return game:GetService("CoreGui") end)
        if okCore and core then parent = core end
    end
    if not parent then
        parent = LocalPlayer:WaitForChild("PlayerGui")
    end

    fovGui = Instance.new("ScreenGui")
    fovGui.Name = "HubFOVCircle"
    fovGui.IgnoreGuiInset = true
    fovGui.ResetOnSpawn = false
    fovGui.DisplayOrder = 9999

    fovRing = Instance.new("Frame")
    fovRing.Name = "Ring"
    fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
    fovRing.BackgroundTransparency = 1
    fovRing.BorderSizePixel = 0

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = fovRing

    fovStroke = Instance.new("UIStroke")
    fovStroke.Thickness = 1.5
    fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fovStroke.Color = State.FOVColor
    fovStroke.Parent = fovRing

    fovDot = Instance.new("Frame")
    fovDot.Name = "CenterDot"
    fovDot.AnchorPoint = Vector2.new(0.5, 0.5)
    fovDot.Size = UDim2.fromOffset(4, 4)
    fovDot.BackgroundColor3 = State.FOVColor
    fovDot.BackgroundTransparency = 0.2
    fovDot.BorderSizePixel = 0
    local dotCorner = Instance.new("UICorner")
    dotCorner.CornerRadius = UDim.new(1, 0)
    dotCorner.Parent = fovDot

    fovRing.Parent = fovGui
    fovDot.Parent = fovGui
    fovGui.Parent = parent
    fovGui.Enabled = false
end)

addConn("FOVRender", RunService.RenderStepped:Connect(function()
    if not fovGui or not fovRing or not fovStroke then return end
    if (State.SilentAim or State.Aimbot) and State.FOVVisible then
        local cam = workspace.CurrentCamera
        if cam then
            local vp = cam.ViewportSize
            local d = math.max(math.floor(State.FOV) * 2, 10)
            fovRing.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
            fovRing.Size = UDim2.fromOffset(d, d)
            fovStroke.Color = State.FOVColor
            if fovDot then
                fovDot.Position = UDim2.fromOffset(vp.X / 2, vp.Y / 2)
                fovDot.BackgroundColor3 = State.FOVColor
            end
        end
        fovGui.Enabled = true
    else
        fovGui.Enabled = false
    end
end))

--───────────────────────── FULLBRIGHT ──────────────────────────
local LightingDefaults = {
    Ambient       = Lighting.Ambient,
    Brightness    = Lighting.Brightness,
    FogEnd        = Lighting.FogEnd,
    ClockTime     = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
}

local function setFullbright(on)
    State.Fullbright = on
    if on then
        Lighting.Ambient       = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness    = 3
        Lighting.FogEnd        = 100000
        Lighting.ClockTime     = 14
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient       = LightingDefaults.Ambient
        Lighting.Brightness    = LightingDefaults.Brightness
        Lighting.FogEnd        = LightingDefaults.FogEnd
        Lighting.ClockTime     = LightingDefaults.ClockTime
        Lighting.GlobalShadows = LightingDefaults.GlobalShadows
    end
end

--────────────── INTERACCIÓN INSTANTÁNEA ─────────────────────────
local function setPromptHold(prompt, zero)
    if zero then
        if prompt:GetAttribute("HubOriginalHold") == nil then
            prompt:SetAttribute("HubOriginalHold", prompt.HoldDuration)
        end
        prompt.HoldDuration = 0
    else
        local orig = prompt:GetAttribute("HubOriginalHold")
        if orig ~= nil then
            prompt.HoldDuration = orig
        end
    end
end

local function setInstantUse(on)
    State.InstantUse = on
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("ProximityPrompt") then
            setPromptHold(obj, on)
        end
    end
end

addConn("Prompts", workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") and State.InstantUse then
        task.defer(setPromptHold, obj, true)
    end
end))

--─────────────────── SILENT AIM (FIX #4, #6, #16) ──────────────
local HookSupported = false
local oldNamecall = nil

-- [FIX v6.5 #6] caché de BaseParts del personaje (1 s)
local shotOriginCache = { time = 0, parts = {} }
local function getCharPartsForShot()
    local now = os.clock()
    if now - shotOriginCache.time > 1 then
        shotOriginCache.time = now
        shotOriginCache.parts = {}
        local char = LocalPlayer.Character
        if char then
            for _, obj in ipairs(char:GetDescendants()) do
                if obj:IsA("BasePart") then
                    table.insert(shotOriginCache.parts, obj)
                end
            end
        end
    end
    return shotOriginCache.parts
end

local function isShotOrigin(origin)
    for _, part in ipairs(getCharPartsForShot()) do
        if (origin - part.Position).Magnitude < 6 then
            return true
        end
    end
    local cam = workspace.CurrentCamera
    if cam and (origin - cam.CFrame.Position).Magnitude < 15 then
        return true
    end
    return false
end

local function hasLineOfSight(targetChar, head)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position
    local dirVec = head.Position - origin
    if dirVec.Magnitude < 0.1 then return true end

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local exclude = {}
    if LocalPlayer.Character then table.insert(exclude, LocalPlayer.Character) end
    if targetChar then table.insert(exclude, targetChar) end
    params.FilterDescendantsInstances = exclude
    params.RespectCanCollide = true

    State.LOSBusy = true
    local okRay, result = pcall(function()
        return workspace:Raycast(origin, dirVec, params)
    end)
    State.LOSBusy = false

    -- [FIX v6.5 #4] fallar seguro si el raycast falla
    if not okRay then return false end
    return result == nil
end

local cachedTarget, cachedTargetAt = nil, 0

local function getSilentTarget()
    local now = os.clock()
    -- [FIX v6.5 #9] validar que el jugador siga en el juego
    if cachedTarget and (now - cachedTargetAt) < 0.1 then
        if cachedTarget.Parent == nil then
            cachedTarget = nil
        else
            local c = cachedTarget.Character
            local h = c and c:FindFirstChildOfClass("Humanoid")
            if h and h.Health > 0 then
                return cachedTarget
            end
            cachedTarget = nil
        end
    end

    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local centerV2 = Vector2.new(vp.X / 2, vp.Y / 2)
    local best, bestDist = nil, State.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Parent ~= nil and plr.Character then
            local sameTeam = plr.Team ~= nil and plr.Team == LocalPlayer.Team
            if not (State.IgnoreTeam and sameTeam) then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local head = plr.Character:FindFirstChild("Head")
                if hum and hum.Health > 0 and head then
                    local pos, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen and pos.Z > 0 then
                        local d = (Vector2.new(pos.X, pos.Y) - centerV2).Magnitude
                        if plr == cachedTarget then
                            d = d * 0.7
                        end
                        if d < bestDist then
                            if (not State.WallDetect) or hasLineOfSight(plr.Character, head) then
                                best, bestDist = plr, d
                            end
                        end
                    end
                end
            end
        end
    end
    cachedTarget = best
    cachedTargetAt = now
    return best
end

local function computeRedirect(origin, dir)
    local target = getSilentTarget()
    local targetChar = target and target.Character
    local head = targetChar and targetChar:FindFirstChild("Head")
    if not head then return nil end
    local newDir = (head.Position - origin).Unit * dir.Magnitude
    return newDir, targetChar, head
end

-- [FIX v6.5 #1] GetDescendants para filtrar accesorios bajo Head
local function buildHeadParams(params, targetChar, head)
    if not params then return nil end
    local np = RaycastParams.new()
    pcall(function()
        np.FilterType = params.FilterType
        np.IgnoreWater = params.IgnoreWater
        np.RespectCanCollide = params.RespectCanCollide
    end)
    pcall(function()
        np.CollisionGroup = params.CollisionGroup
    end)
    local list = {}
    pcall(function()
        for _, inst in ipairs(params.FilterDescendantsInstances) do
            table.insert(list, inst)
        end
    end)
    if targetChar then
        for _, inst in ipairs(targetChar:GetDescendants()) do
            if inst ~= head then
                table.insert(list, inst)
            end
        end
    end
    np.FilterDescendantsInstances = list
    return np
end

-- [FIX v6.5 #16] pcall a getnamecallmethod
local function namecallCore(self, oldNC, ...)
    local okM, method = pcall(getnamecallmethod)
    if not okM then return oldNC(self, ...) end
    if State.SilentAim and not State.LOSBusy and self == workspace
        and (method == "Raycast" or method == "FindPartOnRay" or method == "FindPartOnRayWithIgnoreList") then
        local args = { ... }
        local origin = args[1]
        local dir = nil
        if method == "Raycast" then
            dir = args[2]
        elseif typeof(args[1]) == "Ray" then
            origin = args[1].Origin
            dir = args[1].Direction
        end
        if typeof(origin) == "Vector3" and typeof(dir) == "Vector3"
            and dir.Magnitude > 0 and isShotOrigin(origin) then
            State.ShotsSeen = State.ShotsSeen + 1
            local newDir, targetChar, head = computeRedirect(origin, dir)
            if newDir then
                State.ShotsHit = State.ShotsHit + 1
                if method == "Raycast" then
                    local newParams = buildHeadParams(args[3], targetChar, head)
                    return oldNC(self, origin, newDir, newParams or args[3])
                else
                    return oldNC(self, Ray.new(origin, newDir), table.unpack(args, 2))
                end
            end
        end
    end
    return oldNC(self, ...)
end

pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        return namecallCore(self, oldNamecall, ...)
    end))
    HookSupported = true
end)

local ManualHookActive = false
if not HookSupported and type(getrawmetatable) == "function"
    and type(setreadonly) == "function" and type(newcclosure) == "function" then
    pcall(function()
        local mt = getrawmetatable(game)
        local oldNC = mt.__namecall
        if type(oldNC) ~= "function" then return end
        setreadonly(mt, false)
        mt.__namecall = newcclosure(function(self, ...)
            return namecallCore(self, oldNC, ...)
        end)
        setreadonly(mt, true)
        ManualHookActive = true
    end)
end

local HookFnSupported = false
if not HookSupported and not ManualHookActive and type(hookfunction) == "function" then
    pcall(function()
        local origRay = nil
        local newFn
        newFn = function(ws, origin, dir, params)
            if State.SilentAim and not State.LOSBusy
                and typeof(origin) == "Vector3" and typeof(dir) == "Vector3"
                and dir.Magnitude > 0 and isShotOrigin(origin) then
                State.ShotsSeen = State.ShotsSeen + 1
                local newDir, targetChar, head = computeRedirect(origin, dir)
                if newDir then
                    State.ShotsHit = State.ShotsHit + 1
                    local newParams = buildHeadParams(params, targetChar, head)
                    return origRay(ws, origin, newDir, newParams or params)
                end
            end
            return origRay(ws, origin, dir, params)
        end
        origRay = hookfunction(workspace.Raycast, newFn)
        HookFnSupported = true
    end)
    pcall(function()
        local origFPR = nil
        local newFPR
        newFPR = function(ws, ray, ...)
            local origin, dir = ray.Origin, ray.Direction
            if State.SilentAim and not State.LOSBusy
                and typeof(origin) == "Vector3" and typeof(dir) == "Vector3"
                and dir.Magnitude > 0 and isShotOrigin(origin) then
                State.ShotsSeen = State.ShotsSeen + 1
                local newDir = computeRedirect(origin, dir)
                if newDir then
                    State.ShotsHit = State.ShotsHit + 1
                    return origFPR(ws, Ray.new(origin, newDir), ...)
                end
            end
            return origFPR(ws, ray, ...)
        end
        origFPR = hookfunction(workspace.FindPartOnRay, newFPR)
    end)
end

-- [FIX v6.5 #3, #7] Mouse hook cachea el mouse + guarda oldIndex
local ManualIndexActive = false
local oldMouseIndex = nil
local cachedMouse = nil

local function installMouseHook()
    if ManualIndexActive then return end
    if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function"
        or type(newcclosure) ~= "function" then
        notify("Combate", "Tu ejecutor no soporta el hook de Mouse.")
        return
    end
    pcall(function()
        cachedMouse = LocalPlayer:GetMouse()
    end)
    if not cachedMouse then
        notify("Combate", "No se pudo obtener el Mouse del LocalPlayer.")
        return
    end
    pcall(function()
        local mt = getrawmetatable(game)
        oldMouseIndex = mt.__index
        if type(oldMouseIndex) ~= "function" then return end
        setreadonly(mt, false)
        mt.__index = newcclosure(function(t, k)
            local v = oldMouseIndex(t, k)
            if State.SilentAim and State.MouseAim and not State.LOSBusy
                and t == cachedMouse then
                if k == "Hit" or k == "Target" or k == "UnitRay" then
                    local target = getSilentTarget()
                    local head = target and target.Character and target.Character:FindFirstChild("Head")
                    if head then
                        if k == "Hit" then
                            return CFrame.new(head.Position)
                        elseif k == "Target" then
                            return head
                        else
                            local cam = workspace.CurrentCamera
                            local o = cam and cam.CFrame.Position or head.Position
                            return Ray.new(o, (head.Position - o).Unit * 1000)
                        end
                    end
                end
            end
            return v
        end)
        setreadonly(mt, true)
        ManualIndexActive = true
    end)
    if ManualIndexActive then
        notify("Combate", "Modo Mouse activo: Target/Hit/UnitRay van a la cabeza del objetivo.")
    else
        notify("Combate", "No se pudo instalar el hook de Mouse.")
    end
end

-- [FIX v6.5 #3] función para restaurar __index en unload
local function uninstallMouseHook()
    if not ManualIndexActive or not oldMouseIndex then return end
    pcall(function()
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        mt.__index = oldMouseIndex
        setreadonly(mt, true)
    end)
    ManualIndexActive = false
    oldMouseIndex = nil
end

--────────────────── HITBOX EXPANDER (FIX #2, #10) ──────────────
local hitboxParts   = {}
local hitboxLoopRun = true

local function partsForHitbox(char)
    local found = {}
    if State.HitboxMode == "Cabeza" then
        local h = char:FindFirstChild("Head")
        if h then table.insert(found, h) end
    elseif State.HitboxMode == "Parte invisible" then
        local r = char:FindFirstChild("HumanoidRootPart")
        if r then table.insert(found, r) end
    else
        local names = {
            "Head", "Torso", "UpperTorso", "LowerTorso", "HumanoidRootPart",
            "Left Arm", "Right Arm", "Left Leg", "Right Leg",
            "LeftUpperArm", "RightUpperArm", "LeftLowerArm", "RightLowerArm",
            "LeftHand", "RightHand",
            "LeftUpperLeg", "RightUpperLeg", "LeftLowerLeg", "RightLowerLeg",
            "LeftFoot", "RightFoot",
        }
        for _, n in ipairs(names) do
            local p = char:FindFirstChild(n)
            if p then table.insert(found, p) end
        end
    end
    return found
end

local function expandParts(plr)
    if plr == LocalPlayer then return end
    if State.HitboxOnlyEnemy and plr.Team ~= nil and plr.Team == LocalPlayer.Team then
        return
    end
    local char = plr.Character
    if not char then return end
    for _, part in ipairs(partsForHitbox(char)) do
        if hitboxParts[part] == nil then
            hitboxParts[part] = {
                size       = part.Size,
                massless   = part.Massless,
                cancollide = part.CanCollide,
                canquery   = part.CanQuery,   -- [FIX v6.5 #10]
            }
        end
        pcall(function()
            part.Size = Vector3.new(State.HeadSize, State.HeadSize, State.HeadSize)
            part.CanQuery = true
            -- [FIX v6.5 #2] NO tocar Massless en HumanoidRootPart
            if part.Name ~= "HumanoidRootPart" then
                part.Massless = true
                part.CanCollide = false
            end
        end)
    end
end

local function restoreHitbox()
    for part, rec in pairs(hitboxParts) do
        if part and part.Parent then
            pcall(function()
                part.Size       = rec.size
                part.Massless   = rec.massless
                part.CanCollide = rec.cancollide
                part.CanQuery   = rec.canquery
            end)
        end
    end
    hitboxParts = {}
end

local function reapplyHitbox()
    restoreHitbox()
    if State.Hitbox then
        for _, plr in ipairs(Players:GetPlayers()) do
            expandParts(plr)
        end
    end
end

local function setHitbox(on)
    State.Hitbox = on
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            expandParts(plr)
        end
        notify("Combate", "Hitbox activo (" .. State.HitboxMode .. ").")
    else
        restoreHitbox()
    end
end

task.spawn(function()
    while hitboxLoopRun do
        task.wait(0.5)
        if State.Hitbox then
            for part in pairs(hitboxParts) do
                if not part.Parent then
                    hitboxParts[part] = nil
                end
            end
            for _, plr in ipairs(Players:GetPlayers()) do
                expandParts(plr)
            end
        end
    end
end)

--──────────────────────── AUTO RECARGA ─────────────────────────
local lastReload = 0
local function trySendReload()
    if os.clock() - lastReload < 2 then return end
    lastReload = os.clock()
    local sent = false
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
        sent = true
    end)
    if not sent then
        pcall(function()
            keypress(82)
            task.wait(0.05)
            keyrelease(82)
        end)
    end
end

local function findAmmoValue(tool)
    for _, obj in ipairs(tool:GetDescendants()) do
        if obj:IsA("IntValue") or obj:IsA("NumberValue") then
            local n = obj.Name:lower()
            if n:find("ammo", 1, true) or n:find("mag", 1, true) or n:find("clip", 1, true) then
                return obj
            end
        end
    end
    return nil
end

local toolConns = {}

local function watchTool(tool, char)
    local ammoVal = findAmmoValue(tool)
    if ammoVal then
        toolConns[tool] = ammoVal.Changed:Connect(function(v)
            if State.AutoReload and v == 0 then
                task.wait(0.1)
                trySendReload()
            end
        end)
    end
    task.spawn(function()
        -- [FIX v6.5 #8] guard extra por si el tool se destruye sin cambiar de padre
        while tool.Parent == char and tool:IsDescendantOf(char) do
            if State.AutoReload then
                local ammo = tool:GetAttribute("Ammo")
                    or tool:GetAttribute("AmmoCount")
                    or tool:GetAttribute("Magazine")
                if ammo == 0 then
                    trySendReload()
                end
            end
            task.wait(0.25)
        end
        if toolConns[tool] then
            pcall(function() toolConns[tool]:Disconnect() end)
            toolConns[tool] = nil
        end
    end)
end

local function watchCharacterTools(char)
    addConn("CharToolsChildAdded_" .. tostring(char), char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            watchTool(child, char)
        end
    end))
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            watchTool(child, char)
        end
    end
end

if LocalPlayer.Character then
    watchCharacterTools(LocalPlayer.Character)
end
addConn("CharTools", LocalPlayer.CharacterAdded:Connect(watchCharacterTools))

--──────────────────── TP AL SPAWN / RESET ──────────────────────
local function teleportToSpawn()
    local root = getRoot()
    if not root then
        notify("Jugador", "Sin personaje.")
        return
    end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            root.CFrame = obj.CFrame + Vector3.new(0, 5, 0)
            notify("Jugador", "Teletransportado al spawn.")
            return
        end
    end
    notify("Jugador", "No se encontró ningún spawn en el mapa.")
end

local teamConns = {}

local function watchPlayer(plr)
    addConn("Char_" .. plr.Name, plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if State.Hitbox then
            expandParts(plr)
        end
        if State.ESP and not DrawingSupported then
            attachHL(plr)
        end
    end))
    teamConns[plr] = plr:GetPropertyChangedSignal("Team"):Connect(function()
        if State.Hitbox and State.HitboxOnlyEnemy then
            task.defer(reapplyHitbox)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    watchPlayer(plr)
end

--─────────────────────── AIMBOT DE CÁMARA ──────────────────────
local function aimStep(dt)
    if not State.Aimbot then return end
    if State.AimbotRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local target = getSilentTarget()
    local char = target and target.Character
    local head = char and char:FindFirstChild("Head")
    local hum = char and char:FindFirstChildOfClass("Humanoid")
    if not head or not hum or hum.Health <= 0 then return end
    local camPos = cam.CFrame.Position
    if (head.Position - camPos).Magnitude < 0.5 then return end
    local goal = CFrame.lookAt(camPos, head.Position)
    local rate = math.max(State.AimSmooth, 1) * 0.6
    local alpha = math.clamp(1 - math.exp(-(dt or 0.016) * rate), 0.01, 1)
    cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end

local function setAimbotBinding()
    pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)
    if Conns["AimbotFallback"] then
        pcall(function() Conns["AimbotFallback"]:Disconnect() end)
        Conns["AimbotFallback"] = nil
    end
    if State.Aimbot then
        local okBind = pcall(function()
            RunService:BindToRenderStep("HubAimbotStep", Enum.RenderPriority.Camera.Value + 1, aimStep)
        end)
        if not okBind then
            addConn("AimbotFallback", RunService.RenderStepped:Connect(aimStep))
        end
    end
end

--─────────────────────────── PRINCIPAL ─────────────────────────
TabMain:CreateToggle({
    name = "Interacción instantánea (E sin mantener)",
    currentValue = State.InstantUse,
    callback = function(on)
        setInstantUse(on)
        maybeSave()
    end,
})

TabMain:CreateToggle({
    name = "Anti-AFK (no te expulsa por inactividad)",
    callback = function(on)
        -- [FIX v6.5 #13] desconectar antes de reconectar
        if antiAFKConn then
            antiAFKConn:Disconnect()
            antiAFKConn = nil
        end
        if on then
            antiAFKConn = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end,
})

TabMain:CreateButton({
    name = "Reconectar al servidor (rejoin)",
    callback = function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end,
})

TabMain:CreateButton({
    name = "Ir al spawn",
    callback = teleportToSpawn,
})

TabMain:CreateButton({
    name = "Reaparecer (reset personaje)",
    callback = function()
        local hum = getHumanoid()
        if hum then
            hum.Health = 0
        end
    end,
})

--─────────────────────────── COMBATE ───────────────────────────
UIRefs.SilentAim = TabCombat:CreateToggle({
    name = "Silent Aim (las balas van a la cabeza)",
    currentValue = State.SilentAim,
    callback = function(on)
        if on and not HookSupported and not ManualHookActive and not HookFnSupported then
            notify("Combate", "Tu ejecutor no soporta los hooks necesarios. Silent Aim no disponible: usa el Aimbot de cámara.")
            return
        end
        State.SilentAim = on
        if on then
            local capa = HookSupported and "hookmetamethod"
                or (ManualHookActive and "manual/Xeno" or "hookfunction")
            notify("Combate", "Silent Aim ON (capa: " .. capa .. ").")
        end
        maybeSave()
    end,
})

UIRefs.FOV = TabCombat:CreateSlider({
    name = "FOV del aim (radio en píxeles desde el centro)",
    range = { 10, 600 },
    increment = 1,
    currentValue = State.FOV,
    callback = function(value)
        State.FOV = value
        maybeSave()
    end,
})

UIRefs.FOVVisible = TabCombat:CreateToggle({
    name = "Mostrar círculo del FOV (fijo en el centro)",
    currentValue = State.FOVVisible,
    callback = function(on)
        State.FOVVisible = on
        -- [FIX v6.5 #15] avisar si no hay aims activos
        if on and not (State.SilentAim or State.Aimbot) then
            notify("Combate", "El círculo solo se muestra con Silent Aim o Aimbot activos.")
        end
        maybeSave()
    end,
})

-- [FIX v6.5 #11] fallback real si CreateColorPicker falla
local pickerOk = false
if type(TabCombat.CreateColorPicker) == "function" then
    pickerOk = pcall(function()
        UIRefs.FOVColorPicker = TabCombat:CreateColorPicker({
            name = "Color del círculo",
            color = State.FOVColor,
            callback = function(color)
                State.FOVColor = color
                maybeSave()
            end,
        })
    end)
end
if not pickerOk then
    for _, c in ipairs({
        { label = "cian",   color = Color3.fromRGB(0, 255, 255) },
        { label = "rojo",   color = Color3.fromRGB(255, 0, 60) },
        { label = "verde",  color = Color3.fromRGB(0, 255, 90) },
        { label = "blanco", color = Color3.fromRGB(255, 255, 255) },
    }) do
        TabCombat:CreateButton({
            name = "Color del círculo: " .. c.label,
            callback = function()
                State.FOVColor = c.color
                maybeSave()
            end,
        })
    end
end

UIRefs.WallDetect = TabCombat:CreateToggle({
    name = "Wall detect (no apuntar a través de paredes)",
    currentValue = State.WallDetect,
    callback = function(on)
        State.WallDetect = on
        maybeSave()
    end,
})

UIRefs.IgnoreTeam = TabCombat:CreateToggle({
    name = "Ignorar aliados (no apuntar a tu equipo)",
    currentValue = State.IgnoreTeam,
    callback = function(on)
        State.IgnoreTeam = on
        maybeSave()
    end,
})

UIRefs.Hitbox = TabCombat:CreateToggle({
    name = "Hitbox expander",
    currentValue = State.Hitbox,
    callback = function(on)
        setHitbox(on)
        maybeSave()
    end,
})

-- [FIX v6.5 #12] fallback real si CreateDropdown falla
local dropOk = false
if type(TabCombat.CreateDropdown) == "function" then
    dropOk = pcall(function()
        UIRefs.HitboxMode = TabCombat:CreateDropdown({
            name = "Modo del hitbox",
            options = { "Cabeza", "Parte invisible", "Cuerpo completo" },
            currentOption = { State.HitboxMode },
            multipleOptions = false,
            callback = function(option)
                local val = option
                if type(val) == "table" then val = val[1] end
                if val and val ~= "" then
                    State.HitboxMode = tostring(val)
                    reapplyHitbox()
                    maybeSave()
                end
            end,
        })
    end)
end
if not dropOk then
    TabCombat:CreateButton({
        name = "Cambiar modo del hitbox (mira la notificación)",
        callback = function()
            local order = { "Cabeza", "Parte invisible", "Cuerpo completo" }
            local idx = 1
            for i, m in ipairs(order) do
                if m == State.HitboxMode then idx = i break end
            end
            State.HitboxMode = order[(idx % #order) + 1]
            reapplyHitbox()
            maybeSave()
            notify("Combate", "Modo del hitbox: " .. State.HitboxMode)
        end,
    })
end

UIRefs.HitboxOnlyEnemy = TabCombat:CreateToggle({
    name = "Hitbox solo en enemigos (nunca en tu equipo)",
    currentValue = State.HitboxOnlyEnemy,
    callback = function(on)
        State.HitboxOnlyEnemy = on
        reapplyHitbox()
        maybeSave()
    end,
})

UIRefs.HeadSize = TabCombat:CreateSlider({
    name = "Tamaño del hitbox",
    range = { 2, 20 },
    increment = 0.5,
    currentValue = State.HeadSize,
    callback = function(value)
        State.HeadSize = value
        if State.Hitbox then
            for _, plr in ipairs(Players:GetPlayers()) do
                expandParts(plr)
            end
        end
        maybeSave()
    end,
})

UIRefs.AutoReload = TabCombat:CreateToggle({
    name = "Auto Recarga (pulsa R solo al vaciar el cargador)",
    currentValue = State.AutoReload,
    callback = function(on)
        State.AutoReload = on
        maybeSave()
    end,
})

UIRefs.Aimbot = TabCombat:CreateToggle({
    name = "Aimbot de cámara (mira a la cabeza del objetivo)",
    currentValue = State.Aimbot,
    callback = function(on)
        State.Aimbot = on
        setAimbotBinding()
        maybeSave()
    end,
})

UIRefs.AimbotRMB = TabCombat:CreateToggle({
    name = "Aimbot solo con clic derecho mantenido",
    currentValue = State.AimbotRMB,
    callback = function(on)
        State.AimbotRMB = on
        maybeSave()
    end,
})

UIRefs.AimSmooth = TabCombat:CreateSlider({
    name = "Aimbot: suavidad (alto = más suave)",
    range = { 5, 100 },
    increment = 5,
    currentValue = State.AimSmooth,
    callback = function(value)
        State.AimSmooth = value
        maybeSave()
    end,
})

UIRefs.MouseAim = TabCombat:CreateToggle({
    name = "Modo Mouse (si el arma usa Target/Hit del ratón)",
    currentValue = State.MouseAim,
    callback = function(on)
        State.MouseAim = on
        if on then installMouseHook() end
        maybeSave()
    end,
})

TabCombat:CreateButton({
    name = "Diagnóstico del ejecutor (dime qué te sale)",
    callback = function()
        local execName = "desconocido"
        pcall(function()
            execName = (identifyexecutor and identifyexecutor()) or "desconocido"
        end)
        local lines = {
            "Ejecutor: " .. tostring(execName),
            "Capa 1: " .. (HookSupported and "OK" or "NO"),
            "Capa 2: " .. (ManualHookActive and "OK" or "NO"),
            "Capa 3: " .. (HookFnSupported and "OK" or "NO"),
            "Mouse: " .. (ManualIndexActive and "OK" or "NO"),
            "Rayos vistos: " .. tostring(State.ShotsSeen),
            "Redirigidos: " .. tostring(State.ShotsHit),
            "Drawing: " .. (DrawingSupported and "OK" or "NO"),
            "AutoSave: " .. (State.AutoSave and "ON" or "OFF"),
        }
        notify("Diagnóstico", table.concat(lines, " · "))
    end,
})

--──────────────────────────── VISUAL ───────────────────────────
UIRefs.ESP = TabVisual:CreateToggle({
    name = "ESP en cajas (color del equipo o personalizado)",
    currentValue = State.ESP,
    callback = function(on)
        setESP(on)
        maybeSave()
    end,
})

UIRefs.ESPName = TabVisual:CreateToggle({
    name = "ESP: mostrar nombre",
    currentValue = State.ESPName,
    callback = function(on)
        State.ESPName = on
        maybeSave()
    end,
})

UIRefs.ESPDist = TabVisual:CreateToggle({
    name = "ESP: mostrar distancia",
    currentValue = State.ESPDist,
    callback = function(on)
        State.ESPDist = on
        maybeSave()
    end,
})

UIRefs.ESPHealth = TabVisual:CreateToggle({
    name = "ESP: mostrar barra de vida",
    currentValue = State.ESPHealth,
    callback = function(on)
        State.ESPHealth = on
        maybeSave()
    end,
})

UIRefs.ESPTracers = TabVisual:CreateToggle({
    name = "ESP: tracers (líneas hasta cada jugador)",
    currentValue = State.ESPTracers,
    callback = function(on)
        State.ESPTracers = on
        maybeSave()
    end,
})

UIRefs.ESPEnemiesOnly = TabVisual:CreateToggle({
    name = "ESP: ocultar compañeros de equipo",
    currentValue = State.ESPEnemiesOnly,
    callback = function(on)
        State.ESPEnemiesOnly = on
        maybeSave()
    end,
})

UIRefs.ESPMaxDist = TabVisual:CreateSlider({
    name = "ESP: distancia máxima",
    range = { 200, 5000 },
    increment = 100,
    currentValue = State.ESPMaxDist,
    callback = function(value)
        State.ESPMaxDist = value
        maybeSave()
    end,
})

UIRefs.UseESPColor = TabVisual:CreateToggle({
    name = "ESP: usar color personalizado (en vez del color del equipo)",
    currentValue = State.UseESPColor,
    callback = function(on)
        State.UseESPColor = on
        maybeSave()
    end,
})

-- [FIX v6.5 #11] fallback real
local espPickerOk = false
if type(TabVisual.CreateColorPicker) == "function" then
    espPickerOk = pcall(function()
        UIRefs.ESPColorPicker = TabVisual:CreateColorPicker({
            name = "Color personalizado del ESP",
            color = State.ESPColor,
            callback = function(color)
                State.ESPColor = color
                maybeSave()
            end,
        })
    end)
end
if not espPickerOk then
    for _, c in ipairs({
        { label = "blanco",  color = Color3.fromRGB(255, 255, 255) },
        { label = "rojo",    color = Color3.fromRGB(255, 0, 60) },
        { label = "verde",   color = Color3.fromRGB(0, 255, 90) },
        { label = "azul",    color = Color3.fromRGB(0, 140, 255) },
        { label = "amarillo", color = Color3.fromRGB(255, 230, 0) },
    }) do
        TabVisual:CreateButton({
            name = "Color del ESP: " .. c.label,
            callback = function()
                State.ESPColor = c.color
                State.UseESPColor = true
                pcall(function()
                    if UIRefs.UseESPColor then UIRefs.UseESPColor:Set(true) end
                end)
                maybeSave()
            end,
        })
    end
end

TabVisual:CreateToggle({
    name = "Fullbright (mapa iluminado, sin niebla)",
    currentValue = State.Fullbright,
    callback = function(on)
        setFullbright(on)
        maybeSave()
    end,
})

--─────────────────────────── VARIOS ────────────────────────────
TabExtra:CreateToggle({
    name = "Deslimitar FPS (240)",
    callback = function(on)
        pcall(function()
            if setfpscap then setfpscap(on and 240 or 60) end
        end)
    end,
})

TabExtra:CreateButton({
    name = "Descargar / cerrar el Hub",
    callback = function()
        hitboxLoopRun = false
        setESP(false)
        setInstantUse(false)
        setFullbright(false)
        restoreHitbox()
        State.SilentAim = false
        State.AutoReload = false
        State.Aimbot = false
        setAimbotBinding()
        State.Hitbox = false
        -- [FIX v6.5 #3] restaurar __index del Mouse
        uninstallMouseHook()
        if antiAFKConn then
            antiAFKConn:Disconnect()
            antiAFKConn = nil
        end
        for name, conn in pairs(Conns) do
            pcall(function() conn:Disconnect() end)
            Conns[name] = nil
        end
        for tool, conn in pairs(toolConns) do
            pcall(function() conn:Disconnect() end)
            toolConns[tool] = nil
        end
        if fovGui then
            pcall(function() fovGui:Destroy() end)
            fovGui = nil
        end
        pcall(function() Rayfield:Destroy() end)
    end,
})

--─────────────────────────── CONFIG ────────────────────────────
-- [FIX v6.5 #14] sincronizar también los color pickers
local function syncUI()
    for key, el in pairs(UIRefs) do
        if el and key ~= "FOVColorPicker" and key ~= "ESPColorPicker" then
            pcall(function() el:Set(State[key]) end)
        end
    end
    if UIRefs.FOVColorPicker then
        pcall(function() UIRefs.FOVColorPicker:Set(State.FOVColor) end)
    end
    if UIRefs.ESPColorPicker then
        pcall(function() UIRefs.ESPColorPicker:Set(State.ESPColor) end)
    end
end

local function applyLoadedEffects()
    setInstantUse(State.InstantUse)
    setFullbright(State.Fullbright)
    setESP(State.ESP)
    setHitbox(State.Hitbox)
    setAimbotBinding()
    if State.MouseAim then
        installMouseHook()
    end
end

TabConfig:CreateButton({
    name = "Guardar configuración ahora",
    callback = function()
        saveConfig()
        notify("Config", "Configuración guardada en " .. CONFIG_FILE)
    end,
})

TabConfig:CreateButton({
    name = "Cargar configuración guardada",
    callback = function()
        if loadConfig() then
            syncUI()
            applyLoadedEffects()
            notify("Config", "Configuración cargada.")
        else
            notify("Config", "No hay ninguna configuración guardada.")
        end
    end,
})

TabConfig:CreateButton({
    name = "Borrar configuración guardada",
    callback = function()
        pcall(function()
            if delfile then delfile(CONFIG_FILE) end
        end)
        notify("Config", "Configuración borrada.")
    end,
})

TabConfig:CreateButton({
    name = "Restablecer todos los valores por defecto",
    callback = function()
        for k, v in pairs(DEFAULTS) do
            State[k] = v
        end
        syncUI()
        applyLoadedEffects()
        saveConfig()
        notify("Config", "Valores por defecto restaurados.")
    end,
})

-- [FIX v6.5 #5] autoguardado REAL
TabConfig:CreateToggle({
    name = "Autoguardado (se guarda solo al cambiar algo)",
    currentValue = State.AutoSave,
    callback = function(on)
        State.AutoSave = on
        -- aquí SIEMPRE guardamos para persistir el propio estado del toggle
        saveConfig()
        notify("Config", on and "Autoguardado activo." or "Autoguardado desactivado (usa Guardar ahora).")
    end,
})

--────────────────── CONEXIONES DE JUGADORES ────────────────────
addConn("PlayersAdded", Players.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if State.ESP and DrawingSupported and plr ~= LocalPlayer then
        createDrawings(plr)
    elseif State.ESP then
        attachHL(plr)
    end
    if State.Hitbox then
        task.defer(expandParts, plr)
    end
end))

addConn("PlayersRemoving", Players.PlayerRemoving:Connect(function(plr)
    clearPlayerVisual(plr)
    local tconn = teamConns[plr]
    if tconn then
        tconn:Disconnect()
        teamConns[plr] = nil
    end
    local cconn = Conns["Char_" .. plr.Name]
    if cconn then
        cconn:Disconnect()
        Conns["Char_" .. plr.Name] = nil
    end
end))

--──────────────────────── INICIO FINAL ────────────────────────
if configLoaded then
    applyLoadedEffects()
    notify("SCP Roleplay Hub v6.5", "Cargado con tu configuración guardada.")
else
    notify("SCP Roleplay Hub v6.5", "Cargado. Todo lo que actives se guardará solo.")
end