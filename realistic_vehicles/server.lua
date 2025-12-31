-- Client-side: apply repair visually and mechanically
RegisterNetEvent("veh:repairVehicle:sync")
AddEventHandler("veh:repairVehicle:sync", function(netId, part)
    local veh = NetworkGetEntityFromNetworkId(netId)
    if DoesEntityExist(veh) then
        if part == "engine" then
            SetVehicleEngineHealth(veh, 1000.0)
        elseif part == "body" then
            SetVehicleBodyHealth(veh, 1000.0)
            SetVehicleDeformationFixed(veh)
        elseif part == "tires" then
            for i = 0, 5 do
                SetVehicleTyreFixed(veh, i)
            end
        end

        -- Fix the vehicle visually
        SetVehicleFixed(veh)
        SetVehicleDirtLevel(veh, 0.0) -- optional: cleans the car

        -- Trigger your HUD refresh event
        TriggerEvent("vehiclehud:client:refresh", -1, veh)
    end
end)

--------------------------------------------------
-- Sync wheel detachment 
--------------------------------------------------
RegisterNetEvent("veh:detachWheelsServer")
AddEventHandler("veh:detachWheelsServer", function(netId, wheels)
    -- Send to all clients
    TriggerClientEvent("veh:detachWheels", -1, netId, wheels)
end)

--------------------------------------------------
-- Engine Smoke 
--------------------------------------------------
RegisterNetEvent("veh:engineSmoke")
AddEventHandler("veh:engineSmoke", function(netId, enable)
    -- Broadcast to all clients
    TriggerClientEvent("veh:engineSmokeClient", -1, netId, enable)
end)