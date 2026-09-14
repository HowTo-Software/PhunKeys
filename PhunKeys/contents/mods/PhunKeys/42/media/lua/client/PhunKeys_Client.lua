if isServer() then
    return
end

require "PhunKeys_Shared"

local function packVehicle(player, box)
    if box then
        getSoundManager():PlaySound("PhunKeys_Transmute", false, 0):setVolume(0.50)
        sendClientCommand(PhunKeys.module, PhunKeys.command, {
            boxId = box:getID()
        })
    end
end

Events.OnFillInventoryObjectContextMenu.Add(function(playerNum, context, items)
    for _, entry in ipairs(items or {}) do
        local item = type(entry) == "table" and entry.items and entry.items[1] or entry
        if item and item.getFullType and item:getFullType() == PhunKeys.boxItemType then
            context:addOption("Transmute", getSpecificPlayer(playerNum), packVehicle, item)
        end
    end
end)

Events.OnServerCommand.Add(function(module, command, arguments)
    if module == PhunKeys.module and command == PhunKeys.playSoundCommand and arguments and arguments.sound then
        getSoundManager():PlaySound(arguments.sound, false, 0):setVolume(0.50)
    end
end)
