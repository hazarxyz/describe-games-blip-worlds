Config = {
    Items = {
        "voxels.cube",
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
    return shape
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

local function refreshUi()
    if scoreText == nil then
        return
    end
    local parts = {}
    for _, resource in ipairs(resourceNames) do
        table.insert(parts, resource .. ": " .. tostring(inventory[resource] or 0))
    end
    scoreText.Text = "Blip mining farming Draft" .. " | " .. table.concat(parts, " | ") .. " | Action mines nearby nodes"
end

local function spawnResource(resource, index, position, color)
    local node = makeBox("resource_" .. resource .. "_" .. tostring(index), color, -1, 1, 0, 2, -1, 1, position)
    resourceTypes[node] = resource
    resourceAmounts[node] = 3
    table.insert(resourceNodes, node)
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
    if Player.Motion ~= nil then
        Player.Motion:Set(Number3.Zero)
    end
end

Client.OnStart = function()
    resetInventory()
    makeBox("wide_grass_floor", Color(70, 175, 105), -34, 34, 0, 0, -24, 24, { 0, 0, 0 })
    makeBox("north_ridge", Color(90, 110, 130), -18, 18, 1, 4, -28, -25, { 0, 0, 0 })
    makeBox("west_hill", Color(80, 130, 90), -38, -35, 1, 5, -12, 14, { 0, 0, 0 })
    marketShape = makeBox("glowing_market_goal", Color(255, 220, 80), -3, 3, 0, 1, -3, 3, { 24, 1, 16 })

    spawnResource("crystal", 1, { -12, 2, -8 }, Color(110, 230, 255))
    spawnResource("crystal", 2, { 8, 2, -14 }, Color(110, 230, 255))
    spawnResource("stone", 1, { -20, 2, 12 }, Color(130, 130, 145))
    spawnResource("gold", 1, { 16, 2, 6 }, Color(245, 190, 55))

    -- Blip genre module: exploration landmark
    explorationLandmarkShape = makeBox("exploration_landmark_goal", Color(255, 220, 80), -3, 3, 0, 5, -3, 3, { 22, 3, 12 })


    local ui = require("uikit")
    scoreText = ui:createText("Blip mining farming Draft", Color.White)
    scoreText.parentDidResize = function(self)
        self.pos = { 22, Screen.Height - self.Height - 22 }
    end
    scoreText:parentDidResize()
    refreshUi()

    resetPlayer()
    equippedTool = createEquippedTool()
    Player:EquipRightHand(equippedTool)
    ccc:set({
        target = Player,
        targetSpeed = 52,
        cameraDistance = 40,
        cameraMinDistance = 18,
        cameraMaxDistance = 72,
        cameraRigidity = 0.45,
        cameraRotationSensitivity = 1.0,
        rotatePlayerWithCamera = false,
        faceMotionDirection = true,
    })
end

Client.Action1 = function()
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

    if nearest ~= nil and nearestDistance < 8 then
        resourceAmounts[nearest] = (resourceAmounts[nearest] or 0) - 1
        local resource = resourceTypes[nearest] or "resource"
        inventory[resource] = (inventory[resource] or 0) + 1
        if resourceAmounts[nearest] <= 0 then
            nearest.IsHidden = true
        end
        refreshUi()
    elseif Player.IsOnGround then
        Player.Velocity.Y = 72
    end
end

Pointer.Down = function()
    Client.Action1()
end

Client.Tick = function()
    if Player.Position.Y < -40 then
        resetPlayer()
    end

    if marketShape ~= nil then
        local delta = Player.Position - marketShape.Position
        if delta.Length < 8 and inventoryTotal() >= 5 then
            if scoreText ~= nil then
                scoreText.Text = "Goal reached. Ask chat to expand this mining farming world."
            end
        end
    end

end

Server.OnPlayerJoin = function(player)
    print("Blip multiplayer-ready join: " .. player.Username)
end
