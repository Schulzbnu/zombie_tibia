GuildRefuges = GuildRefuges or {}
GuildRefuges.configs = {
    initial = {
        name = "Abrigo Inicial",
        loadingMap = "refugio_inicial",
        mapFile = "data/world/map_2.otbm",
        teleportPosition = Position(1123, 1052, 7),
        requiredItems = {
            {id = 5901, count = 200, name = "tábuas de madeira"},
            {id = 5880, count = 50, name = "blocos de pedra"},
            {id = 5887, count = 30, name = "lingotes de metal"}
        }
    }
}

GuildRefuges._loadedMaps = GuildRefuges._loadedMaps or {}
GuildRefuges._loadedMapFiles = GuildRefuges._loadedMapFiles or {}

local function normalizeId(refugeId)
    if type(refugeId) ~= "string" then
        return nil
    end
    return refugeId:lower()
end

function GuildRefuges.getConfig(refugeId)
    local normalized = normalizeId(refugeId)
    if not normalized then
        return nil
    end
    return GuildRefuges.configs[normalized]
end

function GuildRefuges.requireConfig(refugeId)
    local config = GuildRefuges.getConfig(refugeId)
    if not config then
        error(string.format("GuildRefuges: configuração '%s' não encontrada.", tostring(refugeId)))
    end
    return config
end

function GuildRefuges.isMapLoaded(refugeId)
    local normalized = normalizeId(refugeId)
    return normalized and GuildRefuges._loadedMaps[normalized] or false
end

function GuildRefuges.markMapLoaded(refugeId)
    local normalized = normalizeId(refugeId)
    if normalized then
        GuildRefuges._loadedMaps[normalized] = true
    end
end

function GuildRefuges.isMapFileLoaded(mapFile)
    if type(mapFile) ~= "string" then
        return false
    end
    return GuildRefuges._loadedMapFiles[mapFile] or false
end

function GuildRefuges.markMapFileLoaded(mapFile)
    if type(mapFile) ~= "string" then
        return
    end
    GuildRefuges._loadedMapFiles[mapFile] = true
end

local function normalizeLoadingMap(loadingMap)
    if type(loadingMap) ~= "string" then
        return nil
    end
    return loadingMap:lower()
end

function GuildRefuges.getKeyByLoadingMap(loadingMap)
    local normalized = normalizeLoadingMap(loadingMap)
    if not normalized then
        return nil
    end

    for key, config in pairs(GuildRefuges.configs) do
        if type(config.loadingMap) == "string" and config.loadingMap:lower() == normalized then
            return key, config
        end
    end

    return nil
end

local function markLoaded(normalizedKey, mapFile)
    GuildRefuges.markMapLoaded(normalizedKey)
    if mapFile then
        GuildRefuges.markMapFileLoaded(mapFile)
    end
end

function GuildRefuges.ensureMapLoaded(refugeId, config)
    local normalizedKey = normalizeId(refugeId)
    if not normalizedKey then
        return false, string.format("GuildRefuges: identificador inválido (%s).", tostring(refugeId))
    end

    config = config or GuildRefuges.getConfig(normalizedKey)
    if not config then
        return false, string.format("GuildRefuges: configuração '%s' não encontrada.", tostring(refugeId))
    end

    local mapFile = config.mapFile
    if not mapFile or mapFile == "" then
        markLoaded(normalizedKey)
        return true
    end

    if GuildRefuges.isMapLoaded(normalizedKey) or GuildRefuges.isMapFileLoaded(mapFile) then
        markLoaded(normalizedKey, mapFile)
        return true
    end

    local teleportPosition = config.teleportPosition
    if teleportPosition then
        local tile = Tile(teleportPosition)
        if tile then
            markLoaded(normalizedKey, mapFile)
            return true
        end
    end

    local fileHandle = io.open(mapFile, "r")
    if not fileHandle then
        return false, string.format("O arquivo de mapa %s não foi encontrado. Avise a equipe administrativa.", mapFile)
    end
    fileHandle:close()

    Game.loadMap(mapFile)
    markLoaded(normalizedKey, mapFile)
    return true
end
