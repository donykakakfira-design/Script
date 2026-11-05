--[[
    FABLEHERD HELPER - Roblox LocalScript / Executor
    Dibuat berdasarkan struktur file game yang diunggah.
    Fitur: Auto Attack Guardian, ESP Guardian, ESP Player,
           Teleport Guardian, Drop Egg, Anti-AFK.
    Catatan: fitur server hanya bekerja jika game mengizinkan aksi tersebut.
]]

if _G.FableherdHelperRunning then
    warn("Fableherd Helper sudah berjalan.")
    return
end
_G.FableherdHelperRunning = true

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local VirtualUser = game:GetService("VirtualUser")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

local MountSystem = ReplicatedStorage:WaitForChild("MountSystem", 10)
local Remotes = MountSystem and MountSystem:WaitForChild("Remotes", 10)
local PetRequest = Remotes and Remotes:WaitForChild("PetRequest", 10)

if not PetRequest then
    warn("PetRequest tidak ditemukan. Script dihentikan.")
    _G.FableherdHelperRunning = nil
    return
end

local Config
pcall(function()
    Config = require(ReplicatedStorage:WaitForChild("Fableherd"):WaitForChild("PetMountConfig"))
end)

local ATTACK_DELAY = 1
if Config and Config.Combat and tonumber(Config.Combat.AttackCooldownSeconds) then
    ATTACK_DELAY = math.max(0.3, Config.Combat.AttackCooldownSeconds + 0.05)
end

local State = {
    AutoAttack = false,
    GuardianESP = false,
    PlayerESP = false,
    AutoDropEgg = false,
    AntiAFK = true,
    Running = true,
}

local Connections = {}
local Highlights = {}
local Labels = {}

local function getRoot(character)
    return character and character:FindFirstChild("HumanoidRootPart")
end

local function getCharacterRoot()
    return getRoot(LocalPlayer.Character)
end

local function hasSummonedMount()
    local folderName = (Config and Config.SummonFolderName) or "SummonedMounts"
    local folder = workspace:FindFirstChild(folderName)
    if not folder then return false end

    local suffix = "_" .. tostring(LocalPlayer.UserId)
    for _, item in ipairs(folder:GetChildren()) do
        if item:GetAttribute("Occupied") == true
            and item.Name:sub(-#suffix) == suffix then
            return true
        end
    end
    return false
end

local function nearestGuardian()
    local root = getCharacterRoot()
    local folder = workspace:FindFirstChild("WildGuardians")
    if not root or not folder then return nil, math.huge end

    local maxRange = (Config and Config.Combat
        and tonumber(Config.Combat.PlayerAttackRange)) or 25

    local best, bestDistance = nil, maxRange
    for _, guardian in ipairs(folder:GetChildren()) do
        if guardian:IsA("Model") and guardian:GetAttribute("Defeated") ~= true then
            local ok, position = pcall(function()
                return guardian:GetPivot().Position
            end)
            if ok then
                local distance = (Vector3.new(position.X, root.Position.Y, position.Z)
                    - root.Position).Magnitude
                distance = distance - (guardian:GetAttribute("BodyRadius") or 0)
                if distance <= bestDistance then
                    best, bestDistance = guardian, distance
                end
            end
        end
    end
    return best, bestDistance
end

local function attack()
    if not hasSummonedMount() then return end
    local target, distance = nearestGuardian()
    if not target then return end

    local root = getCharacterRoot()
    if not root then return end

    -- Hadapkan karakter ke arah Guardian.
    local pos = target:GetPivot().Position
    root.CFrame = CFrame.lookAt(
        root.Position,
        Vector3.new(pos.X, root.Position.Y, pos.Z)
    )

    pcall(function()
        PetRequest:InvokeServer("Attack")
    end)
end

local function dropEgg()
    local character = LocalPlayer.Character
    local tool = character and character:FindFirstChildOfClass("Tool")
    local eggId

    if tool and tool:GetAttribute("Kind") == "Egg" then
        eggId = tool:GetAttribute("ItemId")
    end

    if type(eggId) == "string" and eggId ~= "" then
        pcall(function()
            PetRequest:InvokeServer("DropEgg", { EggId = eggId })
        end)
    else
        pcall(function()
            PetRequest:InvokeServer("DropCargo", {})
        end)
    end
end

local function clearVisuals()
    for object, highlight in pairs(Highlights) do
        if highlight then highlight:Destroy() end
        Highlights[object] = nil
    end
    for object, label in pairs(Labels) do
        if label then label:Destroy() end
        Labels[object] = nil
    end
end

local function addESP(object, title, color)
    if not object or not object.Parent then return end

    if not Highlights[object] then
        local h = Instance.new("Highlight")
        h.Name = "FableherdHelperESP"
        h.FillColor = color
        h.OutlineColor = color
        h.FillTransparency = 0.72
        h.OutlineTransparency = 0
        h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
        h.Adornee = object
        h.Parent = object
        Highlights[object] = h
    end

    local adornee = object:FindFirstChild("Head")
        or object:FindFirstChild("HumanoidRootPart")
        or object:FindFirstChildWhichIsA("BasePart")

    if adornee and not Labels[object] then
        local billboard = Instance.new("BillboardGui")
        billboard.Name = "FableherdHelperLabel"
        billboard.Adornee = adornee
        billboard.Size = UDim2.fromOffset(150, 28)
        billboard.StudsOffset = Vector3.new(0, 2.8, 0)
        billboard.AlwaysOnTop = true

        local text = Instance.new("TextLabel")
        text.BackgroundTransparency = 1
        text.Size = UDim2.fromScale(1, 1)
        text.Font = Enum.Font.GothamBold
        text.TextSize = 13
        text.TextColor3 = color
        text.TextStrokeTransparency = 0.25
        text.Text = title
        text.Parent = billboard

        billboard.Parent = PlayerGui
        Labels[object] = billboard
    end
end

local function refreshESP()
    if State.GuardianESP then
        local folder = workspace:FindFirstChild("WildGuardians")
        if folder then
            for _, guardian in ipairs(folder:GetChildren()) do
                if guardian:IsA("Model") and guardian:GetAttribute("Defeated") ~= true then
                    addESP(guardian, "GUARDIAN", Color3.fromRGB(255, 190, 60))
                end
            end
        end
    end

    if State.PlayerESP then
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character then
                addESP(player.Character, player.Name, Color3.fromRGB(80, 190, 255))
            end
        end
    end

    for object, highlight in pairs(Highlights) do
        local keep = (State.GuardianESP and object:IsDescendantOf(workspace:FindFirstChild("WildGuardians") or workspace))
            or (State.PlayerESP and object ~= nil and object:IsDescendantOf(workspace)
                and Players:GetPlayerFromCharacter(object) ~= nil)
        if not keep or not object.Parent then
            if highlight then highlight:Destroy() end
            Highlights[object] = nil
            if Labels[object] then Labels[object]:Destroy(); Labels[object] = nil end
        end
    end
end

-- GUI
local oldGui = PlayerGui:FindFirstChild("FableherdHelperGui")
if oldGui then oldGui:Destroy() end

local Gui = Instance.new("ScreenGui")
Gui.Name = "FableherdHelperGui"
Gui.ResetOnSpawn = false
Gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
Gui.Parent = PlayerGui

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.fromOffset(265, 350)
Main.Position = UDim2.new(0, 18, 0.35, 0)
Main.BackgroundColor3 = Color3.fromRGB(22, 25, 34)
Main.BorderSizePixel = 0
Main.Parent = Gui

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 12)
Corner.Parent = Main

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(75, 145, 255)
Stroke.Thickness = 1.5
Stroke.Parent = Main

local Top = Instance.new("Frame")
Top.Size = UDim2.new(1, 0, 0, 42)
Top.BackgroundColor3 = Color3.fromRGB(35, 43, 60)
Top.BorderSizePixel = 0
Top.Parent = Main
Instance.new("UICorner", Top).CornerRadius = UDim.new(0, 12)

local Title = Instance.new("TextLabel")
Title.BackgroundTransparency = 1
Title.Position = UDim2.fromOffset(12, 0)
Title.Size = UDim2.new(1, -50, 1, 0)
Title.Font = Enum.Font.GothamBold
Title.Text = "FABLEHERD HELPER"
Title.TextColor3 = Color3.new(1, 1, 1)
Title.TextSize = 14
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = Top

local Close = Instance.new("TextButton")
Close.Size = UDim2.fromOffset(34, 30)
Close.Position = UDim2.new(1, -39, 0, 6)
Close.BackgroundColor3 = Color3.fromRGB(190, 65, 65)
Close.Text = "×"
Close.TextColor3 = Color3.new(1, 1, 1)
Close.TextSize = 22
Close.Font = Enum.Font.GothamBold
Close.Parent = Top
Instance.new("UICorner", Close).CornerRadius = UDim.new(0, 8)

local Content = Instance.new("Frame")
Content.BackgroundTransparency = 1
Content.Position = UDim2.fromOffset(10, 50)
Content.Size = UDim2.new(1, -20, 1, -60)
Content.Parent = Main

local Layout = Instance.new("UIListLayout")
Layout.Padding = UDim.new(0, 7)
Layout.SortOrder = Enum.SortOrder.LayoutOrder
Layout.Parent = Content

local Status = Instance.new("TextLabel")
Status.LayoutOrder = 0
Status.Size = UDim2.new(1, 0, 0, 22)
Status.BackgroundTransparency = 1
Status.Font = Enum.Font.Gotham
Status.TextSize = 11
Status.TextColor3 = Color3.fromRGB(170, 190, 215)
Status.Text = "Status: siap"
Status.Parent = Content

local Buttons = {}

local function makeToggle(key, label, order)
    local button = Instance.new("TextButton")
    button.Name = key
    button.LayoutOrder = order
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(55, 62, 78)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Parent = Content
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)

    local function update()
        button.Text = label .. (State[key] and "  [ON]" or "  [OFF]")
        button.BackgroundColor3 = State[key]
            and Color3.fromRGB(35, 125, 85)
            or Color3.fromRGB(55, 62, 78)
    end

    button.Activated:Connect(function()
        State[key] = not State[key]
        update()
        if key == "GuardianESP" or key == "PlayerESP" then
            if not State.GuardianESP and not State.PlayerESP then
                clearVisuals()
            end
        end
    end)

    Buttons[key] = update
    update()
end

local function makeAction(label, order, callback)
    local button = Instance.new("TextButton")
    button.LayoutOrder = order
    button.Size = UDim2.new(1, 0, 0, 34)
    button.BackgroundColor3 = Color3.fromRGB(55, 95, 155)
    button.BorderSizePixel = 0
    button.Font = Enum.Font.GothamSemibold
    button.TextSize = 12
    button.TextColor3 = Color3.new(1, 1, 1)
    button.Text = label
    button.Parent = Content
    Instance.new("UICorner", button).CornerRadius = UDim.new(0, 8)
    button.Activated:Connect(callback)
end

makeToggle("AutoAttack", "Auto Attack Guardian", 1)
makeToggle("GuardianESP", "ESP Guardian", 2)
makeToggle("PlayerESP", "ESP Player", 3)
makeToggle("AutoDropEgg", "Auto Drop Egg", 4)
makeToggle("AntiAFK", "Anti-AFK", 5)

makeAction("Teleport ke Guardian Terdekat", 6, function()
    local root = getCharacterRoot()
    local target = nearestGuardian()
    if root and target then
        local position = target:GetPivot().Position
        root.CFrame = CFrame.new(position + Vector3.new(0, 5, 7))
        Status.Text = "Status: teleport selesai"
    else
        Status.Text = "Status: Guardian tidak ditemukan"
    end
end)

makeAction("Drop Egg / Cargo Sekarang", 7, function()
    dropEgg()
    Status.Text = "Status: permintaan drop dikirim"
end)

-- Drag GUI (mouse dan touch)
local dragging, dragInput, dragStart, startPos
Top.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
        dragging = true
        dragStart = input.Position
        startPos = Main.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Top.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch then
        dragInput = input
    end
end)

table.insert(Connections, RunService.RenderStepped:Connect(function()
    if dragging and dragInput then
        local delta = dragInput.Position - dragStart
        Main.Position = UDim2.new(
            startPos.X.Scale, startPos.X.Offset + delta.X,
            startPos.Y.Scale, startPos.Y.Offset + delta.Y
        )
    end
end))

Close.Activated:Connect(function()
    State.Running = false
    for _, connection in ipairs(Connections) do
        pcall(function() connection:Disconnect() end)
    end
    clearVisuals()
    Gui:Destroy()
    _G.FableherdHelperRunning = nil
end)

-- Loop fitur
task.spawn(function()
    local lastAttack = 0
    local lastDrop = 0
    local lastESP = 0

    while State.Running and Gui.Parent do
        local now = os.clock()

        if State.AutoAttack and now - lastAttack >= ATTACK_DELAY then
            lastAttack = now
            attack()
        end

        if State.AutoDropEgg and now - lastDrop >= 1.5 then
            lastDrop = now
            local character = LocalPlayer.Character
            local tool = character and character:FindFirstChildOfClass("Tool")
            if tool and tool:GetAttribute("Kind") == "Egg" then
                dropEgg()
            end
        end

        if now - lastESP >= 0.8 then
            lastESP = now
            if State.GuardianESP or State.PlayerESP then
                refreshESP()
            else
                clearVisuals()
            end
        end

        Status.Text = "Status: aktif | Attack delay: " .. string.format("%.1f", ATTACK_DELAY) .. "s"
        task.wait(0.15)
    end
end)

-- Anti-AFK: meniru input kecil saat Roblox mengirim sinyal idle.
table.insert(Connections, LocalPlayer.Idled:Connect(function()
    if State.AntiAFK and State.Running then
        pcall(function()
            VirtualUser:CaptureController()
            VirtualUser:ClickButton2(Vector2.new(0, 0))
        end)
    end
end))

print("Fableherd Helper berhasil dimuat.")
