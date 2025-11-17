-- Dungeon instance helper library

DUNGEON_INSTANCE_REGION = DUNGEON_INSTANCE_REGION or {
    from = Position(1000, 1000, 7),
    to = Position(1199, 1199, 7)
}

DUNGEON_INSTANCE_CONFIG = DUNGEON_INSTANCE_CONFIG or {
    width = 50,
    height = 50,
    maxInstances = 12,
    wallItemId = 1045,
    floorItemId = 352,
    defaultFloorCoverage = 0.35,
    defaultMonsterCount = 10,
    defaultMonsters = {"Rat", "Cave Rat"}
}

DungeonInstances = DungeonInstances or {}
DungeonInstances.instances = DungeonInstances.instances or {}

local function getSlotsPerRow()
    local width = DUNGEON_INSTANCE_CONFIG.width
    if width <= 0 then
        return 0
    end

    return math.floor((DUNGEON_INSTANCE_REGION.to.x - DUNGEON_INSTANCE_REGION.from.x + 1) / width)
end

local function getSlotsPerColumn()
    local height = DUNGEON_INSTANCE_CONFIG.height
    if height <= 0 then
        return 0
    end

    return math.floor((DUNGEON_INSTANCE_REGION.to.y - DUNGEON_INSTANCE_REGION.from.y + 1) / height)
end

local function getInstanceOrigin(id)
    local slotsPerRow = getSlotsPerRow()
    local slotsPerColumn = getSlotsPerColumn()

    if slotsPerRow <= 0 or slotsPerColumn <= 0 then
        return nil
    end

    local row = math.floor((id - 1) / slotsPerRow)
    if row >= slotsPerColumn then
        return nil
    end

    local column = (id - 1) % slotsPerRow
    local x = DUNGEON_INSTANCE_REGION.from.x + (column * DUNGEON_INSTANCE_CONFIG.width)
    local y = DUNGEON_INSTANCE_REGION.from.y + (row * DUNGEON_INSTANCE_CONFIG.height)

    return Position(x, y, DUNGEON_INSTANCE_REGION.from.z)
end

local function clearInstanceArea(origin, width, height)
    for yy = 0, height - 1 do
        for xx = 0, width - 1 do
            local pos = Position(origin.x + xx, origin.y + yy, origin.z)
            local tile = Tile(pos)
            if tile then
                local items = tile:getItems()
                if items then
                    for _, item in ipairs(items) do
                        if not item:isGround() then
                            item:remove()
                        end
                    end
                end
            end
        end
    end
end

function DungeonInstances.allocateSlot()
    local totalSlots = math.min(DUNGEON_INSTANCE_CONFIG.maxInstances, getSlotsPerRow() * getSlotsPerColumn())
    if totalSlots <= 0 then
        return nil, nil
    end

    for id = 1, totalSlots do
        if not DungeonInstances.instances[id] then
            local origin = getInstanceOrigin(id)
            if origin then
                return id, origin
            end
        end
    end

    return nil, nil
end

function DungeonInstances.generateRandomLayout(width, height, floorTarget)
    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = 1
        end
    end

    local x = math.floor(width / 2)
    local y = math.floor(height / 2)
    grid[y][x] = 0

    local floorCount = 1
    local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
    local maxSteps = width * height * 10

    for _ = 1, maxSteps do
        local direction = dirs[math.random(#dirs)]
        x = x + direction[1]
        y = y + direction[2]

        if x < 2 then
            x = 2
        elseif x > width - 1 then
            x = width - 1
        end

        if y < 2 then
            y = 2
        elseif y > height - 1 then
            y = height - 1
        end

        if grid[y][x] == 1 then
            grid[y][x] = 0
            floorCount = floorCount + 1
        end

        if floorCount >= floorTarget then
            break
        end
    end

    return grid
end

local function applyLayout(origin, grid)
    local height = #grid
    if height == 0 then
        return
    end

    local width = #grid[1]
    clearInstanceArea(origin, width, height)

    for y = 1, height do
        for x = 1, width do
            local pos = Position(origin.x + (x - 1), origin.y + (y - 1), origin.z)
            if grid[y][x] == 1 then
                Game.createItem(DUNGEON_INSTANCE_CONFIG.wallItemId, 1, pos)
            elseif DUNGEON_INSTANCE_CONFIG.floorItemId then
                Game.createItem(DUNGEON_INSTANCE_CONFIG.floorItemId, 1, pos)
            end
        end
    end
end

local function spawnMonsters(origin, grid, monsterNames, maxSpawns)
    local floorTiles = {}
    for y = 1, #grid do
        for x = 1, #grid[y] do
            if grid[y][x] == 0 then
                table.insert(floorTiles, Position(origin.x + (x - 1), origin.y + (y - 1), origin.z))
            end
        end
    end

    local spawned = {}
    if #floorTiles == 0 then
        return spawned
    end

    local spawns = math.min(maxSpawns, #floorTiles)
    for i = 1, spawns do
        local tileIndex = math.random(#floorTiles)
        local spawnPosition = floorTiles[tileIndex]
        floorTiles[tileIndex] = floorTiles[#floorTiles]
        table.remove(floorTiles)

        local monsterName = monsterNames[((i - 1) % #monsterNames) + 1]
        local monster = Game.createMonster(monsterName, spawnPosition, true, true)
        if monster then
            table.insert(spawned, monster)
        end
    end

    return spawned
end

function DungeonInstances.create(monsterNames, spawnCount, floorCoverage)
    if not DUNGEON_INSTANCE_CONFIG.width or not DUNGEON_INSTANCE_CONFIG.height then
        return nil, nil, "Instance dimensions are not configured."
    end

    local instanceId, origin = DungeonInstances.allocateSlot()
    if not instanceId then
        return nil, nil, "No available instance slots."
    end

    local monsters = monsterNames or DUNGEON_INSTANCE_CONFIG.defaultMonsters
    if monsters then
        local cleaned = {}
        for _, name in ipairs(monsters) do
            if name and name ~= "" then
                table.insert(cleaned, name)
            end
        end

        if #cleaned > 0 then
            monsters = cleaned
        end
    end

    if not monsters or #monsters == 0 then
        monsters = DUNGEON_INSTANCE_CONFIG.defaultMonsters
    end

    local spawnTotal = spawnCount or DUNGEON_INSTANCE_CONFIG.defaultMonsterCount
    local coverage = floorCoverage or DUNGEON_INSTANCE_CONFIG.defaultFloorCoverage
    coverage = math.max(0.05, math.min(0.9, coverage))

    local width = DUNGEON_INSTANCE_CONFIG.width
    local height = DUNGEON_INSTANCE_CONFIG.height
    local floorTarget = math.max(1, math.floor(width * height * coverage))
    local layout = DungeonInstances.generateRandomLayout(width, height, floorTarget)

    applyLayout(origin, layout)
    local spawnedMonsters = spawnMonsters(origin, layout, monsters, spawnTotal)

    DungeonInstances.instances[instanceId] = {
        origin = origin,
        layout = layout,
        monsters = spawnedMonsters
    }

    return instanceId, origin
end

function DungeonInstances.release(instanceId, clearArea)
    local instance = DungeonInstances.instances[instanceId]
    if not instance then
        return false
    end

    if instance.monsters then
        for _, monster in ipairs(instance.monsters) do
            if monster and not monster:isRemoved() then
                monster:remove()
            end
        end
    end

    if clearArea then
        clearInstanceArea(instance.origin, DUNGEON_INSTANCE_CONFIG.width, DUNGEON_INSTANCE_CONFIG.height)
    end

    DungeonInstances.instances[instanceId] = nil
    return true
end

function DungeonInstances.describeSlots()
    return {
        perRow = getSlotsPerRow(),
        perColumn = getSlotsPerColumn(),
        configuredMax = DUNGEON_INSTANCE_CONFIG.maxInstances
    }
end
