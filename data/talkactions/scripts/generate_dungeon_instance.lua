function onSay(player, words, param)
    if not player:getGroup():getAccess() then
        return true
    end

    if player:getAccountType() < ACCOUNT_TYPE_GAMEMASTER then
        player:sendCancelMessage("You are not authorized to manage dungeon instances.")
        return false
    end

    local args = param:splitTrimmed(" ")
    if args[1] and args[1]:lower() == "release" then
        local instanceId = tonumber(args[2] or "")
        if not instanceId then
            player:sendCancelMessage("Usage: /instance release <id>")
            return false
        end

        if DungeonInstances.release(instanceId, true) then
            player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Instance %d cleaned and released.", instanceId))
        else
            player:sendCancelMessage("No instance stored with that id.")
        end
        return false
    end

    if args[1] and args[1]:lower() == "slots" then
        local slots = DungeonInstances.describeSlots()
        player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format("Slots per row: %d, per column: %d, configured max: %d.", slots.perRow, slots.perColumn, slots.configuredMax))
        return false
    end

    local monsterNames = DUNGEON_INSTANCE_CONFIG.defaultMonsters
    if args[1] and args[1] ~= "" then
        monsterNames = args[1]:splitTrimmed(",")
    end

    local spawnCount = tonumber(args[2] or "") or DUNGEON_INSTANCE_CONFIG.defaultMonsterCount
    local coverage = tonumber(args[3] or "") or DUNGEON_INSTANCE_CONFIG.defaultFloorCoverage

    local instanceId, origin, errorMsg = DungeonInstances.create(monsterNames, spawnCount, coverage)
    if not instanceId then
        player:sendCancelMessage(errorMsg or "Unable to create dungeon instance.")
        return false
    end

    player:sendTextMessage(MESSAGE_EVENT_ADVANCE, string.format(
        "Dungeon instance %d generated at %d, %d, %d with %d monsters.",
        instanceId,
        origin.x,
        origin.y,
        origin.z,
        spawnCount
    ))
    return false
end
