-- DeveloperPanel.client.lua
-- Pasang sebagai LocalScript di StarterPlayer > StarterPlayerScripts.
-- Hanya untuk experience milik sendiri / pengujian dengan izin.
-- ESP dan teleport di bawah berjalan di sisi client; server tetap harus
-- memvalidasi semua aksi gameplay penting.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "DeveloperPanel"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(250, 280)
frame.Position = UDim2.new(0, 20, 0.35, 0)
frame.BackgroundColor3 = Color3.fromRGB(25, 27, 34)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, -16, 0, 38)
title.Position = UDim2.fromOffset(8, 4)
title.BackgroundTransparency = 1
title.Text = "DEVELOPER PANEL"
title.TextColor3 = Color3.fromRGB(255, 255, 255)
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.Parent = frame

local function makeButton(text, y)
    local button = Instance.new("TextButton")
    button.Size = UDim2.new(1, -20, 0, 34)
    button.Position = UDim2.fromOffset(10, y)
    button.BackgroundColor3 = Color3.fromRGB(54, 59, 73)
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.Font = Enum.Font.Gotham
    button.TextSize = 13
    button.Text = text
    button.AutoButtonColor = true
    button.Parent = frame
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, 7)
    c.Parent = button
    return button
end

-- Drag panel
do
    local dragging, dragStart, startPos
    title.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1
        or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true
            dragStart = input.Position
            startPos = frame.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then
                    dragging = false
                end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
        or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - dragStart
            frame.Position = UDim2.new(
                startPos.X.Scale, startPos.X.Offset + delta.X,
                startPos.Y.Scale, startPos.Y.Offset + delta.Y
            )
        end
    end)
end

local espEnabled = false
local highlights = {}

local function clearESP()
    for player, highlight in pairs(highlights) do
        if highlight then highlight:Destroy() end
        highlights[player] = nil
    end
end

local function addESP(player)
    if player == localPlayer or not espEnabled then return end
    local character = player.Character
    if not character then return end

    if highlights[player] then highlights[player]:Destroy() end

    local highlight = Instance.new("Highlight")
    highlight.Name = "DeveloperESP"
    highlight.Adornee = character
    highlight.FillColor = Color3.fromRGB(255, 190, 60)
    highlight.OutlineColor = Color3.fromRGB(255, 255, 255)
    highlight.FillTransparency = 0.65
    highlight.DepthMode = Enum.HighlightDepthMode.Occluded
    highlight.Parent = character
    highlights[player] = highlight
end

local espButton = makeButton("ESP Pemain: OFF", 50)
espButton.MouseButton1Click:Connect(function()
    espEnabled = not espEnabled
    espButton.Text = "ESP Pemain: " .. (espEnabled and "ON" or "OFF")
    if espEnabled then
        for _, player in ipairs(Players:GetPlayers()) do addESP(player) end
    else
        clearESP()
    end
end)

Players.PlayerAdded:Connect(function(player)
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        addESP(player)
    end)
end)

Players.PlayerRemoving:Connect(function(player)
    if highlights[player] then highlights[player]:Destroy() end
    highlights[player] = nil
end)

for _, player in ipairs(Players:GetPlayers()) do
    player.CharacterAdded:Connect(function()
        task.wait(0.5)
        addESP(player)
    end)
end

local teleportButton = makeButton("Teleport ke Spawn", 92)
teleportButton.MouseButton1Click:Connect(function()
    local character = localPlayer.Character
    local root = character and character:FindFirstChild("HumanoidRootPart")
    local spawnLocation = workspace:FindFirstChildWhichIsA("SpawnLocation", true)
    if root and spawnLocation then
        root.CFrame = spawnLocation.CFrame + Vector3.new(0, 4, 0)
    else
        warn("SpawnLocation atau HumanoidRootPart tidak ditemukan.")
    end
end)

local closeButton = makeButton("Tutup Panel", 134)
closeButton.MouseButton1Click:Connect(function()
    gui.Enabled = false
end)

local reopenButton = Instance.new("TextButton")
reopenButton.Name = "OpenDeveloperPanel"
reopenButton.Size = UDim2.fromOffset(110, 32)
reopenButton.Position = UDim2.new(0, 20, 0, 20)
reopenButton.BackgroundColor3 = Color3.fromRGB(54, 59, 73)
reopenButton.TextColor3 = Color3.new(1, 1, 1)
reopenButton.Text = "Buka Panel"
reopenButton.Font = Enum.Font.GothamBold
reopenButton.TextSize = 12
reopenButton.Visible = false
reopenButton.Parent = gui
reopenButton.MouseButton1Click:Connect(function()
    gui.Enabled = true
    reopenButton.Visible = false
end)
closeButton.MouseButton1Click:Connect(function()
    gui.Enabled = false
    reopenButton.Visible = true
end)

local note = Instance.new("TextLabel")
note.Size = UDim2.new(1, -20, 0, 88)
note.Position = UDim2.fromOffset(10, 178)
note.BackgroundTransparency = 1
note.TextWrapped = true
note.TextYAlignment = Enum.TextYAlignment.Top
note.Text = "Auto Collect, sistem combat test, dan anti-AFK perlu integrasi server resmi game. Jangan jalankan aksi penting hanya dari LocalScript."
note.TextColor3 = Color3.fromRGB(190, 195, 205)
note.Font = Enum.Font.Gotham
note.TextSize = 11
note.Parent = frame
