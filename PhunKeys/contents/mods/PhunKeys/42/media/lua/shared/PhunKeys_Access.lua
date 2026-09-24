print("[PhunKeys][BOOT][DEBUG2] ENTER SHARED PhunKeys_Access.lua")
require "PhunKeys_Shared"

-- Two booleans on an existing vehicle part are persisted/replicated by vanilla:
-- PhunKeysAccess = protected vehicle; PhunKeysGuestAccess = reversible guest permission.
-- Neither is a player/ownership registry.
function PhunKeys.accessPart(vehicle)
    return vehicle and (vehicle:getPartById("Engine") or vehicle:getPartByIndex(0))
end

function PhunKeys.isProtected(vehicle)
    local part = PhunKeys.accessPart(vehicle)
    return part ~= nil and part:getModData().PhunKeysAccess == true
end

-- Guest permission is a separate, explicit state from protection.
-- Missing/false means access is revoked (the safe default for older protected cars).
function PhunKeys.isGuestAccessGranted(vehicle)
    local part = PhunKeys.accessPart(vehicle)
    return part ~= nil and part:getModData().PhunKeysGuestAccess == true
end

function PhunKeys.hasRealKey(player, vehicle)
    if not player then return false end
    local key = player:getInventory():haveThisKeyId(vehicle:getKeyId())
    return key ~= nil and key ~= false
end

function PhunKeys.isMechanicsAdmin(player)
    return player and (player:isMechanicsCheat()
        or (checkPermissions and Capability and checkPermissions(player, Capability.UseMechanicsCheat)))
end

-- Kept as a diagnostic/helper matching B42.20.x physical accessibility.
-- PhunKeys authorization no longer derives from this: Lock/Grant Access is explicit.
function PhunKeys.isAccessible(vehicle)
    for i = 0, vehicle:getPartCount() - 1 do
        local part = vehicle:getPartByIndex(i)
        if part then
            local door, window = part:getDoor(), part:getWindow()
            if part:getId() ~= "EngineDoor" and door
                and (door:isOpen() or not door:isLocked() or not part:getInventoryItem()) then return true end
            if window and (window:isOpen() or window:isDestroyed() or not part:getInventoryItem()) then return true end
        end
    end
    return false
end

function PhunKeys.canInteract(player, vehicle)
    if not PhunKeys.isProtected(vehicle) then return true end
    return player ~= nil and (PhunKeys.isMechanicsAdmin(player)
        or PhunKeys.hasRealKey(player, vehicle) or PhunKeys.isGuestAccessGranted(vehicle)) or false
end

-- Passenger entry/exit and the real key test are left to vanilla.
-- An authorized guest can request an engine start without acquiring a key.
function PhunKeys.startProtectedEngine(player, vehicle)
    if not player or not vehicle or player:getVehicle() ~= vehicle
        or not vehicle:isDriver(player) or not PhunKeys.canInteract(player, vehicle) then return false end
    vehicle:tryStartEngine(true)
    return true
end

print("[PhunKeys][SHARED][Access] PhunKeys_Access.lua loaded")
