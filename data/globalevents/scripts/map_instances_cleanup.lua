-- data/globalevents/scripts/map_instances_cleanup.lua

function onThink(interval)
    Instances.tickCleanup()
    return true
end
