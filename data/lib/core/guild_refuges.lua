GuildRefuges = GuildRefuges or {}
GuildRefuges.configs = {
    initial = {
        name = "Abrigo Inicial",
        loadingMap = "refugio_inicial",
        mapFile = "data/world/refugio_inicial.otbm",
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
