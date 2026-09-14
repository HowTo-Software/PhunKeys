if isClient() then
    return
end

require "PhunKeys_Shared"

local function isNearVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()
    return dx * dx + dy * dy <= PhunKeys.maxDistance * PhunKeys.maxDistance
end

local function vehicleIsEmpty(vehicle)
    local passengers = vehicle:getMaxPassengers()
    for seat = 0, passengers - 1 do
        if vehicle:getCharacter(seat) then
            return false
        end
    end
    return true
end

local function vehicleStorageIsEmpty(vehicle)
    for index = 0, vehicle:getPartCount() - 1 do
        local container = vehicle:getPartByIndex(index):getItemContainer()
        if container and not container:getItems():isEmpty() then
            return false
        end
    end
    return true
end

local function findInventoryItem(player, itemId, itemType)
    local inventory = player:getInventory()
    local allItems = inventory.getAllItemsRecurse and inventory:getAllItemsRecurse() or inventory:getItems()
    for index = 0, allItems:size() - 1 do
        local item = allItems:get(index)
        if item:getID() == itemId and item:getFullType() == itemType then
            return item
        end
    end
end

local function carKeyInBox(box)
    local inventory = box:getInventory()
    local items = inventory and inventory:getItems()
    if not items or items:size() ~= 1 then
        return
    end
    local key = items:get(0)
    if key and key:getFullType() == "Base.CarKey" and key:getKeyId() ~= -1 then
        return key
    end
end

local function vehicleForKey(player, keyId)
    local vehicles = getCell():getVehicles()
    for index = 0, vehicles:size() - 1 do
        local vehicle = vehicles:get(index)
        if vehicle:getKeyId() == keyId and isNearVehicle(player, vehicle) and vehicleIsEmpty(vehicle) and vehicleStorageIsEmpty(vehicle) then
            return vehicle
        end
    end
end

local function packVehicle(player, arguments)
    local boxId = arguments and tonumber(arguments.boxId)
    local box = boxId and findInventoryItem(player, boxId, PhunKeys.boxItemType)
    local key = box and carKeyInBox(box)
    local vehicle = key and vehicleForKey(player, key:getKeyId())
    if not vehicle then
        return
    end

    local boxInventory = box:getInventory()
    boxInventory:Remove(key)
    sendRemoveItemFromContainer(boxInventory, key)

    local sellerKey = boxInventory:AddItem(PhunKeys.itemType)
    if not sellerKey then
        boxInventory:AddItem(key)
        sendAddItemToContainer(boxInventory, key)
        return
    end
    sendAddItemToContainer(boxInventory, sellerKey)
    sendServerCommand(player, PhunKeys.module, PhunKeys.playSoundCommand, {
        sound = "PhunKeys_KeyRemove"
    })

    vehicle:permanentlyRemove()
end

Events.OnClientCommand.Add(function(module, command, player, arguments)
    if module ~= PhunKeys.module then
        return
    end
    if command == PhunKeys.command then
        packVehicle(player, arguments)
    end
end)