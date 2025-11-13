local keywordHandler = KeywordHandler:new()
local npcHandler = NpcHandler:new(keywordHandler)
NpcSystem.parseParameters(npcHandler)

local Topic = {}

local refugeKey = NpcSystem.getParameter('refuge_key')
if type(refugeKey) ~= 'string' or refugeKey == '' then
    error("refuge_keeper.lua: defina o parâmetro 'refuge_key' no NPC para associá-lo a um refúgio.")
end

refugeKey = refugeKey:lower()

npcHandler.refugeKey = refugeKey
npcHandler.refugeConfig = GuildRefuges.requireConfig(refugeKey)

local function getRefugeConfig()
    return npcHandler.refugeConfig
end

local function getRefugeKey()
    return npcHandler.refugeKey
end

local function resetTopic(cid)
    Topic[cid] = 0
end

local function getItemDisplayName(requirement)
    if requirement.name then
        return requirement.name
    end

    local itemType = ItemType(requirement.id)
    local itemName = itemType and itemType:getName() or "item desconhecido"
    return itemName ~= "" and itemName or "item desconhecido"
end

local function formatRequirements(config)
    local requirements = config.requiredItems or {}
    local fragments = {}
    for index, requirement in ipairs(requirements) do
        local part = string.format("%dx %s", requirement.count, getItemDisplayName(requirement))
        fragments[#fragments + 1] = part
    end

    if #fragments == 0 then
        return "nenhum recurso"
    end

    if #fragments == 1 then
        return fragments[1]
    end

    return table.concat(fragments, ", ", 1, #fragments - 1) .. " e " .. fragments[#fragments]
end

local function hasAllRequirements(player, config)
    local requirements = config.requiredItems or {}
    local missing = {}
    for _, requirement in ipairs(requirements) do
        local owned = player:getItemCount(requirement.id)
        if owned < requirement.count then
            missing[#missing + 1] = string.format("%dx %s", requirement.count - owned, getItemDisplayName(requirement))
        end
    end
    return #missing == 0, missing
end

local function removeRequirements(player, config)
    local requirements = config.requiredItems or {}
    local removed = {}
    for _, requirement in ipairs(requirements) do
        if requirement.count > 0 then
            if player:removeItem(requirement.id, requirement.count) then
                removed[#removed + 1] = {id = requirement.id, count = requirement.count}
            else
                if #removed > 0 then
                    for _, entry in ipairs(removed) do
                        player:addItem(entry.id, entry.count)
                    end
                end
                return false
            end
        end
    end
    return true, removed
end

local function refundRemovedItems(player, removed)
    for _, entry in ipairs(removed) do
        player:addItem(entry.id, entry.count)
    end
end

local function getRefugeByMap(config)
    local resultId = db.storeQuery("SELECT `id`, `name`, `guild_id`, `loading_map` FROM `guild_refuges` WHERE `loading_map` = " .. db.escapeString(config.loadingMap) .. " LIMIT 1")
    if resultId then
        local data = {
            id = result.getNumber(resultId, "id"),
            name = result.getString(resultId, "name"),
            guildId = result.getNumber(resultId, "guild_id"),
            loadingMap = result.getString(resultId, "loading_map")
        }
        result.free(resultId)
        return data
    end
    return nil
end

local function getRefugeByGuild(guildId)
    local resultId = db.storeQuery("SELECT `id`, `name`, `loading_map` FROM `guild_refuges` WHERE `guild_id` = " .. guildId .. " LIMIT 1")
    if resultId then
        local data = {
            id = result.getNumber(resultId, "id"),
            name = result.getString(resultId, "name"),
            loadingMap = result.getString(resultId, "loading_map")
        }
        result.free(resultId)
        return data
    end
    return nil
end

local function getGuildName(guildId)
    local resultId = db.storeQuery("SELECT `name` FROM `guilds` WHERE `id` = " .. guildId .. " LIMIT 1")
    if resultId then
        local guildName = result.getString(resultId, "name")
        result.free(resultId)
        return guildName
    end
    return nil
end

local function ensureMapLoaded(player, config)
    local success, errorMessage = GuildRefuges.ensureMapLoaded(getRefugeKey(), config)
    if not success and player and errorMessage then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, errorMessage)
    end
    return success
end

local function teleportPlayer(player, config)
    local position = config.teleportPosition
    if not position then
        return
    end

    local tile = Tile(position)
    if not tile then
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, "O mapa foi carregado, mas o ponto de chegada do abrigo ainda não está configurado.")
        return
    end

    player:teleportTo(position)
    position:sendMagicEffect(CONST_ME_TELEPORT)
end

local function creatureSayCallback(cid, type, msg)
    local player = Player(cid)
    if not player then
        return false
    end

    local message = msg:lower()

    if message:find("refugio") or message:find("refúgio") or message:find("abrigo") then
        local config = getRefugeConfig()
        if not config then
            npcHandler:say("Este abrigo não foi configurado corretamente. Avise a equipe administrativa.", cid)
            resetTopic(cid)
            return true
        end

        local guild = player:getGuild()
        if not guild then
            npcHandler:say("Você precisa fazer parte de uma guilda antes de pensar em administrar um abrigo.", cid)
            resetTopic(cid)
            return true
        end

        if player:getGuildLevel() < 3 then
            npcHandler:say("Somente o líder da guilda pode reivindicar um abrigo. Traga o seu líder até mim.", cid)
            resetTopic(cid)
            return true
        end

        local alreadyOwned = getRefugeByGuild(guild:getId())
        if alreadyOwned then
            npcHandler:say(string.format("A sua guilda já controla o abrigo '%s'. Use-o bem!", alreadyOwned.name), cid)
            resetTopic(cid)
            return true
        end

        local claimed = getRefugeByMap(config)
        if claimed then
            if claimed.guildId == guild:getId() then
                npcHandler:say(string.format("Sua guilda já registrou o abrigo '%s'.", claimed.name), cid)
            else
                local ownerName = getGuildName(claimed.guildId) or "uma guilda desconhecida"
                npcHandler:say(string.format("Esse abrigo já pertence à guilda %s. Talvez vocês precisem disputar outro local.", ownerName), cid)
            end
            resetTopic(cid)
            return true
        end

        npcHandler:say(string.format("Para fundar o %s, sua guilda precisa entregar %s. Você deseja entregar esses recursos agora?", config.name, formatRequirements(config)), cid)
        Topic[cid] = 1
        return true
    end

    if Topic[cid] == 1 then
        if message == "sim" then
            local config = getRefugeConfig()
            if not config then
                npcHandler:say("Este abrigo não foi configurado corretamente. Avise a equipe administrativa.", cid)
                resetTopic(cid)
                return true
            end

            local guild = player:getGuild()
            if not guild then
                npcHandler:say("Você não está mais em uma guilda.", cid)
                resetTopic(cid)
                return true
            end

            if player:getGuildLevel() < 3 then
                npcHandler:say("Somente líderes de guilda podem concluir este ritual.", cid)
                resetTopic(cid)
                return true
            end

            local alreadyOwned = getRefugeByGuild(guild:getId())
            if alreadyOwned then
                npcHandler:say(string.format("A sua guilda já possui o abrigo '%s'.", alreadyOwned.name), cid)
                resetTopic(cid)
                return true
            end

            local claimed = getRefugeByMap(config)
            if claimed then
                npcHandler:say("Alguém reivindicou o abrigo enquanto conversávamos. Volte mais tarde.", cid)
                resetTopic(cid)
                return true
            end

            local hasResources, missing = hasAllRequirements(player, config)
            if not hasResources then
                npcHandler:say("Você ainda está faltando: " .. table.concat(missing, ", ") .. ". Volte quando estiver com tudo em mãos.", cid)
                resetTopic(cid)
                return true
            end

            local removed, removedItems = removeRequirements(player, config)
            if not removed then
                npcHandler:say("Não consegui retirar todos os materiais da sua mochila. Reorganize-os e tente novamente.", cid)
                resetTopic(cid)
                return true
            end

            local now = os.time()
            local insertQuery = string.format(
                "INSERT INTO `guild_refuges` (`name`, `guild_id`, `leader_id`, `level`, `loading_map`, `created_at`, `updated_at`) VALUES (%s, %d, %d, %d, %s, %d, %d)",
                db.escapeString(config.name),
                guild:getId(),
                player:getGuid(),
                1,
                db.escapeString(config.loadingMap),
                now,
                now
            )

            if not db.query(insertQuery) then
                npcHandler:say("Ocorreu um erro ao registrar o abrigo. Seus recursos foram devolvidos.", cid)
                refundRemovedItems(player, removedItems)
                resetTopic(cid)
                return true
            end

            npcHandler:say(string.format("O abrigo '%s' agora pertence à sua guilda! Prepare-se para defendê-lo.", config.name), cid)
            if ensureMapLoaded(player, config) then
                teleportPlayer(player, config)
            end
            resetTopic(cid)
            return true
        elseif message == "nao" or message == "não" then
            npcHandler:say("Tudo bem. Pense com calma e retorne quando tiver certeza.", cid)
            resetTopic(cid)
            return true
        end
    end

    return false
end

npcHandler:setMessage(MESSAGE_GREET, "Saudações, viajante. Eu posso ajudar sua guilda a erguer um abrigo seguro.")
npcHandler:setMessage(MESSAGE_FAREWELL, "Que os mortos não encontrem o caminho até você.")
npcHandler:setCallback(CALLBACK_MESSAGE_DEFAULT, creatureSayCallback)

function onCreatureAppear(cid)
    npcHandler:onCreatureAppear(cid)
end

function onCreatureDisappear(cid)
    npcHandler:onCreatureDisappear(cid)
    Topic[cid] = nil
end

function onCreatureSay(cid, type, msg)
    npcHandler:onCreatureSay(cid, type, msg)
end

function onThink()
    npcHandler:onThink()
end

npcHandler:addModule(FocusModule:new())
