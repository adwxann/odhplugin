local shared = odh_shared_plugins

local flick_section = shared.AddSection("🎯 Flick to Murderer [v4.3]")

flick_section:AddLabel("The ONLY working solution for ShiftLock")

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")
local Camera = workspace.CurrentCamera

local flickEnabled = false
local flickSpeed = 0.15
local returnSpeed = 0.2
local shootDelay = 0.05
local shiftLockDisableDuration = 0.1
local selectedInput = "Q"
local inputType = "Keyboard"
local showTracers = false
local maxDistance = 150
local smoothReturn = true
local antiDetection = true
local forceDisableShiftLock = true
local rotationMethod = "Velocity-Based"

local isFlicking = false
local originalCFrame = nil
local mobileButton = nil
local tracer = nil
local wasShiftLockEnabled = false
local originalMouseBehavior = nil
local originalVelocity = nil
local wasInAir = false
local rotationConnection = nil

local keyboardKeys = {
    "Q", "E", "R", "T", "Y", "F", "G", "H", "Z", "X", "C", "V", "B",
    "Tab", "CapsLock", "LeftShift", "LeftControl", "LeftAlt",
    "One", "Two", "Three", "Four", "Five",
    "F1", "F2", "F3", "F4", "F5", "F6",
    "Insert", "Delete", "Home", "End", "PageUp", "PageDown"
}

local mouseButtons = {
    "Left Click", "Right Click", "Middle Click", "Mouse4", "Mouse5"
}

local rotationMethods = {
    "Velocity-Based",
    "CFrame-Instant", 
    "TweenService",
    "BodyVelocity"
}

local function isShiftLockActive()
    return UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter
end

local function disableShiftLock()
    if isShiftLockActive() then
        wasShiftLockEnabled = true
        originalMouseBehavior = UserInputService.MouseBehavior
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.AutoRotate = false
            end
        end
        
        return true
    end
    return false
end

local function restoreShiftLock()
    if wasShiftLockEnabled and originalMouseBehavior then
        task.wait(shiftLockDisableDuration)
        UserInputService.MouseBehavior = originalMouseBehavior
        
        local character = LocalPlayer.Character
        if character then
            local humanoid = character:FindFirstChild("Humanoid")
            if humanoid then
                humanoid.AutoRotate = true
            end
        end
        
        wasShiftLockEnabled = false
        originalMouseBehavior = nil
    end
end

local function findMurdererMM2()
    local success, roleData = pcall(function()
        local remote = ReplicatedStorage:FindFirstChild("GetPlayerData", true)
        if remote and remote:IsA("RemoteFunction") then
            return remote:InvokeServer()
        end
    end)
    
    if success and roleData then
        for playerName, data in pairs(roleData) do
            if data.Role == "Murderer" and not data.Killed and not data.Dead then
                local player = Players:FindFirstChild(playerName)
                if player and player.Character then
                    return player
                end
            end
        end
    end
    
    return nil
end

local function findMurdererGeneric()
    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer and player.Character then
            local humanoid = player.Character:FindFirstChild("Humanoid")
            if humanoid and humanoid.Health > 0 then
                for _, item in ipairs(player.Character:GetChildren()) do
                    if item:IsA("Tool") then
                        local toolName = item.Name:lower()
                        if toolName:find("knife") or toolName:find("sword") or 
                           toolName:find("blade") or toolName:find("scythe") or 
                           toolName:find("killer") or toolName:find("murderer") then
                            return player
                        end
                    end
                end
                
                local backpack = player:FindFirstChild("Backpack")
                if backpack then
                    for _, item in ipairs(backpack:GetChildren()) do
                        if item:IsA("Tool") then
                            local toolName = item.Name:lower()
                            if toolName:find("knife") or toolName:find("sword") or 
                               toolName:find("blade") or toolName:find("scythe") or 
                               toolName:find("killer") or toolName:find("murderer") then
                                return player
                            end
                        end
                    end
                end
            end
        end
    end
    return nil
end

local function findMurderer()
    if game.PlaceId == 142823291 then
        local murderer = findMurdererMM2()
        if murderer then return murderer end
    end
    return findMurdererGeneric()
end

local function equipGun()
    local character = LocalPlayer.Character
    if not character then return false end
    
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoid then return false end
    
    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") then
            local toolName = tool.Name:lower()
            if toolName:find("gun") or toolName:find("pistol") or 
               toolName:find("revolver") or toolName:find("shooter") then
                return true
            end
        end
    end
    
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            if tool:IsA("Tool") then
                local toolName = tool.Name:lower()
                if toolName:find("gun") or toolName:find("pistol") or 
                   toolName:find("revolver") or toolName:find("shooter") then
                    humanoid:EquipTool(tool)
                    task.wait(0.1)
                    return true
                end
            end
        end
    end
    
    return false
end

local function updateTracer(targetPosition)
    if not showTracers then
        if tracer then
            tracer:Destroy()
            tracer = nil
        end
        return
    end
    
    if not tracer then
        tracer = Instance.new("Part")
        tracer.Name = "FlickTracer"
        tracer.Anchored = true
        tracer.CanCollide = false
        tracer.Material = Enum.Material.Neon
        tracer.BrickColor = BrickColor.new("Really red")
        tracer.Transparency = 0.5
        tracer.Parent = workspace
    end
    
    local character = LocalPlayer.Character
    if character and character:FindFirstChild("HumanoidRootPart") then
        local startPos = character.HumanoidRootPart.Position
        local distance = (targetPosition - startPos).Magnitude
        
        tracer.Size = Vector3.new(0.2, 0.2, distance)
        tracer.CFrame = CFrame.lookAt(startPos, targetPosition) * CFrame.new(0, 0, -distance/2)
        
        task.spawn(function()
            for i = 0.5, 1, 0.1 do
                tracer.Transparency = i
                task.wait(0.05)
            end
            if tracer then
                tracer:Destroy()
                tracer = nil
            end
        end)
    end
end

local function simulateClick()
    local success = false
    
    if not success then
        success = pcall(function()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
            task.wait()
            VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
        end)
    end
    
    if not success then
        success = pcall(function()
            local mouse = LocalPlayer:GetMouse()
            if mouse.Click then
                mouse:Click()
            end
        end)
    end
    
    pcall(function()
        local character = LocalPlayer.Character
        if character then
            for _, tool in pairs(character:GetChildren()) do
                if tool:IsA("Tool") then
                    tool:Activate()
                    break
                end
            end
        end
    end)
end

local function isPlayerInAir(humanoid, rootPart)
    if humanoid:GetState() == Enum.HumanoidStateType.Freefall or 
       humanoid:GetState() == Enum.HumanoidStateType.Flying or
       humanoid:GetState() == Enum.HumanoidStateType.Jumping then
        return true
    end
    
    local raycast = workspace:Raycast(rootPart.Position, Vector3.new(0, -5, 0))
    return raycast == nil
end

local function performRotation(humanoidRootPart, targetCFrame, callback)
    if rotationMethod == "CFrame-Instant" then
        humanoidRootPart.CFrame = targetCFrame
        if wasInAir and originalVelocity then
            humanoidRootPart.AssemblyLinearVelocity = originalVelocity
        end
        task.wait(flickSpeed)
        callback()
        
    elseif rotationMethod == "Velocity-Based" then
        local startTime = tick()
        local startCFrame = humanoidRootPart.CFrame
        local savedVelocity = humanoidRootPart.AssemblyLinearVelocity
        
        rotationConnection = RunService.Heartbeat:Connect(function()
            local elapsed = tick() - startTime
            local progress = math.min(elapsed / flickSpeed, 1)
            
            local currentRotation = startCFrame:Lerp(targetCFrame, progress)
            humanoidRootPart.CFrame = CFrame.new(humanoidRootPart.Position) * currentRotation.Rotation
            humanoidRootPart.AssemblyLinearVelocity = savedVelocity
            
            if progress >= 1 then
                if rotationConnection then
                    rotationConnection:Disconnect()
                    rotationConnection = nil
                end
                callback()
            end
        end)
        
    elseif rotationMethod == "TweenService" then
        if wasInAir then
            humanoidRootPart.CFrame = targetCFrame
            humanoidRootPart.AssemblyLinearVelocity = originalVelocity
            task.wait(flickSpeed)
            callback()
        else
            local tweenInfo = TweenInfo.new(
                flickSpeed,
                Enum.EasingStyle.Sine,
                Enum.EasingDirection.InOut
            )
            
            local tween = TweenService:Create(
                humanoidRootPart,
                tweenInfo,
                {CFrame = targetCFrame}
            )
            
            tween:Play()
            tween.Completed:Connect(callback)
        end
        
    elseif rotationMethod == "BodyVelocity" then
        local bodyVelocity = Instance.new("BodyVelocity")
        bodyVelocity.MaxForce = Vector3.new(0, math.huge, 0)
        bodyVelocity.Velocity = originalVelocity or Vector3.new(0, 0, 0)
        bodyVelocity.Parent = humanoidRootPart
        
        humanoidRootPart.CFrame = targetCFrame
        
        task.wait(flickSpeed)
        bodyVelocity:Destroy()
        callback()
    end
end

local function performFlick()
    if isFlicking then return end
    if not flickEnabled then return end
    
    local character = LocalPlayer.Character
    if not character then
        shared.Notify("❌ Character not found!", 2)
        return
    end
    
    local humanoidRootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChild("Humanoid")
    if not humanoidRootPart or not humanoid then return end
    
    local murderer = findMurderer()
    if not murderer or not murderer.Character then
        shared.Notify("⚠️ Murderer not found!", 2)
        return
    end
    
    local murdererRoot = murderer.Character:FindFirstChild("HumanoidRootPart")
    if not murdererRoot then return end
    
    local distance = (murdererRoot.Position - humanoidRootPart.Position).Magnitude
    if distance > maxDistance then
        shared.Notify("⚠️ Target too far: " .. math.floor(distance) .. " studs", 2)
        return
    end
    
    if not equipGun() then
        shared.Notify("❌ Gun not found!", 2)
        return
    end
    
    isFlicking = true
    
    originalCFrame = humanoidRootPart.CFrame
    
    wasInAir = isPlayerInAir(humanoid, humanoidRootPart)
    if wasInAir then
        originalVelocity = humanoidRootPart.AssemblyLinearVelocity
    end
    
    local shiftLockWasDisabled = false
    if forceDisableShiftLock and isShiftLockActive() then
        shiftLockWasDisabled = disableShiftLock()
        if shiftLockWasDisabled then
            task.wait(0.05)
        end
    end
    
    updateTracer(murdererRoot.Position)
    
    local myPosition = humanoidRootPart.Position
    local targetPosition = murdererRoot.Position
    local direction = (targetPosition - myPosition) * Vector3.new(1, 0, 1)
    
    if direction.Magnitude > 0 then
        direction = direction.Unit
        local targetCFrame = CFrame.lookAt(myPosition, myPosition + direction)
        
        if wasInAir then
            targetCFrame = CFrame.new(humanoidRootPart.Position) * targetCFrame.Rotation
        else
            targetCFrame = CFrame.new(originalCFrame.Position) * targetCFrame.Rotation
        end
        
        performRotation(humanoidRootPart, targetCFrame, function()
            task.wait(shootDelay)
            simulateClick()
            
            if originalCFrame then
                performRotation(humanoidRootPart, originalCFrame, function()
                    if shiftLockWasDisabled then
                        restoreShiftLock()
                    end
                    
                    if not wasInAir then
                        humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                        humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
                    end
                    
                    isFlicking = false
                end)
            else
                if shiftLockWasDisabled then
                    restoreShiftLock()
                end
                isFlicking = false
            end
        end)
    end
    
    shared.Notify("✅ Flicked: " .. murderer.Name .. " (" .. math.floor(distance) .. " studs)", 1)
end

flick_section:AddToggle("Enable Flick", function(state)
    flickEnabled = state
    if state then
        shared.Notify("✅ Flick Enabled", 2)
    else
        shared.Notify("❌ Flick Disabled", 2)
        if tracer then
            tracer:Destroy()
            tracer = nil
        end
        if rotationConnection then
            rotationConnection:Disconnect()
            rotationConnection = nil
        end
    end
end)

flick_section:AddToggle("Auto-Disable ShiftLock (Required)", function(state)
    forceDisableShiftLock = state
    if state then
        shared.Notify("✅ Will temporarily disable ShiftLock during flick", 3)
    else
        shared.Notify("⚠️ Flick won't work with ShiftLock active!", 3)
    end
end)

flick_section:AddDropdown("Rotation Method", rotationMethods, function(selected)
    rotationMethod = selected
    shared.Notify("🔄 Method: " .. selected, 2)
    
    if selected == "Velocity-Based" then
        shared.Notify("Best for air physics preservation", 3)
    elseif selected == "CFrame-Instant" then
        shared.Notify("Instant rotation, maintains velocity", 3)
    elseif selected == "TweenService" then
        shared.Notify("Smooth but may cause floating", 3)
    elseif selected == "BodyVelocity" then
        shared.Notify("Uses physics to maintain momentum", 3)
    end
end)

flick_section:AddSlider("ShiftLock Disable Duration (ms)", 50, 500, 100, function(value)
    shiftLockDisableDuration = value / 1000
    shared.Notify("⏱️ ShiftLock restore delay: " .. value .. "ms", 1)
end)

flick_section:AddDropdown("Input Type", {"Keyboard", "Mouse"}, function(selected)
    inputType = selected
    shared.Notify("📌 Input type: " .. selected, 2)
end)

flick_section:AddDropdown("Keyboard Key", keyboardKeys, function(selected)
    selectedInput = selected
    shared.Notify("⌨️ Key set to: " .. selected, 2)
end)

flick_section:AddDropdown("Mouse Button", mouseButtons, function(selected)
    selectedInput = selected
    shared.Notify("🖱️ Mouse button: " .. selected, 2)
end)

flick_section:AddSlider("Flick Speed (ms)", 0, 500, 150, function(value)
    flickSpeed = value / 1000
    local speedType = value < 50 and "Instant" or value < 150 and "Fast" or value < 300 and "Natural" or "Slow"
    shared.Notify("⚡ Speed: " .. speedType, 1)
end)

flick_section:AddSlider("Return Speed (ms)", 0, 500, 200, function(value)
    returnSpeed = value / 1000
end)

flick_section:AddSlider("Shoot Delay (ms)", 0, 200, 50, function(value)
    shootDelay = value / 1000
end)

flick_section:AddSlider("Max Distance", 50, 500, 150, function(value)
    maxDistance = value
end)

flick_section:AddLabel("⚙️ Advanced Features")

flick_section:AddToggle("Smooth Movement", function(state)
    smoothReturn = state
    shared.Notify(state and "✅ Smooth movement ON" or "❌ Smooth movement OFF", 2)
end)

flick_section:AddToggle("Anti-Detection (Human-like)", function(state)
    antiDetection = state
    shared.Notify(state and "✅ Anti-detection ON" or "❌ Anti-detection OFF", 2)
end)

flick_section:AddToggle("Show Tracers", function(state)
    showTracers = state
    if not state and tracer then
        tracer:Destroy()
        tracer = nil
    end
    shared.Notify(state and "✅ Tracers ON" or "❌ Tracers OFF", 2)
end)

local function handleInput(input)
    if not flickEnabled or isFlicking then return end
    
    if inputType == "Keyboard" then
        local keyName = selectedInput
        
        local specialKeys = {
            ["Tab"] = Enum.KeyCode.Tab,
            ["CapsLock"] = Enum.KeyCode.CapsLock,
            ["LeftShift"] = Enum.KeyCode.LeftShift,
            ["LeftControl"] = Enum.KeyCode.LeftControl,
            ["LeftAlt"] = Enum.KeyCode.LeftAlt,
            ["One"] = Enum.KeyCode.One,
            ["Two"] = Enum.KeyCode.Two,
            ["Three"] = Enum.KeyCode.Three,
            ["Four"] = Enum.KeyCode.Four,
            ["Five"] = Enum.KeyCode.Five,
            ["Insert"] = Enum.KeyCode.Insert,
            ["Delete"] = Enum.KeyCode.Delete,
            ["Home"] = Enum.KeyCode.Home,
            ["End"] = Enum.KeyCode.End,
            ["PageUp"] = Enum.KeyCode.PageUp,
            ["PageDown"] = Enum.KeyCode.PageDown
        }
        
        local targetKey
        if specialKeys[keyName] then
            targetKey = specialKeys[keyName]
        elseif keyName:sub(1, 1) == "F" and tonumber(keyName:sub(2)) then
            targetKey = Enum.KeyCode["F" .. keyName:sub(2)]
        else
            targetKey = Enum.KeyCode[keyName]
        end
        
        if input.KeyCode == targetKey then
            performFlick()
        end
    elseif inputType == "Mouse" then
        local mouseMap = {
            ["Left Click"] = Enum.UserInputType.MouseButton1,
            ["Right Click"] = Enum.UserInputType.MouseButton2,
            ["Middle Click"] = Enum.UserInputType.MouseButton3,
            ["Mouse4"] = Enum.UserInputType.MouseButton4,
            ["Mouse5"] = Enum.UserInputType.MouseButton5
        }
        
        if input.UserInputType == mouseMap[selectedInput] then
            performFlick()
        end
    end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    handleInput(input)
end)

flick_section:AddToggle("Mobile Button", function(state)
    if state then
        if mobileButton then mobileButton:Destroy() end
        
        local gui = Instance.new("ScreenGui")
        gui.Name = "FlickMobileGUI"
        gui.ResetOnSpawn = false
        gui.Parent = LocalPlayer:WaitForChild("PlayerGui")
        
        local button = Instance.new("TextButton")
        button.Name = "FlickButton"
        button.Text = "🎯"
        button.Font = Enum.Font.SourceSansBold
        button.TextScaled = true
        button.TextColor3 = Color3.fromRGB(255, 255, 255)
        button.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        button.BorderSizePixel = 3
        button.BorderColor3 = Color3.fromRGB(0, 0, 0)
        button.Size = UDim2.new(0, 60, 0, 60)
        button.Position = UDim2.new(0.85, 0, 0.5, 0)
        button.Active = true
        button.Draggable = true
        button.Parent = gui
        
        local corner = Instance.new("UICorner")
        corner.CornerRadius = UDim.new(0.5, 0)
        corner.Parent = button
        
        button.MouseButton1Down:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(180, 30, 30)
            button.Size = UDim2.new(0, 55, 0, 55)
        end)
        
        button.MouseButton1Up:Connect(function()
            button.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
            button.Size = UDim2.new(0, 60, 0, 60)
            performFlick()
        end)
        
        mobileButton = gui
    else
        if mobileButton then
            mobileButton:Destroy()
            mobileButton = nil
        end
    end
end)

flick_section:AddLabel("")
flick_section:AddLabel("⚠️ IMPORTANT:")
flick_section:AddLabel("• ShiftLock is temporarily disabled during flick")

shared.Notify("✅ Flick-to-Murderer v4.3 Loaded!", 3)
shared.Notify("Try 'Velocity Based' method for best air physics", 4)
print("=====================================")
print("Flick-to-Murderer Plugin v4.3")
print("Multiple rotation methods available")
print("Air physics preservation fixed")
print("=====================================")

return function()
    if mobileButton then mobileButton:Destroy() end
    if tracer then tracer:Destroy() end
    if rotationConnection then
        rotationConnection:Disconnect()
        rotationConnection = nil
    end
    if wasShiftLockEnabled then
        restoreShiftLock()
    end
end