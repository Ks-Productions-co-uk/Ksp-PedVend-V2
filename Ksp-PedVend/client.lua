local QBCore = exports['qb-core']:GetCoreObject()
local cooldownNotified = false
local currentObjects = {}
local currentBlips = {}
local Items = Config.Items
local menuStructure = {}

-- Functions
function OpenMainMenu()
    CreateMenuStructure()
    SendNUIMessage({
        type = "openMenu",
        menuStructure = menuStructure,
        items = Config.Items
    })
    SetNuiFocus(true, true)
end

function CreateMenuStructure()
    menuStructure = {}

    for category, items in pairs(Items) do
        local submenuOptions = {}
        for _, item in ipairs(items) do
            table.insert(submenuOptions, {
                label = string.format("%s - Sell: $%s | Buy: $%s", item.label, item.price, item.price * 2),
                itemName = item.name,
                sellPrice = item.price,
                buyPrice = item.price * 2
            })
        end
        table.insert(menuStructure, {
            label = category,
            submenu = submenuOptions
        })
    end

    table.insert(menuStructure, {
        label = "Marked Bill Exchange",
        submenu = {
            {
                label = "Exchange Marked Bills",
                itemName = "markedbills",
                sellPrice = 2000,
                buyPrice = 2000
            }
        }
    })
end

-- Events
RegisterNetEvent('ksp-pedvend:openMainMenu')
AddEventHandler('ksp-pedvend:openMainMenu', function()
    TriggerServerEvent('ksp-pedvend:checkMenuCooldown')
end)

RegisterNetEvent('ksp-pedvend:menuAccessGranted')
AddEventHandler('ksp-pedvend:menuAccessGranted', function()
    OpenMainMenu()
end)

RegisterNetEvent('ksp-pedvend:menuAccessDenied')
AddEventHandler('ksp-pedvend:menuAccessDenied', function()
    return
end)

RegisterNetEvent('ksp-pedvend:callPolice')
AddEventHandler('ksp-pedvend:callPolice', function(items, quantity, actionType)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local alertMessage = ''
    
    if actionType == 'buying' then
        alertMessage = 'Suspicious activity detected. Someone is buying: ' .. items
    elseif actionType == 'selling' then
        alertMessage = 'Suspicious activity detected. Someone is selling: ' .. items
    elseif actionType == 'exchanging' then
        alertMessage = 'Suspicious activity detected. Someone is exchanging: ' .. items
    end
    
    TriggerServerEvent('police:server:policeAlert', alertMessage)
end)

RegisterNetEvent('ksp-pedvend:notifyCooldown')
AddEventHandler('ksp-pedvend:notifyCooldown', function(timeLeft)
    if not cooldownNotified then
        TriggerEvent('QBCore:Notify', "You need to wait " .. timeLeft .. " seconds before selling again.", 'error')
        cooldownNotified = true

        Citizen.SetTimeout(timeLeft * 1000, function()
            cooldownNotified = false
        end)
    end
end)

-- NUI Callbacks
RegisterNUICallback('sellItems', function(data, cb)
    local items = data.items
    local category = data.category
    local totalQuantity = 0
    for _, item in ipairs(items) do
        totalQuantity = totalQuantity + item.quantity
    end
    
    local sellDuration = math.min(totalQuantity * 1000, 60000)
    
    QBCore.Functions.Progressbar("sell_items", "Selling items...", sellDuration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('ksp-pedvend:sellMultipleItems', items, category)
        if math.random(1, 100) <= Config.PoliceCallChance then
            local itemList = {}
            for _, item in ipairs(items) do
                table.insert(itemList, item.quantity .. "x " .. item.name)
            end
            local itemString = table.concat(itemList, ", ")
            TriggerEvent('ksp-pedvend:callPolice', itemString, totalQuantity, 'selling')
        end
    end, function()
        TriggerEvent('QBCore:Notify', "Sale canceled.", 'error')
    end)
    
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('buyItems', function(data, cb)
    local items = data.items
    local category = data.category
    local totalQuantity = 0
    for _, item in ipairs(items) do
        totalQuantity = totalQuantity + item.quantity
    end
    
    local buyDuration = math.min(totalQuantity * 1000, 60000)
    
    QBCore.Functions.Progressbar("buy_items", "Buying items...", buyDuration, false, true, {
        disableMovement = true,
        disableCarMovement = true,
        disableMouse = false,
        disableCombat = true,
    }, {}, {}, {}, function()
        TriggerServerEvent('ksp-pedvend:buyMultipleItems', items, category)
        if math.random(1, 100) <= Config.BuyPoliceCallChance then
            local itemList = {}
            for _, item in ipairs(items) do
                table.insert(itemList, item.quantity .. "x " .. item.name)
            end
            local itemString = table.concat(itemList, ", ")
            TriggerEvent('ksp-pedvend:callPolice', itemString, totalQuantity, 'buying')
        end
    end, function()
        TriggerEvent('QBCore:Notify', "Purchase canceled.", 'error')
    end)
    
    SetNuiFocus(false, false)
    cb('ok')
end)

RegisterNUICallback('exchangeMarkedBills', function(data, cb)
    local quantity = data.quantity
    if quantity and quantity > 0 then
        local exchangeDuration = math.min(quantity * 1000, 60000)
        QBCore.Functions.Progressbar("exchange_marked_bills", "Exchanging...", exchangeDuration, false, true, {
            disableMovement = true,
            disableCarMovement = true,
            disableMouse = false,
            disableCombat = true,
        }, {}, {}, {}, function()
            TriggerServerEvent('ksp-pedvend:exchangeMarkedBills', quantity)
            if math.random(1, 100) <= Config.PoliceCallChance then
                TriggerEvent('ksp-pedvend:callPolice', quantity .. "x marked bills", quantity, 'exchanging')
            end
        end, function()
            TriggerEvent('QBCore:Notify', "Exchange canceled.", 'error')
        end)
    else
        TriggerEvent('QBCore:Notify', "Invalid quantity.", 'error')
    end
    cb('ok')
end)

RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
    cb({status = 'ok'})
    Wait(100)
end)

-- Main Thread for Static Vehicles
Citizen.CreateThread(function()
    Wait(1000)
    
    for _, location in pairs(Config.SellLocations) do
        -- Create vehicle and driver
        local hash = GetHashKey(location.vehicle)
        local driverModel = GetHashKey("s_m_m_gentransport")
        
        RequestModel(hash)
        RequestModel(driverModel)
        
        while not HasModelLoaded(hash) or not HasModelLoaded(driverModel) do
            Wait(10)
        end
        
        local vehicle = CreateVehicle(hash, location.coords.x, location.coords.y, location.coords.z, location.coords.w, true, false)
        SetEntityAsMissionEntity(vehicle, true, true)
        SetVehicleOnGroundProperly(vehicle)
        
        -- Create and setup driver
        local driver = CreatePed(4, driverModel, location.coords.x, location.coords.y, location.coords.z, location.coords.w, true, true)
        TaskWarpPedIntoVehicle(driver, vehicle, -1)
        SetEntityAsMissionEntity(driver, true, true)
        SetBlockingOfNonTemporaryEvents(driver, true)
        SetPedCanBeDraggedOut(driver, false)
        SetPedCanBeKnockedOffVehicle(driver, 1)
        SetPedCanRagdoll(driver, false)
        SetEntityInvincible(driver, true)
        
        -- Vehicle settings
        SetVehicleDoorsLocked(vehicle, 2)
        SetVehicleEngineOn(vehicle, true, true, false)
        SetVehicleDirtLevel(vehicle, 0.0)
        SetVehicleDoorOpen(vehicle, 5, false, false)  -- 5 is trunk door
        
        if Config.ShowBlips and location.blip then
            local blip = AddBlipForCoord(location.coords.x, location.coords.y, location.coords.z)
            SetBlipSprite(blip, location.blip.sprite)
            SetBlipDisplay(blip, 4)
            SetBlipScale(blip, location.blip.scale)
            SetBlipColour(blip, location.blip.color)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName("STRING")
            AddTextComponentString(location.blip.label)
            EndTextCommandSetBlipName(blip)
            table.insert(currentBlips, blip)
        end
    
        exports['qb-target']:AddTargetEntity(vehicle, {
            options = {
                {
                    type = "client",
                    event = "ksp-pedvend:openMainMenu",
                    icon = "fas fa-cash-register",
                    label = "Access Vendor",
                }
            },
            distance = 2.5
        })
        
        table.insert(currentObjects, {vehicle = vehicle, driver = driver})
        
        SetModelAsNoLongerNeeded(hash)
        SetModelAsNoLongerNeeded(driverModel)
    end
end)

-- Cleanup Handler
AddEventHandler('onResourceStop', function(resourceName)
    if resourceName == GetCurrentResourceName() then
        -- Clean up blips
        if currentBlips then
            for _, blip in pairs(currentBlips) do
                RemoveBlip(blip)
            end
        end
        
        if currentObjects then
            for _, obj in pairs(currentObjects) do
                if type(obj) == "table" then
                    if obj.vehicle and DoesEntityExist(obj.vehicle) then
                        DeleteEntity(obj.vehicle)
                    end
                    if obj.driver and DoesEntityExist(obj.driver) then
                        DeleteEntity(obj.driver)
                    end
                else
                    if DoesEntityExist(obj) then
                        DeleteEntity(obj)
                    end
                end
            end
        end
    end
end)

