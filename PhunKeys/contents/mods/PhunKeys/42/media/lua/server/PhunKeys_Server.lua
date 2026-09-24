print("[PhunKeys][BOOT][DEBUG3-SET-ITERATOR] ENTER SERVER PhunKeys_Server.lua")
if isClient() then
    return
end

require "PhunKeys_Shared"
require "PhunKeys_Access"

local function log(message)
    print("[PhunKeys] " .. tostring(message))
end

local function isNearVehicle(player, vehicle)
    local dx = player:getX() - vehicle:getX()
    local dy = player:getY() - vehicle:getY()

    return dx * dx + dy * dy <=
        PhunKeys.maxDistance * PhunKeys.maxDistance
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
        local part = vehicle:getPartByIndex(index)

        if part then
            local container = part:getItemContainer()

            if container and not container:getItems():isEmpty() then
                return false
            end
        end
    end

    return true
end

local function findBox(player, boxId)
    local inventory = player:getInventory()
    local items = inventory:getItems()

    for index = 0, items:size() - 1 do
        local item = items:get(index)

        if item
            and item:getID() == boxId
            and item:getFullType() == PhunKeys.boxItemType then

            return item
        end
    end

    return nil
end

local function carKeyInBox(box)
    local inventory = box:getInventory()

    if not inventory then
        log("Box has no internal inventory.")
        return nil
    end

    local items = inventory:getItems()

    if items:size() ~= 1 then
        log("Box must contain exactly one item. Found: " .. tostring(items:size()))
        return nil
    end

    local key = items:get(0)

    if not key then
        log("Box item was nil.")
        return nil
    end

    log(
        "Box contains "
        .. tostring(key:getFullType())
        .. " keyId="
        .. tostring(key:getKeyId())
    )

    if key:getFullType() ~= "Base.CarKey" then
        log("Item is not Base.CarKey.")
        return nil
    end

    if key:getKeyId() == -1 then
        log("Car key has invalid key ID.")
        return nil
    end

    return key
end

local function vehicleForKey(player, keyId)
    local vehicles = getCell():getVehicles()

    if not vehicles then
        log("getCell():getVehicles() returned nil.")
        return nil
    end

    log(
        "Searching "
        .. tostring(vehicles:size())
        .. " loaded vehicles for keyId="
        .. tostring(keyId)
    )

    local iterator = vehicles:iterator()

    while iterator:hasNext() do
        local vehicle = iterator:next()

        if vehicle then
            local vehicleKeyId = vehicle:getKeyId()

            if vehicleKeyId == keyId then
                log("Found vehicle matching key ID.")

                if not isNearVehicle(player, vehicle) then
                    log("Matching vehicle is too far away.")
                    return nil
                end

                if not vehicleIsEmpty(vehicle) then
                    log("Matching vehicle has an occupant.")
                    return nil
                end

                if not vehicleStorageIsEmpty(vehicle) then
                    log("Matching vehicle contains stored items.")
                    return nil
                end

                return vehicle
            end
        end
    end

    log("No loaded vehicle matched key ID.")
    return nil
end

local function packVehicle(player, arguments)
    log("Received packVehicle request from " .. tostring(player:getUsername()))

    if not arguments then
        log("No command arguments received.")
        return
    end

    local boxId = tonumber(arguments.boxId)

    if not boxId then
        log("Invalid box ID.")
        return
    end

    log("Looking for box ID " .. tostring(boxId))

    local box = findBox(player, boxId)

    if not box then
        log("Could not find Vehicle Conversion Box in player inventory.")
        return
    end

    log("Conversion Box found.")

    local key = carKeyInBox(box)

    if not key then
        return
    end

    if key:isFavorite() then
        log("Rejected Transmute: the car key is favorited.")
        return
    end

    local keyId = key:getKeyId()
    local vehicle = vehicleForKey(player, keyId)

    if not vehicle then
        return
    end

    log("All checks passed. Beginning conversion.")

    local boxInventory = box:getInventory()

    -- Remove original car key.
    if boxInventory:contains(key) then
        boxInventory:Remove(key)
        sendRemoveItemFromContainer(boxInventory, key)
    else
        log("Key vanished from box before removal.")
        return
    end

    -- Create sellable trade-in key.
    local sellerKey = boxInventory:AddItem(PhunKeys.itemType)

    if not sellerKey then
        log("FAILED to create " .. tostring(PhunKeys.itemType))

        local restoredKey = boxInventory:AddItem("Base.CarKey")

        if restoredKey then
            restoredKey:setKeyId(keyId)
            sendAddItemToContainer(boxInventory, restoredKey)
        end

        return
    end

    sendAddItemToContainer(boxInventory, sellerKey)

    log("Created Vehicle Trade-In Key.")

    -- Remove the actual vehicle.
    log("Removing vehicle.")
    vehicle:permanentlyRemove()

    log("Vehicle conversion complete.")

    sendServerCommand(
        player,
        PhunKeys.module,
        PhunKeys.playSoundCommand,
        {
            sound = "PhunKeys_KeyRemove"
        }
    )
end

-- Lock/GrantAccess deliberately do not use vehicleForKey(): passengers/cargo are allowed.
local function accessResult(player, message)
    log(message)
    if isServer() then
        sendServerCommand(player, PhunKeys.module, PhunKeys.accessResultCommand, {
            playerNum = player:getPlayerNum(), message = message
        })
    else
        player:Say(message)
    end
end

local function accessVehicleForBox(player, arguments, actionName)
    log("[" .. tostring(actionName) .. "] validating request; arguments=" .. tostring(arguments))
    local boxId = type(arguments) == "table" and tonumber(arguments.boxId) or nil
    log("[" .. tostring(actionName) .. "] boxId=" .. tostring(boxId))
    local box = boxId and findBox(player, boxId) or nil
    if not box then
        log("[" .. tostring(actionName) .. "] FAILED: box not found in player inventory")
    else
        log("[" .. tostring(actionName) .. "] box found; fullType=" .. tostring(box:getFullType()))
    end
    local key = box and carKeyInBox(box) or nil
    if not key then
        log("[" .. tostring(actionName) .. "] FAILED: no valid Base.CarKey in box")
        accessResult(player, actionName .. " requires one favorited car key in your box.")
        return nil
    end
    log("[" .. tostring(actionName) .. "] keyId=" .. tostring(key:getKeyId())
        .. " favorite=" .. tostring(key:isFavorite()))
    if not key:isFavorite() then
        log("[" .. tostring(actionName) .. "] FAILED: key is not favorited server-side")
        accessResult(player, actionName .. " requires one favorited car key in your box.")
        return nil
    end
    local vehicles = getCell():getVehicles()
    if not vehicles then
        log("[" .. tostring(actionName) .. "] FAILED: getCell():getVehicles() returned nil")
        accessResult(player, "No matching vehicle within reach.")
        return nil
    end
    log("[" .. tostring(actionName) .. "] searching " .. tostring(vehicles:size()) .. " loaded vehicles")
    -- IsoCell:getVehicles() is java.util.Set<BaseVehicle> in B42.20.x.
    local iterator = vehicles:iterator()
    local i = 0
    while iterator:hasNext() do
        local vehicle = iterator:next()
        if vehicle then
            local vehicleKeyId = vehicle:getKeyId()
            if vehicleKeyId == key:getKeyId() then
                local dx = player:getX() - vehicle:getX()
                local dy = player:getY() - vehicle:getY()
                local dist2 = dx * dx + dy * dy
                local sameZ = math.floor(player:getZ()) == math.floor(vehicle:getZ())
                log("[" .. tostring(actionName) .. "] matched key vehicle iterIndex=" .. tostring(i)
                    .. " vehicleId=" .. tostring(vehicle:getId())
                    .. " dist2=" .. tostring(dist2)
                    .. " maxDist2=" .. tostring(PhunKeys.maxDistance * PhunKeys.maxDistance)
                    .. " sameZ=" .. tostring(sameZ)
                    .. " protected=" .. tostring(PhunKeys.isProtected(vehicle))
                    .. " guestAccess=" .. tostring(PhunKeys.isGuestAccessGranted(vehicle)))
                if isNearVehicle(player, vehicle) and sameZ then
                    log("[" .. tostring(actionName) .. "] vehicle validation PASSED")
                    return vehicle
                end
            end
        end
        i = i + 1
    end
    log("[" .. tostring(actionName) .. "] FAILED: no matching vehicle within reach")
    accessResult(player, "No matching vehicle within reach.")
    return nil
end

local function setVehicleDoorLocks(vehicle, locked)
    local changed = 0
    log("Setting physical door locks vehicleId=" .. tostring(vehicle:getId()) .. " locked=" .. tostring(locked))
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part and part:getDoor() and part:getInventoryItem() then
            log("  door part=" .. tostring(part:getId()) .. " previousLocked=" .. tostring(part:getDoor():isLocked()))
            part:getDoor():setLocked(locked)
            vehicle:transmitPartDoor(part)
            changed = changed + 1
        end
    end
    vehicle:setTrunkLocked(locked)
    log("Physical lock update complete; doorPartsChanged=" .. tostring(changed) .. " trunkLocked=" .. tostring(locked))
end

function PhunKeys.Lock(player, arguments)
    log("Received Lock request from " .. tostring(player:getUsername()))
    local vehicle = accessVehicleForBox(player, arguments, "Lock")
    if not vehicle then return false end

    local part = PhunKeys.accessPart(vehicle)
    if not part then
        accessResult(player, "Matching vehicle has no usable protection part.")
        return false
    end

    local data = part:getModData()
    data.PhunKeysAccess = true
    data.PhunKeysGuestAccess = false
    vehicle:transmitPartModData(part)
    setVehicleDoorLocks(vehicle, true)
    accessResult(player, "Vehicle locked. Guest access revoked.")
    return true
end

function PhunKeys.GrantAccess(player, arguments)
    log("Received GrantAccess request from " .. tostring(player:getUsername()))
    local vehicle = accessVehicleForBox(player, arguments, "Grant Access")
    if not vehicle then return false end
    if not PhunKeys.isProtected(vehicle) then
        accessResult(player, "Lock the vehicle with PhunKeys before granting access.")
        return false
    end

    local part = PhunKeys.accessPart(vehicle)
    if not part then
        accessResult(player, "Matching vehicle has no usable protection part.")
        return false
    end

    part:getModData().PhunKeysGuestAccess = true
    vehicle:transmitPartModData(part)
    setVehicleDoorLocks(vehicle, false)
    accessResult(player, "Access granted. Vehicle unlocked for guests.")
    return true
end

Events.OnClientCommand.Add(function(module, command, player, arguments)
    if module ~= PhunKeys.module then
        return
    end

    log("OnClientCommand command=" .. tostring(command)
        .. " player=" .. tostring(player and player:getUsername() or "nil")
        .. " arguments=" .. tostring(arguments))

    if command == PhunKeys.command then
        packVehicle(player, arguments)
    elseif command == PhunKeys.grantAccessCommand then
        PhunKeys.GrantAccess(player, arguments)
    elseif command == PhunKeys.lockCommand then
        PhunKeys.Lock(player, arguments)
    end
end)

log("Server Lua loaded.")