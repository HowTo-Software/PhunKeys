print("[PhunKeys][BOOT][DEBUG2] ENTER SERVER PhunKeys_CommandGuard.lua")
if isClient() then return end
require "PhunKeys_Access"

local function glog(message) print("[PhunKeys][COMMANDGUARD] " .. tostring(message)) end

local mutations = {
    crash = true, damageFromHitChr = true, fixPart = true, setPartCondition = true, setContainerContentAmount = true,
    setTirePressure = true, setDoorOpen = true, damageWindow = true,
    configHeadlight = true, repair = true, repairPart = true, remove = true,
    cheatHotwire = true, setRust = true, setHSV = true, setSkinIndex = true,
    setAlarmed = true, putKeyOnDoor = true, removeKeyFromDoor = true
}
function PhunKeys.allowVehicleCommand(player, command, args)
    glog("command=" .. tostring(command) .. " player=" .. tostring(player and player:getUsername() or "nil") .. " args=" .. tostring(args))
    if command == "startEngine" then
        local vehicle = player:getVehicle()
        if PhunKeys.isProtected(vehicle) then
            PhunKeys.startProtectedEngine(player, vehicle)
            return false -- handled here; never trust the client's args.haveKey
        end
        return true
    end
    if command == "attachTrailer" then
        return PhunKeys.canInteract(player, getVehicleById(args.vehicleA))
            and PhunKeys.canInteract(player, getVehicleById(args.vehicleB))
    end
    if (command == "detachTrailer" or command == "detachTrailerSpontaneous") then
        local vehicle = getVehicleById(args.vehicle)
        return PhunKeys.canInteract(player, vehicle)
            and PhunKeys.canInteract(player, vehicle and vehicle:getVehicleTowing())
            and PhunKeys.canInteract(player, vehicle and vehicle:getVehicleTowedBy())
    end
    if not mutations[command] then return true end
    local vehicle = getVehicleById(args.vehicle)
    if not PhunKeys.isProtected(vehicle) then return true end
    -- Whole-vehicle deletion is an admin operation, never guest Mechanics access.
    if command == "remove" then return PhunKeys.isMechanicsAdmin(player) end
    if command == "setDoorOpen" and args.open == false then return true end
    if not PhunKeys.canInteract(player, vehicle) then
        glog("BLOCK vehicle/" .. command .. " on locked protected vehicle.")
        return false
    end
    return true
end

glog("PhunKeys_CommandGuard.lua loaded")
