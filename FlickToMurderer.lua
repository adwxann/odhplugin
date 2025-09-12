local shared = odh_shared_plugins

local flick_section = shared.AddSection("🎯 Flick to Murderer [v5.0 Mobile Fix]")
flick_section:AddLabel("Mobile joystick freeze has been fixed")

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local Camera = workspace.CurrentCamera

local flickEnabled = false
local isFlicking = false

local flickSpeed = 0.15
local returnSpeed = 0.2
local shootDelay = 0.05
local shiftLockDisableDuration = 0.1
local maxDistance = 150
local rotationMethod = "Velocity-Based"
local forceDisableShiftLock = true
local showTracers = false

local inputType = "Keyboard"
local selectedInput = "Q"

local originalCFrame = nil
local originalVelocity = nil
local wasInAir = false
local wasShiftLockEnabled = false
local originalMouseBehavior = nil

local mobileButton = nil
local tracer = nil
local rotationConnection = nil

local notificationSettings = {
    flickSuccess = true,
    flickEnabled = true,
    flickDisabled = true,
    targetNotFound = true,
    targetTooFar = true,
    gunNotFound = true,
    mobileRestore = true,
    configChanges = true
}

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
    "Velocity-Based", "CFrame-Instant", "TweenService", "BodyVelocity"
}

local function showNotification(type, message, duration)
    if notificationSettings[type] then
        shared.Notify(message, duration)
    end
end

local function restoreCharacterState()
    local character = LocalPlayer.Character
    if not character then return end
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    local rootPart = character:FindFirstChild("HumanoidRootPart")

    if wasShiftLockEnabled and originalMouseBehavior then
        task.wait(shiftLockDisableDuration)
        UserInputService.MouseBehavior = originalMouseBehavior
        wasShiftLockEnabled = false
        originalMouseBehavior = nil
    end

    if humanoid then
        humanoid.AutoRotate = true
        if UserInputService.TouchEnabled then
            pcall(function()
                humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
            end)
            task.wait()
            if rootPart then
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0.01)
                task.wait()
                rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
            end
            showNotification("mobileRestore", "📱 Mobile controls restored", 1)
        end
    end
end

local function findTarget(findClosest)
    if findClosest then
        local closestPlayer, minDistance = nil, maxDistance
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                local distance = (LocalPlayer.Character.HumanoidRootPart.Position - player.Character.HumanoidRootPart.Position).Magnitude
                if distance < minDistance then
                    minDistance = distance
                    closestPlayer = player
                end
            end
        end
        return closestPlayer
    else
        if game.PlaceId == 142823291 then
            local success, roleData = pcall(function()
                return ReplicatedStorage.GetPlayerData:InvokeServer()
            end)
            if success and roleData then
                for name, data in pairs(roleData) do
                    if data.Role == "Murderer" and not data.Killed and not data.Dead then
                        local player = Players:FindFirstChild(name)
                        if player and player.Character then return player end
                    end
                end
            end
        end
        for _, player in ipairs(Players:GetPlayers()) do
            if player ~= LocalPlayer and player.Character and player.Character:FindFirstChild("Humanoid") and player.Character.Humanoid.Health > 0 then
                for _, item in ipairs(player.Character:GetChildren()) do
                    if item:IsA("Tool") and item.Name:lower():match("knife|sword|blade|scythe|killer|murderer") then
                        return player
                    end
                end
            end
        end
    end
    return nil
end

local function hasGunEquipped()
    local character = LocalPlayer.Character
    if not character then return false end

    for _, tool in ipairs(character:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():match("gun|pistol|revolver|shooter") then
            return true
        end
    end
    return false
end

local function equipGun()
    if hasGunEquipped() then return true end

    local character = LocalPlayer.Character
    local humanoid = character and character:FindFirstChildOfClass("Humanoid")
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if not humanoid or not backpack then return false end

    for _, tool in ipairs(backpack:GetChildren()) do
        if tool:IsA("Tool") and tool.Name:lower():match("gun|pistol|revolver|shooter") then
            humanoid:EquipTool(tool)
            task.wait(0.1)
            return true
        end
    end
    return false
end

local function updateTracer(targetPosition)
    if tracer then
        tracer:Destroy()
        tracer = nil
    end
    if not showTracers then return end

    local rootPart = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end

    tracer = Instance.new("Part")
    tracer.Name = "FlickTracer"
    tracer.Anchored = true
    tracer.CanCollide = false
    tracer.Material = Enum.Material.Neon
    tracer.Color = Color3.fromRGB(255, 0, 0)
    tracer.Transparency = 0.5
    tracer.Parent = workspace

    local startPos = rootPart.Position
    local distance = (targetPosition - startPos).Magnitude
    tracer.Size = Vector3.new(0.2, 0.2, distance)
    tracer.CFrame = CFrame.lookAt(startPos, targetPosition) * CFrame.new(0, 0, -distance / 2)

    task.spawn(function()
        TweenService:Create(tracer, TweenInfo.new(0.5), {Transparency = 1}):Play()
        task.wait(0.5)
        if tracer then
            tracer:Destroy()
            tracer = nil
        end
    end)
end

local function simulateClick()
    pcall(function()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, true, game, 0)
        task.wait()
        VirtualInputManager:SendMouseButtonEvent(0, 0, 0, false, game, 0)
    end)
    pcall(function()
        for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
            if tool:IsA("Tool") then tool:Activate() break end
        end
    end)
end

local function isPlayerInAir(humanoid)
    local state = humanoid:GetState()
    return state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
end

local function performRotation(rootPart, targetCFrame, speed, onCompleted)
    local startCFrame = rootPart.CFrame

    if rotationMethod == "CFrame-Instant" then
        rootPart.CFrame = targetCFrame
        if wasInAir and originalVelocity then rootPart.AssemblyLinearVelocity = originalVelocity end
        task.wait(speed)
        onCompleted()

    elseif rotationMethod == "Velocity-Based" then
        local startTime = tick()
        local savedVelocity = wasInAir and originalVelocity or rootPart.AssemblyLinearVelocity
        rotationConnection = RunService.Heartbeat:Connect(function()
            local progress = math.min((tick() - startTime) / speed, 1)
            local currentRotation = startCFrame:Lerp(targetCFrame, progress).Rotation
            rootPart.CFrame = CFrame.new(rootPart.Position) * currentRotation
            rootPart.AssemblyLinearVelocity = savedVelocity
            if progress >= 1 then
                rotationConnection:Disconnect()
                rotationConnection = nil
                onCompleted()
            end
        end)

    elseif rotationMethod == "TweenService" then
        local tween = TweenService:Create(rootPart, TweenInfo.new(speed, Enum.EasingStyle.Sine), {CFrame = targetCFrame})
        tween.Completed:Connect(onCompleted)
        tween:Play()

    elseif rotationMethod == "BodyVelocity" then
        local bodyVel = Instance.new("BodyVelocity")
        bodyVel.MaxForce = Vector3.new(0, math.huge, 0)
        bodyVel.Velocity = originalVelocity or Vector3.new()
        bodyVel.Parent = rootPart
        rootPart.CFrame = targetCFrame
        task.wait(speed)
        bodyVel:Destroy()
        onCompleted()
    end
end

local function executeFlick(isTest)
    if isFlicking or not flickEnabled then return end

    local character = LocalPlayer.Character
    if not character then return end
    local rootPart = character:FindFirstChild("HumanoidRootPart")
    local humanoid = character:FindFirstChildOfClass("Humanoid")
    if not rootPart or not humanoid then return end

    if not isTest and not equipGun() then
        showNotification("gunNotFound", "❌ Gun not found!", 2)
        return
    end

    local targetPlayer = findTarget(isTest)
    if not targetPlayer or not targetPlayer.Character then
        local message = isTest and "⚠️ No nearby players found!" or "⚠️ Murderer not found!"
        showNotification("targetNotFound", message, 2)
        return
    end

    local targetRoot = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
    if not targetRoot then return end

    local distance = (targetRoot.Position - rootPart.Position).Magnitude
    if distance > maxDistance then
        showNotification("targetTooFar", "⚠️ Target too far: " .. math.floor(distance) .. " studs", 2)
        return
    end

    isFlicking = true
    originalCFrame = rootPart.CFrame
    wasInAir = isPlayerInAir(humanoid)
    if wasInAir then originalVelocity = rootPart.AssemblyLinearVelocity end

    if forceDisableShiftLock and UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
        wasShiftLockEnabled = true
        originalMouseBehavior = UserInputService.MouseBehavior
        UserInputService.MouseBehavior = Enum.MouseBehavior.Default
        task.wait(0.05)
    end

    updateTracer(targetRoot.Position)

    local direction = (targetRoot.Position - rootPart.Position) * Vector3.new(1, 0, 1)
    local targetRotation = CFrame.lookAt(rootPart.Position, rootPart.Position + direction.Unit)
    local targetCFrame = CFrame.new(rootPart.Position) * targetRotation.Rotation
    
    local flickMessage = (isTest and "Test flick on " or "Flicked: ") .. targetPlayer.Name .. " (" .. math.floor(distance) .. " studs)"

    performRotation(rootPart, targetCFrame, flickSpeed, function()
        if not isTest then
            task.wait(shootDelay)
            simulateClick()
        end
        showNotification("flickSuccess", "✅ " .. flickMessage, 1)

        performRotation(rootPart, originalCFrame, returnSpeed, function()
            restoreCharacterState()
            isFlicking = false
        end)
    end)
end

local enableFlickToggle = flick_section:AddToggle("Enable Flick", function(state)
    flickEnabled = state
    showNotification(state and "flickEnabled" or "flickDisabled", state and "✅ Flick Enabled" or "❌ Flick Disabled", 2)
end)
enableFlickToggle:setState(false)

local autoDisableShiftLockToggle = flick_section:AddToggle("Auto-Disable ShiftLock", function(state)
    forceDisableShiftLock = state
    showNotification("configChanges", state and "✅ Will disable ShiftLock" or "⚠️ Flick may fail with ShiftLock", 3)
end)
autoDisableShiftLockToggle:setState(true)

local showTracersToggle = flick_section:AddToggle("Show Tracers", function(state)
    showTracers = state
    showNotification("configChanges", state and "✅ Tracers ON" or "❌ Tracers OFF", 2)
end)
showTracersToggle:setState(false)

flick_section:AddDropdown("Rotation Method", rotationMethods, function(selected)
    rotationMethod = selected
    showNotification("configChanges", "🔄 Method: " .. selected, 2)
end)

flick_section:AddSlider("Flick Speed (ms)", 0, 500, 150, function(value)
    flickSpeed = value / 1000
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

flick_section:AddButton("Test Flick", function()
    executeFlick(true)
end)

local input_section = shared.AddSection("⌨️ Input Settings")
input_section:AddDropdown("Input Type", {"Keyboard", "Mouse"}, function(selected)
    inputType = selected
    showNotification("configChanges", "📌 Input type: " .. selected, 2)
end)

input_section:AddDropdown("Keyboard Key", keyboardKeys, function(selected)
    selectedInput = selected
    showNotification("configChanges", "⌨️ Key set to: " .. selected, 2)
end)

input_section:AddDropdown("Mouse Button", mouseButtons, function(selected)
    selectedInput = selected
    showNotification("configChanges", "🖱️ Mouse button: " .. selected, 2)
end)

local notification_section = shared.AddSection("🔔 Notification Settings")
local flickSuccessToggle = notification_section:AddToggle("Flick Success", function(s) notificationSettings.flickSuccess = s end)
flickSuccessToggle:setState(true)
local targetNotFoundToggle = notification_section:AddToggle("Target Not Found", function(s) notificationSettings.targetNotFound = s end)
targetNotFoundToggle:setState(true)
local targetTooFarToggle = notification_section:AddToggle("Target Too Far", function(s) notificationSettings.targetTooFar = s end)
targetTooFarToggle:setState(true)
local gunNotFoundToggle = notification_section:AddToggle("Gun Not Found", function(s) notificationSettings.gunNotFound = s end)
gunNotFoundToggle:setState(true)
local enableDisableToggle = notification_section:AddToggle("Enable/Disable Flick", function(s) notificationSettings.flickEnabled = s; notificationSettings.flickDisabled = s end)
enableDisableToggle:setState(true)
local mobileRestoreToggle = notification_section:AddToggle("Mobile Restore Msg", function(s) notificationSettings.mobileRestore = s end)
mobileRestoreToggle:setState(true)
local configChangesToggle = notification_section:AddToggle("Config Changes", function(s) notificationSettings.configChanges = s end)
configChangesToggle:setState(false)

local function handleInput(input, gameProcessed)
    if gameProcessed or isFlicking or not flickEnabled then return end

    if inputType == "Keyboard" then
        if input.KeyCode.Name == selectedInput then
            executeFlick(false)
        end
    elseif inputType == "Mouse" then
        local mouseMap = {
            ["Left Click"] = Enum.UserInputType.MouseButton1, ["Right Click"] = Enum.UserInputType.MouseButton2,
            ["Middle Click"] = Enum.UserInputType.MouseButton3, ["Mouse4"] = Enum.UserInputType.MouseButton4,
            ["Mouse5"] = Enum.UserInputType.MouseButton5
        }
        if input.UserInputType == mouseMap[selectedInput] then
            executeFlick(false)
        end
    end
end

UserInputService.InputBegan:Connect(handleInput)

flick_section:AddToggle("Mobile Button", function(state)
    if mobileButton then mobileButton:Destroy() mobileButton = nil end
    if state then
        local gui = Instance.new("ScreenGui", LocalPlayer:WaitForChild("PlayerGui"))
        gui.Name = "FlickMobileGUI"
        gui.ResetOnSpawn = false
        
        local button = Instance.new("TextButton", gui)
        button.Name = "FlickButton"
        button.Text = "🎯"
        button.Font = Enum.Font.SourceSansBold
        button.TextScaled = true
        button.TextColor3 = Color3.new(1, 1, 1)
        button.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
        button.Size = UDim2.new(0, 60, 0, 60)
        button.Position = UDim2.new(0.85, 0, 0.5, 0)
        button.Draggable = true
        
        local corner = Instance.new("UICorner", button)
        corner.CornerRadius = UDim.new(0.5, 0)
        
        button.MouseButton1Click:Connect(function()
            executeFlick(false)
        end)
        
        mobileButton = gui
        showNotification("configChanges", "📱 Mobile button created", 2)
    end
end)

return function()
    if mobileButton then mobileButton:Destroy() end
    if tracer then tracer:Destroy() end
    if rotationConnection then rotationConnection:Disconnect() end
    restoreCharacterState()
end

