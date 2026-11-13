--[[═══════════════════════════════════════════════════════════════
      SCP ROLEPLAY HUB v8.2  |  Rayfield Gen2
      · Aimbot estable (anti-vibración):
        - AimbotRMB OFF por defecto (auto-apunta sin clic derecho)
        - Deadzone con histéresis (0.5° enter / 2° exit)
        - Alpha adaptativo por ángulo
        - Cap de rotación por frame (8° default)
        - Head position filtrada (ignora breathing)
        - FOV circle cambia de color según estado
      · Motor Exunys integrado + anti-vibración
   ═══════════════════════════════════════════════════════════════]]

local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
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
    LocalPlayer:Kick("No se pudo cargar Rayfield.")
    return
end

local Window = Rayfield:CreateWindow({
    name = "SCP Roleplay Hub",
    subtitle = "Rayfield Gen2 · v8.2",
    sidebarLayout = true,
    keySystem = true,
    keySettings = {
        title = "SCP Roleplay Hub", subtitle = "Key System",
        note = "Introduce la clave", fileName = "SCPHubKey",
        saveKey = true, grabKeyFromSite = false, key = { "20112026" },
    },
})

local TabMain    = Window:CreateTab({ name = "Principal", icon = 93364949241311 })
local TabCombat  = Window:CreateTab({ name = "Combate",   icon = 93364949241311 })
local TabVisual  = Window:CreateTab({ name = "Visual",    icon = 93364949241311 })
local TabExtra   = Window:CreateTab({ name = "Varios",    icon = 93364949241311 })
local TabConfig  = Window:CreateTab({ name = "Config",    icon = 93364949241311 })

--═══════════════════════════════════════════════════════════════
--                 ESTADO (defaults v8.2)
--═══════════════════════════════════════════════════════════════
local State = {
    AutoSave = true,
    -- ESP
    ESP = false, ESPName = true, ESPDist = true, ESPHealth = true, ESPTracers = false,
    ESPMaxDist = 2000, ESPEnemiesOnly = false,
    ESPColorMode = "Equipo del juego", ESPColor = Color3.fromRGB(255, 255, 255),
    -- Utils
    InstantUse = false, Fullbright = false,
    -- Aimbot [v8.2 defaults]
    Aimbot = false,
    AimbotRMB = false,               -- [v8.2] auto-apunta sin clic derecho
    LockMode = "CFrame",
    LockPart = "Head",
    AimSmooth = 30,                  -- [v8.2] suavizado estable
    AimDeadzone = 0.5,               -- [v8.2] tolerancia en grados
    AimMaxRotPerFrame = 8,           -- [v8.2] máx °/frame
    AimMaxDist = 5000,
    RequireWeapon = false,           -- [v8.2] OFF para no bloquear si falla gun check
    ForceScriptable = false,
    FOV = 600,                       -- [v8.2] FOV amplio
    FOVVisible = true,
    FOVFollowMouse = false,
    FOVColor = Color3.fromRGB(255, 255, 255),
    TargetPriority = "Cercano al crosshair",
    TargetIndicator = true,
    WallDetect = false,
    IgnoreTeam = false,
    SCPFriendly = false,
    ShieldMode = "Ignorar",
    -- Hitbox
    Hitbox = false, HitboxMode = "Cabeza", HitboxOnlyEnemy = false, HeadSize = 6,
    -- Auto-reload
    AutoReload = false, AutoReloadKey = "R", AutoReloadThreshold = 0,
}

local DEFAULTS = {}
for k, v in pairs(State) do DEFAULTS[k] = v end

local Highlights, ESPDraw, ESPConns, UIRefs = {}, {}, {}, {}
local ESPRender, antiAFKConn = nil, nil
local hubRunning = true

local Conns = {}
local function addConn(name, conn)
    if Conns[name] then pcall(function() Conns[name]:Disconnect() end) end
    Conns[name] = conn
    return conn
end
local function notify(t, c) pcall(function() Window:Notify({ title = t, content = c }) end) end
local function printDbg(...) pcall(function() print("[HUB]", ...) end) end

local function getHumanoid()
    local c = LocalPlayer.Character
    return c and c:FindFirstChildOfClass("Humanoid")
end
local function getRoot()
    local c = LocalPlayer.Character
    return c and c:FindFirstChild("HumanoidRootPart")
end

--═══════════════════════════════════════════════════════════════
--                        CONFIG
--═══════════════════════════════════════════════════════════════
local CONFIG_FILE = "SCPHub_Config.json"
local SAVE_KEYS = {
    "AutoSave","ESP","ESPName","ESPDist","ESPHealth","ESPTracers","ESPMaxDist","ESPEnemiesOnly",
    "ESPColorMode","ESPColor","InstantUse","Fullbright",
    "Aimbot","AimbotRMB","LockMode","LockPart","AimSmooth","AimDeadzone","AimMaxRotPerFrame",
    "AimMaxDist","RequireWeapon","ForceScriptable",
    "FOV","FOVVisible","FOVFollowMouse","FOVColor",
    "TargetPriority","TargetIndicator","WallDetect","IgnoreTeam","SCPFriendly","ShieldMode",
    "Hitbox","HitboxMode","HitboxOnlyEnemy","HeadSize",
    "AutoReload","AutoReloadKey","AutoReloadThreshold",
}

local function saveConfig()
    pcall(function()
        local data = {}
        for _, k in ipairs(SAVE_KEYS) do
            local v = State[k]
            data[k] = typeof(v) == "Color3" and { r = v.R, g = v.G, b = v.B } or v
        end
        writefile(CONFIG_FILE, HttpService:JSONEncode(data))
    end)
end
local function maybeSave() if State.AutoSave then saveConfig() end end
local function loadConfig()
    local loaded = false
    pcall(function()
        if isfile and isfile(CONFIG_FILE) then
            local data = HttpService:JSONDecode(readfile(CONFIG_FILE))
            if type(data) == "table" then
                for _, k in ipairs(SAVE_KEYS) do
                    local v = data[k]
                    if v ~= nil then
                        if type(v) == "table" and typeof(State[k]) == "Color3" then
                            State[k] = Color3.new(v.r or 1, v.g or 1, v.b or 1)
                        elseif typeof(v) == typeof(State[k]) then
                            State[k] = v
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

--═══════════════════════════════════════════════════════════════
--                     COLORES SCP:RP
--═══════════════════════════════════════════════════════════════
local SCPTeamColors = {
    { pattern = "^scp%-", c = Color3.fromRGB(150, 0, 200) },
    { pattern = "^scp$",  c = Color3.fromRGB(150, 0, 200) },
    { pattern = "chaos",  c = Color3.fromRGB(180, 30, 30) },
    { pattern = "insurgency", c = Color3.fromRGB(180, 30, 30) },
    { pattern = "mtf",    c = Color3.fromRGB(30, 100, 200) },
    { pattern = "class%-d", c = Color3.fromRGB(255, 140, 0) },
    { pattern = "scientist", c = Color3.fromRGB(180, 180, 255) },
    { pattern = "research",  c = Color3.fromRGB(180, 180, 255) },
    { pattern = "security",  c = Color3.fromRGB(60, 60, 60) },
    { pattern = "foundation", c = Color3.fromRGB(200, 200, 200) },
    { pattern = "goc",       c = Color3.fromRGB(0, 180, 80) },
    { pattern = "uiu",       c = Color3.fromRGB(200, 200, 0) },
    { pattern = "serpent",   c = Color3.fromRGB(0, 150, 150) },
}
local function getSCPTeamColor(plr)
    local lower = string.lower((plr.Team and plr.Team.Name) or "")
    for _, e in ipairs(SCPTeamColors) do
        if string.find(lower, e.pattern) then return e.c end
    end
    if plr.Team then return plr.Team.Color end
    return Color3.fromRGB(255, 255, 255)
end
local function espColorFor(plr)
    local m = State.ESPColorMode or "Equipo del juego"
    if m == "Color personalizado" then return State.ESPColor
    elseif m == "Colores SCP:RP" then return getSCPTeamColor(plr)
    else return (plr.Team and plr.Team.Color) or Color3.fromRGB(255, 255, 255) end
end

--═══════════════════════════════════════════════════════════════
--                     DEAD CHECK
--═══════════════════════════════════════════════════════════════
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

--═══════════════════════════════════════════════════════════════
--                     TEAM + SHIELD + GUN
--═══════════════════════════════════════════════════════════════
local function getTeamGroup(name)
    if not name then return nil end
    local l = string.lower(name)
    if l:find("^scp") or l:find("scp%-") then return "SCP" end
    if l:find("chaos") or l:find("insurgency") then return "Chaos" end
    if l:find("mtf") or l:find("mobile task") then return "MTF" end
    if l:find("class%-d") or l:find("class d") then return "Class-D" end
    if l:find("scientist") or l:find("research") then return "Foundation" end
    if l:find("foundation") or l:find("security") then return "Foundation" end
    if l:find("goc") or l:find("occult") then return "GOC" end
    if l:find("uiu") then return "UIU" end
    if l:find("serpent") then return "Serpent" end
    return nil
end
local function isAlly(plr)
    if not plr or plr == LocalPlayer then return true end
    if State.SCPFriendly then
        local myG = getTeamGroup(LocalPlayer.Team and LocalPlayer.Team.Name or nil)
        local theirG = getTeamGroup(plr.Team and plr.Team.Name or nil)
        if myG and theirG and myG == theirG then return true end
    end
    if LocalPlayer.Team ~= nil and plr.Team ~= nil then
        return LocalPlayer.Team == plr.Team
    end
    return false
end

local SHIELD_PATTERNS = { "shield", "riot", "ballistic", "escutcheon", "escudo", "barrier" }
local function isShieldName(name)
    if not name then return false end
    local l = string.lower(name)
    for _, pat in ipairs(SHIELD_PATTERNS) do
        if l:find(pat, 1, true) then return true end
    end
    return false
end

local NON_WEAPON = {
    "shield","riot","ballistic","escutcheon","escudo","barrier",
    "radio","keycard","key card","key_card","key-card",
    "medkit","med kit","bandage","first aid","firstaid","defib","syringe",
    "handcuff","restraint","cuff","backpack","flashlight","lantern",
    "paper","document","file","note","badge","id card","gasmask",
    "hat","helmet","vest","armor","uniform",
}
local function isNonWeapon(name)
    if not name then return true end
    local l = string.lower(name)
    for _, pat in ipairs(NON_WEAPON) do
        if l:find(pat, 1, true) then return true end
    end
    return false
end

local function hasWeaponEquipped()
    local char = LocalPlayer.Character
    if not char then return false, nil end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and not isNonWeapon(tool.Name) then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                return true, tool
            end
        end
    end
    return false, nil
end

local shieldCache = {}
local function detectShield(plr)
    if not plr then return nil end
    local now = os.clock()
    local e = shieldCache[plr]
    if e and (now - e.time) < 0.4 then return e.shield end
    local char = plr.Character
    if not char then shieldCache[plr] = { shield = nil, time = now }; return nil end
    local result = nil
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") and isShieldName(child.Name) then
            local h = child:FindFirstChild("Handle")
            if h and h:IsA("BasePart") then
                result = { instance = child, handle = h }
                break
            end
        end
    end
    shieldCache[plr] = { shield = result, time = now }
    return result
end

--═══════════════════════════════════════════════════════════════
--                          ESP
--═══════════════════════════════════════════════════════════════
local DrawingSupported = false
pcall(function()
    local t = Drawing.new("Square")
    t:Remove()
    DrawingSupported = true
end)

local function clearPlayerVisual(plr)
    local o = ESPDraw[plr]
    if o then
        for _, obj in pairs(o) do pcall(function() obj:Remove() end) end
        ESPDraw[plr] = nil
    end
    local hl = Highlights[plr]
    if hl then pcall(function() hl:Destroy() end); Highlights[plr] = nil end
    local c = ESPConns[plr]
    if c then pcall(function() c:Disconnect() end); ESPConns[plr] = nil end
end

local function createDrawings(plr)
    if ESPDraw[plr] then return end
    local box = Drawing.new("Square"); box.Thickness = 1.5; box.Filled = false; box.Transparency = 1; box.Visible = false
    local name = Drawing.new("Text"); name.Size = 13; name.Center = true; name.Outline = true; name.Visible = false
    local dist = Drawing.new("Text"); dist.Size = 12; dist.Center = true; dist.Outline = true; dist.Visible = false
    local hbg = Drawing.new("Square"); hbg.Thickness = 0; hbg.Filled = true; hbg.Color = Color3.new(); hbg.Transparency = 0.6; hbg.Visible = false
    local hp = Drawing.new("Square"); hp.Thickness = 0; hp.Filled = true; hp.Visible = false
    local tr = Drawing.new("Line"); tr.Thickness = 1.5; tr.Transparency = 1; tr.Visible = false
    ESPDraw[plr] = { box = box, name = name, dist = dist, health = hp, healthbg = hbg, tracer = tr }
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
            local hum = char and char:FindFirstChildOfClass("Humanoid")
            local visible, dist, cx, ty, bw, bh = false, 0, 0, 0, 0, 0
            if State.ESPEnemiesOnly and isAlly(plr) then char = nil end
            if char and root and hum and hum.Health > 0 and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                dist = (cam.CFrame.Position - root.Position).Magnitude
                if dist <= State.ESPMaxDist then
                    local tS = cam:WorldToViewportPoint(root.Position + Vector3.new(0, 3.4, 0))
                    local bS = cam:WorldToViewportPoint(root.Position - Vector3.new(0, 3.0, 0))
                    local cS = cam:WorldToViewportPoint(root.Position)
                    if cS.Z > 0 then
                        bh = math.abs(bS.Y - tS.Y)
                        if bh > 4 then
                            bw = bh * 0.55; cx = cS.X; ty = math.min(tS.Y, bS.Y)
                            visible = true
                        end
                    end
                end
            end
            if visible then
                local col = espColorFor(plr)
                objs.box.Position = Vector2.new(cx - bw / 2, ty)
                objs.box.Size = Vector2.new(bw, bh)
                objs.box.Color = col; objs.box.Visible = true
                if State.ESPName then
                    objs.name.Text = plr.Name
                    objs.name.Position = Vector2.new(cx, ty - 14)
                    objs.name.Color = col; objs.name.Visible = true
                else objs.name.Visible = false end
                if State.ESPDist then
                    objs.dist.Text = tostring(math.floor(dist)) .. " m"
                    objs.dist.Position = Vector2.new(cx, ty + bh + 4)
                    objs.dist.Color = Color3.new(1, 1, 1); objs.dist.Visible = true
                else objs.dist.Visible = false end
                if State.ESPHealth then
                    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local barH = bh * pct
                    objs.healthbg.Position = Vector2.new(cx - bw / 2 - 6, ty)
                    objs.healthbg.Size = Vector2.new(3, bh); objs.healthbg.Visible = true
                    objs.health.Position = Vector2.new(cx - bw / 2 - 6, ty + (bh - barH))
                    objs.health.Size = Vector2.new(3, barH)
                    objs.health.Color = Color3.fromRGB(math.floor(255 * (1 - pct)), math.floor(200 * pct), 0)
                    objs.health.Visible = true
                else
                    objs.healthbg.Visible = false; objs.health.Visible = false
                end
                if objs.tracer then
                    if State.ESPTracers then
                        local vp = cam.ViewportSize
                        objs.tracer.From = Vector2.new(vp.X / 2, vp.Y - 2)
                        objs.tracer.To = Vector2.new(cx, ty + bh)
                        objs.tracer.Color = col; objs.tracer.Visible = true
                    else objs.tracer.Visible = false end
                end
            else
                objs.box.Visible = false; objs.name.Visible = false
                objs.dist.Visible = false; objs.health.Visible = false
                objs.healthbg.Visible = false
                if objs.tracer then objs.tracer.Visible = false end
            end
        end
    end)
end

local function attachHL(plr)
    if plr == LocalPlayer then return end
    if ESPConns[plr] then ESPConns[plr]:Disconnect(); ESPConns[plr] = nil end
    local function attach(char)
        local old = Highlights[plr]
        if old then old:Destroy(); Highlights[plr] = nil end
        if not State.ESP then return end
        local hl = Instance.new("Highlight")
        hl.FillTransparency = 0.65
        hl.FillColor = espColorFor(plr)
        hl.OutlineColor = Color3.new(1, 1, 1)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        Highlights[plr] = hl
    end
    if plr.Character then attach(plr.Character) end
    ESPConns[plr] = plr.CharacterAdded:Connect(attach)
end

local function setESP(on)
    State.ESP = on
    if DrawingSupported then
        if on then
            startRenderLoop()
            for _, p in ipairs(Players:GetPlayers()) do
                if p ~= LocalPlayer then createDrawings(p) end
            end
        else
            for p in pairs(ESPDraw) do clearPlayerVisual(p) end
            if ESPRender then ESPRender:Disconnect(); ESPRender = nil end
        end
    else
        if on then
            for _, p in ipairs(Players:GetPlayers()) do attachHL(p) end
        else
            for p in pairs(Highlights) do clearPlayerVisual(p) end
            for _, c in pairs(ESPConns) do pcall(function() c:Disconnect() end) end
            ESPConns = {}
        end
    end
end

--═══════════════════════════════════════════════════════════════
--                    CÍRCULO FOV (GUI)
--═══════════════════════════════════════════════════════════════
local fovGui, fovRing, fovDot, fovStroke
pcall(function()
    local parent
    if typeof(gethui) == "function" then pcall(function() parent = gethui() end) end
    if not parent then
        local okC, cg = pcall(function() return game:GetService("CoreGui") end)
        if okC and cg then parent = cg end
    end
    if not parent then parent = LocalPlayer:WaitForChild("PlayerGui") end
    fovGui = Instance.new("ScreenGui")
    fovGui.Name = "HubFOVCircle"
    fovGui.IgnoreGuiInset = true
    fovGui.ResetOnSpawn = false
    fovGui.DisplayOrder = 9999
    fovRing = Instance.new("Frame")
    fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
    fovRing.BackgroundTransparency = 1
    fovRing.BorderSizePixel = 0
    local cr = Instance.new("UICorner")
    cr.CornerRadius = UDim.new(1, 0)
    cr.Parent = fovRing
    fovStroke = Instance.new("UIStroke")
    fovStroke.Thickness = 1.5
    fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fovStroke.Color = State.FOVColor
    fovStroke.Parent = fovRing
    fovDot = Instance.new("Frame")
    fovDot.AnchorPoint = Vector2.new(0.5, 0.5)
    fovDot.Size = UDim2.fromOffset(4, 4)
    fovDot.BackgroundColor3 = State.FOVColor
    fovDot.BackgroundTransparency = 0.2
    fovDot.BorderSizePixel = 0
    local dc = Instance.new("UICorner")
    dc.CornerRadius = UDim.new(1, 0)
    dc.Parent = fovDot
    fovRing.Parent = fovGui
    fovDot.Parent = fovGui
    fovGui.Parent = parent
    fovGui.Enabled = false
end)

-- ══════════════════════════════════════════════════════════════
--          AIMBOT v8.2 (estable, anti-vibración)
-- ══════════════════════════════════════════════════════════════
local aimState = {
    target = nil,
    locked = false,
    frameCount = 0,
    noTargetPrint = 0,
    coasting = false,
    lastAngle = 999,
    stableHeadPos = nil,
    stableHeadAt = 0,
    lastTargetName = nil,
    usingScriptable = false,
    originalCameraType = nil,
    originalSensitivity = UserInputService.MouseDeltaSensitivity,
}

local STABILITY = {
    headFilterRate = 15,
    headMoveSnap = 1.0,
    headNoiseIgnore = 0.3,
    deadzoneEnter = 0.5,
    deadzoneExit = 2.0,
    maxRotPerFrame = 8,
}

local function getStableHeadPos(target, dt)
    if not target or not target.head then return nil end
    local rawPos = target.head.Position
    local now = os.clock()

    local targetName = target.plr.Name
    if aimState.lastTargetName ~= targetName then
        aimState.lastTargetName = targetName
        aimState.stableHeadPos = rawPos
        aimState.stableHeadAt = now
        aimState.coasting = false
        aimState.lastAngle = 999
        return rawPos
    end

    if not aimState.stableHeadPos then
        aimState.stableHeadPos = rawPos
        aimState.stableHeadAt = now
        return rawPos
    end

    local delta = (rawPos - aimState.stableHeadPos).Magnitude

    if delta > STABILITY.headMoveSnap then
        aimState.stableHeadPos = rawPos
        aimState.stableHeadAt = now
        return rawPos
    end

    if delta < STABILITY.headNoiseIgnore and (now - aimState.stableHeadAt) < 0.5 then
        return aimState.stableHeadPos
    end

    local alpha = math.clamp(dt * STABILITY.headFilterRate, 0.08, 0.5)
    aimState.stableHeadPos = aimState.stableHeadPos:Lerp(rawPos, alpha)
    aimState.stableHeadAt = now
    return aimState.stableHeadPos
end

local function getLockPosition(plr)
    local char = plr.Character
    if not char then return nil end
    local part = char:FindFirstChild(State.LockPart)
    if not part then
        part = char:FindFirstChild("Head") or char:FindFirstChild("UpperTorso")
            or char:FindFirstChild("Torso") or char:FindFirstChild("HumanoidRootPart")
    end
    return part and part.Position or nil
end

local function getFovCenter(cam)
    if State.FOVFollowMouse then
        return UserInputService:GetMouseLocation()
    end
    local vp = cam.ViewportSize
    return Vector2.new(vp.X / 2, vp.Y / 2)
end

local function isWallBlocking(targetChar, position)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local blacklist = {}
    if LocalPlayer.Character then
        for _, d in ipairs(LocalPlayer.Character:GetDescendants()) do
            blacklist[#blacklist + 1] = d
        end
    end
    for _, d in ipairs(targetChar:GetDescendants()) do
        blacklist[#blacklist + 1] = d
    end
    local ok, parts = pcall(function()
        return cam:GetPartsObscuringTarget({ position }, blacklist)
    end)
    if not ok then return false end
    return parts and #parts > 0
end

local function findClosestPlayer(cam)
    local fovCenter = getFovCenter(cam)
    local camPos = cam.CFrame.Position
    local maxDist = State.AimMaxDist or 5000
    local fov = State.FOV or 600
    local priority = State.TargetPriority or "Cercano al crosshair"
    local wallDetect = State.WallDetect or false
    local ignoreTeam = State.IgnoreTeam or false

    local best, bestScore = nil, math.huge

    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local char = plr.Character
            if char then
                local head = char:FindFirstChild("Head")
                local hum = char:FindFirstChildOfClass("Humanoid")
                if head and hum and hum.Health > 0
                    and hum:GetState() ~= Enum.HumanoidStateType.Dead then
                    local skip = false
                    if ignoreTeam and isAlly(plr) then skip = true end

                    if not skip then
                        local lockPos = getLockPosition(plr)
                        if lockPos then
                            local wd = (lockPos - camPos).Magnitude
                            if wd <= maxDist then
                                local pos = cam:WorldToViewportPoint(lockPos)
                                if pos.Z > 0 then
                                    local sd = (Vector2.new(pos.X, pos.Y) - fovCenter).Magnitude
                                    if sd <= fov then
                                        local wallOk = true
                                        if wallDetect then
                                            wallOk = not isWallBlocking(char, lockPos)
                                        end
                                        if wallOk then
                                            local score
                                            if priority == "Menos HP" then score = hum.Health
                                            elseif priority == "Más cercano en studs" then score = wd
                                            else score = sd end
                                            if score < bestScore then
                                                best = { plr = plr, head = head, hum = hum,
                                                         lockPos = lockPos, score = score }
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
        end
    end
    return best
end

local function cancelLock()
    aimState.locked = false
    aimState.target = nil
    aimState.coasting = false
    aimState.stableHeadPos = nil
    aimState.lastTargetName = nil
    aimState.lastAngle = 999
end

local function aimStep(dt)
    dt = dt or 0.016
    aimState.frameCount = aimState.frameCount + 1
    if not State.Aimbot then return end

    if not isLocalAlive() then
        if aimState.locked then cancelLock() end
        return
    end
    if State.RequireWeapon and not hasWeaponEquipped() then
        if aimState.locked then cancelLock() end
        return
    end
    if State.AimbotRMB then
        if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
            if aimState.locked then cancelLock() end
            return
        end
    end

    local cam = workspace.CurrentCamera
    if not cam then return end

    if not aimState.originalCameraType then
        aimState.originalCameraType = cam.CameraType
    end

    if State.ForceScriptable and cam.CameraType ~= Enum.CameraType.Scriptable then
        pcall(function() cam.CameraType = Enum.CameraType.Scriptable end)
    end

    local target = findClosestPlayer(cam)
    if not target then
        if aimState.locked then cancelLock() end
        local now = os.clock()
        if now - aimState.noTargetPrint > 3 then
            aimState.noTargetPrint = now
            printDbg(string.format(
                "Sin target (players=%d, FOV=%d, maxDist=%d)",
                #Players:GetPlayers(), State.FOV, State.AimMaxDist
            ))
        end
        return
    end

    if aimState.target ~= target.plr then
        aimState.target = target.plr
        aimState.stableHeadPos = nil
        aimState.lastTargetName = nil
        aimState.lastAngle = 999
        printDbg("Target → " .. target.plr.Name)
        notify("Aimbot", "Target: " .. target.plr.Name)
    end
    aimState.locked = true

    local aimPos = getStableHeadPos(target, dt)
    if not aimPos then return end

    if State.ShieldMode and State.ShieldMode ~= "Ignorar" then
        local shield = detectShield(target.plr)
        if shield and shield.handle then
            if State.ShieldMode == "Romper escudo" then
                aimPos = shield.handle.Position
            elseif State.ShieldMode == "Auto (pies)" then
                local root = target.plr.Character and target.plr.Character:FindFirstChild("HumanoidRootPart")
                if root then aimPos = root.Position + Vector3.new(0, -2.5, 0) end
            end
        end
    end

    local camPos = cam.CFrame.Position
    local delta = aimPos - camPos
    if delta.Magnitude < 0.3 then return end

    local currentDir = cam.CFrame.LookVector
    local desiredDir = delta.Unit
    local dot = math.clamp(currentDir:Dot(desiredDir), -1, 1)
    local angleRad = math.acos(dot)
    local angleDeg = math.deg(angleRad)

    local deadzoneEnter = State.AimDeadzone or STABILITY.deadzoneEnter
    local deadzoneExit = deadzoneEnter * 4

    if aimState.coasting then
        if angleDeg > deadzoneExit then
            aimState.coasting = false
        end
    else
        if angleDeg < deadzoneEnter then
            aimState.coasting = true
        end
    end

    if aimState.coasting then
        if aimState.frameCount % 120 == 0 then
            printDbg(string.format("Aimbot: %s | COASTING (angle=%.2f°)", target.plr.Name, angleDeg))
        end
        return
    end

    local smooth = State.AimSmooth or 30
    local baseAlpha = math.clamp(0.9 - (smooth / 100) * 0.8, 0.1, 0.9)

    local angleFactor
    if angleDeg < 5 then
        angleFactor = math.max(0.15, angleDeg / 5)
    elseif angleDeg < 15 then
        angleFactor = 0.5 + (angleDeg - 5) / 20
    else
        angleFactor = 1.0
    end

    local finalAlpha = math.clamp(baseAlpha * angleFactor, 0.02, 0.9)

    local maxRot = math.rad(State.AimMaxRotPerFrame or STABILITY.maxRotPerFrame)
    if angleRad > maxRot then
        finalAlpha = math.min(finalAlpha, maxRot / angleRad)
    end

    local mode = State.LockMode or "CFrame"
    if mode == "mousemoverel" then
        local screenPos = cam:WorldToViewportPoint(aimPos)
        if screenPos.Z > 0 then
            local mouse = UserInputService:GetMouseLocation()
            local dx = (screenPos.X - mouse.X) * finalAlpha
            local dy = (screenPos.Y - mouse.Y) * finalAlpha
            pcall(function()
                if mousemoverel then
                    mousemoverel(dx, dy)
                elseif Input and Input.MouseMove then
                    Input.MouseMove(dx, dy)
                end
            end)
        end
    elseif mode == "mousemoveabs" then
        local screenPos = cam:WorldToViewportPoint(aimPos)
        if screenPos.Z > 0 and mousemoveabs then
            pcall(function() mousemoveabs(screenPos.X, screenPos.Y) end)
        end
    else
        local goal = CFrame.new(camPos, aimPos)
        local newCFrame = cam.CFrame:Lerp(goal, finalAlpha)
        pcall(function() cam.CFrame = newCFrame end)
    end

    if aimState.frameCount % 60 == 0 then
        printDbg(string.format(
            "Aimbot: %s | angle=%.2f° | alpha=%.3f | coasting=%s",
            target.plr.Name, angleDeg, finalAlpha, tostring(aimState.coasting)
        ))
    end
    aimState.lastAngle = angleDeg
end

local function setAimbotBinding()
    if Conns["AimbotStep"] then
        pcall(function() Conns["AimbotStep"]:Disconnect() end)
        Conns["AimbotStep"] = nil
    end
    pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)

    cancelLock()

    if aimState.usingScriptable and aimState.originalCameraType then
        pcall(function()
            local cam = workspace.CurrentCamera
            if cam then cam.CameraType = aimState.originalCameraType end
        end)
        aimState.usingScriptable = false
    end

    if State.Aimbot then
        local okBind = pcall(function()
            RunService:BindToRenderStep("HubAimbotStep", Enum.RenderPriority.Last.Value - 1, aimStep)
        end)
        if not okBind then
            addConn("AimbotStep", RunService.RenderStepped:Connect(aimStep))
            printDbg("Aimbot: RenderStepped fallback")
        else
            printDbg("Aimbot: BindToRenderStep Last-1")
        end
        printDbg(string.format(
            "Aimbot ON | RMB=%s | Smooth=%d | Deadzone=%.1f° | MaxRot=%d°",
            tostring(State.AimbotRMB), State.AimSmooth,
            State.AimDeadzone or STABILITY.deadzoneEnter,
            State.AimMaxRotPerFrame or STABILITY.maxRotPerFrame
        ))
    end
end

-- Indicador de target
local targetHighlight, lastTargetTick = nil, 0
local function clearTargetHighlight()
    if targetHighlight then
        pcall(function() targetHighlight:Destroy() end)
        targetHighlight = nil
    end
end
local function updateTargetIndicator()
    if not State.TargetIndicator or not State.Aimbot or not isLocalAlive() then
        clearTargetHighlight(); return
    end
    if State.RequireWeapon and not hasWeaponEquipped() then
        clearTargetHighlight(); return
    end
    local t = aimState.target
    if not t or not isTargetAlive(t) then clearTargetHighlight(); return end
    local char = t.Character
    local shield = detectShield(t)
    if not targetHighlight or targetHighlight.Parent ~= char then
        clearTargetHighlight()
        targetHighlight = Instance.new("Highlight")
        targetHighlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        targetHighlight.Parent = char
    end
    if shield then
        targetHighlight.OutlineColor = Color3.fromRGB(255, 140, 0)
        targetHighlight.FillColor = Color3.fromRGB(255, 180, 60)
        targetHighlight.FillTransparency = 0.85
    else
        targetHighlight.OutlineColor = State.FOVColor
        targetHighlight.FillColor = State.FOVColor
        targetHighlight.FillTransparency = 1
    end
end
addConn("TargetIndicatorLoop", RunService.Heartbeat:Connect(function()
    local now = os.clock()
    if now - lastTargetTick < 0.15 then return end
    lastTargetTick = now
    updateTargetIndicator()
end))

-- FOV render
addConn("FOVRender", RunService.RenderStepped:Connect(function()
    if not fovGui or not fovRing then return end
    if State.Aimbot and State.FOVVisible then
        local cam = workspace.CurrentCamera
        if cam then
            local center
            if State.FOVFollowMouse then
                center = UserInputService:GetMouseLocation()
            else
                local vp = cam.ViewportSize
                center = Vector2.new(vp.X / 2, vp.Y / 2)
            end
            local d = math.max(math.floor(State.FOV) * 2, 10)
            fovRing.Position = UDim2.fromOffset(center.X, center.Y)
            fovRing.Size = UDim2.fromOffset(d, d)
            fovStroke.Color = aimState.coasting
                and Color3.fromRGB(100, 255, 100)
                or (aimState.locked and Color3.fromRGB(255, 150, 150) or State.FOVColor)
            if fovDot then
                fovDot.Position = UDim2.fromOffset(center.X, center.Y)
                fovDot.BackgroundColor3 = fovStroke.Color
            end
        end
        fovGui.Enabled = true
    else
        fovGui.Enabled = false
    end
end))

--═══════════════════════════════════════════════════════════════
--                    FULLBRIGHT
--═══════════════════════════════════════════════════════════════
local LightDef = {
    Ambient = Lighting.Ambient, Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd, ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
}
local function setFullbright(on)
    State.Fullbright = on
    if on then
        Lighting.Ambient = Color3.fromRGB(200, 200, 200)
        Lighting.Brightness = 3
        Lighting.FogEnd = 100000
        Lighting.ClockTime = 14
        Lighting.GlobalShadows = false
    else
        Lighting.Ambient = LightDef.Ambient
        Lighting.Brightness = LightDef.Brightness
        Lighting.FogEnd = LightDef.FogEnd
        Lighting.ClockTime = LightDef.ClockTime
        Lighting.GlobalShadows = LightDef.GlobalShadows
    end
end

--═══════════════════════════════════════════════════════════════
--              INTERACCIÓN INSTANTÁNEA
--═══════════════════════════════════════════════════════════════
local function setPromptHold(p, zero)
    if zero then
        if p:GetAttribute("HubOriginalHold") == nil then
            p:SetAttribute("HubOriginalHold", p.HoldDuration)
        end
        p.HoldDuration = 0
    else
        local o = p:GetAttribute("HubOriginalHold")
        if o ~= nil then p.HoldDuration = o end
    end
end
local function setInstantUse(on)
    State.InstantUse = on
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("ProximityPrompt") then setPromptHold(o, on) end
    end
end
addConn("Prompts", workspace.DescendantAdded:Connect(function(o)
    if o:IsA("ProximityPrompt") and State.InstantUse then
        task.defer(setPromptHold, o, true)
    end
end))

--═══════════════════════════════════════════════════════════════
--                    AUTO RELOAD
--═══════════════════════════════════════════════════════════════
local AR = { lastReloadTime = 0, lastAmmo = -1, currentTool = nil, attempts = 0, confirmedEmpty = false }
local AMMO_ATTRS = { "Ammo","AmmoCount","Magazine","MagazineAmmo","Clip","CurrentAmmo","Bullets","Rounds" }
local AMMO_PATTERNS = { "^ammo","^currentammo","^magazine","^mag","^clip","^bullets","^rounds","^shots" }

local function readAmmo(tool)
    if not tool then return nil end
    for _, n in ipairs(AMMO_ATTRS) do
        local v = tool:GetAttribute(n)
        if type(v) == "number" then return v end
    end
    local cached = tool:GetAttribute("__HubAmmoInst")
    if typeof(cached) == "Instance" and cached.Parent then return cached.Value end
    for _, o in ipairs(tool:GetDescendants()) do
        if o:IsA("IntValue") or o:IsA("NumberValue") then
            local l = o.Name:lower()
            for _, pat in ipairs(AMMO_PATTERNS) do
                if l:match(pat) then
                    pcall(function() tool:SetAttribute("__HubAmmoInst", o) end)
                    return o.Value
                end
            end
        end
    end
    return nil
end

local function readMaxAmmo(tool)
    for _, n in ipairs({ "MaxAmmo","MaxMagazine","MagazineSize","ClipSize","MaxClip" }) do
        local v = tool:GetAttribute(n)
        if type(v) == "number" and v > 0 then return v end
    end
    return nil
end

local function sendReloadKey()
    local keyName = State.AutoReloadKey or "R"
    local kc = Enum.KeyCode[keyName] or Enum.KeyCode.R
    local ok = false
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, kc, false, game)
        task.wait(0.04)
        vim:SendKeyEvent(false, kc, false, game)
        ok = true
    end)
    if not ok then
        pcall(function()
            keypress(kc.Value); task.wait(0.04); keyrelease(kc.Value)
        end)
    end
end

local function trySendReload()
    local now = os.clock()
    if now - AR.lastReloadTime < 1.2 then return end
    AR.lastReloadTime = now
    AR.attempts = AR.attempts + 1
    sendReloadKey()
end

local function checkAutoReload(tool)
    if not State.AutoReload or not tool then return end
    if not isLocalAlive() then return end
    local ammo = readAmmo(tool)
    if ammo == nil then return end
    if AR.currentTool ~= tool then
        AR.currentTool = tool
        AR.attempts = 0
        AR.confirmedEmpty = false
        AR.lastAmmo = ammo
    end
    if AR.lastAmmo >= 0 and ammo > AR.lastAmmo then
        AR.attempts = 0
        AR.confirmedEmpty = false
    end
    if AR.attempts >= 5 and ammo == AR.lastAmmo then AR.confirmedEmpty = true end
    if AR.confirmedEmpty and ammo == AR.lastAmmo then return end
    local threshold = State.AutoReloadThreshold or 0
    local maxAmmo = readMaxAmmo(tool)
    local shouldReload = false
    if threshold <= 0 then
        shouldReload = (ammo <= 0)
    elseif maxAmmo then
        shouldReload = (ammo <= maxAmmo * (threshold / 100)) and (ammo < maxAmmo)
    else
        shouldReload = (ammo <= threshold)
    end
    if shouldReload then trySendReload() end
    AR.lastAmmo = ammo
end

task.spawn(function()
    while hubRunning do
        task.wait(0.1)
        if State.AutoReload then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then checkAutoReload(tool) else AR.currentTool = nil end
        end
    end
end)

--═══════════════════════════════════════════════════════════════
--                       HITBOX
--═══════════════════════════════════════════════════════════════
local hitboxParts = {}
local function partsForHitbox(char)
    local found = {}
    if State.HitboxMode == "Cabeza" then
        local h = char:FindFirstChild("Head")
        if h then table.insert(found, h) end
    elseif State.HitboxMode == "Parte invisible" then
        local r = char:FindFirstChild("HumanoidRootPart")
        if r then table.insert(found, r) end
    else
        for _, n in ipairs({
            "Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart",
            "Left Arm","Right Arm","Left Leg","Right Leg",
            "LeftUpperArm","RightUpperArm","LeftLowerArm","RightLowerArm",
            "LeftHand","RightHand","LeftUpperLeg","RightUpperLeg",
            "LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot",
        }) do
            local p = char:FindFirstChild(n)
            if p then table.insert(found, p) end
        end
    end
    return found
end

local function expandParts(plr)
    if plr == LocalPlayer then return end
    if not isLocalAlive() then return end
    if not isTargetAlive(plr) then return end
    if State.HitboxOnlyEnemy and isAlly(plr) then return end
    local char = plr.Character
    if not char then return end
    for _, part in ipairs(partsForHitbox(char)) do
        if hitboxParts[part] == nil then
            hitboxParts[part] = {
                size = part.Size, massless = part.Massless,
                cancollide = part.CanCollide, canquery = part.CanQuery,
            }
        end
        pcall(function()
            part.Size = Vector3.new(State.HeadSize, State.HeadSize, State.HeadSize)
            part.CanQuery = true
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
                part.Size = rec.size
                part.Massless = rec.massless
                part.CanCollide = rec.cancollide
                part.CanQuery = rec.canquery
            end)
        end
    end
    hitboxParts = {}
end

local function reapplyHitbox()
    restoreHitbox()
    if State.Hitbox then
        for _, p in ipairs(Players:GetPlayers()) do expandParts(p) end
    end
end

local function setHitbox(on)
    State.Hitbox = on
    if on then
        for _, p in ipairs(Players:GetPlayers()) do expandParts(p) end
        notify("Combate", "Hitbox activo (" .. State.HitboxMode .. ").")
    else
        restoreHitbox()
    end
end

task.spawn(function()
    while hubRunning do
        task.wait(0.5)
        if State.Hitbox and isLocalAlive() then
            for part in pairs(hitboxParts) do
                if not part.Parent then hitboxParts[part] = nil end
            end
            for _, p in ipairs(Players:GetPlayers()) do expandParts(p) end
        end
    end
end)

--═══════════════════════════════════════════════════════════════
--                          TP
--═══════════════════════════════════════════════════════════════
local function teleportToSpawn()
    local root = getRoot()
    if not root then notify("Jugador", "Sin personaje."); return end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("SpawnLocation") then
            root.CFrame = o.CFrame + Vector3.new(0, 5, 0)
            notify("Jugador", "Teletransportado al spawn.")
            return
        end
    end
    notify("Jugador", "No se encontró ningún spawn.")
end

local function teleportToPlayer(p)
    if not p then notify("TP", "Selecciona un jugador primero."); return end
    if not isTargetAlive(p) then notify("TP", p.Name .. " no tiene personaje vivo."); return end
    local mr = getRoot()
    local tr = p.Character:FindFirstChild("HumanoidRootPart")
    if not mr or not tr then notify("TP", "Falta HumanoidRootPart."); return end
    mr.CFrame = tr.CFrame + Vector3.new(0, 3, 0)
    notify("TP", "Teletransportado a " .. p.Name)
end

--═══════════════════════════════════════════════════════════════
--                    UI: PRINCIPAL
--═══════════════════════════════════════════════════════════════
TabMain:CreateToggle({
    name = "Interacción instantánea (E sin mantener)",
    currentValue = State.InstantUse,
    callback = function(on) setInstantUse(on); maybeSave() end,
})
TabMain:CreateToggle({
    name = "Anti-AFK",
    callback = function(on)
        if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
        if on then
            antiAFKConn = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        end
    end,
})
TabMain:CreateButton({
    name = "Reconectar al servidor",
    callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end,
})
TabMain:CreateButton({ name = "Ir al spawn", callback = teleportToSpawn })
TabMain:CreateButton({
    name = "Reaparecer",
    callback = function() local h = getHumanoid(); if h then h.Health = 0 end end,
})

--═══════════════════════════════════════════════════════════════
--                    UI: COMBATE
--═══════════════════════════════════════════════════════════════
UIRefs.Aimbot = TabCombat:CreateToggle({
    name = "🎯 Aimbot de cámara",
    currentValue = State.Aimbot,
    callback = function(on) State.Aimbot = on; setAimbotBinding(); maybeSave() end,
})
UIRefs.AimbotRMB = TabCombat:CreateToggle({
    name = "Aimbot solo con clic derecho mantenido",
    currentValue = State.AimbotRMB,
    callback = function(on) State.AimbotRMB = on; maybeSave() end,
})
UIRefs.RequireWeapon = TabCombat:CreateToggle({
    name = "Gun check (solo con arma equipada)",
    currentValue = State.RequireWeapon,
    callback = function(on) State.RequireWeapon = on; maybeSave() end,
})
UIRefs.ForceScriptable = TabCombat:CreateToggle({
    name = "Forzar CameraType Scriptable (si la cámara no se mueve)",
    currentValue = State.ForceScriptable,
    callback = function(on)
        State.ForceScriptable = on
        if not on then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam and cam.CameraType == Enum.CameraType.Scriptable then
                    cam.CameraType = Enum.CameraType.Custom
                end
            end)
            aimState.usingScriptable = false
        end
        maybeSave()
    end,
})

-- LockMode
local lockModeOk = false
if type(TabCombat.CreateDropdown) == "function" then
    lockModeOk = pcall(function()
        UIRefs.LockMode = TabCombat:CreateDropdown({
            name = "Modo de lock",
            options = { "CFrame", "mousemoverel", "mousemoveabs" },
            currentOption = { State.LockMode },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then
                    State.LockMode = tostring(v)
                    notify("Combate", "LockMode: " .. State.LockMode)
                    maybeSave()
                end
            end,
        })
    end)
end
if not lockModeOk then
    TabCombat:CreateButton({
        name = "Cambiar LockMode",
        callback = function()
            local ord = { "CFrame", "mousemoverel", "mousemoveabs" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.LockMode then i = k; break end end
            State.LockMode = ord[(i % #ord) + 1]
            notify("Combate", "LockMode: " .. State.LockMode)
            maybeSave()
        end,
    })
end

-- LockPart
local lockPartOk = false
if type(TabCombat.CreateDropdown) == "function" then
    lockPartOk = pcall(function()
        UIRefs.LockPart = TabCombat:CreateDropdown({
            name = "Parte del cuerpo a lockear",
            options = { "Head", "UpperTorso", "HumanoidRootPart" },
            currentOption = { State.LockPart },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then State.LockPart = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not lockPartOk then
    TabCombat:CreateButton({
        name = "Cambiar LockPart",
        callback = function()
            local ord = { "Head", "UpperTorso", "HumanoidRootPart" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.LockPart then i = k; break end end
            State.LockPart = ord[(i % #ord) + 1]
            notify("Combate", "LockPart: " .. State.LockPart)
            maybeSave()
        end,
    })
end

UIRefs.AimSmooth = TabCombat:CreateSlider({
    name = "Suavidad (0 = snappy, 100 = muy suave)",
    range = { 0, 100 }, increment = 5,
    currentValue = State.AimSmooth,
    callback = function(v) State.AimSmooth = v; maybeSave() end,
})
UIRefs.AimDeadzone = TabCombat:CreateSlider({
    name = "Tolerancia (° antes de corregir)",
    range = { 0.1, 5 }, increment = 0.1,
    currentValue = State.AimDeadzone,
    callback = function(v) State.AimDeadzone = v; maybeSave() end,
})
UIRefs.AimMaxRotPerFrame = TabCombat:CreateSlider({
    name = "Velocidad máx de giro (°/frame)",
    range = { 2, 30 }, increment = 1,
    currentValue = State.AimMaxRotPerFrame,
    callback = function(v) State.AimMaxRotPerFrame = v; maybeSave() end,
})
UIRefs.AimMaxDist = TabCombat:CreateSlider({
    name = "Distancia máxima (studs)",
    range = { 50, 5000 }, increment = 50,
    currentValue = State.AimMaxDist,
    callback = function(v) State.AimMaxDist = v; maybeSave() end,
})
UIRefs.FOV = TabCombat:CreateSlider({
    name = "FOV del aim (radio px)",
    range = { 10, 800 }, increment = 10,
    currentValue = State.FOV,
    callback = function(v) State.FOV = v; maybeSave() end,
})
UIRefs.FOVVisible = TabCombat:CreateToggle({
    name = "Mostrar círculo del FOV",
    currentValue = State.FOVVisible,
    callback = function(on) State.FOVVisible = on; maybeSave() end,
})
UIRefs.FOVFollowMouse = TabCombat:CreateToggle({
    name = "FOV circle sigue al mouse",
    currentValue = State.FOVFollowMouse,
    callback = function(on) State.FOVFollowMouse = on; maybeSave() end,
})

local pickerOk = false
if type(TabCombat.CreateColorPicker) == "function" then
    pickerOk = pcall(function()
        UIRefs.FOVColorPicker = TabCombat:CreateColorPicker({
            name = "Color del círculo",
            color = State.FOVColor,
            callback = function(c) State.FOVColor = c; maybeSave() end,
        })
    end)
end
if not pickerOk then
    for _, c in ipairs({
        { l = "cian", c = Color3.fromRGB(0, 255, 255) },
        { l = "rojo", c = Color3.fromRGB(255, 0, 60) },
        { l = "verde", c = Color3.fromRGB(0, 255, 90) },
        { l = "blanco", c = Color3.fromRGB(255, 255, 255) },
    }) do
        TabCombat:CreateButton({
            name = "Color círculo: " .. c.l,
            callback = function() State.FOVColor = c.c; maybeSave() end,
        })
    end
end

local prioOk = false
if type(TabCombat.CreateDropdown) == "function" then
    prioOk = pcall(function()
        UIRefs.TargetPriority = TabCombat:CreateDropdown({
            name = "Prioridad de objetivo",
            options = { "Cercano al crosshair", "Menos HP", "Más cercano en studs" },
            currentOption = { State.TargetPriority },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then State.TargetPriority = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not prioOk then
    TabCombat:CreateButton({
        name = "Cambiar prioridad",
        callback = function()
            local ord = { "Cercano al crosshair", "Menos HP", "Más cercano en studs" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.TargetPriority then i = k; break end end
            State.TargetPriority = ord[(i % #ord) + 1]
            notify("Combate", "Prioridad: " .. State.TargetPriority)
            maybeSave()
        end,
    })
end

UIRefs.TargetIndicator = TabCombat:CreateToggle({
    name = "Marcar objetivo actual",
    currentValue = State.TargetIndicator,
    callback = function(on) State.TargetIndicator = on; if not on then clearTargetHighlight() end; maybeSave() end,
})
UIRefs.WallDetect = TabCombat:CreateToggle({
    name = "Wall detect (LOS)",
    currentValue = State.WallDetect,
    callback = function(on) State.WallDetect = on; maybeSave() end,
})
UIRefs.IgnoreTeam = TabCombat:CreateToggle({
    name = "Ignorar aliados",
    currentValue = State.IgnoreTeam,
    callback = function(on) State.IgnoreTeam = on; maybeSave() end,
})
UIRefs.SCPFriendly = TabCombat:CreateToggle({
    name = "SCP friendly (agrupar por facción)",
    currentValue = State.SCPFriendly,
    callback = function(on) State.SCPFriendly = on; maybeSave() end,
})

local shieldDropOk = false
if type(TabCombat.CreateDropdown) == "function" then
    shieldDropOk = pcall(function()
        UIRefs.ShieldMode = TabCombat:CreateDropdown({
            name = "Modo escudo (MTF/Alpha-1)",
            options = { "Ignorar", "Auto (pies)", "Romper escudo" },
            currentOption = { State.ShieldMode },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then
                    State.ShieldMode = tostring(v)
                    shieldCache = {}
                    maybeSave()
                end
            end,
        })
    end)
end
if not shieldDropOk then
    TabCombat:CreateButton({
        name = "Cambiar modo escudo",
        callback = function()
            local ord = { "Ignorar", "Auto (pies)", "Romper escudo" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.ShieldMode then i = k; break end end
            State.ShieldMode = ord[(i % #ord) + 1]
            shieldCache = {}
            notify("Combate", "Modo escudo: " .. State.ShieldMode)
            maybeSave()
        end,
    })
end

UIRefs.Hitbox = TabCombat:CreateToggle({
    name = "Hitbox expander",
    currentValue = State.Hitbox,
    callback = function(on) setHitbox(on); maybeSave() end,
})
local dropOk = false
if type(TabCombat.CreateDropdown) == "function" then
    dropOk = pcall(function()
        UIRefs.HitboxMode = TabCombat:CreateDropdown({
            name = "Modo hitbox",
            options = { "Cabeza", "Parte invisible", "Cuerpo completo" },
            currentOption = { State.HitboxMode },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then
                    State.HitboxMode = tostring(v)
                    reapplyHitbox()
                    maybeSave()
                end
            end,
        })
    end)
end
if not dropOk then
    TabCombat:CreateButton({
        name = "Cambiar modo hitbox",
        callback = function()
            local ord = { "Cabeza", "Parte invisible", "Cuerpo completo" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.HitboxMode then i = k; break end end
            State.HitboxMode = ord[(i % #ord) + 1]
            reapplyHitbox()
            notify("Combate", "Hitbox: " .. State.HitboxMode)
            maybeSave()
        end,
    })
end
UIRefs.HitboxOnlyEnemy = TabCombat:CreateToggle({
    name = "Hitbox solo en enemigos",
    currentValue = State.HitboxOnlyEnemy,
    callback = function(on) State.HitboxOnlyEnemy = on; reapplyHitbox(); maybeSave() end,
})
UIRefs.HeadSize = TabCombat:CreateSlider({
    name = "Tamaño del hitbox",
    range = { 2, 20 }, increment = 0.5,
    currentValue = State.HeadSize,
    callback = function(v)
        State.HeadSize = v
        if State.Hitbox then
            for _, p in ipairs(Players:GetPlayers()) do expandParts(p) end
        end
        maybeSave()
    end,
})

UIRefs.AutoReload = TabCombat:CreateToggle({
    name = "Auto Recarga",
    currentValue = State.AutoReload,
    callback = function(on)
        State.AutoReload = on
        AR.attempts = 0; AR.confirmedEmpty = false; AR.currentTool = nil
        maybeSave()
    end,
})
UIRefs.AutoReloadThreshold = TabCombat:CreateSlider({
    name = "Auto Recarga: umbral % (0 = vacío)",
    range = { 0, 90 }, increment = 5,
    currentValue = State.AutoReloadThreshold,
    callback = function(v) State.AutoReloadThreshold = v; maybeSave() end,
})
local keyDropOk = false
if type(TabCombat.CreateDropdown) == "function" then
    keyDropOk = pcall(function()
        UIRefs.AutoReloadKey = TabCombat:CreateDropdown({
            name = "Auto Recarga: tecla",
            options = { "R", "Tab", "X", "F", "E", "Q" },
            currentOption = { State.AutoReloadKey },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then State.AutoReloadKey = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not keyDropOk then
    TabCombat:CreateButton({
        name = "Cambiar tecla recarga",
        callback = function()
            local ord = { "R", "Tab", "X", "F", "E", "Q" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.AutoReloadKey then i = k; break end end
            State.AutoReloadKey = ord[(i % #ord) + 1]
            notify("Combate", "Tecla: " .. State.AutoReloadKey)
            maybeSave()
        end,
    })
end

TabCombat:CreateButton({
    name = "🛠 Diagnóstico",
    callback = function()
        local exec = "desconocido"
        pcall(function() exec = (identifyexecutor and identifyexecutor()) or "desconocido" end)
        local weaponOk, weaponTool = hasWeaponEquipped()
        local cam = workspace.CurrentCamera
        local lines = {
            "Exec: " .. tostring(exec),
            "Local vivo: " .. (isLocalAlive() and "SÍ" or "NO"),
            "Arma: " .. (weaponOk and (weaponTool and weaponTool.Name or "sí") or "NINGUNA"),
            "Target: " .. (aimState.target and aimState.target.Name or "ninguno"),
            "Locked: " .. tostring(aimState.locked),
            "Coasting: " .. tostring(aimState.coasting),
            "Angle: " .. string.format("%.2f°", aimState.lastAngle or 999),
            "Frames: " .. tostring(aimState.frameCount),
            "LockMode: " .. State.LockMode,
            "LockPart: " .. State.LockPart,
            "Deadzone: " .. tostring(State.AimDeadzone or 0.5) .. "°",
            "MaxRot: " .. tostring(State.AimMaxRotPerFrame or 8) .. "°/frame",
            "CameraType: " .. tostring(cam and cam.CameraType),
            "RMB req: " .. tostring(State.AimbotRMB),
            "FOV: " .. State.FOV .. "px (" .. (State.FOVFollowMouse and "mouse" or "centro") .. ")",
            "Drawing: " .. (DrawingSupported and "OK" or "NO"),
        }
        notify("Diagnóstico", table.concat(lines, " · "))
        printDbg("═══ DIAGNÓSTICO ═══")
        for _, l in ipairs(lines) do printDbg(l) end
    end,
})

--═══════════════════════════════════════════════════════════════
--                    UI: VISUAL
--═══════════════════════════════════════════════════════════════
UIRefs.ESP = TabVisual:CreateToggle({
    name = "ESP en cajas",
    currentValue = State.ESP,
    callback = function(on) setESP(on); maybeSave() end,
})
local espDropOk = false
if type(TabVisual.CreateDropdown) == "function" then
    espDropOk = pcall(function()
        UIRefs.ESPColorMode = TabVisual:CreateDropdown({
            name = "Modo de color del ESP",
            options = { "Equipo del juego", "Colores SCP:RP", "Color personalizado" },
            currentOption = { State.ESPColorMode },
            multipleOptions = false,
            callback = function(o)
                local v = type(o) == "table" and o[1] or o
                if v and v ~= "" then State.ESPColorMode = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not espDropOk then
    TabVisual:CreateButton({
        name = "Cambiar modo color ESP",
        callback = function()
            local ord = { "Equipo del juego", "Colores SCP:RP", "Color personalizado" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.ESPColorMode then i = k; break end end
            State.ESPColorMode = ord[(i % #ord) + 1]
            notify("Visual", "Color ESP: " .. State.ESPColorMode)
            maybeSave()
        end,
    })
end
UIRefs.ESPName = TabVisual:CreateToggle({ name = "ESP: nombre",
    currentValue = State.ESPName, callback = function(on) State.ESPName = on; maybeSave() end })
UIRefs.ESPDist = TabVisual:CreateToggle({ name = "ESP: distancia",
    currentValue = State.ESPDist, callback = function(on) State.ESPDist = on; maybeSave() end })
UIRefs.ESPHealth = TabVisual:CreateToggle({ name = "ESP: barra vida",
    currentValue = State.ESPHealth, callback = function(on) State.ESPHealth = on; maybeSave() end })
UIRefs.ESPTracers = TabVisual:CreateToggle({ name = "ESP: tracers",
    currentValue = State.ESPTracers, callback = function(on) State.ESPTracers = on; maybeSave() end })
UIRefs.ESPEnemiesOnly = TabVisual:CreateToggle({ name = "ESP: ocultar aliados",
    currentValue = State.ESPEnemiesOnly, callback = function(on) State.ESPEnemiesOnly = on; maybeSave() end })
UIRefs.ESPMaxDist = TabVisual:CreateSlider({ name = "ESP: distancia máx",
    range = { 200, 5000 }, increment = 100, currentValue = State.ESPMaxDist,
    callback = function(v) State.ESPMaxDist = v; maybeSave() end })
local espPickerOk = false
if type(TabVisual.CreateColorPicker) == "function" then
    espPickerOk = pcall(function()
        UIRefs.ESPColorPicker = TabVisual:CreateColorPicker({
            name = "Color personalizado ESP",
            color = State.ESPColor,
            callback = function(c) State.ESPColor = c; maybeSave() end,
        })
    end)
end
if not espPickerOk then
    for _, c in ipairs({
        { l = "blanco", c = Color3.fromRGB(255, 255, 255) },
        { l = "rojo", c = Color3.fromRGB(255, 0, 60) },
        { l = "verde", c = Color3.fromRGB(0, 255, 90) },
        { l = "azul", c = Color3.fromRGB(0, 140, 255) },
        { l = "amarillo", c = Color3.fromRGB(255, 230, 0) },
    }) do
        TabVisual:CreateButton({
            name = "Color ESP: " .. c.l,
            callback = function()
                State.ESPColor = c.c
                State.ESPColorMode = "Color personalizado"
                pcall(function() if UIRefs.ESPColorMode then UIRefs.ESPColorMode:Set("Color personalizado") end end)
                maybeSave()
            end,
        })
    end
end
TabVisual:CreateToggle({
    name = "Fullbright",
    currentValue = State.Fullbright,
    callback = function(on) setFullbright(on); maybeSave() end,
})

--═══════════════════════════════════════════════════════════════
--                    UI: VARIOS
--═══════════════════════════════════════════════════════════════
TabExtra:CreateToggle({
    name = "Deslimitar FPS (240)",
    callback = function(on)
        pcall(function() if setfpscap then setfpscap(on and 240 or 60) end end)
    end,
})
local selectedPlayerName
local playerOptions = {}
local function refreshPlayerOptions()
    playerOptions = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(playerOptions, p.Name) end
    end
    if UIRefs.PlayerDropdown then
        pcall(function() UIRefs.PlayerDropdown:Refresh(playerOptions) end)
    end
end
if type(TabExtra.CreateDropdown) == "function" then
    pcall(function()
        UIRefs.PlayerDropdown = TabExtra:CreateDropdown({
            name = "Jugador para TP",
            options = playerOptions,
            currentOption = {},
            multipleOptions = false,
            callback = function(o)
                selectedPlayerName = type(o) == "table" and o[1] or o
            end,
        })
    end)
end
TabExtra:CreateButton({
    name = "Refrescar lista",
    callback = function()
        refreshPlayerOptions()
        notify("TP", #playerOptions .. " jugadores.")
    end,
})
TabExtra:CreateButton({
    name = "TP al seleccionado",
    callback = function()
        if not selectedPlayerName then notify("TP", "Selecciona un jugador."); return end
        teleportToPlayer(Players:FindFirstChild(selectedPlayerName))
    end,
})
TabExtra:CreateButton({
    name = "TP al más cercano",
    callback = function()
        local mr = getRoot()
        if not mr then notify("TP", "Sin personaje."); return end
        local best, bd = nil, math.huge
        for _, p in ipairs(Players:GetPlayers()) do
            if p ~= LocalPlayer and p.Character then
                local r = p.Character:FindFirstChild("HumanoidRootPart")
                if r then
                    local d = (r.Position - mr.Position).Magnitude
                    if d < bd then best, bd = p, d end
                end
            end
        end
        if best then teleportToPlayer(best) else notify("TP", "No hay otros.") end
    end,
})

--═══════════════════════════════════════════════════════════════
--                    UI: CONFIG
--═══════════════════════════════════════════════════════════════
local function syncUI()
    for k, el in pairs(UIRefs) do
        if el and k ~= "FOVColorPicker" and k ~= "ESPColorPicker" and k ~= "PlayerDropdown" then
            pcall(function() el:Set(State[k]) end)
        end
    end
    if UIRefs.FOVColorPicker then pcall(function() UIRefs.FOVColorPicker:Set(State.FOVColor) end) end
    if UIRefs.ESPColorPicker then pcall(function() UIRefs.ESPColorPicker:Set(State.ESPColor) end) end
end

local function applyLoadedEffects()
    setInstantUse(State.InstantUse)
    setFullbright(State.Fullbright)
    setESP(State.ESP)
    setHitbox(State.Hitbox)
    setAimbotBinding()
end

TabConfig:CreateButton({
    name = "Guardar configuración",
    callback = function() saveConfig(); notify("Config", "Guardado.") end,
})
TabConfig:CreateButton({
    name = "Cargar configuración",
    callback = function()
        if loadConfig() then
            syncUI()
            applyLoadedEffects()
            notify("Config", "Cargado.")
        else
            notify("Config", "No hay config.")
        end
    end,
})
TabConfig:CreateButton({
    name = "Borrar configuración",
    callback = function()
        pcall(function() if delfile then delfile(CONFIG_FILE) end end)
        notify("Config", "Borrado.")
    end,
})
TabConfig:CreateButton({
    name = "Restablecer defaults",
    callback = function()
        for k, v in pairs(DEFAULTS) do State[k] = v end
        syncUI()
        applyLoadedEffects()
        saveConfig()
        notify("Config", "Defaults.")
    end,
})
TabConfig:CreateToggle({
    name = "Autoguardado",
    currentValue = State.AutoSave,
    callback = function(on) State.AutoSave = on; saveConfig() end,
})

TabConfig:CreateButton({ name = "────── Atajos ──────", callback = function() end })
local function bindKey(name, keyName, cb)
    local kc = Enum.KeyCode[keyName]
    if not kc then return end
    addConn("KB_" .. name, UserInputService.InputBegan:Connect(function(input, gpe)
        if not gpe and input.KeyCode == kc then cb() end
    end))
    TabConfig:CreateButton({ name = "🔑 " .. name .. " [" .. keyName .. "]", callback = cb })
end
bindKey("Toggle Aimbot", "X", function()
    State.Aimbot = not State.Aimbot
    setAimbotBinding()
    pcall(function() if UIRefs.Aimbot then UIRefs.Aimbot:Set(State.Aimbot) end end)
    notify("Keybind", "Aimbot: " .. (State.Aimbot and "ON" or "OFF"))
    maybeSave()
end)
bindKey("Toggle ESP", "V", function()
    State.ESP = not State.ESP
    setESP(State.ESP)
    pcall(function() if UIRefs.ESP then UIRefs.ESP:Set(State.ESP) end end)
    notify("Keybind", "ESP: " .. (State.ESP and "ON" or "OFF"))
    maybeSave()
end)
bindKey("Toggle Hitbox", "B", function()
    State.Hitbox = not State.Hitbox
    setHitbox(State.Hitbox)
    pcall(function() if UIRefs.Hitbox then UIRefs.Hitbox:Set(State.Hitbox) end end)
    notify("Keybind", "Hitbox: " .. (State.Hitbox and "ON" or "OFF"))
    maybeSave()
end)
bindKey("Toggle Fullbright", "N", function()
    State.Fullbright = not State.Fullbright
    setFullbright(State.Fullbright)
    notify("Keybind", "Fullbright: " .. (State.Fullbright and "ON" or "OFF"))
    maybeSave()
end)

--═══════════════════════════════════════════════════════════════
--                    UNLOAD
--═══════════════════════════════════════════════════════════════
TabExtra:CreateButton({
    name = "Descargar / cerrar el Hub",
    callback = function()
        hubRunning = false
        setESP(false)
        setInstantUse(false)
        setFullbright(false)
        restoreHitbox()
        State.Aimbot = false
        State.Hitbox = false
        State.AutoReload = false
        setAimbotBinding()
        clearTargetHighlight()
        shieldCache = {}
        -- Restaurar sensibilidad
        pcall(function()
            UserInputService.MouseDeltaSensitivity = aimState.originalSensitivity
        end)
        -- Restaurar CameraType
        if aimState.originalCameraType then
            pcall(function()
                local cam = workspace.CurrentCamera
                if cam then cam.CameraType = aimState.originalCameraType end
            end)
        end
        if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
        for name, conn in pairs(Conns) do
            pcall(function() conn:Disconnect() end)
            Conns[name] = nil
        end
        if fovGui then pcall(function() fovGui:Destroy() end); fovGui = nil end
        pcall(function() Rayfield:Destroy() end)
    end,
})

--═══════════════════════════════════════════════════════════════
--              CONEXIONES DE JUGADORES
--═══════════════════════════════════════════════════════════════
local teamConns = {}
local function watchPlayer(plr)
    addConn("Char_" .. plr.Name, plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if State.Hitbox then expandParts(plr) end
        if State.ESP and not DrawingSupported then attachHL(plr) end
        shieldCache[plr] = nil
    end))
    teamConns[plr] = plr:GetPropertyChangedSignal("Team"):Connect(function()
        if State.Hitbox and State.HitboxOnlyEnemy then task.defer(reapplyHitbox) end
        shieldCache[plr] = nil
    end)
end
for _, p in ipairs(Players:GetPlayers()) do watchPlayer(p) end
addConn("PlayersAdded", Players.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if State.ESP and DrawingSupported and plr ~= LocalPlayer then createDrawings(plr)
    elseif State.ESP then attachHL(plr) end
    if State.Hitbox then task.defer(expandParts, plr) end
    task.defer(refreshPlayerOptions)
end))
addConn("PlayersRemoving", Players.PlayerRemoving:Connect(function(plr)
    clearPlayerVisual(plr)
    shieldCache[plr] = nil
    local tc = teamConns[plr]
    if tc then tc:Disconnect(); teamConns[plr] = nil end
    local cc = Conns["Char_" .. plr.Name]
    if cc then cc:Disconnect(); Conns["Char_" .. plr.Name] = nil end
    task.defer(refreshPlayerOptions)
end))

--═══════════════════════════════════════════════════════════════
--                    INICIO
--═══════════════════════════════════════════════════════════════
task.defer(refreshPlayerOptions)

if configLoaded then
    applyLoadedEffects()
    notify("SCP Hub v8.2", "Cargado con config guardada.")
else
    notify("SCP Hub v8.2", "Cargado. AimbotRMB OFF por defecto (auto-apunta).")
end

printDbg("═══════════════════════════════════════════════")
printDbg("SCP Hub v8.2 — Aimbot anti-vibración")
printDbg("· AimbotRMB: " .. tostring(State.AimbotRMB) .. " (OFF = auto-apunta)")
printDbg("· LockMode: " .. State.LockMode)
printDbg("· LockPart: " .. State.LockPart)
printDbg("· AimSmooth: " .. State.AimSmooth)
printDbg("· Deadzone: " .. tostring(State.AimDeadzone) .. "°")
printDbg("· MaxRotPerFrame: " .. tostring(State.AimMaxRotPerFrame) .. "°")
printDbg("· FOV: " .. State.FOV .. "px")
printDbg("· RequireWeapon: " .. tostring(State.RequireWeapon))
printDbg("═══════════════════════════════════════════════")
printDbg("Ajusta si vibra: sube Deadzone a 2°, baja MaxRot a 3°")
printDbg("Ajusta si no llega: baja Deadzone a 0.2°, sube MaxRot a 15°")
printDbg("═══════════════════════════════════════════════")