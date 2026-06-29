Config = {
    Items = {
        "voxels.cube",
        "voxels.apple_tree",
        "voxels.grasspatch_1",
        "voxels.grasspatch_2",
        "voxels.grasspatch_3",
        "voxels.seed_mound",
        "voxels.stone_1",
        "voxels.stone_2",
        "voxels.stone_3",
        "voxels.stone_4",
        "voxels.hay_bail_1",
        "voxels.rustic_fence_1",
        "voxels.white_fence",
        "voxels.windmill",
        "voxels.water_fountain",
        "voxels.toolbox",
        "voxels.hammer",
        "aduermael.coin",
        "pratamacam.turnip",
        "uevoxel.carrot_1",
    },
}

local resourceNames = { "crystal", "stone", "gold" }
local resourceNodes = {}
local resourceAmounts = {}
local resourceTypes = {}
local inventory = {}
local scoreText = nil
local marketShape = nil
local equippedTool = nil
local ccc = require("ccc")
local controls = require("controls")
local inputCodes = require("inputcodes")
local controlsText = nil
local objectiveText = nil
local worldControlsLabel = nil
local worldObjectiveLabel = nil
	local hudLabel = nil
	local hudControlsLabel = nil
	local worldRulesLabel = nil
	local moveKeyState = { forward = false, back = false, left = false, right = false }
	local browserKeyCodes = { W = 87, A = 65, S = 83, D = 68, E = 69, SPACE = 32, UP = 38, DOWN = 40, LEFT = 37, RIGHT = 39 }
local moveInputX = 0
local moveInputY = 0
local desktopMovementActive = false
local actionKeyDown = false
local jumpKeyDown = false
local keyboardListener = nil
local pointerDragListener = nil
local coins = 0
local minedTotal = 0
local cameraYaw = 0
local cameraPitch = 0.18
	local lastControl = "ready"
	local worldHalfX = 96
	local worldHalfZ = 72
	local blipPhysicsMovementSpeed = 44
	local blipPhysicsJumpPower = 72
	local blipPhysicsMiningReach = 8
	local blipPhysicsCameraDistance = 46
	local blipRuleSaleThreshold = 5
	local blipRuleCoinMultiplier = 3
	local blipRuleWinCondition = "build_and_sell_resources"
	local blipEffectLighting = "neon"
	local blipActionEffects = { "tool_swing", "resource_pop", "market_burst", "coin_ping", "crystal_glow" }
	local blipCodeMechanicTags = { "resource_loop", "market_sale", "hud_feedback", "social_join_scaffold", "pickaxe_action", "resource_respawn", "camera_follow", "speed_tuning" }
	local blipRuntimeHooks = { "Client.OnStart", "Client.Tick", "Client.Action1", "Client.Action2" }
	local blipCodeSafety = "structured_no_raw_lua"
	local blipCodeSourceSummary = "Structured mechanic tags compile into allowlisted Blip runtime hooks for spawning, camera follow, pickaxe mining, resource inventory, market sale feedback, and multiplayer join sca"
	local feedbackEffects = {}
	local feedbackEffectCounter = 0
	local blipNightWorld = false
	local worldCodeContractLabel = nil
	local airJumpsRemaining = 0

local explorationLandmarkShape = nil


local function makeBox(name, color, minX, maxX, minY, maxY, minZ, maxZ, position)
    local mutable = MutableShape()
    local colorIndex = mutable.Palette:AddColor(color)

    for x = minX, maxX do
        for y = minY, maxY do
            for z = minZ, maxZ do
                mutable:AddBlock(colorIndex, x, y, z)
            end
        end
    end

    local shape = Shape(mutable)
    shape.Name = name
    shape:SetParent(World)
    shape.Position = position
    pcall(function()
        if string.find(name, "sky") or string.find(name, "moon") then
            shape.IsUnlit = true
        end
    end)
    return shape
end

local function makeWorldText(name, text, color, position, scale)
    local ok, label = pcall(function()
        local item = Text()
        item.Name = name
        item.Type = TextType.World
        item.Text = text
        item.Color = color
        item.BackgroundColor = Color(0, 0, 0, 175)
        item.IsUnlit = true
        item.Padding = 6
        item.MaxDistance = 250
        item.Scale = scale
        item:SetParent(World)
        item.Position = position
        return item
    end)
    if ok then
        return label
    end
    return nil
end

local function spawnBundledShape(name, bundleName, position, scale)
    local ok, shape = pcall(function()
        local loaded = System.ShapeFromBundle(bundleName)
        loaded.Name = name
        loaded:SetParent(World)
        loaded.Position = position
        if scale ~= nil then
            pcall(function()
                loaded.Scale = scale
            end)
        end
        pcall(function()
            loaded.Physics = PhysicsMode.Disabled
        end)
        return loaded
    end)
    if ok then
        return shape
    end
    return nil
end

	local function makeBundledProp(name, bundleName, position, fallbackColor)
	    local shape = spawnBundledShape(name, bundleName, position, 1)
	    if shape ~= nil then
	        return shape
	    end
	    return makeBox(name, fallbackColor, -1, 1, 0, 2, -1, 1, position)
	end

	local function createFeedbackEffect(name, position, color)
	    if position == nil then
	        return
	    end
	    feedbackEffectCounter = feedbackEffectCounter + 1
	    local x = position.X or position[1] or 0
	    local y = position.Y or position[2] or 1
	    local z = position.Z or position[3] or 0
	    local burst = makeBox("feedback_effect_" .. name .. "_" .. tostring(feedbackEffectCounter), color, -1, 1, 0, 1, -1, 1, { x, y + 4, z })
	    table.insert(feedbackEffects, burst)
	    if #feedbackEffects > 14 then
	        local old = table.remove(feedbackEffects, 1)
	        if old ~= nil then
	            old.IsHidden = true
	        end
	    end
	end

	local function applyWorldMood()
	    if blipEffectLighting == "day" and not blipNightWorld then
	        return
	    end
	    pcall(function()
	        if blipEffectLighting == "neon" then
	            Sky.SkyColor = Color(12, 8, 34)
	            Sky.HorizonColor = Color(35, 18, 70)
	            Sky.AbyssColor = Color(4, 2, 18)
	            Sky.LightColor = Color(120, 255, 230)
	        elseif blipEffectLighting == "storm" then
	            Sky.SkyColor = Color(34, 40, 52)
	            Sky.HorizonColor = Color(52, 58, 70)
	            Sky.AbyssColor = Color(16, 20, 28)
	            Sky.LightColor = Color(130, 145, 160)
	        else
	            Sky.SkyColor = Color(5, 9, 28)
	            Sky.HorizonColor = Color(18, 28, 62)
	            Sky.AbyssColor = Color(2, 4, 12)
	            Sky.LightColor = Color(80, 110, 175)
	        end
	    end)
	    pcall(function()
	        if blipEffectLighting == "neon" then
	            Ambient.Color = Color(36, 18, 82)
	            Ambient.SkyLightFactor = 0.58
	            Ambient.DirectionalLightFactor = 0.28
	            Ambient.Intensity = 0.8
	        elseif blipEffectLighting == "storm" then
	            Ambient.Color = Color(54, 58, 68)
	            Ambient.SkyLightFactor = 0.48
	            Ambient.DirectionalLightFactor = 0.18
	            Ambient.Intensity = 0.62
	        else
	            Ambient.Color = Color(28, 34, 68)
	            Ambient.SkyLightFactor = 0.4
	            Ambient.DirectionalLightFactor = 0.22
	            Ambient.Intensity = 0.65
	        end
	    end)
	    pcall(function()
	        Fog.On = true
	        Fog.Color = blipEffectLighting == "storm" and Color(45, 48, 58) or Color(6, 10, 30)
	        Fog.Near = 90
	        Fog.Far = 220
	        Fog.LightAbsorption = 0.35
    end)
end

local function createNightSkySet()
    if not blipNightWorld then
        return
    end
    makeBox("night_sky_north", Color(5, 9, 30), -worldHalfX, worldHalfX, 0, 44, -1, -1, { 0, 16, worldHalfZ + 18 })
    makeBox("night_sky_south", Color(4, 8, 26), -worldHalfX, worldHalfX, 0, 44, -1, -1, { 0, 16, -worldHalfZ - 18 })
    makeBox("night_sky_east", Color(4, 8, 28), -1, -1, 0, 44, -worldHalfZ, worldHalfZ, { worldHalfX + 18, 16, 0 })
    makeBox("night_sky_west", Color(4, 8, 28), -1, -1, 0, 44, -worldHalfZ, worldHalfZ, { -worldHalfX - 18, 16, 0 })
	    makeBox("moon_disc", Color(220, 230, 255), -4, 4, -4, 4, -1, -1, { -30, 46, worldHalfZ + 16 })
	end

	local function createWorldEffects()
	    if blipEffectLighting == "neon" then
	        makeBox("neon_effect_beacon_market", Color(80, 255, 220), -1, 1, 0, 18, -1, 1, { 58, 3, 44 })
	        makeBox("neon_effect_beacon_spawn", Color(210, 90, 255), -1, 1, 0, 14, -1, 1, { 0, 3, 0 })
	    elseif blipEffectLighting == "storm" then
	        makeBox("storm_effect_cloud_band", Color(60, 68, 82), -worldHalfX, worldHalfX, 0, 2, -2, 2, { 0, 42, -worldHalfZ - 8 })
	        makeBox("storm_effect_lightning_marker", Color(190, 220, 255), -1, 1, 0, 16, -1, 1, { -24, 8, -34 })
	    end
	end

local function resetInventory()
    for _, resource in ipairs(resourceNames) do
        inventory[resource] = 0
    end
end

local function inventoryTotal()
    local total = 0
    for _, resource in ipairs(resourceNames) do
        total = total + (inventory[resource] or 0)
    end
    return total
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue
    end
    if value > maxValue then
        return maxValue
    end
    return value
end

	local function hasCodeMechanic(tag)
	    for _, mechanicTag in ipairs(blipCodeMechanicTags) do
	        if mechanicTag == tag then
	            return true
	        end
	    end
	    return false
	end

local function debugControl(message)
    pcall(function()
        print("[describe-blip-control] " .. tostring(message))
    end)
end

local function refreshHudPositions()
    local topOffset = 22
    if objectiveText ~= nil then
        objectiveText.pos = { 22, Screen.Height - topOffset - objectiveText.Height }
        topOffset = topOffset + objectiveText.Height + 10
    end
    if scoreText ~= nil then
        scoreText.pos = { 22, Screen.Height - topOffset - scoreText.Height }
    end
    if controlsText ~= nil then
        controlsText.pos = { 22, 22 }
    end
end

local function styleHudText(node)
    if node == nil or node.object == nil then
        return
    end
    pcall(function()
        node.object.BackgroundColor = Color(0, 0, 0, 180)
        node.object.Padding = 8
        node.object.MaxDistance = 9999
        node.object.IsUnlit = true
        node.object.Scale = 0.42
    end)
end

local function refreshUi()
    if scoreText == nil then
        return
    end
    local parts = {}
    for _, resource in ipairs(resourceNames) do
        table.insert(parts, resource .. ": " .. tostring(inventory[resource] or 0))
    end
    local hudText = "Blip mining farming Draft" .. " | Coins: " .. tostring(coins) .. " | Mined: " .. tostring(minedTotal) .. " | " .. table.concat(parts, " | ") .. " | " .. lastControl
    scoreText.Text = hudText
    pcall(function()
        print("[describe-blip-hud] " .. hudText)
    end)
    if hudLabel ~= nil then
        pcall(function()
            hudLabel.Text = hudText
        end)
    end
    if hudControlsLabel ~= nil then
        pcall(function()
            hudControlsLabel.Text = "WASD/Arrows move | drag to look | Click/E mine | Space jump"
        end)
    end
    refreshHudPositions()
end

local function spawnResource(resource, index, position, color)
    local node = makeBox("resource_" .. resource .. "_" .. tostring(index), color, -1, 1, 0, 2, -1, 1, position)
    resourceTypes[node] = resource
    resourceAmounts[node] = 4
    table.insert(resourceNodes, node)
end

local function createLandscape()
    makeBox("wide_grass_floor", Color(70, 175, 105), -96, 96, 0, 0, -72, 72, { 0, 0, 0 })
    makeBox("market_path_main", Color(132, 92, 54), -4, 4, 0, 0, -64, 62, { 0, 1, 0 })
    makeBox("market_path_cross", Color(132, 92, 54), -76, 76, 0, 0, -3, 3, { 0, 1, 0 })
    makeBox("north_ridge", Color(90, 110, 130), -56, 56, 1, 6, -76, -70, { 0, 0, 0 })
    makeBox("south_meadow_ridge", Color(80, 130, 90), -54, 54, 1, 4, 70, 76, { 0, 0, 0 })
    makeBox("west_hill", Color(80, 130, 90), -100, -94, 1, 7, -38, 42, { 0, 0, 0 })
    makeBox("east_hill", Color(80, 130, 90), 94, 100, 1, 7, -42, 38, { 0, 0, 0 })
    makeBox("farm_plot_wheat", Color(106, 72, 44), -12, 12, 0, 0, -8, 8, { -32, 1, 18 })
    makeBox("farm_plot_carrot", Color(106, 72, 44), -10, 10, 0, 0, -7, 7, { -56, 1, 30 })
    makeBox("farm_plot_crystal_crop", Color(80, 96, 132), -9, 9, 0, 0, -7, 7, { 30, 1, -24 })
    makeBox("pond_water", Color(54, 130, 220), -14, 14, 0, 0, -7, 7, { 54, 1, -46 })
    makeBox("wood_bridge", Color(140, 86, 45), -4, 4, 0, 1, -10, 10, { 54, 2, -46 })

    local treePositions = {
        { -78, 1, -44 }, { -66, 1, -54 }, { -72, 1, 44 }, { -44, 1, 56 },
        { 48, 1, 52 }, { 70, 1, 38 }, { 82, 1, -18 }, { 68, 1, -58 },
        { -84, 1, 12 }, { 34, 1, 58 },
    }
    for i, pos in ipairs(treePositions) do
        makeBundledProp("landscape_tree_" .. tostring(i), "voxels.apple_tree", pos, Color(40, 145, 70))
    end

    local propLayout = {
        { "hay_bail_1", "voxels.hay_bail_1", { -24, 1, 34 }, Color(225, 180, 70) },
        { "hay_bail_2", "voxels.hay_bail_1", { -18, 1, 38 }, Color(225, 180, 70) },
        { "farm_toolbox", "voxels.toolbox", { -12, 1, 16 }, Color(190, 70, 55) },
        { "water_fountain", "voxels.water_fountain", { 14, 1, 44 }, Color(90, 150, 220) },
        { "windmill_landmark", "voxels.windmill", { -62, 1, 50 }, Color(210, 210, 190) },
        { "market_coin_icon", "aduermael.coin", { 61, 3, 44 }, Color(255, 220, 80) },
    }
    for i, entry in ipairs(propLayout) do
        makeBundledProp("official_prop_" .. entry[1] .. "_" .. tostring(i), entry[2], entry[3], entry[4])
    end

    for i = 1, 8 do
        local x = -42 + i * 4
        makeBundledProp("crop_turnip_" .. tostring(i), "pratamacam.turnip", { x, 2, 18 }, Color(170, 225, 80))
        makeBundledProp("crop_carrot_" .. tostring(i), "uevoxel.carrot_1", { x - 24, 2, 30 }, Color(240, 120, 45))
        makeBundledProp("grass_patch_" .. tostring(i), "voxels.grasspatch_" .. tostring(((i - 1) % 3) + 1), { -82 + i * 18, 1, -54 + (i % 3) * 24 }, Color(45, 150, 75))
    end
end

local function createResourceField()
    local resourceLayout = {
        { "crystal", { -10, 2, -8 }, Color(110, 230, 255) },
        { "crystal", { 8, 2, -10 }, Color(110, 230, 255) },
        { "stone", { -16, 2, 8 }, Color(130, 130, 145) },
        { "gold", { 18, 2, 8 }, Color(245, 190, 55) },
        { "crystal", { 30, 2, -30 }, Color(110, 230, 255) },
        { "crystal", { -42, 2, -28 }, Color(110, 230, 255) },
        { "stone", { 48, 2, 20 }, Color(130, 130, 145) },
        { "stone", { -58, 2, 6 }, Color(130, 130, 145) },
        { "gold", { 58, 2, -10 }, Color(245, 190, 55) },
        { "gold", { -64, 2, 42 }, Color(245, 190, 55) },
    }
    for i, entry in ipairs(resourceLayout) do
        spawnResource(entry[1], i, entry[2], entry[3])
        if entry[1] == "stone" then
            makeBundledProp("official_stone_cluster_" .. tostring(i), "voxels.stone_" .. tostring(((i - 1) % 4) + 1), { entry[2][1] + 3, 1, entry[2][3] + 2 }, Color(130, 130, 145))
        end
    end
end

local function createEquippedTool()
    local mutable = MutableShape()
    local handle = mutable.Palette:AddColor(Color(120, 76, 42))
    local metal = mutable.Palette:AddColor(Color(180, 205, 220))

    for y = -4, 4 do
        mutable:AddBlock(handle, 0, y, 0)
    end
    for x = -3, 3 do
        mutable:AddBlock(metal, x, 4, 0)
    end
    mutable:AddBlock(metal, -2, 3, 0)
    mutable:AddBlock(metal, 2, 3, 0)
    mutable:AddPoint("ModelPoint_Hand_v2", { 0, -2, 0 })

    local tool = Shape(mutable)
    tool.Name = "equipped_right_hand_pickaxe"
    tool:SetParent(World)
    return tool
end

local function distanceToPlayer(shape)
    local delta = Player.Position - shape.Position
    return delta.Length
end

local function resetPlayer()
    Player:SetParent(World)
    Player.Position = { 0, 14, 0 }
    Player.Velocity = { 0, 0, 0 }
    Player.Motion = Number3.Zero
    airJumpsRemaining = hasCodeMechanic("double_jump") and 1 or 0
end

	local function configureController()
	    ccc:set({
	        target = Player,
	        targetSpeed = 55,
	        showPointer = true,
	        cameraDistance = blipPhysicsCameraDistance,
	        cameraMinDistance = 18,
	        cameraMaxDistance = 88,
        cameraRotation = { cameraPitch, cameraYaw, 0 },
        cameraRigidity = 0.35,
        cameraRotationSensitivity = 0.65,
        rotatePlayerWithCamera = false,
        faceMotionDirection = true,
        targetAlignYawWithCameraWhenMotionIsSet = true,
    })
end

local function refreshMoveFromKeys()
    local x = 0
    local y = 0
    if moveKeyState.right then
        x = x + 1
    end
    if moveKeyState.left then
        x = x - 1
    end
    if moveKeyState.forward then
        y = y + 1
    end
    if moveKeyState.back then
        y = y - 1
    end
    Client.DirectionalPad(x, y)
end

local function applyDesktopMovement(dt)
    local x = moveInputX or 0
    local y = moveInputY or 0
    if x == 0 and y == 0 then
        if desktopMovementActive then
            Player.Motion = Number3.Zero
            desktopMovementActive = false
            debugControl("DesktopMove stop")
        end
        return
    end

    local length = math.sqrt(x * x + y * y)
    if length <= 0 then
        return
    end

    local nx = x / length
    local ny = y / length
    local frameTime = clamp(dt or 0.016, 0.001, 0.05)
	    local speed = blipPhysicsMovementSpeed
    local forwardX = math.sin(cameraYaw)
    local forwardZ = math.cos(cameraYaw)
    local rightX = math.cos(cameraYaw)
    local rightZ = -math.sin(cameraYaw)
    local dx = (rightX * nx + forwardX * ny)
    local dz = (rightZ * nx + forwardZ * ny)
    local nextPosition = Player.Position + Number3(dx * speed * frameTime, 0, dz * speed * frameTime)

    Player.Rotation:Set(0, math.atan(dx, dz), 0)
    Player.Motion = Number3(dx * speed, 0, dz * speed)
    Player.Position = {
        clamp(nextPosition.X, -worldHalfX + 4, worldHalfX - 4),
        nextPosition.Y,
        clamp(nextPosition.Z, -worldHalfZ + 4, worldHalfZ - 4),
    }
    if not desktopMovementActive then
        desktopMovementActive = true
        debugControl("DesktopMove start " .. tostring(x) .. "," .. tostring(y))
    end
end

local function applyPointerCameraDrag(pe)
    local dx = pe and pe.DX or 0
    local dy = pe and pe.DY or 0
    cameraYaw = cameraYaw + dx * 0.01
    cameraPitch = clamp(cameraPitch - dy * 0.008, -0.85, 0.45)
    debugControl("PointerDrag " .. tostring(dx) .. "," .. tostring(dy))
    refreshUi()
end

local function keyMatches(char, keyCode, engineCode, browserCode, letter)
    local value = string.lower(tostring(char or ""))
    return keyCode == engineCode or keyCode == browserCode or value == letter
end

local function handleKeyboardInput(char, keyCode, _, down)
    local isDown = down == true or down == 1
    debugControl("KeyboardInput " .. tostring(char or "") .. " " .. tostring(keyCode or "") .. " " .. tostring(isDown))
    if keyMatches(char, keyCode, inputCodes.KEY_W, browserKeyCodes.W, "w") or keyCode == inputCodes.UP or keyCode == browserKeyCodes.UP then
        moveKeyState.forward = isDown
        lastControl = isDown and "moving forward" or "ready"
        refreshMoveFromKeys()
    elseif keyMatches(char, keyCode, inputCodes.KEY_S, browserKeyCodes.S, "s") or keyCode == inputCodes.DOWN or keyCode == browserKeyCodes.DOWN then
        moveKeyState.back = isDown
        lastControl = isDown and "moving back" or "ready"
        refreshMoveFromKeys()
    elseif keyMatches(char, keyCode, inputCodes.KEY_D, browserKeyCodes.D, "d") or keyCode == inputCodes.RIGHT or keyCode == browserKeyCodes.RIGHT then
        moveKeyState.right = isDown
        lastControl = isDown and "moving right" or "ready"
        refreshMoveFromKeys()
    elseif keyMatches(char, keyCode, inputCodes.KEY_A, browserKeyCodes.A, "a") or keyCode == inputCodes.LEFT or keyCode == browserKeyCodes.LEFT then
        moveKeyState.left = isDown
        lastControl = isDown and "moving left" or "ready"
        refreshMoveFromKeys()
    elseif keyMatches(char, keyCode, inputCodes.SPACE, browserKeyCodes.SPACE, " ") then
        if isDown and not jumpKeyDown then
            Client.Action1()
        end
        jumpKeyDown = isDown
    elseif keyMatches(char, keyCode, inputCodes.KEY_E, browserKeyCodes.E, "e") then
        if isDown and not actionKeyDown then
            Client.Action2()
        end
        actionKeyDown = isDown
    end
end

Client.DirectionalPad = function(x, y)
    moveInputX = x or 0
    moveInputY = y or 0
    debugControl("DirectionalPad " .. tostring(moveInputX) .. "," .. tostring(moveInputY))
    if moveInputX ~= 0 or moveInputY ~= 0 then
        lastControl = "moving"
    else
        lastControl = "ready"
    end
    refreshUi()
end

local function releaseAllInputs()
    moveKeyState = { forward = false, back = false, left = false, right = false }
    moveInputX = 0
    moveInputY = 0
    desktopMovementActive = false
    actionKeyDown = false
    jumpKeyDown = false
    Player.Motion = Number3.Zero
    Client.DirectionalPad(0, 0)
    debugControl("ReleaseAllInputs")
end

Pointer.Drag = function(pe)
    applyPointerCameraDrag(pe)
end

Client.OnStart = function()
    debugControl("OnStart")
    resetInventory()
    applyWorldMood()
	    createNightSkySet()
	    createLandscape()
	    createWorldEffects()
	    marketShape = makeBox("glowing_market_goal", Color(255, 220, 80), -4, 4, 0, 1, -4, 4, { 58, 1, 44 })
	    worldObjectiveLabel = makeWorldText("world_objective_label", "Goal: Mine resources with the pickaxe fill the inventory to the sale threshold and reach the g", Color(255, 235, 120), { 8, 5, 52 }, 0.08)
	    worldControlsLabel = makeWorldText("world_controls_label", "WASD/Arrows move | drag to look | Click/E mine | Space jump", Color(175, 255, 220), { 8, 4, 52 }, 0.075)
	    worldRulesLabel = makeWorldText("world_rules_label", "Rules: build and sell resources | sell 5+ for 3x coins", Color(150, 220, 255), { 8, 3, 52 }, 0.07)
	    worldCodeContractLabel = makeWorldText("world_code_contract_label", "Code: structured no raw lua | resource loop market sale hud feedback social join scaffold pickaxe acti", Color(190, 180, 255), { 8, 2, 52 }, 0.065)

    createResourceField()

    -- Blip genre module: exploration landmark
    explorationLandmarkShape = makeBox("exploration_landmark_goal", Color(255, 220, 80), -3, 3, 0, 5, -3, 3, { 22, 3, 12 })


    local ui = require("uikit")
    objectiveText = ui:createText("Goal: Mine resources with the pickaxe fill the inventory to the sale threshold and reach the g", Color(255, 235, 120), "small")
    scoreText = ui:createText("Blip mining farming Draft", Color.White, "small")
    controlsText = ui:createText("WASD/Arrows move | drag to look | Click/E mine | Space jump", Color(175, 255, 220), "small")
    pcall(function()
        hudLabel = UI.Label("Blip mining farming Draft", Anchor.HCenter, Anchor.Top)
        hudLabel.TextColor = Color(255, 255, 255)
    end)
    pcall(function()
        if hudLabel ~= nil then
            hudLabel:Add(Anchor.HCenter, Anchor.Top)
        end
    end)
    pcall(function()
        hudControlsLabel = UI.Label("WASD/Arrows move | drag to look | Click/E mine | Space jump", Anchor.HCenter, Anchor.Bottom)
        hudControlsLabel.TextColor = Color(175, 255, 220)
    end)
    pcall(function()
        if hudControlsLabel ~= nil then
            hudControlsLabel:Add(Anchor.HCenter, Anchor.Bottom)
        end
    end)
    styleHudText(objectiveText)
    styleHudText(scoreText)
    styleHudText(controlsText)
    objectiveText.parentDidResize = refreshHudPositions
    scoreText.parentDidResize = refreshHudPositions
    controlsText.parentDidResize = refreshHudPositions
    refreshHudPositions()
    refreshUi()

    resetPlayer()
    moveKeyState = { forward = false, back = false, left = false, right = false }
    moveInputX = 0
    moveInputY = 0
    desktopMovementActive = false
    actionKeyDown = false
    jumpKeyDown = false
    pcall(function()
        releaseAllInputs()
    end)
    if pointerDragListener ~= nil then
        pcall(function()
            pointerDragListener:Remove()
        end)
    end
    equippedTool = createEquippedTool()
    Player:EquipRightHand(equippedTool)
    pcall(function()
        Pointer:Show()
        UI.Crosshair = false
    end)
    keyboardListener = LocalEvent:Listen(LocalEvent.Name.KeyboardInput, handleKeyboardInput, { system = System, topPriority = true })
    pointerDragListener = LocalEvent:Listen(LocalEvent.Name.PointerDrag, function(pe)
        applyPointerCameraDrag(pe)
    end, { system = System, topPriority = true })
    configureController()
end

local function performJumpAction()
    if Player.IsOnGround then
	        lastControl = "jumping"
	        refreshUi()
	        createFeedbackEffect("jump_ring", Player.Position, Color(160, 220, 255))
	        airJumpsRemaining = hasCodeMechanic("double_jump") and 1 or 0
	        Player.Velocity.Y = blipPhysicsJumpPower
	    elseif hasCodeMechanic("double_jump") and airJumpsRemaining > 0 then
	        airJumpsRemaining = airJumpsRemaining - 1
	        lastControl = "double jump"
	        refreshUi()
	        createFeedbackEffect("double_jump_ring", Player.Position, Color(190, 180, 255))
	        Player.Velocity.Y = blipPhysicsJumpPower
	    end
	end

local function performMineAction()
    lastControl = "Action mines nearby nodes"
    debugControl("MineAction")
    Player:SwingRight()

    local nearest = nil
    local nearestDistance = 9999
    for _, node in ipairs(resourceNodes) do
        if (resourceAmounts[node] or 0) > 0 then
            local d = distanceToPlayer(node)
            if d < nearestDistance then
                nearest = node
                nearestDistance = d
            end
        end
    end

	    if nearest ~= nil and nearestDistance < blipPhysicsMiningReach then
	        resourceAmounts[nearest] = (resourceAmounts[nearest] or 0) - 1
	        local resource = resourceTypes[nearest] or "resource"
	        inventory[resource] = (inventory[resource] or 0) + 1
	        minedTotal = minedTotal + 1
	        createFeedbackEffect("resource_pop_" .. resource, nearest.Position, Color(110, 230, 255))
	        if resourceAmounts[nearest] <= 0 then
	            nearest.IsHidden = true
        end
        refreshUi()
    else
        lastControl = "no resource in reach"
        refreshUi()
    end
end

Client.Action1 = function()
    debugControl("Action1Jump")
    performJumpAction()
end

Client.Action2 = function()
    performMineAction()
end

Client.Action3 = function()
    performJumpAction()
end

Pointer.Click = function()
    performMineAction()
end

Client.Action1Release = function()
    lastControl = "ready"
    refreshUi()
end

Client.Tick = function(dt)
    applyDesktopMovement(dt)

    if Player.IsOnGround and hasCodeMechanic("double_jump") then
        airJumpsRemaining = 1
    end

    if Player.Position.Y < -40 then
        resetPlayer()
    end

	    if marketShape ~= nil then
	        local delta = Player.Position - marketShape.Position
	        if delta.Length < 8 and inventoryTotal() >= blipRuleSaleThreshold then
	            local sold = inventoryTotal()
	            coins = coins + sold * blipRuleCoinMultiplier
	            resetInventory()
	            lastControl = "sold harvest for coins"
	            createFeedbackEffect("market_burst", marketShape.Position, Color(255, 220, 80))
	            refreshUi()
            if scoreText ~= nil then
                scoreText.Text = "Market sold " .. tostring(sold) .. " resources. Coins: " .. tostring(coins) .. ". Ask chat to expand this mining farming world."
            end
        end
    end

end

Server.OnPlayerJoin = function(player)
    print("Blip multiplayer-ready join: " .. player.Username)
end
