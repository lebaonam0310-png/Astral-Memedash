--[[
    Meme Dash - Astral v1.0.2
    - Button: Quick click = Toggle Menu.
    - Auto image fallback.
]]

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")
local VirtualUser = game:GetService("VirtualUser")
local CoreGui = game:GetService("CoreGui")

local LP = Players.LocalPlayer
local Camera = Workspace.CurrentCamera

local LOGO_ID = "rbxassetid://122642388068501" 
local TARGET_NAMES = {"Freddy", "maxwell", "TrollFace", "Gi-hun", "HN", "Nerd", "Peanut"}

local State = {
    AutoFarm = false, FarmMoney = true, FarmXP = true, FarmEvent = false,
    AutoJump = false, 
    EnableSpeed = false, WalkSpeed = 16,
    EnableJump = false, JumpHeight = 50,
    FlyEnabled = false, FlySpeed = 50, Noclip = false,
    ESPNextbot = false, ESPPlayer = false, ESPMode = "Highlight",
    ESPNextbotColor = Color3.fromRGB(255, 0, 0), ESPPlayerColor = Color3.fromRGB(0, 255, 0),
    ESPShowName = true, AntiNextbot = false, AntiNextbotRange = 50,
    TargetNames = TARGET_NAMES,
}

local Connections = {}
local FlyConnection, AntiNextbotConn, NoclipConn, SpeedConn, JumpConn
local ScriptEnabled = true
local Window = nil
local isSpeedHooked = false

local function HookProperties()
    if isSpeedHooked then return end
    pcall(function()
        local oldIndex
        local mt = getrawmetatable(game)
        setreadonly(mt, false)
        oldIndex = mt.__newindex
        mt.__newindex = newcclosure(function(t, k, v)
            if ScriptEnabled and t:IsA("Humanoid") then
                if k == "WalkSpeed" and State.EnableSpeed and (v == 10 or v == 16 or v < State.WalkSpeed) then
                    return oldIndex(t, k, State.WalkSpeed)
                elseif k == "JumpHeight" and State.EnableJump and (v == 5 or v < State.JumpHeight) then
                    return oldIndex(t, k, State.JumpHeight)
                end
            end
            return oldIndex(t, k, v)
        end)
        setreadonly(mt, true)
        isSpeedHooked = true
    end)
end
HookProperties()

local NEXTBOT_FOLDER = Workspace:FindFirstChild("Nextbots")
if not NEXTBOT_FOLDER then
    task.spawn(function()
        for i = 1, 60 do
            task.wait(1)
            NEXTBOT_FOLDER = Workspace:FindFirstChild("Nextbots")
            if NEXTBOT_FOLDER then break end
        end
    end)
end

local function getChar()
    local char = LP.Character
    if not char then return nil end
    local hrp = char:FindFirstChild("HumanoidRootPart")
    local hum = char:FindFirstChildOfClass("Humanoid")
    if not hrp or not hum or hum.Health <= 0 then return nil end
    return char, hrp, hum
end

local function isTarget(model)
    if model == LP.Character then return false end
    if NEXTBOT_FOLDER then
        if not model:IsDescendantOf(NEXTBOT_FOLDER) then return false end
    else
        local found = false
        for _, name in ipairs(State.TargetNames) do
            if model.Name:lower():find(name:lower()) then found = true break end
        end
        if not found then return false end
    end
    local hum = model:FindFirstChildOfClass("Humanoid")
    return hum and hum.Health > 0
end

local function findNearestTarget(range)
    local char, hrp = getChar()
    if not char or not hrp then return nil end
    local folder = NEXTBOT_FOLDER or Workspace
    local nearest, nearestDist = nil, range or 200
    for _, obj in ipairs(folder:GetDescendants()) do
        if obj:IsA("Model") and isTarget(obj) then
            local tHrp = obj:FindFirstChild("HumanoidRootPart")
            if tHrp then
                local d = (tHrp.Position - hrp.Position).Magnitude
                if d < nearestDist then nearest, nearestDist = obj, d end
            end
        end
    end
    return nearest
end

local function startSpeedEngine()
    if SpeedConn then SpeedConn:Disconnect() end
    SpeedConn = RunService.RenderStepped:Connect(function()
        if not ScriptEnabled then return end
        local char, hrp, hum = getChar()
        if not hum then return end
        if State.EnableSpeed and State.WalkSpeed > 16 then
            if hum.WalkSpeed ~= State.WalkSpeed then hum.WalkSpeed = State.WalkSpeed end
            if hum:GetState() == Enum.HumanoidStateType.Freefall and hrp.AssemblyLinearVelocity.Y < -5 then
                local moveDir = hum.MoveDirection
                if moveDir.Magnitude > 0 then
                    hrp.AssemblyLinearVelocity = Vector3.new(moveDir.X * State.WalkSpeed, hrp.AssemblyLinearVelocity.Y, moveDir.Z * State.WalkSpeed)
                end
            end
        end
    end)
end

local function startJumpEngine()
    if JumpConn then JumpConn:Disconnect() end
    JumpConn = RunService.Heartbeat:Connect(function()
        if not ScriptEnabled then return end
        local char, hrp, hum = getChar()
        if not hum then return end
        if State.EnableJump then
            if hum.UseJumpPower then hum.UseJumpPower = false end
            if math.abs(hum.JumpHeight - State.JumpHeight) > 0.1 then hum.JumpHeight = State.JumpHeight end
        end
    end)
end

local function startNoclip()
    if NoclipConn then NoclipConn:Disconnect() end
    NoclipConn = RunService.Stepped:Connect(function()
        if not ScriptEnabled or not State.Noclip then return end
        local char = LP.Character
        if char then
            for _, v in pairs(char:GetDescendants()) do
                if v:IsA("BasePart") and v.CanCollide then v.CanCollide = false end
            end
        end
    end)
end

local function startFly()
    if FlyConnection then FlyConnection:Disconnect() end
    local char, hrp, hum = getChar()
    if not char or not hrp then return end
    hum.PlatformStand = true
    local bodyVel = Instance.new("BodyVelocity")
    bodyVel.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    bodyVel.Velocity = Vector3.zero
    bodyVel.Parent = hrp
    FlyConnection = RunService.RenderStepped:Connect(function()
        if not ScriptEnabled then return end
        local c, h = getChar()
        if not c or not h or not Camera.Parent then return end
        local dir = Vector3.zero
        if UserInputService:IsKeyDown(Enum.KeyCode.W) then dir += Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.S) then dir -= Camera.CFrame.LookVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.A) then dir -= Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.D) then dir += Camera.CFrame.RightVector end
        if UserInputService:IsKeyDown(Enum.KeyCode.Space) then dir += Vector3.new(0,1,0) end
        if UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then dir -= Vector3.new(0,1,0) end
        bodyVel.Velocity = dir.Magnitude > 0 and dir.Unit * State.FlySpeed or Vector3.zero
    end)
end

local function stopFly()
    if FlyConnection then FlyConnection:Disconnect() FlyConnection = nil end
    local char, hrp, hum = getChar()
    if hrp then
        local bv = hrp:FindFirstChildOfClass("BodyVelocity")
        if bv then bv:Destroy() end
    end
    if hum then hum.PlatformStand = false end
end

local ESP = { Cache = {}, Connections = {}, UpdateRate = 1/15 }
local function clearESP()
    for model, data in pairs(ESP.Cache) do
        if data.highlight then data.highlight:Destroy() end
        if data.billboard then data.billboard:Destroy() end
    end
    ESP.Cache = {}
end

local function attachESP(model, color, showName)
    if ESP.Cache[model] then return end
    local data = {}
    local hl = Instance.new("Highlight")
    hl.Adornee = model; hl.FillColor = color; hl.OutlineColor = Color3.new(1,1,1)
    hl.FillTransparency = 0.5; hl.OutlineTransparency = 1; hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
    hl.Parent = model; data.highlight = hl
    if showName then
        local head = model:FindFirstChild("Head") or model:FindFirstChild("HumanoidRootPart")
        if head then
            local bb = Instance.new("BillboardGui")
            bb.Size = UDim2.new(0, 100, 0, 20); bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true; bb.Adornee = head; bb.Parent = model
            local tl = Instance.new("TextLabel")
            tl.Size = UDim2.new(1,0,1,0); tl.BackgroundTransparency = 1; tl.Text = model.Name
            tl.TextColor3 = color; tl.TextStrokeTransparency = 0; tl.TextScaled = true; tl.Parent = bb
            data.billboard = bb
        end
    end
    ESP.Cache[model] = data
end

local function detachESP(model)
    local data = ESP.Cache[model]
    if not data then return end
    if data.highlight then data.highlight:Destroy() end
    if data.billboard then data.billboard:Destroy() end
    ESP.Cache[model] = nil
end

local function startESP()
    if ESP.Connections.scan then ESP.Connections.scan:Disconnect() end
    local lastScan = 0
    ESP.Connections.scan = RunService.Heartbeat:Connect(function()
        if not ScriptEnabled or not (State.ESPNextbot or State.ESPPlayer) then return end
        local now = tick()
        if now - lastScan < ESP.UpdateRate then return end
        lastScan = now
        local seen = {}
        if State.ESPNextbot then
            local folder = NEXTBOT_FOLDER or Workspace
            for _, obj in ipairs(folder:GetDescendants()) do
                if obj:IsA("Model") and isTarget(obj) then
                    seen[obj] = true; attachESP(obj, State.ESPNextbotColor, State.ESPShowName)
                end
            end
        end
        if State.ESPPlayer then
            for _, plr in ipairs(Players:GetPlayers()) do
                if plr ~= LP and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    seen[plr.Character] = true; attachESP(plr.Character, State.ESPPlayerColor, State.ESPShowName)
                end
            end
        end
        for model in pairs(ESP.Cache) do
            if not seen[model] then detachESP(model) end
        end
    end)
end

local function startAntiNextbot()
    if AntiNextbotConn then AntiNextbotConn:Disconnect() end
    AntiNextbotConn = RunService.Heartbeat:Connect(function()
        if not ScriptEnabled or not State.AntiNextbot then return end
        local char, hrp = getChar()
        if not char or not hrp then return end
        local folder = NEXTBOT_FOLDER or Workspace
        for _, obj in ipairs(folder:GetChildren()) do
            if obj:IsA("Model") and isTarget(obj) then
                local tHrp = obj:FindFirstChild("HumanoidRootPart")
                if tHrp and (tHrp.Position - hrp.Position).Magnitude < State.AntiNextbotRange then
                    hrp.CFrame = CFrame.new(hrp.Position + (hrp.Position - tHrp.Position).Unit * 100 + Vector3.new(0, 50, 0))
                    break
                end
            end
        end
    end)
end

local function farmLoop()
    if not ScriptEnabled or not State.AutoFarm then return end
    local char, hrp = getChar()
    if not char or not hrp then return end
    if State.FarmEvent then hrp.CFrame = CFrame.new(hrp.Position.X, 500, hrp.Position.Z) end
    if State.FarmMoney or State.FarmXP then
        local target = findNearestTarget(200)
        if target then
            local tHrp = target:FindFirstChild("HumanoidRootPart")
            if tHrp then
                if (tHrp.Position - hrp.Position).Magnitude > 10 then hrp.CFrame = CFrame.new(tHrp.Position + Vector3.new(0, 3, 0)) end
                pcall(function() VirtualUser:Button1Down(Vector2.new(0,0)); task.wait(0.05); VirtualUser:Button1Up(Vector2.new(0,0)) end)
            end
        end
    end
end

Window = Fluent:CreateWindow({
    Title = "Astral | Meme Dash",
    SubTitle = "Beta v1.0.1",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Dark",
    MinimizeKey = nil
})

local Tabs = {
    Farm = Window:AddTab({ Title = "AutoFarm", Icon = "tractor" }),
    Player = Window:AddTab({ Title = "Player", Icon = "user" }),
    Visual = Window:AddTab({ Title = "Visual", Icon = "eye" }),
    Misc = Window:AddTab({ Title = "Misc", Icon = "settings" }),
}

Tabs.Farm:AddToggle("AutoFarm", { Title = "Auto Farm", Default = false }):OnChanged(function(v)
    State.AutoFarm = v
    if v then
        if Connections.farm then Connections.farm:Disconnect() end
        Connections.farm = RunService.Heartbeat:Connect(function() pcall(farmLoop) end)
    else
        if Connections.farm then Connections.farm:Disconnect() end
    end
end)
Tabs.Farm:AddToggle("FarmMoney", { Title = "Farm Money", Default = true }):OnChanged(function(v) State.FarmMoney = v end)
Tabs.Farm:AddToggle("FarmXP", { Title = "Farm XP", Default = true }):OnChanged(function(v) State.FarmXP = v end)
Tabs.Farm:AddToggle("FarmEvent", { Title = "Farm Event", Default = false }):OnChanged(function(v) State.FarmEvent = v end)

Tabs.Player:AddToggle("EnableSpeed", { Title = "Enable WalkSpeed", Default = false }):OnChanged(function(v)
    State.EnableSpeed = v
    if not v then local _, _, hum = getChar(); if hum then hum.WalkSpeed = 16 end end
end)
Tabs.Player:AddSlider("WalkSpeed", { Title = "Walk Speed", Default = 16, Min = 16, Max = 150, Rounding = 0 }):OnChanged(function(v) 
    State.WalkSpeed = v 
    if State.EnableSpeed then local _, _, hum = getChar(); if hum then hum.WalkSpeed = v end end
end)

Tabs.Player:AddToggle("EnableJump", { Title = "Enable Jump Height", Default = false }):OnChanged(function(v)
    State.EnableJump = v
    if not v then local _, _, hum = getChar(); if hum then hum.UseJumpPower = true; hum.JumpPower = 50 end end
end)
Tabs.Player:AddSlider("JumpHeight", { Title = "Jump Height", Default = 50, Min = 50, Max = 500, Rounding = 0 }):OnChanged(function(v) 
    State.JumpHeight = v 
    if State.EnableJump then local _, _, hum = getChar(); if hum then hum.UseJumpPower = false; hum.JumpHeight = v end end
end)

Tabs.Player:AddToggle("AutoJump", { Title = "Auto Jump", Default = false }):OnChanged(function(v)
    State.AutoJump = v
    if v then
        if Connections.jump then Connections.jump:Disconnect() end
        Connections.jump = RunService.Heartbeat:Connect(function()
            if State.AutoJump and ScriptEnabled then
                local _, _, hum = getChar()
                if hum and hum:GetState() ~= Enum.HumanoidStateType.Jumping then hum.Jump = true end
            end
        end)
    else
        if Connections.jump then Connections.jump:Disconnect() end
    end
end)

Tabs.Player:AddToggle("Noclip", { Title = "Noclip (No Clip)", Default = false }):OnChanged(function(v)
    State.Noclip = v
    if v then startNoclip() else if NoclipConn then NoclipConn:Disconnect() end end
end)
Tabs.Player:AddToggle("Fly", { Title = "Fly", Default = false }):OnChanged(function(v)
    State.FlyEnabled = v
    if v then startFly() else stopFly() end
end)
Tabs.Player:AddSlider("FlySpeed", { Title = "Fly Speed", Default = 50, Min = 10, Max = 300, Rounding = 0 }):OnChanged(function(v) State.FlySpeed = v end)

Tabs.Visual:AddToggle("ESPNextbot", { Title = "ESP Nextbot", Default = false }):OnChanged(function(v)
    State.ESPNextbot = v
    if v or State.ESPPlayer then startESP() else if ESP.Connections.scan then ESP.Connections.scan:Disconnect() end clearESP() end
end)
Tabs.Visual:AddToggle("ESPPlayer", { Title = "ESP Player", Default = false }):OnChanged(function(v)
    State.ESPPlayer = v
    if v or State.ESPNextbot then startESP() else if ESP.Connections.scan then ESP.Connections.scan:Disconnect() end clearESP() end
end)
Tabs.Visual:AddToggle("ESPShowName", { Title = "Show Name", Default = true }):OnChanged(function(v) State.ESPShowName = v; clearESP(); if State.ESPNextbot or State.ESPPlayer then startESP() end end)

Tabs.Misc:AddSlider("FPSCap", { Title = "FPS Cap", Default = 60, Min = 60, Max = 360, Rounding = 0 }):OnChanged(function(v) pcall(function() if setfpscap then setfpscap(v) end end) end)
Tabs.Misc:AddToggle("AntiNextbot", { Title = "Anti Nextbot", Default = false }):OnChanged(function(v)
    State.AntiNextbot = v
    if v then startAntiNextbot() else if AntiNextbotConn then AntiNextbotConn:Disconnect() end end
end)
Tabs.Misc:AddSlider("AntiNextbotRange", { Title = "Anti Range", Default = 50, Min = 10, Max = 200, Rounding = 0 }):OnChanged(function(v) State.AntiNextbotRange = v end)

local function createLogoButton()
    pcall(function()
        if CoreGui:FindFirstChild("AstralMainGui") then CoreGui.AstralMainGui:Destroy() end
    end)

    local gui = Instance.new("ScreenGui")
    gui.Name = "AstralMainGui"
    gui.ResetOnSpawn = false
    gui.DisplayOrder = 9999
    pcall(function() gui.Parent = CoreGui end)
    if not gui.Parent then gui.Parent = LP:WaitForChild("PlayerGui") end
    
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 55, 0, 55)
    holder.Position = UDim2.new(0.9, 0, 0.4, 0)
    holder.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
    holder.BorderSizePixel = 0
    holder.Parent = gui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(1, 0)
    corner.Parent = holder

    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(0, 170, 255)
    stroke.Thickness = 2
    stroke.Parent = holder

    local btn = Instance.new("ImageButton")
    btn.Size = UDim2.new(1, -6, 1, -6)
    btn.Position = UDim2.new(0, 3, 0, 3)
    btn.BackgroundTransparency = 1
    btn.Image = LOGO_ID
    btn.ScaleType = Enum.ScaleType.Fit
    btn.Parent = holder

    local btnCorner = Instance.new("UICorner")
    btnCorner.CornerRadius = UDim.new(1, 0)
    btnCorner.Parent = btn

    local dragging, dragInput, dragStart, startPos, moved
    holder.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            dragging = true; moved = false
            dragStart = input.Position; startPos = holder.Position
            input.Changed:Connect(function()
                if input.UserInputState == Enum.UserInputState.End then dragging = false end
            end)
        end
    end)
    holder.InputChanged:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
            dragInput = input
        end
    end)
    UserInputService.InputChanged:Connect(function(input)
        if input == dragInput and dragging then
            local delta = input.Position - dragStart
            if delta.Magnitude > 5 then moved = true end
            holder.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
        end
    end)

    local isUIVisible = true
    btn.MouseButton1Click:Connect(function()
        if moved then return end
        isUIVisible = not isUIVisible
        
        local found = false
        for _, container in ipairs({CoreGui, LP:FindFirstChild("PlayerGui")}) do
            if container then
                for _, g in ipairs(container:GetChildren()) do
                    if g:IsA("ScreenGui") and g.Name ~= "AstralMainGui" then
                        if g:FindFirstChild("Main", true) or g:FindFirstChild("Acrylic", true) then
                            g.Enabled = isUIVisible
                            found = true
                        end
                    end
                end
            end
        end
        if not found and Window then
            pcall(function() Window:Minimize() end)
        end

        stroke.Color = isUIVisible and Color3.fromRGB(0, 170, 255) or Color3.fromRGB(100, 100, 100)
        holder.BackgroundTransparency = isUIVisible and 0.2 or 0.6
    end)
end

createLogoButton()
startSpeedEngine()
startJumpEngine()
Window:SelectTab(1)

Fluent:Notify({
    Title = "Astral Loaded",
    Content = "Script loaded successfully.",
    Duration = 5
})

LP.CharacterAdded:Connect(function(char)
    task.wait(1)
    clearESP()
    if ScriptEnabled then
        if State.ESPNextbot or State.ESPPlayer then startESP() end
    end
end)
