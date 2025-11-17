-- data/actions/scripts/map_instance.lua

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
    -- Exemplo de decisão de tipo de mapa pelo actionid
    local mapType = "basic"
    if item:getActionId() == 5001 then
        mapType = "corrupted"
    elseif item:getActionId() == 5002 then
        mapType = "fire"
    end

    local ok, result = Instances.createInstance({
        owner = player,
        mapType = mapType,
        -- seed opcional baseado no uid do item
        seed = item:getUniqueId() > 0 and item:getUniqueId() or os.time()
    })

    if not ok then
        player:sendCancelMessage(result)
        return true
    end

    -- Se quiser consumir o item:
    -- item:remove(1)

    return true
end
