--[[═══════════════════════════════════════════════════════════════
          SCP ROLEPLAY HUB v7.5  |  Rayfield Gen2
          v7.5: FIX "no apunta":
                · AimbotRMB = false default (ya no requiere clic derecho)
                · ShieldMode = "Ignorar" default (apunta a la cabeza)
                · FOV medido sobre HEAD, no sobre aim point
                · Binding en Last-1 (el juego no puede sobrescribir)
                · LOS con fallback agresivo
                · Debug integrado con contadores
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
    LocalPlayer:Kick("Este hub es exclusivo de SCP Roleplay.")
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
    subtitle = "Rayfield Gen2 · v7.5",
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

--══════════════════════════ ESTADO ═════════════════════════════
local State = {
    AutoSave = true,
    ESP = false, ESPName = true, ESPDist = true, ESPHealth = true,
    ESPTracers = false, ESPMaxDist = 2000, ESPEnemiesOnly = false,
    ESPColorMode = "Equipo del juego",
    ESPColor = Color3.fromRGB(255, 255, 255),
    InstantUse = false, Fullbright = false,
    Aimbot = false,
    AimbotRMB = false,                      -- [v7.5] FIX: antes true
    AimSmooth = 35, AimMaxDist = 500,
    RequireWeapon = true,
    TargetPriority = "Cercano al crosshair", TargetIndicator = true,
    WallDetect = true, IgnoreTeam = true, SCPFriendly = false,
    ShieldMode = "Ignorar",                 -- [v7.5] FIX: antes "Auto (pies)"
    AutoSwitchEnabled = true, AutoSwitchTriggerTime = 2.5, AutoSwitchDuration = 3,
    FOV = 120, FOVVisible = true, FOVColor = Color3.fromRGB(0, 255, 255),
    Hitbox = false, HitboxMode = "Cabeza", HitboxOnlyEnemy = true, HeadSize = 6,
    AutoReload = false, AutoReloadKey = "R", AutoReloadThreshold = 0,
}

local DEFAULTS = {}
for k, v in pairs(State) do DEFAULTS[k] = v end

-- [v7.5] Contadores de debug
local aimDebug = {
    frames = 0,
    triedWeapon = 0,
    triedAlive = 0,
    rejectedAlive = 0,
    rejectedTeam = 0,
    rejectedFov = 0,
    rejectedDist = 0,
    rejectedLos = 0,
    accepted = 0,
    lastCamPos = nil,
}

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
local function getHumanoid() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function getRoot() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end

--══════════════════════════ CONFIG ═════════════════════════════
local CONFIG_FILE = "SCPHub_Config.json"
local SAVE_KEYS = {
    "AutoSave","ESP","ESPName","ESPDist","ESPHealth","ESPTracers","ESPMaxDist","ESPEnemiesOnly",
    "ESPColorMode","ESPColor","InstantUse","Fullbright",
    "Aimbot","AimbotRMB","AimSmooth","AimMaxDist","RequireWeapon",
    "TargetPriority","TargetIndicator","WallDetect","IgnoreTeam","SCPFriendly","ShieldMode",
    "AutoSwitchEnabled","AutoSwitchTriggerTime","AutoSwitchDuration",
    "FOV","FOVVisible","FOVColor",
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
                        elseif typeof(v) == typeof(State[k]) then State[k] = v end
                    end
                end
                loaded = true
            end
        end
    end)
    return loaded
end
-- [v7.5] NO cargamos config al arrancar (evita que un config viejo rompa el aimbot)
local configLoaded = false

--══════════════════════ COLORES SCP:RP ═════════════════════════
local SCPTeamColors = {
    { pattern = "^scp%-", c = Color3.fromRGB(150, 0, 200) },
    { pattern = "^scp$",  c = Color3.fromRGB(150, 0, 200) },
    { pattern = "^scp ",  c = Color3.fromRGB(150, 0, 200) },
    { pattern = "chaos",  c = Color3.fromRGB(180, 30, 30) },
    { pattern = "insurgency", c = Color3.fromRGB(180, 30, 30) },
    { pattern = "mtf",    c = Color3.fromRGB(30, 100, 200) },
    { pattern = "mobile task", c = Color3.fromRGB(30, 100, 200) },
    { pattern = "class%-d", c = Color3.fromRGB(255, 140, 0) },
    { pattern = "d%-class", c = Color3.fromRGB(255, 140, 0) },
    { pattern = "class d",  c = Color3.fromRGB(255, 140, 0) },
    { pattern = "scientist", c = Color3.fromRGB(180, 180, 255) },
    { pattern = "research",  c = Color3.fromRGB(180, 180, 255) },
    { pattern = "site security", c = Color3.fromRGB(60, 60, 60) },
    { pattern = "security",  c = Color3.fromRGB(60, 60, 60) },
    { pattern = "foundation", c = Color3.fromRGB(200, 200, 200) },
    { pattern = "goc",       c = Color3.fromRGB(0, 180, 80) },
    { pattern = "occult",    c = Color3.fromRGB(0, 180, 80) },
    { pattern = "uiu",       c = Color3.fromRGB(200, 200, 0) },
    { pattern = "serpent",   c = Color3.fromRGB(0, 150, 150) },
}
local function getSCPTeamColor(plr)
    local lower = string.lower((plr.Team and plr.Team.Name) or "")
    for _, e in ipairs(SCPTeamColors) do if string.find(lower, e.pattern) then return e.c end end
    if plr.Team then return plr.Team.Color end
    return Color3.fromRGB(255, 255, 255)
end
local function espColorFor(plr)
    local m = State.ESPColorMode or "Equipo del juego"
    if m == "Color personalizado" then return State.ESPColor
    elseif m == "Colores SCP:RP" then return getSCPTeamColor(plr)
    else return (plr.Team and plr.Team.Color) or Color3.fromRGB(255, 255, 255) end
end

--═════════════════════════ DEAD CHECK ══════════════════════════
local function isLocalAlive()
    local char = LocalPlayer.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    if not char:FindFirstChild("HumanoidRootPart") then return false end
    return true
end
local function isTargetAlive(plr)
    if not plr or plr.Parent == nil then return false end
    local char = plr.Character
    if not char then return false end
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hum or hum.Health <= 0 then return false end
    if hum:GetState() == Enum.HumanoidStateType.Dead then return false end
    if not hum.RootPart then return false end
    return true
end

--══════════════════════ TEAM + SHIELD + GUN ════════════════════
local function getTeamGroup(teamName)
    if not teamName then return nil end
    local l = string.lower(teamName)
    if l:find("^scp") or l:find("scp%-") then return "SCP" end
    if l:find("chaos") or l:find("insurgency") then return "Chaos" end
    if l:find("mtf") or l:find("mobile task") then return "MTF" end
    if l:find("class%-d") or l:find("d%-class") or l:find("class d") then return "Class-D" end
    if l:find("scientist") or l:find("research") then return "Foundation" end
    if l:find("foundation") or l:find("security") or l:find("site") then return "Foundation" end
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

local SHIELD_PATTERNS = { "shield", "riot shield", "ballistic shield", "escutcheon", "escudo", "riot", "ballistic" }
local function isShieldName(name)
    if not name then return false end
    local l = string.lower(name)
    for _, pat in ipairs(SHIELD_PATTERNS) do
        if l:find(pat, 1, true) then return true end
    end
    return false
end

-- [v7.5] Gun check: lista de cosas que NO son armas
local NON_WEAPON_NAMES = {
    "shield","riot","ballistic","escutcheon","escudo","barrier",
    "radio","keycard","key card","key_card","key-card",
    "medkit","med kit","bandage","first aid","firstaid","defib","syringe","bandages",
    "handcuff","restraint","cuff","cuffs",
    "backpack","flashlight","lantern",
    "paper","document","file","note","notes",
    "badge","id card","idcard",
    "gasmask","gas mask",
}
local function isNonWeaponName(name)
    if not name then return true end
    local l = string.lower(name)
    for _, pat in ipairs(NON_WEAPON_NAMES) do
        if l:find(pat, 1, true) then return true end
    end
    return false
end
local function hasWeaponEquipped()
    local char = LocalPlayer.Character
    if not char then return false end
    for _, tool in ipairs(char:GetChildren()) do
        if tool:IsA("Tool") and not isNonWeaponName(tool.Name) then
            local handle = tool:FindFirstChild("Handle")
            if handle and handle:IsA("BasePart") then
                return true, tool
            end
        end
    end
    return false
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
            if h and h:IsA("BasePart") then result = { instance = child, handle = h }; break end
        end
    end
    if not result then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("Accessory") and isShieldName(child.Name) then
                local h = child:FindFirstChild("Handle")
                if h and h:IsA("BasePart") then result = { instance = child, handle = h }; break end
            end
        end
    end
    if not result then
        for _, child in ipairs(char:GetChildren()) do
            if child:IsA("BasePart") and isShieldName(child.Name) then
                result = { instance = child, handle = child }; break
            end
        end
    end
    shieldCache[plr] = { shield = result, time = now }
    return result
end

--════════════════════════════ LOS ══════════════════════════════
-- [v7.5] Lista de exclusión robusta con fallback
local function buildExcludeList(targetChar, shield, aggressive)
    local list = { LocalPlayer.Character }
    if targetChar then
        if aggressive then
            -- Fallback agresivo: excluir TODO el character del target
            table.insert(list, targetChar)
        else
            -- Normal: excluir solo body parts + accesorios
            for _, c in ipairs(targetChar:GetChildren()) do
                if c:IsA("BasePart") or c:IsA("Accessory") or c:IsA("Tool") then
                    if c:IsA("Tool") and shield and shield.instance == c then
                        -- no excluir escudo (queremos bloquear contra él)
                    else
                        table.insert(list, c)
                    end
                end
            end
        end
    end
    return list
end

local function singleRaycast(origin, aimPos, exclude)
    local dir = aimPos - origin
    if dir.Magnitude < 0.1 then return true end
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = exclude
    params.RespectCanCollide = true
    params.IgnoreWater = true
    local ok, result = pcall(function() return workspace:Raycast(origin, dir, params) end)
    if not ok then return false end
    return result == nil
end

-- [v7.5] LOS con fallback: si el raycast normal falla, reintentar con excludes agresivos
local function isAimPointClear(targetChar, aimPos, shield)
    local cam = workspace.CurrentCamera
    if not cam then return false end
    local origin = cam.CFrame.Position

    -- Intento 1: exclusión normal (body parts + accesorios)
    local exclude1 = buildExcludeList(targetChar, shield, false)
    local offsets = { Vector3.new(0,0,0), Vector3.new(0,0.5,0), Vector3.new(0,0,-0.5), Vector3.new(0,-0.5,0) }
    for _, off in ipairs(offsets) do
        if singleRaycast(origin, aimPos + off, exclude1) then return true end
    end

    -- Intento 2: exclusión agresiva (todo el character)
    local exclude2 = buildExcludeList(targetChar, shield, true)
    for _, off in ipairs(offsets) do
        if singleRaycast(origin, aimPos + off, exclude2) then return true end
    end

    return false
end

--════════════════════════════ ESP ══════════════════════════════
local DrawingSupported = false
pcall(function()
    local t = Drawing.new("Square"); t:Remove(); DrawingSupported = true
end)
local function clearPlayerVisual(plr)
    local o = ESPDraw[plr]
    if o then for _, obj in pairs(o) do pcall(function() obj:Remove() end) end; ESPDraw[plr] = nil end
    local hl = Highlights[plr]
    if hl then pcall(function() hl:Destroy() end); Highlights[plr] = nil end
    local c = ESPConns[plr]
    if c then pcall(function() c:Disconnect() end); ESPConns[plr] = nil end
end
local function createDrawings(plr)
    if ESPDraw[plr] then return end
    local box = Drawing.new("Square"); box.Thickness=1.5; box.Filled=false; box.Transparency=1; box.Visible=false
    local name = Drawing.new("Text"); name.Size=13; name.Center=true; name.Outline=true; name.Visible=false
    local dist = Drawing.new("Text"); dist.Size=12; dist.Center=true; dist.Outline=true; dist.Visible=false
    local hbg = Drawing.new("Square"); hbg.Thickness=0; hbg.Filled=true; hbg.Color=Color3.new(); hbg.Transparency=0.6; hbg.Visible=false
    local hp = Drawing.new("Square"); hp.Thickness=0; hp.Filled=true; hp.Visible=false
    local tr = Drawing.new("Line"); tr.Thickness=1.5; tr.Transparency=1; tr.Visible=false
    ESPDraw[plr] = { box=box, name=name, dist=dist, health=hp, healthbg=hbg, tracer=tr }
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
                            bw, cx, ty = bh * 0.55, cS.X, math.min(tS.Y, bS.Y)
                            visible = true
                        end
                    end
                end
            end
            if visible then
                local col = espColorFor(plr)
                objs.box.Position = Vector2.new(cx - bw/2, ty)
                objs.box.Size = Vector2.new(bw, bh)
                objs.box.Color = col; objs.box.Visible = true
                if State.ESPName then
                    objs.name.Text = plr.Name
                    objs.name.Position = Vector2.new(cx, ty - 14)
                    objs.name.Color = col; objs.name.Visible = true
                else objs.name.Visible = false end
                if State.ESPDist then
                    objs.dist.Text = tostring(math.floor(dist)).." m"
                    objs.dist.Position = Vector2.new(cx, ty + bh + 4)
                    objs.dist.Color = Color3.new(1,1,1); objs.dist.Visible = true
                else objs.dist.Visible = false end
                if State.ESPHealth then
                    local pct = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    local barH = bh * pct
                    objs.healthbg.Position = Vector2.new(cx - bw/2 - 6, ty)
                    objs.healthbg.Size = Vector2.new(3, bh); objs.healthbg.Visible = true
                    objs.health.Position = Vector2.new(cx - bw/2 - 6, ty + (bh - barH))
                    objs.health.Size = Vector2.new(3, barH)
                    objs.health.Color = Color3.fromRGB(math.floor(255*(1-pct)), math.floor(200*pct), 0)
                    objs.health.Visible = true
                else objs.healthbg.Visible = false; objs.health.Visible = false end
                if objs.tracer then
                    if State.ESPTracers then
                        local vp = cam.ViewportSize
                        objs.tracer.From = Vector2.new(vp.X/2, vp.Y - 2)
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
        hl.OutlineColor = Color3.new(1,1,1)
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
            for _, p in ipairs(Players:GetPlayers()) do if p ~= LocalPlayer then createDrawings(p) end end
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

--═══════════════════════ CÍRCULO FOV ═══════════════════════════
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
    fovGui.Name = "HubFOVCircle"; fovGui.IgnoreGuiInset = true
    fovGui.ResetOnSpawn = false; fovGui.DisplayOrder = 9999
    fovRing = Instance.new("Frame")
    fovRing.AnchorPoint = Vector2.new(0.5, 0.5)
    fovRing.BackgroundTransparency = 1; fovRing.BorderSizePixel = 0
    local cr = Instance.new("UICorner"); cr.CornerRadius = UDim.new(1,0); cr.Parent = fovRing
    fovStroke = Instance.new("UIStroke")
    fovStroke.Thickness = 1.5
    fovStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    fovStroke.Color = State.FOVColor; fovStroke.Parent = fovRing
    fovDot = Instance.new("Frame")
    fovDot.AnchorPoint = Vector2.new(0.5, 0.5)
    fovDot.Size = UDim2.fromOffset(4,4)
    fovDot.BackgroundColor3 = State.FOVColor
    fovDot.BackgroundTransparency = 0.2; fovDot.BorderSizePixel = 0
    local dc = Instance.new("UICorner"); dc.CornerRadius = UDim.new(1,0); dc.Parent = fovDot
    fovRing.Parent = fovGui; fovDot.Parent = fovGui
    fovGui.Parent = parent; fovGui.Enabled = false
end)
addConn("FOVRender", RunService.RenderStepped:Connect(function()
    if not fovGui or not fovRing then return end
    if State.Aimbot and State.FOVVisible and isLocalAlive() then
        local cam = workspace.CurrentCamera
        if cam then
            local vp = cam.ViewportSize
            local d = math.max(math.floor(State.FOV) * 2, 10)
            fovRing.Position = UDim2.fromOffset(vp.X/2, vp.Y/2)
            fovRing.Size = UDim2.fromOffset(d, d)
            fovStroke.Color = State.FOVColor
            if fovDot then
                fovDot.Position = UDim2.fromOffset(vp.X/2, vp.Y/2)
                fovDot.BackgroundColor3 = State.FOVColor
            end
        end
        fovGui.Enabled = true
    else
        fovGui.Enabled = false
    end
end))

--════════════════════════ FULLBRIGHT ═══════════════════════════
local LightDef = {
    Ambient = Lighting.Ambient, Brightness = Lighting.Brightness,
    FogEnd = Lighting.FogEnd, ClockTime = Lighting.ClockTime,
    GlobalShadows = Lighting.GlobalShadows,
}
local function setFullbright(on)
    State.Fullbright = on
    if on then
        Lighting.Ambient = Color3.fromRGB(200,200,200)
        Lighting.Brightness = 3; Lighting.FogEnd = 100000
        Lighting.ClockTime = 14; Lighting.GlobalShadows = false
    else
        Lighting.Ambient = LightDef.Ambient
        Lighting.Brightness = LightDef.Brightness
        Lighting.FogEnd = LightDef.FogEnd
        Lighting.ClockTime = LightDef.ClockTime
        Lighting.GlobalShadows = LightDef.GlobalShadows
    end
end

--══════════════════════ INTERACCIÓN INSTANT ════════════════════
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
    if o:IsA("ProximityPrompt") and State.InstantUse then task.defer(setPromptHold, o, true) end
end))

--═════════════════════════ AUTO RELOAD ═════════════════════════
local AR = { lastReloadTime=0, lastAmmo=-1, currentTool=nil, attempts=0, confirmedEmpty=false }
local AMMO_ATTRS = { "Ammo","AmmoCount","Magazine","MagazineAmmo","Clip","CurrentAmmo","Bullets","Rounds" }
local AMMO_PATTERNS = { "^ammo","^currentammo","^magazine","^mag","^clip","^bullets","^rounds","^shots" }

function readAmmo(tool)
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
    if not ok then pcall(function() keypress(kc.Value); task.wait(0.04); keyrelease(kc.Value) end) end
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
        AR.currentTool = tool; AR.attempts = 0; AR.confirmedEmpty = false; AR.lastAmmo = ammo
    end
    if AR.lastAmmo >= 0 and ammo > AR.lastAmmo then
        AR.attempts = 0; AR.confirmedEmpty = false
    end
    if AR.attempts >= 5 and ammo == AR.lastAmmo then AR.confirmedEmpty = true end
    if AR.confirmedEmpty and ammo == AR.lastAmmo then return end
    local threshold = State.AutoReloadThreshold or 0
    local maxAmmo = readMaxAmmo(tool)
    local shouldReload = false
    if threshold <= 0 then
        shouldReload = (ammo <= 0)
    else
        if maxAmmo then
            shouldReload = (ammo <= maxAmmo * (threshold / 100)) and (ammo < maxAmmo)
        else
            shouldReload = (ammo <= threshold)
        end
    end
    if shouldReload then trySendReload() end
    AR.lastAmmo = ammo
end
task.spawn(function()
    while hubRunning do
        task.wait(0.05)
        if State.AutoReload then
            local char = LocalPlayer.Character
            local tool = char and char:FindFirstChildOfClass("Tool")
            if tool then checkAutoReload(tool) else AR.currentTool = nil end
        end
    end
end)

--═══════════════════════════════════════════════════════════════
--                  AIMBOT v7.5 (todo fixed)
--═══════════════════════════════════════════════════════════════
local aimState = { target = nil, switchTime = 0, smoothedPos = nil, cand = nil }
local candCache = {}
local autoSwitch = { active = false, until_ = 0, targetPlr = nil, sameTargetStart = 0, lastHP = 0 }

local function updateAutoSwitchState(currentTarget, currentHum, currentShield, now)
    if not State.AutoSwitchEnabled or State.ShieldMode ~= "Auto (pies)" then
        autoSwitch.active = false; return
    end
    if not currentTarget or not currentShield then
        autoSwitch.active = false; autoSwitch.targetPlr = nil; autoSwitch.sameTargetStart = 0; return
    end
    if autoSwitch.targetPlr ~= currentTarget then
        autoSwitch.targetPlr = currentTarget
        autoSwitch.sameTargetStart = now
        autoSwitch.lastHP = currentHum.Health
        autoSwitch.active = false
        return
    end
    if currentHum.Health < autoSwitch.lastHP then
        autoSwitch.sameTargetStart = now; autoSwitch.lastHP = currentHum.Health
        autoSwitch.active = false
        return
    end
    if autoSwitch.active then
        if now >= autoSwitch.until_ then
            autoSwitch.active = false
            notify("Aimbot", "Auto-switch finalizado.")
        end
        return
    end
    if (now - autoSwitch.sameTargetStart) >= (State.AutoSwitchTriggerTime or 2.5) then
        autoSwitch.active = true
        autoSwitch.until_ = now + (State.AutoSwitchDuration or 3)
        notify("Aimbot", "Auto-switch: rompiendo escudo de " .. currentTarget.Name)
    end
end

local function predictPosition(plr, basePos, lookAhead)
    local char = plr.Character
    if not char then return basePos end
    local root = char:FindFirstChild("HumanoidRootPart")
    if not root then return basePos end
    local velocity = root.AssemblyLinearVelocity or root.Velocity or Vector3.new()
    if velocity.Magnitude < 1 then return basePos end
    return basePos + velocity * lookAhead
end

-- [v7.5] Resuelve aim part según modo (por defecto head = Ignorar)
local function resolveAimPart(plr, head, shield, now)
    local mode = State.ShieldMode or "Ignorar"
    if autoSwitch.active and now < autoSwitch.until_ and autoSwitch.targetPlr == plr and shield then
        return shield.handle, "shield"
    end
    if not shield or mode == "Ignorar" then return head, "head" end
    if mode == "Romper escudo" then return shield.handle, "shield" end
    local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
    if root then return root, "lower" end
    return head, "head"
end

-- [v7.5] Candidato con FOV + score sobre HEAD (no sobre aim point)
local function getAimbotCandidate(plr, cam, camPos, centerV2, maxDist, priority, now)
    aimDebug.triedAlive = aimDebug.triedAlive + 1
    if not isTargetAlive(plr) then
        aimDebug.rejectedAlive = aimDebug.rejectedAlive + 1
        return nil
    end
    if State.IgnoreTeam and isAlly(plr) then
        aimDebug.rejectedTeam = aimDebug.rejectedTeam + 1
        return nil
    end
    local char = plr.Character
    local head = char:FindFirstChild("Head")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not head or not hum then return nil end

    -- [v7.5] FOV sobre la HEAD (fix del bug de v7.4)
    local headPos = head.Position
    local headDist = (headPos - camPos).Magnitude
    if headDist > maxDist then
        aimDebug.rejectedDist = aimDebug.rejectedDist + 1
        return nil
    end
    local headScreen, onS = cam:WorldToViewportPoint(headPos)
    if not onS or headScreen.Z <= 0 then
        aimDebug.rejectedFov = aimDebug.rejectedFov + 1
        return nil
    end
    local headSd = (Vector2.new(headScreen.X, headScreen.Y) - centerV2).Magnitude
    if headSd > State.FOV then
        aimDebug.rejectedFov = aimDebug.rejectedFov + 1
        return nil
    end

    -- Resolver aim part (puede ser head o shield/pies)
    local shield = detectShield(plr)
    local mode = State.ShieldMode or "Ignorar"
    if shield and mode == "Saltar objetivo" then
        -- Comprobar si el escudo bloquea la cabeza
        local camOrigin = cam.CFrame.Position
        local exclude = buildExcludeList(char, nil, false)
        local dir = headPos - camOrigin
        if dir.Magnitude > 0.1 then
            local params = RaycastParams.new()
            params.FilterType = Enum.RaycastFilterType.Exclude
            params.FilterDescendantsInstances = exclude
            params.RespectCanCollide = true
            local okR, result = pcall(function() return workspace:Raycast(camOrigin, dir, params) end)
            if okR and result and (result.Instance == shield.handle
                or (shield.instance and result.Instance:IsDescendantOf(shield.instance))) then
                return nil
            end
        end
    end
    local aimPart, aimKind = resolveAimPart(plr, head, shield, now)
    if not aimPart or not aimPart.Parent then return nil end

    -- Wall check sobre el aim part (con fallback)
    if State.WallDetect then
        local aimPos = aimPart.Position
        if aimKind == "lower" then aimPos = aimPos + Vector3.new(0, -2.5, 0) end
        if not isAimPointClear(char, aimPos, shield) then
            aimDebug.rejectedLos = aimDebug.rejectedLos + 1
            return nil
        end
    end

    -- Score según prioridad (sobre HEAD)
    local score
    if priority == "Menos HP" then score = hum.Health
    elseif priority == "Más cercano en studs" then score = headDist
    else score = headSd end

    aimDebug.accepted = aimDebug.accepted + 1
    return {
        plr = plr, head = head, hum = hum,
        aimPart = aimPart, aimKind = aimKind,
        shield = shield, score = score,
    }
end

local function getCandCached(plr, cam, camPos, centerV2, maxDist, priority, now)
    local e = candCache[plr]
    if e and (now - e.time) < 0.1 then return e.cand end
    local cand = getAimbotCandidate(plr, cam, camPos, centerV2, maxDist, priority, now)
    candCache[plr] = { cand = cand, time = now }
    return cand
end

local function getAimbotTarget()
    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local vp = cam.ViewportSize
    local centerV2 = Vector2.new(vp.X / 2, vp.Y / 2)
    local camPos = cam.CFrame.Position
    local maxDist = State.AimMaxDist or 500
    local priority = State.TargetPriority or "Cercano al crosshair"
    local now = os.clock()

    -- Reset debug counters (cada llamada)
    aimDebug.triedAlive = 0
    aimDebug.rejectedAlive = 0
    aimDebug.rejectedTeam = 0
    aimDebug.rejectedFov = 0
    aimDebug.rejectedDist = 0
    aimDebug.rejectedLos = 0
    aimDebug.accepted = 0

    if aimState.target and isTargetAlive(aimState.target) then
        local hum = aimState.target.Character:FindFirstChildOfClass("Humanoid")
        local sh = detectShield(aimState.target)
        if hum then updateAutoSwitchState(aimState.target, hum, sh, now) end
    end

    local currentCand = nil
    if aimState.target and isTargetAlive(aimState.target) then
        currentCand = getCandCached(aimState.target, cam, camPos, centerV2, maxDist, priority, now)
    end

    local bestCand = nil
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local c = getCandCached(plr, cam, camPos, centerV2, maxDist, priority, now)
            if c and (not bestCand or c.score < bestCand.score) then
                bestCand = c
            end
        end
    end

    if not bestCand and not currentCand then
        aimState.target = nil; aimState.cand = nil; aimState.smoothedPos = nil
        return nil
    end

    if currentCand then
        if bestCand and bestCand.plr ~= currentCand.plr and bestCand.score < currentCand.score * 0.75 then
            aimState.target = bestCand.plr
            aimState.switchTime = now
            aimState.smoothedPos = nil
            aimState.cand = bestCand
            return bestCand
        end
        aimState.cand = currentCand
        return currentCand
    end

    aimState.target = bestCand.plr
    aimState.switchTime = now
    aimState.smoothedPos = nil
    aimState.cand = bestCand
    return bestCand
end

local function aimStep(dt)
    dt = dt or 0.016
    aimDebug.frames = aimDebug.frames + 1
    if not State.Aimbot then return end
    if not isLocalAlive() then
        aimState.smoothedPos = nil
        return
    end
    if State.RequireWeapon and not hasWeaponEquipped() then
        aimDebug.triedWeapon = aimDebug.triedWeapon + 1
        aimState.smoothedPos = nil
        aimState.target = nil; aimState.cand = nil
        autoSwitch.active = false; autoSwitch.sameTargetStart = 0
        return
    end
    if State.AimbotRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end
    local cam = workspace.CurrentCamera
    if not cam then return end
    local cand = getAimbotTarget()
    if not cand or not cand.aimPart or not cand.aimPart.Parent then
        aimState.smoothedPos = nil
        return
    end
    local basePos = cand.aimPart.Position
    if cand.aimKind == "lower" then basePos = basePos + Vector3.new(0, -2.5, 0) end
    local rawPos = predictPosition(cand.plr, basePos, 0.10)

    if not aimState.smoothedPos then
        aimState.smoothedPos = rawPos
    else
        local smoothRate = math.max(3, 14 - State.AimSmooth * 0.10)
        local alpha = 1 - math.exp(-dt * smoothRate)
        aimState.smoothedPos = aimState.smoothedPos:Lerp(rawPos, math.clamp(alpha, 0.02, 0.8))
    end

    local camPos = cam.CFrame.Position
    local delta = aimState.smoothedPos - camPos
    if delta.Magnitude < 0.5 then return end

    local goal = CFrame.lookAt(camPos, aimState.smoothedPos, cam.CFrame.UpVector)
    local camRate = math.max(2, 10 - State.AimSmooth * 0.08)
    local camAlpha = math.clamp(1 - math.exp(-dt * camRate), 0.01, 0.5)
    cam.CFrame = cam.CFrame:Lerp(goal, camAlpha)
end

-- [v7.5] Binding a Last-1 (garantiza ejecución DESPUÉS de cualquier camera controller)
local function setAimbotBinding()
    pcall(function() RunService:UnbindFromRenderStep("HubAimbotStep") end)
    if Conns["AimbotFallback"] then
        pcall(function() Conns["AimbotFallback"]:Disconnect() end)
        Conns["AimbotFallback"] = nil
    end
    aimState.smoothedPos = nil
    if State.Aimbot then
        -- Intento 1: Last - 1
        local okB = pcall(function()
            RunService:BindToRenderStep("HubAimbotStep", Enum.RenderPriority.Last.Value - 1, aimStep)
        end)
        if not okB then
            -- Intento 2: Camera + 1 (fallback)
            local okB2 = pcall(function()
                RunService:BindToRenderStep("HubAimbotStep", Enum.RenderPriority.Camera.Value + 1, aimStep)
            end)
            if not okB2 then
                addConn("AimbotFallback", RunService.RenderStepped:Connect(aimStep))
            end
        end
    end
end

--════════════════════ INDICADOR TARGET ═════════════════════════
local targetHighlight, lastTargetTick = nil, 0
local function clearTargetHighlight()
    if targetHighlight then pcall(function() targetHighlight:Destroy() end); targetHighlight = nil end
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
    if autoSwitch.active and autoSwitch.targetPlr == t then
        targetHighlight.OutlineColor = Color3.fromRGB(255, 50, 50)
        targetHighlight.FillColor = Color3.fromRGB(255, 100, 100)
        targetHighlight.FillTransparency = 0.6
    elseif shield then
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
    if now - lastTargetTick < 0.12 then return end
    lastTargetTick = now
    updateTargetIndicator()
end))

--═══════════════════════════ HITBOX ════════════════════════════
local hitboxParts = {}
local function partsForHitbox(char)
    local found = {}
    if State.HitboxMode == "Cabeza" then
        local h = char:FindFirstChild("Head"); if h then table.insert(found, h) end
    elseif State.HitboxMode == "Parte invisible" then
        local r = char:FindFirstChild("HumanoidRootPart"); if r then table.insert(found, r) end
    else
        for _, n in ipairs({ "Head","Torso","UpperTorso","LowerTorso","HumanoidRootPart",
            "Left Arm","Right Arm","Left Leg","Right Leg","LeftUpperArm","RightUpperArm",
            "LeftLowerArm","RightLowerArm","LeftHand","RightHand","LeftUpperLeg","RightUpperLeg",
            "LeftLowerLeg","RightLowerLeg","LeftFoot","RightFoot" }) do
            local p = char:FindFirstChild(n); if p then table.insert(found, p) end
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
            hitboxParts[part] = { size=part.Size, massless=part.Massless,
                cancollide=part.CanCollide, canquery=part.CanQuery }
        end
        pcall(function()
            part.Size = Vector3.new(State.HeadSize, State.HeadSize, State.HeadSize)
            part.CanQuery = true
            if part.Name ~= "HumanoidRootPart" then
                part.Massless = true; part.CanCollide = false
            end
        end)
    end
end
local function restoreHitbox()
    for part, rec in pairs(hitboxParts) do
        if part and part.Parent then
            pcall(function()
                part.Size = rec.size; part.Massless = rec.massless
                part.CanCollide = rec.cancollide; part.CanQuery = rec.canquery
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
    else restoreHitbox() end
end
task.spawn(function()
    while hubRunning do
        task.wait(0.5)
        if State.Hitbox and isLocalAlive() then
            for part in pairs(hitboxParts) do if not part.Parent then hitboxParts[part] = nil end end
            for _, p in ipairs(Players:GetPlayers()) do expandParts(p) end
        end
    end
end)

--═════════════════════════════ TP ══════════════════════════════
local function teleportToSpawn()
    local root = getRoot()
    if not root then notify("Jugador", "Sin personaje."); return end
    for _, o in ipairs(workspace:GetDescendants()) do
        if o:IsA("SpawnLocation") then
            root.CFrame = o.CFrame + Vector3.new(0, 5, 0)
            notify("Jugador", "Teletransportado al spawn."); return
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

--═══════════════════════ UI: PRINCIPAL ═════════════════════════
TabMain:CreateToggle({
    name = "Interacción instantánea (E sin mantener)",
    currentValue = State.InstantUse,
    callback = function(on) setInstantUse(on); maybeSave() end,
})
TabMain:CreateToggle({
    name = "Anti-AFK (no te expulsa por inactividad)",
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
    name = "Reconectar al servidor (rejoin)",
    callback = function() TeleportService:Teleport(game.PlaceId, LocalPlayer) end,
})
TabMain:CreateButton({ name = "Ir al spawn", callback = teleportToSpawn })
TabMain:CreateButton({
    name = "Reaparecer (reset personaje)",
    callback = function() local h = getHumanoid(); if h then h.Health = 0 end end,
})

--═══════════════════════ UI: COMBATE ═══════════════════════════
UIRefs.Aimbot = TabCombat:CreateToggle({
    name = "Aimbot de cámara (mira al objetivo)",
    currentValue = State.Aimbot,
    callback = function(on) State.Aimbot = on; setAimbotBinding(); maybeSave() end,
})
UIRefs.AimbotRMB = TabCombat:CreateToggle({
    name = "Aimbot solo con clic derecho mantenido",
    currentValue = State.AimbotRMB,
    callback = function(on) State.AimbotRMB = on; maybeSave() end,
})
UIRefs.RequireWeapon = TabCombat:CreateToggle({
    name = "Gun check (solo activo con arma equipada)",
    currentValue = State.RequireWeapon,
    callback = function(on) State.RequireWeapon = on; maybeSave() end,
})
UIRefs.AimSmooth = TabCombat:CreateSlider({
    name = "Aimbot: suavidad (alto = más suave)",
    range = { 5, 100 }, increment = 5,
    currentValue = State.AimSmooth,
    callback = function(v) State.AimSmooth = v; maybeSave() end,
})
UIRefs.AimMaxDist = TabCombat:CreateSlider({
    name = "Distancia máxima del aim (studs)",
    range = { 50, 2000 }, increment = 25,
    currentValue = State.AimMaxDist,
    callback = function(v) State.AimMaxDist = v; maybeSave() end,
})
UIRefs.FOV = TabCombat:CreateSlider({
    name = "FOV del aim (radio px desde el centro)",
    range = { 10, 600 }, increment = 1,
    currentValue = State.FOV,
    callback = function(v) State.FOV = v; maybeSave() end,
})
UIRefs.FOVVisible = TabCombat:CreateToggle({
    name = "Mostrar círculo del FOV",
    currentValue = State.FOVVisible,
    callback = function(on) State.FOVVisible = on; maybeSave() end,
})
local pickerOk = false
if type(TabCombat.CreateColorPicker) == "function" then
    pickerOk = pcall(function()
        UIRefs.FOVColorPicker = TabCombat:CreateColorPicker({
            name = "Color del círculo + marcador",
            color = State.FOVColor,
            callback = function(c) State.FOVColor = c; maybeSave() end,
        })
    end)
end
if not pickerOk then
    for _, c in ipairs({
        { l="cian", c=Color3.fromRGB(0,255,255) }, { l="rojo", c=Color3.fromRGB(255,0,60) },
        { l="verde", c=Color3.fromRGB(0,255,90) }, { l="blanco", c=Color3.fromRGB(255,255,255) },
    }) do
        TabCombat:CreateButton({ name = "Color círculo: " .. c.l,
            callback = function() State.FOVColor = c.c; maybeSave() end })
    end
end

local prioOk = false
if type(TabCombat.CreateDropdown) == "function" then
    prioOk = pcall(function()
        UIRefs.TargetPriority = TabCombat:CreateDropdown({
            name = "Prioridad del objetivo",
            options = { "Cercano al crosshair", "Menos HP", "Más cercano en studs" },
            currentOption = { State.TargetPriority },
            multipleOptions = false,
            callback = function(o)
                local v = type(o)=="table" and o[1] or o
                if v and v~="" then State.TargetPriority = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not prioOk then
    TabCombat:CreateButton({
        name = "Cambiar prioridad de objetivo",
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
            name = "Modo de escudo (MTF / Alpha-1)",
            options = { "Ignorar", "Auto (pies)", "Romper escudo", "Saltar objetivo" },
            currentOption = { State.ShieldMode },
            multipleOptions = false,
            callback = function(o)
                local v = type(o)=="table" and o[1] or o
                if v and v~="" then
                    State.ShieldMode = tostring(v)
                    candCache = {}; shieldCache = {}
                    notify("Combate", "Modo escudo: " .. State.ShieldMode)
                    maybeSave()
                end
            end,
        })
    end)
end
if not shieldDropOk then
    TabCombat:CreateButton({
        name = "Cambiar modo de escudo",
        callback = function()
            local ord = { "Ignorar", "Auto (pies)", "Romper escudo", "Saltar objetivo" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.ShieldMode then i = k; break end end
            State.ShieldMode = ord[(i % #ord) + 1]
            candCache = {}; shieldCache = {}
            notify("Combate", "Modo escudo: " .. State.ShieldMode)
            maybeSave()
        end,
    })
end

UIRefs.AutoSwitchEnabled = TabCombat:CreateToggle({
    name = "Auto-switch a romper escudo",
    currentValue = State.AutoSwitchEnabled,
    callback = function(on)
        State.AutoSwitchEnabled = on
        if not on then autoSwitch.active = false end
        maybeSave()
    end,
})
UIRefs.AutoSwitchTriggerTime = TabCombat:CreateSlider({
    name = "Auto-switch: trigger (s)",
    range = { 1, 5 }, increment = 0.5,
    currentValue = State.AutoSwitchTriggerTime,
    callback = function(v) State.AutoSwitchTriggerTime = v; maybeSave() end,
})
UIRefs.AutoSwitchDuration = TabCombat:CreateSlider({
    name = "Auto-switch: duración (s)",
    range = { 1, 5 }, increment = 0.5,
    currentValue = State.AutoSwitchDuration,
    callback = function(v) State.AutoSwitchDuration = v; maybeSave() end,
})

UIRefs.Hitbox = TabCombat:CreateToggle({
    name = "Hitbox expander",
    currentValue = State.Hitbox,
    callback = function(on) setHitbox(on); maybeSave() end,
})
local dropOk = false
if type(TabCombat.CreateDropdown) == "function" then
    dropOk = pcall(function()
        UIRefs.HitboxMode = TabCombat:CreateDropdown({
            name = "Modo del hitbox",
            options = { "Cabeza", "Parte invisible", "Cuerpo completo" },
            currentOption = { State.HitboxMode },
            multipleOptions = false,
            callback = function(o)
                local v = type(o)=="table" and o[1] or o
                if v and v~="" then State.HitboxMode = tostring(v); reapplyHitbox(); maybeSave() end
            end,
        })
    end)
end
if not dropOk then
    TabCombat:CreateButton({
        name = "Cambiar modo del hitbox",
        callback = function()
            local ord = { "Cabeza", "Parte invisible", "Cuerpo completo" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.HitboxMode then i = k; break end end
            State.HitboxMode = ord[(i % #ord) + 1]
            reapplyHitbox(); maybeSave()
            notify("Combate", "Modo hitbox: " .. State.HitboxMode)
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
        if State.Hitbox then for _, p in ipairs(Players:GetPlayers()) do expandParts(p) end end
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
    name = "Auto Recarga: umbral % (0 = solo al vaciar)",
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
                local v = type(o)=="table" and o[1] or o
                if v and v~="" then State.AutoReloadKey = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not keyDropOk then
    TabCombat:CreateButton({
        name = "Cambiar tecla de recarga",
        callback = function()
            local ord = { "R","Tab","X","F","E","Q" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.AutoReloadKey then i = k; break end end
            State.AutoReloadKey = ord[(i % #ord) + 1]
            notify("Combate", "Tecla: " .. State.AutoReloadKey)
            maybeSave()
        end,
    })
end

-- [v7.5] Diagnóstico + Debug
TabCombat:CreateButton({
    name = "Diagnóstico del ejecutor",
    callback = function()
        local exec = "desconocido"
        pcall(function() exec = (identifyexecutor and identifyexecutor()) or "desconocido" end)
        local tgt = aimState.target and aimState.target.Name or "ninguno"
        local weaponOk, weaponTool = hasWeaponEquipped()
        local weaponInfo = weaponOk and (weaponTool and weaponTool.Name or "sí") or "NINGUNA"
        local lines = {
            "Exec: " .. tostring(exec),
            "Local vivo: " .. (isLocalAlive() and "SÍ" or "NO"),
            "Arma: " .. weaponInfo,
            "Target: " .. tostring(tgt),
            "Modo escudo: " .. tostring(State.ShieldMode),
            "RMB req: " .. (State.AimbotRMB and "SÍ (pulsa clic derecho)" or "NO"),
            "Frames aimStep: " .. tostring(aimDebug.frames),
            "Drawing: " .. (DrawingSupported and "OK" or "NO"),
        }
        notify("Diagnóstico", table.concat(lines, " · "))
    end,
})

TabCombat:CreateButton({
    name = "🛠 Debug aimbot (por qué no apunta)",
    callback = function()
        local now = os.clock()
        local cam = workspace.CurrentCamera
        local weaponOk, weaponTool = hasWeaponEquipped()
        local lines = {
            "Aimbot ON: " .. (State.Aimbot and "SÍ" or "NO"),
            "Frames: " .. tostring(aimDebug.frames),
            "Local vivo: " .. (isLocalAlive() and "SÍ" or "NO"),
            "Arma: " .. (weaponOk and (weaponTool and weaponTool.Name or "sí") or "NINGUNA"),
            "RMB req: " .. (State.AimbotRMB and "SÍ" or "NO"),
            "--- último frame ---",
            "Tried: " .. tostring(aimDebug.triedAlive),
            "Rechazados - muertos: " .. tostring(aimDebug.rejectedAlive),
            "Rechazados - team: " .. tostring(aimDebug.rejectedTeam),
            "Rechazados - dist: " .. tostring(aimDebug.rejectedDist),
            "Rechazados - FOV: " .. tostring(aimDebug.rejectedFov),
            "Rechazados - LOS: " .. tostring(aimDebug.rejectedLos),
            "Aceptados: " .. tostring(aimDebug.accepted),
            "FOV actual: " .. tostring(State.FOV) .. "px",
            "Target: " .. (aimState.target and aimState.target.Name or "ninguno"),
        }
        notify("Debug Aimbot", table.concat(lines, " · "))
    end,
})

--═══════════════════════ UI: VISUAL ════════════════════════════
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
                local v = type(o)=="table" and o[1] or o
                if v and v~="" then State.ESPColorMode = tostring(v); maybeSave() end
            end,
        })
    end)
end
if not espDropOk then
    TabVisual:CreateButton({
        name = "Cambiar modo de color del ESP",
        callback = function()
            local ord = { "Equipo del juego","Colores SCP:RP","Color personalizado" }
            local i = 1
            for k, m in ipairs(ord) do if m == State.ESPColorMode then i = k; break end end
            State.ESPColorMode = ord[(i % #ord) + 1]
            notify("Visual", "Modo color: " .. State.ESPColorMode); maybeSave()
        end,
    })
end
UIRefs.ESPName = TabVisual:CreateToggle({ name = "ESP: nombre",
    currentValue = State.ESPName, callback = function(on) State.ESPName = on; maybeSave() end })
UIRefs.ESPDist = TabVisual:CreateToggle({ name = "ESP: distancia",
    currentValue = State.ESPDist, callback = function(on) State.ESPDist = on; maybeSave() end })
UIRefs.ESPHealth = TabVisual:CreateToggle({ name = "ESP: barra de vida",
    currentValue = State.ESPHealth, callback = function(on) State.ESPHealth = on; maybeSave() end })
UIRefs.ESPTracers = TabVisual:CreateToggle({ name = "ESP: tracers",
    currentValue = State.ESPTracers, callback = function(on) State.ESPTracers = on; maybeSave() end })
UIRefs.ESPEnemiesOnly = TabVisual:CreateToggle({ name = "ESP: ocultar aliados",
    currentValue = State.ESPEnemiesOnly, callback = function(on) State.ESPEnemiesOnly = on; maybeSave() end })
UIRefs.ESPMaxDist = TabVisual:CreateSlider({ name = "ESP: distancia máxima",
    range = { 200, 5000 }, increment = 100, currentValue = State.ESPMaxDist,
    callback = function(v) State.ESPMaxDist = v; maybeSave() end })
local espPickerOk = false
if type(TabVisual.CreateColorPicker) == "function" then
    espPickerOk = pcall(function()
        UIRefs.ESPColorPicker = TabVisual:CreateColorPicker({
            name = "Color personalizado del ESP",
            color = State.ESPColor,
            callback = function(c) State.ESPColor = c; maybeSave() end,
        })
    end)
end
if not espPickerOk then
    for _, c in ipairs({
        { l="blanco", c=Color3.fromRGB(255,255,255) }, { l="rojo", c=Color3.fromRGB(255,0,60) },
        { l="verde", c=Color3.fromRGB(0,255,90) }, { l="azul", c=Color3.fromRGB(0,140,255) },
        { l="amarillo", c=Color3.fromRGB(255,230,0) },
    }) do
        TabVisual:CreateButton({ name = "Color ESP: " .. c.l,
            callback = function()
                State.ESPColor = c.c
                State.ESPColorMode = "Color personalizado"
                pcall(function() if UIRefs.ESPColorMode then UIRefs.ESPColorMode:Set("Color personalizado") end end)
                maybeSave()
            end })
    end
end
TabVisual:CreateToggle({
    name = "Fullbright",
    currentValue = State.Fullbright,
    callback = function(on) setFullbright(on); maybeSave() end,
})

--═══════════════════════ UI: VARIOS ════════════════════════════
TabExtra:CreateToggle({
    name = "Deslimitar FPS (240)",
    callback = function(on) pcall(function() if setfpscap then setfpscap(on and 240 or 60) end end) end,
})
local selectedPlayerName
local playerOptions = {}
local function refreshPlayerOptions()
    playerOptions = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(playerOptions, p.Name) end
    end
    if UIRefs.PlayerDropdown then pcall(function() UIRefs.PlayerDropdown:Refresh(playerOptions) end) end
end
local playerDropOk = false
if type(TabExtra.CreateDropdown) == "function" then
    playerDropOk = pcall(function()
        UIRefs.PlayerDropdown = TabExtra:CreateDropdown({
            name = "Jugador para TP",
            options = playerOptions, currentOption = {},
            multipleOptions = false,
            callback = function(o) selectedPlayerName = type(o)=="table" and o[1] or o end,
        })
    end)
end
TabExtra:CreateButton({
    name = "Refrescar lista",
    callback = function() refreshPlayerOptions(); notify("TP", #playerOptions .. " jugadores.") end,
})
TabExtra:CreateButton({
    name = "TP al seleccionado",
    callback = function()
        if not selectedPlayerName then notify("TP", "Selecciona un jugador primero."); return end
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

--═══════════════════════ UI: CONFIG ════════════════════════════
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

TabConfig:CreateButton({ name = "Guardar configuración",
    callback = function() saveConfig(); notify("Config", "Guardado.") end })
TabConfig:CreateButton({ name = "Cargar configuración",
    callback = function()
        if loadConfig() then syncUI(); applyLoadedEffects(); notify("Config", "Cargado.") else notify("Config", "No hay config.") end
    end })
TabConfig:CreateButton({ name = "Borrar configuración",
    callback = function() pcall(function() if delfile then delfile(CONFIG_FILE) end end); notify("Config", "Borrado.") end })
TabConfig:CreateButton({ name = "Restablecer defaults",
    callback = function()
        for k, v in pairs(DEFAULTS) do State[k] = v end
        autoSwitch.active = false
        syncUI(); applyLoadedEffects(); saveConfig()
        notify("Config", "Defaults.")
    end })
TabConfig:CreateToggle({ name = "Autoguardado",
    currentValue = State.AutoSave,
    callback = function(on) State.AutoSave = on; saveConfig() end })

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
    notify("Keybind", "Aimbot: " .. (State.Aimbot and "ON" or "OFF")); maybeSave()
end)
bindKey("Toggle ESP", "V", function()
    State.ESP = not State.ESP
    setESP(State.ESP)
    pcall(function() if UIRefs.ESP then UIRefs.ESP:Set(State.ESP) end end)
    notify("Keybind", "ESP: " .. (State.ESP and "ON" or "OFF")); maybeSave()
end)
bindKey("Toggle Hitbox", "B", function()
    State.Hitbox = not State.Hitbox
    setHitbox(State.Hitbox)
    pcall(function() if UIRefs.Hitbox then UIRefs.Hitbox:Set(State.Hitbox) end end)
    notify("Keybind", "Hitbox: " .. (State.Hitbox and "ON" or "OFF")); maybeSave()
end)
bindKey("Toggle Fullbright", "N", function()
    State.Fullbright = not State.Fullbright
    setFullbright(State.Fullbright)
    notify("Keybind", "Fullbright: " .. (State.Fullbright and "ON" or "OFF")); maybeSave()
end)

--═══════════════════════════ UNLOAD ════════════════════════════
TabExtra:CreateButton({
    name = "Descargar / cerrar el Hub",
    callback = function()
        hubRunning = false
        setESP(false); setInstantUse(false); setFullbright(false); restoreHitbox()
        State.Aimbot = false; State.Hitbox = false; State.AutoReload = false
        setAimbotBinding(); clearTargetHighlight(); autoSwitch.active = false
        candCache = {}; shieldCache = {}
        if antiAFKConn then antiAFKConn:Disconnect(); antiAFKConn = nil end
        for name, conn in pairs(Conns) do pcall(function() conn:Disconnect() end); Conns[name] = nil end
        if fovGui then pcall(function() fovGui:Destroy() end); fovGui = nil end
        pcall(function() Rayfield:Destroy() end)
    end,
})

--══════════════════════ CONEXIONES JUGADORES ═══════════════════
local teamConns = {}
local function watchPlayer(plr)
    addConn("Char_" .. plr.Name, plr.CharacterAdded:Connect(function()
        task.wait(0.5)
        if State.Hitbox then expandParts(plr) end
        if State.ESP and not DrawingSupported then attachHL(plr) end
        shieldCache[plr] = nil; candCache[plr] = nil
    end))
    teamConns[plr] = plr:GetPropertyChangedSignal("Team"):Connect(function()
        if State.Hitbox and State.HitboxOnlyEnemy then task.defer(reapplyHitbox) end
        shieldCache[plr] = nil; candCache[plr] = nil
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
    shieldCache[plr] = nil; candCache[plr] = nil
    local tc = teamConns[plr]
    if tc then tc:Disconnect(); teamConns[plr] = nil end
    local cc = Conns["Char_" .. plr.Name]
    if cc then cc:Disconnect(); Conns["Char_" .. plr.Name] = nil end
    task.defer(refreshPlayerOptions)
end))

--═══════════════════════════ INICIO ════════════════════════════
task.defer(refreshPlayerOptions)
notify("SCP Roleplay Hub v7.5", "Cargado. Defaults actualizados: AimbotRMB OFF, ShieldMode Ignorar. Prueba el Debug si no apunta.")