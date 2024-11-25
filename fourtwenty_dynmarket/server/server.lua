local QBCore, ESX = nil, nil

if Config.Framework == "QBCore" then
    QBCore = exports['qb-core']:GetCoreObject()
    if not QBCore then
        print("^1ERROR: Failed to get QBCore object.^7")
    end
elseif Config.Framework == "ESX" then
    ESX = exports['es_extended']:getSharedObject()
    if not ESX then
        print("^1ERROR: Failed to get ESX shared object.^7")
    end
else
    print("^1ERROR: Unsupported framework: " .. Config.Framework .. "^7")
end

-- State management
local marketPrices = {}
local nextUpdates = {}
local marketTrends = {}
local lastSaleUpdates = {}

-- Market initialization functions
local function LoadMarketPrices(marketId)
    local market = Config.Markets[marketId]
    if not market then 
        print(string.format("[DynMarket] Error: Market %s not found in config", marketId))
        return 
    end
    
    MySQL.Async.fetchAll('SELECT item_name, current_price, supply_impact FROM fourtwenty_market_prices WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    }, function(results)
        marketPrices[marketId] = {}
        marketTrends[marketId] = {}
        lastSaleUpdates[marketId] = {}
        
        -- Create lookup table for saved prices
        local savedPrices = {}
        for _, row in ipairs(results) do
            savedPrices[row.item_name] = {
                price = row.current_price,
                supplyImpact = row.supply_impact or 0.0
            }
        end
        
        -- Initialize or load prices for each item
        for _, item in ipairs(market.items) do
            if not item.item or not item.basePrice then
                print(string.format("[DynMarket] Error: Invalid item configuration in market %s", marketId))
                goto continue
            end
            
            local saved = savedPrices[item.item]
            
            if saved then
                marketPrices[marketId][item.item] = saved.price
                marketTrends[marketId][item.item] = "stable"
            else
                marketPrices[marketId][item.item] = item.basePrice
                marketTrends[marketId][item.item] = "stable"
                
                MySQL.Async.execute('INSERT INTO fourtwenty_market_prices (market_id, item_name, current_price) VALUES (@marketId, @item, @price)', {
                    ['@marketId'] = marketId,
                    ['@item'] = item.item,
                    ['@price'] = item.basePrice
                })
            end
            
            lastSaleUpdates[marketId][item.item] = 0
            
            ::continue::
        end
        
        nextUpdates[marketId] = os.time() + (Config.Intervals.randomUpdate / 1000)
        
        if Config.Debug then
            print(string.format("[DynMarket] Market initialized: %s", marketId))
        end
    end)
end

function InitializeMarkets()
    for marketId, market in pairs(Config.Markets) do
        if market.enabled then
            LoadMarketPrices(marketId)
        end
    end
end

-- Database initialization
MySQL.ready(function()
    -- Original price table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_market_prices (
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            current_price INT,
            supply_impact FLOAT DEFAULT 0.0,
            last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (market_id, item_name)
        )
    ]])
    
    -- Supply/demand sales tracking table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_market_sales (
            id INT AUTO_INCREMENT PRIMARY KEY,
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            quantity INT,
            price_per_unit INT,
            sale_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX idx_market_item (market_id, item_name),
            INDEX idx_sale_time (sale_time)
        )
    ]])
    
    -- Counter items tracking table
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS fourtwenty_counter_items (
            market_id VARCHAR(50),
            item_name VARCHAR(50),
            counter_item VARCHAR(50),
            counter_quantity INT DEFAULT 0,
            last_update TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (market_id, item_name, counter_item)
        )
    ]])
    
    -- Initialize markets after database is ready
    InitializeMarkets()
end)

-- Supply & Demand Functions
local function GetBaseSupplyImpact(marketId, itemName)
    if not Config.IsSupplyDemandEnabled(marketId) then return 0.0 end
    
    local sdSettings = Config.GetSupplyDemandSettings(marketId)
    if not sdSettings then return 0.0 end
    
    local history = MySQL.Sync.fetchAll([[ 
        SELECT 
            COUNT(*) as transactions, 
            SUM(quantity) as total_sold 
        FROM fourtwenty_market_sales 
        WHERE 
            market_id = @marketId 
            AND item_name = @itemName 
            AND sale_time > DATE_SUB(NOW(), INTERVAL @hours HOUR)
    ]], {
        ['@marketId'] = marketId,
        ['@itemName'] = itemName,
        ['@hours'] = sdSettings.history.duration
    })[1]

    -- If no sales, reduce price over time for recovery
    if not history or not history.total_sold or history.total_sold == 0 then
        return -sdSettings.impact.recovery
    end

    -- Larger sales should increase price (reduce supply = scarcity)
    return -math.min(history.total_sold * sdSettings.impact.sale, sdSettings.impact.maximum)
end

local function GetCounterItemEffect(marketId, itemName)
    if not Config.PriceCalculation.influences.counterItems.enabled then
        return 0.0
    end

    local market = Config.Markets[marketId]
    if not market then return 0.0 end
    
    -- Find item configuration
    local itemConfig = nil
    for _, item in ipairs(market.items) do
        if item.item == itemName then
            itemConfig = item
            break
        end
    end
    
    -- If no counter item defined, return 0 effect
    if not itemConfig or not itemConfig.counterItem then 
        return 0.0 
    end
    
    -- Get counter item sales data
    local counterData = MySQL.Sync.fetchAll([[
        SELECT counter_quantity 
        FROM fourtwenty_counter_items 
        WHERE market_id = @marketId 
        AND item_name = @itemName 
        AND counter_item = @counterItem
        AND last_update > DATE_SUB(NOW(), INTERVAL 24 HOUR)
    ]], {
        ['@marketId'] = marketId,
        ['@itemName'] = itemName,
        ['@counterItem'] = itemConfig.counterItem
    })[1]
    
    if not counterData or not counterData.counter_quantity then 
        return 0.0 
    end
    
    -- Calculate positive effect based on counter item sales
    local effect = counterData.counter_quantity * (itemConfig.counterEffect or 0.01)
    
    -- Ensure effect doesn't exceed maximum impact
    if market.priceSettings and market.priceSettings.supplyDemand then
        return math.min(effect, market.priceSettings.supplyDemand.impact.maximum)
    end
    
    return effect
end

local function GetSupplyImpact(marketId, itemName)
    if not Config.IsSupplyDemandEnabled(marketId) then return 0.0 end
    
    local sdSettings = Config.GetSupplyDemandSettings(marketId)
    if not sdSettings then return 0.0 end
    
    -- Get base supply/demand impact
    local baseImpact = GetBaseSupplyImpact(marketId, itemName)
    
    -- Get counter item effect (if any)
    local counterEffect = GetCounterItemEffect(marketId, itemName)
    
    -- Combine effects (counter items reduce negative supply impact)
    local finalImpact = baseImpact - counterEffect
    
    -- Ensure within maximum bounds
    return math.max(-sdSettings.impact.maximum, finalImpact)
end

local function CalculateNewPrice(marketId, itemName)
    if Config.Debug then
        print("\n=== Starting price calculation for " .. itemName .. " in market " .. marketId .. " ===")
    end

    local market = Config.Markets[marketId]
    if not market or not market.priceSettings then
        print("Error: Invalid market or missing price settings")
        return nil
    end

    -- Find item and its base price
    local item = nil
    for _, marketItem in ipairs(market.items) do
        if marketItem.item == itemName then
            item = marketItem
            break
        end
    end

    if not item then
        print("Error: Item not found in market")
        return nil
    end

    local basePrice = item.basePrice
    local currentPrice = marketPrices[marketId][itemName] or basePrice

    if Config.Debug then
        print("Base price: " .. basePrice)
        print("Current price: " .. currentPrice)
    end

    local totalChange = 0
    local totalWeight = 0

    -- Calculate random fluctuation if enabled
    if Config.PriceCalculation.influences.randomFluctuation.enabled then
        local maxChange = math.floor(basePrice * (market.priceSettings.maxChangePercent / 100))
        local randomChange = math.random(-maxChange, maxChange)
        local randomWeight = Config.PriceCalculation.influences.randomFluctuation.weight

        totalChange = totalChange + (randomChange * randomWeight)
        totalWeight = totalWeight + randomWeight

        if Config.Debug then
            print("Random price change: " .. randomChange)
            print("Random weight: " .. randomWeight)
        end
    end

    -- Apply supply & demand impact if enabled
    if Config.PriceCalculation.influences.supplyDemand.enabled then
        local supplyImpact = GetSupplyImpact(marketId, itemName)
        local supplyChange = math.floor(basePrice * supplyImpact)
        local supplyWeight = Config.PriceCalculation.influences.supplyDemand.weight

        totalChange = totalChange + (supplyChange * supplyWeight)
        totalWeight = totalWeight + supplyWeight

        if Config.Debug then
            print("Supply impact (price delta): " .. supplyChange)
            print("Supply weight: " .. supplyWeight)
        end
    end

    -- Normalize the total change if we have any weights
    if totalWeight > 0 then
        totalChange = totalChange / totalWeight
    end

    if Config.Debug then
        print("Total weighted change: " .. totalChange)
    end

    -- Final price calculation
    local newPrice = currentPrice + totalChange
    local minPrice = math.floor(basePrice * market.priceSettings.minMultiplier)
    local maxPrice = math.floor(basePrice * market.priceSettings.maxMultiplier)
    local finalPrice = math.max(minPrice, math.min(maxPrice, math.floor(newPrice + 0.5))) -- Ensure whole numbers

    if Config.Debug then
        print("Price boundaries:")
        print("Min allowed price: " .. minPrice)
        print("Max allowed price: " .. maxPrice)
        print("Rounded final price: " .. finalPrice)
    end

    -- Apply minimal change threshold
    local threshold = Config.PriceCalculation.minChangeThreshold or 1
    if math.abs(finalPrice - currentPrice) < threshold then
        finalPrice = currentPrice
        if Config.Debug then
            print("Price change below threshold, keeping current price.")
        end
    end

    -- Set price trend
    local trend
    if finalPrice > currentPrice then
        trend = "up"
    elseif finalPrice < currentPrice then
        trend = "down"
    else
        trend = "stable"
    end
    marketTrends[marketId][itemName] = trend

    if Config.Debug then
        print("Price trend: " .. trend)
        print("=== Price calculation complete ===\n")
    end

    return finalPrice
end

local function UpdateMarketPrices(marketId)
    if not Config.Markets[marketId] or not Config.Markets[marketId].enabled then 
        return 
    end
    
    local market = Config.Markets[marketId]
    local pricesChanged = false
    
    -- Update prices for all items
    for _, configItem in ipairs(market.items) do
        local itemName = configItem.item
        local currentPrice = marketPrices[marketId][itemName] or configItem.basePrice
        
        local newPrice = CalculateNewPrice(marketId, itemName)
        
        if newPrice and newPrice ~= currentPrice then
            marketPrices[marketId][itemName] = newPrice
            pricesChanged = true
            
            -- Update database
            MySQL.Async.execute('UPDATE fourtwenty_market_prices SET current_price = @price WHERE market_id = @marketId AND item_name = @item', {
                ['@price'] = newPrice,
                ['@marketId'] = marketId,
                ['@item'] = itemName
            })
        end
    end
    
    -- Schedule next update
    nextUpdates[marketId] = os.time() + (Config.Intervals.randomUpdate / 1000)
    
    -- Notify clients if prices changed
    if pricesChanged then
        local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
        TriggerClientEvent('fourtwenty_dynmarket:updatePrices', -1, marketId, marketPrices[marketId], marketTrends[marketId], timeUntilUpdate)
    end
end

-- Price update thread
CreateThread(function()
    while true do
        local currentTime = os.time()
        
        for marketId, updateTime in pairs(nextUpdates) do
            if currentTime >= updateTime then
                UpdateMarketPrices(marketId)
            end
        end
        Wait(5000) -- Check every 5 seconds
    end
end)

-- Counter items update thread
CreateThread(function()
    while true do
        Wait(3600000) -- Check every hour
        
        if Config.PriceCalculation.influences.counterItems.enabled then
            -- Reduce counter item quantities by 50% if they haven't been updated in 24 hours
            MySQL.Async.execute([[
                UPDATE fourtwenty_counter_items 
                SET counter_quantity = FLOOR(counter_quantity * 0.5)
                WHERE last_update < DATE_SUB(NOW(), INTERVAL 24 HOUR)
            ]])
        end
    end
end)

-- Event Handlers
RegisterServerEvent('fourtwenty_dynmarket:requestMarketData')
AddEventHandler('fourtwenty_dynmarket:requestMarketData', function(marketId)
    local source = source
    
    if marketPrices[marketId] then
        local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
        TriggerClientEvent('fourtwenty_dynmarket:receiveMarketData', source, {
            marketId = marketId,
            prices = marketPrices[marketId],
            trends = marketTrends[marketId],
            nextUpdate = timeUntilUpdate
        })
    end
end)

RegisterServerEvent('fourtwenty_dynmarket:sellItems')
AddEventHandler('fourtwenty_dynmarket:sellItems', function(marketId, itemList)
    local source = source
    local xPlayer

    if Config.Framework == "ESX" then
        xPlayer = ESX.GetPlayerFromId(source)
    elseif Config.Framework == "QBCore" then
        xPlayer = QBCore.Functions.GetPlayer(source)
    else
        print("^1ERROR: Unsupported framework^7")
        return
    end

    -- Check if market and player are valid
    if not xPlayer or not Config.Markets[marketId] or not Config.Markets[marketId].enabled then 
        return 
    end

    local totalEarnings = 0
    local soldItems = {}

    -- Process each item in the sale
    for _, itemData in pairs(itemList) do
        if itemData and itemData.item then
            local item = nil

            -- Get the item from the player's inventory based on the framework
            if Config.Framework == "ESX" then
                item = xPlayer.getInventoryItem(itemData.item)
            elseif Config.Framework == "QBCore" then
                item = xPlayer.Functions.GetItemByName(itemData.item)
            end
            
            if item and ((Config.Framework == "ESX" and item.count > 0) or (Config.Framework == "QBCore" and item.amount > 0)) then
                local itemCount = Config.Framework == "ESX" and item.count or item.amount
                local price = marketPrices[marketId] and marketPrices[marketId][itemData.item] or itemData.basePrice

                if price then
                    local earnings = math.floor(itemCount * price)
                    
                    table.insert(soldItems, {
                        item = itemData.item,
                        count = itemCount,
                        price = price,
                        earnings = earnings
                    })
                    
                    totalEarnings = totalEarnings + earnings
                    
                    -- Track sale for supply/demand if enabled
                    if Config.IsSupplyDemandEnabled(marketId) then
                        lastSaleUpdates[marketId][itemData.item] = os.time()
                        
                        MySQL.Async.execute([[
                            INSERT INTO fourtwenty_market_sales 
                                (market_id, item_name, quantity, price_per_unit)
                            VALUES 
                                (@marketId, @item, @quantity, @price)
                        ]], {
                            ['@marketId'] = marketId,
                            ['@item'] = itemData.item,
                            ['@quantity'] = itemCount,
                            ['@price'] = price
                        })
                    end
                end
            else
                -- Debug info if item not found or zero quantity
                if Config.Debug then
                    print(string.format("[DynMarket] No quantity for item %s in inventory of player %s", itemData.item, xPlayer.identifier))
                end
            end
        end
    end

    if totalEarnings > 0 then
        -- Add the money to the player's account
        if Config.Framework == "ESX" then
            xPlayer.addAccountMoney('money', totalEarnings)
        elseif Config.Framework == "QBCore" then
            xPlayer.Functions.AddMoney('cash', totalEarnings)
        end
        
        -- Remove sold items from the player's inventory
        for _, sale in ipairs(soldItems) do
            if Config.Framework == "ESX" then
                xPlayer.removeInventoryItem(sale.item, sale.count)
            elseif Config.Framework == "QBCore" then
                xPlayer.Functions.RemoveItem(sale.item, sale.count)
            end
        end
        
        -- Notify the player of the completed sale
        TriggerClientEvent('fourtwenty_dynmarket:sellComplete', source, {
            total = totalEarnings,
            items = soldItems
        })
        
        if Config.Debug then
            print(string.format("[DynMarket] Sale completed for %s: $%d", xPlayer.identifier, totalEarnings))
        end
    else
        -- Notify the player if no items were sold
        TriggerClientEvent('fourtwenty_dynmarket:notification', source, 'no_items')
    end
end)

-- Counter item sale event
RegisterServerEvent('fourtwenty_dynmarket:counterItemSold')
AddEventHandler('fourtwenty_dynmarket:counterItemSold', function(marketId, itemName, counterItem, quantity)
    if not Config.PriceCalculation.influences.counterItems.enabled then return end
    
    if not Config.Markets[marketId] then return end
    
    -- Validate that this counter item exists in configuration
    local isValidCounter = false
    for _, item in ipairs(Config.Markets[marketId].items) do
        if item.item == itemName and item.counterItem == counterItem then
            isValidCounter = true
            break
        end
    end
    
    if not isValidCounter then return end
    
    -- Update counter item quantity
    MySQL.Async.execute([[
        INSERT INTO fourtwenty_counter_items 
            (market_id, item_name, counter_item, counter_quantity) 
        VALUES 
            (@marketId, @itemName, @counterItem, @quantity)
        ON DUPLICATE KEY UPDATE 
            counter_quantity = counter_quantity + @quantity,
            last_update = CURRENT_TIMESTAMP
    ]], {
        ['@marketId'] = marketId,
        ['@itemName'] = itemName,
        ['@counterItem'] = counterItem,
        ['@quantity'] = quantity
    })
end)

if Config.Framework == "ESX" then
    ESX.RegisterServerCallback('fourtwenty_dynmarket:getMarketInfo', function(source, cb, marketId)
        -- Validate market exists and is enabled
        if not Config.Markets[marketId] or not Config.Markets[marketId].enabled then
            cb(false)
            return
        end
        
        -- Validate market has been initialized
        if not nextUpdates[marketId] then
            cb(false)
            return
        end
        
        -- Calculate time until next price update
        local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
        
        -- Return market data
        cb({
            config = Config.Markets[marketId],
            prices = marketPrices[marketId] or {},
            trends = marketTrends[marketId] or {},
            nextUpdate = timeUntilUpdate
        })
    end)
elseif Config.Framework == "QBCore" then
    QBCore.Functions.CreateCallback('fourtwenty_dynmarket:getMarketInfo', function(source, cb, marketId)
        -- Validate market exists and is enabled
        if not Config.Markets[marketId] or not Config.Markets[marketId].enabled then
            cb(false)
            return
        end
        
        -- Validate market has been initialized
        if not nextUpdates[marketId] then
            cb(false)
            return
        end
        
        -- Calculate time until next price update
        local timeUntilUpdate = math.max(0, (nextUpdates[marketId] - os.time()) * 1000)
        
        -- Return market data
        cb({
            config = Config.Markets[marketId],
            prices = marketPrices[marketId] or {},
            trends = marketTrends[marketId] or {},
            nextUpdate = timeUntilUpdate
        })
    end)
else
    print("^1ERROR: Unsupported framework: " .. Config.Framework .. "^7")
end

-- Additional helper functions
local function ResetSupplyDemand(marketId)
    if not Config.Markets[marketId] then return end
    
    MySQL.Async.execute('DELETE FROM fourtwenty_market_sales WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    })
    
    MySQL.Async.execute('UPDATE fourtwenty_market_prices SET supply_impact = 0.0 WHERE market_id = @marketId', {
        ['@marketId'] = marketId
    })
end

-- Export functions for other resources
exports('getItemPrice', function(marketId, itemName)
    if marketPrices[marketId] and marketPrices[marketId][itemName] then
        return marketPrices[marketId][itemName]
    end
    return nil
end)

exports('getMarketTrends', function(marketId)
    return marketTrends[marketId] or {}
end)

exports('resetMarketPrices', function(marketId)
    if Config.Markets[marketId] then
        LoadMarketPrices(marketId)
        return true
    end
    return false
end)
