--!strict
--[[
    DEV CHEAT SIMULATOR — Roblox Studio / Luau
    Внутриигровой "читерский" режим для СВОЕЙ игры.

    Куда вставлять:
    StarterPlayer > StarterPlayerScripts > DevCheatMenu (LocalScript)

    Бинды меняются во вкладке «Интерфейс».
    Всё работает из ОДНОГО LocalScript.
    Настройки можно экспортировать кодом и импортировать обратно.

    ВАЖНО:
    • Auto Fire здесь работает как внутриигровая симуляция состояния.
    • Он находит цель около прицела, проверяет команду и прямую видимость через Raycast.
    • Проверяются Head / Torso / HumanoidRootPart.
    • Если все точки закрыты стеной/объектом — состояние «ЗАКРЫТА».
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UIS = game:GetService("UserInputService")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Stats = game:GetService("Stats")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Camera = workspace.CurrentCamera

local CONFIG = {
    Aim = {
        Enabled = false,
        ShowFOV = true,
        FOV = 170,
        Speed = 100, -- 96..100 = почти мгновенно
        TeamCheck = true,
        VisibleOnly = true,
        TargetPart = "Head",
        HighlightTarget = true,
    },

    ESP = {
        Enabled = false,
        Boxes = true,
        CornerBoxes = false,
        Names = true,
        DisplayNames = true,
        HealthBar = true,
        NumericHP = true,
        Distance = true,
        Tracers = false,
        HeadDot = true,
        Direction = false,
        Chams = false,
        ChamsThroughWalls = true,
        FilledBox = false,
        Skeleton = false,
        Wireframe = false,
        WireframeDensity = 4,
        ToolName = true,
        VisibilityText = true,
        TeamTag = true,
        Offscreen = true,
        TeamColors = true,
        ShowTeammates = true,
        VisibilityTint = true,
        MaxDistance = 1200,
        TextSize = 13,
        BoxThickness = 2,
        Opacity = 0.95,
        ColorPreset = 1,
    },

    Radar = {
        Enabled = false,
        Range = 300,
        Size = 180,
        SeparateAllies = true,
    },

    Camera = {
        Freecam = false,
        FreecamSpeed = 70,
        FOV = 70,
    },

    AutoFire = {
        Enabled = false,
        CPS = 8,
        Radius = 26,
        TeamCheck = true,
        VisibleOnly = true,
        PauseWhenMenuOpen = true,
        MaxDistance = 1000,
        -- Реальная активация Tool (только для СВОЕЙ игры, где ты разработчик).
        ActivateTool = false,
        FireWhileButtonHeld = false,
    },

    SilentAim = {
        Enabled = false,
        FOV = 220,
        ShowFOV = true,
        TeamCheck = true,
        VisibleOnly = true,
        TargetPart = "Head",
        HighlightTarget = true,
        Color = Color3.fromRGB(255, 92, 130),
    },

    Movement = {
        Fly = false,
        FlySpeed = 55,
        HighJump = false,
        JumpPower = 100,
        InfiniteJump = false,
    },

    World = {
        Fullbright = false,
        NoFog = false,
        Crosshair = true,
        ShowFPS = true,
        ShowPing = true,
    },

    Visuals = {
        ChinaHat = false,
        Halo = false,
        OrbitLights = false,
        OrbitCount = 4,
        OrbitRadius = 3.4,
        OrbitSpeed = 1.8,
        BlackSky = false,
        Trail = false,
        JumpCircle = false,
        TargetRing = false,
        WorldTint = false,
        TintStrength = 0.22,
    },

    TP = {
        PullSelected = false,
        FreezeSelected = false,
        AutoSelectNewPlayers = false,
        FrontDistance = 7,
        FormationSpacing = 3.2,
        MaxPerRow = 5,
    },

    UI = {
        Scale = 1,
        Opacity = 0.03,
    },

    Keybinds = {
        Menu = "RightShift",
        Aim = "Q",
        ESP = "E",
        Fly = "F",
        Freecam = "C",
        Radar = "R",
        TPBehind = "G",
        TPCycle = "Y",
        Visuals = "V",
        SilentAim = "T",
        AutoFire = "X",
    }
}

-- Local-only profile import/export.
-- Roblox LocalScript cannot permanently write files or DataStore by itself,
-- so the whole profile is encoded into a text code the player can save manually.

local function deepMerge(target, source)
    if type(source) ~= "table" then return end
    for key, value in pairs(source) do
        if type(value) == "table" and type(target[key]) == "table" then
            deepMerge(target[key], value)
        elseif target[key] ~= nil and (type(value) == "boolean" or type(value) == "number" or type(value) == "string") then
            target[key] = value
        end
    end
end

local function scheduleSave()
    -- Intentionally empty: profile saving is manual via Export/Import code.
end

local function exportProfile(): string
    local ok, encoded = pcall(function()
        return HttpService:JSONEncode(CONFIG)
    end)
    if not ok then
        return "NBL4|ERROR"
    end
    return "NBL4|" .. encoded
end

local function importProfile(code: string): (boolean, string)
    if string.sub(code, 1, 5) ~= "NBL4|" then
        return false, "Неверный код профиля"
    end

    local payload = string.sub(code, 6)
    local ok, decoded = pcall(function()
        return HttpService:JSONDecode(payload)
    end)

    if not ok or type(decoded) ~= "table" then
        return false, "Код повреждён"
    end

    -- Добиваем отсутствующие секции/поля значениями по умолчанию,
    -- чтобы старые коды профиля не ломали новые функции.
    for sectionName, sectionTable in pairs(CONFIG) do
        if type(sectionTable) == "table" then
            decoded[sectionName] = decoded[sectionName] or {}
            for fieldName, defaultValue in pairs(sectionTable) do
                if decoded[sectionName][fieldName] == nil then
                    decoded[sectionName][fieldName] = defaultValue
                end
            end
        end
    end

    deepMerge(CONFIG, decoded)
    return true, "Профиль применён"
end

local COLOR_PRESETS = {
    {
        Name = "Красный / Синий",
        Enemy = Color3.fromRGB(255, 76, 98),
        Ally = Color3.fromRGB(76, 156, 255),
        Visible = Color3.fromRGB(85, 255, 165),
    },
    {
        Name = "Фиолетовый / Бирюза",
        Enemy = Color3.fromRGB(191, 96, 255),
        Ally = Color3.fromRGB(68, 229, 255),
        Visible = Color3.fromRGB(112, 255, 188),
    },
    {
        Name = "Белый / Золото",
        Enemy = Color3.fromRGB(245, 245, 250),
        Ally = Color3.fromRGB(255, 203, 82),
        Visible = Color3.fromRGB(113, 255, 143),
    },
    {
        Name = "Оранжевый / Зелёный",
        Enemy = Color3.fromRGB(255, 142, 70),
        Ally = Color3.fromRGB(90, 225, 134),
        Visible = Color3.fromRGB(255, 235, 100),
    },
}

local THEME = {
    Bg = Color3.fromRGB(10, 12, 18),
    Panel = Color3.fromRGB(17, 20, 29),
    Panel2 = Color3.fromRGB(22, 26, 37),
    Panel3 = Color3.fromRGB(29, 34, 48),
    Text = Color3.fromRGB(240, 243, 255),
    Muted = Color3.fromRGB(145, 153, 176),
    Accent = Color3.fromRGB(95, 105, 255),
    Accent2 = Color3.fromRGB(153, 91, 255),
    Good = Color3.fromRGB(78, 229, 151),
    Warn = Color3.fromRGB(255, 194, 74),
    Bad = Color3.fromRGB(255, 83, 102),
    Stroke = Color3.fromRGB(57, 64, 90),
}

---------------------------------------------------------------------
-- Helpers
---------------------------------------------------------------------

local function new(className: string, props: {[string]: any}?, parent: Instance?): Instance
    local obj = Instance.new(className)
    if props then
        for key, value in pairs(props) do
            (obj :: any)[key] = value
        end
    end
    if parent then
        obj.Parent = parent
    end
    return obj
end

local function round(obj: Instance, radius: number?)
    new("UICorner", {CornerRadius = UDim.new(0, radius or 9)}, obj)
end

local function stroke(obj: Instance, color: Color3?, thickness: number?, transparency: number?)
    return new("UIStroke", {
        Color = color or THEME.Stroke,
        Thickness = thickness or 1,
        Transparency = transparency or 0,
    }, obj)
end

local function tween(obj: Instance, time: number, props: {[string]: any})
    TweenService:Create(obj, TweenInfo.new(time, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), props):Play()
end

local function getCharacter(player: Player): Model?
    return player.Character
end

local function getHumanoid(player: Player): Humanoid?
    local character = getCharacter(player)
    return character and character:FindFirstChildOfClass("Humanoid") or nil
end

local function getRoot(player: Player): BasePart?
    local character = getCharacter(player)
    if not character then return nil end
    return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getTargetPart(player: Player, partName: string?): BasePart?
    local character = getCharacter(player)
    if not character then return nil end

    local requested = character:FindFirstChild(partName or CONFIG.Aim.TargetPart)
    if requested and requested:IsA("BasePart") then
        return requested
    end

    return (character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local function isAlive(player: Player): boolean
    local hum = getHumanoid(player)
    return hum ~= nil and hum.Health > 0
end

local function isAlly(player: Player): boolean
    return LocalPlayer.Team ~= nil and player.Team == LocalPlayer.Team
end

local function distanceTo(player: Player): number
    local a = getRoot(LocalPlayer)
    local b = getRoot(player)
    if not a or not b then return math.huge end
    return (a.Position - b.Position).Magnitude
end

local function isVisible(player: Player, part: BasePart?): boolean
    part = part or getTargetPart(player)
    if not part then return false end

    local character = LocalPlayer.Character
    local params = RaycastParams.new()
    params.FilterType = Enum.RaycastFilterType.Exclude
    params.FilterDescendantsInstances = character and {character} or {}
    params.IgnoreWater = true

    local origin = Camera.CFrame.Position
    local result = workspace:Raycast(origin, part.Position - origin, params)

    if not result then
        return true
    end

    local targetCharacter = player.Character
    return targetCharacter ~= nil and result.Instance:IsDescendantOf(targetCharacter)
end

local function currentPreset()
    return COLOR_PRESETS[CONFIG.ESP.ColorPreset]
end

---------------------------------------------------------------------
-- Root UI
---------------------------------------------------------------------

local old = PlayerGui:FindFirstChild("DevCheatSimulator")
if old then old:Destroy() end

local GUI = new("ScreenGui", {
    Name = "DevCheatSimulator",
    ResetOnSpawn = false,
    IgnoreGuiInset = true,
    DisplayOrder = 999,
    ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
}, PlayerGui) :: ScreenGui

local Shadow = new("Frame", {
    Name = "Shadow",
    Size = UDim2.fromOffset(854, 534),
    Position = UDim2.new(0.5, -421, 0.5, -257),
    BackgroundColor3 = Color3.new(0, 0, 0),
    BackgroundTransparency = 0.45,
    BorderSizePixel = 0,
}, GUI) :: Frame
round(Shadow, 18)

local Main = new("Frame", {
    Name = "Main",
    Size = UDim2.fromOffset(840, 520),
    Position = UDim2.new(0.5, -420, 0.5, -260),
    BackgroundColor3 = THEME.Panel,
    BackgroundTransparency = CONFIG.UI.Opacity,
    BorderSizePixel = 0,
    ClipsDescendants = true,
}, GUI) :: Frame
round(Main, 16)
stroke(Main, THEME.Stroke, 1, 0.1)

local Scale = new("UIScale", {Scale = CONFIG.UI.Scale}, Main) :: UIScale
local ShadowScale = new("UIScale", {Scale = CONFIG.UI.Scale}, Shadow) :: UIScale

local Sidebar = new("Frame", {
    Size = UDim2.new(0, 190, 1, 0),
    BackgroundColor3 = THEME.Bg,
    BackgroundTransparency = 0.08,
    BorderSizePixel = 0,
}, Main) :: Frame

local Brand = new("TextLabel", {
    Position = UDim2.fromOffset(18, 12),
    Size = UDim2.new(1, -30, 0, 50),
    BackgroundTransparency = 1,
    Text = "NEBULA  //  DEV",
    TextColor3 = THEME.Text,
    TextSize = 17,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar) :: TextLabel

local BrandSub = new("TextLabel", {
    Position = UDim2.fromOffset(18, 42),
    Size = UDim2.new(1, -30, 0, 24),
    BackgroundTransparency = 1,
    Text = "cheat simulator • local",
    TextColor3 = THEME.Muted,
    TextSize = 10,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Sidebar) :: TextLabel

local Nav = new("ScrollingFrame", {
    Position = UDim2.fromOffset(10, 79),
    Size = UDim2.new(1, -20, 1, -140),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 2,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
}, Sidebar) :: ScrollingFrame
new("UIListLayout", {Padding = UDim.new(0, 5)}, Nav)

local KeyHint = new("TextLabel", {
    Position = UDim2.new(0, 14, 1, -52),
    Size = UDim2.new(1, -28, 0, 38),
    BackgroundColor3 = THEME.Panel2,
    BorderSizePixel = 0,
    Text = "RightShift   меню",
    TextColor3 = THEME.Muted,
    TextSize = 11,
    Font = Enum.Font.GothamMedium,
}, Sidebar) :: TextLabel
round(KeyHint, 8)
stroke(KeyHint, THEME.Stroke, 1, 0.45)

local Topbar = new("Frame", {
    Position = UDim2.fromOffset(190, 0),
    Size = UDim2.new(1, -190, 0, 70),
    BackgroundColor3 = THEME.Panel,
    BorderSizePixel = 0,
}, Main) :: Frame

local PageTitle = new("TextLabel", {
    Position = UDim2.fromOffset(22, 12),
    Size = UDim2.fromOffset(250, 30),
    BackgroundTransparency = 1,
    Text = "AIM",
    TextColor3 = THEME.Text,
    TextSize = 22,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Topbar) :: TextLabel

local PageSub = new("TextLabel", {
    Position = UDim2.fromOffset(22, 39),
    Size = UDim2.fromOffset(330, 20),
    BackgroundTransparency = 1,
    Text = "настройки внутриигрового режима",
    TextColor3 = THEME.Muted,
    TextSize = 11,
    Font = Enum.Font.Gotham,
    TextXAlignment = Enum.TextXAlignment.Left,
}, Topbar) :: TextLabel

local Search = new("TextBox", {
    Position = UDim2.new(1, -248, 0, 18),
    Size = UDim2.fromOffset(224, 36),
    BackgroundColor3 = THEME.Panel2,
    BorderSizePixel = 0,
    PlaceholderText = "Поиск функции...",
    Text = "",
    TextColor3 = THEME.Text,
    PlaceholderColor3 = THEME.Muted,
    TextSize = 12,
    Font = Enum.Font.Gotham,
    ClearTextOnFocus = false,
}, Topbar) :: TextBox
round(Search, 9)
stroke(Search, THEME.Stroke, 1, 0.35)

local Content = new("Frame", {
    Position = UDim2.fromOffset(204, 76),
    Size = UDim2.new(1, -218, 1, -90),
    BackgroundTransparency = 1,
}, Main) :: Frame

local Pages: {[string]: ScrollingFrame} = {}
local PageRows: {[string]: {GuiObject}} = {}
local NavButtons: {[string]: TextButton} = {}
local CurrentPage = "AIM"

local function createPage(name: string): ScrollingFrame
    local page = new("ScrollingFrame", {
        Name = name,
        Size = UDim2.fromScale(1, 1),
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        ScrollBarThickness = 3,
        ScrollBarImageColor3 = THEME.Accent,
        AutomaticCanvasSize = Enum.AutomaticSize.Y,
        CanvasSize = UDim2.new(),
        Visible = false,
    }, Content) :: ScrollingFrame

    local layout = new("UIListLayout", {
        Padding = UDim.new(0, 8),
        SortOrder = Enum.SortOrder.LayoutOrder,
    }, page) :: UIListLayout

    new("UIPadding", {
        PaddingRight = UDim.new(0, 5),
        PaddingBottom = UDim.new(0, 8),
    }, page)

    Pages[name] = page
    PageRows[name] = {}
    return page
end

local function openPage(name: string)
    CurrentPage = name
    for pageName, page in pairs(Pages) do
        page.Visible = pageName == name
    end
    for buttonName, buttonObj in pairs(NavButtons) do
        if buttonName == name then
            tween(buttonObj, 0.15, {BackgroundColor3 = THEME.Accent})
            buttonObj.TextColor3 = Color3.new(1, 1, 1)
        else
            tween(buttonObj, 0.15, {BackgroundColor3 = THEME.Panel2})
            buttonObj.TextColor3 = THEME.Muted
        end
    end
    PageTitle.Text = name
    Search.Text = ""
end

local function navButton(name: string, icon: string)
    local b = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 36),
        BackgroundColor3 = THEME.Panel2,
        BorderSizePixel = 0,
        AutoButtonColor = false,
        Text = "  " .. icon .. "   " .. name,
        TextColor3 = THEME.Muted,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, Nav) :: TextButton
    round(b, 8)
    NavButtons[name] = b
    b.MouseButton1Click:Connect(function()
        openPage(name)
    end)
end

local function registerRow(pageName: string, row: GuiObject, searchText: string)
    row:SetAttribute("SearchText", string.lower(searchText))
    table.insert(PageRows[pageName], row)
end

local function section(pageName: string, text: string)
    local page = Pages[pageName]
    local label = new("TextLabel", {
        Size = UDim2.new(1, 0, 0, 28),
        BackgroundTransparency = 1,
        Text = string.upper(text),
        TextColor3 = THEME.Muted,
        TextSize = 10,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, page) :: TextLabel
    registerRow(pageName, label, text)
end

local function card(pageName: string, height: number, searchText: string): Frame
    local row = new("Frame", {
        Size = UDim2.new(1, 0, 0, height),
        BackgroundColor3 = THEME.Panel2,
        BorderSizePixel = 0,
    }, Pages[pageName]) :: Frame
    round(row, 10)
    stroke(row, THEME.Stroke, 1, 0.55)
    registerRow(pageName, row, searchText)
    return row
end

local function info(pageName: string, text: string): TextLabel
    local row = card(pageName, 38, text)
    local label = new("TextLabel", {
        Position = UDim2.fromOffset(12, 0),
        Size = UDim2.new(1, -24, 1, 0),
        BackgroundTransparency = 1,
        Text = text,
        TextColor3 = THEME.Muted,
        TextSize = 11,
        Font = Enum.Font.Gotham,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row) :: TextLabel
    return label
end

local function toggle(pageName: string, labelText: string, initial: boolean, callback: (boolean) -> ())
    local row = card(pageName, 46, labelText)
    local label = new("TextLabel", {
        Position = UDim2.fromOffset(13, 0),
        Size = UDim2.new(1, -84, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row) :: TextLabel

    local switch = new("TextButton", {
        Position = UDim2.new(1, -58, 0.5, -13),
        Size = UDim2.fromOffset(46, 26),
        BackgroundColor3 = initial and THEME.Accent or THEME.Panel3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row) :: TextButton
    round(switch, 13)

    local knob = new("Frame", {
        Size = UDim2.fromOffset(20, 20),
        Position = initial and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, switch) :: Frame
    round(knob, 10)

    local value = initial
    local function set(v: boolean)
        value = v
        tween(switch, 0.14, {BackgroundColor3 = value and THEME.Accent or THEME.Panel3})
        tween(knob, 0.14, {Position = value and UDim2.fromOffset(23, 3) or UDim2.fromOffset(3, 3)})
        callback(value)
        scheduleSave()
    end

    switch.MouseButton1Click:Connect(function()
        set(not value)
    end)

    callback(initial)
    return set
end

local function slider(
    pageName: string,
    labelText: string,
    initial: number,
    minimum: number,
    maximum: number,
    step: number,
    callback: (number) -> ()
)
    local row = card(pageName, 62, labelText)

    new("TextLabel", {
        Position = UDim2.fromOffset(13, 5),
        Size = UDim2.new(1, -90, 0, 24),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local valueLabel = new("TextLabel", {
        Position = UDim2.new(1, -72, 0, 5),
        Size = UDim2.fromOffset(58, 24),
        BackgroundTransparency = 1,
        TextColor3 = Color3.fromRGB(169, 178, 255),
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        TextXAlignment = Enum.TextXAlignment.Right,
    }, row) :: TextLabel

    local bar = new("TextButton", {
        Position = UDim2.fromOffset(13, 39),
        Size = UDim2.new(1, -26, 0, 7),
        BackgroundColor3 = THEME.Panel3,
        BorderSizePixel = 0,
        Text = "",
        AutoButtonColor = false,
    }, row) :: TextButton
    round(bar, 4)

    local fill = new("Frame", {
        Size = UDim2.new(0, 0, 1, 0),
        BackgroundColor3 = THEME.Accent,
        BorderSizePixel = 0,
    }, bar) :: Frame
    round(fill, 4)

    local dot = new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.fromScale(0, 0.5),
        Size = UDim2.fromOffset(13, 13),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
    }, bar) :: Frame
    round(dot, 7)

    local value = initial
    local dragging = false

    local function quantize(v: number): number
        local q = math.round((v - minimum) / step) * step + minimum
        return math.clamp(q, minimum, maximum)
    end

    local function set(v: number)
        value = quantize(v)
        local alpha = (value - minimum) / (maximum - minimum)
        fill.Size = UDim2.new(alpha, 0, 1, 0)
        dot.Position = UDim2.new(alpha, 0, 0.5, 0)
        valueLabel.Text = tostring(math.round(value * 100) / 100)
        callback(value)
        scheduleSave()
    end

    local function fromMouse()
        local x = UIS:GetMouseLocation().X
        local alpha = math.clamp((x - bar.AbsolutePosition.X) / math.max(bar.AbsoluteSize.X, 1), 0, 1)
        set(minimum + (maximum - minimum) * alpha)
    end

    bar.MouseButton1Down:Connect(function()
        dragging = true
        fromMouse()
    end)

    UIS.InputChanged:Connect(function(input)
        if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
            fromMouse()
        end
    end)

    UIS.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 then
            dragging = false
        end
    end)

    set(initial)
    return set
end

local function actionButton(pageName: string, labelText: string, callback: () -> ())
    local row = new("TextButton", {
        Size = UDim2.new(1, 0, 0, 42),
        BackgroundColor3 = THEME.Panel3,
        BorderSizePixel = 0,
        Text = labelText,
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, Pages[pageName]) :: TextButton
    round(row, 9)
    stroke(row, THEME.Stroke, 1, 0.4)
    registerRow(pageName, row, labelText)

    row.MouseEnter:Connect(function()
        tween(row, 0.12, {BackgroundColor3 = THEME.Accent})
    end)
    row.MouseLeave:Connect(function()
        tween(row, 0.12, {BackgroundColor3 = THEME.Panel3})
    end)
    row.MouseButton1Click:Connect(callback)
    return row
end

local waitingBind: string? = nil
local bindButtons: {[string]: TextButton} = {}

local function keybindControl(pageName: string, labelText: string, bindName: string)
    local row = card(pageName, 46, labelText .. " bind")

    new("TextLabel", {
        Position = UDim2.fromOffset(13, 0),
        Size = UDim2.new(1, -125, 1, 0),
        BackgroundTransparency = 1,
        Text = labelText,
        TextColor3 = THEME.Text,
        TextSize = 12,
        Font = Enum.Font.GothamMedium,
        TextXAlignment = Enum.TextXAlignment.Left,
    }, row)

    local button = new("TextButton", {
        Position = UDim2.new(1, -112, 0.5, -13),
        Size = UDim2.fromOffset(100, 26),
        BackgroundColor3 = THEME.Panel3,
        BorderSizePixel = 0,
        Text = (CONFIG.Keybinds :: any)[bindName] or "None",
        TextColor3 = THEME.Text,
        TextSize = 11,
        Font = Enum.Font.GothamBold,
        AutoButtonColor = false,
    }, row) :: TextButton
    round(button, 7)
    bindButtons[bindName] = button

    button.MouseButton1Click:Connect(function()
        waitingBind = bindName
        button.Text = "Нажми..."
        button.BackgroundColor3 = THEME.Accent
    end)
end

---------------------------------------------------------------------
-- Pages + navigation
---------------------------------------------------------------------

local pageNames = {
    {"AIM", "🎯"},
    {"Silent Aim", "🔇"},
    {"ESP", "👁"},
    {"VISUALS", "✨"},
    {"Радар", "📡"},
    {"Камера", "🎥"},
    {"Автострельба", "⚡"},
    {"Движение", "✈"},
    {"TP", "📍"},
    {"Мир", "💡"},
    {"Player Info", "👤"},
    {"Интерфейс", "⚙"},
}

for _, data in ipairs(pageNames) do
    createPage(data[1])
    navButton(data[1], data[2])
end

Search:GetPropertyChangedSignal("Text"):Connect(function()
    local q = string.lower(Search.Text)
    for _, row in ipairs(PageRows[CurrentPage] or {}) do
        local text = row:GetAttribute("SearchText") or ""
        row.Visible = q == "" or string.find(text, q, 1, true) ~= nil
    end
end)

---------------------------------------------------------------------
-- Overlay primitives
---------------------------------------------------------------------

local Overlay = new("Frame", {
    Name = "Overlay",
    Size = UDim2.fromScale(1, 1),
    BackgroundTransparency = 1,
    ZIndex = 10,
}, GUI) :: Frame

local FOVCircle = new("Frame", {
    Name = "FOV",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 20,
}, Overlay) :: Frame
round(FOVCircle, 999)
local FOVStroke = stroke(FOVCircle, Color3.fromRGB(120, 132, 255), 1, 0.1)
FOVStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local CrossH = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(18, 2),
    BackgroundColor3 = Color3.fromRGB(245, 247, 255),
    BorderSizePixel = 0,
    ZIndex = 30,
}, Overlay) :: Frame
local CrossV = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Size = UDim2.fromOffset(2, 18),
    BackgroundColor3 = Color3.fromRGB(245, 247, 255),
    BorderSizePixel = 0,
    ZIndex = 30,
}, Overlay) :: Frame
round(CrossH, 2)
round(CrossV, 2)

local HUD = new("TextLabel", {
    Position = UDim2.fromOffset(16, 16),
    Size = UDim2.fromOffset(255, 92),
    BackgroundColor3 = THEME.Bg,
    BackgroundTransparency = 0.18,
    BorderSizePixel = 0,
    Text = "",
    TextColor3 = THEME.Text,
    TextSize = 12,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
    ZIndex = 50,
}, GUI) :: TextLabel
round(HUD, 10)
stroke(HUD, THEME.Stroke, 1, 0.35)

---------------------------------------------------------------------
-- Aim highlight
---------------------------------------------------------------------

local AimHighlight = new("Highlight", {
    Name = "DevAimHighlight",
    Enabled = false,
    FillColor = Color3.fromRGB(255, 78, 104),
    FillTransparency = 0.76,
    OutlineColor = Color3.fromRGB(255, 255, 255),
    OutlineTransparency = 0.08,
    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}, workspace) :: Highlight

---------------------------------------------------------------------
-- ESP objects
---------------------------------------------------------------------

type ESPData = {
    SilentRing: CylinderHandleAdornment?,
    Box: Frame,
    BoxStroke: UIStroke,
    Corners: {Frame},
    Name: TextLabel,
    Info: TextLabel,
    HPBack: Frame,
    HPFill: Frame,
    Dot: Frame,
    Tracer: Frame,
    Direction: Frame,
    Arrow: TextLabel,
    Highlight: Highlight,
    Fill: Frame,
    Extra: TextLabel,
    Skeleton: {Frame},
    Wireframe: {Frame},
}

local ESPObjects: {[Player]: ESPData} = {}

local function lineFrame(parent: Instance): Frame
    return new("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 15,
    }, parent) :: Frame
end

local function setLine(frame: Frame, x1: number, y1: number, x2: number, y2: number, thickness: number)
    local dx, dy = x2 - x1, y2 - y1
    local len = math.sqrt(dx * dx + dy * dy)
    frame.Size = UDim2.fromOffset(len, thickness)
    frame.Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2)
    frame.Rotation = math.deg(math.atan2(dy, dx))
end

local function createCorner(parent: Instance): Frame
    return new("Frame", {
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 13,
    }, parent) :: Frame
end

local function createESP(player: Player): ESPData
    if ESPObjects[player] then return ESPObjects[player] end

    local box = new("Frame", {
        BackgroundTransparency = 1,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 12,
    }, Overlay) :: Frame
    local boxStroke = stroke(box, Color3.new(1, 1, 1), CONFIG.ESP.BoxThickness, 0)

    local fill = new("Frame", {
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.88,
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 11,
    }, box) :: Frame

    local corners = {}
    for _ = 1, 8 do
        table.insert(corners, createCorner(box))
    end

    local name = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(260, 20),
        TextColor3 = Color3.new(1, 1, 1),
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.35,
        TextSize = CONFIG.ESP.TextSize,
        Font = Enum.Font.GothamBold,
        Visible = false,
        ZIndex = 14,
    }, Overlay) :: TextLabel

    local infoLabel = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(260, 18),
        TextColor3 = Color3.fromRGB(225, 230, 245),
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.35,
        TextSize = math.max(10, CONFIG.ESP.TextSize - 1),
        Font = Enum.Font.Code,
        Visible = false,
        ZIndex = 14,
    }, Overlay) :: TextLabel

    local hpBack = new("Frame", {
        BackgroundColor3 = Color3.fromRGB(18, 20, 25),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 14,
    }, Overlay) :: Frame
    round(hpBack, 2)

    local hpFill = new("Frame", {
        AnchorPoint = Vector2.new(0, 1),
        Position = UDim2.fromScale(0, 1),
        Size = UDim2.fromScale(1, 1),
        BackgroundColor3 = THEME.Good,
        BorderSizePixel = 0,
        ZIndex = 15,
    }, hpBack) :: Frame
    round(hpFill, 2)

    local dot = new("Frame", {
        Size = UDim2.fromOffset(7, 7),
        BackgroundColor3 = Color3.new(1, 1, 1),
        BorderSizePixel = 0,
        Visible = false,
        ZIndex = 15,
    }, Overlay) :: Frame
    round(dot, 7)

    local tracer = lineFrame(Overlay)
    local direction = lineFrame(Overlay)

    local arrow = new("TextLabel", {
        Size = UDim2.fromOffset(28, 28),
        BackgroundColor3 = THEME.Bg,
        BackgroundTransparency = 0.2,
        Text = "◆",
        TextColor3 = Color3.new(1, 1, 1),
        TextSize = 16,
        Font = Enum.Font.GothamBold,
        Visible = false,
        ZIndex = 16,
    }, Overlay) :: TextLabel
    round(arrow, 14)

    local extra = new("TextLabel", {
        BackgroundTransparency = 1,
        Size = UDim2.fromOffset(300, 18),
        TextColor3 = Color3.fromRGB(225, 230, 245),
        TextStrokeColor3 = Color3.new(0, 0, 0),
        TextStrokeTransparency = 0.3,
        TextSize = math.max(10, CONFIG.ESP.TextSize - 2),
        Font = Enum.Font.Code,
        Visible = false,
        ZIndex = 14,
    }, Overlay) :: TextLabel

    local skeleton = {}
    for _ = 1, 18 do
        table.insert(skeleton, lineFrame(Overlay))
    end

    local wireframe = {}
    for _ = 1, 18 do
        table.insert(wireframe, lineFrame(Overlay))
    end

    local highlight = new("Highlight", {
        Enabled = false,
        FillTransparency = 0.82,
        OutlineTransparency = 0.12,
        DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
    }, workspace) :: Highlight

    local data: ESPData = {
        SilentRing = nil,
        Box = box,
        BoxStroke = boxStroke :: UIStroke,
        Corners = corners,
        Name = name,
        Info = infoLabel,
        HPBack = hpBack,
        HPFill = hpFill,
        Dot = dot,
        Tracer = tracer,
        Direction = direction,
        Arrow = arrow,
        Highlight = highlight,
        Fill = fill,
        Extra = extra,
        Skeleton = skeleton,
        Wireframe = wireframe,
    }

    ESPObjects[player] = data
    return data
end

local function hideESP(data: ESPData)
    if data.SilentRing then data.SilentRing.Visible = false end
    data.Box.Visible = false
    data.Name.Visible = false
    data.Info.Visible = false
    data.HPBack.Visible = false
    data.Dot.Visible = false
    data.Tracer.Visible = false
    data.Direction.Visible = false
    data.Arrow.Visible = false
    data.Highlight.Enabled = false
    data.Fill.Visible = false
    data.Extra.Visible = false
    for _, line in ipairs(data.Skeleton) do line.Visible = false end
    for _, line in ipairs(data.Wireframe) do line.Visible = false end
    for _, c in ipairs(data.Corners) do
        c.Visible = false
    end
end

local function projectedBounds(character: Model): (number?, number?, number?, number?)
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    local valid = 0

    -- Считаем рамку только по частям тела.
    -- Tool/аксессуары больше не растягивают ESP в сторону.
    for _, part in ipairs(character:GetChildren()) do
        if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
            local cf = part.CFrame
            local size = part.Size
            local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2

            for _, x in ipairs({-hx, hx}) do
                for _, y in ipairs({-hy, hy}) do
                    for _, z in ipairs({-hz, hz}) do
                        local world = cf:PointToWorldSpace(Vector3.new(x, y, z))
                        local p = Camera:WorldToViewportPoint(world)

                        if p.Z > 0 then
                            valid += 1
                            minX = math.min(minX, p.X)
                            minY = math.min(minY, p.Y)
                            maxX = math.max(maxX, p.X)
                            maxY = math.max(maxY, p.Y)
                        end
                    end
                end
            end
        end
    end

    if valid < 4 then
        return nil, nil, nil, nil
    end

    local padX = math.clamp((maxX - minX) * 0.03, 1, 4)
    local padY = math.clamp((maxY - minY) * 0.02, 1, 4)

    return minX - padX, minY - padY, maxX + padX, maxY + padY
end

local function updateCorners(data: ESPData, width: number, height: number, color: Color3)
    local len = math.clamp(math.min(width, height) * 0.23, 8, 22)
    local t = CONFIG.ESP.BoxThickness

    for _, c in ipairs(data.Corners) do
        c.BackgroundColor3 = color
        c.Visible = CONFIG.ESP.CornerBoxes
    end

    -- TL horizontal / vertical
    data.Corners[1].Position = UDim2.fromOffset(0, 0)
    data.Corners[1].Size = UDim2.fromOffset(len, t)
    data.Corners[2].Position = UDim2.fromOffset(0, 0)
    data.Corners[2].Size = UDim2.fromOffset(t, len)

    -- TR
    data.Corners[3].Position = UDim2.new(1, -len, 0, 0)
    data.Corners[3].Size = UDim2.fromOffset(len, t)
    data.Corners[4].Position = UDim2.new(1, -t, 0, 0)
    data.Corners[4].Size = UDim2.fromOffset(t, len)

    -- BL
    data.Corners[5].Position = UDim2.new(0, 0, 1, -t)
    data.Corners[5].Size = UDim2.fromOffset(len, t)
    data.Corners[6].Position = UDim2.new(0, 0, 1, -len)
    data.Corners[6].Size = UDim2.fromOffset(t, len)

    -- BR
    data.Corners[7].Position = UDim2.new(1, -len, 1, -t)
    data.Corners[7].Size = UDim2.fromOffset(len, t)
    data.Corners[8].Position = UDim2.new(1, -t, 1, -len)
    data.Corners[8].Size = UDim2.fromOffset(t, len)
end


local function drawSkeleton(data: ESPData, character: Model, color: Color3)
    for _, line in ipairs(data.Skeleton) do
        line.Visible = false
    end

    if not CONFIG.ESP.Skeleton then
        return
    end

    local links

    if character:FindFirstChild("UpperTorso") then
        links = {
            {"Head", "UpperTorso"},
            {"UpperTorso", "LowerTorso"},
            {"UpperTorso", "LeftUpperArm"},
            {"LeftUpperArm", "LeftLowerArm"},
            {"LeftLowerArm", "LeftHand"},
            {"UpperTorso", "RightUpperArm"},
            {"RightUpperArm", "RightLowerArm"},
            {"RightLowerArm", "RightHand"},
            {"LowerTorso", "LeftUpperLeg"},
            {"LeftUpperLeg", "LeftLowerLeg"},
            {"LeftLowerLeg", "LeftFoot"},
            {"LowerTorso", "RightUpperLeg"},
            {"RightUpperLeg", "RightLowerLeg"},
            {"RightLowerLeg", "RightFoot"},
        }
    else
        links = {
            {"Head", "Torso"},
            {"Torso", "Left Arm"},
            {"Torso", "Right Arm"},
            {"Torso", "Left Leg"},
            {"Torso", "Right Leg"},
        }
    end

    local index = 1

    for _, pair in ipairs(links) do
        local a = character:FindFirstChild(pair[1])
        local b = character:FindFirstChild(pair[2])

        if a and b and a:IsA("BasePart") and b:IsA("BasePart") then
            local pa, ona = Camera:WorldToViewportPoint(a.Position)
            local pb, onb = Camera:WorldToViewportPoint(b.Position)

            if pa.Z > 0 and pb.Z > 0 and (ona or onb) then
                local line = data.Skeleton[index]

                if line then
                    line.BackgroundColor3 = color
                    line.BackgroundTransparency = 1 - CONFIG.ESP.Opacity
                    line.Visible = true

                    setLine(
                        line,
                        pa.X,
                        pa.Y,
                        pb.X,
                        pb.Y,
                        math.max(1, CONFIG.ESP.BoxThickness * 0.7)
                    )

                    index += 1
                end
            end
        end
    end
end


local function drawWireframe(data: ESPData, minX: number, minY: number, maxX: number, maxY: number, color: Color3)
    for _, line in ipairs(data.Wireframe) do
        line.Visible = false
    end

    if not CONFIG.ESP.Wireframe then
        return
    end

    local density = math.clamp(math.floor(CONFIG.ESP.WireframeDensity), 2, 6)
    local index = 1
    local width = maxX - minX
    local height = maxY - minY

    local function useLine(x1, y1, x2, y2)
        local line = data.Wireframe[index]
        if not line then
            return
        end

        line.BackgroundColor3 = color
        line.BackgroundTransparency = math.clamp(0.35 + (1 - CONFIG.ESP.Opacity), 0.2, 0.8)
        line.Visible = true

        setLine(
            line,
            x1,
            y1,
            x2,
            y2,
            math.max(1, CONFIG.ESP.BoxThickness * 0.5)
        )

        index += 1
    end

    for i = 1, density do
        local a = i / (density + 1)
        local x = minX + width * a
        local y = minY + height * a

        useLine(x, minY, x, maxY)
        useLine(minX, y, maxX, y)
    end

    useLine(minX, minY, maxX, maxY)
    useLine(maxX, minY, minX, maxY)
end

---------------------------------------------------------------------
-- Radar
---------------------------------------------------------------------

local Radar = new("Frame", {
    Name = "Radar",
    Position = UDim2.new(1, -206, 0, 18),
    Size = UDim2.fromOffset(CONFIG.Radar.Size, CONFIG.Radar.Size),
    BackgroundColor3 = THEME.Bg,
    BackgroundTransparency = 0.12,
    BorderSizePixel = 0,
    Visible = false,
    ZIndex = 40,
}, GUI) :: Frame
round(Radar, 14)
stroke(Radar, THEME.Stroke, 1, 0.2)

local RadarTitle = new("TextLabel", {
    Position = UDim2.fromOffset(10, 7),
    Size = UDim2.new(1, -20, 0, 18),
    BackgroundTransparency = 1,
    Text = "RADAR",
    TextColor3 = THEME.Muted,
    TextSize = 9,
    Font = Enum.Font.GothamBold,
    TextXAlignment = Enum.TextXAlignment.Left,
    ZIndex = 42,
}, Radar) :: TextLabel

new("Frame", {
    Position = UDim2.new(0.5, -1, 0, 28),
    Size = UDim2.new(0, 1, 1, -35),
    BackgroundColor3 = THEME.Stroke,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 41,
}, Radar)

new("Frame", {
    Position = UDim2.new(0, 7, 0.5, 13),
    Size = UDim2.new(1, -14, 0, 1),
    BackgroundColor3 = THEME.Stroke,
    BackgroundTransparency = 0.4,
    BorderSizePixel = 0,
    ZIndex = 41,
}, Radar)

local RadarMe = new("Frame", {
    AnchorPoint = Vector2.new(0.5, 0.5),
    Position = UDim2.new(0.5, 0, 0.5, 13),
    Size = UDim2.fromOffset(8, 8),
    BackgroundColor3 = Color3.new(1, 1, 1),
    BorderSizePixel = 0,
    ZIndex = 44,
}, Radar) :: Frame
round(RadarMe, 8)

local RadarDots: {[Player]: Frame} = {}

---------------------------------------------------------------------
-- Targeting
---------------------------------------------------------------------

local function findNearestTarget(radius: number, teamCheck: boolean, visibleOnly: boolean, maxWorldDistance: number?, partName: string?): Player?
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local best: Player? = nil
    local bestDistance = radius

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            if teamCheck and isAlly(player) then
                continue
            end
            if maxWorldDistance and distanceTo(player) > maxWorldDistance then
                continue
            end

            local part = getTargetPart(player, partName)
            if not part then continue end

            local point, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen and point.Z > 0 then
                local screenDistance = (Vector2.new(point.X, point.Y) - center).Magnitude
                if screenDistance <= bestDistance then
                    if (not visibleOnly) or isVisible(player, part) then
                        bestDistance = screenDistance
                        best = player
                    end
                end
            end
        end
    end

    return best
end

local function nearestCandidateIgnoringWall(radius: number, teamCheck: boolean, maxWorldDistance: number?): Player?
    return findNearestTarget(radius, teamCheck, false, maxWorldDistance)
end

local function getEquippedTool(): Tool?
    local character = LocalPlayer.Character
    if not character then return nil end
    return character:FindFirstChildOfClass("Tool")
end

local function getAutoFireVisiblePart(player: Player): BasePart?
    local character = player.Character
    if not character then return nil end

    local candidates = {
        character:FindFirstChild("Head"),
        character:FindFirstChild("UpperTorso"),
        character:FindFirstChild("Torso"),
        character:FindFirstChild("HumanoidRootPart"),
    }

    for _, part in ipairs(candidates) do
        if part and part:IsA("BasePart") and isVisible(player, part) then
            return part
        end
    end

    return nil
end

---------------------------------------------------------------------

---------------------------------------------------------------------
-- Local cosmetic visuals
---------------------------------------------------------------------

local VisualFolder = new("Folder", {Name = "NebulaLocalVisuals"}, workspace)

---------------------------------------------------------------------
-- Silent Aim internals
---------------------------------------------------------------------

local SilentCircle = new("Frame", {
    Name = "SilentFOV",
    AnchorPoint = Vector2.new(0.5, 0.5),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ZIndex = 21,
}, Overlay) :: Frame
round(SilentCircle, 999)
local SilentCircleStroke = stroke(SilentCircle, CONFIG.SilentAim.Color, 1, 0.15)
SilentCircleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

local SilentHighlight = new("Highlight", {
    Name = "DevSilentHighlight",
    Enabled = false,
    FillColor = CONFIG.SilentAim.Color,
    FillTransparency = 0.72,
    OutlineColor = CONFIG.SilentAim.Color,
    OutlineTransparency = 0.05,
    DepthMode = Enum.HighlightDepthMode.AlwaysOnTop,
}, workspace) :: Highlight

local CurrentSilentTarget: Player? = nil

local function getSilentTargetPart(player: Player): BasePart?
    local character = player.Character
    if not character then return nil end
    local requested = character:FindFirstChild(CONFIG.SilentAim.TargetPart)
    if requested and requested:IsA("BasePart") then
        return requested
    end
    return (character:FindFirstChild("Head")
        or character:FindFirstChild("UpperTorso")
        or character:FindFirstChild("Torso")
        or character:FindFirstChild("HumanoidRootPart")) :: BasePart?
end

local function findSilentTarget(): Player?
    local viewport = Camera.ViewportSize
    local center = Vector2.new(viewport.X / 2, viewport.Y / 2)
    local best: Player? = nil
    local bestDistance = CONFIG.SilentAim.FOV

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            if CONFIG.SilentAim.TeamCheck and isAlly(player) then
                continue
            end

            local part = getSilentTargetPart(player)
            if not part then continue end

            local point, onScreen = Camera:WorldToViewportPoint(part.Position)
            if onScreen and point.Z > 0 then
                local screenDistance = (Vector2.new(point.X, point.Y) - center).Magnitude
                if screenDistance <= bestDistance then
                    if (not CONFIG.SilentAim.VisibleOnly) or isVisible(player, part) then
                        bestDistance = screenDistance
                        best = player
                    end
                end
            end
        end
    end

    return best
end

local function ensureSilentRing(data: ESPData): CylinderHandleAdornment
    if data.SilentRing and data.SilentRing.Parent then
        return data.SilentRing
    end
    data.SilentRing = new("CylinderHandleAdornment", {
        Name = "SilentRing",
        AlwaysOnTop = true,
        Height = 0.06,
        Radius = 2.4,
        Color3 = CONFIG.SilentAim.Color,
        Transparency = 0.14,
        ZIndex = 4,
        Visible = false,
    }, VisualFolder) :: CylinderHandleAdornment
    return data.SilentRing
end

-- Отслеживание нажатия ЛКМ (момент «выстрела»).
local MouseDownTime = 0
local LastFireClock = 0

local MouseHeld = false

UIS.InputBegan:Connect(function(input, processed)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MouseDownTime = os.clock()
        MouseHeld = true
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        MouseHeld = false
    end
end)

-- Сколько миллисекунд после клика считаем, что идёт выстрел.
local FIRE_WINDOW_MS = 250

local function isShootingNow(): boolean
    if os.clock() - MouseDownTime <= FIRE_WINDOW_MS / 1000 then
        return true
    end
    -- Режим автострельбы: стрельба идёт постоянно с заданным CPS.
    if CONFIG.AutoFire.Enabled and CONFIG.AutoFire.ActivateTool then
        local interval = 1 / math.max(CONFIG.AutoFire.CPS, 1)
        if os.clock() - LastFireClock < interval + FIRE_WINDOW_MS / 1000 then
            return true
        end
    end
    return false
end

-- Подмена результата Raycast для СВОЕЙ игры:
-- RemoteEvent'ы хранят последний результат FindFirstRaycast в поле .Instance.
-- Если ты стреляешь через другой механизм — скажи, и я поменяю точку подмены.
local targetRemote = ReplicatedStorage:FindFirstChild("ShootEvent", true)
if targetRemote and targetRemote:IsA("RemoteEvent") then
    local original = targetRemote.OnClientEvent
    local metatable = getmetatable(original)

    if metatable and type(metatable.__index) == "table" then
        local methods = metatable.__index
        local originalFindFirst = methods.FindFirstRaycast

        methods.FindFirstRaycast = function(self, ...)
            local result = originalFindFirst(self, ...)

            if CONFIG.SilentAim.Enabled and isShootingNow() then
                local target = CurrentSilentTarget
                if target and target ~= LocalPlayer and isAlive(target) then
                    local part = getSilentTargetPart(target)
                    if part then
                        local origin = Camera.CFrame.Position
                        local direction = (part.Position - origin) * 500

                        local params = RaycastParams.new()
                        params.FilterType = Enum.RaycastFilterType.Exclude
                        local character = LocalPlayer.Character
                        params.FilterDescendantsInstances = character and {character} or {}
                        params.IgnoreWater = true

                        local newResult = workspace:Raycast(origin, direction, params)
                        if newResult and newResult.Instance:IsDescendantOf(target.Character) then
                            result = newResult
                        elseif result then
                            rawset(result, "Instance", part)
                            rawset(result, "Position", part.Position)
                            rawset(result, "Normal", (origin - part.Position).Unit)
                        end
                    end
                end
            end

            return result
        end
    end
end
local ColorFX = new("ColorCorrectionEffect", {
    Name = "NebulaWorldTint",
    Enabled = false,
    TintColor = Color3.fromRGB(165, 130, 255),
    Saturation = 0.05,
    Contrast = 0.06,
}, Lighting) :: ColorCorrectionEffect

local ChinaHat: ConeHandleAdornment? = nil
local Halo: CylinderHandleAdornment? = nil
local TargetRing: CylinderHandleAdornment? = nil
local OrbitParts: {BasePart} = {}
local TrailObject: Trail? = nil
local TrailA0: Attachment? = nil
local TrailA1: Attachment? = nil

local VisualOriginal = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

local function destroyOrbit()
    for _, part in ipairs(OrbitParts) do
        if part then part:Destroy() end
    end
    table.clear(OrbitParts)
end

local function refreshCharacterVisuals()
    local character = LocalPlayer.Character
    if not character then return end

    local head = character:FindFirstChild("Head") :: BasePart?
    local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?

    if ChinaHat then ChinaHat:Destroy(); ChinaHat = nil end
    if Halo then Halo:Destroy(); Halo = nil end
    if TrailObject then TrailObject:Destroy(); TrailObject = nil end
    if TrailA0 then TrailA0:Destroy(); TrailA0 = nil end
    if TrailA1 then TrailA1:Destroy(); TrailA1 = nil end
    destroyOrbit()

    if CONFIG.Visuals.ChinaHat and head then
        ChinaHat = new("ConeHandleAdornment", {
            Name = "ChinaHat",
            Adornee = head,
            AlwaysOnTop = true,
            Height = 0.55,
            Radius = 1.55,
            CFrame = CFrame.new(0, 1.18, 0) * CFrame.Angles(math.rad(-90), 0, 0),
            Color3 = Color3.fromRGB(155, 105, 255),
            Transparency = 0.22,
            ZIndex = 2,
        }, VisualFolder) :: ConeHandleAdornment
    end

    if CONFIG.Visuals.Halo and head then
        Halo = new("CylinderHandleAdornment", {
            Name = "Halo",
            Adornee = head,
            AlwaysOnTop = true,
            Height = 0.08,
            Radius = 1.05,
            CFrame = CFrame.new(0, 1.65, 0),
            Color3 = Color3.fromRGB(255, 226, 105),
            Transparency = 0.14,
            ZIndex = 3,
        }, VisualFolder) :: CylinderHandleAdornment
    end

    if CONFIG.Visuals.Trail and root then
        TrailA0 = new("Attachment", {
            Name = "NebulaTrailA0",
            Position = Vector3.new(-0.8, -1.1, 0),
        }, root) :: Attachment
        TrailA1 = new("Attachment", {
            Name = "NebulaTrailA1",
            Position = Vector3.new(0.8, -1.1, 0),
        }, root) :: Attachment

        TrailObject = new("Trail", {
            Name = "NebulaTrail",
            Attachment0 = TrailA0,
            Attachment1 = TrailA1,
            Lifetime = 0.5,
            MinLength = 0.05,
            FaceCamera = true,
            LightEmission = 0.7,
            Transparency = NumberSequence.new({
                NumberSequenceKeypoint.new(0, 0.05),
                NumberSequenceKeypoint.new(1, 1),
            }),
            Color = ColorSequence.new(
                Color3.fromRGB(100, 115, 255),
                Color3.fromRGB(190, 85, 255)
            ),
        }, root) :: Trail
    end

    if CONFIG.Visuals.OrbitLights and root then
        for i = 1, math.clamp(math.floor(CONFIG.Visuals.OrbitCount), 1, 8) do
            local p = new("Part", {
                Name = "OrbitLight",
                Shape = Enum.PartType.Ball,
                Size = Vector3.new(0.34, 0.34, 0.34),
                Material = Enum.Material.Neon,
                Color = (i % 2 == 0) and Color3.fromRGB(105, 120, 255) or Color3.fromRGB(190, 90, 255),
                CanCollide = false,
                CanTouch = false,
                CanQuery = false,
                Anchored = true,
                CastShadow = false,
                Transparency = 0.06,
            }, VisualFolder) :: BasePart
            table.insert(OrbitParts, p)
        end
    end
end

local function spawnJumpCircle()
    if not CONFIG.Visuals.JumpCircle then return end
    local root = getRoot(LocalPlayer)
    if not root then return end

    local ring = new("Part", {
        Name = "JumpCircle",
        Shape = Enum.PartType.Cylinder,
        Size = Vector3.new(0.06, 2.2, 2.2),
        CFrame = CFrame.new(root.Position - Vector3.new(0, 2.7, 0)) * CFrame.Angles(0, 0, math.rad(90)),
        Anchored = true,
        CanCollide = false,
        CanQuery = false,
        CanTouch = false,
        Material = Enum.Material.Neon,
        Color = Color3.fromRGB(130, 100, 255),
        Transparency = 0.2,
        CastShadow = false,
    }, VisualFolder) :: BasePart

    TweenService:Create(ring, TweenInfo.new(0.55, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = Vector3.new(0.03, 8.5, 8.5),
        Transparency = 1,
    }):Play()

    task.delay(0.62, function()
        if ring then ring:Destroy() end
    end)
end


-- UI controls
---------------------------------------------------------------------

-- AIM
section("AIM", "Основное")
toggle("AIM", "Главный AIM", CONFIG.Aim.Enabled, function(v) CONFIG.Aim.Enabled = v end)
toggle("AIM", "FOV-круг", CONFIG.Aim.ShowFOV, function(v) CONFIG.Aim.ShowFOV = v end)
slider("AIM", "Размер FOV", CONFIG.Aim.FOV, 30, 450, 5, function(v) CONFIG.Aim.FOV = v end)
slider("AIM", "Скорость AIM", CONFIG.Aim.Speed, 1, 100, 1, function(v) CONFIG.Aim.Speed = v end)
toggle("AIM", "Проверка команды", CONFIG.Aim.TeamCheck, function(v) CONFIG.Aim.TeamCheck = v end)
toggle("AIM", "Только видимые цели", CONFIG.Aim.VisibleOnly, function(v) CONFIG.Aim.VisibleOnly = v end)
toggle("AIM", "Подсветка текущей цели", CONFIG.Aim.HighlightTarget, function(v) CONFIG.Aim.HighlightTarget = v end)
local AimStatus = info("AIM", "Цель: нет")

-- Silent Aim (UI)
section("Silent Aim", "Основное")
toggle("Silent Aim", "Включить Silent Aim", CONFIG.SilentAim.Enabled, function(v) CONFIG.SilentAim.Enabled = v end)
toggle("Silent Aim", "Показывать FOV-круг", CONFIG.SilentAim.ShowFOV, function(v) CONFIG.SilentAim.ShowFOV = v end)
slider("Silent Aim", "Размер FOV (пиксели)", CONFIG.SilentAim.FOV, 50, 600, 10, function(v) CONFIG.SilentAim.FOV = v end)
toggle("Silent Aim", "Проверка команды", CONFIG.SilentAim.TeamCheck, function(v) CONFIG.SilentAim.TeamCheck = v end)
toggle("Silent Aim", "Только видимые цели", CONFIG.SilentAim.VisibleOnly, function(v) CONFIG.SilentAim.VisibleOnly = v end)
toggle("Silent Aim", "Кружок под целью", CONFIG.SilentAim.HighlightTarget, function(v) CONFIG.SilentAim.HighlightTarget = v end)
local SilentStatus = info("Silent Aim", "Статус: выключен")

-- ESP
section("ESP", "Отображение")
toggle("ESP", "Включить ESP", CONFIG.ESP.Enabled, function(v) CONFIG.ESP.Enabled = v end)
toggle("ESP", "Обычная рамка", CONFIG.ESP.Boxes, function(v) CONFIG.ESP.Boxes = v end)
toggle("ESP", "Угловая рамка", CONFIG.ESP.CornerBoxes, function(v) CONFIG.ESP.CornerBoxes = v end)
toggle("ESP", "Ник", CONFIG.ESP.Names, function(v) CONFIG.ESP.Names = v end)
toggle("ESP", "Display Name", CONFIG.ESP.DisplayNames, function(v) CONFIG.ESP.DisplayNames = v end)
toggle("ESP", "Полоска здоровья", CONFIG.ESP.HealthBar, function(v) CONFIG.ESP.HealthBar = v end)
toggle("ESP", "Числовое HP", CONFIG.ESP.NumericHP, function(v) CONFIG.ESP.NumericHP = v end)
toggle("ESP", "Расстояние", CONFIG.ESP.Distance, function(v) CONFIG.ESP.Distance = v end)
toggle("ESP", "Линия снизу экрана", CONFIG.ESP.Tracers, function(v) CONFIG.ESP.Tracers = v end)
toggle("ESP", "Точка над головой", CONFIG.ESP.HeadDot, function(v) CONFIG.ESP.HeadDot = v end)
toggle("ESP", "Направление взгляда", CONFIG.ESP.Direction, function(v) CONFIG.ESP.Direction = v end)
toggle("ESP", "Подсветка силуэта", CONFIG.ESP.Chams, function(v) CONFIG.ESP.Chams = v end)
toggle("ESP", "Силуэт через стены", CONFIG.ESP.ChamsThroughWalls, function(v) CONFIG.ESP.ChamsThroughWalls = v end)
toggle("ESP", "Полупрозрачная заливка рамки", CONFIG.ESP.FilledBox, function(v) CONFIG.ESP.FilledBox = v end)
toggle("ESP", "Скелет", CONFIG.ESP.Skeleton, function(v) CONFIG.ESP.Skeleton = v end)
toggle("ESP", "Сетчатый режим / Wireframe", CONFIG.ESP.Wireframe, function(v) CONFIG.ESP.Wireframe = v end)
slider("ESP", "Плотность сетки", CONFIG.ESP.WireframeDensity, 2, 6, 1, function(v) CONFIG.ESP.WireframeDensity = v end)
toggle("ESP", "Tool / оружие", CONFIG.ESP.ToolName, function(v) CONFIG.ESP.ToolName = v end)
toggle("ESP", "Статус видимости", CONFIG.ESP.VisibilityText, function(v) CONFIG.ESP.VisibilityText = v end)
toggle("ESP", "Тег команды", CONFIG.ESP.TeamTag, function(v) CONFIG.ESP.TeamTag = v end)
toggle("ESP", "Индикатор за экраном", CONFIG.ESP.Offscreen, function(v) CONFIG.ESP.Offscreen = v end)

section("ESP", "Фильтры")
toggle("ESP", "Показывать союзников", CONFIG.ESP.ShowTeammates, function(v) CONFIG.ESP.ShowTeammates = v end)
toggle("ESP", "Разные цвета команд", CONFIG.ESP.TeamColors, function(v) CONFIG.ESP.TeamColors = v end)
toggle("ESP", "Отдельный цвет видимой цели", CONFIG.ESP.VisibilityTint, function(v) CONFIG.ESP.VisibilityTint = v end)
slider("ESP", "Макс. дистанция", CONFIG.ESP.MaxDistance, 100, 3000, 50, function(v) CONFIG.ESP.MaxDistance = v end)

section("ESP", "Внешний вид")
slider("ESP", "Размер текста", CONFIG.ESP.TextSize, 10, 20, 1, function(v) CONFIG.ESP.TextSize = v end)
slider("ESP", "Толщина рамки", CONFIG.ESP.BoxThickness, 1, 5, 0.5, function(v) CONFIG.ESP.BoxThickness = v end)
slider("ESP", "Прозрачность ESP", CONFIG.ESP.Opacity, 0.2, 1, 0.05, function(v) CONFIG.ESP.Opacity = v end)

local ESPPresetButton
ESPPresetButton = actionButton("ESP", "🎨 Цвета: " .. currentPreset().Name, function()
    CONFIG.ESP.ColorPreset += 1
    if CONFIG.ESP.ColorPreset > #COLOR_PRESETS then
        CONFIG.ESP.ColorPreset = 1
    end
    ESPPresetButton.Text = "🎨 Цвета: " .. currentPreset().Name
    scheduleSave()
end)
local ESPCount = info("ESP", "Игроков на ESP: 0")

-- VISUALS
section("VISUALS", "Игрок")
toggle("VISUALS", "China Hat", CONFIG.Visuals.ChinaHat, function(v)
    CONFIG.Visuals.ChinaHat = v
    refreshCharacterVisuals()
end)
toggle("VISUALS", "Halo", CONFIG.Visuals.Halo, function(v)
    CONFIG.Visuals.Halo = v
    refreshCharacterVisuals()
end)
toggle("VISUALS", "Orbit Lights", CONFIG.Visuals.OrbitLights, function(v)
    CONFIG.Visuals.OrbitLights = v
    refreshCharacterVisuals()
end)
slider("VISUALS", "Количество Orbit Lights", CONFIG.Visuals.OrbitCount, 1, 8, 1, function(v)
    CONFIG.Visuals.OrbitCount = v
    if CONFIG.Visuals.OrbitLights then refreshCharacterVisuals() end
end)
slider("VISUALS", "Радиус орбиты", CONFIG.Visuals.OrbitRadius, 1.5, 7, 0.1, function(v)
    CONFIG.Visuals.OrbitRadius = v
end)
slider("VISUALS", "Скорость орбиты", CONFIG.Visuals.OrbitSpeed, 0.2, 5, 0.1, function(v)
    CONFIG.Visuals.OrbitSpeed = v
end)
toggle("VISUALS", "Trail", CONFIG.Visuals.Trail, function(v)
    CONFIG.Visuals.Trail = v
    refreshCharacterVisuals()
end)
toggle("VISUALS", "Jump Circle", CONFIG.Visuals.JumpCircle, function(v)
    CONFIG.Visuals.JumpCircle = v
end)
toggle("VISUALS", "Target Ring", CONFIG.Visuals.TargetRing, function(v)
    CONFIG.Visuals.TargetRing = v
end)

section("VISUALS", "Мир")
toggle("VISUALS", "Black Sky", CONFIG.Visuals.BlackSky, function(v)
    CONFIG.Visuals.BlackSky = v
    if v then
        Lighting.ClockTime = 0
        Lighting.Brightness = 0.35
        Lighting.Ambient = Color3.fromRGB(10, 10, 18)
        Lighting.OutdoorAmbient = Color3.fromRGB(5, 5, 10)
    else
        Lighting.ClockTime = VisualOriginal.ClockTime
        Lighting.Brightness = VisualOriginal.Brightness
        Lighting.Ambient = VisualOriginal.Ambient
        Lighting.OutdoorAmbient = VisualOriginal.OutdoorAmbient
    end
end)
toggle("VISUALS", "World Tint", CONFIG.Visuals.WorldTint, function(v)
    CONFIG.Visuals.WorldTint = v
    ColorFX.Enabled = v
end)
slider("VISUALS", "Сила World Tint", CONFIG.Visuals.TintStrength, 0, 0.75, 0.05, function(v)
    CONFIG.Visuals.TintStrength = v
    ColorFX.Contrast = v * 0.35
    ColorFX.Saturation = v * 0.3
end)

-- Radar
section("Радар", "Мини-карта")
toggle("Радар", "Включить радар", CONFIG.Radar.Enabled, function(v) CONFIG.Radar.Enabled = v end)
slider("Радар", "Дальность", CONFIG.Radar.Range, 50, 1500, 25, function(v) CONFIG.Radar.Range = v end)
toggle("Радар", "Союзники отдельным цветом", CONFIG.Radar.SeparateAllies, function(v) CONFIG.Radar.SeparateAllies = v end)

-- Camera
section("Камера", "Наблюдение")
local SpectateIndex = 0
actionButton("Камера", "👁 Следующий игрок", function()
    local list = {}
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and isAlive(player) then
            table.insert(list, player)
        end
    end
    if #list == 0 then return end
    SpectateIndex = (SpectateIndex % #list) + 1
    local hum = getHumanoid(list[SpectateIndex])
    if hum then
        CONFIG.Camera.Freecam = false
        Camera.CameraType = Enum.CameraType.Custom
        Camera.CameraSubject = hum
    end
end)

toggle("Камера", "Свободная камера", CONFIG.Camera.Freecam, function(v)
    CONFIG.Camera.Freecam = v
    if v then
        Camera.CameraType = Enum.CameraType.Scriptable
    else
        Camera.CameraType = Enum.CameraType.Custom
        local hum = getHumanoid(LocalPlayer)
        if hum then Camera.CameraSubject = hum end
    end
end)
slider("Камера", "Скорость свободной камеры", CONFIG.Camera.FreecamSpeed, 10, 250, 5, function(v) CONFIG.Camera.FreecamSpeed = v end)
slider("Камера", "FOV камеры", CONFIG.Camera.FOV, 40, 120, 1, function(v)
    CONFIG.Camera.FOV = v
    Camera.FieldOfView = v
end)
actionButton("Камера", "Первое лицо", function()
    LocalPlayer.CameraMode = Enum.CameraMode.LockFirstPerson
end)
actionButton("Камера", "Третье лицо", function()
    LocalPlayer.CameraMode = Enum.CameraMode.Classic
    LocalPlayer.CameraMinZoomDistance = 0.5
    LocalPlayer.CameraMaxZoomDistance = 30
end)
actionButton("Камера", "↩ Вернуть камеру к себе", function()
    CONFIG.Camera.Freecam = false
    Camera.CameraType = Enum.CameraType.Custom
    local hum = getHumanoid(LocalPlayer)
    if hum then Camera.CameraSubject = hum end
end)

-- Auto Fire
section("Автострельба", "Автоматическая активация Tool")
toggle("Автострельба", "Включить автострельбу", CONFIG.AutoFire.Enabled, function(v) CONFIG.AutoFire.Enabled = v end)
slider("Автострельба", "Скорость / CPS", CONFIG.AutoFire.CPS, 1, 20, 1, function(v) CONFIG.AutoFire.CPS = v end)
slider("Автострельба", "Радиус около прицела", CONFIG.AutoFire.Radius, 5, 100, 1, function(v) CONFIG.AutoFire.Radius = v end)
slider("Автострельба", "Макс. дистанция", CONFIG.AutoFire.MaxDistance, 100, 2500, 50, function(v) CONFIG.AutoFire.MaxDistance = v end)
toggle("Автострельба", "Проверка команды", CONFIG.AutoFire.TeamCheck, function(v) CONFIG.AutoFire.TeamCheck = v end)
toggle("Автострельба", "Проверка препятствий", CONFIG.AutoFire.VisibleOnly, function(v) CONFIG.AutoFire.VisibleOnly = v end)
toggle("Автострельба", "Пауза при открытом меню", CONFIG.AutoFire.PauseWhenMenuOpen, function(v) CONFIG.AutoFire.PauseWhenMenuOpen = v end)
toggle("Автострельба", "Реально активировать Tool (своя игра)", CONFIG.AutoFire.ActivateTool, function(v) CONFIG.AutoFire.ActivateTool = v end)
toggle("Автострельба", "Стрелять, пока зажата ЛКМ", CONFIG.AutoFire.FireWhileButtonHeld, function(v) CONFIG.AutoFire.FireWhileButtonHeld = v end)
local FireStatus = info("Автострельба", "Статус: выключено")
local ToolStatus = info("Автострельба", "Tool: не экипирован")

-- Movement
section("Движение", "Передвижение")
toggle("Движение", "Полёт", CONFIG.Movement.Fly, function(v) CONFIG.Movement.Fly = v end)
slider("Движение", "Скорость полёта", CONFIG.Movement.FlySpeed, 10, 200, 5, function(v) CONFIG.Movement.FlySpeed = v end)
toggle("Движение", "Высокий прыжок", CONFIG.Movement.HighJump, function(v)
    CONFIG.Movement.HighJump = v
    local hum = getHumanoid(LocalPlayer)
    if hum then
        hum.UseJumpPower = true
        hum.JumpPower = v and CONFIG.Movement.JumpPower or 50
    end
end)
slider("Движение", "Сила высокого прыжка", CONFIG.Movement.JumpPower, 50, 180, 5, function(v)
    CONFIG.Movement.JumpPower = v
    local hum = getHumanoid(LocalPlayer)
    if hum and CONFIG.Movement.HighJump then hum.JumpPower = v end
end)
toggle("Движение", "Бесконечный прыжок", CONFIG.Movement.InfiniteJump, function(v) CONFIG.Movement.InfiniteJump = v end)
local SpeedInfo = info("Движение", "Текущая скорость: 0")

-- TP
section("TP", "Игроки с галочками")
local SelectedPlayer: Player? = nil
local SavedPosition: CFrame? = nil
local CheckedPlayers: {[number]: boolean} = {}
local PlayerRows: {[Player]: TextButton} = {}
local TPCycleEnabled = false
local TPCycleIndex = 0
local CurrentCycleTarget: Player? = nil
local CurrentDeathConnection: RBXScriptConnection? = nil

-- Игроки, которых именно этот LocalScript локально заанкорил.
-- Это позволяет не снимать Anchor у объектов, которые были заморожены самой игрой.
local LocallyFrozen: {[number]: boolean} = {}
local GroupControlAccumulator = 0

local SelectedLabel = info("TP", "Текущая цель: не выбрана")
local TPDistance = info("TP", "Расстояние: —")

local listCard = card("TP", 190, "список игроков")
local PlayerList = new("ScrollingFrame", {
    Position = UDim2.fromOffset(8, 8),
    Size = UDim2.new(1, -16, 1, -16),
    BackgroundTransparency = 1,
    BorderSizePixel = 0,
    ScrollBarThickness = 3,
    AutomaticCanvasSize = Enum.AutomaticSize.Y,
    CanvasSize = UDim2.new(),
}, listCard) :: ScrollingFrame
new("UIListLayout", {Padding = UDim.new(0, 5)}, PlayerList)

local function sortedPlayers(): {Player}
    local list = {}
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then table.insert(list, p) end
    end
    table.sort(list, function(a, b)
        return string.lower(a.Name) < string.lower(b.Name)
    end)
    return list
end

local function checkedAlivePlayers(): {Player}
    local list = {}
    for _, p in ipairs(sortedPlayers()) do
        if CheckedPlayers[p.UserId] and isAlive(p) then
            table.insert(list, p)
        end
    end
    return list
end

local function setSelected(p: Player?)
    SelectedPlayer = p
    if p then
        SelectedLabel.Text = "Текущая цель: " .. p.Name .. " [" .. p.DisplayName .. "]"
    else
        SelectedLabel.Text = "Текущая цель: не выбрана"
    end
end

local function rebuildPlayerList()
    for _, row in pairs(PlayerRows) do
        row:Destroy()
    end
    table.clear(PlayerRows)

    for _, p in ipairs(sortedPlayers()) do
        local checked = CheckedPlayers[p.UserId] == true
        local row = new("TextButton", {
            Size = UDim2.new(1, -4, 0, 34),
            BackgroundColor3 = THEME.Panel3,
            BorderSizePixel = 0,
            Text = (checked and "☑  " or "☐  ") .. p.Name .. "  [" .. p.DisplayName .. "]",
            TextColor3 = checked and THEME.Good or THEME.Text,
            TextSize = 11,
            Font = Enum.Font.GothamMedium,
            TextXAlignment = Enum.TextXAlignment.Left,
            AutoButtonColor = false,
        }, PlayerList) :: TextButton
        round(row, 7)
        PlayerRows[p] = row

        row.MouseButton1Click:Connect(function()
            CheckedPlayers[p.UserId] = not (CheckedPlayers[p.UserId] == true)

            if not CheckedPlayers[p.UserId] and LocallyFrozen[p.UserId] then
                local root = getRoot(p)

                if root then
                    root.Anchored = false
                end

                LocallyFrozen[p.UserId] = nil
            end

            setSelected(p)
            rebuildPlayerList()
        end)
    end
end

local function teleportBehind(p: Player, distance: number?)
    local myCharacter = LocalPlayer.Character
    local targetRoot = getRoot(p)
    if not myCharacter or not targetRoot then return end

    local d = distance or 3
    local pos = targetRoot.CFrame * CFrame.new(0, 0, d)
    myCharacter:PivotTo(CFrame.lookAt(pos.Position, targetRoot.Position))
    setSelected(p)
end

local function teleportTo(p: Player)
    local myCharacter = LocalPlayer.Character
    local targetRoot = getRoot(p)
    if not myCharacter or not targetRoot then return end
    myCharacter:PivotTo(targetRoot.CFrame * CFrame.new(3, 0, 0))
    setSelected(p)
end

local function unfreezePlayerLocally(p: Player)
    if not LocallyFrozen[p.UserId] then
        return
    end

    local root = getRoot(p)

    if root then
        root.Anchored = false
    end

    LocallyFrozen[p.UserId] = nil
end

local function releaseAllLocalFreeze()
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            unfreezePlayerLocally(p)
        end
    end
end

local function checkedCount(): number
    local count = 0

    for _, p in ipairs(sortedPlayers()) do
        if CheckedPlayers[p.UserId] then
            count += 1
        end
    end

    return count
end

local function pullSelectedNow()
    local myRoot = getRoot(LocalPlayer)

    if not myRoot then
        return
    end

    local list = checkedAlivePlayers()

    if #list == 0 then
        return
    end

    local perRow = math.clamp(
        math.floor(CONFIG.TP.MaxPerRow),
        1,
        8
    )

    local spacing = CONFIG.TP.FormationSpacing
    local frontDistance = CONFIG.TP.FrontDistance

    for index, p in ipairs(list) do
        local character = p.Character
        local root = getRoot(p)

        if character and root then
            local zeroIndex = index - 1
            local row = math.floor(zeroIndex / perRow)
            local column = zeroIndex % perRow

            local itemsInThisRow = math.min(
                perRow,
                #list - row * perRow
            )

            local centeredColumn =
                column - (itemsInThisRow - 1) / 2

            -- В Roblox локальный -Z = направление вперёд.
            local targetCF =
                myRoot.CFrame
                * CFrame.new(
                    centeredColumn * spacing,
                    0,
                    -frontDistance - row * spacing
                )

            character:PivotTo(
                CFrame.lookAt(
                    targetCF.Position,
                    myRoot.Position
                )
            )

            if CONFIG.TP.FreezeSelected then
                root.AssemblyLinearVelocity = Vector3.zero
                root.AssemblyAngularVelocity = Vector3.zero
                root.Anchored = true
                LocallyFrozen[p.UserId] = true
            elseif LocallyFrozen[p.UserId] then
                root.Anchored = false
                LocallyFrozen[p.UserId] = nil
            end
        end
    end

    -- Если с игрока сняли галочку, а мы раньше его заморозили —
    -- возвращаем движение.
    for _, p in ipairs(sortedPlayers()) do
        if not CheckedPlayers[p.UserId] then
            unfreezePlayerLocally(p)
        end
    end
end

local function stopTPCycle()
    TPCycleEnabled = false
    CurrentCycleTarget = nil
    if CurrentDeathConnection then
        CurrentDeathConnection:Disconnect()
        CurrentDeathConnection = nil
    end
end

local goNextCycleTarget
goNextCycleTarget = function()
    if not TPCycleEnabled then return end

    if CurrentDeathConnection then
        CurrentDeathConnection:Disconnect()
        CurrentDeathConnection = nil
    end

    local list = checkedAlivePlayers()
    if #list == 0 then
        stopTPCycle()
        SelectedLabel.Text = "TP-цикл: нет живых отмеченных игроков"
        return
    end

    TPCycleIndex = (TPCycleIndex % #list) + 1
    local target = list[TPCycleIndex]
    CurrentCycleTarget = target
    teleportBehind(target, 3)

    local hum = getHumanoid(target)
    if hum then
        CurrentDeathConnection = hum.Died:Connect(function()
            task.wait(0.12)
            goNextCycleTarget()
        end)
    end
end

actionButton("TP", "☑ Выбрать всех", function()
    for _, p in ipairs(sortedPlayers()) do
        CheckedPlayers[p.UserId] = true
    end
    rebuildPlayerList()
end)

actionButton("TP", "☐ Снять все", function()
    table.clear(CheckedPlayers)
    releaseAllLocalFreeze()
    rebuildPlayerList()
end)

section("TP", "Групповое управление")

toggle("TP", "Притягивать выбранных перед собой", CONFIG.TP.PullSelected, function(v)
    CONFIG.TP.PullSelected = v

    if v then
        pullSelectedNow()
    end
end)

toggle("TP", "Заморозить выбранных", CONFIG.TP.FreezeSelected, function(v)
    CONFIG.TP.FreezeSelected = v

    if v then
        pullSelectedNow()
    else
        releaseAllLocalFreeze()
    end
end)

toggle("TP", "Автоматически отмечать новых игроков", CONFIG.TP.AutoSelectNewPlayers, function(v)
    CONFIG.TP.AutoSelectNewPlayers = v
end)

slider("TP", "Дистанция перед собой", CONFIG.TP.FrontDistance, 3, 25, 1, function(v)
    CONFIG.TP.FrontDistance = v
end)

slider("TP", "Расстояние между игроками", CONFIG.TP.FormationSpacing, 2, 8, 0.2, function(v)
    CONFIG.TP.FormationSpacing = v
end)

slider("TP", "Игроков в одном ряду", CONFIG.TP.MaxPerRow, 1, 8, 1, function(v)
    CONFIG.TP.MaxPerRow = v
end)

local GroupTPStatus = info("TP", "Группа: выключена")

actionButton("TP", "🧲 Притянуть выбранных сейчас", function()
    pullSelectedNow()
end)

actionButton("TP", "🔓 Разморозить выбранных", function()
    CONFIG.TP.FreezeSelected = false
    releaseAllLocalFreeze()
end)

actionButton("TP", "📍 TP к текущему", function()
    if SelectedPlayer then teleportTo(SelectedPlayer) end
end)

actionButton("TP", "⚡ TP за спину текущему", function()
    if SelectedPlayer then teleportBehind(SelectedPlayer, 3) end
end)

actionButton("TP", "▶ Запустить TP-цикл", function()
    TPCycleEnabled = true
    TPCycleIndex = 0
    goNextCycleTarget()
end)

actionButton("TP", "⏹ Остановить TP-цикл", function()
    stopTPCycle()
end)

actionButton("TP", "💾 Сохранить позицию", function()
    local root = getRoot(LocalPlayer)
    if root then SavedPosition = root.CFrame end
end)

actionButton("TP", "↩ Вернуться в сохранённую позицию", function()
    if SavedPosition and LocalPlayer.Character then
        LocalPlayer.Character:PivotTo(SavedPosition)
    end
end)

rebuildPlayerList()

Players.PlayerAdded:Connect(function(p)
    if CONFIG.TP.AutoSelectNewPlayers and p ~= LocalPlayer then
        CheckedPlayers[p.UserId] = true
    end

    -- Галочка хранится по UserId, поэтому после CharacterAdded/респавна
    -- этот же игрок автоматически снова попадает под Pull/Freeze.
    p.CharacterAdded:Connect(function()
        task.wait(0.15)

        if CheckedPlayers[p.UserId]
            and (CONFIG.TP.PullSelected or CONFIG.TP.FreezeSelected) then

            pullSelectedNow()
        end
    end)

    rebuildPlayerList()
end)

-- Подключаем респавн уже присутствующих игроков.
for _, existingPlayer in ipairs(Players:GetPlayers()) do
    if existingPlayer ~= LocalPlayer then
        existingPlayer.CharacterAdded:Connect(function()
            task.wait(0.15)

            if CheckedPlayers[existingPlayer.UserId]
                and (CONFIG.TP.PullSelected or CONFIG.TP.FreezeSelected) then

                pullSelectedNow()
            end
        end)
    end
end

Players.PlayerRemoving:Connect(function(p)
    CheckedPlayers[p.UserId] = nil
    LocallyFrozen[p.UserId] = nil

    if SelectedPlayer == p then
        setSelected(nil)
    end

    if CurrentCycleTarget == p and TPCycleEnabled then
        task.defer(goNextCycleTarget)
    end

    task.defer(rebuildPlayerList)
end)

-- Постоянное клиентское удержание выбранных игроков.
-- Для реальных сетевых игроков сервер может периодически вернуть позицию,
-- поэтому при включённом PullSelected мы повторяем позиционирование.
RunService.Heartbeat:Connect(function(dt)
    GroupControlAccumulator += dt

    -- ~30 обновлений/сек достаточно плавно и заметно легче, чем каждый frame.
    if GroupControlAccumulator < (1 / 30) then
        return
    end

    GroupControlAccumulator = 0

    if CONFIG.TP.PullSelected or CONFIG.TP.FreezeSelected then
        pullSelectedNow()
    elseif next(LocallyFrozen) ~= nil then
        releaseAllLocalFreeze()
    end

    local modeParts = {}

    if CONFIG.TP.PullSelected then
        table.insert(modeParts, "TP ON")
    end

    if CONFIG.TP.FreezeSelected then
        table.insert(modeParts, "FREEZE ON")
    end

    GroupTPStatus.Text =
        string.format(
            "Отмечено: %d  •  %s",
            checkedCount(),
            #modeParts > 0 and table.concat(modeParts, " + ") or "группа выключена"
        )
end)

-- World
local OriginalLighting = {
    Brightness = Lighting.Brightness,
    ClockTime = Lighting.ClockTime,
    FogStart = Lighting.FogStart,
    FogEnd = Lighting.FogEnd,
    Ambient = Lighting.Ambient,
    OutdoorAmbient = Lighting.OutdoorAmbient,
}

section("Мир", "Визуал")
toggle("Мир", "Fullbright", CONFIG.World.Fullbright, function(v)
    CONFIG.World.Fullbright = v
    if v then
        Lighting.Brightness = 3
        Lighting.ClockTime = 14
        Lighting.Ambient = Color3.fromRGB(180, 180, 190)
        Lighting.OutdoorAmbient = Color3.fromRGB(185, 185, 195)
    else
        Lighting.Brightness = OriginalLighting.Brightness
        Lighting.ClockTime = OriginalLighting.ClockTime
        Lighting.Ambient = OriginalLighting.Ambient
        Lighting.OutdoorAmbient = OriginalLighting.OutdoorAmbient
    end
end)
toggle("Мир", "Убрать туман", CONFIG.World.NoFog, function(v)
    CONFIG.World.NoFog = v
    if v then
        Lighting.FogStart = 100000
        Lighting.FogEnd = 1000000
    else
        Lighting.FogStart = OriginalLighting.FogStart
        Lighting.FogEnd = OriginalLighting.FogEnd
    end
end)
toggle("Мир", "Дополнительный прицел", CONFIG.World.Crosshair, function(v) CONFIG.World.Crosshair = v end)
toggle("Мир", "Показывать FPS", CONFIG.World.ShowFPS, function(v) CONFIG.World.ShowFPS = v end)
toggle("Мир", "Показывать Ping", CONFIG.World.ShowPing, function(v) CONFIG.World.ShowPing = v end)
local WorldTime = info("Мир", "Время мира: —")

-- Player Info
section("Player Info", "Информация")
local PlayerInfo1 = info("Player Info", "Ник: —")
local PlayerInfo2 = info("Player Info", "User ID: —")
local PlayerInfo3 = info("Player Info", "Команда: —")
local PlayerInfo4 = info("Player Info", "HP: —")
local PlayerInfo5 = info("Player Info", "Расстояние: —")
local PlayerInfoIndex = 0
actionButton("Player Info", "Следующий игрок", function()
    local list = sortedPlayers()
    if #list == 0 then return end
    PlayerInfoIndex = (PlayerInfoIndex % #list) + 1
    setSelected(list[PlayerInfoIndex])
end)

-- Interface
section("Интерфейс", "Бинды")
keybindControl("Интерфейс", "Открыть меню", "Menu")
keybindControl("Интерфейс", "AIM вкл/выкл", "Aim")
keybindControl("Интерфейс", "ESP вкл/выкл", "ESP")
keybindControl("Интерфейс", "Полёт вкл/выкл", "Fly")
keybindControl("Интерфейс", "Freecam вкл/выкл", "Freecam")
keybindControl("Интерфейс", "Радар вкл/выкл", "Radar")
keybindControl("Интерфейс", "VISUALS вкл/выкл", "Visuals")
keybindControl("Интерфейс", "TP за спину", "TPBehind")
keybindControl("Интерфейс", "TP-цикл", "TPCycle")
keybindControl("Интерфейс", "Silent Aim вкл/выкл", "SilentAim")
keybindControl("Интерфейс", "Автострельба вкл/выкл", "AutoFire")

section("Интерфейс", "Профиль настроек")
local ProfileCodeBox = new("TextBox", {
    Size = UDim2.new(1, 0, 0, 82),
    BackgroundColor3 = THEME.Panel2,
    BorderSizePixel = 0,
    Text = "",
    PlaceholderText = "Здесь появится код профиля или вставь код сюда...",
    TextWrapped = true,
    MultiLine = true,
    ClearTextOnFocus = false,
    TextColor3 = THEME.Text,
    PlaceholderColor3 = THEME.Muted,
    TextSize = 10,
    Font = Enum.Font.Code,
    TextXAlignment = Enum.TextXAlignment.Left,
    TextYAlignment = Enum.TextYAlignment.Top,
}, Pages["Интерфейс"]) :: TextBox
round(ProfileCodeBox, 9)
stroke(ProfileCodeBox, THEME.Stroke, 1, 0.4)
registerRow("Интерфейс", ProfileCodeBox, "код профиля экспорт импорт")

local ProfileStatus = info("Интерфейс", "Профиль: готов")
actionButton("Интерфейс", "💾 Сгенерировать код настроек", function()
    ProfileCodeBox.Text = exportProfile()
    ProfileStatus.Text = "Профиль: код создан — скопируй его"
end)
actionButton("Интерфейс", "📂 Применить вставленный код", function()
    local ok, message = importProfile(ProfileCodeBox.Text)
    ProfileStatus.Text = "Профиль: " .. message
    if ok then
        -- Старый профиль мог иметь одну клавишу сразу на две функции.
        local usedKeys = {}

        for bindName, keyName in pairs(CONFIG.Keybinds) do
            if keyName ~= "None" and usedKeys[keyName] then
                (CONFIG.Keybinds :: any)[bindName] = "None"
            elseif keyName ~= "None" then
                usedKeys[keyName] = bindName
            end
        end

        Scale.Scale = CONFIG.UI.Scale
        ShadowScale.Scale = CONFIG.UI.Scale
        Main.BackgroundTransparency = CONFIG.UI.Opacity
        Camera.FieldOfView = CONFIG.Camera.FOV
        ColorFX.Enabled = CONFIG.Visuals.WorldTint
        refreshCharacterVisuals()

        for bindName, button in pairs(bindButtons) do
            button.Text = (CONFIG.Keybinds :: any)[bindName] or "None"
        end
    end
end)

section("Интерфейс", "Окно")
slider("Интерфейс", "Масштаб интерфейса", CONFIG.UI.Scale, 0.7, 1.35, 0.05, function(v)
    CONFIG.UI.Scale = v
    Scale.Scale = v
    ShadowScale.Scale = v
end)
slider("Интерфейс", "Прозрачность окна", CONFIG.UI.Opacity, 0, 0.5, 0.05, function(v)
    CONFIG.UI.Opacity = v
    Main.BackgroundTransparency = v
end)
actionButton("Интерфейс", "♻ Сбросить положение окна", function()
    Main.Position = UDim2.new(0.5, -420, 0.5, -260)
    Shadow.Position = UDim2.new(0.5, -421, 0.5, -257)
end)

---------------------------------------------------------------------
-- Dragging
---------------------------------------------------------------------

local dragging = false
local dragStart = Vector2.zero
local mainStart = Main.Position

Topbar.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        mainStart = Main.Position
    end
end)

UIS.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        local newPos = UDim2.new(
            mainStart.X.Scale, mainStart.X.Offset + delta.X,
            mainStart.Y.Scale, mainStart.Y.Offset + delta.Y
        )
        Main.Position = newPos
        Shadow.Position = UDim2.new(newPos.X.Scale, newPos.X.Offset - 1, newPos.Y.Scale, newPos.Y.Offset + 3)
    end
end)

UIS.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)

---------------------------------------------------------------------
-- Keyboard state
---------------------------------------------------------------------

local Keys: {[Enum.KeyCode]: boolean} = {}
local MenuOpen = true

local function keyMatches(input: InputObject, bindName: string): boolean
    local saved = (CONFIG.Keybinds :: any)[bindName]
    if not saved then return false end
    return input.KeyCode ~= Enum.KeyCode.Unknown and input.KeyCode.Name == saved
end

UIS.InputBegan:Connect(function(input, processed)
    if waitingBind then
        if input.KeyCode ~= Enum.KeyCode.Unknown then
            local newKey = input.KeyCode.Name
            local conflictName = nil

            for name, keyName in pairs(CONFIG.Keybinds) do
                if name ~= waitingBind and keyName == newKey then
                    conflictName = name
                    break
                end
            end

            local b = bindButtons[waitingBind]

            if conflictName then
                if b then
                    b.Text = "ЗАНЯТО"
                    b.BackgroundColor3 = THEME.Bad

                    task.delay(1, function()
                        if b then
                            b.Text = (CONFIG.Keybinds :: any)[waitingBind] or "None"
                            b.BackgroundColor3 = THEME.Panel3
                        end
                    end)
                end
            else
                (CONFIG.Keybinds :: any)[waitingBind] = newKey

                if b then
                    b.Text = newKey
                    b.BackgroundColor3 = THEME.Panel3
                end
            end

            waitingBind = nil
            scheduleSave()
        end

        return
    end

    if keyMatches(input, "Menu") then
        MenuOpen = not MenuOpen
        Main.Visible = MenuOpen
        Shadow.Visible = MenuOpen
        return
    end

    if processed then return end
    Keys[input.KeyCode] = true

    if keyMatches(input, "Aim") then
        CONFIG.Aim.Enabled = not CONFIG.Aim.Enabled
        scheduleSave()
    elseif keyMatches(input, "ESP") then
        CONFIG.ESP.Enabled = not CONFIG.ESP.Enabled
        scheduleSave()
    elseif keyMatches(input, "Fly") then
        CONFIG.Movement.Fly = not CONFIG.Movement.Fly
        scheduleSave()
    elseif keyMatches(input, "Freecam") then
        CONFIG.Camera.Freecam = not CONFIG.Camera.Freecam
        Camera.CameraType = CONFIG.Camera.Freecam and Enum.CameraType.Scriptable or Enum.CameraType.Custom
        if not CONFIG.Camera.Freecam then
            local hum = getHumanoid(LocalPlayer)
            if hum then Camera.CameraSubject = hum end
        end
        scheduleSave()
    elseif keyMatches(input, "Radar") then
        CONFIG.Radar.Enabled = not CONFIG.Radar.Enabled
        scheduleSave()
    elseif keyMatches(input, "SilentAim") then
        CONFIG.SilentAim.Enabled = not CONFIG.SilentAim.Enabled
        scheduleSave()
    elseif keyMatches(input, "AutoFire") then
        CONFIG.AutoFire.Enabled = not CONFIG.AutoFire.Enabled
        scheduleSave()
    elseif keyMatches(input, "Visuals") then
        local newState = not (
            CONFIG.Visuals.ChinaHat
            or CONFIG.Visuals.Halo
            or CONFIG.Visuals.OrbitLights
            or CONFIG.Visuals.Trail
        )
        CONFIG.Visuals.ChinaHat = newState
        CONFIG.Visuals.Halo = newState
        CONFIG.Visuals.OrbitLights = newState
        refreshCharacterVisuals()
    elseif keyMatches(input, "TPBehind") then
        if SelectedPlayer then teleportBehind(SelectedPlayer, 3) end
    elseif keyMatches(input, "TPCycle") then
        if TPCycleEnabled then
            stopTPCycle()
        else
            TPCycleEnabled = true
            TPCycleIndex = 0
            goNextCycleTarget()
        end
    end
end)

UIS.InputEnded:Connect(function(input)
    Keys[input.KeyCode] = false
end)

UIS.JumpRequest:Connect(function()
    local hum = getHumanoid(LocalPlayer)
    local root = getRoot(LocalPlayer)

    if CONFIG.Movement.InfiniteJump and hum then
        hum:ChangeState(Enum.HumanoidStateType.Jumping)
    end

    if CONFIG.Movement.HighJump and root then
        task.defer(function()
            if root.Parent then
                local current = root.AssemblyLinearVelocity

                root.AssemblyLinearVelocity = Vector3.new(
                    current.X,
                    math.max(current.Y, CONFIG.Movement.JumpPower),
                    current.Z
                )
            end
        end)
    end
end)

local function movementVector(): Vector3
    local v = Vector3.zero
    if Keys[Enum.KeyCode.W] then v += Vector3.new(0, 0, -1) end
    if Keys[Enum.KeyCode.S] then v += Vector3.new(0, 0, 1) end
    if Keys[Enum.KeyCode.A] then v += Vector3.new(-1, 0, 0) end
    if Keys[Enum.KeyCode.D] then v += Vector3.new(1, 0, 0) end
    if Keys[Enum.KeyCode.Space] then v += Vector3.new(0, 1, 0) end
    if Keys[Enum.KeyCode.LeftControl] then v += Vector3.new(0, -1, 0) end
    return v
end

---------------------------------------------------------------------
-- Main loop
---------------------------------------------------------------------

local CurrentAimTarget: Player? = nil
local LastShot = 0
local FPS = 0
local FPSFrames = 0
local FPSClock = os.clock()

RunService.RenderStepped:Connect(function(dt)
    Camera = workspace.CurrentCamera
    if not Camera then return end

    local viewport = Camera.ViewportSize
    local centerX, centerY = viewport.X / 2, viewport.Y / 2

    CrossH.Position = UDim2.fromOffset(centerX, centerY)
    CrossV.Position = UDim2.fromOffset(centerX, centerY)
    CrossH.Visible = CONFIG.World.Crosshair
    CrossV.Visible = CONFIG.World.Crosshair

    FOVCircle.Size = UDim2.fromOffset(CONFIG.Aim.FOV * 2, CONFIG.Aim.FOV * 2)
    FOVCircle.Position = UDim2.fromOffset(centerX, centerY)
    FOVCircle.Visible = CONFIG.Aim.ShowFOV
    FOVStroke.Color = THEME.Accent

    -----------------------------------------------------------------
    -- AIM
    -----------------------------------------------------------------

    if CONFIG.Aim.Enabled then
        CurrentAimTarget = findNearestTarget(
            CONFIG.Aim.FOV,
            CONFIG.Aim.TeamCheck,
            CONFIG.Aim.VisibleOnly,
            nil
        )

        if CurrentAimTarget then
            local targetPart = getTargetPart(CurrentAimTarget)
            if targetPart then
                local desired = CFrame.lookAt(Camera.CFrame.Position, targetPart.Position)
                -- Быстрый AIM:
                -- 1 = плавно, 50 = быстро, 90 = почти мгновенно, 100 = snap.
                local speed = math.clamp(CONFIG.Aim.Speed, 1, 100)

                if speed >= 96 then
                    Camera.CFrame = desired
                else
                    local normalized = speed / 100
                    local responsiveness = 10 + (normalized ^ 1.35) * 115
                    local alpha = 1 - math.exp(-responsiveness * dt)
                    Camera.CFrame = Camera.CFrame:Lerp(desired, alpha)
                end

                local visible = isVisible(CurrentAimTarget, targetPart)
                AimStatus.Text = string.format(
                    "Цель: %s  •  %.0f studs  •  %s",
                    CurrentAimTarget.Name,
                    distanceTo(CurrentAimTarget),
                    visible and "ВИДНА" or "ЗАКРЫТА"
                )

                if CONFIG.Aim.HighlightTarget then
                    AimHighlight.Adornee = CurrentAimTarget.Character
                    AimHighlight.Enabled = true
                else
                    AimHighlight.Enabled = false
                end
            end
        else
            AimStatus.Text = "Цель: нет"
            AimHighlight.Enabled = false
        end
    else
        CurrentAimTarget = nil
        AimStatus.Text = "Цель: AIM выключен"
        AimHighlight.Enabled = false
    end

    -----------------------------------------------------------------
    -- SILENT AIM
    -----------------------------------------------------------------

    if CONFIG.SilentAim.Enabled then
        CurrentSilentTarget = findSilentTarget()

        SilentCircle.Size = UDim2.fromOffset(CONFIG.SilentAim.FOV * 2, CONFIG.SilentAim.FOV * 2)
        SilentCircle.Position = UDim2.fromOffset(centerX, centerY)
        SilentCircle.Visible = CONFIG.SilentAim.ShowFOV
        SilentCircleStroke.Color = CONFIG.SilentAim.Color

        if CurrentSilentTarget then
            local targetRoot = getRoot(CurrentSilentTarget)
            local visiblePart = getAutoFireVisiblePart(CurrentSilentTarget) or getSilentTargetPart(CurrentSilentTarget)

            SilentStatus.Text = string.format(
                "Цель: %s  •  %.0f studs  •  %s",
                CurrentSilentTarget.Name,
                distanceTo(CurrentSilentTarget),
                visiblePart and "ПОПАДАНИЕ" or "ЗАКРЫТА"
            )

            if CONFIG.SilentAim.HighlightTarget and targetRoot then
                local data = createESP(CurrentSilentTarget)
                local ring = ensureSilentRing(data)
                ring.Adornee = targetRoot
                ring.CFrame = CFrame.new(0, -2.8, 0)
                ring.Color3 = CONFIG.SilentAim.Color
                ring.Visible = true
            end

            if CONFIG.SilentAim.HighlightTarget then
                SilentHighlight.Adornee = CurrentSilentTarget.Character
                SilentHighlight.Enabled = true
            else
                SilentHighlight.Enabled = false
            end
        else
            SilentStatus.Text = "Цель: нет (в FOV никого)"
            SilentHighlight.Enabled = false
        end
    else
        CurrentSilentTarget = nil
        SilentStatus.Text = "Статус: выключен"
        SilentCircle.Visible = false
        SilentHighlight.Enabled = false
    end

    -----------------------------------------------------------------
    -- ESP
    -----------------------------------------------------------------

    local shown = 0
    local preset = currentPreset()

    -- Сначала скрываем прошлый кадр: старые рамки больше не залипают.
    for _, oldData in pairs(ESPObjects) do
        hideESP(oldData)
    end

    for _, player in ipairs(Players:GetPlayers()) do
        if player == LocalPlayer then continue end
        local data = createESP(player)

        if not CONFIG.ESP.Enabled or not isAlive(player) then
            hideESP(data)
            continue
        end

        if isAlly(player) and not CONFIG.ESP.ShowTeammates then
            hideESP(data)
            continue
        end

        local character = player.Character
        local root = getRoot(player)
        local hum = getHumanoid(player)
        local head = character and character:FindFirstChild("Head") :: BasePart?

        if not character or not root or not hum then
            hideESP(data)
            continue
        end

        local worldDistance = distanceTo(player)
        if worldDistance > CONFIG.ESP.MaxDistance then
            hideESP(data)
            continue
        end

        local rootPoint, rootOnScreen = Camera:WorldToViewportPoint(root.Position)
        local visible = isVisible(player, head or root)

        local color = preset.Enemy
        if CONFIG.ESP.TeamColors and isAlly(player) then
            color = preset.Ally
        elseif CONFIG.ESP.VisibilityTint and visible then
            color = preset.Visible
        end

        data.BoxStroke.Color = color
        data.BoxStroke.Thickness = CONFIG.ESP.BoxThickness
        data.BoxStroke.Transparency = 1 - CONFIG.ESP.Opacity
        data.Name.TextColor3 = color
        data.Name.TextTransparency = 1 - CONFIG.ESP.Opacity
        data.Info.TextTransparency = 1 - CONFIG.ESP.Opacity
        data.Dot.BackgroundColor3 = color
        data.Dot.BackgroundTransparency = 1 - CONFIG.ESP.Opacity
        data.Tracer.BackgroundColor3 = color
        data.Tracer.BackgroundTransparency = 1 - CONFIG.ESP.Opacity
        data.Direction.BackgroundColor3 = color
        data.Direction.BackgroundTransparency = 1 - CONFIG.ESP.Opacity
        data.Arrow.TextColor3 = color
        data.Name.TextSize = CONFIG.ESP.TextSize
        data.Info.TextSize = math.max(10, CONFIG.ESP.TextSize - 1)
        data.Extra.TextSize = math.max(9, CONFIG.ESP.TextSize - 2)
        data.Fill.BackgroundColor3 = color
        data.Fill.BackgroundTransparency = math.clamp(0.92 - CONFIG.ESP.Opacity * 0.12, 0.78, 0.96)

        if rootOnScreen and rootPoint.Z > 0 then
            local minX, minY, maxX, maxY = projectedBounds(character)
            if minX and minY and maxX and maxY then
                shown += 1

                local width = math.max(maxX - minX, 12)
                local height = math.max(maxY - minY, 24)

                data.Box.Position = UDim2.fromOffset(minX, minY)
                data.Box.Size = UDim2.fromOffset(width, height)
                data.Box.Visible = CONFIG.ESP.Boxes or CONFIG.ESP.CornerBoxes or CONFIG.ESP.FilledBox
                data.BoxStroke.Enabled = CONFIG.ESP.Boxes
                data.Fill.Visible = CONFIG.ESP.FilledBox
                updateCorners(data, width, height, color)

                local nameParts = {}
                if CONFIG.ESP.Names then table.insert(nameParts, player.Name) end
                if CONFIG.ESP.DisplayNames then table.insert(nameParts, "[" .. player.DisplayName .. "]") end
                data.Name.Text = table.concat(nameParts, "  ")
                data.Name.Position = UDim2.fromOffset((minX + maxX) / 2 - 130, minY - 22)
                data.Name.Visible = #nameParts > 0

                local infoParts = {}
                if CONFIG.ESP.NumericHP then
                    table.insert(infoParts, string.format("%.0f HP", hum.Health))
                end
                if CONFIG.ESP.Distance then
                    table.insert(infoParts, string.format("%.0f studs", worldDistance))
                end
                data.Info.Text = table.concat(infoParts, "  •  ")
                data.Info.Position = UDim2.fromOffset((minX + maxX) / 2 - 130, maxY + 2)
                data.Info.Visible = #infoParts > 0

                local extraParts = {}
                if CONFIG.ESP.ToolName then
                    local equipped = character:FindFirstChildOfClass("Tool")
                    if equipped then table.insert(extraParts, "TOOL: " .. equipped.Name) end
                end
                if CONFIG.ESP.VisibilityText then
                    table.insert(extraParts, visible and "VISIBLE" or "BLOCKED")
                end
                if CONFIG.ESP.TeamTag and player.Team then
                    table.insert(extraParts, "TEAM: " .. player.Team.Name)
                end
                data.Extra.Text = table.concat(extraParts, "  •  ")
                data.Extra.TextColor3 = visible and currentPreset().Visible or color
                data.Extra.TextTransparency = 1 - CONFIG.ESP.Opacity
                data.Extra.Position = UDim2.fromOffset((minX + maxX) / 2 - 150, maxY + 19)
                data.Extra.Visible = #extraParts > 0

                drawSkeleton(data, character, color)
                drawWireframe(data, minX, minY, maxX, maxY, color)

                if CONFIG.ESP.HealthBar then
                    local healthAlpha = math.clamp(hum.Health / math.max(hum.MaxHealth, 1), 0, 1)
                    data.HPBack.Position = UDim2.fromOffset(minX - 8, minY)
                    data.HPBack.Size = UDim2.fromOffset(4, height)
                    data.HPBack.Visible = true
                    data.HPFill.Size = UDim2.new(1, 0, healthAlpha, 0)
                    data.HPFill.BackgroundColor3 = Color3.fromRGB(
                        math.floor(255 * (1 - healthAlpha)),
                        math.floor(220 * healthAlpha + 25),
                        80
                    )
                else
                    data.HPBack.Visible = false
                end

                if CONFIG.ESP.HeadDot and head then
                    local hp, on = Camera:WorldToViewportPoint(head.Position)
                    if on and hp.Z > 0 then
                        data.Dot.Position = UDim2.fromOffset(hp.X - 3.5, hp.Y - 3.5)
                        data.Dot.Visible = true
                    else
                        data.Dot.Visible = false
                    end
                else
                    data.Dot.Visible = false
                end

                if CONFIG.ESP.Tracers then
                    data.Tracer.Visible = true
                    setLine(data.Tracer, centerX, viewport.Y - 4, rootPoint.X, rootPoint.Y, CONFIG.ESP.BoxThickness)
                else
                    data.Tracer.Visible = false
                end

                if CONFIG.ESP.Direction and head then
                    local a, aOn = Camera:WorldToViewportPoint(head.Position)
                    local b, bOn = Camera:WorldToViewportPoint(head.Position + head.CFrame.LookVector * 5)
                    if aOn and bOn and a.Z > 0 and b.Z > 0 then
                        data.Direction.Visible = true
                        setLine(data.Direction, a.X, a.Y, b.X, b.Y, CONFIG.ESP.BoxThickness)
                    else
                        data.Direction.Visible = false
                    end
                else
                    data.Direction.Visible = false
                end

                data.Arrow.Visible = false
            else
                hideESP(data)
            end
        else
            data.Box.Visible = false
            data.Name.Visible = false
            data.Info.Visible = false
            data.HPBack.Visible = false
            data.Dot.Visible = false
            data.Tracer.Visible = false
            data.Direction.Visible = false
            data.Fill.Visible = false
            data.Extra.Visible = false
            for _, line in ipairs(data.Skeleton) do line.Visible = false end
            for _, line in ipairs(data.Wireframe) do line.Visible = false end
            for _, c in ipairs(data.Corners) do c.Visible = false end

            if CONFIG.ESP.Offscreen then
                local x = math.clamp(rootPoint.X, 26, viewport.X - 26)
                local y = math.clamp(rootPoint.Y, 26, viewport.Y - 26)
                if rootPoint.Z < 0 then
                    x = viewport.X - x
                    y = viewport.Y - y
                end
                data.Arrow.Position = UDim2.fromOffset(x - 14, y - 14)
                data.Arrow.Visible = true
            else
                data.Arrow.Visible = false
            end
        end

        if CONFIG.ESP.Chams then
            data.Highlight.Adornee = character
            data.Highlight.FillColor = color
            data.Highlight.OutlineColor = color
            data.Highlight.DepthMode = CONFIG.ESP.ChamsThroughWalls
                and Enum.HighlightDepthMode.AlwaysOnTop
                or Enum.HighlightDepthMode.Occluded
            data.Highlight.Enabled = true
        else
            data.Highlight.Enabled = false
        end
    end

    ESPCount.Text = "Игроков на ESP: " .. tostring(shown)

    -----------------------------------------------------------------
    -- Radar
    -----------------------------------------------------------------

    Radar.Visible = CONFIG.Radar.Enabled

    if CONFIG.Radar.Enabled then
        for _, dot in pairs(RadarDots) do
            dot.Visible = false
        end

        local myRoot = getRoot(LocalPlayer)
        if myRoot then
            for _, player in ipairs(Players:GetPlayers()) do
                if player == LocalPlayer then continue end

                local root = getRoot(player)
                if not root or not isAlive(player) then
                    if RadarDots[player] then RadarDots[player].Visible = false end
                    continue
                end

                local dot = RadarDots[player]
                if not dot then
                    dot = new("Frame", {
                        Size = UDim2.fromOffset(7, 7),
                        BorderSizePixel = 0,
                        ZIndex = 45,
                    }, Radar) :: Frame
                    round(dot, 7)
                    RadarDots[player] = dot
                end

                local difference = root.Position - myRoot.Position
                local localDir = Camera.CFrame:VectorToObjectSpace(difference)
                local usableRadius = CONFIG.Radar.Size / 2 - 14
                local scale = usableRadius / CONFIG.Radar.Range
                local x = math.clamp(localDir.X * scale, -usableRadius, usableRadius)
                local z = math.clamp(localDir.Z * scale, -usableRadius, usableRadius)

                dot.Position = UDim2.new(0.5, x - 3.5, 0.5, z + 9.5)
                dot.BackgroundColor3 = (CONFIG.Radar.SeparateAllies and isAlly(player))
                    and currentPreset().Ally
                    or currentPreset().Enemy
                dot.Visible = true
            end
        end
    end

    -----------------------------------------------------------------
    -- Auto Fire
    -----------------------------------------------------------------

    local tool = getEquippedTool()
    ToolStatus.Text = tool and ("Tool: " .. tool.Name) or "Tool: не экипирован"

    if not CONFIG.AutoFire.Enabled then
        FireStatus.Text = "Статус: выключено"
        FireStatus.TextColor3 = THEME.Muted
    elseif CONFIG.AutoFire.PauseWhenMenuOpen and MenuOpen then
        FireStatus.Text = "Статус: ПАУЗА — меню открыто"
        FireStatus.TextColor3 = THEME.Warn
    elseif not tool then
        FireStatus.Text = "Статус: НЕТ TOOL"
        FireStatus.TextColor3 = THEME.Warn
    elseif not tool.Enabled then
        FireStatus.Text = "Статус: Tool на перезарядке / выключен"
        FireStatus.TextColor3 = THEME.Warn
    else
        local candidate = nearestCandidateIgnoringWall(
            CONFIG.AutoFire.Radius,
            CONFIG.AutoFire.TeamCheck,
            CONFIG.AutoFire.MaxDistance
        )

        if not candidate then
            FireStatus.Text = "Статус: НЕТ ЦЕЛИ"
            FireStatus.TextColor3 = THEME.Muted
        else
            local visiblePart = getAutoFireVisiblePart(candidate)
            local visible = visiblePart ~= nil

            if CONFIG.AutoFire.VisibleOnly and not visible then
                FireStatus.Text = "Статус: ЗАКРЫТА — " .. candidate.Name
                FireStatus.TextColor3 = THEME.Bad
            else
                FireStatus.Text = "Статус: ЦЕЛЬ ВИДНА — " .. candidate.Name
                FireStatus.TextColor3 = THEME.Good

                local interval = 1 / math.max(CONFIG.AutoFire.CPS, 1)
                local wantFire = (not CONFIG.AutoFire.FireWhileButtonHeld) or MouseHeld

                if wantFire and os.clock() - LastShot >= interval then
                    LastShot = os.clock()
                    local fired = false

                    if CONFIG.AutoFire.ActivateTool then
                        -- Реальная активация Tool (только для СВОЕЙ игры).
                        -- Если у твоего оружия другое название RemoteEvent'а —
                        -- поменяй имя в строке ниже.
                        local fireRemote = ReplicatedStorage:FindFirstChild("Fire", true)
                        if fireRemote and fireRemote:IsA("RemoteEvent") then
                            pcall(function()
                                fireRemote:FireServer(visiblePart or getTargetPart(candidate))
                            end)
                            fired = true
                        elseif tool:FindFirstChild("Fire") and tool:FindFirstChild("Fire"):IsA("RemoteEvent") then
                            pcall(function()
                                (tool:FindFirstChild("Fire") :: RemoteEvent):FireServer(visiblePart or getTargetPart(candidate))
                            end)
                            fired = true
                        else
                            -- Стандартный способ: активировать Tool как кнопкой F.
                            tool:Activate()
                            fired = true
                        end
                    end

                    if fired then
                        FireStatus.Text = "Статус: ОГОНЬ — " .. candidate.Name
                    else
                        -- Безопасная симуляция автострельбы:
                        -- цель видна и условия выполнены, но реальный Tool не активируется.
                        FireStatus.Text = "Статус: СИМУЛЯЦИЯ — " .. candidate.Name
                    end
                end
            end
        end
    end

    -----------------------------------------------------------------
    -- VISUALS runtime
    -----------------------------------------------------------------

    local myRootForVisuals = getRoot(LocalPlayer)

    if CONFIG.Visuals.OrbitLights and myRootForVisuals then
        if #OrbitParts ~= math.clamp(math.floor(CONFIG.Visuals.OrbitCount), 1, 8) then
            refreshCharacterVisuals()
        end

        local now = os.clock() * CONFIG.Visuals.OrbitSpeed
        for i, part in ipairs(OrbitParts) do
            local angle = now + ((i - 1) / math.max(#OrbitParts, 1)) * math.pi * 2
            local radius = CONFIG.Visuals.OrbitRadius
            local y = 0.8 + math.sin(now * 1.4 + i) * 0.65
            part.CFrame = CFrame.new(
                myRootForVisuals.Position
                + Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
            )
        end
    end

    if CONFIG.Visuals.TargetRing and CurrentAimTarget then
        local targetRoot = getRoot(CurrentAimTarget)
        if targetRoot then
            if not TargetRing then
                TargetRing = new("CylinderHandleAdornment", {
                    Name = "TargetRing",
                    AlwaysOnTop = true,
                    Height = 0.06,
                    Radius = 2.4,
                    Color3 = Color3.fromRGB(255, 80, 115),
                    Transparency = 0.14,
                    ZIndex = 4,
                }, VisualFolder) :: CylinderHandleAdornment
            end
            TargetRing.Adornee = targetRoot
            TargetRing.CFrame = CFrame.new(0, -2.8, 0)
            TargetRing.Visible = true
        end
    elseif TargetRing then
        TargetRing.Visible = false
    end

    -----------------------------------------------------------------
    -- Freecam
    -----------------------------------------------------------------

    if CONFIG.Camera.Freecam then
        Camera.CameraType = Enum.CameraType.Scriptable
        local move = movementVector()
        if move.Magnitude > 0 then
            move = move.Unit
            local worldMove = Camera.CFrame:VectorToWorldSpace(move)
            Camera.CFrame += worldMove * CONFIG.Camera.FreecamSpeed * dt
        end
    end

    -----------------------------------------------------------------
    -- Fly
    -----------------------------------------------------------------

    if CONFIG.Movement.Fly and not CONFIG.Camera.Freecam then
        local root = getRoot(LocalPlayer)
        if root then
            local move = movementVector()
            if move.Magnitude > 0 then
                move = move.Unit
                local worldMove = Camera.CFrame:VectorToWorldSpace(move)
                root.CFrame += worldMove * CONFIG.Movement.FlySpeed * dt
            end
            root.AssemblyLinearVelocity = Vector3.zero
        end
    end

    local myRoot = getRoot(LocalPlayer)
    if myRoot then
        SpeedInfo.Text = string.format("Текущая скорость: %.1f", myRoot.AssemblyLinearVelocity.Magnitude)
    end

    -----------------------------------------------------------------
    -- TP + player info
    -----------------------------------------------------------------

    if SelectedPlayer and SelectedPlayer.Parent == Players then
        local hum = getHumanoid(SelectedPlayer)
        local dist = distanceTo(SelectedPlayer)

        TPDistance.Text = dist < math.huge and string.format("Расстояние: %.1f studs", dist) or "Расстояние: —"
        PlayerInfo1.Text = "Ник: " .. SelectedPlayer.Name .. "  [" .. SelectedPlayer.DisplayName .. "]"
        PlayerInfo2.Text = "User ID: " .. tostring(SelectedPlayer.UserId)
        PlayerInfo3.Text = "Команда: " .. (SelectedPlayer.Team and SelectedPlayer.Team.Name or "Нет")
        PlayerInfo4.Text = hum and string.format("HP: %.0f / %.0f", hum.Health, hum.MaxHealth) or "HP: —"
        PlayerInfo5.Text = dist < math.huge and string.format("Расстояние: %.1f studs", dist) or "Расстояние: —"
    end

    WorldTime.Text = string.format("Время мира: %.2f", Lighting.ClockTime)

    -----------------------------------------------------------------
    -- FPS / ping HUD
    -----------------------------------------------------------------

    FPSFrames += 1
    local now = os.clock()
    if now - FPSClock >= 1 then
        FPS = FPSFrames
        FPSFrames = 0
        FPSClock = now
    end

    local ping = "?"
    if CONFIG.World.ShowPing then
        pcall(function()
            ping = Stats.Network.ServerStatsItem["Data Ping"]:GetValueString()
        end)
    end

    local lines = {}
    if CONFIG.World.ShowFPS then table.insert(lines, "FPS     " .. tostring(FPS)) end
    if CONFIG.World.ShowPing then table.insert(lines, "PING    " .. ping) end
    if CONFIG.Movement.Fly then table.insert(lines, "FLY     ON") end
    if CurrentAimTarget then table.insert(lines, "TARGET  " .. CurrentAimTarget.Name) end
    if CONFIG.SilentAim.Enabled then
        table.insert(lines, "SILENT  " .. (CurrentSilentTarget and CurrentSilentTarget.Name or "нет цели"))
    end
    if CONFIG.AutoFire.Enabled then table.insert(lines, "AUTO    ON" .. (MouseHeld and " (LMB)" or "")) end

    HUD.Text = "  " .. table.concat(lines, "\n  ")
    HUD.Visible = #lines > 0
end)

---------------------------------------------------------------------
-- Cleanup
---------------------------------------------------------------------

Players.PlayerRemoving:Connect(function(player)
    local data = ESPObjects[player]
    if data then
        if data.SilentRing then data.SilentRing:Destroy() end
        data.Box:Destroy()
        data.Name:Destroy()
        data.Info:Destroy()
        data.HPBack:Destroy()
        data.Dot:Destroy()
        data.Tracer:Destroy()
        data.Direction:Destroy()
        data.Arrow:Destroy()
        data.Highlight:Destroy()
        data.Extra:Destroy()
        for _, line in ipairs(data.Skeleton) do line:Destroy() end
        for _, line in ipairs(data.Wireframe) do line:Destroy() end
        ESPObjects[player] = nil
    end

    if RadarDots[player] then
        RadarDots[player]:Destroy()
        RadarDots[player] = nil
    end

    if SelectedPlayer == player then
        SelectedPlayer = nil
        SelectedLabel.Text = "Игрок: не выбран"
    end
end)

LocalPlayer.CharacterAdded:Connect(function()
    task.wait(0.3)
    refreshCharacterVisuals()
    local humVisual = getHumanoid(LocalPlayer)
    if humVisual then
        humVisual.StateChanged:Connect(function(_, newState)
            if newState == Enum.HumanoidStateType.Jumping then
                spawnJumpCircle()
            end
        end)
    end
    if CONFIG.Movement.HighJump then
        local hum = getHumanoid(LocalPlayer)
        if hum then
            hum.UseJumpPower = true
            hum.JumpPower = CONFIG.Movement.JumpPower
        end
    end
end)

refreshCharacterVisuals()
local initialHumanoid = getHumanoid(LocalPlayer)
if initialHumanoid then
    initialHumanoid.StateChanged:Connect(function(_, newState)
        if newState == Enum.HumanoidStateType.Jumping then
            spawnJumpCircle()
        end
    end)
end

openPage("AIM")

print("NEBULA DEV MENU v5.2 GROUP TP loaded")
print("RightShift = menu")
