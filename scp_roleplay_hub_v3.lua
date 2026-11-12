--[[═══════════════════════════════════════════════════════════════
          SCP ROLEPLAY HUB v3  |  Rayfield Gen2
          · Solo carga en SCP Roleplay (PlaceId 5041144419)
          · Key System: clave 20112026
          · Combate:    Silent Aim, Hitbox de cabeza, Auto Recarga (R)
          · Jugador:    velocidad, salto, salto infinito, noclip
          · Visual:     ESP con color de equipo, fullbright
   ═══════════════════════════════════════════════════════════════]]

--// Servicios
local Players          = game:GetService("Players")
local RunService       = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Lighting         = game:GetService("Lighting")
local TeleportService  = game:GetService("TeleportService")
local VirtualUser      = game:GetService("VirtualUser")

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

--// Estado
local State = {
    Velocidad  = 16,
    Salto      = 50,
    InfJump    = false,
    Noclip     = false,
    ESP        = false,
    InstantUse = false,
    Fullbright = false,
    SilentAim  = false,
    FOV        = 120,
    IgnoreTeam = true,
    Hitbox     = false,
    HeadSize   = 6,
    AutoReload = false,
}

local Highlights = {} -- [Player] = Highlight

--────────────────────────── UTILIDADES ──────────────────────────
local function notify(title, content)
    Window:Notify({ title = title, content = content })
end

local function getHumanoid()
    local char = LocalPlayer.Character
    return char and char:FindFirstChildOfClass("Humanoid")
end

-- Reaplica velocidad y salto al reaparecer
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
local function removeESP(plr)
    local hl = Highlights[plr]
    if hl then
        hl:Destroy()
        Highlights[plr] = nil
    end
end

local function createESP(plr)
    if plr == LocalPlayer then return end
    local function attach(char)
        removeESP(plr)
        if not State.ESP then return end
        local hl = Instance.new("Highlight")
        hl.Name = "HubESP"
        hl.FillTransparency = 0.65
        hl.FillColor = (plr.Team and plr.Team.Color) or Color3.fromRGB(255, 60, 60)
        hl.OutlineColor = Color3.fromRGB(255, 255, 255)
        hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        hl.Parent = char
        Highlights[plr] = hl
    end
    if plr.Character then
        attach(plr.Character)
    end
    plr.CharacterAdded:Connect(attach)
end

local function setESP(on)
    State.ESP = on
    if on then
        for _, plr in ipairs(Players:GetPlayers()) do
            createESP(plr)
        end
    else
        for plr in pairs(Highlights) do
            removeESP(plr)
        end
    end
end

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

-- ¿El rayo sale de mi personaje/cámara? (evita redirigir rayos ajenos)
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

-- Jugador más cercano a la mira dentro del FOV
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
                            best, bestDist = plr, d
                        end
                    end
                end
            end
        end
    end
    return best
end

-- Instala el hook UNA sola vez; dentro se comprueba State.SilentAim
pcall(function()
    oldNamecall = hookmetamethod(game, "__namecall", newcclosure(function(self, ...)
        local method = getnamecallmethod()
        if State.SilentAim and self == workspace and (method == "Raycast" or method == "FindPartOnRay") then
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
    -- Caso 1: la munición es un IntValue/NumberValue dentro del arma
    local ammoVal = findAmmoValue(tool)
    if ammoVal then
        ammoVal.Changed:Connect(function(v)
            if State.AutoReload and v == 0 then
                task.wait(0.1)
                trySendReload()
            end
        end)
    end
    -- Caso 2: la munición es un atributo del Tool
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

-- Vigila spawns de otros jugadores (ESP + hitbox)
local function watchPlayer(plr)
    plr.CharacterAdded:Connect(function(char)
        task.wait(0.5)
        if State.Hitbox then
            expandHead(plr)
        end
    end)
end

for _, plr in ipairs(Players:GetPlayers()) do
    watchPlayer(plr)
end

--─────────────────────────── PRINCIPAL ──────────────────────────
TabMain:CreateToggle({
    name = "Interacción instantánea (E sin mantener)",
    callback = setInstantUse,
})

local antiAFKConn = nil
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
TabPlayer:CreateSlider({
    name = "Velocidad de movimiento",
    range = { 0, 200 },
    increment = 1,
    currentValue = 16,
    callback = function(value)
        State.Velocidad = value
        local hum = getHumanoid()
        if hum then
            hum.WalkSpeed = value
        end
    end,
})

TabPlayer:CreateSlider({
    name = "Altura de salto",
    range = { 20, 300 },
    increment = 1,
    currentValue = 50,
    callback = function(value)
        State.Salto = value
        local hum = getHumanoid()
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = value
        end
    end,
})

TabPlayer:CreateToggle({
    name = "Salto infinito",
    callback = function(on)
        State.InfJump = on
    end,
})

TabPlayer:CreateToggle({
    name = "Noclip (atravesar paredes)",
    callback = function(on)
        State.Noclip = on
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
        notify("Jugador", "Valores restablecidos a 16 / 50.")
    end,
})

--─────────────────────────── COMBATE ────────────────────────────
TabCombat:CreateToggle({
    name = "Silent Aim (las balas van a la cabeza)",
    callback = function(on)
        if on and not HookSupported then
            notify("Combate", "Tu ejecutor no soporta hookmetamethod. Silent Aim no disponible.")
            return
        end
        State.SilentAim = on
    end,
})

TabCombat:CreateSlider({
    name = "FOV del Silent Aim (píxeles)",
    range = { 10, 600 },
    increment = 1,
    currentValue = 120,
    callback = function(value)
        State.FOV = value
    end,
})

TabCombat:CreateToggle({
    name = "Ignorar aliados (no apuntar a tu equipo)",
    currentValue = true,
    callback = function(on)
        State.IgnoreTeam = on
    end,
})

TabCombat:CreateToggle({
    name = "Hitbox expander (cabeza)",
    callback = setHitbox,
})

TabCombat:CreateSlider({
    name = "Tamaño de la cabeza",
    range = { 2, 20 },
    increment = 0.5,
    currentValue = 6,
    callback = function(value)
        State.HeadSize = value
        if State.Hitbox then
            for _, plr in ipairs(Players:GetPlayers()) do
                expandHead(plr)
            end
        end
    end,
})

TabCombat:CreateToggle({
    name = "Auto Recarga (pulsa R solo al vaciar el cargador)",
    callback = function(on)
        State.AutoReload = on
        if on then
            notify("Combate", "Auto recarga activada.")
        end
    end,
})

--──────────────────────────── VISUAL ────────────────────────────
TabVisual:CreateToggle({
    name = "ESP (ver jugadores con color de equipo)",
    callback = setESP,
})

TabVisual:CreateToggle({
    name = "Fullbright (mapa iluminado, sin niebla)",
    callback = setFullbright,
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
        restoreHeads()
        State.Noclip = false
        State.SilentAim = false
        State.AutoReload = false
        Rayfield:Destroy()
    end,
})

--────────────────────── CONEXIONES DE JUGADORES ─────────────────
Players.PlayerAdded:Connect(function(plr)
    watchPlayer(plr)
    if State.ESP then
        createESP(plr)
    end
    if State.Hitbox then
        task.defer(expandHead, plr)
    end
end)

Players.PlayerRemoving:Connect(function(plr)
    removeESP(plr)
end)

--─────────────────────────── BIENVENIDA ─────────────────────────
notify("SCP Roleplay Hub", "Cargado correctamente en SCP Roleplay. ¡Que disfrutes!")
