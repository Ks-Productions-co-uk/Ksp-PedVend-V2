local QBCore = exports['qb-core']:GetCoreObject()
local vendorCooldown = {}
local cooldownTime = Config.Cooldown

-- Event Handlers
RegisterServerEvent('ksp-pedvend:sellMultipleItems')
AddEventHandler('ksp-pedvend:sellMultipleItems', function(items, category)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local currentTime = os.time()

    local totalPrice = 0
    local soldItems = {}

    for _, item in ipairs(items) do
        local itemConfig = nil
        for _, configItem in ipairs(Config.Items[category]) do
            if configItem.name == item.name then
                itemConfig = configItem
                break
            end
        end

        if itemConfig then
            local playerItem = xPlayer.Functions.GetItemByName(item.name)
            if playerItem and playerItem.amount >= item.quantity then
                local itemPrice = itemConfig.price * item.quantity
                xPlayer.Functions.RemoveItem(item.name, item.quantity)
                totalPrice = totalPrice + itemPrice
                table.insert(soldItems, {name = itemConfig.label, quantity = item.quantity, price = itemPrice})
            else
                TriggerClientEvent('QBCore:Notify', src, "You don't have enough " .. itemConfig.label .. " to sell.", 'error')
            end
        end
    end

    if totalPrice > 0 then
        xPlayer.Functions.AddMoney('cash', totalPrice)
        TriggerClientEvent('QBCore:Notify', src, 'You sold multiple items for $' .. totalPrice, 'success')
        TriggerClientEvent('playCashSound', src)

        TriggerClientEvent('ksp-pedvend:soldItemsBreakdown', src, soldItems)
    end
end)

RegisterServerEvent('ksp-pedvend:buyMultipleItems')
AddEventHandler('ksp-pedvend:buyMultipleItems', function(items, category)
    local src = source
    local xPlayer = QBCore.Functions.GetPlayer(src)
    local totalPrice = 0
    local boughtItems = {}

    for _, item in ipairs(items) do
        local itemConfig = nil
        for _, configItem in ipairs(Config.Items[category]) do
            if configItem.name == item.name then
                itemConfig = configItem
                break
            end
        end

        if itemConfig then
            local itemPrice = (itemConfig.price * 2) * item.quantity
            if xPlayer.Functions.RemoveMoney('cash', itemPrice) then
                xPlayer.Functions.AddItem(item.name, item.quantity)
                totalPrice = totalPrice + itemPrice
                table.insert(boughtItems, {name = itemConfig.label, quantity = item.quantity, price = itemPrice})
            else
                TriggerClientEvent('QBCore:Notify', src, "You don't have enough money to buy " .. itemConfig.label .. ".", 'error')
            end
        end
    end

    if totalPrice > 0 then
        TriggerClientEvent('QBCore:Notify', src, 'You bought multiple items for $' .. totalPrice, 'success')
        TriggerClientEvent('ksp-pedvend:boughtItemsBreakdown', src, boughtItems)
    end
end)

RegisterServerEvent('ksp-pedvend:exchangeMarkedBills')
AddEventHandler('ksp-pedvend:exchangeMarkedBills', function(quantity)
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    local markedBillItem = 'markedbills'
    local exchangeRate = 2000

    if not Player then
        print("Player object is nil for source: " .. src)
        TriggerClientEvent('QBCore:Notify', src, "Unable to process exchange. Player not found.", 'error')
        return
    end

    if not Player.Functions.GetItemByName then
        print("GetItemByName function not found for player: " .. src)
        TriggerClientEvent('QBCore:Notify', src, "Unable to process exchange. Inventory function not found.", 'error')
        return
    end

    local markedBills = Player.Functions.GetItemByName(markedBillItem)
    print("Marked bills for player " .. src .. ": " .. tostring(markedBills))

    if not markedBills then
        TriggerClientEvent('QBCore:Notify', src, "You don't have any marked bills.", 'error')
        return
    end

    if markedBills.amount < quantity then
        TriggerClientEvent('QBCore:Notify', src, "You don't have enough marked bills. You have " .. markedBills.amount .. ".", 'error')
        return
    end

    local totalAmount = quantity * exchangeRate

    Player.Functions.RemoveItem(markedBillItem, quantity)
    Player.Functions.AddMoney('bank', totalAmount)

    TriggerClientEvent('QBCore:Notify', src, "Exchanged " .. quantity .. " marked bills for $" .. totalAmount, 'success')
end)

RegisterServerEvent('ksp-pedvend:checkMenuCooldown')
AddEventHandler('ksp-pedvend:checkMenuCooldown', function()
    local src = source
    local currentTime = os.time()
    
    if vendorCooldown[src] then
        if (currentTime - vendorCooldown[src]) < cooldownTime then
            local timeLeft = math.ceil(cooldownTime - (currentTime - vendorCooldown[src]))
            TriggerClientEvent('QBCore:Notify', src, "Vendor cooldown active: " .. timeLeft .. " seconds remaining", 'error')
            return false
        end
    end
    
    vendorCooldown[src] = currentTime
    TriggerClientEvent('ksp-pedvend:menuAccessGranted', src)
    return true
end)
