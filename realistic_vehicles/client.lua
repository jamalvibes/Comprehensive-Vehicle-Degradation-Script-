local vehicleStates = {}
math.randomseed(GetGameTimer())

-- ================================
-- HELPERS
-- ================================
local function clamp(val, min, max)
    return math.max(min, math.min(max, val))
end

local function vehKey(veh)
    return tostring(veh)
end

local function initVehicle(veh)
    local key = vehKey(veh)
    if vehicleStates[key] then return end

    vehicleStates[key] = {
        engine = GetVehicleEngineHealth(veh),
        body = GetVehicleBodyHealth(veh),
        tires = 100.0,
        lastPos = GetEntityCoords(veh),
        lastSpeed = 0.0
    }
end

local function loadAnim(dict)
    RequestAnimDict(dict)
    while not HasAnimDictLoaded(dict) do
        Wait(0)
    end
end

local function playRepairAnim(ped, dict, anim, duration)
    loadAnim(dict)
    TaskPlayAnim(ped, dict, anim, 8.0, -8.0, duration, 1, 0, false, false, false)
end

local function freezePlayer(state)
    FreezeEntityPosition(PlayerPedId(), state)
end

local function detachWheelLocal(veh, wheel)
    if not IsVehicleTyreBurst(veh, wheel, false) then
        -- Burst the tire
        SetVehicleTyreBurst(veh, wheel, true, 1000.0)
        SetVehicleWheelHealth(veh, wheel, 0.0)

        -- Fully break off the wheel visually and physically
        BreakOffVehicleWheel(veh, wheel, true, false, true, false)
    end
end

-- ================================
-- SYNCED REPAIR Event
-- ================================
RegisterNetEvent("veh:repairVehicle", function(netId, repairType)
    local veh = NetToVeh(netId)
    if veh == 0 then return end

    local data = vehicleStates[vehKey(veh)]
    if not data then return end

    if repairType == "tires" then
        for _, w in pairs({0,1,4,5}) do
            SetVehicleTyreFixed(veh, w)
            SetVehicleWheelHealth(veh, w, 1000.0)
        end
        data.tires = Config.RepairValues.Tires
        SetVehicleReduceGrip(veh, false)

    elseif repairType == "engine" then
        data.engine = Config.RepairValues.Engine
        SetVehicleEngineHealth(veh, data.engine)

    elseif repairType == "body" then
        data.body = Config.RepairValues.Body
        SetVehicleBodyHealth(veh, data.body)
    end
end)

-- ================================
-- SYNCED WHEEL DETACH EVENT
-- ================================
RegisterNetEvent("veh:detachWheels")
AddEventHandler("veh:detachWheels", function(netId, wheels)
    local veh = NetToVeh(netId)
    if veh == 0 then return end

    for _, wheel in ipairs(wheels) do
        detachWheelLocal(veh, wheel)
    end
end)

-- ================================
-- VEHICLE UPDATE LOOP
-- ================================
CreateThread(function()
    while true do
        Wait(1000)

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then goto skip end

        initVehicle(veh)
        local data = vehicleStates[vehKey(veh)]

        local speed = GetEntitySpeed(veh)
        local pos = GetEntityCoords(veh)
        local dist = #(pos - data.lastPos)

        -- Passive wear
        data.engine = clamp(
            data.engine - Config.EngineWearPerSecond,
            Config.MinEngineHealth,
            1000.0
        )

        data.body = clamp(
            data.body - Config.BodyWearPerSecond,
            Config.MinBodyHealth,
            1000.0
        )

        -- Tire wear
        data.tires = clamp(
            data.tires - (dist * Config.TireWearPerMeter),
            Config.MinTireHealth,
            100.0
        )

    -- Collision logic
local speedDelta = data.lastSpeed - speed
if speedDelta > 10.0 then
    local impactDamage = speedDelta * Config.CollisionMultiplier

    data.engine = data.engine - (impactDamage * Config.EngineMultiplier)
    data.body   = data.body - (impactDamage * Config.BodyImpactMultiplier)

    -- Wheel loss (server-synced)
    if Config.WheelDamage.Enabled then
        local threshold = Config.WheelDamage.ImpactThreshold

        if data.tires <= Config.WheelDamage.LowTireThreshold then
            threshold = threshold / Config.WheelDamage.WornTireMultiplier
        end

        if speedDelta >= threshold and math.random() < Config.WheelDamage.DetachChance then
            local wheels = {0, 1, 4, 5}

            -- Randomly detach 1 to 3 wheels
            local detachCount = math.random(1, 3)
            local detached = {}

            for i = 1, detachCount do
                -- pick a random wheel not already detached
                local idx = math.random(#wheels)
                table.insert(detached, wheels[idx])
                table.remove(wheels, idx)
            end

            -- Trigger server once with all wheels
            TriggerServerEvent(
                "veh:detachWheelsServer",
                NetworkGetNetworkIdFromEntity(veh),
                detached
            )

            data.tires = math.max(data.tires - (15.0 * detachCount), 0.0)
        end
    end
end

        -- Apply damage
        SetVehicleEngineHealth(veh, data.engine)
        SetVehicleBodyHealth(veh, data.body)

         -- Engine stuck/off if engine or body reaches 0%
        if data.engine <= 0.0 or data.body <= 0.0 then
            data.stalled = true
            SetVehicleEngineOn(veh, false, true, true)
        else
            if data.stalled then
                -- Prevent engine from being turned on until repaired
                SetVehicleEngineOn(veh, false, true, true)
            end
        end
        -- Engine smoke logic
        if data.engine / 1000 <= 0.20 then
            if not data.smoking then
                data.smoking = true
                TriggerServerEvent("veh:engineSmoke", NetworkGetNetworkIdFromEntity(veh), true)
            end
        else
            if data.smoking then
                data.smoking = false
                TriggerServerEvent("veh:engineSmoke", NetworkGetNetworkIdFromEntity(veh), false)
            end
        end
        -- Grip effects
        SetVehicleReduceGrip(veh, data.tires <= 25)

        data.lastSpeed = speed
        data.lastPos = pos

        ::skip::
    end
end)

-- ================================
-- HUD
-- ================================
CreateThread(function()
    while true do
        Wait(0)

        if not Config.HUD.Enabled then goto skip end

        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if veh == 0 then goto skip end

        local data = vehicleStates[vehKey(veh)]
        if not data then goto skip end

        local function draw(x, y, text)
            SetTextFont(4)
            SetTextScale(Config.HUD.Scale, Config.HUD.Scale)
            SetTextColour(255, 255, 255, 220)
            SetTextOutline()
            BeginTextCommandDisplayText("STRING")
            AddTextComponentString(text)
            EndTextCommandDisplayText(x, y)
        end

        local x, y, s = Config.HUD.X, Config.HUD.Y, Config.HUD.Spacing

        draw(x, y,         string.format("Engine: %.0f%%", (data.engine / 1000) * 100))
        draw(x, y + s,     string.format("Body: %.0f%%",   (data.body / 1000) * 100))
        draw(x, y + s * 2, string.format("Tires: %.0f%%",  data.tires))

        ::skip::
    end
end)

-- ================================
-- CLEANUP DESTROYED VEHICLES
-- ================================
CreateThread(function()
    while true do
        Wait(10000)
        for k in pairs(vehicleStates) do
            if not DoesEntityExist(tonumber(k)) then
                vehicleStates[k] = nil
            end
        end
    end
end)

-- ================================
-- REPAIR COMMANDS (Client-Side Visual Fix)
-- ================================
local function getNearestVehicleWithinDistance(pedCoords, maxDistance)
    local veh = GetVehiclePedIsIn(PlayerPedId(), false)
    if veh ~= 0 then
        return veh
    end

    -- Find closest vehicle
    veh = GetClosestVehicle(pedCoords.x, pedCoords.y, pedCoords.z, maxDistance, 0, 70)
    if DoesEntityExist(veh) then
        local vehCoords = GetEntityCoords(veh)
        if #(pedCoords - vehCoords) <= maxDistance then
            return veh
        end
    end

    return nil
end

local function applyLocalRepair(veh, part)
    local key = vehKey(veh)
    if not vehicleStates[key] then return end

    if part == "engine" then
        vehicleStates[key].engine = Config.RepairValues.Engine
        vehicleStates[key].stalled = false
        SetVehicleEngineHealth(veh, Config.RepairValues.Engine)

    elseif part == "body" then
        vehicleStates[key].body = Config.RepairValues.Body
        vehicleStates[key].stalled = false
        SetVehicleBodyHealth(veh, Config.RepairValues.Body)
        SetVehicleDeformationFixed(veh)

    elseif part == "tires" then
        vehicleStates[key].tires = Config.RepairValues.Tires
        for _, w in ipairs({0,1,4,5}) do
            SetVehicleTyreFixed(veh, w)
        end
        SetVehicleReduceGrip(veh, false)
    end

    -- Fix vehicle visually and clean it
    SetVehicleFixed(veh)
    SetVehicleDirtLevel(veh, 0.0)
end

-- Replace Tires
RegisterCommand("replacetires", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = getNearestVehicleWithinDistance(coords, Config.RepairDistance)
    if not veh then
        TriggerEvent('chat:addMessage', { args = { "No vehicle nearby within repair range." } })
        return
    end

    freezePlayer(true)
    playRepairAnim(ped, "amb@world_human_vehicle_mechanic@male@base", "base", Config.RepairTimes.ReplaceTires)
    Wait(Config.RepairTimes.ReplaceTires)

    TriggerServerEvent(
        "veh:repairVehicle",
        NetworkGetNetworkIdFromEntity(veh),
        "tires"
    )

    -- Apply local repair immediately
    applyLocalRepair(veh, "tires")

    ClearPedTasks(ped)
    freezePlayer(false)
end)

-- Repair Engine
RegisterCommand("repairengine", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = getNearestVehicleWithinDistance(coords, Config.RepairDistance)
    if not veh then
        TriggerEvent('chat:addMessage', { args = { "No vehicle nearby within repair range." } })
        return
    end

    freezePlayer(true)
    playRepairAnim(ped, "mini@repair", "fixing_a_ped", Config.RepairTimes.RepairEngine)
    Wait(Config.RepairTimes.RepairEngine)

    TriggerServerEvent(
        "veh:repairVehicle",
        NetworkGetNetworkIdFromEntity(veh),
        "engine"
    )

    -- Apply local repair immediately
    applyLocalRepair(veh, "engine")

    ClearPedTasks(ped)
    freezePlayer(false)
end)

-- Repair Body
RegisterCommand("repairbody", function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local veh = getNearestVehicleWithinDistance(coords, Config.RepairDistance)
    if not veh then
        TriggerEvent('chat:addMessage', { args = { "No vehicle nearby within repair range." } })
        return
    end

    freezePlayer(true)
    playRepairAnim(ped, "amb@world_human_maid_clean@base", "base", Config.RepairTimes.RepairBody)
    Wait(Config.RepairTimes.RepairBody)

    TriggerServerEvent(
        "veh:repairVehicle",
        NetworkGetNetworkIdFromEntity(veh),
        "body"
    )

    -- Apply local repair immediately
    applyLocalRepair(veh, "body")

    ClearPedTasks(ped)
    freezePlayer(false)
end)

