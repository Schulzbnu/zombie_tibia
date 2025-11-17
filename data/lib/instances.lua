-- data/lib/instances.lua
-- Sistema de instâncias estilo Path of Exile

Instances = Instances or {}

-- Área reservada no .otbm para TODAS as instâncias
Instances.MAP_REGION = {
    from = Position(1000, 1000, 7),
    to   = Position(1199, 1199, 7)
}

-- Configurações gerais de instância
Instances.CONFIG = {
    width = 50,
    height = 50,
    maxInstances = 12, -- quantos slots cabem na área
    wallItemId = 1045, -- PAREDE (trocar pelos itens do seu mapa)
    floorItemId = 352  -- PISO (opcional)
}

-- Tipos de mapa (você pode inventar vários)
Instances.MAP_TYPES = {
    basic = {
        name = "Mapa Básico",
        monsterSet = {"zombie_weak", "zombie_fast"},
        monsterCount = 30,
        floorRatio = 0.35,      -- % de chão
        duration = 20 * 60      -- 20 minutos
    },
    corrupted = {
        name = "Mapa Corrompido",
        monsterSet = {"corrupted_zombie", "corrupted_spirit"},
        monsterCount = 40,
        floorRatio = 0.30,
        duration = 20 * 60
    },
    fire = {
        name = "Mapa Flamejante",
        monsterSet = {"fire_zombie", "flame_skull"},
        monsterCount = 35,
        floorRatio = 0.32,
        duration = 20 * 60
    }
}

-- tabela de instâncias ativas
Instances.slots = Instances.slots or {}

----------------------------------------------------------------
-- ALOCAÇÃO DE SLOT DENTRO DA ÁREA RESERVADA
----------------------------------------------------------------
function Instances.allocateSlot()
    local cfg = Instances.CONFIG
    local region = Instances.MAP_REGION

    for id = 1, cfg.maxInstances do
        if not Instances.slots[id] then
            -- Distribui em grid (exemplo 4 colunas)
            local cols = 4
            local w, h = cfg.width, cfg.height
            local col = (id - 1) % cols
            local row = math.floor((id - 1) / cols)

            local baseX = region.from.x + col * w
            local baseY = region.from.y + row * h
            local origin = Position(baseX, baseY, region.from.z)
            return id, origin
        end
    end
    return nil, nil
end

----------------------------------------------------------------
-- GERAÇÃO DO LAYOUT (RANDOM WALK)
----------------------------------------------------------------
function Instances.generateRandomLayout(width, height, floorRatio, seed)
    if seed then
        math.randomseed(seed)
    end

    local floorTarget = math.floor(width * height * floorRatio)

    local grid = {}
    for y = 1, height do
        grid[y] = {}
        for x = 1, width do
            grid[y][x] = 1 -- 1 = parede, 0 = chão
        end
    end

    local x = math.floor(width / 2)
    local y = math.floor(height / 2)
    grid[y][x] = 0
    local floorCount = 1

    local dirs = {
        {1, 0}, {-1, 0}, {0, 1}, {0, -1}
    }

    local maxSteps = width * height * 10

    for i = 1, maxSteps do
        local d = dirs[math.random(#dirs)]
        x = x + d[1]
        y = y + d[2]

        if x < 2 then x = 2 end
        if x > width - 1 then x = width - 1 end
        if y < 2 then y = 2 end
        if y > height - 1 then y = height - 1 end

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

----------------------------------------------------------------
-- LIMPAR ÁREA DE UMA INSTÂNCIA
----------------------------------------------------------------
function Instances.clearArea(origin, w, h)
    for yy = 0, h - 1 do
        for xx = 0, w - 1 do
            local pos = Position(origin.x + xx, origin.y + yy, origin.z)
            local tile = Tile(pos)
            if tile then
                local items = tile:getItems()
                if items then
                    for _, item in ipairs(items) do
                        -- aqui você pode filtrar por itemid se quiser
                        item:remove()
                    end
                end
            end
        end
    end
end

----------------------------------------------------------------
-- APLICAR LAYOUT NO MUNDO
----------------------------------------------------------------
function Instances.applyLayout(origin, grid)
    local cfg = Instances.CONFIG
    local h = #grid
    local w = #grid[1]

    Instances.clearArea(origin, w, h)

    for y = 1, h do
        for x = 1, w do
            local pos = Position(origin.x + (x - 1), origin.y + (y - 1), origin.z)
            if grid[y][x] == 1 then
                Game.createItem(cfg.wallItemId, 1, pos)
            else
                if cfg.floorItemId then
                    Game.createItem(cfg.floorItemId, 1, pos)
                end
            end
        end
    end
end

----------------------------------------------------------------
-- SPAWN DE MONSTROS
----------------------------------------------------------------
function Instances.spawnMonsters(instanceId, origin, grid, monsterSet, monsterCount)
    local h = #grid
    local w = #grid[1]
    local floorPositions = {}

    for y = 1, h do
        for x = 1, w do
            if grid[y][x] == 0 then
                table.insert(floorPositions, Position(origin.x + (x - 1), origin.y + (y - 1), origin.z))
            end
        end
    end

    Instances.slots[instanceId].monsters = {}

    for i = 1, monsterCount do
        local pos = floorPositions[math.random(#floorPositions)]
        local name = monsterSet[math.random(#monsterSet)]
        local monster = Game.createMonster(name, pos)
        if monster then
            table.insert(Instances.slots[instanceId].monsters, monster:getId())
        end
    end
end

----------------------------------------------------------------
-- CRIAR INSTÂNCIA
----------------------------------------------------------------
-- params: {
--   owner = Player,
--   mapType = "basic"/"corrupted"/etc,
--   seed = number (opcional),
-- }
function Instances.createInstance(params)
    local player = params.owner
    if not player then
        return false, "Sem jogador dono da instância."
    end

    local mapType = params.mapType or "basic"
    local typeCfg = Instances.MAP_TYPES[mapType]
    if not typeCfg then
        return false, "Tipo de mapa invalido."
    end

    local id, origin = Instances.allocateSlot()
    if not id then
        return false, "Nenhum mapa disponivel no momento."
    end

    local cfg = Instances.CONFIG
    local seed = params.seed or os.time()

    local grid = Instances.generateRandomLayout(
        cfg.width,
        cfg.height,
        typeCfg.floorRatio or 0.35,
        seed
    )

    Instances.slots[id] = {
        id = id,
        origin = origin,
        grid = grid,
        type = mapType,
        ownerId = player:getId(),
        expiresAt = os.time() + (typeCfg.duration or 20 * 60),
        seed = seed
    }

    Instances.applyLayout(origin, grid)
    Instances.spawnMonsters(id, origin, grid, typeCfg.monsterSet, typeCfg.monsterCount)

    -- Teleporta pro centro aproximado
    local entryPos = Position(
        origin.x + math.floor(cfg.width / 2),
        origin.y + math.floor(cfg.height / 2),
        origin.z
    )

    player:teleportTo(entryPos)
    entryPos:sendMagicEffect(CONST_ME_TELEPORT)

    return true, id
end

----------------------------------------------------------------
-- DESTRUIR INSTÂNCIA
----------------------------------------------------------------
function Instances.destroyInstance(id)
    local inst = Instances.slots[id]
    if not inst then
        return
    end

    -- Remove monstros
    if inst.monsters then
        for _, cid in ipairs(inst.monsters) do
            local creature = Creature(cid)
            if creature then
                creature:remove()
            end
        end
    end

    -- Limpa área
    local cfg = Instances.CONFIG
    Instances.clearArea(inst.origin, cfg.width, cfg.height)

    Instances.slots[id] = nil
end

----------------------------------------------------------------
-- LIMPEZA POR TEMPO (CHAMADA PELO GLOBALEVENT)
----------------------------------------------------------------
function Instances.tickCleanup()
    local now = os.time()
    for id, inst in pairs(Instances.slots) do
        if now >= inst.expiresAt then
            Instances.destroyInstance(id)
        end
    end
end
