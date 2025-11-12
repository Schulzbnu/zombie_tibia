--[=[
Configuração dos itens que carregam novos mapas. Use como chave o
`uniqueid`, `actionid` ou até mesmo o `itemid` do item. O script procura
por uma configuração nessa ordem e utiliza o primeiro valor encontrado.
Defina o caminho completo do arquivo `.otbm` que deve ser carregado e,
opcionalmente, personalize as mensagens enviadas para o jogador que
ativou o item e para todos os jogadores online.
]=]

local loadMapSwitches = {
  [32000] = {
    path = "data/world/zombie.otbm",
    playerMessage = "O novo mapa de zumbis está sendo carregado...",
    playerMessageType = MESSAGE_EVENT_ADVANCE,
    broadcastMessage = "O mapa de zumbis foi carregado!",
    broadcastType = MESSAGE_STATUS_WARNING
  }
}

local function fileExists(path)
  local file = io.open(path, "rb")
  if file then
    file:close()
    return true
  end
  return false
end

function onUse(player, item, fromPosition, target, toPosition, isHotkey)
  local config = loadMapSwitches[item.uid]
    or loadMapSwitches[item:getActionId()]
    or loadMapSwitches[item.itemid]
  if not config then
    player:sendCancelMessage("Nada acontece.")
    return true
  end

  local path = config.path
  if type(path) ~= "string" or path == "" then
    player:sendCancelMessage("Mapa inválido configurado.")
    return true
  end

  if not fileExists(path) then
    player:sendCancelMessage("Arquivo de mapa não encontrado.")
    return true
  end

  Game.loadMap(path)

  local playerMessage = config.playerMessage
  if playerMessage ~= false then
    player:sendTextMessage(config.playerMessageType or MESSAGE_EVENT_ADVANCE, playerMessage or ("Carregando mapa " .. path .. "."))
  end

  local broadcastMessage = config.broadcastMessage
  if broadcastMessage then
    Game.broadcastMessage(broadcastMessage, config.broadcastType)
  end
  return true
end
