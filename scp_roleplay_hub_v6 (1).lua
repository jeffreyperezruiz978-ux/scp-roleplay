--[[═══════════════════════════════════════════════════════════════
          SCP ROLEPLAY HUB v6.3  |  Rayfield Gen2
          · Solo carga en SCP Roleplay (PlaceId 5041144419)
          · Key System: clave 20112026
          · Silent Aim con 3 capas: hookmetamethod, metamétodos manuales
            (getrawmetatable, el que funciona en XENO) y hookfunction
          · Modo Mouse: intercepta Target/Hit/UnitRay de armas con Mouse
          · Aimbot de cámara + hitbox 3 modos + ESP cajas tamaño fijo
          · Círculo del FOV en UI pura + diagnóstico con contadores
   ═══════════════════════════════════════════════════════════════]]

--// Servicios
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")
local GuiService       = game:GetService("GuiService")
local HttpService      = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

--// Verificación del juego: solo cargar en SCP Roleplay
if game.PlaceId ~= 5041144419 then
    LocalPlayer:Kick("Este hub es exclusivo de SCP Roleplay (PlaceId 5041144419).")
    return
end

--// Carga protegida de Rayfield
local ok, Rayfield = pcall(function()
    return loadstring(game:HttpGet("https://sirius.menu/gen2"))()
end)
if not ok or not Rayfield then
    LocalPlayer:Kick("No se pudo cargar Rayfield. Revisa tu conexión o tu ejecutor.")
    return
end

--// Ventana (con Key System)
local Window = Rayfield:CreateWindow({
    name = "SCP Roleplay Hub",
    subtitle = "Rayfield Gen2 · v6.3",
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

--// Pestañas
local TabMain    = Window:CreateTab({ name = "Principal", icon = 93364949241311 })
local TabCombat  = Window:CreateTab({ name = "Combate",   icon = 93364949241311 })
local TabVisual  = Window:CreateTab({ name = "Visual",    icon = 93364949241311 })
local TabExtra   = Window:CreateTab({ name = "Varios",    icon = 93364949241311 })
local TabConfig  = Window:CreateTab({ name = "Config",    icon = 93364949241311 })

--// Estado
local State = {
    ESP             = false,
    ESPName         = true,
    ESPDist         = true,
    ESPHealth       = true,
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
    -- internas (no se guardan en la config)
    LOSBusy         = false,
    ShotsSeen       = 0,
    ShotsHit        = 0,
}

local DEFAULTS = {
    ESP = false, ESPName = true, ESPDist = true, ESPHealth = true,
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

local Highlights = {}   -- [Player] = Highlight (fallback si no hay Drawing)
local ESPDraw    = {}   -- [Player] = objetos Drawing del ESP
local ESPConns   = {}   -- [Player] = conexión CharacterAdded del fallback
local ESPRender  = nil  -- conexión del bucle de render
local antiAFKConn = nil
local UIRefs     = {}   -- referencias a elementos de la UI para sincronizar

--// [v6] Registro central de conexiones para poder descargar TODO limpio
local Conns = {}
local function addConn(name, conn)
    if Conns[name] then
        pcall(function() Conns[name]:Disconnect() end)
    end
    Conns[name] = conn
    return conn
end

--────────────────────────── UTILIDADES ──────────────────────────
local function notify(title, content)
    Window:Notify({ title = title, content = content })
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

local function getRoot()
    local char = LocalPlayer.Character
    return char and char:FindFirstChild("HumanoidRootPart")
end

--─────────────────────────── CONFIG ─────────────────────────────
local CONFIG_FILE = "SCPHub_Config.json"

local SAVE_KEYS = {
    "ESP", "ESPName", "ESPDist", "ESPHealth", "ESPMaxDist", "ESPEnemiesOnly",
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

-- Carga la config ANTES de crear la UI para que los valores aparezcan
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
        hl:Destroy()
        Highlights[plr] = nil
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

    ESPDraw[plr] = {
        box      = box,
        name     = name,
        dist     = distTxt,
        health   = health,
        healthbg = healthbg,
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

            -- [v6] opción: ocultar a los compañeros de equipo
            local sameTeam = plr.Team ~= nil and plr.Team == LocalPlayer.Team
            if State.ESPEnemiesOnly and sameTeam then
                char = nil
            end

            if char and root and hum and hum.Health > 0 then
                dist = (cam.CFrame.Position - root.Position).Magnitude
                if dist <= State.ESPMaxDist then
                    -- [v6] Caja de tamaño FIJO anclada al HumanoidRootPart.
                    -- Antes se usaba GetBoundingBox del personaje, así que
                    -- al agrandar el hitbox la caja del ESP crecía también.
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
            else
                objs.box.Visible = false
                objs.name.Visible = false
                objs.dist.Visible = false
                objs.health.Visible = false
                objs.healthbg.Visible = false
            end
        end
    end)
end

-- Fallback: Highlight dentro del personaje (solo si no hay Drawing API)
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
                conn:Disconnect()
            end
            ESPConns = {}
        end
    end
end

--────────────────── CÍRCULO DEL FOV (SILENT AIM) ────────────────
-- [v6.2] Círculo en UI PURA (Frame + UICorner + UIStroke): funciona en
-- TODOS los ejecutores. Xeno y otros no dibujan bien los círculos con la
-- librería Drawing, así que ya no se usa para esto.
local fovGui, fovRing, fovStroke = nil, nil, nil
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

    fovRing.Parent = fovGui
    fovGui.Parent = parent
    fovGui.Enabled = false
end)

addConn("FOVRender", RunService.RenderStepped:Connect(function()
    if not fovGui or not fovRing or not fovStroke then return end
    if State.SilentAim and State.FOVVisible then
        local m = UserInputService:GetMouseLocation()
        fovRing.Position = UDim2.fromOffset(m.X, m.Y)
        local d = math.max(math.floor(State.FOV) * 2, 10)
        fovRing.Size = UDim2.fromOffset(d, d)
        fovStroke.Color = State.FOVColor
        fovGui.Enabled = true
    else
        fovGui.Enabled = false
    end
end))

--───────────────────────── FULLBRIGHT ───────────────────────────
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

--────────────── INTERACCIÓN INSTANTÁNEA (prompts) ───────────────
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

--──────────────────────── SILENT AIM ────────────────────────────
local HookSupported = false
local oldNamecall = nil

-- [v6] Acepta orígenes cerca de CUALQUIER parte del personaje (cañón,
-- mano, cámara...). Antes solo miraba la Head y la cámara, y fallaba
-- con armas cuyo rayo sale del cañón del arma.
local function isShotOrigin(origin)
    local char = LocalPlayer.Character
    if char then
        for _, obj in ipairs(char:GetDescendants()) do
            if obj:IsA("BasePart") and (origin - obj.Position).Magnitude < 6 then
                return true
            end
        end
    end
    local cam = workspace.CurrentCamera
    if cam and (origin - cam.CFrame.Position).Magnitude < 15 then
        return true
    end
    return false
end

-- Wall detect: ¿hay línea de visión hasta el objetivo?
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
    -- [v6.1] ignora cristales, follaje y partes no sólidas: solo las
    -- paredes de verdad bloquean la detección (antes un cristal contaba
    -- como pared y el silent aim descartaba objetivos visibles)
    params.RespectCanCollide = true

    State.LOSBusy = true
    local okRay, result = pcall(function()
        return workspace:Raycast(origin, dirVec, params)
    end)
    State.LOSBusy = false

    if not okRay then return true end
    return result == nil
end

-- [v6] Objetivo en caché (0.1 s): el hook se dispara en cada raycast
-- del juego y antes recalculaba el objetivo entero en cada uno.
local cachedTarget, cachedTargetAt = nil, 0

local function getSilentTarget()
    local now = os.clock()
    if cachedTarget and (now - cachedTargetAt) < 0.1 then
        local c = cachedTarget.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h and h.Health > 0 then
            return cachedTarget
        end
        cachedTarget = nil
    end

    local cam = workspace.CurrentCamera
    if not cam then return nil end
    local mousePos = UserInputService:GetMouseLocation()
    local best, bestDist = nil, State.FOV
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer and plr.Character then
            local sameTeam = plr.Team ~= nil and plr.Team == LocalPlayer.Team
            if not (State.IgnoreTeam and sameTeam) then
                local hum = plr.Character:FindFirstChildOfClass("Humanoid")
                local head = plr.Character:FindFirstChild("Head")
                if hum and hum.Health > 0 and head then
                    -- [v6] WorldToViewportPoint: mismo sistema de coordenadas
                    -- que GetMouseLocation y que el círculo del FOV.
                    -- (Antes se usaba WorldToScreenPoint y había un desfase
                    -- de ~36 px respecto al círculo dibujado.)
                    local pos, onScreen = cam:WorldToViewportPoint(head.Position)
                    if onScreen and pos.Z > 0 then
                        local d = (Vector2.new(pos.X, pos.Y) - Vector2.new(mousePos.X, mousePos.Y)).Magnitude
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

-- [v6.1] Redirección compartida por todos los hooks
local function computeRedirect(origin, dir)
    local target = getSilentTarget()
    local targetChar = target and target.Character
    local head = targetChar and targetChar:FindFirstChild("Head")
    if not head then return nil end
    local newDir = (head.Position - origin).Unit * dir.Magnitude
    return newDir, targetChar, head
end

-- [v6.1] CLAVE: parchea los RaycastParams para que el rayo redirigido
-- atraviese el cuerpo del objetivo (brazos, torso, accesorios...) y
-- registre la CABEZA de verdad. Sin esto el rayo solía chocar primero
-- con el hombro o el brazo y el impacto contaba como disparo al cuerpo:
-- era la razón principal por la que "el silent aim no funcionaba".
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
        for _, inst in ipairs(targetChar:GetChildren()) do
            if inst ~= head then
                table.insert(list, inst)
            end
        end
    end
    np.FilterDescendantsInstances = list
    return np
end

-- [v6.3] Lógica común del hook de __namecall, compartida por las capas 1 y 2
local function namecallCore(self, oldNC, ...)
    local method = getnamecallmethod()
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

-- CAPA 1: hookmetamethod (Wave, Synapse, Delta, Solara v2...)
pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        return namecallCore(self, oldNamecall, ...)
    end))
    HookSupported = true
end)

-- CAPA 2 [v6.3]: metamétodos MANUALES con getrawmetatable + setreadonly.
-- Es la técnica que usan los scripts que SÍ funcionan en XENO (que no
-- tiene hookmetamethod). No depende de ninguna función rara: solo de
-- getrawmetatable, setreadonly y newcclosure (básicas de Xeno).
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

-- CAPA 3 (último recurso): hookfunction directa sobre workspace.Raycast
-- y workspace.FindPartOnRay.
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

-- [v6.3] MODO MOUSE (opcional): algunas armas usan Mouse.Target / Hit /
-- UnitRay en vez de Raycast. Este hook (también manual, compatible con
-- Xeno) redirige esas lecturas a la cabeza del objetivo.
local ManualIndexActive = false

local function installMouseHook()
    if ManualIndexActive then return end
    if type(getrawmetatable) ~= "function" or type(setreadonly) ~= "function"
        or type(newcclosure) ~= "function" then
        notify("Combate", "Tu ejecutor no soporta el hook de Mouse.")
        return
    end
    pcall(function()
        local mt = getrawmetatable(game)
        local oldIdx = mt.__index
        if type(oldIdx) ~= "function" then return end
        setreadonly(mt, false)
        mt.__index = newcclosure(function(t, k)
            local v = oldIdx(t, k)
            if State.SilentAim and State.MouseAim and not State.LOSBusy
                and t == LocalPlayer:GetMouse() then
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

--────────────────────── HITBOX EXPANDER [v6] ────────────────────
-- 3 modos:
--   "Cabeza"          → agranda la Head (se ve grande)
--   "Parte invisible" → agranda el HumanoidRootPart: los disparos del
--                       cliente lo registran igual pero NO se ve nada
--   "Cuerpo completo" → agranda cabeza, torso, brazos y piernas
-- Además se reaplica cada 0.5 s: si el juego restaura los tamaños
-- (uniform, cambio de equipo, respawn...), vuelve a agrandarlos solo.

local hitboxParts   = {}   -- [BasePart] = { size, massless, cancollide }
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
            }
        end
        pcall(function()
            part.Size = Vector3.new(State.HeadSize, State.HeadSize, State.HeadSize)
            part.CanQuery = true
            part.Massless = true
            -- El HumanoidRootPart NO se toca en colisión: si lo ponemos
            -- no colisionable el personaje se hunde en el suelo.
            if part.Name ~= "HumanoidRootPart" then
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
        notify("Combate", "Hitbox activo (" .. State.HitboxMode ..
            "). Si el arma sigue sin registrar, es que valida impactos en el servidor: usa el Silent Aim.")
    else
        restoreHitbox()
    end
end

-- [v6] Reaplicación continua cada 0.5 s
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

--──────────────────────── AUTO RECARGA ──────────────────────────
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
        -- [v6] fallback para ejecutores sin VirtualInputManager
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

-- [v6] toolConns: las conexiones de munición ahora se desconectan solas
-- cuando el tool deja de estar equipado (antes se acumulaban).
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
        -- [v6] antes el bucle seguía vivo aunque guardases el arma
        while tool.Parent == char do
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
            toolConns[tool]:Disconnect()
            toolConns[tool] = nil
        end
    end)
end

local function watchCharacterTools(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            watchTool(child, char)
        end
    end)
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

--──────────────────── TP AL SPAWN / REAPARECER ──────────────────
local function teleportToSpawn()
    local root = getRoot()
    if not root then return end
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("SpawnLocation") then
            root.CFrame = obj.CFrame + Vector3.new(0, 5, 0)
            notify("Jugador", "Teletransportado al spawn.")
            return
        end
    end
    notify("Jugador", "No se encontró ningún spawn en el mapa.")
end

-- Vigila spawns de otros jugadores (hitbox + ESP fallback + equipo)
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
    -- [v6] si cambia de equipo, reaplica el hitbox (ahí está en otro
    -- bando y la uniforme nueva puede restaurar tamaños)
    teamConns[plr] = plr:GetPropertyChangedSignal("Team"):Connect(function()
        if State.Hitbox and State.HitboxOnlyEnemy then
            task.defer(reapplyHitbox)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    watchPlayer(plr)
end

--──────────────────── AIMBOT DE CÁMARA [v6.1] ───────────────
-- Alternativa fiable: si el arma calcula el disparo con la dirección de
-- la cámara (muy común), seguir a la cabeza con la cámara SÍ registra.
addConn("Aimbot", RunService.RenderStepped:Connect(function()
    if not State.Aimbot then return end
    if State.AimbotRMB and not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton2) then
        return
    end
    local target = getSilentTarget()
    local head = target and target.Character and target.Character:FindFirstChild("Head")
    local cam = workspace.CurrentCamera
    if not head or not cam then return end
    local goal = CFrame.lookAt(cam.CFrame.Position, head.Position)
    local alpha = math.clamp(State.AimSmooth / 100, 0.05, 1)
    cam.CFrame = cam.CFrame:Lerp(goal, alpha)
end))

--─────────────────────────── PRINCIPAL ──────────────────────────
TabMain:CreateToggle({
    name = "Interacción instantánea (E sin mantener)",
    currentValue = State.InstantUse,
    callback = function(on)
        setInstantUse(on)
        saveConfig()
    end,
})

TabMain:CreateToggle({
    name = "Anti-AFK (no te expulsa por inactividad)",
    callback = function(on)
        if on then
            antiAFKConn = LocalPlayer.Idled:Connect(function()
                VirtualUser:CaptureController()
                VirtualUser:ClickButton2(Vector2.new())
            end)
        elseif antiAFKConn then
            antiAFKConn:Disconnect()
            antiAFKConn = nil
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

--─────────────────────────── COMBATE ────────────────────────────
UIRefs.SilentAim = TabCombat:CreateToggle({
    name = "Silent Aim (las balas van a la cabeza)",
    currentValue = State.SilentAim,
    callback = function(on)
        if on and not HookSupported and not ManualHookActive and not HookFnSupported then
            notify("Combate", "Tu ejecutor no soporta los hooks necesarios. Silent Aim no disponible: usa el Aimbot de cámara.")
            return
        end
        State.SilentAim = on
        saveConfig()
    end,
})

UIRefs.FOV = TabCombat:CreateSlider({
    name = "FOV del Silent Aim (píxeles)",
    range = { 10, 600 },
    increment = 1,
    currentValue = State.FOV,
    callback = function(value)
        State.FOV = value
        saveConfig()
    end,
})

UIRefs.FOVVisible = TabCombat:CreateToggle({
    name = "Mostrar círculo del FOV",
    currentValue = State.FOVVisible,
    callback = function(on)
        State.FOVVisible = on
        saveConfig()
    end,
})

-- Selector de color del círculo (con botones de respaldo)
if type(TabCombat.CreateColorPicker) == "function" then
    pcall(function()
        TabCombat:CreateColorPicker({
            name = "Color del círculo",
            color = State.FOVColor,
            callback = function(color)
                State.FOVColor = color
                saveConfig()
            end,
        })
    end)
else
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
                saveConfig()
            end,
        })
    end
end

UIRefs.WallDetect = TabCombat:CreateToggle({
    name = "Wall detect (no apuntar a través de paredes)",
    currentValue = State.WallDetect,
    callback = function(on)
        State.WallDetect = on
        saveConfig()
    end,
})

UIRefs.IgnoreTeam = TabCombat:CreateToggle({
    name = "Ignorar aliados (no apuntar a tu equipo)",
    currentValue = State.IgnoreTeam,
    callback = function(on)
        State.IgnoreTeam = on
        saveConfig()
    end,
})

UIRefs.Hitbox = TabCombat:CreateToggle({
    name = "Hitbox expander",
    currentValue = State.Hitbox,
    callback = function(on)
        setHitbox(on)
        saveConfig()
    end,
})

-- [v6] Selector del modo de hitbox (con botón de respaldo)
if type(TabCombat.CreateDropdown) == "function" then
    pcall(function()
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
                    saveConfig()
                end
            end,
        })
    end)
else
    TabCombat:CreateButton({
        name = "Cambiar modo del hitbox (mira la notificación)",
        callback = function()
            local order = { "Cabeza", "Parte invisible", "Cuerpo completo" }
            local idx = 1
            for i, m in ipairs(order) do
                if m == State.HitboxMode then
                    idx = i
                    break
                end
            end
            State.HitboxMode = order[(idx % #order) + 1]
            reapplyHitbox()
            saveConfig()
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
        saveConfig()
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
        saveConfig()
    end,
})

UIRefs.AutoReload = TabCombat:CreateToggle({
    name = "Auto Recarga (pulsa R solo al vaciar el cargador)",
    currentValue = State.AutoReload,
    callback = function(on)
        State.AutoReload = on
        saveConfig()
    end,
})

-- [v6.1] AIMBOT DE CÁMARA
UIRefs.Aimbot = TabCombat:CreateToggle({
    name = "Aimbot de cámara (mira a la cabeza del objetivo)",
    currentValue = State.Aimbot,
    callback = function(on)
        State.Aimbot = on
        saveConfig()
    end,
})

UIRefs.AimbotRMB = TabCombat:CreateToggle({
    name = "Aimbot solo con clic derecho mantenido",
    currentValue = State.AimbotRMB,
    callback = function(on)
        State.AimbotRMB = on
        saveConfig()
    end,
})

UIRefs.AimSmooth = TabCombat:CreateSlider({
    name = "Aimbot: suavidad (alto = más suave)",
    range = { 5, 100 },
    increment = 5,
    currentValue = State.AimSmooth,
    callback = function(value)
        State.AimSmooth = value
        saveConfig()
    end,
})

-- [v6.3] MODO MOUSE: para armas que apuntan con Mouse.Target/Hit
UIRefs.MouseAim = TabCombat:CreateToggle({
    name = "Modo Mouse (si el arma usa Target/Hit del ratón)",
    currentValue = State.MouseAim,
    callback = function(on)
        State.MouseAim = on
        if on then
            installMouseHook()
        end
        saveConfig()
    end,
})

-- [v6.3] DIAGNÓSTICO
TabCombat:CreateButton({
    name = "Diagnóstico del ejecutor (dime qué te sale)",
    callback = function()
        local execName = "desconocido"
        pcall(function()
            execName = (identifyexecutor and identifyexecutor()) or "desconocido"
        end)
        local lines = {
            "Ejecutor: " .. tostring(execName),
            "Capa 1 (hookmetamethod): " .. (HookSupported and "OK" or "NO"),
            "Capa 2 (manual/Xeno): " .. (ManualHookActive and "OK" or "NO"),
            "Capa 3 (hookfunction): " .. (HookFnSupported and "OK" or "NO"),
            "Hook Mouse: " .. (ManualIndexActive and "OK" or "NO"),
            "Rayos vistos: " .. tostring(State.ShotsSeen),
            "Redirigidos: " .. tostring(State.ShotsHit),
            "Drawing: " .. (DrawingSupported and "OK" or "NO"),
        }
        notify("Diagnóstico", table.concat(lines, " · "))
    end,
})

--──────────────────────────── VISUAL ────────────────────────────
UIRefs.ESP = TabVisual:CreateToggle({
    name = "ESP en cajas (color del equipo o personalizado)",
    currentValue = State.ESP,
    callback = function(on)
        setESP(on)
        saveConfig()
    end,
})

UIRefs.ESPName = TabVisual:CreateToggle({
    name = "ESP: mostrar nombre",
    currentValue = State.ESPName,
    callback = function(on)
        State.ESPName = on
        saveConfig()
    end,
})

UIRefs.ESPDist = TabVisual:CreateToggle({
    name = "ESP: mostrar distancia",
    currentValue = State.ESPDist,
    callback = function(on)
        State.ESPDist = on
        saveConfig()
    end,
})

UIRefs.ESPHealth = TabVisual:CreateToggle({
    name = "ESP: mostrar barra de vida",
    currentValue = State.ESPHealth,
    callback = function(on)
        State.ESPHealth = on
        saveConfig()
    end,
})

UIRefs.ESPEnemiesOnly = TabVisual:CreateToggle({
    name = "ESP: ocultar compañeros de equipo",
    currentValue = State.ESPEnemiesOnly,
    callback = function(on)
        State.ESPEnemiesOnly = on
        saveConfig()
    end,
})

UIRefs.ESPMaxDist = TabVisual:CreateSlider({
    name = "ESP: distancia máxima",
    range = { 200, 5000 },
    increment = 100,
    currentValue = State.ESPMaxDist,
    callback = function(value)
        State.ESPMaxDist = value
        saveConfig()
    end,
})

UIRefs.UseESPColor = TabVisual:CreateToggle({
    name = "ESP: usar color personalizado (en vez del color del equipo)",
    currentValue = State.UseESPColor,
    callback = function(on)
        State.UseESPColor = on
        saveConfig()
    end,
})

if type(TabVisual.CreateColorPicker) == "function" then
    pcall(function()
        TabVisual:CreateColorPicker({
            name = "Color personalizado del ESP",
            color = State.ESPColor,
            callback = function(color)
                State.ESPColor = color
                saveConfig()
            end,
        })
    end)
else
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
                saveConfig()
            end,
        })
    end
end

TabVisual:CreateToggle({
    name = "Fullbright (mapa iluminado, sin niebla)",
    currentValue = State.Fullbright,
    callback = function(on)
        setFullbright(on)
        saveConfig()
    end,
})

--───────────────────────────── VARIOS ───────────────────────────
TabExtra:CreateToggle({
    name = "Deslimitar FPS (240)",
    callback = function(on)
        pcall(function()
            if setfpscap then
                setfpscap(on and 240 or 60)
            end
        end)
    end,
})

TabExtra:CreateButton({
    name = "Descargar / cerrar el Hub",
    callback = function()
        -- [v6.2] descarga completa: para bucles, desconecta todo y restaura
        hitboxLoopRun = false
        setESP(false)
        setInstantUse(false)
        setFullbright(false)
        restoreHitbox()
        State.SilentAim = false
        State.AutoReload = false
        State.Aimbot = false
        State.Hitbox = false
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
        Rayfield:Destroy()
    end,
})

--──────────────────────────── CONFIG ────────────────────────────
local function syncUI()
    for key, el in pairs(UIRefs) do
        if el then
            pcall(function()
                el:Set(State[key])
            end)
        end
    end
end

local function applyLoadedEffects()
    setInstantUse(State.InstantUse)
    setFullbright(State.Fullbright)
    setESP(State.ESP)
    setHitbox(State.Hitbox)
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

TabConfig:CreateToggle({
    name = "Autoguardado (se guarda solo al cambiar algo)",
    currentValue = true,
    callback = function(on)
        notify("Config", on and "Autoguardado activo." or "Ojo: desactivado, usa Guardar ahora.")
        if on then saveConfig() end
    end,
})

--────────────────────── CONEXIONES DE JUGADORES ─────────────────
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
    local conn = ESPConns[plr]
    if conn then
        conn:Disconnect()
        ESPConns[plr] = nil
    end
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

--──────────────────────── INICIO FINAL ──────────────────────────
if configLoaded then
    applyLoadedEffects()
    notify("SCP Roleplay Hub v6.3", "Cargado con tu configuración guardada.")
else
    notify("SCP Roleplay Hub v6.3", "Cargado. Todo lo que actives se guardará solo.")
end
