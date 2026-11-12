--[[═══════════════════════════════════════════════════════════════
          SCP ROLEPLAY HUB v5  |  Rayfield Gen2
          · Solo carga en SCP Roleplay (PlaceId 5041144419)
          · Key System: clave 20112026
          · Config: autoguardado de todo (archivo SCPHub_Config.json)
          · ESP por cajas con color de equipo o color personalizado
          · Silent Aim con círculo de FOV visible + wall detect
          · Fly, Click TP, noclip, salto infinito, auto recarga...
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
    subtitle = "Rayfield Gen2",
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
local TabPlayer  = Window:CreateTab({ name = "Jugador",   icon = 93364949241311 })
local TabCombat  = Window:CreateTab({ name = "Combate",   icon = 93364949241311 })
local TabVisual  = Window:CreateTab({ name = "Visual",    icon = 93364949241311 })
local TabExtra   = Window:CreateTab({ name = "Varios",    icon = 93364949241311 })
local TabConfig  = Window:CreateTab({ name = "Config",    icon = 93364949241311 })

--// Estado
local State = {
    Velocidad       = 16,
    Salto           = 50,
    InfJump         = false,
    Noclip          = false,
    Fly             = false,
    FlySpeed        = 60,
    ClickTP         = false,
    ESP             = false,
    ESPName         = true,
    ESPDist         = true,
    ESPHealth       = true,
    ESPMaxDist      = 2000,
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
    HitboxOnlyEnemy = true,
    HeadSize        = 6,
    AutoReload      = false,
    LOSBusy         = false,
}

local DEFAULTS = {
    Velocidad = 16, Salto = 50, InfJump = false, Noclip = false,
    Fly = false, FlySpeed = 60, ClickTP = false,
    ESP = false, ESPName = true, ESPDist = true, ESPHealth = true,
    ESPMaxDist = 2000, UseESPColor = false,
    ESPColor = Color3.fromRGB(255, 255, 255),
    InstantUse = false, Fullbright = false,
    SilentAim = false, FOV = 120, FOVVisible = true,
    FOVColor = Color3.fromRGB(0, 255, 255),
    WallDetect = true, IgnoreTeam = true,
    Hitbox = false, HitboxOnlyEnemy = true, HeadSize = 6,
    AutoReload = false,
}

local Highlights = {}   -- [Player] = Highlight (fallback si no hay Drawing)
local ESPDraw    = {}   -- [Player] = objetos Drawing del ESP
local ESPConns   = {}   -- [Player] = conexión CharacterAdded del fallback
local ESPRender  = nil  -- conexión del bucle de render
local antiAFKConn = nil
local UIRefs     = {}   -- referencias a elementos de la UI para sincronizar

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
    "Velocidad", "Salto", "InfJump", "Noclip",
    "Fly", "FlySpeed", "ClickTP",
    "ESP", "ESPName", "ESPDist", "ESPHealth", "ESPMaxDist",
    "UseESPColor", "ESPColor",
    "InstantUse", "Fullbright",
    "SilentAim", "FOV", "FOVVisible", "FOVColor",
    "WallDetect", "IgnoreTeam",
    "Hitbox", "HitboxOnlyEnemy", "HeadSize",
    "AutoReload",
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

--──────────── Reaplica velocidad y salto al reaparecer ──────────
LocalPlayer.CharacterAdded:Connect(function(char)
    local hum = char:WaitForChild("Humanoid", 10)
    if not hum then return end
    task.wait(0.3)
    hum.UseJumpPower = true
    hum.WalkSpeed = State.Velocidad
    hum.JumpPower = State.Salto
end)

--// Noclip
RunService.Stepped:Connect(function()
    if not State.Noclip then return end
    local char = LocalPlayer.Character
    if not char then return end
    for _, obj in ipairs(char:GetDescendants()) do
        if obj:IsA("BasePart") and obj.CanCollide then
            obj.CanCollide = false
        end
    end
end)

--// Salto infinito
UserInputService.JumpRequest:Connect(function()
    if not State.InfJump then return end
    local hum = getHumanoid()
    if hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end
end)

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

            if char and root and hum and hum.Health > 0 then
                dist = (cam.CFrame.Position - root.Position).Magnitude
                if dist <= State.ESPMaxDist then
                    local okBB, bbCf, bbSize = pcall(char.GetBoundingBox, char)
                    if okBB then
                        local topWorld    = (bbCf * CFrame.new(0,  bbSize.Y / 2, 0)).Position
                        local bottomWorld = (bbCf * CFrame.new(0, -bbSize.Y / 2, 0)).Position
                        local topS, on1 = cam:WorldToViewportPoint(topWorld)
                        local botS, on2 = cam:WorldToViewportPoint(bottomWorld)
                        local ctrS, on3 = cam:WorldToViewportPoint(root.Position)
                        if on1 and on2 and on3 then
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
local fovCircle = nil
if DrawingSupported then
    pcall(function()
        fovCircle = Drawing.new("Circle")
        fovCircle.NumSides = 64
        fovCircle.Thickness = 1.5
        fovCircle.Filled = false
        fovCircle.Transparency = 1
        fovCircle.Visible = false
    end)
end

RunService.RenderStepped:Connect(function()
    if not fovCircle then return end
    if State.SilentAim and State.FOVVisible then
        local m = UserInputService:GetMouseLocation()
        fovCircle.Position = Vector2.new(m.X, m.Y)
        fovCircle.Radius = State.FOV
        fovCircle.Color = State.FOVColor
        fovCircle.Visible = true
    else
        fovCircle.Visible = false
    end
end)

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

workspace.DescendantAdded:Connect(function(obj)
    if obj:IsA("ProximityPrompt") and State.InstantUse then
        task.defer(setPromptHold, obj, true)
    end
end)

--──────────────────────── SILENT AIM ────────────────────────────
local HookSupported = false
local oldNamecall = nil

local function isShotOrigin(origin)
    local char = LocalPlayer.Character
    local head = char and char:FindFirstChild("Head")
    if head and (origin - head.Position).Magnitude < 8 then
        return true
    end
    local cam = workspace.CurrentCamera
    if cam and (origin - cam.CFrame.Position).Magnitude < 12 then
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

    State.LOSBusy = true
    local okRay, result = pcall(function()
        return workspace:Raycast(origin, dirVec, params)
    end)
    State.LOSBusy = false

    if not okRay then return true end
    return result == nil
end

local function getSilentTarget()
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
                    local pos, onScreen = cam:WorldToScreenPoint(head.Position)
                    if onScreen then
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
    return best
end

pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if State.SilentAim and not State.LOSBusy
            and self == workspace and (method == "Raycast" or method == "FindPartOnRay") then
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
                local target = getSilentTarget()
                local targetChar = target and target.Character
                local head = targetChar and targetChar:FindFirstChild("Head")
                if head then
                    local newDir = (head.Position - origin).Unit * dir.Magnitude
                    if method == "Raycast" then
                        return oldNamecall(self, origin, newDir, unpack(args, 3))
                    else
                        return oldNamecall(self, Ray.new(origin, newDir), unpack(args, 2))
                    end
                end
            end
        end
        return oldNamecall(self, ...)
    end))
    HookSupported = true
end)

--────────────────────── HITBOX EXPANDER ─────────────────────────
local headSizes = {} -- [Head] = tamaño original

local function expandHead(plr)
    if plr == LocalPlayer then return end
    if State.HitboxOnlyEnemy and plr.Team ~= nil and plr.Team == LocalPlayer.Team then
        return
    end
    local char = plr.Character
    local head = char and char:FindFirstChild("Head")
    if head then
        if headSizes[head] == nil then
            headSizes[head] = head.Size
        end
        head.Size = Vector3.new(State.HeadSize, State.HeadSize, State.HeadSize)
        head.CanCollide = false
        head.Massless = true
    end
end

local function restoreHeads()
    for head, orig in pairs(headSizes) do
        if head and head.Parent then
            head.Size = orig
        end
    end
    headSizes = {}
end

local function setHitbox(on)
    State.Hitbox = on
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            expandHead(plr)
        end
    else
        restoreHeads()
    end
end

local function reapplyHitbox()
    restoreHeads()
    if State.Hitbox then
        for _, plr in ipairs(Players:GetPlayers()) do
            expandHead(plr)
        end
    end
end

--──────────────────────── AUTO RECARGA ──────────────────────────
local lastReload = 0
local function trySendReload()
    if os.clock() - lastReload < 2 then return end
    lastReload = os.clock()
    pcall(function()
        local vim = game:GetService("VirtualInputManager")
        vim:SendKeyEvent(true, Enum.KeyCode.R, false, game)
        task.wait(0.05)
        vim:SendKeyEvent(false, Enum.KeyCode.R, false, game)
    end)
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

local function watchTool(tool)
    local ammoVal = findAmmoValue(tool)
    if ammoVal then
        ammoVal.Changed:Connect(function(v)
            if State.AutoReload and v == 0 then
                task.wait(0.1)
                trySendReload()
            end
        end)
    end
    task.spawn(function()
        while tool.Parent do
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
    end)
end

local function watchCharacterTools(char)
    char.ChildAdded:Connect(function(child)
        if child:IsA("Tool") then
            watchTool(child)
        end
    end)
    for _, child in ipairs(char:GetChildren()) do
        if child:IsA("Tool") then
            watchTool(child)
        end
    end
end

if LocalPlayer.Character then
    watchCharacterTools(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(watchCharacterTools)

--─────────────────────────── VUELO ──────────────────────────────
local flyBV = nil
local flyConn = nil

local function setFly(on)
    State.Fly = on
    if flyConn then
        flyConn:Disconnect()
        flyConn = nil
    end
    if flyBV then
        pcall(function() flyBV:Destroy() end)
        flyBV = nil
    end
    if on then
        local root = getRoot()
        if not root then
            notify("Jugador", "No hay personaje para activar el vuelo.")
            State.Fly = false
            return
        end
        flyBV = Instance.new("BodyVelocity")
        flyBV.MaxForce = Vector3.new(1e9, 1e9, 1e9)
        flyBV.Velocity = Vector3.zero
        flyBV.Parent = root
        flyConn = RunService.RenderStepped:Connect(function()
            if not State.Fly then return end
            local r = getRoot()
            local hum = getHumanoid()
            if not r or not hum or not flyBV or flyBV.Parent ~= r then return end
            local vel = Vector3.zero
            local md = hum.MoveDirection
            if md.Magnitude > 0 then
                vel = md * State.FlySpeed
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.Space) then
                vel = vel + Vector3.new(0, State.FlySpeed, 0)
            end
            if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) then
                vel = vel - Vector3.new(0, State.FlySpeed, 0)
            end
            flyBV.Velocity = vel
        end)
    end
end

-- Reativar el vuelo al reaparecer
LocalPlayer.CharacterAdded:Connect(function()
    if State.Fly then
        task.wait(0.6)
        setFly(true)
    end
end)

--────────────────────────── CLICK TP ────────────────────────────
UserInputService.InputBegan:Connect(function(input, processed)
    if processed or not State.ClickTP then return end
    if not UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then return end
    if input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end

    local cam = workspace.CurrentCamera
    local root = getRoot()
    if not cam or not root then return end

    local m = UserInputService:GetMouseLocation()
    local inset = GuiService:GetGuiInset()
    local unitRay = cam:ViewportPointToRay(m.X, m.Y - inset.Y)

    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    local excl = {}
    if LocalPlayer.Character then table.insert(excl, LocalPlayer.Character) end
    params.FilterDescendantsInstances = excl

    State.LOSBusy = true
    local okTP, hit = pcall(function()
        return workspace:Raycast(unitRay.Origin, unitRay.Direction * 2000, params)
    end)
    State.LOSBusy = false

    if okTP and hit then
        root.CFrame = CFrame.new(hit.Position + Vector3.new(0, 4, 0))
    end
end)

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

-- Vigila spawns de otros jugadores (hitbox + ESP fallback)
local function watchPlayer(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if State.Hitbox then
            expandHead(plr)
        end
        if State.ESP and not DrawingSupported then
            attachHL(plr)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    watchPlayer(plr)
end

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

--──────────────────────────── JUGADOR ───────────────────────────
UIRefs.Velocidad = TabPlayer:CreateSlider({
    name = "Velocidad de movimiento",
    range = { 0, 200 },
    increment = 1,
    currentValue = State.Velocidad,
    callback = function(value)
        State.Velocidad = value
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = value
        end
        saveConfig()
    end,
})

UIRefs.Salto = TabPlayer:CreateSlider({
    name = "Altura de salto",
    range = { 20, 300 },
    increment = 1,
    currentValue = State.Salto,
    callback = function(value)
        State.Salto = value
        local hum = getHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = value
        end
        saveConfig()
    end,
})

UIRefs.InfJump = TabPlayer:CreateToggle({
    name = "Salto infinito",
    currentValue = State.InfJump,
    callback = function(on)
        State.InfJump = on
        saveConfig()
    end,
})

UIRefs.Noclip = TabPlayer:CreateToggle({
    name = "Noclip (atravesar paredes)",
    currentValue = State.Noclip,
    callback = function(on)
        State.Noclip = on
        saveConfig()
    end,
})

UIRefs.Fly = TabPlayer:CreateToggle({
    name = "Vuelo (fly): WASD mueve, Espacio sube, Shift baja",
    currentValue = State.Fly,
    callback = function(on)
        setFly(on)
        saveConfig()
    end,
})

UIRefs.FlySpeed = TabPlayer:CreateSlider({
    name = "Velocidad de vuelo",
    range = { 10, 300 },
    increment = 5,
    currentValue = State.FlySpeed,
    callback = function(value)
        State.FlySpeed = value
        saveConfig()
    end,
})

UIRefs.ClickTP = TabPlayer:CreateToggle({
    name = "Click TP (mantén Ctrl y haz clic donde quieras ir)",
    currentValue = State.ClickTP,
    callback = function(on)
        State.ClickTP = on
        saveConfig()
    end,
})

TabPlayer:CreateButton({
    name = "Ir al spawn",
    callback = teleportToSpawn,
})

TabPlayer:CreateButton({
    name = "Reaparecer (reset personaje)",
    callback = function()
        local hum = getHumanoid()
        if hum then
            hum.Health = 0
        end
    end,
})

TabPlayer:CreateButton({
    name = "Restablecer velocidad y salto",
    callback = function()
        State.Velocidad, State.Salto = 16, 50
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = 16
            hum.JumpPower = 50
        end
        pcall(function()
            if UIRefs.Velocidad then UIRefs.Velocidad:Set(16) end
            if UIRefs.Salto then UIRefs.Salto:Set(50) end
        end)
        saveConfig()
        notify("Jugador", "Valores restablecidos a 16 / 50.")
    end,
})

--─────────────────────────── COMBATE ────────────────────────────
UIRefs.SilentAim = TabCombat:CreateToggle({
    name = "Silent Aim (las balas van a la cabeza)",
    currentValue = State.SilentAim,
    callback = function(on)
        if on and not HookSupported then
            notify("Combate", "Tu ejecutor no soporta hookmetamethod. Silent Aim no disponible.")
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
    name = "Hitbox expander (cabeza)",
    currentValue = State.Hitbox,
    callback = function(on)
        setHitbox(on)
        saveConfig()
    end,
})

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
    name = "Tamaño de la cabeza",
    range = { 2, 20 },
    increment = 0.5,
    currentValue = State.HeadSize,
    callback = function(value)
        State.HeadSize = value
        if State.Hitbox then
            for _, plr in ipairs(Players:GetPlayers()) do
                expandHead(plr)
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
        setESP(false)
        setInstantUse(false)
        setFullbright(false)
        setFly(false)
        restoreHeads()
        State.Noclip = false
        State.SilentAim = false
        State.AutoReload = false
        if antiAFKConn then
            antiAFKConn:Disconnect()
            antiAFKConn = nil
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
    local hum = getHumanoid()
    if hum then
        hum.UseJumpPower = true
        hum.WalkSpeed = State.Velocidad
        hum.JumpPower = State.Salto
    end
    setInstantUse(State.InstantUse)
    setFullbright(State.Fullbright)
    setESP(State.ESP)
    setHitbox(State.Hitbox)
    setFly(State.Fly)
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
Players.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if State.ESP and DrawingSupported and plr ~= LocalPlayer then
        createDrawings(plr)
    elseif State.ESP then
        attachHL(plr)
    end
    if State.Hitbox then
        task.defer(expandHead, plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    clearPlayerVisual(plr)
    local conn = ESPConns[plr]
    if conn then
        conn:Disconnect()
        ESPConns[plr] = nil
    end
end)

--──────────────────────── INICIO FINAL ──────────────────────────
if configLoaded then
    applyLoadedEffects()
    notify("SCP Roleplay Hub v5", "Cargado con tu configuración guardada.")
else
    notify("SCP Roleplay Hub v5", "Cargado. Todo lo que actives se guardará solo.")
end
