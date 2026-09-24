print("[PhunKeys][BOOT][DEBUG2] ENTER CLIENT PhunKeys_Mechanics.lua")
if isServer() then return end
require "PhunKeys_Access"

local function mlog(message)
    print("[PhunKeys][MECHANICS] " .. tostring(message))
end

local function req(path)
    local ok, err = pcall(require, path)
    if not ok then mlog("REQUIRE FAILED '" .. tostring(path) .. "': " .. tostring(err)) end
    return ok
end

local okMenu = req("Vehicles/ISUI/ISVehicleMenu")
local okMechanics = req("Vehicles/ISUI/ISVehicleMechanics")
local okOpen = req("Vehicles/TimedActions/ISOpenMechanicsUIAction")

local function denied(player, vehicle, source)
    local allowed = PhunKeys.canInteract(player, vehicle)
    if allowed then return false end
    mlog("BLOCK " .. tostring(source)
        .. " player=" .. tostring(player and player:getUsername() or "nil")
        .. " vehicleId=" .. tostring(vehicle and vehicle:getId() or "nil")
        .. " protected=" .. tostring(vehicle and PhunKeys.isProtected(vehicle) or false)
        .. " guestAccess=" .. tostring(vehicle and PhunKeys.isGuestAccessGranted(vehicle) or false))
    if player then player:Say("This vehicle is locked. You need its matching key.") end
    return true
end

local hooksOK, hooksFailed = 0, 0

if okMenu and ISVehicleMenu and type(ISVehicleMenu.onMechanic) == "function" then
    local onMechanic = ISVehicleMenu.onMechanic
    ISVehicleMenu.onMechanic = function(player, vehicle, ...)
        if denied(player, vehicle, "ISVehicleMenu.onMechanic") then return end
        return onMechanic(player, vehicle, ...)
    end
    hooksOK = hooksOK + 1
    mlog("HOOK OK ISVehicleMenu.onMechanic")
else
    hooksFailed = hooksFailed + 1
    mlog("HOOK FAILED ISVehicleMenu.onMechanic")
end

if okOpen and ISOpenMechanicsUIAction
    and type(ISOpenMechanicsUIAction.isValid) == "function"
    and type(ISOpenMechanicsUIAction.perform) == "function" then
    local openValid, openPerform = ISOpenMechanicsUIAction.isValid, ISOpenMechanicsUIAction.perform
    ISOpenMechanicsUIAction.isValid = function(self, ...)
        if not PhunKeys.canInteract(self.character, self.vehicle) then
            mlog("BLOCK ISOpenMechanicsUIAction.isValid vehicleId=" .. tostring(self.vehicle and self.vehicle:getId() or "nil"))
            return false
        end
        return openValid(self, ...)
    end
    ISOpenMechanicsUIAction.perform = function(self, ...)
        if denied(self.character, self.vehicle, "ISOpenMechanicsUIAction.perform") then
            ISBaseTimedAction.perform(self)
            return
        end
        return openPerform(self, ...)
    end
    hooksOK = hooksOK + 2
    mlog("HOOK OK ISOpenMechanicsUIAction.isValid/perform")
else
    hooksFailed = hooksFailed + 1
    mlog("HOOK FAILED ISOpenMechanicsUIAction.isValid/perform")
end

if okMechanics and ISVehicleMechanics and type(ISVehicleMechanics.doPartContextMenu) == "function" then
    local partMenu = ISVehicleMechanics.doPartContextMenu
    ISVehicleMechanics.doPartContextMenu = function(self, ...)
        if denied(self.chr, self.vehicle, "ISVehicleMechanics.doPartContextMenu") then self:close(); return end
        return partMenu(self, ...)
    end
    hooksOK = hooksOK + 1
    mlog("HOOK OK ISVehicleMechanics.doPartContextMenu")
else
    hooksFailed = hooksFailed + 1
    mlog("HOOK FAILED ISVehicleMechanics.doPartContextMenu")
end

if okMenu and ISVehicleMenu and type(ISVehicleMenu.showRadialMenu) == "function" then
    local showRadial = ISVehicleMenu.showRadialMenu
    ISVehicleMenu.showRadialMenu = function(player, ...)
        local result = showRadial(player, ...)
        local vehicle = player:getVehicle()
        local menu = getPlayerRadialMenu(player:getPlayerNum())
        if vehicle and menu:isReallyVisible() and PhunKeys.isProtected(vehicle)
            and PhunKeys.canInteract(player, vehicle) and vehicle:isDriver(player)
            and vehicle:isEngineWorking() and not vehicle:isEngineStarted() and not vehicle:isEngineRunning()
            and not SandboxVars.VehicleEasyUse and not vehicle:isHotwired()
            and not vehicle:isKeysInIgnition() and not PhunKeys.hasRealKey(player, vehicle) then
            mlog("adding protected guest Start Engine radial slice vehicleId=" .. tostring(vehicle:getId()))
            menu:addSlice(getText("ContextMenu_VehicleStartEngine"),
                getTexture("media/ui/vehicles/vehicle_ignitionON.png"), ISVehicleMenu.onStartEngine, player)
        end
        return result
    end
    hooksOK = hooksOK + 1
    mlog("HOOK OK ISVehicleMenu.showRadialMenu")
else
    hooksFailed = hooksFailed + 1
    mlog("HOOK FAILED ISVehicleMenu.showRadialMenu")
end

mlog("load complete; hooksOK=" .. tostring(hooksOK) .. " hooksFailed=" .. tostring(hooksFailed))
