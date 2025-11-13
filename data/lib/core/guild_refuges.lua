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

function GuildRefuges.getConfigIdByLoadingMap(loadingMap)
    local normalized = normalizeId(loadingMap)
    if not normalized then
        return nil
    end

    for refugeId, config in pairs(GuildRefuges.configs) do
        if type(config.loadingMap) == "string" and config.loadingMap:lower() == normalized then
            return refugeId
        end
    end

    return nil
end

function GuildRefuges.getConfigByLoadingMap(loadingMap)
    local refugeId = GuildRefuges.getConfigIdByLoadingMap(loadingMap)
    if not refugeId then
        return nil, nil
    end

    return GuildRefuges.configs[refugeId], refugeId
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

function GuildRefuges.loadMap(refugeId)
    if GuildRefuges.isMapLoaded(refugeId) then
        return true
    end

    local config = GuildRefuges.getConfig(refugeId)
    if not config then
        return false, "config_missing"
    end

    local mapFile = config.mapFile
    if type(mapFile) ~= "string" or mapFile == "" then
        return false, "mapfile_missing"
    end

    local fileHandle = io.open(mapFile, "r")
    if not fileHandle then
        return false, "mapfile_not_found", mapFile
    end
    fileHandle:close()

    Game.loadMap(mapFile)
    GuildRefuges.markMapLoaded(refugeId)
    return true
end

function GuildRefuges.loadClaimedMapsFromDatabase()
    local resultId = db.storeQuery("SELECT `loading_map` FROM `guild_refuges`")
    if not resultId then
        return
    end

    local processed = {}
    repeat
        local loadingMap = result.getString(resultId, "loading_map")
        if loadingMap and loadingMap ~= "" then
            local refugeConfig, refugeId = GuildRefuges.getConfigByLoadingMap(loadingMap)
            if refugeId and not processed[refugeId] then
                local success, errorCode, extra = GuildRefuges.loadMap(refugeId)
                if not success then
                    if errorCode == "mapfile_missing" then
                        print(string.format("[GuildRefuges] Arquivo de mapa não configurado para '%s'.", refugeId))
                    elseif errorCode == "mapfile_not_found" then
                        local path = extra or (refugeConfig and refugeConfig.mapFile) or "desconhecido"
                        print(string.format("[GuildRefuges] Arquivo de mapa '%s' não encontrado para '%s'.", path, refugeId))
                    else
                        print(string.format("[GuildRefuges] Não foi possível carregar o mapa do refúgio '%s'.", refugeId))
                    end
                end
                processed[refugeId] = true
            elseif not refugeId then
                print(string.format("[GuildRefuges] Configuração não encontrada para loading_map '%s'.", loadingMap))
            end
        end
    until not result.next(resultId)
    result.free(resultId)
end
